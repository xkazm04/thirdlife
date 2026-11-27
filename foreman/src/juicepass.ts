// S2-juice (juice day, 27 Nov 2026): the standard juice pass for a person's change that adds a move.
// Last night (27 Nov) the editor built every crazy ability exactly as its sentence said and no more; the hand-made
// versions (robot hammer, shield charge, Arsenal's meteor, J4b's dunk sentence) read far better on screen because of
// juice the sentence did not name: a tell that grows, exaggeration, hit-stop and a camera kick, a word mid-screen,
// particles and sound, a slow beat on the big moment, and the world answering. The pass is that layer as builder text
// (prompts/juice_pass.md), given to the package that owns the change, beside the change request.
//
// The owner decides WHEN it runs (ask 2 of the night's verdict). This file is the same in both arms of the spike except
// JUICE_MODE:
//   - "auto" (arm A): every change that adds a move runs the pass, unless the person says "keep it plain";
//   - "choice" (arm B): the pass runs only when the person picked "make it juicy" in Create (the words are in the request).
import fs from "node:fs";
import path from "node:path";
import { PKG_ROOT } from "./paths.js";
import { FOREMAN_NOTE } from "./conduct.js";
import { changeKind } from "./boundlift.js";
import type { JobEvent } from "./events.js";

export type JuiceMode = "auto" | "choice";
/** The arm of the spike this tree carries (the only line the two arms differ in). */
export const JUICE_MODE: JuiceMode = "auto";

/** The person's words that ask for the pass (Create's "make it juicy" card writes them). */
export const JUICY = /\bmake (it|them|this|that|the \w+( \w+)?) (more )?juic(y|ier)\b|\bjuice it( up)?\b/i;
/** The person's words that turn it off in arm A. */
export const PLAIN = /\b(keep (it|this|them|the \w+) plain|plain(ly)?,? (no|without) juice|no juice( pass)?|without (the )?juice)\b/i;
/** Words that name a move a body makes on a key (an ability), as opposed to a rule, a number or a look. */
const MOVE = /\b(abilit\w*|power\w*|(new|big|special|signature) (move|attack|shot|skill)|super\w*|hammer\w*|sledge\w*|swing\w*|charg\w*|slam\w*|smash\w*|dash\w*|lunge\w*|leap\w*|jump\w*|dunk\w*|block\w*|throw\w*|hurl\w*|toss\w*|shoot\w*|shot|slapshot\w*|kick\w*|punch\w*|bash\w*|tackl\w*|roll\w*|loop\w*|flip\w*|spin\w*|stomp\w*|pound\w*|whirl\w*|boost\w*|launch\w*|grab\w*|hook\w*|ricochet\w*|boomerang\w*|teleport\w*|blast\w*|fireball\w*|meteor\w*)\b/;
/** A key or button named for it ("hold F", "press G", "on Q", "on Shift", "the middle mouse button"). */
const ON_KEY = /\b(hold(ing)?|press(ing)?|tap(ping)?|on|with|release|key|button)\s+(the\s+)?([A-Z]|[Ss]pace|[Ss]hift|[Cc]trl|[Tt]ab|(left|right|middle) mouse( button)?)\b(?![a-z])/;
/** Words that ADD something a body can do (a change to an existing move's rules or numbers adds none). */
const ADDS = /\b(give|gives|giving|add|adds|adding|let (me|him|her|them|us|every\w*|each|all|the \w+|defenders?|attackers?|players?)|(a|my|his|their) new|new (key|move|ability|power|attack|trick|skill)|can now|learns?)\b/i;

/** Words that change the rules of a move the game already has (Arsenal's "no longer on a cooldown", "I start with one"). */
const RULES_OF = /\b(the rules of|no longer|comes? back by itself|i start (the match )?with (one|two|three|\d+))\b/i;

/** Does the person's change add a move (an ability)? A look, view or fairness change never does, nor a change to the
 * rules or numbers of a move the game already has ("the shield on F is no longer on a cooldown"). */
