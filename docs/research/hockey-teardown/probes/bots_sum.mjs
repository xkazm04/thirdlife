// H2 bots probe: summarise the cells of tests/bots_probe.gd. node sum.mjs <out dir> [--json]
// Per minute = per 3600 live frames, pooled over the seeds of a cell (sum of counts / sum of live minutes).
import fs from "node:fs"; import path from "node:path";
const root = process.argv[2]; const asJson = process.argv.includes("--json");
const find = (o) => { if (!o || typeof o !== "object") return null; if (o.bots) return o; for (const k in o) { const x = find(o[k]); if (x) return x; } return null; };
const med = (a) => { const s = [...a].sort((x, y) => x - y); return s.length ? s[Math.floor(s.length / 2)] : NaN; };
const r2 = (x) => (Number.isFinite(x) ? +x.toFixed(2) : "n/a");
const cells = [];
for (const L of ["rookie", "pro", "allstar"]) for (const H of ["ai", "newcomer", "regular"]) {
  const dir = path.join(root, `${L}_${H}`); if (!fs.existsSync(dir)) continue;
  const C = {}; const A = {}; let lf = 0, n = 0, failed = 0, saves = { blue: 0, red: 0 }, ent = { blue: 0, red: 0 }, entok = { blue: 0, red: 0 }, crowd4 = 0, wins = 0, frames = 0;
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith(".json"))) {
    const r = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")); const b = find(r);
    if (!b || !r.frames_run) { failed++; continue; }
    n++; lf += b.bots.live_f; frames += r.frames_run; if (b.won) wins++;
    for (const k in b.bots.c) C[k] = (C[k] ?? 0) + b.bots.c[k];
    for (const k in b.bots.arr) A[k] = (A[k] ?? []).concat(b.bots.arr[k]);
    for (const s of ["blue", "red"]) saves[s] += b.bots.saves?.[s] ?? 0;
    const raw = b.metrics?.raw ?? {}; for (const s of ["blue", "red"]) { ent[s] += raw.entries?.[s] ?? 0; entok[s] += raw.entries_ok?.[s] ?? 0; }
    crowd4 += raw.crowd4 ?? 0;
  }
  const g = (k) => C[k] ?? 0; const min = lf / 3600; const pm = (k) => g(k) / min;
  const who = H === "ai" ? ["blue", "red"] : ["human", "blue", "red"];
  const reach = (i, w) => { const a = A[`reach_${i}_${w}`] ?? []; const nev = g(`reach_never_${i}_${w}`); const tot = a.length + nev; return { med_f: med(a), within60: tot ? a.filter((x) => x <= 60).length / tot : NaN, never: tot ? nev / tot : NaN, carries: tot }; };
  const row = { cell: `${L} / ${H}`, seeds: n, failed, live_min: r2(min), live_min_per_match: r2(min / n), blue_wins: wins, agg: {}, play: {}, human: {} };
  for (const w of who) {
    const p = (w === "red") ? "blue" : "red"; // the side pressing this carrier
    row.agg[`carrier_${w}`] = { pressed_by: p, reach_2_3m: reach(0, w), reach_3m: reach(1, w),
      opp_within_5m: r2(g(`near0_${w}`) / g(`f_carry_${w}`)), opp_within_10m: r2(g(`near1_${w}`) / g(`f_carry_${w}`)),
      opp_within_3_33m: r2(g(`near2_${w}`) / g(`f_carry_${w}`)), opp_within_6_67m: r2(g(`near3_${w}`) / g(`f_carry_${w}`)), circle_per_min: r2(pm(`circle_${w}`)) };
  }
  for (const s of ["blue", "red"]) {
    const sk = H === "ai" ? [s] : (s === "blue" ? ["blue", "human"] : ["red"]); // a side's AI (blue AI and the human apart)
    const ai = s; const o = s === "blue" ? "red" : "blue";
    const hits = Object.keys(C).filter((k) => k.startsWith(`hit_${ai}_`) && k !== `hit_${ai}_`);
    const landed = (kind) => hits.filter((k) => k.includes(`_${kind}_`)).reduce((x, k) => x + g(k), 0);
    row.agg[`${s}_ai`] = { poke_try_pm: r2(pm(`poke_try_${ai}`)), poke_ok_pm: r2(pm(`poke_ok_${ai}`)), hit_try_pm: r2(pm(`hit_try_${ai}`)),
      body_landed_pm: r2(landed("body") / min), cross_landed_pm: r2(landed("cross") / min), knockdowns_pm: r2(hits.filter((k) => k.endsWith("knockdown")).reduce((x, k) => x + g(k), 0) / min),
      forecheckers_mean: r2(g(`fc_n_${s}`) / g(`fc_f_${s}`)), forecheck_2plus_share: r2(g(`fc_2_${s}`) / g(`fc_f_${s}`)) };
    const ok = sk.reduce((x, w) => x + g(`pass_end_${w}_ok`), 0), lost = sk.reduce((x, w) => x + g(`pass_end_${w}_lost`), 0);
    const plen = A[`pass_len_${ai}`] ?? []; const sd = A[`shot_dist_${s}`] ?? [];
    const shotsAi = g(`shot_${ai}`); const shotsAll = sk.reduce((x, w) => x + g(`shot_${w}`), 0);
    row.play[s] = { passes_ai_pm: r2(pm(`pass_${ai}`)), pass_completion_side: r2(ok / (ok + lost)), pass_len_ai_med_m: r2(med(plen)),
      chain_touches_mean: r2((A[`chain_${s}`] ?? []).reduce((x, y) => x + y, 0) / Math.max((A[`chain_${s}`] ?? []).length, 1)),
      shots_ai_pm: r2(shotsAi / min), shots_side_pm: r2(shotsAll / min), shot_dist_med_m: r2(med(sd)), shots_inside_9m: r2(sd.filter((x) => x <= 9).length / Math.max(sd.length, 1)),
      on_net_share: r2((g(`goal_${s}`) + saves[o]) / Math.max(shotsAll, 1)), goals_pm: r2(pm(`goal_${s}`)), goals_lasttouch_def: g(`goal_lasttouch_def_${s}`),
      entries_pm: r2(ent[s] / min), entry_success: r2(entok[s] / Math.max(ent[s], 1)), possession_share: r2(g(`f_poss_${s}`) / lf),
      spread_m: r2(g(`spread_${s}`) / lf), chasers_mean: r2(g(`chase_${s}`) / lf), chase2_share: r2(g(`chase2_${s}`) / lf),
      mate_dist_to_carrier_m: r2(g(`mate_dist_${s}`) / g(`mate_n_${s}`)), net_front_share: r2(g(`netfront_${s}`) / g(`f_poss_${s}`)),
      slot_covered_share: r2(g(`slotcover_${s}`) / g(`f_poss_${o}`)), idle_2s_pm: r2(pm(`idle_${s}`)), takes_ai_pm: r2(pm(`takes_${ai}`)) };
  }
  row.play.loose_share = r2(g("f_loose") / lf); row.play.scrum4_share = r2(crowd4 / lf);
  row.play.thirds = { blue_def: r2(g("f_third_blue_def") / lf), neutral: r2(g("f_third_neutral") / lf), blue_off: r2(g("f_third_blue_off") / lf) };
  if (H !== "ai") row.human = { fed_pm: r2(pm("feed_human")), mates_shots_pm: r2(pm("shot_blue")), mates_takeaways_pm: r2(pm("takeaway_blue_ai")), hits_on_him_pm: r2(pm("hit_on_human")),
    poked_off_him_pm: r2(pm("poked_off_human")), first60: { touches: r2(g("first60_touches") / n), fed: r2(g("first60_fed") / n), shots: r2(g("first60_shots") / n), passes: r2(g("first60_passes") / n), hits_taken: r2(g("first60_hit_on_human") / n), goals_for: r2(g("first60_goal_blue") / n), goals_against: r2(g("first60_goal_red") / n) } };
  cells.push(row);
}
console.log(JSON.stringify(cells, null, asJson ? 0 : 1));
