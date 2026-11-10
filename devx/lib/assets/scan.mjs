// Kit scan: runs engine/tools/assets/scan_kit.gd in headless Godot and turns its TLASSET lines into manifest entries.
import fs from "node:fs";
import path from "node:path";

/** Parses scan output. Returns {rows, errors}. Rows are sorted by id so the result never depends on print order. */
export function parseScan(stdout) {
  const rows = [];
  const errors = [];
  let done = false;
  for (const line of stdout.split(/\r?\n/)) {
    if (line.startsWith("TLASSET_ERROR ")) errors.push(line.slice(14));
    else if (line.startsWith("TLASSET_DONE")) done = true;
    else if (line.startsWith("TLASSET ")) {
      try { rows.push(JSON.parse(line.slice(8))); } catch { errors.push(`unparseable scan line: ${line.slice(0, 80)}`); }
    }
  }
  if (!done) errors.push("scan did not reach TLASSET_DONE (Godot crashed or the script failed to load)");
  rows.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return { rows, errors };
}

/** Runs the scan. `ctx` is devx/lib/ctx.mjs. Returns {ok, rows, errors, ms, couldNotRun?}. */
export function runScan(ctx) {
  const godot = ctx.resolveGodot();
  if (!godot) return { ok: false, rows: [], errors: ["no Godot found (set TL_GODOT or .tl/local.json)"], ms: 0, couldNotRun: true };
  const t0 = Date.now();
  if (!fs.existsSync(path.join(ctx.ENGINE, ".godot", "global_script_class_cache.cfg"))) {
    ctx.run(godot, ["--headless", "--path", ctx.ENGINE, "--import"], { timeout: 300000 });
  }
  const r = ctx.run(godot, ["--headless", "--path", ctx.ENGINE, "-s", "tools/assets/scan_kit.gd"], { timeout: 180000 });
  const { rows, errors } = parseScan(r.stdout);
  return { ok: errors.length === 0 && rows.length > 0, rows, errors, ms: Date.now() - t0 };
}

/** The engine-owned kit_part entries for a scan. Hash is TLKit.hash (SHA-1 hex); bytes are 0 because nothing is stored. */
export function kitEntries(rows) {
  return rows.map((r) => ({
    id: r.id,
    kind: "kit_part",
    source: "procedural",
    origin: `tlkit:${r.part}`,
    hash: r.hash,
    bytes: 0,
    tris: r.tris,
    license: "first-party",
    provenance: { tool: "TLKit", author: "engine" },
    owner: "engine",
  }));
}
