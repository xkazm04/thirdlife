// H2 (day of 25 Nov 2026): a finished game on a core moves to the newest base (foreman rebase, rebase.ts). The job is built on
// the fake adapter as Create drives it (the E3 route, as e4b_fast_change.test.ts builds it); then the engine's base gets
// better (a file added, a script changed) and `foreman rebase <job>` re-copies the base under the game: its cartridge and skin
// stay byte for byte, the base's new and changed files arrive, the result is verified and promoted as version 2. A game that
// changed a base script is refused (the move would lose it). A bare pack moves the same way.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { main } from "../cli.js";
import { PKG_ROOT, REPO_ROOT } from "../paths.js";
import { rebuildState } from "../joblog.js";
import type { PlanAnswer } from "../designer.js";
import { cleanup, tempDir, readEvents, sampleConcept, v2Brief, FIXTURE } from "./helpers.js";
import { blobId, knownBase, planRebase, writeRebase } from "../rebase.js";

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
  const e = path.join(tempDir("h2-engine"), "engine");
  fs.mkdirSync(path.join(e, "kernel"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "kernel", "API.md"), path.join(e, "kernel", "API.md"));
  fs.cpSync(path.join(ENGINE, "cards"), path.join(e, "cards"), { recursive: true });
  fs.mkdirSync(path.join(e, "cores", "rink"), { recursive: true });
  for (const f of ["SNAPSHOT.md", "GAMEMODE.md", "CARTRIDGE.md"]) if (fs.existsSync(path.join(ENGINE, "cores", "rink", f))) fs.copyFileSync(path.join(ENGINE, "cores", "rink", f), path.join(e, "cores", "rink", f));
  fs.cpSync(path.join(ENGINE, "cores", "rink", "native", "content", "Cartridges", "modes"), path.join(e, "cores", "rink", "native", "content", "Cartridges", "modes"), { recursive: true });
  const base = fs.existsSync(E1_BASE) ? path.dirname(E1_BASE) : fixtureBase(path.join(tempDir("h2-base"), "rink_game"));
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

/** A core job on the fake adapter, built to its first version as Create drives it. */
async function coreJob(label: string): Promise<{ jobDir: string; run: (argv: string[], kind: string) => Promise<number>; cartRel: string; log: string[]; engine: string }> {
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
  return { jobDir, run, cartRel, log, engine };
}


const read = (f: string): string => fs.readFileSync(f, "utf8");

test("H2: foreman rebase moves a finished core game to the newest base: the base's new and changed files arrive, the cartridge, skin and match stay byte for byte, verified and promoted as version 2", async () => {
  const j = await coreJob("h2-rebase");
  const base = path.join(j.engine, "templates", "rink_game");
  const s0 = rebuildState(j.jobDir, { write: false });
  const v1 = path.join(j.jobDir, s0.promoted?.dest as string);
  // the base gets better after the game was made
  fs.writeFileSync(path.join(base, "scripts", "h2_toy.gd"), "extends RefCounted\n# H2: a newer base's file\n");
  const someScript = fs.readdirSync(path.join(base, "scripts")).find((f) => f.endsWith(".gd") && f !== "h2_toy.gd") as string;
  fs.appendFileSync(path.join(base, "scripts", someScript), "\n# H2: the newer base changed this script\n");
  const from = readEvents(j.jobDir).at(-1)?.seq ?? 0;
  const out: string[] = [];
  assert.equal(await main(["rebase", j.jobDir, "--runner", "fake", "--engine-dir", j.engine], (x) => out.push(x)), 0, out.join("\n"));
  const s = rebuildState(j.jobDir, { write: false });
  assert.equal(s.jobState?.state, "done");
  assert.equal(s.promotions.length, 2, "a new version beside the first");
  assert.match(s.promoted?.dest ?? "", /@0\.1\.1$/);
  const v2 = path.join(j.jobDir, s.promoted?.dest as string);
  assert.ok(fs.existsSync(path.join(v1, "pack.json")), "the first version is kept");
  assert.equal(read(path.join(v2, "scripts", "h2_toy.gd")), read(path.join(base, "scripts", "h2_toy.gd")), "the base's new file arrived");
  assert.equal(read(path.join(v2, "scripts", someScript)), read(path.join(base, "scripts", someScript)), "the base's changed script arrived");
  for (const f of [j.cartRel, "data/skin.json", "data/match.json"]) assert.ok(fs.readFileSync(path.join(v2, ...f.split("/"))).equals(fs.readFileSync(path.join(v1, ...f.split("/")))), `${f} kept byte for byte`);
  assert.equal(read(path.join(j.jobDir, "pack", "scripts", "h2_toy.gd")), read(path.join(base, "scripts", "h2_toy.gd")), "pack/ is the new version");
  assert.ok(fs.existsSync(path.join(j.jobDir, "ref", "base", "rink_game", "scripts", "h2_toy.gd")), "the job's reference copy of the base follows");
  const evs = readEvents(j.jobDir).filter((e) => e.seq > from);
  const verbs = evs.flatMap((e) => (e.type === "verify" ? [e.verb] : []));
  assert.deepEqual(verbs.slice(0, 2), ["lint", "smoke"]);
  assert.ok(verbs.filter((v) => v === "bot").length >= 2, `every bot of the manifest: ${verbs.join(",")}`);
  const notes = evs.flatMap((e) => (e.type === "note" ? [e.text] : []));
  assert.ok(notes.some((t) => t.startsWith("[foreman] what changed in v0.1.1 (since v0.1.0): moved to the newest base")), notes.join("\n"));
  const m = JSON.parse(read(path.join(v2, "pack.json"))) as { version: string };
  assert.equal(m.version, "0.1.1");
  // nothing more to move: a second rebase does nothing
  const out2: string[] = [];
  assert.equal(await main(["rebase", j.jobDir, "--runner", "fake", "--engine-dir", j.engine], (x) => out2.push(x)), 0, out2.join("\n"));
  assert.equal(rebuildState(j.jobDir, { write: false }).promotions.length, 2);
  assert.ok(out2.some((l) => l.includes("on the newest base already")), out2.join("\n"));
});

