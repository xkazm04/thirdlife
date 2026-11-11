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
import type { JobEvent, PackageSpec } from "../events.js";
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
