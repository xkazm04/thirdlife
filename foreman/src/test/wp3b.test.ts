// WP3b: the contract amendments of 2026-11-10 (JOB.md, RUNNER.md), tested against the fake adapter and fake runner.
//   1 composed manifest   2 re-plan on failure   3 milestones   4 the V5 critic with images
//   5 environment          6 runner changes       7 pack id checked at the first merge
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir, tempJob, foremanFor, readEvents, scriptWith, packFiles, fastVerifier, fixturePlan, fixtureScript, Kill, FAKE_RUNNER, VERBS } from "./helpers.js";
import { FakeBuilder, type FakeStep } from "../builder/fake.js";
import { ClaudeCliBuilder, withoutSecrets } from "../builder/claude-cli.js";
import { Verifier, REPORT_KEYS } from "../verifier.js";
import { inProcessFakeRunner, fakeRunner } from "../testing/fake-runner-core.js";
import { composeManifest, depClosure, dependants, ENTRY_SCRIPT } from "../manifest.js";
import { critic, planCheck, replanPackages, DEFAULT_RUBRIC } from "../designer.js";
import { validateEvent, type JobEvent, type PackageSpec } from "../events.js";
import { foldEvents, rebuildState } from "../joblog.js";
import { builderConduct, restsOnAClock } from "../foreman.js";
import type { RunProcessRequest, RunProcessResult, SpawnFn } from "../proc.js";
import { PKG_ROOT } from "../paths.js";

after(cleanup);

const ofType = <T extends JobEvent["type"]>(evs: JobEvent[], type: T): Extract<JobEvent, { type: T }>[] => evs.filter((e) => e.type === type) as Extract<JobEvent, { type: T }>[];
const states = (evs: JobEvent[], pkg: string): string[] => ofType(evs, "package_state").filter((e) => e.package === pkg).map((e) => `${e.state}${e.round}`);
const manifestOf = (dir: string): Record<string, unknown> => JSON.parse(fs.readFileSync(path.join(dir, "pack.json"), "utf8")) as Record<string, unknown>;
const clone = <T>(v: T): T => JSON.parse(JSON.stringify(v)) as T;

// ---------------------------------------------------------------- 1. composed manifest

test("1 manifest: pack.json is composed from packId, title, version and the registers of merged packages; no merge lists it", async () => {
  const job = tempJob("manifest");
  const seen: Record<string, unknown>[] = [];
  const { foreman } = foremanFor(job, {
    onEvent: (ev) => {
      if (ev.type === "merge") seen.push(manifestOf(path.join(job.jobDir, "pack")));
    },
  });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done");
  const evs = readEvents(job.jobDir);
  // After the FIRST merge the pack already has a complete manifest, written by the Foreman.
  assert.deepEqual(seen[0], {
    id: "game.paddle_court",
    version: "0.1.0",
    kernelApi: "0.1",
    title: "Paddle Court",
    capabilities: ["physics", "input", "rules", "ball", "ai", "camera"],
    entry: ENTRY_SCRIPT,
    assets: [],
    tests: ["tests/bot_rally.gd"],
    cameras: ["hero"],
  });
  for (const m of ofType(evs, "merge")) assert.ok(!m.files.includes("pack.json"), "the manifest is never a package's file");
  // The fake builder of `core` writes its own pack.json (one-space indent). It never reaches pack/.
  const text = fs.readFileSync(path.join(job.jobDir, "pack", "pack.json"), "utf8");
  assert.match(text, /^\{\n  "id": "game\.paddle_court"/, "two-space indent: the Foreman's text, not the builder's");
  const coreVerifying = ofType(evs, "package_state").find((e) => e.package === "core" && e.state === "verifying");
  assert.match(coreVerifying?.detail ?? "", /pack\.json \(edited by the builder; the Foreman's composed manifest was put back\)/);
});

test("1 manifest: a later package's registers appear only once it is merged; a workspace gets its own package plus its dependencies", () => {
  const plan = fixturePlan();
  const extra: PackageSpec = { ...clone(plan[2] as PackageSpec), id: "sound", deps: ["court"], scope: ["gen/sound.gd", "tests/bot_sound.gd"], registers: { capabilities: ["audio"], assets: ["gen/sound.gd"], tests: ["tests/bot_sound.gd"], cameras: ["side"] }, acceptance: [] };
  const all = [...plan, extra];
  const job = { packId: "game.x", title: "X" };
  const before = composeManifest(job, all.filter((p) => p.id !== "sound"));
  assert.deepEqual([before.assets, before.tests, before.cameras, before.capabilities.includes("audio")], [[], ["tests/bot_rally.gd"], ["hero"], false]);
  const afterMerge = composeManifest(job, all);
  assert.deepEqual([afterMerge.assets, afterMerge.tests, afterMerge.cameras], [["gen/sound.gd"], ["tests/bot_rally.gd", "tests/bot_sound.gd"], ["hero", "side"]]);
  assert.ok(afterMerge.capabilities.includes("audio"));
  assert.deepEqual([...depClosure(all, "sound")].sort(), ["core", "court", "sound"]);
  assert.deepEqual(dependants(all, "core").sort(), ["court", "paddle_ai", "sound"]);
  assert.equal(composeManifest({ packId: "game.x", title: "T".repeat(200) }, plan).title.length, 80, "the schema allows 80 characters");
  assert.equal(composeManifest(job, [{ ...(plan[1] as PackageSpec) }]).cameras, undefined, "an absent value is omitted, not an empty list");
});

test("1 manifest: no scope may hold pack.json, one root owns the entry script and a bot; the Planner prompt and schema say so", async () => {
  const plan = fixturePlan();
  assert.deepEqual(planCheck(plan, { verbs: VERBS }), []);
  const owns = clone(plan);
  (owns[1] as PackageSpec).scope.push("pack.json");
  assert.match(planCheck(owns, { verbs: VERBS }).join("\n"), /package "court": scope must not include pack\.json/);
  const glob = clone(plan);
  (glob[1] as PackageSpec).scope = ["*.json"];
  assert.match(planCheck(glob, { verbs: VERBS }).join("\n"), /package "court": scope must not include pack\.json/);
  const twoRoots = clone(plan);
  (twoRoots[1] as PackageSpec).deps = [];
  assert.match(planCheck(twoRoots, { verbs: VERBS }).join("\n"), /exactly one package may have no dependencies/);
  const noEntry = clone(plan);
  (noEntry[0] as PackageSpec).scope = ["scripts/start.gd", "tests/bot_rally.gd"];
  assert.match(planCheck(noEntry, { verbs: VERBS }).join("\n"), /root package "core" must have scripts\/main\.gd in its scope/);
  const noBot = clone(plan);
  delete (noBot[0] as PackageSpec).registers?.tests;
  assert.match(planCheck(noBot, { verbs: VERBS }).join("\n"), /root package "core" must register at least one bot/);
  const foreign = clone(plan);
  (foreign[1] as PackageSpec).registers = { tests: ["tests/bot_other.gd"] };
  assert.match(planCheck(foreign, { verbs: VERBS }).join("\n"), /package "court": registers "tests\/bot_other\.gd" but its scope does not contain that file/);
  const unknownBot = clone(plan);
  (unknownBot[2] as PackageSpec).acceptance = [{ level: "V4", verb: "bot", args: ["--test=tests/bot_nobody.gd"] }];
  assert.match(planCheck(unknownBot, { verbs: VERBS }).join("\n"), /bot acceptance runs tests\/bot_nobody\.gd, which neither this package nor a package it depends on registers/);
  // Options the real runner refuses (exit 2) are refused in the plan, before a round is spent on them.
  const badOpt = clone(plan);
  (badOpt[0] as PackageSpec).acceptance = [{ level: "V2", verb: "smoke", args: ["--speed=9"] }, { level: "V5", verb: "capture", args: ["--cam=hero"] }];
  const probs = planCheck(badOpt, { verbs: VERBS }).join("\n");
  assert.match(probs, /smoke does not take --speed \(allowed: --seed, --frames; from /);
  assert.match(probs, /acceptance verb "capture" is not allowed/);
  assert.match(planCheck(plan, { maxPackages: 2, verbs: VERBS }).join("\n"), /the plan has 3 packages; the limit for this job is 2/);

  const promptText = fs.readFileSync(path.join(PKG_ROOT, "prompts", "planner.md"), "utf8");
  assert.match(promptText, /Nobody writes `pack\.json`/);
  assert.match(promptText, /No `scope` may contain `pack\.json`/);
  const schema = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "prompts", "plan.schema.json"), "utf8")) as { properties: { packages: { items: { properties: Record<string, { properties?: object }> } } } };
  assert.deepEqual(Object.keys(schema.properties.packages.items.properties["registers"]?.properties ?? {}), ["capabilities", "assets", "tests", "cameras"]);
  // A plan_set event with a registers block reads strictly; an unknown key inside it is an error.
  const base = { v: 1, seq: 4, ts: "2026-11-10T17:00:03.000Z", job: "j", type: "plan_set", packages: plan };
  assert.doesNotThrow(() => validateEvent(base));
  const bad = clone(base);
  ((bad.packages[0] as PackageSpec).registers as Record<string, unknown>)["entry"] = "scripts/other.gd";
  assert.throws(() => validateEvent(bad), /unknown key "entry"/);
});

// ---------------------------------------------------------------- 2. re-plan on failure

const brokenMain = "extends Node\nfunc _pack_tick(frame):\n\tFAKE_SCRIPT_ERROR()\n";
/** `core` never passes; every other step is the fixture's. */
function coreAlwaysBroken(extra: FakeStep[] = []): FakeStep[] {
  return [...extra, { match: { role: "builder", package: "core" }, write: { "scripts/main.gd": brokenMain, "tests/bot_rally.gd": "extends Node\n" }, text: "Done." }];
}
/** A replacement for `core` under a new id, with the fixture's good files. */
function replacement(id: string): { spec: PackageSpec; step: FakeStep } {
  const core = clone(fixturePlan()[0] as PackageSpec);
  const write = { ...(fixtureScript().steps[0]?.write ?? {}) };
  delete write["pack.json"];
  delete write["NOTES.txt"];
  return { spec: { ...core, id, title: `Entry script, second cut (${id})` }, step: { match: { role: "builder", package: id }, write, text: "Done.", tokensIn: 100, tokensOut: 10 } };
}

test("2 re-plan: after the round limit the package goes back to the Planner once; `replan` covers it and its dependants; the job then finishes", async () => {
  const job = tempJob("replan");
  const r = replacement("core2");
  const plan = fixturePlan();
  const fresh = [r.spec, { ...clone(plan[1] as PackageSpec), deps: ["core2"] }, { ...clone(plan[2] as PackageSpec), deps: ["core2"] }];
  const builder = new FakeBuilder(scriptWith([...coreAlwaysBroken([r.step]), { match: { role: "planner" }, json: { packages: fresh }, tokensIn: 700, tokensOut: 300 }]));
  const { foreman } = foremanFor(job, { builder, roundLimit: 2, maxReplans: 3 });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "running2", "verifying2", "failed2"]);
  const re = ofType(evs, "replan");
  assert.equal(re.length, 1);
  assert.deepEqual([re[0]?.added, re[0]?.removed, [...(re[0]?.changed ?? [])].sort()], [["core2"], ["core"], ["court", "paddle_ai"]]);
  assert.match(re[0]?.reason ?? "", /failed after 2 round\(s\): core \(verify_failed\)/);
  // The order in the log: the Planner's run, then replan, then the fresh plan_set, then the queue.
  const at = evs.indexOf(re[0] as JobEvent);
  assert.deepEqual(evs.slice(at - 1, at + 5).map((e) => e.type), ["builder_run", "replan", "plan_set", "package_state", "package_state", "package_state"]);
  const plannerRun = evs[at - 1];
  assert.ok(plannerRun?.type === "builder_run" && plannerRun.package === undefined && plannerRun.mode === "generate" && plannerRun.tokensIn === 700);
  assert.deepEqual(s.order, ["core2", "court", "paddle_ai"]);
  assert.deepEqual(s.order.map((id) => s.packages[id]?.state), ["promoted", "promoted", "promoted"]);
  assert.equal(s.planRevision, 2);
  assert.equal(s.replans, 1);
  assert.deepEqual([...s.replanned].sort(), ["core", "court", "paddle_ai"]);
  // The Planner was told what failed, why, and what is kept.
  const asked = builder.calls.find((c) => c.req.meta?.role === "planner");
  assert.match(asked?.req.prompt ?? "", /This is a RE-PLAN after a failure/);
  assert.match(asked?.req.prompt ?? "", /- core: cause verify_failed/);
  assert.match(asked?.req.prompt ?? "", /"schema":"tl\.verify\/1"/, "the last failing verify report goes to the Planner");
  assert.match(asked?.req.prompt ?? "", /These packages depend on a failed one and must be returned again/);
  // The dependants restarted from nothing: they had been blocked, now they run round 1 in a fresh workspace.
  assert.deepEqual(states(evs, "court").slice(0, 3), ["queued1", "blocked1", "queued1"]);
  assert.equal(ofType(evs, "package_state").find((e) => e.package === "court" && e.state === "queued" && e.detail === "replanned")?.round, 1);
  // The log still reads strictly and rebuilds to the same state.
  const again = rebuildState(job.jobDir, { write: false });
  assert.deepEqual(again.packages, s.packages);
});

