// E3 of 24-25 Nov (lane "route"): the Foreman's route from a sentence to a game ON THE RINK CORE: the rink_sport
// template and card.rink_core, the cartridge-first plan (a "start from the base" package the Foreman executes itself,
// then data packages), the cartridge check before smoke, the measured check at a look, and the whole route on the fake
// adapter from `foreman new "3 against 3 hockey on a small pond rink"` to the promotion, through the person gate.
// Lanes E1 (engine/templates/rink_game) and E2 (CARTRIDGE.md, schema/, foreman/src/cartridge.ts, rink.sh
// check-cartridge) land beside this lane: the tests that need their files skip with the file named; the rest run on
// the stand-in base (fixtures/base-rink-game.json) and the repository's own core documents.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { main } from "../cli.js";
import { PKG_ROOT, REPO_ROOT, toPosix } from "../paths.js";
import { rebuildState } from "../joblog.js";
import type { PackageSpec, Phase } from "../events.js";
import { planCheck, type PlanAnswer } from "../designer.js";
import { mergePatch } from "../builder/fake.js";
import { templateExcerpt, templateForSentence, templateOf, conceptTemplateProblems, briefTemplateProblems } from "../templates.js";
import { RINK_ROUTE, baseScope, basePackage, basePlayerCheck, coreBriefProblems, coreLines, corePlanProblems, envelopeProblems, fakeRinkCheck, figuresOf, knownCartridgePaths, normalizeCorePlan, startFromBase, validateCartridgeFile } from "../coreroute.js";
import { prepareReference, refContents, referenceOf, referenceText } from "../reference.js";
import { cardBriefSection } from "../cards.js";
import { verbsFor } from "../verbs.js";
import { FAKE_RUNNER } from "../paths.js";
import { cleanup, tempDir, readEvents, sampleConcept, v2Brief, FIXTURE } from "./helpers.js";

after(cleanup);

const ENGINE = path.join(REPO_ROOT, "engine");
/** The stand-in base (fixtures/base-rink-game.json, written out; its cartridge is hokej's Third Life cut). */
function writeBase(dir: string): string {
  const doc = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "fixtures", "base-rink-game.json"), "utf8")) as { files: Record<string, string> };
  for (const [rel, text] of Object.entries(doc.files)) {
    fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), text);
  }
  fs.mkdirSync(path.join(dir, "data"), { recursive: true });
  fs.copyFileSync(path.join(REPO_ROOT, "engine", "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"), path.join(dir, "data", "game.cartridge.json"));
  return dir;
}
const FIXTURE_BASE = writeBase(path.join(tempDir("core-base"), "rink_game"));
const VERBS = verbsFor({ exe: process.execPath, preArgs: [FAKE_RUNNER], engineDir: tempDir("core-verbs") });
const E1_BASE = path.join(ENGINE, "templates", "rink_game", "pack.json");
const E2_VALIDATOR = path.join(PKG_ROOT, "src", "cartridge.ts");
const E2_CATALOG = path.join(ENGINE, "cores", "rink", "CARTRIDGE.md");
const rinkT = { id: "rink_sport" as const, reference: "thirdjam's match on the rink core", copies: ["thirdjam's match on the rink core, unchanged: skating, puck, bots", "the cartridge keys it changes: rink size, team size, rules", "the skin: title and team colours"] };

/** A job's reference copy with the fixture base in ref/base/rink_game/ (and the repository's cards). */
function refWithBase(label: string): string {
  const ref = path.join(tempDir(label), "ref");
  fs.cpSync(FIXTURE_BASE, path.join(ref, "base", "rink_game"), { recursive: true });
  fs.cpSync(path.join(ENGINE, "cards"), path.join(ref, "cards"), { recursive: true });
  return ref;
}

