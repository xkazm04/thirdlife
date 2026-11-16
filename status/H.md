# Lane H status

SEEN 01:13 started H0; read COMMON.md, H0 brief, JOB3-HOCKEY record (0.1.1: hash 5af10fbc..., 3:1, 4,887 frames, seed 1).
SEEN 01:14 engine/packs/hockey is byte-identical to site/.../promoted/game.ice_hockey_three_against@0.1.1 (diff -r: only the 9 *.gd.uid files Godot's import wrote).
SEEN 01:14 four verbs on engine/packs/hockey exit 0: lint (0 bypasses, 739 lines), smoke eed5cf0dec85f89e @3600, invariants (bot_deterministic 7326d67a twice), bot_hockey 7326d67aeb26ad7a @8130 (3:1, 6 shots, WIN), bot_hockey_ai de74f3a77315f9a5 @17719 (3:2).
SEEN 01:15 the brief's premise "hash 5af10fbc... in 4,887 frames" is the PRE-P7 hash. Named cause: P7 (docs/reports/P7-CONTRACT.md:72-106, 11 Nov) widened statehash.gd (generator + input) and the 0.001 rounding moved bot frame counts; its table rows 91-93 give hockey smoke b0ddd31f->eed5cf0d, bot_hockey 5af10fbc@4888 -> 7326d67a@8130, bot_hockey_ai 19126956@14236 -> de74f3a7@17719. All three of mine equal P7's new column, and P11/P12 reports carry the same. Control: seed_paddle dff1a390@4486, seed_wall cb75fb26@1221 = P7/P11 values. Nothing moved since P7.
SEEN 01:17 world.gd PACK_BASES already has res://packs: a walk or world.sh names the house game as `hockey` (world.sh run --packs=hockey --frames=600: loaded from engine/packs/hockey, exit 0, 0 errors).
SEEN 01:19 my mistake, harmless: one `tl check --tier fast --changed` ran in the MAIN checkout (a `cd ... && (...) &` put the cd in the background subshell). Read-only steps; it may have appended one line to main's gitignored .tl/gate-history.jsonl. Re-run in the worktree below.
SEEN 01:20 check.mjs prints only 300 characters of a step's detail: packs.mjs puts the failing pack and verb names first, then the output folder, then one reason.

## Baseline for the night (engine/packs/hockey, 0.1.1, seed 1, headless, frames counted)
| run | frames | result | state_hash |
|---|---|---|---|
| smoke | 3600 | 0 errors | eed5cf0dec85f89e... |
| bot tests/bot_hockey.gd | 8130 (done at 8130) | blue 3 : 1 red, b0 took 6 shots, WIN | 7326d67aeb26ad7a98deea08b6f81950674672a84b7f5aaa4b6275861699dde4 |
| bot tests/bot_hockey_ai.gd | 17719 | blue 3 : 2 red, 24 AI shots, all six moved | de74f3a77315f9a59b5268adb1148c2093ca19cc6c659dc20a0bdf1127cd2bfd |
| invariants | 3600 idle + 8130 bot twice | determinism, bot_deterministic, budgets all ok | idle eed5cf0d, bot 7326d67a |
Script lines: 739 (scripts 422, gen 6, tests 184; lint). Lint bypasses: 0 ([]). Kit parts used 21, added 0. Frame p99 1.0-1.3 ms (busy machine: decides nothing).

What a person can do today (main.gd, rink_api.gd, data/tuning.json):
- skate one skater, b0 (blue, role "player"), with W A S D (8 m/s top, accel 12, lateral grip 3, turn rate 5); the camera is a fixed high arena view (b0 is its subject).
- Space shoots: only if the puck is within 1.5 m and inside the front cone (dot >= 0.5) and 0.4 s since the last shot; the puck leaves along b0's FACING (not toward a target), 18 m/s.
- R restarts after the match is over (first to 3).
What a person cannot do: pass (no pass verb, no aim at a teammate), carry or own the puck (no possession: the puck is a free ball that a skate bumps), check or contact anyone deliberately (no body check, no cross-check: contact is only physics bodies colliding), switch skater, sprint, stop/brake on a key, change difficulty, see whose puck it is. Teammates b1 (chaser), b2 (back) and red r0 (chaser), r1 (support), r2 (back) are brain.gd bots on three roles.

## Proposed for the Director (not edited by me)
- PATCHES: none needed from neighbours.
- Claims: `.claude/sessions.json` on main holds the stale claim "core-perfection" (night of 11-12 Nov) over engine/tools/**, engine/seeds/**, perf/**, engine/kernel/** and contracts/**. My package touches engine/tools/look.sh, perf/budgets.mjs and engine/kernel/world/draw/far_study.mjs under it (the brief named them). I added no claim (it would overlap and fail `tl arch`); the Director settles the claim file.
- Re-prove (I did not run the export or the window tour): `bash engine/tools/export.sh` then `export.sh check` (docs/EXE.md table at line ~146: hockey plot dc7b01fb9ad8e1da at 2476 own ticks with the site/ copy; the pack is byte-identical, so the same hash is expected); `look.sh clip hockey`; `far_study.mjs walk|motion` without --hockey (now defaults to `hockey`); `node perf/budgets.mjs --only hockey`. Note: the export preset is `all_resources`, so engine/packs/hockey is now also inside ThirdLife.pck besides games/ (217 KB more at most).
- engine/kernel/proc/PROCESS.md:94 still names `site/.../@0.1.1` with the pre-P7 hash: a historical record of P8, left as it is.

READY 01:24
Files (worktree .claude/worktrees/jl-hockey):
- new: devx/lib/gate/steps/packs.mjs, devx/test/packs.test.mjs, engine/packs/README.md, status/H.md
- changed: engine/boot/games.json (hockey `from` engine/packs/hockey, not optional; note), engine/tools/look.sh (clip hockey -> engine/packs/hockey, HOCKEY_PACK still overrides), engine/kernel/world/draw/far_study.mjs (hockey defaults to the house game `hockey`; walk no longer needs --hockey), perf/budgets.mjs (TL_HOCKEY_PACK default `hockey`), devx/lib/commands/play.mjs (lists and resolves house games), context-map.json (context `packs`), docs/OWNERSHIP.md (row House games), docs/EXE.md (hockey row and the P14 note)
- engine/packs/hockey/: unchanged from the Director's copy (Godot's import added the 9 *.gd.uid files)
Acceptance:
| line | verdict | figure |
|---|---|---|
| four verbs exit 0; bot hash equals record or the difference is explained | met | lint/smoke/both bots/invariants exit 0; bot 7326d67a@8130 != record 5af10fbc@4887: named cause P7's hash widening and 0.001 rounding (P7-CONTRACT.md:92), and my hashes equal P7's new column for all three runs |
| `tl check --tier full --only packs` found = completed; a broken copy outside the repo fails naming pack and verb | met | PASS "found 1, completed 1; verb runs 5 of 5; hockey bot:bot_hockey 7326d67aeb26ad7a@8130, hockey bot:bot_hockey_ai de74f3a77315f9a5@17719" exit 0. Broken copy %TEMP%/h0/broken/hockey_broken (an Array index error at frame 600), TL_GATE_PACKS_DIR: FAIL "found 1, completed 0; verb runs 1 of 5; FAILED hockey_broken: smoke, bot:bot_hockey, bot:bot_hockey_ai, invariants; first: hockey_broken smoke: smoke.no_script_errors: 1 errors in 3600 frames" exit 1. An earlier break with `call(` was caught at lint (fence) too. |
| `tl check --tier fast --changed` green; `tl arch` green (claims rule included) | met, one step could not run | arch PASS, assets PASS, cards PASS, devx.test PASS 135 pass 0 fail across 9 files; foreman.typecheck could not run (foreman/node_modules missing in the worktree: not passed). `tl arch` exit 0, 9 rules, scope-claims PASS. |
| `tl play` lists `hockey` | met | "house games (tl play <name>): hockey  Ice hockey, three against three"; `tl play hockey` resolves to engine/packs/hockey (not opened: no window tonight) |
| no file of site/ is read by anything I changed | met | grep "site/" over the changed code files: only the games.json note's prose; look.sh's two site fallbacks and perf/budgets' site default removed |
Kernel members added: none. API unchanged (1.1).
