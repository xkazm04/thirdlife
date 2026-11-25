// E3g of 25 Nov 2026: the Designer's exact fixes, made by the Foreman without the model (generate.ts `exactFix`).
// Lane E5's real job 3 (PROOF-E5c.md): two starts failed after three attempts each on checks whose fix is exact:
//   - a WORLD line with "75 widths long" / "75 by 37 widths": the player's unit is "body widths" -> "75 body widths";
//   - a SKIN line naming a field by another spelling of a field the base's skin has ("Level", "team name",
//     "team_name" for team_names): the field's own spelling.
// Anything that needs a judgement (a new number, a field the base does not have, a longer text) stays with the model.
import type { Brief } from "./events.js";
import { methodLines, WORLD_UNITS } from "./method.js";
import { baseEngineDir, coreLines, knownPath, skinFields, type CoreRoute } from "./coreroute.js";

/** A size in a bare unit: "75 widths", "37 lengths", "5.6 heights" (not already "body widths"). */
const BARE_UNIT = /(\d(?:[\d.,]*\d)?\s*(?:x\s*\d(?:[\d.,]*\d)?\s*)?)(?<!body )(widths?|lengths?|heights?)\b/gi;

/** E3g: the WORLD line with its bare units made the player's ("75 widths" -> "75 body widths"); undefined when nothing is exact. */
export function worldUnitFix(rules: string): { rules: string; fixed: string } | undefined {
  const l = methodLines(rules);
  if (l.world.length !== 1 || WORLD_UNITS.test(l.world[0] as string)) return undefined;
  const lines = rules.split(/\r?\n/);
  const at = lines.findIndex((x) => /^\s*(?:[-*]\s*)?WORLD\s*:/.test(x));
  if (at < 0) return undefined;
  const before = lines[at] as string;
  const after = before.replace(BARE_UNIT, (_m, n: string, u: string) => `${n}body ${u}`);
  if (after === before || !WORLD_UNITS.test(after)) return undefined;
  lines[at] = after;
  return { rules: lines.join("\n"), fixed: `WORLD line: the sizes in the player's units ("${before.trim().slice(0, 80)}" -> "${after.trim().slice(0, 80)}")` };
}

/** A field name as a person may spell it: lower case, spaces and dashes as underscores, a final "s" dropped. */
const loose = (f: string): string => f.toLowerCase().replace(/[\s-]+/g, "_").replace(/s$/, "");

/** E3g: SKIN lines whose field is another spelling of exactly one of the base's skin fields, given that spelling. */
export function skinFieldFix(rules: string, skin: Set<string>): { rules: string; fixed: string[] } | undefined {
  const top = [...skin].filter((x) => !x.includes(".") && !x.includes("["));
  const fixed: string[] = [];
  const lines = rules.split(/\r?\n/).map((raw) => {
    const s = coreLines(raw).skin[0];
    if (s === undefined || knownPath(s.field, skin)) return raw;
    const match = top.filter((k) => loose(k) === loose(s.field));
    if (match.length !== 1) return raw;
    fixed.push(`SKIN field "${s.field}" is the base's "${match[0] as string}"`);
    return raw.replace(new RegExp(`(SKIN\\s*:\\s*)${s.field.replace(/[.[\]]/g, "\\$&")}`), `$1${match[0] as string}`);
  });
  return fixed.length > 0 ? { rules: lines.join("\n"), fixed } : undefined;
}

/** E3g: the Designer answer's exact fixes (`{brief, estimate}`), for generate.ts; undefined when none applies. */
export function designerExactFix(value: unknown, route: CoreRoute | undefined, engineDir: string): { value: unknown; fixed: string[] } | undefined {
  const brief = (value as { brief?: Brief } | null)?.brief;
  if (typeof brief?.rules !== "string") return undefined;
  let rules = brief.rules;
  const fixed: string[] = [];
  const w = worldUnitFix(rules);
  if (w !== undefined) {
    rules = w.rules;
    fixed.push(w.fixed);
  }
  const skin = route !== undefined ? skinFields(baseEngineDir(engineDir, route)) : undefined;
  const s = skin !== undefined ? skinFieldFix(rules, skin) : undefined;
  if (s !== undefined) {
    rules = s.rules;
    fixed.push(...s.fixed);
  }
  return fixed.length > 0 ? { value: { ...(value as object), brief: { ...brief, rules } }, fixed } : undefined;
}