test("H2: a game that changed a base script is refused (the move would lose its change); the game stays as it was", async () => {
  const j = await coreJob("h2-conflict");
  const base = path.join(j.engine, "templates", "rink_game");
  const s0 = rebuildState(j.jobDir, { write: false });
  const v1 = path.join(j.jobDir, s0.promoted?.dest as string);
  const someScript = fs.readdirSync(path.join(v1, "scripts")).find((f) => f.endsWith(".gd")) as string;
  fs.appendFileSync(path.join(v1, "scripts", someScript), "\n# the game's own edit\n");
  fs.writeFileSync(path.join(base, "scripts", "h2_toy.gd"), "extends RefCounted\n");
  const out: string[] = [];
  assert.equal(await main(["rebase", j.jobDir, "--runner", "fake", "--engine-dir", j.engine], (x) => out.push(x)), 1, out.join("\n"));
  const s = rebuildState(j.jobDir, { write: false });
  assert.equal(s.promotions.length, 1);
  assert.equal(s.jobState?.state, "done");
  assert.ok(s.notes.some((n) => n.text.includes("the move to the newest base was refused") && n.text.includes(`scripts/${someScript}`)), JSON.stringify(s.notes.slice(-2)));
});

test("H2: a bare pack moves the same way: a file that is some version of the base is replaced, data the game changed is kept, git's blob ids name the base's versions", () => {
  const root = tempDir("h2-bare");
  const base = path.join(root, "base");
  const game = path.join(root, "game");
  const w = (d: string, f: string, t: string): void => {
    fs.mkdirSync(path.dirname(path.join(d, f)), { recursive: true });
    fs.writeFileSync(path.join(d, f), t);
  };
  w(base, "pack.json", JSON.stringify({ id: "template.rink_game", version: "0.1.0", kernelApi: "1.30", title: "base", tests: ["tests/bot_a.gd", "tests/bot_toys.gd"], cameras: ["follow", "top"], subject: "Skater" }));
  w(base, "scripts/main.gd", "new main\n");
  w(base, "scripts/toys.gd", "toys\n");
  w(base, "tests/bot_a.gd", "a\n");
  w(base, "tests/bot_toys.gd", "t\n");
  w(base, "data/barks.json", "base barks\n");
  w(base, "data/regular.cartridge.json", "{}\n");
  w(game, "pack.json", JSON.stringify({ id: "game.pond", version: "0.1.4", kernelApi: "1.29", title: "Pond", tests: ["tests/bot_a.gd", "tests/bot_pond.gd"], cameras: ["follow", "top"] }));
  w(game, "scripts/main.gd", "old main\n");
  w(game, "tests/bot_a.gd", "a\n");
  w(game, "tests/bot_pond.gd", "pond\n");
  w(game, "data/barks.json", "pond banter\n");
  w(game, "data/match.json", JSON.stringify({ cartridge: "pond.cartridge.json" }));
  w(game, "data/pond.cartridge.json", "{\"pond\": 1}\n");
  w(game, "data/regular.cartridge.json", "{}\n");
  const known = new Map([["scripts/main.gd", new Set([blobId(Buffer.from("old main\n"))])]]);
  const plan = planRebase(game, base, known);
  assert.deepEqual(plan.replaced, ["scripts/main.gd"]);
  assert.deepEqual(plan.added, ["scripts/toys.gd", "tests/bot_toys.gd"]);
  assert.deepEqual(plan.kept, ["data/barks.json", "data/match.json", "data/pond.cartridge.json", "tests/bot_pond.gd"]);
  assert.deepEqual(plan.conflicts, []);
  assert.equal(plan.cartridge, "data/pond.cartridge.json");
  assert.deepEqual(plan.manifest["tests"], ["tests/bot_a.gd", "tests/bot_toys.gd", "tests/bot_pond.gd"]);
  assert.equal(plan.manifest["version"], "0.1.5");
  assert.equal(plan.manifest["kernelApi"], "1.30");
  assert.equal(plan.manifest["id"], "game.pond");
  assert.equal(plan.manifest["subject"], "Skater");
  const out = path.join(root, "out");
  writeRebase(game, base, plan, out);
  assert.equal(read(path.join(out, "scripts", "main.gd")), "new main\n");
  assert.equal(read(path.join(out, "data", "barks.json")), "pond banter\n");
  assert.equal(read(path.join(out, "scripts", "toys.gd")), "toys\n");
  // a game script that is no version of the base: a conflict
  w(game, "scripts/main.gd", "the game's own main\n");
  assert.deepEqual(planRebase(game, base, known).conflicts, ["scripts/main.gd"]);
  // git's history of the real base names its versions: the newest base's main.gd is one of them
  const mainGd = path.join(REPO_ROOT, "engine", "templates", "rink_game", "scripts", "main.gd");
  const k = knownBase("engine/templates/rink_game");
  if (fs.existsSync(mainGd) && !k.sources[0]?.includes("not readable")) assert.ok((k.known.get("scripts/main.gd")?.size ?? 0) > 0, k.sources.join("; "));
});

