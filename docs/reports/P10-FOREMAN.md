# P10 the Foreman's change path: builder report and Director verification

Brief `briefs/BRIEF-P10-FOREMAN.md`. Builder wall time 13:22 to 14:40 on 2026-11-11 (77 min; harness: 489,053 subagent tokens, 205 tool uses). Work done in the worktree `.claude/worktrees/core-p10` (branch `core-p10-foreman`).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

STATUS: all six items are built and proven with fixtures, but the full gate is RED on one finding of mine. `tl arch` (size-ratchet) refuses `foreman/src/foreman.ts` at 2477 lines against its grandfathered 2138. The remedy is yours to choose (PATCHES-P10.md entry 5, below). No model call, no git command, nothing edited outside `foreman/**`.

All paths below are under `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p10\` unless written in full. "Scratchpad" is `C:\Users\kazda\AppData\Local\Temp\claude\7d3340621aca3b8f\23bbf8b6-20c4-4024-8c8c-d890f693decb\scratchpad\`.

## 1. Per item: what was built and what proves it

**Item 1, a rebuilt dependant is checked against the whole pack** (`foreman/src/foreman.ts`: `packTestsFor`, `packTest`, called from `mergeAndGate`)
- After a re-opened package's candidate passes lint and smoke, every test of the pack that no dependant answers for runs on the candidate. A dependant answers for a test it registers or runs in its acceptance; those run right after the merge in the dependants' re-verification.
- A failing test of another package is compared with a control run of the same test on `pack/` without the round's files.
  - Control passes: the merge is refused and a `[foreman] PACK TEST FAILED` note names the test's package and the merging package.
  - Control fails too: a note, and the merge goes on.
- My first rule ("every test not registered by a dependant") was wrong. It refused the owner's own merge in an existing N3 test, which is the case the change path exists for. The rule above replaced it.
- Proof: test "1 replay of the real hockey job's first change request" in `foreman/src/test/p10.test.ts`.
- Proof by command line: `foreman run`, then `foreman change "<the real first request>"` on a copy of the fixture: 143 events, `done`, 0.1.1 beside 0.1.0.
  - Event 116: the owner's bot FAILED on hockey_ai's round-2 candidate.
  - Event 117: control ok. Event 118: the note.
  - Events 130/131: both bots ok on the round-3 candidate. Events 137/138: final bots ok.
  - Output: `<scratchpad>replay\change.out`; log: `<scratchpad>replay\site\ice-hockey-change-replay-1\job.jsonl`.

**Item 2, a failed final verification goes back to a package** (`sendBackFinal`, `blameFinal`, `cap`, `finish`)
- After an earlier promotion, a final failure re-opens one package for one round (`FINAL VERIFICATION FAILED (n of limit) ... [report: ...]`).
- How the package is chosen, from the log:
  - Bot: the package that merged last after the state the test's last passing run saw. If nothing merged since, or the test never passed, the package that registers the test.
  - lint, smoke, invariants: the package that merged last since the promotion.
- Limit: `--final-rounds`, default the round limit, counted from the last `promoted` or `change_requested`. When spent, the job ends `done` with a reason starting `the change was NOT made:` that names the earlier promotion.
- A first build with no promotion still ends `failed`.
- Proof: the two tests "2 final verification: ..." in `p10.test.ts`. With the merge gate off, the real job's failure re-opens hockey_ai ("hockey_ai merged last ... and nothing else changed"), one round, `done`. With an AI that never fixes it and `finalRounds` 2: `done`, "the change was NOT made", promotion 0.1.0 untouched, three AI runs in total.

**Item 3, a change request carries the present value** (`presentValuesText` in `foreman/src/p10.ts`)
- The prompt of a package with change requests gets a section "The values as they are now": each `params` entry with value and range, then the small values of every `data/*.json`.
- **The brief's premise did not hold for last night's pack.** On the real 0.1.0 pack the puck's size was in neither `params` nor `data/*.json`. It was a literal at `scripts/main.gd:40`: `TLKit.build("puck", {"radius": 0.15, "height": 0.08})`. The table as specified would not have shown it.
- I added a third source: numbers the owner's scripts give to named keys.
- Proof: tests "3 present values: ..." (three). One reads the real promoted pack (read only) and asserts that only the script line carries the radius. Table for the real pack: `<scratchpad>real-pack-values.txt` (3764 characters, 16 lines).

**Item 4, the inbox** (`foreman/src/inbox.ts`, `foreman/src/requests.ts`, `takeInbox` in the scheduling loop)
- `foreman answer` and `foreman change` on a running job append one line to `<job>/inbox.jsonl` and exit 0.
- The running Foreman reads it at start, every `--inbox-poll-ms` (default 1000), before it pauses, fails or finishes, and before it releases the lock.
- Each entry becomes the same event with `inbox: <id>`, so nothing is lost or logged twice across a kill.
- An answered package restarts while others build. A change request waits as `pending` until its package is finished and idle.
- Proof: five tests "4 inbox: ...". The two-process test spawns `foreman run`, then `foreman answer` and `foreman change` as separate processes: both events exactly once, in file order, taken while `court` was still building, no lock error, exit 0. It passed in every run, including the overloaded one.

**Item 5, the engine's verdicts** (`isStarved`, `starvedStalls` in `p10.ts`; `starvedVerdict`, `starvedDetail` in `foreman.ts`)
- Exit 2, `not_run`, engine error beginning `starved:` is treated as the machine: note, the usual pauses and retries, then `blocked` with cause `machine_busy` and the job `paused`.
- `metrics.starved_stalls` is summed into the `detail` of the event that ends the round.
- Proof: two tests "5 starved: ..." in `foreman/src/test/p10b.test.ts`: one builder run, no `failed`, round stays 1, and a resume verifies the same files without a builder.
- The report shape was read from `engine/kernel/host/host.gd` lines 300-307 and 566-573. It was not produced by a real starved run.
- The fake runner now matches the engine (`invariants.many_budget`, the new `frame_budget` detail). The real-against-fake parity test was failing before I touched anything, because P1 added that check.

Dead code, as asked. With a P1 engine on Windows with the processor clock:
- `classifyStalls` verdict `machine_load` (different frames) can no longer be produced.
- The second run in `verifyTwice` for a `tick_timeout` is redundant, since the result is deterministic.
- `measureMachine` (the reference gauge) is reachable only through a frame-budget-only failure, which the engine now judges on each frame's best of N runs.
- The N3c re-read in `feedback()` fires only for old logs.

All of it is still live where the engine counts wall time: `TL_NO_CPUCLOCK=1`, non-Windows, and the `site/_engine_snapshot*` engines that real jobs have used so far. I propose removal once jobs run only against a P1+ engine. Removed tonight: nothing.

**Item 6, the player's part** (`playerChecks`, `playerCheckProblems` in `foreman/src/designer.ts`; `foreman/prompts/planner.md`, `builder.md`)
- A plan in which a package registers `input` must hold, in a contract, a line `PLAYER CHECK: tests/<bot>.gd fails when <...>` naming a registered bot. The plan check refuses a plan without it.
- I withdrew a sub-rule that the bot must be in some acceptance: it refused a partial re-plan, and the final verification runs every registered bot anyway.
- Proof: two tests "6 player check: ..." in `p10b.test.ts`, and `foreman/dry/p10-prompts-racing.txt` (the new text is at lines 237-248).
- Not provable without a model: whether a Planner writes the line, and whether the bot a builder writes really fails when the player has nothing to do.

## 2. Acceptance checks

| Check | Result |
|---|---|
| `npx tsc --noEmit` clean | Yes |
| `npm test` passes, none skipped without a reason | Yes: 181 tests, 174 pass, 0 fail, 7 skipped (5 "TL_GODOT is not set", 2 older tests that need the marble job under this checkout's `site/`), 198 s run alone |
| Same suite with the real engine | The five engine tests pass on the final build (82 s). A whole-suite engine run was done only on the build before the last correction and the file splits: 180 tests, 178 pass, 0 fail |
| Replay fixture: both bots, one step earlier, not `failed` | Yes |
| Change request on a pack with `params`: owner's prompt shows current values | Yes (`puck.radius = 0.15 (min 0.04, max 0.3, step 0.01)`, and 0.35 after the first change) |
| Two processes on one job through the inbox | Yes |
| `starved` run: nothing to a builder, round not spent | Yes |
| Dry prompt `foreman/dry/p10-prompts-racing.txt` | Yes, 92 KB, hand-written brief |
| Proposed text for `contracts/JOB.md` | Section 4 below |

Gates:
- `tl check --tier fast --changed` passed at 13:53, but before the size findings existed for me to see: `--changed` selected only `foreman.typecheck`. `tl arch`, run directly at 14:28, FAILS on the foreman.ts size finding.
- `tl check --tier full` (13:57 to 14:26, log `<scratchpad>full-gate.txt`) ended RED:

| Step | Result |
|---|---|
| arch | FAIL: size-ratchet, three findings then; one left now (foreman.ts) |
| devx.test | FAIL: 121 pass, 2 fail; the visible failure names are the real-tree-green cases, which I take to follow from arch |
| foreman.test | FAIL: wall-clock process-kill tests (two named, the list was cut off). I had started a second suite beside the gate by mistake |
| foreman.test, rerun alone (`--only foreman.typecheck,foreman.test`, `<scratchpad>gate2.txt`) | PASS, "174 pass, 0 fail" |
| kernel.selftest | FAIL: 0 failed, 77 passed, then the step's 15-minute limit. Engine untouched by me |
| assets, cards, foreman.typecheck, kit.selftest, seeds (24 cases) | PASS |
| perf | PASS, "machine BUSY ... NOT judged and not recorded" (not marked quiet) |
| item.selftest, ui.selftest | Skipped (need the marble job) |

The rerun's 174 means the five engine tests did not run inside the gate step; I did not look into why.

## 3. Files changed (all under `foreman/`)

- `src/foreman.ts`: items 1, 2, 4 (drain and poll), 5; the prompt section for item 3. 2138 to 2477 lines.
- `src/p10.ts` (new, 148 lines): fixed texts, `isStarved`, `starvedStalls`, `presentValuesText`; re-exported by foreman.ts.
- `src/inbox.ts` (new, 182): entry format, atomic append, strict read, drain with dedupe by id, rejected list.
- `src/requests.ts` (new, 103): `foreman change` / `answer` (log or inbox) and `lockHolder`, moved out of cli.ts.
- `src/cli.ts`: calls requests.ts; flags `--pack-tests`, `--final-rounds`, `--inbox-poll-ms`; help. 918 to 906 lines.
- `src/events.ts`: optional `inbox` on `answer` and `change_requested`.
- `data/job-events.schema.json`: regenerated.
- `src/designer.ts`: the player check in `planCheck`.
- `prompts/planner.md`: the rule "The player's part is tested".
- `prompts/builder.md`: the player's part; the clock paragraph says what the engine does since P1.
- `src/testing/fake-runner-core.ts`: `FAKE_RUNNER_STARVED`, `FAKE_STARVED`, `FAKE_RUNNER_STARVED_STALLS`, `FAKE_TEST_NEEDS(<bot>:<token>)`, `invariants.many_budget`.
- `src/test/p10.test.ts` (new, 488 lines, 11 tests: items 1 to 4) and `src/test/p10b.test.ts` (new, 186 lines, 5 tests: items 5 and 6).
- `fixtures/make-hockey-fixture.mjs` and `fixtures/job-hockey-change/` (job.jsonl, fake-builder.json, foreman.config.json): the real job's plan and events 232-279 as a fake script.
- `fixtures/make-fixture.mjs`, `fixtures/job-paddle/job.jsonl`: the root's contract names its PLAYER CHECK.
- `dry/night-street-race-20261111-0/job.jsonl`, `dry/p10-prompts-racing.txt`.
- `JOURNAL.md` (section "P10"), `PATCHES-P10.md`.

## 4. Proposed text for `contracts/JOB.md`

```
### Added after P10 (2026-11-11): the change path, the inbox, the engine's verdicts, the player's check

- **Pack tests at a merge.** For a package that was re-opened (a `reopened` event) or is merged again, the whole-pack
  check before the merge runs, after `lint` and `smoke`, every test of the candidate's manifest that no package
  depending on the merging one answers for (a dependant answers for a test it registers and for a test its acceptance
  runs; those run right after the merge, in the dependants' re-verification). They are `verify` events without
  `package`, with `after: <pkg>`, report `reports/<pkg>-r<round>-pack-bot-<test>-s<seq>.json`. When a test of another
  package fails there, the same test is run on `pack/` without the round's files
  (`reports/<pkg>-r<round>-control-bot-<test>-s<seq>.json`). Control passes: the merge is refused, the round fails as
  for any failed check, and a note `[foreman] PACK TEST FAILED after the merge of <pkg> was tried: <test>, a test of
  package <owner>, ...` names both packages. Control fails too: a note `[foreman] pack test fails without this merge
  too: ...` and the merge goes on. `--pack-tests after_change|always|never`; default `after_change`.
- **A failed final verification after a promotion does not end the job.** The failure goes to one package:
  `reopened {package, reason}` whose reason starts `FINAL VERIFICATION FAILED (<n> of <limit>) at <verb> ...
  [report: <path>]. Sent back to <pkg>: <evidence>`, then `queued` with the same text as detail. That package gets
  ONE round. Which package: for a bot, the one that merged last after the state that the test's last passing run in
  the log saw; when nothing merged since, or the log has no passing run, the package that registers the test; for
  `lint`, `smoke` and `invariants` the package that merged last since the last promotion. Limit: `--final-rounds`
  (default: the round limit), counted from the last `promoted` or `change_requested`. When it is spent the job ends
  `job_state {state: "done"}` with a reason that starts `the change was NOT made:` and names the earlier promotion;
  there is no new `promoted` event and `pack/` keeps the unpromoted files. A job without a promotion ends `failed`
  as before.
- **Present values.** The prompt of a package that carries change requests has, under the requests, a section
  "The values as they are now": every `params` entry with its current value and range; the small values (numbers,
  booleans, strings up to 40 characters, lists of up to four numbers) of every `data/*.json`; the numbers the
  package's own scripts give to named keys. No model is asked and no event is written.
- **Inbox.** `<job>/inbox.jsonl`: one JSON object per line, appended in one write.
  `{id, ts, kind: "answer", package, text, by, change?}` or `{id, ts, kind: "change", text, package?}`; unknown keys
  are errors; a last line without its newline is not read yet. `foreman answer` and `foreman change` write there
  (exit 0; nothing is run) while another Foreman holds the job's lock, and write the log themselves otherwise, after
  what the inbox still holds. The lock holder reads the inbox when it starts, every `--inbox-poll-ms` (default 1000)
  while builders run, before it decides to pause, fail or finish, and once more before it releases the lock. Each
  entry becomes the event it would have been, with the entry's id in `inbox` (`answer.inbox`,
  `change_requested.inbox`: optional strings). An entry is taken when an event with its id exists; one that cannot
  become an event (no open question, an unknown package, nothing merged yet) is appended to
  `<job>/inbox.rejected.jsonl` with the reason and not tried again. An answered package is started again at once,
  while the other packages go on building. A change request taken while builders run re-opens its package only
  when that package is `promoted` and no builder is working on it; until then the request stays `pending` in the
  log, and it is applied at the latest when no builder runs any more (as at the start of a run).
  This replaces "it refuses while another Foreman holds the job's lock" in the section added after N3. `run`,
  `resume` and `cancel` still refuse.
- **Starved.** A runner result with exit 2, outcome `not_run` and an error of kind `engine` whose message begins
  `starved:` is the machine's, never the pack's: a note `[foreman] inconclusive: machine busy. the machine starved
  the run: ...`, the same pauses and retries as for a clock-based failure, then `blocked` with cause `machine_busy`
  and the job `paused`. Nothing is sent to a builder and the round is not spent. When the checks of a round report
  `metrics.starved_stalls`, the sum is in the `detail` of the `package_state` that ends the round (`promoted`,
  `failed`) or of the next `running`: `starved_stalls <n> (<ms> ms) in <k> check run(s) ...`.
- **Player check.** A plan in which a package registers the capability `input` must hold, in a contract, a line
  `PLAYER CHECK: tests/<bot>.gd fails when <what the human-controlled side can no longer do>`; the bot must be in a
  package's `registers.tests`. The plan check refuses a plan without it (first plan, re-plan, a hand-written plan).
- Files in a job directory added by this: `inbox.jsonl`, `inbox.rejected.jsonl`.
```

## 5. Contents of `foreman/PATCHES-P10.md` (nothing applied)

Entry 1 and entry 5 carry code and are given in full; entries 2 to 4 are condensed here and complete in the file.

**Entry 1. `engine/ui/panel.gd` and `engine/ui/foreman_door.gd`: answer while the Foreman builds.** The panel still waits for a pause, and the door follows an answer with `resume`, which is now the only step that would collide with the lock.

`panel.gd`, `_question_block` (line 1092):
```gdscript
-	var can: bool = door != null and door.available and not read_only and busy.is_empty() and not working
+	var can: bool = door != null and door.available and not read_only and busy.is_empty()
```
Drop the hint that is no longer true:
```gdscript
-		if working and busy.is_empty():
-			why = "The Foreman still works on other packages; it takes your answer when it pauses."
```
Pass whether a Foreman is alive:
```gdscript
-		var e: String = door.answer(str(j["dir"]), str(q["package"]), field.text, str(meta) if meta != null else "")
+		var alive: bool = door.foreman_alive(str(j["dir"]), int(j.get("lock_pid", 0)))
+		var e: String = door.answer(str(j["dir"]), str(q["package"]), field.text, str(meta) if meta != null else "", alive)
```
`foreman_door.gd`, `answer` (line 133):
```gdscript
-func answer(job_dir: String, package: String, text: String, change_package: String) -> String:
+func answer(job_dir: String, package: String, text: String, change_package: String, foreman_running: bool = false) -> String:
 	...
-	return _start(job_dir, "answer", [a, ["resume", job_dir] + _flags("resume")])
+	if foreman_running:
+		return _start(job_dir, "answer", [a])
+	return _start(job_dir, "answer", [a, ["resume", job_dir] + _flags("resume")])
```
- `change()` needs no edit: on a running job the CLI writes to the inbox and exits 0.
- `selftest.gd` line 182 keeps passing, because the new argument has a default.
- If `job_model.gd` checks event keys strictly, add `inbox` (string) to `answer` and `change_requested`.

**Entry 2. `contracts/JOB.md`.** The section above.

**Entry 3. `engine/cards/*.json` and `contracts/CARDS.md`.** An optional `player_check` key beside `bot`, so the Planner copies the right check per kind of game. Draft values for the three cards are in the file; I read the cards' titles and summaries, not their bots. The card schema must change with it.

**Entry 4. `docs/reports/JOB3-HOCKEY.md`, finding 12 (information).** The puck's size was a script literal, not a param or data value (item 3 above).

**Entry 5. `devx/arch.baseline.json`: the size ratchet (the gate is RED on this).** Two remedies:
1. Bump the number (one line, your file):
```json
-    "foreman/src/foreman.ts": 2138,
+    "foreman/src/foreman.ts": 2477,
```
2. Split, about 30 minutes with a full suite run. I did not do this: I would not move the core loop's methods in the last twenty minutes without a full run.
   - Move as free functions over a small host object: `testOwner`, `packTestsFor`, `packTest`; `finalLimit`, `finalSent`, `testOfVerify`, `blameFinal`, `sendBackFinal`; `starvedVerdict`, `countStarved`, `starvedDetail`. That is about 240 lines.
   - The last 100 lines are the inbox methods, two feedback paragraphs and option comments, or the older N3c stall classification as a second module.

## 6. What changed for a pack author (and a plan author)

- A plan with player input needs the `PLAYER CHECK:` line and a registered bot whose `ok` depends on what the player's side did.
- After a change, a rebuilt package must pass every test of the pack with its files merged in, not only its own acceptance.
- Put tunable numbers in `data/*.json` and declare them in `params`. A change request then shows the value and range; a number left in a script appears only as a raw script line.
- No change to the pack format, the runner, or any engine file.

## 7. Not verified

- Anything a model does: whether a Planner writes the PLAYER CHECK line and a useful bot, whether a builder takes "bigger" as a modest step once it sees the present value, and how builders react to the pack-test and final-verification feedback.
- A real `starved` report: the shape was read from host.gd, not observed.
- Pack tests and the final send-back on the real runner. The real-engine N3 change test passes with the new code, but its plan has one bot.
- The inbox with the claude-cli adapter, and with more than two writers at once.
- The panel and door patch: not applied, not run.
- A whole-suite engine run on the final build (only the five engine tests were rerun).
- The cost of `--pack-tests always` on a real job.

Findings about the machine:
- `kernel.selftest` hit its 15-minute step limit with 0 failures.
- The Foreman's own test `spawn door: our timeout kills the process tree` (`foreman/src/test/builder.test.ts:163`) rests on wall-clock waits: it failed twice under two suites at once and passes alone. I did not change it.

## 8. Questions

1. Bump the baseline, or assign the split of foreman.ts (entry 5)?
2. Should a failed final verification of a first build also go back to a package? I kept `failed`, as the brief says "after a change".
3. Should `--pack-tests always` be the default? It would have caught finding 7 at the AI's first merge, at the price of one bot run per test per merge.
4. When a change ends "not made", `pack/` keeps the unpromoted files and the next request builds on them (as last night's second request did). Should it be put back to the promoted pack instead?
5. May the second-line clock code go once the pre-P1 snapshot engines are retired?

## 9. Minutes

Start 13:22:50, report at about 14:40 (both from `date`): 77 minutes of the 90. No node or Godot process of mine is left running.

---

## Director verification

Done 14:41 to 15:10 on 2026-11-11 in the builder's worktree.

### The gate was red, and what was done about it

The builder's full gate failed on one finding of its own: `foreman/src/foreman.ts` had grown from 2,138 to 2,477
lines against the size ratchet. The Director did not raise the number. A second builder (Opus, 24 minutes) split the
file without changing behaviour: the options interface, the machine-or-pack checks, the builder conduct texts and the
P10 gate functions moved into four new modules (`options.ts` 108 lines, `machine.ts` 118, `conduct.ts` 105,
`p10gate.ts` 183); `foreman.ts` is 2,032 lines. Moved code was compared block by block with the original by script;
every export is still exported from `foreman.ts`.

### What was re-run, and the result

| Check | Result |
|---|---|
| `npx tsc --noEmit` in `foreman/` (Director) | clean |
| `node devx/bin/tl.mjs arch` (Director) | 8 rules PASS; the size ratchet holds 14 files at their baseline and names none |
| `npm test` alone, after the split (second builder) | 181 tests, 174 pass, 0 fail, 7 skipped: the same count as before the split |
| the same with the real engine (`TL_GODOT` and `TL_ENGINE_DIR` set to the worktree's engine) | 181 tests, 179 pass, 0 fail, 2 skipped (they need job folders under `site/`) |
| `node devx/bin/tl.mjs check --tier fast` (second builder) | PASS |

The second builder also applied the panel patch (entry 1 of `foreman/PATCHES-P10.md`): the designer panel may answer
a question while the Foreman builds, through the inbox. Both scripts pass the engine's check; the panel's selftest
needs last night's marble job, which a worktree does not have, and is run by the Director on the merged tree.

### What this settles

- Last night's failure cannot repeat in that form: a rebuilt dependant is checked against every test of the pack
  before its merge, and a failed final verification after a promotion goes back to one package instead of ending the
  job. The replay of the real hockey job's first change request ends `done`, one step earlier.
- A change request shows the builder the present value. The premise that such values are in `params` or in data
  files was wrong for last night's pack: the puck's radius was a number in a script line. The prompt now shows those
  lines too; the plan check and the cards should push such numbers into data.
- A person can answer and ask while the Foreman works (the inbox); nothing is lost across a kill.
- A plan with a player must name the test that fails when the player has nothing to do.

### What is not verified

Everything a model does with these: whether a Planner writes a useful player check, whether a builder treats
"bigger" as a modest step once it sees the present value. A real `starved` report from the engine (its shape was
read from the code). The inbox with the real Claude builder. No real job was run today: six builders were using the
machine.

### Director's decisions on the builder's questions

1. The file was split; the baseline was not raised.
2. A failed final verification of a first build stays `failed` for now: a first build has no promoted pack to fall
   back on, and its packages have all just used their rounds.
3. `--pack-tests` stays `after_change` by default until one real job has shown what `always` costs.
4. Yes: when a change ends "not made", `pack/` must be put back to the promoted pack, so that the next request does
   not build on rejected files. Not built today; it is the first item of the next Foreman pass.
5. The older clock code goes when no job runs against an engine from before P1 any more.

The proposed text for `contracts/JOB.md` is accepted and goes in with the round's merge.
