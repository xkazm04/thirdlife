import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { FakeBuilder } from "../builder/fake.js";
import { MessagesApiBuilder } from "../builder/messages-api.js";
import { ClaudeCliBuilder, parseEnvelope } from "../builder/claude-cli.js";
import { deriveBashAllowlist, runnerArgv } from "../builder/allowlist.js";
import { extractJson, schemaErrors } from "../builder/json.js";
import { runProcess, resolveExe, type RunProcessRequest, type RunProcessResult, type SpawnFn } from "../proc.js";
import { OUTCOMES } from "../events.js";
import { cleanup, tempDir } from "./helpers.js";
import { PKG_ROOT } from "../paths.js";

after(cleanup);

const schema = { type: "object", additionalProperties: false, required: ["n"], properties: { n: { type: "integer" } } };

// ---------- fake ----------

test("fake: writes the scripted files in edit mode, inside cwd only, and returns the scripted text and tokens", async () => {
  const cwd = tempDir("fake");
  const b = new FakeBuilder({ steps: [{ match: { package: "p" }, write: { "scripts/a.gd": "extends Node\n" }, text: "done", tokensIn: 10, tokensOut: 3 }] });
  const r = await b.run({ prompt: "x", mode: "edit", cwd, timeoutMs: 1000, meta: { package: "p", round: 1 } });
  assert.equal(r.ok, true);
  assert.equal(r.outcome, "ok");
  assert.equal(r.text, "done");
  assert.equal(r.tokensIn, 10);
  assert.equal(r.tokensOut, 3);
  assert.equal(fs.readFileSync(path.join(cwd, "scripts/a.gd"), "utf8"), "extends Node\n");
  // generate mode never writes, whatever the script says
  const cwd2 = tempDir("fake2");
  await b.run({ prompt: "x", mode: "generate", cwd: cwd2, timeoutMs: 1000, meta: { package: "p" } });
  assert.deepEqual(fs.readdirSync(cwd2), []);
  const esc = new FakeBuilder({ steps: [{ write: { "../escape.txt": "x" } }] });
  await assert.rejects(esc.run({ prompt: "x", mode: "edit", cwd, timeoutMs: 1000 }), /escapes cwd/);
});

test("fake: timeout, truncation, error and refusal are typed outcomes, never thrown", async () => {
  const cwd = tempDir("fake3");
  const b = new FakeBuilder({
    steps: [
      { match: { package: "hang" }, hang: true },
      { match: { package: "slow" }, delayMs: 5000 },
      { match: { package: "cut" }, outcome: "truncated", text: "half an ans" },
      { match: { package: "err" }, outcome: "error", error: { kind: "api", message: "boom" } },
      { match: { package: "no" }, outcome: "refused" },
    ],
  });
  const run = (pkg: string, timeoutMs = 60): ReturnType<FakeBuilder["run"]> => b.run({ prompt: "x", mode: "edit", cwd, timeoutMs, meta: { package: pkg } });
  const hang = await run("hang");
  assert.deepEqual([hang.ok, hang.outcome], [false, "timeout"]);
  const slow = await run("slow");
  assert.deepEqual([slow.ok, slow.outcome], [false, "timeout"]);
  const cut = await run("cut");
  assert.deepEqual([cut.ok, cut.outcome, cut.text], [false, "truncated", "half an ans"]);
  const err = await run("err");
  assert.deepEqual([err.ok, err.outcome, err.error?.message], [false, "error", "boom"]);
  const no = await run("no");
  assert.deepEqual([no.ok, no.outcome], [false, "refused"]);
  const unscripted = await run("nobody");
  assert.deepEqual([unscripted.outcome, unscripted.error?.kind], ["error", "config"]);
  const badTimeout = await b.run({ prompt: "x", mode: "edit", cwd, timeoutMs: 0, meta: { package: "err" } });
  assert.deepEqual([badTimeout.outcome, badTimeout.error?.kind], ["error", "config"]);
  for (const r of [hang, slow, cut, err, no, unscripted]) assert.ok((OUTCOMES as readonly string[]).includes(r.outcome));
});

