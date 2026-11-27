// N27 of the night of 27 Nov 2026 (lane T, the tofu gate): a person's change is built as asked and the balance it moves
// is a note to the person; the bounds it did not touch still guard; the Foreman's measures are the Foreman's; a rule
// nobody asked for is listed on the what-changed card. Each test failed on main e66eb94e (no such notes, the gate
// refused) and passes now. Sentences are the ones lanes sent on 25 Nov (G19) and tonight (J4).
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir } from "./helpers.js";
import type { Acceptance, JobEvent, PackageSpec } from "../events.js";
import type { GateHost } from "../p10gate.js";
import type { VerifyResult } from "../verifier.js";
import { longerMatch, onlyOutOfFrames, tofuGate } from "../tofugate.js";
import { blameFinal, sendBackFinal } from "../p10gate.js";
import { tofuLine } from "../tofu.js";
import { BALANCE_MOVED, BALANCE_SKIPPED, askedChange, changeKind } from "../boundlift.js";
import { keepMeasures, measureTests, runHandChecks, MEASURE_KEPT } from "../handcheck.js";
import { UNASKED_RULE, whatChangedNote } from "../fastchange.js";
import { REPO_ROOT } from "../paths.js";

after(cleanup);

const G19_CAMERA = "Make the view and the screen like my picture. The camera sits low behind my captain, about head height and a few steps back, looking down the court to the sea gate, so my captain is big at the bottom and I see the others in front of him; a glowing teal ring under my captain's feet. At the top a small score plate: blue score, the clock, gold score. Bottom left three key buttons: RMB BLOCK, LMB BASH, Q CALL. Show the Q captain's call hint only when the call is ready. And a clear blue noon sky instead of the sunset.";
const J4_DUNK = "Give it NBA Jam dunks on a new key F: hold F with the ball to crouch and charge, release to leap three or four times higher than a normal jump with long hang time; from inside the free-throw line you fly all the way to the rim and slam it, with a slow-motion beat at the rim, the rim and the camera shaking, a burst at the net, the crowd and the score flashing, and you hang on the rim.";
const HAMMER = "Give every robot a double-sledged hammer: hold to wind up, release to swing; a robot it hits is launched across the pitch and tumbles. The rivals use it too.";

test("N27 1: the person's words are read clause by clause: a play change, a view change, a look change, a fairer change", () => {
  assert.equal(changeKind(G19_CAMERA), "view", "G19 core r11: camera, score plate, key buttons, hints and the sky are the view");
  assert.equal(changeKind(J4_DUNK), "play", "J4: a dunk is play, though the camera shakes with it");
  assert.equal(changeKind(HAMMER), "play");
  assert.equal(changeKind("Quilted jackets for the sailors and gold shields with a white wave."), "look");
  assert.equal(changeKind("Make it fairer: the hammer side wins too often."), "fair");
  assert.equal(changeKind("Make it more fun."), "play", "words the Foreman cannot place are built as asked");
  assert.equal(changeKind("Make Bram's slam brutal and unfair on purpose: triple damage to my captain."), "play", "asking for an unfair game is a play change, not a fairness ask");
});

// a design-room job with a tofu stage: one promoted version, then a change request, then the core's round
const PLAN = [{ id: "core", title: "core", milestone: "blockout", deps: [], scope: ["scripts/**", "tests/**"], contract: tofuLine({ id: "duel" } as never), registers: { tests: ["tests/bot_tofu.gd"] }, acceptance: [{ level: "V4", verb: "bot", args: ["--test=tests/bot_tofu.gd"] }] }] as unknown as PackageSpec[];
// rounds under metrics.raw, as G19's tofu bot writes them (final-bot-bot_tofu-s580.json)
const GOOD = { feedback_f: 1, skill_spread: 0.6, skill_variants: 4, idle_max_f: 58, tell_min_f: 21, tells: 72, pressure_waves: 8, lead_change_share: 1, close_rounds: 1, verbs_used: 6, contact_types: 11, one_sided_contacts: 0, raw: { rounds: [{ winner: "crew" }, { winner: "gulls" }, { winner: "crew" }] } };

