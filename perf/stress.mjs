// perf/stress.mjs: run runner verbs on a pack N times, optionally under the load generator, and print one line per run.
//   node perf/stress.mjs --engine <engine dir> --pack <dir> [--verbs bot,invariants] [--runs 5] [--load [N]] [--seed 1]
// --expect-exit 3: every run must end exit 3 / outcome watchdog with the processor-time message (a real endless loop).
// Exit 0 when every run passed, 1 when any failed. Starts only the processes it needs and ends all of them.
import { spawn, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const a = process.argv.slice(2);
const get = (k, d) => { const i = a.indexOf(k); return i >= 0 ? a[i + 1] : d; };
const engine = path.resolve(get("--engine", "engine"));
const pack = get("--pack");
const verbs = get("--verbs", "bot,invariants").split(",");
const runs = Number(get("--runs", 5));
const seed = get("--seed", "1");
const expect = Number(get("--expect-exit", 0));   // 3 for a pack with a real endless loop: stopped as the pack's failure
const li = a.indexOf("--load");
const loadN = li >= 0 ? (a[li + 1] && !a[li + 1].startsWith("--") ? Number(a[li + 1]) : os.cpus().length) : 0;
const godot = process.env.TL_GODOT ?? "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe";
if (!pack) { console.error("--pack is required"); process.exit(2); }

let load = null;
if (loadN > 0) {
  load = spawn(process.execPath, [path.join(path.dirname(fileURLToPath(import.meta.url)), "loadgen.mjs"), "hold", "--procs", String(loadN), "--max-s", "1500"], { stdio: "ignore" });
  await new Promise((r) => setTimeout(r, 1500));
}
const stop = () => { try { load?.kill("SIGKILL"); } catch { /* gone */ } };
process.on("exit", stop);

let fails = 0, n = 0;
for (const verb of verbs) {
  for (let i = 0; i < runs; i++) {
    const report = path.join(os.tmpdir(), `p1_stress_${process.pid}_${verb}_${i}.json`);
    const t0 = Date.now();
    const r = spawnSync(godot, ["--headless", "--path", engine, "res://kernel/host/host.tscn", "--", verb, `--pack=${pack}`, `--seed=${seed}`, `--report=${report}`],
      { encoding: "utf8", maxBuffer: 64 << 20, env: { ...process.env, MSYS_NO_PATHCONV: "1" } });
    let rep = null;
    try { rep = JSON.parse(fs.readFileSync(report, "utf8")); fs.unlinkSync(report); } catch { /* no report */ }
    const bad = rep ? rep.checks.filter((c) => !c.ok).map((c) => `${c.id}: ${c.detail}`) : ["no report (exit " + r.status + ")"];
    n++;
    const ok = r.status === expect && (expect !== 3 || rep?.outcome === "watchdog" && /processor time/.test(JSON.stringify(rep.errors)));
    if (!ok) fails++;
    const m = rep?.metrics ?? {};
    console.log(`${ok ? "PASS" : "FAIL"} ${verb} run ${i + 1}/${runs} exit ${r.status} ${((Date.now() - t0) / 1000).toFixed(1)}s p50 ${m.frame_ms_p50 ?? "-"} p99 ${m.frame_ms_p99 ?? "-"}${bad.length ? "  " + bad.join(" | ").slice(0, 300) : ""}${expect === 3 && rep ? "  " + (rep.errors[0]?.message ?? "").slice(0, 200) : ""}`);
  }
}
stop();
console.log(`${fails === 0 ? "PASS" : "FAIL"} ${n - fails}/${n} runs passed${loadN ? ` under ${loadN} load processes` : ""}`);
process.exit(fails ? 1 : 0);
