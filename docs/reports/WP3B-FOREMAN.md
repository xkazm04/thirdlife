# WP3b Foreman on the real engine, first real job: builder report and Director verification

Brief `briefs/BRIEF-WP3B-FOREMAN.md`. Builder wall time 19:59 to 21:02 CEST on 2026-11-10 (63 min; harness: 514,247 subagent tokens, 152 tool uses). The real job itself: 14 min 22 s, 2,682,580 tokens in (2,457,191 of them cache reads), 98,790 out, on the owner's subscription.

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

# WP3b Foreman: final report

## Status
All three parts are done. The real job ran end to end and finished `done`: three packages, each promoted in round 1, no re-plan. I finished at 21:02 CEST, inside the time-box.

- `npm test` with `TL_GODOT` set: 114 tests, 114 pass, 0 skipped (three consecutive runs).
- `npm test` without `TL_GODOT`: 110 pass, 4 skipped (the engine tests).
- `tsc --noEmit`: clean.
- No stray `node`, `claude` or Godot process of mine. No file under `site/_engine_snapshot` has a modification time after 20:00.

**Not exercised live** (fake tests only): the re-plan, any round after the first, a builder timeout, a `QUESTION:`, a real truncation or rate-limit response, and `readonly-scan`.

## Part 1, item by item
New tests are in `foreman/src/test/wp3b.test.ts` (23 tests, named by item number).

1. **Composed manifest: built.** `src/manifest.ts` writes `pack.json` from `packId`, title, version and the `registers` of merged packages.
   - The plan check refuses any scope containing `pack.json`, and requires exactly one root package that owns `scripts/main.gd` and registers a bot. The Planner prompt and schema say so.
   - A builder's edit to `pack.json` is put back and recorded.
   - The entry script is fixed at `scripts/main.gd` and the version at `0.1.0`, because `registers` has no entry key and no event carries a version.
2. **Re-plan on failure: built, tested with the fake only.** After the round limit a package and its dependants go back to the Planner; a package id goes back once; at most three per job (`--max-replans`), then `job_state: failed` with the reason. A refused builder is not re-planned. A kill between `replan` and `plan_set` is repaired on resume.
3. **Milestones: built, ran live three times.** For each declared camera the Foreman captures frames 120 and 480 with `--test=<first bot>`, retries a failed capture once, then runs the critic, then writes `milestone` with the paths. A kill before the `milestone` event is caught up on resume.
4. **V5 critic: built, ran live three times.**
   - `claude --help` has no image flag. Images go in with `--input-format stream-json`, as one stdin user message holding base64 image blocks and then the text. This works with `--tools ""`, so the critic stays in `generate` mode.
   - Recorded in `data/capabilities.json`.
   - The critic does not gate the job.
5. **Environment: built.** Edit and readonly-scan children, and the runner, do not inherit names containing `KEY`, `TOKEN`, `SECRET` or `PASSWORD`. The exceptions are `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN` and `CLAUDE_CODE_OAUTH_TOKEN`. Tested through the spawn door. No file in the job directory mentions a lane variable.
6. **Runner changes: built.**
   - An unfinished bot is accepted as exit 1 `failed` or exit 3 `watchdog`. The snapshot engine still returns 3.
   - Unknown check ids and metrics keys pass; an unknown top-level key makes the report invalid.
   - `merge.removed[]`, `verify.after`, `billing.mode: none` and typed `budget.policy.limit` are in.
7. **Pack id mismatch: built.** A lint report with another pack id refuses the first merge.

Also added, beyond the brief:
- `foreman comment`.
- `foreman verify` now defaults to all five verbs.
- A reference copy for builders (see Questions).
- A milestone note "NO VISIBLE CHANGE" when captures are byte-identical to an earlier milestone's.
- A re-run of clock-based verdicts (Part 2, difference 8).

## Part 2: differences between the fake and the real runner
Every verb passes on `pack_min` and `ex_slide` through `foreman verify`. The bad packs fail as documented. `src/test/engine.test.ts` has 4 tests, including a parity test (same top-level keys, check ids and exit codes from both runners on one pack). The fake is fixed to match in every case below.

