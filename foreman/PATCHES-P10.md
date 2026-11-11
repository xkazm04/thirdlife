# P10: patches outside `foreman/**` (not applied; for the Director)

Each entry: the file, the exact change, the reason. Nothing here is needed for `foreman/` to be green.

## 1. `engine/ui/panel.gd` and `engine/ui/foreman_door.gd`: answer while the Foreman builds

Reason: since P10 `foreman answer` and `foreman change` no longer need the job's lock. While another Foreman process
runs the job they write one line to `<job>/inbox.jsonl` and return 0; the running Foreman logs the `answer` (or
`change_requested`) within `--inbox-poll-ms` (default 1000 ms), starts the asking package again while its other
packages keep building, and re-opens a finished package for a change at once. The panel still waits for a pause, and
the door still follows an answer with `resume`, which now is the only step that would fail on the lock.

`engine/ui/panel.gd`, `_question_block` (line 1092 in this worktree):

```gdscript
-	var working: bool = phase in JobModel.LIVE_PHASES
-	var can: bool = door != null and door.available and not read_only and busy.is_empty() and not working
+	var working: bool = phase in JobModel.LIVE_PHASES
+	var can: bool = door != null and door.available and not read_only and busy.is_empty()
```

and, a few lines below, drop the hint that is no longer true:

```gdscript
-		if working and busy.is_empty():
-			why = "The Foreman still works on other packages; it takes your answer when it pauses."
```

and pass whether a Foreman is alive (the panel already knows: `door.foreman_alive(dir, int(j.get("lock_pid", 0)))`):

```gdscript
-		var e: String = door.answer(str(j["dir"]), str(q["package"]), field.text, str(meta) if meta != null else "")
+		var alive: bool = door.foreman_alive(str(j["dir"]), int(j.get("lock_pid", 0)))
+		var e: String = door.answer(str(j["dir"]), str(q["package"]), field.text, str(meta) if meta != null else "", alive)
```

`engine/ui/foreman_door.gd`, `answer` (line 133):

```gdscript
-func answer(job_dir: String, package: String, text: String, change_package: String) -> String:
+## `foreman_running`: a Foreman holds this job. The answer then goes through its inbox and it continues by itself;
+## a `resume` step would only collide with its lock.
+func answer(job_dir: String, package: String, text: String, change_package: String, foreman_running: bool = false) -> String:
 	var t: String = clean_text(text)
 	if t.is_empty():
 		return "write the answer first"
 	var a: Array = ["answer", job_dir, package, t]
 	if not change_package.is_empty():
 		a.append_array(["--change", change_package])
-	return _start(job_dir, "answer", [a, ["resume", job_dir] + _flags("resume")])
+	if foreman_running:
+		return _start(job_dir, "answer", [a])
+	return _start(job_dir, "answer", [a, ["resume", job_dir] + _flags("resume")])
```

`change()` needs no edit: `foreman change <job> "<text>"` on a running job writes to the inbox and exits 0 without
running anything (its stdout begins `change request handed to the running Foreman`). The panel's "Ask for a change"
control can therefore be enabled while a job is `running` too, if the Director wants that; the request waits in the
log as `pending` until its package is finished and idle.

`engine/ui/selftest.gd` line 182 (`dry.answer("J", "feel", "yes", "core")`) keeps passing: the new argument has a
default. A case for the running job would be `dry.answer("J", "feel", "yes", "", true)` expecting ONE step.

The job model (`engine/ui/job_model.gd`) reads `answer` and `change_requested` events as before; both may now carry
one more key, `inbox` (a string). If the model checks keys strictly, add it.

## 2. `contracts/JOB.md`: the section "Added after P10"

The proposed text is in the P10 report (and at the end of the "P10" section of `foreman/JOURNAL.md`). Summary of what
changes on the wire: `answer` and `change_requested` may carry `inbox`; new files `inbox.jsonl` and
`inbox.rejected.jsonl` in a job directory; `verify` reports named `<pkg>-r<round>-pack-bot-<test>` and
`<pkg>-r<round>-control-bot-<test>`; a `reopened.reason` and a `queued` detail starting `FINAL VERIFICATION FAILED`;
a `done` job whose reason starts `the change was NOT made`; `foreman change` and `foreman answer` no longer refuse
while another Foreman holds the lock.

