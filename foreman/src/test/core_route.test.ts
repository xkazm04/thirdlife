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
import { RINK_ROUTE, baseCartridges, baseFiles, baseScope, basePackage, basePlayerCheck, coreBriefProblems, coreLines, corePlanProblems, fakeRinkCheck, knownCartridgePaths, knownPath, normalizeCorePlan, rinkCheckLine, rinkCheckRun, skinFields, startFromBase, validateCartridgeFile } from "../coreroute.js";
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

const RINK_LINES = ["CARTRIDGE: game.rink.length_m = 60 (a pond: every pass reaches)", "CARTRIDGE: game.rink.width_m = 30", "CARTRIDGE: game.teams = three a side, a chaser and a support each", "SKIN: title = POND", "SKIN: team_names = Pond Blue and Pond Orange"].join("\n");

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
  assert.deepEqual(l.skin.map((s) => s.field), ["title", "team_names"]);
  assert.equal(l.cartridge[0]?.value, "60 (a pond: every pass reaches)");
  const known = knownCartridgePaths(ENGINE);
  for (const k of ["game.rink.length_m", "game.teams", "game.rules.score_to_win", "game.look.tier", "title"]) assert.ok(known.has(k), k);
  assert.ok([...known].some((k) => k.startsWith("game.pickups")), "the modes add pickups, abilities, zones");
  // E5 (25 Nov, first real Designer): the envelope's game is "$ref": "game.schema.json"; its keys are known too
  if (fs.existsSync(path.join(ENGINE, "cores", "rink", "schema", "game.schema.json")))
    for (const k of ["game.effects", "game.rules.hooks", "game.contact.check_windup_frames", "game.contact.bot_check_windup_frames"]) assert.ok(knownPath(k, known), k);
  assert.deepEqual(coreBriefProblems(RINK_LINES, RINK_ROUTE, ENGINE), [], "lane E1's skin has title and team_names");
  assert.ok(coreBriefProblems("CARTRIDGE: game.rink.length_m = 60\nSKIN: teams = A", RINK_ROUTE, ENGINE).some((p) => p.includes(`"teams", which is not a field of the base's data/skin.json`)));
  // E5c (25 Nov, the real Designer refused twice): the skin reader's optional team_plural and the README's "level words"
  if (fs.existsSync(path.join(ENGINE, "templates", "rink_game", "scripts", "hud", "skin.gd")))
    assert.deepEqual(coreBriefProblems("CARTRIDGE: game.rink.length_m = 60\nSKIN: team_plural = both plural\nSKIN: level words = Day Trippers, Ringers", RINK_ROUTE, ENGINE).filter((p) => p.includes("SKIN line")), []);
  const bad = coreBriefProblems("CARTRIDGE: game.rink.kick_power = 9\nSKIN: title = X", RINK_ROUTE, ENGINE);
  assert.ok(bad.some((p) => p.includes('"game.rink.kick_power", which is not a key of the rink cartridge')), bad.join("\n"));
  assert.ok(coreBriefProblems("nothing", RINK_ROUTE, ENGINE).some((p) => p.includes('1 to 16 "CARTRIDGE:')));
  const brief = { ...v2Brief(), rules: `${v2Brief().rules}\n${RINK_LINES}`, concept: { ...sampleConcept(), template: rinkT } };
  assert.deepEqual(briefTemplateProblems(brief, rinkT), []);
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
  // E5 (25 Nov): the base fails the invariants budgets itself; a core package is never held to them
  const withInv = corePlan();
  withInv.packages = withInv.packages.map((p) => (p.kind === "base" ? p : { ...p, acceptance: [...p.acceptance, { level: "V3" as const, verb: "invariants" as const, args: [] }] }));
  assert.ok(normalizeCorePlan(withInv, RINK_ROUTE, path.join(ref, "base", "rink_game")).packages.every((p) => p.acceptance.every((a) => a.verb !== "invariants")));
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