test("2 re-plan: a package that fails again after its re-plan is not sent back a second time: job_state failed", async () => {
  const job = tempJob("replan-once");
  // The Planner answers with the SAME id: the second failure of `core` is final.
  const plan = fixturePlan();
  const builder = new FakeBuilder(scriptWith([...coreAlwaysBroken(), { match: { role: "planner" }, json: { packages: plan } }]));
  const { foreman } = foremanFor(job, { builder, roundLimit: 1, maxReplans: 3 });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "failed");
  assert.match(s.jobState?.reason ?? "", /no re-plan: core already went back to the Planner once/);
  const evs = readEvents(job.jobDir);
  assert.equal(ofType(evs, "replan").length, 1);
  assert.deepEqual(ofType(evs, "replan")[0]?.changed, ["core", "court", "paddle_ai"]);
  assert.equal(builder.calls.filter((c) => c.req.meta?.role === "planner").length, 1);
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "failed1", "queued1", "running1", "verifying1", "failed1"]);
});

test("2 re-plan: at most three re-plans per job (and --max-replans fewer); then the job fails and says why", async () => {
  const plan = fixturePlan();
  const run = async (maxReplans: number): Promise<{ replans: number; reason: string; plannerCalls: number }> => {
    const job = tempJob(`replan-cap-${maxReplans}`);
    // Every re-plan invents a new id for the root, and every one of them is broken.
    let n = 1;
    const builder = new FakeBuilder({ steps: [{ match: { role: "builder" }, write: { "scripts/main.gd": brokenMain, "tests/bot_rally.gd": "extends Node\n" }, text: "Done." }] });
    const { foreman } = foremanFor(job, {
      builder,
      roundLimit: 1,
      maxReplans,
      replanner: async (input) => {
        n += 1;
        assert.equal(input.failed.length, 1);
        const id = `core${n}`;
        const root = { ...clone(plan[0] as PackageSpec), id };
        return { ok: true, value: { packages: [root, ...input.dependants.map((d) => ({ ...d, deps: [id] }))] }, calls: [] };
      },
    });
    const s = await foreman.run();
    assert.equal(s.jobState?.state, "failed");
    return { replans: ofType(readEvents(job.jobDir), "replan").length, reason: s.jobState?.reason ?? "", plannerCalls: n - 1 };
  };
  const three = await run(3);
  assert.deepEqual([three.replans, three.plannerCalls], [3, 3]);
  assert.match(three.reason, /failed: core4 \(verify_failed\).*no re-plan: the limit of 3 re-plan\(s\) for this job is used up/);
  const one = await run(1);
  assert.deepEqual([one.replans, one.plannerCalls], [1, 1]);
  assert.match(one.reason, /the limit of 1 re-plan\(s\)/);
  const none = await run(0);
  assert.equal(none.replans, 0);
});

