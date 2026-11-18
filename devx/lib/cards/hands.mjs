// Recipe cards, lane C2 (18 Nov): the hand checks of a card (`hands`), judged the same way by `tl cards hands` and by
// the Foreman's final verification (foreman/src/handcheck.ts imports this file). Pure: no file system, no imports.

/** The test a pack registers for one hand: tests/bot_hand_<hand>.gd. */
export function handTest(hand) {
  return `tests/bot_hand_${hand}.gd`;
}

/** Wilson 95 % interval of k wins of n, whole percent. */
export function wilson(k, n) {
  if (!n) return { lo: 0, hi: 0 };
  const z = 1.96, p = k / n, d = 1 + (z * z) / n, c = (p + (z * z) / (2 * n)) / d;
  const h = (z * Math.sqrt((p * (1 - p)) / n + (z * z) / (4 * n * n))) / d;
  return { lo: Math.round(Math.max(0, c - h) * 100), hi: Math.round(Math.min(1, c + h) * 100) };
}

/** The bound of a check in words: "at least 16", "at most 0", "at least 1 and at most 5". */
export function boundText(c) {
  return [c.wins_min !== undefined ? `at least ${c.wins_min}` : "", c.wins_max !== undefined ? `at most ${c.wins_max}` : ""].filter(Boolean).join(" and ");
}

/**
 * One check's verdict from its runs. `completed` runs finished, `wins` of them said won, `unread` finished without a
 * boolean `won`. A run that does not finish is never a pass (docs/GATE-HONESTY.md).
 */
export function judgeHand(c, seeds, completed, wins, unread = 0) {
  const iv = wilson(wins, completed);
  const fig = `${wins} of ${completed} won (Wilson 95 % ${iv.lo}..${iv.hi})`;
  if (completed < seeds) return { ok: false, why: `${completed} of ${seeds} runs finished; ${fig}` };
  if (unread > 0) return { ok: false, why: `${unread} run(s) have no boolean "won" in their bot result` };
  if (c.wins_min !== undefined && wins < c.wins_min) return { ok: false, why: `${fig}; the card asks ${boundText(c)}` };
  if (c.wins_max !== undefined && wins > c.wins_max) return { ok: false, why: `${fig}; the card asks ${boundText(c)}` };
  return { ok: true, why: `${fig}; the card asks ${boundText(c)}` };
}
