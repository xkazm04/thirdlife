// devx.test: node --test over every devx/test/**/*.test.mjs. Reports found (tests the runner reported) and completed (those that
// reached a verdict); zero test files, a run without its summary, a timeout or a kill is never a pass (docs/GATE-HONESTY.md).
import fs from "node:fs";
import path from "node:path";
import { judgeNodeTest, keepLog } from "../nodetest.mjs";
export const id = "devx.test";
export const tiers = ["fast", "full"];
export const paths = ["devx/**"];
const TIMEOUT_MS = 10 * 60 * 1000;
function findTests(dir) {
  let out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out = out.concat(findTests(p)); else if (e.name.endsWith(".test.mjs")) out.push(p);
  }
  return out;
}
export async function run(ctx) {
  const dir = path.join(ctx.REPO, "devx", "test");
  const files = fs.existsSync(dir) ? findTests(dir).sort() : [];
  if (!files.length) return { ok: false, found: 0, completed: 0, detail: "no devx test files under devx/test: nothing was checked" };
  const r = ctx.run(process.execPath, ["--test", ...files], { cwd: ctx.REPO, timeout: TIMEOUT_MS, env: { TL_IN_GATE: "1" } });
  const v = judgeNodeTest(r, { files: files.length, timeoutMs: TIMEOUT_MS, log: ".tl/last/devx.test.log" });
  if (!v.ok) keepLog(ctx.REPO, "devx.test", r);
  return v;
}
