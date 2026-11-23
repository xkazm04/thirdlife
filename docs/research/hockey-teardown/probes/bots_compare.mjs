// H2: thirdjam vs ours tables for BEHAVIOUR-BOTS.md. node compare.mjs > tables.md
import fs from "node:fs";
const T = "C:/Users/kazda/kiro/third-life/.claude/worktrees/d23-bots/.tl/";
const ours = JSON.parse(fs.readFileSync(T + "probe/sum.json", "utf8"));
const O = (lv, h) => ours.find((c) => c.cell === `${lv} / ${h}`);
const TJ = (lv, h) => JSON.parse(fs.readFileSync(`${T}tj-run/out/${lv}_${h}/sum.json`, "utf8"));
const INT = { regular: JSON.parse(fs.readFileSync(T + "tj-run/out/interest_regular/sum.json", "utf8")), novice: JSON.parse(fs.readFileSync(T + "tj-run/out/interest_novice/sum.json", "utf8")) };
const EV = {}; for (const l of ["rookie", "pro", "all_star"]) { let n = 0, min = 0; const c = {}; // the rendered matches of a level, pooled
  for (const d of fs.readdirSync(T + "tj-run/out").filter((d) => d === `game_${l}` || d.startsWith(`game_${l}_s`))) { try { const e = JSON.parse(fs.readFileSync(`${T}tj-run/out/${d}/events.json`, "utf8")); n++; min += e.sim_min; for (const k in e.counts) c[k] = (c[k] ?? 0) + e.counts[k]; } catch { } }
  EV[l] = { matches: n, sim_min: min, per_min: Object.fromEntries(Object.entries(c).map(([k, v]) => [k, v / min])) }; }
