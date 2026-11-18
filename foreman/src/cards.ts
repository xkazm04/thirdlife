// Recipe cards in a job (JOB.md, "Added 2026-11-17"; contracts/CARDS.md). The reference copy holds every card of the
// engine under ref/cards/ (each card's JSON and INDEX.md, the `tl cards list` table); the Planner may name one for the
// whole job (`plan_set.card`), and every builder brief of that job then carries the card's text exactly as
// `tl cards brief <id>` prints it.
//
// One implementation, not two: the texts come from devx/lib/cards/brief.mjs, the module `tl cards` itself prints
// with. The Foreman imports that file (it lives in this repository beside foreman/, and the Foreman already reads
// contracts/PACK.md from the same tree); copying the formatter here would let the two drift apart unseen.
import fs from "node:fs";
import path from "node:path";
import { cardBriefText, cardListLine, type Card } from "../../devx/lib/cards/brief.mjs";
import { stripBom, toPosix } from "./paths.js";

export type { Card };
export { cardBriefText, cardListLine };

export const CARD_ID_RE = /^card\.[a-z][a-z0-9_]*$/;

/** The cards of a directory (engine/cards or ref/cards), by file name order. A file that is not a card is skipped. */
export function readCards(dir: string): { file: string; card: Card }[] {
  if (!fs.existsSync(dir)) return [];
  const out: { file: string; card: Card }[] = [];
  for (const name of fs.readdirSync(dir).filter((n) => n.endsWith(".json")).sort()) {
    try {
      const card = JSON.parse(stripBom(fs.readFileSync(path.join(dir, name), "utf8"))) as Card;
      if (card && typeof card === "object" && typeof card.id === "string" && CARD_ID_RE.test(card.id)) out.push({ file: name, card });
    } catch {
      /* not a card: `tl cards check` is where a broken card turns red; the job just does not offer it */
    }
  }
  return out;
}

/** The ids of the cards a job's reference copy offers (`<job>/ref/cards/`). */
export function cardIds(refDir: string): string[] {
  return readCards(path.join(refDir, "cards")).map((c) => c.card.id);
}

/** The hands a card's `hands` block checks (CARDS.md "Hand checks"), in its order; [] when it has none. */
export function cardHandList(card: Card): string[] {
  const h = (card as Card & { hands?: { checks?: { hand: string }[] } }).hands;
  return (h?.checks ?? []).map((c) => c.hand);
}

/** What the plan check needs of ref/cards/: the card ids, and per card the hands its plan must register tests for. */
export function cardLimits(refDir: string): { cards: string[]; cardHands: Record<string, string[]> } {
  const cards = readCards(path.join(refDir, "cards")).map((c) => c.card);
  return { cards: cards.map((c) => c.id), cardHands: Object.fromEntries(cards.filter((c) => cardHandList(c).length > 0).map((c) => [c.id, cardHandList(c)])) };
}

/**
 * Lane C3: a plan that names a card with hand checks must register, in some package's `registers.tests`, every
 * tests/bot_hand_<hand>.gd the card checks (like the PLAYER CHECK rule): otherwise final verification would fail it.
 */
export function planHandProblems(packages: { id: string; registers?: { tests?: string[] } }[], card: string | undefined, cardHands: Record<string, string[]>): string[] {
  const need = card !== undefined ? (cardHands[card] ?? []) : [];
  const registered = new Set(packages.flatMap((p) => p.registers?.tests ?? []));
  const missing = need.map((h) => `tests/bot_hand_${h}.gd`).filter((t) => !registered.has(t));
  if (missing.length === 0) return [];
  return [
    `the card ${card ?? ""} has hand checks, and no package registers ${missing.join(", ")}. Register each in registers.tests (and its scope) of the package that owns the player's bot: a bot that plays the game's own policy through TLHand.create(ctx, "<hand>") ("idle" presses nothing), is done when the game is over, and returns ok (it finished) and won (true or false) in _bot_result(). The Foreman plays each on many seeds before it promotes; the card's text names the bounds and a real example to copy.`,
  ];
}

