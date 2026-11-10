// Integration: the Foreman's own Verifier (and `foreman verify`) against the REAL engine.
// Skipped when TL_GODOT is not set. The engine directory is TL_ENGINE_DIR, or site/_engine_snapshot; never the
// live engine/ (another builder may be changing it). Nothing is written into the engine directory by this test:
// reports and captures go to temp directories.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir, FAKE_RUNNER } from "./helpers.js";
import { Verifier, REPORT_KEYS, type VerifyResult } from "../verifier.js";
import { restsOnAClock } from "../foreman.js";
import { inProcessFakeRunner } from "../testing/fake-runner-core.js";
import { main } from "../cli.js";
import { copyDir } from "../scope.js";
import { REPO_ROOT } from "../paths.js";
import type { Verb } from "../events.js";

after(cleanup);

const godot = process.env["TL_GODOT"];
const engineDir = path.resolve(process.env["TL_ENGINE_DIR"] && process.env["TL_ENGINE_DIR"].length > 0 ? process.env["TL_ENGINE_DIR"] : path.join(REPO_ROOT, "site", "_engine_snapshot"));
const examples = path.join(engineDir, "kernel", "examples");
const skip = !godot ? "TL_GODOT is not set" : !fs.existsSync(godot) ? `TL_GODOT does not exist: ${godot}` : !fs.existsSync(examples) ? `no kernel/examples under ${engineDir}` : false;
const opts = { skip, timeout: 600_000 };

const real = (): Verifier => new Verifier({ godot: godot as string, engineDir, timeoutMs: 180_000 });
const ex = (name: string): string => path.join(examples, name);

/** One verb through the Verifier. A capture is tried once more before it counts as failed (the window can die in the driver under GPU load). */
async function run(v: Verifier, pack: string, verb: Verb, args: string[], reports: string, name = verb as string): Promise<VerifyResult & { attempts: number }> {
  let r = await v.run({ verb, args, packDir: pack, reportFile: path.join(reports, `${name}.json`) });
  let attempts = 1;
  if (!r.ok && verb === "capture") {
    r = await v.run({ verb, args, packDir: pack, reportFile: path.join(reports, `${name}.json`) });
    attempts = 2;
  }
  return { ...r, attempts };
}
const checkIds = (r: VerifyResult): string[] => (r.report?.checks ?? []).map((c) => c.id);
const isPng = (file: string): boolean => fs.existsSync(file) && fs.readFileSync(file).subarray(1, 4).toString("latin1") === "PNG";

test("real engine: every verb passes on the good example packs, and the reports are what RUNNER.md says", opts, async (t) => {
  const v = real();
  for (const [name, bot, cam, botFrames] of [
    ["pack_min", "tests/bot_roll.gd", "hero", "3000"],
    ["ex_slide", "tests/bot_slide.gd", "lanes", "3000"],
  ] as const) {
    const reports = tempDir(`engine-${name}`);
    const lint = await run(v, ex(name), "lint", [], reports);
    assert.deepEqual([lint.ok, lint.exitCode, lint.level, lint.flags], [true, 0, "V1", []], `${name} lint: ${lint.summary}`);
    assert.deepEqual(checkIds(lint), ["lint.schema", "lint.layout", "lint.fence", "lint.capabilities", "lint.size"]);
    const comp = lint.report?.["composability"] as { gdscript_lines: Record<string, number>; kit_parts_added: number; bypasses: unknown[] };
    assert.ok(comp.gdscript_lines["scripts"] !== undefined && comp.gdscript_lines["scripts"] > 0 && Array.isArray(comp.bypasses));

    const smoke = await run(v, ex(name), "smoke", ["--seed=1", "--frames=600"], reports);
    assert.deepEqual([smoke.ok, smoke.exitCode, smoke.level, smoke.flags], [true, 0, "V2", []], `${name} smoke: ${smoke.summary}`);
    assert.deepEqual(checkIds(smoke), ["smoke.loads", "smoke.no_script_errors", "smoke.no_engine_errors", "smoke.watchdog"]);
    assert.match(String((smoke.report?.["metrics"] as Record<string, unknown>)["state_hash"]), /^[0-9a-f]{64}$/);

    const inv = await run(v, ex(name), "invariants", ["--seed=1", "--frames=600"], reports);
    assert.deepEqual([inv.ok, inv.exitCode, inv.level, inv.flags], [true, 0, "V3", []], `${name} invariants: ${inv.summary}`);
    for (const id of ["invariants.determinism", "invariants.below_ground", "invariants.frame_budget", "invariants.entity_budget"]) assert.ok(checkIds(inv).includes(id), id);

    const b = await run(v, ex(name), "bot", [`--test=${bot}`, `--frames=${botFrames}`], reports);
    assert.deepEqual([b.ok, b.exitCode, b.level, b.flags], [true, 0, "V4", []], `${name} bot: ${b.summary}`);
    const botBlock = b.report?.["bot"] as { test: string; done: boolean; frames: number; result: { ok: boolean; summary: string } };
    assert.deepEqual([botBlock.test, botBlock.done, botBlock.result.ok], [bot, true, true]);
    assert.ok(checkIds(b).includes("bot.completed") && checkIds(b).includes("bot.ok") && checkIds(b).includes("smoke.no_engine_errors"));

    const png = path.join(reports, `${cam}.png`);
    const cap = await run(v, ex(name), "capture", [`--cam=${cam}`, `--out=${png.replace(/\\/g, "/")}`, "--res=1280x720", `--test=${bot}`], reports);
    assert.deepEqual([cap.ok, cap.exitCode, cap.level, cap.flags], [true, 0, "V5", []], `${name} capture (attempts: ${cap.attempts}): ${cap.summary}`);
    const capBlock = cap.report?.["capture"] as { cam: string; frame: number; width: number; height: number };
    assert.deepEqual([capBlock.cam, capBlock.frame, capBlock.width, capBlock.height], [cam, 120, 1280, 720]);
    assert.ok(isPng(png), "the capture is a PNG file");
    t.diagnostic(`${name}: capture passed on attempt ${cap.attempts} of 2`);
    assert.match(cap.report?.checks.find((c) => c.id === "capture.written")?.detail ?? "", /rendering driver: d3d12/, "captures come from Direct3D 12 (RUNNER.md)");

    for (const r of [lint, smoke, inv, b, cap]) {
      // Report file and last stdout line agreed (no flags above); every top-level key is one the contract fixes.
      for (const k of Object.keys(r.report ?? {})) assert.ok((REPORT_KEYS as readonly string[]).includes(k), `${name} ${r.verb}: top-level key ${k}`);
      assert.equal(r.report?.["kernelApi"], "0.1");
      assert.ok(fs.existsSync(r.reportFile) && fs.existsSync(r.verdictFile));
    }
    // Nothing of ours is left in the engine's example directory.
    assert.ok(!fs.readdirSync(ex(name)).some((f) => /report|\.tmp|\.png$/.test(f)));
  }
});

