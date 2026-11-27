// H1f of 25 Nov (lane G4, events 232-243): crews_stakes asked "may the fix touch files outside the crews scope, such as
// scripts/main.gd, scripts/core/** and scripts/bodies/**?", the person answered "Yes, the frame-time failure. You may
// change scripts/main.gd, scripts/core and scripts/bodies so six players run within the budget.", the builder made the
// fix there, and the Foreman dropped all three files as out of scope. A person's written yes to a scope question widens
// that package's scope for that change (until it is re-opened again): the paths the answer names (a folder means all its
// files). The merge says in a note what was widened. Pure: the package, the log and the words in, a scope out.
import type { JobEvent, PackageSpec } from "./events.js";
import { FOREMAN_NOTE } from "./conduct.js";
import { matchesAny } from "./scope.js";
import { movesTestFor } from "./movestest.js";

/** A question that asks for files outside the package's scope (the builder's words or the Foreman's). */
const SCOPE_QUESTION = /\b(scope|outside|may (the fix|it|this package|i) (touch|change|edit)|can (those|these) files|be added to)\b/i;
/** An answer that says yes (not "no", not "only ..."). */
const YES = /^\s*(yes|yeah|yep|ok(ay)?|sure|go ahead|you may|allowed|fine)\b/i;
const NO = /\b(no|not|don'?t|never)\b/i;

/** The paths an answer names: tokens with a slash (data/x.json, scripts/core, scripts/core/**), quotes and dots trimmed. */
export function pathsIn(text: string): string[] {
  const out: string[] = [];
  for (const m of text.matchAll(/[`'"]?([A-Za-z0-9_.-]+(?:\/[A-Za-z0-9_.*-]+)+)[`'"]?/g)) {
    let p = (m[1] as string).replace(/[.,;:]+$/, "");
    if (p.startsWith("res://")) p = p.slice(6);
    if (!/\.[A-Za-z0-9]+$/.test(p) && !p.endsWith("**")) p = `${p.replace(/\/\*?$/, "")}/**`;
    if (!out.includes(p)) out.push(p);
  }
  return out;
}

/** The globs a person granted package `id` in its current change: yes-answers to scope questions since its last re-opening. */
export function grantedScope(events: readonly JobEvent[], id: string): string[] {
  const reopenAt = [...events].reverse().find((e) => e.type === "reopened" && e.package === id)?.seq ?? 0;
  const out: string[] = [];
  let question: string | undefined;
  for (const e of events) {
    if (e.seq <= reopenAt) continue;
    if (e.type === "question" && e.package === id) question = e.text;
    if (e.type !== "answer" || e.package !== id || question === undefined) continue;
    const yes = YES.test(e.text) && !NO.test(e.text.replace(/^\s*\S+/, "").split(/[.;]/)[0] ?? "");
    // H1g (the Director's answer): a bare yes ("yes, go ahead") grants the paths the question named; a yes that names
    // paths grants those
    const named = pathsIn(e.text);
    if (SCOPE_QUESTION.test(question) && yes) for (const p of named.length > 0 ? named : pathsIn(question)) if (!out.includes(p)) out.push(p);
    question = undefined;
  }
  return out;
}

/**
 * D27 item 7 (S4's Arsenal copy, events 1082-1095): the cartridge's builder named the exact rules-sidecar switches for "the
 * rival bots get the same hip check ... throw itself in front of a hard shot" (bot_ability_share, dive_shot_share) and
 * marked them NOT BUILT, because data/harbour.rules.json was outside its scope; the person's "Yes, add that file" granted
 * nothing (the question named no path). On a game on a core, the package that owns the game's cartridge (with
 * data/match.json) also owns its rules sidecar data/<cut>.rules.json in a person's change, unless another package lists it.
 */
export function sidecarOf(plan: readonly PackageSpec[], spec: PackageSpec, events: readonly JobEvent[]): string | undefined {
  if (spec.kind === "base" || !spec.scope.includes("data/match.json")) return undefined;
  const cart = spec.scope.find((g) => /^data\/[^/*]+\.cartridge\.json$/.test(g));
  if (cart === undefined) return undefined;
  const side = cart.replace(/\.cartridge\.json$/, ".rules.json");
  if (spec.scope.includes(side) || plan.some((p) => p.id !== spec.id && p.kind !== "base" && matchesAny(p.scope, side))) return undefined;
  let last = -1;
  for (const e of events) if (e.type === "promoted") last = e.seq;
  return last >= 0 && events.some((e) => e.type === "change_requested" && e.seq > last) ? side : undefined;
}

/** The package as the Foreman verifies and merges it now: its plan scope plus what the person granted in this change. */
export function withGrants(spec: PackageSpec, events: readonly JobEvent[], plan?: readonly PackageSpec[]): PackageSpec {
  const side = plan !== undefined ? sidecarOf(plan, spec, events) : undefined;
  const moves = plan !== undefined ? movesTestFor(plan, spec, events) : undefined; // D27b item 23: a count of its own
  const extra = [...grantedScope(events, spec.id), ...(side !== undefined ? [side] : []), ...(moves !== undefined ? [moves] : [])].filter((g) => !spec.scope.includes(g));
  return extra.length === 0 ? spec : { ...spec, scope: [...spec.scope, ...extra] };
}

/** The note a merge gets when it wrote files the plan's scope did not hold: what was widened, and on whose word. */
export function widenedNote(plan: readonly PackageSpec[], events: readonly JobEvent[], id: string, files: readonly string[]): string | undefined {
  const own = plan.find((p) => p.id === id)?.scope ?? [];
  const outside = files.filter((f) => !matchesAny(own, f));
  if (outside.length === 0) return undefined;
  const spec = plan.find((p) => p.id === id);
  const side = spec !== undefined ? sidecarOf(plan, spec, events) : undefined;
  if (side !== undefined && outside.includes(side)) return `${FOREMAN_NOTE}scope widened for this change: ${id} owns the game's cartridge, so it may write its rules sidecar ${side} for a play rule the person asked that no cartridge key says; merged outside its plan scope: ${outside.join(", ")}`;
  const moves = spec !== undefined ? movesTestFor(plan, spec, events) : undefined;
  if (moves !== undefined && outside.includes(moves)) return `${FOREMAN_NOTE}scope widened for this change: ${id}'s acceptance runs no bot test of its own besides the Foreman's tofu bot, so it may write ${moves} to count its new moves (the Foreman runs it in its land check; the pack's manifest does not list it); merged outside its plan scope: ${outside.join(", ")}`;
  const granted = grantedScope(events, id);
  if (granted.length === 0) return undefined; // H1g: files outside the plan scope that no answer granted are not "widened" (another rule put them there)
  return `${FOREMAN_NOTE}scope widened for this change, on the person's answer: ${id} may change ${granted.join(", ")}; merged outside its plan scope: ${outside.join(", ")}`;
}
