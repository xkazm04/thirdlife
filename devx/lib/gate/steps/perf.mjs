// perf (full tier, P1): the headless scenarios of `tl perf` against the last QUIET baseline in perf/ledger.jsonl.
//   * no quiet baseline yet            -> pass, says so (run `tl perf run` on a quiet machine to make one)
//   * the machine is busy (measured)   -> pass WITHOUT judging, says so; nothing is recorded
//   * quiet, a metric beyond its tolerance (devx/lib/perf/ledger.mjs TOLERANCE) -> fail, naming scenario, metric, figures;
//     the gate runs a failed perf step once more, alone (clockOnly), so one noisy run cannot fail the gate
// Windowed scenarios (tour6, hero1440, load6) are left to `tl perf run`; TL_PERF_SCENARIOS=tour6,mix30,... overrides the list.
import path from "node:path";
import { compareScenario, lastQuiet, readLedger } from "../../perf/ledger.mjs";
import { judge, sample } from "../../perf/quiet.mjs";
import { SCENARIOS, bestOf } from "../../perf/scenarios.mjs";
import { machineId } from "../../commands/perf.mjs";

export const id = "perf";
export const tiers = ["full"];
export const paths = ["engine/kernel/**", "engine/kits/**", "engine/rigs/**", "engine/style/**", "engine/seeds/**", "engine/project.godot", "perf/**", "devx/lib/perf/**"];

export async function run(ctx) {
  if (!ctx.resolveGodot()) return { ok: false, detail: "no Godot found: set TL_GODOT or .tl/local.json (tl doctor)" };
  const ids = (process.env.TL_PERF_SCENARIOS ?? "mix30,pile600").split(",").filter((s) => SCENARIOS[s]);
  const rows = readLedger(path.join(ctx.REPO, "perf", "ledger.jsonl"));
  const machine = machineId();
  const baselines = Object.fromEntries(ids.map((s) => [s, lastQuiet(rows, s, machine)]));
  if (ids.every((s) => !baselines[s])) return { ok: true, detail: `no quiet baseline for ${ids.join(", ")} on this machine in perf/ledger.jsonl: not judged (tl perf run on a quiet machine records one)` };
  const pre = await sample(1500);
  const now = {};
  for (const s of ids) {
    if (!baselines[s]) continue;
    const runs = [];
    for (let i = 0; i < 2; i++) runs.push(SCENARIOS[s].run(ctx));     // best of two: a busy moment only ever adds time
    now[s] = bestOf(runs);
  }
  const post = await sample(1500);
  const v = judge([pre, post]);
  if (!v.quiet) return { ok: true, detail: `machine BUSY (use ${(v.util * 100).toFixed(0)}%, probe ${v.probe}): perf measured but NOT judged and not recorded` };
  const bad = [];
  for (const s of Object.keys(now)) {
    for (const c of compareScenario(baselines[s].scenarios[s], now[s])) {
      if (c.verdict === "REGRESSED") bad.push(`${s}/${c.metric} ${c.now} vs baseline ${c.base} (limit ${c.limit.toFixed(3)}, baseline of ${baselines[s].ts})`);
    }
  }
  if (bad.length) return { ok: false, clockOnly: !ctx.retry, detail: `perf regressed on a quiet machine: ${bad.slice(0, 4).join(" | ")}` };
  return { ok: true, detail: `${Object.keys(now).join(", ")} within tolerance of the last quiet baseline (machine quiet: use ${(v.util * 100).toFixed(0)}%, probe ${v.probe})` };
}
