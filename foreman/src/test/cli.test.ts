import { test, after } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { main, parseArgs, statusTable, UsageError } from "../cli.js";
import { rebuildState } from "../joblog.js";
import { killTree, runProcess } from "../proc.js";
import { cleanup, tempDir, tempJob, readEvents, fixtureScript, fixturePlan, packFiles, FIXTURE } from "./helpers.js";
import { PKG_ROOT } from "../paths.js";
import type { JobEvent } from "../events.js";

after(cleanup);

const CLI = path.join(PKG_ROOT, "dist", "cli.js");
const run = async (argv: string[]): Promise<{ code: number; text: string }> => {
  const lines: string[] = [];
  const code = await main(argv, (s) => lines.push(s));
  return { code, text: lines.join("\n") };
};
const cli = (args: string[], env: NodeJS.ProcessEnv = {}, timeoutMs = 60_000): ReturnType<typeof runProcess> =>
  runProcess({ exe: process.execPath, args: [CLI, ...args], env: { ...process.env, ...env }, timeoutMs });

test("cli: argument parsing", () => {
  const a = parseArgs(["run", "job1", "--adapter", "fake", "--parallel=3", "--quiet"]);
  assert.deepEqual(a, { cmd: "run", pos: ["job1"], flags: { adapter: "fake", parallel: "3", quiet: true } });
  assert.throws(() => parseArgs(["run", "--adapter"]), UsageError);
});

test("cli: `node dist/cli.js run <fixture job> --adapter fake` builds the three packages to promoted against the fake runner", async () => {
  const job = tempJob("cli-run");
  // Exactly the acceptance command, nothing else: the job's own foreman.config.json selects the fake runner and an
  // engine directory inside the job, whatever TL_GODOT and TL_ENGINE_DIR say (here they point at nothing).
  const r = await cli(["run", job.jobDir, "--adapter", "fake"], { TL_GODOT: path.join(job.root, "no-such-godot.exe"), TL_ENGINE_DIR: path.join(job.root, "no-such-engine") });
  assert.equal(r.exitCode, 0, r.stderr + r.stdout);
  job.engineDir = path.join(job.jobDir, "engine-out");
  assert.ok(!fs.existsSync(path.join(job.root, "no-such-engine")));
  assert.match(r.stdout, /job_state\s+done: pack verified V0 to V4 and promoted/);
  assert.match(r.stdout, /core\s+promoted\s+1\s+blockout/);
  assert.match(r.stdout, /paddle_ai\s+promoted\s+2\s+greybox/);
  const s = rebuildState(job.jobDir, { write: false });
  assert.deepEqual(s.order.map((id) => s.packages[id]?.state), ["promoted", "promoted", "promoted"]);
  // WP3c item 8: the default promotion target is the job directory; the engine directory is not touched.
  assert.ok(fs.existsSync(path.join(job.jobDir, "promoted", "game.paddle_court", "pack.json")));
  assert.ok(!fs.existsSync(path.join(job.engineDir, "packs")));
  assert.ok(!fs.existsSync(path.join(job.jobDir, "foreman.lock")), "the lock is released on a clean exit");

  const st = await cli(["status", job.jobDir]);
  assert.equal(st.exitCode, 0);
  assert.match(st.stdout, /package\s+state\s+round\s+milestone\s+runs\s+cause\s+last verify/);
  assert.match(st.stdout, /state\s+done/);
  assert.match(st.stdout, /billing\s+fake none/);
});

