// H1 of the day run of 25 Nov 2026 (editor hardening): the defects lane E5's real job E5e found
// (docs/shifts/2026-11-24-night/lanes/E5-proof/PROOF-E5e.md "Defects for the Director"). Each test below failed on main
// 39d3f7b and passes now.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, fastVerifier, foremanFor, readEvents, sampleConcept, scriptWith, tempDir, tempJob, v2Brief, type TempJob } from "./helpers.js";
import { spawnSync } from "node:child_process";
import type { FakeStep } from "../builder/fake.js";
import type { Brief, JobEvent, PackageSpec } from "../events.js";
import type { Verifier } from "../verifier.js";
type VerifyRequest = Parameters<Verifier["run"]>[0];
import { FAKE_VERBS_FILE, loadVerbs } from "../verbs.js";
import { REPO_ROOT } from "../paths.js";
import { HUD_HIDDEN, hudOn } from "../quality.js";
import { countKitUse, isCoreData } from "../conduct.js";
import { addedEntries, asksRemoval, compactChange, isYes, removedEntries, removedSince } from "../removal.js";
import { whatChangedNote } from "../fastchange.js";
import { main } from "../cli.js";
import { rebuildState } from "../joblog.js";

after(cleanup);

function designJob(label: string): TempJob {
  const job = tempJob(label);
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  const brief = JSON.parse(lines[1] as string) as { brief: Brief };
  brief.brief = { ...v2Brief(), concept: sampleConcept() };
  lines[1] = JSON.stringify(brief);
  const plan = JSON.parse(lines[3] as string) as { packages: PackageSpec[] };
  for (const p of plan.packages) p.milestone = "blockout";
  lines[3] = JSON.stringify(plan);
  fs.writeFileSync(file, lines.map((l) => l + "\n").join(""));
  return job;
}

/** A job whose engine's verbs.json is the fixture's plus the given capture options; the verifier records every request. */
function filmedJob(label: string, extra: Record<string, unknown>): { job: TempJob; requests: VerifyRequest[]; verifier: ReturnType<typeof fastVerifier> } {
  const job = designJob(label);
  const verbs = JSON.parse(fs.readFileSync(FAKE_VERBS_FILE, "utf8"));
  Object.assign(verbs.verbs.capture.options, extra);
  fs.mkdirSync(path.join(job.engineDir, "kernel", "runner"), { recursive: true });
  fs.writeFileSync(path.join(job.engineDir, "kernel", "runner", "verbs.json"), JSON.stringify(verbs, null, 1));
  const verifier = fastVerifier(job.engineDir);
  const requests: VerifyRequest[] = [];
  const run = verifier.run.bind(verifier);
  verifier.run = (req) => {
    requests.push(req);
    return run(req);
  };
  return { job, requests, verifier };
}

const CRITIC_OK: FakeStep = { match: { role: "critic" }, json: { ok: true, scores: { silhouette: 0.8, readability: 0.8, style_consistency: 0.8, shows_play: 0.8, fun_promise: 0.8, feel: 0.7, slop: 1, kill_criteria: 0.9 }, notes: ["the ring is under #7"] } };

// ---------------------------------------------------------------- 1. the critic sees the HUD

test("H1 1 (E5e defect 1): the engine's runner keeps the HUD on --hud=on (K2), so every still and strip the critic judges is filmed HUD on and labelled so; the critic prompt is told never to call a hidden HUD missing", async () => {
  const { job, requests, verifier } = filmedJob("h1-hud", { hud: { type: "string", default: "off" }, strip: { type: "string", default: "" } });
  const { foreman, builder } = foremanFor(job, { verifier, critic: true, promoteTo: "job", captureFrames: [120], script: scriptWith([CRITIC_OK]) });
  assert.equal((await foreman.run()).jobState?.state, "done");
  const captures = requests.filter((r) => r.verb === "capture");
  assert.ok(captures.length >= 2, `a still and a strip (got ${captures.length})`);
  for (const c of captures) assert.ok((c.args ?? []).includes("--hud=on"), `capture without the HUD: ${(c.args ?? []).join(" ")}`);
  const prompt = builder.calls.find((c) => c.req.meta?.role === "critic")?.req.prompt ?? "";
  assert.match(prompt, /- image 1 of 2, attached to this message: blockout-hero-f120\.png: camera hero, frame 120, [^\n]*; HUD ON: as a person sees the game/);
  assert.match(prompt, /MOTION STRIP [^\n]*; HUD ON: as a person sees the game/);
  assert.match(prompt, /never write that\na ring, a score, a clock or a hint is missing from a HUD OFF capture/);
  assert.equal(hudOn(loadVerbs(path.join(REPO_ROOT, "engine"))), true, "the real runner (engine/kernel/runner/verbs.json) has capture --hud");
});

