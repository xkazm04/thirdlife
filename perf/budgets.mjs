// perf/budgets.mjs: what a pack costs today, as a stage game (alone in a world) and as one of many (ten copies in one world).
// Figures are world-tick milliseconds from tools/world.sh (scripts + the tree's tick + every active physics space), bot mode,
// headless; each cell is the lower of two runs (a busy machine only adds time). Prints a markdown table; --json prints the rows.
//   node perf/budgets.mjs [--frames N] [--copies K] [--json] [--only name,name]
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const a = process.argv.slice(2);
const get = (k, d) => { const i = a.indexOf(k); return i >= 0 ? a[i + 1] : d; };
const frames = Number(get("--frames", 1200));
const copies = Number(get("--copies", 10));
const only = get("--only", "")?.split(",").filter(Boolean);
const hockey = process.env.TL_HOCKEY_PACK ?? "C:/Users/kazda/kiro/third-life/site/ice-hockey-three-against-20261111-1/promoted/game.ice_hockey_three_against@0.1.1";
const godot = process.env.TL_GODOT ?? "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe";

const packs = [["seed_paddle", "seed_paddle"], ["seed_wall", "seed_wall"], ["seed_drive", "seed_drive"], ["ex_bounce", "ex_bounce"], ["ex_car", "ex_car"],
  ["ex_kit", "ex_kit"], ["ex_shuffle", "ex_shuffle"], ["ex_slide", "ex_slide"], ["ex_walker", "ex_walker"], ["ex_wall", "ex_wall"], ["hockey", hockey]]
  .filter(([n]) => !only.length || only.includes(n));

function world(list, mode) {
  const r = spawnSync("bash", [path.join(repo, "engine", "tools", "world.sh"), "run", `--packs=${list}`, `--mode=${mode}`, `--frames=${frames}`], { encoding: "utf8", maxBuffer: 1 << 26, env: { ...process.env, TL_GODOT: godot } });
  const w = r.stdout.split(/\r?\n/).filter((l) => l.includes('"kind":"world"')).map((l) => JSON.parse(l))[0];
  if (!w) throw new Error("no world line: " + r.stdout.slice(0, 200) + r.stderr.slice(0, 200));
  const packsOut = r.stdout.split(/\r?\n/).filter((l) => l.includes('"kind":"pack"')).map((l) => JSON.parse(l));
  return { w, bodies: Math.max(...packsOut.map((p) => p.bodies_max ?? 0)), nodes: Math.max(...packsOut.map((p) => p.entities_max ?? 0)) };
}
/** What `invariants` itself measures (the idle run, nobody plays): each frame's best over the runs, p50 and p99. */
function idle(dir0) {
  const dir = path.isAbsolute(dir0) || dir0.includes(":") ? dir0 : [path.join(repo, "engine", "seeds", dir0), path.join(repo, "engine", "kernel", "examples", dir0)].find((d) => fs.existsSync(d));
  const rep = path.join(process.env.TEMP ?? "/tmp", `tl_budget_${process.pid}.json`);
  spawnSync("bash", [path.join(repo, "engine", "tools", "tl.sh"), "invariants", `--pack=${dir}`, "--bot-frames=60", `--report=${rep}`], { encoding: "utf8", env: { ...process.env, TL_GODOT: godot, TL_QUIET: "1" } });
  const r = JSON.parse(fs.readFileSync(rep, "utf8"));
  fs.unlinkSync(rep);
  return { p50: r.metrics?.frame_ms_p50, p99: r.metrics?.frame_ms_p99, bodies: r.metrics?.bodies_max, nodes: r.metrics?.entities_max };
}
const best = (xs) => Math.min(...xs);
const rows = [];
for (const [name, dir] of packs) {
  const mode = fs.existsSync(path.join(repo, "engine", "kernel", "examples", name, "tests")) || name.startsWith("seed_") || name === "hockey" ? "bot" : "smoke";
  try {
    const s = [world(dir, mode), world(dir, mode)];
    const m = [world(Array(copies).fill(dir).join(","), mode), world(Array(copies).fill(dir).join(","), mode)];
    const id = idle(dir);
    rows.push({ pack: name, mode, idle_p50: id.p50, idle_p99: id.p99, stage_p50: best(s.map((x) => x.w.iter_ms_p50)), stage_p99: best(s.map((x) => x.w.iter_ms_p99)), many_p50_per_pack: best(m.map((x) => x.w.iter_ms_p50)) / copies,
      many_p99_per_pack: best(m.map((x) => x.w.iter_ms_p99)) / copies, bodies: s[0].bodies, nodes: s[0].nodes });
  } catch (e) { rows.push({ pack: name, error: String(e.message).slice(0, 120) }); }
}
if (a.includes("--json")) console.log(JSON.stringify(rows, null, 1));
else {
  console.log(`| pack | mode | idle run p50 ms | idle run p99 ms | stage p50 ms | stage p99 ms | one of ${copies}: p50 ms per pack | p99 ms per pack | bodies | nodes |\n|---|---|---|---|---|---|---|---|---|---|`);
  for (const r of rows) console.log(r.error ? `| ${r.pack} | ${r.error} |` : `| ${r.pack} | ${r.mode} | ${r.idle_p50} | ${r.idle_p99} | ${r.stage_p50.toFixed(3)} | ${r.stage_p99.toFixed(3)} | ${r.many_p50_per_pack.toFixed(3)} | ${r.many_p99_per_pack.toFixed(3)} | ${r.bodies} | ${r.nodes} |`);
}
