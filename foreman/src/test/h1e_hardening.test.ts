// H1e of the day run of 25 Nov 2026 (editor hardening, round 5): games from scratch judged as hockey. Fixtures are the
// real texts of lanes G2 (robot football, d25-robot) and G4 (half-court basketball, d25-court), copied read only into
// foreman/fixtures/h1e/. Each test failed on main d6260bb and passes now.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, foremanFor, readEvents, scriptWith, tempDir, tempJob } from "./helpers.js";
import { rebuildState } from "../joblog.js";
import type { FakeStep } from "../builder/fake.js";
import type { Brief, JobEvent, PackageSpec } from "../events.js";
import type { GateHost } from "../p10gate.js";
import type { VerifyResult } from "../verifier.js";
import { REPO_ROOT } from "../paths.js";
import { contactDiff } from "../revisepair.js";
import { gameHasRow, gameHasVerb, gameWords } from "../gamewords.js";
import { houseForeign, houseItem } from "../quality.js";
import { tofuGate } from "../tofugate.js";
import { cardBriefSection } from "../cards.js";
import { toyClear, toyLines } from "../rinkjudge.js";

after(cleanup);

const FX = path.join(REPO_ROOT, "foreman", "fixtures", "h1e");
const read = <T>(f: string): T => JSON.parse(fs.readFileSync(path.join(FX, f), "utf8")) as T;
const G4_BRIEF = read<Brief>("g4-brief.json");
const G2_BRIEF = read<Brief>("g2-brief.json");
const HOCKEY = path.join(REPO_ROOT, "engine", "packs", "hockey");

// ---------------------------------------------------------------- 0. the first promotion is held to the window too

test("H1e 0 (the Director's answer to H1d: a first promotion takes one picture): a v0.1.0 that throws a script error in a window is not promoted, in words", async () => {
  const job = tempJob("h1e-first");
  const voice: FakeStep = { match: { role: "builder", package: "core", round: 1 }, write: { "scripts/main.gd": "extends Node\n# the opening call FAKE_WINDOW_ERROR\n", "tests/bot_rally.gd": "extends Node\n" }, text: "Done.\nDEVIATIONS: none" };
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith([voice]) }).foreman.run();
  assert.equal(s.jobState?.state, "failed", JSON.stringify(s.jobState));
  assert.match(s.jobState?.reason ?? "", /^promotion refused: in a window, as a person plays it, the game throws script errors in 1 of 1 promotion picture\(s\): rink audio: no voice for commentary line 'faceoff\.drop\.04' \(scripts\/main\.gd:2\)\. [^]*Nothing was promoted\./);
  assert.equal(rebuildState(job.jobDir, { write: false }).promotions.length, 0);
  // a clean first build takes its one picture and is promoted
  const ok = tempJob("h1e-first-ok");
  const s2 = await foremanFor(ok, { promoteTo: "job" }).foreman.run();
  assert.equal(s2.jobState?.state, "done");
  assert.equal(readEvents(ok.jobDir).filter((e) => e.type === "verify" && e.verb === "capture" && /promotion1-capture-/.test(e.report)).length, 1, "one picture");
});

// ---------------------------------------------------------------- 1. judged by the game's own design

test("H1e 1 (G4 events 127-171: a basketball pack held for want of 70 HOCKEY contact rows): the house rows a game's design does not have are not judged and never missing; the ones it shares still are", () => {
  const words = gameWords(G4_BRIEF);
  const build = path.join(tempDir("h1e-build"), "pack");
  fs.mkdirSync(path.join(build, "data"), { recursive: true });
  fs.copyFileSync(path.join(FX, "g4-tuning.json"), path.join(build, "data", "tuning.json"));
  const before = contactDiff(build, HOCKEY, "arcade_sport", "hockey");
  assert.equal(before?.missing.length, 70, "without the game's words every house row is asked for (the old behaviour)");
  const now = contactDiff(build, HOCKEY, "arcade_sport", "hockey", 14, words);
  assert.ok(now !== undefined);
  for (const k of ["check_gap", "check_cone_deg", "board_bonus", "board_range", "cross_gap", "lunge_speed", "save_frames", "goal_shake"]) assert.ok(!now.missing.some((x) => x.includes(`.${k} `)), `${k} is hockey's, not missing`);
  assert.ok(now.missing.some((x) => x.includes("hits.stumble_ratio")), "how a body takes contact is shared, and still asked");
  assert.ok(now.missing.length < 70 && now.missing.length > 0);
  assert.match(now.line, /\d+ house contact row\(s\) belong to engine\/packs\/hockey's own play \(check, [^)]*board[^)]*\), which this game's design does not have: not judged, not missing/);
  // verbs: G2's robot football designed its own one-timer (an aspect card), G4's basketball did not
  assert.equal(gameHasVerb(G2_BRIEF.design ? gameWords(G2_BRIEF) : undefined, "one_timer"), true);
  assert.equal(gameHasVerb(words, "one_timer"), false);
  assert.equal(gameHasVerb(words, "screen_spring"), true);
  assert.equal(gameHasRow(undefined, "hits.board_bonus"), true, "a brief without a design: nothing is filtered");
});

