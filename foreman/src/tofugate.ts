// H1e of 25 Nov (lane G4's half court, events 76 and 81-86): a builder's own tofu bot answered `ok: true` while its
// metrics were outside the plan's bounds (pressure_waves 0 against >= 2, scrum_share 0.453 against <= 0.3; its note:
// "bot_tofu's ok only requires one match and 3 verbs used; it does not enforce the metric bounds"), and the round merged
// and was promoted. The bounds are the Foreman's to enforce, against the plan's rows (tofu.ts), at every acceptance run
// of the plan's tofu bot (G4's court_exchange, the tofu package): a bot that passes with a metric out of bounds fails the
// round, with the rows in words, and nothing is merged. Two such rounds at most (the look's revise budget, QUALITY_ROUNDS);
// after them the round merges and the milestone look judges the same bounds and holds the job for the person, as before,
// so a bound the game cannot meet still reaches the person instead of spending builder rounds to the cap.
import fs from "node:fs";
import path from "node:path";
import type { Acceptance } from "./events.js";
import type { GateHost } from "./p10gate.js";
import type { VerifyResult } from "./verifier.js";
import { courtOf, judgeTofu, tofuMetricsFor, tofuOf } from "./tofu.js";
import { QUALITY_ROUNDS } from "./quality_state.js";

/** The words a round gets when the plan's tofu bot passed with metrics out of the plan's bounds; undefined otherwise. */
export function tofuGate(h: Pick<GateHost, "s" | "pkg" | "dir" | "rel" | "append">, id: string, a: Pick<Acceptance, "verb" | "args">, vr: VerifyResult): VerifyResult | undefined {
  const t = tofuOf(h.s.plan);
  if (t === undefined || a.verb !== "bot" || !vr.ok || !a.args.includes(`--test=${t.test}`)) return undefined;
  const p = h.pkg(id);
  if (p.round - (p.roundBase ?? 1) >= QUALITY_ROUNDS) return undefined; // the look judges it from here on
  const result = (vr.report as { bot?: { result?: { metrics?: unknown; hand?: unknown } } } | undefined)?.bot?.result;
  const m = result?.metrics;
  const metrics = m !== null && typeof m === "object" && !Array.isArray(m) ? (m as Record<string, unknown>) : undefined;
  const judged = judgeTofu(metrics, tofuMetricsFor(h.s.brief?.concept?.template, h.s.brief?.design?.verbs.length, courtOf(h.s.brief)), t.test);
  if (judged.ok) return undefined;
  const out = judged.rows.filter((r) => !r.ok).map((r) => `${r.id} ${r.value ?? "absent"} (the plan's bound: ${r.want})`);
  const summary = `${t.test} answered ok, but the Foreman judges its metrics against the plan's tofu bounds and ${out.length} ${out.length === 1 ? "is" : "are"} outside them: ${out.join("; ")}. A bot's own ok is not the check: change the game until the figures it counts are inside the bounds (never the bot's ok, never the counting).`;
  // The judgement is a failed check of its own (the next round's feedback reads the round's failed verify event).
  const file = h.dir("reports", `${id}-r${p.round}-tofu-bounds-s${h.s.lastSeq + 1}.json`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify({ schema: "tl.foreman.tofu-bounds/1", verb: "bot", level: "V4", ok: false, outcome: "failed", by: `the Foreman (tofugate.ts) on ${h.rel(vr.reportFile)}`, test: t.test, checks: judged.rows.map((r) => ({ id: `tofu.${r.id}`, ok: r.ok, detail: `${r.value ?? "absent"} (the plan's bound: ${r.want})` })), errors: [{ kind: "bounds", message: summary }] }, null, 1) + "\n");
  h.append({ type: "verify", package: id, round: p.round, level: "V4", verb: "bot", ok: false, report: h.rel(file) });
  return { ...vr, ok: false, summary, reportFile: file, verdictFile: file };
}
