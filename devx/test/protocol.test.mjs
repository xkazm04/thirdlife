// The tl.devx/1 protocol (CLAUDE.md "The one command"): every exit path of every command ends in a tl.devx/1 JSON line
// whose `exit` equals the process exit, 0 pass, 1 fail, 2 could not run. A missing last line then means only one thing:
// the run was killed (docs/GATE-HONESTY.md). Offline: usage errors and fixture commands only, no Godot.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

const DEVX = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const TL = path.join(DEVX, "bin", "tl.mjs");
const COMMANDS = path.join(DEVX, "lib", "commands");
const tmp = (p) => fs.mkdtempSync(path.join(os.tmpdir(), p));

function tl(args, env = {}) {
  const r = spawnSync(process.execPath, [TL, ...args], { encoding: "utf8", env: { ...process.env, ...env }, timeout: 60000 });
  const lines = (r.stdout ?? "").split(/\r?\n/).filter((l) => l.trim());
  let json = null; try { json = JSON.parse(lines.at(-1) ?? "null"); } catch { /* no JSON last line */ }
  return { code: r.status, lines, json, stderr: r.stderr ?? "" };
}
function assertProtocol(r, cmd, exit) {
  assert.ok(r.json, `no JSON last line; stdout ended: ${JSON.stringify(r.lines.slice(-2))}, stderr: ${r.stderr.slice(-300)}`);
  assert.equal(r.json.schema, "tl.devx/1");
  if (cmd) assert.equal(r.json.cmd, cmd);
  if (exit !== undefined) assert.equal(r.code, exit);
  assert.equal(r.json.exit, r.code, "the JSON exit is the process exit");
  assert.equal(r.json.ok, r.code === 0);
}

test("printVerdict: a not_run step prints NOT RUN, the verdict exits 2 and names it", async () => {
  const { printVerdict } = await import(pathToFileURL(path.join(DEVX, "lib", "ctx.mjs")));
  const lines = []; const orig = console.log; console.log = (...a) => lines.push(a.join(" "));
  let code; try { code = printVerdict("x", [{ id: "a", ok: false, not_run: true, ms: 0, detail: "no Godot" }]); } finally { console.log = orig; }
  assert.equal(code, 2);
  assert.ok(lines[0].startsWith("NOT RUN"), lines[0]);
  const json = JSON.parse(lines.at(-1));
  assert.equal(json.exit, 2); assert.equal(json.ok, false); assert.deepEqual(json.not_run, ["a"]);
});

test("printVerdict: a fail beats a not_run (exit 1); zero steps is a fail, never a pass", async () => {
  const { printVerdict } = await import(pathToFileURL(path.join(DEVX, "lib", "ctx.mjs")));
  const orig = console.log; const out = []; console.log = (...a) => out.push(a.join(" "));
  let mixed, none, green;
  try {
    mixed = printVerdict("x", [{ id: "a", ok: false, not_run: true, ms: 0, detail: "" }, { id: "b", ok: false, ms: 0, detail: "" }]);
    none = printVerdict("x", []);
    green = printVerdict("x", [{ id: "a", ok: true, ms: 0, detail: "" }]);
  } finally { console.log = orig; }
  assert.equal(mixed, 1); assert.equal(none, 1); assert.equal(green, 0);
  assert.equal(JSON.parse(out.at(-1)).exit, 0);
});

test("tl check --tier bogus: exit 2 and a tl.devx/1 line carrying the usage", () => {
  const r = tl(["check", "--tier", "bogus"]);
  assertProtocol(r, "check", 2);
  assert.match(r.json.error, /usage: tl check/);
});

test("tl ladder --pack does/not/exist: exit 2 and a tl.devx/1 line", () => {
  const r = tl(["ladder", "--pack", "does/not/exist"]);
  assertProtocol(r, "ladder", 2);
  assert.match(r.json.error, /no pack\.json/);
});

test("tl perf compare 1 (wrong arity): exit 2 and a tl.devx/1 line; no command hand-builds the line", () => {
  assertProtocol(tl(["perf", "compare", "1"]), "perf compare", 2);
  const hand = fs.readdirSync(COMMANDS).filter((f) => /schema:\s*"tl\.devx\/1"/.test(fs.readFileSync(path.join(COMMANDS, f), "utf8")));
  assert.deepEqual(hand, [], "tl.devx/1 lines come from devx/lib/verdict.mjs only");
});

test("a command that throws still ends in a tl.devx/1 line with exit 1", () => {
  const dir = tmp("tlcli_");
  fs.writeFileSync(path.join(dir, "boom.mjs"), "export const summary = 'x';\nexport async function run() { throw new Error('kaboom'); }\n");
  const cli = pathToFileURL(path.join(DEVX, "lib", "cli.mjs")).href;
  const script = `const m = await import(${JSON.stringify(cli)}); process.exit(await m.main(["boom"], { commandsDir: ${JSON.stringify(dir)} }));`;
  const r = spawnSync(process.execPath, ["--input-type=module", "-e", script], { encoding: "utf8", timeout: 30000 });
  const json = JSON.parse(r.stdout.trim().split(/\r?\n/).at(-1));
  assert.equal(r.status, 1);
  assert.equal(json.schema, "tl.devx/1"); assert.equal(json.ok, false); assert.equal(json.exit, 1);
  assert.match(json.error, /^boom threw: .*kaboom/);
  fs.rmSync(dir, { recursive: true });
});

test("tl check --trend: exit 0 and the last line is tl.devx/1 carrying the trend rows", () => {
  const r = tl(["check", "--trend"]);
  assertProtocol(r, "check", 0);
  assert.ok(Array.isArray(r.json.trend));
});

test("tl itself: no command, an unknown command and help each end in a tl.devx/1 line", () => {
  assertProtocol(tl([]), "help", 2);
  assertProtocol(tl(["nosuch"]), "nosuch", 2);
  assertProtocol(tl(["help"]), "help", 0);
});

// One row per command file: an offline argv and the exit it must give (undefined = whatever the machine says, but said
// in the JSON line too). A new command without a row turns this red.
const ROWS = {
  arch: { args: ["--root", path.join(os.tmpdir(), "tl-no-such-root-dir")], exit: 2 },
  assets: { args: ["bogus"], exit: 2 },
  cards: { args: ["bogus"], exit: 2 },
  check: { args: ["--bogus"], exit: 2 },
  doctor: { args: [] },
  hook: { args: ["bogus"], exit: 2 },
  ladder: { args: ["--bogus"], exit: 2 },
  ledger: { args: [], env: () => ({ TL_SITE_DIR: tmp("tlsite_") }), exit: 0 },
  new: { args: [], exit: 2 },
  perf: { args: ["bogus"], exit: 2 },
  play: { args: ["no_such_pack_anywhere"], exit: 2 },
  trees: { args: ["bogus"], exit: 2 },
  watch: { args: ["--pack", "does/not/exist"], exit: 2 },
};

test("derived coverage: every command file has a protocol row", () => {
  const names = fs.readdirSync(COMMANDS).filter((f) => f.endsWith(".mjs")).map((f) => f.slice(0, -4)).sort();
  assert.deepEqual(names.filter((n) => !ROWS[n]), [], "add a row to ROWS for each new command");
});

for (const [name, row] of Object.entries(ROWS)) {
  test(`protocol row: tl ${name} ${row.args.join(" ")}`, () => assertProtocol(tl([name, ...row.args], row.env?.() ?? {}), name, row.exit));
}
