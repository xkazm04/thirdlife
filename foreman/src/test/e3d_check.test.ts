// E3d of 25 Nov: the measured check ACTS. Lane E5's real job 1 ("3 against 3 hockey on a small pond rink") shipped with
// about 33 goals a match (hokej plays 2 to 5) because the check only warned; its change "the orange team is too strong"
// went through on a game whose teams are red and blue. Fixtures are E5's own (foreman/fixtures/e5-job1/): the 33-goal
// cartridge, its skin, and lane E2's real tl.rink.check/1 lines measured on them.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { main } from "../cli.js";
import { PKG_ROOT, REPO_ROOT, toPosix } from "../paths.js";
import { rebuildState } from "../joblog.js";
import type { PlanAnswer } from "../designer.js";
import { rinkCheckRun } from "../coreroute.js";
import { absentInChange, goalBand, grossDefects, teamsSeen } from "../rinkjudge.js";
import { cleanup, tempDir, readEvents, sampleConcept, v2Brief, FIXTURE } from "./helpers.js";

after(cleanup);

const ENGINE = path.join(REPO_ROOT, "engine");
const E5 = path.join(PKG_ROOT, "fixtures", "e5-job1");
const read = (f: string): string => fs.readFileSync(path.join(E5, f), "utf8");
const json = (f: string): unknown => JSON.parse(read(f));