## 3. `engine/cards/*.json` and `contracts/CARDS.md` (recipe cards): name the player's check per kind of game

Reason: the Planner prompt now asks for a bot that fails when the human-controlled side has nothing to do, with
generic examples. A recipe card knows the right check for its kind of game and could carry it, so the Planner copies
it instead of inventing one. Proposed optional key on a card (`contracts/CARDS.md`), beside the card's `bot` key.
Suggested values for the three cards that exist (drafts: I read the cards' titles and summaries, not their bots):

```json
"player_check": "fails when the player's side touched the ball fewer than 3 times, or when the result with the bot idle equals the result with the bot playing"     // two_sides_ball
"player_check": "fails when the car passed no checkpoint through the bot's own inputs (a car nobody steers must not finish a lap)"     // timed_drive
"player_check": "fails when no piece was knocked out of place by a ball the player threw (a piece that falls without a throw does not count)"     // knock_down
```

Not applied: cards and their contract are outside `foreman/**`, and "unknown keys are errors" means the card schema
must change with it.

## 4. `docs/reports/JOB3-HOCKEY.md`, finding 12 (information)

Reason: the finding says "a change request could carry the current value so that 'bigger' has a scale". Measured on
the pack the first request was made on (`site/ice-hockey-three-against-20261111-1/promoted/game.ice_hockey_three_against`,
version 0.1.0): the puck's size was in neither `params` (5 entries, none for the puck) nor `data/*.json`
(`tuning.json` has `puck.max_speed` and `puck.drag` only). It was a literal in the owner's script:
`scripts/main.gd:40: puck = TLBall.create({"part": TLKit.build("puck", {"radius": 0.15, "height": 0.08}), ...`.
The table the brief asked for would not have shown it. P10 therefore lists a third source, the numbers the owner's
own scripts give to named keys, and the test `3 present values: a figure that is in no data file ...` proves that
line is found in the real pack.

## 5. `devx/arch.baseline.json`: the size ratchet and `foreman/src/foreman.ts` (the gate is RED on this until decided)

Reason: `tl arch` (rule `size-ratchet`) lets a grandfathered file shrink but not grow. `foreman/src/foreman.ts` was
2138 lines and is 2477 after P10; `tl check` therefore fails at `arch`, and `devx.test` fails with it (two of its
cases run the real tree and expect it green). I found this only when the full gate ended at 14:26, and fixed what
could be fixed safely in the time left: `cli.ts` is back under its number (975 -> 906; the two request commands
moved to the new `src/requests.ts`), the test file is split (`p10.test.ts` 488 lines, `p10b.test.ts` 186), and the
pure helpers moved to the new `src/p10.ts` (148 lines). What is left in `foreman.ts` are methods of the `Foreman`
class that use its private state. Two ways to make the gate green; the first is one line, the second is the right one:

1. Bump the number (the Director's file):

```json
-    "foreman/src/foreman.ts": 2138,
+    "foreman/src/foreman.ts": 2477,
```

2. Split, about 30 minutes with a full suite run (not done: I would not move the core loop's methods in the last
   twenty minutes without one). The methods that move as free functions over a small host object (`o`, the state,
   the events, `append`, `rel`, `dir`, `pkg`, `verifyLogged`, `verifyOnce`, `reopen`): `testOwner`, `packTestsFor`,
   `packTest` (item 1); `finalLimit`, `finalSent`, `testOfVerify`, `blameFinal`, `sendBackFinal` (item 2);
   `starvedVerdict`, `countStarved`, `starvedDetail` (item 5). That is about 240 lines; the last 100 are the inbox
   methods (`takeInbox`, `changeReady`, `askedOwners`), the two feedback paragraphs and the option comments, or an
   older block of the same file (the N3c stall classification, about 60 lines with its helpers, is a natural second
   module: see the report on what no longer fires).
