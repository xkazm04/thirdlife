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
}

/** The table rows of a cartridge catalog (CARTRIDGE.md): the backticked keys of the first cell and the row's words. */
export function catalogRows(md: string): CatalogRow[] {
  const out: CatalogRow[] = [];
  for (const line of md.split(/\r?\n/)) {
    if (!line.startsWith("| `")) continue;
    const cells = line.split("|").slice(1, -1).map((c) => c.trim());
    const keys = [...(cells[0] ?? "").matchAll(/`([^`]+)`/g)].map((m) => m[1] as string).filter((k) => /^[a-z][\w.*]*$/i.test(k));
    if (keys.length === 0) continue;
    out.push({ keys, text: cells.slice(1).join(" ").replace(/`/g, "") });
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
];

function stems(text: string): Set<string> {
  const out = new Set<string>();
  for (const raw of text.toLowerCase().split(/[^a-z]+/)) {
    if (raw.length < 3 || STOP.has(raw)) continue;
    let w = raw.replace(/(ing|ed|er|est|es|s|ly)$/, "");
    if (w.length < 3) w = raw;
    const same = SAME.find(([re]) => re.test(w));
    out.add(same ? same[1] : w);
  }
  return out;
}

/**
 * Catalog rows that may hold what a "no key" line says has none: for each clause of the line (split at commas, "and"
 * and full stops), the rows whose key names share a stem with it (twice the weight) or whose words share two. At most
 * `max` rows, best first; [] when nothing meets the line.
 */
export function keysFor(rows: readonly CatalogRow[], line: string, max = 6, perClause = 2): CatalogRow[] {
  const clauses = line.split(/[,.;:]|\band\b/).map((c) => stems(c)).filter((s) => s.size > 0);
  const out: CatalogRow[] = [];
  for (const c of clauses) {
    const scored: [CatalogRow, number][] = [];
    for (const r of rows) {
      const inKey = [...stems(r.keys.join(" ").replace(/[._]/g, " "))].filter((s) => c.has(s)).length;
      const inText = [...stems(r.text)].filter((s) => c.has(s)).length;
      const score = 2 * inKey + inText;
      if (inKey > 0 ? score >= 3 : inText >= 3) scored.push([r, score]);
    }
    // the best rows of each clause (a clause names one thing; rows tied at the top all go)
    for (const [r] of scored.sort((a, b) => b[1] - a[1]).slice(0, perClause)) if (!out.includes(r)) out.push(r);
  }
  return out.slice(0, max);
}

/** The words that go with a carried "no key" line: the catalog's candidate rows, or "" when none. */
export function keyHint(rows: readonly CatalogRow[], line: string, catalogPath: string): string {
  if (!NO_KEY.test(line)) return "";
  const hits = keysFor(rows, line);
  if (hits.length === 0) return "";
  return `the catalog (${catalogPath}) has keys that may be exactly that: ${hits.map((r) => `${r.keys.join(" / ")} (${r.text.slice(0, 120).trim()})`).join("; ")}`;
}
