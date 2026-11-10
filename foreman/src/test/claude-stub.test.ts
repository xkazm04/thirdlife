// The claude-cli adapter through the REAL spawn door (process, stdin, argv, kill), against a stand-in executable
// that speaks the dialect recorded from Claude Code 2.1.322. No network, no tokens.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { ClaudeCliBuilder } from "../builder/claude-cli.js";
import { Foreman } from "../foreman.js";
import { cleanup, tempDir, tempJob, fixtureScript, fastVerifier, readEvents, packFiles, foremanFor } from "./helpers.js";
import { PKG_ROOT, FAKE_RUNNER } from "../paths.js";

after(cleanup);

const FAKE_CLAUDE = path.join(PKG_ROOT, "dist", "testing", "fake-claude.js");

interface StubCall {
  argv: string[];
  cwd: string;
  promptSha1: string;
  promptLength: number;
  settings?: { permissions: { allow: string[]; deny: string[] } };
  keyPresent: boolean;
}

function stub(steps: object[], extraEnv: NodeJS.ProcessEnv = {}): { env: NodeJS.ProcessEnv; calls: () => StubCall[] } {
  const dir = tempDir("stub");
  const script = path.join(dir, "script.json");
  const log = path.join(dir, "calls.jsonl");
  fs.writeFileSync(script, JSON.stringify({ steps }));
  // The environment a child would really get, minus anything that would bill: the stand-in needs none of it.
  const env: NodeJS.ProcessEnv = { PATH: process.env["PATH"], SystemRoot: process.env["SystemRoot"], TEMP: process.env["TEMP"], TMP: process.env["TMP"], FAKE_CLAUDE_SCRIPT: script, FAKE_CLAUDE_LOG: log, ...extraEnv };
  return {
    env,
    calls: () => (fs.existsSync(log) ? fs.readFileSync(log, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l) as StubCall) : []),
  };
}

/** The fixture's fake-builder script, re-keyed on what a real CLI can see: the prompt text. */
function stepsFromFixture(): object[] {
  return fixtureScript().steps.map((s) => ({
    all: [`# Your package: ${s.match?.package} (`, ...(s.match?.round !== undefined ? [`# Round ${s.match.round} of`] : [])],
    write: s.write,
    text: s.text,
    tokensIn: s.tokensIn,
    tokensOut: s.tokensOut,
  }));
}

test("claude-cli through a real process: probe, then a generate run whose prompt arrives intact over stdin", async () => {
  const s = stub([{ all: ["capital"], json: { capital: "Paris" }, tokensIn: 2713, tokensOut: 54 }]);
  const b = new ClaudeCliBuilder({ bin: FAKE_CLAUDE, env: s.env });
  const p = await b.probe();
  assert.deepEqual([p.ok, p.installed, p.version, p.authorized, p.billing.mode], [true, true, "2.1.322", true, "subscription"]);
  const prompt = 'Name the capital of France as {"capital": "<name>"}.\n--dangerously-skip-permissions "quoted" %PATH% $HOME `backticks` čeština\n';
  const schema = { type: "object", additionalProperties: false, required: ["capital"], properties: { capital: { type: "string" } } };
  const r = await b.run({ prompt, mode: "generate", cwd: "", schema, timeoutMs: 20_000, model: "sonnet" });
  assert.deepEqual([r.ok, r.outcome, r.json, r.tokensIn, r.tokensOut], [true, "ok", { capital: "Paris" }, 2715, 54]);
  assert.deepEqual(r.observed?.tools, ["StructuredOutput"]);
  const call = s.calls()[0] as StubCall;
  assert.equal(call.promptSha1, crypto.createHash("sha1").update(prompt).digest("hex"), "the prompt was altered on its way to the child");
  assert.ok(!call.argv.join(" ").includes("capital of France"), "prompt text in argv");
  assert.equal(call.argv[call.argv.indexOf("--tools") + 1], "", "an empty --tools value must survive Windows argument quoting");
  assert.deepEqual(JSON.parse(call.argv[call.argv.indexOf("--json-schema") + 1] ?? "null"), schema, "the schema must survive Windows argument quoting");
  assert.notEqual(path.resolve(call.cwd), path.resolve(process.cwd()));
});

