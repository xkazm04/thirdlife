// The design room (JOB.md "Added 2026-11-21"): before the first brief_set the Designer runs three steps: concept
// (five candidate pitches, one chosen), design (the game design doc with its feel sheet, plus the v2 fields) and a
// producer review. A "revise" review runs the design step once more with the review's notes; round 2 is final. Kept
// out of designer.ts (its line rule); the texts are in roomtext.ts.
import fs from "node:fs";
import path from "node:path";
import type { Brief } from "./events.js";
import { designBrief, generate, type DesignerInput, type DesignerOutput, type GenerateCall, type GenerateOptions, type Generated } from "./designer.js";
import { PKG_ROOT } from "./paths.js";
import { REVIEW_SCORES, ROOM_LIMITS, conceptProblems, reviewProblems, type Concept, type DesignReview } from "./room_wire.js";
import { earlierProblems, earlierText, takenProblems, takenText } from "./concepts.js";
import { conceptTemplateProblems, templateExcerpt, templatesMenuText } from "./templates.js";
import { BRIEF_LIMITS, CONCEPT_LIMITS, REVIEW_LIMITS } from "./repair.js";
import { REVIEW_THRESHOLD, conceptAnswerSchema, conceptText, qualityText, reviewAnswerSchema, slopIds, type ReviewAnswer } from "./roomtext.js";

const prompt = (name: string): string => fs.readFileSync(path.join(PKG_ROOT, "prompts", name), "utf8");

function redesignBlock(input: DesignerInput): string {
  if (input.previous === undefined) return "";
  return [
    "",
    "# This is a REDESIGN: the player reacted to the previous brief",
    `The previous concept: ${input.previous.brief.concept ? conceptText(input.previous.brief.concept).split("\n")[0] : "(none)"}; the previous pitch: ${input.previous.brief.pitch ?? "(none)"}`,
    "Keep the concept the player reacted well to; change it where the reactions turn against it.",
    "",
  ].join("\n");
}

/** L1b: the room's input: a crazy job also carries the standard concepts made for the same sentence. */
export type RoomInput = DesignerInput & { taken?: Concept[]; /** N4 round 5: earlier concepts of the sentence in this mode. */ earlier?: Concept[] };

export interface RoomOutput extends DesignerOutput {
  /** The reviews in order (1 or 2), each written as a design_reviewed event before the brief_set. */
  reviews: DesignReview[];
}

/** The concept step alone (step 1). */
export function conceptStep(builder: Parameters<typeof designBrief>[0], input: RoomInput, vars: Record<string, string>, opts: GenerateOptions): Promise<Generated<{ concept: Concept }>> {
  return generate<{ concept: Concept }>(
    builder,
    "concept",
    prompt("concept.md"),
    { ...vars, quality: qualityText(["3", "4", "6", "8"]), templates: templatesMenuText(), redesign: redesignBlock(input), taken: takenText(input.creativity, input.taken) + earlierText(input.earlier) },
    conceptAnswerSchema,
    (v) => [...conceptProblems((v as { concept: Concept }).concept), ...conceptTemplateProblems((v as { concept: Concept }).concept, input.sentence), ...takenProblems((v as { concept: Concept }).concept, input.taken, input.sentence), ...earlierProblems((v as { concept: Concept }).concept, input.earlier, input.sentence)],
    { ...opts, attempts: opts.attempts ?? 3, limits: CONCEPT_LIMITS }, // word limits: a repair call first (repair.ts), then the attempts
  );
}

/** The review step alone (step 3). The verdict is recomputed from the scores and the slop ids. */
export async function reviewStep(builder: Parameters<typeof designBrief>[0], input: DesignerInput, concept: Concept, brief: Brief, round: number, opts: GenerateOptions): Promise<Generated<DesignReview>> {
  const known = slopIds();
  const res = await generate<ReviewAnswer>(
    builder,
    "design_review",
    prompt("design-review.md"),
    {
      sentence: input.sentence,
      creativity: input.creativity === "crazy" ? "The job is CRAZY: one or two unexpected mechanics are added on top of the player's words (aspects marked crazy)." : "The job is STANDARD: serve the player's words.",
      concept: conceptText(concept),
      design: JSON.stringify(brief, null, 1),
      quality: qualityText(["6", "3", "10"]),
      template: templateExcerpt(concept.template, "design"),
      threshold: String(REVIEW_THRESHOLD),
      round: String(round),
      final: round >= ROOM_LIMITS.reviewRounds ? " (the final round: the brief is set whatever you say, so make the notes the builders' warnings)" : "",
    },
    reviewAnswerSchema,
    (v) => {
      const r = v as ReviewAnswer;
      const unknown = r.slop.filter((s) => known.length > 0 && !known.includes(s));
      return [...reviewProblems(r), ...(unknown.length > 0 ? [`slop ids ${unknown.join(", ")} are not in the slop list (${known.join(", ")})`] : [])];
    },
    { ...opts, attempts: opts.attempts ?? 3, limits: REVIEW_LIMITS },
  );
  if (!res.ok) return res;
  const r = res.value;
  const low = REVIEW_SCORES.filter((k) => (r.scores[k] ?? 0) < REVIEW_THRESHOLD);
  const verdict = r.verdict === "ok" && low.length === 0 && r.slop.length === 0 ? "ok" : "revise";
  const slopNote = r.slop.filter((s) => !r.notes.includes(s));
  const notes = slopNote.length > 0 ? `${r.notes} Slop: ${slopNote.join(", ")}.` : r.notes;
  return { ok: true, value: { round, verdict, scores: r.scores, notes }, calls: res.calls };
}

