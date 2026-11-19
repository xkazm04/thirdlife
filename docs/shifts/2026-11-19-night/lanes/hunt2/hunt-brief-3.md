# QA round 2, part 3: the kernel API, the packs and the seeds in depth

You are a QA engineer writing failing tests for Third Life (Godot 4.7.2 game sandbox). Repository: this directory (a git
worktree). Read `CLAUDE.md`, `contracts/README.md`, `contracts/PACK.md`, `contracts/RUNNER.md`, `engine/kernel/API.md`, then
`docs/shifts/2026-11-19-night/lanes/hunt2/astra-findings.md` (A1-A15) and `astra-findings-2.md` (B1-B12): do NOT re-report
those. Godot: `G=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe` (class cache imported).
Git Bash on Windows. `docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh <ID>` runs a `.gd.txt` case.

## Rules (same as parts 1 and 2)
- Read-only git is fine (`git log`, `git diff`, `git show`, `git blame`); do not commit, stash, reset or checkout.
- Do NOT edit any file outside `docs/shifts/2026-11-19-night/lanes/hunt2/`. Finding and proving, not fixing.
- Repros under `docs/shifts/2026-11-19-night/lanes/hunt2/repro/` named `C<n>.gd.txt` / `.sh` / `.py`, first comment line =
  exact run command, final line `REPRO C<n>: FAIL <numbers>` or `REPRO C<n>: PASS`.
- Always `--headless`, `timeout 180`, time in physics frames. Never kill a process you did not start. No full gate. The
  director runs the full gate in parallel: if the machine is slow, that is why; do not stop it.

## Task 1 (about 15 %): review the two newest fixes
`git diff -- engine/kernel/api/tl_hand.gd` (B10: a postponed release now pushes what follows so a next press keeps an up
frame) and `git diff -- engine/packs/hockey/scripts/main.gd` (A14 + B1: venues, dress and benched skaters kept out of the
tree are freed at NOTIFICATION_PREDELETE). Try to break them: hand stats (`taps_lost`, `presses`, `lengthened`), axis keys
and the opposite-key rule, held keys (`press` then `release`), sticks/overshoots, determinism per seed; a predelete that
frees a node still referenced, double free, a node in the tree at predelete, the dress shown/hidden by mode.

## Task 2 (about 85 %): hunt where the director can fix (scope `engine/kernel/api/**`, `engine/packs/**`, `engine/seeds/**`,
`engine/boot/**`)
1. Kernel API classes not yet probed: `TLRules` (checkpoints, laps, time limit, finish, best laps, snapshot), `TLInput`
   (declare, tap, just_pressed, axis, aim, record/replay samples), `TLContext` (seeded generator, read_json, load_script,
   space_state_of), `TLTrigger` / `TLBodies` (enter/exit, group_filter, teleports), `TLHud`, `TLOrbitCam`, `TLBiped` default
   feel and walker feel (`set_body_scale` while sliding, `place` mid-slide, `down()` / get up, `facing`), `TLVehicle` (other
   than nitro), `TLBall` (other than the holder), `TLLaws`, `TLDamage`, `TLStandin`, `TLKit` / `TLMesh` use from packs.
   Check the API.md promises line by line against the code: unknown option keys must be errors, absent = omitted (never
   null/0), lists not singletons, determinism.
2. `engine/packs/hockey/**` (modes, drills, dial, menu, AI under `scripts/ai/`, fx, look): a mode switch or R mid-goal,
   face-off states, a menu action during a pause, AI with a skater down, the dial, state() keys, hash stability.
3. `engine/packs/parkour/**` beyond the retry (A3/A15 done): checkpoints, camera chute tilt, HUD, falls, restart while
   sliding, the views.
4. `engine/seeds/**` (seed_drive, seed_wall, seed_paddle: rules, bots, tuning keys) and `engine/boot/**` (boot.gd verbs
   check / probe / tag, --games, --site-job, TL_EXE_* env parsing, village.json loading).

## Evidence standard (a finding without all of these is dropped)
`file:line` (current lines) and why, citing the doc/contract line it violates; a runnable repro you ran twice, with the
output pasted; severity (high: wrong gate verdict, crash, determinism break, data loss, stuck/fall-through in shipped
content; medium: wrong behaviour met in normal use; low: edge, cosmetic, doc); reach (the caller in shipped code); `may
predate 17 Nov` flag from `git blame`. Prefer 6-12 proven findings over many speculative ones.

## Deliverable
`docs/shifts/2026-11-19-night/lanes/hunt2/astra-findings-3.md`, written incrementally: one section per finding (C1, C2, ...)
high -> low, each with file:line, why, repro path + command, pasted output, severity, reach, predate flag, suggested fix.
Then "Fix review: held" (task 1) and "Probed and sound" (task 2).
