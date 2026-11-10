// WP3c: the second-round amendments of 2026-11-10 (JOB.md, RUNNER.md), against the fake adapter and the fake runner.
//   1 reference copy          2 Planner prompt        3 `note` event          4 no visible change
//   5 critic's extra round    6 capture frames        7 budget weights        8 promotion target
//   9 `foreman verify` re-runs a clock-based verdict
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir, tempJob, foremanFor, readEvents, scriptWith, fastVerifier, packFiles, type TempJob } from "./helpers.js";
import { FakeBuilder, type FakeStep } from "../builder/fake.js";
import { ClaudeCliBuilder } from "../builder/claude-cli.js";
import { planPackages, renderPlannerPrompt } from "../designer.js";
import { validateEvent, type JobEvent, type PackageSpec } from "../events.js";
import { foldEvents, rebuildState, weightedTokens } from "../joblog.js";
import { budgetVerdict } from "../budget.js";
import { Foreman, parseDeviations, CRITIC_ROUND, NO_VISIBLE_CHANGE } from "../foreman.js";
import { existingText, prepareReference, refContents, referenceOf, referenceText } from "../reference.js";
import { runProcess } from "../proc.js";
import { PKG_ROOT, REPO_ROOT } from "../paths.js";

after(cleanup);

const ofType = <T extends JobEvent["type"]>(evs: JobEvent[], type: T): Extract<JobEvent, { type: T }>[] => evs.filter((e) => e.type === type) as Extract<JobEvent, { type: T }>[];
const states = (evs: JobEvent[], pkg: string): string[] => ofType(evs, "package_state").filter((e) => e.package === pkg).map((e) => `${e.state}${e.round}`);
const CLI = path.join(PKG_ROOT, "dist", "cli.js");
const cli = (args: string[], env: NodeJS.ProcessEnv = {}): ReturnType<typeof runProcess> => runProcess({ exe: process.execPath, args: [CLI, ...args], env: { ...process.env, ...env }, timeoutMs: 60_000 });
const promptsOf = (b: FakeBuilder, pkg: string): string[] => b.calls.filter((c) => c.req.meta?.role === "builder" && c.req.meta?.package === pkg).map((c) => c.req.prompt);

function write(root: string, files: Record<string, string>): void {
  for (const [rel, body] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(root, rel)), { recursive: true });
    fs.writeFileSync(path.join(root, rel), body);
  }
}

/** A stand-in engine as the 20:00 snapshot was: kernel only. */
function oldEngine(): string {
  const dir = tempDir("engine-old");
  write(dir, {
    "kernel/API.md": "# Kernel API\nctx.read_json\n",
    "kernel/examples/pack_min/pack.json": "{}\n",
    "kernel/examples/ex_slide/pack.json": "{}\n",
    "kernel/data/materials.json": "{}\n",
    "kernel/data/surfaces.json": "{}\n",
  });
  return dir;
}

/** A stand-in engine as the live one is: kernel plus seeds, kit, rigs, style. */
function liveEngine(): string {
  const dir = oldEngine();
  write(dir, {
    "seeds/README.md": "# How to write a pack (ten minutes)\nFind the seed nearest to your game.\n",
    "seeds/seed_paddle/pack.json": "{}\n",
    "seeds/seed_paddle/README.md": "paddle seed\n",
    "seeds/seed_paddle/scripts/main.gd": "extends Node\n",
    "seeds/seed_drive/pack.json": "{}\n",
    "seeds/seed_wall/pack.json": "{}\n",
    "seeds/captures/sheet.png": "not copied",
    "kits/KIT.md": "# The kit\n## Parts (3)\n### `rink`\n### `stands`\n### `goal`\n",
    "kits/LAYOUT.md": "# Layout contract: `tl.layout/1`\n## `terrain`\n## `arenas[]`\n## `props[]`\n",
    "kits/tl_kit.gd": "extends RefCounted\n",
    "rigs/RIGS.md": "# Rigs\n## `biped`\n## `vehicle`\n",
    "style/STYLE.md": "# Style (`TLStyle`)\n",
  });
  return dir;
}

/** Rewrites the fixture's plan before the job starts. */
function editPlan(job: TempJob, change: (plan: PackageSpec[]) => void): void {
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter((l) => l.length > 0);
  const out = lines.map((l) => {
    const ev = JSON.parse(l) as JobEvent;
    if (ev.type !== "plan_set") return l;
    change(ev.packages);
    return JSON.stringify(validateEvent(ev));
  });
  fs.writeFileSync(file, out.join("\n") + "\n");
}

/** The root package also runs the bot, as a real root does: every milestone then uses the same capture frames. */
const rootRunsBot = (plan: PackageSpec[]): void => {
  plan.find((p) => p.id === "core")?.acceptance.push({ level: "V4", verb: "bot", args: ["--test=tests/bot_rally.gd"] });
};
const AI_JSON = '{\n "reaction_frames": 8,\n "max_speed_mps": 6,\n "error_m": 0.3\n}\n';
const AI_GD = "extends RefCounted\n\nfunc decide(ball_y: float, paddle_y: float, tuning: Dictionary) -> float:\n\treturn signf(ball_y - paddle_y)\n";
/** A paddle_ai round that passes every check and changes nothing a camera sees (the fake runner skips such files). */
const invisible = (round: number): FakeStep => ({
  match: { role: "builder", package: "paddle_ai", round },
  write: { "data/ai.json": AI_JSON.replace("{", '{\n "_look": "FAKE_INVISIBLE",'), "scripts/paddle_ai.gd": `# FAKE_INVISIBLE\n${AI_GD}` },
  text: "Done.\nDEVIATIONS: none",
});
const visible = (round: number): FakeStep => ({ match: { role: "builder", package: "paddle_ai", round }, write: { "data/ai.json": AI_JSON, "scripts/paddle_ai.gd": AI_GD }, text: "Done." });
const criticSays = (attempt: number, readability: number, note: string): FakeStep => ({
  match: { role: "critic", attempt },
  json: { ok: readability >= 0.6, scores: { silhouette: 0.8, readability, style_consistency: 0.7, shows_play: 0.7 }, notes: [note] },
});

