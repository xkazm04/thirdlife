export const summary = "recipe cards (engine/cards): list | check | show <id> | brief <id> (the text a builder is given)";
import { checkCards, loadCards } from "../cards/check.mjs";

/** The card as the block of text that goes into a builder's brief. Deterministic: same card, same text. */
export function cardBrief(card) {
  const L = [];
  const list = (title, items) => { if (items?.length) { L.push(`${title}:`); for (const i of items) L.push(`- ${i}`); } };
  L.push(`RECIPE ${card.id} v${card.version}: ${card.title}`, card.summary, "");
  L.push(`Start from: engine/seeds/${card.seed}/ (copy its shape, then change data before code).`);
  L.push(`Capabilities: ${card.capabilities.join(", ")}`);
  L.push(`Kit parts the seed already uses: ${card.kit_parts.join(", ")}`);
  if (card.swap_parts?.length) L.push(`Kit parts to reach for when the request differs: ${card.swap_parts.join(", ")}`);
  L.push(`API the seed shows: ${card.api.join(", ")}`);
  L.push(`Rules by data (data/rules.json keys): ${card.rules_keys.join(", ")}`, "");
  L.push("Data files, written before any script:");
  for (const d of card.data_files) L.push(`- ${d.file}: ${d.role}`);
  list("Do", card.do); list("Do not", card.dont);
  L.push(`Bot: copy ${card.bot.template}. It plays by: ${card.bot.plays_by} It has won when: ${card.bot.wins_when}`);
  list("Accepted when", card.acceptance);
  if (card.variants?.length) { L.push("Known variants:"); for (const v of card.variants) L.push(`- "${v.ask}": ${v.change}`); }
  return L.join("\n") + "\n";
}

export async function run(args, ctx) {
  const [sub = "list", id] = args;
  const root = ctx.REPO;
  if (sub === "check") {
    const { steps, problems } = checkCards({ root });
    if (args.includes("--verbose")) for (const p of [...problems.shape, ...problems.tree]) console.log(`  ${p}`);
    return ctx.printVerdict("cards check", steps, { problems });
  }
  const { cards, errors } = loadCards(root);
  for (const e of errors) console.error(e);
  if (sub === "list") {
    for (const { card } of cards) console.log(`${String(card.id).padEnd(24)} ${String(card.seed).padEnd(14)} ${card.title}`);
    return errors.length ? 1 : 0;
  }
  if (sub === "show" || sub === "brief") {
    const hit = cards.find((c) => c.card.id === id || c.card.id === `card.${id}`);
    if (!hit) { console.error(`tl cards: no card '${id ?? ""}'. Known: ${cards.map((c) => c.card.id).join(", ")}`); return 2; }
    console.log(sub === "show" ? JSON.stringify(hit.card, null, 2) : cardBrief(hit.card).trimEnd());
    return 0;
  }
  console.error("tl cards list | check [--verbose] | show <id> | brief <id>");
  return 2;
}
