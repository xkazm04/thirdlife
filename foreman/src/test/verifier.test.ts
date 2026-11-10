import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir, processVerifier, fixtureScript, FAKE_RUNNER } from "./helpers.js";
import { runnerLocation, resolveRunner } from "../verifier.js";

after(cleanup);

/** A pack directory built from the fixture's own scripted files (the good version of every file). */
function goodPack(extra: Record<string, string> = {}): { root: string; pack: string; reports: string } {
  const root = tempDir("verify");
  const pack = path.join(root, "pack");
  const files: Record<string, string> = {};
  for (const s of fixtureScript().steps) Object.assign(files, s.write ?? {});
  delete files["NOTES.txt"];
  Object.assign(files, extra);
  for (const [rel, content] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(pack, rel)), { recursive: true });
    fs.writeFileSync(path.join(pack, rel), content);
  }
  return { root, pack, reports: path.join(root, "reports") };
}

test("verifier: the fake runner is spawned directly (node + script, no shell) and a good pack passes every verb", async () => {
  const { root, pack, reports } = goodPack();
  const v = processVerifier(path.join(root, "engine"));
  assert.equal(v.location.exe, process.execPath);
  assert.deepEqual(v.location.preArgs, [FAKE_RUNNER]);
  for (const [verb, args, level] of [
    ["lint", [], "V1"],
    ["smoke", ["--seed=3", "--frames=120"], "V2"],
    ["invariants", [], "V3"],
    ["bot", ["--test=tests/bot_rally.gd"], "V4"],
  ] as const) {
    const r = await v.run({ verb, args: [...args], packDir: pack, reportFile: path.join(reports, `${verb}.json`) });
    assert.deepEqual([verb, r.ok, r.exitCode, r.level, r.flags], [verb, true, 0, level, []]);
    assert.equal(r.report?.outcome, "passed");
    assert.equal(r.reportFile, path.join(reports, `${verb}.json`));
    assert.ok(fs.existsSync(r.verdictFile));
  }
  const smoke = JSON.parse(fs.readFileSync(path.join(reports, "smoke.json"), "utf8")) as { seed: number; frames: number; metrics: { state_hash: string } };
  assert.deepEqual([smoke.seed, smoke.frames], [3, 120]);
  assert.match(smoke.metrics.state_hash, /^[0-9a-f]{64}$/);
});

test("verifier: a failing check is exit 1 + outcome failed, and the report says which check", async () => {
  const { root, pack, reports } = goodPack({ "scripts/paddle_ai.gd": "extends RefCounted\nfunc decide():\n\treturn FAKE_SCRIPT_ERROR()\n" });
  const v = processVerifier(path.join(root, "engine"));
  const r = await v.run({ verb: "smoke", packDir: pack, reportFile: path.join(reports, "smoke.json") });
  assert.deepEqual([r.ok, r.exitCode, r.flags, r.report?.outcome], [false, 1, [], "failed"]);
  assert.equal(r.report?.errors[0]?.kind, "script_error");
  assert.equal(r.report?.errors[0]?.file, "scripts/paddle_ai.gd");
  assert.match(r.summary, /smoke\.no_script_errors/);
  const lint = await v.run({ verb: "lint", packDir: pack, reportFile: path.join(reports, "lint.json") });
  assert.equal(lint.ok, true, "lint does not see a runtime error; smoke does");
});

test("verifier: lint catches a manifest that breaks the schema and a fenced API", async () => {
  const bad = goodPack({ "pack.json": JSON.stringify({ id: "NotNamespaced", version: "1", kernelApi: "0.1", title: "x", capabilities: ["telepathy"], entry: "scripts/main.gd", assets: [], tests: [], extra: true }) });
  const v = processVerifier(path.join(bad.root, "engine"));
  const r = await v.run({ verb: "lint", packDir: bad.pack, reportFile: path.join(bad.reports, "lint.json") });
  assert.deepEqual([r.ok, r.exitCode], [false, 1]);
  assert.ok(r.report?.checks.some((c) => c.id === "lint.schema" && !c.ok));
  const fenced = goodPack({ "scripts/court.gd": "extends RefCounted\nstatic func build(ctx, layout):\n\tOS.execute(\"calc\", [])\n" });
  const r2 = await v.run({ verb: "lint", packDir: fenced.pack, reportFile: path.join(fenced.reports, "lint.json") });
  assert.equal(r2.ok, false);
  assert.ok(r2.report?.errors.some((e) => e.kind === "fence" && e.file === "scripts/court.gd" && e.line === 3));
});

