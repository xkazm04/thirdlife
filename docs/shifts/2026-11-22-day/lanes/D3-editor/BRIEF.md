# D3 editor: the critic cross-checks bot claims against the film; one hockey job through the editor (day of 22 Nov 2026)

**Owner (~10:40, verbatim):** "run next shift now with all three steps as daily shift, I will play the game after before
major directions for night shift".

**Context (owner, ~10:30):** the six colosseum proofs are accepted for now: "the game does not play well but I will need to
think more before next directions". Do NOT resume those six jobs.

Worktree: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d22-editor` (branch d22-editor, from main 45f108d). Route:
Opus solo.

## Goal (N4's "next three" item 1, and the verdict's step 3)
1. **Check claims against the film.**
   - A bot's `metrics` are claims; the contracts/PACK.md amendment of 2026-11-22 names `metrics` and `moments`. Cross-check
     them against what the capture shows. Two kinds of finding:
     - a strip where no body moves for 50 frames while `idle_max_f` claims under 120;
     - a claimed contact moment whose strip shows no contact.
   - The critic gets both the claim and the measured contradiction, and a contradicted claim cannot pass the tofu or house
     check.
   - Measure motion from the frames themselves: frame differences on the stills and strips the editor already takes. It must
     be deterministic and cheap.
2. **Build one hockey job through the editor to its tofu (blockout) look.**
   - Run `foreman new` from a hockey-like sentence with the hockey house template, then plan and run it with Opus builders.
     Run it detached, one command per line.
   - The pattern is `.tl/proof/proof.sh` and `planrun.sh` in the main checkout: copy them into your tree's `.tl/` and point
     them at your tree.
   - Report how far it got, the critic's scores, the house strip beside the build's strip, and what the editor got wrong.
   - A held milestone is a result, not a failure. Do not accept or retry it yourself; the owner decides.
3. **If time remains:** N4's next-three item 2. The revise round gets the build's contact strip beside the house strip at the
   same contact kind, plus the diff of its contact numbers against the house.

## Acceptance
- **Unit tests in foreman for the cross-check:** a fixture with a contradicted claim fails the check, and an honest one
  passes. `npm test` all green, with the count stated (main: 290 tests, 284 pass, 0 fail, 6 skip).
- **The cross-check on real reports:** run it over at least two, read-only, and give the findings it prints:
  - a house hockey ladder report;
  - one of last night's proof jobs under `site/fight-colosseum-20261122-*`.
- **The hockey job:** its id, the milestones reached, the critic's lines, the strips (JPG) in your lane folder, and
  tokens and cost from `tl ledger`.
- **Contracts:** JOB.md and PACK.md changes go in your report as proposals; contracts are Director-only.
- **Gates:** the fast tier green; `npm run -s build` in your foreman.

## Scope (your claim)
- **Yours:**
  - `foreman/**`
  - `docs/GAME-QUALITY.md`
  - `devx/lib/cards/**`
  - your tree's `.tl/` and `site/` (the job lives in YOUR tree's site/, not main's)
  - your lane folder
- **Not yours:** anything under `engine/**` (D1 and D2).

## Time and rounds
Time box: until 17:15. Round 1 is the claim check; the hockey job runs in the background meanwhile.

## Shift-wide rules for this day
- Absolute paths only; never `cd` inside a backgrounded command line.
- After you send "landable round k" (SendMessage to the Director), make NO edits in your tree until the Director answers
  "landed" (or "rejected").
- Stamp STANDUP lines from `date`, never from memory. A STANDUP line at least every 60 minutes; no line for 60 minutes
  gets a status ask, a second miss gets a stop.
- Lanes stop at 17:15 (CEST): report written, last STANDUP line `done` or `cut`.
- Other sessions load this machine: wall-clock checks (hockey many_budget, perf, the kernel suite's cap) are not evidence
  on a busy machine; say so instead of tuning to them.
- The full tier in a worktree needs `npm ci` in its `foreman/` and plain copies (no links) of
  `site/marble-run-three-marbles-20261110-1` and `-2` from the main checkout into its `site/`.

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-22-day/lanes/<lane>/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
  when the lane lands).
- Append one line at each milestone and at least every 60 minutes of work:
  `HH:MM | state: working|blocked|done|cut | did: <one line> | next: <one line> | gates: <last PASS/FAIL line or ->`
- `blocked` names the question in the same line. Then keep working on whatever the block does not touch.
- When you finish, write `REPORT.txt` beside it (the harness refuses agent writes to files named REPORT.md), return the
  full report as your final message too, and set the last standup line to `done`.

## Honesty
- Evidence or it is not done: a gate line, a test count, a still, a video, a repro before and after.
- A stopped run is never a pass. NOT RUN is not PASS. Fewer tests completed than on main is a stopped run.
- Unmeasured is not zero. Never fake a frame, a figure or a hash.
- A behaviour change that moves a test expectation is named, with why. Never loosen a test to make it pass.
- What the player sees or feels is judged as a person meets it (a window, the exported game), not only headless.

## Laws (CLAUDE.md)
- Work only in your worktree. No git that writes (read-only `git diff`/`git status` are fine). The Director lands.
- Never kill a process you did not start. Prefer `--headless`. Build the class cache once: `"$G" --headless --path engine --import`.
- Time is physics frames; determinism (same pack + seed + frames = same state_hash); unknown keys are errors; packs use only
  the TL* API and never declare class_name; kit, rigs, style reference nothing outside themselves.
- Contracts (`contracts/*`) are Director-only: put the question in your report.
- New selftest cases go in your own `engine/tools/selftest.d/NNN-<name>.sh` files, numbered inside the block range your brief
  assigns (two lanes once collided on 360).
- Raw captures (frame folders, long or uncompressed clips, mkv/avi) stay under `.tl/` in your worktree. The lane folder
  gets only sheets, notes, JPG stills and mp4 clips of 30 s or less.
- A kernel API addition updates `engine/kernel/API.md`; the Director regenerates docs on main (`tl arch --index`).
- Gates before `done`: `node devx/bin/tl.mjs check --tier fast`; when kernel, kits, rigs, style or seeds changed, also
  `node devx/bin/tl.mjs check --tier full` (perf alone if it says NOT RUN).

## REPORT.md
- Outcome against each acceptance criterion: met / not met, with its evidence.
- Gates with PASS/FAIL lines and counts.
- Changed files; behaviour changes; anything the owner should look at, and how.
- Questions for the Director; the next three things this lane would do.
