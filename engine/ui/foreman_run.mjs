// N6: the door the designer panel uses to start the Foreman. It runs `node <cli> <step...>` one step after another
// (for example approve, then plan, then run), stops at the first step that does not exit as expected, and writes
// everything the Foreman printed to one log file whose last line the panel reads. It builds nothing itself and never
// edits a job directory: every step is a Foreman command line.
//
//   node foreman_run.mjs --log <file> --cli <foreman/dist/cli.js> -- <cmd> <args...> [ ";;" <cmd> <args...> ]...
//
// A step's exit code 0 continues. `run`, `resume` and `change` may also end with 3 (paused) or 1 (job failed): that
// is the job's own outcome, written in job.jsonl, and ends the chain without being an error of the door.
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const argv = process.argv.slice(2);
const sep = argv.indexOf("--");
const head = sep === -1 ? argv : argv.slice(0, sep);
const rest = sep === -1 ? [] : argv.slice(sep + 1);
const opt = (name) => {
  const i = head.indexOf(name);
  return i === -1 ? undefined : head[i + 1];
};
const logFile = opt("--log");
const cli = opt("--cli");
if (!logFile || !cli || rest.length === 0) {
  console.error("usage: foreman_run.mjs --log FILE --cli CLI -- cmd args [;; cmd args]...");
  process.exit(2);
}
fs.mkdirSync(path.dirname(logFile), { recursive: true });
const steps = [];
let cur = [];
for (const a of rest) {
  if (a === ";;") {
    if (cur.length > 0) steps.push(cur);
    cur = [];
  } else cur.push(a);
}
if (cur.length > 0) steps.push(cur);

const say = (line) => fs.appendFileSync(logFile, line + "\n");
let code = 0;
let at = "";
if (!fs.existsSync(cli)) {
  say(`[door] the Foreman is not there: ${cli}`);
  say(`[door] end code=127 step=none`);
  process.exit(127);
}
for (const step of steps) {
  at = step[0];
  say(`[door] ${new Date().toISOString()} foreman ${step.map((s) => (/\s/.test(s) ? JSON.stringify(s) : s)).join(" ")}`);
  const fd = fs.openSync(logFile, "a");
  const r = spawnSync(process.execPath, [cli, ...step], { stdio: ["ignore", fd, fd], windowsHide: true });
  fs.closeSync(fd);
  code = r.status ?? (r.error ? 126 : 125);
  if (r.error) say(`[door] could not start: ${r.error.message}`);
  say(`[door] step ${at} exit ${code}`);
  if (code !== 0) break;
}
const jobOutcome = ["run", "resume", "change"].includes(at) && (code === 1 || code === 3);
say(`[door] end code=${code} step=${at} ${code === 0 || jobOutcome ? "ok" : "error"}`);
process.exit(code);