test("H1 1b: a runner whose capture cannot keep the HUD gets no --hud and every label says exactly what is hidden", async () => {
  const { job, requests, verifier } = filmedJob("h1-nohud", {});
  const { foreman, builder } = foremanFor(job, { verifier, critic: true, promoteTo: "job", captureFrames: [120], script: scriptWith([{ ...CRITIC_OK, json: { ok: true, scores: { silhouette: 0.8, readability: 0.8, style_consistency: 0.8, shows_play: 0.8, fun_promise: 0.8, kill_criteria: 0.9 }, notes: ["fine"] } }]) });
  assert.equal((await foreman.run()).jobState?.state, "done");
  assert.ok(requests.some((r) => r.verb === "capture"));
  assert.ok(requests.every((r) => !(r.args ?? []).some((a) => a.startsWith("--hud"))));
  const prompt = builder.calls.find((c) => c.req.meta?.role === "critic")?.req.prompt ?? "";
  assert.ok(prompt.includes(`blockout-hero-f120.png: camera hero, frame 120`) && prompt.includes(HUD_HIDDEN), prompt.slice(0, 2000));
  assert.match(HUD_HIDDEN, /score, clock, rings and arrows under players, hints, banners, radar/);
  void (readEvents(job.jobDir) as JobEvent[]);
});

// ---------------------------------------------------------------- 2. a core's zones are data, not kit parts

const H1_FIX = path.join(REPO_ROOT, "foreman", "fixtures", "h1");
/** E5e's v0.1.1 cartridge (patches job, data/slush.cartridge.json) as the job promoted it: 8 zones, 4 bumpers of size 7. */
export const slushV011 = (): Record<string, any> => JSON.parse(fs.readFileSync(path.join(H1_FIX, "slush.v011.cartridge.json"), "utf8"));
/** Its v0.1.0, as PROOF-E5e.md table 2 says it was: no lane-middle, spot-nw at the north-west, bumpers 5 at (+-28, +-12). */
export function slushV010(): Record<string, any> {
  const c = slushV011();
  const zones = (c.game.rink.zones as { id: string }[]).filter((z) => z.id !== "lane-middle");
  zones.splice(zones.findIndex((z) => z.id === "spot-ne"), 0, { id: "spot-nw", shape: "rect", x: -18, z: 9, w: 2, d: 2, kind: "boost_only" } as { id: string });
  c.game.rink.zones = zones;
  c.game.rink.obstacles = (c.game.rink.obstacles as { x: number; z: number }[]).map((o) => ({ ...o, x: Math.sign(o.x) * 28, z: Math.sign(o.z) * 12, size: 5 }));
  return c;
}

test("H1 2 (E5e defect 2, event 110: \"kit parts used fell from 14 to 13\"): a cartridge's zones, obstacles and abilities and a rules sidecar are not kit parts; layout data and TLKit calls still are", () => {
  const pack = path.join(tempJob("h1-kit").root, "pack");
  const put = (rel: string, text: string): void => {
    fs.mkdirSync(path.dirname(path.join(pack, rel)), { recursive: true });
    fs.writeFileSync(path.join(pack, rel), text);
  };
  put("data/layout.json", JSON.stringify({ props: [{ kind: "crate", at: [0, 0, 0] }, { kind: "lamp", at: [1, 0, 0] }] }));
  put("scripts/main.gd", "extends Node\n# TLKit.crate in a comment does not count\nfunc _ready():\n\tTLKit.make(\"goal\")\n");
  put("data/slush.cartridge.json", JSON.stringify(slushV010(), null, 1));
  put("data/slush.rules.json", JSON.stringify({ schema: "tl.rink.rules/1", abilities: [{ kind: "dash" }] }));
  put("data/second.json", JSON.stringify({ ...slushV010(), id: "named-otherwise" })); // a cartridge known by its schema
  assert.equal(countKitUse(pack), 3, "2 layout props + 1 TLKit call; the cartridges' 8 zones and 4 bumpers and the sidecar's ability are data");
  put("data/slush.cartridge.json", JSON.stringify(slushV011(), null, 1)); // spot-nw dropped for lane-middle
  assert.equal(countKitUse(pack), 3, "dropping a zone is not a kit regression");
  assert.equal(isCoreData("data/slush.cartridge.json", "{}"), true);
  assert.equal(isCoreData("data/layout.json", fs.readFileSync(path.join(pack, "data", "layout.json"), "utf8")), false);
});

// ---------------------------------------------------------------- 3. the measured check: split, capped, cached

