// Two steps from one file: typecheck (fast) and test (full). Needs foreman/node_modules (`npm ci` in foreman/).
import fs from "node:fs";
import path from "node:path";
const FOREMAN_PATHS = ["foreman/**", "contracts/**"];
function npm(ctx, args, timeout) {
  if (!fs.existsSync(path.join(ctx.FOREMAN, "node_modules"))) return { code: 2, stdout: "", stderr: "foreman/node_modules missing: run `npm ci` in foreman/" };
  const win = process.platform === "win32";   // npm is npm.cmd on Windows; spawn needs cmd.exe for it (no shell:true: DEP0190)
  return ctx.run(win ? "cmd.exe" : "npm", win ? ["/d", "/s", "/c", "npm", ...args] : args, { cwd: ctx.FOREMAN, timeout });
}
const tail = (r) => (r.stdout + "\n" + r.stderr).split(/\r?\n/).filter((l) => l.trim()).slice(-3).join(" | ").slice(0, 300);
export const steps = [
  { id: "foreman.typecheck", tiers: ["fast", "full"], paths: FOREMAN_PATHS,
    async run(ctx) { const r = npm(ctx, ["run", "typecheck", "--silent"], 5 * 60 * 1000); return r.code === 0 ? { ok: true, detail: "tsc --noEmit clean" } : { ok: false, detail: tail(r) }; } },
  { id: "foreman.test", tiers: ["full"], paths: FOREMAN_PATHS,
    async run(ctx) {
      const r = npm(ctx, ["test", "--silent"], 10 * 60 * 1000);
      const m = (k) => (r.stdout.match(new RegExp(`^(?:#|ℹ) ${k} (\\d+)`, "m")) ?? [])[1];
      if (r.code === 0) return { ok: true, detail: `${m("pass") ?? "?"} pass, ${m("fail") ?? "?"} fail` };
      // A failure names the failing tests and keeps the whole output: a red line that does not say which test is useless.
      const log = path.join(ctx.REPO, ".tl", "last", "foreman.test.log");
      try { fs.mkdirSync(path.dirname(log), { recursive: true }); fs.writeFileSync(log, r.stdout + "\n" + r.stderr); } catch { /* the verdict still stands */ }
      const failed = [...new Set((r.stdout.match(/^\s*(?:✖|not ok \d+ -) .+$/gm) ?? []).map((l) => l.trim().replace(/\s*\(\d+(\.\d+)?ms\)$/, "")))];
      const names = failed.length ? failed.slice(0, 5).join(" | ").slice(0, 400) : tail(r);
      return { ok: false, detail: `${m("fail") ?? "?"} failed: ${names} (full output: .tl/last/foreman.test.log)` };
    } },
];
