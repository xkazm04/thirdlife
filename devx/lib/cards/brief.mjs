// Recipe cards (tl.card/1, contracts/CARDS.md): the texts a card becomes. Pure functions of the card, no file system,
// no imports: `tl cards brief` / `tl cards list` print these, and the Foreman (foreman/src/cards.ts) imports this very
// file to write a builder's brief and the job's ref/cards/INDEX.md, so the two can never drift (one implementation).

/** Where the card's worked example lives: a seed pack or (2026-11-17) a house game. */
export function cardExample(card) {
  return card.pack !== undefined ? `engine/packs/${card.pack}/` : `engine/seeds/${card.seed}/`;
}

/** The card as the block of text that goes into a builder's brief. Deterministic: same card, same text. */
export function cardBrief(card) {
  const L = [];
  const list = (title, items) => { if (items?.length) { L.push(`${title}:`); for (const i of items) L.push(`- ${i}`); } };
  const what = card.pack !== undefined ? "house game" : "seed";
  L.push(`RECIPE ${card.id} v${card.version}: ${card.title}`, card.summary, "");
  L.push(`Start from: ${cardExample(card)} (copy its shape, then change data before code).`);
  L.push(`Capabilities: ${card.capabilities.join(", ")}`);
  L.push(`Kit parts the ${what} already uses: ${card.kit_parts.join(", ")}`);
  if (card.swap_parts?.length) L.push(`Kit parts to reach for when the request differs: ${card.swap_parts.join(", ")}`);
  L.push(`API the ${what} shows: ${card.api.join(", ")}`);
  if (card.core) {
    // E3 of 24 Nov: a game on a core is a cartridge over the base; the win condition lives in the cartridge.
    L.push(`Rules by data (key paths of the cartridge ${card.core.cartridge}): ${card.rules_keys.join(", ")}`);
    L.push(`Core: this kind of game runs on the ${card.core.id} core (engine/cores/${card.core.id}/, ctx.cores.open). A game is a cartridge${card.core.base ? ` over the base engine/templates/${card.core.base}/` : ""}: change data, never the simulation. Measured check: ${card.core.check}`, "");
  } else L.push(`Rules by data (data/rules.json keys): ${card.rules_keys.join(", ")}`, "");
  L.push("Data files, written before any script:");
  for (const d of card.data_files) L.push(`- ${d.file}: ${d.role}`);
  list("Do", card.do); list("Do not", card.dont);
  L.push(`Bot: copy ${card.bot.template}. It plays by: ${card.bot.plays_by} It has won when: ${card.bot.wins_when}`);
  list("Accepted when", card.acceptance);
  if (card.hands?.checks?.length) {
    L.push(`Hand checks (the Foreman runs them before it promotes, seeds 1 to ${card.hands.seeds}): register tests/bot_hand_<hand>.gd for each, playing your bot's policy through TLHand.create(ctx, "<hand>") (idle: press nothing, and never stop on your own: the game must end its round by itself), done when the game is over, ok = it finished, and "won" (true or false) in _bot_result():`);
    for (const c of card.hands.checks) {
      const b = [c.wins_min !== undefined ? `at least ${c.wins_min}` : "", c.wins_max !== undefined ? `at most ${c.wins_max}` : ""].filter(Boolean).join(" and ");
      L.push(`- ${c.hand}: wins ${b} of ${card.hands.seeds} (measured: ${c.measured})`);
    }
    L.push(`The example's hand tests, to copy (a plan without them is refused): ${card.hands.checks.map((c) => `${cardExample(card)}tests/bot_hand_${c.hand}.gd`).join(", ")}`);
  }
  if (card.variants?.length) { L.push("Known variants:"); for (const v of card.variants) L.push(`- "${v.ask}": ${v.change}`); }
  // L1 of 21 Nov: the `fun` block (CARDS.md 2026-11-20) reaches the builders and the Planner too, not only the Designer.
  if (card.fun) {
    L.push("What makes this kind of game fun (the card's fun block: land it in the package that owns each part):");
    for (const [k, items] of Object.entries(card.fun)) for (const i of items ?? []) L.push(`- ${k.replace(/_/g, " ")}: ${i}`);
  }
  return L.join("\n") + "\n";
}

/** The exact text `tl cards brief <id>` prints (without the final newline console.log adds). */
export function cardBriefText(card) {
  return cardBrief(card).trimEnd();
}

/** One line of `tl cards list`: id, seed (or house pack), title. */
export function cardListLine(card) {
  return `${String(card.id).padEnd(24)} ${String(card.pack ?? card.seed).padEnd(14)} ${card.title}`;
}
