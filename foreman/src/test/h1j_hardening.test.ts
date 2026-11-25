// H1j of the day run of 25 Nov 2026 (editor hardening, round 10, the last of the day): the Director's answers to H1i, on
// lane G5's real bumper-kart job (d25-kart, read only; events to 411 in fixtures/h1i, 412-481 in fixtures/h1j). Each test
// failed on main 75bcf55 and passes now.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup } from "./helpers.js";
import type { JobEvent } from "../events.js";
import { REPO_ROOT } from "../paths.js";
import { foldEvents } from "../joblog.js";
import { sendBackHands } from "../handcheck.js";
import { lastHandRows, retryEvents } from "../resumefix.js";

after(cleanup);

const read = (f: string): JobEvent[] => fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", f), "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l) as JobEvent);
const JOB = "bumper-kart-football-3-20261125-1";

test("H1j 1 (the Director: pressing Resume means \"try again with today's editor\"; G5's one hand-check send-back (event 352) was spent before the job failed (411), so the resume at 412 failed the same check again at 461): every resume of a failed job grants one more send-back", () => {
  const upTo411 = read("h1i/g5-job-to-411.jsonl");
  const resumed = [...upTo411, ...read("h1j/g5-412-481.jsonl").filter((e) => e.seq === 412)];
  const rows = lastHandRows(path.join(REPO_ROOT, "foreman", "fixtures", "h1i", "reports"));
  const host = (events: JobEvent[]) => {
    const reopened: string[] = [];
    return { h: { s: foldEvents(JOB, events), events, reopen: (id: string) => reopened.push(id) } as never, reopened };
  };
  const before = host(upTo411);
  assert.equal(sendBackHands(before.h, rows), false, "before the resume: the send-back of event 352 is spent");
  const after = host(resumed);
  assert.equal(sendBackHands(after.h, rows), true, "after Resume (event 412): one more");
  assert.deepEqual(after.reopened, ["core"], "to the package that registers tests/bot_hand_perfect.gd");
});

test("H1j 2 (G5 events 462-481: after the job failed the person sent a change request; it re-opened core, whose round 12 ran in the workspace where round 11's hand-test fix waited, and merged both): a person's waiting change wins over Resume's send-back of the same package, and the waiting fix rides along with it", () => {
  const upTo411 = read("h1i/g5-job-to-411.jsonl");
  const later = read("h1j/g5-412-481.jsonl");
  const rows = lastHandRows(path.join(REPO_ROOT, "foreman", "fixtures", "h1i", "reports"));
  // the job failed again at 461 and the person's change is waiting at 462 (not yet routed)
  const atChange = [...upTo411, ...later.filter((e) => e.seq <= 462)];
  const s = foldEvents(JOB, atChange);
  assert.equal(s.jobState?.state, "failed");
  assert.ok(s.changes.some((c) => c.state === "pending"), "the change waits");
  assert.deepEqual(retryEvents(s, atChange, rows, () => true), [], "Resume does not set core verifying under a waiting change: the change goes first");
  // without the change, Resume would send core back (its waiting fix): the rule is about the change, not the job
  const noChange = [...upTo411, ...later.filter((e) => e.seq <= 461)];
  assert.equal(retryEvents(foldEvents(JOB, noChange), noChange, rows, () => true)[0]?.["state"], "verifying");
  // and the real outcome: the change round (r12) merged round 11's fix of the hand test with the change
  const merge = later.find((e) => e.type === "merge" && e.package === "core");
  assert.ok(merge?.type === "merge" && merge.files.includes("tests/bot_hand_perfect.gd") && merge.files.includes("scripts/core/kart.gd"), JSON.stringify(merge));
});
