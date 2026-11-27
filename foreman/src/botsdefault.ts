// S1-bots arm A (juice day, 27 Nov 2026): a new move tells the bots by default. Last night karts, basketball and
// shield wall each needed a second sentence before the bots used a new move ("the rivals use it too"), and in the
// 3 v 3 games the bots that think in a crew package's mind never heard of it (the change went to core only). Now the
// owner question (grow.ts ownerOrNew, the same ONE Planner call) also says whether the change ADDS a move, whether the
// words say what the bots do with it, and which packages drive a bot. When the words say nothing about the bots, the
// Foreman adds by default: the bots use the move at sensible moments and answer it (dodge, block, brace, punish).
// - The owner gets it in its brief (a `[foreman] bots by default` note on its package, read by the builder prompt).
// - Every OTHER package that drives a bot gets a Foreman wire request (`[foreman] wire in <owner> ...`, grow.ts's wait:
//   it runs after the owner's change is merged), so a crew's mind learns the move too.
// - "only I can do it" turns the use off: no bot uses the move; they still answer it.
// - Words that DO name the bots still reach every bot package (the minimal routing lane T builds on main).
// - The what-changed card says what the Foreman added, and how to turn it off.
// Pure helpers; foreman.ts calls applyBotsDefault from applyChangeRequests.
import type { PackageLine } from "./designer.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";

export const BOTS_DEFAULT = "bots by default";
/** The note on the owner's package (its brief) and on the card: `[foreman] bots by default (change request event N): ...`. */
export const BOTS_NOTE = `${FOREMAN_NOTE}${BOTS_DEFAULT}`;
export const BOTS_MODES = ["said", "unsaid", "only_me"] as const;
export type BotsMode = (typeof BOTS_MODES)[number];

export interface BotsPlan {
  move: string;
  mode: BotsMode;
  packages: string[];
  use?: string;
  answer?: string;
}

/** The owner answer's extra keys (all optional: a change that adds no move answers as before). */
export const BOTS_PROPERTIES = {
  move: { type: "string" },
  bots: { type: "string", enum: [...BOTS_MODES] },
  bot_packages: { type: "array", items: { type: "string" } },
  use: { type: "string" },
  answer: { type: "string" },
} as const;

/** A file whose name says a bot decides there: a brain, a mind, an AI or crew/team/rival file (tests are not). */
const BOT_FILE = /(^|\/)(brains?|brain_\w+|minds?|ai|bots?|rivals?|crews?|teams?|tactics|coach|opponents?)(\.|\/|$)/i;

/** The packages whose files look like a bot's brain (a hint for the Planner, and the fallback when it names none). */
export function botHints(packages: readonly PackageLine[]): string[] {
  return packages.filter((p) => p.files.some((f) => !f.startsWith("tests/") && BOT_FILE.test(f))).map((p) => p.id);
}

/** The owner prompt's section on moves and bots. */
export function botsPromptText(packages: readonly PackageLine[]): string {
  const hints = botHints(packages);
  return [
    "",
    "# A new move and the bots (answer these in the same object)",
    `Packages whose files look like a bot's brain: ${hints.length > 0 ? hints.join(", ") : "(none found by file name)"}.`,
    "- `move`: only when the request ADDS a move a player does (an ability, an attack, a jump, a trick, a throw, a dash, a shove): name it in a few words. Omit it for anything else (a number, a look, a rule, a camera, a sound).",
    "- `bots` (with a move only): \"said\" when the request says what the bots, the rivals, the opponents or the computer players do with it; \"only_me\" when the player keeps it to himself (\"only I can do it\", \"the bots never use it\"); \"unsaid\" when it says nothing about them.",
    "- `bot_packages` (with a move only): EVERY package above whose own files make a bot decide what to do (a brain, a mind, AI or crew data), the owner too when it drives a bot. In a 3 v 3 game the crew or team package usually drives most of the bots.",
    "- `use` (with \"unsaid\"): one sentence: the sensible moments a bot uses the move (when it pays off, respecting its cost and cooldown, never as spam).",
    "- `answer` (with \"unsaid\" or \"only_me\"): one sentence: how a bot answers the move when it comes at him (dodge, block, brace, hop, spin away, punish the miss), using the counters the request or the game already has.",
  ].join("\n");
}

/** Problems of the owner answer's extra keys. */
export function botsProblems(v: { move?: unknown; bots?: unknown; bot_packages?: unknown }, ids: readonly string[]): string[] {
  const bad = Array.isArray(v.bot_packages) ? (v.bot_packages as unknown[]).filter((x) => typeof x !== "string" || !ids.includes(x)) : [];
  return bad.length > 0 ? [`"bot_packages" may name only listed packages (${ids.join(", ")}); not: ${bad.map(String).join(", ")}`] : [];
}