test("2 re-plan: a refused builder or a Planner that gives no valid plan ends the job without a replan event; a kill between replan and plan_set is repaired", async () => {
  const refusedJob = tempJob("replan-refused");
  const refused = new FakeBuilder(scriptWith([{ match: { role: "builder", package: "core" }, outcome: "refused" }]));
  const s1 = await foremanFor(refusedJob, { builder: refused, maxReplans: 3 }).foreman.run();
  assert.equal(s1.jobState?.state, "failed");
  assert.match(s1.jobState?.reason ?? "", /no re-plan: core \(builder_error\) is not a failure a new plan can fix/);
  assert.equal(ofType(readEvents(refusedJob.jobDir), "replan").length, 0);

  const badJob = tempJob("replan-bad");
  const bad = new FakeBuilder(scriptWith([...coreAlwaysBroken(), { match: { role: "planner" }, json: { packages: [{ ...clone(fixturePlan()[0] as PackageSpec), id: "core2", scope: ["pack.json", "scripts/main.gd", "tests/bot_rally.gd"] }] } }]));
  const s2 = await foremanFor(badJob, { builder: bad, roundLimit: 1, maxReplans: 3 }).foreman.run();
  assert.equal(s2.jobState?.state, "failed");
  assert.match(s2.jobState?.reason ?? "", /re-plan failed: planner: answer still invalid after 2 attempts/);
  const evs2 = readEvents(badJob.jobDir);
  assert.equal(ofType(evs2, "replan").length, 0, "an invalid plan never becomes a replan event");
  assert.equal(ofType(evs2, "builder_run").filter((e) => e.package === undefined).length, 2, "both Planner attempts are in the log");

  // A kill right after `replan`: the resume asks the Planner again and writes plan_set without a second replan.
  const killJob = tempJob("replan-kill");
  const r = replacement("core2");
  const plan = fixturePlan();
  const fresh = [r.spec, { ...clone(plan[1] as PackageSpec), deps: ["core2"] }, { ...clone(plan[2] as PackageSpec), deps: ["core2"] }];
  const script = scriptWith([...coreAlwaysBroken([r.step]), { match: { role: "planner" }, json: { packages: fresh } }]);
  await assert.rejects(
    foremanFor(killJob, {
      builder: new FakeBuilder(script),
      roundLimit: 2,
      maxReplans: 3,
      afterAppend: (ev) => {
        if (ev.type === "replan") throw new Kill(ev.seq);
      },
    }).foreman.run(),
    Kill,
  );
  assert.ok(rebuildState(killJob.jobDir, { write: false }).pendingReplan, "the log ends in a replan without its plan_set");
  const s3 = await foremanFor(killJob, { builder: new FakeBuilder(script), roundLimit: 2, maxReplans: 3 }).foreman.run();
  assert.equal(s3.jobState?.state, "done", JSON.stringify(s3.jobState));
  assert.equal(ofType(readEvents(killJob.jobDir), "replan").length, 1);
  assert.equal(s3.replans, 1);
  assert.equal(s3.pendingReplan, undefined);
});

test("2 re-plan: replanPackages validates the answer together with the kept packages", async () => {
  const plan = fixturePlan();
  const kept = [plan[0] as PackageSpec];
  const input = { sentence: "s", packId: "game.x", title: "X", brief: { rules: "r", arena: "a", ai: "i", controls: "c", mood: "m" }, packContract: "(contract)", kept, failed: [{ spec: plan[1] as PackageSpec, cause: "verify_failed", detail: "smoke failed" }], dependants: [] };
  const good = new FakeBuilder({ steps: [{ match: { role: "planner" }, json: { packages: [{ ...clone(plan[1] as PackageSpec), id: "court2" }] } }] });
  const ok = await replanPackages(good, input, { maxPackages: 3, verbs: VERBS });
  assert.ok(ok.ok && ok.value.packages.map((p) => p.id).join() === "court2");
  // Returning a kept package, or stepping on its files, is rejected with the reason and asked again once.
  const clash = new FakeBuilder({ steps: [{ match: { role: "planner" }, json: { packages: [plan[0], { ...clone(plan[1] as PackageSpec), id: "court2", scope: ["scripts/main.gd"] }] } }] });
  const no = await replanPackages(clash, input, { verbs: VERBS });
  assert.ok(!no.ok);
  assert.match(no.ok ? "" : no.reason, /package id "core" belongs to a kept package/);
  assert.equal(clash.calls.length, 2);
  assert.match(clash.calls[1]?.req.prompt ?? "", /Your previous answer was rejected/);
  const tooMany = new FakeBuilder({ steps: [{ match: { role: "planner" }, json: { packages: [{ ...clone(plan[1] as PackageSpec), id: "court2" }, { ...clone(plan[2] as PackageSpec), id: "ai2" }] } }] });
  const over = await replanPackages(tooMany, input, { maxPackages: 2, verbs: VERBS });
  assert.match(over.ok ? "" : over.reason, /the limit for this job is 2/);
});

// ---------------------------------------------------------------- 3. milestones

const criticStep: FakeStep = { match: { role: "critic" }, json: { ok: true, scores: { silhouette: 0.9, readability: 0.8, style_consistency: 0.7, shows_play: 0.65 }, notes: ["the court and both paddles are clear"] }, tokensIn: 900, tokensOut: 80 };

test("3 milestones: when the last package of a milestone merges, capture per declared camera with --test=<first bot>, then the critic, then `milestone` with the capture paths", async () => {
  const job = tempJob("milestone");
  const builder = new FakeBuilder(scriptWith([criticStep]));
  const { foreman } = foremanFor(job, { builder, critic: true });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done");
  const evs = readEvents(job.jobDir);
  const ms = ofType(evs, "milestone");
  assert.deepEqual(ms.map((m) => m.milestone), ["blockout", "greybox"]);
  assert.deepEqual(ms[0]?.captures, ["captures/blockout-hero-f120.png", "captures/blockout-hero-f480.png"]);
  for (const m of ms) for (const c of m.captures) assert.ok(fs.statSync(path.join(job.jobDir, c)).size > 0, c);
  assert.match(ms[0]?.summary ?? "", /all 2 package\(s\) of this milestone are merged and verified: core, court; 2 capture\(s\); critic \(V5\) ok: silhouette 0\.9/);
  // blockout = core + court: the milestone comes right after court is promoted, in this order.
  const courtPromoted = evs.findIndex((e) => e.type === "package_state" && e.package === "court" && e.state === "promoted");
  assert.deepEqual(evs.slice(courtPromoted + 1, courtPromoted + 5).map((e) => (e.type === "verify" ? `verify:${e.verb}:${e.level}:${e.after}:${e.package ?? "pack"}` : e.type)), [
    "verify:capture:V5:court:pack",
    "verify:capture:V5:court:pack",
    "builder_run",
    "milestone",
  ]);
  const criticRun = evs[courtPromoted + 3];
  assert.ok(criticRun?.type === "builder_run" && criticRun.package === undefined && criticRun.mode === "generate" && criticRun.tokensIn === 900);
  // The runner was called with the camera, the frame, the first bot of the manifest and an absolute --out.
  const verdict = JSON.parse(fs.readFileSync(path.join(job.jobDir, (evs[courtPromoted + 1] as Extract<JobEvent, { type: "verify" }>).report.replace(/\.json$/, ".verdict.json")), "utf8")) as { argv: string[] };
  assert.ok(verdict.argv.includes("--cam=hero") && verdict.argv.includes("--frame=120") && verdict.argv.includes("--test=tests/bot_rally.gd") && verdict.argv.includes("--res=1280x720"));
  assert.ok(verdict.argv.includes("--headless"), "the supervisor is headless for capture too");
  assert.ok(path.isAbsolute((verdict.argv.find((a) => a.startsWith("--out=")) ?? "").slice(6)));
  // The critic was GIVEN the images, in generate mode.
  const call = builder.calls.find((c) => c.req.meta?.role === "critic");
  assert.equal(call?.req.mode, "generate");
  assert.deepEqual(call?.req.images?.map((p) => path.basename(p)), ["blockout-hero-f120.png", "blockout-hero-f480.png"]);
  assert.match(call?.req.prompt ?? "", /Mood asked for: Flat-shaded blocks/);
  // The critique itself is a file the summary points at.
  const critique = fs.readdirSync(path.join(job.jobDir, "reports")).find((f) => f.startsWith("critic-blockout-"));
  const body = JSON.parse(fs.readFileSync(path.join(job.jobDir, "reports", critique ?? ""), "utf8")) as { ok: boolean; scores: Record<string, number>; captures: string[] };
  assert.deepEqual([body.ok, body.scores["shows_play"], body.captures.length], [true, 0.65, 2]);
  assert.deepEqual(s.milestones.map((m) => m.captures.length), [2, 2]);
  // The fake runner renders the same pixel every time, so the second milestone shows nothing new, and says so.
  assert.doesNotMatch(ms[0]?.summary ?? "", /NO VISIBLE CHANGE/);
  // WP3c: the fake runner's picture now depends on the pack's files, so a milestone that added files is a visible change.
  assert.doesNotMatch(ms[1]?.summary ?? "", /NO VISIBLE CHANGE/);
});

