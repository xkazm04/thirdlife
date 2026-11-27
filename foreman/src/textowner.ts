// D27 lane T3, item 45 (lane N-newcomer's Arsenal copy, events 1489-1496): "the two new lines are too long for the ONE
// MATCH card ... ("...your shot floors everyone." and "bump them" sticks out of the card ...). Make every line of the ONE
// MATCH card fit" went to harbour (the Planner: the card "is most likely drawn by harbour's scripts/main.gd"). The lines
// are the skin's (data/skin.json `about`), so harbour put its own copy in data/tuning.json `harbour.about_lines` and drew
// it over the skin's list: "its two long `about` lines are no longer shown. If its owner edits `about` later, nothing on
// screen changes". Two packages now own one text, and the skin's is dead. A text the person reads has one owner: the
// package whose file holds it. When the person quotes words that one other package's data file holds (and the Planner's
// package does not), that package changes them first; the Planner's package gets the drawing (the card, the wrap) as the
// Foreman's request, and is told never to keep a copy of the words. Pure but for the reads `read` makes.
import fs from "node:fs";
import type { PackageSpec } from "./events.js";
import { isBase } from "./coreroute.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import { drawPartHead } from "./playsplit.js";

/** A person's words, lower case, without punctuation at the ends and with one space between words. */
const norm = (s: string): string => s.toLowerCase().replace(/[‘’]/g, "'").replace(/[^a-z0-9'%]+/g, " ").trim();

/** The quoted fragments of `text` of three words or more ("...your shot floors everyone." -> "your shot floors everyone"). */
export function quotedFragments(text: string): string[] {
  const out: string[] = [];
  for (const m of text.matchAll(/"([^"]+)"|“([^”]+)”/g)) {
    const f = norm(m[1] ?? m[2] ?? "");
    if (f.split(" ").length >= 3 && !out.includes(f)) out.push(f);
  }
  return out;
}

/** Words that ask for the words themselves to change (a line too long, cut off, wrong, old). */
export const TEXT_ASK = /\b(too long|cut off|sticks? out|runs? past|does(?:n't| not) fit|fit inside|fits?|shorter|reword\w*|wording|typo|misspel\w*|still says|says wrong|wrong (?:words?|line|text)|old (?:line|text|words?)|should (?:say|read)|change (?:the )?(?:words?|line|text))\b/i;

/**
 * The quoted fragments that the person asks to change: a quote whose own sentence (about 160 characters before it and
 * 80 after, cut at a full stop outside the quote) has a TEXT_ASK word. A quote given as a reference ("the G key keeps
 * saying "after your Q call"", lane N's shield sentence 1506) is not an ask about the words.
 */
export function askedFragments(text: string): string[] {
  const out: string[] = [];
  for (const m of text.matchAll(/"([^"]+)"|“([^”]+)”/g)) {
    const f = norm(m[1] ?? m[2] ?? "");
    if (f.split(" ").length < 3 || out.includes(f)) continue;
    const at = m.index ?? 0;
    const bare = (s: string): string => s.replace(/"[^"]*"|“[^”]*”/g, " ");
    const before = bare(text.slice(Math.max(0, at - 160), at)).split(/[.!?]\s+(?=[A-Z])/).at(-1) ?? "";
    const after = bare(text.slice(at + m[0].length, at + m[0].length + 80)).split(/[.!?](?:\s|$)/)[0] ?? "";
    if (TEXT_ASK.test(`${before} ${after}`)) out.push(f);
  }
  return out;
}

/** The text files of a package a person's words can live in: its plain data paths (JSON, text, Markdown). */
export const textFiles = (p: Pick<PackageSpec, "scope">): string[] => p.scope.filter((f) => !f.includes("*") && /^data\/.*\.(json|txt|md)$/.test(f) && !/\.cartridge\.json$|(^|\/)match\.json$/.test(f));

/**
 * The package other than `owner` (never a base) whose data file holds words the person quoted that `owner`'s own files do
 * not, when exactly one does: the text is that package's, it goes first, and `owner` gets the drawing. Undefined otherwise
 * (no quote, quotes nobody else holds, or more than one other holder).
 */
export function textSplit(plan: readonly PackageSpec[], read: (rel: string) => string | undefined, owner: string, seq: number, text: string): { owner: string; why: string; draw: { package: string; text: string } } | undefined {
  if (text.startsWith(FOREMAN_NOTE)) return undefined;
  const frags = askedFragments(text); // only the quotes the person asks to change
  const mine = plan.find((p) => p.id === owner);
  if (frags.length === 0 || mine === undefined || isBase(mine)) return undefined;
  const holds = (p: PackageSpec): { file: string; frag: string }[] => textFiles(p).flatMap((file) => {
    const body = read(file);
    if (body === undefined) return [];
    const flat = norm(body);
    return frags.filter((f) => ` ${flat} `.includes(` ${f} `)).map((frag) => ({ file, frag }));
  });
  // a quote the owner holds is the owner's (the person may quote what works, "I see YOUR CHECK MADE YOU MEGA"); the
  // quotes only another package holds are that package's
  const own = new Set(holds(mine).map((h) => h.frag));
  const holders = plan.filter((p) => p.id !== owner && !isBase(p)).map((p) => ({ p, hits: holds(p).filter((h) => !own.has(h.frag)) })).filter((x) => x.hits.length > 0);
  if (holders.length !== 1) return undefined;
  const { p, hits } = holders[0] as { p: PackageSpec; hits: { file: string; frag: string }[] };
  const files = [...new Set(hits.map((h) => h.file))];
  const said = hits.map((h) => `"${h.frag}"`).join(", ");
  const why = `the words the person quotes (${clip(said, 200)}) are held in ${files.join(", ")}, which "${p.id}" owns, so the change goes to "${p.id}" first (one owner per text a person reads); "${owner}", which the Planner named, draws them`;
  const body = `${drawPartHead(seq)}for what your files show (${mine.scope.slice(0, 6).join(", ")}${mine.scope.length > 6 ? ", ..." : ""}): the words the person quotes (${clip(said, 300)}) are "${p.id}"'s, in ${files.join(", ")}, and "${p.id}" changes them there. Draw those words as ${files.join(", ")} holds them (lay them out, wrap them, size the card for them): never keep a copy of them in your own files, and never draw your own text over theirs; a word that must change is "${p.id}"'s (a NOT DONE line naming ${files[0]}). The whole change: "${text}"`;
  return { owner: p.id, why, draw: { package: owner, text: clip(body, 3000) } };
}

/** A file's text, or undefined when it cannot be read. */
export function readOr(file: string): string | undefined {
  try {
    return fs.readFileSync(file, "utf8");
  } catch {
    return undefined;
  }
}
