// Lane editor, 19 Nov (round 2): `foreman new --place-calls <json>` writes the editor's "Find a place" calls as
// job-level builder runs (no package, no round), after billing and before the Designer's brief, so tl ledger counts them.
import { after, test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { main, UsageError } from "../cli.js";
import { readLog } from "../joblog.js";
import { cleanup, FIXTURE, tempDir, v2Brief, roomSteps, designerSteps } from "./helpers.js";

after(cleanup);
const quiet = () => {};
const calls = [
  { adapter: "claude-cli", model: "claude-sonnet-5-5", durationMs: 8125, tokensIn: 5296, tokensOut: 581 },
  { adapter: "fake", model: "fake", durationMs: 1500 },
];

async function newJob(extra: string[]): Promise<{ code: number; site: string }> {
  const root = tempDir("placecalls");
  const site = path.join(root, "jobs"), script = path.join(root, "fake.json");
  const brief = readLog(FIXTURE).events.find((e) => e.type === "brief_set")!;
  fs.writeFileSync(script, JSON.stringify({ steps: [...designerSteps(brief.estimate), ...roomSteps()] }));
  const code = await main(["new", "ice hockey", "--site", site, "--adapter", "fake", "--fake-script", script, ...extra], quiet);
  return { code, site };
}

test("new --place-calls logs each call as a job-level builder_run after billing, before the Designer", async () => {
  const { code, site } = await newJob(["--place-calls", JSON.stringify(calls)]);
  assert.equal(code, 0);
  const events = readLog(path.join(site, fs.readdirSync(site)[0]!)).events;
  const types = events.map((e) => e.type);
  assert.deepEqual(types.slice(0, 5), ["job_created", "billing", "builder_run", "builder_run", "builder_run"]);
  const placed = events.slice(2, 4);
  for (const [i, e] of placed.entries()) {
    assert.ok(e.type === "builder_run");
    assert.equal(e.package, undefined);
    assert.equal(e.round, undefined);
    assert.equal(e.mode, "generate");
    assert.equal(e.outcome, "ok");
    assert.equal(e.adapter, calls[i]!.adapter);
    assert.equal(e.model, calls[i]!.model);
    assert.equal(e.tokensIn, calls[i]!.tokensIn);
    assert.equal(e.tokensOut, calls[i]!.tokensOut);
    assert.equal(e.transcript, undefined);
  }
  assert.ok(!("tokensIn" in placed[1]!), "absent tokens stay absent");
  assert.ok(types.includes("brief_set"));
});

test("new without --place-calls writes no extra builder run", async () => {
  const { code, site } = await newJob([]);
  assert.equal(code, 0);
  const events = readLog(path.join(site, fs.readdirSync(site)[0]!)).events;
  assert.equal(events.filter((e) => e.type === "builder_run").length, 3, "only the design room's three runs (concept, design, review: JOB.md 2026-11-21)");
});

test("a bad --place-calls value is refused before anything is written", async () => {
  const bad = [
    "not json",
    "[]",
    JSON.stringify({ adapter: "fake" }),
    JSON.stringify([{ adapter: "gpt", model: "x", durationMs: 1 }]),
    JSON.stringify([{ adapter: "fake", model: "", durationMs: 1 }]),
    JSON.stringify([{ adapter: "fake", model: "fake", durationMs: -1 }]),
    JSON.stringify([{ adapter: "fake", model: "fake", durationMs: 1, tokensIn: 1.5 }]),
    JSON.stringify([{ adapter: "fake", model: "fake", durationMs: 1, role: "placer" }]),
  ];
  const root = tempDir("placecalls-bad");
  const site = path.join(root, "jobs");
  for (const value of bad) {
    await assert.rejects(main(["new", "ice hockey", "--site", site, "--adapter", "fake", "--place-calls", value], quiet),
      (e) => e instanceof UsageError && e.message.includes("--place-calls"), value);
    assert.ok(!fs.existsSync(site) || fs.readdirSync(site).length === 0, `nothing written for ${value}`);
  }
});

test("the title is the idea's first sentence: the workbench's '<idea>. Decided: ...' gives a clean sign", async () => {
  const root = tempDir("title");
  const site = path.join(root, "jobs"), script = path.join(root, "fake.json");
  const brief = readLog(FIXTURE).events.find((e) => e.type === "brief_set")!;
  fs.writeFileSync(script, JSON.stringify({ steps: [...designerSteps(brief.estimate), ...roomSteps()] }));
  const cases: [string, string][] = [
    ["ice hockey, three against three by the river. Decided: ice hockey on a rink; three against three.", "Ice hockey, three against three by the river"],
    ["balls roll down a ramp: three of them", "Balls roll down a ramp"],
    ["a ramp with balls", "A ramp with balls"],
  ];
  for (const [sentence, title] of cases) {
    assert.equal(await main(["new", sentence, "--site", site, "--adapter", "fake", "--fake-script", script], quiet), 0);
  }
  const titles = fs.readdirSync(site).sort().map((d) => readLog(path.join(site, d)).events[0]).map((e) => (e?.type === "job_created" ? e.title : ""));
  assert.deepEqual(titles.sort(), cases.map((c) => c[1]).sort());
});