test("3 milestones: a failed capture is tried once more; two failures are recorded and the milestone is still written; no camera means no capture", async () => {
  // First capture call fails, its retry passes.
  const flaky = tempJob("milestone-flaky");
  const v1 = fastVerifier(flaky.engineDir, { FAKE_RUNNER_CAPTURE_FAILS: "1" });
  const s1 = await foremanFor(flaky, { builder: new FakeBuilder(scriptWith([criticStep])), critic: true, verifier: v1, captureFrames: [120] }).foreman.run();
  assert.equal(s1.jobState?.state, "done");
  const evs1 = readEvents(flaky.jobDir);
  const caps1 = ofType(evs1, "verify").filter((e) => e.verb === "capture" && e.after === "court");
  assert.deepEqual(caps1.map((e) => [e.ok, e.exitCode]), [[false, 1], [true, 0]]);
  const m1 = ofType(evs1, "milestone")[0];
  assert.deepEqual(m1?.captures, ["captures/blockout-hero-f120.png"]);
  assert.match(m1?.summary ?? "", /capture hero frame 120, attempt 1 of 2, failed/);

  // Every capture fails: no image, no critic call, the milestone says so.
  const dead = tempJob("milestone-dead");
  const builder = new FakeBuilder(scriptWith([{ match: { role: "builder", package: "court" }, write: { ...(fixtureScript().steps[1]?.write ?? {}), "data/court.json": '{"note": "FAKE_CAPTURE_FAIL"}\n' }, text: "Done." }, criticStep]));
  const s2 = await foremanFor(dead, { builder, critic: true, captureFrames: [120] }).foreman.run();
  assert.equal(s2.jobState?.state, "done", "a capture failure does not fail the job in Phase 0");
  const evs2 = readEvents(dead.jobDir);
  const m2 = ofType(evs2, "milestone")[0];
  assert.deepEqual(m2?.captures, []);
  assert.match(m2?.summary ?? "", /0 capture\(s\); critic not run; capture hero frame 120, attempt 1 of 2, failed.*attempt 2 of 2, failed/);
  assert.equal(ofType(evs2, "verify").filter((e) => e.verb === "capture" && e.after === "court").length, 2);
  assert.equal(builder.calls.filter((c) => c.req.meta?.role === "critic" && (c.req.images ?? []).some((i) => i.includes("blockout"))).length, 0);

  // A pack without a camera: nothing to capture, and the summary says why.
  const blind = tempJob("milestone-blind");
  const lines = fs.readFileSync(path.join(blind.jobDir, "job.jsonl"), "utf8").trim().split("\n").map((l) => JSON.parse(l) as JobEvent);
  const planEv = lines[3] as Extract<JobEvent, { type: "plan_set" }>;
  delete (planEv.packages[0] as PackageSpec).registers?.cameras;
  fs.writeFileSync(path.join(blind.jobDir, "job.jsonl"), lines.map((l) => JSON.stringify(l) + "\n").join(""));
  const s3 = await foremanFor(blind, { critic: true }).foreman.run();
  assert.equal(s3.jobState?.state, "done");
  assert.match(s3.milestones[0]?.summary ?? "", /0 capture\(s\); critic not run; the pack declares no camera/);
});

test("3 milestones: a kill between the last merge and the `milestone` event is caught up on resume, once", async () => {
  const job = tempJob("milestone-kill");
  const script = scriptWith([criticStep]);
  await assert.rejects(
    foremanFor(job, {
      builder: new FakeBuilder(script),
      critic: true,
      afterAppend: (ev) => {
        if (ev.type === "package_state" && ev.package === "court" && ev.state === "promoted") throw new Kill(ev.seq);
      },
    }).foreman.run(),
    Kill,
  );
  assert.equal(ofType(readEvents(job.jobDir), "milestone").length, 0);
  const s = await foremanFor(job, { builder: new FakeBuilder(script), critic: true }).foreman.run();
  assert.equal(s.jobState?.state, "done");
  const evs = readEvents(job.jobDir);
  assert.deepEqual(ofType(evs, "milestone").map((m) => m.milestone), ["blockout", "greybox"]);
  assert.equal(ofType(evs, "milestone")[0]?.captures.length, 2);
  // And a third run adds nothing.
  const n = evs.length;
  await foremanFor(job, { builder: new FakeBuilder(script), critic: true }).foreman.run();
  assert.equal(readEvents(job.jobDir).length, n);
});

// ---------------------------------------------------------------- 4. the V5 critic for real

const PNG = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=", "base64");

function recordedSpawn(answer: (req: RunProcessRequest) => string): { calls: RunProcessRequest[]; spawn: SpawnFn } {
  const calls: RunProcessRequest[] = [];
  const spawn: SpawnFn = async (req): Promise<RunProcessResult> => {
    calls.push(req);
    const base = { exitCode: 0, stderr: "", timedOut: false, outputCapped: false, durationMs: 5 };
    if (req.args[0] === "--version") return { ...base, stdout: "2.1.322 (Claude Code)\n" };
    if (req.args[0] === "auth") return { ...base, stdout: JSON.stringify({ loggedIn: true, authMethod: "claude.ai", subscriptionType: "max" }) };
    return { ...base, stdout: answer(req) };
  };
  return { calls, spawn };
}
const envelope = (structured: unknown): string =>
  [
    { type: "system", subtype: "init", tools: ["StructuredOutput"], model: "claude-sonnet-x", permissionMode: "default", apiKeySource: "none" },
    { type: "result", subtype: "success", is_error: false, result: JSON.stringify(structured), structured_output: structured, stop_reason: "tool_use", usage: { input_tokens: 2, cache_creation_input_tokens: 4000, cache_read_input_tokens: 600, output_tokens: 90 } },
  ]
    .map((e) => JSON.stringify(e))
    .join("\n") + "\n";