const corePlan = (): PlanAnswer => ({
  card: "card.rink_core",
  phases: [
    { id: "pond_plays", title: "The pond plays", try: "Skate three a side on a small pond", packages: ["base", "cartridge"] },
    { id: "pond_skin", title: "The pond's look", try: "See POND and the team colours", packages: ["skin"] },
  ],
  packages: [
    { id: "base", kind: "base", title: "Start from the rink base", milestone: "greybox", deps: [], scope: ["scripts/**"], contract: "start from the base", acceptance: [] },
    {
      id: "cartridge",
      title: "The pond cartridge",
      milestone: "greybox",
      deps: ["base"],
      scope: ["data/game.cartridge.json"],
      contract: "Copy the Pond mode: game.rink.length_m 60, game.rink.width_m 30; three a side. Every other key stays the base's.",
      acceptance: [{ level: "V1", verb: "lint", args: [] }, { level: "V4", verb: "bot", args: ["--test=tests/bot_first_match.gd"] }, { level: "V4", verb: "bot", args: ["--test=tests/bot_match_hand.gd"] }],
    },
    { id: "skin", title: "The pond skin", milestone: "tuned", deps: ["cartridge"], scope: ["data/skin.json"], contract: "SKIN: title POND; the teams BLUE and ORANGE.", acceptance: [{ level: "V1", verb: "lint", args: [] }, { level: "V2", verb: "smoke", args: [] }] },
  ],
});

const RINK_LINES = ["CARTRIDGE: game.rink.length_m = 60 (a pond: every pass reaches)", "CARTRIDGE: game.rink.width_m = 30", "CARTRIDGE: game.teams = three a side, a chaser and a support each", "SKIN: title = POND", "SKIN: teams = BLUE and ORANGE"].join("\n");

// ---------------------------------------------------------------- the template and the card

test("E3 route: a rink game takes the rink_sport template (the core route); a ball game stays arcade_sport; a fight stays the duel", () => {
  assert.equal(templateForSentence("3 against 3 hockey on a small pond rink")?.id, "rink_sport");
  assert.equal(templateForSentence("pond hockey, shinny on a frozen lake")?.id, "rink_sport");
  assert.equal(templateForSentence("robot soccer, five a side")?.id, "arcade_sport");
  assert.equal(templateForSentence("a duel in a colosseum")?.id, "duel");
  const t = templateOf("rink_sport");
  assert.equal(t?.core, RINK_ROUTE);
  assert.equal(t?.house?.pack, "hokej", "the house game is hokej, not the old engine/packs/hockey");
  assert.equal(t?.card, "card.rink_core");
  assert.deepEqual(t?.metrics, [], "no tofu rows: the core carries the feel");
  assert.deepEqual(conceptTemplateProblems({ ...sampleConcept(), template: rinkT }, "3 against 3 hockey on a small pond rink"), []);
  const wrong = conceptTemplateProblems({ ...sampleConcept(), template: { id: "arcade_sport", reference: "NHL 94", copies: ["possession", "utility AI", "roles"] } }, "3 against 3 hockey on a small pond rink");
  assert.ok(wrong.some((p) => p.includes('the template is "rink_sport"')), wrong.join("\n"));
});