test("E3 route: a cartridge edit is checked before any runner verb by lane E2's validator (thirdjam's), its problems pointer-prefixed; a rules sidecar by the core's reader", async () => {
  const dir = tempDir("core-validate");
  fs.mkdirSync(path.join(dir, "data"));
  const doc = JSON.parse(fs.readFileSync(path.join(FIXTURE_BASE, "data", "game.cartridge.json"), "utf8")) as { game: { skater: Record<string, unknown> } };
  fs.writeFileSync(path.join(dir, "data", "ok.cartridge.json"), JSON.stringify(doc));
  const ok = await validateCartridgeFile(dir, "data/ok.cartridge.json");
  assert.deepEqual(ok.problems, []);
  assert.match(ok.by, /thirdjam's validator \(foreman\/src\/cartridge\.ts validateCartridgeText\)/);
  doc.game.skater["speeed"] = 14;
  fs.writeFileSync(path.join(dir, "data", "bad.cartridge.json"), JSON.stringify(doc));
  const bad = await validateCartridgeFile(dir, "data/bad.cartridge.json");
  assert.match(bad.problems[0] ?? "", /^at \/game\/skater\/speeed: unknown key "speeed" is not allowed here/);
  fs.writeFileSync(path.join(dir, "data", "bad.rules.json"), '{"schema": "tl.rink.rules/1", "rules": {"kick_power": 3}}');
  const rules = await validateCartridgeFile(dir, "data/bad.rules.json");
  assert.match(rules.problems[0] ?? "", /unknown rule "kick_power"/);
  assert.match(rules.by, /the core's rules reader/);
});

test("E3b route: the measured check is read from lane E2's tl.rink.check/1 line: exit codes, the pro playtester's figures, refusals, could not run", async () => {
  const line = { tool: "tl.rink.check/1", ok: true, ran: true, levels: { rookie: { playtester: { matches: 10, wins: 10 } }, pro: { playtester: { matches: 10, wins: 7, goals_for: 2.6, goals_against: 1.7, minutes: 2.9, speed_mean: 9.4 } } }, warnings: ["the top speed is high"], problems: [] };
  const run = rinkCheckRun(0, `PASS lines\n${JSON.stringify(line)}`);
  assert.equal(run.code, 0);
  assert.deepEqual(run.figures, { rookie_wins_of_10: 10, pro_wins_of_10: 7, pro_goals_a_match: 4.3, pro_minutes: 2.9, pro_speed_mean: 9.4 });
  assert.match(run.summary, /warnings: the top speed is high/);
  assert.equal(rinkCheckRun(1, JSON.stringify({ tool: "tl.rink.check/1", ok: false, ran: false, refused: ["at /kick: unknown key"] })).code, 1);
  assert.equal(rinkCheckRun(1, JSON.stringify({ ...line, ok: false, problems: ["pro seed 3 did not end"] })).code, 1);
  assert.equal(rinkCheckRun(2, JSON.stringify({ tool: "tl.rink.check/1", ok: false, ran: false, why: "rinklab.exe is not built" })).summary, "could not run: rinklab.exe is not built");
  assert.equal(rinkCheckRun(0, '{"goals": 3}').code, 2, "no tl.rink.check/1 line: not a pass");
  assert.equal(rinkCheckLine("x\n{}\n" + JSON.stringify(line))?.tool, "tl.rink.check/1");
  const fake = await fakeRinkCheck(path.join(FIXTURE_BASE, "data", "game.cartridge.json"));
  assert.equal(fake.code, 0, fake.summary);
  assert.ok(fake.figures["pro_speed_mean"] !== undefined);
  const dir = tempDir("core-fake-check");
  fs.writeFileSync(path.join(dir, "bad.cartridge.json"), '{"schema": "tj.cartridge/1", "kick": 1}');
  assert.equal((await fakeRinkCheck(path.join(dir, "bad.cartridge.json"))).code, 1);
  assert.equal((await fakeRinkCheck(path.join(dir, "none.json"))).code, 2);
});

test("E3 route: the fake builder edits a JSON file in place (a merge patch), as a builder edits the base's cartridge", () => {
  assert.deepEqual(mergePatch({ game: { rink: { length_m: 90, width_m: 45 }, teams: [1] }, title: "a" }, { game: { rink: { length_m: 60 }, teams: [1, 2] }, title: null }), { game: { rink: { length_m: 60, width_m: 45 }, teams: [1, 2] } });
});

// ---------------------------------------------------------------- the whole route on the fake adapter, as Create drives it

/** An engine directory for the fake route: the repository's API, cards and core documents, lane E1's base, a slim hokej. */
function routeEngine(): string {
  const e = path.join(tempDir("core-engine"), "engine");
  fs.mkdirSync(path.join(e, "kernel"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "kernel", "API.md"), path.join(e, "kernel", "API.md"));
  fs.cpSync(path.join(ENGINE, "cards"), path.join(e, "cards"), { recursive: true });
  for (const f of ["SNAPSHOT.md", "GAMEMODE.md", "CARTRIDGE.md"]) {
    fs.mkdirSync(path.join(e, "cores", "rink"), { recursive: true });
    if (fs.existsSync(path.join(ENGINE, "cores", "rink", f))) fs.copyFileSync(path.join(ENGINE, "cores", "rink", f), path.join(e, "cores", "rink", f));
  }
  fs.cpSync(path.join(ENGINE, "cores", "rink", "native", "content", "Cartridges", "modes"), path.join(e, "cores", "rink", "native", "content", "Cartridges", "modes"), { recursive: true });
  fs.cpSync(fs.existsSync(E1_BASE) ? path.dirname(E1_BASE) : FIXTURE_BASE, path.join(e, "templates", "rink_game"), { recursive: true, filter: (src) => !src.endsWith(".uid") });
  fs.mkdirSync(path.join(e, "packs", "hokej", "data"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "pack.json"), path.join(e, "packs", "hokej", "pack.json"));
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"), path.join(e, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"));
  return e;
}