/**
 * The three steps, then (on "revise") the design step and the review once more. Round 2 is final: its verdict is
 * recorded and the brief is set whatever it says. The brief carries the concept and the design. A failed step fails
 * the room (nothing is written by this function; the caller logs the calls, the reviews and the brief).
 */
export async function designRoom(builder: Parameters<typeof designBrief>[0], input: RoomInput, opts: GenerateOptions = {}): Promise<Generated<RoomOutput>> {
  const calls: GenerateCall[] = [];
  const fail = (reason: string): Generated<RoomOutput> => ({ ok: false, reason, calls });
  const base = { sentence: input.sentence, creativity: creativityLine(input), engine: input.engine ?? "(the engine was not described for this call)", cards: input.cards ?? "(no recipe cards)" };
  const c = await conceptStep(builder, input, base, opts);
  calls.push(...c.calls);
  if (!c.ok) return fail(c.reason);
  const concept = c.value.concept;
  const reviews: DesignReview[] = [];
  let feedback: string | undefined;
  for (let round = 1; round <= ROOM_LIMITS.reviewRounds; round++) {
    const d = await designBrief(builder, { ...input, concept, ...(feedback !== undefined ? { review: feedback } : {}) }, { ...opts, attempts: opts.attempts ?? 3, limits: BRIEF_LIMITS });
    calls.push(...d.calls);
    if (!d.ok) return fail(d.reason);
    const brief: Brief = { ...d.value.brief, concept };
    const r = await reviewStep(builder, input, concept, brief, round, opts);
    calls.push(...r.calls);
    if (!r.ok) return fail(r.reason);
    reviews.push(r.value);
    if (r.value.verdict === "ok" || round === ROOM_LIMITS.reviewRounds) return { ok: true, value: { brief, estimate: d.value.estimate, reviews }, calls };
    feedback = [
      "",
      "# The producer sent your design back (review round 1 of 2): revise it",
      `Scores: ${REVIEW_SCORES.map((k) => `${k} ${r.value.scores[k]}`).join(", ")} (each must reach ${REVIEW_THRESHOLD}).`,
      `Notes: ${r.value.notes}`,
      `Your previous design (JSON):\n${JSON.stringify(d.value.brief, null, 1)}`,
      "Answer with the whole brief again, revised: fix what the notes name, keep what works, stay inside every word limit.",
      "",
    ].join("\n");
  }
  return fail("design room: no round ended");
}

/** The creativity text the concept step reads (the design step has its own, longer one in designer.ts). */
function creativityLine(input: DesignerInput): string {
  return input.creativity === "crazy"
    ? "CRAZY. Keep every word the player said; on top add one or two unexpected mechanics that bend a rule the player takes for granted (what scores, who they control, what a hit leaves behind, what the place and the crowd do). The crazy part sits ON TOP of the copied template's core, never instead of it. Let at least two candidates be crazy in different ways."
    : "STANDARD. Serve the player's words: every candidate is the game they asked for; the boldness is in the fantasy, the core exchange and the twist, not in things they did not ask for.";
}


/** Writes the room's result: each review as a `design_reviewed` event, then the `brief_set` they judged. */
export function appendRoom(append: (body: { type: "design_reviewed"; round: number; verdict: DesignReview["verdict"]; scores: DesignReview["scores"]; notes: string } | { type: "brief_set"; brief: Brief; estimate: RoomOutput["estimate"] }) => unknown, value: RoomOutput): void {
  for (const r of value.reviews) append({ type: "design_reviewed", round: r.round, verdict: r.verdict, scores: r.scores, notes: r.notes });
  append({ type: "brief_set", brief: value.brief, estimate: value.estimate });
}
