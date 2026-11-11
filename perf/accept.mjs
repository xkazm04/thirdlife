// perf/accept.mjs: the "limits that hold" acceptance in one command. Under ONE load generator it runs the same verbs on the
// same pack with two engines at once (the engine under test and a pristine engine, for example the main checkout's) so that both
// see the same load, and prints both verdicts.
//   node perf/accept.mjs --pack <dir> --engine <engine dir> --base <other engine dir> [--verbs bot,invariants] [--runs 5] [--procs N]
// Exit 0 when every run of --engine passed (the base engine failing is the expected finding and does not change the exit code).
import { spawn } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const a = process.argv.slice(2);
const get = (k, d) => { const i = a.indexOf(k); return i >= 0 ? a[i + 1] : d; };
const pack = get("--pack"), engine = get("--engine"), base = get("--base");
if (!pack || !engine || !base) { console.error("--pack, --engine and --base are required"); process.exit(2); }
const procs = get("--procs", String(os.cpus().length));
const common = ["--pack", pack, "--verbs", get("--verbs", "bot,invariants"), "--runs", get("--runs", "5"), "--seed", get("--seed", "1")];

const load = spawn(process.execPath, [path.join(here, "loadgen.mjs"), "hold", "--procs", procs, "--max-s", "3300"], { stdio: "ignore" });
const stop = () => { try { load.kill("SIGKILL"); } catch { /* gone */ } };
process.on("exit", stop);
await new Promise((r) => setTimeout(r, 1500));
const run = (label, eng) => new Promise((resolve) => {
  const c = spawn(process.execPath, [path.join(here, "stress.mjs"), "--engine", eng, ...common], { stdio: ["ignore", "pipe", "inherit"] });
  let out = "";
  c.stdout.on("data", (d) => { out += d; });
  c.on("exit", (code) => resolve({ label, code, out }));
});
const [mine, theirs] = await Promise.all([run("ENGINE UNDER TEST", engine), run("BASE ENGINE", base)]);
stop();
for (const r of [theirs, mine]) console.log(`==== ${r.label} (${r.label === "BASE ENGINE" ? base : engine}) under ${procs} load processes\n${r.out.trim()}`);
process.exit(mine.code === 0 ? 0 : 1);
