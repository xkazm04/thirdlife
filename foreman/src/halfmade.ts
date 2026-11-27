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
import fs from "node:fs";
import { NO_KEY, catalogRows, keyHint, type CatalogRow } from "./keyfind.js";
import { cartridgeOwner } from "./coreowner.js";

/** A builder's line that says part of the change is not made here. */
// D27 item 2 (lane J1, event 1012): "RULE: not done. ... It needs `data/harbour.cartridge.json`, which is outside my
// scope" was missed (lower case, no "here"), so the cartridge edit its builder spelled out never reached the cartridge.
export const NOT_DONE = /\bNOT (DONE|MADE|BUILT)\b|\bnot done here\b|\bbelongs? to another package\b|^(?:RULE:\s*)?[Nn]ot (?:done|made|built)\b|\b[Nn]eeds? `?[\w./*-]+`?,? which (?:is|are) outside (?:of )?my scope\b/;
/** The start of the Foreman's request for the rest (after FOREMAN_NOTE), and of the note when nobody owns it. */
export const REST_OF = "the rest of your change";
/** D27 items 17-18: the start of the Foreman's request (after FOREMAN_NOTE) that sends a NOT DONE about the base's files back to its builder. */
export const OWN_FILES = "make in your own files the part of your change";
export const NOT_MADE = "part of your change was NOT made";

/** The lines of a builder's note, without list marks. */
export function noteLines(text: string): string[] {
  return text.split(/\r?\n/).map((l) => l.replace(/^\s*[-*]\s*/, "").trim()).filter((l) => l !== "" && !/^DEVIATIONS:?\s*(none)?$/i.test(l));
}

/** The builder's own notes of package `id` after event `since` (not the Foreman's); "" when none. */
function builderNote(events: readonly JobEvent[], id: string, since: number): string {
  return events.filter((e) => e.type === "note" && e.package === id && e.seq > since && !e.text.startsWith(FOREMAN_NOTE)).map((e) => (e.type === "note" ? e.text : "")).join("\n");
}

/** The package whose plan scope holds a path the line names (not `id`, never a base package); undefined when none does. */
export function ownerOf(plan: readonly PackageSpec[], id: string, line: string): string | undefined {
  const paths = pathsIn(line);
  const others = plan.filter((p) => p.id !== id && p.kind !== "base");
  // D27 item 2: a package that lists the path itself before one whose glob holds it (J1: data/** of the base)
  return (others.find((p) => paths.some((x) => p.scope.includes(x))) ?? others.find((p) => paths.some((x) => matchesAny(p.scope, x.replace(/\/\*\*$/, "/x.gd")))))?.id;
}

/** What afterMerge needs to know of a game on a core: who owns the cartridge, and the catalog's rows (keyfind.ts). */
export interface CoreHint {
  cartridgeOwner?: string;
  rows: readonly CatalogRow[];
  catalogPath: string;
}

