// E3 of 24-25 Nov: the quality gates of a game on a core (coreroute.ts). The hand-built gates (the tofu rows, the
// blockout, the house hockey's bot figures) assume a hand-written simulation; on a core the simulation is the core's,
// so the floor is:
//   1. before any runner verb, every cartridge or rules file a round changed is validated (lane E2's validator, the
//      envelope check while it is missing): a problem sends the round back with the problems, as a failed check would;
//   2. at every look, the measured check of lane E2 (`bash engine/tools/rink.sh check-cartridge <file>`) plays the
//      game's cartridge headless beside the same check on the house game's (engine/packs/hokej), and a failed check
//      makes the look NOT ok and names the package that owns the cartridge. A check that could not run is said, never
//      counted as a pass, and sends nothing to a builder (the tool is missing, not the game).
// Then the base's own bots (first match, the match hand) run as the cartridge package's acceptance, and a person plays
// the first phase. Over the Foreman's gate host, as p10gate.ts and quality.ts are.
import fs from "node:fs";
import path from "node:path";
import type { Milestone } from "./events.js";
import type { GateHost } from "./p10gate.js";
import type { GateFailure } from "./machine.js";
import { CARTRIDGE_INVALID, coreDataFiles, fakeRinkCheck, gameCartridges, runRinkCheck, validateCartridgeFile, type CoreCheckRun, type CoreRoute } from "./coreroute.js";
import { coreRouteOf } from "./templates.js";
import { isFakeRunner } from "./verbs.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import type { TofuResult, TofuRow } from "./tofu.js";
import { toPosix } from "./paths.js";

/** The job's core route (undefined for a hand-built game). */
export const jobCore = (h: Pick<GateHost, "s">): CoreRoute | undefined => coreRouteOf(h.s.brief?.concept?.template);

const reportPath = (h: GateHost, stem: string): string => h.dir("reports", `${stem}-s${h.s.lastSeq + 1}.json`);

/**
 * Before the acceptance of a round: the cartridge and rules files the round changed (`files`, workspace-relative), each
 * validated. Undefined when the job is not on a core, nothing changed, or every file is valid. A failure is written as
 * a report and a Foreman note (the next round's feedback reads it) and returned as a failed check of level V0.
 */