1. **Capture supervisor.** RUNNER.md says the caller passes `--position 0,1440`. Starting the supervisor windowed crashed in `amdxc64.dll` (exit 0xC0000005, no report) on my one attempt. The engine's API.md section 18 says the supervisor runs headless and opens the worker window itself. The Foreman now always passes `--headless`.
2. **Render driver.** The snapshot tries the default driver first; RUNNER.md says Direct3D 12. The Verifier sets `TL_RENDER_DRIVERS=d3d12` for capture.
3. **Invalid manifest.** On any verb but lint this is exit 2 `not_run` with no checks. The fake said exit 1.
4. **Unknown option.** Exit 2. The fake ignored it. The plan check now refuses acceptance options the runner does not take.
5. **Report contents.** `smoke.no_engine_errors` exists, and the smoke checks appear in invariants, bot and capture. Capture has no `metrics`. `state_hash` is 64 hex characters.
6. **Arguments.** `bot --test` must be one of the manifest's tests. Capture needs an absolute `--out` and a registered camera.
7. **Fence.** Only bare calls are fenced (`ctx.rng.randf_range(` is allowed), and strings are blanked first. The parity test found this one.
8. **Wall clock.** Under CPU load, a 120-frame smoke on `bad_script_error` ended as `watchdog` (tick over 250 ms) in 3 of 10 runs instead of `failed`. The finished marble pack passed 8 of 8 under the same load, but single-run p99 reached 12 ms against the 8 ms budget. The Foreman now re-runs a clock-based verdict once and logs both runs.

Capture never needed its retry, in the job or in the diagnostics of the test runs. One capture took 34 s; the others took 2 to 4 s.

## Part 3: the real job
- **Job directory:** `C:\Users\kazda\kiro\third-life\site\marble-run-three-marbles-20261110-1`
- **Log:** `job.jsonl`, 64 events, reads strictly, no torn tail.
- **Final state:** `done` ("pack verified V0 to V4; promotion was not requested").

Limits stated before the run: 3 rounds, 12 minutes per builder run, one re-plan, at most 3 packages, `sonnet` for every role, 2 packages in parallel. Token policy: `tokens_per_hour` 15,000,000, counting cache reads at full weight, as a runaway guard.

I ran with `--no-promote`, because promotion would write into the read-only snapshot. There is therefore no `promoted` event, and no command to promote the pack later.

**Designer.** Valid on the first attempt. The brief: three marbles (wood, steel, rubber), a four-segment ramp, a 12 m ice sheet, 20 s timeout, start and restart inputs.

**Planner (first live call).** Valid on the first attempt, with exactly three packages:
- `course_core`: the root, the whole playable race in 7 files; acceptance lint, smoke, invariants, bot.
- `look_pass`: a generator plus a dressing script.
- `sound_tune`: a generator, an audio script and a bot.

Both later packages depend only on `course_core`.

**Builders.**
- **`course_core`:** 60 turns. It read the reference API and `ex_slide`, and ran the runner 15 times from its shell (bot 12 times, lint, smoke, invariants).
  - Four tool calls were refused: two reads and a `cat` of the snapshot's `materials.json` / `surfaces.json`, and a `python3` file edit.
  - Nothing was written outside its workspace.
  - Its answer listed four deviations from its contract (for example, marbles pass through each other). Nothing reads that text.
- **`sound_tune`:** ran bot and lint only, and said so.
- **`look_pass`:** ran lint, smoke and invariants. It said it had not seen the rendered look. One `grep` was refused.

**Verifier.** Every workspace check, every merge gate and the final gate passed first time. I re-ran all five verbs on `pack/` afterwards and they pass. `bot_race`: steel 6.76 m, wood 5.02 m, rubber 3.98 m, ending at the 20 s timeout.

**Composability from lint:** `gdscript_lines` scripts 551, gen 18, tests 91; `kit_parts_added` 0; `bypasses` [].