test("4 critic: a generate-mode call that is given the capture images as base64 blocks in a stream-json user message, and returns schema-checked scores and notes", async () => {
  const dir = tempDir("critic");
  const a = path.join(dir, "greybox-hero-f120.png");
  const b = path.join(dir, "greybox-hero-f480.png");
  fs.writeFileSync(a, PNG);
  fs.writeFileSync(b, PNG);
  const answer = { ok: true, scores: { silhouette: 0.8, readability: 0.7, style_consistency: 0.5, shows_play: 0.9 }, notes: ["three marbles on a wooden ramp", "the ice sheet is hard to tell from the floor"] };
  const rec = recordedSpawn(() => envelope(answer));
  const builder = new ClaudeCliBuilder({ bin: process.execPath, env: { PATH: "x", SOME_API_KEY: "never-read" }, spawn: rec.spawn });
  const res = await critic(builder, [a, b], DEFAULT_RUBRIC, { model: "sonnet", context: "Mood asked for: toy workshop" });
  assert.ok(res.ok, res.ok ? "" : res.reason);
  // ok is recomputed from the scores: style_consistency 0.5 is under the 0.6 threshold.
  assert.equal(res.value.ok, false);
  assert.deepEqual(res.value.scores, answer.scores);
  assert.match(res.value.notes.join("|"), /critic said ok=true; scores against threshold 0\.6 give ok=false/);

  const call = rec.calls.find((c) => c.args.includes("-p"));
  assert.ok(call);
  const args = call.args;
  assert.equal(args[args.indexOf("--input-format") + 1], "stream-json", "images travel as a stream-json user message");
  assert.equal(args.filter((x) => x === "--input-format").length, 1);
  assert.equal(args[args.indexOf("--tools") + 1], "", "generate mode: no tools");
  assert.ok(args.includes("--json-schema"));
  assert.ok(!args.some((x) => x.includes("greybox-hero")), "no image path or data in argv");
  const lines = (call.stdin ?? "").trim().split("\n");
  assert.equal(lines.length, 1, "one user message, one line");
  const msg = JSON.parse(lines[0] ?? "{}") as { type: string; message: { role: string; content: { type: string; text?: string; source?: { type: string; media_type: string; data: string } }[] } };
  assert.deepEqual([msg.type, msg.message.role, msg.message.content.map((c) => c.type)], ["user", "user", ["image", "image", "text"]]);
  assert.deepEqual(msg.message.content[0]?.source, { type: "base64", media_type: "image/png", data: PNG.toString("base64") });
  const text = msg.message.content[2]?.text ?? "";
  assert.match(text, /image 1 of 2, attached to this message: greybox-hero-f120\.png/);
  for (const r of DEFAULT_RUBRIC) assert.ok(text.includes(`- ${r.id}: `), r.id);
  assert.deepEqual(DEFAULT_RUBRIC.map((r) => r.id), ["silhouette", "readability", "style_consistency", "shows_play"]);
  assert.match(text, /Mood asked for: toy workshop/);
  // The capability matrix records how the image is handed over.
  const caps = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "data", "capabilities.json"), "utf8")) as { adapters: { "claude-cli": { images: { status: string; how: string }; flags: { imageInput: { add: string[] } } }[] } };
  assert.equal(caps.adapters["claude-cli"][0]?.images.status, "observed");
  assert.deepEqual(caps.adapters["claude-cli"][0]?.flags.imageInput.add, ["--input-format", "stream-json"]);
});

test("4 critic: an answer that misses a rubric item or is not the schema is rejected and asked again once; a missing image is an error, not a guess", async () => {
  const dir = tempDir("critic-bad");
  const a = path.join(dir, "a.png");
  fs.writeFileSync(a, PNG);
  let n = 0;
  const rec = recordedSpawn(() => {
    n += 1;
    return envelope(n === 1 ? { ok: true, scores: { silhouette: 0.8 }, notes: [] } : { ok: true, scores: { silhouette: 0.8, readability: 0.7, style_consistency: 0.7, shows_play: 0.9 }, notes: ["fine"] });
  });
  const builder = new ClaudeCliBuilder({ bin: process.execPath, env: { PATH: "x" }, spawn: rec.spawn });
  const res = await critic(builder, [a]);
  assert.ok(res.ok && res.value.ok);
  assert.equal(res.calls.length, 2);
  assert.match(res.calls[0]?.problems.join("|") ?? "", /scores has no entry for rubric item "readability"/);
  const second = JSON.parse(((rec.calls.filter((c) => c.args.includes("-p"))[1]?.stdin ?? "").trim().split("\n")[0]) ?? "{}") as { message: { content: { type: string; text?: string }[] } };
  assert.deepEqual(second.message.content.map((c) => c.type), ["image", "text"], "the retry carries the image again");
  assert.match(second.message.content[1]?.text ?? "", /Your previous answer was rejected/);

  const missing = await critic(builder, [path.join(dir, "nope.png")]);
  assert.ok(!missing.ok);
  assert.match(missing.ok ? "" : missing.reason, /image not found/);
  const none = await critic(new FakeBuilder({ steps: [{ match: { role: "critic" }, json: { ok: true, scores: { silhouette: 1, readability: 1, style_consistency: 1, shows_play: 1 }, notes: [] } }] }), []);
  assert.ok(none.ok && none.value.ok === false, "no captures can never be ok");
});

// ---------------------------------------------------------------- 5. environment

test("5 environment: edit and readonly-scan runs do not inherit names containing KEY, TOKEN, SECRET or PASSWORD, apart from the adapter's own auth; generate runs are untouched", async () => {
  const env: NodeJS.ProcessEnv = {
    PATH: "x",
    SystemRoot: "C:\\Windows",
    ANTHROPIC_KEY_LANE_ALPHA: "v1",
    anthropic_key_lane_beta: "v2",
    GITHUB_TOKEN: "v3",
    DB_PASSWORD: "v4",
    MY_SECRET: "v5",
    OPENAI_API_KEY: "v6",
    Passwordless: "v7",
    CLAUDE_CODE_OAUTH_TOKEN: "auth1",
    HARMLESS: "yes",
    TL_GODOT: "godot",
  };
  const cut = withoutSecrets(env);
  assert.deepEqual(Object.keys(cut.env).sort(), ["CLAUDE_CODE_OAUTH_TOKEN", "HARMLESS", "PATH", "SystemRoot", "TL_GODOT"]);
  assert.equal(cut.removed, 7);

  const ok = [{ type: "system", subtype: "init", tools: [], model: "m", permissionMode: "acceptEdits", apiKeySource: "none" }, { type: "result", subtype: "success", is_error: false, result: "done", stop_reason: "end_turn", usage: { input_tokens: 1, output_tokens: 1 } }].map((e) => JSON.stringify(e)).join("\n") + "\n";
  const rec = recordedSpawn(() => ok);
  const b = new ClaudeCliBuilder({ bin: process.execPath, env, spawn: rec.spawn, allowEdit: true });
  const ws = tempDir("env-ws");
  const names = (mode: string): string[] => Object.keys(rec.calls.filter((c) => c.args.includes("-p")).find((c) => (mode === "edit" ? c.args.includes("acceptEdits") : mode === "readonly-scan" ? c.args.includes("Read,Glob,Grep") : c.args[c.args.indexOf("--tools") + 1] === ""))?.env ?? {}).sort();
  assert.equal((await b.run({ prompt: "p", mode: "edit", cwd: ws, timeoutMs: 5000 })).outcome, "ok");
  assert.equal((await b.run({ prompt: "p", mode: "readonly-scan", cwd: ws, timeoutMs: 5000 })).outcome, "ok");
  assert.equal((await b.run({ prompt: "p", mode: "generate", cwd: "", timeoutMs: 5000 })).outcome, "ok");
  const safe = ["CLAUDE_CODE_OAUTH_TOKEN", "HARMLESS", "PATH", "SystemRoot", "TL_GODOT"];
  assert.deepEqual(names("edit"), safe);
  assert.deepEqual(names("readonly-scan"), safe);
  assert.equal(names("generate").length, Object.keys(env).length, "a generate run has no tools to read its environment with and inherits it");
  // The probe says that it happens, with a count and no names or values.
  const probe = await b.probe();
  const note = probe.notes.find((n) => n.includes("key-like")) ?? "";
  assert.match(note, /do not inherit key-like variables.*: 7 hidden in this environment/);
  assert.ok(!/LANE|v[1-7]\b/.test(JSON.stringify(probe)), "neither a hidden name nor a value leaks into the probe");

  // An API-key login keeps working: the key the adapter itself needs is the exception.
  const keyed = new ClaudeCliBuilder({ bin: process.execPath, env: { PATH: "x", ANTHROPIC_API_KEY: "k", OTHER_API_KEY: "o" }, spawn: rec.spawn, allowEdit: true });
  assert.deepEqual(Object.keys(keyed.childEnv("edit").env).sort(), ["ANTHROPIC_API_KEY", "PATH"]);

  // The runner (pack code runs inside it) gets no key-like variable at all.
  let seen: NodeJS.ProcessEnv | undefined;
  const inner = inProcessFakeRunner();
  const v = new Verifier({ godot: FAKE_RUNNER, engineDir: tempDir("env-engine"), env, spawn: async (req) => ((seen = req.env), inner(req)) });
  await v.run({ verb: "lint", packDir: ws, reportFile: path.join(tempDir("env-rep"), "lint.json") });
  assert.deepEqual(Object.keys(seen ?? {}).sort(), ["HARMLESS", "PATH", "SystemRoot", "TL_GODOT"]);
});

