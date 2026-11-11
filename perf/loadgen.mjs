// perf/loadgen.mjs: a load generator for measuring under a busy machine (P1). It starts N processor-bound node
// processes and ends every one of them it started. It never touches a process it did not start.
//
//   node perf/loadgen.mjs run [--procs N] [--max-s S] -- <command> [args...]   run the command under load, then stop the load
//   node perf/loadgen.mjs hold [--procs N] [--max-s S]                          hold the load until Ctrl-C or --max-s
//
// N defaults to the number of logical processors (the machine is then saturated: every thread gets about half a core
// before other sessions' work is counted). --max-s (default 900) is a dead man's switch: the load ends by itself.
import { spawn } from "node:child_process";
import os from "node:os";

const argv = process.argv.slice(2);
const cmd = argv.shift();
const dd = argv.indexOf("--");
const own = dd >= 0 ? argv.slice(0, dd) : argv;
const rest = dd >= 0 ? argv.slice(dd + 1) : [];
const opt = (k, d) => { const i = own.indexOf(k); return i >= 0 ? Number(own[i + 1]) : d; };
const procs = opt("--procs", os.cpus().length);
const maxS = opt("--max-s", 900);

const kids = [];
function stopAll() { for (const k of kids) { try { k.kill("SIGKILL"); } catch { /* already gone */ } } kids.length = 0; }
process.on("exit", stopAll);
for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) process.on(sig, () => { stopAll(); process.exit(130); });

for (let i = 0; i < procs; i++) {
  // each child also ends by itself after maxS seconds, in case this parent is killed without a chance to clean up
  const k = spawn(process.execPath, ["-e", `const t=Date.now()+${maxS * 1000};let x=0;while(Date.now()<t){for(let i=0;i<1e6;i++)x+=i%7;}`], { stdio: "ignore" });
  kids.push(k);
}
console.error(`loadgen: ${procs} processor-bound processes started`);
const timer = setTimeout(() => { stopAll(); process.exit(0); }, maxS * 1000);

if (cmd === "run" && rest.length) {
  const c = spawn(rest[0], rest.slice(1), { stdio: "inherit", shell: false });
  c.on("exit", (code) => { clearTimeout(timer); stopAll(); process.exit(code ?? 1); });
  c.on("error", (e) => { console.error("loadgen: " + e.message); clearTimeout(timer); stopAll(); process.exit(2); });
} else if (cmd !== "hold") {
  console.error("usage: loadgen.mjs run|hold [--procs N] [--max-s S] [-- command...]");
  stopAll(); process.exit(2);
}
