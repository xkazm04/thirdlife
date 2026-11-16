// Why a package round runs, as one typed fold over the job log (src/rounds.ts). Pure: no job, no builder, no runner.
// The log format does not change: the kind is derived from the fixed starts of `detail` / `reason` (JOB.md).
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import type { JobEvent } from "../events.js";
import { changeReason, type JobState, type PackageView } from "../joblog.js";
import { PKG_ROOT } from "../paths.js";
import { CHANGE_ROUND, CRITIC_ROUND, DEP_CHANGED, FINAL_FAILED, KIT_REGRESSION, roundCap, roundKindOf, roundKinds, requeueDetail } from "../rounds.js";

let seq = 0;
const ev = (e: Record<string, unknown>): JobEvent => ({ seq: ++seq, ts: "2026-11-16T00:00:00.000Z", ...e }) as unknown as JobEvent;
const queued = (round: number, detail?: string): JobEvent => ev({ type: "package_state", package: "core", state: "queued", round, ...(detail !== undefined ? { detail } : {}) });
const reopened = (reason: string): JobEvent => ev({ type: "reopened", package: "core", reason });
const planSet = (): JobEvent => ev({ type: "plan_set", packages: [] });
const view = (roundBase: number): PackageView => ({ id: "core", round: roundBase - 1, roundBase }) as unknown as PackageView;

test("rounds 1: a queued round whose detail starts with the critic constant is a critic round", () => {
  const events = [planSet(), queued(1), queued(2, `${CRITIC_ROUND} (milestone greybox): look 2. Critic's notes: flat`)];
  assert.equal(roundKindOf(events, "core", 2), "critic");
  assert.equal(roundKindOf(events, "core", 1), "first");
});

test("rounds 2: a kit regression in the round after the critic's is the critic's kit retry", () => {
  const events = [planSet(), queued(1), queued(2, `${CRITIC_ROUND}: look 2`), queued(3, `${KIT_REGRESSION}: kit parts 4 -> 1. The round passed`)];
  assert.equal(roundKindOf(events, "core", 3), "critic_kit_retry");
  // Without the critic round before it, the same detail is a plain kit regression.
  const plain = [planSet(), queued(1), queued(2), queued(3, `${KIT_REGRESSION}: kit parts 4 -> 1`)];
  assert.equal(roundKindOf(plain, "core", 3), "kit_regression");
  assert.equal(roundKindOf(plain, "core", 2), "verify_retry");
});

test("rounds 3: the round cap is the re-opening round after a failed final verification, the round limit otherwise", () => {
  const fin = [planSet(), queued(1), reopened(`${FINAL_FAILED} (1 of 2) at smoke (V2) [report: x]. Sent back to core: owns it.`), queued(4, `${FINAL_FAILED} (1 of 2) at smoke`)];
  assert.equal(roundCap(view(4), roundKinds(fin), 4), 4);
  const change = [planSet(), queued(1), reopened(`${changeReason(12)}; the request names the package: bigger`), queued(4, `${CHANGE_ROUND}: bigger`)];
  assert.equal(roundCap(view(4), roundKinds(change), 4), 7);
  // Never re-opened: the limit counts from round 1.
  assert.equal(roundCap({ id: "core", round: 1 } as unknown as PackageView, roundKinds([planSet(), queued(1)]), 4), 4);
});

test("rounds 4: a re-opening whose queued was lost (a kill between) is re-queued with the detail it would have had", () => {
  const state = { changes: [{ seq: 12, text: "make the paddle bigger", state: "reopened" }] } as unknown as JobState;
  const events = [planSet(), queued(1), reopened(`${changeReason(12)}; the request names the package: make the paddle bigger`)];
  assert.equal(requeueDetail(events, state, "core"), `${CHANGE_ROUND}: make the paddle bigger`);
  const dep = [planSet(), queued(1), reopened("its dependency x was changed and merged again, and smoke (V2) now fails")];
  assert.equal(requeueDetail(dep, state, "core"), `${DEP_CHANGED}: its dependency x was changed and merged again, and smoke (V2) now fails`);
  const fin = `${FINAL_FAILED} (1 of 2) at smoke (V2) [report: r]. Sent back to core: owns it.`;
  assert.equal(requeueDetail([planSet(), queued(1), reopened(fin)], state, "core"), fin);
});

test("rounds 5: free text that only mentions the critic is a verify retry, not a critic round", () => {
  const events = [planSet(), queued(1), queued(2, "critic says the paddle is fine")];
  assert.equal(roundKindOf(events, "core", 2), "verify_retry");
});
