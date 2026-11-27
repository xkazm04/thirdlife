// D27b of the juice day of 27 Nov 2026 (lane T2-editor): what lane J2nd met in the editor (its PROOF-J2nd.md findings
// 1, 2, 4-9). Each test fails on the code before this lane and passes now. Events, notes and reports are J2nd's own
// (fixtures/d27b, copied from d25-kart/.tl/jobs/j2nd).
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, foremanFor, readEvents, scriptWith, tempDir, tempJob } from "./helpers.js";
import type { FakeStep } from "../builder/fake.js";
import type { JobEvent, PackageSpec } from "../events.js";
import type { GateHost } from "../p10gate.js";
import type { GateFailure } from "../machine.js";
import { JobLog } from "../joblog.js";
import { REPO_ROOT } from "../paths.js";
import { withGrants, widenedNote } from "../scopegrant.js";
import { MOVES_LAND, MOVES_UNCOUNTED, landGate } from "../landcheck.js";
import { movesTestFor } from "../movestest.js";
import { NOT_MADE, REST_OF, afterMerge, handsOff, processRemark } from "../halfmade.js";
import { blockedByOwner, ownerWaits } from "../ownerfix.js";
import { asksOwnTest, ownTestAnswer } from "../owntest.js";
import { answeredThisChange, askedAgain } from "../asktwice.js";
import { unaskedRules } from "../fastchange.js";
import { isRuleLine } from "../rulelines.js";
import { askedChange, changeKind } from "../boundlift.js";
import { fairChecks, fairText, perSeed } from "../fairseeds.js";
import { earlierUnmade } from "../unmade.js";
import { changeBoundary } from "../changeend.js";
import { whatChangedNote } from "../fastchange.js";

after(cleanup);

const fixture = <T>(name: string): T => JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "d27b", name), "utf8")) as T;
type Fix = { plan: PackageSpec[]; promoted: JobEvent; events: JobEvent[] };
const note = (events: readonly JobEvent[], seq: number): string => {
  const e = events.find((x) => x.seq === seq);
  return e?.type === "note" || e?.type === "change_requested" ? e.text : "";
};

/** A small GateHost over a list of events (appends go to `out` and into the events). */
function host(plan: PackageSpec[], events: JobEvent[], packages: Record<string, unknown>, dir = tempDir("d27b-host")): GateHost & { out: Record<string, unknown>[] } {
  const out: Record<string, unknown>[] = [];
  let seq = events.reduce((n, e) => Math.max(n, e.seq), 0);
  return {
    out,
    s: { plan, packages, lastSeq: seq } as unknown as GateHost["s"],
    events,
    dir: (...p: string[]) => path.join(dir, ...p),
    rel: (abs: string) => path.relative(dir, abs).replace(/\\/g, "/"),
    pkg: (id: string) => packages[id] as GateHost["s"]["packages"][string],
    append: (e: Record<string, unknown>) => {
      seq += 1;
      const ev = { ...e, seq } as unknown as JobEvent;
      out.push(e);
      events.push(ev);
      return ev;
    },
  } as unknown as GateHost & { out: Record<string, unknown>[] };
}

// ---------------------------------------------------------------- 23. a package with no bot test of its own counts its move

test("D27b 23 (J2nd's biplane copy, events 743-778: core's acceptance runs only the frozen tofu bot, so the harpoon's count was put in the tofu bot twice and undone twice, and the card said the harpoon was NOT made while it hooks her): such a package may write tests/moves_<id>.gd, is told so, and is never told its move was not made only because nobody counted it", () => {
  const j = fixture<Fix>("j2nd-biplane-harpoon.json");
  const core = j.plan.find((p) => p.id === "core") as PackageSpec;
  const before = [j.promoted, ...j.events.filter((e) => e.seq <= 750)];
  // the scope: tests/moves_core.gd in this play change, never for a package with a bot test of its own
  assert.equal(movesTestFor(j.plan, core, before), "tests/moves_core.gd");
  assert.ok(withGrants(core, before, j.plan).scope.includes("tests/moves_core.gd"));
  assert.equal(movesTestFor(j.plan, j.plan.find((p) => p.id === "rival_season") as PackageSpec, before), undefined, "rival_season runs tests/bot_season.gd");
  assert.equal(movesTestFor(j.plan, core, [j.promoted]), undefined, "no change in flight");
  assert.match(widenedNote(j.plan, before, "core", ["scripts/core/harpoon.gd", "tests/moves_core.gd"]) ?? "", /^\[foreman\] scope widened for this change: core's acceptance runs no bot test of its own besides the Foreman's tofu bot, so it may write tests\/moves_core\.gd/);
  // round 24 as it happened (no count in any bot report): the builder is told to write its own test, not "a bot test your acceptance runs"
  const r24 = [j.promoted, ...j.events.filter((e) => e.seq <= 756)];
  const h = host(j.plan, r24, { core: { round: 24, roundBase: 24 } });
  const fail = landGate(h, "core", 24);
  assert.equal(fail?.ok, false);
  assert.match(fail?.summary ?? "", /write tests\/moves_core\.gd, a bot test of your own \(it is in your scope for this change and the Foreman runs it in this check with --test=tests\/moves_core\.gd; you do not add it to pack\.json\)/);
  assert.doesNotMatch(fail?.summary ?? "", /to the metrics of a bot test your acceptance runs/);
  // round 26, the revise budget spent with the move still uncounted: "not counted", never "NOT made"
  const r26 = [j.promoted, ...j.events.filter((e) => e.seq <= 777)];
  const h26 = host(j.plan, r26, { core: { round: 26, roundBase: 24 } });
  assert.equal(landGate(h26, "core", 26), undefined);
  const said = String(h26.out.at(-1)?.["text"] ?? "");
  assert.match(said, new RegExp(`^${MOVES_UNCOUNTED.replace(/[[\]]/g, "\\$&")} by core: no bot test counted harpoon after 3 rounds`));
  assert.ok(!said.includes(NOT_MADE), said);
  assert.match(note(j.events, 778), /NOT made by core: the new move harpoon does not land/, "what the card said that day");
});

