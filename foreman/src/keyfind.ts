// D27 item 3 (lane J1, event 1012): the drawing package's builder told the person "the cartridge has no key for it" for
// "winding up longer for a harder shot, being easier to knock over while winding up", while the catalog has both
// (shot.charge_frames_max / charge_speed_bonus, CARTRIDGE.md:109-110; game.contact.spin_stability, :394). A builder's
// "no key" is a claim about the catalog, so the Foreman reads the catalog for it: the rows whose key or words meet the
// claim's words go with the request to the cartridge's owner, and the person is never told "no key" as a fact while the
// catalog has candidates. Pure.

/** A builder's line that says the cartridge (or the core) has no key for something. */
export const NO_KEY = /\b(?:has|have|there is|there are) no (?:cartridge )?keys?\b|\bno (?:cartridge )?key (?:for|in|that)\b|\bnot buildable as data\b|\bno key\b/i;

export interface CatalogRow {
  keys: string[];
  text: string;
  /** D27 T3 item 39: the row's listed values (an enum's `a \| b \| c` type cell), when it lists any. */
  values?: string[];
}

/** The table rows of a cartridge catalog (CARTRIDGE.md): the backticked keys of the first cell and the row's words. */
export function catalogRows(md: string): CatalogRow[] {
  const out: CatalogRow[] = [];
  for (const line of md.split(/\r?\n/)) {
    if (!line.startsWith("| `")) continue;
    const cells = line.split("|").slice(1, -1).map((c) => c.trim());
    const keys = [...(cells[0] ?? "").matchAll(/`([^`]+)`/g)].map((m) => m[1] as string).filter((k) => /^[a-z][\w.*]*(?:\[\][\w.*]*)*$/i.test(k)); // D27 T3 item 39: list entries too (`game.effects[].trigger` was never read)
    if (keys.length === 0) continue;
    // the type cell of a generated key row lists its values as `a \| b`, which the split at every bar cuts into cells
    const typed = line.split(/(?<!\\)\|/).slice(1, -1).map((c) => c.trim())[1] ?? "";
    const values = typed.includes("\\|") ? typed.split(/\\+\|/).map((v) => v.replace(/`/g, "").trim()).filter((v) => /^[a-z][a-z0-9_]*$/.test(v)) : [];
    out.push({ keys, text: cells.slice(1).join(" ").replace(/`/g, "").replace(/\s*\\+\s*/g, " | "), ...(values.length > 0 ? { values } : {}) });
  }
  return out;
}

const STOP = new Set(["the", "and", "for", "with", "that", "this", "from", "into", "over", "under", "while", "when", "than", "then", "more", "less", "every", "each", "being", "its", "his", "her", "their", "your", "you", "are", "was", "has", "have", "not", "one", "all", "any", "out", "off", "longer", "normal", "twice", "much", "very", "goes", "feels", "person", "key", "keys", "cartridge", "core", "data", "rule", "rules", "done", "buildable", "skater", "skaters", "player", "players"]);

/** The person's words and the catalog's words for the same thing, as one stem each. */
const SAME: [RegExp, string][] = [
  [/^(wind|hold|held|charg|windup)/, "charg"],
  [/^(knock|stabil|fall|topple|stumbl|easi|floor)/, "stabil"],
  [/^(fast|speed|hard|quick|magnitud)/, "speed"],
  [/^(cooldown|recharg|again)/, "cooldown"],
  [/^(heav|weigh|mass)/, "mass"], // D27 T3 item 39: "twice as heavy" is the stat skater_mass
  [/^(modifi|effect|boost|buff|power)/, "effect"], // D27 T3 item 39: "a modifier", "a boost" are the catalog's effects
];

function stems(text: string): Set<string> {
  const out = new Set<string>();
  for (const raw of text.toLowerCase().split(/[^a-z]+/)) {
    if (raw.length < 3 || STOP.has(raw)) continue;
    let w = raw.replace(/(ing|ed|er|est|es|s|ly)$/, "");
    if (w.length < 3) w = raw;
    const same = SAME.find(([re]) => re.test(raw)) ?? SAME.find(([re]) => re.test(w)); // D27 T3: "speed", "mass" keep their stem
    out.add(same ? same[1] : w);
  }
  return out;
}

/**
 * D27 lane T3, item 39 (lane J2b's Arsenal copy, event 1277: harbour said "I found no cartridge key for a modifier that
 * starts on a check"; the hint offered bump_ratio, cross_any_man, turn_rate, check_cooldown_restart and check_reach_m, and
 * missed the one that does it, `game.effects[]` with trigger `check_landed` and stats skater_mass, skater_speed,
 * skater_turn_rate): a catalog row's VALUES are searched too. A snake_case value of a row (a trigger, a stat, a kind)
 * whose every word is in a clause is a hit of the row with that value ("a landed check" meets `check_landed`), and the
 * hint names it as key = value. Rows with a value hit go first.
 */
export function valueHits(row: CatalogRow, clause: Set<string>): string[] {
  const out: string[] = [];
  for (const v of row.values ?? []) {
    if (!v.includes("_")) continue;
    const parts = [...stems(v.replace(/_/g, " "))];
    if (parts.length >= 2 && parts.every((p) => clause.has(p)) && !out.includes(v)) out.push(v);
    else if (parts.length === 1 && v.split("_").length >= 2 && clause.has(parts[0] as string) && (VALUE_ONE.has(parts[0] as string)) && !out.includes(v)) out.push(v);
  }
  return out;
}

/** Stat words a one-word value hit may stand on (skater_mass for "mass" or "heavy", skater_turn_rate is two words). */
const VALUE_ONE = new Set(["mass", "speed", "accel", "grip"].flatMap((w) => [...stems(w)]));

/**
 * Catalog rows that may hold what a "no key" line says has none: for each clause of the line (split at commas, "and"
 * and full stops), the rows whose key names share a stem with it (twice the weight) or whose words share two. At most
 * `max` rows, best first; [] when nothing meets the line.
 */
export function keysFor(rows: readonly CatalogRow[], line: string, max = 6, perClause = 2): CatalogRow[] {
  const clauses = line.split(/[,.;:]|\band\b/).map((c) => stems(c)).filter((s) => s.size > 0);
  const out: CatalogRow[] = [];
  const byValue: CatalogRow[] = [];
  for (const c of clauses) {
    const scored: [CatalogRow, number][] = [];
    for (const r of rows) {
      const inKey = [...stems(r.keys.join(" ").replace(/[._]/g, " "))].filter((s) => c.has(s)).length;
      const inText = [...stems(r.text)].filter((s) => c.has(s)).length;
      const values = valueHits(r, c).length; // D27 T3 item 39: a trigger or stat value the clause names
      const score = 2 * inKey + inText + 3 * values;
      if (values > 0 && !byValue.includes(r)) byValue.push(r);
      if (inKey > 0 || values > 0 ? score >= 3 : inText >= 3) scored.push([r, score]);
    }
    // the best rows of each clause (a clause names one thing; rows tied at the top all go)
    for (const [r] of scored.sort((a, b) => b[1] - a[1]).slice(0, perClause)) if (!out.includes(r)) out.push(r);
  }
  // rows a value hit names go first, and each brings the list it belongs to (game.effects[].trigger brings game.effects)
  const heads = byValue.flatMap((r) => r.keys.flatMap((k) => (k.includes("[]") ? [k.slice(0, k.indexOf("[]"))] : []))).flatMap((h) => rows.filter((r) => r.keys.includes(h)));
  return [...new Set([...heads, ...byValue, ...out])].slice(0, max);
}

/** The values of `row` a line names (for the hint: key = value). */
export function valuesIn(row: CatalogRow, line: string): string[] {
  return [...new Set(line.split(/[,.;:]|\band\b/).flatMap((c) => valueHits(row, stems(c))))];
}

/** The words that go with a carried "no key" line: the catalog's candidate rows, or "" when none. */
export function keyHint(rows: readonly CatalogRow[], line: string, catalogPath: string): string {
  if (!NO_KEY.test(line)) return "";
  const hits = keysFor(rows, line);
  if (hits.length === 0) return "";
  return `the catalog (${catalogPath}) has keys that may be exactly that: ${hits.map((r) => { const v = valuesIn(r, line); return `${r.keys.join(" / ")}${v.length > 0 ? ` = ${v.join(" | ")}` : ""} (${r.text.slice(0, 120).trim()})`; }).join("; ")}`;
}

/**
 * D27 lane T3, item 39 (the same job, event 1290: after the person's answer the quick cartridge diff said "no key says it",
 * and cartridge r14's builder then wrote the `mega` effect with trigger `check_landed` in 2.3 minutes): the diff's prompt
 * holds the catalog's player-words sections only, where `effects[]` reads "timed changes to stats ... given by pickups,
 * zones or hooks" and no trigger is named. The rows of the full key list that the words of the change meet go with it,
 * each with every row of the list it belongs to (an effect needs its id, target, duration, stats and trigger). "" when
 * the words meet none.
 */
export function catalogFor(md: string, text: string, max = 8): string {
  const rows = catalogRows(md);
  const hits = keysFor(rows, text, max, 2);
  if (hits.length === 0) return "";
  const heads = [...new Set(hits.flatMap((r) => r.keys.map((k) => (k.includes("[]") ? k.slice(0, k.indexOf("[]")) : k))))];
  const family = rows.filter((r) => hits.includes(r) || r.keys.some((k) => heads.some((h) => k === h || k.startsWith(`${h}[]`))));
  return family.slice(0, 30).map((r) => { const v = valuesIn(r, text); return `- ${r.keys.join(" / ")}${v.length > 0 ? ` (your words name: ${v.join(", ")})` : ""}: ${r.text.replace(/\s+/g, " ").trim()}`; }).join("\n");
}
