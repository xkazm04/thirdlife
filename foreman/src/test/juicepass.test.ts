// S2-juice (juice day, 27 Nov 2026): the standard juice pass for a person's change that adds a move (juicepass.ts).
// The sentences are real: J2's hammer, J19's shield moves and J5's jump from the night of 27 Nov; the robot job's 25 Nov
// changes (a look, teammates, a ball) are the changes that add no move. The same file runs in both arms of the spike:
// each case names the mode it means.
import { test } from "node:test";
import assert from "node:assert/strict";
import type { JobEvent } from "../events.js";
import { askedChange } from "../boundlift.js";
import { JUICE_MODE, JUICE_NOTE, JUICE_OFFER, addsMove, juiceNote, juiceNoteFor, juicePart, juicePassText, juiceRuns } from "../juicepass.js";

const HAMMER = "Give every robot a double-headed sledgehammer: hold F to charge, release to swing. The longer I charge, the higher and farther the hit robot flies, tumbling, with sparks, a clang. It drives the ball. Misses leave me open. Bots swing, dodge.";
const SHIELD = "Give every fighter two big moves. F is a shield charge: crouch behind the lowered shield for a moment, then sprint straight ahead three times as fast; everyone in the way is bowled over like pins.";
const KART = "Give my kart a jump on Q, like Rocket League: the tub crouches down on its springs for a moment, then hops about three metres up.";
const LOOP = "Give me a loop-the-loop on E: my plane pulls a big full vertical loop in about a second and a half.";
const NO_MOVE = [
  "Make it look like a sunny seaside rooftop: a pale green court with white lines, terracotta roof tiles around it.",
  "My teammates do too little: they should run into open space, call for the ball and pass it back to me.",
  "The ball is too small and the same yellow as my robots, so I keep losing it. Make it a big white football.",
  "The hammer is too strong: make it fairer.",
  "Move the camera higher and put the score plate at the top.",
  // Arsenal, 27 Nov night: a rule change to a move the game has (not a new move)
  "Change the rules of the match, not the drawing: the shield on F is no longer on a cooldown that brings it back. I start with one shield use. Picking up a boost gives me a new trick.",
  "I start the match with one shield bubble on F, and it no longer comes back by itself. When I have no trick, picking up a boost from a green spot gives me one.",
  // karts, 27 Nov night: the bots use a move the person added before (ask 1, not a new move)
  "The mint karts should use the air bump on me too: when I am at the ball, one of them jumps and crashes into me in the air.",
];

test("juice 1: a change that adds a move on a key runs the pass in arm A (auto), not in arm B (choice) unless picked", () => {
  for (const s of [HAMMER, SHIELD, KART, LOOP]) {
    assert.ok(addsMove(s), s);
    assert.equal(juiceRuns(s, "auto"), true, s);
    assert.equal(juiceRuns(s, "choice"), false, s);
    assert.equal(juiceRuns(`${s} Make it juicy.`, "choice"), true, s);
  }
});

test("juice 2: changes that add no move never run it on their own (a look, teammates, a ball, fairness, the camera)", () => {
  for (const s of NO_MOVE) {
    assert.equal(addsMove(s), false, s);
    assert.equal(juiceRuns(s, "auto"), false, s);
    assert.equal(juiceRuns(s, "choice"), false, s);
  }
});

test("juice 3: 'keep it plain' turns it off in arm A; 'make it juicy' turns it on in both, also on a follow-up", () => {
  assert.equal(juiceRuns(`${HAMMER} Keep it plain.`, "auto"), false);
  assert.equal(juiceRuns(`${HAMMER} No juice.`, "auto"), false);
  const followUp = 'Make it juicy: "Give every robot a double-headed sledgehammer"';
  assert.equal(juiceRuns(followUp, "auto"), true);
  assert.equal(juiceRuns(followUp, "choice"), true);
  assert.equal(juiceRuns("[foreman] wire in scripts/sim/hammer.gd: make it juicy", "auto"), false, "the Foreman's own follow-ups never run it");
});

test("juice 4: the builder gets the pass's text beside the change request; the person reads a note", () => {
  const part = juicePart(`CHANGE REQUEST: ${HAMMER} Make it juicy.`, "choice");
  assert.ok(part !== undefined && part.startsWith("JUICE PASS") && part === juicePassText());
  for (const k of ["SMALL", "BIG", "SIGNATURE", "TELL THAT GROWS", "EXAGGERATION", "IMPACT", "WORD MID-SCREEN", "SLOW BEAT", "WORLD ANSWERS", "JUICE: size"]) assert.ok(part.includes(k), k);
  assert.equal(juicePart(`CHANGE REQUEST: ${HAMMER}`, "choice"), undefined);
  assert.equal(juicePart(undefined, "auto"), undefined);
  assert.ok(juiceNote("core", "auto").startsWith(JUICE_NOTE) && juiceNote("core", "auto").includes("keep it plain"));
  assert.ok(juiceNote("core", "choice").includes("make it juicy"));
  assert.ok(JUICE_MODE === "auto" || JUICE_MODE === "choice");
  // the note a change gets when it is handed to its owner: ran (both arms), offered (arm B only, a move built plain)
  assert.ok(juiceNoteFor(HAMMER, "core", "auto")?.startsWith(`${JUICE_NOTE}:`));
  assert.ok(juiceNoteFor(HAMMER, "core", "choice")?.startsWith(`${JUICE_OFFER}:`));
  assert.ok(juiceNoteFor(`${HAMMER} Make it juicy.`, "core", "choice")?.startsWith(`${JUICE_NOTE}:`));
  assert.equal(juiceNoteFor(`${HAMMER} Keep it plain.`, "core", "auto"), undefined);
  assert.equal(juiceNoteFor(NO_MOVE[0] as string, "core", "choice"), undefined);
});

