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
import type { JobEvent } from "./events.js";
import { matchesAny } from "./scope.js";
import { pathsIn } from "./scopegrant.js";

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

// ---------- D27 T3 round 2: a package that draws its own copy of another package's text is sent back once ----------
// The routing above sends the person's words to the package that holds them. A builder can still keep its own copy:
// N-newcomer's Arsenal copy, harbour r25 (event 1496): "The HOME card's lines now come from `data/tuning.json`
// `harbour.about_lines` and replace the skin's `about` list on screen"; and S4's base Arsenal, where the skin's own
// builder found it (event 808): "`scripts/main.gd` overrides the skin's tagline with `harbour.tagline` in
// `data/tuning.json` ... a later wording change must update the tuning value too, or the skin's text will not show".
// At a merge, a builder line that says one package's files draw over, override or replace another package's text sends
// the copier back once, naming the text's owner. A second time it is the person's note.

/** Words that say a copy is drawn over, or instead of, someone's text. */
export const COPY_WORDS = /\b(overrid\w*|replace[sd]? (?:the|its|their) [\w-]+'s|instead of (?:the|its|their) [\w-]+'s|(?:is|are) no longer shown|(?:will not|won't|does not|doesn't) show|never shown|drawn over|draws? (?:its|my|their) own)\b/i;
/** Words that name a text a person reads. */
export const TEXT_WORDS = /\b(text|lines?|tagline|title|about|words?|labels?|captions?|wording|sentence|card|hint)\b/i;
/** The start of the Foreman's request (after FOREMAN_NOTE). */
export const ONE_OWNER = "one owner per text";

/**
 * The copies a builder line reports: the package whose files hold the copy (`copier`) and the package whose text it
 * covers (`holder`, a package with text files: named as "the <id>'s ..." or by one of its text files). [] when none.
 */
export function textCopies(plan: readonly PackageSpec[], reporter: string, line: string): { copier: string; holder: string; line: string }[] {
  // "it never replaces the core's ... lines" (the d27-newc kart copy, items, event 1722) says the opposite
  const said = line.replace(/\b(?:never|not|n't|without)\s+(?:\w+\s+)?(?:overrid\w*|replac\w*)[^.;]*/gi, " ");
  if (!COPY_WORDS.test(said) || !TEXT_WORDS.test(line) || /\bNOT (?:DONE|MADE)\b/.test(line)) return [];
  const own = plan.filter((p) => !isBase(p));
  const ownerOf = (f: string): string | undefined => own.find((p) => p.scope.includes(f) || matchesAny(p.scope, f))?.id;
  const named = [...new Set(pathsIn(line).map(ownerOf).filter((x): x is string => x !== undefined))];
  // the text's owner is named as "the skin's tagline" first; only without that, by a text file of its own the line names
  const holder = own.find((p) => textFiles(p).length > 0 && new RegExp(`\\b${p.id}'s\\b`, "i").test(line)) ?? own.find((p) => textFiles(p).some((f) => line.includes(f)) && !named.every((x) => x === p.id));
  if (holder === undefined) return [];
  const copiers = named.filter((x) => x !== holder.id);
  const copier = copiers.length === 1 ? copiers[0] : copiers.length === 0 && reporter !== holder.id ? reporter : undefined;
  return copier === undefined ? [] : [{ copier, holder: holder.id, line }];
}

/**
 * At `id`'s merge: each copy its builder's notes since its re-opening report goes back once to the copier, naming the
 * text's owner; a copy already sent back in this change is a note for the person. [] when none.
 */
export function copiedTextEvents(plan: readonly PackageSpec[], events: readonly JobEvent[], id: string, round: number): Record<string, unknown>[] {
  let last = -1;
  for (const e of events) if (e.type === "promoted") last = e.seq;
  const since = [...events].reverse().find((e) => e.type === "reopened" && e.package === id)?.seq ?? last;
  const lines = events.filter((e) => e.type === "note" && e.package === id && e.seq > since && !e.text.startsWith(FOREMAN_NOTE)).flatMap((e) => (e.type === "note" ? e.text.split(/\r?\n/) : [])).map((l) => l.replace(/^\s*[-*]\s*/, "").trim());
  const out: Record<string, unknown>[] = [];
  for (const c of lines.flatMap((l) => textCopies(plan, id, l))) {
    const holder = plan.find((p) => p.id === c.holder) as PackageSpec;
    const files = textFiles(holder).join(", ");
    const sent = events.some((e) => e.type === "change_requested" && e.seq > last && e.package === c.copier && e.text.startsWith(`${FOREMAN_NOTE}${ONE_OWNER}`));
    if (out.some((o) => o["package"] === c.copier)) continue;
    if (sent) {
      out.push({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${ONE_OWNER}: ${c.copier} still draws its own copy of ${c.holder}'s text (${files}), after it was sent back once, in ${id}'s words: "${clip(c.line, 300)}"; a later change to ${files} may not show` });
      continue;
    }
    out.push({ type: "change_requested", package: c.copier, text: clip(`${FOREMAN_NOTE}${ONE_OWNER}: ${c.copier}'s files draw their own copy of a text that ${c.holder} owns (${files}), in ${id}'s words: "${c.line}". Take the copy out of your files and draw the words as ${files} holds them; a word that must change is ${c.holder}'s, so write it as a NOT DONE line naming ${files.split(", ")[0]} with the exact words. Change nothing else.`, 2000) });
  }
  return out;
}
