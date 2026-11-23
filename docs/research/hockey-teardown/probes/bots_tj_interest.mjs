// H2: thirdjam's Bar.Brain.Interest rows (its own instrument, lane A206) -> one JSON per level. node interest.mjs <rows.txt>
import fs from "node:fs";
const rows = fs.readFileSync(process.argv[2], "utf8").split("\n");
const num = (s, re) => { const m = re.exec(s); return m ? +m[1] : NaN; };
const side = (blk) => ({
  fast_pct: num(blk, /fast ([\d.]+) %/), close_pct: num(blk, /close ([\d.]+) %/), idle_pct: num(blk, /idle ([\d.]+) %/),
  shots_pm: num(blk, /shots\/min ([\d.]+)/), shots_bands: (/shots\/min [\d.]+ \((<10 \d+, 10-20 \d+, 20-30 \d+, >30 \d+)/.exec(blk) ?? [])[1],
  att_third_s_match: num(blk, /att-third s\/match ([\d.]+)/), carries: num(blk, /carries (\d+):/), carry_shot: num(blk, /: shot (\d+) %/), carry_pass: num(blk, /pass (\d+) % lost/),
  carry_lost: num(blk, /lost (\d+) %/), carry_mean_s: num(blk, /mean ([\d.]+) s/), possession_pct: num(blk, /possession ([\d.]+) %/), passes: num(blk, /passes (\d+) done/),
  pass_done_pct: num(blk, /done (\d+) %/), net_front_att_pct: num(blk, /net front in att third (\d+) %/), long_pass_done_pct: num(blk, /done over 6 m (\d+) %/),
  def_on_carrier_pct: num(blk, /on-carrier (\d+) %/), def_crease_pct: num(blk, /crease (\d+) % receiver/), def_clump_pct: num(blk, /clump (\d+) %/) });
const out = {};
for (const r of rows) {
  const lv = (/@(\w+)/.exec(r) ?? [])[1]; if (!lv) continue; out[lv] ??= { hits: { kd_given: 0, checks_landed: 0, presses: 0, cross_landed: 0, knocked_down: 0 }, frames: 0 };
  if (r.startsWith("INTEREST match")) {
    out[lv].frames += num(r, /: (\d+) frames/);
    for (const k of Object.keys(out[lv].hits)) out[lv].hits[k] += num(r, new RegExp(`${k} (\\d+)`));
  } else if (r.startsWith("INTEREST cell")) {
    const mi = r.indexOf("MATES:"), oi = r.indexOf("OPPS:"), gi = r.indexOf("skaters over 10");
    Object.assign(out[lv], { human_wins: num(r, /human wins (\d+)/), mates: side(r.slice(mi, oi)), opps: side(r.slice(oi, gi)),
      loose_bot_in_1_5s_pct: num(r, /a bot on it within 1.5 s ([\d.]+) %/), loose_first_bot_touch_s: num(r, /mean to first bot touch ([\d.]+) s/),
      human_carry_pressed_4m_pct: num(r, /human carry pressed \(opp within 4 m\) ([\d.]+) %/), play_min_match: num(r, /play min\/match ([\d.]+)/), human_shots_pm: num(r, /human shots\/min ([\d.]+)/) });
  }
}
for (const lv in out) { const m = out[lv].play_min_match * 20; out[lv].hits_pm = Object.fromEntries(Object.entries(out[lv].hits).map(([k, v]) => [k, +(v / m).toFixed(2)])); }
console.log(JSON.stringify(out, null, 1));
