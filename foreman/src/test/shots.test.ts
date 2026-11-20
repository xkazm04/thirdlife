// L2b of 21 Nov: a milestone is filmed with the pack's first test (as before) AND the own acceptance bot of its
// newest package, at 25 % and 95 % of where that bot finished; the critic is told which bot and package each capture
// is from. Found by the crazy proof job: the flood (frame 2402 of bot_flood's 2582) was never on camera.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { planShots, shotFile, shotFrames, shotLabel, MAX_SHOT_BOTS } from "../shots.js";
import { validateEvent, type JobEvent, type PackageSpec } from "../events.js";
import { cleanup, tempJob, foremanFor, readEvents, scriptWith, fixtureScript } from "./helpers.js";

after(cleanup);

const acc = (...tests: string[]): PackageSpec["acceptance"] => [{ level: "V1", verb: "lint", args: [] }, ...tests.map((t) => ({ level: "V4" as const, verb: "bot" as const, args: [`--test=${t}`, "--seed=1"] }))];
const pkg = (id: string, deps: string[], registers: string[], runs: string[]): PackageSpec => ({ id, title: id, milestone: "tuned", deps, scope: [`scripts/${id}.gd`, ...registers], contract: "c", acceptance: acc(...runs), ...(registers.length > 0 ? { registers: { tests: registers } } : {}) });

// The crazy proof job's tuned milestone, as its plan and merges were (fight-colosseum-20261120-2).
const plan: PackageSpec[] = [
  { ...pkg("core", [], ["tests/bot_bout.gd"], ["tests/bot_bout.gd"]), milestone: "blockout" },
  pkg("impact", ["core"], ["tests/bot_slam.gd"], ["tests/bot_bout.gd", "tests/bot_slam.gd"]),
  pkg("growth", ["impact"], [], ["tests/bot_bout.gd", "tests/bot_ladder.gd"]),
  pkg("flood", ["growth"], ["tests/bot_flood.gd"], ["tests/bot_bout.gd", "tests/bot_flood.gd"]),
];
const merges = (order: string[]): JobEvent[] => order.map((p, i) => ({ v: 1, seq: 10 + i, ts: "2026-11-20T22:00:00.000Z", job: "j", type: "merge", package: p, files: [`scripts/${p}.gd`] }) as JobEvent);
const manifest = ["tests/bot_bout.gd", "tests/bot_ladder.gd", "tests/bot_slam.gd", "tests/bot_flood.gd"];
const finish: Record<string, number> = { "tests/bot_bout.gd": 465, "tests/bot_slam.gd": 900, "tests/bot_flood.gd": 2582 };

test("shots: the first test as before, plus the newest package's own acceptance bot at 25 % and 95 % of ITS finish (the flood at 2402 is inside 2453)", () => {
  const shots = planShots(plan, merges(["core", "impact", "growth", "flood"]), ["impact", "growth", "flood"], manifest, (b) => finish[b]);
  assert.equal(shots.length, MAX_SHOT_BOTS);
  assert.deepEqual(shots[0], { bot: "tests/bot_bout.gd", package: "core", frames: [116, 349], finish: 465, kind: "first" });
  assert.deepEqual(shots[1], { bot: "tests/bot_flood.gd", package: "flood", frames: [646, 2453], finish: 2582, kind: "own" });
  assert.ok((shots[1]?.frames[1] ?? 0) > 2402, "the second frame is after the flood starts");
  assert.ok(Math.round(2582 * 0.75) < 2402, "the old 75 % would still miss it");
});

test("shots: newest merge first; a package with no own acceptance bot is skipped; the first test is never filmed twice; the cap holds", () => {
  // impact merged again after flood (a change round): impact is now the newest.
  const again = planShots(plan, merges(["core", "impact", "growth", "flood", "impact"]), ["impact", "growth", "flood"], manifest, (b) => finish[b]);
  assert.deepEqual(again.map((s) => [s.bot, s.package]), [["tests/bot_bout.gd", "core"], ["tests/bot_slam.gd", "impact"]]);
  // growth only runs other packages' bots: nothing of its own to film.
  assert.deepEqual(planShots(plan, merges(["growth"]), ["growth"], manifest, (b) => finish[b]).map((s) => s.kind), ["first"]);
  // core's own bot IS the first test: one shot, the old one (blockout of every job made before L2b looks the same).
  assert.deepEqual(planShots(plan, merges(["core"]), ["core"], manifest, (b) => finish[b]).map((s) => s.bot), ["tests/bot_bout.gd"]);
  // a bot the package registers but its acceptance never runs, or one the manifest does not list, is not its own.
  const noRun = [{ ...plan[0] as PackageSpec }, pkg("x", ["core"], ["tests/bot_x.gd"], []), pkg("y", ["core"], ["tests/bot_y.gd"], ["tests/bot_y.gd"])];
  assert.deepEqual(planShots(noRun, merges(["x", "y"]), ["x", "y"], manifest, () => undefined).map((s) => s.bot), ["tests/bot_bout.gd"]);
  // no passing report yet: 120 and 480, as before; the captureFrames option wins everywhere.
  assert.deepEqual(shotFrames(undefined, "own"), [120, 480]);
  assert.deepEqual(planShots(plan, merges(["flood"]), ["flood"], manifest, (b) => finish[b], [10]).map((s) => s.frames), [[10], [10]]);
  // no test at all: one shot without a bot.
  assert.deepEqual(planShots([], [], [], [], () => undefined), [{ frames: [120, 480], kind: "first" }]);
});

