// `tl ledger [--json]`: read-only cost/outcome ledger of Foreman jobs, derived from each job's job.jsonl (contracts/JOB.md).
// Field sources (every figure is read from events, nothing is estimated; an unreadable field prints "-"):
//   outcome   last `job_state` event's state                        wall      last event ts - `job_created` ts
//   run       last event ts - first `job_state` running ts (the job log's own "started"); job 1 of the marble record used this, job 2 used wall
//   packages  distinct `package_state`.package                      rounds    sum over packages of the highest `package_state`.round
//   tokens    sums of `builder_run`.tokensIn / tokensOut / tokensCacheRead (tokensIn INCLUDES the cache-read part)
//   weighted  (in - cacheRead) + 0.1 * cacheRead + out, the JOB.md budget weighting; "-" unless in, out and cacheRead are all known
//   replans   count of `replan` events                              critic    count of `package_state` queued events whose detail starts "critic"
//   edit      count of `builder_run` with mode "edit"
// M4 (spark world-sandbox): the Home's LLM command bar calls the model outside any job; the exe logs each call to
// <home>/llm_calls.jsonl (engine/kernel/world/build/command_calls.gd: one line per event, the LAST line of an id is
// the call). `--home <dir>` names the folder; else TL_HOME_BUILD_DIR, then the exported exe's user folder
// %APPDATA%/ThirdLife/home, then the editor binary's %APPDATA%/Godot/app_userdata/Third Life Engine/home. The calls are
// listed after the jobs (sentence, model, tokens, duration, ops, kept), with their totals; --json adds "home" and "calls".
import fs from "node:fs";
import path from "node:path";
import { REPO, run } from "../ctx.mjs";
import { couldNotRun } from "../verdict.mjs";

export const summary = "cost/outcome ledger of Foreman jobs and the Home's LLM calls (read-only) [--json] [--home <dir>]";

/** The Home folders whose llm_calls.jsonl the ledger reads, the first that has one (or null). */
export function findHome(env = process.env, flag = undefined) {
  const app = env.APPDATA ?? "";
  const cands = flag ? [flag] : [env.TL_HOME_BUILD_DIR, app && path.join(app, "ThirdLife", "home"), app && path.join(app, "Godot", "app_userdata", "Third Life Engine", "home")];
  for (const c of cands.filter(Boolean)) if (fs.existsSync(path.join(c, "llm_calls.jsonl"))) return path.resolve(c);
  return null;
}

/** The calls of one llm_calls.jsonl: the last line of each id, in the order first seen, and their totals. */
export function readCalls(file) {
  const by = new Map();
  for (const l of fs.readFileSync(file, "utf8").split("\n")) {
    if (!l.trim()) continue;
    let c;
    try { c = JSON.parse(l); } catch { continue; }
    if (c && typeof c.id === "string") by.set(c.id, c);
  }
  const calls = [...by.values()];
  const sum = (k) => { const xs = calls.filter((c) => Number.isFinite(c[k])); return xs.length ? xs.reduce((a, c) => a + c[k], 0) : null; };
  return { calls, totals: { calls: calls.length, kept: calls.filter((c) => c.accepted === true).length,
    reverted: calls.filter((c) => c.accepted === false && c.error === undefined).length, failed: calls.filter((c) => c.error !== undefined).length,
    pending: calls.filter((c) => c.accepted === "pending").length, tokensIn: sum("tokensIn"), tokensOut: sum("tokensOut"), durationMs: sum("durationMs") } };
}

