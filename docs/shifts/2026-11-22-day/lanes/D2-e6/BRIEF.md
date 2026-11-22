# D2 e6: a game in a world plays as it does alone, then hockey "pass out of pressure" (day of 22 Nov 2026)

**Owner (verbatim, ~10:30):** "2.Keep bots as is for now, land 'pass out of pressure' once E6 is fidex".
**And (~10:40):** "run next shift now with all three steps as daily shift, I will play the game after before major
directions for night shift"

Worktree: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d22-e6` (branch d22-e6, from main 45f108d).

## Route: Opus-directed Astra
You are the Opus director, and you build through Codex:

```
codex exec -m gpt-6.2-astra -c model_reasoning_effort=high --dangerously-bypass-approvals-and-sandbox \
  --skip-git-repo-check -C <tree> "<brief>" < /dev/null > <tree>/.tl/codex-<round>.log 2>&1
```

- Always pass `< /dev/null`.
- Resume a run by the session id in its log, never with `--last`.
- Tell Astra "read-only git is fine; do not commit".
- You verify every claim and re-run every gate yourself; Astra's report is a claim.
- If the fix turns out small, build it yourself when that is faster.

## The law it breaks (CLAUDE.md)
"A game in a world plays as it does alone." E6: hockey's r2a variant hashes differently in `world.sh` than alone. The first
divergence is at frame 2016 in N3's run and at 2050 in N1's copy, when a skater touches several net or board shapes at once.

## N1's diagnosis (10:02, not proven to the line)
- **The cause:**
  - In a world, each body is first created in the viewport's default space. Then `adopt()` in `engine/kernel/world/pack.gd`,
    called from `world.gd` `_on_node_added`, moves it into the pack's own space with `PhysicsServer3D.body_set_space`.
  - Alone, each body is created once.
- **What this does:** Jolt's body order differs. A whole-space intersect_shape at frame 3 lists the same 105 colliders in
  another order (goal_red/Frame moved), so multi-contacts are solved in another order.
- **Ruled out:** material laws, the space's gravity and damping, the body set, the origin, frame counters, own vs shared
  space.
- **Evidence on main:** `docs/shifts/2026-11-22-night/lanes/N1-kit/REPORT.md` (section E6) and
  `.../N1-kit/e6/body_order_{world,alone}.txt`.
- **Repro:**
  - `C:/Users/kazda/kiro/third-life/.claude/worktrees/n22-hockey/.tl/w_r2a`, an engine copy with r2a;
  - `.../n22-hockey/docs/shifts/2026-11-22-night/lanes/N3-hockey/wcmp.sh`, which compares the two runs at a frame.

## Fix directions (pick by evidence)
- **(b), preferred if it works:** no body is ever moved; a pack's bodies are created in its own space from the start, so
  lone hashes stay unchanged.
- **(a):** the lone runner also gives the pack its own space and goes through the same insertion path. This moves every lone
  hash once, so every expected hash the gate keeps must be re-recorded, and you say so.
- **Verify the cause first:** a probe that makes the two orders equal must make r2a equal at frame 2050. If it does not, the
  diagnosis is wrong; say so.

## Acceptance
1. **The selftest:** a new selftest (block 760-769) compares a pack's physics body order in world and alone at frame 3, and
   the r2a-like multi-contact case too if you can make it small. It FAILS on main 45f108d and PASSES on the fix; show both
   runs.
2. **r2a hashes the same:** r2a, N3's "the carrier re-decides the moment an opponent comes inside pressure_m", hashes the
   same in world and alone through at least 20000 frames, on 3 seeds. Its source is `n22-hockey/.tl/r2a`, and N3's STANDUP
   lines 03:07-03:52 describe it.
3. **The hash A/B:** A/B every pack verb hash against main with `tl check --tier full --only packs,world`. List which moved
   and why; under (b), none should.
4. **Round 2, after round 1 lands:** land r2a on the landed hockey (`engine/packs/hockey`). The owner kept the bots' spacing
   as it is: no keep_off_m change. Evidence:
   - a window clip of 20 s or less, red passing out of pressure, regular hand;
   - the metrics that move: passes per possession, completion, and red's hits kept;
   - 56/56 hockey tests;
   - world.alone the same.
5. **Gates:** fast and full tier green in your tree. A kernel API change goes in `engine/kernel/API.md`; never stage
   `docs/generated` (the Director regenerates it).

## Scope (your claim)
- **Yours:**
  - `engine/kernel/world/pack.gd`
  - `engine/kernel/world/world.gd`
  - `engine/kernel/runner/**`
  - `engine/kernel/API.md`, if needed
  - `engine/packs/hockey/**`
  - `engine/tools/selftest.d/76*`
  - your lane folder
- **Not yours:** `engine/kernel/world/home/`, `landscape.gd` and `land/` belong to D1.
- **Other kernel files:** if the fix needs one, name it to the Director first.

## Time and rounds
Time box: until 17:15.
- Round 1: E6 and its selftest.
- Round 2: r2a.

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