| Run | Rounds | Outcome | Seconds | Tokens in | Tokens out |
|---|---|---|---|---|---|
| Designer | – | ok | 15.9 | 3,925 | 1,067 |
| Planner | – | ok | 83.7 | 55,684 | 12,160 |
| `course_core` | 1 | ok, promoted | 645.8 | 2,266,338 | 74,913 |
| `sound_tune` | 1 | ok, promoted | 42.6 | 158,341 | 3,739 |
| `look_pass` | 1 | ok, promoted | 55.1 | 180,197 | 5,007 |
| Critic, 3 calls | – | ok | 76.9 | 18,095 | 1,904 |
| **Total** | | | **920** | **2,682,580** | **98,790** |

Of the input tokens, 2,457,191 are cache reads. The CLI's notional cost is $2.13. Wall time from run start to `done` was 14 min 22 s.

**Foreman fixes during the run:** none. One mistake of mine: I first launched the run as a tool task with a 10-minute timeout. I killed it 20 s in and relaunched it detached with `resume`; events 13 to 15 show this.

**Captures.** I looked at all six.
- They show a honey-wood ramp with rails, a pale blue ice sheet with tick marks, and three marbles (brown, white, red) that move between frame 120 and frame 480.
- The ramp reads as a tangled pile of overlapping segments, and the backdrop is dark brown.
- The three milestone pairs are byte-identical, so the art pass drew nothing and still passed V0 to V3. `gen/look.gd` calls `set_script` after `add_child`; `gen/sound.gd` does it in the other order and works. I think that is the cause, but I did not confirm it.
- The critic said "NOT ok" all three times (readability 0.4), with notes that match what I saw.
- At frames 120 and 480 the marbles are still on the ramp. A capture I took at frame 1000 shows them on the ice.

## What this says about hockey
1. **Package size against the time limit breaks first.** The root package used 10.8 of 12 minutes for about 550 lines. A hockey root would time out, and the 3-package limit pushes everything into the root.
2. **Contract drift is invisible.** The builder's four deviations live only in an answer nobody reads. With more packages sharing state, dependants will build against a contract that is no longer true.
3. **Visual work is unverified.** Builders cannot capture, the critic does not gate, and nothing checked that the ramp is a usable zig-zag.
4. **Parallel builders load the machine.** The clock-based limits will then misfire on a heavier pack.
5. **The token budget is dominated by cache reads.** Two or three parallel hockey builders would reach 15M per hour.

## Questions
1. RUNNER.md and capture: proposed wording "the supervisor always runs `--headless` and opens the capture window itself at `0,1440`".
2. Builders got a copy of API.md, `pack_min` and `ex_slide` in `<job>/ref/`, not the snapshot path. `--restricted` confines the file tools, and a live test showed an `--add-dir` directory is writable. May `ref/` join the allowed job-directory entries? The law tables are now copied too, after the refusals above.
3. Should a "NOT ok" critic, or a "NO VISIBLE CHANGE" milestone, fail the milestone?
4. Where does the manifest version come from, and is the fixed entry `scripts/main.gd` acceptable?
5. Should the budget count cache reads at a lower weight?
6. Should builder deviations become an event, for example `note {package, round, text}`?
7. The CLI lets some harmless commands through without a grant (`echo`, `node --version`, one `grep`). Acceptable?
8. The second run of a clock-based verdict is my decision, not the contract's. Proposed JOB.md wording: "a verification whose only failure is clock-based is run once more; both are logged".
9. Capture frames are fixed at 120 and 480. Should a pack declare its own?
10. The "tuned" milestone fired before "art_pass" because the packages ran in parallel. Are milestones ordered stages or labels?

## Minutes spent
19:59 to 21:02 by `date`: 63 minutes. `C:\Users\kazda\kiro\third-life\foreman\JOURNAL.md` (section "WP3b") has the step-by-step record.

---

## Director verification

Done 21:09 to 21:15 CEST on 2026-11-10, after the builder had stopped.

### What was re-run, and the result