test("H2: a check the move breaks stops it (the game stays as it was); a check that already failed on the game is kept as it was, named, and does not stop the move", async () => {
  const j = await coreJob("h2-verify");
  const base = path.join(j.engine, "templates", "rink_game");
  const v1 = path.join(j.jobDir, rebuildState(j.jobDir, { write: false }).promoted?.dest as string);
  // the newer base breaks its toy bot (the fake runner fails a bot whose own file holds the marker)
  const toy = path.join(base, "tests", "bot_toys.gd");
  const toyText = read(toy);
  fs.appendFileSync(toy, "\n# FAKE_BOT_FAIL\n");
  fs.writeFileSync(path.join(base, "scripts", "h2_toy.gd"), "extends RefCounted\n");
  const out: string[] = [];
  assert.equal(await main(["rebase", j.jobDir, "--runner", "fake", "--engine-dir", j.engine], (x) => out.push(x)), 1, out.join("\n"));
  let s = rebuildState(j.jobDir, { write: false });
  assert.equal(s.promotions.length, 1, "no new version");
  assert.equal(s.jobState?.state, "done");
  assert.match(s.jobState?.reason ?? "", /NOT made: bot failed .*it passes on the game as it was/);
  assert.ok(!fs.existsSync(path.join(j.jobDir, "pack", "scripts", "h2_toy.gd")), "pack/ is the game as it was");
  // the base is fine again, but a file of the game's own fails its skin bot already: the move goes through, the failure is named
  fs.writeFileSync(toy, toyText);
  fs.writeFileSync(path.join(v1, "data", "h2_notes.txt"), "FAKE_TEST_NEEDS(bot_skin:h2never)\n");
  const out2: string[] = [];
  assert.equal(await main(["rebase", j.jobDir, "--runner", "fake", "--engine-dir", j.engine], (x) => out2.push(x)), 0, out2.join("\n"));
  s = rebuildState(j.jobDir, { write: false });
  assert.equal(s.promotions.length, 2);
  assert.ok(s.notes.some((n) => n.text.includes("kept these failures as they were") && n.text.includes("bot-bot_skin")), JSON.stringify(s.notes.slice(-3)));
});