/** The card with this id in the reference copy, or undefined. */
export function cardOf(refDir: string, id: string): Card | undefined {
  return readCards(path.join(refDir, "cards")).find((c) => c.card.id === id)?.card;
}

/** ref/cards/INDEX.md: the `tl cards list` table, one line per card, in a code block. */
export function cardsIndexText(cards: Card[]): string {
  return ["# Recipe cards (`tl cards list`)", "", "```", ...cards.map((c) => cardListLine(c)), "```", ""].join("\n");
}

/**
 * The plan check for `card` (JOB.md 2026-11-17): absent is fine; a present id must be one of the cards in ref/cards/,
 * like an unknown key is refused.
 */
export function planCardProblems(card: unknown, known: string[]): string[] {
  if (card === undefined) return [];
  if (typeof card !== "string" || !CARD_ID_RE.test(card)) return [`"card" must be a card id like card.<snake_name>, got ${JSON.stringify(card)}`];
  if (!known.includes(card)) {
    return [known.length > 0 ? `"card": "${card}" is not a card of this job (ref/cards/ holds ${known.join(", ")}); name one of them or omit "card"` : `"card": "${card}" names a card, but this job's reference copy has no cards; omit "card"`];
  }
  return [];
}

/** The Planner's "Recipe cards" section: each card's id, title, when it applies and when not, read from ref/cards/. */
export function cardsPlannerText(refDir: string): string {
  const cards = readCards(path.join(refDir, "cards")).map((c) => c.card);
  if (cards.length === 0) return "This engine has no recipe cards: omit `card`.";
  const lines: string[] = [];
  for (const c of cards) {
    lines.push(`- \`${c.id}\` (${c.pack !== undefined ? `house game engine/packs/${c.pack}` : `seed ${c.seed ?? "?"}`}): ${c.title}`);
    for (const w of c.applies_when) lines.push(`  - applies when: ${w}`);
    for (const w of c.not_when ?? []) lines.push(`  - NOT when: ${w}`);
    const hands = (c as Card & { hands?: { checks: { hand: string }[] } }).hands;
    if (hands?.checks?.length) lines.push(`  - hand checks: when you name this card, some package must register ${hands.checks.map((h) => `tests/bot_hand_${h.hand}.gd`).join(", ")} (the Foreman plays them through a person's hand on many seeds before it promotes; the card's text tells the builder what each must find)`);
  }
  lines.push(`Each card in full: \`ref/cards/<name>.json\`; the list: \`ref/cards/INDEX.md\`.`);
  return lines.join("\n");
}

/** The builder brief's "Recipe card" section for a job whose plan names `card`. */
export function cardBriefSection(refDir: string, card: string | undefined): string {
  if (card === undefined) return "";
  const c = cardOf(refDir, card);
  if (!c) return `\n## Recipe card\nThe plan names the card ${card}, but this job's reference copy does not hold it: follow the contract and the seeds.\n`;
  // The card names engine paths (engine/seeds/<seed>/, engine/packs/<pack>/); a builder reads them in its reference
  // copy. Said once here, above the card, so the card text itself stays exactly what `tl cards brief` prints.
  const where = c.pack !== undefined ? `engine/packs/${c.pack}/ is ${toPosix(path.join(refDir, "packs", c.pack))}/` : `engine/seeds/${c.seed ?? ""}/ is ${toPosix(path.join(refDir, "seeds", c.seed ?? ""))}/`;
  return [
    "",
    `## Recipe card (the Planner chose ${card} for this whole job: follow it; your contract wins where the two disagree)`,
    `Paths in the card are the engine's; read them in your reference copy: ${where}.`,
    cardBriefText(c),
    "",
  ].join("\n");
}
