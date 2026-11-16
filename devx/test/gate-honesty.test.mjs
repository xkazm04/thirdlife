// T2 (jam-lessons-home): a gate that cannot pass by stopping. One test per false-pass path in docs/GATE-HONESTY.md.
// Every lib module is loaded with a relative dynamic import, so this same file run beside a copy of the OLD devx/lib shows each
// test failing before the cure (the "before" run is in status/T2.md).
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const lib = (p) => import(new URL(`../lib/${p}`, import.meta.url).href);
const tmp = (tag) => fs.mkdtempSync(path.join(os.tmpdir(), `tl_hon_${tag}_`));

async function gate(args, steps, ctx) {
  const { execute } = await lib("commands/check.mjs");
  const lines = [];
  const orig = console.log; console.log = (...a) => lines.push(a.join(" "));
  const origErr = console.error; console.error = () => {};
  let exit; try { exit = await execute(args, { steps, historyFile: null, ctx, disk: () => ({ line: "disk: test", free_gb: 100, floor_gb: 20, low: false }) }); }
  finally { console.log = orig; console.error = origErr; }
  return { exit, lines, json: JSON.parse(lines.at(-1)) };
}
const fake = (id, run) => ({ id, tiers: ["fast", "full"], paths: [`${id}/**`], run });
async function fakeCtx(over = {}) {
  const real = await lib("ctx.mjs");
  const repo = tmp("repo");
  return { ...real, REPO: repo, ENGINE: path.join(repo, "engine"), FOREMAN: path.join(repo, "foreman"), resolveGodot: () => "godot.exe", ...over };
}
const stepOf = async (file, id) => { const m = await lib(`gate/steps/${file}`); return m.steps ? { ...m.steps.find((s) => s.id === id), file } : { id: m.id, tiers: m.tiers, paths: m.paths, run: m.run, file }; };

test("engine: a step that says ok but completed fewer units than it found is a FAIL", async () => {
  const { exit, json } = await gate([], [fake("partial", async () => ({ ok: true, found: 373, completed: 214, detail: "214 pass" }))], await fakeCtx());
  assert.equal(exit, 1);
  assert.equal(json.steps[0].ok, false);
  assert.match(json.steps[0].detail, /completed 214 of 373/);
});

test("engine: a step that found zero units is a FAIL", async () => {
  const { exit, json } = await gate([], [fake("empty", async () => ({ ok: true, found: 0, completed: 0 }))], await fakeCtx());
  assert.equal(exit, 1); assert.match(json.steps[0].detail, /found 0/);
});

test("engine: a step that could not run makes the gate exit 2, never 0 and never a PASS line", async () => {
  const { exit, lines, json } = await gate([], [fake("good", async () => ({ ok: true, found: 1, completed: 1 })), fake("absent", async () => ({ ok: false, notRun: true, detail: "no Godot" }))], await fakeCtx());
  assert.equal(exit, 2);
  assert.ok(!lines.some((l) => l.startsWith("PASS") && l.includes("absent")));
  assert.deepEqual(json.not_run, ["absent"]);
  assert.match(json.steps.find((s) => s.id === "absent").detail, /^could not run/);
});

test("engine: a gate with zero steps selected is a FAIL (nothing was checked); --changed with no change still passes with its note", async () => {
  const none = await gate(["--tier", "fast"], [{ id: "fullonly", tiers: ["full"], paths: ["x/**"], run: async () => ({ ok: true }) }], await fakeCtx());
  assert.equal(none.exit, 1);
  const { execute } = await lib("commands/check.mjs");
  const o = console.log, e = console.error; const lines = []; console.log = (...a) => lines.push(a.join(" ")); console.error = () => {};
  let exit; try { exit = await execute(["--changed"], { steps: [fake("a", async () => ({ ok: true }))], historyFile: null, ctx: await fakeCtx(), git: () => "", disk: () => ({ line: "disk: test" }) }); } finally { console.log = o; console.error = e; }
  assert.equal(exit, 0); assert.ok(lines.some((l) => l.includes("no changes against HEAD")));
});