// ---------------------------------------------------------------- 1. reference copy

test("1 reference: an engine with seeds, kit, rigs and style gives ref/seeds/**, KIT.md, LAYOUT.md, RIGS.md, STYLE.md; the builder prompt names them and the reading order", async () => {
  const engine = liveEngine();
  const job = tempJob("ref-live");
  const { foreman, builder } = foremanFor(job, { reference: referenceOf(engine) });
  assert.equal((await foreman.run()).jobState?.state, "done");
  const ref = path.join(job.jobDir, "ref");
  for (const f of ["API.md", "examples/pack_min/pack.json", "examples/ex_slide/pack.json", "data/materials.json", "data/surfaces.json", "seeds/README.md", "seeds/seed_paddle/pack.json", "seeds/seed_paddle/scripts/main.gd", "seeds/seed_drive/pack.json", "seeds/seed_wall/pack.json", "kits/KIT.md", "kits/LAYOUT.md", "rigs/RIGS.md", "style/STYLE.md"]) {
    assert.ok(fs.existsSync(path.join(ref, f)), `ref/${f}`);
  }
  assert.ok(!fs.existsSync(path.join(ref, "seeds", "captures")), "capture images of the seeds are not reference material");
  assert.ok(!fs.existsSync(path.join(ref, "kits", "tl_kit.gd")), "only the documents of the kit are copied");
  assert.deepEqual(refContents(ref).seeds, ["seed_drive", "seed_paddle", "seed_wall"]);
  const prompt = promptsOf(builder, "core")[0] ?? "";
  assert.match(prompt, /1\. READ [^\n]*\/ref\/seeds\/README\.md FIRST/);
  assert.match(prompt, /2\. COPY THE NEAREST SEED: [^\n]*\(seed_drive, seed_paddle, seed_wall\)/);
  assert.match(prompt, /3\. BUILD THE VENUE FROM THE KIT BEFORE MAKING BOXES: [^\n]*\/ref\/kits\/LAYOUT\.md[^\n]*\/ref\/kits\/KIT\.md/);
  for (const name of ["ref/seeds/seed_paddle/", "ref/kits/KIT.md", "ref/kits/LAYOUT.md", "ref/rigs/RIGS.md", "ref/style/STYLE.md", "ref/API.md", "ref/examples/pack_min/", "ref/data/"]) assert.ok(prompt.includes(name), `the prompt names ${name}`);
  // The engine directory itself is never a path in the prompt's reference section, and nothing was written to it.
  assert.ok(!referenceText(ref).includes(engine.replace(/\\/g, "/")));
  assert.ok(!fs.existsSync(path.join(engine, "packs")));
});

test("1 reference: an engine without seeds or a kit (the old snapshot) still works: a smaller copy, and the prompt says there is no kit", async () => {
  const engine = oldEngine();
  const job = tempJob("ref-old");
  const { foreman, builder } = foremanFor(job, { reference: referenceOf(engine) });
  assert.equal((await foreman.run()).jobState?.state, "done");
  const ref = path.join(job.jobDir, "ref");
  assert.deepEqual(fs.readdirSync(ref).sort(), ["API.md", "data", "examples"]);
  const prompt = promptsOf(builder, "core")[0] ?? "";
  assert.match(prompt, /Kernel API \(everything a pack script may call, with examples; READ IT FIRST\)/);
  assert.match(prompt, /This engine has no kit, no rigs, no style layer and no seed games/);
  assert.doesNotMatch(prompt, /COPY THE NEAREST SEED|ref\/seeds/);
});

test("1 reference: the repository's two engines read as expected (read-only): the live engine has seeds and the four documents, the snapshot has neither", { skip: !fs.existsSync(path.join(REPO_ROOT, "engine", "kernel", "API.md")) }, () => {
  const live = referenceOf(path.join(REPO_ROOT, "engine"));
  const ref = path.join(tempDir("ref-repo"), "ref");
  prepareReference(ref, live);
  const c = refContents(ref);
  assert.ok(c.api && c.seedsReadme);
  assert.deepEqual(c.seeds, ["seed_drive", "seed_paddle", "seed_wall"]);
  assert.deepEqual(c.docs, ["kits/KIT.md", "kits/LAYOUT.md", "rigs/RIGS.md", "style/STYLE.md"]);
  assert.match(existingText(ref), /\*\*The kit\*\* \(`TLKit`, document `ref\/kits\/KIT\.md`\): \d+ ready-made venue parts: [^\n]*rink/);
  const snap = path.join(REPO_ROOT, "site", "_engine_snapshot");
  if (fs.existsSync(snap)) {
    const old = referenceOf(snap);
    assert.equal(old.seedsDir, undefined);
    assert.equal(old.docs, undefined);
    assert.ok(old.apiDoc !== undefined);
  }
});

