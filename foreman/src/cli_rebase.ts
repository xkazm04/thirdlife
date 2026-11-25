// H2 of 25 Nov: `foreman rebase`: a finished game on a core moves to the newest base (rebase.ts says what moves and what
// stays). For a job: verified as a final verification is (lint, smoke, every bot of the manifest), then promoted beside
// the earlier versions; a failure leaves the game as it was. For a bare pack (--pack): written to --out and verified.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import type { PackageSpec, Registers, Verb } from "./events.js";
import type { JobState } from "./joblog.js";
import { JobLog } from "./joblog.js";
import { restsOnAClock } from "./machine.js";
import { PACK_VERSION } from "./manifest.js";
import { promotePack, readManifest } from "./promoter.js";
import { RINK_ROUTE, baseEngineDir, baseRefDir, baseRegisters, hasBase } from "./coreroute.js";
import { coreRouteOf } from "./templates.js";
import { FOREMAN_NOTE } from "./conduct.js";
import { WHAT_CHANGED } from "./fastchange.js";
import { REPO_ROOT, toPosix } from "./paths.js";
import { knownBase, nothingToMove, planRebase, rebaseSummary, swapDir, writeRebase, type RebasePlan } from "./rebase.js";
import { UsageError, str, type Args } from "./cli_args.js";
import type { Verifier, VerifyResult } from "./verifier.js";

export const REBASE_HELP = `  rebase <job> [--runner fake] [--engine-dir DIR]
        a finished game on a core moves to the newest base (engine/templates/<base>/): the base's files are copied
        again, the game's own are kept byte for byte (its cartridge, rules, skin, match, its own files, data it
        changed); a script or test the game changed is a conflict and refuses the move. The result is verified (lint,
        smoke, every bot of the manifest; a bot that fails is run on the game as it was, and one that fails there too is
        kept as it was and named) and promoted beside the earlier versions (promoted/<pack id>@<version>/); a check the
        move broke leaves the game as it was. Refused while a Foreman runs the job.
  rebase --pack <dir> --out <dir> [--base DIR] [--no-verify] [--runner fake]
        the same for a pack that is not a job (a promoted copy): written to --out and verified there`;

const rel = (from: string, abs: string): string => toPosix(path.relative(from, abs));

/**
 * lint, smoke, then every bot of the manifest; a clock-based failure is run once more (JOB.md). A check that fails is run on
 * the game as it was (`before`): when it fails there too, the move did not cause it (the game's own failure, kept as it was,
 * and named), and the verification goes on; only a check the move broke stops it.
 */
async function verifyAll(verifier: Verifier, packDir: string, reportDir: string, say: (r: VerifyResult, name: string) => void, before?: string): Promise<{ ok: boolean; failed?: VerifyResult; n: number; asBefore: string[] }> {
  let tests: string[] = [];
  try {
    tests = readManifest(packDir).tests;
  } catch {
    /* lint says why */
  }
  const runs: { verb: Verb; args: string[]; name: string }[] = [
    { verb: "lint", args: [], name: "lint" },
    { verb: "smoke", args: [], name: "smoke" },
    ...tests.map((t) => ({ verb: "bot" as Verb, args: [`--test=${t}`], name: `bot-${path.basename(t, ".gd")}` })),
  ];
  fs.mkdirSync(reportDir, { recursive: true });
  const asBefore: string[] = [];
  for (const r of runs) {
    let v = await verifier.run({ verb: r.verb, args: r.args, packDir, reportFile: path.join(reportDir, `${r.name}.json`) });
    if (!v.ok && restsOnAClock(v)) v = await verifier.run({ verb: r.verb, args: r.args, packDir, reportFile: path.join(reportDir, `${r.name}-again.json`) });
    say(v, r.name);
    if (!v.ok && before !== undefined && r.verb === "bot") {
      const was = await verifier.run({ verb: r.verb, args: r.args, packDir: before, reportFile: path.join(reportDir, `${r.name}-before.json`) });
      if (!was.ok) {
        asBefore.push(`${r.name} (fails on the game as it was too: ${was.summary.slice(0, 160)})`);
        continue;
      }
    }
    if (!v.ok) return { ok: false, failed: v, n: runs.length, asBefore };
  }
  return { ok: true, n: runs.length, asBefore };
}

function printPlan(plan: RebasePlan, out: (s: string) => void): void {
  out(`replaced  ${plan.replaced.length}  ${plan.replaced.join(", ")}`);
  out(`added     ${plan.added.length}  ${plan.added.join(", ")}`);
  out(`removed   ${plan.removed.length}  ${plan.removed.join(", ")}`);
  out(`current   ${plan.same.length}`);
  out(`kept      ${plan.kept.length}  ${plan.kept.join(", ")}`);
  if (plan.cartridge !== undefined) out(`cartridge ${plan.cartridge} (kept byte for byte)`);
  if (plan.edited.length > 0) out(`edited    ${plan.edited.length}  ${plan.edited.join(", ")}: the game's own changes, kept (the newest base did not change these files)`);
  for (const c of plan.conflicts) out(`CONFLICT  ${c}: both changed it: ${plan.why[c] ?? ""}; moving would lose one side`);
  out(`manifest  version ${String(plan.manifest["version"])}, tests ${(plan.manifest["tests"] as string[] | undefined)?.join(", ") ?? "none"}`);
}

