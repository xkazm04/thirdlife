// Shared runner for the shell-script steps (kernel selftest, seeds): run with reports kept in a temp dir, count PASS/FAIL lines,
// classify a failure as clock-only from the reports (see flaky.mjs).
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { classify } from "./flaky.mjs";

const TIMEOUT_MS = 15 * 60 * 1000;

export function runScriptStep(ctx, script, label) {
  if (!ctx.resolveGodot()) return { ok: false, detail: "no Godot found: set TL_GODOT or .tl/local.json {\"godot\": ...} (tl doctor)" };
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl_gate_"));
  try {
    const r = ctx.bash(script, [], { cwd: ctx.REPO, timeout: TIMEOUT_MS, env: { TL_SELFTEST_DIR: dir } });
    const pass = (r.stdout.match(/^PASS /gm) ?? []).length;
    if (r.code === 0) return { ok: true, detail: `${pass} cases passed` };
    const { failed, clockOnly } = classify(r.stdout, dir);
    const fails = r.stdout.split(/\r?\n/).filter((l) => l.startsWith("FAIL")).slice(0, 3).map((l) => l.slice(0, 160)).join(" | ");
    const why = fails || `exit ${r.code}: ${(r.stderr || r.stdout).trim().split(/\r?\n/).slice(-2).join(" | ").slice(0, 240)}`;
    return { ok: false, clockOnly, detail: `${label}: ${failed.length} failed, ${pass} passed; ${clockOnly ? "clock-only: " : ""}${why}` };
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
