// H1i of the day run of 25 Nov 2026 (editor hardening, round 9), from lane G5's bumper karts and the Director's answer to
// H1h: a card names the bounds its choice lifts. Each test failed on main 86cf870 and passes now. (Item 1, Resume on a
// failed job's card, is the Create selftest block 864: create.failed.*.)
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup } from "./helpers.js";
import type { Brief, JobEvent } from "../events.js";
import { foldEvents } from "../joblog.js";
import { lastHandRows, retryEvents, waitingRound } from "../resumefix.js";
import { validateEvent } from "../events.js";
import { REPO_ROOT } from "../paths.js";
import { liftedBounds } from "../boundlift.js";
import { designerProblems, renderDesignerPrompt } from "../designer.js";
import { tofuMetricsFor } from "../tofu.js";

after(cleanup);

const G5 = (): Brief => JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "h1g", "g5-brief.json"), "utf8")) as Brief;

test("H1i 2 (the Director, after G5's \"Never Held\" ball was held to the hockey card's possession bound): an aspect's alternative carries `lifts`, the plan's tofu checks it makes meaningless; the person's pick lifts exactly those, and the word rule stays the fallback", () => {
  const brief = G5();
  const ball = brief.aspects?.find((a) => a.id === "ball");
  assert.ok(ball !== undefined);
  // the Designer writes it on the alternative (G5's card, with a neutral title so the word rule cannot guess)
  ball.alternatives = [{ id: "loose_ball", title: "Free Roller", line: "Push it, bump it, chase it.", lifts: ["possession_median_f"] }, ...ball.alternatives.slice(1)];
  const rows = tofuMetricsFor({ id: "arcade_sport" } as never, 3);
  const lifted = liftedBounds({ brief, reactions: { ball: { choice: "loose_ball", seq: 14 } } } as never, [], rows);
  assert.deepEqual([...lifted], [["possession_median_f", "your card \"Free Roller\" (it lifts possession_median_f)"]]);
  // the wire: a brief_set with `lifts` is valid; an empty list is not (absent = omit the key)
  const ev = { v: 1, seq: 3, ts: "2026-11-25T19:00:00.000Z", job: "j", type: "brief_set", brief, estimate: { packages: 8, wallMinutes: 420, tokens: 6000000 } };
  assert.doesNotThrow(() => validateEvent(ev));
  const empty = JSON.parse(JSON.stringify(ev)) as { brief: Brief };
  (empty.brief.aspects?.find((a) => a.id === "ball")?.alternatives[0] as { lifts?: string[] }).lifts = [];
  assert.throws(() => validateEvent(empty));
  // the Designer is told which checks exist, and a check that is not the build's is a problem of its answer
  assert.match(renderDesignerPrompt({ sentence: "bumper kart football", concept: G5().concept } as never), /carries `"lifts"`: the ids of\s+those checks \([^)]*`possession_median_f`/);
  const wrong = G5();
  const wb = wrong.aspects?.find((a) => a.id === "ball");
  if (wb !== undefined) wb.alternatives[0] = { ...wb.alternatives[0], id: "loose_ball", title: "Free Roller", line: "x", lifts: ["ball_held_frames"] } as never;
  assert.ok(designerProblems(wrong, { concept: { template: { id: "arcade_sport" } } } as never).some((p) => p.startsWith("alternative \"loose_ball\" of aspect \"ball\" lifts \"ball_held_frames\", which is not a tofu check of this build")));
  // without `lifts` the words still lift it (G5's real card, H1h)
  const real = G5();
  assert.ok(liftedBounds({ brief: real, reactions: { ball: { choice: "loose_ball", seq: 14 } } } as never, [], rows).has("possession_median_f"));
});

// ---------------------------------------------------------------- 1. Resume on a failed job: back to the failing test's owner

test("H1i 1 (G5 events 352-412: the hand check failed, its one send-back to core (r11) fixed the test but the round was refused by the possession bound; the job failed; `resume --retry-failed` re-ran only the final checks and failed the same way): a resume of a job that failed on a hand check sends the failing test's owner back, verifying its waiting fix without a builder run", () => {
  const dir = path.join(REPO_ROOT, "foreman", "fixtures", "h1i");
  const events = fs.readFileSync(path.join(dir, "g5-job-to-411.jsonl"), "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l) as JobEvent);
  const s = foldEvents("bumper-kart-football-3-20261125-1", events);
  assert.equal(s.jobState?.state, "failed");
  assert.equal(s.packages["core"]?.state, "promoted", "core is promoted, so the old --retry-failed queued nothing");
  const rows = lastHandRows(path.join(dir, "reports"));
  assert.deepEqual(rows.filter((r) => !r.ok).map((r) => r.test), ["tests/bot_hand_perfect.gd"]);
  assert.equal(waitingRound(events, "core"), 11, "core r11 answered ok after core's last merge: its fix waits");
  const out = retryEvents(s, events, rows, () => true);
  assert.deepEqual(out.map((e) => [e["type"], e["package"], e["state"], e["round"]]), [["package_state", "core", "verifying", 11]]);
  assert.match(String(out[0]?.["detail"]), /^resumed: round 11's fix waited unmerged in core's workspace \(the job failed at the hand check: tests\/bot_hand_perfect\.gd \(perfect hand\): 20 run\(s\) have no boolean "won" in their bot result\); it is checked again as it is, its builder is not run$/);
  // the fold reads it as a round left verifying: the Foreman verifies the workspace and does not pay the builder again
  const after = foldEvents(s.job, [...events, { v: 1, seq: 412, ts: "t", job: s.job, ...out[0] } as unknown as JobEvent]);
  assert.equal(after.packages["core"]?.state, "verifying");
  assert.ok(after.packages["core"]?.builtRounds.includes(11));
  // no workspace left: core is re-opened with the hand check's rows (a new round)
  const fresh = retryEvents(s, events, rows, () => false);
  assert.deepEqual(fresh.map((e) => [e["type"], e["package"], e["state"]]), [["reopened", "core", undefined], ["package_state", "core", "queued"]]);
  assert.match(String(fresh[0]?.["reason"]), /^hand check failed \(on resume\) for card card\.team_possession: tests\/bot_hand_perfect\.gd \(perfect hand\)/);
});