/**
 * The Foreman's door as Create drives it (engine/ui/foreman_door.gd: new_game, approve, phase, change), one command at a
 * time with the flags of a flags.json (its `new`, `plan`, `run`, `resume`, `change` entries).
 */
function door(flags: Record<string, string[]>, say: (s: string) => void): { cmd: (argv: string[], kind: string) => Promise<number> } {
  return { cmd: (argv, kind) => main([...argv, ...(flags[kind] ?? flags["run"] ?? [])], say) };
}

test("E3 route on the fake adapter, driven as Create drives it: `foreman new \"3 against 3 hockey on a small pond rink\"` -> plan (base + cartridge + skin) -> the base copied, a refused cartridge edit sent back with E2's pointer, the measured check, the person gate -> promoted; then \"make it faster\" is a cartridge diff through applyChanges, measured before and after -> a new version; a change no key can say goes to the builder", async () => {
  const engine = routeEngine();
  const base = path.join(engine, "templates", "rink_game");
  const cartFile = (JSON.parse(fs.readFileSync(path.join(base, "data", "match.json"), "utf8")) as { cartridge?: string }).cartridge ?? "game.cartridge.json";
  const cartRel = `data/${cartFile}`;
  const root = tempDir("core-e2e");
  const jobs = path.join(root, "jobs");
  const estimate = (readEvents(FIXTURE).find((e) => e.type === "brief_set") as { estimate: unknown }).estimate;
  const brief = { ...v2Brief(), rules: `${v2Brief().rules}\n${RINK_LINES}` };
  const plan = corePlan();
  for (const p of plan.packages) p.scope = p.scope.map((g) => (g === "data/game.cartridge.json" ? cartRel : g));
  const script = {
    steps: [
      { match: { role: "concept" }, json: { concept: { ...sampleConcept(), chosen: 0, template: rinkT } } },
      { match: { role: "designer" }, json: { brief, estimate } },
      { match: { role: "design_review" }, json: { scores: { hook: 0.8, gif: 0.7, depth: 0.7, feel: 0.8, fit: 0.9 }, slop: [], verdict: "ok", notes: "Keep the pond small." } },
      // E4's owner question for a change request (grow.ts ownerOrNew keeps the old words), before the Planner's plan.
      { match: { role: "planner", promptIncludes: "Decide which ONE package owns" }, json: { package: "cartridge", reason: "speed and bounce are the game's cartridge" } },
      { match: { role: "planner" }, json: plan },
      // The change "make it faster": a diff of key paths; the one no key can say: an empty diff.
      { match: { role: "cartridge", promptIncludes: 'in their words\n"make it faster"' }, json: { changes: { "game.skater.speed": 14, "game.skater.accel": 30 }, why: "every skater is faster off the mark and at full stride" } },
      { match: { role: "cartridge" }, json: { changes: {}, why: "a puck that bounces like a ball is not a key of the rink core" } },
      // Round 1 of the cartridge: a key the core does not know. The Foreman refuses it before any runner verb.
      { match: { role: "builder", package: "cartridge", round: 1 }, patch: { [cartRel]: { kick: { power: 9 } } }, text: "Wrote the pond.\nDEVIATIONS: none" },
      { match: { role: "builder", package: "cartridge", round: 2, promptIncludes: 'at /kick: unknown key "kick"' }, patch: { [cartRel]: { kick: null, title: "Pond", game: { rink: { length_m: 60, width_m: 30, corner_radius_m: 3 } } } }, text: "Removed the unknown key; the pond is 60 x 30.\nDEVIATIONS: none" },
      { match: { role: "builder", package: "cartridge", promptIncludes: "bounce like a ball" }, patch: { [cartRel]: { title: "Pond (no bounce: the core has no ball)" } }, text: "The core has no bouncing ball; the title says so.\nDEVIATIONS: the puck does not bounce" },
      { match: { role: "builder", package: "skin" }, patch: { "data/skin.json": { title: "POND", team_names: ["Pond Blue", "Pond Orange"] } }, text: "The pond's words.\nDEVIATIONS: none" },
    ],
  };
  const scriptFile = path.join(root, "fake.json");
  fs.writeFileSync(scriptFile, JSON.stringify(script));
  // Create's flags.json for the fake adapter and the fake runner (as E4's 781-create-iterate.sh writes one).
  const common = ["--adapter", "fake", "--fake-script", scriptFile, "--engine-dir", engine];
  const flags = { new: common, plan: [...common, "--runner", "fake", "--max-packages", "2"], run: [...common, "--runner", "fake", "--parallel", "1", "--no-critic", "--quiet"], resume: [...common, "--runner", "fake", "--parallel", "1", "--no-critic", "--quiet"], change: [...common, "--runner", "fake", "--parallel", "1", "--no-critic", "--quiet"] };
  const lines: string[] = [];
  const d = door(flags, (s) => lines.push(s));
  // GO: new_game (foreman_door.gd:160)
  assert.equal(await d.cmd(["new", "3 against 3 hockey on a small pond rink", "--site", jobs], "new"), 0, lines.join("\n"));
  const jobDir = path.join(jobs, fs.readdirSync(jobs)[0] as string);
  let s = rebuildState(jobDir, { write: false });
  assert.equal(s.brief?.concept?.template?.id, "rink_sport");
  // Build it: approve, plan, run (foreman_door.gd:196)
  assert.equal(await main(["approve", jobDir], (x) => lines.push(x)), 0);
  assert.equal(await d.cmd(["plan", jobDir], "plan"), 0, lines.join("\n"));
  s = rebuildState(jobDir, { write: false });
  assert.equal(s.card, "card.rink_core");
  assert.equal(s.plan.find((p) => p.id === "base")?.kind, "base");
  assert.ok(fs.existsSync(path.join(jobDir, "ref", "base", "rink_game", "pack.json")), "the job's reference copy holds the base");
  const planner = fs.readdirSync(path.join(jobDir, "reports")).find((f) => f.startsWith("planner-"));
  assert.match(fs.readFileSync(path.join(jobDir, "reports", planner as string), "utf8"), /This game is ON THE RINK CORE: plan it cartridge first/);
  assert.equal(await d.cmd(["run", jobDir], "run"), 3, lines.join("\n"));
  let evs = readEvents(jobDir);
  assert.ok(!evs.some((e) => e.type === "builder_run" && e.package === "base"), "the base package runs no builder");
  const baseMerge = evs.find((e) => e.type === "merge" && e.package === "base");
  assert.ok(baseMerge?.type === "merge" && baseMerge.files.includes("scripts/main.gd") && baseMerge.files.includes(cartRel));
  const refused = evs.find((e) => e.type === "note" && e.package === "cartridge" && e.round === 1 && e.text.includes("cartridge edit not valid"));
  assert.ok(refused?.type === "note" && refused.text.includes(`- ${cartRel} at /kick: unknown key "kick" is not allowed here`), refused?.type === "note" ? refused.text : "no refusal note");
  assert.ok(!evs.some((e) => e.type === "verify" && e.package === "cartridge" && e.round === 1), "nothing was run on the refused round");
  const ms = evs.find((e) => e.type === "milestone" && e.milestone === "greybox");
  const summary = ms?.type === "milestone" ? ms.summary : "no greybox milestone";
  assert.match(summary, new RegExp(`core check ok \\(\`bash engine/tools/rink\\.sh check-cartridge <file>\`\\): ${cartRel.replace(/\./g, "\\.")} passed \\(rookie_wins_of_10`));
  assert.match(summary, /beside the house game hokej \(data\/hockey\.thirdlife\.cartridge\.json\): passed/);
  // Pass (the person gate), the skin phase, Pass: the first version.
  assert.equal(await d.cmd(["phase", jobDir, "pass"], "resume"), 3, lines.join("\n"));
  assert.equal(await d.cmd(["phase", jobDir, "pass"], "resume"), 0, lines.join("\n"));
  s = rebuildState(jobDir, { write: false });
  assert.equal(s.jobState?.state, "done", s.jobState?.reason);
  const v1 = s.promotions.at(-1)?.dest as string;
  assert.equal((JSON.parse(fs.readFileSync(path.join(jobDir, v1, "data", "skin.json"), "utf8")) as { title: string }).title, "POND");
  const speedOf = (dest: string): number => (JSON.parse(fs.readFileSync(path.join(jobDir, dest, ...cartRel.split("/")), "utf8")) as { game: { skater: { speed: number } } }).game.skater.speed;
  const speed0 = speedOf(v1);

  // The change box: "make it faster" (foreman_door.gd:257) -> a cartridge diff, no builder.
  const runsBefore = readEvents(jobDir).filter((e) => e.type === "builder_run" && e.package === "cartridge").length;
  assert.equal(await d.cmd(["change", jobDir, "make it faster"], "change"), 0, lines.join("\n"));
  evs = readEvents(jobDir);
  const diff = evs.find((e) => e.type === "note" && e.package === "cartridge" && e.text.includes("cartridge diff: "));
  assert.ok(diff?.type === "note", "a cartridge diff note");
  assert.match(diff.text, new RegExp(`game\\.skater\\.speed: ${speed0} -> 14; game\\.skater\\.accel: \\d+ -> 30`));
  assert.match(diff.text, /measured before: ok \(.*pro_speed_mean [\d.]+.*\); after: ok \(.*pro_speed_mean [\d.]+/);
  assert.equal(evs.filter((e) => e.type === "builder_run" && e.package === "cartridge").length, runsBefore, "no builder ran for the diff round");
  assert.ok(fs.readdirSync(path.join(jobDir, "reports")).some((f) => f.startsWith("cartridge-a1-")), "one short generate call (role cartridge) wrote the diff");
  s = rebuildState(jobDir, { write: false });
  assert.equal(s.jobState?.state, "done", s.jobState?.reason);
  assert.equal(s.promotions.length, 2, "a new version beside the first");
  assert.equal(speedOf(s.promotions.at(-1)?.dest as string), 14);
  assert.equal(speedOf(v1), speed0, "the first version is kept as it was");

  // A change no key can say: the diff is not made and the builder gets the round.
  assert.equal(await d.cmd(["change", jobDir, "make the puck bounce like a ball"], "change"), 0, lines.join("\n"));
  evs = readEvents(jobDir);
  assert.ok(evs.some((e) => e.type === "note" && e.package === "cartridge" && /cartridge diff not made: no key says it/.test(e.text)), JSON.stringify(evs.filter((e) => (e.type === "note" || e.type === "package_state" || e.type === "builder_run") && e.package === "cartridge").map((e) => (e.type === "note" ? `note ${e.package} r${e.round}: ${e.text.slice(0, 160)}` : e.type === "package_state" ? `${e.package} ${e.state} r${e.round} ${e.detail?.slice(0, 80) ?? ""}` : e.type)), null, 1));
  assert.equal(evs.filter((e) => e.type === "builder_run" && e.package === "cartridge").length, runsBefore + 1, "the fallback is one builder round");
  s = rebuildState(jobDir, { write: false });
  assert.equal(s.promotions.length, 3);
});

test("E3 route: the real base (lane E1) starts a plan with the base package fixed from it", { skip: !fs.existsSync(E1_BASE) ? "lane E1's engine/templates/rink_game has not landed in this tree" : false }, () => {
  const dir = path.dirname(E1_BASE);
  const p = basePackage(RINK_ROUTE, dir);
  assert.deepEqual(p.scope, ["assets/**", "data/**", "gen/**", "scripts/**", "tests/**"]);
  assert.ok(!baseFiles(dir).some((f) => f.endsWith(".uid") || f === "README.md" || f === "pack.json"), "no uid, README or manifest copied");
  // E3e: the base's own list (lane E1b added tests/bot_toys.gd): the route reads it from the base, never a list of its own.
  assert.deepEqual(p.registers?.tests, (JSON.parse(fs.readFileSync(E1_BASE, "utf8")) as { tests: string[] }).tests);
  assert.deepEqual(p.acceptance.map((a) => a.args.join(" ")), ["", "", "--test=tests/bot_first_match.gd"]);
  assert.equal(basePlayerCheck(dir), "PLAYER CHECK: tests/bot_match_hand.gd fails when the human's skater never carried the puck or took no shot", "hokej's match hand needs the human's carry and shot (its ok line)");
  assert.equal(baseCartridges(dir).game, "data/hockey.regular.cartridge.json", "data/match.json names the game's cartridge");
  assert.ok(skinFields(dir)?.has("team_names"));
});

test("E3b route: a hand-written core plan (`foreman plan --from`) gets its base package fixed from the base, as the Planner's does", async () => {
  const engine = routeEngine();
  const root = tempDir("core-from");
  const jobs = path.join(root, "jobs");
  const estimate = (readEvents(FIXTURE).find((e) => e.type === "brief_set") as { estimate: unknown }).estimate;
  const script = path.join(root, "fake.json");
  fs.writeFileSync(script, JSON.stringify({ steps: [
    { match: { role: "concept" }, json: { concept: { ...sampleConcept(), chosen: 0, template: rinkT } } },
    { match: { role: "designer" }, json: { brief: { ...v2Brief(), rules: `${v2Brief().rules}\n${RINK_LINES}` }, estimate } },
    { match: { role: "design_review" }, json: { scores: { hook: 0.8, gif: 0.7, depth: 0.7, feel: 0.8, fit: 0.9 }, slop: [], verdict: "ok", notes: "ok" } },
  ] }));
  const quiet = (): void => {};
  assert.equal(await main(["new", "pond hockey, three a side", "--site", jobs, "--adapter", "fake", "--fake-script", script, "--engine-dir", engine], quiet), 0);
  const jobDir = path.join(jobs, fs.readdirSync(jobs)[0] as string);
  assert.equal(await main(["approve", jobDir], quiet), 0);
  const cartRel = `data/${(JSON.parse(fs.readFileSync(path.join(engine, "templates", "rink_game", "data", "match.json"), "utf8")) as { cartridge: string }).cartridge}`;
  const plan = corePlan();
  for (const p of plan.packages) p.scope = p.scope.map((g) => (g === "data/game.cartridge.json" ? cartRel : g));
  const file = path.join(root, "plan.json");
  fs.writeFileSync(file, JSON.stringify(plan));
  const lines: string[] = [];
  assert.equal(await main(["plan", jobDir, "--from", file, "--engine-dir", engine, "--runner", "fake", "--max-packages", "2"], (x) => lines.push(x)), 0, lines.join("\n"));
  const base = rebuildState(jobDir, { write: false }).plan.find((p) => p.kind === "base");
  assert.ok((base?.scope ?? []).includes("data/**") && (base?.scope ?? []).includes("scripts/**"), JSON.stringify(base?.scope));
  assert.ok((base?.registers?.tests ?? []).includes("tests/bot_first_match.gd"));
  assert.match(base?.contract ?? "", /PLAYER CHECK: tests\/bot_match_hand\.gd fails when/);
});

test("E3e: a diff round runs the base's toy bot only when the diff changed the rink's zones or obstacles", async () => {
  const { toyBots, roundAcceptance } = await import("../fastchange.js");
  const plan = [{ id: "base", kind: "base" as const, title: "b", milestone: "greybox" as const, deps: [], scope: ["tests/**"], contract: "c", acceptance: [], registers: { tests: ["tests/bot_match_hand.gd", "tests/bot_first_match.gd", "tests/bot_toys.gd"] } }, { id: "cartridge", title: "c", milestone: "greybox" as const, deps: ["base"], scope: ["data/x.cartridge.json"], contract: "PLAYER CHECK: tests/bot_match_hand.gd fails when the human never shoots", acceptance: [{ level: "V1" as const, verb: "lint" as const, args: [] }, { level: "V4" as const, verb: "bot" as const, args: ["--test=tests/bot_first_match.gd"] }, { level: "V4" as const, verb: "bot" as const, args: ["--test=tests/bot_match_hand.gd"] }] }];
  const state = (diff: string) => ({ plan, notes: [{ package: "cartridge", round: 3, text: `[foreman] cartridge diff: ${diff} (why); measured before: ok` }], promotions: [{ packId: "g", version: "0.1.0", dest: "x" }], brief: { concept: { template: { id: "rink_sport" } } } }) as unknown as Parameters<typeof toyBots>[0];
  assert.deepEqual(toyBots(state("game.skater.speed: 11 -> 14"), "cartridge", 3), [], "a speed diff: no toy bot");
  assert.deepEqual(toyBots(state("game.rink.obstacles: absent -> [{\"kind\":\"bumper\"}]"), "cartridge", 3).map((a) => a.args[0]), ["--test=tests/bot_toys.gd"]);
  const acc = roundAcceptance(state("game.rink.zones[0].kind: \"slow_ice\" -> \"fast_ice\""), plan[1] as never, 3).map((a) => `${a.verb} ${a.args.join(" ")}`.trim());
  assert.deepEqual(acc, ["lint", "bot --test=tests/bot_match_hand.gd", "bot --test=tests/bot_toys.gd"], "lint, the player check, the toy bot");
});
