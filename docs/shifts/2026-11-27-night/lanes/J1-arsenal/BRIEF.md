# J1-arsenal: Arsenal hockey (3 v 3 hockey on the rink core, v0.1.21 with tricks), a unique juice

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-arsenal` (branch n27-arsenal, from main e66eb94e; foreman built, class cache imported at 00:17). Model: Opus. Drive Create as
a person, judge by play and eye, and fall back to building by hand where the editor fails.

**The game:** Arsenal hockey (3 v 3 hockey on the rink core, v0.1.21 with tricks). Its real Create job is `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-arsenal/.tl/jobs/three-against-three-hockey-20261125-1`. The menu copy of its best version is
`C:/Users/kazda/kiro/third-life/.tl/proof-games/arsenal_v0121`. The 25 Nov lane's account of how the game was made, with its job
commands, is `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-25-day/lanes/G1-arsenal/PROOF-G1.md`. Read it first.

**Tonight's juice** (first proposal; you design the details and may change them if a better crazy idea fits the game):
- **The meteor slapshot** (a charged shot): a wind-up, a puck that trails fire and knocks over every skater it touches on the way, a goal net that bulges, glass that shakes.
- **The bots** try it from distance and dive to block it.

**References to mimic:** NHL Hitz and Mutant League (on fire, knockdowns), Blades of Steel.

Lane folder: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-arsenal/docs/shifts/2026-11-27-night/lanes/J1-arsenal/` (STANDUP.md, PROOF-J1-arsenal.md, stills/, clips/).

Acceptance:
- The juice sheet (1-3 abilities) is written before the first sentence.
- Each ability goes in first as a Create change sentence on the real job. Record its time, tokens, path and outcome.
- Every refusal, bend or failure gets a `blocked-editor` line with evidence, and that ability is then built by hand in
  `.tl/juice/arsenal_hand/`.
- For every ability that exists: a clip of 20 s or less, stills you looked at, uses per minute by the bots, 3600 headless
  frames with 0 script errors, and the same hash twice.
- PROOF-J1-arsenal.md says which abilities the editor made and which were made by hand, and how each feels to a person.
- "landable J1-arsenal", with the best pack path and the menu title, by 07:00.

---

# Night rules (27 Nov 2026), above the lane rules

- **The owner's words:** "lets use the night to give each game a unique juice. We will need to demonstrate juicy/crazy
  ability to express we can compose any ide there: For example carts with ability to jump, Robots with doublesledged
  hammer allowed to bash oponents, Basketball with crazy high jumps and dunks/blocks."
- **Read first:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/PLAN.md`,
  especially "What juice means tonight". The ability must be crazy and must read at a glance:
  - anticipation;
  - exaggeration;
  - impact (hit-stop, camera kick, knockback with a tumble, particles, sound);
  - the game answering it: the bots use it and react to it, and there is counterplay or a cost.
  Behaviour first: it changes what the hand and the bots do, not only the look.
- **The machine:** RAM at most 80 %, no CPU cap. Before every heavy step (a Foreman job start or change, any Godot run, a
  lab check, npm test, a selftest block) run
  `bash C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/tools/room.sh --wait`.
  Never kill a process you did not start. Another session (the Home sandbox) runs all night. Never touch
  `engine/kits/**`, `engine/kernel/**`, `engine/boot/**` or `contracts/**`.
- **Paths:** absolute paths only; never `cd` in a backgrounded command. Run Foreman job commands detached, one per line, and
  read their logs. A script that starts real (paid) work gets one dry start, checked within 5 minutes.
- **Rounds:** 45-75 minutes. A STANDUP line at least every 60 minutes. A lane silent for 60 minutes is asked; at 120 it is
  stopped.
- **Landable:** after you write "landable", stop editing until the Director says it landed. When you need the Director
  (a fast-forward, a ruling, a menu row), end your turn with the ask in your final message.

## For juice lanes (J*): you are the person first
1. **Design before you type** (at most 20 minutes). Write the juice sheet at the top of `PROOF-<lane>.md`. For each of
   1-3 abilities:
   - the key;
   - the wind-up;
   - the exaggeration, in numbers;
   - the impact;
   - what the bots do with it and against it;
   - the counterplay or cost;
   - the reference game it copies.
   Then the sentence a person would type for it.
2. **Editor first.** Send each ability as a Create change sentence on your game's real job, exactly as a person does:
   - Create's command order through `foreman`, with the flags of `engine/ui/flags/real.json` (real adapter, paid);
   - your jobs root is your tree's `.tl/jobs/`;
   - answer every card as a person would.
   Read your game's 25 Nov PROOF doc first: it has the job's commands and what the editor did.
   For each change record: time, tokens, path (fast/full), what changed, and whether it is what you asked, as you see it
   played.
3. **When the editor refuses, bends or fails an ability:**
   - write a `blocked-editor` line: `blocked-editor: <what a person met> | evidence: <job event / still>`;
   - end your turn with it if the Director must route it (lane T fixes the editor tonight);
   - meanwhile build that ability by hand. Copy the job's newest pack to `.tl/juice/<slug>_hand/` in your tree and add the
     ability there, with the TL* API only.
   Never edit foreman/, engine/ or contracts/. The verdict says which abilities came from the editor and which were built
   by hand.
4. **Prove it as a person meets it,** for each ability that exists:
   - one window clip of 20 s or less (mp4): the hand using it, and a bot using it;
   - 2-3 JPG stills you LOOKED at, with plain words on how it feels;
   - a headless run of 3600 frames with 0 script errors, and the bots' uses per minute;
   - determinism held (same seed, same hash).
   Film as the 25 Nov lanes did (their PROOF docs: window captures through the exe's `TL_EXE_*` variables or the engine
   tools; ffmpeg to mp4), using the repo's window lock.
5. **Landable:**
   - give the Director the best pack path (a job version or `.tl/juice/...`) and the menu title you want;
   - write "landable <lane>";
   - be done by 07:00.

---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-27-night/lanes/J1-arsenal/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