/**
 * H2b: the plan follows the base. A job's pack.json is composed again from the plan's registers on its next merge (a change);
 * the base package's registers were the base's of the day the job was planned, so a moved game lost the newest base's bots
 * (tests/bot_toys.gd) at its next change. The base package's registers become the newest base's (its tests first) united with
 * what the plan had. Returns the plan_set to write, or undefined when nothing changes.
 */
export function planAfterRebase(s: JobState, baseDir: string, present: (rel: string) => boolean): { packages: PackageSpec[]; card?: string; phases?: { id: string; title: string; try: string; packages: string[] }[] } | undefined {
  const i = s.plan.findIndex((p) => p.kind === "base");
  if (i < 0) return undefined;
  const old: Registers = s.plan[i]?.registers ?? {};
  const nb = baseRegisters(baseDir);
  const merged: Registers = {};
  for (const k of ["capabilities", "assets", "tests", "cameras"] as const) {
    const v = [...new Set([...(nb[k] ?? []), ...(old[k] ?? [])])].filter((x) => k === "capabilities" || k === "cameras" || present(x));
    if (v.length > 0) merged[k] = v;
  }
  if (JSON.stringify(merged) === JSON.stringify(old)) return undefined;
  const packages = s.plan.map((p, j) => (j === i ? { ...p, registers: merged } : p));
  return { packages, ...(s.card !== undefined ? { card: s.card } : {}), ...(s.phases.length > 0 ? { phases: s.phases.map((ph) => ({ id: ph.id, title: ph.title, try: ph.try, packages: [...ph.packages] })) } : {}) };
}

