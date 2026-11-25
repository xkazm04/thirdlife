// H1 of 25 Nov (E5e defect 3): a change can remove something the person did not mention. Job 3's "make the bumpers bigger
// and add a fast lane through the middle" dropped the game's "pass from here" spot spot-nw to fit the core's 8-zone limit,
// and the what-changed note said it only inside a long JSON value. Now:
//   - what a change removes is found by comparing the cartridge before and after: an entry of a list (a zone, an
//     obstacle, a team, an ability) that is gone; list entries with an `id` are named by it, others by their `kind`;
//   - it is named on its own line of the what-changed note: "removed: spot-nw (game.rink.zones); why: ...";
//   - when the person's words did not ask for a removal, the change pauses with a question card ("To add lane-middle I
//     must remove spot-nw: OK?") and is made as it is only on a yes; any other answer is a new try that keeps it.
// Pure functions; coregate.ts and the Foreman's promotion use them.
import fs from "node:fs";
import path from "node:path";
import { playedCartridges } from "./played.js";

/** One list entry a change removed (or added): the key path of the list and the entry's name. */
export interface Removal {
  where: string;
  what: string;
}

type Json = unknown;
const isObj = (v: Json): v is Record<string, Json> => typeof v === "object" && v !== null && !Array.isArray(v);
const idOf = (v: Json): string | undefined => (isObj(v) && typeof v["id"] === "string" && v["id"] !== "" ? v["id"] : undefined);
const kindOf = (v: Json): string => (isObj(v) && typeof v["kind"] === "string" ? v["kind"] : isObj(v) && typeof v["name"] === "string" ? v["name"] : "entry");
const join = (at: string, k: string): string => (at === "" ? k : `${at}.${k}`);

/** The list entries of `before` that `after` does not have, by key path. Entries with an id are matched by it (and compared inside). */
export function removedEntries(before: Json, after: Json, at = ""): Removal[] {
  return diffEntries(before, after, at, "removed");
}

/** The list entries `after` has that `before` did not (what a change adds), as removedEntries names them. */
export function addedEntries(before: Json, after: Json, at = ""): Removal[] {
  return diffEntries(before, after, at, "added");
}

function diffEntries(before: Json, after: Json, at: string, want: "removed" | "added"): Removal[] {
  const out: Removal[] = [];
  if (isObj(before) && isObj(after)) {
    for (const k of Object.keys(before)) if (k in after) out.push(...diffEntries(before[k], after[k], join(at, k), want));
    return out;
  }
  if (!Array.isArray(before) || !Array.isArray(after)) return out;
  const [from, to] = want === "removed" ? [before, after] : [after, before];
  if (from.every((e) => idOf(e) !== undefined)) {
    const ids = new Map(to.flatMap((e) => (idOf(e) !== undefined ? [[idOf(e) as string, e]] : [])));
    for (const e of from) {
      const twin = ids.get(idOf(e) as string);
      if (twin === undefined) out.push({ where: at, what: idOf(e) as string });
      else out.push(...(want === "removed" ? diffEntries(e, twin, join(at, idOf(e) as string), want) : diffEntries(twin, e, join(at, idOf(e) as string), want)));
    }
    return out;
  }
  // No ids (the rink's obstacles): counted by kind, so a bumper made bigger is not a bumper removed.
  const count = (list: Json[]): Map<string, number> => {
    const m = new Map<string, number>();
    for (const e of list) m.set(kindOf(e), (m.get(kindOf(e)) ?? 0) + 1);
    return m;
  };
  const a = count(from);
  const b = count(to);
  for (const [k, n] of a) {
    const gone = n - (b.get(k) ?? 0);
    if (gone > 0) out.push({ where: at, what: gone === 1 ? `a ${k}` : `${gone} ${k}s` });
  }
  return out;
}

/** "spot-nw (game.rink.zones)", several joined with ", ". */
export const entriesText = (list: Removal[]): string => list.map((r) => `${r.what}${r.where !== "" ? ` (${r.where})` : ""}`).join(", ");

/** The person's words ask for something to go: remove, drop, delete, take out, get rid of, without, no more, fewer, less... */
export function asksRemoval(words: string): boolean {
  return /\b(remov\w*|delet\w*|drop\w*|take (?:\w+ ){0,3}(?:out|away|off)|get rid|rid of|without|no more|fewer|less|lose|cut|clear\w*|strip\w*|instead of|replac\w*|swap\w*)\b/i.test(words);
}