test("fake: an answer is validated against the schema; a cut-off JSON answer is `truncated`, not `error`", async () => {
  const b = new FakeBuilder({
    steps: [
      { match: { role: "good" }, json: { n: 3 } },
      { match: { role: "fenced" }, text: "Here you go:\n```json\n{\"n\": 4}\n```" },
      { match: { role: "wrong" }, json: { n: "three" } },
      { match: { role: "cut" }, text: '{"n": 3, "items": [1, 2' },
      { match: { role: "prose" }, text: "I would rather not." },
    ],
  });
  const run = (role: string): ReturnType<FakeBuilder["run"]> => b.run({ prompt: "x", mode: "generate", cwd: "", schema, timeoutMs: 1000, meta: { role } });
  assert.deepEqual((await run("good")).json, { n: 3 });
  assert.deepEqual((await run("fenced")).json, { n: 4 });
  const wrong = await run("wrong");
  assert.deepEqual([wrong.outcome, wrong.error?.kind], ["error", "schema"]);
  const cut = await run("cut");
  assert.deepEqual([cut.outcome, cut.error?.kind], ["truncated", "parse"]);
  const prose = await run("prose");
  assert.deepEqual([prose.outcome, prose.error?.kind], ["error", "parse"]);
});

test("json helpers: extraction ladder and schema errors", () => {
  assert.deepEqual(extractJson('{"a":1}'), { ok: true, value: { a: 1 } });
  assert.deepEqual(extractJson('noise {"a":{"b":"}"}} trailing'), { ok: true, value: { a: { b: "}" } } });
  assert.equal(extractJson("").ok, false);
  const cut = extractJson('{"a": [1, 2');
  assert.ok(!cut.ok && cut.looksCutOff);
  assert.deepEqual(schemaErrors(schema, { n: 1 }), []);
  assert.match(schemaErrors(schema, { n: 1, m: 2 }).join(), /additional properties "m"/);
});

// ---------- messages-api ----------

test("messages-api: refused with a clear message unless a named key variable is set; never calls out, never shows the key", async () => {
  const secret = "sk-test-DO-NOT-PRINT-123456";
  const none = new MessagesApiBuilder({ env: {} });
  const r1 = await none.run({ prompt: "x", mode: "generate", cwd: "", timeoutMs: 1000 });
  assert.deepEqual([r1.ok, r1.outcome], [false, "refused"]);
  assert.match(r1.error?.message ?? "", /no key variable was named/);
  const unset = new MessagesApiBuilder({ keyVar: "MY_KEY", env: {} });
  const r2 = await unset.run({ prompt: "x", mode: "generate", cwd: "", timeoutMs: 1000 });
  assert.match(r2.error?.message ?? "", /MY_KEY is not set/);
  const set = new MessagesApiBuilder({ keyVar: "MY_KEY", env: { MY_KEY: secret } });
  const r3 = await set.run({ prompt: "x", mode: "generate", cwd: "", timeoutMs: 1000 });
  assert.deepEqual([r3.ok, r3.outcome], [false, "refused"]);
  assert.match(r3.error?.message ?? "", /stub/);
  const p = await set.probe();
  assert.equal(p.billing.mode, "api_key");
  assert.equal(p.ok, false);
  assert.ok(!JSON.stringify([r1, r2, r3, p]).includes(secret), "the key value must never appear in a result");
});

// ---------- allowlist ----------

