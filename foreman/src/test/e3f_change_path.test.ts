// E3f (night of 24-25 Nov 2026): a change keeps the person's game. Lane E5's real proof E5b (PROOF-E5b.md "Defects for the
// Director") ran two real jobs on the rink core:
//   job 2 (pirate hockey, teal v gold, first to 1, 70 x 35): "make the goals bigger" -> the Planner named the base
//     (event 198), the base's change round copied the engine's base again, its note said skin.json and match.json were
//     kept (201) while its merge listed them (208): version 2 was plain HOKEJ;
//   job 1 (the pond): the cartridge diff's merge listed match.json and the drill test, byte-identical (346), so every
//     change took the full path; the critic named the base and its reasons cost about 89 of 140 min of revise rounds;
//     a first-to-5 over in 1.2 min passed the measured check.
// Each test below failed on hokej 9a9126f and passes now.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { main } from "../cli.js";
import { PKG_ROOT, REPO_ROOT } from "../paths.js";
import { foldEvents, rebuildState } from "../joblog.js";
import type { JobEvent, PackageSpec } from "../events.js";
import type { PlanAnswer } from "../designer.js";
import type { GateHost } from "../p10gate.js";
import { sendBack, type Verdict } from "../quality.js";
import { lookOk, qualityNext } from "../quality_state.js";
import { rinkCheckRun, RINK_ROUTE } from "../coreroute.js";
import { changeCandidates, coreChangeOwner } from "../coreowner.js";
import { unseenChange } from "../rinkjudge.js";
import { cleanup, tempDir, readEvents, sampleConcept, v2Brief, FIXTURE } from "./helpers.js";

after(cleanup);

const ENGINE = path.join(REPO_ROOT, "engine");
const E1_BASE = path.join(ENGINE, "templates", "rink_game", "pack.json");
const LINES = path.join(REPO_ROOT, "foreman", "src", "test", "fixtures", "e3f-lines");

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
  const e = path.join(tempDir("e3f-engine"), "engine");
  fs.mkdirSync(path.join(e, "kernel"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "kernel", "API.md"), path.join(e, "kernel", "API.md"));
  fs.cpSync(path.join(ENGINE, "cards"), path.join(e, "cards"), { recursive: true });
  fs.mkdirSync(path.join(e, "cores", "rink"), { recursive: true });
  for (const f of ["SNAPSHOT.md", "GAMEMODE.md", "CARTRIDGE.md"]) if (fs.existsSync(path.join(ENGINE, "cores", "rink", f))) fs.copyFileSync(path.join(ENGINE, "cores", "rink", f), path.join(e, "cores", "rink", f));
  fs.cpSync(path.join(ENGINE, "cores", "rink", "native", "content", "Cartridges", "modes"), path.join(e, "cores", "rink", "native", "content", "Cartridges", "modes"), { recursive: true });
  const base = fs.existsSync(E1_BASE) ? path.dirname(E1_BASE) : fixtureBase(path.join(tempDir("e3f-base"), "rink_game"));
  fs.cpSync(base, path.join(e, "templates", "rink_game"), { recursive: true, filter: (src) => !src.endsWith(".uid") });
  fs.mkdirSync(path.join(e, "packs", "hokej", "data"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "pack.json"), path.join(e, "packs", "hokej", "pack.json"));
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"), path.join(e, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"));
  return e;
}

const rinkT = { id: "rink_sport" as const, reference: "thirdjam's match on the rink core", copies: ["thirdjam's match on the rink core, unchanged: skating, puck, bots", "the cartridge keys it changes: rink size, team size, rules", "the skin: title and team colours"] };
const RINK_LINES = ["CARTRIDGE: game.rink.length_m = 70 (a harbour rink)", "CARTRIDGE: game.rink.width_m = 35", "SKIN: title = PIRATES"].join("\n");
const ACCEPT = [{ level: "V1" as const, verb: "lint" as const, args: [] }, { level: "V4" as const, verb: "bot" as const, args: ["--test=tests/bot_first_match.gd"] }, { level: "V4" as const, verb: "bot" as const, args: ["--test=tests/bot_match_hand.gd"] }];

