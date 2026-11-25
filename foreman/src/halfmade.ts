// H1g item 5 (lane G2, events 642-730: "My teammates ... should run into open space ... And a match is over in one minute:
// make it first to 5" was routed to ONE package, core; core's builder made the match length and wrote "NOT DONE here
// (change request 3): teammates running into open space ... belong to another package"; the job ended done and the
// what-changed line repeated the whole request as if all of it were made). When a change round's builder says part of
// the change is not done, the rest goes on: to the package whose plan scope holds the files the builder names (a change
// request for it, the Foreman's, carrying the person's words), or, when no other package owns them, the person is told
// plainly which part was not made. The what-changed line says what was made and, apart, what was not.
import type { JobEvent, PackageSpec } from "./events.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import { matchesAny } from "./scope.js";
import { pathsIn, widenedNote } from "./scopegrant.js";

/** A builder's line that says part of the change is not made here. */
export const NOT_DONE = /\bNOT (DONE|MADE|BUILT)\b|\bnot done here\b|\bbelongs? to another package\b/;
/** The start of the Foreman's request for the rest (after FOREMAN_NOTE), and of the note when nobody owns it. */
export const REST_OF = "the rest of your change";
export const NOT_MADE = "part of your change was NOT made";

/** The lines of a builder's note, without list marks. */
export function noteLines(text: string): string[] {
  return text.split(/\r?\n/).map((l) => l.replace(/^\s*[-*]\s*/, "").trim()).filter((l) => l !== "" && !/^DEVIATIONS:?\s*(none)?$/i.test(l));
}

/** The builder's own note of package `id` in round `round` (not the Foreman's); "" when none. */
function builderNote(events: readonly JobEvent[], id: string, round: number): string {
  return events.filter((e) => e.type === "note" && e.package === id && e.round === round && !e.text.startsWith(FOREMAN_NOTE)).map((e) => (e.type === "note" ? e.text : "")).join("\n");
}

/** The package whose plan scope holds a path the line names (not `id`); undefined when none does. */
export function ownerOf(plan: readonly PackageSpec[], id: string, line: string): string | undefined {
  const paths = pathsIn(line);
  for (const p of plan) {
    if (p.id === id) continue;
    if (paths.some((x) => matchesAny(p.scope, x.replace(/\/\*\*$/, "/x.gd")) || p.scope.includes(x))) return p.id;
  }
  return undefined;
}

/** The events a merge appends after it: what the person's yes widened (H1f), and the rest of a half-made change (H1g). */
export function afterMerge(plan: readonly PackageSpec[], events: readonly JobEvent[], id: string, round: number, files: readonly string[], request: string | undefined): Record<string, unknown>[] {
  const out: Record<string, unknown>[] = [];
  const wide = widenedNote(plan, events, id, files);
  if (wide !== undefined) out.push({ type: "note", package: id, round, text: wide });
  // only a change round: the package's last re-opening was for a change request (the person's, or the rest of one)
  const reason = [...events].reverse().find((e) => e.type === "reopened" && e.package === id);
  if (request === undefined || request === "" || reason?.type !== "reopened" || !/change request|rest of your change/.test(reason.reason)) return out;
  const rest = noteLines(builderNote(events, id, round)).filter((l) => NOT_DONE.test(l));
  if (rest.length === 0) return out;
  const said = rest.map((l) => clip(l, 400)).join(" / ");
  const owner = ownerOf(plan, id, rest.join(" "));
  if (owner !== undefined) {
    out.push({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${NOT_MADE} by ${id}; it goes on to ${owner}, whose files ${id} names: ${said}` });
    out.push({ type: "change_requested", package: owner, text: clip(`${FOREMAN_NOTE}${REST_OF}, which ${id} did not make ("${said}"): "${request}"`, 2000) });
  } else out.push({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${NOT_MADE}: ${id} made what it could and says: ${said}. No other package owns the rest: say it again as a change of its own if you still want it` });
  return out;
}

/** For the what-changed line: the builders' NOT DONE lines since the last promotion, and whether each went on. */
export function notMadeSince(since: readonly JobEvent[]): string[] {
  return since.flatMap((e) => {
    if (e.type !== "note" || !e.text.startsWith(`${FOREMAN_NOTE}${NOT_MADE}`)) return [];
    const text = e.text.slice(FOREMAN_NOTE.length);
    const to = / it goes on to (\S+), whose files/.exec(text)?.[1];
    // the owner merged the rest after it was sent on: say so
    const made = to !== undefined && since.some((x) => x.type === "merge" && x.package === to && x.seq > e.seq);
    return [made ? text.replace(` it goes on to ${to}, whose files`, ` it went on to ${to}, which made it; ${to}'s files`) : text];
  });
}