test("bash allowlist is derived from the package's acceptance commands: one prefix per verb, never a bare launcher", () => {
  const loc = { exe: "C:\\tools\\godot\\Godot_console.exe", preArgs: [], engineDir: "C:\\repo\\engine" };
  const acc = [
    { verb: "lint" as const, args: [] },
    { verb: "smoke" as const, args: ["--seed=1", "--frames=600"] },
    { verb: "bot" as const, args: ["--test=tests/bot_rally.gd"] },
    { verb: "smoke" as const, args: ["--seed=2"] },
  ];
  const d = deriveBashAllowlist(loc, acc, "C:\\site\\j\\ws\\core", "C:\\site\\j\\reports\\self-core");
  assert.equal(d.commands.length, 4);
  assert.equal(d.allow.length, 3, "two smoke entries give one rule");
  for (const rule of d.allow) {
    assert.match(rule, /^Bash\(C:\/tools\/godot\/Godot_console\.exe --headless --path C:\/repo\/engine res:\/\/kernel\/host\/host\.tscn -- (lint|smoke|bot):\*\)$/);
  }
  assert.ok(!d.allow.some((r) => /^Bash\([^ ]+:\*\)$/.test(r)), "no rule may grant the launcher alone");
  assert.ok(!d.allow.some((r) => r.includes("capture")), "a verb that is not in the acceptance list is not granted");
  assert.ok(d.deny.includes("Bash(git:*)"));
  assert.match(d.commands[1] ?? "", /-- smoke --pack=C:\/site\/j\/ws\/core --seed=1 --frames=600 --report=C:\/site\/j\/reports\/self-core\/self-smoke\.json$/);
  // no acceptance, no shell
  assert.deepEqual(deriveBashAllowlist(loc, [], "ws", "r").allow, []);
});

test("bash allowlist: an argument with a shell control operator produces no grant", () => {
  const loc = { exe: "godot", preArgs: [], engineDir: "/e" };
  const d = deriveBashAllowlist(loc, [{ verb: "smoke", args: ["--seed=1; rm -rf /"] }, { verb: "lint", args: ["--x=$(whoami)"] }, { verb: "bot", args: ["--test=a|b"] }], "/ws", "/r");
  assert.deepEqual(d.allow, []);
  assert.deepEqual(d.commands, []);
  assert.equal(d.rejected.length, 3);
});

test("runner argv follows RUNNER.md; every verb, capture included, starts the supervisor --headless", () => {
  const loc = { exe: "node", preArgs: ["fake.js"], engineDir: "/e" };
  assert.deepEqual(runnerArgv(loc, { verb: "lint", args: [] }, "/p", "/r.json"), ["fake.js", "--headless", "--path", "/e", "res://kernel/host/host.tscn", "--", "lint", "--pack=/p", "--report=/r.json"]);
  const cap = runnerArgv(loc, { verb: "capture", args: ["--cam=hero"] }, "/p", "/r.json");
  assert.equal(cap[1], "--headless", "the supervisor opens the capture window itself (kernel API.md section 18)");
  assert.ok(!cap.includes("--position"));
});

// ---------- the spawn door ----------

test("spawn door: our timeout kills the process tree and reports timedOut; no shell is involved", async () => {
  const dir = tempDir("proc");
  const marker = path.join(dir, "grandchild-alive.txt");
  const child = path.join(dir, "child.mjs");
  const grand = path.join(dir, "grand.mjs");
  fs.writeFileSync(grand, `import fs from "node:fs"; setInterval(() => fs.writeFileSync(${JSON.stringify(marker)}, String(Date.now())), 50);`);
  fs.writeFileSync(child, `import { spawn } from "node:child_process"; spawn(process.execPath, [${JSON.stringify(grand)}], { stdio: "ignore" }); console.log("started"); setInterval(() => {}, 1000);`);
  const r = await runProcess({ exe: process.execPath, args: [child], timeoutMs: 1500 });
  assert.equal(r.timedOut, true);
  assert.equal(r.exitCode, undefined);
  assert.match(r.stdout, /started/);
  // The grandchild must be dead too: its heartbeat file stops changing.
  await new Promise((res) => setTimeout(res, 300));
  const before = fs.existsSync(marker) ? fs.readFileSync(marker, "utf8") : "";
  await new Promise((res) => setTimeout(res, 400));
  const afterwards = fs.existsSync(marker) ? fs.readFileSync(marker, "utf8") : "";
  assert.equal(afterwards, before, "the grandchild kept running after the tree kill");
});