test("D27b 23b: through the Foreman, a package whose acceptance runs no bot test writes tests/moves_core.gd; the Foreman runs it in the land check, the move lands, and the file merges", async () => {
  const job = tempJob("d27b-moves");
  assert.equal((await foremanFor(job, { promoteTo: "job" }).foreman.run()).jobState?.state, "done");
  const log = JobLog.open(job.jobDir);
  log.append({ type: "change_requested", text: "Give my paddle a smash: when the ball comes I can slam it back twice as fast." });
  log.close();
  const from = readEvents(job.jobDir).at(-1)?.seq ?? 0;
  const steps: FakeStep[] = [
    { match: { role: "planner", promptIncludes: "Decide which ONE package owns" }, json: { package: "core", reason: "the paddle is the core's" } },
    { match: { role: "builder", package: "core" }, write: { "scripts/main.gd": "extends Node\n# smash x2\n", "tests/moves_core.gd": "extends Node\n# FAKE_METRICS({\"moves\": {\"smash\": {\"started\": 5, \"landed\": 3, \"last_f\": 590}}})\n" }, text: "Done.\nDEVIATIONS:\n- NEW MOVE: smash" },
  ];
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith(steps) }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > from);
  const run = later.find((e) => e.type === "verify" && e.package === "core" && e.report.includes("-moves"));
  assert.ok(run?.type === "verify" && run.ok, "the Foreman ran tests/moves_core.gd");
  assert.ok(later.some((e) => e.type === "note" && e.text.startsWith(`${MOVES_LAND}: smash landed 3 of 5 (60 %)`)), "the move is counted and lands");
  assert.ok(!later.some((e) => e.type === "note" && e.text.includes(NOT_MADE)), "nothing is called not made");
  const merge = later.find((e) => e.type === "merge" && e.package === "core");
  assert.ok(merge?.type === "merge" && merge.files.includes("tests/moves_core.gd"), "the test is the package's own file now");
  assert.equal(later.filter((e) => e.type === "builder_run" && e.package === "core").length, 1, "one round");
  assert.ok(!JSON.parse(fs.readFileSync(path.join(job.jobDir, "pack", "pack.json"), "utf8")).tests.includes("tests/moves_core.gd"), "the pack's manifest does not list it");
  assert.ok(!fs.existsSync(path.join(job.jobDir, "ws", "_moves_core")), "the copy is gone");
});

// ---------------------------------------------------------------- 24. a script error in another package's file goes to its owner