test("cli: kill the Foreman process mid-run, then `resume` finishes without redoing completed packages", async () => {
  const job = tempJob("cli-kill");
  const env = { ...process.env, FAKE_RUNNER_DELAY_MS: "150" };
  const args = [CLI, "run", job.jobDir, "--adapter", "fake", "--runner", "fake", "--engine-dir", job.engineDir, "--parallel", "1"];
  const child = spawn(process.execPath, args, { env, stdio: "ignore", windowsHide: true });
  const exited = new Promise<void>((res) => child.on("close", () => res()));
  const has = (evs: JobEvent[], pred: (e: JobEvent) => boolean): boolean => evs.some(pred);
  // Wait until core is promoted and the next package is in flight, then kill the whole tree.
  const deadline = Date.now() + 60_000;
  let seen: JobEvent[] = [];
  for (;;) {
    assert.ok(Date.now() < deadline, "the run never reached the kill point");
    await new Promise((res) => setTimeout(res, 40));
    try {
      seen = readEvents(job.jobDir);
    } catch {
      continue; // a line being written right now
    }
    const corePromoted = has(seen, (e) => e.type === "package_state" && e.package === "core" && e.state === "promoted");
    const courtBuilt = has(seen, (e) => e.type === "builder_run" && e.package === "court");
    if (corePromoted && courtBuilt) break;
  }
  assert.ok(child.pid !== undefined);
  killTree(child.pid as number);
  await exited;
  const atKill = rebuildState(job.jobDir, { write: false });
  assert.notEqual(atKill.jobState?.state, "done", "the run finished before it could be killed");
  assert.equal(atKill.packages["core"]?.state, "promoted");
  assert.ok(["running", "verifying"].includes(atKill.packages["court"]?.state ?? ""), `court was ${atKill.packages["court"]?.state}`);
  assert.ok(fs.existsSync(path.join(job.jobDir, "foreman.lock")), "a killed Foreman leaves its lock behind");
  const killedAt = atKill.lastSeq;
  const dead = await cli(["status", job.jobDir]);
  assert.match(dead.stdout, /foreman\s+NOT running \(pid \d+ is gone: it was killed\); the log stops at event \d+\. Continue with: foreman resume/);

  const r = await cli(["resume", job.jobDir, "--adapter", "fake", "--runner", "fake", "--engine-dir", job.engineDir]);
  assert.equal(r.exitCode, 0, r.stderr + r.stdout);
  const evs = readEvents(job.jobDir);
  const s = rebuildState(job.jobDir, { write: false });
  assert.equal(s.jobState?.state, "done");
  assert.deepEqual(s.order.map((id) => s.packages[id]?.state), ["promoted", "promoted", "promoted"]);
  const runsOf = (pkg: string): number => evs.filter((e) => e.type === "builder_run" && e.package === pkg).length;
  assert.equal(runsOf("core"), 1, "core was promoted before the kill and must not be rebuilt");
  assert.equal(runsOf("court"), 1, "court's builder had already answered ok: only its verification is redone");
  assert.equal(evs.filter((e) => e.seq > killedAt && e.type === "package_state" && e.package === "core").length, 0, "no new state for a promoted package");
  const resumed = evs.find((e) => e.seq > killedAt && e.type === "package_state" && e.package === "court");
  assert.ok(resumed?.type === "package_state" && resumed.round === 1 && /resumed/.test(resumed.detail ?? ""));
  assert.ok(evs.some((e) => e.type === "job_state" && e.seq > killedAt && /resumed/.test(e.reason ?? "")));
  // Same pack as an uninterrupted run.
  const ref = tempJob("cli-ref");
  const refRun = await cli(["run", ref.jobDir, "--adapter", "fake", "--quiet"]);
  assert.equal(refRun.exitCode, 0);
  assert.deepEqual(packFiles(path.join(job.jobDir, "pack")), packFiles(path.join(ref.jobDir, "pack")));
});

test("cli: without a job config the runner comes from TL_GODOT and TL_ENGINE_DIR; an unknown config key is an error", async () => {
  const job = tempJob("cli-env");
  fs.rmSync(path.join(job.jobDir, "foreman.config.json"));
  const r = await cli(["run", job.jobDir, "--adapter", "fake", "--quiet"], { TL_GODOT: path.join(PKG_ROOT, "dist", "testing", "fake-runner.js"), TL_ENGINE_DIR: job.engineDir });
  assert.equal(r.exitCode, 0, r.stderr + r.stdout);
  assert.ok(fs.existsSync(path.join(job.jobDir, "promoted", "game.paddle_court", "pack.json")));
  // A runner that does not exist fails verification (a typed result), it does not crash the Foreman.
  const job2 = tempJob("cli-env2");
  fs.rmSync(path.join(job2.jobDir, "foreman.config.json"));
  // N3: the runner's option list is read from the engine at start, so this stand-in engine needs its verbs.json
  // (without it the run stops before anything is verified: n3.test.ts, item 4).
  fs.mkdirSync(path.join(job2.engineDir, "kernel", "runner"), { recursive: true });
  fs.copyFileSync(path.join(PKG_ROOT, "fixtures", "engine", "kernel", "runner", "verbs.json"), path.join(job2.engineDir, "kernel", "runner", "verbs.json"));
  const bad = await cli(["run", job2.jobDir, "--adapter", "fake", "--round-limit", "1"], { TL_GODOT: path.join(job2.root, "no-such-godot.exe"), TL_ENGINE_DIR: job2.engineDir });
  assert.equal(bad.exitCode, 1);
  assert.match(bad.stdout, /core\s+failed\s+1\s+blockout\s+1\s+verify_failed/);
  const job3 = tempJob("cli-env3");
  fs.writeFileSync(path.join(job3.jobDir, "foreman.config.json"), JSON.stringify({ godot: "@fake", engine: "typo" }));
  const typo = await cli(["run", job3.jobDir, "--adapter", "fake"]);
  assert.equal(typo.exitCode, 2);
  assert.match(typo.stderr, /additional properties "engine"/);
});

