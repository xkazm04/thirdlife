// H2: thirdjam's rendered-game log (JAMEVENT / JAMHIT lines) -> pokes, checks, cross-checks, passes, shots by side. node events.mjs <game.log>
// Skaters 0-4 are the human's side (0 = the human, played by jam.ScriptHuman 2), 5-9 the opponents. Minutes = sim frames / 3600
// up to the last event (stoppages included: an upper bound on play time, so rates here are a lower bound).
import fs from "node:fs";
const L = fs.readFileSync(process.argv[2], "utf8").split("\n");
const C = {}; const add = (k, v = 1) => (C[k] = (C[k] ?? 0) + v);
const side = (w) => (w === 0 ? "human" : w < 5 ? "mates" : "opps");
let last = 0, prevPoss = -1, lastFrame = 0, level = "", passLen = [];
for (const ln of L) {
  let m = /JAMMATCH level=(\w+)/.exec(ln); if (m) level = m[1];
  m = /JAMEVENT (\w+) who=(-?\d+) where=\(([-\d.]+),([-\d.]+),[-\d.]+\) strength=[\d.]+ frame=(\d+) kind=(\S+)/.exec(ln);
  if (m) {
    const [, ev, who, , , fr, kind] = m; const w = +who; lastFrame = Math.max(lastFrame, +fr);
    if (ev === "poke") add(`poke_${kind === "clean" ? "landed" : "miss"}_${side(w)}`);
    if (ev === "lift") add(`cross_press_${side(w)}`);
    if (ev === "pass") add(`pass_${side(w)}`);
    if (ev === "shot") add(`shot_${side(w)}`);
    if (ev === "goal") add(`goal_${side(w)}`);
    if (ev === "possess" && w >= 0) { if (prevPoss >= 0 && (prevPoss < 5) !== (w < 5)) add(`turnover_to_${w < 5 ? "blue" : "red"}`); prevPoss = w; add(`possess_${side(w)}`); }
    continue;
  }
  m = /JAMHIT frame=(\d+) kind=(\w+) result=(\w+) checker=(-?\d+) victim=(-?\d+)/.exec(ln);
  if (m) { const [, , kind, res, ch, vi] = m; const s = side(+ch); add(`hit_${kind}_try_${s}`); if (res !== "miss") add(`hit_${kind}_landed_${s}`); if (res === "down") add(`hit_${kind}_down_${s}`); if (+vi === 0 && res !== "miss") add("hits_on_human"); }
}
const min = lastFrame / 3600; const out = { level, sim_min: +min.toFixed(2), per_min: {} };
for (const k of Object.keys(C).sort()) out.per_min[k] = +(C[k] / min).toFixed(2);
out.counts = C; console.log(JSON.stringify(out));