export async function coreDataGate(h: GateHost, id: string, round: number, ws: string, files: string[]): Promise<GateFailure | undefined> {
  if (jobCore(h) === undefined) return undefined;
  const changed = coreDataFiles(files);
  if (changed.length === 0) return undefined;
  const verdicts = await Promise.all(changed.map((f) => validateCartridgeFile(ws, f)));
  const bad = verdicts.filter((v) => v.problems.length > 0);
  const file = reportPath(h, `${id}-r${round}-cartridge`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify({ schema: "tl.foreman.cartridge/1", package: id, round, ok: bad.length === 0, files: verdicts }, null, 1) + "\n");
  if (bad.length === 0) return undefined;
  const problems = bad.flatMap((v) => v.problems.map((p) => `${p} (${v.by})`));
  const summary = `${CARTRIDGE_INVALID}: ${bad.map((v) => v.file).join(", ")}: ${clip(problems.join("; "), 1500)}. Nothing was run: a cartridge the core refuses opens no game (ctx.cores.open returns null). Fix the keys and values; the catalog and the schema are in your reference copy (ref/cores/).`;
  h.append({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${summary} [report: ${h.rel(file)}]` });
  return { verb: "lint", level: "V0", ok: false, reportFile: file, verdictFile: file, flags: [], summary, durationMs: 0 };
}

/** The measured check, by the job's runner: lane E2's script, the fake runner's stand-in, or the test seam. */
export function coreCheck(h: GateHost, file: string): Promise<CoreCheckRun> {
  const seam = (h.o as { coreCheck?: (file: string) => Promise<CoreCheckRun> }).coreCheck;
  if (seam !== undefined) return seam(file);
  return isFakeRunner(h.o.verifier.location) ? fakeRinkCheck(file) : runRinkCheck(h.o.verifier.location.engineDir, file);
}

/** The house game's side of the measured check, run once per job and kept in reports/core-house-<house>.json. */
async function houseSide(h: GateHost, core: CoreRoute): Promise<CoreCheckRun | undefined> {
  const keep = h.dir("reports", `core-house-${core.house}.json`);
  try {
    return JSON.parse(fs.readFileSync(keep, "utf8")) as CoreCheckRun;
  } catch {
    /* not measured yet */
  }
  const cart = h.dir("ref", "packs", core.house, ...core.houseCartridge.split("/"));
  if (!fs.existsSync(cart)) return undefined;
  const run = await coreCheck(h, cart);
  if (run.code !== 2) {
    fs.mkdirSync(path.dirname(keep), { recursive: true });
    fs.writeFileSync(keep, JSON.stringify(run, null, 1) + "\n");
  }
  return run;
}

const figuresText = (f: Record<string, number>): string => Object.entries(f).map(([k, v]) => `${k} ${v}`).join(", ") || "no figures";

/**
 * The measured check of a look (milestone `m`) for a job on a core: every game cartridge in pack/ checked beside the house
 * game's. Undefined when the job is not on a core or pack/ has no cartridge. `measured` false = it could not run.
 */
export async function coreLook(h: GateHost, m: Milestone): Promise<(TofuResult & { package: string; report: string; measured: boolean }) | undefined> {
  const core = jobCore(h);
  if (core === undefined) return undefined;
  const carts = gameCartridges(h.dir("pack"), h.s.plan);
  if (carts.length === 0) return undefined;
  const house = await houseSide(h, core);
  const rows: TofuRow[] = [];
  const said: string[] = [];
  let measured = true;
  let owner = carts[0]?.owner ?? h.s.plan[0]?.id ?? "";
  for (const c of carts) {
    const run = await coreCheck(h, h.dir("pack", ...c.file.split("/")));
    if (run.code === 2) measured = false;
    if (run.code === 1 && c.owner !== undefined) owner = c.owner;
    rows.push({ id: `check:${c.file}`, item: core.check, want: "exit 0", ...(run.code !== 2 ? { value: run.code } : {}), ok: run.code === 0 });
    for (const [k, v] of Object.entries(run.figures)) rows.push({ id: k, item: `${c.file}`, want: house?.figures[k] !== undefined ? `house ${house.figures[k]}` : "measured", value: v, ok: true });
    said.push(`${c.file} ${run.code === 0 ? "passed" : run.code === 1 ? "FAILED" : "could not run"} (${figuresText(run.figures)}): ${clip(run.summary, 300)}`);
  }
  const ok = rows.every((r) => r.ok);
  const by = house === undefined ? `the house game ${core.house}'s cartridge was not measured (no ref/packs/${core.house}/${core.houseCartridge})` : `the house game ${core.house} (${core.houseCartridge}): ${house.code === 0 ? "passed" : house.code === 1 ? "FAILED" : "could not run"} (${figuresText(house.figures)})`;
  const line = !measured
    ? `CORE CHECK NOT MEASURED (\`${core.check}\` could not run; not a pass, and nothing was sent to a builder): ${said.join("; ")}; ${by}`
    : ok
      ? `core check ok (\`${core.check}\`): ${said.join("; ")}; beside ${by}`
      : `CORE CHECK NOT ok (\`${core.check}\`): ${said.join("; ")}; beside ${by}. Make the cartridge play: the check's figures above are what a person will meet`;
  const file = reportPath(h, `core-${m}`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify({ schema: "tl.foreman.core/1", milestone: m, core: core.core, check: core.check, ok: ok && measured, measured, package: owner, rows, line, cartridges: carts.map((c) => toPosix(c.file)), ...(house !== undefined ? { house } : {}) }, null, 1) + "\n");
  return { ok: ok && measured, rows, line, package: owner, report: h.rel(file), measured };
}