test("spawn door: stdin reaches the child, a missing executable is a result not an exception", async () => {
  const echo = await runProcess({ exe: process.execPath, args: ["-e", "process.stdin.pipe(process.stdout)"], stdin: 'quotes " and --flag-shaped text\nline 2', timeoutMs: 10_000 });
  assert.equal(echo.exitCode, 0);
  assert.equal(echo.stdout, 'quotes " and --flag-shaped text\nline 2');
  const missing = await runProcess({ exe: path.join(os.tmpdir(), "no-such-exe-tl.exe"), args: [], timeoutMs: 2000 });
  assert.ok(missing.spawnError);
  assert.equal(resolveExe("definitely-not-a-real-tool-tl"), undefined);
  assert.ok(resolveExe("node"));
});

// ---------- claude-cli (no live calls here: the process is replaced by a recorded envelope) ----------

interface Recorded {
  calls: RunProcessRequest[];
  spawn: SpawnFn;
}
function recorded(answer: (req: RunProcessRequest) => Partial<RunProcessResult>): Recorded {
  const calls: RunProcessRequest[] = [];
  const spawn: SpawnFn = async (req) => {
    calls.push(req);
    if (req.args[0] === "--version") return { exitCode: 0, stdout: "2.1.322 (Claude Code)\n", stderr: "", timedOut: false, outputCapped: false, durationMs: 5 };
    if (req.args[0] === "auth") {
      const key = req.env?.["ANTHROPIC_API_KEY"];
      const body = key ? { loggedIn: true, authMethod: "api_key" } : { loggedIn: true, authMethod: "claude.ai", subscriptionType: "max", email: "someone@example.com" };
      return { exitCode: 0, stdout: JSON.stringify(body), stderr: "", timedOut: false, outputCapped: false, durationMs: 5 };
    }
    return { exitCode: 0, stdout: "", stderr: "", timedOut: false, outputCapped: false, durationMs: 42, ...answer(req) };
  };
  return { calls, spawn };
}
const ndjson = (...events: object[]): string => events.map((e) => JSON.stringify(e)).join("\n") + "\n";
const init = { type: "system", subtype: "init", tools: [], model: "claude-sonnet-x", permissionMode: "default", apiKeySource: "none" };
const okResult = (extra: object = {}): object => ({
  type: "result",
  subtype: "success",
  is_error: false,
  result: "hello",
  stop_reason: "end_turn",
  usage: { input_tokens: 4, cache_creation_input_tokens: 100, cache_read_input_tokens: 2000, output_tokens: 12 },
  ...extra,
});
const fakeBin = process.execPath; // any real executable: it is never started, the spawn function is replaced

test("claude-cli: the prompt travels over stdin and never appears in argv; generate runs in a neutral directory without tools", async () => {
  const rec = recorded(() => ({ stdout: ndjson(init, okResult()) }));
  const b = new ClaudeCliBuilder({ bin: fakeBin, env: {}, spawn: rec.spawn });
  const prompt = 'Say "hi" --dangerously-skip-permissions\nsecond line';
  const cwd = tempDir("gen");
  const r = await b.run({ prompt, mode: "generate", cwd, timeoutMs: 5000, model: "sonnet" });
  assert.equal(r.outcome, "ok");
  assert.equal(r.text, "hello");
  assert.equal(r.tokensIn, 2104);
  assert.equal(r.tokensOut, 12);
  assert.deepEqual(r.observed?.billingMode, "subscription");
  const call = rec.calls[rec.calls.length - 1] as RunProcessRequest;
  assert.equal(call.stdin, prompt);
  assert.ok(!call.args.some((a) => a.includes("Say") || a.includes("second line")), "prompt text found in argv");
  assert.ok(call.args.includes("-p"));
  const tools = call.args[call.args.indexOf("--tools") + 1];
  assert.equal(tools, "", "generate mode must disable every tool");
  assert.notEqual(path.resolve(call.cwd ?? ""), path.resolve(cwd));
  assert.ok((call.cwd ?? "").startsWith(os.tmpdir()), "generate must run in a neutral temp directory");
  assert.ok(!fs.existsSync(call.cwd ?? ""), "the neutral directory is removed afterwards");
  assert.deepEqual(call.args.slice(call.args.indexOf("--model"), call.args.indexOf("--model") + 2), ["--model", "sonnet"]);
  assert.ok(!call.args.includes("--bare"), "--bare would bypass the subscription login");
  assert.ok(!call.args.includes("--dangerously-skip-permissions"));
});

