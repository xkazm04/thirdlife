// `tl ledger [--json]`: read-only cost/outcome ledger of Foreman jobs, derived from each job's job.jsonl (contracts/JOB.md).
// Field sources (every figure is read from events, nothing is estimated; an unreadable field prints "-"):
//   outcome   last `job_state` event's state                        wall      last event ts - `job_created` ts
//   run       last event ts - first `job_state` running ts (the job log's own "started"); job 1 of the marble record used this, job 2 used wall
//   packages  distinct `package_state`.package                      rounds    sum over packages of the highest `package_state`.round
//   tokens    sums of `builder_run`.tokensIn / tokensOut / tokensCacheRead (tokensIn INCLUDES the cache-read part)
//   weighted  (in - cacheRead) + 0.1 * cacheRead + out, the JOB.md budget weighting; "-" unless in, out and cacheRead are all known
//   replans   count of `replan` events                              critic    count of `package_state` queued events whose detail starts "critic"
//   edit      count of `builder_run` with mode "edit"
import fs from "node:fs";
import path from "node:path";
import { REPO, run } from "../ctx.mjs";

export const summary = "cost/outcome ledger of Foreman jobs (read-only) [--json]";

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
  if (!siteRoot) { console.error("tl ledger: no site directory (set TL_SITE_DIR, or run in a checkout with site/)"); return 2; }
  const led = readLedger(siteRoot);
  if (args.includes("--json")) { console.log(JSON.stringify({ schema: "tl.ledger/1", site: siteRoot.split(path.sep).join("/"), ...led })); return 0; }
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
  return 0;
}
export { run_ as run };