// ---------------------------------------------------------------- 2. Planner prompt

test("2 planner: the prompt names what exists (kit parts, layout, rigs, style, seeds), the real builder time limit, the sizing rule, the art_pass rule and the package limit", async () => {
  const ref = path.join(tempDir("plan-ref"), "ref");
  prepareReference(ref, referenceOf(liveEngine()));
  const input = { sentence: "ice hockey, three a side", packId: "game.hockey", title: "Hockey", brief: { rules: "r", arena: "a", ai: "i", controls: "c", mood: "m" }, packContract: "(pack contract)", kernelApi: "(api)" };
  const text = renderPlannerPrompt({ ...input, existing: existingText(ref), builderTimeoutMs: 12 * 60_000 }, { maxPackages: 3 });
  assert.match(text, /# What already exists \(use it; do not plan to rebuild it\)/);
  assert.match(text, /\*\*The kit\*\* \(`TLKit`, document `ref\/kits\/KIT\.md`\): 3 ready-made venue parts: rink, stands, goal\./);
  assert.match(text, /\*\*The layout contract\*\* [^\n]*sections: terrain, arenas\[\], props\[\]/);
  assert.match(text, /\*\*The rigs\*\* [^\n]*: biped, vehicle\./);
  assert.match(text, /\*\*The style layer\*\* \(`TLStyle`/);
  assert.match(text, /\*\*Seed games\*\* [^\n]*: seed_drive, seed_paddle, seed_wall\./);
  assert.match(text, /How to write a pack \(ten minutes\)/, "the seeds' own guide is in the prompt");
  assert.match(text, /hard time limit of 12 minutes\*\* of wall clock/);
  assert.match(text, /\*\*The root package is the smallest thing that plays\*\*[^]*FEW files/);
  assert.match(text, /\*\*Later packages carry the rest\*\*/);
  assert.match(text, /\*\*An `art_pass` package must change what the camera sees\.\*\*[^]*no_visible_change/);
  assert.match(text, /At most 3 packages in total for this job \(a hard limit\)\./);
  assert.ok(!text.includes("{{"), "no placeholder is left unfilled");
  // The limit of packages and the time limit are parameters.
  const other = renderPlannerPrompt({ ...input, builderTimeoutMs: 25 * 60_000 }, { maxPackages: 5 });
  assert.match(other, /At most 5 packages in total/);
  assert.match(other, /hard time limit of 25 minutes/);
  assert.match(other, /no kit, no rigs, no style layer and no seed games/);
  assert.match(renderPlannerPrompt(input), /hard time limit of 30 minutes[^]*Three to eight packages/);
  // The prompt a real Planner call sends is this same text.
  const b = new FakeBuilder({ steps: [{ outcome: "error", error: { kind: "exit", message: "stop here" } }] });
  await planPackages(b, { ...input, existing: existingText(ref), builderTimeoutMs: 12 * 60_000 }, { maxPackages: 3 });
  assert.equal(b.calls[0]?.req.prompt, text);
});

test("2 planner: `foreman prompts <job>` prints the assembled Planner prompt and every builder prompt without calling a model, and `plan` prepares ref/", async () => {
  const engine = liveEngine();
  const job = tempJob("dry");
  const before = fs.readFileSync(path.join(job.jobDir, "job.jsonl"), "utf8");
  const r = await cli(["prompts", job.jobDir, "--engine-dir", engine, "--max-packages", "3", "--timeout-ms", "720000", "--round-limit", "3"]);
  assert.equal(r.exitCode, 0, r.stderr + r.stdout);
  assert.match(r.stdout, /={20} PLANNER PROMPT \(job paddle-court-20261110-1, engine /);
  assert.match(r.stdout, /hard time limit of 12 minutes[^]*At most 3 packages/);
  assert.match(r.stdout, /Seed games\*\* [^\n]*seed_drive, seed_paddle, seed_wall/);
  for (const id of ["core", "court", "paddle_ai"]) assert.match(r.stdout, new RegExp(`={20} BUILDER PROMPT: package ${id}, round 1 `));
  assert.match(r.stdout, /# Round 1 of 3\nThis run has a hard time limit of 12 minutes of wall clock/);
  assert.match(r.stdout, /READ [^\n]*\/ref\/seeds\/README\.md FIRST/);
  assert.equal(fs.readFileSync(path.join(job.jobDir, "job.jsonl"), "utf8"), before, "a dry check writes no event");
  assert.ok(fs.existsSync(path.join(job.jobDir, "ref", "seeds", "README.md")), "ref/ is prepared, as a run would");
});

// ---------------------------------------------------------------- 3. note event

test("3 note: deviations stated under DEVIATIONS: become a `note {package, round, text}` event and are part of the brief of every package that depends on it", async () => {
  assert.equal(parseDeviations("Done. Wrote a.gd.\nDEVIATIONS: none"), undefined);
  assert.equal(parseDeviations("Done.\nDEVIATIONS:\n- None.\n"), undefined);
  assert.equal(parseDeviations("Done. No deviations to speak of."), undefined, "only the heading counts");
  assert.equal(parseDeviations("files: a\n**DEVIATIONS:**\n- one\n- two\nQUESTION: may I?"), "- one\n- two");
  assert.equal(parseDeviations("DEVIATIONS: the ball is `puck`"), "the ball is `puck`");

  const job = tempJob("note");
  const said = "- the ball node is called `puck_ball`, not `ball`\n- marbles pass through each other (no marble-marble collision)";
  const core: FakeStep = { ...(scriptWith().steps[0] as FakeStep), text: `Done. Wrote scripts/main.gd.\n\nDEVIATIONS:\n${said}\n` };
  const { foreman, builder } = foremanFor(job, { script: scriptWith([core]) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done");
  const evs = readEvents(job.jobDir);
  const notes = ofType(evs, "note");
  assert.deepEqual(notes.map((n) => [n.package, n.round, n.text]), [["core", 1, said]], "court and paddle_ai stated none: no event for them");
  // The note comes right after the builder_run it was read from, before the verification.
  const at = evs.findIndex((e) => e.type === "note");
  assert.equal(evs[at - 1]?.type, "builder_run");
  assert.deepEqual(s.notes, [{ package: "core", round: 1, text: said }]);
  assert.deepEqual(rebuildState(job.jobDir, { write: false }).notes, s.notes, "the notes are rebuilt from the log alone");
  for (const dep of ["court", "paddle_ai"]) {
    for (const p of promptsOf(builder, dep)) {
      assert.match(p, /## What the packages you depend on did differently from their contracts\n[^\n]*did NOT follow their contract to the letter/);
      assert.ok(p.includes("- core (round 1): - the ball node is called `puck_ball`, not `ball`"), `${dep} is told`);
      assert.ok(p.includes("marbles pass through each other"));
    }
  }
  assert.match(promptsOf(builder, "core")[0] ?? "", /did differently from their contracts\nNone stated: build against the contracts as written\./);
  assert.match(promptsOf(builder, "core")[0] ?? "", /the heading `DEVIATIONS:`[^]*write `DEVIATIONS: none`/, "the builder is asked for the heading");
  // Strict reader: the event is known, and its keys are fixed.
  assert.throws(() => validateEvent({ v: 1, seq: 9, ts: "2026-11-10T20:00:00Z", job: "j", type: "note", package: "core", round: 1, text: "x", extra: 1 }), /unknown key "extra"/);
  assert.throws(() => validateEvent({ v: 1, seq: 9, ts: "2026-11-10T20:00:00Z", job: "j", type: "note", package: "core", text: "x" }), /missing key "round"/);
});

// ---------------------------------------------------------------- 4. no visible change

test("4 no visible change: an art_pass milestone whose captures are byte-identical to the previous milestone's fails its packages that round (cause no_visible_change) and the next round gets that as feedback", async () => {
  const job = tempJob("nvc");
  editPlan(job, (plan) => {
    rootRunsBot(plan);
    (plan.find((p) => p.id === "paddle_ai") as PackageSpec).milestone = "art_pass";
  });
  const { foreman, builder } = foremanFor(job, { script: scriptWith([invisible(1), visible(2)]), roundLimit: 3 });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  // Round 1 passed every check and was merged; the captures showed nothing new; round 2 changed the picture.
  assert.deepEqual(states(evs, "paddle_ai"), ["queued1", "running1", "verifying1", "promoted1", "failed1", "queued2", "running2", "verifying2", "promoted2"]);
  const failed = ofType(evs, "package_state").find((e) => e.package === "paddle_ai" && e.state === "failed");
  assert.equal(failed?.cause, "no_visible_change");
  assert.match(failed?.detail ?? "", /^NO VISIBLE CHANGE: every capture of the art_pass milestone \(art_pass-hero-f150\.png, art_pass-hero-f450\.png\) is byte-identical to the "blockout" milestone's/);
  assert.ok((failed?.detail ?? "").startsWith(NO_VISIBLE_CHANGE));
  const round2 = promptsOf(builder, "paddle_ai")[1] ?? "";
  assert.match(round2, /# Round 2 of 3/);
  assert.match(round2, /Round 1 passed the Verifier and was merged, but the package was sent back: NO VISIBLE CHANGE: every capture/);
  assert.match(round2, /Passing the same checks again without a visible change is not enough/);
  // The milestone is written once, after the round that changed the picture; the blockout milestone is untouched.
  assert.deepEqual(ofType(evs, "milestone").map((m) => m.milestone), ["blockout", "art_pass"]);
  assert.doesNotMatch(ofType(evs, "milestone")[1]?.summary ?? "", /NO VISIBLE CHANGE/);
  assert.equal(s.packages["paddle_ai"]?.round, 2);
});

test("4 no visible change: at the round limit the package stays failed with that cause and the job fails; a milestone that is not art_pass only gets a note", async () => {
  const job = tempJob("nvc-limit");
  editPlan(job, (plan) => {
    rootRunsBot(plan);
    (plan.find((p) => p.id === "paddle_ai") as PackageSpec).milestone = "art_pass";
  });
  const s = await foremanFor(job, { script: scriptWith([invisible(1), invisible(2)]), roundLimit: 2 }).foreman.run();
  assert.equal(s.jobState?.state, "failed");
  assert.match(s.jobState?.reason ?? "", /failed: paddle_ai \(no_visible_change\)/);
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "paddle_ai"), ["queued1", "running1", "verifying1", "promoted1", "failed1", "queued2", "running2", "verifying2", "promoted2", "failed2"]);
  assert.deepEqual(ofType(evs, "milestone").map((m) => m.milestone), ["blockout"], "the art_pass milestone was never reached");
  assert.equal(ofType(evs, "promoted").length, 0);
  // A package that was merged and then failed for good leaves pack/ again: its files and its place in the manifest.
  const lastMerge = ofType(evs, "merge").filter((m) => m.package === "paddle_ai").pop();
  assert.deepEqual([lastMerge?.files, lastMerge?.removed], [[], ["data/ai.json", "scripts/paddle_ai.gd"]]);
  assert.deepEqual(Object.keys(packFiles(path.join(job.jobDir, "pack"))).sort(), ["data/court.json", "pack.json", "scripts/court.gd", "scripts/main.gd", "tests/bot_rally.gd"]);
  assert.deepEqual(s.packages["paddle_ai"]?.mergedFiles, []);

  // greybox is not an art pass: identical captures are a note in the milestone, and the package stays promoted.
  const grey = tempJob("nvc-grey");
  editPlan(grey, rootRunsBot);
  const s2 = await foremanFor(grey, { script: scriptWith([invisible(1)]) }).foreman.run();
  assert.equal(s2.jobState?.state, "done");
  const ms = ofType(readEvents(grey.jobDir), "milestone");
  assert.match(ms[1]?.summary ?? "", /NO VISIBLE CHANGE: every capture is byte-identical to the "blockout" milestone's/);
  assert.deepEqual(states(readEvents(grey.jobDir), "paddle_ai"), ["queued1", "running1", "verifying1", "promoted1"]);
});

test("4 no visible change: a kill between `failed` and the next round's `queued` is repaired on resume", async () => {
  const job = tempJob("nvc-kill");
  editPlan(job, (plan) => {
    rootRunsBot(plan);
    (plan.find((p) => p.id === "paddle_ai") as PackageSpec).milestone = "art_pass";
  });
  const script = scriptWith([invisible(1), visible(2)]);
  await assert.rejects(
    foremanFor(job, {
      script,
      roundLimit: 3,
      afterAppend: (ev) => {
        if (ev.type === "package_state" && ev.state === "failed" && ev.cause === "no_visible_change") throw new Error("kill");
      },
    }).foreman.run(),
    /kill/,
  );
  const s = await foremanFor(job, { script, roundLimit: 3 }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  assert.deepEqual(states(readEvents(job.jobDir), "paddle_ai").slice(-5), ["failed1", "queued2", "running2", "verifying2", "promoted2"]);
});

// ---------------------------------------------------------------- 5. critic

test("5 critic: NOT ok gives the milestone's packages one extra round with the critic's notes as feedback; the verdict of the second look is in the `milestone` event", async () => {
  const job = tempJob("critic-round");
  const { foreman, builder } = foremanFor(job, { critic: true, script: scriptWith([criticSays(1, 0.4, "the ramp reads as a tangled pile"), criticSays(2, 0.8, "the court reads clearly now")]) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  // blockout = core + court: both get round 2, exactly once.
  for (const id of ["core", "court"]) assert.deepEqual(states(evs, id), ["queued1", "running1", "verifying1", "promoted1", "queued2", "running2", "verifying2", "promoted2"], id);
  const sentBack = ofType(evs, "package_state").find((e) => e.package === "core" && e.state === "queued" && e.round === 2);
  assert.ok((sentBack?.detail ?? "").startsWith(CRITIC_ROUND));
  assert.match(sentBack?.detail ?? "", /readability 0\.4[^]*Critic's notes: the ramp reads as a tangled pile[^]*\[reports\/critic-blockout-s\d+\.json\]/);
  for (const id of ["core", "court"]) {
    const p = promptsOf(builder, id)[1] ?? "";
    assert.match(p, /Round 1 passed the Verifier and was merged, but the package was sent back: critic \(V5\) NOT ok, one extra round: [^\n]*the ramp reads as a tangled pile/, id);
  }
  const ms = ofType(evs, "milestone");
  assert.deepEqual(ms.map((m) => m.milestone), ["blockout", "greybox"], "one milestone event per milestone");
  assert.match(ms[0]?.summary ?? "", /critic \(V5\) ok: [^\n]*the court reads clearly now[^\n]*\(the verdict after the one extra round/);
  assert.equal(ofType(evs, "builder_run").filter((e) => e.package === undefined).length, 3, "three critic calls: blockout twice, greybox once");
});

test("5 critic: after the extra round the job continues whatever the verdict, and whatever happened in that round", async () => {
  // NOT ok twice: no third round; the NOT ok verdict stays in the milestone event; the job is done.
  const job = tempJob("critic-twice");
  const s = await foremanFor(job, { critic: true, script: scriptWith([criticSays(1, 0.4, "pile"), criticSays(2, 0.3, "still a pile")]) }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  assert.equal(s.packages["core"]?.round, 2);
  assert.equal(s.packages["court"]?.round, 2);
  assert.match(ofType(evs, "milestone")[0]?.summary ?? "", /critic \(V5\) NOT ok: [^\n]*still a pile/);

  // The extra round itself fails (the builder errors): the package stays as it was merged, and the job goes on.
  const job2 = tempJob("critic-round-fails");
  const boom: FakeStep = { match: { role: "builder", package: "court", round: 2 }, outcome: "error", error: { kind: "exit", message: "crashed" } };
  const s2 = await foremanFor(job2, { critic: true, script: scriptWith([boom, criticSays(1, 0.4, "pile")]) }).foreman.run();
  assert.equal(s2.jobState?.state, "done", JSON.stringify(s2.jobState));
  const evs2 = readEvents(job2.jobDir);
  assert.deepEqual(states(evs2, "court"), ["queued1", "running1", "verifying1", "promoted1", "queued2", "running2", "promoted2"]);
  assert.match(ofType(evs2, "package_state").filter((e) => e.package === "court").pop()?.detail ?? "", /the extra round after the critic did not pass \(builder error: crashed\); the files merged before it stay in pack\//);
  assert.deepEqual(ofType(evs2, "milestone").map((m) => m.milestone), ["blockout", "greybox"]);
  assert.ok(fs.existsSync(path.join(job2.jobDir, "pack", "scripts", "court.gd")));
});

test("4+5 resume: kill at every event of a job with a critic round and a no-visible-change round, then resume: done, one milestone event each, same pack, no ok builder round paid twice", async () => {
  const setup = (label: string): TempJob => {
    const job = tempJob(label);
    editPlan(job, (plan) => {
      rootRunsBot(plan);
      (plan.find((p) => p.id === "paddle_ai") as PackageSpec).milestone = "art_pass";
    });
    return job;
  };
  // The critic never likes the blockout (so its verdict does not depend on which Foreman process asks).
  const blockoutBad: FakeStep = { match: { role: "critic", promptIncludes: "blockout-hero" }, json: { ok: false, scores: { silhouette: 0.8, readability: 0.4, style_consistency: 0.7, shows_play: 0.7 }, notes: ["pile"] } };
  const script = (): ReturnType<typeof scriptWith> => scriptWith([blockoutBad, invisible(1), visible(2)]);
  const ref = setup("killref");
  const s0 = await foremanFor(ref, { critic: true, roundLimit: 3, script: script() }).foreman.run();
  assert.equal(s0.jobState?.state, "done", JSON.stringify(s0.jobState));
  const refPack = packFiles(path.join(ref.jobDir, "pack"));
  const total = readEvents(ref.jobDir).length;
  assert.ok(total > 70, String(total));
  for (let killAt = 5; killAt < total; killAt++) {
    const where = "stop after event " + String(killAt);
    const job = setup("k" + String(killAt));
    await assert.rejects(
      foremanFor(job, {
        critic: true,
        roundLimit: 3,
        script: script(),
        afterAppend: (ev) => {
          if (ev.seq === killAt) throw new Error("simulated stop");
        },
      }).foreman.run(),
      /simulated stop/,
    );
    const s = await foremanFor(job, { critic: true, roundLimit: 3, script: script() }).foreman.run();
    const evs = readEvents(job.jobDir);
    assert.equal(s.jobState?.state, "done", where + ": " + JSON.stringify(s.jobState));
    assert.deepEqual(ofType(evs, "milestone").map((m) => m.milestone), ["blockout", "art_pass"], where);
    assert.deepEqual(s.order.map((id) => s.packages[id]?.state), ["promoted", "promoted", "promoted"], where);
    assert.equal(s.packages["paddle_ai"]?.round, 2, where);
    assert.deepEqual(packFiles(path.join(job.jobDir, "pack")), refPack, where + ": pack differs");
    const okRuns = ofType(evs, "builder_run").filter((e) => e.outcome === "ok" && e.package !== undefined).map((e) => String(e.package) + ":" + String(e.round));
    assert.equal(new Set(okRuns).size, okRuns.length, where + ": an ok builder round ran twice (" + okRuns.join(",") + ")");
    assert.ok(ofType(evs, "package_state").filter((e) => e.state === "queued" && (e.detail ?? "").startsWith(CRITIC_ROUND)).length <= 2, where + ": more than one critic round");
  }
});

// ---------------------------------------------------------------- 6. capture frames

test("6 capture frames: 25 % and 75 % of the frame at which the first bot finished in its last passing report; 120 and 480 when there is none", async () => {
  // The fake bot finishes at frame 600. With the root running it, every milestone is captured at 150 and 450.
  const job = tempJob("frames");
  editPlan(job, rootRunsBot);
  await foremanFor(job).foreman.run();
  const evs = readEvents(job.jobDir);
  assert.deepEqual(ofType(evs, "milestone").map((m) => m.captures), [
    ["captures/blockout-hero-f150.png", "captures/blockout-hero-f450.png"],
    ["captures/greybox-hero-f150.png", "captures/greybox-hero-f450.png"],
  ]);
  const cap = ofType(evs, "verify").find((e) => e.verb === "capture");
  const verdict = JSON.parse(fs.readFileSync(path.join(job.jobDir, (cap?.report ?? "").replace(/\.json$/, ".verdict.json")), "utf8")) as { argv: string[] };
  assert.ok(verdict.argv.includes("--frame=150") && verdict.argv.includes("--test=tests/bot_rally.gd"));
  // The fixture as it is: no bot has passed when blockout is reached (120, 480); one has when greybox is (150, 450).
  const plain = tempJob("frames-plain");
  await foremanFor(plain).foreman.run();
  assert.deepEqual(ofType(readEvents(plain.jobDir), "milestone").map((m) => m.captures), [
    ["captures/blockout-hero-f120.png", "captures/blockout-hero-f480.png"],
    ["captures/greybox-hero-f150.png", "captures/greybox-hero-f450.png"],
  ]);
  // An explicit option still wins.
  const fixed = tempJob("frames-fixed");
  editPlan(fixed, rootRunsBot);
  await foremanFor(fixed, { captureFrames: [10] }).foreman.run();
  assert.deepEqual(ofType(readEvents(fixed.jobDir), "milestone")[0]?.captures, ["captures/blockout-hero-f10.png"]);
});

// ---------------------------------------------------------------- 7. budget

test("7 budget: cache-read tokens count at 0.1 against a token policy; the raw figures are logged unchanged", async () => {
  assert.equal(weightedTokens(1000, 100, 900), 290);
  assert.equal(weightedTokens(1000, 100), 1100);
  assert.equal(weightedTokens(500, 0, 9999), 50, "cache reads are never more than the input");
  // The first real job's root package: 2,266,338 in, of which most were cache reads.
  const at = "2026-11-10T20:00:00Z";
  const base = { v: 1 as const, ts: at, job: "j" };
  const evs = [
    { ...base, seq: 1, type: "job_created", sentence: "s", packId: "game.x", title: "X" },
    { ...base, seq: 2, type: "builder_run", adapter: "claude-cli", mode: "generate", model: "sonnet", outcome: "ok", durationMs: 1, tokensIn: 2_266_338, tokensOut: 74_913, tokensCacheRead: 2_100_000 },
  ].map((e) => validateEvent(e));
  const s = foldEvents("j", evs);
  assert.deepEqual(s.tokens, { in: 2_266_338, out: 74_913, cacheRead: 2_100_000, unreportedRuns: 0 }, "raw totals");
  assert.deepEqual(s.tokenLedger, [{ ts: at, tokens: 2_266_338 - 2_100_000 + 210_000 + 74_913 }]);
  const now = (): Date => new Date("2026-11-10T20:10:00Z");
  assert.equal(budgetVerdict({ kind: "tokens_per_hour", limit: 1_000_000 }, s, { now }).allowed, true, "451,251 weighted tokens are under a 1M limit");
  assert.equal(budgetVerdict({ kind: "tokens_per_hour", limit: 400_000 }, s, { now }).allowed, false);
  // Through the Foreman: the event carries the adapter's raw figures, cache reads included.
  const job = tempJob("cache");
  const core: FakeStep = { ...(scriptWith().steps[0] as FakeStep), tokensIn: 100_000, tokensOut: 1000, tokensCacheRead: 90_000 };
  const s2 = await foremanFor(job, { script: scriptWith([core]), budget: { kind: "tokens_per_hour", limit: 50_000 } }).foreman.run();
  assert.equal(s2.jobState?.state, "done", "100,000 raw tokens would have paused a 50,000 policy; 20,000 weighted do not");
  const run = ofType(readEvents(job.jobDir), "builder_run").find((e) => e.package === "core");
  assert.deepEqual([run?.tokensIn, run?.tokensOut, run?.tokensCacheRead], [100_000, 1000, 90_000]);
  assert.equal(ofType(readEvents(job.jobDir), "budget").filter((e) => e.state === "paused").length, 0);
  // The claude CLI's result event carries the figure as usage.cache_read_input_tokens (capability matrix).
  const b = new ClaudeCliBuilder({ bin: process.execPath, env: {} });
  const stdout = JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "hi", stop_reason: "end_turn", usage: { input_tokens: 10, cache_creation_input_tokens: 20, cache_read_input_tokens: 300, output_tokens: 5 } }) + "\n";
  const r = b.normalize({ exitCode: 0, stdout, stderr: "", timedOut: false, outputCapped: false, durationMs: 1 }, [], "", { prompt: "p", mode: "generate", cwd: "", timeoutMs: 1000 }, 1000);
  assert.deepEqual([r.tokensIn, r.tokensOut, r.tokensCacheRead], [330, 5, 300]);
  const caps = fs.readFileSync(path.join(PKG_ROOT, "data", "capabilities.json"), "utf8");
  assert.match(caps, /cache_read_input_tokens/);
});

test("7 budget: the derived budget state is `closed` once the job has ended, and open again while a resumed job runs", async () => {
  const job = tempJob("budget-close");
  const policy = { kind: "tokens_per_hour" as const, limit: 10_000_000 };
  const s = await foremanFor(job, { budget: policy }).foreman.run();
  assert.equal(s.jobState?.state, "done");
  assert.deepEqual([s.budget?.state, s.budget?.reason], ["closed", "job ended (done)"]);
  assert.equal(rebuildState(job.jobDir, { write: false }).budget?.state, "closed");
  assert.equal((JSON.parse(fs.readFileSync(path.join(job.jobDir, "state.json"), "utf8")) as { budget: { state: string } }).budget.state, "closed");
  // A job that fails closes it too; a prefix of the log that ends while running does not.
  const evs = readEvents(job.jobDir);
  const lastRunning = evs.findLastIndex((e) => e.type === "job_state" && e.state === "running");
  assert.equal(foldEvents("x", evs.slice(0, evs.length - 1)).budget?.state, "running");
  assert.ok(lastRunning >= 0);
  // A resume (a new `job_state running`) opens it again with what the last budget event said.
  const resumed = validateEvent({ v: 1, seq: evs.length + 1, ts: "2026-11-10T21:00:00Z", job: evs[0]?.job, type: "job_state", state: "running", reason: "resumed (was done)" });
  assert.deepEqual([foldEvents("x", [...evs, resumed]).budget?.state, foldEvents("x", [...evs, resumed]).budget?.reason], ["running", "policy set"]);
  const bad = tempJob("budget-close-failed");
  const broken: FakeStep = { match: { role: "builder", package: "core" }, outcome: "refused" };
  const s2 = await foremanFor(bad, { budget: policy, script: scriptWith([broken]) }).foreman.run();
  assert.deepEqual([s2.jobState?.state, s2.budget?.state, s2.budget?.reason], ["failed", "closed", "job ended (failed)"]);
});

// ---------------------------------------------------------------- 8. promotion

test("8 promotion: the default target is <job>/promoted/<pack id>/, so a job ends `promoted` without touching the engine", async () => {
  const job = tempJob("promote-job");
  const foreman = new Foreman({ jobDir: job.jobDir, builder: new FakeBuilder(scriptWith()), verifier: fastVerifier(job.engineDir), parallel: 1, packContract: "(omitted)", critic: false });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done");
  assert.match(s.jobState?.reason ?? "", /^pack verified V0 to V4 and promoted under the job directory \(promoted\/game\.paddle_court\)$/);
  assert.deepEqual(s.promoted, { packId: "game.paddle_court", version: "0.1.0", dest: "promoted/game.paddle_court" });
  assert.deepEqual(packFiles(path.join(job.jobDir, "promoted", "game.paddle_court")), packFiles(path.join(job.jobDir, "pack")));
  assert.deepEqual(fs.readdirSync(job.engineDir), [], "nothing was written to the engine directory");
});

test("8 promotion: --promote-to engine writes <engine>/packs/<id>/; when the engine directory is not writable it falls back to the job directory and says so", async () => {
  const ok = tempJob("promote-engine");
  const s = await foremanFor(ok, { promoteTo: "engine" }).foreman.run();
  assert.equal(s.promoted?.dest, "packs/game.paddle_court");
  assert.match(s.jobState?.reason ?? "", /promoted into the engine \(packs\/\)/);
  assert.ok(!fs.existsSync(path.join(ok.jobDir, "promoted")));
  // Not writable: <engine>/packs exists as a FILE, so no pack directory can be made under it.
  const ro = tempJob("promote-ro");
  fs.writeFileSync(path.join(ro.engineDir, "packs"), "not a directory");
  const s2 = await foremanFor(ro, { promoteTo: "engine" }).foreman.run();
  assert.equal(s2.jobState?.state, "done");
  assert.equal(s2.promoted?.dest, "promoted/game.paddle_court");
  assert.match(s2.jobState?.reason ?? "", /promoted under the job directory \(promoted\/game\.paddle_court\); the engine directory is not writable/);
  assert.ok(fs.existsSync(path.join(ro.jobDir, "promoted", "game.paddle_court", "pack.json")));
  assert.equal(fs.readFileSync(path.join(ro.engineDir, "packs"), "utf8"), "not a directory");
  // The CLI: default job, and a wrong value is a usage error.
  const viaCli = tempJob("promote-cli");
  const r = await cli(["run", viaCli.jobDir, "--adapter", "fake", "--quiet"]);
  assert.equal(r.exitCode, 0, r.stderr + r.stdout);
  assert.ok(fs.existsSync(path.join(viaCli.jobDir, "promoted", "game.paddle_court", "pack.json")));
  assert.ok(!fs.existsSync(path.join(viaCli.jobDir, "engine-out", "packs")));
  const bad = await cli(["run", tempJob("promote-bad").jobDir, "--adapter", "fake", "--promote-to", "moon"]);
  assert.equal(bad.exitCode, 2);
  assert.match(bad.stderr, /--promote-to takes "job"/);
});

// ---------------------------------------------------------------- 9. foreman verify and clock-based verdicts

test("9 verify: `foreman verify <pack>` runs a clock-based failure once more, shows both runs, and the second decides", async () => {
  const job = tempJob("verify-clock");
  await foremanFor(job).foreman.run();
  const pack = path.join(job.jobDir, "pack");
  const reports = tempDir("verify-clock-reports");
  const r = await cli(["verify", pack, "--runner", "fake", "--verbs", "lint,smoke", "--reports", reports], { FAKE_RUNNER_LOAD_TRIPS: "1" });
  assert.equal(r.exitCode, 0, r.stderr + r.stdout);
  const smoke = r.stdout.split("\n").filter((l) => l.startsWith("smoke"));
  assert.equal(smoke.length, 2, r.stdout);
  assert.match(smoke[0] ?? "", /FAILED\s+exit=3[^\n]*\(clock-based: running it once more\)/);
  assert.match(smoke[1] ?? "", /ok\s+exit=0[^\n]*\(second run of a clock-based verdict; this one decides\)/);
  assert.ok(fs.existsSync(path.join(reports, "smoke.json")) && fs.existsSync(path.join(reports, "smoke-again.json")), "both reports are kept");
  // Tripping twice is believed: exit 1.
  const twice = await cli(["verify", pack, "--runner", "fake", "--verbs", "smoke", "--reports", tempDir("verify-clock-2")], { FAKE_RUNNER_LOAD_TRIPS: "2" });
  assert.equal(twice.exitCode, 1);
  assert.equal(twice.stdout.split("\n").filter((l) => l.startsWith("smoke")).length, 2);
});