/** The events a merge appends after it: what the person's yes widened (H1f), and the rest of a half-made change (H1g). */
export function afterMerge(plan: readonly PackageSpec[], events: readonly JobEvent[], id: string, round: number, files: readonly string[], request: string | undefined, core?: CoreHint): Record<string, unknown>[] {
  const out: Record<string, unknown>[] = [];
  const wide = widenedNote(plan, events, id, files);
  if (wide !== undefined) out.push({ type: "note", package: id, round, text: wide });
  // only a change round: the package's last re-opening was for a change request (the person's, or the rest of one)
  const reason = [...events].reverse().find((e) => e.type === "reopened" && e.package === id);
  if (request === undefined || request === "" || reason?.type !== "reopened" || !/change request|rest of your change/.test(reason.reason)) return out;
  // D27 item 2: every round since the re-opening (a NOT DONE line of a round that failed is still not done)
  const rest = [...new Set(noteLines(builderNote(events, id, reason.seq)).filter((l) => NOT_DONE.test(l)))];
  if (rest.length === 0) return out;
  // D27: lists, not singletons: each line goes to the package that owns the files it names; a line that names none
  // goes with the others when they all go to one package, and on a core a line about the cartridge or a key goes to
  // the cartridge's owner
  const named = rest.map((l) => ownerOf(plan, id, l));
  const owners = [...new Set(named.filter((o): o is string => o !== undefined))];
  const toCart = core?.cartridgeOwner !== undefined && core.cartridgeOwner !== id ? core.cartridgeOwner : undefined;
  // D27 round 4, items 17 and 18 (JB-back's Arsenal copy, events 1095-1115: "F lights only a second after the drop" named
  // the base's scripts/human_input.gd and went to the cartridge, which has no key for it and changed nothing; "the net
  // bulges and the glass shakes" named the base's scripts/match_view.gd and stayed a note): a line whose files are the
  // base's (no builder changes the base) goes back once to its own builder, to make it in its own files; only a line that
  // names no file, and does not already say the catalog was searched, goes to the cartridge's owner
  const bases = plan.filter((p) => p.kind === "base");
  const baseOnly = (l: string): boolean => {
    const ps = pathsIn(l);
    return ps.length > 0 && ps.every((x) => bases.some((b) => b.scope.includes(x) || matchesAny(b.scope, x.replace(/\/\*\*$/, "/x.gd"))));
  };
  const toCartLine = (l: string): boolean => toCart !== undefined && pathsIn(l).length === 0 && !/\bsearched\b/i.test(l) && (/cartridge|\bkeys?\b/i.test(l) || NO_KEY.test(l));
  // D27 round 4 (the d27 copy of JB's Arsenal, harbour r16, event 1080: "the net bulging ... the glass shaking. The nets and
  // glass belong to the base's arena, and no file in my scope can move them" named no file and went with the skin's line to
  // the skin): a line that names no file never joins another package's line. It goes to the cartridge when it is about a
  // key not yet searched; back to its own builder (its own drawing can do it) unless it says only the core could; else it
  // stays the person's note.
  const coreOnly = (l: string): boolean => /\b(inside the core|the core's own|core patch|C\+\+|native code|bots never hold)\b/i.test(l);
  const ownerOfLine = (l: string, i: number): string | undefined =>
    named[i] ?? (baseOnly(l) ? id : undefined) ?? (pathsIn(l).length > 0 && owners.length === 1 ? owners[0] : undefined) ?? (toCartLine(l) ? toCart : undefined) ?? (pathsIn(l).length === 0 && !coreOnly(l) && /\b(base|arena|kit|outside my scope|no file)\b/i.test(l) ? id : undefined);
  const groups = new Map<string | undefined, string[]>();
  rest.forEach((l, i) => {
    const o = ownerOfLine(l, i);
    groups.set(o, [...(groups.get(o) ?? []), l]);
  });
  // D27 (the d27 copy of J1, events 1029-1078): one hop. The skin, asked only for the rest harbour handed it, said the
  // meteor itself needs the cartridge, and the request went back to the cartridge, which had already made its part.
  // A round that was itself handed the rest of a change tells the person what it did not make; it sends nothing on.
  const lastPromo = events.reduce((n, e) => (e.type === "promoted" ? e.seq : n), -1);
  const mergedInChange = (evs: readonly JobEvent[], pkg: string): boolean => evs.some((e) => e.type === "merge" && e.package === pkg && e.seq > lastPromo);
  const hop = request.startsWith(`${FOREMAN_NOTE}${REST_OF}`) || request.startsWith(`${FOREMAN_NOTE}${OWN_FILES}`);
  // D27 round 4, item 17 (the d27 copy of JB's Arsenal, run 2, event 1080: harbour sent "F lights only a second after
  // the drop" to the cartridge, which has no key for it, though harbour's own main.gd can hold the key back): a handed-on
  // round that cannot make a line in its own files sends it back once to the package that handed it on, to make there
  const sender = /^\[foreman\] the rest of your change, which (\S+) did not make/.exec(request)?.[1];
  const backAlready = (pkg: string): boolean => events.some((e) => e.type === "change_requested" && e.package === pkg && e.seq > lastPromo && e.text.startsWith(`${FOREMAN_NOTE}${OWN_FILES}`));
  const toSender = hop && sender !== undefined && sender !== id && !backAlready(sender);
  if (toSender) {
    const back = [...(groups.get(id) ?? []), ...(groups.get(undefined) ?? [])];
    groups.delete(id);
    groups.delete(undefined);
    if (back.length > 0) groups.set(`\u0000${sender}`, back);
  }
  for (const [owner, lines] of groups) {
    const said = lines.map((l) => clip(l, 400)).join(" / ");
    if (owner === `\u0000${sender}` && sender !== undefined) {
      out.push({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${NOT_MADE} by ${id} either; it goes back to ${sender}, which handed it on, to make in its own files: ${said}` });
      out.push({ type: "change_requested", package: sender, text: clip(`${FOREMAN_NOTE}${OWN_FILES} that you handed on, and ${id} could not make ("${said}"): build it in your own files (wrap or filter the input before it reaches the core, override it, or draw your own), or say plainly that it cannot be made: "${request}"`, 3000) });
      continue;
    }
    if (owner === id) {
      // D27 items 17-18: the base's files: back to this builder once; a second time it is the person's to hear
      if (hop) {
        out.push({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${NOT_MADE}: ${id} could not make it in its own files either and says: ${said}` });
        continue;
      }
      out.push({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${NOT_MADE} by ${id} yet; it goes back to ${id}, because the files it names are the base's, which no package changes: ${said}` });
      out.push({ type: "change_requested", package: id, text: clip(`${FOREMAN_NOTE}${OWN_FILES} that you marked NOT DONE ("${said}"): the files it names are the base's, which no package changes, so build it in your own files (wrap or filter the input before it reaches the core, override it, or draw your own), or say plainly that it cannot be made: "${request}"`, 3000) });
      continue;
    }
    // D27 item 14: a handed-on round may still send a line to a package that has not merged in this change (it has not
    // made its part yet); never back to one that has
    if (owner !== undefined && hop && mergedInChange(events, owner)) {
      out.push({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${NOT_MADE}: ${id} made the part handed to it and says: ${said}. It was already handed on once, so the Foreman does not send it to ${owner} again` });
      continue;
    }
    if (owner === undefined) {
      out.push({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${NOT_MADE}: ${id} made what it could and says: ${said}. No other package owns the rest: say it again as a change of its own if you still want it` });
      continue;
    }
    // D27 item 3: a "no key" claim is checked against the catalog before it travels
    const hints = core === undefined ? [] : [...new Set(lines.map((l) => keyHint(core.rows, l, core.catalogPath)).filter((h) => h !== ""))];
    const check = hints.length > 0 ? ` ${id} said the cartridge has no key for part of it, but ${hints.join("; ")}: read those rows before you say a key is missing.` : "";
    out.push({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${NOT_MADE} by ${id}; it goes on to ${owner}, whose files ${id} names: ${said}${hints.length > 0 ? ` (the catalog has candidate keys for what ${id} called missing: ${hints.join("; ")})` : ""}` });
    out.push({ type: "change_requested", package: owner, text: clip(`${FOREMAN_NOTE}${REST_OF}, which ${id} did not make ("${said}"):${check} "${request}"`, 3000) });
  }
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

/** D27 item 3: the CoreHint of a job on a core (its reference copy's catalog); undefined for a hand-built game. */
export function coreHintOf(plan: readonly PackageSpec[], core: { core: string } | undefined, dir: (...parts: string[]) => string): CoreHint | undefined {
  if (core === undefined) return undefined;
  const file = dir("ref", "cores", core.core, "CARTRIDGE.md");
  let md = "";
  try {
    md = fs.readFileSync(file, "utf8");
  } catch {
    /* no catalog in the reference copy: the owner is still known */
  }
  const owner = cartridgeOwner(plan)?.id;
  return { ...(owner !== undefined ? { cartridgeOwner: owner } : {}), rows: catalogRows(md), catalogPath: `ref/cores/${core.core}/CARTRIDGE.md` };
}

/**
 * D27 round 3 (JB-back's shield copy, events 869-960: crew was queued for the rivals' part, waiting for core; core's merge
 * then handed crew its NOT DONE lines (event 888); crew r8 built the rivals' part and merged, and only then did the hand-off
 * re-open crew for r9, which found "all three were already in place"): the Foreman's own request (a hand-off, the rivals'
 * part) for a package that is queued and has not built its round yet joins that round now: the package is re-opened before
 * its builder starts, and its builder reads every change of the package in one prompt.
 */
export function foldable(p: { state: string; round: number; id?: string }, text: string | undefined, running: boolean, events: readonly JobEvent[]): boolean {
  if (running || p.state !== "queued" || text === undefined || !text.startsWith(FOREMAN_NOTE)) return false;
  const id = p.id;
  return id !== undefined && !events.some((e) => e.type === "builder_run" && e.package === id && (e.round ?? 0) >= p.round);
}