function job(change: string | undefined, promoted = true) {
  const dir = tempDir("n27-tofu");
  fs.mkdirSync(path.join(dir, "reports"), { recursive: true });
  fs.writeFileSync(path.join(dir, "reports", "final-bot-bot_tofu-s5.json"), JSON.stringify({ bot: { test: "tests/bot_tofu.gd", done: true, result: { ok: true, metrics: GOOD } } }));
  const events = [
    { seq: 5, type: "verify", round: 1, level: "V4", verb: "bot", ok: true, report: "reports/final-bot-bot_tofu-s5.json" },
    ...(promoted ? [{ seq: 6, type: "promoted", packId: "game.x", version: "0.1.0", dest: "promoted/game.x" }] : []),
    ...(change !== undefined ? [{ seq: 7, type: "change_requested", text: change }] : []),
  ] as unknown as JobEvent[];
  const appended: Record<string, unknown>[] = [];
  const h = {
    s: { plan: PLAN, brief: { concept: { template: { id: "duel" } }, design: { verbs: [1, 2, 3, 4, 5, 6] } }, reactions: {}, lastSeq: 9 },
    events,
    pkg: () => ({ round: 11, roundBase: 11 }),
    dir: (...p: string[]) => path.join(dir, ...p),
    rel: (abs: string) => path.relative(dir, abs).split(path.sep).join("/"),
    append: (e: Record<string, unknown>) => (appended.push(e), events.push({ seq: 100 + appended.length, ...e } as unknown as JobEvent), e as unknown as JobEvent),
  } as unknown as GateHost;
  return { h, appended, dir };
}
const bot = (metrics: Record<string, unknown>, dir: string) => ({ verb: "bot", level: "V4", ok: true, report: { bot: { test: "tests/bot_tofu.gd", done: true, result: { ok: true, metrics } } }, reportFile: path.join(dir, "reports", "core-r11-bot.json"), verdictFile: "", flags: [], summary: "bot passed", durationMs: 1 }) as unknown as VerifyResult;
const A = { verb: "bot" as const, args: ["--test=tests/bot_tofu.gd"] };
const ONE_SIDED = { ...GOOD, close_rounds: 0, lead_change_share: 0, skill_spread: 1, skill_variants: 2, rounds: [{ winner: "crew" }, { winner: "crew" }, { winner: "crew" }] };