test("cli: probe prints adapter, version, auth and billing for the offline adapters without spending anything", async () => {
  const fake = await run(["probe", "--adapter", "fake"]);
  assert.equal(fake.code, 0);
  assert.match(fake.text, /adapter\s+fake/);
  assert.match(fake.text, /version\s+fake-1/);
  assert.match(fake.text, /probe cost\s+0 tokens/);
  const api = await run(["probe", "--adapter", "messages-api", "--api-key-var", "TL_TEST_NO_SUCH_KEY"]);
  assert.equal(api.code, 1);
  assert.match(api.text, /billing\s+api_key/);
  assert.match(api.text, /TL_TEST_NO_SUCH_KEY is not set/);
});

test("cli: new -> approve -> plan -> run, with the Designer and Planner answered by the fake", async () => {
  const root = tempDir("cli-new");
  const site = path.join(root, "site");
  const script = fixtureScript();
  const brief = { rules: "first to 5", arena: "walled court", ai: "follows the ball", controls: "paddle_up, paddle_down", mood: "flat" };
  script.steps.unshift(
    { match: { role: "designer" }, json: { brief, estimate: { packages: 3, wallMinutes: 20, tokens: 150000 } }, tokensIn: 800, tokensOut: 150 },
    { match: { role: "planner" }, json: { packages: fixturePlan() }, tokensIn: 3000, tokensOut: 1200 },
  );
  const scriptFile = path.join(root, "fake.json");
  fs.writeFileSync(scriptFile, JSON.stringify(script));
  const made = await run(["new", "a ball-and-paddle game in a walled court", "--site", site, "--adapter", "fake", "--fake-script", scriptFile]);
  assert.equal(made.code, 0, made.text);
  const jobId = fs.readdirSync(site)[0] as string;
  assert.match(jobId, /^ball-paddle-walled-court-\d{8}-1$/);
  const jobDir = path.join(site, jobId);
  let evs = readEvents(jobDir);
  assert.deepEqual(evs.map((e) => e.type), ["job_created", "billing", "builder_run", "brief_set"]);
  const designerRun = evs[2];
  assert.ok(designerRun?.type === "builder_run" && designerRun.mode === "generate" && designerRun.package === undefined && designerRun.tokensIn === 800);
  assert.equal(evs[0]?.type === "job_created" ? evs[0].packId : "", "game.ball_paddle_walled_court");

  const early = await run(["plan", jobId, "--site", site, "--adapter", "fake", "--fake-script", scriptFile, "--no-reference"]).catch((e: unknown) => e);
  assert.ok(early instanceof UsageError && /not approved/.test(early.message), "no plan before the brief is approved");
  assert.equal((await run(["approve", jobId, "--site", site])).code, 0);
  const planned = await run(["plan", jobId, "--site", site, "--adapter", "fake", "--fake-script", scriptFile, "--no-reference"]);
  assert.equal(planned.code, 0, planned.text);
  evs = readEvents(jobDir);
  assert.deepEqual(evs.slice(4).map((e) => e.type), ["brief_approved", "builder_run", "plan_set", "package_state", "package_state", "package_state"]);

  // A second job on the same day gets the next number.
  await run(["new", "a ball-and-paddle game in a walled court", "--site", site, "--adapter", "fake", "--fake-script", scriptFile, "--auto-approve"]);
  assert.ok(fs.existsSync(path.join(site, jobId.replace(/-1$/, "-2"))));

  const engine = path.join(root, "engine");
  const built = await run(["run", jobId, "--site", site, "--adapter", "fake", "--fake-script", scriptFile, "--runner", "fake", "--engine-dir", engine, "--quiet"]);
  // The fake builder still writes a pack.json with another id (game.paddle_court). It no longer matters: the
  // manifest is composed by the Foreman from the job's own packId, so the job finishes and the pack carries that id.
  assert.equal(built.code, 0, built.text);
  const s = rebuildState(jobDir, { write: false });
  assert.deepEqual(s.order.map((id) => s.packages[id]?.state), ["promoted", "promoted", "promoted"]);
  const manifest = JSON.parse(fs.readFileSync(path.join(jobDir, "pack", "pack.json"), "utf8")) as { id: string; tests: string[] };
  assert.equal(manifest.id, "game.ball_paddle_walled_court");
  assert.deepEqual(manifest.tests, ["tests/bot_rally.gd"]);
  assert.equal(s.promoted?.packId, "game.ball_paddle_walled_court");
});

