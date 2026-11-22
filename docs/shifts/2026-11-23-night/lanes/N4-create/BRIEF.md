# N4 create: the editor cannot start a new idea (night of 22-23 Nov 2026)

**The owner, ~18:35, after playing the day's exe (verbatim):** "Editor cannot start new idea to build, World itslef is
very nice with downsides in blinking objects below/above the ground, and blinking objects aggressively with distance
levels. In far there are seen incomplete structures, on closer distance green ground. Hockey is unplayable garbage,
analyze in deep thirdjam - it is a mediocre hockey game we delivered but at least it has set basic gameplay mechanics,
AI, bugless graphics and balanced speed (https://github.com/xkazm04/thirdjam). Our hockey is a proof we should not start
any new minigame development as there is a lack of understanding how games should be done - we need research to change
mindset of what we are doing. The fact players can skate and shoot puck does not mean we delivered entertaining hockey
experience, the fact players can punch in arena and take damage does not mean we delivered fun fighting game. Both are
slop nobody would touch for fun and we should prepare processes and prompts to go much deeper in game design"

Worktree: `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-create` (branch n23-create, from main). Route: Opus solo.

## Goal
In the exported game (`.claude/worktrees/d22-int/dist/PLAY-LATEST.cmd`, build 48c4f59), the owner could not start a new
idea from Create. Reproduce it exactly as he met it, find the cause, fix it, and prove the fix in an exported exe.

## What to do
1. **Reproduce it.**
   - In the exe's menu, choose Create, or the World's construction site or designer panel: whichever "start a new idea"
     is.
   - Read:
     - `engine/ui/`: panel.gd, foreman_door.gd, host.gd;
     - `engine/boot/menu.gd` and `hub.gd`;
     - docs/TWO-WORLDS.md;
     - the exe's logs (`dist/ThirdLife/ThirdLife-last-run.log`).
   - Candidates to rule in or out:
     - the exe cannot find `foreman/dist/cli.js` from dist/ (find_cli walks up from the engine directory);
     - node is not found;
     - no flags are given to the panel;
     - a button is wired to nothing;
     - a typing field takes no keys.
   - Name the cause with file:line and the exact on-screen text.
2. **Fix it inside your claim.** If the fix needs `foreman/` (N2's claim) or the export script, SendMessage the Director
   first.
3. **Prove it.**
   - Export in YOUR tree: `bash engine/tools/export.sh --commit <tree HEAD>`. In that exe, Create must start a new idea
     up to the Designer's first answer.
   - Use Foreman's FAKE adapter, so no real job runs tonight (no minigames).
   - A window clip or stills of the flow.
   - A ui.selftest case (block 780-789, or the ui selftest file) that would have caught it.

## Acceptance
- The cause named with evidence: a before still or a log line.
- The fix, and the after flow in an exported exe.
- ui.selftest green with the new case; fast tier green.

## Scope (your claim)
`engine/ui/**`, `engine/boot/menu.gd`, `engine/boot/hub.gd`, `engine/tools/selftest.d/78*`, your lane folder.

## Time
Time box: until 06:45, but this is small. Aim to be landable by 23:00, then write the report. If the fix lands early, the
Director may give you one more item from the owner's list.

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