test("verifier: exit code and outcome that disagree are flagged and never count as a pass", async () => {
  const { root, pack, reports } = goodPack();
  const v = processVerifier(path.join(root, "engine"), { FAKE_RUNNER_MODE: "disagree" });
  const r = await v.run({ verb: "smoke", packDir: pack, reportFile: path.join(reports, "smoke.json") });
  // The report claims passed; the process exited 1.
  assert.equal(r.report?.outcome, "passed");
  assert.equal(r.report?.ok, true);
  assert.equal(r.exitCode, 1);
  assert.equal(r.ok, false);
  assert.deepEqual(r.flags, ["exit_outcome_disagree"]);
  assert.match(r.summary, /exit code 1 means failed, the report says passed/);
  // The other direction: report says failed, exit code says 0.
  const broken = goodPack({ "scripts/court.gd": "extends RefCounted\n# FAKE_SCRIPT_ERROR\nfunc f():\n\treturn FAKE_SCRIPT_ERROR\n" });
  const r2 = await v.run({ verb: "smoke", packDir: broken.pack, reportFile: path.join(broken.reports, "smoke.json") });
  assert.deepEqual([r2.ok, r2.exitCode, r2.report?.outcome, r2.flags], [false, 0, "failed", ["exit_outcome_disagree"]]);
});

test("verifier: a runner that hangs is killed on our timeout and reported as such", async () => {
  const { root, pack, reports } = goodPack();
  const v = processVerifier(path.join(root, "engine"), { FAKE_RUNNER_MODE: "hang" }, 1500);
  const t0 = Date.now();
  const r = await v.run({ verb: "smoke", packDir: pack, reportFile: path.join(reports, "smoke.json") });
  assert.ok(Date.now() - t0 < 15_000, "the verifier itself must not hang");
  assert.deepEqual([r.ok, r.exitCode, r.flags], [false, undefined, ["runner_timeout"]]);
  assert.equal(r.reportFile, r.verdictFile, "with no runner report the event points at our verdict file");
  const verdict = JSON.parse(fs.readFileSync(r.verdictFile, "utf8")) as { timedOut: boolean; ok: boolean };
  assert.deepEqual([verdict.timedOut, verdict.ok], [true, false]);
});

test("verifier: garbage on stdout and a missing report file are failures, even with exit code 0", async () => {
  const { root, pack, reports } = goodPack();
  const garbage = await processVerifier(path.join(root, "engine"), { FAKE_RUNNER_MODE: "garbage" }).run({ verb: "smoke", packDir: pack, reportFile: path.join(reports, "g.json") });
  assert.equal(garbage.exitCode, 0);
  assert.equal(garbage.ok, false);
  assert.deepEqual(garbage.flags, ["stdout_not_json", "report_missing"]);
  assert.equal(garbage.report, undefined);
  const noReport = await processVerifier(path.join(root, "engine"), { FAKE_RUNNER_MODE: "noreport" }).run({ verb: "smoke", packDir: pack, reportFile: path.join(reports, "n.json") });
  assert.equal(noReport.ok, false);
  assert.deepEqual(noReport.flags, ["report_missing"]);
});

