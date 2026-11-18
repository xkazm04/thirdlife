export const summary = "recipe cards (engine/cards): list | check | show <id> | brief <id> (the text a builder is given) | hands <pack> --card <id> (the card's hand checks on a pack)";
import { checkCards, loadCards } from "../cards/check.mjs";
import { cardBrief, cardBriefText, cardListLine } from "../cards/brief.mjs";
import { runHands } from "../cards/handrun.mjs";

// The texts live in ../cards/brief.mjs, the one implementation the Foreman imports too (foreman/src/cards.ts).
export { cardBrief };

export async function run(args, ctx) {
  const [sub = "list", id] = args;
  const root = ctx.REPO;
  if (sub === "check") {
    const { steps, problems } = checkCards({ root });
    if (args.includes("--verbose")) for (const p of [...problems.shape, ...problems.tree]) console.log(`  ${p}`);
    return ctx.printVerdict("cards check", steps, { problems });
  }
  if (sub === "hands") return runHands(args.slice(1), ctx);
  const { cards, errors } = loadCards(root);
  for (const e of errors) console.error(e);
  if (sub === "list") {
    for (const { card } of cards) console.log(cardListLine(card));
    return errors.length ? 1 : 0;
  }
  if (sub === "show" || sub === "brief") {
    const hit = cards.find((c) => c.card.id === id || c.card.id === `card.${id}`);
    if (!hit) { console.error(`tl cards: no card '${id ?? ""}'. Known: ${cards.map((c) => c.card.id).join(", ")}`); return 2; }
    console.log(sub === "show" ? JSON.stringify(hit.card, null, 2) : cardBriefText(hit.card));
    return 0;
  }
  console.error("tl cards list | check [--verbose] | show <id> | brief <id> | hands <pack dir> --card <id> [--seeds N] [--tests <dir>] [--par N]");
  return 2;
}
