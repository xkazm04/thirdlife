# QA round 2, part 2: new areas, plus a review of the fixes made after part 1

You are a QA engineer writing failing tests for Third Life (Godot 4.7.2 game sandbox). Repository: this directory (a git
worktree). Read `CLAUDE.md`, `contracts/README.md`, `engine/kernel/API.md`, then
`docs/shifts/2026-11-19-night/lanes/hunt2/astra-findings.md` (part 1: findings A1-A15 and what held; do NOT re-report
those). Godot: `G=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe` (class cache imported).
Git Bash on Windows. `docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh <ID>` runs a `.gd.txt` case the same way as
part 1.

## Rules (same as part 1)
- Read-only git is fine (`git log`, `git diff`, `git show`, `git blame`); do not commit, stash, reset or checkout.
- Do NOT edit any file outside `docs/shifts/2026-11-19-night/lanes/hunt2/`. Finding and proving, not fixing.
- Repros under `docs/shifts/2026-11-19-night/lanes/hunt2/repro/` named `B<n>.gd.txt` / `.sh` / `.py`, first comment line =
  exact run command, final line `REPRO B<n>: FAIL <numbers>` or `REPRO B<n>: PASS`.
- Always `--headless`, `timeout 180`, time in physics frames. Never kill a process you did not start. No full gate.

## Task 1: review the fixes (do this first, about 20 % of your effort)
`git diff` shows the uncommitted fixes the director made after part 1, in `engine/kernel/api/tl_ball.gd` (A6),
`tl_chase_cam.gd` (A4, A10), `tl_vehicle.gd` (A9), `engine/packs/hockey/scripts/rink_api.gd` (A7, A8) and `main.gd` (A14),
`engine/packs/parkour/scripts/main.gd` (A15), `engine/boot/boot.gd` (A2), and a new selftest block
`engine/tools/selftest.d/360-hunt2-fixes.sh` (run: `bash engine/tools/selftest.sh hunt2.`). Try to break each fix: an edge
it misses, a neighbour it breaks, a determinism change (same seed + frames must give the same state hash), a test in the
block that would pass on the unfixed code, a GDScript gotcha (freed objects, weakref, signals). Report each problem as a
finding with a repro (ids B1, B2, ...), or list the fix under "held" with what you tried.

## Task 2: hunt in areas part 1 did not cover (about 80 %)
Priority order; findings outside `engine/kernel/api`, `engine/packs`, `engine/seeds`, `engine/boot` are still wanted (other
teams fix them), so give them the same evidence:
1. `engine/kernel/world/site.gd` and `engine/kernel/world/site/**` (construction site that shows a Foreman job from its
   `job.jsonl`; fixtures under `site/fixtures/`): malformed or growing logs, a job that fails, a promoted game arriving,
   paths, determinism.
2. `engine/kernel/runner/visit.gd`, `bugfix_runner_*.gd` (stage hand-over, recording `--record`, replay): does a recorded
   visit replay to the same hash? inputs held across hand-over? lengths.
3. `engine/kernel/world/terrain/**` (world_space, world_body walker, village_terrain, landmarks incl. the Pip landmark at
   `assets/engine/pip.glb`), `engine/kernel/world/draw/**` (view, view_seam, draw_pictures caches keyed `|cover2`,
   PIC_VERSION 15), `engine/kernel/world/visitor.gd`: holes, floors, caches, a visitor stuck or falling through.
4. Gate honesty in `engine/tools/selftest.d/*.sh` (all blocks, not only 310), `engine/tools/seeds.sh`, `engine/tools/tl.sh`,
   `devx/lib/gate/steps/*.mjs`, `devx/lib/commands/ladder.mjs`: a stopped / empty / partial run reported PASS, a count that
   can drop silently, an exit code that lies (`docs/GATE-HONESTY.md`).
5. `engine/seeds/*/tests/bot_hand_*.gd`, `TLHand` (`engine/kernel/api/`): hand profiles, determinism, lost taps.
6. `engine/rigs/**` (biped rig, gait, moves, review tools) and `engine/style/**`.

## Evidence standard (a finding without all of these is dropped)
`file:line` (current lines) and why, citing the doc/contract line it violates; a runnable repro you ran twice, with the
output pasted; severity (high: wrong gate verdict, crash, determinism break, data loss, stuck/fall-through in shipped
content; medium: wrong behaviour met in normal use; low: edge, cosmetic, doc); reach (the caller in shipped code); `may
predate 17 Nov` flag from `git blame`. Prefer 6-12 proven findings over many speculative ones.

## Deliverable
`docs/shifts/2026-11-19-night/lanes/hunt2/astra-findings-2.md`, written incrementally: one section per finding (B1, B2, ...)
high -> low, each with file:line, why, repro path + command, pasted output, severity, reach, predate flag, suggested fix.
Then "Fix review: held" (task 1) and "Probed and sound" (task 2).