test("E3d: the goals band comes from thirdjam's own cartridges; E5's 33-goal pond is a gross defect, hokej is not", () => {
  const band = goalBand();
  assert.ok(band !== undefined, "foreman/data/rink-goal-band.json");
  assert.equal(band.min, 1, "sudden death: one goal ends it");
  assert.equal(band.max, 17.6, "the cage at pro");
  assert.equal(band.hi, 21.8);
  assert.match(band.source, /thirdjam's cartridges \(the regular cut and the modes of MODES\.md\)/);
  const pond = grossDefects(json("check.v010.json") as object);
  assert.ok(pond.defects.some((d) => d.startsWith("32.9 goals a match at pro (thirdjam's regular playtester): thirdjam's own cartridges play 1 to 17.6, so 0 to 21.8 is the band")), pond.defects.join("\n"));
  assert.deepEqual(grossDefects(json("check.hokej.json") as object).defects, [], "hokej plays inside the band");
  const run = rinkCheckRun(0, read("check.v010.json"));
  assert.equal(run.code, 1, "a measured gross defect fails the cartridge");
  assert.match(run.summary, /^GROSS DEFECTS: 29 goals a match at rookie/);
  assert.equal(rinkCheckRun(0, read("check.hokej.json")).code, 0);
});

test("E3d: K8's coarse cells: the idle hand winning half, skating alone a third, a match that never ends; a hand whose sim copies differ is NOT VALID, not a verdict", () => {
  const ok = { levels: { pro: { playtester: { matches: 10, wins: 7, goals_for: 2.6, goals_against: 1.7, not_over: 0 } } } };
  assert.deepEqual(grossDefects({ ...ok, defects: { idle: { matches: 16, wins: 0 }, skate_only: { matches: 16, wins: 2, clone_mismatch: 0 } } }).defects, []);
  assert.match(grossDefects({ ...ok, defects: { idle: { matches: 16, wins: 8 } } }).defects.join(), /the idle hand \(nothing pressed\) wins 8 of 16 at pro/);
  assert.match(grossDefects({ ...ok, defects: { skate_only: { matches: 16, wins: 6, clone_mismatch: 0 } } }).defects.join(), /skating alone \(no shot, pass or check\) wins 6 of 16/);
  const invalid = grossDefects({ ...ok, defects: { skate_only: { matches: 16, wins: 9, clone_checked: 300, clone_mismatch: 4 } } });
  assert.deepEqual(invalid.defects, []);
  assert.match(invalid.notes.join(), /planning hand NOT VALID for this cartridge \(4 of 300 frames/);
  assert.match(grossDefects({ levels: { pro: { playtester: { matches: 10, wins: 0, goals_for: 0, goals_against: 0, not_over: 3 } } } }).defects.join(), /3 of 10 matches at pro never end/);
  // Mean speed beyond thirdjam's range is the person's wish when the change asked for speed, and stays words either way.
  const fast = { ...ok, defects: { idle: { matches: 16, wins: 0 } }, warnings: ["the skaters' mean speed (m/s) at pro is 13.9, above anything thirdjam ships (6.2..10.3)"] };
  assert.deepEqual(grossDefects(fast, "make it faster").defects, []);
  assert.match(grossDefects(fast, "make it faster").notes.join(), /above anything thirdjam ships \(6\.2\.\.10\.3\) \(asked for by the person: "make it faster"\)/);
  assert.doesNotMatch(grossDefects(fast, "the bots are too strong").notes.join(), /asked for/);
});

test("E3d: a change is read against the teams the person sees (skin names, colours on the ice), never the cartridge's ids", () => {
  const skin = json("skin.json");
  const cart = json("pond.v012.cartridge.json");
  assert.deepEqual(teamsSeen(skin, cart), [{ name: "Red Toques", colour: "red", side: "yours" }, { name: "Blue Scarves", colour: "blue", side: "the bots'" }], "ids say blue and orange; the ice says red and blue");
  assert.equal(absentInChange("the orange team is too strong", skin, cart), "There is no orange team in this game: your side is red (Red Toques), the bots are blue (Blue Scarves). Did you mean the blue team, the bots? Say it again with the team's colour or name, and the change is made.");
  assert.equal(absentInChange("the blue team is too strong", skin, cart), undefined);
  assert.equal(absentInChange("the Scarves are too strong", skin, cart), undefined);
  assert.equal(absentInChange("make it faster", skin, cart), undefined);
  assert.match(absentInChange("make the green team slower", skin, cart) ?? "", /^There is no green team in this game: [^]*Which team did you mean\?/);
});

/** An engine for the fake route: the repository's API, cards, core documents, lane E1's base and a slim hokej. */
function routeEngine(): string {
  const e = path.join(tempDir("e3d-engine"), "engine");
  fs.mkdirSync(path.join(e, "kernel"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "kernel", "API.md"), path.join(e, "kernel", "API.md"));
  fs.cpSync(path.join(ENGINE, "cards"), path.join(e, "cards"), { recursive: true });
  fs.mkdirSync(path.join(e, "cores", "rink"), { recursive: true });
  for (const f of ["SNAPSHOT.md", "GAMEMODE.md", "CARTRIDGE.md"]) fs.copyFileSync(path.join(ENGINE, "cores", "rink", f), path.join(e, "cores", "rink", f));
  fs.cpSync(path.join(ENGINE, "cores", "rink", "native", "content", "Cartridges", "modes"), path.join(e, "cores", "rink", "native", "content", "Cartridges", "modes"), { recursive: true });
  fs.cpSync(path.join(ENGINE, "templates", "rink_game"), path.join(e, "templates", "rink_game"), { recursive: true, filter: (src) => !src.endsWith(".uid") });
  fs.mkdirSync(path.join(e, "packs", "hokej", "data"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "pack.json"), path.join(e, "packs", "hokej", "pack.json"));
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"), path.join(e, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"));
  return e;
}

