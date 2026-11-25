// H2c (25 Nov 2026, the Director's ruling): a game made in Create is a dungeon, judged by the solo budget unless a person
// places it in the village. The kernel's budget_class called every pack outside the engine's tree "many" (the village's
// one-of-many p50 of 1.0 ms), and a Create job's pack always lives outside it: G4's 3 v 3 basketball (1.15-1.44 ms) lost
// about four rounds and three questions to a budget no builder could reach. The Foreman now tells the runner's invariants
// where the job's game lives (--home): "village" for a village site job (its job_created has a lot), "create" otherwise;
// the builders' own self-check commands carry it too. A runner whose verbs.json does not know the option is not given it.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { Verifier } from "../verifier.js";
import { REPO_ROOT } from "../paths.js";
import { acceptanceOptions, loadVerbs } from "../verbs.js";
import type { SpawnFn } from "../proc.js";
import { cleanup, foremanFor, tempJob, tempDir, FIXTURE } from "./helpers.js";

after(cleanup);

const ENGINE = path.join(REPO_ROOT, "engine");

/** A spawn that records the runner's argv and answers like a runner that found nothing (a passed invariants report). */
function recorder(seen: string[][]): SpawnFn {
  return async (req) => {
    seen.push([...req.args]);
    const rep = req.args.find((a) => a.startsWith("--report="))?.slice(9) as string;
    const verb = req.args[req.args.indexOf("--") + 1] as string;
    const report = { schema: "tl.verify/1", verb, level: "V3", ok: true, outcome: "passed", checks: [], errors: [], metrics: {} };
    fs.writeFileSync(rep, JSON.stringify(report));
    return { exitCode: 0, stdout: JSON.stringify(report) + "\n", stderr: "", timedOut: false, outputCapped: false, durationMs: 1 };
  };
}

test("H2c: the engine's runner knows invariants --home (create | village), and a plan may not set it (the Foreman's own option)", () => {
  const v = loadVerbs(ENGINE);
  assert.ok(v.verbs["invariants"]?.options["home"] !== undefined, "verbs.json lists invariants --home");
  assert.ok(!(acceptanceOptions(v, "invariants") ?? []).includes("home"), "a package's acceptance cannot carry --home");
  const host = fs.readFileSync(path.join(ENGINE, "kernel", "host", "host.gd"), "utf8");
  assert.match(host, /"invariants": \[[^\]]*"home"\]/, "host.gd's OPTIONS table has it (it must equal verbs.json)");
});

test("H2c: the Verifier passes --home to invariants only (and only when told the job's home, and only to a runner that knows it)", async () => {
  const seen: string[][] = [];
  const dir = tempDir("h2c-verify");
  const v = new Verifier({ godot: path.join(dir, "godot.exe"), engineDir: ENGINE, spawn: recorder(seen) });
  const run = (verb: "invariants" | "bot"): Promise<unknown> => v.run({ verb, args: [], packDir: dir, reportFile: path.join(dir, `${verb}-${seen.length}.json`) });
  await run("invariants");
  assert.ok(!seen.at(-1)?.some((a) => a.startsWith("--home")), "not told: no --home (the engine's boot files decide)");
  v.home = "create";
  await run("invariants");
  assert.ok(seen.at(-1)?.includes("--home=create"), `told create: ${seen.at(-1)?.join(" ")}`);
  await run("bot");
  assert.ok(!seen.at(-1)?.some((a) => a.startsWith("--home")), "a bot run: no --home");
  v.home = "village";
  await run("invariants");
  assert.ok(seen.at(-1)?.includes("--home=village"));
  assert.deepEqual(v.argsFor("invariants", ["--home=create"]), ["--home=create"], "an explicit --home is never doubled");
  // an engine whose verbs.json does not list the option (an older snapshot) is not given it: it would refuse an unknown option
  const old = path.join(dir, "old-engine");
  fs.mkdirSync(path.join(old, "kernel", "runner"), { recursive: true });
  const verbs = JSON.parse(fs.readFileSync(path.join(ENGINE, "kernel", "runner", "verbs.json"), "utf8")) as { verbs: Record<string, { options: Record<string, unknown> }> };
  delete verbs.verbs["invariants"]?.options["home"];
  fs.writeFileSync(path.join(old, "kernel", "runner", "verbs.json"), JSON.stringify(verbs));
  const ov = new Verifier({ godot: path.join(dir, "godot.exe"), engineDir: old, spawn: recorder(seen) });
  ov.home = "create";
  await ov.run({ verb: "invariants", args: [], packDir: dir, reportFile: path.join(dir, "old.json") });
  assert.ok(!seen.at(-1)?.some((a) => a.startsWith("--home")), "an engine without the option: none");
});

test("H2c: the Foreman tells the verifier the job's home: a job made in Create (no lot) is create, a village site job (its lot) is village", async () => {
  const job = tempJob("h2c-create");
  const { foreman } = foremanFor(job);
  const v = (foreman as unknown as { o: { verifier: Verifier } }).o.verifier;
  foreman.previewBuilderPrompts();
  assert.equal(v.home, "create", "the fixture job was made without a lot");
  await foreman.run();
  assert.equal(v.home, "create", "and run() says so too");

  const site = tempJob("h2c-village");
  const file = path.join(site.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter((l) => l.length > 0);
  const first = JSON.parse(lines[0] as string) as Record<string, unknown>;
  first["lot"] = { at: [12, -8], yaw_deg: 90, radius: 14 };
  lines[0] = JSON.stringify(first);
  fs.writeFileSync(file, lines.join("\n") + "\n");
  const { foreman: sf } = foremanFor(site);
  sf.previewBuilderPrompts();
  assert.equal((sf as unknown as { o: { verifier: Verifier } }).o.verifier.home, "village", "a job placed on a village lot keeps the one-of-many budget");
  void FIXTURE;
});
