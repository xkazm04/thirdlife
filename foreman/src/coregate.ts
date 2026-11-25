// E3 of 24-25 Nov: the quality gates of a game on a core (coreroute.ts). The hand-built gates (the tofu rows, the
// blockout, the house hockey's bot figures) assume a hand-written simulation; on a core the simulation is the core's,
// so the floor is:
//   1. before any runner verb, every cartridge or rules file a round changed is validated as the core validates it
//      (thirdjam's validator and the core's rules reader, foreman/src/cartridge.ts): a problem sends the round back with lane
//      E2's pointer-prefixed sentences, as a failed check would;
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
import { CARTRIDGE_INVALID, coreDataFiles, fakeRinkCheck, gameCartridges, runRinkCheck, sectionOf, validateCartridgeFile, type CoreCheckRun, type CoreRoute } from "./coreroute.js";
import { applyChanges, type ChangeResult } from "./cartridge.js"; // lane E2: a change set applied and validated
import { absentInChange, teamsSeen } from "./rinkjudge.js"; // E3d: a change the game cannot mean is asked back
import { generate } from "./designer.js";
import type { RunResult } from "./builder/types.js";
import { coreRouteOf } from "./templates.js";
import { isFakeRunner } from "./verbs.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import type { TofuResult, TofuRow } from "./tofu.js";
import { PKG_ROOT, stripBom, toPosix } from "./paths.js";

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
  if (bad.length === 0) return measuredGate(h, id, round, ws, changed.filter((f) => f.endsWith(".cartridge.json")));
  // Lane E2's sentences start with a JSON pointer ("at /game/skater/speeed: unknown key ... Allowed keys: ..."): kept whole, one per line.
  const problems = bad.flatMap((v) => v.problems.map((p) => `- ${v.file} ${p}`));
  const summary = `${CARTRIDGE_INVALID}: ${bad.map((v) => `${v.file} (${v.by})`).join(", ")}:\n${clip(problems.join("\n"), 2500)}\nNothing was run: a cartridge the core refuses opens no game (ctx.cores.open returns null). Fix the keys and values; the catalog and the schema are in your reference copy (ref/cores/).`;
  h.append({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${summary} [report: ${h.rel(file)}]` });
  return { verb: "lint", level: "V0", ok: false, reportFile: file, verdictFile: file, flags: [], summary, durationMs: 0 };
}

/** The person's words a round answers (the newest change request of its package), for the check's "asked for". */
const askedOf = (h: GateHost, id: string): string | undefined => (h.pkg(id).changes ?? []).at(-1);

/**
 * E3d: a valid cartridge edit is MEASURED before any runner verb too, and a gross defect (rinkjudge.ts: goals a match
 * outside thirdjam's band, a match that never ends, won idle, won by skating alone) sends it back to its owner like a
 * refused edit, with the figures and the house game's beside them. A check that cannot run sends nothing back (said in a
 * note; the look says NOT MEASURED).
 */
async function measuredGate(h: GateHost, id: string, round: number, ws: string, carts: string[]): Promise<GateFailure | undefined> {
  const core = jobCore(h);
  if (core === undefined || carts.length === 0) return undefined;
  const house = await houseSide(h, core);
  const bad: string[] = [];
  const said: string[] = [];
  for (const f of carts) {
    const run = await coreCheck(h, path.join(ws, ...f.split("/")), askedOf(h, id));
    said.push(`${f}: ${run.code === 0 ? "measured ok" : run.code === 1 ? "FAILED" : "not measured"} (${figuresText(run.figures)}): ${clip(run.summary, 500)}`);
    if (run.code === 1) bad.push(`- ${f}: ${(run.defects ?? [run.summary]).join("\n- ")}`);
  }
  const file = reportPath(h, `${id}-r${round}-measured`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify({ schema: "tl.foreman.measured/1", package: id, round, ok: bad.length === 0, said, ...(house !== undefined ? { house } : {}) }, null, 1) + "\n");
  if (bad.length === 0) return undefined;
  const beside = house !== undefined ? `The house game ${core.house} (${core.houseCartridge}) measured the same way: ${figuresText(house.figures)}.` : "";
  const summary = `${CARTRIDGE_INVALID}: the measured check (\`${core.check}\`) finds gross defects a person would meet at once:\n${bad.join("\n")}\n${beside}\nNothing was run. Change the keys that make them (the catalog says which keys move goals and match length: ref/cores/${core.core}/CARTRIDGE.md) and keep the rest of the cartridge.`;
  h.append({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${summary} [report: ${h.rel(file)}]` });
  return { verb: "lint", level: "V0", ok: false, reportFile: file, verdictFile: file, flags: [], summary, durationMs: 0 };
}

/** The measured check, by the job's runner: lane E2's script, the fake runner's stand-in, or the test seam. `asked`: the person's words. */
export function coreCheck(h: GateHost, file: string, asked?: string): Promise<CoreCheckRun> {
  const seam = (h.o as { coreCheck?: (file: string, asked?: string) => Promise<CoreCheckRun> }).coreCheck;
  if (seam !== undefined) return seam(file, asked);
  return isFakeRunner(h.o.verifier.location) ? fakeRinkCheck(file, asked) : runRinkCheck(h.o.verifier.location.engineDir, file, asked);
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

// ---------- E3b of 25 Nov: a change round on a core game as a cartridge diff (lane E2's applyChanges) ----------

/** The start of the Foreman's note (after FOREMAN_NOTE) when a change round is a cartridge diff the Foreman applies. */
export const CARTRIDGE_DIFF = "cartridge diff";

const diffFile = (h: GateHost, id: string, round: number): string => h.dir("reports", `${id}-r${round}-diff.cartridge.json`);
const diffSchema = { type: "object", additionalProperties: false, required: ["changes", "why"], properties: { changes: { type: "object" }, why: { type: "string", minLength: 1 } } } as const;
const PROMPT = path.join(PKG_ROOT, "prompts", "cartridge-change.md");
const verdictWord = (r: CoreCheckRun): string => (r.code === 0 ? "ok" : r.code === 1 ? "FAILED" : "not measured");

/** The catalog a diff is written from: CARTRIDGE.md sections 3 and 5 in the job's reference copy. */
function diffCatalog(h: GateHost, core: CoreRoute): string {
  const file = h.dir("ref", "cores", core.core, "CARTRIDGE.md");
  return [sectionOf(file, /^## 3\. /), sectionOf(file, /^## 5\. /)].filter(Boolean).join("\n\n") || "(the catalog is not in this job's reference copy: use the keys of the cartridge above)";
}

/**
 * E4's seam (applyChangeRequests): a change request whose owning package holds the game's cartridge tries a cartridge diff
 * first. One short generate call (role `cartridge`) answers {changes, why}; lane E2's applyChanges applies it to the
 * cartridge as pack/ holds it and validates it (a refused diff is asked once more with the pointer-prefixed errors); the
 * measured check runs on the cartridge before and after. A valid diff the check does not fail becomes the owner's next
 * round (`round`), run by the Foreman (diffRound), not by a builder. Anything else: the round goes to the builder as
 * before, with the reason in a note. Returns whether the round is a diff round.
 */
export async function cartridgeChange(h: GateHost, owner: string, round: number, text: string, answered = false): Promise<boolean> {
  const core = jobCore(h);
  const cart = core !== undefined ? gameCartridges(h.dir("pack"), h.s.plan).find((c) => c.owner === owner) : undefined;
  if (core === undefined || cart === undefined) return false;
  const note = (t: string): void => {
    h.append({ type: "note", package: owner, round, text: `${FOREMAN_NOTE}${t}` });
  };
  const packFile = h.dir("pack", ...cart.file.split("/"));
  const current = JSON.parse(stripBom(fs.readFileSync(packFile, "utf8"))) as Record<string, unknown>;
  let skin: unknown;
  try {
    skin = JSON.parse(stripBom(fs.readFileSync(h.dir("pack", "data", "skin.json"), "utf8")));
  } catch {
    skin = undefined;
  }
  // E3d: words that name what the game does not have ("the orange team" on a red and blue game) are asked back, in plain
  // words, through the builders' question path (a `question` event on the owner: Create and `foreman answer` reply).
  const absent = answered ? undefined : absentInChange(text, skin, current);
  if (absent !== undefined) {
    note(`${CARTRIDGE_ASKED}: "${clip(text, 200)}": ${absent}`);
    h.append({ type: "question", package: owner, text: absent });
    h.append({ type: "package_state", package: owner, state: "blocked", round, cause: "question", detail: clip(absent, 200) });
    return false;
  }
  const model = h.o.plannerModel ?? h.o.model;
  const before = await coreCheck(h, packFile, text);
  const teams = teamsSeen(skin, current).map((t, i) => `team ${i} (${t.side}): ${t.colour ?? "?"}${t.name !== undefined ? `, named "${t.name}"` : ""}`).join("; ") || "(no teams read)";
  let refused = "";
  let applied: ChangeResult | undefined;
  let after: CoreCheckRun | undefined;
  let why = "";
  const out = diffFile(h, owner, round);
  for (let attempt = 1; attempt <= 2 && applied === undefined; attempt++) {
    const vars = { title: h.s.title ?? "", sentence: h.s.sentence ?? "", change: text, file: cart.file, cartridge: JSON.stringify(current, null, 1), catalog: diffCatalog(h, core), teams, measured: `${verdictWord(before)}: ${figuresText(before.figures)}; ${clip(before.summary, 400)}`, refused };
    const res = await generate<{ changes: Record<string, unknown>; why: string }>(h.o.builder, "cartridge", fs.readFileSync(PROMPT, "utf8"), vars, diffSchema, () => [], { ...(model ? { model } : {}), timeoutMs: 5 * 60_000, attempts: 1 });
    h.logGenerateCalls(res.calls, model);
    if (!res.ok) {
      note(`${CARTRIDGE_DIFF} not made (${clip(res.reason, 200)}): the change goes to the builder`);
      return false;
    }
    why = res.value.why;
    if (Object.keys(res.value.changes).length === 0) {
      note(`${CARTRIDGE_DIFF} not made: no key says it (${clip(why, 200)}): the change goes to the builder`);
      return false;
    }
    let r: ChangeResult;
    try {
      r = await applyChanges(current, res.value.changes);
    } catch (e) {
      r = { ok: false, errors: [(e as Error).message], cartridge: current, changed: [] };
    }
    if (r.ok && r.changed.every((c) => { const m = /: (.*) -> (.*)$/.exec(c); return m !== null && m[1] === m[2]; })) {
      note(`${CARTRIDGE_DIFF} not made: the diff changes nothing (${clip(r.changed.join("; "), 200)}): the change goes to the builder`);
      return false;
    }
    if (!r.ok) {
      refused = `\n# Your previous diff was refused by thirdjam's validator\n${r.errors.map((x) => `- ${x}`).join("\n")}\nAnswer again with a diff the validator accepts.\n`;
      continue;
    }
    // E3d: the diff is measured, and a gross defect sends it back like a refusal, with the figures before and after.
    fs.mkdirSync(path.dirname(out), { recursive: true });
    fs.writeFileSync(out, JSON.stringify(r.cartridge, null, 1) + "\n");
    after = await coreCheck(h, out, text);
    if (after.code === 1) {
      refused = `\n# Your previous diff (${r.changed.join("; ")}) was measured and fails\n${(after.defects ?? [after.summary]).map((x) => `- ${x}`).join("\n")}\nBefore it the game measured: ${figuresText(before.figures)}. Answer again with a diff that does what the person asked without these.\n`;
      continue;
    }
    applied = r;
  }
  if (applied === undefined || after === undefined) {
    note(`${CARTRIDGE_DIFF} not made: refused twice (${clip(refused.replace(/\s+/g, " "), 500)}): the change goes to the builder`);
    return false;
  }
  const report = h.dir("reports", `${owner}-r${round}-diff-s${h.s.lastSeq + 1}.json`);
  fs.writeFileSync(report, JSON.stringify({ schema: "tl.foreman.diff/1", package: owner, round, file: cart.file, change: text, why, changed: applied.changed, before, after }, null, 1) + "\n");
  const said = `measured before: ${verdictWord(before)} (${figuresText(before.figures)}); after: ${verdictWord(after)} (${figuresText(after.figures)})${after.code === 0 ? `; ${clip(after.summary, 300)}` : ""}`;
  note(`${CARTRIDGE_DIFF}: ${applied.changed.join("; ")} (${clip(why, 200)}); ${said} [report: ${h.rel(report)}]`);
  return true;
}

/** The start of the Foreman's note (after FOREMAN_NOTE) when a change was asked back (it names what the game lacks). */
export const CARTRIDGE_ASKED = "change asked back";

/**
 * The owner's round when it is a diff round (a CARTRIDGE_DIFF note for this round): the diffed cartridge goes into the
 * workspace and the round is verified and merged like a builder's. A change that was asked back and is answered now is
 * tried as a diff again first, with the person's answer. Undefined otherwise (the builder runs).
 */
export async function diffRound(h: GateHost, id: string, round: number, ws: string): Promise<RunResult | undefined> {
  const diffNote = (): unknown => [...h.s.notes].reverse().find((x) => x.package === id && x.round === round && x.text.startsWith(`${FOREMAN_NOTE}${CARTRIDGE_DIFF}: `));
  if (diffNote() === undefined) {
    const asked = [...h.s.notes].reverse().find((x) => x.package === id && x.round === round && x.text.startsWith(`${FOREMAN_NOTE}${CARTRIDGE_ASKED}`));
    const p = h.pkg(id);
    if (asked === undefined || p.lastAnswer === undefined || p.openQuestion !== undefined) return undefined;
    if (!(await cartridgeChange(h, id, round, `${askedOf(h, id) ?? ""}. Asked which team, the person answered: "${p.lastAnswer}"`, true))) return undefined;
  }
  const src = diffFile(h, id, round);
  const cart = gameCartridges(h.dir("pack"), h.s.plan).find((c) => c.owner === id);
  if (diffNote() === undefined || cart === undefined || !fs.existsSync(src)) return undefined;
  fs.mkdirSync(path.dirname(path.join(ws, ...cart.file.split("/"))), { recursive: true });
  fs.copyFileSync(src, path.join(ws, ...cart.file.split("/")));
  return { ok: true, outcome: "ok", raw: { foreman: "cartridge diff", file: cart.file }, durationMs: 0 };
}

/**
 * E3d (lane E5: the person passed phase 1 with no figures, because the look waited for a package of phase 2): at every
 * phase pause of a core job the measured check runs on the game's cartridges, beside the house game's, and its figures
 * are a Foreman note on the cartridge's owner (status and Create show them with the playtest card).
 */
export async function phaseCheck(h: GateHost, phase: string): Promise<void> {
  const core = jobCore(h);
  if (core === undefined) return;
  const carts = gameCartridges(h.dir("pack"), h.s.plan);
  if (carts.length === 0) return;
  const house = await houseSide(h, core);
  for (const c of carts) {
    const owner = c.owner ?? h.s.plan[0]?.id;
    if (owner === undefined) continue;
    const run = await coreCheck(h, h.dir("pack", ...c.file.split("/")));
    const file = reportPath(h, `core-phase-${phase}`);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify({ schema: "tl.foreman.measured/1", phase, file: c.file, run, ...(house !== undefined ? { house } : {}) }, null, 1) + "\n");
    h.append({ type: "note", package: owner, round: h.pkg(owner).round, text: `${FOREMAN_NOTE}${PHASE_MEASURED} ${phase}: ${c.file} ${verdictWord(run)} (${figuresText(run.figures)}); ${clip(run.summary, 400)}${house !== undefined ? `; the house game ${core.house}: ${figuresText(house.figures)}` : ""} [report: ${h.rel(file)}]` });
  }
}

/** The start of the phase-pause figures note (after FOREMAN_NOTE). */
export const PHASE_MEASURED = "measured at the phase pause";