export async function rebaseCommand(a: Args, verifier: Verifier, jobDir: string | undefined, out: (s: string) => void): Promise<number> {
  const engineDir = verifier.location.engineDir;
  if (jobDir === undefined) {
    const packDir = str(a, "pack");
    const outDir = str(a, "out");
    if (packDir === undefined || outDir === undefined) throw new UsageError("usage: foreman rebase <job> | foreman rebase --pack <dir> --out <dir> [--base DIR]");
    if (!fs.existsSync(path.join(packDir, "pack.json"))) throw new UsageError(`no pack.json in ${packDir}`);
    const baseDir = path.resolve(str(a, "base") ?? baseEngineDir(engineDir, RINK_ROUTE));
    if (!hasBase(baseDir)) throw new UsageError(`no base at ${baseDir}`);
    if (path.resolve(outDir) === path.resolve(packDir)) throw new UsageError("--out must not be the pack itself (the game is never changed in place)");
    const k = knownBase(rel(REPO_ROOT, baseDir));
    out(`base      ${toPosix(baseDir)}  (older versions from: ${k.sources.join("; ")})`);
    const plan = planRebase(path.resolve(packDir), baseDir, k.known);
    printPlan(plan, out);
    if (plan.conflicts.length > 0) return 1;
    writeRebase(path.resolve(packDir), baseDir, plan, path.resolve(outDir));
    out(`written   ${toPosix(path.resolve(outDir))}: ${rebaseSummary(plan, rel(REPO_ROOT, baseDir))}`);
    if (a.flags["no-verify"] === true) return 0;
    const reports = path.resolve(str(a, "reports") ?? fs.mkdtempSync(path.join(os.tmpdir(), "tl-foreman-rebase-")));
    const v = await verifyAll(verifier, path.resolve(outDir), reports, (r, name) => out(`${name.padEnd(10)} ${r.level}  ${r.ok ? "ok    " : "FAILED"}  ${r.durationMs}ms  ${r.summary}  [${toPosix(r.reportFile)}]`), path.resolve(packDir));
    for (const b of v.asBefore) out(`as before ${b}`);
    out(v.ok ? `PASS  rebase: verified (${v.n} checks${v.asBefore.length > 0 ? `; ${v.asBefore.length} failed as on the game before the move` : ""})` : `FAIL  rebase: ${v.failed?.verb ?? "?"} failed (it passes on the game as it was: the move broke it)`);
    return v.ok ? 0 : 1;
  }

  // ---- a job ----
  const log = JobLog.open(jobDir);
  try {
    const s = log.state;
    const route = coreRouteOf(s.brief?.concept?.template);
    if (route === undefined) throw new UsageError("this game is not on a core: it has no base to move to");
    if (s.promoted === undefined) throw new UsageError("this game has no promotion yet: finish it first");
    if (s.jobState?.state !== "done") throw new UsageError(`the job is ${s.jobState?.state ?? "not started"}: a game moves to the newest base when it is done`);
    const baseDir = baseEngineDir(engineDir, route);
    if (!hasBase(baseDir)) throw new UsageError(`no base at ${toPosix(baseDir)}`);
    const from = s.promoted.dest.startsWith("promoted/") ? path.join(jobDir, ...s.promoted.dest.split("/")) : path.join(engineDir, ...s.promoted.dest.split("/"));
    if (!fs.existsSync(path.join(from, "pack.json"))) throw new UsageError(`the last promotion ${s.promoted.dest} is not there`);
    const owner = s.plan.find((p) => p.kind === "base")?.id ?? (s.order[0] as string);
    const round = s.packages[owner]?.round ?? 1;
    const refBase = baseRefDir(path.join(jobDir, "ref"), route);
    const k = knownBase(rel(REPO_ROOT, baseDir), [refBase]);
    const version = PACK_VERSION.replace(/\d+$/, String(s.promotions.length));
    out(`game      ${s.promoted.packId} ${s.promoted.version} (${s.promoted.dest})`);
    out(`base      ${toPosix(baseDir)}  (older versions from: ${k.sources.join("; ")})`);
    const plan = planRebase(from, baseDir, k.known, version, fs.existsSync(path.join(refBase, "pack.json")) ? refBase : undefined);
    printPlan(plan, out);
    if (plan.conflicts.length > 0) {
      log.append({ type: "note", package: owner, round, text: `${FOREMAN_NOTE}the move to the newest base was refused: both the game and the newer base changed ${plan.conflicts.map((c) => `${c} (${plan.why[c] ?? ""})`).join("; ")}; moving would lose one side; the game plays as before` });
      return 1;
    }
    if (nothingToMove(plan)) {
      out("current   the game is on the newest base already: nothing to do");
      return 0;
    }
    const cand = path.join(jobDir, "rebase", "pack");
    writeRebase(from, baseDir, plan, cand);
    const summary = rebaseSummary(plan, rel(REPO_ROOT, baseDir));
    log.append({ type: "job_state", state: "running", reason: `moving to the newest base (${rel(REPO_ROOT, baseDir)}), then the whole verification` });
    const reports = path.join(jobDir, "reports", `rebase-s${log.state.lastSeq + 1}`);
    const v = await verifyAll(verifier, cand, reports, (r, name) => {
      log.append({ type: "verify", round: 1, level: r.level, verb: r.verb, ok: r.ok, report: rel(jobDir, r.reportFile), ...(r.exitCode !== undefined ? { exitCode: r.exitCode } : {}), after: owner });
      out(`${name.padEnd(10)} ${r.level}  ${r.ok ? "ok    " : "FAILED"}  ${r.durationMs}ms  ${r.summary}`);
    }, from);
    if (!v.ok) {
      const why = `the move to the newest base was NOT made: ${v.failed?.verb ?? "?"} failed (${v.failed?.level ?? "?"}; it passes on the game as it was): ${(v.failed?.summary ?? "").slice(0, 400)}. The game plays as before (${s.promoted.packId} ${s.promoted.version}, ${s.promoted.dest}).`;
      log.append({ type: "note", package: owner, round, text: `${FOREMAN_NOTE}${why}` });
      log.append({ type: "job_state", state: "done", reason: why.slice(0, 900) });
      out(`FAIL  rebase: ${why}`);
      return 1;
    }
    const replanned = planAfterRebase(s, baseDir, (rel) => fs.existsSync(path.join(cand, ...rel.split("/"))));
    swapDir(cand, path.join(jobDir, "pack"));
    if (fs.existsSync(path.join(jobDir, "ref"))) swapDir(baseDir, refBase); // the job's reference copy of the base follows (later rounds start from it)
    fs.rmSync(path.join(jobDir, "rebase"), { recursive: true, force: true });
    if (replanned !== undefined) log.append({ type: "plan_set", ...replanned }); // H2b: the base package's registers follow the base
    log.append({ type: "merge", package: owner, files: [...plan.replaced, ...plan.added, "pack.json"].sort(), ...(plan.removed.length > 0 ? { removed: plan.removed } : {}) });
    log.append({ type: "note", package: owner, round, text: `${FOREMAN_NOTE}${WHAT_CHANGED} in v${version} (since v${s.promoted.version}): ${summary}`.slice(0, 1000) });
    if (v.asBefore.length > 0) log.append({ type: "note", package: owner, round, text: `${FOREMAN_NOTE}the move to the newest base kept these failures as they were (each fails on v${s.promoted.version} too): ${v.asBefore.join("; ")}`.slice(0, 1000) });
    const pr = promotePack(path.join(jobDir, "pack"), jobDir, s.packId, "promoted", `${s.packId ?? "pack"}@${version}`);
    log.append({ type: "promoted", packId: pr.packId, version: pr.version, dest: pr.dest });
    const nth = log.state.promotions.length;
    log.append({ type: "job_state", state: "done", reason: `moved to the newest base and verified (${v.n} checks: lint, smoke, every bot); promoted under the job directory (${pr.dest}; promotion ${nth} of this job; the earlier one is kept)` });
    out(`PASS  rebase: ${pr.packId} ${pr.version} promoted to ${pr.dest} (${v.n} checks)`);
    return 0;
  } finally {
    log.close();
  }
}