test("hideEnv: variables that have nothing to do with the build never reach the child, in the probe or in a run", async () => {
  const secret = "sk-other-project-NEVER-SHOW-9999";
  const s = stub([{ all: [], text: "hi" }], { ANTHROPIC_API_KEY: secret, OTHER_LANE_KEY_A: secret, other_lane_key_b: secret, KEEP_ME: "visible" });
  const seen: NodeJS.ProcessEnv[] = [];
  const { runProcess } = await import("../proc.js");
  const b = new ClaudeCliBuilder({
    bin: FAKE_CLAUDE,
    env: s.env,
    hideEnv: ["ANTHROPIC_API_KEY", "OTHER_LANE_KEY_*"],
    spawn: (req) => {
      seen.push(req.env ?? {});
      return runProcess(req);
    },
  });
  const p = await b.probe();
  // With the key hidden the stand-in reports a subscription login, exactly as the real CLI would decide from its env.
  assert.equal(p.billing.mode, "subscription");
  assert.match(p.notes.join(" "), /3 environment variable\(s\) matching ANTHROPIC_API_KEY, OTHER_LANE_KEY_\* are hidden from the CLI/);
  const r = await b.run({ prompt: "hello", mode: "generate", cwd: "", timeoutMs: 20_000 });
  assert.equal(r.outcome, "ok");
  assert.equal(r.observed?.apiKeySource, "none");
  assert.equal(s.calls()[0]?.keyPresent, false);
  assert.equal(seen.length, 3);
  for (const env of seen) {
    assert.ok(!Object.values(env).includes(secret), "a hidden value reached the child environment");
    assert.equal(env["KEEP_ME"], "visible");
  }
  assert.ok(!JSON.stringify([p, r]).includes(secret));
});

test("claude-cli through a real process: a hung CLI is killed on our timeout and reported as `timeout`", async () => {
  const s = stub([{ all: [], hang: true }]);
  const b = new ClaudeCliBuilder({ bin: FAKE_CLAUDE, env: s.env });
  const t0 = Date.now();
  const r = await b.run({ prompt: "anything", mode: "generate", cwd: "", timeoutMs: 1500 });
  assert.deepEqual([r.ok, r.outcome], [false, "timeout"]);
  assert.ok(Date.now() - t0 < 12_000);
  assert.deepEqual(r.observed?.tools, [], "the init event that arrived before the kill is kept");
});

test("claude-cli through a real process: not logged in is `refused`, an error result is `error`, a cut answer is `truncated`", async () => {
  const out = stub([], { FAKE_CLAUDE_AUTH: "none" });
  const notIn = new ClaudeCliBuilder({ bin: FAKE_CLAUDE, env: out.env });
  const p = await notIn.probe();
  assert.deepEqual([p.ok, p.authorized], [false, false]);
  const r = await notIn.run({ prompt: "x", mode: "generate", cwd: "", timeoutMs: 10_000 });
  assert.deepEqual([r.outcome, r.error?.kind], ["refused", "auth"]);
  assert.equal(out.calls().length, 0, "nothing is sent when the probe says not authorized");

  const s = stub([
    { all: ["limit"], isError: true, text: "Claude AI usage limit reached|1794352800" },
    { all: ["cut"], stopReason: "max_tokens", text: "half an ans" },
  ]);
  const b = new ClaudeCliBuilder({ bin: FAKE_CLAUDE, env: s.env });
  const limited = await b.run({ prompt: "limit", mode: "generate", cwd: "", timeoutMs: 10_000 });
  assert.deepEqual([limited.outcome, limited.error?.kind], ["error", "rate_limit"]);
  assert.ok((limited.error?.retryAfterMs ?? -1) >= 0, "the reset time from the rate limit event is carried");
  const cut = await b.run({ prompt: "cut", mode: "generate", cwd: "", timeoutMs: 10_000 });
  assert.deepEqual([cut.outcome, cut.text], ["truncated", "half an ans"]);
});