/** Job 2's plan (state.json of pirate-hockey-sharks-against-20261125-1): base, a cartridge package that owns a NEW cartridge and match.json, a skin package. */
function pirate(cartRel: string, extraScope: string[] = []): PlanAnswer {
  return {
    card: "card.rink_core",
    phases: [
      { id: "golden_goal", title: "Golden goal", try: "First goal wins on a 70 x 35 harbour rink", packages: ["base", "cartridge"] },
      { id: "pirate_voice", title: "The pirate voice", try: "See PIRATES and the teal and gold teams", packages: ["skin"] },
    ],
    packages: [
      { id: "base", kind: "base", title: "Start from the rink_game base", milestone: "greybox", deps: [], scope: ["scripts/**"], contract: "start from the base", acceptance: [] },
      { id: "cartridge", title: "Sharks v Gulls golden-goal cartridge", milestone: "greybox", deps: ["base"], scope: [cartRel, "data/match.json", ...extraScope], contract: "Data only. Copy the base's cartridge; rink 70 x 35; first to 1. data/match.json names it.", acceptance: ACCEPT },
      { id: "skin", title: "Pirate skin, commentary and barks", milestone: "tuned", deps: ["base", "cartridge"], scope: ["data/skin.json"], contract: "SKIN: title PIRATES.", acceptance: [{ level: "V1", verb: "lint", args: [] }, { level: "V2", verb: "smoke", args: [] }] },
    ],
  };
}

/** The runner's work between two seqs, by verb. */
function workOf(evs: JobEvent[], from: number): Record<string, number> {
  const verbs: Record<string, number> = {};
  for (const e of evs) if (e.type === "verify" && e.seq > from) verbs[e.verb] = (verbs[e.verb] ?? 0) + 1;
  return verbs;
}

interface CoreJob { jobDir: string; run: (argv: string[], kind: string) => Promise<number>; log: string[]; cartRel: string }

/**
 * A core job on the fake adapter, built to its first version as Create drives it. `shape` "job2": the cartridge package
 * writes a NEW cartridge (data/sharks_gulls.cartridge.json) and points match.json at it, as job 2's did; "job1": it edits
 * the base's cartridge, match.json and a drill test, as job 1's did. The Planner's owner answer is the real job 2 one.
 */