export function findSiteRoot(env = process.env, repo = REPO) {
  const cands = [];
  if (env.TL_SITE_DIR) cands.push(env.TL_SITE_DIR);
  cands.push(path.join(repo, "site"));
  const g = run("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd: repo });
  if (g.code === 0 && g.stdout.trim()) cands.push(path.join(path.dirname(g.stdout.trim()), "site"));
  for (const c of cands) if (fs.existsSync(c) && fs.statSync(c).isDirectory()) return path.resolve(c);
  return null;
}

/** Reads one job.jsonl into a ledger row. Missing figures are null. */
export function readJob(file) {
  const events = [];
  let broken = null;
  const lines = fs.readFileSync(file, "utf8").split("\n");
  lines.forEach((l, i) => {
    if (!l.trim()) return;
    try { events.push(JSON.parse(l)); } catch { if (i < lines.length - 1 && lines.slice(i + 1).some((x) => x.trim())) broken ??= `line ${i + 1} is not JSON`; }
  });
  const of = (t) => events.filter((e) => e.type === t);
  const sum = (key) => {
    const xs = of("builder_run").filter((e) => Number.isFinite(e[key]));
    return xs.length ? xs.reduce((a, e) => a + e[key], 0) : null;
  };
  const created = of("job_created")[0];
  const last = events.at(-1);
  const started = of("job_state").find((e) => e.state === "running");
  const states = of("job_state");
  const rounds = new Map();
  for (const e of of("package_state")) rounds.set(e.package, Math.max(rounds.get(e.package) ?? 0, e.round ?? 0));
  const tin = sum("tokensIn"), tout = sum("tokensOut"), tcache = sum("tokensCacheRead");
  return {
    id: path.basename(path.dirname(file)),
    outcome: states.at(-1)?.state ?? null,
    wallMs: created && last ? Date.parse(last.ts) - Date.parse(created.ts) : null,
    runMs: started && last ? Date.parse(last.ts) - Date.parse(started.ts) : null,
    packages: rounds.size || null,
    rounds: rounds.size ? [...rounds.values()].reduce((a, b) => a + b, 0) : null,
    tokensIn: tin, tokensOut: tout, tokensCacheRead: tcache,
    weighted: tin !== null && tout !== null && tcache !== null ? Math.round(tin - tcache + 0.1 * tcache + tout) : null,
    replans: events.length ? of("replan").length : null,
    critic: events.length ? of("package_state").filter((e) => e.state === "queued" && String(e.detail ?? "").startsWith("critic")).length : null,
    editRuns: of("builder_run").length ? of("builder_run").filter((e) => e.mode === "edit").length : null,
    events: events.length,
    ...(broken ? { problem: broken } : {}),
  };
}

export function readLedger(siteRoot) {
  const jobs = [];
  for (const d of fs.readdirSync(siteRoot, { withFileTypes: true }).filter((x) => x.isDirectory() && !x.name.startsWith("_")).sort((a, b) => (a.name < b.name ? -1 : 1))) {
    const f = path.join(siteRoot, d.name, "job.jsonl");
    if (fs.existsSync(f)) jobs.push(readJob(f));
  }
  const tot = {};
  for (const k of ["wallMs", "runMs", "packages", "rounds", "tokensIn", "tokensOut", "tokensCacheRead", "weighted", "replans", "critic", "editRuns"]) {
    const known = jobs.filter((j) => j[k] !== null);
    tot[k] = known.length ? known.reduce((a, j) => a + j[k], 0) : null;
    if (known.length && known.length < jobs.length) tot[`${k}_jobs`] = known.length;
  }
  return { jobs, totals: tot };
}

const dash = (v, f = String) => (v === null || v === undefined ? "-" : f(v));
const dur = (ms) => `${Math.floor(ms / 60000)}m${String(Math.floor(ms / 1000) % 60).padStart(2, "0")}s`;
const num = (n) => n.toLocaleString("en-US");

export async function run_(args) {
  const siteRoot = findSiteRoot();
  const hi = args.indexOf("--home");
  const home = findHome(process.env, hi >= 0 ? args[hi + 1] : undefined);
  if (hi >= 0 && !home) return couldNotRun("ledger", `tl ledger: no llm_calls.jsonl in ${args[hi + 1] ?? "(no folder given)"}`);
  if (!siteRoot && !home) return couldNotRun("ledger", "tl ledger: no site directory (set TL_SITE_DIR, or run in a checkout with site/) and no Home calls log");
  const calls = home ? readCalls(path.join(home, "llm_calls.jsonl")) : null;
  if (!siteRoot) return printCalls(home, calls, args.includes("--json"), true);
  const led = readLedger(siteRoot);
  if (args.includes("--json")) {
    console.log(JSON.stringify({ schema: "tl.ledger/1", site: siteRoot.split(path.sep).join("/"), ...led, ...(home ? { home: home.split(path.sep).join("/"), calls } : {}) }));
    return 0;
  }
  const cols = [["job", 36, "l"], ["outcome", 8, "l"], ["wall", 7], ["run", 7], ["pkgs", 4], ["rounds", 6], ["edit", 4], ["in", 11], ["out", 9], ["cacheRd", 11], ["weighted", 9], ["replan", 6], ["critic", 6]];
  const fmt = (cells) => cells.map((c, i) => (cols[i][2] === "l" ? String(c).padEnd(cols[i][1]) : String(c).padStart(cols[i][1]))).join("  ");
  console.log(`site: ${siteRoot.split(path.sep).join("/")}`);
  console.log(fmt(cols.map((c) => c[0])));
  const row = (j) => fmt([j.id, dash(j.outcome), dash(j.wallMs, dur), dash(j.runMs, dur), dash(j.packages), dash(j.rounds), dash(j.editRuns), dash(j.tokensIn, num), dash(j.tokensOut, num), dash(j.tokensCacheRead, num), dash(j.weighted, num), dash(j.replans), dash(j.critic)]);
  for (const j of led.jobs) console.log(row(j) + (j.problem ? `   (${j.problem})` : ""));
  const t = led.totals;
  console.log(fmt(["total (" + led.jobs.length + " jobs)", "", dash(t.wallMs, dur), dash(t.runMs, dur), dash(t.packages), dash(t.rounds), dash(t.editRuns), dash(t.tokensIn, num), dash(t.tokensOut, num), dash(t.tokensCacheRead, num), dash(t.weighted, num), dash(t.replans), dash(t.critic)]));
  const partial = Object.keys(t).filter((k) => k.endsWith("_jobs")).map((k) => `${k.replace("_jobs", "")} from ${t[k]} jobs`);
  if (partial.length) console.log(`note: totals use only the jobs that report the field: ${partial.join(", ")}`);
  if (home) printCalls(home, calls, false, false);
  return 0;
}

/** The Home's LLM calls as a table (or the JSON line when there is no site to print it with). */
function printCalls(home, calls, json, alone) {
  const where = home.split(path.sep).join("/");
  if (json) { console.log(JSON.stringify({ schema: "tl.ledger/1", home: where, calls })); return 0; }
  const cols = [["call", 28, "l"], ["kept", 7, "l"], ["model", 16, "l"], ["dur", 7], ["in", 9], ["out", 8], ["ops", 5], ["refused", 7], ["sentence", 40, "l"]];
  const fmt = (cells) => cells.map((c, i) => (cols[i][2] === "l" ? String(c).padEnd(cols[i][1]) : String(c).padStart(cols[i][1]))).join("  ");
  console.log(`${alone ? "" : "\n"}home calls: ${where}/llm_calls.jsonl`);
  console.log(fmt(cols.map((c) => c[0])));
  for (const c of calls.calls) {
    const kept = c.error !== undefined ? "error" : c.accepted === "pending" ? "pending" : c.accepted ? "kept" : "revert";
    console.log(fmt([c.id, kept, dash(c.model), dash(c.durationMs, dur), dash(c.tokensIn, num), dash(c.tokensOut, num), dash(c.ops), dash(c.refused), String(c.sentence ?? "").slice(0, 40)]) + (c.error ? `   (${String(c.error).slice(0, 80)})` : ""));
  }
  const t = calls.totals;
  console.log(fmt([`total (${t.calls} calls)`, `${t.kept} kept`, `${t.reverted} rev, ${t.failed} err`, dash(t.durationMs, dur), dash(t.tokensIn, num), dash(t.tokensOut, num), "", "", t.pending ? `${t.pending} pending` : ""]));
  return 0;
}
export { run_ as run };
