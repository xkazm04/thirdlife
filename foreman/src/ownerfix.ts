// D27b item 24 (lane T2-editor; J2nd's kart copy, events 1303-1365): the Planner added `items` for the red shell and
// asked core to wire it in. items r1 called TLAudio.play("hit_steel"), which is no engine preset; it merged, because its
// own checks never load it. core r19-r22 each wired items in, met that one script error in scripts/items/items.gd:280 in
// its bot run, and wrote the exact one-line fix as "NOT DONE: ... needs scripts/items/items.gd, which is outside my
// scope". A NOT DONE travels only after a MERGE (halfmade.ts afterMerge, lane T's items 17 and 18), and no core round
// could merge, so the fix never reached items; core ran out of rounds, was re-opened for items' own hand-off (r23-r26),
// failed the same way, and v0.1.8 was promoted with the shells never switched on (the same hash as v0.1.7). items, which
// depends on core, could not run while core was re-opened.
// A round that failed only on script errors in files another package owns (and that package has merged them) waits for
// that package: the error and the builder's own words go to the owner as the rest of the change, the round's package is
// set back to its merged files (Foreman.keepEarlier), and its change is asked again; every request of the waiting
// package waits until the owner has merged again (or ended its round without a merge). Once per owner per change.
import type { JobEvent, PackageSpec } from "./events.js";
import type { GateHost } from "./p10gate.js";
import type { GateFailure } from "./machine.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import { matchesAny } from "./scope.js";
import { REST_OF, handsOff, noteLines } from "./halfmade.js";
import { pathsIn, withGrants } from "./scopegrant.js";

/** The words after "[foreman] <id> " of the note that says a package waits for another one's fix. */
export const WAITS_FOR = "waits for";
/** The start of the Foreman's request (after FOREMAN_NOTE) that asks a waiting package's change again. */
export const AGAIN_AFTER = "your change again, now that";

const lastPromotion = (events: readonly JobEvent[]): number => events.reduce((n, e) => (e.type === "promoted" ? e.seq : n), -1);

/** The owner of a file among the other packages (never a base, never `id`), or undefined. */
function fileOwner(plan: readonly PackageSpec[], id: string, file: string): string | undefined {
  const others = plan.filter((p) => p.id !== id && p.kind !== "base");
  return (others.find((p) => p.scope.includes(file)) ?? others.find((p) => matchesAny(p.scope, file)))?.id;
}

/**
 * After a failed round of `id`: when every script error of the failed check is in a file another package owns and has
 * merged, hand the fix to that owner and ask `id`'s change again after it. Appends the events and returns true (the
 * caller then keeps `id`'s merged files: keepEarlier); false when the failure is `id`'s own, or was handed on already.
 */
export function blockedByOwner(h: Pick<GateHost, "s" | "events" | "pkg" | "append">, id: string, round: number, failure: GateFailure): boolean {
  if (failure.ok || failure.inconclusive !== undefined || failure.kitRegression !== undefined) return false;
  const errs = (failure.report?.errors ?? []).filter((e): e is { kind: string; file: string; line?: number; message: string } => e.kind === "script_error" && typeof e.file === "string" && e.file !== "");
  if (errs.length === 0 || (failure.report?.errors ?? []).length !== errs.length) return false;
  const plan = h.s.plan;
  const spec = plan.find((p) => p.id === id);
  if (spec === undefined || spec.kind === "base") return false;
  const mine = withGrants(spec, h.events, plan).scope;
  if (errs.some((e) => matchesAny(mine, e.file))) return false;
  const owners = [...new Set(errs.map((e) => fileOwner(plan, id, e.file)))];
  const owner = owners[0];
  if (owners.length !== 1 || owner === undefined) return false;
  const op = h.s.packages[owner];
  if (op === undefined || op.state !== "promoted" || (op.mergedFiles ?? []).length === 0 || !errs.every((e) => (op.mergedFiles ?? []).includes(e.file))) return false;
  const p = h.pkg(id);
  if ((p.mergedFiles ?? []).length === 0 || p.roundBase === undefined) return false; // keepEarlier keeps only a re-opened, merged package
  const since = lastPromotion(h.events);
  const head = `${FOREMAN_NOTE}${id} ${WAITS_FOR} ${owner}:`;
  if (h.events.some((e) => e.type === "note" && e.package === id && e.seq > since && e.text.startsWith(head))) return false;
  const request = (p.changes ?? []).at(-1) ?? "";
  const where = errs.slice(0, 3).map((e) => `${e.file}${e.line !== undefined ? `:${e.line}` : ""}: ${clip(e.message, 220)}`).join("; ");
  // the builder's own words for the fix (its NOT DONE lines that name the owner's files), newest round first
  const words = [...h.events].reverse().filter((e) => e.type === "note" && e.package === id && e.seq > since && !e.text.startsWith(FOREMAN_NOTE)).flatMap((e) => (e.type === "note" ? noteLines(e.text) : []));
  const said = words.find((l) => handsOff(l) && pathsIn(l).some((x) => errs.some((e) => e.file === x)));
  h.append({ type: "note", package: id, round, text: clip(`${head} ${id}'s round ${round} failed only on a script error in a file that ${owner} owns (${where}), which ${id} cannot change; the fix goes to ${owner}, and ${id}'s change runs again once ${owner} has merged it`, 1200) });
  h.append({ type: "change_requested", package: owner, text: clip(`${FOREMAN_NOTE}${REST_OF}, which ${id} did not make ("${said ?? `fix the script error in ${where}`}"): ${id}'s check fails on a script error in your file (${where}), and ${id} cannot change your files, so its part of the change waits for you. Fix it in your files and keep what your package already does: "${request}"`, 3000) });
  h.append({ type: "change_requested", package: id, text: clip(`${FOREMAN_NOTE}${AGAIN_AFTER} ${owner} has fixed the script error in its file (${where}): "${request}"`, 3000) });
  return true;
}

/** The words keepEarlier gets for a round that waits for another package's fix ("" when it does not wait). */
export function waitsWhy(events: readonly JobEvent[], id: string, round: number): string {
  const n = [...events].reverse().find((e) => e.type === "note" && e.package === id && e.round === round && e.text.startsWith(`${FOREMAN_NOTE}${id} ${WAITS_FOR} `));
  const owner = n?.type === "note" ? n.text.slice(`${FOREMAN_NOTE}${id} ${WAITS_FOR} `.length).split(":")[0] : undefined;
  return owner !== undefined ? `${WAITS_FOR} ${owner}'s fix; ` : "";
}

/** A change request for a package that waits for another one's fix waits too, until that one has merged again or ended its round. */
export function ownerWaits(events: readonly JobEvent[], c: { package?: string }): boolean {
  const id = c.package;
  if (id === undefined) return false;
  const since = lastPromotion(events);
  const head = `${FOREMAN_NOTE}${id} ${WAITS_FOR} `;
  const note = [...events].reverse().find((e) => e.type === "note" && e.package === id && e.seq > since && e.text.startsWith(head));
  if (note === undefined || note.type !== "note") return false;
  const owner = note.text.slice(head.length).split(":")[0] ?? "";
  if (events.some((e) => e.type === "merge" && e.package === owner && e.seq > note.seq)) return false;
  const reopened = events.find((e) => e.type === "reopened" && e.package === owner && e.seq > note.seq);
  const ended = reopened !== undefined && events.some((e) => e.type === "package_state" && e.package === owner && e.seq > reopened.seq && (e.state === "promoted" || e.state === "failed"));
  return !ended;
}
