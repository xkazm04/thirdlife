# D5 arm B final report

**Nine defects reproduced** across stage recording, walker movement, camera avoidance, terrain and the test runner. Two were high severity. A rebuilt game silently lost its stage replay after one tap on tick 18 of 20. On a village pad awaiting its game, the ground shader closed the hole while the idle walker fell 46.33 m through it in 120 ticks.

| Acceptance | Verdict | Evidence |
|---|---|---|
| 1. Numbered findings with source, severity, command and output | Met | Nine findings in `findings.md` · 2 high, 5 medium, 2 low. Verified every quoted output line against its command. |
| 2. Reproductions run from the worktree root | Met | `python docs/reports/astra-trial/d5/repro/run.py all` printed `D5 reproduced 9/9` and exited 0 after a fresh import. The existing controls also printed `WALKCASE done 8 8` and `GROUNDCASE ok`. |
| 3. Unreproduced suspicions labelled | Met | One doorway suspicion. The 1.8 m walker cleared the 2.0 m opening despite two blocked ticks. |

**Files changed** under `docs/reports/astra-trial/d5/` were `b.md`, `findings.md`, `repro/run.py`, `repro/cases.gd` and `repro/pad.gd`. All source changes are in the report directory. Generated caches remain in `engine/.godot/` and `.tl/astra-b/` because automatic command review blocked recursive cleanup.

**Next** I would preserve the original input tick count across stage rebuilds and give the temporary village pad collision support until the pack collider arrives. The `record` and `coldpad` cases provide regression tests for those fixes.

**Cost** was 12 min 59 s, from 13:05:34 to 13:18:33 CET, within the 75-minute box. Token usage was unavailable.

# Arm B progress

- 2026-11-18T13:05:57+01:00 Read the three briefs, repository instructions, scope and contracts index.
- 2026-11-18T13:06:46+01:00 Reviewed lane reports and traced movement, camera, terrain classification and test entry points. Selected fixed-tick comparisons with independent geometry checks.
- 2026-11-18T13:08:58+01:00 Headless import completed. Five probes reproduced: 65-degree idle bank, rotated sheet, camera setup option, crown overlap during a jump, and a held slide pose after leaving a game.
- 2026-11-18T13:12:17+01:00 Confirmed rebuilt-stage recording loss with the real input sampler and session writer. A single action on tick 18 of 20 saved with a live input and disappeared after its input was freed. Examined doorway clearance and the named walk-case entry point.
- 2026-11-18T13:14:04+01:00 Verified both cold-plot ground paths with the real renderer. The village pad closed visually but the idle body fell 46.33 m in 120 ticks. Flat ground kept its 42.5 m cut open. The low-door suspicion was not reproduced.
- 2026-11-18T13:15:56+01:00 Re-ran all nine named reproductions together from the root: D5 reproduced 9/9, exit 0. Existing controls: WALKCASE done 8 8, GROUNDCASE ok, both exit 0.
- 2026-11-18T13:16:56+01:00 Wrote nine numbered findings and the measured doorway suspicion. Checking the exact documented commands and the runner's first-use import.
- 2026-11-18T13:18:07+01:00 Verified all nine individual commands against every quoted output line and all nine from a clean import. Recursive cleanup of the generated local caches was blocked by automatic command review.