test("real engine: three bad packs (and more) fail the way the runner documents; the Verifier's verdict agrees with the exit code", opts, async (t) => {
  const v = real();
  const reports = tempDir("engine-bad");
  // 1. bad_schema: lint fails with a schema error at a file and line; any verb that runs code could not run.
  const lint = await run(v, ex("bad_schema"), "lint", [], reports, "schema-lint");
  assert.deepEqual([lint.ok, lint.exitCode, lint.report?.outcome, lint.flags], [false, 1, "failed", []]);
  assert.deepEqual([lint.report?.errors[0]?.kind, lint.report?.errors[0]?.file, typeof lint.report?.errors[0]?.line], ["schema", "pack.json", "number"]);
  const norun = await run(v, ex("bad_schema"), "smoke", [], reports, "schema-smoke");
  assert.deepEqual([norun.ok, norun.exitCode, norun.report?.outcome, norun.report?.checks.length, norun.flags], [false, 2, "not_run", 0, []]);
  // 2. bad_script_error: a runtime error, attributed to the pack's file and line.
  //    Under CPU load the real runner was seen to end this very run as `watchdog` (tick_timeout, a wall-clock
  //    limit) in 3 of 10 tries. The Foreman runs such a result once more (restsOnAClock); so does this test.
  let se = await run(v, ex("bad_script_error"), "smoke", ["--frames=120"], reports, "script-error");
  for (let i = 0; i < 3 && restsOnAClock(se); i++) {
    t.diagnostic(`bad_script_error smoke ended as watchdog (${se.report?.checks.find((c) => c.id === "smoke.watchdog")?.detail ?? ""}); running it again`);
    se = await run(v, ex("bad_script_error"), "smoke", ["--frames=120"], reports, `script-error-again${i}`);
  }
  assert.deepEqual([se.ok, se.exitCode, se.report?.outcome, se.flags], [false, 1, "failed", []]);
  const err = se.report?.errors.find((e) => e.kind === "script_error");
  assert.deepEqual([err?.file, typeof err?.line], ["scripts/main.gd", "number"]);
  assert.equal(se.report?.checks.find((c) => c.id === "smoke.no_script_errors")?.ok, false);
  // 3. bad_bot: a bot that never finishes. RUNNER.md (amended) says exit 1 `failed`; the snapshot engine still
  //    answers exit 3 `watchdog`. Both are accepted; either way bot.completed is false and nothing is flagged.
  const nb = await run(v, ex("bad_bot"), "bot", ["--frames=300"], reports, "bot-never");
  assert.equal(nb.ok, false);
  assert.ok((nb.exitCode === 1 && nb.report?.outcome === "failed") || (nb.exitCode === 3 && nb.report?.outcome === "watchdog"), `exit ${nb.exitCode}, outcome ${nb.report?.outcome}`);
  assert.deepEqual([nb.flags, nb.report?.checks.find((c) => c.id === "bot.completed")?.ok, (nb.report?.["bot"] as { done: boolean }).done], [[], false, false]);
  // More: a runaway tick is the watchdog (exit 3); a non-deterministic pack fails invariants; an unknown option
  // and a missing pack could not run (exit 2).
  const wd = await run(v, ex("bad_watchdog"), "smoke", ["--frames=600"], reports, "watchdog");
  assert.deepEqual([wd.ok, wd.exitCode, wd.report?.outcome, wd.flags], [false, 3, "watchdog", []]);
  const nd = await run(v, ex("bad_nondeterminism"), "invariants", ["--frames=300"], reports, "nondeterminism");
  assert.deepEqual([nd.ok, nd.exitCode, nd.report?.checks.find((c) => c.id === "invariants.determinism")?.ok], [false, 1, false]);
  const opt = await run(v, ex("pack_min"), "smoke", ["--speed=9"], reports, "bad-option");
  assert.deepEqual([opt.ok, opt.exitCode, opt.report?.outcome], [false, 2, "not_run"]);
  assert.match(opt.report?.errors[0]?.message ?? "", /unknown option --speed/);
  const gone = await run(v, path.join(examples, "no_such_pack"), "smoke", [], reports, "missing-pack");
  assert.deepEqual([gone.ok, gone.exitCode, gone.report?.errors[0]?.kind], [false, 2, "load"]);
});