test("N27 2 (J4 court_exchange r8, event 926: the dunk built cleanly and was refused on skill_spread 1 and skill_variants 2): a play change that moves the balance rows is built as asked, with a plain-words note", () => {
  const j = job(J4_DUNK);
  assert.equal(tofuGate(j.h, "core", A, bot(ONE_SIDED, j.dir)), undefined, "the round passes: the person asked for it");
  const note = String(j.appended.find((e) => String(e["text"]).startsWith(BALANCE_MOVED))?.["text"]);
  assert.match(note.split("\n")[0] ?? "", /^\[foreman\] balance moved by your change: built as you asked; the crew side now wins 3 of 3 of the Foreman's test rounds \(was 2 of 3\)\. Say "make it fairer" to tune it\.$/);
  assert.match(note, /close_rounds 0 \(was 1\), the Foreman's bound 1 or more/);
  assert.match(note, /skill_spread 1 \(was 0\.6\)/);
  // the same figures before any version are the tofu stage: refused as before
  const first = job(undefined, false);
  assert.match(tofuGate(first.h, "core", A, bot(ONE_SIDED, first.dir))?.summary ?? "", /close_rounds 0 \(the plan's bound: >= 1\)/);
});

test("N27 3: a bound the change did not touch still guards: a regression is refused, a row already out before the change is not its regression", () => {
  // a play change that breaks feedback within 3 frames (no word of it names a delay): refused
  const j = job(HAMMER);
  const f = tofuGate(j.h, "core", A, bot({ ...ONE_SIDED, feedback_f: 9 }, j.dir));
  assert.match(f?.summary ?? "", /feedback_f 9 \(the plan's bound: <= 3\)/);
  assert.match(f?.summary ?? "", /did not ask to move them: keep what the person asked/);
  assert.doesNotMatch(f?.summary ?? "", /close_rounds/, "the rows the change moved are not in the refusal");
  // a look change that makes the rounds one-sided: the balance rows guard
  const look = job("Quilted jackets for the sailors and gold shields with a white wave.");
  assert.match(tofuGate(look.h, "core", A, bot(ONE_SIDED, look.dir))?.summary ?? "", /close_rounds 0/);
  // the hammer launches robots: idle rivals are what it asked for (a tumble), so idle_max_f is moved, not refused
  const idle = job(HAMMER);
  assert.equal(tofuGate(idle.h, "core", A, bot({ ...GOOD, idle_max_f: 300 }, idle.dir)), undefined);
  // a row already outside before the change: not this change's regression
  const was = job("Quilted jackets for the sailors.");
  fs.writeFileSync(path.join(was.dir, "reports", "final-bot-bot_tofu-s5.json"), JSON.stringify({ bot: { test: "tests/bot_tofu.gd", done: true, result: { ok: true, metrics: { ...GOOD, tell_min_f: 12 } } } }));
  assert.equal(tofuGate(was.h, "core", A, bot({ ...GOOD, tell_min_f: 12 }, was.dir)), undefined);
  assert.match(String(was.appended.find((e) => String(e["text"]).includes("already outside"))?.["text"]), /tell_min_f \(was 12, bound 20 or more\)/);
});

test("N27 4 (G19 core r11: the camera, score plate and keys were refused on skill_spread 1, lead_change_share 0, close_rounds 0): a camera- or HUD-only change skips the balance check", () => {
  const j = job(G19_CAMERA);
  assert.equal(tofuGate(j.h, "core", A, bot(ONE_SIDED, j.dir)), undefined);
  assert.match(String(j.appended.find((e) => String(e["text"]).startsWith(BALANCE_SKIPPED))?.["text"]), /a change to the view or the screen only; tests\/bot_tofu\.gd figures outside their bounds, not judged: skill_spread 1/);
  assert.equal(j.appended.filter((e) => String(e["text"]).startsWith(BALANCE_MOVED)).length, 0, "no balance note to the person: nothing they asked moved it");
  assert.equal(askedChange(j.h.events)?.kind, "view");
});

test("N27 5 (G4; G19 core r5 changed tests/bot_tofu.gd; J11 biplane r16 edited tests/support/pilot.gd, which the bot loads): the tofu bot and the scripts it loads are the Foreman's once merged; an edit is undone and named", () => {
  const dir = tempDir("n27-measure");
  const ws = path.join(dir, "ws", "core");
  for (const d of [path.join(dir, "pack", "tests"), path.join(ws, "tests"), path.join(dir, "ref", "cards")]) fs.mkdirSync(d, { recursive: true });
  fs.copyFileSync(path.join(REPO_ROOT, "engine", "cards", "team_possession.json"), path.join(dir, "ref", "cards", "team_possession.json"));
  fs.writeFileSync(path.join(dir, "pack", "tests", "bot_tofu.gd"), "policy A\n\tpilot = ctx.load_script(\"tests/support/pilot.gd\").new()\n");
  fs.writeFileSync(path.join(ws, "tests", "bot_tofu.gd"), "policy B: wait for the rival to whiff\n");
  for (const d of [path.join(dir, "pack", "tests", "support"), path.join(ws, "tests", "support")]) fs.mkdirSync(d, { recursive: true });
  fs.writeFileSync(path.join(dir, "pack", "tests", "support", "pilot.gd"), "roll share 0.5\n");
  fs.writeFileSync(path.join(ws, "tests", "support", "pilot.gd"), "roll share 0.6\n");
  fs.writeFileSync(path.join(ws, "tests", "bot_hand_newcomer.gd"), "a hand test not merged yet\n");
  const appended: Record<string, unknown>[] = [];
  const h = { s: { plan: PLAN, card: "card.team_possession" }, dir: (...p: string[]) => path.join(dir, ...p), append: (e: Record<string, unknown>) => (appended.push(e), e) } as unknown as GateHost;
  assert.deepEqual(measureTests(h), ["tests/bot_tofu.gd", "tests/support/pilot.gd"]);
  assert.deepEqual(keepMeasures(h, "core", 5, ws), ["tests/bot_tofu.gd", "tests/support/pilot.gd"]);
  assert.match(fs.readFileSync(path.join(ws, "tests", "bot_tofu.gd"), "utf8"), /^policy A\n/, "the builder's policy is undone");
  assert.equal(fs.readFileSync(path.join(ws, "tests", "support", "pilot.gd"), "utf8"), "roll share 0.5\n", "the pilot the bot loads is undone too (J11 r16)");
  assert.equal(fs.readFileSync(path.join(ws, "tests", "bot_hand_newcomer.gd"), "utf8"), "a hand test not merged yet\n", "a hand test is not a frozen measure (yet)");
  assert.match(String(appended[0]?.["text"]), new RegExp(`^${MEASURE_KEPT.replace(/[[\]]/g, "\\$&")}: tests/bot_tofu\\.gd, tests/support/pilot\\.gd are measures the Foreman judges by`));
  assert.deepEqual(keepMeasures(h, "core", 6, ws), [], "nothing to undo the second time");
});

test("N27 6 (G19 core r12: \"Gull blows on the controlled captain now do 2.0 times damage\", \"New comeback rule not in the contract\"): the what-changed card lists each rule the person did not ask for, and the balance their change moved", () => {
  const r12 = "- Gull blows on the controlled captain now do 2.0 times damage (was 1.0). This is `gulls_on_captain_k`, a new value with a slider from 1 to 2.5.\n- New comeback rule not in the contract: a crew behind on rounds deals extra damage, 1 + 1.5 per round behind (`roused_k`). A hint at round start names which side is roused.\n- Fallen figures are now rebuilt one per frame over the last 12 frames of the between-round pause.\nRULE: after a bash the basher's next swing is 20 % faster";
  const events = [
    { seq: 1, type: "promoted", packId: "game.x", version: "0.1.3", dest: "promoted/game.x" },
    { seq: 2, type: "change_requested", text: HAMMER },
    { seq: 3, type: "note", package: "core", round: 12, text: r12 },
    { seq: 4, type: "note", package: "core", round: 12, text: `${BALANCE_MOVED}: built as you asked; the crew side now wins 3 of 3 of the Foreman's test rounds (was 2 of 3). Say "make it fairer" to tune it.\nfigures (...)` },
    { seq: 5, type: "merge", package: "core", files: ["scripts/contact.gd"] },
  ] as unknown as JobEvent[];
  const card = whatChangedNote(events, "0.1.4");
  const lines = card.split("\n");
  assert.ok(lines.includes(`balance moved by your change: built as you asked; the crew side now wins 3 of 3 of the Foreman's test rounds (was 2 of 3). Say "make it fairer" to tune it.`));
  const rules = lines.filter((l) => l.startsWith(UNASKED_RULE));
  assert.equal(rules.length, 3, lines.join("\n"));
  assert.match(rules[0] ?? "", /2\.0 times damage/);
  assert.match(rules[1] ?? "", /comeback rule not in the contract/);
  assert.match(rules[2] ?? "", /^unasked rule \(the builder's words; you did not ask for it\): after a bash the basher's next swing is 20 % faster$/);
  assert.ok(!rules.some((l) => /Fallen figures/.test(l)), "an ordinary line is not a rule");
});

test("N27 7: the card's hand check in a play change is a note, not a refusal; the idle hand and a look change still guard", async () => {
  const run = async (change: string, wins: Record<string, number>) => {
    const dir = tempDir("n27-hands");
    for (const d of [path.join(dir, "pack"), path.join(dir, "ref", "cards"), path.join(dir, "reports")]) fs.mkdirSync(d, { recursive: true });
    fs.copyFileSync(path.join(REPO_ROOT, "engine", "cards", "team_possession.json"), path.join(dir, "ref", "cards", "team_possession.json"));
    fs.writeFileSync(path.join(dir, "pack", "pack.json"), JSON.stringify({ id: "game.x", version: "0.1.1", kernelApi: "1.0", tests: ["tests/bot_hand_newcomer.gd", "tests/bot_hand_perfect.gd"] }));
    fs.writeFileSync(path.join(dir, "reports", "hand-checks-s4.json"), JSON.stringify({ schema: "tl.hand-checks/1", rows: [{ hand: "newcomer", wins: 15, seeds: 20 }, { hand: "perfect", wins: 20, seeds: 20 }] }));
    const appended: Record<string, unknown>[] = [];
    const events = [{ seq: 6, type: "promoted" }, { seq: 7, type: "change_requested", text: change }] as unknown as JobEvent[];
    const h = {
      s: { plan: [{ id: "teams", registers: { tests: ["tests/bot_hand_newcomer.gd", "tests/bot_hand_perfect.gd"] } }], packages: { teams: { round: 3 } }, card: "card.team_possession", lastSeq: 40 },
      events,
      dir: (...p: string[]) => path.join(dir, ...p),
      append: (e: Record<string, unknown>) => (appended.push(e), e),
      verifyLogged: async (a: { args: string[] }) => {
        const hand = /bot_hand_(\w+)\.gd/.exec(a.args[0] ?? "")?.[1] ?? "";
        const seed = Number(/--seed=(\d+)/.exec(a.args[1] ?? "")?.[1]);
        return { ok: true, report: { bot: { done: true, result: { won: seed <= (wins[hand] ?? 0) } } } };
      },
    } as unknown as GateHost;
    return { ...(await runHandChecks(h, path.join(dir, "pack"))), appended };
  };
  const hard = await run(HAMMER, { newcomer: 6, perfect: 20 });
  assert.equal(hard.failure, "", "built as asked: promoted");
  assert.match(String(hard.appended[0]?.["text"]), /^\[foreman\] balance moved by your change: built as you asked; a newcomer player now wins 6 of 20 \(was 15 of 20\)\. Say "make it fairer" to tune it\./);
  assert.equal(hard.appended[0]?.["package"], "teams");
  const look = await run("Gold shields and quilted jackets.", { newcomer: 6, perfect: 20 });
  assert.match(look.failure, /newcomer: 6 of 20 won/, "a look change that makes the game hard for a newcomer is refused as before");
});

// ---------------------------------------------------------------- T2: J2's final-verification loop

const OUT_OF_FRAMES = { checks: [{ id: "bot.completed", ok: false, detail: "frame_budget: not done within 36000 frames" }, { id: "bot.ok", ok: false, detail: "3 matches" }], bot: { test: "tests/bot_tofu.gd", done: false, frames: 36000 } };

test("N27 T2 1 (J2 robots, event 1017: the hammer made matches about 4.5 min and core's three-match tofu bot ran out of 36,000 frames): in a person's play change a bot that only ran out of frames runs again with three times the frames, and the person is told", async () => {
  const events = [{ seq: 6, type: "promoted" }, { seq: 7, type: "change_requested", text: HAMMER }] as unknown as JobEvent[];
  const appended: Record<string, unknown>[] = [];
  const h = { s: { plan: PLAN, packages: { core: { round: 16 } } }, events, append: (e: Record<string, unknown>) => (appended.push(e), e) } as unknown as GateHost;
  const failed = { verb: "bot", level: "V4", ok: false, report: OUT_OF_FRAMES, summary: "bot failed" } as unknown as VerifyResult;
  assert.equal(onlyOutOfFrames(failed), true);
  const asked: string[][] = [];
  const done = await longerMatch(h, A, failed, { round: 1 }, async (args) => (asked.push(args), { verb: "bot", level: "V4", ok: true, report: { bot: { test: "tests/bot_tofu.gd", done: true, frames: 48600 } }, summary: "bot passed" }) as unknown as VerifyResult);
  assert.deepEqual(asked, [["--test=tests/bot_tofu.gd", "--frames=108000"]]);
  assert.equal(done?.ok, true, "the run with the frames it needs counts");
  assert.match(String(appended[0]?.["text"]), /^\[foreman\] balance moved by your change: built as you asked; matches now run longer \(the Foreman's test needed about 1\.4 times the frames it planned\)\. Say "make matches shorter" to tune it\./);
  // a match that never ends stays a failure
  const never = await longerMatch(h, A, failed, { round: 1 }, async () => ({ ...failed, report: { ...OUT_OF_FRAMES, bot: { ...OUT_OF_FRAMES.bot, frames: 108000 } } }) as unknown as VerifyResult);
  assert.equal(never?.ok, false);
  assert.match(never?.summary ?? "", /not done with 108000 frames either/);
  // not in a play change, or not only frames: the run stands as it was
  const look = { ...h, events: [{ seq: 6, type: "promoted" }, { seq: 7, type: "change_requested", text: "Paint the robots gold." }] } as unknown as GateHost;
  assert.equal(await longerMatch(look, A, failed, { round: 1 }, async () => assert.fail("no rerun")), undefined);
  const crashed = { ...failed, report: { ...OUT_OF_FRAMES, checks: [...OUT_OF_FRAMES.checks, { id: "smoke.no_script_errors", ok: false, detail: "1 error" }] } } as unknown as VerifyResult;
  assert.equal(await longerMatch(h, A, crashed, { round: 1 }, async () => assert.fail("no rerun")), undefined);
});

/** A J2-shaped log: core's tofu bot passed at 980, show merged at 1011 (a control run cleared it at 1006), final fails at 1017. */
function finalJob(extra: Record<string, unknown>[]) {
  const dir = tempDir("n27-final");
  fs.mkdirSync(path.join(dir, "reports"), { recursive: true });
  for (const f of ["pass-980.json", "final-1017.json"]) fs.writeFileSync(path.join(dir, "reports", f), JSON.stringify({ bot: { test: "tests/bot_tofu.gd" } }));
  const events = [
    { seq: 900, type: "promoted" },
    { seq: 930, type: "change_requested", text: HAMMER },
    { seq: 960, type: "merge", package: "core", files: ["scripts/sim/hammer.gd"] },
    { seq: 980, type: "verify", round: 3, level: "V4", verb: "bot", ok: true, report: "reports/pass-980.json", package: "brain" },
    { seq: 1006, type: "note", package: "show", round: 2, text: "[foreman] pack test fails without this merge too: tests/bot_tofu.gd, a test of package core, fails on the whole pack with the round-2 files of show merged in (x) and fails without them as well (control run: y). Not caused by this merge, which goes on; core is the package to look at." },
    { seq: 1011, type: "merge", package: "show", files: ["data/show.json"] },
    ...extra,
  ] as unknown as JobEvent[];
  const appended: Record<string, unknown>[] = [];
  const reopened: string[] = [];
  const pkgs = { core: { state: "promoted", round: 16, mergedFiles: ["scripts/sim/hammer.gd"] }, show: { state: "promoted", round: 2, mergedFiles: ["data/show.json"] } };
  const h = {
    o: { roundLimit: 4 },
    s: { plan: [{ id: "core", registers: { tests: ["tests/bot_tofu.gd"] } }, { id: "show", registers: { tests: [] } }], packages: pkgs, promotions: [{}], order: ["core", "show"] },
    events,
    pkg: (id: string) => pkgs[id as keyof typeof pkgs],
    dir: (...p: string[]) => path.join(dir, ...p),
    rel: (abs: string) => path.relative(dir, abs).split(path.sep).join("/"),
    append: (e: Record<string, unknown>) => (appended.push(e), e),
    reopen: (id: string) => reopened.push(id),
  } as unknown as GateHost;
  const vr = { verb: "bot", level: "V4", ok: false, report: OUT_OF_FRAMES, reportFile: path.join(dir, "reports", "final-1017.json"), summary: "bot failed: failed checks [bot.completed, bot.ok]" } as unknown as VerifyResult;
  return { h, appended, reopened, vr };
}
const FINAL_A = { level: "V4", verb: "bot", args: ["--test=tests/bot_tofu.gd"] } as unknown as Acceptance;

test("N27 T2 2 (J2 events 1006 and 1018: a control run showed core's test fails without show's files, and the final verification still sent it to show, four times): a package a control run cleared is not blamed; the test's owner takes it", () => {
  const j = finalJob([]);
  assert.equal(blameFinal(j.h, FINAL_A, j.vr)?.id, "core");
  assert.match(blameFinal(j.h, FINAL_A, j.vr)?.how ?? "", /show is cleared \(a control run showed tests\/bot_tofu\.gd fails without its files too \(event 1006\)\)/);
  assert.equal(sendBackFinal(j.h, FINAL_A, j.vr), "sent");
  assert.deepEqual(j.reopened, ["core"]);
});

test("N27 T2 3 (J2 event 1022, show r3: \"No change made ... nothing in my scope can fix the cause\"): a builder's nothing-in-my-part answer stops the loop and the person is told why", () => {
  // core was sent the check and answered that nothing in its part can fix it: nobody is left
  const j = finalJob([
    { seq: 1018, type: "reopened", package: "core", reason: "FINAL VERIFICATION FAILED (1 of 4) at bot (V4) --test=tests/bot_tofu.gd [report: r]. Sent back to core: ..." },
    { seq: 1022, type: "note", package: "core", round: 17, text: "- No change made. The failing check is the tofu bot running out of frames; nothing in my scope can fix the cause without working around the check." },
  ]);
  assert.equal(blameFinal(j.h, FINAL_A, j.vr), undefined);
  assert.equal(sendBackFinal(j.h, FINAL_A, j.vr), "spent", "the loop stops: the change ends on the earlier version");
  assert.deepEqual(j.reopened, []);
  assert.match(String(j.appended[0]?.["text"]), /^\[foreman\] change not finished: the game's check tests\/bot_tofu\.gd still fails .*no part of the game is left that can fix it: show: a control run .*; core: its builder answered: "No change made\. The failing check is the tofu bot running out of frames; nothing in my scope can fix the cause/);
});

test("N27 T2 4 (J2's copy, event 1146: \"close test rounds: now 0, was 0\" was told to the person as their change's doing): a row already outside before the change gets no balance note", () => {
  const j = job(HAMMER);
  fs.writeFileSync(path.join(j.dir, "reports", "final-bot-bot_tofu-s5.json"), JSON.stringify({ bot: { test: "tests/bot_tofu.gd", done: true, result: { ok: true, metrics: { ...GOOD, close_rounds: 0 } } } }));
  assert.equal(tofuGate(j.h, "core", A, bot({ ...GOOD, close_rounds: 0 }, j.dir)), undefined);
  assert.equal(j.appended.filter((e) => String(e["text"]).startsWith(BALANCE_MOVED)).length, 0);
  assert.match(String(j.appended.find((e) => String(e["text"]).includes("already outside"))?.["text"]), /close_rounds \(was 0, bound 1 or more\)/);
});

test("N27 T2 5 (J2's copy, core r16 refused on tells 2 < 3 after \"hold F to raise it, release to swing\"): a new attack move with its own wind-up moves the tells the frozen bot counts; a look change still guards them", () => {
  const j = job("Give every robot a double-headed sledgehammer: hold F to raise it, release to swing. A hit launches a robot far, tumbling.");
  assert.equal(tofuGate(j.h, "core", A, bot({ ...GOOD, tells: 2 }, j.dir)), undefined);
  const look = job("Paint the robots gold.");
  assert.match(tofuGate(look.h, "core", A, bot({ ...GOOD, tells: 2 }, look.dir))?.summary ?? "", /tells 2 \(the plan's bound: >= 3\)/);
});