const CHECK = path.join(REPO_ROOT, "engine", "cores", "rink", "lab", "check_cartridge.mjs");
const FAKE_LAB = path.join(H1_FIX, "fake-rinklab.mjs");

interface Checked { code: number; line: Record<string, unknown>; log: { what: string; pid: number; t: number; args: string[] }[] }

/** check_cartridge.mjs --defects as the Foreman runs it (coreroute.ts runRinkCheck), on the stand-in lab. */
function checkCartridge(cart: string, extra: string[], env: Record<string, string>): Checked {
  const log = path.join(tempDir("h1-lab-log"), "lab.jsonl");
  const r = spawnSync(process.execPath, [CHECK, cart, "--defects", "--json-only", ...extra], { encoding: "utf8", env: { ...process.env, TL_RINKLAB_EXE: FAKE_LAB, TL_FAKE_LAB_LOG: log, ...env } });
  const last = (r.stdout ?? "").trim().split(/\r?\n/).at(-1) ?? "";
  const lines = fs.existsSync(log) ? fs.readFileSync(log, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : [];
  return { code: r.status ?? -1, line: JSON.parse(last) as Record<string, unknown>, log: lines };
}
const without = (l: Record<string, unknown>, ...keys: string[]): string => JSON.stringify(Object.fromEntries(Object.entries(l).filter(([k]) => !keys.includes(k))));
/** The most lab processes that ran at once, from their start and end lines. */
function peak(log: Checked["log"]): number {
  let now = 0;
  let most = 0;
  for (const e of [...log].sort((x, y) => x.t - y.t || (x.what === "end" ? -1 : 1))) {
    now += e.what === "start" ? 1 : -1;
    most = Math.max(most, now);
  }
  return most;
}

test("H1 3 (E3g item 5: 73 s of a 76 s check was one process playing the 16 skate_only matches in a row): the defect cells are split into 4 seed groups, at most 4 lab processes run at once, and the JSON line is byte for byte the one process's", () => {
  const cart = path.join(tempDir("h1-cart"), "slush.cartridge.json");
  fs.writeFileSync(cart, JSON.stringify(slushV010(), null, 1));
  const one = checkCartridge(cart, ["--no-cache", "--defect-groups", "1", "--jobs", "8"], {});
  const split = checkCartridge(cart, ["--no-cache"], {});
  assert.equal(one.code, 0, JSON.stringify(one.line));
  assert.equal(split.code, 0, JSON.stringify(split.line));
  assert.equal(without(split.line, "seconds"), without(one.line, "seconds"), "the same figures, byte for byte");
  assert.deepEqual((split.line["defects"] as Record<string, { matches: number }>)["skate_only"]?.matches, 16);
  const groups = (hand: string, log: Checked["log"]): string[] => log.filter((e) => e.what === "start" && e.args.includes(hand)).map((e) => e.args.find((a) => a.startsWith("-seeds=")) ?? "").sort();
  assert.deepEqual(groups("-plancheck", split.log), ["-seeds=1-4", "-seeds=13-16", "-seeds=5-8", "-seeds=9-12"]);
  assert.deepEqual(groups("-remove=idle", split.log), ["-seeds=1-4", "-seeds=13-16", "-seeds=5-8", "-seeds=9-12"]);
  assert.deepEqual(groups("-plancheck", one.log), ["-seeds=1-16"]);
  assert.equal(split.log.filter((e) => e.what === "start").length, 14, "3 playtester + 3 planning cells + 4 + 4 defect groups");
  assert.ok(peak(split.log) <= 4, `at most 4 lab processes at once (saw ${peak(split.log)})`);
  assert.ok(peak(split.log) >= 2, "the groups do run side by side");
  const capped = checkCartridge(cart, ["--no-cache", "--defect-groups", "9"], {});
  assert.equal(capped.log.filter((e) => e.what === "start" && e.args.includes("-plancheck")).length, 4, "never more than 4 groups");
});

test("H1 3b: the check's lab lines are cached by the cartridge's bytes and the lab's: the same check again plays no match and says so; another cartridge or another lab exe plays again", () => {
  const dir = tempDir("h1-cache");
  const cache = path.join(dir, "cache");
  const cart = path.join(dir, "slush.cartridge.json");
  fs.writeFileSync(cart, JSON.stringify(slushV010(), null, 1));
  const cold = checkCartridge(cart, [], { TL_RINK_CHECK_CACHE: cache });
  assert.equal(cold.code, 0);
  assert.equal(cold.line["cached"], undefined, "absent when measured (never false)");
  assert.equal(cold.log.filter((e) => e.what === "start").length, 14);
  const warm = checkCartridge(cart, [], { TL_RINK_CHECK_CACHE: cache });
  assert.equal(warm.log.length, 0, "no lab process ran");
  assert.equal(warm.line["cached"], true);
  assert.equal(without(warm.line, "seconds", "cached"), without(cold.line, "seconds"));
  // another cartridge (E5e's v0.1.1: lane-middle for spot-nw) is measured
  fs.writeFileSync(cart, JSON.stringify(slushV011(), null, 1));
  const other = checkCartridge(cart, [], { TL_RINK_CHECK_CACHE: cache });
  assert.equal(other.log.filter((e) => e.what === "start").length, 14);
  assert.notEqual(without(other.line, "seconds"), without(cold.line, "seconds"));
  // another lab exe (a rebuilt rinklab) is measured again
  const lab2 = path.join(dir, "fake-rinklab-2.mjs");
  fs.writeFileSync(lab2, `${fs.readFileSync(FAKE_LAB, "utf8")}\n// rebuilt\n`);
  const rebuilt = checkCartridge(cart, [], { TL_RINK_CHECK_CACHE: cache, TL_RINKLAB_EXE: lab2 });
  assert.equal(rebuilt.log.filter((e) => e.what === "start").length, 14);
  assert.equal(rebuilt.line["cached"], undefined);
  // --no-cache measures
  assert.equal(checkCartridge(cart, ["--no-cache"], { TL_RINK_CHECK_CACHE: cache }).log.filter((e) => e.what === "start").length, 14);
});

// ---------------------------------------------------------------- 4. a change that removes something unasked

const ENGINE = path.join(REPO_ROOT, "engine");

/** The stand-in engine of a core job (as e3f_change_path.test.ts builds it): the cards, the rink core's documents and modes, the base, hokej. */
function routeEngine(): string {
  const e = path.join(tempDir("h1-engine"), "engine");
  fs.mkdirSync(path.join(e, "kernel"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "kernel", "API.md"), path.join(e, "kernel", "API.md"));
  fs.cpSync(path.join(ENGINE, "cards"), path.join(e, "cards"), { recursive: true });
  fs.mkdirSync(path.join(e, "cores", "rink"), { recursive: true });
  for (const f of ["SNAPSHOT.md", "GAMEMODE.md", "CARTRIDGE.md"]) if (fs.existsSync(path.join(ENGINE, "cores", "rink", f))) fs.copyFileSync(path.join(ENGINE, "cores", "rink", f), path.join(e, "cores", "rink", f));
  fs.cpSync(path.join(ENGINE, "cores", "rink", "native", "content", "Cartridges", "modes"), path.join(e, "cores", "rink", "native", "content", "Cartridges", "modes"), { recursive: true });
  fs.cpSync(path.join(ENGINE, "templates", "rink_game"), path.join(e, "templates", "rink_game"), { recursive: true, filter: (src) => !src.endsWith(".uid") });
  fs.mkdirSync(path.join(e, "packs", "hokej", "data"), { recursive: true });
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "pack.json"), path.join(e, "packs", "hokej", "pack.json"));
  fs.copyFileSync(path.join(ENGINE, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"), path.join(e, "packs", "hokej", "data", "hockey.thirdlife.cartridge.json"));
  return e;
}

const CART = "data/slush.cartridge.json";
const SLUSH_ASKED = "make the bumpers bigger and add a fast lane through the middle";
/** E5e's first diff (PROOF-E5e.md section 2): bumpers 5 -> 7, lane-middle added, and TWO boost spots dropped (spot-nw, spot-ne) to stay under the core's 8 zones. */
function e5eDiff(): Record<string, unknown> {
  const v011 = slushV011();
  return { "game.rink.obstacles": v011.game.rink.obstacles, "game.rink.zones": (v011.game.rink.zones as { id: string }[]).filter((z) => z.id !== "spot-ne") };
}

/** E5e's patches job on the fake adapter, built to v0.1.0 (data/slush.cartridge.json, 8 zones); `run` drives it as Create does. */
async function slushJob(label: string): Promise<{ jobDir: string; run: (argv: string[]) => Promise<number>; log: string[] }> {
  const engine = routeEngine();
  const root = tempDir(label);
  const jobs = path.join(root, "jobs");
  const estimate = (readEvents(path.join(REPO_ROOT, "foreman", "fixtures", "job-paddle")).find((e) => e.type === "brief_set") as { estimate: unknown }).estimate;
  const rinkT = { id: "rink_sport" as const, reference: "thirdjam's match on the rink core", copies: ["thirdjam's match on the rink core, unchanged: skating, puck, bots", "the cartridge keys it changes: zones, obstacles", "the skin: title and team colours"] };
  const accept = [{ level: "V1" as const, verb: "lint" as const, args: [] }, { level: "V4" as const, verb: "bot" as const, args: ["--test=tests/bot_first_match.gd"] }];
  const plan = {
    card: "card.rink_core",
    phases: [{ id: "patches", title: "Slow and fast patches", try: "Skate through slush and fast lanes", packages: ["base", "slush_cartridge"] }, { id: "voice", title: "The patches' voice", try: "See PATCHES", packages: ["skin"] }],
    packages: [
      { id: "base", kind: "base", title: "Start from the rink_game base", milestone: "greybox", deps: [], scope: ["scripts/**"], contract: "start from the base", acceptance: [] },
      { id: "slush_cartridge", title: "Slush and fast patches, corner bumpers", milestone: "greybox", deps: ["base"], scope: [CART, "data/match.json"], contract: "Data only: zones and bumpers.", acceptance: accept },
      { id: "skin", title: "The patches skin", milestone: "tuned", deps: ["base", "slush_cartridge"], scope: ["data/skin.json"], contract: "SKIN: title PATCHES.", acceptance: [{ level: "V1" as const, verb: "lint" as const, args: [] }, { level: "V2" as const, verb: "smoke" as const, args: [] }] },
    ],
  };
  const script = {
    steps: [
      { match: { role: "concept" }, json: { concept: { ...sampleConcept(), chosen: 0, template: rinkT } } },
      { match: { role: "designer" }, json: { brief: { ...v2Brief(), rules: `${v2Brief().rules}\nCARTRIDGE: game.rink.zones = slow and fast patches\nSKIN: title = PATCHES` }, estimate } },
      { match: { role: "design_review" }, json: { scores: { hook: 0.8, gif: 0.7, depth: 0.7, feel: 0.8, fit: 0.9 }, slop: [], verdict: "ok", notes: "ok" } },
      { match: { role: "planner", promptIncludes: "Decide which ONE package owns" }, json: { package: "slush_cartridge", reason: "bumpers and lanes are the cartridge's zones and obstacles" } },
      { match: { role: "planner" }, json: plan },
      // a second try that keeps spot-ne but still drops spot-nw: asked again
      { match: { role: "cartridge", promptIncludes: "the person answered: \"no, keep spot-ne" }, json: { changes: { "game.rink.obstacles": slushV011().game.rink.obstacles, "game.rink.zones": slushV011().game.rink.zones }, why: "lane-middle; spot-ne kept, spot-nw goes (8 zones at most)" } },
      // the second try, after the person said no: the bumpers alone, every spot kept
      { match: { role: "cartridge", promptIncludes: "the person answered: \"no" }, json: { changes: { "game.rink.obstacles": slushV011().game.rink.obstacles }, why: "bumpers 7; no lane, so every spot stays" } },
      { match: { role: "cartridge" }, json: { changes: e5eDiff(), why: "bumpers 5 -> 7; lane-middle across the centre; the core allows at most 8 zones, so two boost spots go" } },
      { match: { role: "builder", package: "skin" }, patch: { "data/skin.json": { title: "PATCHES" } }, text: "The words.\nDEVIATIONS: none" },
      { match: { role: "builder", package: "slush_cartridge" }, write: { [CART]: JSON.stringify(slushV010(), null, 1) + "\n" }, patch: { "data/match.json": { cartridge: "slush.cartridge.json" } }, text: "The patches.\nDEVIATIONS: none" },
    ],
  };
  const scriptFile = path.join(root, "fake.json");
  fs.writeFileSync(scriptFile, JSON.stringify(script));
  const common = ["--adapter", "fake", "--fake-script", scriptFile, "--engine-dir", engine];
  const runFlags = [...common, "--runner", "fake", "--parallel", "1", "--no-critic", "--quiet"];
  const log: string[] = [];
  const say = (s: string): void => {
    log.push(s);
  };
  assert.equal(await main(["new", "hockey where the ice has slow and fast patches and bumpers in the corners", "--site", jobs, ...common], say), 0, log.join("\n"));
  const jobDir = path.join(jobs, fs.readdirSync(jobs)[0] as string);
  assert.equal(await main(["approve", jobDir], say), 0, log.join("\n"));
  assert.equal(await main(["plan", jobDir, ...common, "--runner", "fake", "--max-packages", "3"], say), 0, log.join("\n"));
  assert.equal(await main(["run", jobDir, ...runFlags], say), 3, log.join("\n"));
  assert.equal(await main(["phase", jobDir, "pass", ...runFlags], say), 3, log.join("\n"));
  assert.equal(await main(["phase", jobDir, "pass", ...runFlags], say), 0, log.join("\n"));
  assert.equal(rebuildState(jobDir, { write: false }).promotions.length, 1, log.join("\n"));
  return { jobDir, run: (argv) => main([...argv, ...runFlags], say), log };
}

const promoted = (jobDir: string, rel: string): Record<string, any> => {
  const s = rebuildState(jobDir, { write: false });
  return JSON.parse(fs.readFileSync(path.join(jobDir, s.promotions.at(-1)?.dest as string, ...rel.split("/")), "utf8"));
};
const zoneIds = (c: Record<string, any>): string[] => (c.game.rink.zones as { id: string }[]).map((z) => z.id);

test("H1 4 (E5e defects 2 and 3, the real change): \"make the bumpers bigger and add a fast lane through the middle\" whose diff drops spot-nw and spot-ne pauses with \"To add lane-middle I must remove spot-nw, spot-ne: OK?\"; OK makes it as it is, without a kit regression and without a builder round, and the what-changed note names each removal on its own line", async () => {
  const j = await slushJob("h1-remove");
  const from = readEvents(j.jobDir).at(-1)?.seq ?? 0;
  await j.run(["change", j.jobDir, SLUSH_ASKED]);
  let evs = readEvents(j.jobDir).filter((e) => e.seq > from);
  const q = evs.find((e) => e.type === "question");
  assert.ok(q?.type === "question", j.log.slice(-8).join("\n"));
  assert.equal(q.package, "slush_cartridge");
  assert.match(q.text, /^To add lane-middle I must remove spot-nw, spot-ne: OK\? \(spot-nw \(game\.rink\.zones\), spot-ne \(game\.rink\.zones\); the change's reason: bumpers 5 -> 7; lane-middle across the centre; the core allows at most 8 zones, so two boost spots go\)/);
  assert.ok(!evs.some((e) => e.type === "merge"), "nothing merged before the person says OK");
  assert.deepEqual(zoneIds(promoted(j.jobDir, CART)), zoneIds(slushV010()), "v0.1.0 untouched");
  assert.equal(rebuildState(j.jobDir, { write: false }).promotions.length, 1);
  // The person answers OK (Create's answer box): the diff that waited is made, with no new model call.
  const calls = readEvents(j.jobDir).filter((e) => e.type === "builder_run").length;
  assert.equal(await main(["answer", j.jobDir, "slush_cartridge", "OK"], (s) => j.log.push(s)), 0);
  await j.run(["resume", j.jobDir]);
  evs = readEvents(j.jobDir).filter((e) => e.seq > from);
  const s = rebuildState(j.jobDir, { write: false });
  assert.equal(s.jobState?.state, "done", `${s.jobState?.reason}\n${j.log.slice(-8).join("\n")}`);
  assert.equal(s.promotions.length, 2);
  assert.ok(!evs.some((e) => (e.type === "package_state" && e.cause === "kit_regression") || (e.type === "note" && /KIT REGRESSION/.test(e.text))), "a dropped zone is not a kit regression (E5e event 110)");
  assert.equal(readEvents(j.jobDir).filter((e) => e.type === "builder_run").length, calls, "no model call and no builder round after OK");
  assert.deepEqual(zoneIds(promoted(j.jobDir, CART)), ["lane-north", "lane-south", "lane-middle", "bog-east", "bog-west", "spot-se", "spot-sw"]);
  const what = evs.filter((e) => e.type === "note" && e.text.startsWith("[foreman] what changed")).map((e) => (e.type === "note" ? e.text : ""));
  assert.equal(what.length, 1);
  const lines = (what[0] ?? "").split("\n");
  // the first line is E3f's, cut at 1000 characters as before (here inside the zones' JSON: that is why a removal needs its own line)
  assert.match(lines[0] ?? "", /^\[foreman\] what changed in v0\.1\.1 \(since v0\.1\.0\): asked "make the bumpers bigger and add a fast lane through the middle"; game\.rink\.obstacles: /);
  assert.deepEqual(lines.slice(1).map((l) => l.replace(/; why: .*$/, "")), ["removed: spot-nw (game.rink.zones)", "removed: spot-ne (game.rink.zones)"]);
  assert.match(lines[1] ?? "", /; why: bumpers 5 -> 7; lane-middle across the centre; the core allows at most 8 zones, so two boost spots go \(the person agreed to the removal: "OK"\)$/);
});

test("H1 4b: a no keeps the spots (the diff is tried again with the answer and drops nothing); words that ask for the removal are made at once, the removal still named", async () => {
  const j = await slushJob("h1-remove-no");
  await j.run(["change", j.jobDir, SLUSH_ASKED]);
  assert.equal(await main(["answer", j.jobDir, "slush_cartridge", "no, keep the boost spots"], (s) => j.log.push(s)), 0);
  await j.run(["resume", j.jobDir]);
  const s = rebuildState(j.jobDir, { write: false });
  assert.equal(s.jobState?.state, "done", `${s.jobState?.reason}\n${j.log.slice(-8).join("\n")}`);
  assert.deepEqual(zoneIds(promoted(j.jobDir, CART)), zoneIds(slushV010()), "every spot kept");
  assert.equal(promoted(j.jobDir, CART).game.rink.obstacles[0].size, 7);
  const k = await slushJob("h1-remove-asked");
  const from = readEvents(k.jobDir).at(-1)?.seq ?? 0;
  await k.run(["change", k.jobDir, "drop two boost spots and add a fast lane through the middle, bigger bumpers"]);
  const evs = readEvents(k.jobDir).filter((e) => e.seq > from);
  assert.ok(!evs.some((e) => e.type === "question"), "asked for: no question");
  assert.equal(rebuildState(k.jobDir, { write: false }).promotions.length, 2);
  const what = evs.find((e) => e.type === "note" && e.text.startsWith("[foreman] what changed"));
  assert.match(what?.type === "note" ? what.text : "", /\nremoved: spot-nw \(game\.rink\.zones\); why: [^\n]+\nremoved: spot-ne \(game\.rink\.zones\); why: /);
});

test("H1 4d: a no whose next try still removes something is asked again (the Foreman's own words about the removal never count as the person asking for it)", async () => {
  const j = await slushJob("h1-remove-again");
  await j.run(["change", j.jobDir, SLUSH_ASKED]);
  assert.equal(await main(["answer", j.jobDir, "slush_cartridge", "no, keep spot-ne"], (s) => j.log.push(s)), 0);
  await j.run(["resume", j.jobDir]);
  const qs = readEvents(j.jobDir).filter((e) => e.type === "question").map((e) => (e.type === "question" ? e.text : ""));
  assert.equal(qs.length, 2, j.log.slice(-6).join("\n"));
  assert.match(qs[1] ?? "", /^To add lane-middle I must remove spot-nw: OK\? /);
  assert.equal(rebuildState(j.jobDir, { write: false }).promotions.length, 1, "nothing made until the person says OK");
  assert.equal(await main(["answer", j.jobDir, "slush_cartridge", "ok"], (s) => j.log.push(s)), 0);
  await j.run(["resume", j.jobDir]);
  assert.deepEqual(zoneIds(promoted(j.jobDir, CART)), zoneIds(slushV011()));
});

test("H1 4c: the pure parts: removals by id and by kind, asked words, a yes, the builder's path named from the promoted copy", () => {
  assert.deepEqual(removedEntries(slushV010(), slushV011()), [{ where: "game.rink.zones", what: "spot-nw" }]);
  assert.deepEqual(addedEntries(slushV010(), slushV011()), [{ where: "game.rink.zones", what: "lane-middle" }]);
  const fewer = slushV010();
  fewer.game.rink.obstacles = fewer.game.rink.obstacles.slice(1);
  assert.deepEqual(removedEntries(slushV010(), fewer), [{ where: "game.rink.obstacles", what: "a bumper" }], "obstacles have no id: counted by kind");
  const bigger = slushV010();
  bigger.game.rink.obstacles = slushV011().game.rink.obstacles;
  assert.deepEqual(removedEntries(slushV010(), bigger), [], "bigger bumpers remove nothing");
  for (const w of ["remove the north-west spot", "drop a boost spot", "fewer bumpers", "a lane instead of the spot", "without the bog", "take the spots out"]) assert.equal(asksRemoval(w), true, w);
  for (const w of [SLUSH_ASKED, "make the rink bigger", "faster skaters"]) assert.equal(asksRemoval(w), false, w);
  for (const a of ["OK", "ok", "Yes", "yes, no problem", "sure, go on", "It's fine"]) assert.equal(isYes(a), true, a);
  for (const a of ["no", "no, keep the boost spots", "ok but keep spot-nw", "keep them", "yes, but not spot-ne"]) assert.equal(isYes(a), false, a);
  const was = path.join(tempDir("h1-promoted"), "pack");
  const now = path.join(tempDir("h1-now"), "pack");
  for (const [d, c] of [[was, slushV010()], [now, slushV011()]] as const) {
    fs.mkdirSync(path.join(d, "data"), { recursive: true });
    fs.writeFileSync(path.join(d, CART), JSON.stringify(c));
  }
  assert.deepEqual(removedSince(was, now), [{ where: "game.rink.zones", what: "spot-nw" }]);
  const ev = (seq: number, body: Record<string, unknown>): JobEvent => ({ v: 1, seq, ts: "t", job: "j", ...body }) as unknown as JobEvent;
  const log = [ev(1, { type: "promoted", packId: "p", version: "0.1.0", dest: "promoted/p" }), ev(2, { type: "change_requested", text: SLUSH_ASKED }), ev(3, { type: "merge", package: "slush_cartridge", round: 2, files: [CART] })];
  assert.equal(whatChangedNote(log, "0.1.1", removedSince(was, now)), `[foreman] what changed in v0.1.1 (since v0.1.0): asked "${SLUSH_ASKED}"; files: ${CART}\nremoved: spot-nw (game.rink.zones); why: not said (a builder's round; its DEVIATIONS may say)`);
  assert.equal(whatChangedNote(log, "0.1.1"), `[foreman] what changed in v0.1.1 (since v0.1.0): asked "${SLUSH_ASKED}"; files: ${CART}`, "nothing removed: the one line as before");
});

test("H1b 3 (E5e: the what-changed line carried the zones' whole JSON and was cut at 1000 characters): list changes are compact, \"game.rink.zones: + lane-middle, - spot-nw, - spot-ne\", so the line ends with its files; scalars stay as they were", async () => {
  const j = await slushJob("h1b-compact");
  const from = readEvents(j.jobDir).at(-1)?.seq ?? 0;
  await j.run(["change", j.jobDir, "drop two boost spots and add a fast lane through the middle, bigger bumpers"]);
  const what = readEvents(j.jobDir).find((e) => e.seq > from && e.type === "note" && e.text.startsWith("[foreman] what changed"));
  const first = (what?.type === "note" ? what.text : "").split("\n")[0] ?? "";
  assert.equal(first, "[foreman] what changed in v0.1.1 (since v0.1.0): asked \"drop two boost spots and add a fast lane through the middle, bigger bumpers\"; game.rink.obstacles: 4 bumpers changed, size 5 -> 7, x, z; game.rink.zones: + lane-middle, - spot-nw, - spot-ne; files: data/slush.cartridge.json");
  assert.equal(compactChange("game.rink.goal_width_m: 4 -> 4.4"), "game.rink.goal_width_m: 4 -> 4.4");
  assert.equal(compactChange('game.ai.difficulty: "pro" -> "rookie"'), 'game.ai.difficulty: "pro" -> "rookie"');
  assert.equal(compactChange('game.rules: {"first_to":3,"periods":1} -> {"first_to":5,"periods":1}'), "game.rules: first_to changed");
  assert.equal(compactChange('game.rink.zones: absent -> [{"id":"a","kind":"boost_only"}]'), 'game.rink.zones: absent -> [{"id":"a","kind":"boost_only"}]', "a list that was absent is shown as it is");
});

test("H1b 4: `rink.sh check-warm` measures the house cartridge and every base's once (the Foreman's arguments), so a job's first check reads the cache; again, it measures nothing; a lab build whose exe is new runs it", () => {
  const cache = path.join(tempDir("h1b-warm"), "cache");
  const env = { ...process.env, TL_RINKLAB_EXE: FAKE_LAB, TL_RINK_CHECK_CACHE: cache };
  const warm = (): string => (spawnSync("bash", [path.join(REPO_ROOT, "engine", "tools", "rink.sh"), "check-warm"], { encoding: "utf8", env }).stdout ?? "").trim().split(/\r?\n/).at(-1) ?? "";
  const bases = fs.readdirSync(path.join(ENGINE, "templates")).flatMap((t) => (fs.existsSync(path.join(ENGINE, "templates", t, "data")) ? fs.readdirSync(path.join(ENGINE, "templates", t, "data")).filter((f) => f.endsWith(".cartridge.json")) : [])).length;
  assert.equal(warm(), `PASS  rink check-warm: ${bases + 1} cartridge(s) in the cache (${bases + 1} measured now, 0 already there)`);
  assert.equal(warm(), `PASS  rink check-warm: ${bases + 1} cartridge(s) in the cache (0 measured now, ${bases + 1} already there)`);
  // the job's house check (coreroute.ts runRinkCheck: the cartridge, its rules, --defects) is now a cache read
  const hk = path.join(ENGINE, "packs", "hokej", "data");
  const house = checkCartridge(path.join(hk, "hockey.thirdlife.cartridge.json"), ["--rules", path.join(hk, "hockey.thirdlife.rules.json")], { TL_RINK_CHECK_CACHE: cache });
  assert.equal(house.line["cached"], true);
  assert.equal(house.log.length, 0, "no lab process ran");
  const sh = fs.readFileSync(path.join(ENGINE, "tools", "rink.sh"), "utf8");
  assert.equal((sh.match(/\|\| "\$0" check-warm/g) ?? []).length, 2, "lab-build and lab-build-thirdlife warm when their exe changed");
});
