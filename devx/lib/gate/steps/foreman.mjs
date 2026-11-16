// Two steps from one file: typecheck (fast) and test (full). Needs foreman/node_modules (`npm ci` in foreman/): without it both
// steps COULD NOT RUN (exit 2), never pass and never fail. foreman.test counts like devx.test (found / completed), names the failing
// tests with their file and line, and keeps the whole output in .tl/last/foreman.test.log on every run (docs/GATE-HONESTY.md).
import fs from "node:fs";
import path from "node:path";
import { cutShort } from "../counts.mjs";
import { judgeNodeTest, keepLog } from "../nodetest.mjs";
const FOREMAN_PATHS = ["foreman/**", "contracts/**"];
const MISSING = "foreman/node_modules missing: run `npm ci` in foreman/";
const hasDeps = (ctx) => fs.existsSync(path.join(ctx.FOREMAN, "node_modules"));
function npm(ctx, args, timeout) {
  const win = process.platform === "win32";   // npm is npm.cmd on Windows; spawn needs cmd.exe for it (no shell:true: DEP0190)
  return ctx.run(win ? "cmd.exe" : "npm", win ? ["/d", "/s", "/c", "npm", ...args] : args, { cwd: ctx.FOREMAN, timeout });
}
const tail = (r) => (r.stdout + "\n" + r.stderr).split(/\r?\n/).filter((l) => l.trim()).slice(-3).join(" | ").slice(0, 300);
const TYPECHECK_MS = 5 * 60 * 1000, TEST_MS = 10 * 60 * 1000;
export const steps = [
  { id: "foreman.typecheck", tiers: ["fast", "full"], paths: FOREMAN_PATHS,
    async run(ctx) {
      if (!hasDeps(ctx)) return { ok: false, notRun: true, detail: MISSING };
      const r = npm(ctx, ["run", "typecheck", "--silent"], TYPECHECK_MS);
      const cut = cutShort(r, TYPECHECK_MS);
      if (r.signal && !r.timedOut) return { ok: false, notRun: true, detail: `tsc ${cut}` };
      return r.code === 0 && !cut ? { ok: true, detail: "tsc --noEmit clean" } : { ok: false, detail: `${cut ? cut + "; " : ""}${tail(r)}` };
    } },
  { id: "foreman.test", tiers: ["full"], paths: FOREMAN_PATHS,
    async run(ctx) {
      if (!hasDeps(ctx)) return { ok: false, notRun: true, detail: MISSING };
      const r = npm(ctx, ["test", "--silent"], TEST_MS);
      keepLog(ctx.REPO, "foreman.test", r);   // every run: the one failure in six under load had no name and no output to read
      return judgeNodeTest(r, { timeoutMs: TEST_MS, log: ".tl/last/foreman.test.log" });
    } },
];
