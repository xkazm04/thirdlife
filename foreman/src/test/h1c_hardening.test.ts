// H1c of the day run of 25 Nov 2026 (editor hardening, round 3), from lane G1's real Arsenal hockey job
// (d25-arsenal .tl/jobs/three-against-three-hockey-20261125-1, PROOF-G1.md). Each test failed on main f2753e3 and passes now.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir } from "./helpers.js";
import { REPO_ROOT } from "../paths.js";
import { coreDataGate } from "../coregate.js";
import { runRinkCheck, type CoreCheckRun } from "../coreroute.js";
import { DRAW_TRUE, sendBack, type Verdict } from "../quality.js";
import type { GateHost } from "../p10gate.js";

after(cleanup);

const H1_FIX = path.join(REPO_ROOT, "foreman", "fixtures", "h1");
const G1_CART = path.join(H1_FIX, "harbour.g1.cartridge.json");
const G1_DRILL = path.join(H1_FIX, "drill_slush100.g1.cartridge.json");

/** A core job's gate host (the rink route), as e3f_change_path.test.ts builds one; records what it is told. */
function coreHost(label: string, coreCheck?: (file: string) => Promise<CoreCheckRun>): { h: GateHost; dir: string; appended: Record<string, unknown>[]; reopened: string[]; details: string[] } {
  const dir = tempDir(label);
  fs.mkdirSync(path.join(dir, "pack"), { recursive: true });
  const appended: Record<string, unknown>[] = [];
  const reopened: string[] = [];
  const details: string[] = [];
  const promoted = { state: "promoted", mergedFiles: ["data/x.json"], round: 1 };
  const plan = [{ id: "base", kind: "base", scope: ["scripts/**"] }, { id: "cartridge", scope: ["data/harbour.cartridge.json", "data/match.json"] }, { id: "harbour", scope: ["scripts/harbour.gd", "tests/bot_harbour.gd", "data/drill_*.cartridge.json", "data/tuning.json"] }];
  const h = {
    o: { ...(coreCheck !== undefined ? { coreCheck } : {}), verifier: { location: { engineDir: path.join(REPO_ROOT, "engine"), preArgs: [] } } },
    s: { plan, lastSeq: 40, notes: [], packages: { base: promoted, cartridge: promoted, harbour: promoted }, order: ["base", "cartridge", "harbour"], brief: { concept: { template: { id: "rink_sport" } } } },
    events: [],
    dir: (...p: string[]) => path.join(dir, ...p),
    rel: (abs: string) => path.relative(dir, abs).split(path.sep).join("/"),
    pkg: () => ({ round: 1, changes: [] }),
    append: (e: Record<string, unknown>) => {
      appended.push(e);
      return e;
    },
    reopen: (id: string, _reason: string, detail: string) => {
      reopened.push(id);
      details.push(detail);
    },
  } as unknown as GateHost;
  return { h, dir, appended, reopened, details };
}

// ---------------------------------------------------------------- 1. what a toy is worth