const LV = [["rookie", "rookie"], ["pro", "pro"], ["all_star", "allstar"]];
const P = (x) => (typeof x === "number" && isFinite(x) ? Math.round(x * 100) + " %" : "n/a"); const N = (x) => (typeof x === "number" && isFinite(x) ? (+x).toFixed(x >= 10 ? 0 : 1) : "n/a");
const out = []; const tab = (title, head, rows) => out.push(`\n**${title}**\n`, "| " + head.join(" | ") + " |", "|" + head.map(() => "---").join("|") + "|", ...rows.map((r) => "| " + r.join(" | ") + " |"));
const pair = (a, b) => `${a} / ${b}`;
// 1.1 time to pressure and crowding
const r11 = [];
for (const [tl, ol] of LV) for (const [th, oh, who, label] of [["brain", "ai", "blue", "all-AI: blue's carriers"], ["regular", "regular", "human", "the human (regular hand)"], ["novice", "newcomer", "human", "the human (newcomer / novice hand)"]]) {
  const t = TJ(tl, th).agg[`carrier_${who}`]; const o = O(ol, oh).agg[`carrier_${who}`];
  r11.push([ol, label, pair(P(t.reach_2_3m.within60), P(o.reach_2_3m.within60)), pair(P(t.reach_2_3m.never), P(o.reach_2_3m.never)), pair(N(t.opp_within_5m), N(o.opp_within_5m) + ` (${N(o.opp_within_3_33m)})`), pair(N(t.opp_within_10m), N(o.opp_within_10m) + ` (${N(o.opp_within_6_67m)})`)]);
}
tab("1.1 How soon and how many opponents meet the carrier (thirdjam / ours)", ["level", "carrier", "an opponent within 2.3 m inside 1 s of the take", "never reached before he let go", "opponents within 5 m (ours at rink scale 3.3 m)", "within 10 m (ours 6.7 m)"], r11);
// 1.2 forecheck
const r12 = [];
for (const [tl, ol] of LV) for (const [th, oh] of [["brain", "ai"], ["regular", "regular"]]) {
  const t = TJ(tl, th).agg.red_pressing; const o = O(ol, oh).agg.red_ai;
  r12.push([ol, oh === "ai" ? "all-AI" : "regular hand", pair(N(t.forecheckers_mean) + " of 5", N(o.forecheckers_mean) + " of 3"), pair(P(t.forecheck_2plus_share), P(o.forecheck_2plus_share))]);
}
tab("1.2 Forecheck: red skaters in blue's end while blue carries there (thirdjam / ours)", ["level", "cell", "red forecheckers, mean", "two or more"], r12);
// 1.3 sticks and bodies, the opponents (red) per minute
const r13 = [];
for (const [tl, ol] of LV) {
  const e = EV[tl]?.per_min ?? {}; const o = O(ol, "regular").agg.red_ai; const oa = O(ol, "ai").agg.red_ai; const tr = TJ(tl, "regular").human ?? {};
  const g = (k) => e[k] ?? 0;
  r13.push([ol, `${EV[tl].matches} (${N(EV[tl].sim_min)})`, pair(N(g("poke_landed_opps") + g("poke_miss_opps")), N(o.poke_try_pm)), pair(N(g("poke_landed_opps")), N(o.poke_ok_pm)), pair(N(g("hit_check_try_opps") + g("hit_cross_try_opps")), N(o.hit_try_pm)), pair(N(g("hit_check_landed_opps")), N(o.body_landed_pm)), pair(N(g("hit_cross_landed_opps")), N(o.cross_landed_pm)), pair(N(tr.bot_hits_on_him_pm), N(O(ol, "regular").human.hits_on_him_pm)), `${N(oa.poke_try_pm)} / ${N(oa.hit_try_pm)} / ${N(oa.body_landed_pm)} / ${N(oa.cross_landed_pm)}`]);
}
tab("1.3 What the opponents do with stick and body, a minute (thirdjam / ours)", ["level", "thirdjam rendered matches (minutes)", "pokes tried", "pokes that took the puck", "checks + cross-checks tried", "body checks landed", "cross-checks landed", "hits landed on the human (20 matches each)", "ours all-AI: pokes / hits tried / body / cross landed"], r13);
// 2.x ability
const r21 = []; const r22 = []; const r23 = [];
for (const [tl, ol] of LV) for (const [th, oh, ih] of [["brain", "ai", null], ["regular", "regular", "regular"]]) {
  const t = TJ(tl, th); const o = O(ol, oh); const it = ih ? INT[ih][tl] : null; const im = it ? it.play_min_match * 20 : NaN;
  for (const s of ["red", "blue"]) {
    const op = o.play[s]; const tp = t.play[s]; const is = it ? (s === "red" ? it.opps : it.mates) : null;
    r21.push([ol, oh === "ai" ? "all-AI" : "regular hand", s, pair(is ? N(is.passes / im) : "n/a", N(op.passes_ai_pm)), pair(is ? is.pass_done_pct + " %" : "n/a", P(op.pass_completion_side)), pair(N(tp.chain_touches_mean), N(op.chain_touches_mean)), pair(N(tp.shots_pm), N(op.shots_side_pm)), pair(is ? is.shots_bands : "n/a", `median ${N(op.shot_dist_med_m)} m, ${P(op.shots_inside_9m)} inside 9 m`), pair(N(tp.goals_pm), N(op.goals_pm))]);
    r22.push([ol, oh === "ai" ? "all-AI" : "regular hand", s, pair(P(tp.possession_share), P(op.possession_share)), pair(N(tp.spread_m) + " m", N(op.spread_m) + " m"), pair(N(tp.chasers_mean) + " of 5", N(op.chasers_mean) + " of 3"), pair(P(tp.chase2_share), P(op.chase2_share)), pair(N(tp.mate_dist_to_carrier_m) + " m", N(op.mate_dist_to_carrier_m) + " m"), pair(P(tp.net_front_share), P(op.net_front_share)), pair(P(tp.slot_covered_share), P(op.slot_covered_share)), pair(N(tp.idle_2s_pm), N(op.idle_2s_pm))]);
  }
  r23.push([ol, oh === "ai" ? "all-AI" : "regular hand", pair(P(t.play.loose_share), P(o.play.loose_share)), pair(P(t.play.scrum4_share), P(o.play.scrum4_share)), pair(`${P(t.play.thirds.blue_def)} ${P(t.play.thirds.neutral)} ${P(t.play.thirds.blue_off)}`, `${P(o.play.thirds.blue_def)} ${P(o.play.thirds.neutral)} ${P(o.play.thirds.blue_off)}`), pair(N(t.live_min_per_match), N(o.live_min_per_match)), pair(`${t.blue_wins}/20`, `${o.blue_wins}/${o.seeds}`)]);
}
tab("2.1 Passing and shooting, a minute (thirdjam / ours)", ["level", "cell", "side", "passes", "completed", "touches per possession", "shots", "where from (thirdjam: shots by distance band <10 / 10-20 / 20-30 / >30 m, 20 matches; ours: distance)", "goals"], r21);
tab("2.2 Shape and the man without the puck (thirdjam / ours)", ["level", "cell", "side", "possession", "spread", "chasers within 5 m of the puck", "two or more of one side chasing", "mates' distance to their carrier", "a mate at the net front while carrying", "own slot covered while defending", "idle 2 s, a minute"], r22);
tab("2.3 The puck and the match (thirdjam / ours)", ["level", "cell", "puck loose", "4+ skaters within 5 m of the puck", "puck in blue's end / neutral / red's end", "live minutes a match", "blue wins"], r23);
// entries (ours) against thirdjam's nearest figure (seconds a match a side carries in its attacking third, Interest)
const re = [];
for (const [tl, ol] of LV) for (const s of ["red", "blue"]) { const o = O(ol, "regular").play[s]; const oa = O(ol, "ai").play[s]; const it = INT.regular[tl][s === "red" ? "opps" : "mates"];
  re.push([ol, s, `${N(it.att_third_s_match)} s a match`, `${N(it.carry_shot)} / ${N(it.carry_pass)} / ${N(it.carry_lost)} %`, `${N(o.entries_pm)} / ${P(o.entry_success)}`, `${N(oa.entries_pm)} / ${P(oa.entry_success)}`]); }
tab("2.3b Getting into the attacking zone (thirdjam's own figures / ours; regular hand)", ["level", "side", "thirdjam: carrying in its attacking third", "thirdjam: a bot carry ends in shot / pass / loss", "ours: entries a minute / kept 2 s or shot (regular hand)", "ours all-AI: entries / kept"], re);
// human
const rh = [];
for (const [tl, ol] of LV) for (const [th, oh] of [["novice", "newcomer"], ["regular", "regular"]]) {
  const t = TJ(tl, th).human; const o = O(ol, oh).human; const it = INT[th][tl];
  rh.push([ol, oh, pair(N(t.fed_pm), N(o.fed_pm)), pair(N(t.mates_shots_pm), N(o.mates_shots_pm)), pair(N(t.bot_hits_on_him_pm), N(o.hits_on_him_pm)), pair(N(t.touches_pm), N(o.first60.touches) + " in his first 60 s"), pair(N(t.first_touch_s_med) + " s", "n/a"), pair(N(it.human_carry_pressed_4m_pct) + " %", "see 1.1")]);
}
tab("2.4 The human's mates and opponents (thirdjam / ours)", ["level", "hand", "mates' passes to him a minute", "mates' shots a minute", "opponents' hits landed on him a minute", "his touches a minute", "first touch (median)", "his carries with an opponent within 4 m (thirdjam's own figure)"], rh);
console.log(out.join("\n"));
