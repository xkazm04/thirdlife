import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { PKG_ROOT } from "../paths.js";
import { cleanup, tempDir } from "./helpers.js";
after(cleanup);

const ask = { schema: "tl.place-ask/1", sentence: "three on three", card: "card.team_possession", answers: { players: "3" },
  footprint: { size_m: [47, 27], height_m: 9, shape: "rink" }, radius: 32,
  village: { plots: [{ id: "parkour", label: "parkour yard", kind: "plot", at: [4, 20], r: 30 }],
    road: [[1, 2], [80, 4]], road_half_m: 3, bounds: [-100, -100, 100, 100] } };
const proposals = [{ at: [0, -50], yaw_deg: 15, reason: "A short walk to the road." }, { at: [75, -80], yaw_deg: 0, reason: "Beyond the yard." }];
function place(input: unknown, replies: unknown[], promptText = "parkour yard | plot") {
  const root = tempDir("place"), file = path.join(root, "ask.json"), out = path.join(root, "answer.json");
  fs.writeFileSync(file, JSON.stringify(input));
  const script = path.join(root, "fake.json");
  fs.writeFileSync(script, JSON.stringify({ model: "village-designer", steps: replies.map((json, i) => ({
    match: { role: "placer", attempt: i + 1, promptIncludes: i ? "Your previous answer was rejected" : promptText },
    json, tokensIn: 10, tokensOut: 2,
  })) }));
  const site = path.join(root, "site");
  const run = spawnSync(process.execPath, [path.join(PKG_ROOT, "dist/cli.js"), "place", "--in", file, "--out", out,
    "--site", site, "--adapter", "fake", "--fake-script", script], { encoding: "utf8" });
  assert.ok(!fs.existsSync(site));
  return { code: run.status, error: run.stderr, result: fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, "utf8")) : undefined };
}
test("place writes checked proposals and the placer call's usage without starting a job", () => {
  const r = place(ask, [{ proposals }]);
  assert.equal(r.code, 0, r.error);
  assert.deepEqual(r.result.proposals, proposals);
  assert.deepEqual([r.result.schema, r.result.adapter, r.result.model, r.result.tokensIn, r.result.tokensOut],
    ["tl.place-answer/1", "fake", "village-designer", 10, 2]);
  assert.ok(r.result.durationMs >= 0);
});
test("place presents measured facts and preserves a candidate on the tolerance boundary", () => {
  const candidates = [{ id: "A", at: [0, -50], score: 87.5, facts: ["6 m walk from the gate to the road"] }];
  const picks = [{ ...proposals[0], at: [0.5, -50], candidate: "A" }, proposals[1]];
  const r = place({ ...ask, candidates }, [{ proposals: picks }], "A | 0,-50 | 87.5 | 6 m walk from the gate to the road");
  assert.equal(r.code, 0, r.error);
  assert.deepEqual(r.result.proposals, picks);
});

test("place retries unknown candidates, offsets beyond half a metre, and invented figures", () => {
  const candidates = [{ id: "A", at: [0, -50], score: 88, facts: ["flat ground"] }];
  const picks = [{ ...proposals[0], candidate: "A" }, proposals[1]];
  for (const invalid of [{ candidate: "B" }, { at: [0.4, -49.6] }, { reason: "A 78 m walk to the road." }]) {
    const r = place({ ...ask, candidates }, [{ proposals: [{ ...picks[0], ...invalid }, picks[1]] }, { proposals: picks }]);
    assert.equal(r.code, 0, r.error);
    assert.deepEqual(r.result.proposals, picks);
    assert.equal(r.result.tokensIn, 20);
  }
});

test("place rejects an unknown nested input key before generating", () => {
  const r = place({ ...ask, village: { ...ask.village, mystery: 1 } }, []);
  assert.equal(r.code, 2);
  assert.match(r.error, /--in.*mystery/);
  assert.equal(r.result, undefined);
});
test("place reports a model error after two malformed answers", () => {
  const r = place(ask, [{ proposals: [] }, { proposals: [{ path: [] }] }]);
  assert.equal(r.code, 1);
  assert.match(r.result.error, /after 2 attempts/);
  assert.deepEqual(Object.keys(r.result).sort(), ["error", "schema"]);
});
test("place retries duplicate or out-of-bounds centres with feedback and counts both calls", () => {
  for (const at of [[3, -49], [101, 0]]) {
    const r = place(ask, [{ proposals: [proposals[0], { ...proposals[1], at }] }, { proposals }]);
    assert.equal(r.code, 0, r.error);
    assert.deepEqual(r.result.proposals, proposals);
    assert.equal(r.result.tokensIn, 20);
  }
});
