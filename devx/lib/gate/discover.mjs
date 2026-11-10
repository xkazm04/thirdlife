// Step discovery: every devx/lib/gate/steps/*.mjs exports a step (id, tiers, paths, run) or `steps` (an array of them).
// A missing directory is fine. A file that throws on import or exports a malformed step becomes a FAIL step naming the file.
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

export function validateStep(s) {
  if (!s || typeof s !== "object") return "step is not an object";
  if (typeof s.id !== "string" || !s.id) return "missing string `id`";
  if (!Array.isArray(s.tiers) || !s.tiers.length || !s.tiers.every((t) => t === "fast" || t === "full")) return "`tiers` must be a non-empty array of \"fast\"|\"full\"";
  if (!Array.isArray(s.paths) || !s.paths.every((p) => typeof p === "string")) return "`paths` must be an array of glob strings";
  if (typeof s.run !== "function") return "`run` must be a function";
  return null;
}

/** -> {steps, broken}; broken = [{file, message}] */
export async function discoverSteps(dir) {
  const steps = [], broken = [];
  let files = [];
  try { files = fs.readdirSync(dir).filter((f) => f.endsWith(".mjs")).sort(); } catch { return { steps, broken }; }
  for (const f of files) {
    let mod;
    try { mod = await import(pathToFileURL(path.join(dir, f)).href); }
    catch (e) { broken.push({ file: f, message: `import failed: ${String(e?.message ?? e).split("\n")[0]}` }); continue; }
    const list = Array.isArray(mod.steps) ? mod.steps : [{ id: mod.id, tiers: mod.tiers, paths: mod.paths, run: mod.run }];
    for (const s of list) {
      const bad = validateStep(s);
      if (bad) broken.push({ file: f, message: `malformed step${s?.id ? ` '${s.id}'` : ""}: ${bad}` });
      else steps.push({ ...s, file: f });
    }
  }
  const seen = new Set();
  return { steps: steps.filter((s) => (seen.has(s.id) ? (broken.push({ file: s.file, message: `duplicate step id '${s.id}'` }), false) : (seen.add(s.id), true))), broken };
}
