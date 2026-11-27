// D27b item 26 (lane T2-editor; J2nd's kart copy, events 1517-1526): core r32 asked the person "Should the pack's own
// test get through three matches quicker with wider goals (about 9 m each side of centre instead of 7), or with a
// shorter match (2 minutes instead of 3)?". The job paused; the person answered "Neither ... Let your own check run
// longer instead of changing my game", and core then edited the frozen tofu bot, which the freeze undid. The Foreman's
// own test is never the person's question: a bot run that runs out of frames, or fits fewer matches than the test wants,
// in a person's play change is run again with three times the frames (tofugate.ts longerMatch, lane T's item (b)). The
// Foreman answers such a question itself (an `answer` by "foreman"), the builder goes on in the same round, and the
// person never sees a question.
import type { JobEvent, PackageSpec } from "./events.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import { tofuOf } from "./tofu.js";

/** Words of a question about the Foreman's own test (the tofu bot, the pack's own test, a check that must fit or pass). */
const OWN_TEST = /\b(the pack's own (test|check|bot)|the foreman's (own )?(test|check|bot|measure)|tofu (bot|test|check)|(own|the) (test|check|bot)s? (get through|fits?|pass(es)?|finish(es)?|runs? out)|so (that )?the (test|check|bot) (fits|passes|finishes)|(test|check|bot)'s (frame|frames|budget)|frame budget of the (test|check|bot))\b/i;

/** The start of the Foreman's note (after FOREMAN_NOTE) when it answered a question about its own test itself. */
export const ANSWERED_OWN = "answered for you";

/** The Foreman's own answer to a builder's question about its test. */
export const OWN_TEST_ANSWER = "The Foreman answers this itself: its own tests are never a reason to change the game, and the person is not asked about them. Keep the game as the person asked (no goals, match length, scoring or rules changed for a test's sake) and never edit the tofu bot. A bot run that runs out of its frames, or fits fewer matches than the test wants, in a play change is run once more by the Foreman with three times the frames. Make the person's change, and say under DEVIATIONS what the test measured.";

/** Is the builder's question about the Foreman's own test (its words, or the plan's tofu bot's path)? */
export function asksOwnTest(plan: readonly PackageSpec[], question: string): boolean {
  const tofu = tofuOf(plan as PackageSpec[])?.test;
  return OWN_TEST.test(question) || (tofu !== undefined && question.includes(tofu));
}

/** The events that answer such a question for the person (question, the Foreman's answer, a note); undefined otherwise. */
export function ownTestAnswer(plan: readonly PackageSpec[], id: string, round: number, question: string): Record<string, unknown>[] | undefined {
  if (!asksOwnTest(plan, question)) return undefined;
  return [
    { type: "question", package: id, text: question },
    { type: "answer", package: id, text: OWN_TEST_ANSWER, by: "foreman" },
    { type: "note", package: id, round, text: `${FOREMAN_NOTE}${ANSWERED_OWN}: ${id} asked about the Foreman's own test ("${clip(question, 300)}"); the Foreman answered it itself and did not ask you: the game stays as you asked, and a test that needs more frames gets them from the Foreman.` },
  ];
}

/** An answer the Foreman gave itself (not the person's word in this change). */
export const foremanAnswered = (e: JobEvent): boolean => e.type === "answer" && e.by === "foreman";