async function coreJob(label: string, shape: "job1" | "job2"): Promise<CoreJob> {
  const engine = routeEngine();
  const base = path.join(engine, "templates", "rink_game");
  const baseCart = (JSON.parse(fs.readFileSync(path.join(base, "data", "match.json"), "utf8")) as { cartridge?: string }).cartridge ?? "game.cartridge.json";
  const cartRel = shape === "job2" ? "data/sharks_gulls.cartridge.json" : `data/${baseCart}`;
  const cart = JSON.parse(fs.readFileSync(path.join(base, "data", baseCart), "utf8")) as { title?: string; game: { rink: Record<string, unknown> } };
  cart.title = "Sharks vs Gulls: Golden Goal";
  cart.game.rink = { ...cart.game.rink, length_m: 70, width_m: 35, corner_radius_m: 3.5 };
  const root = tempDir(label);
  const jobs = path.join(root, "jobs");
  const estimate = (readEvents(FIXTURE).find((e) => e.type === "brief_set") as { estimate: unknown }).estimate;
  const cartStep = shape === "job2"
    ? { match: { role: "builder", package: "cartridge" }, write: { [cartRel]: JSON.stringify(cart, null, 1) + "\n" }, patch: { "data/match.json": { cartridge: path.basename(cartRel), difficulty: "rookie" } }, text: "The golden-goal cartridge.\nDEVIATIONS: none" }
    : { match: { role: "builder", package: "cartridge" }, write: { "tests/bot_pond_drill.gd": "extends RefCounted\n\nfunc run(_ctx) -> bool:\n\treturn true\n" }, patch: { [cartRel]: { title: "Pond", game: { rink: { length_m: 60, width_m: 30, corner_radius_m: 3 } } }, "data/match.json": { difficulty: "rookie" } }, text: "The pond.\nDEVIATIONS: none" };
  const script = {
    steps: [
      { match: { role: "concept" }, json: { concept: { ...sampleConcept(), chosen: 0, template: rinkT } } },
      { match: { role: "designer" }, json: { brief: { ...v2Brief(), rules: `${v2Brief().rules}\n${RINK_LINES}` }, estimate } },
      { match: { role: "design_review" }, json: { scores: { hook: 0.8, gif: 0.7, depth: 0.7, feel: 0.8, fit: 0.9 }, slop: [], verdict: "ok", notes: "Keep it small." } },
      // job 2's real answer (reports/planner-a1-s197.json), word for word
      { match: { role: "planner", promptIncludes: "Decide which ONE package owns" }, json: { package: "base", reason: "Goal size is part of the play space, which the root rink_game base builds (including gen/tj_rink.gd), and the packages that depend on it can be re-verified after the change." } },
      { match: { role: "planner" }, json: pirate(cartRel, shape === "job1" ? ["tests/bot_pond_drill.gd"] : []) },
      { match: { role: "cartridge", promptIncludes: "goals bigger" }, json: { changes: { "game.rink.goal_width_m": 4.4 }, why: "Both goals are wider, so shots that hit the post go in." } },
      { match: { role: "cartridge" }, json: { changes: { "game.skater.speed": 14, "game.skater.accel": 30 }, why: "every skater is faster off the mark and at full stride" } },
      cartStep,
      { match: { role: "builder", package: "skin" }, patch: { "data/skin.json": { title: "PIRATES" } }, text: "The pirate words.\nDEVIATIONS: none" },
    ],
  };
  const scriptFile = path.join(root, "fake.json");
  fs.writeFileSync(scriptFile, JSON.stringify(script));
  const common = ["--adapter", "fake", "--fake-script", scriptFile, "--engine-dir", engine];
  const runFlags = [...common, "--runner", "fake", "--parallel", "1", "--no-critic", "--quiet"];
  const flags: Record<string, string[]> = { new: common, plan: [...common, "--runner", "fake", "--max-packages", "3"], run: runFlags, resume: runFlags, change: runFlags };
  const log: string[] = [];
  const run = (argv: string[], kind: string): Promise<number> => main([...argv, ...(flags[kind] ?? runFlags)], (s) => log.push(s));
  assert.equal(await run(["new", "pirate hockey, the Sharks against the Gulls in teal and gold, first goal wins", "--site", jobs], "new"), 0, log.join("\n"));
  const jobDir = path.join(jobs, fs.readdirSync(jobs)[0] as string);
  assert.equal(await main(["approve", jobDir], (x) => log.push(x)), 0);
  assert.equal(await run(["plan", jobDir], "plan"), 0, log.join("\n"));
  assert.equal(await run(["run", jobDir], "run"), 3, log.join("\n"));
  assert.equal(await run(["phase", jobDir, "pass"], "resume"), 3, log.join("\n"));
  assert.equal(await run(["phase", jobDir, "pass"], "resume"), 0, log.join("\n"));
  assert.equal(rebuildState(jobDir, { write: false }).jobState?.state, "done", log.join("\n"));
  return { jobDir, run, log, cartRel };
}

const bytes = (j: CoreJob, version: number, rel: string): string => {
  const s = rebuildState(j.jobDir, { write: false });
  return fs.readFileSync(path.join(j.jobDir, s.promotions[version - 1]?.dest as string, ...rel.split("/")), "utf8");
};