test("Foreman + claude-cli adapter (stand-in CLI) builds the fixture: edit mode in ws/, derived shell grants, tokens and billing in the log", async () => {
  const job = tempJob("stub-job");
  const s = stub(stepsFromFixture());
  const builder = new ClaudeCliBuilder({ bin: FAKE_CLAUDE, env: s.env, allowEdit: true });
  const foreman = new Foreman({ jobDir: job.jobDir, builder, verifier: fastVerifier(job.engineDir), parallel: 2, builderTimeoutMs: 30_000, model: "sonnet", critic: false });
  const state = await foreman.run();
  assert.equal(state.jobState?.state, "done", JSON.stringify(state.jobState));
  assert.deepEqual(state.order.map((id) => [state.packages[id]?.state, state.packages[id]?.round]), [["promoted", 1], ["promoted", 1], ["promoted", 2]]);
  // Same pack as the in-process fake builder produces.
  const ref = tempJob("stub-ref");
  await foremanFor(ref).foreman.run();
  assert.deepEqual(packFiles(path.join(job.jobDir, "pack")), packFiles(path.join(ref.jobDir, "pack")));

  const evs = readEvents(job.jobDir);
  const billing = evs.filter((e) => e.type === "billing");
  assert.equal(billing.length, 1);
  assert.ok(billing[0]?.type === "billing" && billing[0].adapter === "claude-cli" && billing[0].mode === "subscription");
  const runs = evs.filter((e) => e.type === "builder_run");
  assert.equal(runs.length, 4);
  for (const r of runs) assert.ok(r.type === "builder_run" && r.adapter === "claude-cli" && r.mode === "edit" && r.model === "sonnet" && r.outcome === "ok" && (r.tokensIn ?? 0) > 4000);
  assert.equal(state.tokens.in, 5202 + 4102 + 4302 + 5002);

  const calls = s.calls();
  assert.equal(calls.length, 4);
  for (const c of calls) {
    // Each builder ran inside its own package workspace and nowhere else.
    assert.match(c.cwd.replace(/\\/g, "/"), /\/ws\/(core|court|paddle_ai)$/);
    // The shell is granted, and only for the runner calls this package's acceptance needs.
    assert.equal(c.argv[c.argv.indexOf("--tools") + 1], "Read,Glob,Grep,Edit,Write,Bash");
    assert.ok(c.argv.includes("--restricted") && c.argv.includes("--safe-mode"));
    assert.equal(c.argv[c.argv.indexOf("--permission-mode") + 1], "acceptEdits");
    assert.equal(c.argv[c.argv.indexOf("--permission-prompts") + 1], "none");
    const allow = c.settings?.permissions.allow ?? [];
    assert.ok(allow.length >= 2);
    const runner = FAKE_RUNNER.replace(/\\/g, "/");
    for (const rule of allow) {
      assert.ok(rule.startsWith("Bash(") && rule.includes(runner) && /-- (lint|smoke|bot):\*\)$/.test(rule), rule);
    }
    assert.ok(c.settings?.permissions.deny.includes("Bash(git:*)"));
  }
  const ai = calls.filter((c) => /paddle_ai$/.test(c.cwd.replace(/\\/g, "/")));
  assert.ok((ai[0]?.settings?.permissions.allow ?? []).some((r) => r.includes("-- bot:*")), "paddle_ai's acceptance has a bot run, so its builder may run it");
  const core = calls.find((c) => /core$/.test(c.cwd.replace(/\\/g, "/")));
  assert.ok(!(core?.settings?.permissions.allow ?? []).some((r) => r.includes("-- bot:*")), "core's acceptance has no bot run, so its builder may not");
  // Transcripts keep the full envelope.
  const t = JSON.parse(fs.readFileSync(path.join(job.jobDir, runs[0]?.type === "builder_run" ? (runs[0].transcript ?? "") : ""), "utf8")) as { raw: { events: { type: string }[] }; prompt: string };
  assert.ok(t.raw.events.some((e) => e.type === "result"));
  assert.match(t.prompt, /You may run exactly these commands yourself/);
});

test("a run whose own init event contradicts the probe's billing is logged at once as a new billing event", async () => {
  const job = tempJob("stub-billing");
  // The probe sees a subscription login; the child then reports that a key decided its auth.
  const s = stub(stepsFromFixture(), { FAKE_CLAUDE_AUTHSOURCE: "ANTHROPIC_API_KEY" });
  const builder = new ClaudeCliBuilder({ bin: FAKE_CLAUDE, env: s.env, allowEdit: true });
  const state = await new Foreman({ jobDir: job.jobDir, builder, verifier: fastVerifier(job.engineDir), parallel: 1, builderTimeoutMs: 30_000, critic: false }).run();
  assert.equal(state.jobState?.state, "done");
  const evs = readEvents(job.jobDir);
  const billing = evs.filter((e) => e.type === "billing");
  assert.deepEqual(billing.map((e) => (e.type === "billing" ? e.mode : "")), ["subscription", "api_key"]);
  assert.match(billing[1]?.type === "billing" ? billing[1].evidence : "", /apiKeySource=ANTHROPIC_API_KEY, which contradicts the probe/);
  const firstRun = evs.find((e) => e.type === "builder_run");
  assert.equal(billing[1]?.seq, (firstRun?.seq ?? 0) + 1, "the contradiction is logged right after the first run that showed it");
  assert.equal(state.billing?.mode, "api_key");
});

test("edit mode without consent: the Foreman's package fails with builder_error and nothing is spawned for it", async () => {
  const job = tempJob("stub-consent");
  const s = stub(stepsFromFixture());
  const builder = new ClaudeCliBuilder({ bin: FAKE_CLAUDE, env: s.env });
  const state = await new Foreman({ jobDir: job.jobDir, builder, verifier: fastVerifier(job.engineDir), builderTimeoutMs: 30_000, maxReplans: 0 }).run();
  assert.equal(state.jobState?.state, "failed");
  assert.deepEqual([state.packages["core"]?.state, state.packages["core"]?.cause], ["failed", "builder_error"]);
  assert.match(state.packages["core"]?.detail ?? "", /explicit consent/);
  assert.equal(s.calls().length, 0);
});