test("H1e 1b (G2 events 84, 126 and G4: the revise pair said \"make the house game's kind happen\", a hockey one_timer; G4's basketball has none, G2's robot football designed its own): the house_game rubric names what this game does not have and forbids asking for it", () => {
  const dir = tempDir("h1e-house");
  fs.mkdirSync(path.join(dir, "ref", "packs", "hockey", "data"), { recursive: true });
  fs.copyFileSync(path.join(HOCKEY, "data", "tuning.json"), path.join(dir, "ref", "packs", "hockey", "data", "tuning.json"));
  const h = { s: { brief: G4_BRIEF }, dir: (...p: string[]) => path.join(dir, ...p) } as unknown as GateHost;
  const foreign = houseForeign(h, "hockey");
  for (const w of ["one_timer", "check", "board", "cross"]) assert.ok(foreign.includes(w), `${w} in ${foreign.join(", ")}`);
  assert.ok(!foreign.includes("poke"), "a poke is the basketball's too (its steal copies the template's poke)");
  assert.match(houseItem("hockey", foreign).text, /This game's design does not have the house game's one_timer, [^.]*: never call them missing and never ask for them; set beside it only what the two games share \(the bodies, how they take contact, the team's play\)\./);
  assert.doesNotMatch(houseItem("hockey").text, /does not have/, "a game of the house game's own kind is judged as before");
});

// ---------------------------------------------------------------- 2. the plan's tofu bounds, enforced by the Foreman

test("H1e 2 (G4 events 76, 81-86: bot_tofu answered ok with pressure_waves 0 and scrum_share 0.453, and the round merged and was promoted): the Foreman judges the tofu bot's metrics against the plan's bounds at the round's acceptance", () => {
  const plan = read<PackageSpec[]>("g4-plan.json");
  const report = read<VerifyResult["report"]>("g4-court_exchange-r2-bot-s82.json");
  const dir = tempDir("h1e-tofu");
  const appended: Record<string, unknown>[] = [];
  const h = {
    s: { plan, brief: G4_BRIEF, lastSeq: 81 },
    pkg: () => ({ round: 2, roundBase: undefined }),
    dir: (...p: string[]) => path.join(dir, ...p),
    rel: (abs: string) => path.relative(dir, abs).split(path.sep).join("/"),
    append: (e: Record<string, unknown>) => (appended.push(e), e as unknown as JobEvent),
  } as unknown as GateHost;
  const vr = { verb: "bot", level: "V4", ok: true, report, reportFile: path.join(dir, "reports", "court_exchange-r2-bot-s82.json"), verdictFile: "", flags: [], summary: "bot passed", durationMs: 1 } as unknown as VerifyResult;
  const a = { verb: "bot" as const, args: ["--test=tests/bot_tofu.gd", "--frames=72000"] };
  const f = tofuGate(h, "court_exchange", a, vr);
  assert.ok(f !== undefined && !f.ok, "the bot's ok is not the check");
  assert.match(f.summary, /^tests\/bot_tofu\.gd answered ok, but the Foreman judges its metrics against the plan's tofu bounds and \d+ are outside them: [^]*pressure_waves 0 \(the plan's bound: >= 2\)[^]*scrum_share 0\.453 \(the plan's bound: <= 0\.3\)/);
  const ev = appended.find((e) => e["type"] === "verify");
  assert.equal(ev?.["ok"], false, "a failed check of its own, which the next round's feedback reads");
  assert.ok(fs.existsSync(path.join(dir, String(ev?.["report"]))));
  // another bot, or a bot inside its bounds, is the bot's own verdict as before
  assert.equal(tofuGate(h, "court_exchange", { verb: "bot", args: ["--test=tests/bot_play.gd"] }, vr), undefined);
  // after two such rounds the round merges and the milestone look judges (two revise rounds, then the person)
  const later = { ...h, pkg: () => ({ round: 3 }) } as unknown as GateHost;
  assert.equal(tofuGate(later, "court_exchange", a, vr), undefined);
});

// ---------------------------------------------------------------- 3. the card says what transfers

test("H1e 3: the team-possession card names what a ball game takes from the house hockey (bodies, contact, possession, the pass, team AI) and what it does not (stick, puck, one-timer, boards, body check), and the builder's recipe section carries it", () => {
  const card = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "engine", "cards", "team_possession.json"), "utf8")) as { dont: string[]; variants: { ask: string; change: string }[] };
  const line = card.dont.find((d) => d.startsWith("Do not carry hockey into a ball game."));
  assert.ok(line !== undefined);
  for (const w of ["bodies", "possession by reach", "the pass", "team AI", "stick", "puck", "one-timer", "boards", "body check", "cross-check"]) assert.ok(line.includes(w), w);
  assert.ok(card.variants.some((v) => v.ask === "basketball or another ball game on a court" && /drop the stick, the one-timer, the boards and the body check/.test(v.change)));
  const section = cardBriefSection(path.join(REPO_ROOT, "engine"), "card.team_possession");
  assert.match(section, /Do not carry hockey into a ball game\./);
});

