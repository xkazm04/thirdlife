// House games (H0): every folder under engine/packs/ with a pack.json is a finished game the repo keeps and gates. For each:
// lint, smoke, every bot of its manifest's `tests`, invariants (tl.sh verbs, headless). A unit is one (pack, verb) run; it is
// completed only when the verb printed its tl.verify/1 line with ok true and exited 0. The step reports the count found and the
// count completed and fails when they differ (a stopped or incomplete run is never a pass), naming each failing pack and verb.
// The full output of every run is kept in .tl/gate-packs/<pack>.<verb>.log (gitignored; overwritten by the next run).
// TL_GATE_PACKS_DIR (path.delimiter-separated) replaces engine/packs as the roots: the seam for the broken-copy test.
import fs from "node:fs";
import path from "node:path";

export const id = "packs";
export const tiers = ["full"];
export const paths = ["engine/packs/**", "engine/kernel/**", "engine/kits/**", "engine/rigs/**", "engine/style/**", "engine/tools/tl.sh", "engine/project.godot"];

/** Pack dirs (a pack.json directly inside) under each root, sorted. Nothing is skipped: a house game is gated or it is not one. */
export function findPacks(roots) {
  const out = [];
  for (const r of roots) {
    let ents = [];
    try { ents = fs.readdirSync(r, { withFileTypes: true }); } catch { continue; }
    for (const e of ents.filter((x) => x.isDirectory()).sort((a, b) => a.name.localeCompare(b.name)))
      if (fs.existsSync(path.join(r, e.name, "pack.json"))) out.push(path.join(r, e.name));
  }
  return out;
}

/** The units of one pack: lint, smoke, one bot per manifest test, invariants. A manifest that does not parse is one failed unit. */
export function unitsOf(dir) {
  let tests = [];
  try { tests = JSON.parse(fs.readFileSync(path.join(dir, "pack.json"), "utf8")).tests ?? []; }
  catch (e) { return [{ verb: "manifest", args: [], error: `pack.json does not parse: ${String(e.message).split("\n")[0]}` }]; }
  return [{ verb: "lint", args: [] }, { verb: "smoke", args: [] },
    ...tests.map((t) => ({ verb: `bot:${path.basename(t, ".gd")}`, tl: "bot", args: [`--test=${t}`] })), { verb: "invariants", args: [] }];
}

/** The verify line of a verb's output: the last line that parses as tl.verify/1 JSON. */
export function verifyLine(stdout) {
  const lines = String(stdout).split(/\r?\n/).filter((l) => l.startsWith("{"));
  for (let i = lines.length - 1; i >= 0; i--) { try { const j = JSON.parse(lines[i]); if (j.schema === "tl.verify/1") return j; } catch { /* not JSON */ } }
  return null;
}

/** Pure core. runVerb(dir, tlVerb, args) -> {code, stdout, stderr}; keep(name, text) stores a run's output.
 *  -> {ok, found, completed, units, done, failures:[{pack, verb, why}], summary:[{pack, verb, hash, frames}]} */
export function gatePacks(dirs, runVerb, keep = () => {}) {
  let units = 0, done = 0, completed = 0;
  const failures = [], summary = [];
  for (const dir of dirs) {
    const name = path.basename(dir);
    let packOk = true;
    for (const u of unitsOf(dir)) {
      units++;
      if (u.error) { failures.push({ pack: name, verb: u.verb, why: u.error }); packOk = false; continue; }
      const r = runVerb(dir, u.tl ?? u.verb, u.args);
      keep(`${name}.${u.verb.replace(/[^A-Za-z0-9_.-]/g, "_")}.log`, `# exit ${r.code}\n${r.stdout}\n--- stderr\n${r.stderr}`);
      const v = verifyLine(r.stdout);
      if (r.code === 0 && v && v.ok === true) {
        done++;
        summary.push({ pack: name, verb: u.verb, hash: v.metrics?.state_hash?.slice(0, 16), frames: v.frames });
        continue;
      }
      packOk = false;
      const failed = (v?.checks ?? []).filter((c) => !c.ok).map((c) => `${c.id}: ${String(c.detail ?? "").slice(0, 120)}`);
      const why = failed.length ? failed.slice(0, 2).join("; ")
        : v ? `${v.outcome ?? "not ok"}${v.errors?.length ? ": " + String(v.errors[0]).slice(0, 160) : ""}`
          : `exit ${r.code}, no tl.verify/1 line: ${(r.stderr || r.stdout).trim().split(/\r?\n/).slice(-2).join(" | ").slice(0, 200)}`;
      failures.push({ pack: name, verb: u.verb, why });
    }
    if (packOk) completed++;
  }
  return { ok: dirs.length > 0 && completed === dirs.length && done === units, found: dirs.length, completed, units, done, failures, summary };
}

export async function run(ctx) {
  const roots = process.env.TL_GATE_PACKS_DIR ? process.env.TL_GATE_PACKS_DIR.split(path.delimiter).filter(Boolean) : [path.join(ctx.ENGINE, "packs")];
  const dirs = findPacks(roots);
  if (!dirs.length) return { ok: false, detail: `found 0 house games under ${roots.join(", ")}, completed 0: nothing gated is not a pass` };
  if (!ctx.resolveGodot()) return { ok: false, detail: `found ${dirs.length}, completed 0: no Godot found: set TL_GODOT or .tl/local.json (tl doctor)` };
  const logDir = path.join(ctx.REPO, ".tl", "gate-packs");
  fs.mkdirSync(logDir, { recursive: true });
  for (const f of fs.readdirSync(logDir)) if (f.endsWith(".log")) fs.rmSync(path.join(logDir, f));   // this run's output only
  const tl = path.join(ctx.ENGINE, "tools", "tl.sh");
  const res = gatePacks(dirs,
    (dir, verb, args) => ctx.bash(tl, [verb, `--pack=${dir}`, ...args], { cwd: ctx.REPO, timeout: 20 * 60 * 1000 }),
    (name, text) => fs.writeFileSync(path.join(logDir, name), text));
  const counts = `found ${res.found}, completed ${res.completed}; verb runs ${res.done} of ${res.units}`;
  const logs = `output: ${path.relative(ctx.REPO, logDir).replace(/\\/g, "/")}/`;
  if (res.ok) return { ok: true, detail: `${counts}; ${res.summary.filter((s) => s.verb.startsWith("bot:")).map((s) => `${s.pack} ${s.verb} ${s.hash}@${s.frames}`).join(", ")}; ${logs}` };
  // check.mjs prints 300 characters of a detail: the failing pack and verb names come first, one reason, then where the output is
  const byPack = [...new Set(res.failures.map((f) => f.pack))].map((p) => `${p}: ${res.failures.filter((f) => f.pack === p).map((f) => f.verb).join(", ")}`);
  const f0 = res.failures[0];
  return { ok: false, detail: `${counts}; FAILED ${byPack.join("; ")}; ${logs}; first: ${f0 ? `${f0.pack} ${f0.verb}: ${f0.why}` : "?"}` };
}