export function addsMove(text: string): boolean {
  if (changeKind(text) !== "play" || !ADDS.test(text) || RULES_OF.test(text)) return false;
  return MOVE.test(text.toLowerCase()) && (ON_KEY.test(text) || /\b(abilit\w*|power\w*|(new|big|special|signature) (move|attack|shot|skill)|give (every|each|all|my|the) \w+( \w+)? (a|an|two|three) )/i.test(text));
}

/** Does the pass run on this change request text (the person's words, as logged)? */
export function juiceRuns(text: string, mode: JuiceMode = JUICE_MODE): boolean {
  if (text.startsWith(FOREMAN_NOTE)) return false; // the Foreman's own follow-ups (wire-in, the rest of a half-made change)
  if (mode === "choice") return JUICY.test(text);
  if (PLAIN.test(text)) return false;
  return JUICY.test(text) || addsMove(text);
}

/** The pass's own words, for the balance rows the person's words touch (boundlift.ts askedChange): hit-stop, a launch
 * that tumbles, a wind-up tell. The pass asks for them, so a row that measures them is moved by the change, not regressed. */
export const JUICE_WORDS = "wind-up tell, launch, tumble, hit-stop freeze";

let passText: string | undefined;
/** prompts/juice_pass.md, read once. */
export function juicePassText(): string {
  return (passText ??= fs.readFileSync(path.join(PKG_ROOT, "prompts", "juice_pass.md"), "utf8").trim());
}

/** The pass for a builder's prompt, when the change it was re-opened for runs it (the queued detail "CHANGE REQUEST: ..."). */
export function juicePart(changeDetail: string | undefined, mode: JuiceMode = JUICE_MODE): string | undefined {
  if (changeDetail === undefined) return undefined;
  const text = changeDetail.replace(/^CHANGE REQUEST:\s*/, "");
  return juiceRuns(text, mode) || text.startsWith(`${FOREMAN_NOTE}${JUICE_MORE}`) ? juicePassText() : undefined;
}

export const JUICE_NOTE = `${FOREMAN_NOTE}juice pass`;
/** Arm B: a change that adds a move ran without the pass; Create offers "make it juicy" as a one-click follow-up. */
export const JUICE_OFFER = `${FOREMAN_NOTE}juice pass offered`;
/** The Foreman's note when the pass goes to a package, in words for the person. */
export function juiceNote(owner: string, mode: JuiceMode = JUICE_MODE): string {
  return mode === "auto"
    ? `${JUICE_NOTE}: your change adds a move, so ${owner} also gets the standard juice pass (a tell that grows, exaggeration, hit-stop and a camera kick, a word mid-screen, particles and sound, a slow beat on the big moment, the world answering). Say "keep it plain" in a change to leave it out.`
    : `${JUICE_NOTE}: you picked "make it juicy", so ${owner} also gets the standard juice pass (a tell that grows, exaggeration, hit-stop and a camera kick, a word mid-screen, particles and sound, a slow beat on the big moment, the world answering).`;
}

/** The note a change request gets when it is handed to `owner`: the pass ran, or (arm B) it was not picked for a change
 * that adds a move, so Create offers it as a follow-up; undefined otherwise. */
export function juiceNoteFor(text: string, owner: string, mode: JuiceMode = JUICE_MODE): string | undefined {
  if (juiceRuns(text, mode)) return juiceNote(owner, mode);
  if (mode === "choice" && !text.startsWith(FOREMAN_NOTE) && addsMove(text)) return `${JUICE_OFFER}: your change adds a move and was built plain, as you asked. Pick "make it juicy" to give it a tell, an impact word, a camera kick and a slow beat.`;
  return undefined;
}