// ---------------------------------------------------------------- 4. no confident word from noise

test("H1e 4 (G1 round 3, PROOF-G1.md section 14: at 20 seeds the pickups read -15, the pads -10, the pools -10; at 80 they are -6, +1, +10): a toy's worth is said only when the paired matches show it; otherwise \"not clear yet\" with the two counts", () => {
  type Row = { toy: string; s20: { with: number; without: number }; s80: { with: number; without: number; only_with?: number; only_without?: number } };
  const fx = read<{ toys: Row[]; versions80: { version: string; with: number; without: number; only_with: number; only_without: number }[] }>("g1-toys-20-vs-80.json");
  // every pairing of the 20-seed figures (won only with / only without that give those totals) is "not clear yet":
  // never "costs you" or "changes little" for the three toys whose sign 80 seeds turned over
  for (const t of fx.toys.slice(1)) {
    const diff = t.s20.without - t.s20.with;
    for (let a = 0; a + (a + diff) <= 20; a++) {
      const verdict = toyClear(20, 20, a, a + diff, Math.round((100 * (t.s20.with - t.s20.without)) / 20));
      assert.equal(verdict, "not_clear", `${t.toy}: ${a} only with, ${a + diff} only without`);
    }
  }
  // the 80-seed pairs G1 counted: the returning bubble helps (22 against 11); the first bubble (5 against 8) is not clear
  const by = (v: string) => fx.versions80.find((x) => x.version.startsWith(v)) as (typeof fx.versions80)[number];
  const verdict = (r: (typeof fx.versions80)[number]) => toyClear(80, 80, r.only_with, r.only_without, Math.round((100 * (r.with - r.without)) / 80));
  assert.equal(verdict(by("v0.1.4 to")), "helps");
  assert.equal(verdict(by("v0.1.4 at all_star")), "helps");
  assert.equal(verdict(by("v0.1.0")), "not_clear");
  assert.equal(verdict(by("v0.1.1")), "not_clear");
  // the card's words carry the counts, never a bare figure
  assert.deepEqual(toyLines([{ toy: "the pickups (speed, precision)", measured: true, matches: 20, wins_with: 11, wins_without: 14, points: -15, goal_diff: -0.3, changed: 20, won_only_with: 2, won_only_without: 5 }]), ["The pickups: not clear yet (won only with it 2, only without it 5, of 20)"]);
  assert.deepEqual(toyLines([{ toy: "the F bubble", measured: true, matches: 80, wins_with: 54, wins_without: 43, points: 14, goal_diff: 0.4, changed: 80, won_only_with: 22, won_only_without: 11 }]), [], "a toy that helps needs no line");
});
