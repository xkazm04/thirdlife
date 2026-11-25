// H1f of 25 Nov (lane G4, events 232-243): crews_stakes asked "may the fix touch files outside the crews scope, such as
// scripts/main.gd, scripts/core/** and scripts/bodies/**?", the person answered "Yes, the frame-time failure. You may
// change scripts/main.gd, scripts/core and scripts/bodies so six players run within the budget.", the builder made the
// fix there, and the Foreman dropped all three files as out of scope. A person's written yes to a scope question widens
// that package's scope for that change (until it is re-opened again): the paths the answer names (a folder means all its
// files). The merge says in a note what was widened. Pure: the package, the log and the words in, a scope out.
import type { JobEvent, PackageSpec } from "./events.js";
import { FOREMAN_NOTE } from "./conduct.js";
import { matchesAny } from "./scope.js";

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
    if (SCOPE_QUESTION.test(question) && yes) for (const p of pathsIn(e.text)) if (!out.includes(p)) out.push(p);
    question = undefined;
  }
  return out;
}

/** The package as the Foreman verifies and merges it now: its plan scope plus what the person granted in this change. */
export function withGrants(spec: PackageSpec, events: readonly JobEvent[]): PackageSpec {
  const extra = grantedScope(events, spec.id).filter((g) => !spec.scope.includes(g));
  return extra.length === 0 ? spec : { ...spec, scope: [...spec.scope, ...extra] };
}

/** The note a merge gets when it wrote files the plan's scope did not hold: what was widened, and on whose word. */
export function widenedNote(plan: readonly PackageSpec[], events: readonly JobEvent[], id: string, files: readonly string[]): string | undefined {
  const own = plan.find((p) => p.id === id)?.scope ?? [];
  const outside = files.filter((f) => !matchesAny(own, f));
  if (outside.length === 0) return undefined;
  const granted = grantedScope(events, id);
  return `${FOREMAN_NOTE}scope widened for this change, on the person's answer: ${id} may change ${granted.join(", ")}; merged outside its plan scope: ${outside.join(", ")}`;
}