test("5 environment: the reference directory travels as one --add-dir per directory, and the builder's conduct is read from the envelope", async () => {
  const ok = [
    { type: "system", subtype: "init", tools: ["Bash", "Read"], model: "m", permissionMode: "acceptEdits", apiKeySource: "none" },
    { type: "assistant", message: { content: [{ type: "tool_use", name: "Read", input: { file_path: "ref/API.md" } }, { type: "tool_use", name: "Bash", input: { command: "godot --headless -- lint --pack=ws" } }] } },
    { type: "assistant", message: { content: [{ type: "tool_use", name: "Bash", input: { command: "curl http://example.com" } }] } },
    { type: "result", subtype: "success", is_error: false, result: "done", stop_reason: "end_turn", usage: { input_tokens: 1, output_tokens: 1 }, permission_denials: [{ tool_name: "Bash", tool_input: { command: "curl http://example.com" } }] },
  ]
    .map((e) => JSON.stringify(e))
    .join("\n") + "\n";
  const rec = recordedSpawn(() => ok);
  const b = new ClaudeCliBuilder({ bin: process.execPath, env: { PATH: "x" }, spawn: rec.spawn, allowEdit: true });
  const ws = tempDir("adddir-ws");
  const ref = tempDir("adddir-ref");
  const res = await b.run({ prompt: "p", mode: "edit", cwd: ws, timeoutMs: 5000, addDirs: [ref], model: "sonnet" });
  const args = rec.calls.find((c) => c.args.includes("-p"))?.args ?? [];
  assert.equal(args[args.indexOf("--add-dir") + 1], path.resolve(ref));
  assert.equal(args[args.indexOf("--add-dir") + 2], "--model", "the flag takes exactly one value here, so nothing after it is swallowed");
  assert.deepEqual(builderConduct(res.raw), { tools: { Read: 1, Bash: 2 }, bash: ["godot --headless -- lint --pack=ws", "curl http://example.com"], denials: ["Bash: curl http://example.com"], notes: [] });
});