test("E3 route: the designer reads the core route whole (API.md section 24, the modes, the base or a named gap); the builder reads where ref/ holds it", () => {
  const d = templateExcerpt(rinkT, "design");
  assert.match(d, /ON THE RINK CORE/);
  assert.match(d, /## The kernel API, section 24 in full[^]*ctx\.cores\.open\(id, cartridge = ""\)/);
  assert.match(d, /thirdjam's twelve modes[^]*hockey\.mode\.pond\.cartridge\.json/);
  assert.match(d, /CARTRIDGE: <key path> = <value>[^]*SKIN: <field> = <value>/);
  if (fs.existsSync(E2_CATALOG)) assert.match(d, /## The cartridge catalog \(engine\/cores\/rink\/CARTRIDGE\.md, lane E2\)/);
  else assert.match(d, /CARTRIDGE\.md has not landed yet \(lane E2\)/);
  if (fs.existsSync(E1_BASE)) assert.match(d, /## The base and its skin \(engine\/templates\/rink_game\/README\.md, lane E1\)/);
  else assert.match(d, /engine\/templates\/rink_game\/ has not landed yet \(lane E1\)/);
  const b = templateExcerpt(rinkT, "builder");
  assert.match(b, /ref\/cores\/rink\/ \(SNAPSHOT\.md, GAMEMODE\.md, CARTRIDGE\.md, schema\/, modes\/\)/);
  assert.match(b, /validated by the Foreman \(foreman\/src\/cartridge\.ts, lane E2\) BEFORE lint and smoke/);
  assert.ok(b.length < d.length / 4, "the builder's excerpt names paths, it does not paste the documents");
});

test("E3 route: a core brief names the cartridge keys and skin fields it changes; an unknown key is refused by name", () => {
  const l = coreLines(`FANTASY: x\n${RINK_LINES}`);
  assert.deepEqual(l.cartridge.map((c) => c.path), ["game.rink.length_m", "game.rink.width_m", "game.teams"]);
  assert.deepEqual(l.skin.map((s) => s.field), ["title", "teams"]);
  assert.equal(l.cartridge[0]?.value, "60 (a pond: every pass reaches)");
  const known = knownCartridgePaths(ENGINE);
  for (const k of ["game.rink.length_m", "game.teams", "game.rules.score_to_win", "game.look.tier", "title"]) assert.ok(known.has(k), k);
  assert.ok([...known].some((k) => k.startsWith("game.pickups")), "the modes add pickups, abilities, zones");
  assert.deepEqual(coreBriefProblems(RINK_LINES, RINK_ROUTE, ENGINE).filter((p) => !p.startsWith("SKIN line")), []);
  const bad = coreBriefProblems("CARTRIDGE: game.rink.kick_power = 9\nSKIN: title = X", RINK_ROUTE, ENGINE);
  assert.ok(bad.some((p) => p.includes('"game.rink.kick_power", which is not a key of the rink cartridge')), bad.join("\n"));
  assert.ok(coreBriefProblems("nothing", RINK_ROUTE, ENGINE).some((p) => p.includes('1 to 16 "CARTRIDGE:')));
  const brief = { ...v2Brief(), rules: `${v2Brief().rules}\n${RINK_LINES}`, concept: { ...sampleConcept(), template: rinkT } };
  assert.deepEqual(briefTemplateProblems(brief, rinkT).filter((p) => !p.startsWith("SKIN line")), []);
  assert.ok(briefTemplateProblems(v2Brief(), rinkT).some((p) => p.includes("CARTRIDGE")), "a rink brief without its lines is sent back");
});

test("E3 route: card.rink_core points at hokej and the core; its builder section names the core's documents in ref/ and the check", () => {
  const ref = refWithBase("core-card");
  const s = cardBriefSection(ref, "card.rink_core");
  assert.match(s, /engine\/packs\/hokej\/ is .*ref\/packs\/hokej\//);
  assert.match(s, /This game runs on the rink core: the core's documents are in .*ref\/cores\/rink\//);
  assert.match(s, /validates every cartridge and rules file you write \(foreman\/src\/cartridge\.ts\) before lint and smoke/);
  assert.match(s, /Rules by data \(key paths of the cartridge data\/hockey\.thirdlife\.cartridge\.json\): game\.rules\.mode, game\.rules\.score_to_win/);
});

// ---------------------------------------------------------------- the reference copy

test("E3 route: the reference copy carries the core's documents and modes (ref/cores/rink/) and the base (ref/base/<base>/) when the engine has them", () => {
  const live = referenceOf(ENGINE);
  assert.equal(live.coreEngine, ENGINE);
  assert.ok((live.housePacks ?? []).some((p) => path.basename(p) === "hokej"), "card.rink_core brings hokej whole");
  const ref = path.join(tempDir("core-ref"), "ref");
  prepareReference(ref, live);
  for (const f of ["cores/rink/SNAPSHOT.md", "cores/rink/GAMEMODE.md", "cores/rink/modes/MODES.md", "cores/rink/modes/hockey.mode.pond.cartridge.json"]) assert.ok(fs.existsSync(path.join(ref, ...f.split("/"))), f);
  assert.deepEqual(refContents(ref).cores, ["rink"]);
  const text = referenceText(ref);
  assert.match(text, /The rink core: the core's GDScript surface and every field of its per-frame snapshot: .*ref\/cores\/rink\/SNAPSHOT\.md/);
  assert.match(text, /thirdjam's twelve mode cartridges and MODES\.md.*ref\/cores\/rink\/modes\//);
  if (fs.existsSync(E1_BASE)) assert.ok(fs.existsSync(path.join(ref, "base", "rink_game", "pack.json")), "lane E1's base is copied");
  else assert.equal(fs.existsSync(path.join(ref, "base")), false, "no base in this engine yet (lane E1): nothing pretends there is one");
});

test("E3 route: lane E2's CARTRIDGE.md and schema reach ref/cores/rink/", { skip: !fs.existsSync(E2_CATALOG) ? "lane E2's engine/cores/rink/CARTRIDGE.md has not landed in this tree" : false }, () => {
  const ref = path.join(tempDir("core-ref-e2"), "ref");
  prepareReference(ref, referenceOf(ENGINE));
  assert.ok(fs.existsSync(path.join(ref, "cores", "rink", "CARTRIDGE.md")));
  if (fs.existsSync(path.join(ENGINE, "cores", "rink", "schema"))) assert.ok(fs.existsSync(path.join(ref, "cores", "rink", "schema")));
});

// ---------------------------------------------------------------- the plan

test("E3 route: the base package is fixed from the base: its scope, its manifest's registers, the first-match bot, the player check", () => {
  assert.deepEqual(baseScope(FIXTURE_BASE), ["data/**", "scripts/**", "tests/**"], "pack.json and README.md are not the pack's files");
  const p = basePackage(RINK_ROUTE, FIXTURE_BASE, { id: "base", title: "Start" });
  assert.equal(p.kind, "base");
  assert.deepEqual(p.registers, { capabilities: ["input", "camera", "ui"], tests: ["tests/bot_first_match.gd", "tests/bot_match_hand.gd"], cameras: ["follow"] });
  assert.deepEqual(p.acceptance.map((a) => `${a.verb} ${a.args.join(" ")}`.trim()), ["lint", "smoke", "bot --test=tests/bot_first_match.gd"]);
  assert.equal(basePlayerCheck(FIXTURE_BASE), "PLAYER CHECK: tests/bot_match_hand.gd fails when the human's skater never carried the puck or took no shot");
  assert.match(p.contract, /\nPLAYER CHECK: tests\/bot_match_hand\.gd fails when/);
});

test("E3 route: a cartridge-first plan passes the plan check: the base yields its files, costs no builder, and the first phase plays", () => {
  const ref = refWithBase("core-plan");
  const limits = { verbs: VERBS, maxPackages: 2, template: rinkT, refDir: ref, cards: ["card.rink_core", "card.team_possession"], requirePhases: true };
  const plan = normalizeCorePlan(corePlan(), RINK_ROUTE, path.join(ref, "base", "rink_game"));
  assert.deepEqual(planCheck(plan.packages, limits, plan.card, plan.phases), [], "the base's data/** holds data/game.cartridge.json and data/skin.json: allowed; 3 packages, 2 built");
  // The same overlap without a base is refused, as before.
  const noBase = plan.packages.map((p) => ({ ...p, kind: undefined })).map(({ kind: _k, ...p }) => p as PackageSpec);
  assert.ok(planCheck(noBase, limits, plan.card, plan.phases).some((p) => p.includes('lies inside scope "data/**"')));
  // Not normalised (the Planner's own scope): the plan check still knows the base package.
  const raw = corePlan();
  const why = (pk: PackageSpec[], ph: Phase[] = raw.phases ?? [], card: string | undefined = raw.card): string[] => corePlanProblems(pk, ph, RINK_ROUTE, path.join(ref, "base", "rink_game")).concat(planCheck(pk, limits, card, ph).filter((x) => x.includes("card")));
  assert.ok(why(raw.packages.filter((p) => p.kind !== "base").map((p) => ({ ...p, deps: [] }))).some((p) => p.includes('exactly one package of kind "base"')));
  assert.ok(why(raw.packages.map((p) => (p.id === "cartridge" ? { ...p, milestone: "blockout" as const } : p))).some((p) => p.includes("has no tofu stage")));
  assert.ok(why(raw.packages, [{ id: "a", title: "a", try: "t", packages: ["base", "skin"] }, { id: "b", title: "b", try: "t", packages: ["cartridge"] }]).some((p) => p.includes("holds the package that writes the game's cartridge")));
  assert.ok(why(raw.packages, raw.phases, "card.team_possession").some((p) => p.includes('names its card: "card": "card.rink_core"')));
  assert.ok(corePlanProblems(raw.packages, raw.phases, RINK_ROUTE, path.join(tempDir("no-base"), "base", "rink_game")).some((p) => p.includes("has no base (ref/base/rink_game/")), "no base in the copy: the route says why it cannot start");
  // A base package in a hand-built game is refused.
  assert.ok(planCheck(plan.packages, { ...limits, template: { id: "arcade_sport", reference: "r", copies: [] } }, undefined, plan.phases).some((p) => p.includes('is of kind "base", but this game is not on a core')));
});

test("E3 route: the base's round copies the base, and a re-run never undoes a file a later package owns", () => {
  const root = tempDir("core-start");
  const ref = refWithBase("core-start-ref");
  const ws = path.join(root, "ws"), pack = path.join(root, "pack");
  fs.mkdirSync(ws, { recursive: true });
  fs.mkdirSync(pack, { recursive: true });
  const plan = normalizeCorePlan(corePlan(), RINK_ROUTE, path.join(ref, "base", "rink_game")).packages;
  const base = plan[0] as PackageSpec;
  const r = startFromBase(ws, ref, pack, base, plan, RINK_ROUTE);
  assert.ok(r.ok, r.text);
  assert.deepEqual(r.files, ["data/game.cartridge.json", "data/match.json", "data/skin.json", "scripts/main.gd", "tests/bot_first_match.gd", "tests/bot_match_hand.gd"]);
  fs.mkdirSync(path.join(pack, "data"), { recursive: true });
  fs.writeFileSync(path.join(pack, "data", "game.cartridge.json"), "{\"edited\": true}\n");
  const ws2 = path.join(root, "ws2");
  fs.cpSync(pack, ws2, { recursive: true });
  const again = startFromBase(ws2, ref, pack, base, plan, RINK_ROUTE);
  assert.match(again.text, /kept as pack\/ holds them \(later packages own them\): data\/game\.cartridge\.json/);
  assert.equal(fs.readFileSync(path.join(ws2, "data", "game.cartridge.json"), "utf8"), "{\"edited\": true}\n");
  assert.equal(startFromBase(ws, path.join(root, "noref"), pack, base, plan, RINK_ROUTE).ok, false);
});

// ---------------------------------------------------------------- the cartridge check and the measured check

test("E3 route: a cartridge edit is checked before any runner verb: the envelope (unknown keys, the schema line), then lane E2's validator", async () => {
  assert.deepEqual(envelopeProblems("data/a.cartridge.json", fs.readFileSync(path.join(FIXTURE_BASE, "data", "game.cartridge.json"), "utf8")), []);
  assert.ok(envelopeProblems("data/a.cartridge.json", '{"schema": "tj.cartridge/1", "game": {}, "kick": 1}').some((p) => p.includes('unknown key "kick"')));
  assert.ok(envelopeProblems("data/a.cartridge.json", "{").some((p) => p.includes("not valid JSON")));
  assert.ok(envelopeProblems("data/a.rules.json", '{"schema": "tl.rink.rules/1", "rules": {"net_carry_wall": "yes"}}').some((p) => p.includes("must be a number or a boolean")));
  const dir = tempDir("core-validate");
  fs.mkdirSync(path.join(dir, "data"));
  fs.writeFileSync(path.join(dir, "data", "x.cartridge.json"), '{"schema": "tj.cartridge/1", "game": {"rink": {"length_m": 60}}}');
  const v = await validateCartridgeFile(dir, "data/x.cartridge.json");
  assert.deepEqual(v.problems, []);
  if (!fs.existsSync(E2_VALIDATOR)) assert.match(v.by, /lane E2's foreman\/src\/cartridge\.ts is not in this tree/);
  else assert.match(v.by, /foreman\/src\/cartridge\.ts/);
});

test("E3 route: lane E2's validator refuses a cartridge key the core does not know", { skip: !fs.existsSync(E2_VALIDATOR) ? "lane E2's foreman/src/cartridge.ts has not landed in this tree" : false }, async () => {
  const dir = tempDir("core-validate-e2");
  fs.mkdirSync(path.join(dir, "data"));
  const doc = JSON.parse(fs.readFileSync(path.join(FIXTURE_BASE, "data", "game.cartridge.json"), "utf8")) as { game: { rink: Record<string, unknown> } };
  doc.game.rink["kick_power_m"] = 9;
  fs.writeFileSync(path.join(dir, "data", "x.cartridge.json"), JSON.stringify(doc));
  const v = await validateCartridgeFile(dir, "data/x.cartridge.json");
  assert.match(v.by, /lane E2/);
  assert.ok(v.problems.length > 0, "an unknown key is an error");
});

test("E3 route: the measured check's figures are read from its last JSON line; the fake runner's stand-in reads the cartridge", async () => {
  assert.deepEqual(figuresOf('banner\n{"ok": true, "figures": {"goals_a_match": 4.5, "dead_verbs": 0, "name": "x"}}'), { goals_a_match: 4.5, dead_verbs: 0 });
  assert.deepEqual(figuresOf('{"goals": 3}'), { goals: 3 });
  assert.deepEqual(figuresOf("no json"), {});
  const ok = await fakeRinkCheck(path.join(FIXTURE_BASE, "data", "game.cartridge.json"));
  assert.equal(ok.code, 0, ok.summary);
  assert.equal(ok.figures["rink_length_m"], 90);
  const dir = tempDir("core-fake-check");
  fs.writeFileSync(path.join(dir, "bad.cartridge.json"), '{"schema": "tj.cartridge/1", "game": {}, "title": "FAKE_CORE_CHECK_FAIL"}');
  assert.equal((await fakeRinkCheck(path.join(dir, "bad.cartridge.json"))).code, 1);
  assert.equal((await fakeRinkCheck(path.join(dir, "none.json"))).code, 2);
});

test("E3 route: the fake builder edits a JSON file in place (a merge patch), as a builder edits the base's cartridge", () => {
  assert.deepEqual(mergePatch({ game: { rink: { length_m: 90, width_m: 45 }, teams: [1] }, title: "a" }, { game: { rink: { length_m: 60 }, teams: [1, 2] }, title: null }), { game: { rink: { length_m: 60, width_m: 45 }, teams: [1, 2] } });
});

// ---------------------------------------------------------------- the whole route on the fake adapter

/** An engine directory for the fake route: the repository's API, cards and core documents, the fixture base, a slim hokej. */
function routeEngine(): string {
  const e = path.join(tempDir("core-engine"), "engine");
  fs.mkdirSync(path.join(e, "kernel"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "kernel", "API.md"), path.join(e, "kernel", "API.md"));
  fs.cpSync(path.join(ENGINE, "cards"), path.join(e, "cards"), { recursive: true });
  for (const f of ["SNAPSHOT.md", "GAMEMODE.md"]) {
    fs.mkdirSync(path.join(e, "cores", "rink"), { recursive: true });
    fs.copyFileSync(path.join(ENGINE, "cores", "rink", f), path.join(e, "cores", "rink", f));
  }
  fs.cpSync(path.join(ENGINE, "cores", "rink", "native", "content", "Cartridges", "modes"), path.join(e, "cores", "rink", "native", "content", "Cartridges", "modes"), { recursive: true });
  fs.cpSync(FIXTURE_BASE, path.join(e, "templates", "rink_game"), { recursive: true });
  fs.mkdirSync(path.join(e, "packs", "hokej", "data"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "pack.json"), path.join(e, "packs", "hokej", "pack.json"));
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"), path.join(e, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"));
  return e;
}

test("E3 route on the fake adapter: `foreman new \"3 against 3 hockey on a small pond rink\"` -> design room -> plan (base + cartridge + skin) -> the base copied, a cartridge edit, a refused edit sent back, the merge gate, the measured check -> the person gate -> promoted", async () => {
  const engine = routeEngine();
  const root = tempDir("core-e2e");
  const site = path.join(root, "jobs");
  const estimate = (readEvents(FIXTURE).find((e) => e.type === "brief_set") as { estimate: unknown }).estimate;
  const brief = { ...v2Brief(), rules: `${v2Brief().rules}\n${RINK_LINES}` };
  const script = {
    steps: [
      { match: { role: "concept" }, json: { concept: { ...sampleConcept(), template: rinkT } } },
      { match: { role: "designer" }, json: { brief, estimate } },
      { match: { role: "design_review" }, json: { scores: { hook: 0.8, gif: 0.7, depth: 0.7, feel: 0.8, fit: 0.9 }, slop: [], verdict: "ok", notes: "Keep the pond small." } },
      { match: { role: "planner" }, json: corePlan() },
      // Round 1 of the cartridge: a key the core does not know. The Foreman refuses it before any runner verb.
      { match: { role: "builder", package: "cartridge", round: 1 }, patch: { "data/game.cartridge.json": { kick: { power: 9 } } }, text: "Wrote the pond.\nDEVIATIONS: none" },
      { match: { role: "builder", package: "cartridge", round: 2, promptIncludes: "cartridge edit not valid" }, patch: { "data/game.cartridge.json": { kick: null, title: "Pond", game: { rink: { length_m: 60, width_m: 30, corner_radius_m: 3 } } } }, text: "Removed the unknown key; the pond is 60 x 30.\nDEVIATIONS: none" },
      { match: { role: "builder", package: "skin" }, patch: { "data/skin.json": { title: "POND", tagline: "Three a side on the ice." } }, text: "The pond's words.\nDEVIATIONS: none" },
    ],
  };
  const scriptFile = path.join(root, "fake.json");
  fs.writeFileSync(scriptFile, JSON.stringify(script));
  const lines: string[] = [];
  const say = (s: string): void => {
    lines.push(s);
  };
  assert.equal(await main(["new", "3 against 3 hockey on a small pond rink", "--site", site, "--adapter", "fake", "--fake-script", scriptFile, "--engine-dir", engine], say), 0, lines.join("\n"));
  const jobDir = path.join(site, fs.readdirSync(site)[0] as string);
  let s = rebuildState(jobDir, { write: false });
  assert.equal(s.brief?.concept?.template?.id, "rink_sport");
  fs.writeFileSync(path.join(jobDir, "foreman.config.json"), JSON.stringify({ godot: "@fake", engineDir: toPosix(engine) }));
  fs.copyFileSync(scriptFile, path.join(jobDir, "fake-builder.json"));
  assert.equal(await main(["approve", jobDir], say), 0);
  assert.equal(await main(["plan", jobDir, "--adapter", "fake", "--max-packages", "2"], say), 0, lines.join("\n"));
  s = rebuildState(jobDir, { write: false });
  assert.equal(s.card, "card.rink_core");
  const base = s.plan.find((p) => p.id === "base");
  assert.equal(base?.kind, "base");
  assert.deepEqual(base?.scope, ["data/**", "scripts/**", "tests/**"], "the Foreman fixed the base package from the base");
  assert.ok(fs.existsSync(path.join(jobDir, "ref", "base", "rink_game", "pack.json")), "the job's reference copy holds the base");
  const planner = fs.readdirSync(path.join(jobDir, "reports")).find((f) => f.startsWith("planner-"));
  assert.ok(planner !== undefined, "the Planner's call is kept");
  assert.match(fs.readFileSync(path.join(jobDir, "reports", planner), "utf8"), /This game is ON THE RINK CORE: plan it cartridge first/);

  // Phase 1: the base (no builder) and the cartridge; then the person gate.
  const FLAGS = ["--adapter", "fake", "--quiet", "--parallel", "1", "--no-critic"];
  const r1 = await main(["run", jobDir, ...FLAGS], say);
  assert.equal(r1, 3, lines.join("\n"));
  const evs = readEvents(jobDir);
  assert.ok(!evs.some((e) => e.type === "builder_run" && e.package === "base"), "the base package runs no builder");
  assert.ok(evs.some((e) => e.type === "note" && e.package === "base" && e.text.includes("started from the base engine/templates/rink_game/")), "the base's round says what it copied");
  const baseMerge = evs.find((e) => e.type === "merge" && e.package === "base");
  assert.ok(baseMerge?.type === "merge" && baseMerge.files.includes("scripts/main.gd") && baseMerge.files.includes("data/game.cartridge.json"));
  const refused = evs.find((e) => e.type === "note" && e.package === "cartridge" && e.round === 1 && e.text.includes("cartridge edit not valid"));
  assert.ok(refused?.type === "note" && /unknown key "kick"/.test(refused.text), "round 1's unknown key is refused before any runner verb");
  assert.ok(!evs.some((e) => e.type === "verify" && e.package === "cartridge" && e.round === 1), "nothing was run on the refused round");
  const cartMerge = evs.find((e) => e.type === "merge" && e.package === "cartridge");
  assert.ok(cartMerge?.type === "merge" && cartMerge.files.includes("data/game.cartridge.json"), "the cartridge package owns the base's cartridge from then on");
  const cart = JSON.parse(fs.readFileSync(path.join(jobDir, "pack", "data", "game.cartridge.json"), "utf8")) as { title: string; kick?: unknown; game: { rink: { length_m: number; width_m: number }; teams: unknown[] } };
  assert.equal(cart.title, "Pond");
  assert.equal(cart.game.rink.length_m, 60);
  assert.equal(cart.kick, undefined);
  assert.ok(Array.isArray(cart.game.teams), "every key the brief did not name stays the base's");
  const ms = evs.find((e) => e.type === "milestone" && e.milestone === "greybox");
  assert.ok(ms?.type === "milestone" && /core check ok \(`bash engine\/tools\/rink\.sh check-cartridge <file>`\): data\/game\.cartridge\.json passed \(rink_length_m 60/.test(ms.summary), ms?.type === "milestone" ? ms.summary : "no greybox milestone");
  assert.match(ms?.type === "milestone" ? ms.summary : "", /beside the house game hokej \(data\/hockey\.thirdlife\.cartridge\.json\): passed/);
  assert.ok(!evs.some((e) => e.type === "verify" && e.report.includes("tofu")), "no tofu rows on a core");
  assert.deepEqual(evs.filter((e) => e.type === "phase_done" || (e.type === "job_state" && e.state === "paused")).map((e) => (e.type === "phase_done" ? `phase_done:${e.phase}` : "paused")), ["phase_done:pond_plays", "paused"]);
  const pack = JSON.parse(fs.readFileSync(path.join(jobDir, "pack", "pack.json"), "utf8")) as { id: string; tests: string[]; cameras: string[] };
  assert.deepEqual(pack.tests, ["tests/bot_first_match.gd", "tests/bot_match_hand.gd"], "the base's bots registered through the base package");

  // The person plays the first phase and passes it; the skin phase; the last pass promotes.
  assert.equal(await main(["phase", jobDir, "pass", ...FLAGS], say), 3, lines.join("\n"));
  assert.equal(await main(["phase", jobDir, "pass", ...FLAGS], say), 0, lines.join("\n"));
  s = rebuildState(jobDir, { write: false });
  assert.equal(s.jobState?.state, "done", s.jobState?.reason);
  const promoted = path.join(jobDir, "promoted", s.packId as string);
  assert.equal((JSON.parse(fs.readFileSync(path.join(promoted, "data", "skin.json"), "utf8")) as { title: string }).title, "POND");
  assert.equal((JSON.parse(fs.readFileSync(path.join(promoted, "data", "game.cartridge.json"), "utf8")) as { game: { rink: { width_m: number } } }).game.rink.width_m, 30);
  assert.ok(!readEvents(jobDir).some((e) => e.type === "builder_run" && e.package === "base"));
});

test("E3 route: the real base (lane E1) starts a plan with the base package fixed from it", { skip: !fs.existsSync(E1_BASE) ? "lane E1's engine/templates/rink_game has not landed in this tree" : false }, () => {
  const dir = path.join(ENGINE, "templates", "rink_game");
  const p = basePackage(RINK_ROUTE, dir);
  assert.ok(p.scope.includes("scripts/**"));
  assert.ok((p.registers?.tests ?? []).length > 0, "the base registers its bots");
  assert.ok(basePlayerCheck(dir) !== undefined, "the base names a bot that fails when the human does nothing");
});
