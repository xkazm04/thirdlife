// M4 (spark world-sandbox): `tl ledger` reads the Home's LLM calls log (<home>/llm_calls.jsonl, written by
// engine/kernel/world/build/command_calls.gd): the last line of a call id is the call.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { findHome, readCalls } from "../lib/commands/ledger.mjs";

function home(lines) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl-ledger-home-"));
  fs.writeFileSync(path.join(dir, "llm_calls.jsonl"), lines.map((l) => (typeof l === "string" ? l : JSON.stringify(l))).join("\n") + "\n");
  return dir;
}

test("the last line of a call is the call; totals count kept, reverted, failed and pending", () => {
  const dir = home([
    { id: "a", ts: "2026-11-26T10:00:00Z", day: "2026-11-26", sentence: "a tower", accepted: "pending" },
    { id: "a", ts: "2026-11-26T10:00:00Z", day: "2026-11-26", sentence: "a tower", accepted: true, model: "opus", tokensIn: 1000, tokensOut: 200, durationMs: 60000, ops: 120, applied: 118, refused: 2 },
    { id: "b", ts: "2026-11-26T10:05:00Z", day: "2026-11-26", sentence: "a wall", accepted: false, model: "opus", tokensIn: 500, tokensOut: 50, durationMs: 20000, ops: 10, applied: 10, refused: 0 },
    "not json",
    { id: "c", ts: "2026-11-26T10:06:00Z", day: "2026-11-26", sentence: "a bridge", accepted: false, error: "the model is not reachable" },
    { id: "d", ts: "2026-11-26T10:07:00Z", day: "2026-11-26", sentence: "a lamp", accepted: "pending" },
  ]);
  const r = readCalls(path.join(dir, "llm_calls.jsonl"));
  assert.deepEqual(r.calls.map((c) => c.id), ["a", "b", "c", "d"]);
  assert.equal(r.calls[0].accepted, true);
  assert.deepEqual(r.totals, { calls: 4, kept: 1, reverted: 1, failed: 1, pending: 1, tokensIn: 1500, tokensOut: 250, durationMs: 80000 });
  assert.equal(findHome({}, dir), path.resolve(dir));
  assert.equal(findHome({ TL_HOME_BUILD_DIR: dir, APPDATA: "" }), path.resolve(dir));
  assert.equal(findHome({}, path.join(dir, "nowhere")), null);
});
