// Shared test scaffolding. Everything runs in temp directories; nothing touches site/ or engine/.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { copyFixture } from "../cli.js";
import { FakeBuilder, type FakeScript, type FakeStep } from "../builder/fake.js";
import { Verifier } from "../verifier.js";
import { inProcessFakeRunner } from "../testing/fake-runner-core.js";
import { Foreman, type ForemanOptions } from "../foreman.js";
import { PKG_ROOT, FAKE_RUNNER } from "../paths.js";
import type { Aspect, Brief, JobEvent, PackageSpec, Phase } from "../events.js";
import { FAKE_VERBS_FILE, readVerbsFile } from "../verbs.js";

/** The verbs of the fake runner (fixtures/engine/kernel/runner/verbs.json): what plan checks in tests are given. */
export const VERBS = readVerbsFile(FAKE_VERBS_FILE);

export const FIXTURE = path.join(PKG_ROOT, "fixtures", "job-paddle");
export { FAKE_RUNNER };

const made: string[] = [];

export function tempDir(label = "t"): string {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), `tl-foreman-${label}-`));
  made.push(d);
  return d;
}

export function cleanup(): void {
  for (const d of made.splice(0)) fs.rmSync(d, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
}

export interface TempJob {
  root: string;
  jobDir: string;
  engineDir: string;
}

/** A fresh copy of the three-package fixture job, with an empty stand-in engine directory beside it. */
export function tempJob(label = "job"): TempJob {
  const root = tempDir(label);
  const jobDir = path.join(root, "site", "paddle-court-20261110-1");
  copyFixture(jobDir);
  const engineDir = path.join(root, "engine");
  fs.mkdirSync(engineDir, { recursive: true });
  return { root, jobDir, engineDir };
}

export function fixtureScript(): FakeScript {
  return JSON.parse(fs.readFileSync(path.join(FIXTURE, "fake-builder.json"), "utf8")) as FakeScript;
}

/** The fixture's script with extra steps placed first (first match wins) and no artificial delays. */
export function scriptWith(first: FakeStep[] = [], keepDelays = false): FakeScript {
  const base = fixtureScript();
  const steps = [...first, ...base.steps].map((s) => (keepDelays ? s : { ...s, delayMs: 0 }));
  return { ...base, steps };
}

/** A verifier whose runner is the fake one, called in-process (fast). */
export function fastVerifier(engineDir: string, env: NodeJS.ProcessEnv = {}): Verifier {
  return new Verifier({ godot: FAKE_RUNNER, engineDir, spawn: inProcessFakeRunner(env), timeoutMs: 300 });
}

/** A verifier that really spawns the fake runner as a process, exactly as TL_GODOT would be. */
export function processVerifier(engineDir: string, env: NodeJS.ProcessEnv = {}, timeoutMs = 20_000): Verifier {
  return new Verifier({ godot: FAKE_RUNNER, engineDir, env: { ...process.env, ...env }, timeoutMs });
}

export function foremanFor(job: TempJob, opts: Partial<ForemanOptions> & { script?: FakeScript } = {}): { foreman: Foreman; builder: FakeBuilder } {
  const { script, ...rest } = opts;
  const builder = (rest.builder as FakeBuilder | undefined) ?? new FakeBuilder(script ?? scriptWith());
  const foreman = new Foreman({
    jobDir: job.jobDir,
    builder,
    verifier: fastVerifier(job.engineDir),
    parallel: 1,
    builderTimeoutMs: 2000,
    packContract: "(pack contract omitted in tests)",
    // The older tests count builder runs and events of the package loop alone: the V5 critic and the re-plan are
    // off unless a test asks for them (wp3b.test.ts does).
    critic: false,
    maxReplans: 0,
    // The older tests look for the promoted pack in the stand-in engine directory; the default since WP3c is the
    // job directory (wp3c.test.ts, item 8).
    promoteTo: "engine",
    ...rest,
  });
  return { foreman, builder };
}

export function readEvents(jobDir: string): JobEvent[] {
  return fs
    .readFileSync(path.join(jobDir, "job.jsonl"), "utf8")
    .split("\n")
    .filter((l) => l.length > 0)
    .map((l) => JSON.parse(l) as JobEvent);
}

export function fixturePlan(): PackageSpec[] {
  const ev = readEvents(FIXTURE).find((e) => e.type === "plan_set");
  if (!ev || ev.type !== "plan_set") throw new Error("fixture has no plan_set");
  return ev.packages;
}

/** JOB.md 2026-11-20: the fixture plan's phases (the court plays first, the rival paddle second). */
export function fixturePhases(): Phase[] {
  return [
    { id: "court_plays", title: "The court plays", try: "Rally the ball off the walls with your paddle", packages: ["core", "court"] },
    { id: "rival", title: "A rival paddle", try: "Beat a rival paddle that chases the ball", packages: ["paddle_ai"] },
  ];
}

/**
 * A v2 brief (JOB.md 2026-11-20): the fixture's five fields plus a pitch and three aspect cards, as every v2 Designer
 * writes it. `crazy`: one aspect carries `crazy: true` (a crazy job's brief).
 */
export function v2Brief(crazy = false): Brief {
  const ev = readEvents(FIXTURE).find((e) => e.type === "brief_set");
  if (!ev || ev.type !== "brief_set") throw new Error("fixture has no brief_set");
  const aspects: Aspect[] = [
    { id: "paddle", icon: "player", title: "Your paddle", line: "Slide along your goal and slap the ball back", detail: "paddle_up and paddle_down; a return speeds the ball up a little", alternatives: [{ id: "two_paddles", title: "Two paddles", line: "Steer a front and a back paddle at once" }, { id: "spinner", title: "A spinning bat", line: "Spin to whack the ball at an angle" }] },
    { id: "rival", icon: "rival", title: "Rival Rex", line: "A greedy paddle that lunges at every ball", detail: "TLSteer.intercept_point with a reaction delay; lunges leave his corner open", alternatives: [{ id: "twin_rivals", title: "Twin rivals", line: "Two small paddles share the far goal" }, { id: "wall_bot", title: "The wall", line: "No rival: beat your own best rally" }] },
    { id: "court", icon: "arena", title: "Walled court", line: "Walls bounce the ball, goals behind each end", detail: "16 m by 9 m, walls on the long sides, a kit rink floor for a fast slide", alternatives: [{ id: "ice_court", title: "Ice court", line: "Everything slides faster on ice" }, { id: "round_court", title: "Round court", line: "A ring with four goals" }] },
  ];
  if (crazy) aspects.push({ id: "magnet_ball", icon: "twist", title: "Magnet ball", line: "Every tenth hit the ball sticks to a wall", detail: "a timer in the pack holds the ball for 60 frames on the wall it hits, then releases it fast", alternatives: [{ id: "split_ball", title: "Splitting ball", line: "A hard hit splits the ball in two" }, { id: "gravity_flip", title: "Tilting court", line: "The court tilts toward the leader" }], crazy: true });
  return { ...ev.brief, pitch: "Slap a speeding ball past Rival Rex on a walled court; first to five wins.", aspects };
}

export function packFiles(dir: string): Record<string, string> {
  const out: Record<string, string> = {};
  const walk = (rel: string): void => {
    for (const e of fs.readdirSync(path.join(dir, rel), { withFileTypes: true })) {
      const r = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory()) walk(r);
      else out[r] = fs.readFileSync(path.join(dir, r), "utf8");
    }
  };
  if (fs.existsSync(dir)) walk("");
  return out;
}

export class Kill extends Error {
  constructor(public readonly atSeq: number) {
    super(`simulated kill after event ${atSeq}`);
    this.name = "Kill";
  }
}