test("engine: the JSON line carries found and completed, per step and in total", async () => {
  const { json } = await gate([], [fake("a", async () => ({ ok: true, found: 3, completed: 3 })), fake("b", async () => ({ ok: true, found: 2, completed: 2 }))], await fakeCtx());
  assert.equal(json.steps_found, 2); assert.equal(json.steps_completed, 2);
  assert.equal(json.units_found, 5); assert.equal(json.units_completed, 5);
  assert.equal(json.steps[0].found, 3); assert.equal(json.steps[0].completed, 3);
});

test("ctx.run names our own timeout (timedOut) on the result", async () => {
  const { run } = await lib("ctx.mjs");
  const r = run(process.execPath, ["-e", "setTimeout(() => {}, 20000)"], { timeout: 400 });
  assert.notEqual(r.code, 0);
  assert.equal(r.timedOut, true);
});

test("devx.test: zero test files is a FAIL, not 'no devx tests yet'", async () => {
  const ctx = await fakeCtx();
  fs.mkdirSync(path.join(ctx.REPO, "devx", "test"), { recursive: true });
  const { exit } = await gate([], [await stepOf("devx.mjs")], ctx);
  assert.equal(exit, 1);
});

test("devx.test: a run stopped before its summary (exit 0 from a wrapper that counted what passed) is a FAIL", async () => {
  const ctx = await fakeCtx({ run: () => ({ code: 0, stdout: "✔ one (1ms)\n✔ two (1ms)\n", stderr: "", ms: 1 }) });
  fs.mkdirSync(path.join(ctx.REPO, "devx", "test"), { recursive: true });
  fs.writeFileSync(path.join(ctx.REPO, "devx", "test", "a.test.mjs"), "");
  const { exit, json } = await gate([], [await stepOf("devx.mjs")], ctx);
  assert.equal(exit, 1); assert.equal(json.steps[0].ok, false);
});

test("devx.test: our timeout is a FAIL that says it timed out; a kill from outside is 'could not run'", async () => {
  const mk = async (r) => { const ctx = await fakeCtx({ run: () => r }); fs.mkdirSync(path.join(ctx.REPO, "devx", "test"), { recursive: true }); fs.writeFileSync(path.join(ctx.REPO, "devx", "test", "a.test.mjs"), ""); return ctx; };
  const t = await gate([], [await stepOf("devx.mjs")], await mk({ code: 2, timedOut: true, signal: "SIGTERM", stdout: "✔ one (1ms)\n", stderr: "", ms: 1 }));
  assert.equal(t.exit, 1); assert.match(t.json.steps[0].detail, /timed out/);
  const k = await gate([], [await stepOf("devx.mjs")], await mk({ code: 1, signal: "SIGKILL", stdout: "✔ one (1ms)\n", stderr: "", ms: 1 }));
  assert.equal(k.exit, 2); assert.match(k.json.steps[0].detail, /killed by SIGKILL/);
});

test("shell selftest: exit 0 with PASS lines but no trailer (the script was stopped) is a FAIL", async () => {
  const ctx = await fakeCtx({ bash: () => ({ code: 0, stdout: "PASS a\nPASS b\n", stderr: "", ms: 1 }) });
  const { exit, json } = await gate([], [await stepOf("seeds.mjs")], ctx);
  assert.equal(exit, 1); assert.match(json.steps[0].detail, /trailer/);
});

test("shell selftest: a trailer that counts more cases than the lines we saw is a FAIL; a whole run passes with its counts", async () => {
  const short = await gate([], [await stepOf("seeds.mjs")], await fakeCtx({ bash: () => ({ code: 0, stdout: "PASS a\nPASS b\nseeds: 3 passed, 0 failed (reports in x)\n", stderr: "", ms: 1 }) }));
  assert.equal(short.exit, 1);
  const whole = await gate([], [await stepOf("seeds.mjs")], await fakeCtx({ bash: () => ({ code: 0, stdout: "PASS a\nPASS b\nseeds: 2 passed, 0 failed (reports in x)\n", stderr: "", ms: 1 }) }));
  assert.equal(whole.exit, 0); assert.equal(whole.json.steps[0].found, 2); assert.equal(whole.json.steps[0].completed, 2);
});