test("cli: a hand-written plan is validated before it is accepted", async () => {
  const root = tempDir("cli-plan");
  const jobDir = path.join(root, "job");
  fs.mkdirSync(jobDir);
  const first3 = fs.readFileSync(path.join(FIXTURE, "job.jsonl"), "utf8").split("\n").slice(0, 3).join("\n") + "\n";
  fs.writeFileSync(path.join(jobDir, "job.jsonl"), first3);
  const plan = fixturePlan();
  const bad = path.join(root, "bad.json");
  fs.writeFileSync(bad, JSON.stringify({ packages: [{ ...plan[0], deps: ["ghost"] }] }));
  const rejected = await run(["plan", jobDir, "--from", bad]);
  assert.equal(rejected.code, 1);
  assert.match(rejected.text, /depends on unknown "ghost"/);
  assert.equal(readEvents(jobDir).length, 3);
  const good = path.join(root, "good.json");
  fs.writeFileSync(good, JSON.stringify({ packages: plan }));
  assert.equal((await run(["plan", jobDir, "--from", good])).code, 0);
  assert.deepEqual(readEvents(jobDir).slice(3).map((e) => e.type), ["plan_set", "package_state", "package_state", "package_state"]);
});

test("cli: verify <dir> runs the verbs on a pack directory and exits 1 when one fails", async () => {
  const job = tempJob("cli-verify");
  const built = await run(["run", job.jobDir, "--adapter", "fake", "--runner", "fake", "--engine-dir", job.engineDir, "--quiet"]);
  assert.equal(built.code, 0);
  const pack = path.join(job.jobDir, "pack");
  const reports = path.join(job.root, "verify-reports");
  const ok = await run(["verify", pack, "--runner", "fake", "--verbs", "lint,smoke,invariants", "--reports", reports]);
  assert.equal(ok.code, 0, ok.text);
  assert.match(ok.text, /lint\s+V1\s+ok/);
  assert.match(ok.text, /invariants\s+V3\s+ok/);
  fs.appendFileSync(path.join(pack, "scripts", "court.gd"), "\n# FAKE_NONDETERMINISTIC\n");
  const bad = await run(["verify", pack, "--runner", "fake", "--verbs", "lint,smoke,invariants", "--reports", reports]);
  assert.equal(bad.code, 1);
  assert.match(bad.text, /invariants\s+V3\s+FAILED\s+exit=1/);
});

test("cli: cancel marks unfinished packages failed with cause cancelled; a later run does nothing unless asked to retry", async () => {
  const job = tempJob("cli-cancel");
  assert.equal((await run(["cancel", job.jobDir, "--reason", "changed my mind"])).code, 0);
  let s = rebuildState(job.jobDir, { write: false });
  assert.deepEqual([s.jobState?.state, s.jobState?.reason], ["cancelled", "changed my mind"]);
  assert.deepEqual(s.order.map((id) => [s.packages[id]?.state, s.packages[id]?.cause]), [["failed", "cancelled"], ["failed", "cancelled"], ["failed", "cancelled"]]);
  const n = readEvents(job.jobDir).length;
  assert.equal((await run(["run", job.jobDir, "--adapter", "fake", "--quiet"])).code, 1);
  assert.equal(readEvents(job.jobDir).length, n, "a cancelled job is not touched by a plain run");
  assert.equal((await run(["resume", job.jobDir, "--adapter", "fake", "--quiet", "--retry-failed"])).code, 0);
  s = rebuildState(job.jobDir, { write: false });
  assert.equal(s.jobState?.state, "done");
});

test("cli: status renders one dense row per package, with state, round and last cause", () => {
  const job = tempJob("cli-status");
  const s = rebuildState(job.jobDir, { write: false });
  const table = statusTable(s);
  assert.match(table, /state\s+created/);
  assert.equal(table.split("\n").filter((l) => /^(core|court|paddle_ai)\s/.test(l)).length, 3);
});
