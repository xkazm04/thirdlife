// `tl trees`: list git worktrees and remove one without ever following a link out of it (docs/GATE-HONESTY.md, part 2).
// The jam's last day: a cleanup of 28 worktrees followed directory junctions inside them into the main checkout and emptied a
// 130 MB licensed plugin folder there. Here a removal unlinks every junction and symbolic link inside the tree FIRST, with a
// non-recursive call, checks each target still holds its files, and only then removes the tree; afterwards it checks that the
// kept folders of the main checkout it named hold as many files as before (or more: other sessions write there; a removal only takes).
//
// Worktrees are read from the files git keeps (<common>/worktrees/*/gitdir, HEAD): listing needs no git. Only "merged into main"
// asks git (merge-base --is-ancestor), and only when a git runner is given. Everything that touches the machine is injectable.
import fs from "node:fs";
import path from "node:path";

const norm = (p) => path.resolve(p).replace(/\\/g, "/").replace(/\/+$/, "");
const same = (a, b) => (process.platform === "win32" ? norm(a).toLowerCase() === norm(b).toLowerCase() : norm(a) === norm(b));
export const inside = (p, dir) => { const a = norm(p), d = norm(dir); const lc = process.platform === "win32"; return (lc ? a.toLowerCase() : a).startsWith((lc ? d.toLowerCase() : d) + "/"); };

/** The common git dir of the repository that holds `repo` (main checkout or any of its worktrees). null when none. */
export function commonGitDir(repo) {
  const dotgit = path.join(repo, ".git");
  let st; try { st = fs.statSync(dotgit); } catch { return null; }
  if (st.isDirectory()) return dotgit;
  const m = fs.readFileSync(dotgit, "utf8").match(/^gitdir:\s*(.+?)\s*$/m);
  if (!m) return null;
  const gitdir = path.resolve(repo, m[1]);
  try { return path.resolve(gitdir, fs.readFileSync(path.join(gitdir, "commondir"), "utf8").trim()); } catch { return gitdir; }
}

const headOf = (gitdir) => {
  try { const h = fs.readFileSync(path.join(gitdir, "HEAD"), "utf8").trim(); const m = h.match(/^ref:\s*refs\/heads\/(.+)$/); return m ? { branch: m[1] } : { detached: h.slice(0, 12) }; }
  catch { return {}; }
};

/** -> [{name, path, main, branch?, detached?, missing?, locked?}] with the main checkout first. */
export function listWorktrees(repo) {
  const common = commonGitDir(repo);
  if (!common) return [];
  const out = [];
  if (path.basename(common) === ".git") out.push({ name: path.basename(path.dirname(common)), path: norm(path.dirname(common)), main: true, ...headOf(common) });
  let ids = [];
  try { ids = fs.readdirSync(path.join(common, "worktrees")).sort(); } catch { /* no linked worktrees */ }
  for (const id of ids) {
    const admin = path.join(common, "worktrees", id);
    let gd; try { gd = fs.readFileSync(path.join(admin, "gitdir"), "utf8").trim(); } catch { continue; }
    const wt = norm(path.dirname(path.resolve(admin, gd)));
    out.push({ name: path.basename(wt), path: wt, main: false, ...headOf(admin), ...(fs.existsSync(wt) ? {} : { missing: true }), ...(fs.existsSync(path.join(admin, "locked")) ? { locked: true } : {}) });
  }
  return out;
}

/** Walks `dir` without following any link. -> {files, bytes, links:[{path, target}], unreadable}. A junction is a link here
 *  (Node's lstat reports a Windows junction as a symbolic link; the junction test in devx/test/trees.test.mjs proves it on the machine). */
export function scanTree(dir) {
  const res = { files: 0, bytes: 0, links: [], unreadable: 0 };
  const stack = [dir];
  while (stack.length) {
    const d = stack.pop();
    let ents; try { ents = fs.readdirSync(d, { withFileTypes: true }); } catch { res.unreadable++; continue; }
    for (const e of ents) {
      const p = path.join(d, e.name);
      if (e.isSymbolicLink()) { let target = "?"; try { target = fs.readlinkSync(p); } catch { /* keep "?" */ } res.links.push({ path: norm(p), target: norm(path.resolve(d, target)) }); continue; }
      if (e.isDirectory()) { stack.push(p); continue; }
      let st; try { st = fs.lstatSync(p); } catch { res.unreadable++; continue; }
      if (st.isSymbolicLink()) { let target = "?"; try { target = fs.readlinkSync(p); } catch { /* keep */ } res.links.push({ path: norm(p), target: norm(path.resolve(d, target)) }); continue; }
      if (st.isDirectory()) { stack.push(p); continue; }   // a junction some Node reports as a plain dirent: lstat decides
      res.files++; res.bytes += st.size;
    }
  }
  return res;
}
export const countFiles = (dir) => (fs.existsSync(dir) ? scanTree(dir).files : null);

