// P10 items 1 and 2 over the Foreman's state: the pack's tests at a merge, and a failed final verification sent back
// to a package. Moved out of foreman.ts in P10b: the methods became free functions over a small host that the Foreman
// builds (`gateHost`); their bodies are unchanged except `this.` -> `h.`.
import fs from "node:fs";
import path from "node:path";
import type { Acceptance, JobEvent } from "./events.js";
import type { JobLog, JobState, PackageView } from "./joblog.js";
import type { VerifyResult } from "./verifier.js";
import { readManifest } from "./promoter.js";
import { dependants } from "./manifest.js";
import { FINAL_FAILED, PACK_TEST_FAILED, PACK_TEST_NOT_MINE } from "./p10.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import type { GateFailure, Verified } from "./machine.js";
import type { ForemanOptions } from "./options.js";

/** What these functions need of the Foreman: its options, the job's state and log, and a few of its methods. */
export interface GateHost {
  readonly o: ForemanOptions & { roundLimit: number };
  readonly s: JobState;
  readonly events: JobEvent[];
  dir(...parts: string[]): string;
  rel(abs: string): string;
  pkg(id: string): PackageView;
  append(body: Parameters<JobLog["append"]>[0]): JobEvent;
  reopen(id: string, reason: string, detail: string): void;
  verifyLogged(a: Pick<Acceptance, "verb" | "args">, packDir: string, stem: string, where: { package?: string; round: number; after?: string }): Promise<Verified>;
}

// ---------- P10 item 1: the pack's tests at the merge gate ----------

/** The package that registers a test in the plan (`registers.tests`). */
export function testOwner(h: GateHost, test: string): string | undefined {
  return h.s.plan.find((p) => (p.registers?.tests ?? []).includes(test))?.id;
}

/**
 * The tests of the pack that run on the candidate of `id`: every test of the candidate's manifest that NO package
 * depending on `id` answers for. A dependant answers for a test it registers and for a test its acceptance runs:
 * right after the merge each dependant's whole acceptance is run again on the merged pack (reverifyDependants) and
 * one that fails is re-opened to adapt, which is what a change to its dependency means. A test nobody downstream
 * answers for (the package's own, a dependency's, a sibling's) must pass with the package's files in before they
 * become pack/: nobody else will be asked to adapt to them. A package without dependants (the real job's
 * hockey_ai) is therefore checked against EVERY test of the pack; a root whose bots its dependants run is
 * checked against none here and against all of them through its dependants a moment later.
 */
export function packTestsFor(h: GateHost, id: string, candidate: string, hadMerged: boolean): string[] {
  const mode = h.o.packTests ?? "after_change";
  if (mode === "never") return [];
  if (mode === "after_change" && !hadMerged && h.pkg(id).roundBase === undefined) return [];
  let tests: string[] = [];
  try {
    tests = readManifest(candidate).tests;
  } catch {
    return [];
  }
  const theirs = new Set(dependants(h.s.plan, id));
  const answered = new Set<string>();
  for (const p of h.s.plan) {
    if (!theirs.has(p.id)) continue;
    for (const t of p.registers?.tests ?? []) answered.add(t);
    for (const a of p.acceptance) {
      const t = a.verb === "bot" ? a.args.find((x) => x.startsWith("--test="))?.slice("--test=".length) : undefined;
      if (t !== undefined) answered.add(t);
    }
  }
  return tests.filter((t) => !answered.has(t));
}

/**
 * One test of the pack on the candidate (pack/ with the round's files of `id` merged in). When it fails and the
 * test is another package's, the same test is run on pack/ WITHOUT those files (the control):
 *   - control passes: the files of `id` are the only difference, so they are the cause. The merge is refused, a
 *     note names the package whose test failed and the package that was merging, and `id` gets the report;
 *   - control fails too: the test was failing before this merge. Not this package's doing: a note, and the merge
 *     goes on (the test's own package is being rebuilt, or the final verification sends it to a package).
 */
export async function packTest(h: GateHost, id: string, round: number, test: string, candidate: string): Promise<GateFailure | undefined> {
  const a: Acceptance = { level: "V4", verb: "bot", args: [`--test=${test}`] };
  const name = path.basename(test, ".gd");
  const vr = await h.verifyLogged(a, candidate, `${id}-r${round}-pack-bot-${name}`, { round, after: id });
  if (vr.ok || vr.inconclusive !== undefined) return vr.ok ? undefined : vr;
  const owner = testOwner(h, test) ?? id;
  const report = h.rel(vr.reportFile);
  if (owner === id) {
    const text = `${PACK_TEST_FAILED} after the merge of ${id} was tried: ${test}, this package's own test, fails on the whole pack with the files of round ${round} merged in (${report}). The files were NOT merged.`;
    h.append({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${text}` });
    return { ...vr, summary: `${text} ${vr.summary}` };
  }
  const control = await h.verifyLogged(a, h.dir("pack"), `${id}-r${round}-control-bot-${name}`, { round, after: id });
  if (control.ok) {
    const text = `${PACK_TEST_FAILED} after the merge of ${id} was tried: ${test}, a test of package ${owner}, fails on the whole pack with the round-${round} files of ${id} merged in (${report}) and passes on the same pack without them (control run: ${h.rel(control.reportFile)}). The files of ${id} are the only difference, so they are the cause. They were NOT merged.`;
    h.append({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${text}` });
    return { ...vr, summary: `${text} ${vr.summary}` };
  }
  h.append({
    type: "note",
    package: id,
    round,
    text: `${FOREMAN_NOTE}${PACK_TEST_NOT_MINE}: ${test}, a test of package ${owner}, fails on the whole pack with the round-${round} files of ${id} merged in (${report}) and ${control.inconclusive !== undefined ? "the control run without them gave no verdict (machine busy)" : `fails without them as well (control run: ${h.rel(control.reportFile)})`}. Not caused by this merge, which goes on; ${owner} is the package to look at.`,
  });
  return undefined;
}
// ---------- P10 item 2: a failed final verification goes back to a package ----------

