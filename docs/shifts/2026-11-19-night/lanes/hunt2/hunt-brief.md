# QA round 2: find real defects in Third Life (Godot 4.7.2 game sandbox) and write a runnable test for each

You are a QA engineer writing failing tests. Repository: this directory (a git worktree). Read `CLAUDE.md` first, then
`contracts/README.md`, `engine/kernel/API.md`. Godot console exe:
`G=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe` (class cache already imported; if a
class is missing run `"$G" --headless --path engine --import` once). Shell is Git Bash on Windows.

## Rules
- Read-only git is fine (`git log`, `git diff`, `git show`, `git blame`); do not commit, stash, reset or checkout.
- Work only inside this directory. Do NOT edit any file outside `docs/shifts/2026-11-19-night/lanes/hunt2/`. This round
  is finding and proving, not fixing.
- Put every test/repro under `docs/shifts/2026-11-19-night/lanes/hunt2/repro/` as `.gd.txt` (a GDScript `extends SceneTree`
  script; run it by copying to a temp `.gd` under the repro folder or by `--script` on a copy), `.sh` or `.py`. The first
  comment line of each repro is its exact run command from the worktree root. Each repro prints one final line
  `REPRO <id>: FAIL <what is wrong, with numbers>` when the defect is present and `REPRO <id>: PASS` when it is not.
- Always `--headless`. Count time in physics frames (60 Hz), never wall clock. Use `timeout 180` around every Godot run.
- Never kill a process you did not start. Other sessions run Godot on this machine.
- Do not run the full gate (`tl check --tier full`); it takes 25 minutes. Small focused runs only
  (`bash engine/tools/selftest.sh <filter>` and single scripts are fine).

## Where to look (what changed since 17 Nov; `git log --since=2026-11-17 --stat` shows it)
Priority order:
1. Kernel API: `engine/kernel/api/tl_biped.gd` (walker: slope jump `SLOPE_JUMP_PUSH`, steep rest, slide, jump buffer,
   edge slide), `engine/kernel/api/tl_chase_cam.gd` (crown band, wall start, avoid_min, rebase into parent frame, snap
   heading, exact reversal, cut on a 90 degree turn), `tl_ball.gd`, `tl_vehicle.gd`. Did each of yesterday's fixes
   (`docs/reports/bugfix-37/REPORT.md`, the D/Q table) actually hold at its edges, and did one break a neighbour?
   Examples to probe: slope jump chaining up a steep bank or V; jump buffer at exactly 8/9 ticks; camera with a parent
   that is rotated/scaled; `snap()` with zero velocity; `avoid_min` larger than distance; determinism (same seed and
   frames give the same state_hash) of anything newly added.
2. Packs: `engine/packs/parkour/**` (rotated course 50x28 m, 4 checkpoints, a new "C retry" that sends you to the landing
   checkpoint when stopped at the beam's near face; see `docs/shifts/2026-11-19-night/lanes/parkour/REPORT.md`) and
   `engine/packs/hockey/**`. Probe: can C retry fire elsewhere / after finish / during a fall / repeatedly to skip a
   section; checkpoint order skipping; timer after retry; hash determinism with retry; HUD state after reset.
3. `engine/seeds/**` and `engine/boot/**` (boot.gd, games.json, village.json): manifest/JSON validation (unknown keys must
   be errors, absent value = omitted key, never null/0), game list loading, paths.
4. The rest (report only, others own them): `engine/kernel/world/**` (walker in the village, terrain, site, draw, view,
   world_space, visitor), `engine/kernel/runner/**` (visit.gd, stage hand-over), `engine/rigs/**`, `engine/style/**`,
   `engine/tools/selftest.sh` and `engine/tools/selftest.d/*.sh` (does any block report PASS for a stopped or empty run?
   `docs/GATE-HONESTY.md`), `devx/lib/**` (the `tl` tool: `tl ladder`, `tl check` steps), `engine/ui/**`.
Known and NOT to re-report: V channel narrower than the capsule wedges him; held slide 0.151 m below floor; pad swap holds
him one tick inside a higher floor; Q31 slide hand height; Q24 sky mask edge; hockey `invariants.many_budget` timing under
load; `tl ladder` "draws 20" display quirk.

## Evidence standard (a finding without all of these is dropped)
- `file:line` of the defect (current line numbers) and a one-paragraph why, citing the contract/doc line it violates.
- A runnable repro that you ran yourself, with the exact output you saw pasted.
- Severity: high (wrong verdict from a gate, crash, determinism break, data loss, player can fall through or get stuck in
  shipped content), medium (wrong behaviour a player or developer meets in normal use), low (edge, cosmetic, doc).
- Reach: does the shipped game or gate actually get there (name the caller)?
- `may predate 17 Nov` flag when `git blame` says the line is older than 2026-11-17.
- Prefer 8-15 solid, proven findings over many speculative ones. Re-run each repro once more before reporting it.

## Deliverable
`docs/shifts/2026-11-19-night/lanes/hunt2/astra-findings.md`: one section per finding (id A1, A2, ...), sorted high ->
low, each with file:line, why, repro path + command, pasted output, severity, reach, predate flag, and a suggested fix in
one or two sentences. End with a list of what you probed and found sound (so nobody re-probes it). Write the findings file
incrementally (after each proven finding), so a stopped run still leaves the work on disk.
