// `tl trees`: the git worktrees of this repository, and a removal that cannot follow a link (devx/lib/trees/core.mjs).
//   tl trees list [--no-git] [--main <ref>]     every worktree: size, branch, merged into main?, processes running from it,
//                                              every junction / symbolic link inside it with its target (--no-git: merged not asked)
//   tl trees remove <name> [--dry-run|--apply] [--keep <dir>]...
//                                              DRY RUN BY DEFAULT: prints the plan. --apply removes: refuses when a process runs
//                                              from the tree, unlinks every link inside first (non-recursive) and checks each
//                                              target kept its files, then `git worktree remove --force`, then checks the main
//                                              checkout's kept folders (site, .tl, foreman/node_modules, every --keep, every link
//                                              target inside it) did not lose files.
import * as realCtx from "../ctx.mjs";
import { isMerged, listProcesses, listWorktrees, processesIn, removeTree, scanTree } from "../trees/core.mjs";

export const summary = "git worktrees: list (size, branch, merged, processes, links inside) | remove <name> (dry run unless --apply; unlinks links first)";
const USAGE = "usage: tl trees list [--no-git] [--main <ref>] | tl trees remove <name> [--dry-run|--apply] [--keep <dir>]...";

/** git runner for the repository, GIT_DIR and friends unset so it asks the repo `cwd` belongs to. */
export const gitIn = (ctx, cwd) => (args) => ctx.run("git", args, { cwd, env: { GIT_DIR: undefined, GIT_WORK_TREE: undefined, GIT_INDEX_FILE: undefined } });

export function parse(args) {
  const [verb, ...rest] = args;
  const o = { verb, name: null, noGit: false, main: "main", apply: false, keep: [] };
  for (let i = 0; i < rest.length; i++) {
    const a = rest[i];
    if (a === "--no-git") o.noGit = true;
    else if (a === "--main") o.main = rest[++i];
    else if (a === "--apply") o.apply = true;
    else if (a === "--dry-run") o.apply = false;
    else if (a === "--keep") o.keep.push(rest[++i]);
    else if (a.startsWith("--keep=")) o.keep.push(a.slice(7));
    else if (!a.startsWith("--") && verb === "remove" && !o.name) o.name = a;
    else throw new Error(`unknown argument ${a}`);
  }
  if (verb !== "list" && verb !== "remove") throw new Error(`unknown verb '${verb ?? ""}'`);
  if (verb === "remove" && !o.name) throw new Error("remove needs a worktree name");
  if (o.keep.some((k) => !k) || !o.main) throw new Error("--keep and --main need a value");
  return o;
}

/** deps = {ctx, repo, procs, git}: omitted -> the real ones. Returns the exit code. */
export async function execute(args, deps = {}) {
  const ctx = deps.ctx ?? realCtx;
  const repo = deps.repo ?? ctx.REPO;
  let o; try { o = parse(args); } catch (e) { console.error(`tl trees: ${e.message}\n${USAGE}`); return 2; }
  const trees = listWorktrees(repo);
  if (!trees.length) { console.error(`tl trees: ${repo} is not inside a git repository`); return 2; }
  const main = trees.find((t) => t.main);
  const git = deps.git ?? (o.noGit && o.verb === "list" ? null : gitIn(ctx, main?.path ?? repo));
  const procs = deps.procs !== undefined ? deps.procs : listProcesses(ctx.run);
  if (o.verb === "list") {
    const rows = [];
    for (const t of trees) {
      const scan = t.main || t.missing ? null : scanTree(t.path);
      const merged = t.main ? undefined : isMerged(git, t.branch, o.main);
      const running = procs ? processesIn(t.path, procs).length : undefined;
      rows.push({ name: t.name, path: t.path, main: t.main, ...(t.branch ? { branch: t.branch } : {}), ...(t.detached ? { detached: t.detached } : {}),
        ...(t.missing ? { missing: true } : {}), ...(merged !== undefined ? { merged } : {}), ...(running !== undefined ? { processes: running } : {}),
        ...(scan ? { files: scan.files, mb: Math.round(scan.bytes / 1e5) / 10, links: scan.links } : {}) });
    }
    const steps = rows.map((r) => ctx.step(r.name, true, 0,
      r.main ? `MAIN CHECKOUT ${r.path} (${r.branch ?? r.detached ?? "?"}; not scanned)`
        : `${r.missing ? "MISSING " : ""}${r.path} | ${r.branch ?? "detached " + (r.detached ?? "?")} | merged into ${o.main}: ${r.merged === undefined ? (o.noGit ? "not asked (--no-git)" : "unknown") : r.merged ? "yes" : "no"} | ${r.mb ?? "?"} MB, ${r.files ?? "?"} files | processes: ${r.processes ?? "could not list"} | links: ${(r.links ?? []).length ? r.links.map((l) => `${l.path} -> ${l.target}`).join(" ; ") : "none"}`));
    return ctx.printVerdict("trees", steps, { trees: rows });
  }
  const res = removeTree(o.name, { repo, git, procs, keep: o.keep, dryRun: !o.apply });
  if (!o.apply) console.log("# tl trees remove is a dry run unless --apply is given (and stays so by default: devx/test/trees.test.mjs proves the junction case on this machine)");
  return ctx.printVerdict("trees", res.steps.map((s) => ctx.step(s.id, s.ok, 0, s.detail)), { apply: o.apply, ...(res.plan ? { plan: res.plan } : {}) });
}

export async function run(args, ctx) { return execute(args, { ctx }); }
