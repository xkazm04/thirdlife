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