test("D27b 24 (J2nd's kart copy, events 1303-1365: core named the one-line fix of scripts/items/items.gd:280 as NOT DONE in r20, r21 and r22; a NOT DONE travels only after a merge, so it never reached items, and v0.1.8 promoted with the shells never switched on): lane T's items 17/18 do not cover a round that cannot merge; the failed round hands the fix to items and waits for it", () => {
  const j = fixture<Fix & { report: GateFailure["report"] }>("j2nd-kart-items.json");
  // lane T's items 17/18 (afterMerge) never run: no core round merged
  assert.ok(!j.events.some((e) => e.type === "merge" && e.package === "core"), "no core merge in 1303-1365");
  const upTo = (seq: number): JobEvent[] => [j.promoted, ...j.events.filter((e) => e.seq <= seq)];
  const reopened = upTo(1337).filter((e) => e.type === "reopened" && e.package === "core").at(-1);
  assert.match(reopened?.type === "reopened" ? reopened.reason : "", /change request \(event 1303\)/);
  // core r20, as it failed (event 1341: the report's only error is items' script error)
  const evs = upTo(1341);
  const items = { state: "promoted", round: 1, mergedFiles: ["data/items.json", "gen/mod_items.gd", "scripts/items/items.gd", "tests/bot_items.gd"] };
  const core = { state: "verifying", round: 20, roundBase: 19, mergedFiles: ["scripts/main.gd"], changes: [note(j.events, 1303)] };
  const h = host(j.plan, evs, { core, items });
  const failure = { verb: "bot", level: "V4", ok: false, report: j.report, summary: "bot failed: failed checks [smoke.no_script_errors], 1 errors", reportFile: "r", verdictFile: "r", flags: [], durationMs: 1 } as unknown as GateFailure;
  assert.equal(blockedByOwner(h, "core", 20, failure), true);
  const [waits, toItems, again] = h.out;
  assert.match(String(waits?.["text"]), /^\[foreman\] core waits for items: core's round 20 failed only on a script error in a file that items owns \(scripts\/items\/items\.gd:280: TLAudio: unknown preset 'hit_steel'/);
  assert.equal(toItems?.["package"], "items");
  assert.match(String(toItems?.["text"]), new RegExp(`^\\[foreman\\] ${REST_OF}, which core did not make \\("NOT DONE: a shell hit on a kart has to play a sound the engine knows .*hit_metal`));
  assert.equal(again?.["package"], "core");
  assert.match(String(again?.["text"]), /^\[foreman\] your change again, now that items has fixed the script error in its file/);
  // every request of core waits until items has merged again; once per owner in a change
  assert.equal(ownerWaits(h.events, { package: "core" }), true);
  assert.equal(ownerWaits(h.events, { package: "items" }), false);
  assert.equal(blockedByOwner(h, "core", 21, failure), false, "once per owner per change");
  h.events.push({ seq: 9001, type: "merge", package: "items", files: ["scripts/items/items.gd"] } as unknown as JobEvent);
  assert.equal(ownerWaits(h.events, { package: "core" }), false, "items merged its fix");
  // core's own script error, or one in a file nobody else owns, is core's: no hand-off
  const own = { ...failure, report: { ...j.report, errors: [{ kind: "script_error", file: "scripts/core/kart.gd", line: 3, message: "x" }] } } as unknown as GateFailure;
  assert.equal(blockedByOwner(host(j.plan, upTo(1341), { core, items }), "core", 20, own), false);
});

test("D27b 24b: through the Foreman, a change whose rounds fail on a script error in the rival paddle's file sends the fix to paddle_ai, waits for its merge, and then makes the change", async () => {
  const job = tempJob("d27b-owner");
  assert.equal((await foremanFor(job, { promoteTo: "job" }).foreman.run()).jobState?.state, "done");
  // a latent bug in paddle_ai's merged file, as items.gd's unknown sound was: it shows only when the game runs it
  const ai = path.join(job.jobDir, "pack", "scripts", "paddle_ai.gd");
  fs.appendFileSync(ai, "# FAKE_SCRIPT_ERROR\n");
  const log = JobLog.open(job.jobDir);
  log.append({ type: "change_requested", text: "Make the ball fly twice as fast off a paddle." });
  log.close();
  const from = readEvents(job.jobDir).at(-1)?.seq ?? 0;
  const steps: FakeStep[] = [
    { match: { role: "planner", promptIncludes: "Decide which ONE package owns" }, json: { package: "core", reason: "the ball is the core's" } },
    { match: { role: "builder", package: "core" }, write: { "scripts/main.gd": "extends Node\n# ball x2\n" }, text: "Done.\nDEVIATIONS:\n- NOT DONE: the ball must fly without a script error, which needs `scripts/paddle_ai.gd`, outside my scope: delete its last line." },
    { match: { role: "builder", package: "paddle_ai" }, write: { "scripts/paddle_ai.gd": "extends RefCounted\n\nfunc decide(ball_y: float, paddle_y: float, tuning: Dictionary) -> float:\n\treturn signf(ball_y - paddle_y)\n" }, text: "Removed the broken last line.\nDEVIATIONS: none" },
  ];
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith(steps) }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > from);
  const handed = later.find((e) => e.type === "change_requested" && e.package === "paddle_ai");
  assert.match(handed?.type === "change_requested" ? handed.text : "", /^\[foreman\] the rest of your change, which core did not make \("NOT DONE: the ball must fly without a script error, which needs `scripts\/paddle_ai\.gd`/);
  const aiMerge = later.find((e) => e.type === "merge" && e.package === "paddle_ai")?.seq ?? Infinity;
  const coreMerge = later.find((e) => e.type === "merge" && e.package === "core")?.seq ?? -1;
  assert.ok(coreMerge > aiMerge, `core merged after paddle_ai's fix (${coreMerge} > ${aiMerge})`);
  assert.equal(later.filter((e) => e.type === "builder_run" && e.package === "core").length, 2, "one failed round, then the change");
  assert.ok(!fs.readFileSync(ai, "utf8").includes("FAKE_SCRIPT_ERROR"));
  assert.equal(fs.readFileSync(path.join(job.jobDir, "pack", "scripts", "main.gd"), "utf8"), "extends Node\n# ball x2\n", "the change was made");
});

// ---------------------------------------------------------------- 26. the Foreman's own test is never the person's question

test("D27b 26 (J2nd's kart copy, event 1518: core asked the person \"Should the pack's own test get through three matches quicker with wider goals ..., or with a shorter match ...?\" and the job paused): the Foreman answers a question about its own test itself", () => {
  const j = fixture<{ plan: PackageSpec[]; events: JobEvent[] }>("j2nd-kart-question.json");
  const q = note(j.events, 1518) || ((j.events.find((e) => e.seq === 1518) as { text?: string } | undefined)?.text ?? "");
  assert.match(q, /^Should the pack's own test get through three matches quicker/);
  assert.equal(asksOwnTest(j.plan, q), true);
  const evs = ownTestAnswer(j.plan, "core", 32, q) ?? [];
  assert.deepEqual(evs.map((e) => e["type"]), ["question", "answer", "note"]);
  assert.equal(evs[1]?.["by"], "foreman");
  assert.match(String(evs[1]?.["text"]), /never a reason to change the game, and the person is not asked about them/);
  // a question about the game is still the person's
  assert.equal(asksOwnTest(j.plan, "Should the shells be red or blue, and should a hit kart spin twice or three times?"), false);
  assert.equal(ownTestAnswer(j.plan, "core", 32, "Should wider goals be the default for every match?"), undefined);
  assert.equal(asksOwnTest(j.plan, "May I change tests/bot_tofu.gd so it accepts 2 matches?"), true, "the plan's tofu bot by its path");
  // the Foreman's answer is not the person's answer in this change (asktwice.ts)
  const events = [{ seq: 1, type: "reopened", package: "core", reason: "change request" }, { seq: 2, type: "question", package: "core", text: q }, { seq: 3, type: "answer", package: "core", text: "x", by: "foreman" }] as unknown as JobEvent[];
  assert.equal(answeredThisChange(events, "core", 10), undefined);
});

test("D27b 26b: through the Foreman, a builder's question about the Foreman's own test is answered by the Foreman; the job never pauses for the person", async () => {
  const job = tempJob("d27b-owntest");
  assert.equal((await foremanFor(job, { promoteTo: "job" }).foreman.run()).jobState?.state, "done");
  const log = JobLog.open(job.jobDir);
  log.append({ type: "change_requested", text: "Make the ball fly twice as fast off a paddle." });
  log.close();
  const from = readEvents(job.jobDir).at(-1)?.seq ?? 0;
  const steps: FakeStep[] = [
    { match: { role: "planner", promptIncludes: "Decide which ONE package owns" }, json: { package: "core", reason: "the ball is the core's" } },
    { match: { role: "builder", package: "core", promptIncludes: "Answer to your question: The Foreman answers this itself" }, write: { "scripts/main.gd": "extends Node\n# ball x2\n" }, text: "Done.\nDEVIATIONS: none" },
    { match: { role: "builder", package: "core" }, text: "QUESTION: Should the pack's own test get through three rallies quicker with a wider court, or should the match be shorter?" },
  ];
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith(steps) }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > from);
  assert.ok(later.some((e) => e.type === "answer" && e.package === "core" && e.by === "foreman"));
  assert.ok(!later.some((e) => e.type === "job_state" && e.state === "paused"), "never paused for the person");
  assert.ok(later.some((e) => e.type === "merge" && e.package === "core"));
});

