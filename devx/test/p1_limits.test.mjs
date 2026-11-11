// P1: the gate's idea of a clock-only failure knows the new report shapes (a starved run, a processor-time tick_timeout).
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { CLOCK_MARKERS, classify } from "../lib/gate/flaky.mjs";

test("a starved run and a tick_timeout report are clock-only; a real failure is not", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl_p1_"));
  try {
    fs.writeFileSync(path.join(dir, "a.json"), JSON.stringify({ errors: [{ kind: "engine", message: "starved: _pack_tick ran 90 s of wall time and the machine gave it 3 ms (no verdict on the pack)" }] }));
    fs.writeFileSync(path.join(dir, "b.json"), '{"watchdog":{"reason":"tick_timeout","cpu_ms":251}}');
    fs.writeFileSync(path.join(dir, "c.json"), '{"checks":[{"id":"smoke.no_script_errors","ok":false}]}');
    assert.equal(classify("FAIL a: x\nFAIL b: y", dir).clockOnly, true);
    assert.equal(classify("FAIL a: x\nFAIL c: y", dir).clockOnly, false);
    assert.ok(CLOCK_MARKERS.length >= 3);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