/** The plan the owner answer gives, or undefined when the change adds no move (or the answer has no `bots`). */
export function botsPlanOf(v: { move?: string; bots?: string; bot_packages?: string[]; use?: string; answer?: string }, packages: readonly PackageLine[]): BotsPlan | undefined {
  const move = (v.move ?? "").trim();
  if (move === "" || !BOTS_MODES.includes(v.bots as BotsMode)) return undefined;
  const ids = packages.map((p) => p.id);
  const named = (v.bot_packages ?? []).filter((x) => ids.includes(x));
  const pk = [...new Set(named.length > 0 ? named : botHints(packages))];
  return { move: clip(move, 120), mode: v.bots as BotsMode, packages: pk, ...(v.use ? { use: clip(v.use.trim(), 300) } : {}), ...(v.answer ? { answer: clip(v.answer.trim(), 300) } : {}) };
}

const useWords = (b: BotsPlan): string => `the bots use "${b.move}" at sensible moments${b.use ? ` (${b.use.replace(/\.$/, "")})` : ""}, never as spam: they respect its wind-up, cost and cooldown and use it when it pays`;
const answerWords = (b: BotsPlan): string => `a bot that sees "${b.move}" coming at him answers it${b.answer ? ` (${b.answer.replace(/\.$/, "")})` : " (dodges, blocks, braces or punishes the miss)"}, after his normal reaction delay`;

/** What the Foreman adds for change request `seq` (undefined: nothing, the words already say it). */
export function botsWords(b: BotsPlan, seq: number): string | undefined {
  if (b.mode === "said") return undefined;
  if (b.mode === "only_me") return `${BOTS_NOTE} (change request event ${seq}): OFF, the person said only they use "${b.move}": no bot ever uses it; ${answerWords(b)}.`;
  return `${BOTS_NOTE} (change request event ${seq}): the person added "${b.move}" and said nothing about the bots, so by default ${useWords(b)}; and ${answerWords(b)}. Every bot this package drives does both (not only one of them), and a test that counts the bots' uses and answers passes. The person can turn this off by saying "only I can do it".`;
}

/** The wire request for another bot package `pkg`: waits until `owner` (which builds the move) is merged again. */
export function botsWireText(b: BotsPlan, owner: string, seq: number, text: string): string {
  const add = botsWords(b, seq);
  const head = `${FOREMAN_NOTE}wire in ${owner} (${BOTS_DEFAULT}, change request event ${seq}): ${owner} adds "${b.move}"; this package drives bots, so they must know it.`;
  const what = add === undefined ? ` The person's words about the bots are for every package that drives a bot: do here what they ask of the bots this package drives.` : ` ${add.slice(FOREMAN_NOTE.length)}`;
  return clip(`${head}${what} Use the move as ${owner} built it (read its merged files: its key, its state and its events), do not build a second one. The person's words: "${text}"`, 1500);
}

/** The bots-by-default notes of package `id`, as lines for its builder brief (empty: none). */
export function botsBriefText(notes: readonly { package: string; text: string }[], id: string): string {
  const mine = notes.filter((n) => n.package === id && n.text.startsWith(BOTS_NOTE)).map((n) => `- ${n.text.slice(FOREMAN_NOTE.length)}`);
  return mine.length === 0 ? "" : `\n## The bots and the new move (the Foreman adds this by default: the player did not say it; it is part of your brief)\n${mine.join("\n")}\n`;
}

/** The card's line(s) for the bots-by-default notes since the last promotion. */
export function botsCardLines(since: readonly { type: string; text?: string; package?: string }[]): string[] {
  const out: string[] = [];
  for (const e of since) {
    if (e.type !== "note" || e.text === undefined || !e.text.startsWith(`${BOTS_NOTE} (change request event`)) continue;
    const m = /"([^"]+)"/.exec(e.text);
    const move = m?.[1] ?? "the new move";
    const pk = /\[bots in: ([^\]]+)\]/.exec(e.text)?.[1];
    out.push(
      / OFF, /.test(e.text)
        ? `${BOTS_DEFAULT}: off, as you said: no bot uses "${move}"; they still dodge or block it`
        : `${BOTS_DEFAULT}: you said nothing about the bots, so the Foreman told them to use "${move}" at good moments and to answer it (dodge, block, punish)${pk ? ` (in ${pk})` : ""}; say "only I can do it" to keep it yours`,
    );
  }
  return [...new Set(out)];
}

/** What applyChangeRequests does for a plan: the owner's note (or none) and the wire requests for the other bot packages. */
export function botsEvents(b: BotsPlan, owner: string, seq: number, text: string): { note?: string; wires: { package: string; text: string }[] } {
  const add = botsWords(b, seq);
  const others = b.packages.filter((p) => p !== owner);
  const inPk = b.packages.length > 0 ? b.packages : [owner];
  const note = add === undefined ? undefined : `${add} [bots in: ${inPk.join(", ")}]`;
  return { ...(note !== undefined ? { note } : {}), wires: others.map((p) => ({ package: p, text: botsWireText(b, owner, seq, text) })) };
}
