// N4 loop rounds 8 and 9 (22 Nov): the look films the exchange where the bot saw it (its `moments`), not at fixed fractions of
// its run. The crazy colosseum proof -3 was filmed at 25 % and 95 % and two strips were 60 frames of standing still.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, foremanFor, readEvents, sampleConcept, scriptWith, tempJob, v2Brief } from "./helpers.js";
import type { FakeStep } from "../builder/fake.js";
import type { Brief, PackageSpec } from "../events.js";
import { pickMoments, planShots } from "../shots.js";
import { tofuLine } from "../tofu.js";

after(cleanup);

test("round 8: moments are picked for variety (one of each kind first), after a strip's lead-up; the first test keeps its 25 % frame", () => {
  const m = [{ kind: "hit", frame: 20 }, { kind: "hit", frame: 120 }, { kind: "hit", frame: 140 }, { kind: "parried", frame: 400 }, { kind: "blocked", frame: 260 }];
  assert.deepEqual(pickMoments(m, 2), [120, 400], "hit then parried (frame 20 has no lead-up)");
  assert.deepEqual(pickMoments(m, 1), [120]);
  assert.deepEqual(pickMoments([], 2), []);
  const plan = [{ id: "core", title: "c", milestone: "blockout" as const, deps: [], scope: ["scripts/main.gd"], contract: "x", acceptance: [{ level: "V4" as const, verb: "bot" as const, args: ["--test=tests/bot_tofu.gd"] }], registers: { tests: ["tests/bot_tofu.gd", "tests/bot_rally.gd"] } }] as PackageSpec[];
  const shots = planShots(plan, [], ["core"], ["tests/bot_rally.gd", "tests/bot_tofu.gd"], () => 600, undefined, (b) => (b === "tests/bot_tofu.gd" ? m : []));
  assert.deepEqual(shots.map((s) => [s.bot, s.frames]), [["tests/bot_rally.gd", [150, 450]], ["tests/bot_tofu.gd", [120, 400]]]);
  const first = planShots(plan, [], ["core"], ["tests/bot_tofu.gd"], () => 600, undefined, () => m);
  assert.deepEqual(first[0]?.frames, [150, 120], "the first test: its 25 % frame stays (the art-pass compare), then its first moment");
});

test("round 8: a job's look films the frames its bot reported (FAKE_METRICS moments through the fake runner)", async () => {
  const job = tempJob("moments-look");
  // Strips on (the fake engine's verbs.json learns --strip): round 9 films a moment as a dense CONTACT strip.
  const { FAKE_VERBS_FILE } = await import("../verbs.js");
  const verbs = JSON.parse(fs.readFileSync(FAKE_VERBS_FILE, "utf8"));
  verbs.verbs.capture.options.strip = { type: "string", default: "" };
  fs.mkdirSync(path.join(job.engineDir, "kernel", "runner"), { recursive: true });
  fs.writeFileSync(path.join(job.engineDir, "kernel", "runner", "verbs.json"), JSON.stringify(verbs, null, 1));
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  const brief = JSON.parse(lines[1] as string) as { brief: Brief };
  brief.brief = { ...v2Brief(), concept: sampleConcept() };
  lines[1] = JSON.stringify(brief);
  const plan = JSON.parse(lines[3] as string) as { packages: PackageSpec[] };
  plan.packages = plan.packages.map((p) => ({ ...p, milestone: "blockout" as const })).map((p) => (p.id === "core" ? { ...p, contract: `${p.contract}\n${tofuLine(undefined, "tests/bot_rally.gd")}`, acceptance: [...p.acceptance, { level: "V4" as const, verb: "bot" as const, args: ["--test=tests/bot_rally.gd", "--frames=1200"] }] } : p));
  lines[3] = JSON.stringify(plan);
  fs.writeFileSync(file, lines.map((l) => l + "\n").join(""));
  const base = scriptWith().steps.find((x) => x.match?.package === "core") as FakeStep;
  const metrics = { feedback_f: 2, skill_spread: 0.4, skill_variants: 3, idle_max_f: 60, tell_min_f: 18, tells: 6, pressure_waves: 3, lead_change_share: 0.5, close_rounds: 2, verbs_used: 2, hand: "regular", moments: { parried: [200], hit: [350, 380] } };
  const core: FakeStep = { ...base, write: { ...(base.write ?? {}), "tests/bot_rally.gd": ((base.write ?? {})["tests/bot_rally.gd"] as string).replace(/# FAKE_METRICS\(.*\)\n/, "") + `# FAKE_METRICS(${JSON.stringify(metrics)})\n` } };
  const { foreman } = foremanFor(job, { promoteTo: "job", script: scriptWith([core]) });
  assert.equal((await foreman.run()).jobState?.state, "done");
  const ms = readEvents(job.jobDir).filter((e) => e.type === "milestone");
  const caps = ms[0]?.type === "milestone" ? ms[0].captures : [];
  assert.ok(caps.some((c) => /blockout-hero-f150\.png$/.test(c)), "the 25 % frame of the first test stays");
  assert.ok(caps.some((c) => /blockout-hero-f200\.png$/.test(c)), `the parried moment is filmed: ${caps.join(", ")}`);
  const strips = ms[0]?.type === "milestone" ? (ms[0].strips ?? []) : [];
  const contact = strips.find((x) => /strip-f190\.png$/.test(x.capture));
  assert.ok(contact, `a strip from 10 frames before the moment: ${strips.map((x) => x.capture).join(", ")}`);
  assert.match(contact?.label ?? "", /^CONTACT \(a moment the bot reported, frame 200; 2 frames apart[^]*frames 190, 192, \.\.\. 212, 2 frames apart/);
  assert.ok(strips.some((x) => /strip-f120\.png$/.test(x.capture) && /5 frames apart/.test(x.label)), "the 25 % frame keeps its ordinary strip");
});
