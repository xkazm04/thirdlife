# Lane parkour, round 2 (day of 19 Nov): interim at 10:55, part 1 done, part 2 waiting for the moves

Worktree d19-parkour2 (branch from main ebeeb2b). Route as before: Astra (codex gpt-6.2-astra, high) decides and builds;
the operator diagnoses, passes facts, and verifies.

## Part 1a: why the newcomer hand lost 3 of 20 (operator diagnosis, before any change)
- Course newcomer lost seeds 8, 14 and 16. Retry newcomer lost seeds 4, 12 and 14
  (evidence/round2/newcomer-seeds-1-20.txt).
- All three course losses timed out in the Swing yard, between checkpoints 6 and 8. Each was stuck for 2,000+ frames,
  with 51-68 falls and 6 swing hits.
- Most falls came right after the beam respawn: the runner walked off the 1.05 m beam sideways, about 2 m within
  24 ticks (newcomer-fall-trace.txt).
- With the bot's beam side taps switched off, all three still failed, but with more swing hits
  (newcomer-no-beam-sidetaps.txt).
- Retry seed 12 is a different case: the run finished, but the slide had ended 0.29 m before the bar.

## Astra's decision (round 3, 10:23-10:43)
**Kept the course and fixed the recovery and the bot's steering.** Its report is
evidence/round2/astra-report-3.md.

**Fairness verdict:** partly a game bug a person could meet, partly the bot.
- The game bug: a side key still held when you fall carried into the respawn, and walked you off the beam (0.69 m drift
  after release; 1.65 m drift when held 18 frames).
- The bot: its controller could re-tap faster than the newcomer hand delivers a tap, and it estimated drift across the
  teleport.
- Each fix alone recovered all three seeds.
- Retry seed 12 had lost fairly under the old rules. It now wins because the slide cue moved from 3.6 m to 3.0 m before
  the bar, for every hand.

**Changes:**
- Game: at the beam respawn the runner faces down the beam. A side key held through the respawn is ignored until you
  release it (or press the other side). Forward and back work at once. The HUD shows "Back on beam · Release side key
  to steer".
- Bots: one controller for every hand. It waits for its own side tap to start and release before requesting another
  (45-frame retry if a tap is lost), measures drift from the new position after a fall, and uses the 3.0 m slide cue.
- New tests: tests/bot_beam_recovery.gd (holding a side key through the respawn gives 0.000 m sideways drift, 1.583 m
  forward; a fresh press moves 0.314 m) and tests/bot_ladder_retry_sharp.gd. Every existing assertion is kept.

## Ladder before and after (tl ladder, seeds 1-20; scripted hands, not a person)
| Level | Hand | Before (wins, mean frames) | After (operator run) |
|---|---|---|---|
| Course | newcomer | 17/20, 2316 | 20/20, 1766 |
| Course | regular | 20/20, 971 | 20/20, 970 |
| Course | sharp | 20/20, 845 | 20/20, 841 |
| Forced C retry | newcomer | 17/20, 2042 | 20/20, 1698 |
| Forced C retry | regular | 20/20, 1041 | 20/20, 1062 |
| Forced C retry | sharp | 20/20, 908 (Astra's baseline) | 20/20, 898 |

**Note:** every hand now wins every seed. The hands differ only in time: a newcomer course run takes about 2.1x a sharp
one (29.4 s vs 14.0 s). The course has no losing hand left, so its difficulty is in time and falls, not in completion
(newcomer median 8.5 falls, Astra's per-seed table r3/newcomer-runs.tsv).

## Part 1b: flight cannot be used in the pack (operator-verified)
- **Visit test:** a scripted windowed visit (evidence/round2/fly-probe-*.json, fly-probe-visit.txt).
  - The visitor entered the parkour plot and pressed F at stage ticks 160 and 260, with Space, Shift and W held.
  - The game's stage input record holds only jump, forward and run (449 samples). No fly action reaches the game.
  - The visitor's own body did not move while on stage.
  - Positive control: after leaving, the same F flew the visitor 11.08 m up (body "fly").
  - Caveat: that visit window ran to the 600 s watchdog and was stopped by its own harness after the last mark. The
    marks and the record were already written, so the evidence stands, but it is not a clean end of the run.
- **Code:** parkour's ACTIONS map has no `fly` key and the pack never calls fly(). The village refuses `enter` while
  flying (visit.gd).
- **Nothing to fix.** The pack does not opt in.

## Gates on the round-3 tree (operator runs)
- lint: PASS.
- Pack tests: 14 bots x seeds 1, 2 and 3 = 42/42 pass.
- Impossibility: 8 mutations x (bot_geometry, bot_course) = 16/16 exit 1, with only bot.ok red.
- Blind-swing probe: still hit at 6 of 12 phases (unchanged).
- `tl check --tier full --only packs,world`: packs PASS 2/2 (44 of 44 verb runs), world PASS 8/8, on the first run.
- `tl check --tier fast`: PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 226/226, foreman.typecheck).
- Evidence: evidence/round2/operator/.

## Changed files so far (round 2)
- engine/packs/parkour: README.md, pack.json (14 tests), scripts/main.gd, tests/bot_course.gd,
  tests/bot_ladder_retry_regular.gd, tests/support/run_hand.gd.
- New tests: tests/bot_beam_recovery.gd, tests/bot_ladder_retry_sharp.gd.
- docs/shifts/2026-11-19-day/lanes/parkour/evidence/round2/**, STANDUP.md.

## Codex
Round 3: 10:23:05-10:43:17 (20 min 12 s). Codex printed "tokens used 826,850" for this resume. That figure appears to
include the session's earlier context: the session total rises each resume.

## Part 2 (moves stage)
Waiting for the flight lane's "moves ready" line and the Director's merge of API 1.10 into this branch.