test("claude-cli: the three modes build different argument vectors (separate seams)", async () => {
  const rec = recorded(() => ({ stdout: ndjson(init, okResult()) }));
  const b = new ClaudeCliBuilder({ bin: fakeBin, env: {}, spawn: rec.spawn, allowEdit: true });
  const cwd = tempDir("modes");
  let settings: { permissions: { allow: string[]; deny: string[] } } | undefined;
  const rec2 = recorded((req) => {
    const i = req.args.indexOf("--settings");
    if (i !== -1) settings = JSON.parse(fs.readFileSync(req.args[i + 1] as string, "utf8")) as typeof settings;
    return { stdout: ndjson(init, okResult()) };
  });
  const b2 = new ClaudeCliBuilder({ bin: fakeBin, env: {}, spawn: rec2.spawn, allowEdit: true });
  await b.run({ prompt: "p", mode: "readonly-scan", cwd, timeoutMs: 5000 });
  const scan = rec.calls[rec.calls.length - 1] as RunProcessRequest;
  assert.equal(scan.args[scan.args.indexOf("--tools") + 1], "Read,Glob,Grep");
  assert.equal(path.resolve(scan.cwd ?? ""), path.resolve(cwd));
  assert.ok(!scan.args.includes("acceptEdits"));

  await b2.run({ prompt: "p", mode: "edit", cwd, timeoutMs: 5000 });
  const editNoShell = rec2.calls[rec2.calls.length - 1] as RunProcessRequest;
  assert.equal(editNoShell.args[editNoShell.args.indexOf("--tools") + 1], "Read,Glob,Grep,Edit,Write", "no derived grant, no Bash tool");
  assert.deepEqual(settings?.permissions.allow, []);

  await b2.run({ prompt: "p", mode: "edit", cwd, timeoutMs: 5000, bash: { allow: ["Bash(godot --headless -- lint:*)"], deny: ["Bash(git:*)"] } });
  const edit = rec2.calls[rec2.calls.length - 1] as RunProcessRequest;
  assert.equal(edit.args[edit.args.indexOf("--tools") + 1], "Read,Glob,Grep,Edit,Write,Bash");
  assert.ok(edit.args.includes("--restricted"));
  assert.deepEqual(settings, { permissions: { allow: ["Bash(godot --headless -- lint:*)"], deny: ["Bash(git:*)"] } });
  const settingsPath = edit.args[edit.args.indexOf("--settings") + 1] as string;
  assert.ok(!path.resolve(settingsPath).startsWith(path.resolve(cwd)), "the settings file must live outside the workspace");
  assert.ok(!fs.existsSync(settingsPath), "the per-call settings file is removed afterwards");
  assert.ok(!edit.args.some((a) => a.includes("Bash(godot")), "rules travel in the file, not in argv");
});

test("claude-cli: edit mode without explicit consent is refused before anything is spawned", async () => {
  const rec = recorded(() => ({ stdout: ndjson(init, okResult()) }));
  const b = new ClaudeCliBuilder({ bin: fakeBin, env: {}, spawn: rec.spawn });
  const r = await b.run({ prompt: "p", mode: "edit", cwd: tempDir("consent"), timeoutMs: 5000 });
  assert.deepEqual([r.outcome, r.error?.kind], ["refused", "permission"]);
  assert.equal(rec.calls.length, 0);
});