/** A yes to "To add X I must remove Y: OK?". */
export function isYes(answer: string): boolean {
  const rest = answer.replace(/^\s*\S+/, "").replace(/\bno (problem|worries)\b/gi, "");
  return /^\s*(ok(ay)?|yes|yeah|yep|sure|fine|go( on| ahead)?|do it|that'?s fine|it'?s fine|agreed|alright|all right|y)\b/i.test(answer) && !/\b(but|keep|not|don'?t|no)\b/i.test(rest);
}

/** The question card: "To add X I must remove Y: OK?", then why, and what an answer does. */
export function removalQuestion(added: Removal[], removed: Removal[], why: string, words: string): string {
  const what = added.length > 0 ? `add ${added.map((a) => a.what).join(", ")}` : `make "${words.slice(0, 120)}"`;
  return `To ${what} I must remove ${removed.map((r) => r.what).join(", ")}: OK? (${entriesText(removed)}; the change's reason: ${why.slice(0, 300)}) Answer OK to make it as it is, or say what to keep and it is tried again without removing it.`;
}

/** The start of the Foreman's note (after FOREMAN_NOTE) that names what a change removed, for the what-changed note. */
export const REMOVED = "removed";

/** The note's text after FOREMAN_NOTE: "removed: spot-nw (game.rink.zones); why: ...". */
export const removedNote = (r: Removal, why: string): string => `${REMOVED}: ${entriesText([r])}; why: ${why.replace(/\s+/g, " ").slice(0, 300)}`;

/**
 * What the pack's core data (data/<name>.cartridge.json) lost since a promoted copy (`promoted`, a pack directory): the
 * builder's path, which no diff names. Unreadable or new files say nothing.
 */
export function removedSince(promoted: string, packDir: string): Removal[] {
  const out: Removal[] = [];
  const data = path.join(packDir, "data");
  if (!fs.existsSync(data)) return out;
  // H1d (lane G1, v0.1.3: "removed: a shield" was the builder's drill file losing its shields, not the game): only the
  // cartridge the game plays is the game; with none named, every cartridge as before.
  const played = playedCartridges(packDir).files.map((x) => x.slice("data/".length));
  for (const f of fs.readdirSync(data).filter((n) => n.endsWith(".cartridge.json") && (played.length === 0 || played.includes(n))).sort()) {
    try {
      const was = JSON.parse(fs.readFileSync(path.join(promoted, "data", f), "utf8").replace(/^﻿/, ""));
      const now = JSON.parse(fs.readFileSync(path.join(data, f), "utf8").replace(/^﻿/, ""));
      out.push(...removedEntries(was, now));
    } catch {
      /* new or unreadable: nothing to compare */
    }
  }
  return out;
}

/**
 * H1b: one line of applyChanges' `changed` ("game.rink.zones: [...] -> [...]") as a person reads it. A list becomes its
 * entries added and removed and what changed in the others ("game.rink.zones: + lane-middle, - spot-nw, - spot-ne";
 * "game.rink.obstacles: 4 bumpers changed, size 5 -> 7, x, z"); an object, the keys that changed; a short value stays as
 * it is ("game.rink.goal_width_m: 4 -> 4.4"). No parentheses and no "; ", so the what-changed line's readers still split it.
 */
export function compactChange(line: string): string {
  const head = /^([^:]+): ([^]*)$/.exec(line);
  if (head === null) return line;
  const [, key, rest] = head as unknown as [string, string, string];
  let before: unknown;
  let after: unknown;
  let found = false;
  for (let i = rest.indexOf(" -> "); i >= 0 && !found; i = rest.indexOf(" -> ", i + 1)) {
    try {
      const a = rest.slice(0, i);
      const b = rest.slice(i + 4);
      before = a === "absent" ? undefined : JSON.parse(a);
      after = b === "absent" ? undefined : JSON.parse(b);
      found = true;
    } catch {
      /* the arrow is inside a value: try the next one */
    }
  }
  if (!found || (!isObj(before) && !Array.isArray(before)) || (!isObj(after) && !Array.isArray(after))) return line;
  const parts: string[] = [];
  if (Array.isArray(before) && Array.isArray(after)) {
    parts.push(...diffEntries(before, after, "", "added").filter((r) => r.where === "").map((r) => `+ ${r.what}`));
    parts.push(...diffEntries(before, after, "", "removed").filter((r) => r.where === "").map((r) => `- ${r.what}`));
    const ids = before.every((e) => idOf(e) !== undefined);
    const pairs: [Json, Json][] = ids ? before.flatMap((e) => { const t = after.find((x) => idOf(x) === idOf(e)); return t !== undefined ? [[e, t] as [Json, Json]] : []; }) : before.slice(0, after.length).map((e, i) => [e, after[i]] as [Json, Json]);
    const moved = pairs.filter(([a, b]) => JSON.stringify(a) !== JSON.stringify(b));
    if (moved.length > 0) {
      const kinds = [...new Set(moved.map(([a]) => (ids ? (idOf(a) as string) : kindOf(a))))];
      const who = ids ? kinds.join(", ") : `${moved.length} ${kinds.length === 1 ? `${kinds[0]}${moved.length > 1 ? "s" : ""}` : "entries"}`;
      parts.push(`${who} changed${changedKeys(moved)}`);
    }
  } else if (isObj(before) && isObj(after)) {
    const keys = [...new Set([...Object.keys(before), ...Object.keys(after)])].filter((k) => JSON.stringify(before[k]) !== JSON.stringify(after[k]));
    parts.push(`${keys.join(", ")} changed`);
  } else return line;
  return `${key}: ${parts.join(", ") || "unchanged"}`;
}

/** ", size 5 -> 7, x, z": the keys that differ in the pairs, with before -> after when every pair agrees on both. */
function changedKeys(pairs: [Json, Json][]): string {
  const keys = new Set<string>();
  for (const [a, b] of pairs) if (isObj(a) && isObj(b)) for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) if (JSON.stringify(a[k]) !== JSON.stringify(b[k])) keys.add(k);
  const said = [...keys].map((k) => {
    const was = new Set(pairs.map(([a]) => JSON.stringify(isObj(a) ? a[k] : undefined)));
    const now = new Set(pairs.map(([, b]) => JSON.stringify(isObj(b) ? b[k] : undefined)));
    const one = (s: Set<string>): string | undefined => (s.size === 1 ? ([...s][0] ?? undefined) : undefined);
    const w = one(was);
    const n = one(now);
    return w !== undefined && n !== undefined && w.length <= 24 && n.length <= 24 ? `${k} ${w} -> ${n}` : k;
  });
  // the keys that say one change for all first
  said.sort((x, y) => Number(y.includes(" -> ")) - Number(x.includes(" -> ")));
  return said.length > 0 ? `, ${said.join(", ")}` : "";
}