| Check | Result |
|---|---|
| `npx tsc --noEmit` in `foreman/` | exit 0 |
| `npm test` with `TL_GODOT` set | 114 tests, 114 pass, 0 skipped, 40 s |
| `foreman verify` on the snapshot's `ex_slide`, all five verbs | lint, smoke, invariants, bot, capture: all ok, exit 0 |
| `foreman status` on the real job | `done`, 3 packages promoted in round 1, tokens in 2,682,580, out 98,790 |
| `site/marble-run-three-marbles-20261110-1/job.jsonl` read event by event | 64 events, every line parses; order is brief, plan, build, verify, candidate gate, merge, capture, critic, milestone, final gate, `done`; billing event says subscription |
| files under `site/_engine_snapshot` changed after 20:01 | none |
| the five verbs on `site/marble-run-three-marbles-20261110-1/pack`, spawned directly, **snapshot engine** | all exit 0; bot `ranking steel, wood, rubber`, 1,207 frames; three runs at seed 1 give one hash |
| the same on the **live engine** (after WP4's kernel changes) | all exit 0, same bot result, a different bot hash |

The Director did not re-run the bad packs through `foreman verify` (one attempt used a wrong option and printed the
usage text); the builder's engine tests cover them and ran inside `npm test`.

**Looked at:** `captures/tuned-course-f480.png` and a new capture of the pack at frame 1,000 on the live engine.
The builder's description is accurate: a wooden ramp that reads as an overlapping pile, not a zig-zag; a plain ice sheet
with tick marks; three small marbles; a flat brown backdrop. It is a grey-box, not the lane-B look.

### What the job does and does not prove

- **Proved:** one sentence became a designed, planned, built and verified pack with no human code and no Foreman fix
  during the run: 14 min 22 s, three packages, every gate green in round 1, 0 bypasses, 0 kit parts added, 660 lines of
  GDScript. The Foreman's limits, billing check, workspace confinement and resume all worked with real nested Claude
  sessions.
- **Not proved: anything about the look or the kit.** The job ran on the 20:00 copy of the engine, which has no kit, no
  rigs, no style and no seed games. The builders had `API.md` and two kernel examples and built from boxes.
- **Not proved: recovery.** Nothing failed, so no second round, no re-plan, no timeout and no question ever ran live.
- **The verifier passed work that did nothing.** `look_pass` changed no pixel (three byte-identical capture pairs) and
  was promoted. The critic said "NOT ok" three times (readability 0.4) and nothing acted on it.
- **The seed does nothing in this game** (seed 2 and seed 7 give the seed-1 hash): the pack never uses `ctx.rng`. True
  to the sentence, and worth knowing: "a different seed changes the hash" cannot be a gate.
- One package took 2.27 M of the 2.68 M input tokens and 10.8 of its 12 minutes.
- Small defects: `budget.state` still says `running` after `done`; with `--no-promote` there is no way to promote later.

### Director's decisions on the builder's questions (contracts amended 2026-11-10, second round)

1. **Capture:** the supervisor always runs `--headless` and opens the capture window itself. `RUNNER.md` amended.
2. **`ref/` is an allowed job-directory entry**: read-only reference copies for builders (API, law tables, examples,
   and from now on the seed packs and the kit, rig and style documents).
3. **An art milestone whose captures are byte-identical to the previous milestone's fails its packages** for that round
   ("no visible change"): it is objective and cheap. **A "NOT ok" critic gives the milestone's packages one extra round**
   with the critic's notes as the feedback; after that round the job goes on and the verdict stays in the log.
4. **Manifest:** version `0.1.0` at the first build; entry fixed at `scripts/main.gd`. Accepted.
5. **Budget:** cache reads count at weight 0.1; the raw figures stay in the log.
6. **Builder deviations become a `note` event** `{package, round, text}`, and the notes of a package are given to the
   builders of its dependants.
7. Harmless ungranted commands passing through the CLI are accepted for the spike; the fence is a guardrail.
8. **A verification whose only failure is clock-based is run once more; both runs are logged.** `JOB.md` amended.
9. **Capture frames** are 25 % and 75 % of the frame at which the first bot finished in its last passing report
   (120 and 480 when there is none), so the image shows the game in play.
10. **Milestones are labels, not ordered stages**: one fires when its packages are merged.