test("real engine: `foreman verify <pack>` runs all five verbs and prints one line per verb", opts, async () => {
  const reports = tempDir("engine-cli");
  const lines: string[] = [];
  const code = await main(["verify", ex("pack_min"), "--engine-dir", engineDir, "--reports", reports], (s) => lines.push(s));
  const text = lines.join("\n");
  assert.equal(code, 0, text);
  for (const re of [/^lint\s+V1\s+ok/m, /^smoke\s+V2\s+ok/m, /^invariants\s+V3\s+ok/m, /^bot-bot_roll\s+V4\s+ok/m, /^capture-hero\s+V5\s+ok/m]) assert.match(text, re);
  assert.ok(isPng(path.join(reports, "capture-hero.png")));
  for (const f of ["lint.json", "smoke.json", "invariants.json", "bot-bot_roll.json", "capture-hero.json"]) {
    assert.equal((JSON.parse(fs.readFileSync(path.join(reports, f), "utf8")) as { schema: string }).schema, "tl.verify/1", f);
  }
  const bad = await main(["verify", ex("bad_script_error"), "--engine-dir", engineDir, "--reports", tempDir("engine-cli-bad"), "--verbs", "lint,smoke"], () => {});
  assert.equal(code === 0 && bad === 1, true, "a failing pack exits 1");
});

test("real engine against the fake: same top-level keys and the same check ids for every verb on the same pack", opts, async () => {
  // A copy of pack_min in a temp directory, so the fake (which reads files) and the real runner see the same pack.
  const root = tempDir("engine-parity");
  const pack = path.join(root, "pack");
  copyDir(ex("pack_min"), pack);
  const v = real();
  const fake = new Verifier({ godot: FAKE_RUNNER, engineDir: path.join(root, "engine"), spawn: inProcessFakeRunner(), timeoutMs: 5000 });
  const cases: [Verb, string[]][] = [
    ["lint", []],
    ["smoke", ["--seed=1", "--frames=300"]],
    ["invariants", ["--seed=1", "--frames=300"]],
    ["bot", ["--test=tests/bot_roll.gd"]],
    ["capture", ["--cam=hero", "--res=1280x720", "--test=tests/bot_roll.gd"]],
  ];
  for (const [verb, args] of cases) {
    const extra = (who: string): string[] => (verb === "capture" ? [...args, `--out=${path.join(root, `${who}.png`).replace(/\\/g, "/")}`] : args);
    const a = await run(v, pack, verb, extra("real"), path.join(root, "real"));
    const b = await run(fake, pack, verb, extra("fake"), path.join(root, "fake"));
    assert.deepEqual([a.ok, b.ok], [true, true], `${verb}: real "${a.summary}" fake "${b.summary}"`);
    assert.deepEqual(Object.keys(b.report ?? {}).sort(), Object.keys(a.report ?? {}).sort(), `${verb}: top-level keys`);
    assert.deepEqual(checkIds(b), checkIds(a), `${verb}: check ids`);
    assert.deepEqual([b.level, b.exitCode], [a.level, a.exitCode], verb);
  }
  // And the same answer to the same mistakes.
  for (const [verb, args] of [["smoke", ["--speed=9"]], ["bot", ["--test=tests/nope.gd"]], ["capture", ["--cam=hero"]]] as [Verb, string[]][]) {
    const a = await v.run({ verb, args, packDir: pack, reportFile: path.join(root, "real", `bad-${verb}.json`) });
    const b = await fake.run({ verb, args, packDir: pack, reportFile: path.join(root, "fake", `bad-${verb}.json`) });
    assert.deepEqual([b.exitCode, b.report?.outcome, checkIds(b)], [a.exitCode, a.report?.outcome, checkIds(a)], `${verb} ${args.join(" ")}`);
  }
});