test("claude-cli: our timeout is a typed `timeout`, with whatever text had arrived", async () => {
  const rec = recorded(() => ({ timedOut: true, exitCode: undefined, stdout: ndjson(init, { type: "assistant", message: { content: [{ type: "text", text: "partial" }] } }) }));
  const b = new ClaudeCliBuilder({ bin: fakeBin, env: {}, spawn: rec.spawn });
  const r = await b.run({ prompt: "p", mode: "generate", cwd: "", timeoutMs: 10 });
  assert.deepEqual([r.ok, r.outcome, r.text], [false, "timeout", "partial"]);
  const call = rec.calls[rec.calls.length - 1] as RunProcessRequest;
  assert.equal(call.timeoutMs, 1000, "a tiny timeout is floored, never turned into no timeout");
  const zero = await b.run({ prompt: "p", mode: "generate", cwd: "", timeoutMs: 0 });
  assert.deepEqual([zero.outcome, zero.error?.kind], ["error", "config"]);
});

test("claude-cli: truncation is its own outcome (max_tokens, a stream without a result, a cut-off JSON answer, a turn cap)", async () => {
  const cases: [string, string][] = [
    ["max_tokens", ndjson(init, okResult({ stop_reason: "max_tokens", result: "half an ans" }))],
    ["no result", ndjson(init, { type: "assistant", message: { content: [{ type: "text", text: "half" }] } })],
    ["cut json", ndjson(init, okResult({ result: '{"n": 1, "list": [1, 2' }))],
    ["turn cap", ndjson(init, { type: "result", subtype: "error_max_turns", is_error: true, result: "" })],
  ];
  for (const [name, stdout] of cases) {
    const rec = recorded(() => ({ stdout }));
    const b = new ClaudeCliBuilder({ bin: fakeBin, env: {}, spawn: rec.spawn });
    const r = await b.run({ prompt: "p", mode: "generate", cwd: "", timeoutMs: 5000, ...(name === "cut json" ? { schema } : {}) });
    assert.deepEqual([name, r.ok, r.outcome], [name, false, "truncated"]);
  }
});

test("claude-cli: errors keep the tool's classification (rate limit, auth, plain failure, schema violation, refusal)", async () => {
  const run = async (stdout: string, extra: Partial<RunProcessResult> = {}, withSchema = false): Promise<Awaited<ReturnType<ClaudeCliBuilder["run"]>>> => {
    const rec = recorded(() => ({ stdout, ...extra }));
    const b = new ClaudeCliBuilder({ bin: fakeBin, env: {}, spawn: rec.spawn });
    return b.run({ prompt: "p", mode: "generate", cwd: "", timeoutMs: 5000, ...(withSchema ? { schema } : {}) });
  };
  const rate = await run(ndjson(init, { type: "result", subtype: "success", is_error: true, result: "Claude AI usage limit reached|1794300000" }), { exitCode: 1 });
  assert.deepEqual([rate.outcome, rate.error?.kind], ["error", "rate_limit"]);
  const auth = await run("", { exitCode: 1, stderr: "Not logged in · Please run /login" });
  assert.deepEqual([auth.outcome, auth.error?.kind], ["refused", "auth"]);
  const crash = await run("Segmentation fault", { exitCode: 139 });
  assert.deepEqual([crash.outcome, crash.error?.kind], ["error", "exit"]);
  const wrong = await run(ndjson(init, okResult({ result: '{"n":"x"}' })), {}, true);
  assert.deepEqual([wrong.outcome, wrong.error?.kind], ["error", "schema"]);
  const structured = await run(ndjson(init, okResult({ result: "see structured output", structured_output: { n: 7 } })), {}, true);
  assert.deepEqual([structured.outcome, structured.json], ["ok", { n: 7 }]);
  const refusal = await run(ndjson(init, okResult({ stop_reason: "refusal", result: "" })));
  assert.deepEqual([refusal.outcome, refusal.error?.kind], ["refused", "refusal"]);
  const spawnFail = await run("", { spawnError: "ENOENT" });
  assert.deepEqual([spawnFail.outcome, spawnFail.error?.kind], ["error", "spawn"]);
});