test("E3f 1 (replay of job 2's change decision): on a promoted core game, \"make the goals bigger\" with the Planner answering \"base\" goes to the cartridge package as a diff on goal_width_m; skin.json and match.json stay byte-equal to v0.1.0", async () => {
  const j = await coreJob("e3f-goals", "job2");
  const from = readEvents(j.jobDir).at(-1)?.seq ?? 0;
  assert.equal(await j.run(["change", j.jobDir, "make the goals bigger"], "change"), 0, j.log.join("\n"));
  const evs = readEvents(j.jobDir).filter((e) => e.seq > from);
  const re = evs.filter((e) => e.type === "reopened");
  assert.deepEqual(re.map((e) => (e.type === "reopened" ? e.package : "")), ["cartridge"], "the cartridge package takes it, never the base");
  assert.match(re[0]?.type === "reopened" ? re[0].reason : "", /the base "base" is the engine's copy .* the change goes to "cartridge", which owns the game's cartridge/);
  assert.ok(!evs.some((e) => e.type === "merge" && e.package === "base"), "the base merges nothing");
  const diff = evs.find((e) => e.type === "note" && e.text.startsWith("[foreman] cartridge diff: "));
  assert.match(diff?.type === "note" ? diff.text : "", /game\.rink\.goal_width_m: 4 -> 4\.4/);
  const s = rebuildState(j.jobDir, { write: false });
  assert.equal(s.promotions.length, 2);
  for (const rel of ["data/skin.json", "data/match.json"]) assert.equal(bytes(j, 2, rel), bytes(j, 1, rel), `${rel} is the game's, as v0.1.0`);
  assert.equal((JSON.parse(bytes(j, 2, j.cartRel)) as { game: { rink: { goal_width_m: number; length_m: number } } }).game.rink.goal_width_m, 4.4);
  assert.equal((JSON.parse(bytes(j, 2, "data/skin.json")) as { title?: string }).title, "PIRATES", "still the pirate game");
  // 5: the promoted version carries one line of what changed (a Foreman note before the promotion; Create can show it)
  const what = evs.filter((e) => e.type === "note" && e.text.startsWith("[foreman] what changed")).map((e) => (e.type === "note" ? e.text : ""));
  assert.deepEqual(what, [`[foreman] what changed in v0.1.1 (since v0.1.0): asked "make the goals bigger"; game.rink.goal_width_m: 4 -> 4.4; files: ${j.cartRel}`]);
});

test("E3f 1b: a base change round (named by hand) never overwrites what later packages own: its note says kept, its merge does not list them, skin and match.json stay v0.1.0's", async () => {
  const j = await coreJob("e3f-base-round", "job2");
  const from = readEvents(j.jobDir).at(-1)?.seq ?? 0;
  assert.equal(await j.run(["change", j.jobDir, "make the goals bigger", "--package", "base"], "change"), 0, j.log.join("\n"));
  const evs = readEvents(j.jobDir).filter((e) => e.seq > from);
  const note = evs.find((e) => e.type === "note" && e.package === "base" && e.text.includes("kept as pack/ holds them"));
  const kept = (note?.type === "note" ? /later packages own them\): (.*)$/.exec(note.text)?.[1] ?? "" : "").split(", ").filter(Boolean);
  assert.deepEqual(kept.sort(), ["data/match.json", "data/skin.json"], note?.type === "note" ? note.text : "no note");
  const merged = evs.filter((e) => e.type === "merge" && e.package === "base").flatMap((e) => (e.type === "merge" ? e.files : []));
  for (const f of [...kept, j.cartRel]) assert.ok(!merged.includes(f), `the base's merge lists ${f}`);
  for (const rel of ["data/skin.json", "data/match.json", j.cartRel]) assert.equal(bytes(j, 2, rel), bytes(j, 1, rel), `${rel} unchanged by a base round`);
});