test("5 reference: API.md and the example packs are copied into <job>/ref once, named in the prompt, and restored when a builder writes there", async () => {
  const job = tempJob("ref");
  const engine = tempDir("ref-engine");
  fs.mkdirSync(path.join(engine, "kernel", "examples", "pack_min", "scripts"), { recursive: true });
  fs.writeFileSync(path.join(engine, "kernel", "API.md"), "# kernel API\n");
  fs.writeFileSync(path.join(engine, "kernel", "examples", "pack_min", "scripts", "main.gd"), "extends Node\n");
  fs.mkdirSync(path.join(engine, "kernel", "data"), { recursive: true });
  fs.writeFileSync(path.join(engine, "kernel", "data", "materials.json"), "{}\n");
  const refFile = path.join(job.jobDir, "ref", "API.md");
  // The fake builder of `court` vandalises the reference copy (an absolute path outside its workspace).
  const vandal = new FakeBuilder(scriptWith());
  const realRun = vandal.run.bind(vandal);
  vandal.run = async (req) => {
    if (req.meta?.package === "court") fs.writeFileSync(refFile, "overwritten by a builder\n");
    return realRun(req);
  };
  const { foreman } = foremanFor(job, { builder: vandal, reference: { apiDoc: path.join(engine, "kernel", "API.md"), examples: [path.join(engine, "kernel", "examples", "pack_min")], data: [path.join(engine, "kernel", "data", "materials.json")] } });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done");
  assert.equal(fs.readFileSync(refFile, "utf8"), "# kernel API\n", "the copy was restored");
  assert.equal(fs.readFileSync(path.join(engine, "kernel", "API.md"), "utf8"), "# kernel API\n", "the engine's own file was never in reach");
  const call = vandal.calls.find((c) => c.req.meta?.package === "core");
  assert.deepEqual(call?.req.addDirs, [path.join(job.jobDir, "ref")]);
  assert.match(call?.req.prompt ?? "", /Kernel API \(everything a pack script may call[^\n]*\/ref\/API\.md/);
  assert.match(call?.req.prompt ?? "", /Example pack that passes every verifier level: [^\n]*\/ref\/examples\/pack_min\//);
  assert.match(call?.req.prompt ?? "", /law tables[^\n]*\(materials\.json\): [^\n]*\/ref\/data\//);
  assert.ok(fs.existsSync(path.join(job.jobDir, "ref", "data", "materials.json")));
  assert.match(call?.req.prompt ?? "", /`pack\.json` is written by the Foreman, not by you/);
  assert.match(call?.req.prompt ?? "", /"entry": "scripts\/main\.gd"/);
  const run = ofType(readEvents(job.jobDir), "builder_run").find((e) => e.package === "court");
  const t = JSON.parse(fs.readFileSync(path.join(job.jobDir, run?.transcript ?? ""), "utf8")) as { conduct: { notes: string[] } };
  assert.deepEqual(t.conduct.notes, ["the builder changed files under ref/ (outside its workspace); the reference copy was restored"]);
});

// ---------------------------------------------------------------- 6. runner changes

function goodPack(extra: Record<string, string> = {}): { pack: string; reports: string; engine: string } {
  const root = tempDir("pack");
  const pack = path.join(root, "pack");
  const files: Record<string, string> = {
    "pack.json": JSON.stringify({ id: "game.t", version: "0.1.0", kernelApi: "0.1", title: "T", capabilities: ["physics"], entry: "scripts/main.gd", assets: [], tests: ["tests/bot.gd"], cameras: ["hero"] }),
    "scripts/main.gd": "extends Node\n",
    "tests/bot.gd": "extends Node\n",
    ...extra,
  };
  for (const [rel, text] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(pack, rel)), { recursive: true });
    fs.writeFileSync(path.join(pack, rel), text);
  }
  return { pack, reports: path.join(root, "reports"), engine: path.join(root, "engine") };
}

test("6 runner: a bot that does not finish is exit 1 `failed` (contract) or exit 3 `watchdog` (the snapshot engine); the Verifier accepts both as a clean 'not passed'", async () => {
  const p = goodPack({ "tests/bot.gd": "extends Node\n# FAKE_BOT_NEVER_DONE\n" });
  const amended = await fastVerifier(p.engine).run({ verb: "bot", args: ["--test=tests/bot.gd", "--frames=300"], packDir: p.pack, reportFile: path.join(p.reports, "a.json") });
  assert.deepEqual([amended.ok, amended.exitCode, amended.report?.outcome, amended.flags], [false, 1, "failed", []]);
  assert.equal(amended.report?.checks.find((c) => c.id === "bot.completed")?.ok, false);
  assert.deepEqual((amended.report?.["bot"] as { done: boolean; frames: number }).done, false);
  const snapshot = await fastVerifier(p.engine, { FAKE_RUNNER_BOT_TIMEOUT: "watchdog" }).run({ verb: "bot", args: ["--test=tests/bot.gd", "--frames=300"], packDir: p.pack, reportFile: path.join(p.reports, "b.json") });
  assert.deepEqual([snapshot.ok, snapshot.exitCode, snapshot.report?.outcome, snapshot.flags], [false, 3, "watchdog", []]);
  assert.equal(snapshot.report?.checks.find((c) => c.id === "bot.completed")?.ok, false);
  assert.match(snapshot.summary, /bot watchdog: failed checks \[smoke\.watchdog, bot\.completed, bot\.ok\]/);
});

test("6 runner: unknown checks[].id values and unknown metrics keys are accepted; top-level keys are strict", async () => {
  const p = goodPack();
  const tamper = (edit: (r: Record<string, unknown>) => void): SpawnFn => {
    const inner = inProcessFakeRunner();
    return async (req) => {
      const res = await inner(req);
      const lines = res.stdout.trimEnd().split("\n");
      const report = JSON.parse(lines[lines.length - 1] ?? "{}") as Record<string, unknown>;
      edit(report);
      lines[lines.length - 1] = JSON.stringify(report);
      const file = (req.args.find((a) => a.startsWith("--report=")) ?? "").slice(9);
      fs.writeFileSync(file, JSON.stringify(report) + "\n");
      return { ...res, stdout: lines.join("\n") + "\n" };
    };
  };
  const additive = new Verifier({
    godot: FAKE_RUNNER,
    engineDir: p.engine,
    spawn: tamper((r) => {
      (r["checks"] as object[]).push({ id: "smoke.something_new_in_0_2", ok: true, detail: "added later" });
      (r["metrics"] as Record<string, unknown>)["gpu_ms_p99"] = 1.5;
    }),
  });
  const ok = await additive.run({ verb: "smoke", packDir: p.pack, reportFile: path.join(p.reports, "ok.json") });
  assert.deepEqual([ok.ok, ok.flags], [true, []]);
  // What the real runner already adds is there in the fake too.
  assert.ok(ok.report?.checks.some((c) => c.id === "smoke.no_engine_errors"));
  assert.equal(typeof (ok.report?.["metrics"] as Record<string, unknown>)["tick_ms_max"], "number");
  const strict = new Verifier({ godot: FAKE_RUNNER, engineDir: p.engine, spawn: tamper((r) => void (r["warnings"] = [])) });
  const bad = await strict.run({ verb: "smoke", packDir: p.pack, reportFile: path.join(p.reports, "bad.json") });
  assert.deepEqual([bad.ok, bad.flags], [false, ["report_invalid"]]);
  assert.match(bad.summary, /unknown top-level key "warnings"/);
  assert.ok(REPORT_KEYS.includes("composability") && REPORT_KEYS.includes("bot") && REPORT_KEYS.includes("capture"));
});

test("6 runner: the fake behaves as the real runner was observed to: not_run for a bad manifest or option, --test and --cam checked, capture needs an absolute --out", () => {
  const p = goodPack();
  const run = (verb: string, args: string[], pack = p.pack): { exit: number; report: { outcome: string; checks: { id: string; ok: boolean }[]; errors: { kind: string; file?: string; message: string }[]; capture?: { width: number } } } => {
    const out = fakeRunner(["--headless", "--path", p.engine, "res://kernel/host/host.tscn", "--", verb, `--pack=${pack}`, ...args, `--report=${path.join(p.reports, `${verb}.json`)}`]);
    const lines = out.stdout.trimEnd().split("\n");
    return { exit: out.exitCode, report: JSON.parse(lines[lines.length - 1] ?? "{}") as never };
  };
  const badManifest = goodPack({ "pack.json": JSON.stringify({ id: "game.t", version: "0.1.0", kernelApi: "0.1", title: "T", capabilities: [], entry: "scripts/main.gd", assets: [], tests: ["tests/bot.gd"], author: "me" }) });
  const lint = run("lint", [], badManifest.pack);
  assert.deepEqual([lint.exit, lint.report.outcome, lint.report.errors[0]?.kind, lint.report.errors[0]?.file], [1, "failed", "schema", "pack.json"]);
  assert.match(lint.report.errors[0]?.message ?? "", /unknown key 'author'/);
  const smoke = run("smoke", [], badManifest.pack);
  assert.deepEqual([smoke.exit, smoke.report.outcome, smoke.report.checks.length, smoke.report.errors.map((e) => e.kind)], [2, "not_run", 0, ["schema", "load"]]);
  const opt = run("smoke", ["--speed=9"]);
  assert.deepEqual([opt.exit, opt.report.errors[0]?.message], [2, "unknown option --speed for 'smoke' (allowed: pack, report, seed, frames)"]);
  const noTest = run("bot", ["--test=tests/nope.gd"]);
  assert.deepEqual([noTest.exit, noTest.report.checks.find((c) => c.id === "smoke.loads")?.ok], [1, false]);
  assert.match(noTest.report.errors[0]?.message ?? "", /--test must be one of the manifest's tests: tests\/bot\.gd/);
  assert.equal(run("bot", []).exit, 0, "without --test the first test of the manifest runs");
  assert.equal(run("capture", ["--cam=hero"]).exit, 2, "--out is required");
  assert.equal(run("capture", ["--cam=hero", "--out=relative.png"]).exit, 2, "and must be absolute");
  const cam = run("capture", ["--cam=nope", `--out=${path.join(p.reports, "x.png")}`]);
  assert.equal(cam.exit, 1);
  assert.match(cam.report.errors[0]?.message ?? "", /no camera view 'nope'; the pack registered: hero/);
  const shot = run("capture", ["--cam=hero", `--out=${path.join(p.reports, "y.png")}`, "--res=1280x720", "--test=tests/bot.gd", "--frame=300"]);
  assert.deepEqual([shot.exit, shot.report.capture?.width, shot.report.checks.map((c) => c.id)], [0, 1280, ["smoke.loads", "smoke.no_script_errors", "smoke.no_engine_errors", "smoke.watchdog", "capture.written"]]);
  const fence = goodPack({ "scripts/main.gd": "extends Node\nfunc f():\n\treturn randf_range(0.0, 1.0) # randi( in a comment is ignored\n" });
  const fenced = run("lint", [], fence.pack);
  assert.deepEqual(fenced.report.errors.map((e) => [e.kind, e.file, e.message]), [["fence", "scripts/main.gd", "'randf_range(' is outside the fence"]]);
});

test("6 events: merge.removed[], verify.after and billing.mode none are read and written; older logs without them still read", async () => {
  const job = tempJob("events");
  // A fourth package that deletes a file court merged earlier (the plan is written straight into the log: the
  // Planner's own check would refuse two packages claiming one file).
  const lines = fs.readFileSync(path.join(job.jobDir, "job.jsonl"), "utf8").trim().split("\n").map((l) => JSON.parse(l) as JobEvent);
  const planEv = lines[3] as Extract<JobEvent, { type: "plan_set" }>;
  planEv.packages.push({ id: "tidy", title: "Removes the court script", milestone: "greybox", deps: ["court", "paddle_ai"], scope: ["scripts/court.gd", "data/tidy.json"], contract: "deletes scripts/court.gd", acceptance: [{ level: "V1", verb: "lint", args: [] }] });
  fs.writeFileSync(path.join(job.jobDir, "job.jsonl"), lines.map((l) => JSON.stringify(l) + "\n").join(""));
  const builder = new FakeBuilder(scriptWith([{ match: { role: "builder", package: "tidy" }, remove: ["scripts/court.gd"], write: { "data/tidy.json": "{}\n" }, text: "Removed it." }]));
  const s = await foremanFor(job, { builder }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  const merge = ofType(evs, "merge").find((e) => e.package === "tidy");
  assert.deepEqual([merge?.files, merge?.removed], [["data/tidy.json"], ["scripts/court.gd"]]);
  assert.ok(!fs.existsSync(path.join(job.jobDir, "pack", "scripts", "court.gd")), "the deletion reached pack/");
  assert.ok(!("scripts/court.gd" in packFiles(path.join(job.engineDir, "packs", "game.paddle_court"))), "and the promoted pack");
  assert.deepEqual(s.packages["court"]?.mergedFiles, ["data/court.json", "scripts/court.gd"], "court's own record is its own");
  assert.equal(ofType(evs, "merge").find((e) => e.package === "court")?.removed, undefined, "absent means omitted");
  // A resume does not mistake the deleted file for a lost one.
  const again = await foremanFor(job, { builder }).foreman.run();
  assert.equal(again.jobState?.state, "done");

  // Whole-pack checks say which merge they gate; package checks and the final gate do not.
  const gate = ofType(evs, "verify").filter((e) => e.package === undefined && e.after !== undefined);
  assert.deepEqual([...new Set(gate.map((e) => e.after))], ["core", "court", "paddle_ai", "tidy"]);
  assert.deepEqual(gate.filter((e) => e.after === "core").map((e) => e.verb), ["lint", "smoke"]);
  assert.ok(ofType(evs, "verify").filter((e) => e.package !== undefined).every((e) => e.after === undefined));
  const final = ofType(evs, "verify").filter((e) => e.package === undefined && e.after === undefined);
  assert.deepEqual(final.map((e) => e.verb), ["lint", "smoke", "invariants", "bot"]);
  assert.throws(() => validateEvent({ v: 1, seq: 9, ts: "2026-11-10T17:00:03.000Z", job: "j", type: "verify", package: "core", round: 1, level: "V1", verb: "lint", ok: true, report: "r.json", after: "core" }), /"after" is only allowed on a whole-pack check/);

  // The fake adapter bills nothing and says so.
  assert.deepEqual(ofType(evs, "billing").map((e) => [e.adapter, e.mode]), [["fake", "none"]]);
  assert.throws(() => validateEvent({ v: 1, seq: 2, ts: "2026-11-10T17:00:03.000Z", job: "j", type: "billing", adapter: "fake", mode: "free", evidence: "x" }), /billing/);
  // The reducer: removed files leave the merged set.
  const st = foldEvents("j", [
    { v: 1, seq: 1, ts: "2026-11-10T17:00:00.000Z", job: "j", type: "job_created", sentence: "s", packId: "game.x", title: "X" },
    { v: 1, seq: 2, ts: "2026-11-10T17:00:01.000Z", job: "j", type: "plan_set", packages: [fixturePlan()[0] as PackageSpec] },
    { v: 1, seq: 3, ts: "2026-11-10T17:00:02.000Z", job: "j", type: "merge", package: "core", files: ["scripts/main.gd", "scripts/old.gd"] },
    { v: 1, seq: 4, ts: "2026-11-10T17:00:03.000Z", job: "j", type: "merge", package: "core", files: ["tests/bot_rally.gd"], removed: ["scripts/old.gd"] },
  ]);
  assert.deepEqual(st.packages["core"]?.mergedFiles, ["scripts/main.gd", "tests/bot_rally.gd"]);
});

test("6 events: budget.policy.limit is typed per kind; `foreman comment` writes the player's comment on a reached milestone", async () => {
  const base = { v: 1, seq: 2, ts: "2026-11-10T17:00:03.000Z", job: "j", type: "budget", state: "running", reason: "policy set" };
  assert.doesNotThrow(() => validateEvent({ ...base, policy: { kind: "tokens_per_hour", limit: 200000 } }));
  assert.doesNotThrow(() => validateEvent({ ...base, policy: { kind: "tokens_per_hour" }, state: "paused", reason: "rate_limit: come back later" }));
  assert.doesNotThrow(() => validateEvent({ ...base, policy: { kind: "overnight", limit: "22:00-07:00" } }));
  assert.doesNotThrow(() => validateEvent({ ...base, policy: { kind: "only_while_playing" } }));
  assert.throws(() => validateEvent({ ...base, policy: { kind: "tokens_per_hour", limit: 1.5 } }), /positive integer number of tokens/);
  assert.throws(() => validateEvent({ ...base, policy: { kind: "tokens_per_hour", limit: "200000" } }), /positive integer number of tokens/);
  assert.throws(() => validateEvent({ ...base, policy: { kind: "overnight", limit: 22 } }), /"HH:MM-HH:MM"/);
  assert.throws(() => validateEvent({ ...base, policy: { kind: "overnight" } }), /"HH:MM-HH:MM"/);
  assert.throws(() => validateEvent({ ...base, policy: { kind: "only_while_playing", limit: 1 } }), /takes no limit/);

  const job = tempJob("comment");
  await foremanFor(job).foreman.run();
  const { main } = await import("../cli.js");
  const lines: string[] = [];
  assert.equal(await main(["comment", job.jobDir, "blockout", "the walls are too low"], (s) => lines.push(s)), 0);
  const last = readEvents(job.jobDir).at(-1);
  assert.deepEqual([last?.type, last?.type === "comment" ? [last.milestone, last.text, last.by] : []], ["comment", ["blockout", "the walls are too low", "player"]]);
  await assert.rejects(main(["comment", job.jobDir, "tuned", "x"], () => {}), /has no "tuned" milestone yet \(reached: blockout, greybox\)/);
  assert.equal(rebuildState(job.jobDir, { write: false }).jobState?.state, "done", "a comment does not change the job's state");
});

test("6 runner: a verdict that rests on a clock (watchdog tick_timeout, physics time budget) is run once more; both runs are in the log and the second decides", async () => {
  // The first run of pack code trips the watchdog falsely, as the real runner did under CPU load.
  const job = tempJob("clock");
  const s = await foremanFor(job, { verifier: fastVerifier(job.engineDir, { FAKE_RUNNER_LOAD_TRIPS: "1" }) }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "promoted1"], "no round was spent on the machine's load");
  const core = ofType(evs, "verify").filter((e) => e.package === "core" || e.after === "core").filter((e) => e.verb === "smoke");
  assert.deepEqual(core.map((e) => [e.package ?? "pack", e.ok, e.exitCode, /-again-s\d+\.json$/.test(e.report)]), [
    ["core", false, 3, false],
    ["core", true, 0, true],
    ["pack", true, 0, false],
  ]);
  // A watchdog stop that happens twice is believed, and the builder is told it was seen twice.
  const real = tempJob("clock-real");
  const runaway: FakeStep = { match: { role: "builder", package: "core" }, write: { "scripts/main.gd": "extends Node\n# FAKE_WATCHDOG\n", "tests/bot_rally.gd": "extends Node\n" }, text: "Done." };
  const s2 = await foremanFor(real, { script: scriptWith([runaway]), roundLimit: 1 }).foreman.run();
  assert.equal(s2.jobState?.state, "failed");
  const smokes = ofType(readEvents(real.jobDir), "verify").filter((e) => e.package === "core" && e.verb === "smoke");
  assert.deepEqual(smokes.map((e) => [e.ok, e.exitCode]), [[false, 3], [false, 3]]);
  assert.match(s2.packages["core"]?.detail ?? "", /second run with the same clock-based result/);
  // A frame-counted stop (a bot that never finishes, as the snapshot reports it) and a plain failure are not retried.
  const p = goodPack({ "tests/bot.gd": "extends Node\n# FAKE_BOT_NEVER_DONE\n" });
  const never = await fastVerifier(p.engine, { FAKE_RUNNER_BOT_TIMEOUT: "watchdog" }).run({ verb: "bot", args: ["--test=tests/bot.gd"], packDir: p.pack, reportFile: path.join(p.reports, "n.json") });
  assert.deepEqual([never.report?.outcome, restsOnAClock(never)], ["watchdog", false]);
  const broken = goodPack({ "scripts/main.gd": "extends Node\nfunc f():\n\tFAKE_SCRIPT_ERROR()\n" });
  const plain = await fastVerifier(broken.engine).run({ verb: "smoke", packDir: broken.pack, reportFile: path.join(broken.reports, "s.json") });
  assert.deepEqual([plain.report?.outcome, restsOnAClock(plain)], ["failed", false]);
  const tick = await fastVerifier(p.engine, { FAKE_RUNNER_LOAD_TRIPS: "1" }).run({ verb: "smoke", packDir: p.pack, reportFile: path.join(p.reports, "t.json") });
  assert.deepEqual([tick.report?.outcome, tick.exitCode, restsOnAClock(tick)], ["watchdog", 3, true]);
});

// ---------------------------------------------------------------- 7. pack id at the first merge

test("7 pack id: a pack the runner loads under another id than the job's is refused at the FIRST merge, not at promotion", async () => {
  const job = tempJob("packid");
  const inner = inProcessFakeRunner();
  // A runner that reports another pack id (as if pack.json had been swapped under the Foreman).
  const lying: SpawnFn = async (req) => {
    const res = await inner(req);
    if (!req.args.some((a) => a.includes("_candidate_")) || !req.args.includes("lint")) return res;
    const lines = res.stdout.trimEnd().split("\n");
    const report = JSON.parse(lines[lines.length - 1] ?? "{}") as Record<string, unknown>;
    report["pack"] = "game.somebody_else";
    lines[lines.length - 1] = JSON.stringify(report);
    fs.writeFileSync((req.args.find((a) => a.startsWith("--report=")) ?? "").slice(9), JSON.stringify(report) + "\n");
    return { ...res, stdout: lines.join("\n") + "\n" };
  };
  const { foreman } = foremanFor(job, { verifier: new Verifier({ godot: FAKE_RUNNER, engineDir: job.engineDir, spawn: lying, timeoutMs: 300 }), roundLimit: 1 });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "failed");
  assert.deepEqual([s.packages["core"]?.state, s.packages["core"]?.cause], ["failed", "verify_failed"]);
  assert.match(s.packages["core"]?.detail ?? "", /the runner reports pack id "game\.somebody_else" but this job was created for "game\.paddle_court": the merge is refused/);
  const evs = readEvents(job.jobDir);
  assert.equal(ofType(evs, "merge").length, 0, "nothing was merged");
  assert.deepEqual(packFiles(path.join(job.jobDir, "pack")), {});
  assert.equal(ofType(evs, "promoted").length, 0);
});