test("E3d on the fake adapter with E5's real job: the 33-goal cartridge is sent back with the figures and hokej's, the fix merges, the phase pause shows the figures; \"the orange team is too strong\" is asked back on a red-and-blue game, answered, and then made as a diff", async () => {
  const engine = routeEngine();
  const cartRel = `data/${(JSON.parse(fs.readFileSync(path.join(engine, "templates", "rink_game", "data", "match.json"), "utf8")) as { cartridge: string }).cartridge}`;
  const flood = read("pond.v010.cartridge.json");
  // E5's real measurement of this very cartridge, replayed by the fake runner's check (keyed by the cartridge's JSON).
  const lines = tempDir("e3d-lines");
  fs.writeFileSync(path.join(lines, `${crypto.createHash("sha1").update(JSON.stringify(JSON.parse(flood))).digest("hex")}.json`), read("check.v010.json"));
  process.env["TL_FAKE_RINK_LINES"] = lines;
  try {
    const root = tempDir("e3d-e2e");
    const jobs = path.join(root, "jobs");
    const estimate = (readEvents(FIXTURE).find((e) => e.type === "brief_set") as { estimate: unknown }).estimate;
    const rinkT = { id: "rink_sport" as const, reference: "thirdjam's match on the rink core", copies: ["thirdjam's match on the rink core, unchanged: skating, puck, bots", "the cartridge keys it changes: rink size, team size", "the skin: title and team colours"] };
    const brief = { ...v2Brief(), rules: `${v2Brief().rules}\nCARTRIDGE: game.rink.length_m = 50 (a pond)\nSKIN: title = Ringer on the Pond\nSKIN: team_names = Red Toques and Blue Scarves` };
    const plan: PlanAnswer = {
      card: "card.rink_core",
      phases: [{ id: "pond_plays", title: "The pond plays", try: "Skate three a side on a small pond", packages: ["base", "cartridge", "skin"] }, { id: "polish", title: "Polish", try: "Play it again", packages: ["words"] }],
      packages: [
        { id: "base", kind: "base", title: "Start from the rink base", milestone: "greybox", deps: [], scope: ["scripts/**"], contract: "start from the base", acceptance: [] },
        { id: "cartridge", title: "The pond cartridge", milestone: "greybox", deps: ["base"], scope: [cartRel], contract: "the pond: three a side on 50 x 26", acceptance: [{ level: "V1", verb: "lint", args: [] }, { level: "V4", verb: "bot", args: ["--test=tests/bot_first_match.gd"] }] },
        { id: "skin", title: "The pond skin", milestone: "greybox", deps: ["cartridge"], scope: ["data/skin.json"], contract: "Red Toques and Blue Scarves", acceptance: [{ level: "V1", verb: "lint", args: [] }] },
        { id: "words", title: "The pond words", milestone: "tuned", deps: ["skin"], scope: ["data/pond_words.json"], contract: "a bank of words", acceptance: [{ level: "V1", verb: "lint", args: [] }] },
      ],
    };
    const script = { steps: [
      { match: { role: "concept" }, json: { concept: { ...sampleConcept(), chosen: 0, template: rinkT } } },
      { match: { role: "designer" }, json: { brief, estimate } },
      { match: { role: "design_review" }, json: { scores: { hook: 0.8, gif: 0.7, depth: 0.7, feel: 0.8, fit: 0.9 }, slop: [], verdict: "ok", notes: "ok" } },
      { match: { role: "planner", promptIncludes: "Decide which ONE package owns" }, json: { package: "cartridge", reason: "the opponents' skill is the cartridge's" } },
      { match: { role: "planner" }, json: plan },
      { match: { role: "cartridge", promptIncludes: "the person answered" }, json: { changes: { "game.ai.difficulty": "rookie" }, why: "the Blue Scarves, the bots, play as rookies: a step slower" } },
      // Round 1: E5's real cartridge, byte for byte. Round 2: the pond made bigger (the fake measures it in the band).
      { match: { role: "builder", package: "cartridge", round: 1 }, write: { [cartRel]: flood }, text: "The pond.\nDEVIATIONS: none" },
      { match: { role: "builder", package: "cartridge", round: 2, promptIncludes: "32.9 goals a match at pro" }, patch: { [cartRel]: { game: { rink: { length_m: 60, width_m: 30 } } } }, text: "A bigger pond, fewer goals.\nDEVIATIONS: none" },
      { match: { role: "builder", package: "skin" }, write: { "data/skin.json": read("skin.json") }, text: "E5's skin.\nDEVIATIONS: none" },
      { match: { role: "builder", package: "words" }, write: { "data/pond_words.json": '{"lines": []}\n' }, text: "Words.\nDEVIATIONS: none" },
    ] };
    const scriptFile = path.join(root, "fake.json");
    fs.writeFileSync(scriptFile, JSON.stringify(script));
    const common = ["--adapter", "fake", "--fake-script", scriptFile, "--engine-dir", engine];
    const run = [...common, "--runner", "fake", "--parallel", "1", "--no-critic", "--quiet"];
    const out: string[] = [];
    const say = (s: string): void => {
      out.push(s);
    };
    assert.equal(await main(["new", "3 against 3 hockey on a small pond rink", "--site", jobs, ...common], say), 0, out.join("\n"));
    const jobDir = path.join(jobs, fs.readdirSync(jobs)[0] as string);
    assert.equal(await main(["approve", jobDir], say), 0);
    assert.equal(await main(["plan", jobDir, ...common, "--runner", "fake", "--max-packages", "3"], say), 0, out.join("\n"));
    assert.equal(await main(["run", jobDir, ...run], say), 3, out.join("\n"));
    let evs = readEvents(jobDir);
    const sent = evs.find((e) => e.type === "note" && e.package === "cartridge" && e.round === 1 && e.text.includes("cartridge edit not valid: the measured check"));
    assert.ok(sent?.type === "note", "the 33-goal cartridge is sent back before any runner verb");
    assert.match(sent.text, /finds gross defects a person would meet at once:\n- data\/[a-z.]+cartridge\.json: 29 goals a match at rookie[^]*32\.9 goals a match at pro/);
    assert.match(sent.text, /The house game hokej \(data\/hockey\.thirdlife\.cartridge\.json\) measured the same way: rookie_wins_of_10/);
    assert.ok(!evs.some((e) => e.type === "verify" && e.package === "cartridge" && e.round === 1), "nothing was run on it");
    assert.ok(evs.some((e) => e.type === "merge" && e.package === "cartridge"), "the fixed cartridge merged");
    const pause = evs.find((e) => e.type === "note" && e.text.startsWith("[foreman] measured at the phase pause pond_plays:"));
    assert.ok(pause?.type === "note" && /ok \(rookie_wins_of_10 9, pro_wins_of_10 6, pro_goals_a_match 3\.8/.test(pause.text), pause?.type === "note" ? pause.text : "no figures at the pause");
    const status: string[] = [];
    await main(["status", jobDir], (x) => status.push(x));
    assert.match(status.join("\n"), /\nmeasured data\/[a-z.]+cartridge\.json ok \(rookie_wins_of_10 9/, "the person sees the figures where he is asked to play");
    assert.equal(await main(["phase", jobDir, "pass", ...run], say), 3, out.join("\n"));
    assert.equal(await main(["phase", jobDir, "pass", ...run], say), 0, out.join("\n"));
    assert.equal(rebuildState(jobDir, { write: false }).promotions.length, 1);

    // "The orange team is too strong" on a red-and-blue game: asked back, not applied.
    await main(["change", jobDir, "the orange team is too strong", ...run], say);
    evs = readEvents(jobDir);
    const q = evs.find((e) => e.type === "question" && e.package === "cartridge");
    assert.ok(q?.type === "question");
    assert.equal(q.text, "There is no orange team in this game: your side is red (Red Toques), the bots are blue (Blue Scarves). Did you mean the blue team, the bots? Say it again with the team's colour or name, and the change is made.");
    assert.ok(!fs.readdirSync(path.join(jobDir, "reports")).some((f) => f.startsWith("cartridge-a1-")), "no diff was asked of the model");
    assert.equal(rebuildState(jobDir, { write: false }).promotions.length, 1, "nothing changed");
    // The person answers (Create's answer box, `foreman answer`): the diff is made from the change and the answer.
    assert.equal(await main(["answer", jobDir, "cartridge", "yes, the blue team, the bots"], say), 0, out.join("\n"));
    await main(["resume", jobDir, ...run], say);
    evs = readEvents(jobDir);
    const diff = evs.find((e) => e.type === "note" && e.package === "cartridge" && e.text.startsWith("[foreman] cartridge diff: "));
    assert.ok(diff?.type === "note", out.slice(-5).join("\n"));
    assert.match(diff.text, /game\.ai\.difficulty: "pro" -> "rookie"/);
    const s = rebuildState(jobDir, { write: false });
    assert.equal(s.jobState?.state, "done", s.jobState?.reason);
    assert.equal(s.promotions.length, 2);
    assert.equal((JSON.parse(fs.readFileSync(path.join(jobDir, s.promotions.at(-1)?.dest as string, ...cartRel.split("/")), "utf8")) as { game: { ai: { difficulty: string } } }).game.ai.difficulty, "rookie");
    assert.ok(toPosix(jobDir).length > 0);
  } finally {
    delete process.env["TL_FAKE_RINK_LINES"];
  }
});