/** Every running process with its exe and command line. -> [{pid, exe, cmd}]. `run` = ctx.run. */
export function listProcesses(run) {
  if (process.platform === "win32") {
    const r = run("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command",
      "Get-CimInstance Win32_Process | Select-Object ProcessId,ExecutablePath,CommandLine | ConvertTo-Json -Compress"], { timeout: 60000 });
    if (r.code !== 0) return null;
    try { const j = JSON.parse(r.stdout); return (Array.isArray(j) ? j : [j]).map((p) => ({ pid: p.ProcessId, exe: p.ExecutablePath ?? "", cmd: p.CommandLine ?? "" })); } catch { return null; }
  }
  const r = run("ps", ["-eo", "pid=,args="], { timeout: 60000 });
  if (r.code !== 0) return null;
  return r.stdout.split("\n").filter((l) => l.trim()).map((l) => { const m = l.trim().match(/^(\d+)\s+(.*)$/); return m ? { pid: Number(m[1]), exe: "", cmd: m[2] } : null; }).filter(Boolean);
}

/** The processes that run from `dir`: their exe or command line names a path inside it. (Windows does not show another process's
 *  working directory; a process sitting in the tree without naming it is caught by the in-use probe at removal.) */
export function processesIn(dir, procs, selfPid = process.pid) {
  const d = norm(dir).toLowerCase(), back = d.replace(/\//g, "\\");
  return (procs ?? []).filter((p) => p.pid !== selfPid && [p.exe, p.cmd].some((s) => { const l = String(s ?? "").toLowerCase(); return l.includes(d + "/") || l.includes(back + "\\") || l.endsWith(d) || l.endsWith(back) || l.includes(d + "\"") || l.includes(back + "\"") || l.includes(d + " ") || l.includes(back + " "); }));
}

/** merged: branch is an ancestor of mainRef. git = (args) -> {code}. -> true | false | undefined (unknown). */
export function isMerged(git, branch, mainRef = "main") {
  if (!git || !branch) return undefined;
  const r = git(["merge-base", "--is-ancestor", `refs/heads/${branch}`, mainRef]);
  return r.code === 0 ? true : r.code === 1 ? false : undefined;
}

/** The folders of the main checkout whose file counts must not change: the defaults that exist, every --keep, and every link
 *  target inside the main checkout. -> [abs posix path]. */
export function keptFolders(mainPath, keep = [], links = []) {
  const defaults = ["site", ".tl", "foreman/node_modules"].map((k) => path.join(mainPath, k));
  const fromLinks = links.map((l) => l.target).filter((t) => inside(t, mainPath));
  const all = [...defaults, ...keep.map((k) => path.resolve(mainPath, k)), ...fromLinks].filter((p) => fs.existsSync(p)).map(norm);
  return [...new Set(all)];
}

/** Removes one link (junction or symlink) without recursion. -> null or the error. */
export function unlinkOnly(p) {
  try { fs.unlinkSync(p); return null; } catch (e1) {
    try { fs.rmdirSync(p); return null; }            // a directory junction/symlink on Windows: rmdir drops the reparse point only
    catch (e2) { return `${e1.code ?? e1.message} / ${e2.code ?? e2.message}`; }
  }
}
const gone = (p) => { try { fs.lstatSync(p); return false; } catch (e) { return e.code === "ENOENT"; } };

/** Windows refuses to rename a directory some process sits in or holds a file of: rename the tree aside and back. -> null or why. */
export function inUseProbe(dir) {
  const aside = `${dir}.tl-trees-probe`;
  try { fs.renameSync(dir, aside); } catch (e) { return `cannot rename the tree aside (${e.code ?? e.message}): something holds it open`; }
  try { fs.renameSync(aside, dir); return null; } catch (e) { return `RENAMED TO ${aside} AND COULD NOT RENAME BACK (${e.code ?? e.message}): rename it back by hand`; }
}

/** The plan and, unless dryRun, the removal. deps = {repo, git (args)->{code,stdout,stderr}, procs:[...], keep:[...]}.
 *  -> {ok, steps:[{id, ok, detail}], plan:{...}}. Every check is a step line; the first failing one stops the removal. */
export function removeTree(name, { repo, git, procs, keep = [], dryRun = true, probe = inUseProbe } = {}) {
  const steps = [];
  const say = (id, ok, detail) => { steps.push({ id, ok, detail }); return ok; };
  const trees = listWorktrees(repo);
  const t = trees.find((w) => !w.main && (w.name === name || same(w.path, name)));
  const main = trees.find((w) => w.main);
  if (!t) { say("find", false, `no linked worktree named '${name}' (have: ${trees.filter((w) => !w.main).map((w) => w.name).join(", ") || "none"})`); return { ok: false, steps }; }
  if (!main) { say("find", false, "no main checkout found for this repository"); return { ok: false, steps }; }
  say("find", true, `${t.name} at ${t.path} (branch ${t.branch ?? t.detached ?? "?"}); main checkout ${main.path}`);
  if (t.missing) { say("exists", false, `the tree's folder is gone; \`git worktree prune\` clears its record`); return { ok: false, steps }; }
  if (procs == null) { say("processes", false, "could not list processes: refusing (a running process may sit in the tree)"); return { ok: false, steps }; }
  const running = processesIn(t.path, procs);
  if (!say("processes", running.length === 0, running.length ? `refused: ${running.length} process(es) run from it: ${running.slice(0, 5).map((p) => `${p.pid} ${String(p.exe || p.cmd).slice(0, 80)}`).join(" | ")}` : "no process runs from it")) return { ok: false, steps };
  const scan = scanTree(t.path);
  const links = scan.links.map((l) => ({ ...l, files: countFiles(l.target) }));
  const kept = keptFolders(main.path, keep, links).map((k) => ({ path: k, files: countFiles(k) }));
  const plan = { tree: t.path, files: scan.files, bytes: scan.bytes, links, kept };
  say("plan", true, `${scan.files} files, ${(scan.bytes / 1e6).toFixed(1)} MB; ${links.length} link(s) to unlink first${links.length ? ": " + links.map((l) => `${l.path} -> ${l.target} (${l.files ?? "missing"} files)`).join(" | ") : ""}; kept folders watched: ${kept.map((k) => `${k.path} (${k.files})`).join(", ") || "none"}`);
  if (dryRun) { say("dry-run", true, "nothing removed (dry run). Add --apply to remove."); return { ok: true, steps, plan }; }
  const busy = probe(t.path);
  if (!say("in-use probe", !busy, busy ?? "the tree's folder can be renamed: nothing holds it open")) return { ok: false, steps, plan };
  for (const l of links) {
    const err = unlinkOnly(l.path);
    const after = countFiles(l.target);
    const okL = !err && gone(l.path) && (l.files === null || (after !== null && after >= l.files));   // a dangling link has no target to keep
    if (!say(`unlink ${path.basename(l.path)}`, okL, okL ? `unlinked (non-recursive); target ${l.target} still has ${after} files` : `${err ?? (gone(l.path) ? "" : "link still there")}; target files before ${l.files}, now ${after}: STOPPED, nothing else removed`)) return { ok: false, steps, plan };
  }
  const again = scanTree(t.path).links;
  if (!say("no links left", again.length === 0, again.length ? `${again.length} link(s) appeared: ${again.map((l) => l.path).join(", ")}: STOPPED` : "the tree holds no link")) return { ok: false, steps, plan };
  const r = git(["worktree", "remove", "--force", t.path]);
  if (!say("git worktree remove", r.code === 0 && !fs.existsSync(t.path), r.code === 0 ? (fs.existsSync(t.path) ? "git said ok but the folder is still there" : "removed") : `git exited ${r.code}: ${String(r.stderr).trim().slice(0, 200)}`)) return { ok: false, steps, plan };
  for (const l of links.filter((x) => x.files !== null)) say(`target ${path.basename(l.target)}`, (countFiles(l.target) ?? -1) >= l.files, `${l.target}: ${countFiles(l.target)} files after, ${l.files} before`);
  for (const k of kept) say(`kept ${path.basename(k.path)}`, (countFiles(k.path) ?? -1) >= k.files, `${k.path}: ${countFiles(k.path)} files after, ${k.files} before`);
  return { ok: steps.every((s) => s.ok), steps, plan };
}
