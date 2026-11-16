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