test("verifier: stdout line and report file are compared by content (key order and whitespace do not matter); a real difference is flagged", async () => {
  const { root, pack, reports } = goodPack();
  const { Verifier } = await import("../verifier.js");
  const body = { schema: "tl.verify/1", verb: "smoke", level: "V2", ok: true, outcome: "passed", checks: [], errors: [] };
  const reordered = { errors: [], checks: [], outcome: "passed", ok: true, level: "V2", verb: "smoke", schema: "tl.verify/1" };
  const make = (fileBody: object): InstanceType<typeof Verifier> =>
    new Verifier({
      godot: "godot.exe",
      engineDir: path.join(root, "engine"),
      spawn: async (req) => {
        const file = (req.args.find((x) => x.startsWith("--report=")) ?? "").slice("--report=".length);
        fs.writeFileSync(file, JSON.stringify(fileBody, null, 2));
        return { exitCode: 0, stdout: `banner\n${JSON.stringify(body)}\n`, stderr: "", timedOut: false, outputCapped: false, durationMs: 1 };
      },
    });
  const same = await make(reordered).run({ verb: "smoke", packDir: pack, reportFile: path.join(reports, "a.json") });
  assert.deepEqual([same.ok, same.flags], [true, []]);
  const differs = await make({ ...reordered, ok: false, outcome: "failed" }).run({ verb: "smoke", packDir: pack, reportFile: path.join(reports, "b.json") });
  assert.equal(differs.ok, false);
  assert.ok(differs.flags.includes("stdout_report_mismatch"));
});

test("verifier: a stale report from an earlier run is never read as this run's answer", async () => {
  const { root, pack, reports } = goodPack();
  const file = path.join(reports, "smoke.json");
  const ok = await processVerifier(path.join(root, "engine")).run({ verb: "smoke", packDir: pack, reportFile: file });
  assert.equal(ok.ok, true);
  assert.ok(fs.existsSync(file));
  const again = await processVerifier(path.join(root, "engine"), { FAKE_RUNNER_MODE: "garbage" }).run({ verb: "smoke", packDir: pack, reportFile: file });
  assert.equal(again.ok, false);
  assert.ok(again.flags.includes("report_missing"));
});

test("verifier: not_run (exit 2) and watchdog (exit 3) are understood, and are not passes", async () => {
  const { root, pack, reports } = goodPack();
  const v = processVerifier(path.join(root, "engine"));
  const missing = await v.run({ verb: "smoke", packDir: path.join(root, "no-such-pack"), reportFile: path.join(reports, "m.json") });
  assert.deepEqual([missing.ok, missing.exitCode, missing.report?.outcome, missing.flags], [false, 2, "not_run", []]);
  const wd = goodPack({ "scripts/court.gd": "extends RefCounted\n# FAKE_WATCHDOG\n" });
  const r = await v.run({ verb: "smoke", packDir: wd.pack, reportFile: path.join(wd.reports, "w.json") });
  assert.deepEqual([r.ok, r.exitCode, r.report?.outcome, r.flags], [false, 3, "watchdog", []]);
  const noBot = await v.run({ verb: "bot", args: ["--test=tests/nope.gd"], packDir: pack, reportFile: path.join(reports, "b.json") });
  assert.deepEqual([noBot.ok, noBot.exitCode], [false, 1]);
});

test("verifier: an executable that does not exist is a failed verification, not an exception", async () => {
  const { root, pack, reports } = goodPack();
  const { Verifier } = await import("../verifier.js");
  const v = new Verifier({ godot: path.join(root, "Godot_missing.exe"), engineDir: path.join(root, "engine"), timeoutMs: 5000 });
  const r = await v.run({ verb: "lint", packDir: pack, reportFile: path.join(reports, "l.json") });
  assert.deepEqual([r.ok, r.flags], [false, ["spawn_error"]]);
});

test("runner location: TL_GODOT and TL_ENGINE_DIR come from the environment; a .js runner is run with node", () => {
  const r = resolveRunner({ TL_GODOT: "D:/godot/godot.exe", TL_ENGINE_DIR: "D:/tl/engine" });
  assert.equal(r.godot, "D:/godot/godot.exe");
  assert.equal(r.engineDir, path.resolve("D:/tl/engine"));
  assert.match(resolveRunner({}).godot, /Godot_v4\.7\.2-stable_win64_console\.exe$/);
  assert.deepEqual(runnerLocation("D:/godot/godot.exe", "e"), { exe: "D:/godot/godot.exe", preArgs: [], engineDir: "e" });
  assert.equal(runnerLocation("x/fake-runner.js", "e").exe, process.execPath);
});
