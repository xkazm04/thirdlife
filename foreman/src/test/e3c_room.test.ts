// E3c of 25 Nov (lane E5's real-adapter proof found both): (1) the concept step turned the plain sentence "3 against 3
// hockey on a small pond rink" into candidate 4 of 5 ("each goal drafts you to the team you beat", likelihood 0.08), so
// the person dropped four aspects by hand: a standard job whose words name a known game and ask for no twist now
// chooses the faithful reading, candidate 1; (2) the greybox critic judged aspects the person had DROPPED: the critic's
// prompt now carries the person's drops, keep-notes and chosen alternatives, and says a dropped aspect is not judged.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { FakeBuilder } from "../builder/fake.js";
import { conceptStep } from "../room.js";
import { asksForTwist, faithfulProblems } from "../concepts.js";
import { criticRubric, personDecisionsText } from "../phases.js";
import { critic, DEFAULT_RUBRIC } from "../designer.js";
import type { JobState } from "../joblog.js";
import type { Concept } from "../events.js";
import { cleanup, sampleConcept, tempDir, v2Brief } from "./helpers.js";

after(cleanup);

const POND = "3 against 3 hockey on a small pond rink";
const rinkT = { id: "rink_sport" as const, reference: "thirdjam's match on the rink core", copies: ["thirdjam's match on the rink core, unchanged: skating, puck, bots", "the cartridge keys it changes: rink size, team size", "the skin: title and team colours"] };
/** The real proof's answer, in shape: five candidates, the twist chosen. */
const twisted = (): Concept => ({
  ...sampleConcept(),
  template: rinkT,
  candidates: [
    { pitch: "Three-a-side pond hockey, quick passes on small ice.", likelihood: 0.7 },
    { pitch: "Pond hockey at dusk against a village team.", likelihood: 0.3 },
    { pitch: "A frozen-lake tournament, three rounds to the cup.", likelihood: 0.2 },
    { pitch: "Each goal drafts you to the team you beat.", likelihood: 0.08 },
    { pitch: "The pond shrinks as the ice melts each minute.", likelihood: 0.05 },
  ],
  chosen: 3,
});

test("E3c concept: a plain sentence that names a known game keeps the faithful candidate 1; a twist is refused and the step asks again", async () => {
  assert.equal(asksForTwist(POND), false);
  assert.deepEqual(faithfulProblems({ ...twisted(), chosen: 0 }, POND, undefined, "rink_sport"), []);
  const p = faithfulProblems(twisted(), POND, undefined, "rink_sport");
  assert.ok(p.some((x) => x.includes('choose the faithful reading, "chosen": 0, not candidate 4 ("Each goal drafts you to the team you beat."')), p.join("\n"));
  assert.ok(faithfulProblems({ ...twisted(), chosen: 0, candidates: twisted().candidates.map((c, i) => (i === 3 ? { ...c, likelihood: 0.9 } : c)) }, POND, undefined, "rink_sport").some((x) => x.includes("give it the highest likelihood")));
  // The person's words leave the twist open, the job is crazy, or no known game is named: the choice stays free.
  // (E3g: a sentence that names its OWN twist, "where every goal swaps the teams", is taken at its word: e3g.test.ts.)
  assert.ok(asksForTwist("pond hockey with a crazy twist"));
  assert.deepEqual(faithfulProblems(twisted(), "pond hockey with a crazy twist", undefined, "rink_sport"), []);
  assert.deepEqual(faithfulProblems(twisted(), POND, "crazy", "rink_sport"), []);
  assert.deepEqual(faithfulProblems(twisted(), "a paddle game on a walled court", undefined, undefined), []);

  const b = new FakeBuilder({ steps: [{ match: { role: "concept", attempt: 1 }, json: { concept: twisted() } }, { match: { role: "concept" }, json: { concept: { ...twisted(), chosen: 0 } } }] });
  const res = await conceptStep(b, { sentence: POND }, { sentence: POND, creativity: "STANDARD", engine: "", cards: "" }, { attempts: 2 });
  assert.ok(res.ok, res.ok ? "" : res.reason);
  assert.equal(res.ok && res.value.concept.chosen, 0, "the faithful reading is the concept");
  assert.equal(res.ok && res.value.concept.candidates[3]?.pitch, "Each goal drafts you to the team you beat.", "the twist stays an offered alternative");
  const second = b.calls.filter((c) => c.req.meta?.role === "concept")[1]?.req.prompt ?? "";
  assert.match(second, /# Your previous answer was rejected[^]*choose the faithful reading/);
  assert.match(b.calls[0]?.req.prompt ?? "", /A plain sentence is taken at its word/);
});

test("E3c critic: the person's drops, keep-notes and chosen alternatives ride in every look's prompt, and a dropped aspect is not judged", async () => {
  const brief = v2Brief();
  const s = { phases: [], brief, reactions: { rival: { choice: "drop", note: "no rival, I play the walls", seq: 9 }, court: { choice: "keep", note: "keep the walls high", seq: 10 }, paddle: { choice: "spinner", seq: 11 } } } as unknown as JobState;
  const text = personDecisionsText(s);
  assert.match(text, /DROPPED "Rival Rex" \(A greedy paddle that lunges at every ball\) \(the person's note: "no rival, I play the walls"\)/);
  assert.match(text, /KEPT "Walled court" \(the person's note: "keep the walls high"\)/);
  assert.match(text, /CHOSE "A spinning bat" instead of "Your paddle"/);
  assert.match(text, /never score any item down or call the look NOT ok because it is missing/);
  const rubric = criticRubric(s, "core");
  assert.deepEqual(rubric.map((r) => r.id), [...DEFAULT_RUBRIC.map((r) => r.id), "fun_promise"], "no new score to answer: the decisions ride on the promise item");
  assert.ok(rubric[4]?.text.includes(text));
  assert.equal(personDecisionsText({ brief, reactions: {} }), "", "no reaction, no decisions line");
  assert.equal(criticRubric({ ...s, reactions: {} } as JobState, "core")[4]?.text.includes("DECISIONS"), false);
  // The critic's prompt as it is sent.
  const img = path.join(tempDir("e3c-critic"), "look.png");
  fs.writeFileSync(img, "png");
  const scores = Object.fromEntries(rubric.map((r) => [r.id, 0.8]));
  const b = new FakeBuilder({ steps: [{ match: { role: "critic" }, json: { ok: true, scores, notes: ["fine"] } }] });
  const res = await critic(b, [img], rubric);
  assert.ok(res.ok);
  assert.match(b.calls[0]?.req.prompt ?? "", /THE PERSON'S DECISIONS[^]*DROPPED "Rival Rex"/);
});
