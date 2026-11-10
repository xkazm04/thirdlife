// devx.test: node --test over every devx/test/**/*.test.mjs that exists (an empty set passes: other packages add theirs).
import fs from "node:fs";
import path from "node:path";
export const id = "devx.test";
export const tiers = ["fast", "full"];
export const paths = ["devx/**"];
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
  if (!files.length) return { ok: true, detail: "no devx tests yet" };
  const r = ctx.run(process.execPath, ["--test", ...files], { cwd: ctx.REPO, timeout: 10 * 60 * 1000, env: { TL_IN_GATE: "1" } });
  const num = (k) => Number((r.stdout.match(new RegExp(`^(?:#|ℹ) ${k} (\\d+)`, "m")) ?? [])[1] ?? NaN);
  const sum = `${num("pass")} pass, ${num("fail")} fail across ${files.length} files`;
  if (r.code === 0) return { ok: true, detail: sum };
  const bad = [...r.stdout.matchAll(/^\s*✖ (.+?) \(\d[\d.]*ms\)$/gm)].slice(0, 3).map((m) => m[1]).join(" | ");
  return { ok: false, detail: `${sum}; ${bad || r.stderr.trim().slice(0, 200)}` };
}
