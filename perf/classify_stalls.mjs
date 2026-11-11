// perf/classify_stalls.mjs: feed the real stalled verification reports of the hockey job to the Foreman's own stall classifier
// (foreman/src/foreman.ts classifyStalls, compiled into a temporary directory; nothing in foreman/ is written).
//   node perf/classify_stalls.mjs [<reports dir>]      default: the main checkout's site/ice-hockey-three-against-20261111-1/reports
// Exit 0 when every group comes out as machine_load, 1 otherwise.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL, fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const dir = process.argv[2] ?? "C:/Users/kazda/kiro/third-life/site/ice-hockey-three-against-20261111-1/reports";
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "tl_classify_"));
try {
  const tsc = path.join(repo, "foreman", "node_modules", "typescript", "bin", "tsc");
  const r = spawnSync(process.execPath, [tsc, "-p", path.join(repo, "foreman", "tsconfig.json"), "--outDir", tmp], { encoding: "utf8" });
  if (r.status !== 0) { console.error("could not compile foreman: " + (r.stdout + r.stderr).slice(0, 300)); process.exit(2); }
  fs.writeFileSync(path.join(tmp, "package.json"), '{"type":"module"}');
  fs.symlinkSync(path.join(repo, "foreman", "node_modules"), path.join(tmp, "node_modules"), "junction");
  const { classifyStalls, stallOf } = await import(pathToFileURL(path.join(tmp, "foreman.js")).href);
  const groups = {
    "round 2, bot": ["hockey_ai-r2-bot-s142", "hockey_ai-r2-bot-again-s143"],
    "round 3, invariants": ["hockey_ai-r3-invariants-s153", "hockey_ai-r3-invariants-again-s154"],
    "round 4, bot": ["hockey_ai-r4-bot-s169", "hockey_ai-r4-bot-again-s170", "hockey_ai-r4-bot-retry1-s172", "hockey_ai-r4-bot-retry2-s174", "hockey_ai-r4-bot-retry3-s176"],
  };
  let bad = 0;
  for (const [g, files] of Object.entries(groups)) {
    const runs = files.map((f) => ({ report: JSON.parse(fs.readFileSync(path.join(dir, f + ".json"), "utf8")) }));
    const v = classifyStalls(runs);
    const places = runs.map((x) => { const s = stallOf(x); return `frame ${s?.frame} ${s?.callback}`; }).join("; ");
    console.log(`${v.verdict === "machine_load" ? "PASS" : "FAIL"}  ${g}: ${v.verdict} (${files.length} reports: ${places})`);
    if (v.verdict !== "machine_load") bad++;
  }
  console.log(`${bad ? "FAIL" : "PASS"}  ${Object.values(groups).flat().length} stalled reports: ${bad ? bad + " group(s) not classified as the machine's" : "every group classified as the machine's"}`);
  process.exit(bad ? 1 : 0);
} finally { fs.rmSync(tmp, { recursive: true, force: true }); }
