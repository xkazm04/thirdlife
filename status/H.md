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
