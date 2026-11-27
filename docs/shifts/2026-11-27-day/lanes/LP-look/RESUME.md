# Lane LP, resumed (11:50): pick up the look polish from the worktree

The first LP agent went silent at 09:09 (last standup 08:33; its last words: "Now I'll rewrite the terrace case for the per-triangle rock") and was stopped by the Director at 11:48. Its work is ON DISK in `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-look` (uncommitted):
- `engine/kernel/world/build/land_mesh.gd` (terrace: rock per triangle from its plane), `engine/style/shaders/toon_cel.gdshader` (+184: terrace face beds/joints; growth kinds cut from the density ratio, a lush two-green meadow, lighter tall grass with wind sheen and light tufts, flowers as screen-round dots), `path_mesh.gd` (stone path), `water_cel.gdshader` (shore), `land_look_case.gd` (half-rewritten case: likely broken), and a new `look_shots.gd` (a capture scene), scratch scripts under `.tl/` (shots0 = before captures, cap/, pxdiff.mjs).
- Its standups: `docs/shifts/2026-11-27-day/lanes/LP-look/STANDUP.md` in the worktree.

**Changed scope**: item 5 (the LLM bridge's prompt) moves to lane C, which owns `foreman/` today; the Director reverted `foreman/prompts/world_edit.md` in your tree. Do not touch `foreman/`.

## Do, in rounds (each round: a standup line "landable" and then touch no file of that round)
1. First, within 15 minutes: read the diff (`git diff`), the brief (`BRIEF.md` beside this file), and write a standup line saying what state you found (compiles? 764/768 green?).
2. **Round 1: terrace + growth** (land_mesh.gd, toon_cel.gdshader, land_look_case.gd): get the cases green (764 HOME look, 763 plants, 610 celsurf, n3 pins byte-identical for unedited ground), after-captures from the same cameras as the before set (`lp-terrace-before/after.jpg`, `lp-growth-10m/25m/50m` before/after), frame p50/p99. Landable.
3. **Round 2: stone path + pond shore** (path_mesh.gd, water_cel.gdshader, and whatever else the shore needs): the same evidence (`lp-stone-path-before/after.jpg`, `lp-shore-before/after.jpg`), 762 paths and 761 water green. Landable.
4. Gates before done (per the brief): fast; the uncapped `bash engine/tools/selftest.sh`; `node devx/bin/tl.mjs check --tier full --only world,packs` (packs' hockey many_budget is red on main too under load: A/B against d25-main if it fails).

## Working rules added after the stall
- A standup line at least every 45 minutes, before any step that may take long, and when a step fails.
- No single tool call longer than 20 minutes: background long runs and check on them; write big files in pieces (Edit), not one giant Write.
- Machine: 4 other Opus lanes run Godot (DN, P, T, C); one heavy step at a time.
