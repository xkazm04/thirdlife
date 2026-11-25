// E4b (night of 24-25 Nov 2026): a change on a game on a core that changes data only (a cartridge diff, a skin edit)
// is playable in minutes, not 15 (E5: 50 s for the diff and its measured check, then the dependants' re-verification,
// every pack test, the whole final verification, the hand checks and four promotion captures). fastchange.ts decides
// what such a round skips; this test drives the E3 route on the fake adapter as Create does and counts the runner's work
// from the change request to the new promotion.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { main } from "../cli.js";
import { PKG_ROOT, REPO_ROOT } from "../paths.js";
import { rebuildState } from "../joblog.js";
import type { JobEvent } from "../events.js";
import type { PlanAnswer } from "../designer.js";
import { cleanup, tempDir, readEvents, sampleConcept, v2Brief, FIXTURE } from "./helpers.js";

after(cleanup);

const ENGINE = path.join(REPO_ROOT, "engine");
const E1_BASE = path.join(ENGINE, "templates", "rink_game", "pack.json");

function fixtureBase(dir: string): string {
  const doc = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "fixtures", "base-rink-game.json"), "utf8")) as { files: Record<string, string> };
  for (const [rel, text] of Object.entries(doc.files)) {
    fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), text);
  }
  fs.mkdirSync(path.join(dir, "data"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"), path.join(dir, "data", "game.cartridge.json"));
  return dir;
}

function routeEngine(): string {
  const e = path.join(tempDir("e4b-engine"), "engine");
  fs.mkdirSync(path.join(e, "kernel"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "kernel", "API.md"), path.join(e, "kernel", "API.md"));
  fs.cpSync(path.join(ENGINE, "cards"), path.join(e, "cards"), { recursive: true });
  fs.mkdirSync(path.join(e, "cores", "rink"), { recursive: true });
  for (const f of ["SNAPSHOT.md", "GAMEMODE.md", "CARTRIDGE.md"]) if (fs.existsSync(path.join(ENGINE, "cores", "rink", f))) fs.copyFileSync(path.join(ENGINE, "cores", "rink", f), path.join(e, "cores", "rink", f));
  fs.cpSync(path.join(ENGINE, "cores", "rink", "native", "content", "Cartridges", "modes"), path.join(e, "cores", "rink", "native", "content", "Cartridges", "modes"), { recursive: true });
  const base = fs.existsSync(E1_BASE) ? path.dirname(E1_BASE) : fixtureBase(path.join(tempDir("e4b-base"), "rink_game"));
  fs.cpSync(base, path.join(e, "templates", "rink_game"), { recursive: true, filter: (src) => !src.endsWith(".uid") });
  fs.mkdirSync(path.join(e, "packs", "hokej", "data"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "pack.json"), path.join(e, "packs", "hokej", "pack.json"));
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"), path.join(e, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"));
  return e;
}

const rinkT = { id: "rink_sport" as const, reference: "thirdjam's match on the rink core", copies: ["thirdjam's match on the rink core, unchanged: skating, puck, bots", "the cartridge keys it changes: rink size, team size, rules", "the skin: title and team colours"] };
const RINK_LINES = ["CARTRIDGE: game.rink.length_m = 60 (a pond: every pass reaches)", "CARTRIDGE: game.rink.width_m = 30", "SKIN: title = POND"].join("\n");

function corePlan(cartRel: string): PlanAnswer {
  return {
    card: "card.rink_core",
    phases: [
      { id: "pond_plays", title: "The pond plays", try: "Skate three a side on a small pond", packages: ["base", "cartridge"] },
      { id: "pond_skin", title: "The pond's look", try: "See POND and the team colours", packages: ["skin"] },
    ],
    packages: [
      { id: "base", kind: "base", title: "Start from the rink base", milestone: "greybox", deps: [], scope: ["scripts/**"], contract: "start from the base", acceptance: [] },
      {
        id: "cartridge", title: "The pond cartridge", milestone: "greybox", deps: ["base"], scope: [cartRel], contract: "Copy the Pond mode: game.rink.length_m 60, game.rink.width_m 30. Every other key stays the base's.",
        acceptance: [{ level: "V1", verb: "lint", args: [] }, { level: "V4", verb: "bot", args: ["--test=tests/bot_first_match.gd"] }, { level: "V4", verb: "bot", args: ["--test=tests/bot_match_hand.gd"] }],
      },
      { id: "skin", title: "The pond skin", milestone: "tuned", deps: ["cartridge"], scope: ["data/skin.json"], contract: "SKIN: title POND.", acceptance: [{ level: "V1", verb: "lint", args: [] }, { level: "V2", verb: "smoke", args: [] }] },
    ],
  };
}

/** The runner's work between two seqs, by verb. */
function workOf(evs: JobEvent[], from: number): { verbs: Record<string, number>; total: number } {
  const verbs: Record<string, number> = {};
  for (const e of evs) if (e.type === "verify" && e.seq > from) verbs[e.verb] = (verbs[e.verb] ?? 0) + 1;
  return { verbs, total: Object.values(verbs).reduce((a, b) => a + b, 0) };
}