test("juice 5: a change the pass runs on also names what the pass adds, for the balance rows it touches", () => {
  const ev = (seq: number, e: Record<string, unknown>): JobEvent => ({ v: 1, seq, ts: "2026-11-27T08:00:00.000Z", job: "j", ...e }) as unknown as JobEvent;
  const events = [ev(1, { type: "promoted", packId: "game.x", version: "0.1.5", dest: "promoted/game.x@0.1.5" }), ev(2, { type: "change_requested", text: `${HAMMER} Make it juicy.` })];
  const asked = askedChange(events);
  assert.ok(asked !== undefined && asked.kind === "play" && /hit-stop/.test(asked.text) && /wind-up/.test(asked.text));
  const plain = askedChange([events[0] as JobEvent, ev(2, { type: "change_requested", text: "Make it look like a sunny seaside rooftop." })]);
  assert.ok(plain !== undefined && !/hit-stop/.test(plain.text));
});

// ---- round 2: the Foreman reads the builder's JUICE: line (juiceGaps / juiceMore). The lines are the real ones of
// round 1 (robots A core r13, shield A core r17, shield B-juicy core r17, robots B-juicy core r13 from its transcript).
const ROBOT_A = "JUICE: size big+signature | tell yes (4-step head heat, throbbing reach ring, rising engine sound, raised-hammer pose) | exaggeration yes (2.0–3.8 m, 1.5–3 turns; flight time unchanged) | hit-stop yes (5–9 frames) | camera yes (shake 0.25–0.45, lens narrowed 8° and back over 12 frames; no follow-up when you are launched) | word yes (BONK! / KA-BONK!! for 40 frames) | particles+sound yes | slow beat small (no camera close-in) | world answers yes (victim tumbles, drops the ball, the ball is driven, skittles reuse the existing rule)";
const SHIELD_A = "JUICE: size big | tell yes | exaggeration no | hit-stop yes | camera yes | word yes | particles+sound yes | slow beat no | world answers small";
const SHIELD_BJ = "JUICE: size big | tell yes (red lane rings that grow along the throw line in 4 steps) | exaggeration small (disc spin; no body launch) | hit-stop yes (8 f) | camera yes (shake plus 7° fov kick) | word yes | particles+sound yes | slow beat no | world answers yes";
const ROBOT_BJ = "JUICE: size big (signature at full charge) | tell yes: the head heats through 4 colour steps | exaggeration yes: 3.6–5.4 m up, 42–58 frames in the air, 1.5–3 turns | hit-stop yes: 5–9 frames on both bodies | camera yes: shake 0.25–0.45 m, lens kick 5–9° over 12 frames, and the camera follows you when you are launched | word yes | particles+sound yes | slow beat yes | world answers yes";

test("juice 6: the checklist line says which big parts were skipped (round 1's real lines)", async () => {
  const { juiceGaps } = await import("../juicepass.js");
  const a = juiceGaps(["JUICE: camera following you up when you are the one launched: not done (camera unchanged).", ROBOT_A]);
  assert.equal(a.length, 2, a.join(" / "));
  assert.ok(a[0]?.startsWith("the launch") && a[1]?.startsWith("the camera following"));
  assert.deepEqual(juiceGaps([SHIELD_A]).map((g) => g.split(" ")[1]), ["launch", "slow"]);
  assert.deepEqual(juiceGaps([SHIELD_BJ]).map((g) => g.split(" ")[1]), ["launch", "slow"]);
  assert.deepEqual(juiceGaps([ROBOT_BJ]), [], "everything made: no more round");
  assert.deepEqual(juiceGaps(["JUICE: size small | tell yes | exaggeration no | hit-stop yes | camera yes | word no | particles+sound yes | slow beat no | world answers no"]), [], "a small move gets a small pass");
  assert.deepEqual(juiceGaps(["the same as the list in my previous message."]), [], "no checklist line: nothing is assumed");
});

test("juice 7: after the merge of a pass round, a skipped big part sends ONE more round to the same package, with the pass", async () => {
  const { juiceMore, JUICE_MORE } = await import("../juicepass.js");
  const ev = (seq: number, e: Record<string, unknown>): JobEvent => ({ v: 1, seq, ts: "2026-11-27T12:00:00.000Z", job: "j", ...e }) as unknown as JobEvent;
  const events = [ev(10, { type: "reopened", package: "core", reason: "change request (event 9)" }), ev(12, { type: "note", package: "core", round: 17, text: `DEVIATIONS:\n- New action throw on G\n- ${SHIELD_A}` })];
  const out = juiceMore(events, "core", 17, `${SHIELD} Make it juicy.`, 10, "choice");
  assert.equal(out.length, 2);
  const req = out[1] as { type: string; package: string; text: string };
  assert.ok(req.type === "change_requested" && req.package === "core" && req.text.startsWith(`[foreman] ${JUICE_MORE}: core's JUICE: checklist`) && req.text.includes("the slow beat"));
  assert.ok(juicePart(`CHANGE REQUEST: ${req.text}`, "choice") === juicePassText(), "the follow-up round carries the pass");
  assert.deepEqual(juiceMore(events, "core", 18, req.text, 10, "choice"), [], "the follow-up's own merge sends nothing more");
  assert.deepEqual(juiceMore(events, "core", 17, SHIELD, 10, "choice"), [], "a plain change (arm B, not picked) is never sent back for juice");
  assert.equal(juiceMore(events, "core", 17, SHIELD, 10, "auto").length, 2, "arm A: the pass ran, so the check runs");
});