// ---- round 2 (the Director, 27 Nov): the Foreman reads the builder's JUICE: checklist line ----
// Round 1 of the spike: the pass was not always obeyed. Robots A kept the slide's 28-frame flight and had no camera
// follow; both shield runs skipped the launch and the slow beat ("sized BIG, not signature"; "not done"). Each builder
// said so in its JUICE: line. Now, after the merge of a round the pass ran on, a big move whose checklist says it
// skipped the launch, the slow beat or the camera follow goes back to the same package for ONE more round.

/** The start of the Foreman's follow-up request (after FOREMAN_NOTE): the round that makes the skipped parts. */
export const JUICE_MORE = "juice pass not finished";

/** The big parts a checklist line says were skipped; [] when the move is small, or nothing big was skipped. */
export function juiceGaps(lines: readonly string[]): string[] {
  const check = [...lines].reverse().find((l) => /^JUICE:\s*size\b/i.test(l));
  if (check === undefined) return [];
  const field = (name: RegExp): string => check.split("|").map((f) => f.replace(/^JUICE:\s*/i, "").trim()).find((f) => name.test(f))?.replace(name, "").trim() ?? "";
  if (!/\b(big|signature)\b/i.test(field(/^size\b/i))) return [];
  const no = (v: string): boolean => /^(no|none|not done|skipped)\b/i.test(v);
  const said = lines.filter((l) => /^JUICE:/i.test(l) && !/^JUICE:\s*size\b/i.test(l) && /\bnot done\b/i.test(l)).join(" ");
  const gaps: string[] = [];
  const ex = field(/^exaggeration\b/i);
  if (no(ex) || /^small\b/i.test(ex) || /\bno (body )?launch\b|\bflight time (is )?(still|unchanged)\b|launch\w*: not done/i.test(`${ex} ${said}`)) gaps.push("the launch (a hit body at least two body heights up, 40 frames or more in the air, spinning)");
  if (no(field(/^slow beat\b/i))) gaps.push("the slow beat on the move at its biggest");
  if (/\bno (camera )?follow|\bfollow\w*:? (no|not done)|\bwithout (a )?follow|\bnot follow|\bcamera follow\w*[^|]*not done|\bcamera unchanged\b/i.test(`${field(/^camera\b/i)} ${said}`)) gaps.push("the camera following a launched player");
  return gaps;
}

/** The lines of package `id`'s own notes after event `since` (the builders', not the Foreman's), without list marks. */
function ownLines(events: readonly JobEvent[], id: string, since: number): string[] {
  return events.flatMap((e) => (e.type === "note" && e.package === id && e.seq > since && !e.text.startsWith(FOREMAN_NOTE) ? e.text.split(/\r?\n/) : [])).map((l) => l.replace(/^\s*[-*]\s*/, "").trim()).filter(Boolean);
}

/**
 * After the merge of a change round the pass ran on (halfmade.ts afterMerge): when the builder's JUICE: line says a big
 * move skipped the launch, the slow beat or the camera follow, one more round for the same package, with the pass. Only
 * once per change: the follow-up's own text is the Foreman's, so the pass does not run a third time.
 */
export function juiceMore(events: readonly JobEvent[], id: string, round: number, request: string, since: number, mode: JuiceMode = JUICE_MODE): Record<string, unknown>[] {
  if (!juiceRuns(request, mode)) return [];
  const gaps = juiceGaps(ownLines(events, id, since));
  if (gaps.length === 0) return [];
  const text = `${FOREMAN_NOTE}${JUICE_MORE}: ${id}'s JUICE: checklist says this big move skipped ${gaps.join("; ")}. Make ${gaps.length === 1 ? "it" : "them"} now in your own files, as the juice pass asks, with the numbers under DEVIATIONS, and keep the rules of the move as they are. The change was: "${request}"`;
  return [
    { type: "note", package: id, round, text: `${FOREMAN_NOTE}${JUICE_MORE}: ${id} skipped ${gaps.join("; ")}; it gets one more round for them` },
    { type: "change_requested", package: id, text: text.length > 3000 ? `${text.slice(0, 2999)}…` : text },
  ];
}