// ---------------------------------------------------------------- 27, 28. what reaches the card

test("D27b 27 (J2nd's court copy, events 1333 and 1345: \"Not done this round: `bot_tofu`, smoke and invariants were not rerun after the change.\" became \"part of your change was NOT made\" on the card): a builder's remark about its own checks is not an unmade part", () => {
  const j = fixture<{ plan: PackageSpec[]; events: JobEvent[] }>("j2nd-court.json");
  const line = "Not done this round: `bot_tofu`, smoke and invariants were not rerun after the change.";
  assert.ok(note(j.events, 1333).includes(line));
  assert.equal(processRemark(line), true);
  assert.equal(handsOff(line), false);
  assert.match(note(j.events, 1345), /NOT made: court_exchange made what it could and says: Not done this round/, "what the card said that day");
  const events = [
    { seq: 1, type: "promoted", packId: "game.x", version: "0.1.6", dest: "x" },
    { seq: 2, type: "change_requested", text: "Add an NBA Jam alley-oop off the glass on C." },
    { seq: 3, type: "reopened", package: "court_exchange", reason: "change request (event 2); the Planner names the package" },
    { ...(j.events.find((e) => e.seq === 1333) as object), seq: 4 },
  ] as unknown as JobEvent[];
  const out = afterMerge(j.plan, events, "court_exchange", 13, ["scripts/core/oop.gd"], "Add an NBA Jam alley-oop off the glass on C.");
  assert.ok(!out.some((e) => String(e["text"] ?? "").includes(NOT_MADE)), JSON.stringify(out));
  // a real hand-off still goes on (lane T's D27 2: the same words with a file outside the scope)
  assert.equal(handsOff("NOT DONE: the shell hit needs scripts/items/items.gd, which is outside my scope: use hit_metal."), true);
  assert.equal(handsOff("NOT DONE: the rival lob needs `scripts/crews/brain.gd`; it was not tested in a whole match."), true, "a game file named: a hand-off");
  // this lane's live run (the biplane copy, event 994 -> 1006): a part made in the builder's own files is not handed on
  const ff = fixture<{ event: JobEvent & { text: string } }>("t2e-biplane-first-flight-994.json").event;
  const own = ff.text.split("\n").map((l) => l.replace(/^\s*[-*]\s*/, "")).find((l) => l.startsWith("The new numbers")) ?? "";
  assert.match(own, /I didn't put them in `data\/tuning\.json`, which belongs to another package/);
  assert.equal(handsOff(own), false);
  assert.equal(handsOff("NOT DONE: the lesson numbers are in my own table; data/tuning.json belongs to another package and needs `lesson.cross_at_f` 300."), true, "an explicit NOT DONE still goes on");
});

test("D27b 28 (J2nd's court copy, event 1525: \"RULE: none added. The odds ... are as before\" reached the v0.1.8 card as \"unasked rule: none added\"): a line that says no rule was added is not a rule", () => {
  const j = fixture<{ plan: PackageSpec[]; events: JobEvent[] }>("j2nd-court.json");
  const n = j.events.find((e) => e.seq === 1525) as JobEvent;
  const rules = unaskedRules([{ seq: 1, type: "merge", package: "court_exchange", files: ["data/tuning.json"] } as unknown as JobEvent, n]);
  assert.ok(!rules.some((r) => /none added/i.test(r)), JSON.stringify(rules));
  assert.equal(isRuleLine("RULE: none added. The odds of the throw, the catch and the contest are as before."), false);
  assert.equal(isRuleLine("- RULE: no new rule."), false);
  // the real rules of event 1333 are still unasked rules
  const r1333 = unaskedRules([{ seq: 1, type: "merge", package: "court_exchange", files: ["data/tuning.json"] } as unknown as JobEvent, j.events.find((e) => e.seq === 1333) as JobEvent]);
  assert.equal(r1333.filter((r) => r.startsWith("RULE:")).length, 2);
});

// ---------------------------------------------------------------- 31. a RULE: line makes a change a play change

test("D27b 31 (J2nd's biplane copy, events 987-1000: the newcomer fix, about the lesson and messages, was judged \"view or screen only\" though first_flight's builder wrote two play-changing RULE: lines, and skill_spread 0.04 went unjudged and untold): a builder's RULE: line makes the change a play change", () => {
  const j = fixture<{ promoted: JobEvent; events: JobEvent[] }>("j2nd-biplane-newcomer.json");
  const ask = j.events.find((e) => e.seq === 987) as JobEvent & { text: string };
  assert.equal(changeKind(ask.text), "view", "the person's words alone read as the view and the screen");
  assert.equal(askedChange([j.promoted, ask])?.kind, "view", "before the builder's note");
  const withNote = [j.promoted, ...j.events.filter((e) => e.seq <= 994)];
  assert.equal(askedChange(withNote)?.kind, "play", "after first_flight's RULE: lines (event 994)");
  assert.match(note(j.events, 1000), /^\[foreman\] balance not judged: a change to the view or the screen only; tests\/bot_tofu\.gd figures outside their bounds, not judged: skill_spread 0\.04/, "what the Foreman said that day");
  // "RULE: none added" does not make a view change play; a builder's note about the view only does not either
  const none = [j.promoted, ask, { seq: 991, type: "note", package: "first_flight", round: 4, text: "- The hint is larger.\n- RULE: none added." }] as unknown as JobEvent[];
  assert.equal(askedChange(none)?.kind, "view");
  // the Foreman's own notes are not a builder's RULE: line
  const foreman = [j.promoted, ask, { seq: 991, type: "note", package: "first_flight", round: 4, text: "[foreman] RULE: something" }] as unknown as JobEvent[];
  assert.equal(askedChange(foreman)?.kind, "view");
});

// ---------------------------------------------------------------- 32. a fairness change is tuned against the measure

function courtJob(): { h: GateHost & { out: Record<string, unknown>[] }; j: { plan: PackageSpec[]; card: { id: string }; events: JobEvent[]; seeds: { seed: number; seq: number; bot: unknown }[] } } {
  const j = fixture<{ plan: PackageSpec[]; card: { id: string }; events: JobEvent[]; seeds: { seed: number; seq: number; bot: unknown }[] }>("j2nd-court.json");
  const dir = tempDir("d27b-court");
  fs.mkdirSync(path.join(dir, "ref", "cards"), { recursive: true });
  fs.writeFileSync(path.join(dir, "ref", "cards", "team_possession.json"), JSON.stringify(j.card));
  fs.mkdirSync(path.join(dir, "reports"), { recursive: true });
  const verifies = j.seeds.map((s) => {
    const rel = `reports/final-hand-newcomer-seed${s.seed}-s${s.seq}.json`;
    fs.writeFileSync(path.join(dir, rel), JSON.stringify({ verb: "bot", ok: true, bot: s.bot }));
    return { seq: s.seq, type: "verify", round: 1, level: "V4", verb: "bot", ok: true, report: rel };
  });
  const manifest = { tests: ["tests/bot_tofu.gd", "tests/bot_hand_newcomer.gd", "tests/bot_hand_perfect.gd"] };
  for (const ws of ["court_exchange", "crews_stakes"]) {
    fs.mkdirSync(path.join(dir, "ws", ws), { recursive: true });
    fs.writeFileSync(path.join(dir, "ws", ws, "pack.json"), JSON.stringify({ id: "game.half_court_3_v", version: "0.1.8", kernelApi: "1.31", title: "x", capabilities: [], entry: "scripts/main.gd", assets: [], ...manifest }));
  }
  const events = [{ seq: 1600, type: "promoted", packId: "game.half_court_3_v", version: "0.1.8", dest: "promoted/x" }, { seq: 1643, type: "change_requested", text: "Make it fairer: a newcomer who has never played should win a little more often against the rivals." }, ...verifies] as unknown as JobEvent[];
  const h = host(j.plan, events, {}, dir);
  (h.s as unknown as { card: string }).card = j.card.id;
  return { h, j };
}

test("D27b 32 (J2nd's court copy, events 1664-1858: court_exchange \"could not measure the newcomer win share; the newcomer hand test is not one of the commands I may run\", crews_stakes measured \"seed 1 only\", and two final checks of about 35 min each failed the card at 10 and 11 of 20): the package that tunes a fairness ask gets the card's bound, the last run per seed, and the hand test among its commands", () => {
  const { h, j } = courtJob();
  assert.match(note(j.events, 1673), /the newcomer hand test is not one of the commands I may run/);
  const rows = perSeed(h, "newcomer", 20);
  assert.equal(rows.length, 20);
  assert.equal(rows.filter((r) => r.won === true).length, 10, "10 of 20, as the hand check of event 1782 counted");
  assert.match(rows.find((r) => r.seed === 9)?.summary ?? "", /"crew": 19, "quarry": 21/);
  const text = fairText(h, "court_exchange");
  assert.match(text, /^\n\n## The measure your fairness change is judged by\nThe person asked for fairness \("Make it fairer/);
  assert.match(text, /- the newcomer hand \(tests\/bot_hand_newcomer\.gd\) on seeds 1\.\.20: the card asks at least 13 wins\. Its last run: won 10 of 20 seed\(s\) run\. Per seed: 1 (WON|lost) /);
  assert.match(text, /9 lost \(newcomer hand: finished true, acted 46, \{ "crew": 19, "quarry": 21 \}\)/);
  assert.match(text, /You may run it yourself on your workspace: it is among the commands below with --seed=1/);
  assert.deepEqual(fairChecks(h, "court_exchange").map((a) => a.args), [["--test=tests/bot_hand_newcomer.gd", "--seed=1"], ["--test=tests/bot_hand_perfect.gd", "--seed=1"]]);
  // not a fairness change: nothing (a play change keeps its prompt as it was)
  h.events.splice(1, 1, { seq: 1643, type: "change_requested", text: "Give my mates a faster alley-oop." } as unknown as JobEvent);
  assert.equal(fairText(h, "court_exchange"), "");
  assert.deepEqual(fairChecks(h, "court_exchange"), []);
  // the round a hand check sent back gets it too (crews_stakes r17, event 1782)
  h.events.push({ seq: 1782, type: "reopened", package: "crews_stakes", reason: "hand check failed (1 of 1) for card card.team_possession: tests/bot_hand_newcomer.gd (newcomer hand): 10 of 20 won" } as unknown as JobEvent);
  assert.match(fairText(h, "crews_stakes"), /The card's hand check sent this package back\./);
});

// ---------------------------------------------------------------- 41, 42. a change that was NOT made leaves no trace

test("D27b 42 (J2nd's court copy j2nd3, events 1629-2180: the cue change ended NOT made at 2046, the next change promoted v0.1.9 without the cue, and its card asked all four sentences while court_exchange wrote \"The C: ALLEY-OOP cue ... unchanged\"): every change that ended NOT made since the last promotion is told as not in this version, and the card names only what this version made", () => {
  const j = fixture<{ events: JobEvent[] }>("j2nd3-court-unmade.json");
  const upto = j.events.filter((e) => e.seq < 2179);
  assert.equal(changeBoundary(upto), 2046, "the job ended at 2046 (its resume at 2048 is no ending): the asks after 2046 are the change in flight");
  const notes = earlierUnmade(upto, "court_exchange", 20);
  assert.equal(notes.length, 2);
  assert.match(notes[0]?.text ?? "", /^\[foreman\] part of your change was NOT made: your earlier change "As a newcomer I never found out the alley-oop exists[^"]*" \/ "Make it fairer: a newcomer now wins only 11 of 20[^"]*" ended NOT made \(hand check of card\.team_possession failed, nothing promoted: newcomer: 11 of 20 won/);
  assert.match(notes[1]?.text ?? "", /your earlier change "As a newcomer I never found out the alley-oop exists[^"]*" ended NOT made .*nothing of it is in this version unless this change made it again$/);
  const card = whatChangedNote(upto, "0.1.9");
  const asked = /asked (.*?); (what you will see|files|nothing)/.exec(card)?.[1] ?? card;
  assert.match(asked, /^"Make it fairer for a newcomer: he still wins only 11 of 20/);
  assert.doesNotMatch(asked, /As a newcomer I never found out/, "the unmade cue sentence is not \"asked\" of this version");
  assert.match(note(j.events, 2063), /The C: ALLEY-OOP cue, your mate's glow and the steal hint are unchanged/, "what the builder said that day");
});

test("D27b 41 (J2nd's court copy j2nd3, events 1858-1925: after \"The change was NOT made\" the workspaces kept the failed tuning, and crews_stakes, which wrote \"No game script or data changed this round\", merged data/crews.json with it): a change that was not made leaves no trace in any workspace; the next change merges only its own files and its card tells the earlier one as not made", async () => {
  const j = fixture<{ events: JobEvent[] }>("j2nd3-court-unmade.json");
  assert.match(note(j.events, 1906), /^- No game script or data changed this round/);
  const m = j.events.find((e) => e.seq === 1925);
  assert.deepEqual(m?.type === "merge" ? m.files : [], ["data/crews.json", "tests/bot_crews.gd"], "what that round merged that day");
  const job = tempJob("d27b-unmade");
  assert.equal((await foremanFor(job, { promoteTo: "job" }).foreman.run()).jobState?.state, "done");
  const ask = (text: string): void => {
    const log = JobLog.open(job.jobDir);
    log.append({ type: "change_requested", text });
    log.close();
  };
  // change 1: the court's round breaks the rally bot only in the final verification (no pack tests, no final rounds): NOT made
  ask("Raise the court walls and make the corners bouncier.");
  const one: FakeStep[] = [
    { match: { role: "planner", promptIncludes: "Decide which ONE package owns" }, json: { package: "court", reason: "the walls are the court's" } },
    { match: { role: "builder", package: "court" }, write: { "data/court.json": "{\"width_m\": 16, \"depth_m\": 9, \"wall_height_m\": 2.0, \"walls\": [\"north\", \"south\"], \"goals\": [\"west\", \"east\"]}\n", "scripts/court.gd": "extends RefCounted\n# bouncy corners FAKE_TEST_NEEDS(bot_rally:corner)\nstatic func build(ctx, layout: Dictionary) -> void:\n\tpass\n" }, text: "Walls 2.0 m, bouncy corners.\nDEVIATIONS: none" },
  ];
  const s1 = await foremanFor(job, { promoteTo: "job", packTests: "never", finalRounds: 0, script: scriptWith(one) }).foreman.run();
  assert.match(s1.jobState?.reason ?? "", /The change was NOT made\./, JSON.stringify(s1.jobState));
  assert.ok(!fs.existsSync(path.join(job.jobDir, "ws", "court.baseline.json")), "its baseline too: the next round cuts it again from pack/");
  assert.ok(!fs.existsSync(path.join(job.jobDir, "ws", "court")), "the unmade round's workspace is gone");
  // change 2: only the wall height, from the same package; its builder writes data/court.json alone
  const from = readEvents(job.jobDir).at(-1)?.seq ?? 0;
  ask("Make the walls 1.5 m high.");
  const two: FakeStep[] = [
    { match: { role: "planner", promptIncludes: "Decide which ONE package owns" }, json: { package: "court", reason: "the walls are the court's" } },
    { match: { role: "builder", package: "court" }, write: { "data/court.json": "{\"width_m\": 16, \"depth_m\": 9, \"wall_height_m\": 1.5, \"walls\": [\"north\", \"south\"], \"goals\": [\"west\", \"east\"]}\n" }, text: "Walls 1.5 m.\nDEVIATIONS: none" },
  ];
  const s2 = await foremanFor(job, { promoteTo: "job", packTests: "never", finalRounds: 0, script: scriptWith(two) }).foreman.run();
  assert.equal(s2.jobState?.state, "done", JSON.stringify(s2.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > from);
  const merge = later.find((e) => e.type === "merge" && e.package === "court");
  assert.deepEqual(merge?.type === "merge" ? merge.files : [], ["data/court.json"], "only this change's file");
  assert.ok(!fs.readFileSync(path.join(job.jobDir, "pack", "scripts", "court.gd"), "utf8").includes("bouncy"), "the unmade corners are not in the game");
  const card = later.filter((e) => e.type === "note" && e.text.startsWith("[foreman] what changed in")).at(-1);
  const text = card?.type === "note" ? card.text : "";
  assert.match(text, /asked "Make the walls 1\.5 m high\."; /);
  assert.doesNotMatch(text.split("\n")[0] ?? "", /Raise the court walls/);
  assert.match(text, /\npart of your change was NOT made: your earlier change "Raise the court walls and make the corners bouncier\." ended NOT made \(/);
});

// ---------------------------------------------------------------- the Director's rulings after the landing (27 Nov, 21:5x)

test("D27b ruling 1: one boundary for the change in flight (changeend.ts): what is asked now, what the card says this version made, and which earlier changes ended NOT made all start after the last job ending since the last promotion, whatever its words", () => {
  const ev = [
    { seq: 1, type: "promoted", packId: "game.x", version: "0.1.1", dest: "promoted/x@0.1.1" },
    { seq: 2, type: "job_state", state: "done", reason: "pack verified V0 to V4 and promoted" },
    { seq: 3, type: "change_requested", text: "Make it fairer: the rivals are too strong." },
    // an ending without the words "The change was NOT made" (main's 24b ending on the paddle fixture) is an ending too
    { seq: 4, type: "job_state", state: "done", reason: "all packages promoted; no merge since the last promotion (a change that was asked for was not made: see the package's detail)" },
    { seq: 5, type: "change_requested", text: "Give my mates a faster alley-oop." },
    { seq: 6, type: "job_state", state: "running", reason: "reopened by a change request (was done)" },
    { seq: 7, type: "merge", package: "court_exchange", files: ["data/tuning.json"] },
  ] as unknown as JobEvent[];
  assert.equal(changeBoundary(ev), 4);
  assert.equal(askedChange(ev)?.text, "Give my mates a faster alley-oop.");
  assert.equal(askedChange(ev)?.kind, "play", "the earlier fairness ask no longer colours it (lane T's item 40)");
  const card = whatChangedNote(ev, "0.1.2");
  assert.match(card, /asked "Give my mates a faster alley-oop\."; /);
  assert.doesNotMatch(card, /Make it fairer/);
  const notes = earlierUnmade(ev, "court_exchange", 3);
  assert.equal(notes.length, 1);
  assert.match(notes[0]?.text ?? "", /your earlier change "Make it fairer: the rivals are too strong\." ended NOT made \(all packages promoted; no merge since the last promotion/);
  // the promotion's own ending closes nothing; before a first version there is no boundary
  assert.equal(earlierUnmade(ev.slice(0, 3), "court_exchange", 3).length, 0);
  assert.equal(changeBoundary([{ seq: 1, type: "job_state", state: "failed", reason: "x" }] as unknown as JobEvent[]), -1);
});

test("D27b ruling 2: a package that asked again after an answer and ended NOT made (asktwice.ts) has its workspace dropped too", () => {
  const dir = tempDir("d27b-asktwice");
  fs.mkdirSync(path.join(dir, "ws", "harbour", "data"), { recursive: true });
  fs.writeFileSync(path.join(dir, "ws", "harbour", "data", "skin.json"), "{\"unmade\": true}\n");
  fs.writeFileSync(path.join(dir, "ws", "harbour.baseline.json"), "{}\n");
  fs.mkdirSync(path.join(dir, "ws", "skin"), { recursive: true });
  const appended: Record<string, unknown>[] = [];
  const plan = [{ id: "harbour", title: "harbour", milestone: "blockout", deps: [], scope: ["data/skin.json"], contract: "", acceptance: [] }] as unknown as PackageSpec[];
  const h = { s: { plan, packages: { harbour: { state: "running" } } }, pkg: () => ({ changes: ["Make the hull red."] }), append: (e: Record<string, unknown>) => (appended.push(e), e), dir: (...p: string[]) => path.join(dir, ...p) } as unknown as Parameters<typeof askedAgain>[0];
  const said = askedAgain(h, undefined, "harbour", 4, "Which red?", { question: "Which hull?", answer: "The big one." });
  assert.match(said, /the change was NOT made/);
  assert.ok(!fs.existsSync(path.join(dir, "ws", "harbour")), "the unmade round's workspace is gone");
  assert.ok(!fs.existsSync(path.join(dir, "ws", "harbour.baseline.json")));
  assert.ok(fs.existsSync(path.join(dir, "ws", "skin")), "another package's workspace stays");
});