test("E3f 2 (job 1 event 346): a cartridge diff merges only the cartridge, not the byte-identical match.json and drill test, so the change stays on the fast path (E4b's 7 runner calls)", async () => {
  const j = await coreJob("e3f-fast", "job1");
  const first = rebuildState(j.jobDir, { write: false }).packages["cartridge"]?.mergedFiles ?? [];
  assert.deepEqual(first, [j.cartRel, "data/match.json", "tests/bot_pond_drill.gd"].sort(), "round 1 merged all three");
  const from = readEvents(j.jobDir).at(-1)?.seq ?? 0;
  assert.equal(await j.run(["change", j.jobDir, "make it faster"], "change"), 0, j.log.join("\n"));
  const evs = readEvents(j.jobDir).filter((e) => e.seq > from);
  const merges = evs.filter((e) => e.type === "merge");
  assert.deepEqual(merges.map((e) => (e.type === "merge" ? [e.package, e.files] : [])), [["cartridge", [j.cartRel]]]);
  assert.deepEqual(workOf(evs, from), { lint: 3, bot: 1, smoke: 2, capture: 1 }, evs.filter((e) => e.type === "verify").map((e) => (e.type === "verify" ? e.report : "")).join(" | "));
  assert.ok(evs.some((e) => e.type === "note" && e.text.startsWith("[foreman] data-only change (data/")));
  assert.ok(!evs.some((e) => e.type === "reopened" && e.package !== "cartridge"), "no dependant re-opened");
});

// ---------- 3: the critic's base-owned reasons go to the person ----------

function criticHost(): { h: GateHost; appended: Record<string, unknown>[]; reopened: string[] } {
  const dir = tempDir("e3f-critic");
  fs.mkdirSync(path.join(dir, "pack"), { recursive: true });
  const appended: Record<string, unknown>[] = [];
  const reopened: string[] = [];
  const promoted = { state: "promoted", mergedFiles: ["data/x.json"], round: 1 };
  const plan = [{ id: "base", kind: "base", scope: ["scripts/**"] }, { id: "cartridge", scope: ["data/pond.cartridge.json"] }, { id: "skin", scope: ["data/skin.json"] }, { id: "trials", scope: ["data/trial_*.cartridge.json"] }];
  const h = {
    s: { plan, lastSeq: 60, packages: { base: promoted, cartridge: promoted, skin: promoted, trials: promoted }, order: ["base", "cartridge", "skin", "trials"], brief: { concept: { template: { id: "rink_sport" } } } },
    events: [],
    dir: (...p: string[]) => path.join(dir, ...p),
    rel: (abs: string) => path.relative(dir, abs).split(path.sep).join("/"),
    pkg: () => ({ round: 1 }),
    append: (e: Record<string, unknown>) => { appended.push(e); return e; },
    reopen: (id: string) => { reopened.push(id); },
  } as unknown as GateHost;
  return { h, appended, reopened };
}

// job 1's greybox critic (event 61) named the base; its notes were the core's contact and the base camera.
const JOB1_CRITIC: Verdict = { ok: false, scores: { silhouette: 0.7, readability: 0.4, style_consistency: 0.7, shows_play: 0.5, fun_promise: 0.3 }, notes: ["contact reactions are a shove, no hit-stop", "the follow camera goes inside bodies in a pile and presses against the glass"], package: "base", report: "reports/critic-greybox-s60.json" };