test("shots: file names (the first shot keeps the old name) and what the critic is told about each capture", () => {
  const [first, own] = planShots(plan, merges(["flood"]), ["flood"], manifest, (b) => finish[b]);
  assert.equal(shotFile("tuned", "play", 116, first!, 0), "tuned-play-f116.png");
  assert.equal(shotFile("tuned", "play", 2453, own!, 1), "tuned-play-bot_flood-f2453.png");
  assert.equal(shotLabel("play", 2453, own!), "camera play, frame 2453, while tests/bot_flood.gd of package flood plays, 95 % of the frame 2582 where it finished");
  assert.equal(shotLabel("play", 120, { frames: [120], kind: "first" }), "camera play, frame 120, no bot playing");
});

test("shots in a run: a package with its own bot gets its own captures, the critic's prompt and the critique report name bot and package per capture", async () => {
  const job = tempJob("shots-run");
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean).map((l) => {
    const ev = JSON.parse(l) as JobEvent;
    if (ev.type !== "plan_set") return l;
    const ai = ev.packages.find((p) => p.id === "paddle_ai") as PackageSpec;
    ai.scope.push("tests/bot_ai.gd");
    ai.registers = { tests: ["tests/bot_ai.gd"] };
    ai.acceptance.push({ level: "V4", verb: "bot", args: ["--test=tests/bot_ai.gd"] });
    ev.packages.find((p) => p.id === "core")?.acceptance.push({ level: "V4", verb: "bot", args: ["--test=tests/bot_rally.gd"] });
    return JSON.stringify(validateEvent(ev));
  });
  fs.writeFileSync(file, lines.join("\n") + "\n");
  const bot = String((fixtureScript().steps.find((s) => s.match?.package === "core")?.write ?? {})["tests/bot_rally.gd"]);
  const script = scriptWith([{ match: { role: "builder", package: "paddle_ai", round: 1 }, write: { "data/ai.json": '{"reaction_frames": 8}\n', "scripts/paddle_ai.gd": "extends RefCounted\n", "tests/bot_ai.gd": bot }, text: "Done." }]);
  const { foreman, builder } = foremanFor(job, { script, critic: true });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const ms = readEvents(job.jobDir).filter((e): e is Extract<JobEvent, { type: "milestone" }> => e.type === "milestone");
  assert.deepEqual(ms.map((m) => m.captures), [
    ["captures/blockout-hero-f150.png", "captures/blockout-hero-f450.png"],
    ["captures/greybox-hero-f150.png", "captures/greybox-hero-f450.png", "captures/greybox-hero-bot_ai-f150.png", "captures/greybox-hero-bot_ai-f570.png"],
  ]);
  const critic = builder.calls.filter((c) => c.req.meta?.role === "critic").at(-1);
  assert.match(critic?.req.prompt ?? "", /image 4 of 4, attached to this message: greybox-hero-bot_ai-f570\.png: camera hero, frame 570, while tests\/bot_ai\.gd of package paddle_ai plays, 95 % of the frame 600 where it finished/);
  assert.match(critic?.req.prompt ?? "", /image 1 of 4, attached to this message: greybox-hero-f150\.png: camera hero, frame 150, while tests\/bot_rally\.gd of package core plays/);
  const report = fs.readdirSync(path.join(job.jobDir, "reports")).filter((f) => f.startsWith("critic-greybox")).map((f) => JSON.parse(fs.readFileSync(path.join(job.jobDir, "reports", f), "utf8")) as { schema?: string; shots?: { capture: string; label: string }[] }).find((r) => r.schema === "tl.foreman.critique/1");
  assert.equal(report?.shots?.length, 4);
  assert.match(report?.shots?.[3]?.label ?? "", /tests\/bot_ai\.gd of package paddle_ai/);
});

test("foreman critique <job> <milestone> --out DIR: the captures and one critic call again, on pack/ as it is; nothing in the job changes", async () => {
  const { main } = await import("../cli.js");
  const job = tempJob("critique-dry");
  const lines: string[] = [];
  assert.equal(await main(["run", job.jobDir, "--adapter", "fake", "--quiet"], (x) => lines.push(x)), 0, lines.join("\n"));
  const before = fs.readFileSync(path.join(job.jobDir, "job.jsonl"), "utf8");
  const files = fs.readdirSync(job.jobDir, { recursive: true }).length;
  const out = path.join(job.root, "critique");
  const said: string[] = [];
  const code = await main(["critique", job.jobDir, "greybox", "--out", out, "--adapter", "fake"], (x) => said.push(x));
  assert.equal(code, 0, said.join("\n"));
  assert.match(said.join("\n"), /shot 1: tests\/bot_rally\.gd \(package core\), finish 600, frames 150, 450/);
  assert.match(said.join("\n"), /critic \(V5\) ok: silhouette 0\.8/);
  const verdict = JSON.parse(fs.readFileSync(path.join(out, "critique.json"), "utf8")) as { dry: boolean; captures: string[]; shots: { label: string }[] };
  assert.equal(verdict.dry, true);
  assert.deepEqual(verdict.captures, ["greybox-hero-f150.png", "greybox-hero-f450.png"]);
  assert.equal(fs.readFileSync(path.join(job.jobDir, "job.jsonl"), "utf8"), before, "no event written");
  assert.equal(fs.readdirSync(job.jobDir, { recursive: true }).length, files, "no file added to the job");
  await assert.rejects(main(["critique", job.jobDir, "greybox", "--out", path.join(job.jobDir, "x")]), /outside the job directory/);
  await assert.rejects(main(["critique", job.jobDir, "nope", "--out", out]), /usage: foreman critique/);
});
