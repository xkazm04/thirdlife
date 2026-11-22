# N3 world: blinking ground and distance levels, incomplete far structures (night of 22-23 Nov 2026)

**The owner, ~18:35, after playing the day's exe (verbatim):** "Editor cannot start new idea to build, World itslef is
very nice with downsides in blinking objects below/above the ground, and blinking objects aggressively with distance
levels. In far there are seen incomplete structures, on closer distance green ground. Hockey is unplayable garbage,
analyze in deep thirdjam - it is a mediocre hockey game we delivered but at least it has set basic gameplay mechanics,
AI, bugless graphics and balanced speed (https://github.com/xkazm04/thirdjam). Our hockey is a proof we should not start
any new minigame development as there is a lack of understanding how games should be done - we need research to change
mindset of what we are doing. The fact players can skate and shoot puck does not mean we delivered entertaining hockey
experience, the fact players can punch in arena and take damage does not mean we delivered fun fighting game. Both are
slop nobody would touch for fun and we should prepare processes and prompts to go much deeper in game design"

Worktree: `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-world` (branch n23-world, from main).

## Route: Opus-directed Astra
You are the Opus director, and you build through Codex:

```
codex exec -m gpt-6.2-astra -c model_reasoning_effort=high --dangerously-bypass-approvals-and-sandbox \
  --skip-git-repo-check -C <tree> "<brief>" < /dev/null > <tree>/.tl/codex-<round>.log 2>&1
```

- Always pass `< /dev/null`.
- Resume a run by its session id, never with `--last`.
- Tell Astra "read-only git is fine; do not commit".
- You verify every claim. Build a fix yourself when that is faster.

## The owner's three findings in the World (exe, Wren Valley, today's main)
1. **Objects blink below and above the ground.** This is z-fighting, or objects sinking and rising: decide which, per
   object kind.
2. **Objects blink aggressively between distance levels.** This is LOD or tier switching, or chunk streaming popping.
3. **Incomplete structures in the distance, green ground closer up.** The far meshes or impostors are missing parts. The
   near ground shows as flat green, which is a material, LOD or draw-order problem.

## What to do
1. **Reproduce each finding as a person meets it.**
   - Open the exe or `boot.tscn` in a window and choose World. Walk and fly the Wren Valley and the village edge.
   - Capture a before-clip (20 s or less) and stills of each finding, with positions.
   - Compare with `TL_HOME=plain` (the old landscape) to tell the Home's own faults from older ones.
2. **Find each cause, with file:line, before building.** Places to look:
   - the Home: `engine/kernel/world/home/` (D1, today);
   - the land chunks: `land/`;
   - the village landscape: `landscape.gd`;
   - the draw tiers: `draw/` and `tiers.gd`;
   - the style.
3. **Fix them.** Take after-clips from the same positions. Add a selftest (block 770-779) for each fix that can be
   measured, for example:
   - no object's base above or below the ground beyond a tolerance;
   - no tier flip-flop within N frames at a fixed distance.

## Acceptance
- Before and after clips and stills from the same spots, for all three findings, judged by eye in your report.
- World = alone holds and nothing else moved:
  - world 8/8 = alone (`tl check --tier full --only world`);
  - every pack verb hash unchanged, unless named;
  - the `home.` and `land.` selftests pass.
- Frame cost before and after, labelled busy or quiet.
- Fast and full tier green. The full tier needs `npm ci` in `foreman/`, plus plain copies of
  `site/marble-run-three-marbles-20261110-1` and `-2`.

## Scope (your claim)
- **Yours:**
  - `engine/kernel/world/**`, except `pack.gd` and `world.gd` (ask first for those);
  - `engine/style/**`, only if the cause is there, and say so first;
  - `engine/tools/selftest.d/77*`;
  - your lane folder.
- **Not yours:** `engine/ui/**` (N4).

## Time and rounds
Time box: until 06:45. Send one landable round per finding when you can.

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