test("kit.selftest: 'RESULT PASS' on a run of zero cases is not a PASS", async () => {
  const ctx = await fakeCtx({ bash: () => ({ code: 0, stdout: "[selftest] headless=true\n[selftest] 0 passed, 0 failed: RESULT PASS\n", stderr: "", ms: 1 }) });
  const { exit } = await gate([], [await stepOf("kit.mjs")], ctx);
  assert.equal(exit, 1);
});

test("item.selftest without its input (the marble job) could not run: exit 2, not a SKIPPED pass", async () => {
  const { exit, json } = await gate([], [await stepOf("selftests.mjs", "item.selftest")], await fakeCtx({ ENGINE: path.join(tmp("e"), "a", "b", "c") }));
  assert.equal(exit, 2); assert.deepEqual(json.not_run, ["item.selftest"]);
});

test("foreman steps without foreman/node_modules could not run (exit 2), they do not fail as code", async () => {
  const { exit, json } = await gate([], [await stepOf("foreman.mjs", "foreman.typecheck")], await fakeCtx());
  assert.equal(exit, 2); assert.match(json.steps[0].detail, /node_modules missing/);
});

test("perf with no quiet baseline judged nothing: could not run (exit 2), not a pass", async () => {
  const { exit } = await gate([], [await stepOf("perf.mjs")], await fakeCtx());
  assert.equal(exit, 2);
});

test("foreman.test: a failure names the failing test with its file and line, and the whole output is kept", async () => {
  const dir = tmp("ft");
  try {
    fs.writeFileSync(path.join(dir, "x.test.mjs"), 'import { test } from "node:test"; import assert from "node:assert";\ntest("passes", () => {});\ntest("the one that fails under load", () => { assert.equal(1, 2); });\n');
    const { run } = await lib("ctx.mjs");
    const real = run(process.execPath, ["--test", "x.test.mjs"], { cwd: dir, env: { NODE_TEST_CONTEXT: undefined } });   // a plain run, not a child of this runner
    assert.equal(real.code, 1);
    const ctx = await fakeCtx({ run: () => real });
    fs.mkdirSync(path.join(ctx.FOREMAN, "node_modules"), { recursive: true });
    const { exit, json } = await gate([], [await stepOf("foreman.mjs", "foreman.test")], ctx);
    assert.equal(exit, 1);
    assert.match(json.steps[0].detail, /the one that fails under load/);
    assert.match(json.steps[0].detail, /x\.test\.mjs:\d+/);
    assert.equal(json.steps[0].found, 2); assert.equal(json.steps[0].completed, 2);
    const log = fs.readFileSync(path.join(ctx.REPO, ".tl", "last", "foreman.test.log"), "utf8");
    assert.match(log, /the one that fails under load/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test("disk floor: says under the floor, never stops; TL_DISK_FLOOR_GB overrides; a bad override keeps the default", async () => {
  const { diskReport, floorGB, DEFAULT_FLOOR_GB } = await lib("disk.mjs");
  const statfs = () => ({ bavail: 5 * 1e9 / 4096, bsize: 4096 });
  const low = diskReport(".", { env: {}, statfs });
  assert.equal(low.low, true); assert.equal(low.free_gb, 5); assert.match(low.line, /WARN .* under the floor of 20 GB/);
  assert.equal(diskReport(".", { env: { TL_DISK_FLOOR_GB: "2" }, statfs }).low, false);
  assert.equal(floorGB({ TL_DISK_FLOOR_GB: "lots" }), DEFAULT_FLOOR_GB);
  const { exit, lines } = await (async () => {
    const { execute } = await lib("commands/check.mjs");
    const o = console.log, e = console.error; const out = []; console.log = (...a) => out.push(a.join(" ")); console.error = () => {};
    try { return { exit: await execute([], { steps: [fake("a", async () => ({ ok: true, found: 1, completed: 1 }))], historyFile: null, ctx: await fakeCtx(), disk: () => low }), lines: out }; }
    finally { console.log = o; console.error = e; }
  })();
  assert.equal(exit, 0, "a low disk never fails or stops the gate");
  assert.ok(lines[0].includes("WARN")); assert.equal(JSON.parse(lines.at(-1)).disk_low, true);
});