test("claude-cli: envelope dialects (event lines with noise, one object, an array) all parse", () => {
  assert.equal(parseEnvelope(`warning: something\n${JSON.stringify(init)}\n${JSON.stringify(okResult())}\n`).events.length, 2);
  assert.equal(parseEnvelope(`warning: something\n${JSON.stringify(init)}\n`).noiseLines, 1);
  assert.equal(parseEnvelope(JSON.stringify(okResult())).events.length, 1);
  assert.equal(parseEnvelope(JSON.stringify([init, okResult()])).events.length, 2);
});

test("claude-cli probe: billing follows the real environment, evidence names the variable and never its value", async () => {
  const secret = "sk-ant-NEVER-SHOW-THIS-0000";
  const sub = new ClaudeCliBuilder({ bin: fakeBin, env: { PATH: process.env["PATH"] }, spawn: recorded(() => ({})).spawn });
  const p1 = await sub.probe();
  assert.deepEqual([p1.ok, p1.installed, p1.version, p1.authorized, p1.billing.mode, p1.zeroCost], [true, true, "2.1.322", true, "subscription", true]);
  assert.match(p1.billing.evidence, /authMethod=claude\.ai/);
  assert.ok(!JSON.stringify(p1).includes("someone@example.com"), "identity fields of auth status are not kept");

  const recKey = recorded(() => ({}));
  const keyed = new ClaudeCliBuilder({ bin: fakeBin, env: { ANTHROPIC_API_KEY: secret }, spawn: recKey.spawn });
  const p2 = await keyed.probe();
  assert.equal(p2.billing.mode, "api_key");
  assert.match(p2.billing.evidence, /ANTHROPIC_API_KEY is set/);
  assert.ok(!JSON.stringify(p2).includes(secret), "the key value must never appear");
  assert.equal(recKey.calls.every((c) => c.env?.["ANTHROPIC_API_KEY"] === secret), true, "the probe uses the same environment as a run");

  // Forced subscription: the metering variable is removed at the one spawn door, for the probe and for runs alike.
  const recStrip = recorded(() => ({ stdout: ndjson(init, okResult()) }));
  const stripped = new ClaudeCliBuilder({ bin: fakeBin, env: { ANTHROPIC_API_KEY: secret }, spawn: recStrip.spawn, billing: "subscription" });
  const p3 = await stripped.probe();
  assert.equal(p3.billing.mode, "subscription");
  assert.match(p3.billing.evidence, /removed from the child environment by the Foreman: ANTHROPIC_API_KEY/);
  await stripped.run({ prompt: "p", mode: "generate", cwd: "", timeoutMs: 5000 });
  assert.ok(recStrip.calls.every((c) => c.env?.["ANTHROPIC_API_KEY"] === undefined));

  const missing = new ClaudeCliBuilder({ bin: path.join(os.tmpdir(), "no-claude-here.exe"), env: {} });
  const p4 = await missing.probe();
  assert.deepEqual([p4.ok, p4.installed], [false, false]);
  const r = await missing.run({ prompt: "p", mode: "generate", cwd: "", timeoutMs: 5000 });
  assert.deepEqual([r.outcome, r.error?.kind], ["refused", "not_available"]);
});

test("capability matrix is dated data with an entry per adapter", () => {
  const doc = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "data", "capabilities.json"), "utf8")) as { adapters: Record<string, { version: string; observedOn: string }[]> };
  for (const name of ["claude-cli", "messages-api", "fake"]) {
    const entries = doc.adapters[name] ?? [];
    assert.ok(entries.length > 0, `${name} has no entry`);
    for (const e of entries) assert.match(e.observedOn, /^\d{4}-\d{2}-\d{2}$/);
  }
});
