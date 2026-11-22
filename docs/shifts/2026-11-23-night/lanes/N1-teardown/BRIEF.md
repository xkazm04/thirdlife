# N1 teardown: thirdjam against our hockey (night of 22-23 Nov 2026)

**The owner, ~18:35, after playing the day's exe (verbatim):** "Editor cannot start new idea to build, World itslef is
very nice with downsides in blinking objects below/above the ground, and blinking objects aggressively with distance
levels. In far there are seen incomplete structures, on closer distance green ground. Hockey is unplayable garbage,
analyze in deep thirdjam - it is a mediocre hockey game we delivered but at least it has set basic gameplay mechanics,
AI, bugless graphics and balanced speed (https://github.com/xkazm04/thirdjam). Our hockey is a proof we should not start
any new minigame development as there is a lack of understanding how games should be done - we need research to change
mindset of what we are doing. The fact players can skate and shoot puck does not mean we delivered entertaining hockey
experience, the fact players can punch in arena and take damage does not mean we delivered fun fighting game. Both are
slop nobody would touch for fun and we should prepare processes and prompts to go much deeper in game design"

Worktree: `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown` (branch n23-teardown, from main).
Route: Opus solo. This lane is RESEARCH ONLY: change nothing in `engine/` or `foreman/`.

## Goal
Find out, with evidence, why thirdjam plays as a basic but real hockey game and our `engine/packs/hockey` does not.

thirdjam is the owner's own jam game (https://github.com/xkazm04/thirdjam). Clone it read-only into your tree's
`.tl/thirdjam`.

Our hockey once copied "thirdjam's real mechanics" (night of 21 Nov, lane L4). N3 reworked it on the night of 22 Nov,
and D2 reworked it again today. Something essential was lost along the way, or never carried over.

## What to do
1. **Read thirdjam end to end.** Cover:
   - its rules;
   - the puck: possession, stickiness, passing, shooting;
   - skating speed and acceleration;
   - the AI: how each player decides, when to pass and when to shoot, positioning, the goalie;
   - camera and controls;
   - what the player feels in the first 30 seconds;
   - its docs (VISION.md and any design notes).

   Run it if it runs on this machine, and say how. If it does not run, read it as code and say so.
2. **Read our hockey the same way:** `engine/packs/hockey`, its README, `data/*.json`, `scripts/ai` and `tests/metrics.gd`.
3. **Play both as a person meets them, where you can.** Use a window and the regular or newcomer hand. Keep clips to 20 s
   or less and make JPG sheets. For our hockey, use `node devx/bin/tl.mjs play hockey` and window clips from its bots.
4. **Write the teardown** as `docs/research/hockey-teardown/TEARDOWN.md`. It covers:
   - **Side by side, per system:** what thirdjam does (file:line), what ours does (file:line), and the difference a
     player feels.
   - **The top 10:** why ours is "unplayable garbage" to the owner, ranked by how much each costs the player, each with
     evidence.
   - **What thirdjam itself still lacks** against a good arcade hockey (NHL Hitz, NHL 94, Hockey Heroes and the like).
     thirdjam is the floor, not the bar.
   - **The lessons for HOW we build games:** process, not hockey. Name where our process produced mechanics without an
     experience.
5. **No fixes.** Put recommendations in the report as a list the owner can accept or reject.

## Acceptance
- TEARDOWN.md backs every claim with file:line evidence on both sides.
- Clips or sheets of both games, or a stated reason why not.
- The ranked top 10 and the process-lessons section. N2 reads them from about 01:00, so keep an interim `INTERIM.md` in
  your lane folder up to date by then.
- Fast tier green (this lane changes docs only).

## Scope (your claim)
`docs/research/hockey-teardown/**`, your lane folder and your tree's `.tl/`. Nothing else.

## Time and rounds
Time box: until 06:45. Two landable rounds:
1. about 01:00: INTERIM.md and the first half of the teardown;
2. by 05:30: the final teardown.

## Shift-wide rules for this night
- Absolute paths only; never `cd` inside a backgrounded command line.
- After you send "landable round k" (SendMessage to the Director), make NO edits in your tree until the Director answers
  "landed" (or "rejected").
- Stamp STANDUP lines from `date`, never from memory. Write a STANDUP line at least every 60 minutes. No line for 60
  minutes gets a status ask, and a second miss gets a stop.
- Lanes stop at 06:45 (CEST): report written, last STANDUP line `done` or `cut`.
- The owner's rule for tonight: no new minigame and no game-feature work on duel or hockey. No Foreman build jobs.
- Other sessions load this machine, so wall-clock checks (hockey many_budget, perf, the kernel suite's cap) are not
  evidence on a busy machine; say so instead of tuning to them. Mind RAM: the system killed a run at 1.7 GB free today.
- The full tier in a worktree needs `npm ci` in its `foreman/`, plus plain copies (no links) of
  `site/marble-run-three-marbles-20261110-1` and `-2` from the main checkout into its `site/`.

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-23-night/lanes/<lane>/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
