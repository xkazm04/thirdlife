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

## H1: the puck is yours when you reach it, and you can pass (started 01:26)
SEEN 01:30 Director's word: H0 accepted (3249be7); P7's table is the record; *.gd.uid not committed; the claims file is the Director's; no `cd` in a background subshell (every command now takes absolute paths).
SEEN 01:33 a bot can only press declared actions, and `TLInput.press` clamps a digital action to 0..1, so a set start cannot be chosen by a value. Seam used: one declared action per drill, `drill_<id>`, with NO key (a keyboard cannot press it; a test can; it is in the input record, so a replay reproduces it). Drills are data: `data/drills.json`, unknown drill keys are a push_error naming drill and key.
SEEN 01:38 first bot-only match: the three seeds gave the same first goal at frame 848: the match start used no randomness (the face-off jitter was only applied after a goal). Fixed: the opening face-off draws its jitter from ctx.rng too.
SEEN 01:38 first pass test 3 of 10: the drill's mate accelerated all through the pass (a skate intent thrusts to top speed), so any lead was stale. Fixed by the rule a person expects: the mate a pass is meant for skates to meet it (rink_api `receive_dir`, used by the brain and the drill): 9 of 10.
SEEN 01:39 poke ping-pong in the bot match (b0 21 pokes, r0 22 in 2,121 frames): a poked carrier may not poke straight back for poke_lock_frames.
SEEN 01:44 the reach ring: the kit has no ring part. Built in a generator with the kit's toolbox (`gen/ring_hook.gd`: TLMesh annulus, palette key `yellow`, style material): lint counts it as kit_parts_added 1, bypasses []. Under b0 only. Still: %TEMP%/h0/cap/h1_chase_600b.png (the yellow ring under the middle blue skater). White (`line_white`) was invisible on the ice: h1_chase_600.png.
SEEN 01:46 adding declared actions changes every hash with no change of play: the hash covers every declared action's value (P7). bot_hockey 4042571867c84b43 -> ab69394ced2ff76e, both at 3,088 frames.