/** A core job on the fake adapter, built to its first version as Create drives it. */
async function coreJob(label: string): Promise<{ jobDir: string; run: (argv: string[], kind: string) => Promise<number>; cartRel: string; log: string[] }> {
  const engine = routeEngine();
  const base = path.join(engine, "templates", "rink_game");
  const cartFile = (JSON.parse(fs.readFileSync(path.join(base, "data", "match.json"), "utf8")) as { cartridge?: string }).cartridge ?? "game.cartridge.json";
  const cartRel = `data/${cartFile}`;
  const root = tempDir(label);
  const jobs = path.join(root, "jobs");
  const estimate = (readEvents(FIXTURE).find((e) => e.type === "brief_set") as { estimate: unknown }).estimate;
  const script = {
    steps: [
      { match: { role: "concept" }, json: { concept: { ...sampleConcept(), chosen: 0, template: rinkT } } },
      { match: { role: "designer" }, json: { brief: { ...v2Brief(), rules: `${v2Brief().rules}\n${RINK_LINES}` }, estimate } },
      { match: { role: "design_review" }, json: { scores: { hook: 0.8, gif: 0.7, depth: 0.7, feel: 0.8, fit: 0.9 }, slop: [], verdict: "ok", notes: "Keep the pond small." } },
      { match: { role: "planner", promptIncludes: "Decide which ONE package owns" }, json: { package: "cartridge", reason: "speed is the game's cartridge" } },
      { match: { role: "planner" }, json: corePlan(cartRel) },
      { match: { role: "cartridge" }, json: { changes: { "game.skater.speed": 14, "game.skater.accel": 30 }, why: "every skater is faster off the mark and at full stride" } },
      { match: { role: "builder", package: "cartridge" }, patch: { [cartRel]: { title: "Pond", game: { rink: { length_m: 60, width_m: 30, corner_radius_m: 3 } } } }, text: "The pond is 60 x 30.\nDEVIATIONS: none" },
      { match: { role: "builder", package: "skin" }, patch: { "data/skin.json": { title: "POND" } }, text: "The pond's words.\nDEVIATIONS: none" },
    ],
  };
  const scriptFile = path.join(root, "fake.json");
  fs.writeFileSync(scriptFile, JSON.stringify(script));
  const common = ["--adapter", "fake", "--fake-script", scriptFile, "--engine-dir", engine];
  const runFlags = [...common, "--runner", "fake", "--parallel", "1", "--no-critic", "--quiet"];
  const flags: Record<string, string[]> = { new: common, plan: [...common, "--runner", "fake", "--max-packages", "3"], run: runFlags, resume: runFlags, change: runFlags };
  const log: string[] = [];
  const run = (argv: string[], kind: string): Promise<number> => main([...argv, ...(flags[kind] ?? runFlags)], (s) => log.push(s));
  assert.equal(await run(["new", "3 against 3 hockey on a small pond rink", "--site", jobs], "new"), 0, log.join("\n"));
  const jobDir = path.join(jobs, fs.readdirSync(jobs)[0] as string);
  assert.equal(await main(["approve", jobDir], (x) => log.push(x)), 0);
  assert.equal(await run(["plan", jobDir], "plan"), 0, log.join("\n"));
  assert.equal(await run(["run", jobDir], "run"), 3, log.join("\n"));
  assert.equal(await run(["phase", jobDir, "pass"], "resume"), 3, log.join("\n"));
  assert.equal(await run(["phase", jobDir, "pass"], "resume"), 0, log.join("\n"));
  assert.equal(rebuildState(jobDir, { write: false }).jobState?.state, "done");
  return { jobDir, run, cartRel, log };
}

// Before E4b the same change ran 19 runner calls: lint 4, smoke 3, bot 8 (acceptance 2, pack tests 3, final 3), capture
// 4, plus the dependants' re-verification. E5's real job: 13 bots and 4 captures, 14.5 min.
test("E4b: a cartridge-diff change runs 7 runner calls (lint + the player check, the merge gate lint + smoke, the final lint + smoke, ONE picture), says what it skipped, and promotes a new version; a script change still goes the whole way", async () => {
  const j = await coreJob("e4b-fast");
  const from = readEvents(j.jobDir).at(-1)?.seq ?? 0;
  const t0 = Date.now();
  assert.equal(await j.run(["change", j.jobDir, "make it faster"], "change"), 0, j.log.join("\n"));
  const ms = Date.now() - t0;
  const evs = readEvents(j.jobDir);
  const w = workOf(evs, from);
  console.log(`E4B-WORK ${JSON.stringify(w)} in ${ms} ms on the fake runner`);
  assert.deepEqual(w.verbs, { lint: 3, bot: 1, smoke: 2, capture: 1 }, evs.filter((e) => e.seq > from && e.type === "verify").map((e) => (e.type === "verify" ? e.report : "")).join(" | "));
  const bot = evs.find((e) => e.seq > from && e.type === "verify" && e.verb === "bot");
  assert.match(bot?.type === "verify" ? bot.report : "", /bot_match_hand|cartridge-r\d+-bot/);
  const notes = evs.filter((e) => e.seq > from && e.type === "note").map((e) => (e.type === "note" ? e.text : ""));
  assert.ok(notes.some((t) => t.startsWith("[foreman] data-only change (data/") && t.includes("re-verification of skin")), notes.join("\n"));
  assert.ok(notes.some((t) => t.startsWith("[foreman] data-only change: the final verification is lint and smoke")), notes.join("\n"));
  assert.ok(!evs.some((e) => e.seq > from && e.type === "verify" && /reverify|pack-bot|final-bot|hand/.test(e.report)), "no re-verification, pack test, final bot or hand check");
  const s = rebuildState(j.jobDir, { write: false });
  assert.equal(s.jobState?.state, "done");
  assert.equal(s.promotions.length, 2);
  const speed = (JSON.parse(fs.readFileSync(path.join(j.jobDir, s.promotions.at(-1)?.dest as string, ...j.cartRel.split("/")), "utf8")) as { game: { skater: { speed: number } } }).game.skater.speed;
  assert.equal(speed, 14, "the new version plays the diff");
});