test("H1c 1 (G1: the shield was worth 0 points, pro 8/20 with and without, and the check said nothing): the Foreman's check plays each toy with and without it; the F ability that changes no match is a line the person sees", async () => {
  const cache = path.join(tempDir("h1c-toys"), "cache");
  const env = { TL_RINKLAB_EXE: path.join(H1_FIX, "fake-rinklab.mjs"), TL_RINK_CHECK_CACHE: cache };
  const was = { ...process.env };
  Object.assign(process.env, env);
  try {
    const run = await runRinkCheck(path.join(REPO_ROOT, "engine"), G1_CART);
    assert.equal(run.code, 0, run.summary);
    // the stand-in lab plays the F ability as nothing (G1's shield) and the pickups as a near nothing (as the real lab did on this cartridge)
    // H1e (25 Nov, G1's round 3: 20 seeds point the other way from 80 for three toys of four): this line said "The pickups:
    // changes little (8 of 20 wins with, 8 without)"; at 4 against 4 paired matches that is noise, so it is "not clear yet".
    assert.deepEqual(run.toys, [
      "The F ability: changes nothing (8 of 20 wins with and without)",
      "The pickups: not clear yet (won only with it 4, only without it 4, of 20)",
      "The fast-ice zones: not clear yet (won only with it 7, only without it 4, of 20)",
      "The slow-ice zones: not clear yet (won only with it 4, only without it 5, of 20)",
    ]);
    assert.match(run.summary, /toy: the F ability \(shield, slow_puck\): changes nothing, not one of 20 matches at pro plays differently without it; pro 8 of 20 wins with it, 8 without \(\+0 points; won only with it 0, only without it 0\), paired goal difference \+0, F pressed [0-9.]+ times a match \(thirdjam's regular playtester\)/);
    // the line itself: every toy a person sees, with its figures (the fast-ice zones change matches: no warning)
    const line = JSON.parse(fs.readFileSync(fs.readdirSync(cache).map((f) => path.join(cache, f))[0] as string, "utf8")) as { done: { hand: string }[] };
    assert.deepEqual(line.done.map((d) => d.hand).filter((x) => x.startsWith("toy:")).sort(), ["toy:ability", "toy:base", "toy:pickups", "toy:zones:fast_ice", "toy:zones:slow_ice"], "inside the cache");
    const again = await runRinkCheck(path.join(REPO_ROOT, "engine"), G1_CART);
    assert.deepEqual(again.toys, run.toys, "the same, read from the cache");
  } finally {
    for (const k of Object.keys(env)) delete process.env[k];
    Object.assign(process.env, was);
  }
});

// ---------------------------------------------------------------- 2. the game's cartridge, not a drill

test("H1c 2 (G1 event 57: the harbour package was refused on its own drill cartridge while the game's passed): the measured check judges the cartridge data/match.json plays; a drill beside it is validated and named, not measured; a refusal says which file it judged", async () => {
  const checked: string[] = [];
  const verdicts: Record<string, CoreCheckRun> = {
    "drill_slush100.cartridge.json": { code: 1, figures: {}, defects: ["6.33 goals a minute at rookie (5.7 goals in 0.9 min, thirdjam's regular playtester)"], summary: "GROSS DEFECTS: 6.33 goals a minute at rookie" },
    "harbour.cartridge.json": { code: 0, figures: { pro_goals_a_match: 6.8 }, summary: "measured, no warning" },
  };
  const { h, dir, appended } = coreHost("h1c-drill", async (file) => {
    checked.push(path.basename(file));
    return verdicts[path.basename(file)] ?? { code: 2, figures: {}, summary: "?" };
  });
  const ws = path.join(dir, "ws");
  fs.mkdirSync(path.join(ws, "data"), { recursive: true });
  fs.copyFileSync(G1_CART, path.join(ws, "data", "harbour.cartridge.json"));
  fs.copyFileSync(G1_DRILL, path.join(ws, "data", "drill_slush100.cartridge.json"));
  fs.writeFileSync(path.join(ws, "data", "match.json"), JSON.stringify({ difficulty: "rookie", cartridge: "harbour.cartridge.json" }));
  const f = await coreDataGate(h, "harbour", 1, ws, ["data/drill_slush100.cartridge.json", "scripts/harbour.gd"]);
  assert.equal(f, undefined, "a drill alone is not the game: no refusal");
  assert.deepEqual(checked, [], "and no measurement");
  const named = appended.find((e) => e["type"] === "note" && String(e["text"]).startsWith("[foreman] not the game's cartridge"));
  assert.equal(named?.["text"], "[foreman] not the game's cartridge: data/drill_slush100.cartridge.json (validated, not measured): the measured check judges the cartridge the game plays, data/harbour.cartridge.json, named by data/match.json");
  // both changed, the game's fails: the refusal names the file it judged and the drill it did not
  verdicts["harbour.cartridge.json"] = { code: 1, figures: {}, defects: ["6.8 goals a match in 1.5 min at pro"], summary: "GROSS DEFECTS" };
  const g = await coreDataGate(h, "cartridge", 2, ws, ["data/harbour.cartridge.json", "data/drill_slush100.cartridge.json"]);
  assert.ok(g !== undefined);
  assert.deepEqual(checked, ["harbour.cartridge.json"]);
  assert.match(g.summary, /^cartridge edit not valid: the measured check \(`[^`]+`\) finds gross defects a person would meet at once:\n- data\/harbour\.cartridge\.json: 6\.8 goals a match in 1\.5 min at pro\n/);
  assert.match(g.summary, /It judged the cartridge the game plays \(data\/harbour\.cartridge\.json, named by data\/match\.json\); data\/drill_slush100\.cartridge\.json beside it: validated, not measured \(a drill or test file is not the game\)\./);
});

// ---------------------------------------------------------------- 3. no drawing against the simulation

const LOOK1: Verdict = { ok: false, scores: { readability: 0.45, feel: 0.1 }, package: "harbour", report: "reports/critic-greybox-s88.json", notes: [
  // G1's real first note of look 1 (reports/critic-greybox-s88.json), word for word
  "I see teal and orange skaters on a pale rink; a ring of cyan beads pops up around teal #7 while orange #9, carrying a huge black cylinder, simply stays inside it. The worst thing for a first-time player is that the bubble changes nothing visible: no flare, hold, recoil or fall (images 1, 2, 9, 10). Failing checklist items visible: 5 (no hint or safe-threat teaching in any frame), 11 (no wind-up of 20 frames or more before the contact), 24 (no readable pause, shake or number pop on the hit; only beads and a few white flecks).",
  "[H] items not judged: a person must play it 6, 7",
] };

test("H1c 3 (G1 events 88-131: \"the bubble shows no bounce\" made the builder draw the rival 2.3 m from where the core had him, two rounds, the second thrown away): a worst reason that asks the core's bodies for a reaction holds the look for the person, no revise round; every other revise round on a core says to draw bodies where the core has them", () => {
  const look = { captures: ["captures/greybox-follow-f920.png"], strips: [], verdict: LOOK1, summary: "s" };
  const a = coreHost("h1c-motion");
  sendBack(a.h, "greybox", ["base", "cartridge", "harbour"], "harbour", 1, look);
  assert.deepEqual(a.reopened, [], "no revise round");
  assert.deepEqual(a.appended.filter((e) => e["type"] === "package_state"), []);
  const m = a.appended.find((e) => e["type"] === "milestone") as { summary: string; round: number } | undefined;
  assert.equal(m?.round, 2, "held for the quality card");
  assert.match(m?.summary ?? "", /^critic \(V5\) NOT ok: the critic asks the bodies for a reaction the rink core does not do \(recoil\); a package could only draw a body away from where the core has it/);
  assert.ok(a.appended.some((e) => e["type"] === "note" && String(e["text"]).startsWith("[foreman] the critic asks the core for a body reaction on the greybox look")));
  // a picture a package can draw true still revises, and the round is told to draw the bodies where the core has them
  const b = coreHost("h1c-picture");
  sendBack(b.h, "greybox", ["base", "cartridge", "harbour"], "harbour", 1, { ...look, verdict: { ...LOOK1, notes: ["I see the harbour; the worst thing is that the opening hint is drawn on top of the commentary line for ten seconds."] } });
  assert.deepEqual(b.reopened, ["harbour"]);
  assert.ok(b.details[0]?.includes(DRAW_TRUE), b.details[0]);
  assert.match(DRAW_TRUE, /draw them where the core has them, never away from it/);
  // a retry the person asked for still runs a round
  const c = coreHost("h1c-retry");
  sendBack(c.h, "greybox", ["base", "cartridge", "harbour"], "harbour", 3, look, "make the bubble flash when it is hit");
  assert.deepEqual(c.reopened, ["harbour"]);
});