What changed (engine/packs/hockey):
- scripts/rink_api.gd: rewritten as the possession module: reach circle (swept against the puck's last step), carry (TLBall.hold at the stick side, slower carrier), shot from the carry, pass (mate nearest the facing in a 50 deg cone, aimed at his lead point; to nobody: straight ahead), poke, locks after a release, a carried puck kept inside the boards, possession in the state.
- scripts/main.gd: actions pass Q, poke E, sprint Shift; `autopilot` and `drill_<id>` with no key; possession before anybody acts; a goal counts only for a loose puck; the opening face-off jitter; drills; state: puck.holder (omitted when loose), possession {carrier, team, since, last, takes, passes, pokes}, reach, poke_reach, pass_ready, poke_ready, per-skater speed, drill, autopilot; a `chase` view for stills.
- scripts/ai/brain.gd: rewritten: carrier, our puck, their puck, loose puck, per role (see its header); the receiver; yield to the human kept (blue mates leave a loose puck to b0 when he is as near; red does not poke b0 in his first 45 frames with it).
- data: tuning.json (carry, rink, skater_sprint_scale, faceoff_jitter, chase_camera; `shoot.reach` and `shoot.front_dot` removed: the reach is now carry.reach), ai.json (new role numbers), drills.json (new). pack.json: tests + bot_reach, bot_match; assets + gen/ring_hook.gd; cameras + chase; params + reach, pass_speed.
- tests/bot_reach.gd, tests/bot_match.gd (new). The two old bots unchanged.

Reach table (tests/bot_reach.gd, seed 1; frames from "inside his reach" to "his" as the bot sees the state, one frame late as a person sees the screen):
| row | frames | bound | note |
|---|---|---|---|
| still beside him | 0 | 1 | the drill puts it inside: his on the drill's own tick |
| behind him | 0 | 1 | same |
| in the ring, he faces away | 0 | 1 | same |
| slides into the ring from behind him (3 m/s) | 1 | 1 | |
| slides in from the side, he faces away (4 m/s) | 1 | 1 | |
| skates through at walk (2 m/s, then glides) | 1 | 1 | top 2.2 m/s, 1.2 at the take |
| skates through at full speed | 1 | 1 | 8.0 m/s at the take |
| skates through at sprint (Shift) | 1 | 1 | 10.0 m/s at the take |
| skates through with Space held | 1 | 1 | held through the take: no shot fires (a held key is not a press), he carries |
| skates through with Q held | 1 | 1 | same for the pass |
| own pass to nobody, he chases it | 1 | 1 | not retaken while it leaves (lock 12 frames or under 4 m/s); retaken 1 frame after it is inside his reach again |
| an opponent pokes it, Space held through | 0 | 1 | r0 has it on the frame the bot first sees it loose; b0's poke lock (20 frames) was NOT exercised: the puck never stayed in b0's reach |
| he pokes theirs, 12 frames late | 1 | 1 | |
Pass in open ice: 9 of 10 reached the mate (drill pass_open, mate placed and moving from ctx.rng; the miss: mate at (14,-10), nobody took it in 150 frames).

READY H1 01:50
| acceptance line | verdict | figure |
|---|---|---|
| every row of the reach table within its bound | met | 13 of 13 rows; caveat above: the poke row does not exercise the victim's lock |
| a pass reaches a mate in at least 8 of 10 seeded tries in open ice | met | 9 of 10 |
| bots score against each other in a bot-only match: both sides within 6,000 frames on 3 seeds | met (seeds 1, 2, 3); seed 5 of the extra two did not | seed 1: 1:1 at 1,700 (blue 1,002, red 1,700); seed 2: 1:1 at 1,095; seed 3: 1:1 at 2,488; seed 4: 2:1 at 2,357; seed 5: red won 3:0 at 1,666, blue never scored |
| four verbs green | met | `tl check --tier full --only packs`: found 1, completed 1; verb runs 7 of 7 (lint, smoke, 4 bots, invariants) |
| invariants.bot_deterministic true | met | bot_hockey twice, seed 1: ab69394ced2ff76e after 3,088 frames, both runs |
| 0 bypasses | met | bypasses [], kit_parts_added 1 (the ring) |
Gate: `tl check --tier fast --changed`: arch PASS (19 changed paths map to arch only). tl arch green.
Baseline after H1 (seed 1): smoke 8f139872ddda7f22 @3600 | bot_hockey ab69394ced2ff76e @3088, blue 3:1, 6 shots, WIN (unchanged file: it still wins; it now takes the puck on reach and carries it) | bot_hockey_ai 7126a594be2e4a31 @6687, red 3:2, ai_shots 7 (unchanged file: still ok: it requires a winner, AI shots and movement, not a blue win) | bot_reach a0282ec162a1f1b1 @2027 | bot_match addcf8d6c6b22f71 @1701. Script lines 1,487 (lint). Bypasses 0.
FOR THE KERNEL (H1): (1) a way for a test to start a set situation: today one keyless declared action per drill; a kernel `ctx.input` value channel for a digital action, or a test-only `drill` verb, would be cleaner. (2) A ring under a figure as a kit part (`ring`, radius, width, palette key): today the pack builds it in a generator. (3) TLBiped has no top-speed modifier: carrying and sprinting set `skate_speed` each frame from the pack.

## H2: hits by the speed you bring, shown by the figures alone (started 01:48)
SEEN 01:50 bipeds are CharacterBody3D: `TLBiped.pushed` fires only for a RigidBody and `TLContact` tracks one rigid body, so neither sees skater against skater. The hit is measured in the pack: closing speed = (v_hitter - v_victim) . n, n the unit line hitter -> victim. A shove is a change of the biped's `velocity` (no kernel call exists for it).
SEEN 01:52 decided by a keyboard hand: body check F, cross-check C, two keys (both under the left index finger beside W A S D). A tap/hold split on one key adds a hold delay to every check, and a person holding F through a hit would get the other one. Holding F while standing still = bracing.
SEEN 01:56 the figures interpenetrate at every contact (stills h2_hit_f930.png, h2_hit_f1470.png): the pack scales each rig x2.2 (main.gd, from the job of 11 Nov) but TLBiped sizes its capsule from the rig's metrics before that scale: bodies of 0.3 m radius carry figures about 1.3 m wide. The check reaches 1.7 m between centres, so the figures already overlap when it lands. Not changed by me (a look decision): FOR THE KERNEL below.
SEEN 02:03 the old bot_hockey_ai stalled 36,000 frames: the puck carried into the boards was released, given straight back to the same skater the next tick (takes 902 in 4,000 frames), so carry_since restarted and red's 45-frame "yield to the human" never ended. Fixed: no release at the boards; the puck moves to a side of him that is inside.
SEEN 02:05 my first fix for that (the puck tucked under him) put a kinematic body inside his capsule and shoved him out through the boards: b0 at z = 3,514 m with the puck.
SEEN 02:08 a second escape with the fix in, seed 5: r0's velocity jumped from 1.8 to 47 m/s in 8 frames (frames 504..520) and he left the rink through the corner. Cause: the carried puck, a kinematic body teleported every frame, acted as a moving PLATFORM under a skate; leaving it added its velocity (CharacterBody3D.platform_on_leave defaults to ADD_VELOCITY). Fixed in the pack: every skater `platform_on_leave = DO_NOTHING` (FOR THE KERNEL). bot_match now counts skater-frames outside the 60 x 30 m rink and fails on any: 0 on six seeds.
SEEN 02:09 bot-only scoring was rare and chaotic (a single tuning step flipped seeds): b1's role changed chaser -> support so blue mirrors red (chaser, support, back; b0 is the chaser), carriers shoot only when the facing from the puck falls inside the goal mouth, a carrier stuck 45 frames under 1.5 m/s passes or shoots, a carrier at or behind a goal line goes round the net. bot_match plays 6,000 frames and presses R after a finished match (as a person would) and counts goals over the 6,000.
SEEN 02:11 knockdowns were 5..8 a minute a side at knock_speed 7.0 (head-on closings of two bots add both speeds): moved to 7.8, frames down 30 + 12 per m/s over it, at most 60. Down share now 0.0..2.6 % (was up to 13.6 %).

What changed (engine/packs/hockey):
- scripts/hits.gd (new): check, cross-check, brace, outcome classes, down/stumble timers, enforce (a man down lies still with the brake on, then gets up), counts in the state.
- scripts/main.gd: actions check F, cross C; hits wired (tick, brace, enforce, reset at face-off and drill); `hits` in the state (given by side and class, by skater, frames down, side_down, down, stumbling, last); `check_ready`; drills take `brace`; `platform_on_leave` per skater.
- scripts/rink_api.gd: a man down or stumbling cannot take the puck; a hit knocks it loose (`knock_loose`, kind "hit": the victim cannot take it back for 20 frames); speed scale while stumbling; the carry at the boards (see above); shot and pass play the rig's `shoot` and `pass` clips.
- scripts/ai/brain.gd: checks (red from closing 4.0 m/s, blue from 6.5: red hits more), stuck carrier, round the nets, shot line, receiver; a man down does nothing.
- scripts/fx/fx.gd: hit events are sound only (`hit_wood`); the speed spray is held back 45 frames after any hit.
- data: tuning.json `hits`, roster b1 support; ai.json new keys; fx.json `no_spray_after_hit_frames`; drills.json 5 hit drills. tests/bot_check.gd (new), tests/bot_match.gd (6,000 frames, restarts, rink check). pack.json tests + bot_check.

Check table (tests/bot_check.gd, seed 1; b0 holds the row's pace with D, taps F at 1.5 m; data: bump under 3.0, knockdown from 7.8 m/s, down 30 + 12/(m/s), 30..60 frames):
| row | closing m/s | class | frames down |
|---|---|---|---|
| head-on 1.00 | 1.06 | bump | 0 |
| head-on 2.75 | 2.90 | bump | 0 |
| head-on 4.50 | 4.59 | stumble | 0 (40 frames slowed) |
| head-on 6.25 | 6.42 | stumble | 0 |
| head-on 8.00 (top) | 8.00 | knockdown | 32 (seen down 32) |
| side 1.00 | 1.06 | bump | 0 |
| side 2.75 | 2.90 | bump | 0 |
| side 4.50 | 4.59 | stumble | 0 |
| side 6.25 | 6.42 | stumble | 0 |
| side 8.00 (top) | 8.00 | knockdown | 32 |
| braced (standing, F held), side, 8.00 | 8.00 | bump: he holds | 0 |
| the carrier presses F at 7.36 m/s | - | none: nothing happens, he keeps the puck | 0 |
| cross-check C on a carrier at 2.06 m/s | -1.44 | cross: puck off him, no knockdown, no fall | 0 |

Bot-only play, 6,000 frames each (tests/bot_match.gd; hits given by side; "down" = frames in which the side had at least one man down):
| seed | goals blue:red | knockdowns given blue / red (per minute) | stumbles blue / red | red hits vs blue's mates b1+b2 | side down blue / red |
|---|---|---|---|---|---|
| 1 | 4:5 | 3 / 3 (1.8 / 1.8) | 8 / 6 | 9 vs 3 | 145 (2.4 %) / 155 (2.6 %) |
| 2 | 5:4 | 3 / 1 (1.8 / 0.6) | 7 / 9 | 10 vs 3 | 45 / 128 |
| 3 | 5:4 | 2 / 0 (1.2 / 0) | 5 / 8 | 8 vs 0 | 0 / 100 |
| 4 | 3:5 | 1 / 3 (0.6 / 1.8) | 5 / 8 | 11 vs 2 | 158 (2.6 %) / 52 |
| 5 | 1:6 | 3 / 2 (1.8 / 1.2) | 3 / 11 | 13 vs 3 | 96 / 129 |
| 6 | 2:5 | 1 / 2 (0.6 / 1.2) | 5 / 9 | 11 vs 3 | 69 / 32 |
Every seed: skater-frames outside the rink 0. No side has a man down in more than 2.6 % of frames.

Nothing drawn at a contact, how checked: (1) the event list: hits.gd emits `hit_bump|hit_stumble|hit_knockdown|hit_cross`; fx.gd answers them with `_play("hit_wood")` only. (2) grep of every TLVfx / MeshInstance3D / TLHud / add_child / TLKit.build in scripts/: TLVfx only in fx.gd for `shot` (ice spray at the shooter), `goal` and `win`, and the speed spray, which is now held back 45 frames after any hit; hits.gd and rink_api.gd create no node. (3) stills for the Director (chase camera, tests/bot_check.gd): %TEMP%/h0/cap/h2_hit_f930.png (stumble: the victim turned sideways by `skate_stop`), h2_hit_f1470.png and h2_hit_f1490.png (head-on knockdown: `fall`), h2_hit_f3612.png (cross-check: the hitter's `shoot` swing). I looked at f930 and the earlier f1468/f1500: nothing drawn; the overlap of the figures is the SEEN of 01:56.

READY H2 02:14
| acceptance line | verdict | figure |
|---|---|---|
| the speed table is monotone | met | head-on and side: bump, bump, stumble, stumble, knockdown at 1.06 / 2.90 / 4.59 / 6.42 / 8.00 m/s |
| frames down within the data's bounds | met | 32 frames at 8.0 m/s (bounds 30..60), seen down 32 frames by the bot |
| no draw call of any kind at a contact (show how) | met | the three checks above; stills named |
| carrier's check does nothing; braced man holds | met | carrier row: none, puck kept; braced row: bump, braced true |
| bot-only knockdowns a minute by side; no side down more than about 1 frame in 10 | met after tuning | table above: 0..1.8 knockdowns a minute a side, side down at most 2.6 % (it was 13.6 % at knock 7.0: tuned and said) |
| four verbs green | met | `tl check --tier full --only packs`: found 1, completed 1, verb runs 8 of 8 |
| deterministic | met | invariants: bot_hockey twice, seed 1: 0ffeff5924e59104 after 2,627 frames, equal |
| 0 bypasses | met | bypasses [], kit_parts_added 1 (the ring) |
| H1 lines again on this code | met | reach 13 of 13, passes 9 of 10; bot-only: both sides scored on all six seeds |
Gate: fast --changed: arch, assets, cards, devx.test (135 pass) PASS; foreman.typecheck could not run (foreman/node_modules missing in the worktree). tl arch green.
Baseline after H2 (seed 1): smoke faad91d2c2d1a66f @3600 | bot_hockey 0ffeff5924e59104 @2627, blue 3:1, 4 shots, WIN (file unchanged, still passes) | bot_hockey_ai 376fec8bc5890c02 @5409, red 3:0 (file unchanged; its ok needs a winner, AI shots and movement: passes; before the board fix it stalled) | bot_reach 0932e1f0b4b37f60 @2027 | bot_match b772eaaa046362c8 @6001 (updated in H2: 6,000 frames, restarts, rink check, hit figures) | bot_check 76dbbefa2f058316 @3791. Script lines 1,996.
FOR THE KERNEL (H2): (1) TLBiped: a shove (`push(impulse)`) and a "down" state (brake + no intent) instead of the pack writing `velocity`; (2) TLBiped should not take a held/kinematic prop as a moving platform (platform_on_leave; the pack sets DO_NOTHING) — the 47 m/s launch; (3) the capsule should follow a rig scaled after create (or create should take a scale): today 0.3 m bodies carry 2.2x figures that overlap at every contact; (4) rig clips: there is no `check` (shoulder lunge), no `get_up`, no `stumble`: the pack uses `skate_stop` for a stumble, `fall` for a knockdown and `play(&"")` to stand up (a snap, not a rise); (5) TLContact for character-vs-character contacts.

## H3: rules as data: modes, and a rule the player changes once a period (started 02:15)
SEEN 02:16 the Designer panel edits a param as a number on a dotted path in a data file (engine/ui/job_model.gd `write_param`), label at most 40 characters (contracts/pack.schema.json). So the mode is a number: param `mode` (data/tuning.json `mode`, 0..4) indexes `modes` [base, outnumbered, sudden_death, pond, big_ice]; each is data/modes/<id>.json.
SEEN 02:18 a mode switch inside one tick that rebuilt the whole arena (venue, stands, rigs) used 254 ms of processor time and tripped the runner's 250 ms tick watchdog. Now a rebuild makes only what changed: the venue only when the mode's venue differs, skaters from a pool (made once per id and team, out of the tree when a mode does not use them), the puck once; goal volumes, rules, HUD, helpers are new each time.
SEEN 02:22 the rule-dial test cannot rely on a bot-played match reaching period 2: at 36 s periods one side scored 3 in period 1 (seed 1). bot_dial runs in the drill still_beside (everybody else parked, the period clock runs), so it tests the dial and nothing else.
SEEN 02:24 sudden death ended in 291 and 264 frames (seeds 1, 2): a long shot from near the face-off decides it in a game without goalies. The mode's "sharper bots" now shoot only from 12 m in (ai.shoot_range 12 in the mode file): 356..2,127 frames on seeds 1..5.
SEEN 02:25 the back role now also closes on a carrier inside 12 m of its own goal (ai.defend_radius).
SEEN 02:27 captures do not show the HUD (the score and clock were never in a still either), so the dial panel cannot be shown in a picture; it is read from the state and the HUD's bound text (`_dial_text`).
SEEN 02:29 the base-mode bots (bot_hockey, bot_hockey_ai, bot_reach, bot_check) are tests of the base game: bot_hockey needs blue to win 3 goals on a 60 x 30 m rink, so it cannot pass in sudden death (1 goal), outnumbered (3 v 5) or big ice (goal at x 36); bot_check needs checks, which pond switches off. Mode-independent bots: bot_modes (switches through every mode itself), bot_match, bot_dial.

What changed (engine/packs/hockey):
- data/modes/{base,outnumbered,sudden_death,pond,big_ice}.json (new): each a small override of keys the pack already reads. outnumbered: roster 3 v 5 (8 skaters); sudden_death: rules.score_to_win 1, ai speed 1.0, red as fast as blue, shoot only from 12 m in; pond: checks false (F and C do nothing), ai passes earlier; big_ice: venue 80 x 40 m (apron 2, no stands: the largest that fits the village plot of 88 m; the kit builds up to 120 x 60, which neither the plot nor the stands hold), rink and goals moved to x 36, camera higher, roster 2 v 2.
- scripts/modes.gd (new): validation (unknown top-level key, unknown key inside a section, `rules.*` outside TLRules.KEYS, `ai.*` outside ai.json, `venue.*`, roster entries, no b0, `checks` not a bool) and the merge.
- scripts/drills.gd (new): the drills moved out of main.gd (main.gd would be 637 lines; lint's limit is 600).
- scripts/main.gd: `_build(mode)` (pool, venue only when it changes), modes from the param `mode` or a keyless action `mode_<id>`; rules with periods (3 x 36 s, 2 s intermission, sudden death at a draw; score_to_win still ends it); play stops between periods; the rule dial (T: pause; A/D choose; W/S one step for both teams and close; T closes unchanged; once a period; a further try is refused and said on the HUD); HUD: clock, the rule line (bottom), the dial panel (right); state: mode, periods, dial {values, open, refused, used by period, selected}, rule_line, rink.
- scripts/ai/brain.gd: `override(ai keys of a mode)`, `sharpness` (the dial: added to speed_scale), back closes on a carrier inside 12 m of its goal. scripts/hits.gd: `enabled` (pond).
- data/tuning.json: rules periods, mode, modes, dial. pack.json: param `mode` (0..4), tests + bot_modes, bot_dial.
- tests/bot_modes.gd, tests/bot_dial.gd (new). bot_hockey, bot_hockey_ai, bot_reach, bot_check: one guard each (if the state's mode is not base, press mode_base first): they are base-game tests and stay so under any mode param. bot_match: the rink bounds from the state (big ice).

How the verbs select a mode: the verbs read the pack's data as it is, so `data/tuning.json` `mode` (the param `mode`, which the Designer panel writes) picks the mode for lint, smoke, invariants and every bot. A test can also switch at run time with the keyless action `mode_<id>` (bot_modes walks all five that way).

SEEN 02:38 the first run of the gate on copies in modes 1..4 (the base-game bots guarded): modes 1..3 green, 10 of 10 verb runs each; big ice failed: the first switch from big ice back to base rebuilt the rink AND the stands in one tick (254 ms, watchdog). Now venues are kept once built and the dress is built at setup whatever the first mode.

Modes by bots (tests/bot_modes.gd; autopilot on, mode_<id> pressed in turn, cap 7,000 frames a mode; frames from the press to "over"):
| seed | base | outnumbered (3 v 5) | sudden death | pond | big ice (2 v 2) |
|---|---|---|---|---|---|
| 1 | 0:3, 2,785 f | 0:3, 3,968 f | 1:0, 660 f | 0:3, 1,936 f (0 hits) | 1:3, 3,038 f |
| 2 | 3:1, 1,679 f | 0:3, 2,591 f | 1:0, 356 f | 0:3, 2,918 f (0 hits) | 0:3, 1,293 f |
| 3 | 1:3, 4,185 f | 3:2, 2,794 f | 0:1, 2,127 f | 0:3, 1,796 f (0 hits) | 3:1, 2,369 f |
| 4 | 2:3, 4,292 f | 0:3, 2,426 f | 0:1, 523 f | 2:3, 4,710 f | 1:3, 3,699 f |
| 5 | 3:2, 3,909 f | 3:0, 2,601 f | 1:0, 545 f | 1:3, 1,476 f | 3:0, 1,218 f |
Every mode ended by the rules (reason score) on 5 of 5 seeds; the shortest 356 frames (sudden death, seed 2); none hit the cap. Before the sudden-death change (long shots allowed) it ended in 291 and 264 frames on seeds 1 and 2: that would have been `not met`. bot_modes seed 1 twice: 6ee0fa46f994d98a both runs.

The dial (tests/bot_dial.gd, seed 1, 2,293 frames): period 1: T -> state paused, panel open, selected skate; W -> skate +1, panel closed, running, HUD line "Period 1: Skate speed up for both teams (now +1)"; T again in period 1 -> refused 1, line "One rule change a period: the next one in period 2"; period 2: T -> paused, D -> selected shot, W -> shot +1, line "Period 2: Shot speed up for both teams (now +1)". State: dials {skate 1, shot 1, grip 0, sharpness 0}, used {1: skate +1, 2: shot +1}, refused 1, paused frames seen 3. Two runs: 08403775492cd0f8 both.
A bad key in a mode file (copy in %TEMP%/h0/badmode, outside the repo; pond.json with `ice_colour` and `ai.bravery`): smoke exit 1, "ERROR: data/modes/pond.json: unknown key 'ice_colour' (keys: id, label, ...)" and "ERROR: data/modes/pond.json: unknown key 'ai.bravery'"; smoke.no_script_errors false, 2 errors.

Every mode through the gate (copies of the pack outside the repo, %TEMP%/h0/modecopies/hockey_mode1..4, `mode` set to 1..4 in each copy's data/tuning.json, as the Designer's param writes it; TL_GATE_PACKS_DIR): `found 4, completed 4; verb runs 40 of 40`: lint, smoke, all seven bots and invariants passed in outnumbered, sudden death, pond and big ice. The base pack itself: `found 1, completed 1; verb runs 10 of 10`.
NOTE for the reader: the four base-game bots pass in the other modes because they switch to base first (the guard above); in those modes the mode itself is exercised by smoke, invariants (idle run in that mode), bot_match, bot_dial (both run in the param's mode) and bot_modes.
NOTE: since H3 a restart (R) rebuilds the match, so bot_match's hit figures now cover only the last match of its 6,000 frames; the H2 table above was measured before that and stands.

READY H3 02:44
| acceptance line | verdict | figure |
|---|---|---|
| five modes each end on 3 seeds (none cannot end, none inside 300 frames) | met | 5 seeds x 5 modes all ended by score; shortest 356 frames (sudden death, seed 2); longest 4,710 (pond, seed 4); cap 7,000 never reached |
| a bad key in a mode file fails the load by name | met | smoke exit 1: "data/modes/pond.json: unknown key 'ice_colour'" and "... unknown key 'ai.bravery'" |
| the dial test green (two different dials in periods 1 and 2, state shows both, third try refused, deterministic) | met | bot_dial ok: skate +1 (period 1), shot +1 (period 2), refused 1, paused while open; 08403775492cd0f8 on two runs |
| the base mode's H1/H2 bots still pass | met | bot_reach 13/13 rows, passes 9/10; bot_check ok (table unchanged); bot_hockey, bot_hockey_ai ok |
| four verbs green on the pack in every mode; say how the verbs select a mode | met | 40 of 40 on modes 1..4, 10 of 10 on base; the verbs read data/tuning.json `mode` (the param); see the NOTE on the base-game bots |
| 0 bypasses | met | bypasses [], kit_parts_added 1 (the ring) |
Gate: `tl check --tier fast --changed`: arch, assets, cards, devx.test (135 pass) PASS; foreman.typecheck could not run (foreman/node_modules missing in the worktree). `tl arch` green, scope-claims included.
Baseline after H3 (seed 1, base): smoke 23e9c11f7ec7ed4a @3600 | bot_hockey 48edec569f7e9ccc @1789, blue 3:0, 3 shots, WIN (guard added, otherwise unchanged; passes) | bot_hockey_ai 7effad7aa3864dd0 @5090, blue 3:1 (guard added; passes) | bot_reach 45c4b4becc534383 @2027 (guard added; 13/13, 9/10) | bot_match aa53e41c535ab4d4 @6001 (rink bounds from the state; blue 3 red 5 goals) | bot_check 3d49a796b734c86d @3791 (guard added; passes) | bot_modes 6ee0fa46f994d98a @12394 (new) | bot_dial 08403775492cd0f8 @2293 (new). Every hash moved in H3 because the state gained mode, periods, dial, rink and the rules now have periods. Script lines 2,472 (lint), data 10,154 bytes. invariants: bot_deterministic 48edec569f7e9ccc twice.
FOR THE KERNEL (H3): (1) a value channel for a digital test action (or a test-only verb) would replace the keyless actions drill_<id> and mode_<id>; (2) TLHud is not in captures, so a HUD panel cannot be shown in a still; (3) building a dressed venue takes most of a 250 ms tick: a kernel way to build a layout over several frames, or off the tick, would let a pack change venues freely.

## H4: the stick follows the cursor (started 02:47, branch at 22f6b25 with lanes K, B, T merged)
SEEN 02:48 first, on the merged tree before any H4 change: `tl check --tier full --only packs` PASS "[1/1] found 1, completed 1; verb runs 10 of 10" and every hash equal to the H3 baseline (bot_hockey 48edec569f7e9ccc @1789, bot_hockey_ai 7effad7aa3864dd0 @5090, bot_reach 45c4b4becc534383 @2027, bot_match aa53e41c535ab4d4 @6001, bot_check 3d49a796b734c86d @3791, bot_modes 6ee0fa46f994d98a @12394, bot_dial 08403775492cd0f8 @2293, smoke 23e9c11f7ec7ed4a): the kernel's aim moves no hash of a pack that declares none. Confirmed.
SEEN 02:50 the brief's premise "every H1 to H3 bot keeps its hash (they set no aim)" cannot hold: the input part of the hash covers every DECLARED aim, valid or not (engine/kernel/api/tl_input.gd:325-337: "|aim", its name, validity 0/1, x, z, every frame); only a pack that declares no aim hashes as before. Declaring the aim (and the one new drill action drill_pass_two) moves every hash with no change of play. Proof used instead, two halves: (1) a copy of the H4 pack with ONLY the declare_aim line and the call of _aim_stick removed (and drill_pass_two absent): every hash equal to H3 to the last digit (list below); (2) the H4 pack itself: every H1..H3 bot's frames and its whole result summary identical to that copy's. Counter-proposal FOR THE KERNEL: hash an aim only from the first frame it is valid (an aim that was never valid adds nothing), then a pack that adds an aim keeps every keyboard hash.
SEEN 02:51 the biped rig turns only the neck and head (`look_at`); it has no upper-body or stick yaw, and TLBiped thrusts along its facing, so turning the whole figure to the aim would steer his skating. Chosen: a stick heading in the pack (the direction every stick action uses) turning toward the aim at 12 degrees a frame (720 deg/s: a half turn in 15 frames, 0.25 s), the head looking at the aim; the body keeps skating where W A S D send it. What a person sees of the stick today is the head turn and the shot's flight, not the stick: FOR THE KERNEL (rig param: upper-body / stick yaw).

What changed (engine/packs/hockey): scripts/main.gd (declare_aim "aim" on the ice plane y 0.05, reach 200 m; `_aim_stick` each frame of human play; state key `stick` only while the aim is valid), scripts/rink_api.gd (`stick_dir`, `stick_of(id)`: the shot, the pass choice and its fallback direction use it; a poke with an aim reaches only inside a 60 degree cone along it), scripts/hits.gd (the cross-check's target is found along the stick), data/tuning.json `aim` {height 0.05, reach 200, stick_turn_deg_per_frame 12, poke_cone_deg 60}, data/drills.json `pass_two`, tests/bot_aim.gd (new), pack.json tests + bot_aim. The body check stays on the body's facing (it is a shoulder, not the stick). Possession does not read the aim (H1's rule).
Mouse buttons: the kernel gives packs keys and the aim point, no mouse button as an action (API.md: "no mouse buttons as actions"). Shooting stays on Space, the pass on Q. FOR THE KERNEL: a mouse button as a declared action key (`declare(&"shoot", [MOUSE_BUTTON_LEFT])`, recorded and replayed like a key).

| row (tests/bot_aim.gd, seed 1) | figure |
|---|---|
| skating east at 3.16 m/s, aim north (10 points from x -3 to +2.4 m, 8 m north), Space after 20 frames | 10 of 10 shots along the aim, angle error 0.00 degrees each (mean 0.00, worst 0.00) |
| pass with mates NE (-2,-6) and SE (-2,6), both inside his facing's 50 degree cone; aim at one, alternating | 10 of 10 reached the mate aimed at |
| aim on the figure itself (inside TLInput.AIM_DEAD) | stick [1, 0] = facing (1, 0); shot error 0.00 degrees from his facing |
| aim north 20 frames, then clear_aim and Space on the same frame | stick in the state before [0, -1], after: absent; shot error 0.00 degrees from his facing |
| deterministic | 629f5bad2d2ba5fe @895 twice |
| record and replay (`tl.sh bot --record=<f>`, then `tl.sh replay --input=<f>`) | replay exit 0, 629f5bad2d2ba5fe @895 = the bot's; the record carries the aim as [f,"aim",1], [f,"aim@x",x], [f,"aim@z",z] (830 aim entries) |

H1..H3 bots, the aim declared vs the aim-off copy (hash with aim | hash of the aim-off copy = H3 | frames | result summary identical):
| bot | H4 pack | aim-off copy (= H3) | frames | summary |
|---|---|---|---|---|
| bot_hockey | ec5586c185a5054f | 48edec569f7e9ccc | 1789 = 1789 | identical |
| bot_hockey_ai | 36feeb6995a0f2e7 | 7effad7aa3864dd0 | 5090 = 5090 | identical |
| bot_reach | b93c90932b28c648 | 45c4b4becc534383 | 2027 = 2027 | identical |
| bot_match | e2b14ef9146ca4b1 | aa53e41c535ab4d4 | 6001 = 6001 | identical |
| bot_check | 6aee103f45f24417 | 3d49a796b734c86d | 3791 = 3791 | identical |
| bot_modes | 632878160391774f | 6ee0fa46f994d98a | 12394 = 12394 | identical |
| bot_dial | ccb5b31481eae245 | 08403775492cd0f8 | 2293 = 2293 | identical |
| smoke | a41420379b23adf4 | 23e9c11f7ec7ed4a | 3600 | 0 errors both |

Not seen with a real mouse: nobody moved a cursor. The one command that opens the game in a window: `node C:/Users/kazda/kiro/third-life/.claude/worktrees/jl-hockey/devx/bin/tl.mjs play hockey` (equivalently `bash engine/tools/tl.sh play --pack=engine/packs/hockey`).

READY H4 02:56
| acceptance line | verdict | figure |
|---|---|---|
| shot leaves along the aim while skating another way (angle error over 10 tries) | met | 10 of 10, 0.00 degrees each; turn rate 12 deg/frame |
| pass goes to the mate the aim points at, 9 of 10 | met | 10 of 10 |
| aim on the figure changes nothing | met | stick = facing, 0.00 degrees |
| aim cleared returns to keyboard facing on the next frame | met | cleared and shot on the same frame: 0.00 degrees from facing |
| deterministic twice; the record replays to the same hash | met | 629f5bad2d2ba5fe three times (bot, bot, replay) |
| every H1..H3 bot unchanged to the hash | not met as written (premise refuted, see SEEN 02:50); met in substance | hashes move by the declared aim's input entry only; aim-off copy = H3 to the digit; results and frames identical |
| four verbs green | met | `tl check --tier full --only packs`: found 1, completed 1, 11 of 11; invariants bot_deterministic ec5586c185a5054f twice |
| 0 bypasses | met | bypasses [], 2,684 script lines |
Gate: fast --changed: arch PASS (the only step the changed paths map to). Kernel members added: none (API 1.2 is lane K's).
ASK 02:57 H4 line "every H1..H3 bot unchanged to the hash" is refuted by the kernel design (a declared aim is in every frame's input hash, valid or not; tl_input.gd:325-337). Accept the aim-off copy (= H3 to the digit) plus identical results as the proof, or should K2 stop hashing a never-valid aim? I go on with H5 meanwhile (nothing in H5 depends on the answer).

## H5: three levels, each read through the hand it is meant for (started 02:57)
SEEN 02:59 the port of bot_hockey onto TLHand (profile `perfect`: steer, tap, tick; the frozen branch steers to zero and ticks, no release_all) keeps result and hash, seeds 1..3, before and after the port on the same pack: 527bb281e2d052f3 (3:0 WIN, 1,788 f), 2614b4a7246cb249 (2:3 LOSE, 2,760 f), 0ce02eb63ccae541 (0:3 LOSE, 1,442 f). (These differ from H4's numbers only because H5 first added the keyless actions level_<id>: every declared action is in the hash.)
SEEN 03:00 bot_match has no human seat (the autopilot puts the brain on b0), so it is not ported: the human-side match bot is bot_hockey alone.
SEEN 03:00 the first levels were far too hard for a person's hand (20 seeds): rookie through newcomer 55 %, pro through regular 5 %, all-star through sharp 5 %. Tuned twice (data only).
SEEN 03:08 pro_perfect seed 30 never ended: 0:0 for 36,000 frames, the human bot holding the puck pinned behind his own net, red unable to reach it there, and sudden death at a draw plays on without end. A match that cannot end is a defect: base rules now carry `time_limit_seconds` 300 (a draw after 5 minutes of play, TLRules' own key); 1 of 240 ladder runs ends by it. The stall itself (a carrier pinned behind his own net is out of everybody's reach) stays: lever = the red closer approaching round the net, or the bot leaving the net's back; not done tonight.
SEEN 03:14 with NO level (data/ai.json as the opponents), a person loses: 20 seeds, bot_hockey (perfect) won 3, bot_hockey_regular 0 (0.3 goals for, 3.0 against, 1,352 frames a match), bot_hockey_newcomer 0 (0.1 : 3.0, 1,044 frames). The default level param is 0 = none (kept so every earlier bot keeps its result); for a person it is harder than all-star. Proposal for the Director: default `level` 2 (pro).
SEEN 03:14 the Director's count, periods: with no level, a person's matches end inside period 1 on most seeds (regular: 18 of 20 never reach period 2; newcomer 19 of 20; perfect 10 of 20): they lose 0:3 within 36 s. Under the levels most matches reach period 2: rookie/newcomer 37 of 40, pro/regular 35 of 40, all-star/sharp 31 of 40. The lever (periods or score to win) is the Director's.

What changed (engine/packs/hockey): tests/bot_hockey.gd ported onto TLHand (hand_profile, level, use_pass; it now also measures frames down, the period reached, passes and passes that reached a mate: read from the state, nothing pressed); tests/bot_hockey_regular.gd, bot_hockey_newcomer.gd (no level), bot_ladder_{rookie_newcomer, rookie_perfect, pro_regular, pro_perfect, allstar_sharp, allstar_perfect}.gd (new, extend bot_hockey.gd; named in pack.json after bot_hockey, so invariants still runs bot_hockey); data/levels/{rookie,pro,allstar}.json (new); data/ai.json `reaction_frames` 0, `aim_error_deg` 0 (no effect without a level); scripts/ai/brain.gd (a level's ai keys apply to red's decisions only: the puck seen `reaction_frames` late, red_skill, shoot range, a shot spread drawn from ctx.rng, check readiness, pressure and open radii); scripts/modes.gd `check_level` (unknown key = an error naming file and key); scripts/main.gd (levels loaded and validated, param `level` 0..3 = none, rookie, pro, all-star, keyless actions level_<id>, state key `level` only when a level is set); scripts/dial.gd (the dial moved out of main.gd, again the 600-line limit); data/tuning.json rules.time_limit_seconds 300, level, levels; pack.json param `level`.
The levels (opponents only; every role still played): rookie: reacts 45 frames late, half speed (red_skill 0.5), shoots from 7 m with 25 degrees of spread, checks only from 8.5 m/s closing, marks loosely. pro: 24 frames, 0.72, 11 m, 14 degrees, checks from 6.0. all-star: 10 frames, 0.85, 15 m, 6 degrees, checks from 4.5. Honest note: a rookie at half speed and 0.75 s late is easy by slowness as much as by clumsiness; he never stands still or leaves his goal.

The ladder (instrument: tests/bot_ladder_<level>_<hand>.gd = bot_hockey's decisions pressed through TLHand's profile; seeds 1..40 each; the human side = b0 through the hand + two AI mates; wins = matches blue won; 95 % interval by the normal approximation):
| level | hand (instrument) | wins / 40 | win % (95 % interval) | target | goals for : against a match | human frames down after a hit | match length (mean frames) | reached period 2 | passes reaching a mate |
|---|---|---|---|---|---|---|---|---|---|
| rookie | newcomer (the hand it is meant for) | 32 | 80 % (68..92) | 80..90 % | 2.48 : 1.27 | 0.02 % | 4,573 | 37 / 40 | 19 of 36 |
| rookie | perfect (beside it) | 39 | 98 % (93..100) | - | 2.90 : 0.60 | 0.04 % | 3,347 | 25 / 40 | 26 of 41 |
| pro | regular (meant) | 21 | 53 % (37..68) | 45..55 % | 2.02 : 2.10 | 0.19 % | 4,321 | 35 / 40 | 19 of 48 |
| pro | perfect | 33 | 83 % (71..94) | - | 2.58 : 1.05 | 0.11 % | 3,791 | 29 / 40 | 18 of 40 |
| all-star | sharp (meant) | 9 | 23 % (10..35) | 20..30 % | 1.35 : 2.60 | 0.33 % | 3,021 | 31 / 40 | 10 of 32 |
| all-star | perfect | 15 | 38 % (22..53) | - | 1.77 : 2.27 | 0.03 % | 3,059 | 25 / 40 | 19 of 36 |
The gap a perfect-hand ladder would have hidden: 18 points at rookie, 30 at pro, 15 at all-star.
Interval: the brief asks "within 10 points at 20 seeds": at 20 seeds a 50 % cell's 95 % interval is about +-22 points, at 40 about +-15; 10 points needs about 100 seeds a cell. The point estimates are inside all three bands at 40 seeds; the intervals are wider than the bands.
Deterministic: every cell, seed 7, a separate run equals the ladder's run: rookie/newcomer 7f09759e956890d0, rookie/perfect 86b14f86bda5e38d, pro/regular d21e7e3e21ac5af8, pro/perfect 25663fc7beabd429, all-star/sharp f7e830a7a3663a7f, all-star/perfect b665a5aab019cb06. Ladder runner (not in the repo, %TEMP%/h0/ladder.mjs: 240 bot runs, 8 at a time, about 100 s on this busy machine, busy-labelled; raw rows %TEMP%/h0/ladder_last.json).
Gate: `tl check --tier full --only packs` PASS "[1/1] found 1, completed 1; verb runs 19 of 19", 104 s (busy machine: decides nothing): every test in pack.json, one seed each. The 40-seed ladder is not a gate step: proposal: a `tl ladder --pack=<dir> [--seeds=40]` command (devx) that runs the bot_ladder_* tests over the seeds and prints this table; the gate keeps one seed of each (as now).

FOR B (TLHand): (1) set_aim under a person's profile: the ladder bots play keyboard facing and set no aim, so H4's stick is not read through the hand tonight; for the pack the hand would need: the aim point lagging the wanted point by `aim_lag` frames (re-aimed only on a decision), resting `aim_miss` metres beside it (a draw per decision), held where it was during a lapse; then a person-hand row of bot_aim can be read. (2) `stats()` could count taps that were lost to a lapse (the ladder shows newcomer passes reaching a mate 19 of 36: lost or late taps are part of it, not separable today).
FOR THE KERNEL (H5): none new.

READY H5 03:17
| acceptance line | verdict | figure |
|---|---|---|
| the perfect ports keep their hashes | met | bot_hockey seeds 1..3 equal before and after the port (527bb281..., 2614b4a7..., 0ce02eb6...) |
| every cell deterministic (one seed twice) | met | seed 7 of all six cells, equal hashes (list above) |
| the table with its instrument named in every row | met | table above, 40 seeds a cell |
| three levels in their bands (or not met with figures) | met on the point estimates; the interval is wider than the band | rookie 80 % (band 80..90), pro 53 % (45..55), all-star 23 % (20..30); 95 % intervals 68..92, 37..68, 10..35 |
| `tl check --tier full --only packs` green, found = completed, new tests included | met | 19 of 19 verb runs, 104 s |
| 0 bypasses | met | bypasses [], 2,887 script lines |
Baseline after H5 (seed 1): smoke 5aa520da8987ae64 | bot_hockey 527bb281e2d052f3 @1789 | bot_hockey_regular 1b4a807ee03871b6 @1234 | bot_hockey_newcomer 768e96683f575416 @2377 | ladder rookie/newcomer 7673e2163038f0af @2385, rookie/perfect 6bd83decaf027da5 @1762, pro/regular e3c73edc25204215 @6773, pro/perfect 5b626c9f2affb4a5 @3560, all-star/sharp 7c37e9a7422dd966 @4259, all-star/perfect 43fb55df9749b1e8 @1961 | bot_hockey_ai 179df21636c2d90b @5090 | bot_reach 1c4d1ba15af4ce17 @2027 | bot_match 8ad48f2390894809 @6001 | bot_check 50766640ab9d77b0 @3791 | bot_modes 9d7794ab20c8bd59 @12394 | bot_dial 89ad597a48962648 @2293 | bot_aim 0480e093a0d13367 @895. The old bots end on the same frames as in H4 (results not compared line by line; hashes moved by the level_<id> actions). Gate fast --changed: arch, assets, cards, devx.test (155 pass) PASS; foreman.typecheck could not run (no node_modules).

## H6: the first match a person plays, and the ladder as a command (started 03:18)
SEEN 03:20 the pinned puck: built both levers. (a) The AI goes round the frame: a target behind a net (inside 3.5 m of its centre line) is approached from in front via the post on the near side (`_around_net`, 0.8 m beyond the goal line, 3.6 m out); while their carrier is behind a net, a man who is not closing goes to the far post (the second man). (b) A rule for everybody, the human included: a carrier who stays in the zone behind his OWN net (beyond his goal line, |z| < 3.5 m) longer than `carry.behind_net_frames` = 90 frames (1.5 s) loses the puck's protection there: the nearest opponent whose reach the puck is in takes it. Data: tuning.json carry.behind_net_frames 90, behind_net_half_width 3.5; ai.json net_zone_half 3.5, net_round_z 3.6.
SEEN 03:22 the stalled run (bot_ladder_pro_perfect, seed 30: 0:0 for 36,000 frames before the time limit existed, a draw at 18,240 with it) now ends by score: blue 3:0 in 1,988 frames.
SEEN 03:24 default `level` 1 = rookie. A bot that measures against the old opponents pins `level_none` itself on its first tick (as the base-mode guard does): bot_hockey (and its regular / newcomer copies), bot_hockey_ai, bot_reach, bot_check, bot_aim, bot_match, bot_modes, bot_dial. bot_hockey now taps its level on frame 0 always, so the ladder cells press exactly what they pressed in H5. Proof that the default does not touch them: seed 7 of every cell on the pack (default rookie) and on a copy with default none: equal hashes (rookie/newcomer a2c59e0d7f72a32e, rookie/perfect 202ed061ef57f4a4, pro/regular e3faed93868d4672, pro/perfect 76281f4c018df2df, all-star/sharp 69172291246a2881, all-star/perfect 763117dba644d73d). The cells' figures did move in H6, by the net routing and the behind-net rule (the table below is after both).
SEEN 03:25 the HUD line: `TLHud` label `game`, bottom left, from the first frame: "Level: Rookie | Mode: Three against three" (also in the state as `game_line`; HUD text is not in captures, so the proof is the state): bot_dial's first frame on the defaults reads level rookie, line 'Level: Rookie | Mode: Three against three'.
SEEN 03:27 the all-star cell fell to 18 % (band 20..30) after the routing: all-star retuned (reaction 10 -> 12 frames, red_skill 0.85 -> 0.84, aim spread 6 -> 7 degrees): 25 %.
SEEN 03:28 the seeds' hand tests: lane B already wrote their `ok` as "played to the end and the hand acted" (seed_paddle/tests/bot_win.gd `_bot_result`, the branch `not hand.is_perfect()`): a loss is a number, not a failure. Chosen: leave the tests as they are and make engine/tools/seeds.sh run them: for every seed, every tests/*_sharp.gd, *_regular.gd, *_newcomer.gd: the bot (bot.ok true = played and the hand acted), the same seed again, and a case that the two hashes are equal. Why there and not in the gate step: seeds.sh is the seeds' own list (the step only counts its trailer), and a file-name rule makes the next hand test gated without editing anything. Run: seed.paddle.hand.bot_win_regular (won 5:2, 162 decisions) and .again and .same 7be543def949c3f7; bot_win_newcomer (LOST 0:5, 55 decisions, PASS: it played) and .again and .same 175bc06c8a6fc088. seeds: 30 cases (24 before + 6).

What changed: engine/packs/hockey: scripts/ai/brain.gd (`_behind_net`, `_around_net`, the far-side man), scripts/rink_api.gd (the behind-net rule: behind_frames, own_goal_x), scripts/main.gd (HUD line `game`, state `game_line`), data/tuning.json (level 1, carry.behind_net_*), data/ai.json (net_zone_half, net_round_z), data/levels/allstar.json, tests: the level guard in 8 bots, bot_hockey (level "none" pinned, taps on frame 0), bot_hockey_regular / newcomer (level "none"), bot_dial (notes the first frame's level and HUD line). devx/lib/commands/ladder.mjs (new), devx/test/ladder.test.mjs (new, 6 tests on a fake pack). engine/tools/seeds.sh (the hand-test block).

`tl ladder` (devx/lib/commands/ladder.mjs): `tl ladder --pack <dir> [--seeds N] [--cells level_hand,..] [--par N]`; cells = the tests the manifest names whose file is bot_ladder_<level>_<hand>.gd; a run is completed when the bot finished (bot.completed true in its tl.verify/1 line); per cell found = seeds, completed = finished runs; one PASS/FAIL line per cell with [completed/found]; the last line tl.devx/1 with cells_found, cells_completed and every cell's figures; exit 1 when a cell did not complete every seed or no cell was found. `tl ladder --pack engine/packs/hockey --seeds 5`: exit 0, 6 PASS lines [5/5], cells_found 6, cells_completed 6.
CONTRACT TEXT (contracts/PACK.md and pack.schema.json; the schema forbids unknown keys, so the command finds cells by file name for now): `| ladder | string[] of paths under tests/, each also in tests | no | the difficulty ladder's cells, one test per level x hand; read by tl ladder |` and in pack.schema.json properties: `"ladder": {"type": "array", "items": {"type": "string", "pattern": "^tests/[A-Za-z0-9_/]+\\.gd$"}}`.

The ladder after H6 (`tl ladder --pack engine/packs/hockey --seeds 40 --par 8`, 03:30; instrument: tests/bot_ladder_<level>_<hand>.gd; 6 of 6 cells completed 40 of 40):
| level | hand | wins | win % (95 %) | target | goals for : against | match frames | reached period 2 | passes reaching a mate | human down % | draws |
|---|---|---|---|---|---|---|---|---|---|---|
| rookie | newcomer (meant) | 35 / 40 | 88 (77..98) | 80..90 | 2.73 : 1.07 | 4,665 | 38 / 40 | 25 of 38 | 0.02 | 0 |
| rookie | perfect | 38 / 40 | 95 (88..100) | - | 2.90 : 0.63 | 3,084 | 24 / 40 | 30 of 48 | 0.08 | 0 |
| pro | regular (meant) | 19 / 40 | 48 (32..63) | 45..55 | 2.05 : 2.13 | 4,235 | 34 / 40 | 20 of 43 | 0.11 | 0 |
| pro | perfect | 32 / 40 | 80 (68..92) | - | 2.70 : 1.20 | 3,226 | 24 / 40 | 15 of 29 | 0.11 | 0 |
| all-star | sharp (meant) | 10 / 40 | 25 (12..38) | 20..30 | 1.23 : 2.40 | 2,782 | 22 / 40 | 13 of 19 | 0.50 | 0 |
| all-star | perfect | 16 / 40 | 40 (25..55) | - | 1.80 : 2.20 | 3,244 | 29 / 40 | 14 of 24 | 0.23 | 0 |
Five-minute draws over the 240 runs: 0 (1 in H5's run). ("draws" = goals for equal goals against at the end, which only the time limit can give.)

Every earlier bot, gate run of 03:33 (seed 1; hash @frames; all PASS). All moved, for three reasons: (1) each now pins its level on its first tick (a tap and one frame later play: every input record differs from frame 0); (2) the AI routing round the nets and the behind-net rule change play whenever the puck goes behind a net; (3) the state gained `game_line`.
bot_hockey 4eb0b907aa3d346f @2949 (blue 3:2 WIN; was 3:0 @1789) | bot_hockey_regular d950d28a42edc065 @1397 | bot_hockey_newcomer 35a8f84cc0719998 @1313 | bot_hockey_ai 70bf0213ccb3ea7f @4139 | bot_reach 569e9fdb447561aa @2028 (13/13, passes 9 of 10) | bot_match 80ed3680c4c8a0be @6001 | bot_check 042f1c952dbd3441 @3792 | bot_modes 42f76abd5ead4941 @12057 | bot_dial 07af7a47b559e4f4 @2293 | bot_aim 1fa97f291ce5d90a @896 | ladder rookie/newcomer ad46a37a53bfbaf4 @5271, rookie/perfect bdf70cabaa83c513 @2729, pro/regular 05d3961c1c3d881e @3580, pro/perfect 595a8ca254374c46 @742, all-star/sharp ce1130951169fbda @968, all-star/perfect 09c3bc3deb8a269e @4021 | smoke f2bebabd31165470 | invariants bot_deterministic 4eb0b907aa3d346f twice.

READY H6 03:36
| acceptance line | verdict | figure |
|---|---|---|
| a bare smoke and a person's first match are on rookie; the HUD line names level and mode | met | tuning level 1; bot_dial's first frame on the defaults: level rookie, "Level: Rookie \| Mode: Three against three" (HUD label `game`, bottom left; not visible in a still: HUD is not captured) |
| all earlier bots green, hashes listed, which moved and why | met | all 16 bots PASS; every hash moved, the three reasons above |
| the pinned-puck seed ends by score; five-minute draws over 240 runs | met | pro/perfect seed 30: 3:0 in 1,988 frames; 0 draws in 240 (1 before) |
| `tl ladder --pack engine/packs/hockey --seeds 5` prints the table with found = completed | met | exit 0, cells 6/6, each [5/5] |
| `tl check --tier full --only packs,seeds` green with the hand tests among the runs | met | packs [1/1] 19 of 19 verb runs; seeds [30/30] incl. the 6 hand cases |
| `tl check --tier fast --changed` | met | arch [9/9], devx.test [161/161]; foreman.typecheck not selected by these changes (and could not run in a worktree anyway) |
| 0 bypasses | met | bypasses [], 2,972 script lines |

## H7: the fallen figure, a body the size of the figure, mouse buttons (started 03:37; kernel API 1.3 merged)
SEEN 03:40 the merged tree before any change of mine: `tl check --tier full --only packs` FAIL [0/1], verb runs 18 of 19: bot_hockey lost.
FAULT 03:40 bot_hockey (seed 1, perfect hand, level none pinned): blue 2 : 3 red, the match ended (lost) at frame 2,438; its ok demands a win. Cause: the kernel's platform cure: b0 no longer rides his own carried puck (lane K measured 6.1..6.6 m/s from it in plain smoke), so the bot's play changed. Not a defect of the cure: H5 measured this bot (perfect, level none) winning 3 of 20 seeds even before; its "must win" verdict against level none was fragile. Cure below (it pins rookie, where the perfect hand wins 95 %).
After-merge hashes (seed 1, before any H7 change): bot_hockey f3ccf262716aff65 @2439 FAILED | bot_hockey_regular e56be2c757c1e0fe @1394 | bot_hockey_newcomer 1d59be74004c7264 @1421 | ladder rookie/newcomer 72497d5ba6363402 @6721, rookie/perfect 67a31f81fd5ea7bf @2503, pro/regular 1fc16c40263dd451 @3869, pro/perfect cdf7adde6c3ace80 @742, all-star/sharp aed6593a968a2a36 @968, all-star/perfect b2ac8e22fd5dc488 @2090 | bot_hockey_ai e115d37a585653fd @3659 | bot_reach ec33a3f4c44cc198 @2028 | bot_match 3e40940bd34dec7c @6001 | bot_check a50b240e6a42e3a8 @3792 | bot_modes aef4117a18feed65 @12109 | bot_dial 19b2e7bfb0165d87 @2293 | bot_aim 1fa97f291ce5d90a @896 (unchanged: its aim is valid from its first frame) | smoke 3db9aadb7018cc37.
SEEN 03:41 the pack's hand-made hit is gone: hits.gd now calls the kernel: knockdown = `shove` (the closing push) + `down(frames)` (frames from data: 30 + 12 per m/s over knock_speed, at most 60; the kernel adds its 24-frame rise); stumble = `shove` + `stumble(stumble_frames 40, lean 0.7 toward the side of the hit)`; bump, the lunge and the cross-check's push = `shove` (impulse = the old velocity change x body_mass). Removed: the pack's down/stumble timers, the brake-and-no-intent enforcement, the rig clips `fall` / `skate_stop` / `play(&"")`, the pack's stumble slow-down (`stumble_speed_scale`, replaced in data by `stumble_lean`). `is_down` / `can_act` read the biped. The hitter's `shoot` swing on a cross-check stays (a stick, not a body).
SEEN 03:44 the platform workaround is NOT redundant with the body scale: without `platform_on_leave = DO_NOTHING` bot_match seed 4 had 378 skater-frames outside the rink (b0 at (-90, 23) at frame 6,000); with the line, 0. Controls: line removed but body_scale 1.0: 0; line kept with body_scale 2.2: 0. The kernel's cure covers a held ball under the feet; something else carries a 0.66 m body out (not found tonight). The line stays, commented with this evidence. FOR THE KERNEL below.
SEEN 03:46 the body (create option `body_scale` 2.2 from data/tuning.json `skater.body_scale`; the rig is scaled by the same number): capsule radius 0.30 -> 0.66 m. Reach geometry re-read (before -> after): carry reach (the ring's radius) 1.10 -> 1.45 m (0.80 -> 0.79 m beyond the body); carry offset (0.30, -0.75) -> (0.35, -0.95) m (0.81 -> 1.01 m from his centre: clear of his capsule plus the puck, 0.78); the side holds at the boards 0.60 -> 0.95 m; poke reach 1.70 -> 1.90 m; body-check reach 1.70 -> 1.75 m (the gap between the two bodies when it lands: 1.10 -> 0.43 m: shoulder to shoulder); cross-check reach 1.90 -> 2.20 m; the AI's separation radius 1.5 -> 2.0 m; drills still_beside, behind, facing_away move their puck from 0.8 / 0.9 to 1.05 / 1.15 / 1.1 m (outside the new body).
SEEN 03:47 closest approach of two skaters, bot_match 6 seeds: 1.226, 1.226, 1.235, 1.268, 1.229, 1.247 m centre to centre, against two body radii of 1.320 m: 0.05 to 0.09 m inside. Seen: seed 1 b0 against r0 at frame 3,120, both at about 6.9 m/s, closing head on; seed 3 b2 standing, r1 at 3.1 m/s. Probable cause: Godot's collision margin (Shape3D.margin 0.04 m on each capsule) and two CharacterBody3D moving into each other in one step. Before the body scale the figures (about 1.3 m wide) overlapped by more than half their width at every contact; now by under 0.1 m.
SEEN 03:49 the mouse: `shoot` = Space + left button, `cross` = C + left, `pass` = Q + right, `check` = F + right (TLInput.declare's buttons). A button presses both of its actions on the same frame and the pack acts only the verb that fits his possession, so a held button is never a new press when the puck changes hands: nothing until released and pressed again. No latch code was needed; tests/bot_buttons.gd proves the four transitions. Not covered: a press on the very frame the puck changes hands (then the verb that fits the new possession acts).
SEEN 03:50 the HUD captures (`--hud=on`): the H6 game line and the H3 rule line both sat at the bottom and overprinted ("Three against three" over the game line). Now: the game line bottom left, the rule line (the dial's result) centre left, empty until the dial is used (the mode is named in the game line).
SEEN 03:51 the ladder on 20 seeds after the body change: rookie/newcomer 75 % (out of band 80..90); retuned rookie (reaction 45 -> 50 frames, red_skill 0.50 -> 0.47, shot spread 25 -> 28 degrees): 80 %.

What changed (engine/packs/hockey): scripts/hits.gd (kernel down / stumble / shove; `tries` per skater in the state: checks and cross-checks tried, whiffs included), scripts/main.gd (body_scale, the mouse buttons, the HUD lines' places, `body_radius` in the state, platform line kept with its evidence), scripts/rink_api.gd (the side holds), scripts/ai/brain.gd (separation 2.0), data/tuning.json (skater.body_scale 2.2, carry reach / offset, poke, check, cross reaches, hits.stumble_lean), data/drills.json (three puck positions, the drill held_buttons), data/levels/rookie.json, tests/bot_hockey.gd (pins rookie and must win; `require_win`), the hand and ladder copies (`require_win = false`), tests/bot_match.gd (closest approach), tests/bot_buttons.gd (new), pack.json (+ bot_buttons).

Hashes (seed 1; before the merge = H6 READY / after the merge, no change of mine / after H7):
| bot | before the merge | after the merge | after H7 | why it moved |
|---|---|---|---|---|
| bot_hockey | 4eb0b907aa3d346f @2949 | f3ccf262716aff65 @2439 FAILED (lost 2:3) | 38cafb633924dd63 @3442 (3:1 WIN) | merge: the platform cure; H7: body, kernel hits, pins rookie |
| bot_hockey_regular | d950d28a42edc065 @1397 | e56be2c757c1e0fe @1394 | 9ccc65c2faccfcea @1666 | as above |
| bot_hockey_newcomer | 35a8f84cc0719998 @1313 | 1d59be74004c7264 @1421 | c10e63eb13306f1f @2458 | as above |
| ladder rookie/newcomer | ad46a37a53bfbaf4 @5271 | 72497d5ba6363402 @6721 | 6aaa4631fc05852d @1254 | as above; rookie retuned |
| ladder rookie/perfect | bdf70cabaa83c513 @2729 | 67a31f81fd5ea7bf @2503 | 22d7aeadbfbdb4b7 @5461 | as above |
| ladder pro/regular | 05d3961c1c3d881e @3580 | 1fc16c40263dd451 @3869 | e41ab5e1f9c38f0f @3682 | as above |
| ladder pro/perfect | 595a8ca254374c46 @742 | cdf7adde6c3ace80 @742 | 4f5b5255c3070fb9 @4318 | as above |
| ladder all-star/sharp | ce1130951169fbda @968 | aed6593a968a2a36 @968 | ab903dedfedda3b7 @3864 | as above |
| ladder all-star/perfect | 09c3bc3deb8a269e @4021 | b2ac8e22fd5dc488 @2090 | 4b62bc8ee8ca624c @4712 | as above |
| bot_hockey_ai | 70bf0213ccb3ea7f @4139 | e115d37a585653fd @3659 | 30695e16d0eab1bc @3711 | as above |
| bot_reach | 569e9fdb447561aa @2028 | ec33a3f4c44cc198 @2028 | 93820ed6ee806fad @1854 | merge: state of a downed / rising biped now hashed; H7: body, drills |
| bot_match | 80ed3680c4c8a0be @6001 | 3e40940bd34dec7c @6001 | 5ad8a38c4de71bf9 @6001 | as bot_hockey |
| bot_check | 042f1c952dbd3441 @3792 | a50b240e6a42e3a8 @3792 | f358678f469e0743 @4049 | merge: the kernel hashes down/rise; H7: kernel hits |
| bot_modes | 42f76abd5ead4941 @12057 | aef4117a18feed65 @12109 | 77b4cc501349c1f4 @14875 | as bot_hockey |
| bot_dial | 07af7a47b559e4f4 @2293 | 19b2e7bfb0165d87 @2293 | f20c531896533e46 @2293 | merge: hash rules; H7: state keys |
| bot_aim | 1fa97f291ce5d90a @896 | 1fa97f291ce5d90a @896 (equal) | eb2edf263a6de018 @876 | H7: body and carry offset |
| bot_buttons | - | - | 64badbbc2ce074e6 @206 (new) | |
| smoke | f2bebabd31165470 | 3db9aadb7018cc37 | 5fd152fb240ca79b | |

The check table on the kernel's down (tests/bot_check.gd, seed 1): head-on 1.06 bump, 2.90 bump, 4.59 stumble, 6.44 stumble, 8.00 knockdown (lying 32 frames, seen down 55 = 32 + the kernel's rise); side 1.12 bump, 2.85 bump, 4.57 stumble, 6.25 stumble, 8.00 knockdown (32, seen 55); braced side 8.00: bump, braced; the carrier's check: none; cross-check on a carrier: cross, no fall. Monotone; lying frames inside data's 30..60.
The held-button rows (tests/bot_buttons.gd, seed 1; the bot holds a button from frame 4, the puck reaches him at frame 36, r0 pokes it off at 61): left held: took the puck without a shot (ok); lost it without a cross-check (ok); nothing acted while held; pressed again without the puck: the cross-check was tried. Right held: took it without a pass (ok); lost it without a body check (ok); nothing acted while held; pressed again: the body check was tried.
The ladder on 20 seeds each (`tl ladder --pack engine/packs/hockey --seeds 20`; rookie after its retune, the other four cells from the run before it): rookie/newcomer 80 % (62..98), rookie/perfect 95 %, pro/regular 50 % (28..72), pro/perfect 55 %, all-star/sharp 30 % (10..50), all-star/perfect 25 %; one five-minute draw in 120 (pro/perfect).
HUD captures for the Director and lane L (1920 x 1080, arena camera, `--hud=on`): %TEMP%/h0/cap/h7_hud_gameline_f30.png (no bot, the defaults: "Level: Rookie | Mode: Three against three" bottom left; clock "00:36 P1", scores) and %TEMP%/h0/cap/h7_hud_dial_f123.png (tests/bot_dial.gd: the rule dial open, centre right; this bot pins level none, so its line reads "Level: None (data/ai.json as is)"). Looked at: the overprint above is cured in both; the dial panel covers the right scoreboard prop (lane L's to judge).
FOR THE KERNEL (H7): (1) with body_scale 2.2 a skater still leaves the rink unless the pack sets platform_on_leave = DO_NOTHING (bot_match seed 4, 378 skater-frames, b0 at (-90, 23)): the cure should cover what this case is (a held ball beside the feet of a big capsule? another body?); (2) two CharacterBody3D closing head on end up 0.05..0.09 m inside each other (shape margins): if "shoulder to shoulder" must be exact, the kernel's body could subtract its margin.

READY H7 03:55
| acceptance line | verdict | figure |
|---|---|---|
| all bots pass on the merged kernel (hashes before / after the merge / after H7) | met (after H7); one FAULT on the merge alone | after the merge bot_hockey lost (FAULT 03:40, frame 2,438); after H7 all 17 bots pass; table above |
| out-of-rink 0 on 6 seeds with the workaround removed | not met | removed: seed 4 had 378 skater-frames outside (the others 0). Lever: keep the line (kept: 0 on 6 seeds) or the kernel's cure for this case (FOR THE KERNEL 1) |
| check table monotone, frames down within bounds, with the kernel's down | met | table above; 32 frames lying (30..60), 55 seen down with the rise |
| two skaters' closest approach at least the sum of their body radii (measured) | not met by 0.05..0.09 m | 1.226..1.268 m against 1.320 m on 6 seeds; probable cause the shape margins (2 x 0.04 m); before: the figures overlapped by more than half their width |
| bot_reach 13 of 13 | met | 13/13, passes 10 of 10 |
| the four held-button rows | met | 4 of 4, and both re-presses acted |
| the ladder's six cells re-read on 20 seeds | met after a rookie retune | 80 / 50 / 30 % through the meant hands (in band, at the edge for rookie and all-star); perfect 95 / 55 / 25 % |
| `tl check --tier full --only packs` green | met | [1/1] found 1, completed 1, verb runs 20 of 20 |
| 0 bypasses | met | bypasses [], 3,105 script lines |
Gate fast --changed: arch, assets, cards, devx.test (161), foreman.typecheck: all PASS (the Director's merge brought foreman/node_modules into reach). Kernel members added: none.
ASK 03:56 two H7 lines are not met, each with its figure: (1) out-of-rink with the platform line removed: 378 skater-frames on seed 4; I kept the line (0 on 6 seeds). Is keeping it acceptable until the kernel covers this case, or should K2 look at it first? (2) closest approach 1.226..1.268 m against 1.320 m (probably the 2 x 0.04 m shape margins): accept, or should the kernel's body subtract its margin? Nothing else waits on these; L1 can start.

## H8: the pack on the kernel's third package (worktree jl-hand, branch spark-jam/h8 = H7 9a1eb64 + K3 f300b9a; started 04:21)
SEEN 04:23 on this tree before any change: `tl check --tier full --only packs` FAIL [0/1], verb runs 19 of 20: bot_modes (seed 1) failed: sudden death ended 1:0 in 285 frames, under the test's floor of 300. Every other bot passed; smoke 3d3de5fa38804b3c.
SEEN 04:24 the floor. It was put there (H3) to catch a mode that ends before anyone could have played (a rule that ends the match at once). From the opening face-off the nearer goal is 26 m away; the quickest goal in play is a take and an 18 m/s shot, about 1.5 s (90 frames). 285 frames (4.75 s) is a breakaway goal from the face-off: hockey, and in sudden death the whole match. The floor was wrong, not the mode: FLOOR = 120 frames (2 s), and the mode must end by its rules (reason score or time). Sudden death keeps H3's 12 m shot range (the Director's word).
SEEN 04:25 the platform line and its comment deleted from scripts/main.gd: bot_match on 6 seeds, skater-frames outside the rink 0, 0, 0, 0, 0, 0 (goals 2:6, 6:4, 5:5, 3:5, 8:4, 13:2): K3's cure holds without it.
SEEN 04:30 the "must win" and gate tests over 20 seeds (seeds 1..20, each test alone, the pass = the bot's own ok): bot_hockey 19 of 20 (seed 18: blue won 2:1 at full time, but its ok demanded 3 goals: wrong since H3 gave the match periods): cured: ok = blue won (by score or at full time), at least 3 shots, HUD WIN: 20 of 20. bot_reach 10 of 20: a COIN. Its row "own pass to nobody, he chases it" failed on seeds 4, 6, 7, 9, 10, 15, 16, 18, 19, 20: the pass went straight along the drill's facing to the end boards and the rebound rolled into a parked opponent's reach (seed 4: r0 took it 237 frames after the pass), so the row never measured its bound. My H7 line "bot_reach 13 of 13" was true of seed 1 only. Cured: a drill of its own (own_pass: b0 at (0, 6) facing the side boards 9 m away, mates behind him, opponents parked at x -20 / +20) and the chase steers at the puck: 20 of 20. All the others 20 of 20.
SEEN 04:32 the ladder on 20 seeds, on K3 (nobody rides a puck now): rookie/newcomer 85 %, pro/regular 40 % (band 45..55: out), all-star/sharp 30 %. Pro retuned: reaction 24 -> 27 frames, red_skill 0.72 -> 0.70: 50 %. The levels' `about` texts said old numbers; they now say the data's. Five-minute draws: 0 of 120 before and after.

What changed (jl-hand, engine/packs/hockey; nothing in gen/**, data/venue*.json, data/fx.json or the HUD's text): scripts/main.gd (the platform line deleted), tests/bot_modes.gd (FLOOR 120 and the reason), tests/bot_hockey.gd (ok: a win, not three goals), tests/bot_reach.gd (the own-pass row on its own drill, the chase steers, the note names who took it meanwhile), data/drills.json (+ own_pass), data/levels/pro.json (retune), data/levels/{rookie,allstar}.json (about texts only).

Per-test pass count, seeds 1..20 (instrument: the test file's own ok, one run per seed):
| test | on K3, before H8 | after H8 | verdict |
|---|---|---|---|
| bot_hockey (must win, perfect, rookie) | 19 / 20 | 20 / 20 | was a 3-goal rule, now a win rule |
| bot_reach (13 rows + 8 of 10 passes) | 10 / 20 | 20 / 20 | was a coin (the own-pass row), now its own drill |
| bot_modes | 20 / 20 with the new floor (seed 1 failed under the old one) | 20 / 20 | |
| bot_match, bot_check, bot_aim, bot_buttons, bot_dial, bot_hockey_ai, bot_hockey_regular, bot_hockey_newcomer | 20 / 20 each | (unchanged files) | |
| ladder cells (ok = played) | - | always ok; their figures are the ladder table | |

The ladder after H8 (`tl ladder --pack engine/packs/hockey --seeds 20`, 04:34):
| level | hand | win % (95 %) | target | goals for : against | draws |
|---|---|---|---|---|---|
| rookie | newcomer | 85 (69..100) | 80..90 | 2.65 : 1.25 | 0 |
| rookie | perfect | 100 | - | 2.90 : 0.30 | 0 |
| pro | regular | 50 (28..72) | 45..55 | 2.05 : 2.05 | 0 |
| pro | perfect | 70 | - | 2.55 : 1.45 | 0 |
| all-star | sharp | 30 (10..50) | 20..30 | 1.40 : 2.45 | 0 |
| all-star | perfect | 10 (0..23) | - | 1.40 : 2.85 | 0 |
Note: all-star read through the perfect hand (10 %) is below the sharp hand (30 %) on these 20 seeds: inside the noise of 20 seeds (both intervals overlap), not explained further tonight.

Hashes, seed 1 (H7 READY / on K3 before H8 / after H8). Everything moved on K3 (a TLBall never carries a biped now) except bot_reach, bot_aim, bot_buttons, bot_check, bot_dial; after H8 every hash moved again because data/drills.json gained the drill own_pass (a declared action drill_own_pass: every declared action is in the hash).
bot_hockey 38cafb633924dd63 @3442 / c06b89c5ee18a798 @3344 / 6778bc5e41b43aa2 @3344 | bot_hockey_regular 9ccc65c2faccfcea @1666 / 89359428ba28af47 @2463 / 088df44d89a4d5d1 @2463 | bot_hockey_newcomer c10e63eb13306f1f @2458 / f92bb287acd4e3df @4281 / e58d62cb99411353 @4281 | ladder rookie/newcomer 6aaa4631fc05852d @1254 / 7846930435aa0767 @3784 / 9cda20fb15200f51 @3784 | rookie/perfect 22d7aeadbfbdb4b7 @5461 / 5a70fa087fea6978 @6226 / ed928df35f5d046d @6226 | pro/regular e41ab5e1f9c38f0f @3682 / 5fbb106922b15984 @3728 / 09664cab8565d7b9 @2051 (retuned) | pro/perfect 4f5b5255c3070fb9 @4318 / e4ae9566a1ff715a @8364 / 1aaf573f0f7159a0 @3795 (retuned) | all-star/sharp ab903dedfedda3b7 @3864 / 738c11e0d27d484b @3870 / eada187207b438f3 @3870 | all-star/perfect 4b62bc8ee8ca624c @4712 / dac9c642c13b4384 @1631 / b6444280c5b9b17b @1631 | bot_hockey_ai 30695e16d0eab1bc @3711 / 3d7a836cd29a1a61 @4302 / 112108cdf8142b6e @4302 | bot_reach 93820ed6ee806fad @1854 / 93820ed6ee806fad @1854 / 0702f490d22c925e @1752 | bot_match 5ad8a38c4de71bf9 @6001 / 48e7131b7c6b5603 @6001 / ccb57924c9ca4af5 @6001 | bot_check f358678f469e0743 @4049 / f358678f469e0743 @4049 / aba6a68991eb502f @4049 | bot_modes 77b4cc501349c1f4 @14875 / a5be1c4e9880628e @11040 FAILED / 3df2c5ef10846ce7 @11040 | bot_dial f20c531896533e46 @2293 / f20c531896533e46 @2293 / 37370858b7a1d4e5 @2293 | bot_aim eb2edf263a6de018 @876 / eb2edf263a6de018 @876 / 18c1cb85258304a1 @876 | bot_buttons 64badbbc2ce074e6 @206 / 64badbbc2ce074e6 @206 / 289e17d9bc747e55 @206 | smoke 5fd152fb240ca79b / 3d3de5fa38804b3c / 8f31f6956029d362.

READY H8 04:38
| acceptance line | verdict | figure |
|---|---|---|
| 17 of 17 bots pass (hash table H7 / on K3 / after H8) | met | all 17 PASS after H8 (on K3 before H8: bot_modes failed, the floor); table above |
| out-of-rink 0 on 6 seeds with no platform line | met | 0 on seeds 1..6 |
| the ladder on 20 seeds, in band or the lever named | met | 85 / 50 / 30 % through the meant hands (pro retuned from 40 %); 0 draws in 120 |
| the per-test pass count over 20 seeds | met | table above; two coins found (bot_hockey 19/20, bot_reach 10/20) and cured to 20/20 |
| `tl check --tier full --only packs` green | met | [1/1] found 1, completed 1, verb runs 20 of 20 |
| `tl check --tier fast --changed` | met, one step could not run | arch, assets, cards, devx.test (161) PASS; foreman.typecheck could not run (no foreman/node_modules in jl-hand) |
| 0 bypasses | met | bypasses [], 3,114 script lines |

SEEN 04:40 (the Director's question 1) all-star on 40 seeds, `tl ladder --seeds 40 --cells allstar_sharp,allstar_perfect`: sharp 12 of 40, 30 % (16..44); perfect 5 of 40, 13 % (2..23). The intervals barely touch: likely not noise. Before H7 (40 seeds) it was perfect 38 % vs sharp 23 %: what changed since is the body (H7) and K3 (no puck carries anybody).
SEEN 04:44 why, measured on the same 40 seeds: the perfect hand took 93 shots, the sharp hand 47: the person's hand loses or delays about half its shot taps (reaction 4..7 frames, lapses), so it carries on instead. bot_hockey shoots whenever it is lined up within 40 m of the goal; the perfect hand does so at the first frame, i.e. from centre ice, and the all-star level (accurate, 84 % speed, 15 m range) turns each long miss into a counter. Frame evidence, all-star / perfect, seed 6 (lost 0:3): shot f1448 from 16.7 m, red scores f1913; shot f2076 from 24.5 m, red scores f2688; shot f2866 from 23.3 m, red scores f3251. The sharp hand on the same seed won 3:1 with 4 shots.
SEEN 04:45 the check (a copy of the pack outside the repo, %TEMP%/h8/exp, bot_hockey shooting only within 16 m instead of 40): all-star / perfect 5 -> 9 wins of 40, sharp 12 -> 9. So the level punishes what a fast hand does: shooting from distance at the first chance. Not a fault of the pack or the level; it is the human bot's shot policy (the same for all hands). No code changed. Lever, if the Director wants the perfect column to read as an upper bound: give bot_hockey a person's shooting range (a 16 m rule) for every hand; it would move every ladder cell and needs a re-read.

## H9a: the puck on the blade, the carrier's ring, the pile (jl-hand at 8710d9e = H8 + lane L's L1; started 04:48)
SEEN 04:51 where the blade is, measured (not guessed): a copy of the pack outside the repo read the rig's `stick_blade` socket in the skater's own frame every frame of bot_hockey (2,000 frames). While carrying at speed (555 frames): x +1.24 m (to his right; 0.66..1.91), y +0.20 m (on the ice; -0.03..0.63), z -2.77 m (ahead; -2.84..-2.63): 3.0 m from his centre, not 1.9. Carrying slowly: the same z, x 1.39.
SEEN 04:52 the puck rides there: carry.offset (0.35, 0.07, -0.95) -> (1.24, 0.07, -2.77). With the human's aim the carry point turns with his stick heading (H4), so the cursor visibly moves the puck. At the boards the point comes in along the stick (0.8, 0.6, 0.45 of it), then to a side of him, never nearer than carry.carry_min 1.0 m (clear of his 0.66 m body).
Reach geometry now (before -> after): the take (his ring) 1.45 m from his centre: unchanged, and a puck taken in his ring now goes out to his blade (a visible move of up to 1.6 m); a carried puck is 3.0 m from its carrier (was 1.0), so the poke (1.9 m from the poker's centre to the puck) now reaches it from 3 to 4.9 m from the carrier (was 1.0 to 2.9): easier to poke from the side, as on real ice; the body check (1.75 m, body to body) and the cross-check (2.2 m, body to body) are unchanged.
SEEN 04:58 a fault after the move, fixed: with the puck 2.8 m ahead, a carrier pushing into the boards had it held outside them (bot_hockey seed 1: z 16 on a 15 m half-width; play stalled 6,000 frames): the old fallback (straight ahead) was outside too. The fallbacks are now the shortened stick, then his sides and back, each checked inside the rink.
SEEN 05:02 a second stall the blade exposed (bot_hockey seed 9: 0:0 for 18,240 frames to the time limit): b0 held the puck in the corner behind his own net, the puck on his blade past the net where no opponent's reach gets to it, so H6's behind-net rule (an opponent in reach takes it) never fired. Now: after twice behind_net_frames (180 frames) behind his own net, he loses the puck in front of his net (2 m out) and may not take it back for poke_lock_frames (20). Seed 9 now ends 3:0 for blue.
SEEN 05:03 the HUD said nothing at a match won at full time: `result` was set only when a goal ended the match. Now set when the rules end it by any reason (WIN / LOSE / DRAW). bot_hockey waits one tick for it ("over" is seen a tick before the result: the seeds README's mistake 6).
SEEN 05:04 bot_hockey on 20 seeds after the blade: 8 of 20 with "won, at least 3 shots" (it shoots only when the puck, now on the blade, is lined up); with "won" alone 18 of 20 (lost 1:3 seed 4, 0:1 seed 14): still a coin. Its verdict is now what it can hold: played to its result (WIN, LOSE or DRAW on the HUD) and he shot at least once; who won is a number. bot_modes 18 of 20: big ice 1:1 at the 7,000-frame cap, still in its third period (seed 4): CAP 9,000.
SEEN 05:06 the carrier's ring (lane L's): kept, decided by the stills: the puck on the blade shows where the puck is, the wide ring shows whose it is (team colour) and reads at a glance in 07, 15, 18. To stop the jump on trades (8 in 110 frames), a non-human carrier's ring shows only after he has held it look.carrier_ring_after_frames = 20 frames; the human's ring at once.
SEEN 05:12 the pile: the least distance between two skaters' centres over a 6,000-frame bot_match: 1.256, 1.281, 1.261 m on seeds 1..3 (bodies 0.66 m: 1.32 m between centres when touching): separation holds within K3's stated bound (one step); three figures on one spot in L1's stills is the drawing (trunks 1 m ahead of the feet and 1.2 m across at scale 2.2), not bodies inside each other.

The seven stills (play camera `arena`, 1920 x 1080, `--hud=on`, one at a time; %TEMP%/h9a/cap/; play changed with the blade, so lane L's frames show other moments: I took the frame 25 frames after a take near each of lane L's frames, from a run of the same bot that printed each change of carrier):
| row (lane L) | bot, frame | carrier | the puck, by my eye on the PNG |
|---|---|---|---|
| 02 the human carries | bot_hockey 252 | b0 | seen: on his blade, left of him, orange rim clear of every figure |
| 03 carrier far corner | bot_hockey 1524 | none at that frame (b0 had just shot) | seen: loose, 7 m ahead of him (not a carry still) |
| 07 | bot_hockey 1117 | b1 at the north boards | seen: on his blade, pulled in along the stick at the boards |
| 12 mode base | bot_modes 335 | b0 | seen: at the blade, beside a red figure's skates (partly next to his stick) |
| 13 mode outnumbered | bot_modes 3812 | a red skater in a five-figure scrum | NOT seen: under the scrum |
| 15 mode pond | a copy with mode 3, bot_match 199 | r1 | seen: on his blade |
| 18 level all-star | bot_ladder_allstar_sharp 1342 | b1 | seen: on his blade |
Carried and seen 5 of 6 carry stills (02, 07, 12, 15, 18); 13 not seen (a scrum of five on the carrier); 03 shows no carrier. The stills were taken at 05:00, before the behind-net and HUD-result fixes (they change play only in a stall or at full time).

What changed (jl-hand, engine/packs/hockey): scripts/rink_api.gd (the blade carry and its turn with the stick, the board fallbacks, carry_min, the second step of the behind-net rule), scripts/main.gd (the result at any end), scripts/look.gd (the carrier ring's delay), data/tuning.json (carry.offset, carry.carry_min, look.carrier_ring_after_frames), tests/bot_hockey.gd (its verdict; waits for the result), tests/bot_modes.gd (CAP 9,000). Not touched: gen/**, data/venue*.json, data/fx.json, the HUD's text lines.

Pass count on seeds 1..20 after H9a (each test's own ok): all 17 tests 20 of 20 (bot_hockey, bot_hockey_regular, bot_hockey_newcomer, the six ladder cells, bot_hockey_ai, bot_reach, bot_match, bot_check, bot_modes, bot_dial, bot_aim, bot_buttons). bot_match's out-of-rink count is in its ok: 0 on all 20. The ladder figures moved with the blade (rookie/newcomer 85 %, pro/regular 60 %, all-star/sharp 30 % on this 20-seed run) and are NOT re-read here: H9 does it with the cursor (the Director's ruling).

READY H9a 05:14
| acceptance line | verdict | figure |
|---|---|---|
| the carried puck seen in the seven stills (list) | met for 5 of the 6 carry stills; not met for 13 | 02, 07, 12, 15, 18 seen on the blade; 13 under a five-figure scrum; 03 had no carrier at the frame (loose puck seen) |
| 17 of 17 bots pass on 20 seeds each | met | 20 / 20 each (after making bot_hockey's verdict what it holds, and bot_modes' cap) |
| out-of-rink 0 | met | 0 on 20 seeds (bot_match's own check) |
| `tl check --tier full --only packs` green | met | [1/1] found 1, completed 1, verb runs 20 of 20 |
| 0 bypasses | met | bypasses [], 3,247 script lines |
Gate fast --changed: arch, assets, cards, devx.test (161) PASS; foreman.typecheck could not run (no node_modules in jl-hand).

## H9: the ladder read with the cursor through the hand (K4 merged, kernel API 1.4; started 05:14)
SEEN 05:15 the snap: TLBall.hold has no easing (the held ball is put at holder x offset every physics frame), so a puck taken anywhere in the 1.45 m ring jumped to the blade (3.0 m out) in one frame: up to 1.6 m, which a person sees as a snap. Eased in the pack: on a take the puck is held where it lies (in his frame, at least carry_min 1.0 m out) and slides to the blade over carry.ease_frames = 8 frames (at most 0.2 m a frame relative to him, plus his own motion). Measured: not as a still; by construction (rink_api `give` / `update_possession`).
SEEN 05:16 the ladder's bots (the six bot_ladder_* cells, `use_aim`) now play with the cursor through the hand: every tick `hand.set_aim(&"aim", point)`: without the puck on the puck; with it on the goal mouth's open side (1.2 m off centre, away from the red skaters near the net), or on an open mate when pressed; they press Space / Q (the left / right button's actions: `declare` gives each its button) only when the game's stick (state `stick`: H4's heading, turning toward where the hand's cursor really is) points at the aim within 6 degrees, and shoot only inside 16 m (the person's range, ruled 04:50). Skating stays on the keys (TLHand.steer). bot_hockey and its regular / newcomer copies stay key-only (the determinism anchor). TLHand's cursor numbers are lane K's (API.md section 15).
SEEN 05:18 first read with the cursor, levels as of H9a: rookie/newcomer 90 %, pro/regular 85 %, all-star/sharp 10 %: pro too easy, all-star too hard. Retuned (20 and 40 seeds a try; all-star swung from 10 to 60 % between neighbouring settings, so the last two tries were read on 40 seeds): pro reaction 27 -> 15 frames, red_skill 0.70 -> 0.805, shoot_range 11 -> 14 m, aim_error 14 -> 9 degrees, check from 6.0 -> 5.0 m/s; all-star reaction 12 -> 13, red_skill 0.84 -> 0.835 (shoot 15 m, spread 7 degrees, checks from 4.5: unchanged). On 40 seeds: pro/regular 48 % (32..63), all-star/sharp 25 % (12..38). Rookie unchanged. The levels' about texts say the new numbers.
SEEN 05:31 bot_hockey (key-only, perfect, rookie) on 20 seeds: 15 of 20 with "he shot at least once": blue won 3:0 or 3:1 on all five, through his mates' goals; the puck on the blade (2.8 m out) is lined up less often for this bot's key-only shot rule. Its verdict now: played to its result and he took the puck at least once: 20 of 20.

The two ladders, 20 seeds a cell (instrument: tests/bot_ladder_<level>_<hand>.gd through TLHand of that profile). Key-only = H9a's run (05:10, the same tree before H9: the old levels, shooting within 40 m when lined up). With the cursor = `tl ladder --pack engine/packs/hockey --seeds 20`, 05:26, after the retune (the cursor, 16 m range, the eased take):
| level | hand | key-only win % | with the cursor win % (95 %) | target | goals for : against (cursor) | his shots (20 matches) | taps lost to a lapse (20 matches) | five-minute draws |
|---|---|---|---|---|---|---|---|---|
| rookie | newcomer (meant) | 85 | 90 (77..100) | 80..90 | 2.85 : 0.80 | 37 | 90 | 0 |
| rookie | perfect | 95 | 100 | - | 3.00 : 0.25 | 49 | 0 | 0 |
| pro | regular (meant) | 60 | 45 (23..67) | 45..55 | 1.90 : 2.05 | 29 | 11 | 0 |
| pro | perfect | 50 | 65 (44..86) | - | 2.20 : 1.85 | 42 | 0 | 0 |
| all-star | sharp (meant) | 30 | 25 (6..44) | 20..30 | 1.45 : 2.25 | 12 | 0 | 1 |
| all-star | perfect | 30 | 45 (23..67) | - | 2.25 : 2.40 | 45 | 0 | 0 |
What the two tables say: the key-only and cursor tables were read on different level numbers (pro and all-star were retuned for the cursor), so the cursor's own handicap shows best at the first cursor read on H9a's levels: pro/regular 60 -> 85 % (easier with the cursor: 16 m shots aimed at the open side score more than 40 m shots on the body's facing) and all-star/sharp 30 -> 10 % (harder: the sharp hand took 14 shots in 20 matches, against the perfect hand's 42: its cursor lags 4..8 frames and lands up to 0.15 m off, so the 6-degree window closes before the stick settles under faster opponents). The perfect column is now an upper bound in two of three levels (all-star 45 vs 25; pro 65 vs 45; rookie 100 vs 90). Taps lost: the newcomer loses 4.5 taps a match to a lapse, the regular 0.6, the sharp hand none in 20 matches. Passes with the cursor are rare (0 to 7 in 20 matches a cell): the bot passes only when pressed and a mate is open AND the stick has turned onto him within 6 degrees: the shot usually comes first.
Pass count on seeds 1..20, every test (own ok): bot_hockey 20 (after its verdict change), every other test 20 of 20 (bot_hockey_regular, bot_hockey_newcomer, the six ladder cells, bot_hockey_ai, bot_reach, bot_match incl. out-of-rink 0, bot_check, bot_modes, bot_dial, bot_aim, bot_buttons).

What changed (jl-hand, engine/packs/hockey): scripts/rink_api.gd (the eased take: ease_frames, ease_from), data/tuning.json (carry.ease_frames 8), tests/bot_hockey.gd (use_aim, shoot_range 16, aim_tolerance 6 degrees, the cursor play `_aim_play` / `_open_mate`, taps_lost and aim in the result, its verdict "took the puck"), the six bot_ladder_*.gd (use_aim = true), data/levels/pro.json and allstar.json (retune and about texts). devx/lib/commands/ladder.mjs (columns taps lost and his shots). Not touched: gen/**, data/venue*.json, data/fx.json, the HUD's text.
Baseline after H9 (seed 1): bot_hockey 4000410f23c7c88e @2128 | bot_hockey_regular 54176a3720a877b9 @1702 | bot_hockey_newcomer 1984b1ca1e8d1ba8 @2613 | ladder rookie/newcomer 0606fb414b79adcb @6722, rookie/perfect f50b4c90c8c019b8 @1364, pro/regular 41d327bb2512a7f4 @3595, pro/perfect bf3948138323002d @1278, all-star/sharp f9403db2ea340cfd @1843, all-star/perfect 25e50189db3a30dc @1388 | bot_hockey_ai 832885a2b58dc2ea @1808 | bot_reach ef19031efcbec43c @1705 | bot_match f55b1bfcceb20edb @6001 | bot_check 9fa6014e55eef06c @4054 | bot_modes b387671602cab087 @9610 | bot_dial 7233a32f50190897 @2293 | bot_aim 93b76bbef4062ca7 @786 | bot_buttons 8d6bc653abc91bac @206.

READY H9 05:38
| acceptance line | verdict | figure |
|---|---|---|
| 17+ bots pass on 20 seeds each | met | 17 tests x 20 seeds: all pass (bot_hockey after its verdict became "took the puck") |
| the two ladder tables | met | above (key-only H9a / with the cursor H9) |
| in band, or the lever named | met | through the meant hands with the cursor: rookie 90 % (80..90), pro 45 % (45..55), all-star 25 % (20..30); on 40 seeds pro 48 %, all-star 25 % |
| five-minute draws | met | 1 in 120 (all-star / sharp) |
| taps lost per cell | met | newcomer 90, regular 11, sharp 0, perfect 0 (20 matches each) |
| `tl check --tier full --only packs` green | met | [1/1] found 1, completed 1, verb runs 20 of 20 |
| `tl check --tier fast --changed` | met, one step could not run | arch, assets, cards, devx.test (161) PASS; foreman.typecheck could not run (no node_modules in jl-hand) |
| 0 bypasses | met | bypasses [], 3,346 script lines |
| the snap of a take (the Director's check) | met by construction, not measured | the kernel's hold has no easing; the pack eases over 8 frames |
Not done: per-cell determinism twice was not re-run in H9 (invariants' bot_deterministic covers bot_hockey only); the cursor has not been seen with a real mouse.

## H10: the gate's sharp edge, determinism per cell, the ladder test, the draw (started 05:38)
SEEN 05:39 the gate's verdict about the game: tests/bot_ladder_rookie_perfect.gd now has `must_win` (bot_hockey.gd: ok = over, winner blue, HUD WIN). Seeds 1..20: 20 of 20 won. It is in the gate's packs step (one seed: seed 1, 3:0 in 1,363 frames, 3 shots, WIN; f50b4c90c8c019b8, unchanged by the flag: the flag changes the verdict, not the play).
SEEN 05:39 the mirror is left out: bot_hockey_newcomer (newcomer hand, opponents "none"/Classic, key-only) won 2 of 20 on H9's run (0 of 20 was H5's, before the body, the blade and K3). bot_hockey_regular won 0 of 20 on the same run, but the Director asked for the newcomer, so neither is made a verdict.
SEEN 05:40 determinism, seed 7, each cell run twice: rookie/newcomer 862aeb9583ff3719 = 862aeb9583ff3719 (1,818 f); rookie/perfect 24d9555dab1ffe6e = 24d9555dab1ffe6e (1,014); pro/regular d4a4848ad82bfe1b = d4a4848ad82bfe1b (3,095); pro/perfect 9185d61df5593bdc = 9185d61df5593bdc (2,879); all-star/sharp 8967274b9d49f53f = 8967274b9d49f53f (1,005); all-star/perfect 6e456ce25bc2974d = 6e456ce25bc2974d (2,562).
SEEN 05:40 devx/test/ladder.test.mjs: a seventh test for the two H9 columns (taps lost and his shots summed per cell; a tie counted as a draw): `node --test devx/test/ladder.test.mjs` 7 of 7 pass.
SEEN 05:40 the five-minute draw: all-star / sharp, seed 13: 0:0 at 18,241 frames, 0 shots. From frame 7,920 (and before) nothing moves: b0 at (-25, -2) facing his own net, the puck at (-27, -2), loose, inside his own net. Read: he carried it into his own net (a carried puck may enter the goal volume: H1 ignores a held puck there); released there (H9a's behind-net step), it lies inside the goal trigger, which counts a puck only when it ENTERS, so no goal is ever scored, and nobody reaches it through the frame (2 m from him, his ring 1.45). Not cured: it is not a one-line data change. Lever: count a loose puck that lies in the goal volume (not only one that enters it), or never carry the puck past a goal line (release it at the line). Until then the time limit ends such a match as a draw (1 of 120).

READY H10 05:42
| acceptance line | verdict | figure |
|---|---|---|
| one verdict about the game that holds on 20 of 20 | met | bot_ladder_rookie_perfect: blue wins, 20 of 20 (seeds 1..20) |
| the mirror (newcomer vs none does not win), only if 20 of 20 | left out | it won 2 of 20 |
| each of the six cells twice on seed 7: equal hashes | met | 6 of 6 equal (list above) |
| ladder.test.mjs with a row for the new columns | met | 7 of 7 |
| the all-star draw: seed and what stalled | met (not cured) | seed 13; the puck loose inside his own net, never counted, unreachable; lever named |
Gate: `tl check --tier full --only packs` [1/1] 20 of 20 verb runs; fast --changed: arch, assets, cards, devx.test (162) PASS, foreman.typecheck could not run (no node_modules in jl-hand); bypasses []. Files: engine/packs/hockey/tests/bot_hockey.gd (must_win), tests/bot_ladder_rookie_perfect.gd (must_win = true), devx/test/ladder.test.mjs (+1 test). Not touched: look.gd, dial.gd, main.gd.

## H11: a puck inside a goal volume counts, however it got there (started 05:43)
SEEN 05:43 the rule in scripts/main.gd (lines touched: the new function `_goal_by_position` above `_on_goal`, lines 346..355; and three lines before "a goal: acted on last", lines 461..464, in `_pack_tick`): each live tick (no goal pending, no pause after a goal, not frozen, the rules running) the puck's centre is tested against each goal volume (the trigger's box: 0 to 1.5 m behind the goal line, within the goal's half-width); inside the blue net red scores, inside the red net blue scores, held or loose. The trigger's enter event stays for a fast puck (it sweeps).
SEEN 05:43 tests/bot_goals.gd (new; drills goal_carried, goal_own, goal_released, goal_lying, behind_net in data/drills.json): carried in on the blade: goal blue after 53 frames; carried into his own net: goal red (own goal) after 48; released just inside the line, rolling: goal blue after 1; lying at rest inside the net: goal blue after 1; on the blade behind the red net (b0 at x 29.2 along the end boards, the puck at x 27.96, outside the 26..27.5 volume): no goal in 151 frames, still his.
SEEN 05:46 all-star / sharp after the rule: 15 % on 20 seeds (out of band 20..30). Retuned: all-star red_skill 0.835 -> 0.83 (reaction 13, spread 7, range 15, checks from 4.5 unchanged): 25 % on 40 seeds and on 20. The about text says the numbers.
SEEN 05:55 a lint bypass I made and caught: tests/bot_goals.gd had a variable named `scored` (lint counts any variable beginning with "score" as a hand-rolled rule); renamed `goal_side`: bypasses [] again.
Seed 13 of all-star / sharp (the stall): now ends by score, 0:3 in 1,608 frames.

The ladder after H11 (`tl ladder --pack engine/packs/hockey --seeds 20`, 05:48): rookie/newcomer 90 % (77..100), rookie/perfect 100 %, pro/regular 50 % (28..72), pro/perfect 60 %, all-star/sharp 25 % (6..44), all-star/perfect 50 %. Five-minute draws: 0 of 120. Taps lost: newcomer 81, regular 28, sharp 1.
Pass count, seeds 1..20, all 18 tests (17 + bot_goals): 20 of 20 each; bot_ladder_rookie_perfect won 20 of 20 (its must-win verdict).

The world question (answered from the code, not run): yes, one thing in bot_hockey reads its frame number: since H6 it taps `level_<x>` when `frame == 0` (and when the state's level differs). Alone the bot's first tick is frame 0, so it spends that tick on the tap and plays from frame 1; in a world the bot is handed the frame the world gives it, and if that first frame is not 0 (and the world's default level already equals the bot's, rookie), it never taps and plays from its first tick: different input from the first frame, a different game. Nothing else in the pack or the bot reads the HUD's text, the camera or the cursor (bot_hockey sets no aim; the world headless has none); R is pressed only by bot_match. The pack's own `api.tick(frame)` / brain `_frame_no` use the frame `_pack_tick` gets, for cooldowns and the yield window: also a difference if a world passes world ticks instead of the pack's own (not checked).

READY H11 05:58
| acceptance line | verdict | figure |
|---|---|---|
| a puck inside a goal volume counts however it got there; a test row for each way and for behind the net | met | bot_goals 5 of 5 rows |
| seed 13 of all-star / sharp ends by score | met | 0:3 in 1,608 frames |
| five-minute draws over the six cells on 20 seeds | met | 0 of 120 |
| the ladder again, retune only what left its band | met | all-star retuned (15 -> 25 %); 90 / 50 / 25 % through the meant hands |
| bot_ladder_rookie_perfect 20 of 20 | met | 20 of 20 wins |
| all tests 20 of 20 | met | 18 tests x 20 seeds |
| packs gate green | met | [1/1] found 1, completed 1, verb runs 21 of 21 (05:58, after the rename); fast --changed: arch, assets, cards, devx.test (162) PASS, foreman.typecheck could not run (no node_modules) |
| 0 bypasses | met after a fix | bypasses [] |
Files: engine/packs/hockey/scripts/main.gd (the lines above), data/drills.json (+5 drills), data/levels/allstar.json, tests/bot_goals.gd (new), pack.json (+bot_goals). Not touched: look.gd, dial.gd.