test("E3f 3: on a core game a critic NOT ok that names the base holds the look for the person at once (no revise round, the card says what the base does); one that names a package of the job still revises; a retry still runs a round", () => {
  const look = { captures: ["captures/greybox-follow-f978.png"], strips: [], verdict: JOB1_CRITIC, summary: "s" };
  const a = criticHost();
  sendBack(a.h, "greybox", ["base", "cartridge"], "cartridge", 1, look);
  assert.deepEqual(a.reopened, [], "nothing re-opened");
  assert.deepEqual(a.appended.filter((e) => e["type"] === "package_state"), [], "no revise round queued");
  const m = a.appended.find((e) => e["type"] === "milestone") as { milestone: string; round: number; summary: string; captures: string[] } | undefined;
  assert.equal(m?.round, 2, "the hold's round: the job pauses for the quality card");
  assert.match(m?.summary ?? "", /^critic \(V5\) NOT ok: this is how the base plays \(base: engine\/templates\/rink_game\/ on the rink core: the skating, the contact, the bots, the base's camera\); no package of this game can change it, so no revise round was spent\..*The critic saw: contact reactions are a shove/);
  assert.equal(lookOk(m?.summary ?? ""), false);
  // the log as the Foreman reads it: held, then a retry sends one round with the person's note
  const ev = (seq: number, body: Record<string, unknown>): JobEvent => ({ v: 1, seq, ts: "t", job: "j", ...body }) as unknown as JobEvent;
  const log = [ev(70, { ...(m as object), type: "milestone" })];
  assert.deepEqual(qualityNext(log, "greybox", ["base", "cartridge"]), { next: "held", round: 2 });
  assert.deepEqual(foldEvents("j", log).qualityHeld, { milestone: "greybox", round: 2, seq: 70 });
  const r = criticHost();
  sendBack(r.h, "greybox", ["base", "cartridge"], "cartridge", 3, look, "make the camera higher");
  assert.deepEqual(r.appended.filter((e) => e["type"] === "package_state").map((e) => e["package"]), ["cartridge"], "a retry with the person's note still runs a round");
  // in the job's own scope: revise as today
  const c = criticHost();
  sendBack(c.h, "greybox", ["base", "cartridge"], "cartridge", 1, { ...look, verdict: { ...JOB1_CRITIC, package: "cartridge" } });
  assert.deepEqual(c.reopened, ["cartridge"]);
  assert.ok(!c.appended.some((e) => e["type"] === "milestone"));
  // off a core: the E5 rule as before (the milestone's built packages)
  const o = criticHost();
  (o.h.s as unknown as { brief: unknown }).brief = {};
  sendBack(o.h, "greybox", ["base", "cartridge"], "cartridge", 1, look);
  assert.deepEqual(o.appended.filter((e) => e["type"] === "package_state").map((e) => e["package"]), ["cartridge"]);
});

test("E3f 3b: a look the core's measured check fails is NOT ok (\"critic (V5) and core check NOT ok\" closed the milestone before)", () => {
  assert.equal(lookOk("all 2 package(s) ...; critic (V5) and core check NOT ok: core 0; CORE CHECK NOT ok (...) [reports/core-greybox-s83.json]"), false);
  assert.equal(lookOk("all 2 package(s) ...; core check NOT ok: core 0 [reports/core-greybox-s83.json]"), false);
  assert.equal(lookOk("all 2 package(s) ...; critic (V5) ok: silhouette 0.8; core check ok (...)"), true);
});

// ---------- 4: the measured check fails a match that is over before a person plays ----------

test("E3f 4: goals a minute against thirdjam's modes (1.29 to 4.8, sudden death included): job 1's first-to-5 in 1.2 min fails, job 2's first goal in 12 s stands as the data says (words), hokej's own cartridge passes", () => {
  const run = (f: string): ReturnType<typeof rinkCheckRun> => rinkCheckRun(0, fs.readFileSync(path.join(LINES, `${f}.json`), "utf8"));
  const j1 = run("job1");
  assert.equal(j1.code, 1, j1.summary);
  assert.match(j1.summary, /^GROSS DEFECTS: 6\.67 goals a minute at rookie \(6 goals in 0\.9 min, thirdjam's regular playtester\): thirdjam's own cartridges score 1\.29 to 4\.8 a minute \(sudden death included\), so 0\.4 to 5\.7 is the band: the match is over before a person has played it; 6\.33 goals a minute at pro/);
  const j2 = run("job2");
  assert.equal(j2.code, 0, j2.summary);
  assert.match(j2.summary, /matches shorter than any of thirdjam's modes \(0\.3 min at rookie, 0\.2 min at pro, 0\.2 min at all_star; the shortest, sudden death, lasts 0\.4 min or more\), at a goal rate thirdjam's modes play: words, not a defect/);
  const hk = run("hokej");
  assert.equal(hk.code, 0, hk.summary);
  assert.equal(hk.summary, "measured, no warning");
});

// ---------- the route's pure parts ----------

test("E3f: on a core the base never takes a change: cartridge words (team colours too: colour_hex is the cartridge's) to the cartridge's owner (the one with match.json), skin-only words to the skin; off a core and for a built owner nothing moves; the Planner is not offered the base", () => {
  const plan = [
    { id: "base", kind: "base", scope: ["assets/**", "data/**", "scripts/**"] },
    { id: "trials", scope: ["data/trial_*.cartridge.json"] },
    { id: "cartridge", scope: ["data/black_ice.cartridge.json", "data/match.json"] },
    { id: "skin", scope: ["data/skin.json"] },
  ] as unknown as PackageSpec[];
  for (const t of ["make the goals bigger", "make it faster", "the orange team is too strong", "a bigger rink", "first to 3", "make the teams red and gold"]) assert.equal(coreChangeOwner(plan, RINK_ROUTE, "base", t).owner, "cartridge", t);
  for (const t of ["change the commentary words", "call it PIRATES"]) assert.equal(coreChangeOwner(plan, RINK_ROUTE, "base", t).owner, "skin", t);
  assert.deepEqual(coreChangeOwner(plan, undefined, "base", "make the goals bigger"), { owner: "base" });
  assert.deepEqual(coreChangeOwner(plan, RINK_ROUTE, "skin", "make the goals bigger"), { owner: "skin" });
  const lines = plan.map((p) => ({ id: p.id, title: p.id, milestone: "greybox", deps: [], files: p.scope }));
  assert.deepEqual(changeCandidates(lines, plan, RINK_ROUTE).map((l) => l.id), ["trials", "cartridge", "skin"]);
  assert.deepEqual(changeCandidates(lines, plan, undefined).map((l) => l.id), ["base", "trials", "cartridge", "skin"]);
});

// ---------- 5: a change a person would not see is answered with the figures ----------

test("E3f 5: \"the orange team is too strong\" while your side wins 10, 10 and 9 of 10 (job 1, event 398's before figures) is asked back with them; a side that loses or a speed change goes through", () => {
  const job1 = { rookie_wins_of_10: 10, pro_wins_of_10: 10, pro_goals_a_match: 6.5, all_star_wins_of_10: 9, idle_wins_of_16: 0 };
  const q = unseenChange("the orange team is too strong", job1);
  assert.equal(q, "Your side already wins 10 of 10 at rookie, 10 of 10 at pro, 9 of 10 at all star (thirdjam's regular playtester on your seat), so weaker bots would hardly show. Did you mean something else that feels too strong (their speed, their checks, a bigger rink), or should the bots be weaker still? Say which, and the change is made.");
  assert.equal(unseenChange("the orange team is too strong", { rookie_wins_of_10: 9, pro_wins_of_10: 6, all_star_wins_of_10: 2 }), undefined);
  assert.equal(unseenChange("make it faster", job1), undefined);
  assert.match(unseenChange("it is too easy", { rookie_wins_of_10: 1, pro_wins_of_10: 0, all_star_wins_of_10: 0 }) ?? "", /^Your side already loses almost every match: it wins 1 of 10 at rookie/);
  assert.equal(unseenChange("it is too easy", job1), undefined, "too easy while winning everything: the change is real");
});
