// T2 (jam-lessons-home): `tl trees`, a removal that cannot follow a link. Everything happens inside one temp folder this test makes:
// a temp git repository (GIT_DIR unset, an empty global config), a worktree of it, and directory junctions inside that worktree
// (the ONE place a junction may be made: `cmd /c mklink /J`, inside the temp folder only). Every junction is removed with a
// non-recursive call before the temp folder goes.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import * as ctx from "../lib/ctx.mjs";
import { execute } from "../lib/commands/trees.mjs";
import { listWorktrees, processesIn, scanTree, unlinkOnly } from "../lib/trees/core.mjs";

const WIN = process.platform === "win32";

function sandbox() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "tl_trees_"));
  const cfg = path.join(root, "gitconfig"); fs.writeFileSync(cfg, "");
  const env = { ...process.env, GIT_DIR: undefined, GIT_WORK_TREE: undefined, GIT_INDEX_FILE: undefined, GIT_CONFIG_GLOBAL: cfg, GIT_CONFIG_NOSYSTEM: "1",
    GIT_AUTHOR_NAME: "t", GIT_AUTHOR_EMAIL: "t@example.invalid", GIT_COMMITTER_NAME: "t", GIT_COMMITTER_EMAIL: "t@example.invalid" };
  for (const k of Object.keys(env)) if (env[k] === undefined) delete env[k];
  const git = (cwd, ...a) => { const r = spawnSync("git", a, { cwd, env, encoding: "utf8" }); return { code: r.status ?? 2, stdout: r.stdout ?? "", stderr: r.stderr ?? "" }; };
  const repo = path.join(root, "repo"); fs.mkdirSync(repo);
  assert.equal(git(repo, "init", "-q", "-b", "main").code, 0);
  fs.writeFileSync(path.join(repo, "README.md"), "temp\n");
  fs.writeFileSync(path.join(repo, ".gitignore"), "site/\n");
  assert.equal(git(repo, "add", "README.md", ".gitignore").code, 0);
  assert.equal(git(repo, "commit", "-q", "-m", "one").code, 0);
  // the main checkout's untracked-but-kept folder (the jam's licensed plugin), and a folder outside every checkout
  const plugin = path.join(repo, "site", "plugin"); fs.mkdirSync(path.join(plugin, "sub"), { recursive: true });
  for (let i = 0; i < 5; i++) fs.writeFileSync(path.join(plugin, `f${i}.bin`), `licensed ${i}`);
  fs.writeFileSync(path.join(plugin, "sub", "deep.bin"), "deep");
  const outside = path.join(root, "outside"); fs.mkdirSync(outside); fs.writeFileSync(path.join(outside, "keep.txt"), "keep");
  return { root, repo, plugin, outside, git, gitRun: (args) => git(repo, ...args) };
}
function junction(link, target) {
  const r = spawnSync("cmd", ["/c", "mklink", "/J", link, target], { encoding: "utf8" });
  assert.equal(r.status, 0, `mklink /J failed: ${r.stdout}${r.stderr}`);
}
/** Cleanup: every link under root unlinked non-recursively, then the temp folder (made by this test) goes. */
function cleanup(root) {
  for (const l of scanTree(root).links) unlinkOnly(l.path);
  assert.equal(scanTree(root).links.length, 0, "no link may be left before the temp folder is removed");
  fs.rmSync(root, { recursive: true, force: true });
}
async function tl(args, deps) {
  const lines = []; const o = console.log, e = console.error; console.log = (...a) => lines.push(a.join(" ")); console.error = (...a) => lines.push(a.join(" "));
  let exit; try { exit = await execute(args, { ctx, ...deps }); } finally { console.log = o; console.error = e; }
  let json = null; try { json = JSON.parse(lines.at(-1)); } catch { /* usage error */ }
  return { exit, lines, json };
}
const files = (d) => scanTree(d).files;

test("processesIn: a process whose exe or command line names a path inside the tree runs from it; a sibling does not", () => {
  const procs = [{ pid: 7, exe: "C:\\x\\wt\\godot.exe", cmd: "" }, { pid: 8, exe: "", cmd: "node C:/x/wt2/a.mjs" }, { pid: 9, exe: "", cmd: "bash \"C:\\x\\wt\"" }];
  assert.deepEqual(processesIn("C:/x/wt", procs, -1).map((p) => p.pid), [7, 9]);
});

