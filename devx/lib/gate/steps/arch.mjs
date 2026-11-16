// Gate step: static architecture rules (devx/arch.rules.json). No Godot; well under a second on the real tree.
import { REPO } from "../../ctx.mjs";
import { runRules } from "../../arch/core.mjs";
import { makeIo } from "../../arch/util.mjs";
import { citedPathGlobs } from "../../arch/reportsindex.mjs";

export const id = "arch";
export const tiers = ["fast", "full"];
const OWN = ["engine/**", "contracts/**", "devx/**", "docs/generated/**", "context-map.json", "docs/OWNERSHIP.md", "docs/reports/**", "briefs/**"];

/** The step's --changed paths for a tree: its own inputs, plus every path a report's pack-author bullet cites (deleting
 *  one anywhere turns a stale mark in docs/generated/REPORTS.md, rule reports-index-fresh). When the reports cannot be
 *  read, the step matches every path: it may run too often, never too seldom. */
export function pathsFor(root) {
  try { return [...OWN, ...citedPathGlobs(makeIo(root))]; } catch { return ["**"]; }
}
export const paths = pathsFor(REPO);

export async function run(ctx = {}) {
  const { results } = runRules({ root: ctx.repo ?? REPO });
  const bad = results.filter((r) => !r.ok);
  const n = { found: results.length, completed: results.length };
  if (!bad.length) return { ok: true, ...n, detail: `${results.length} rules` };
  const first = bad[0].findings[0];
  return { ok: false, ...n, detail: `${bad.map((r) => r.rule.id).join(", ")}: ${first.file}${first.line ? ":" + first.line : ""} ${first.message}`.slice(0, 300) };
}