export function finalLimit(h: GateHost): number {
  return Math.max(0, h.o.finalRounds ?? h.o.roundLimit);
}
/** How often the final verification sent a failure back since the last promotion or change request. */
export function finalSent(h: GateHost): number {
  const events = h.events;
  const since = [...events].reverse().find((e) => e.type === "promoted" || e.type === "change_requested")?.seq ?? 0;
  return events.filter((e) => e.type === "reopened" && e.seq > since && e.reason.startsWith(FINAL_FAILED)).length;
}

/** The test a `bot` verify event ran, read from its report (`bot.test`). */
export function testOfVerify(h: GateHost, e: Extract<JobEvent, { type: "verify" }>): string | undefined {
  try {
    const r = JSON.parse(fs.readFileSync(h.dir(e.report), "utf8")) as { bot?: { test?: unknown } };
    return typeof r.bot?.test === "string" ? r.bot.test : undefined;
  } catch {
    return undefined;
  }
}

/**
 * Which package a failed final check goes back to, decided from the log:
 *   - a bot test: the LAST passing run of that test in the log is found (any run: a workspace, a merge candidate,
 *     a re-verification, an earlier final verification). The packages that merged files AFTER the state that run
 *     saw are the only things that changed since; the one that merged last is re-opened. When nothing merged since
 *     (or the test never passed in this log), the package that registers the test takes it;
 *   - lint, smoke, invariants: no single package owns them; the package that merged last since the last
 *     promotion is re-opened (the checks passed for the promoted pack, so a merge since then broke them).
 */
export function blameFinal(h: GateHost, a: Acceptance, vr: VerifyResult): { id: string; how: string } | undefined {
  const events = h.events;
  const merges = events.filter((e): e is Extract<JobEvent, { type: "merge" }> => e.type === "merge" && e.files.length + (e.removed?.length ?? 0) > 0);
  const promotedAt = [...events].reverse().find((e) => e.type === "promoted")?.seq ?? 0;
  const ok = (id: string | undefined): id is string => id !== undefined && h.s.packages[id] !== undefined && h.pkg(id).state === "promoted" && (h.pkg(id).mergedFiles ?? []).length > 0;
  const lastSince = (seq: number): Extract<JobEvent, { type: "merge" }> | undefined => [...merges].reverse().find((m) => m.seq > seq && ok(m.package));
  if (a.verb !== "bot") {
    const m = lastSince(promotedAt);
    return m ? { id: m.package, how: `${a.verb} is a check of the whole pack and passed for the promoted pack; ${m.package} is the package that merged last since then (event ${m.seq})` } : undefined;
  }
  const test = a.args.find((x) => x.startsWith("--test="))?.slice("--test=".length) ?? "";
  const owner = testOwner(h, test);
  void vr;
  const pass = [...events].reverse().find((e): e is Extract<JobEvent, { type: "verify" }> => e.type === "verify" && e.verb === "bot" && e.ok && testOfVerify(h, e) === test);
  if (pass) {
    // A run on a package's workspace or on its merge candidate already saw that package's files: its own merge
    // right after is not a change since.
    const saw = pass.package !== undefined && !/-reverify-/.test(pass.report) ? pass.package : pass.after !== undefined && /-pack-bot-/.test(pass.report) ? pass.after : undefined;
    const own = saw !== undefined ? merges.find((m) => m.seq > pass.seq && m.package === saw)?.seq : undefined;
    const since = merges.filter((m) => m.seq > pass.seq && m.seq !== own && ok(m.package));
    const last = since[since.length - 1];
    if (last) {
      const others = [...new Set(since.map((m) => m.package))].filter((x) => x !== last.package);
      return { id: last.package, how: `${test}${owner ? ` (a test of package ${owner})` : ""} last passed at event ${pass.seq} (${pass.report}); since the state that run saw, ${last.package} merged last (event ${last.seq})${others.length > 0 ? `, after ${others.join(", ")}` : " and nothing else changed"}, so its files are where the failure comes from` };
    }
    if (ok(owner)) return { id: owner, how: `${test} last passed at event ${pass.seq} and no package merged since, so the package that registers the test (${owner}) takes it` };
  }
  if (ok(owner)) return { id: owner, how: `no passing run of ${test} is in the log, so the package that registers the test (${owner}) takes it` };
  const m = lastSince(promotedAt);
  return m ? { id: m.package, how: `${m.package} merged last (event ${m.seq})` } : undefined;
}

/**
 * "sent": a package was re-opened with the failure and the loop goes on. "spent": the limit of such rounds is
 * used up (the change was not made). "no": this is not a job with an earlier promotion, or nothing can be blamed:
 * the job fails as it did before P10.
 */
export function sendBackFinal(h: GateHost, a: Acceptance, vr: VerifyResult): "sent" | "spent" | "no" {
  if (h.s.promotions.length === 0) return "no";
  const sent = finalSent(h);
  const limit = finalLimit(h);
  if (sent >= limit) return limit > 0 ? "spent" : "no";
  const who = blameFinal(h, a, vr);
  if (!who) return "no";
  const what = `${a.verb} (${vr.level})${a.verb === "bot" ? ` ${a.args.join(" ")}` : ""}`;
  const report = h.rel(vr.reportFile);
  const text = `${FINAL_FAILED} (${sent + 1} of ${limit}) at ${what} [report: ${report}]. Sent back to ${who.id}: ${who.how}. ${clip(vr.summary, 200)}`;
  h.reopen(who.id, text, text);
  return "sent";
}