test("tl trees: list shows the worktree and its junctions; remove is a dry run by default, refuses a running process, and --apply unlinks the junctions first so their targets keep every file", { skip: !WIN && "junctions are a Windows matter (mklink /J)" }, async () => {
  const s = sandbox();
  try {
    const wt = path.join(s.root, "trees", "wt-one");
    assert.equal(s.git(s.repo, "worktree", "add", "-q", "-b", "spark/one", wt).code, 0);
    junction(path.join(wt, "plugin_link"), s.plugin);                  // into the main checkout's kept folder: the jam's case
    fs.mkdirSync(path.join(wt, "deeper"));
    junction(path.join(wt, "deeper", "outside_link"), s.outside);      // a second one, nested, to a folder outside every checkout
    fs.writeFileSync(path.join(wt, "untracked.txt"), "x");
    const pluginBefore = files(s.plugin); const outsideBefore = files(s.outside);
    assert.equal(pluginBefore, 6);

    // the scan sees both junctions as links and does not count the files behind them
    const scan = scanTree(wt);
    assert.equal(scan.links.length, 2);
    assert.ok(scan.files < 6, `the scan must not walk into a junction (counted ${scan.files})`);

    const list = await tl(["list"], { repo: s.repo, procs: [], git: s.gitRun });
    assert.equal(list.exit, 0);
    const row = list.json.trees.find((t) => t.name === "wt-one");
    assert.equal(row.branch, "spark/one"); assert.equal(row.merged, true); assert.equal(row.links.length, 2);
    assert.ok(list.lines.some((l) => l.includes("wt-one") && l.includes("plugin_link ->")));

    const dry = await tl(["remove", "wt-one"], { repo: s.repo, procs: [], git: s.gitRun });
    assert.equal(dry.exit, 0); assert.equal(dry.json.apply, false);
    assert.ok(fs.existsSync(wt) && fs.existsSync(path.join(wt, "plugin_link")), "a dry run removes nothing");
    assert.ok(dry.lines.some((l) => l.includes("dry run")));

    const busy = await tl(["remove", "wt-one", "--apply"], { repo: s.repo, procs: [{ pid: 4242, exe: path.join(wt, "godot.exe"), cmd: "" }], git: s.gitRun });
    assert.equal(busy.exit, 1); assert.ok(busy.lines.some((l) => l.startsWith("FAIL") && l.includes("refused") && l.includes("4242")));
    assert.ok(fs.existsSync(path.join(wt, "untracked.txt")), "a refused removal removes nothing");

    const done = await tl(["remove", "wt-one", "--apply"], { repo: s.repo, procs: [], git: s.gitRun });
    assert.equal(done.exit, 0, done.lines.join("\n"));
    assert.ok(!fs.existsSync(wt), "the tree is gone");
    assert.equal(files(s.plugin), pluginBefore, "every file of the main checkout's kept folder survived");
    assert.equal(fs.readFileSync(path.join(s.plugin, "sub", "deep.bin"), "utf8"), "deep");
    assert.equal(files(s.outside), outsideBefore);
    assert.ok(!listWorktrees(s.repo).some((t) => t.name === "wt-one"), "git no longer lists it");
    assert.ok(done.lines.some((l) => l.startsWith("PASS") && l.includes("unlink plugin_link")));
  } finally { cleanup(s.root); }
});

test("tl trees: unknown name, the main checkout, and a bad verb are refused", async () => {
  const s = sandbox();
  try {
    assert.equal((await tl(["remove", "nope", "--apply"], { repo: s.repo, procs: [], git: s.gitRun })).exit, 1);
    assert.equal((await tl(["remove", "repo", "--apply"], { repo: s.repo, procs: [], git: s.gitRun })).exit, 1);
    assert.ok(fs.existsSync(path.join(s.repo, "README.md")));
    assert.equal((await tl(["burn"], { repo: s.repo, procs: [] })).exit, 2);
    const wt = path.join(s.root, "trees", "wt-two");
    assert.equal(s.git(s.repo, "worktree", "add", "-q", "-b", "spark/two", wt).code, 0);
    const blind = await tl(["remove", "wt-two", "--apply"], { repo: s.repo, procs: null, git: s.gitRun });
    assert.equal(blind.exit, 1); assert.ok(blind.lines.some((l) => l.includes("could not list processes")), "no process list: refuse");
    assert.ok(fs.existsSync(path.join(wt, "README.md")));
  } finally { cleanup(s.root); }
});
