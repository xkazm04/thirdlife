import { after, test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { main, UsageError } from "../cli.js";
import { drainInbox, readInbox } from "../inbox.js";
import { JobLog, readLog, rebuildState } from "../joblog.js";
import { PKG_ROOT } from "../paths.js";
import { cleanup, FIXTURE, fixturePlan, tempDir, v2Brief, roomSteps, designerSteps } from "./helpers.js";

after(cleanup);
const answers = { players: "3", sport: "ice_hockey" };
const lot = { at: [-100, 40], yaw_deg: -15, radius: 22 };
const decision = { key: "players", to: "2" };
const quiet = () => {};

async function createJob() {
  const root = tempDir("editor");
  const site = path.join(root, "jobs"), script = path.join(root, "fake.json");
  const brief = readLog(FIXTURE).events.find((e) => e.type === "brief_set")!;
  fs.writeFileSync(script, JSON.stringify({ steps: [...designerSteps(brief.estimate), ...roomSteps()] }));
  assert.equal(await main(["new", "ice hockey", "--site", site, "--adapter", "fake", "--fake-script", script,
    "--answers", JSON.stringify(answers), "--lot", JSON.stringify(lot)], quiet), 0);
  return path.join(site, fs.readdirSync(site)[0]!);
}

test("new writes the editor answers and lot, and old logs omit both", async () => {
  const dir = await createJob();
  const event = readLog(dir).events[0];
  assert.ok(event?.type === "job_created");
  assert.deepEqual(event.answers, answers);
  assert.deepEqual(event.lot, lot);
  const state = rebuildState(dir, { write: false });
  assert.deepEqual(state.answers, answers);
  assert.deepEqual(state.lot, lot);
  const old = rebuildState(FIXTURE, { write: false });
  assert.ok(!Object.hasOwn(old, "answers") && !Object.hasOwn(old, "lot"));
});

test("invalid new flags cause a usage error before writing anything", async () => {
  const site = tempDir("invalid-editor");
  const invalid: Record<string, string[]> = {
    answers: ["{", "[]", "{}", '{"3players":"three"}', '{"players":"three players"}', '{"players":""}'],
    lot: ["{", JSON.stringify({ ...lot, extra: 1 }), JSON.stringify({ ...lot, radius: 5 }), JSON.stringify({ at: [1, 2], radius: 12 }),
      JSON.stringify({ ...lot, yaw_deg: 361 }), JSON.stringify({ ...lot, at: [1] }), '{"at":[1e999,2],"radius":12,"yaw_deg":0}'],
  };
  for (const [key, values] of Object.entries(invalid)) {
    for (const value of values) {
      await assert.rejects(main(["new", "hockey", "--site", site, "--adapter", "fake", "--" + key, value], quiet),
        (e) => e instanceof UsageError && e.message.includes("--" + key));
      assert.deepEqual(fs.readdirSync(site), []);
    }
  }
});

test("change rejects invalid decisions without writing, and records valid ones directly and through the inbox", async () => {
  const dir = await createJob();
  const log = JobLog.open(dir);
  try {
    log.append({ type: "plan_set", packages: fixturePlan() });
    log.append({ type: "merge", package: "core", files: ["scripts/main.gd"] });
  } finally { log.close(); }
  const args = ["change", dir, "Fewer players", "--no-run", "--decision"];
  const file = path.join(dir, "job.jsonl"), before = fs.readFileSync(file);
  for (const value of ["{", "{}", '{"key":"players","to":""}', '{"key":"players","to":"bad value"}',
    JSON.stringify({ ...decision, extra: true }), JSON.stringify({ ...decision, key: "missing" })]) {
    await assert.rejects(main([...args, value], quiet), (e) => e instanceof UsageError && e.message.includes("--decision"));
    assert.deepEqual(fs.readFileSync(file), before);
    assert.deepEqual(readInbox(dir).entries, []);
  }
  assert.equal(await main([...args, JSON.stringify(decision)], quiet), 0);
  assert.deepEqual(rebuildState(dir, { write: false }).changes.at(-1)?.decision, decision);

  const holder = JobLog.open(dir);
  try {
    const cli = path.join(PKG_ROOT, "dist", "cli.js");
    const invalid = spawnSync(process.execPath, [cli, ...args, '{"key":"missing","to":"2"}'], { encoding: "utf8" });
    assert.equal(invalid.status, 2, invalid.stderr);
    assert.match(invalid.stderr, /--decision.*missing/);
    assert.deepEqual(readInbox(dir).entries, []);
    const res = spawnSync(process.execPath, [cli, ...args, JSON.stringify(decision)], { encoding: "utf8" });
    assert.equal(res.status, 0, res.stderr);
    const entry = readInbox(dir).entries[0];
    assert.ok(entry?.kind === "change");
    assert.deepEqual(entry.decision, decision);
    const drain = () => drainInbox(dir, () => holder.events, () => holder.state, (e) => holder.append(e));
    const event = drain().appended[0];
    assert.ok(event?.type === "change_requested");
    assert.equal(event.inbox, entry.id);
    assert.deepEqual(event.decision, decision);
    assert.deepEqual(drain().appended, []);
  } finally { holder.close(); }
});
