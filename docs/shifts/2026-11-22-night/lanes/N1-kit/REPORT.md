# N1 feel-kit: report (night of 22 Nov 2026)

Lane N1, Opus director + GPT 6.2 Astra builder. Worktree .claude/worktrees/n22-kit (branch n22-kit), base main c7dad86.
Nothing committed (the Director lands). Astra tokens: R1 127,486 (reaction clips) + R2 152,170 (labs, selftests, clip,
stills) = 279,656 of the ~0.8 M budget.

The owner's complaint: "Arena mutual reaction on attacks and collision is almost non-existing". The kernel now gives:
hit-stop that freezes BOTH bodies, one call per contact of DUEL-PLAYBOOK 6.3 that changes BOTH fighters, five reaction
clips on the rig, an opt-in pushbox, a play-camera occluder fade, and TLBall.set_radius. API names were final and sent to
the Director at about 19:50 (target 23:30); a second message at about 20:05 named one behaviour change (bash at a wall
slams the defender onto it) and the pushbox radius advice.

## The API (KERNEL_API 1.13 in this tree; the Director settles the minor at merge)
- TLHit.impact(attacker, victim, frames) -> int; TLHit.STOP_CAP = 20; TLHit.stop_left(who)
- TLHit.hit(attacker, victim, heavy := false, counter := false, tune := {})
- TLHit.blocked(attacker, defender, heavy := false, tune := {})
- TLHit.parried(attacker, defender, heavy := false, tune := {})
- TLHit.clash(a, b, a_heavy := false, b_heavy := false, tune := {})
- TLHit.guard_break(attacker, defender, tune := {}); TLHit.WALL_REACH = 1.2
- TLHit.wall_splat(victim, wall_normal, attacker := null, frames := 60, tune := {})
  Each returns {contact, stop, attacker, attacker_frames, defender, defender_frames}. tune: stop, frames,
  attacker_frames, push, recoil (an unknown key is an error).
- TLHit.stun_of(who) -> StringName, TLHit.stun_left(who), TLHit.busy_left(who), TLHit.clear(who)
- TLHit.pushbox(who, on := true, radius := -1.0), TLHit.pushbox_gap(who) -> float
- ctx.cameras.fade_occluders(on := true, opts := {}) (view, subjects, alpha, frames, max_size), ctx.cameras.faded()
- TLBall.set_radius(r)
- Documented in engine/kernel/API.md section 6 "K8 feel kit (addition in 1.13)" plus a row in section 5 (ball) and in
  section 12 (cameras). The numbers are the playbook's 6.3 table.

How hit-stop meets falls arm A (TLHit.react / TLHit.down), made explicit in API.md and in tl_hit.gd's header:
- During a hit-stop the body does not move and its rig does not tick, so the pose holds. Its down, stumble and stun
  counters hold. move, brake and jump are ignored. Velocity is kept and resumes afterwards.
- Calls made in one frame stack. If impact comes first, a react or down in the same frame plays its flinch or fall
  when the freeze ends.
- TLHit.down ends a stun and its push-back, because a knockdown wins. A hit-stop that is still running keeps running.
- A pack holds its own counters while TLHit.stop_left(b) > 0.

## Acceptance
1. Feel lab, every 6.3 contact between two figures, a bot that asserts both fighters' states change: MET.
   - engine/kernel/examples/ex_feel_lab and its bot tests/bot_contacts.gd. The lab plays 13 contacts in 12 cases:
     light hit, heavy hit, heavy counter-hit, light and heavy blocked, light and heavy parried, light-light clash,
     heavy-heavy clash, heavy against light, open bash, bash with a wall 1 m behind, and a heavy hit that knocks the
     victim into a wall.
   - The bot checks, per contact:
     - both fighters have hit-stop at the call frame and one frame later;
     - each side has exactly the stun name and frames of the table;
     - busy_left reaches stop plus stun;
     - the smallest centre distance is at least the pushbox radii (0.6400 m);
     - the splat frames are right.
   - Measured (attacker / defender):
     | contact | hit-stop | attacker | defender | travel A / D |
     |---|---|---|---|---|
     | light hit | 5 | freeze | hitstun 18 | 0 / 0.25 m |
     | heavy hit | 9 | freeze | hitstun 40 | 0 / 0.60 m |
     | counter | 11 | freeze | hitstun 50 | |
     | light blocked | 3 | 0.15 m recoil | blockstun 14 | 0.15 / 0.35 m |
     | heavy blocked | 6 | recoil 40 | blockstun 18 | 0.30 / 0.50 m |
     | light parried | 10 | parried 52 | recover 8 | |
     | heavy parried | 10 | parried 36 | recover 8 | |
     | light-light clash | 8 | rebound 20 | rebound 20 | 0.3 m each |
     | heavy-heavy clash | 8 | rebound 30 | rebound 30 | |
     | heavy against light | 9 | freeze | hitstun 40 | |
     | open bash | 6 | freeze | guardbroken 30 | 1.00 m |
     | bash at a wall | 12 | freeze | wallsplat 60 | slammed 0.69 m onto the wall |
     | knocked into a wall | 9, then 8 at the wall | | wallsplat 40 when the push meets the wall | 0.0011 m from it |
   - Selftest block 712: feel.lab_lint, _smoke, _bot, _invariants, 4/4 PASS in my own rerun.
   - The 15 s clip is docs/.../N1-kit/feel_lab.mp4: 1080p60, rendered in a window with the movie writer
     (.tl/r2/film.sh), 9 takes. I reviewed a 28-frame contact sheet of it. Both fighters react at every contact. In
     the heavy block the chop holds against the guard, then both recoil. In a parry the red figure's arm flies wide.
     A clash throws both back. The bash drives the defender a metre. At the wall he is slammed back-flat and sags.
2. Pushbox lab, minimum centre distance: MET. engine/kernel/examples/ex_pushbox_lab, block 713, 4/4 PASS.
   - Pair B (pushbox on), charging at a run: minimum 0.6400 m, the same as the radii sum of 0.6400.
   - Pair A (off): 0.5466 m against a capsule sum of 0.60, the old one-step overlap of 1.0.
   - Pair C: a stunned body is walked 4.48 m by the free one, so a stunned body does not push back.
3. Occluder lab, stills before and after: MET. engine/kernel/examples/ex_occluder_lab, block 714, 4/4 PASS.
   - Stills: occluder_before.jpg (the walker is hidden behind the pillar) and occluder_after.jpg (the walker reads
     through it).
   - The bot counts blockers and the pillar's transparency:
     - behind the pillar, fade off: 0 blockers, transparency 0.00;
     - behind the pillar, fade on: 1 blocker, 0.70;
     - clear of the pillar: 0 blockers, 0.00.
   - The pillar loses its ink outline while it is faded and keeps its ground shadow. I looked at both stills.
4. No existing pack's hash moves: MET, measured as an A/B against base c7dad86. The base was extracted read-only with git
   archive to .tl/base and run through the same gate steps.
   - world 8/8 = alone, with all 8 hashes identical to base:
     - seed.drive a2940a1735bc2b72@3441
     - seed.wall 5896844ee2a7bb24@1221
     - seed.paddle dff1a390470352e7@4486
     - example.walker f1c7b53757c34040@371
     - example.kit ca698e71d34d1021@332
     - example.car 3a459d0fe25e7853@1872
     - hockey 83bcd2ed6136227d@2450
     - parkour f7abac006a45bd43@988
   - packs: 74 verb runs. All 72 that carry a state hash are identical to base; the other 2 are lint runs with no hash.
     The lists are in .tl/base-pack-hashes.txt and .tl/mine-pack-hashes.txt, and diff finds no difference.
   - The packs step still FAILED on one check, hockey invariants.many_budget (frame p50 1.001 ms against a 1.0 ms
     budget). That is a wall-clock check on a BUSY machine: the gate measured use at 91 %, and base c7dad86 fails the
     same check under the same load at 1.060 ms. Determinism and bot_deterministic pass in both. This needs a quiet
     machine to settle.
5. Kernel selftest blocks touched: green.
   - Blocks 711 (rig.react 2/2), 712 (4/4), 713 (4/4), 714 (4/4) and 715 (feel.ball_radius 1/1) PASS.
   - Older blocks PASS: rig.fight 4/4 (golden 222 runs, no older clip changed), falls. 6/6, k2. 11/11.
   - Astra's run saw k2.down_invariants fail the same p50 budget under load. Mine passed at the start of the night.
   - The gate's kernel.selftest was killed at its 1800 s cap with 81 of 82 units done and 0 failed. A stopped run is
     not a pass, so I ran the whole suite again with no cap (bash engine/tools/selftest.sh): 429 passed, 0 failed,
     exit 0, at 22:29. k2.down_invariants passed in that run. For comparison, main's last full run (21 Nov day final)
     had 408 cases; this lane adds 15.
6. API.md K8 section: MET (section 6, "K8 feel kit (addition in 1.13)").
7. The Director was messaged the moment the names were final: MET, at about 19:50, well before 23:30.

## Gates (n22-kit, run by me)
- fast tier, PASS 5/5: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck.
- full tier, BUSY machine at 91 %:
  - PASS: arch, assets, cards, devx 229/229, foreman.typecheck, foreman.test 261/261, kit.selftest 120/120,
    seeds 39/39, item.selftest 91/91, ui.selftest 201/201, world 8/8.
  - FAIL packs 73/74: hockey many_budget, wall clock; base fails the same check; hashes identical.
  - FAIL kernel.selftest: killed at the 1800 s cap with 81/82 units and 0 failed.
  - NOT RUN perf: the machine was busy.
- Whole kernel selftest, run without the cap: 429 passed, 0 failed, exit 0 (.tl/selftest-full.log).

## Changed files
- Kernel:
  - engine/kernel/api/tl_hit.gd: the K8 functions. It grew from 114 to 417 lines.
  - engine/kernel/api/tl_biped.gd: +5 lines, now 567 (under the 600 cap). `_feel` is a lazy state object, stepped
    first in _physics_process, and its text goes into `_down_text` only while something runs.
  - engine/kernel/api/tl_ball.gd: set_radius.
  - engine/kernel/api/tl_cameras.gd: fade_occluders and faded.
  - New, internal: engine/kernel/feel/hit_state.gd, pushbox.gd, occluder_fade.gd, ball_radius_case.gd.
  - engine/kernel/runner/manifest.gd: KERNEL_API "1.13".
- Rig, written by Astra R1:
  - new engine/rigs/biped/reaction_poses.gd with the clips block_stun (holds the guard), recoil, parried, guard_broken
    and wall_splat, each sized by _size_hit to the stun;
  - authored_hits.gd: install and route;
  - tl_rig_node.gd: an optional per-clip max_blend; only these clips set it;
  - engine/rigs/RIGS.md: a "Reaction clips" table, plus the regenerated clip list;
  - review/reaction_case.gd;
  - review/fight_golden.txt: 30 lines appended, no older line changed.
- Docs:
  - engine/kernel/API.md;
  - generated: docs/generated/API-INDEX.md, API-V1.json and REPORTS.md (by `tl arch --index`; the Director
    regenerates them on main anyway).
- Examples and tests:
  - examples ex_feel_lab, ex_pushbox_lab, ex_occluder_lab;
  - selftest blocks 711-715.
- Lane folder: react_poses.jpg, occluder_before.jpg, occluder_after.jpg, feel_lab.mp4 (15 s).

## Behaviour changes
- None for any pack that does not call the new functions; this is shown by the hashes above.
- Rig: five more clips in clips(). The rig's metrics are unchanged. The golden poses of every older clip are unchanged.

## What the owner should look at, and how
- docs/shifts/2026-11-22-night/lanes/N1-kit/feel_lab.mp4 (15 s): every contact makes both figures react.
- occluder_before.jpg and occluder_after.jpg.
- react_poses.jpg.
- To watch the lab live: `node devx/bin/tl.mjs play` cannot pick a kernel example, so use the film script
  `bash .tl/r2/film.sh` in this worktree.
  QUESTION for the Director: should the feel lab be reachable with `tl play`?

## Known limits and gaps
- Pushbox radius. The default is the capsule + 0.02 = 0.32 m. The big-headed figures still overlap heads and arms
  when they lean into a strike at ~0.92 m between centres (the contact sheet shows it). A duel should try
  TLHit.pushbox(b, true, 0.45). I said this to the Director for N2.
- Occluder fade:
  - It fades whole kit parts through GeometryInstance3D.transparency, so the faded part loses its ink outline. It
    keeps its shadow.
  - Props that a tl.layout merged into its Static mesh cannot fade one by one. They exceed max_size and never fade.
    A pillar meant to fade is TLKit.build or TLBodies.make.
  - In a world of several packs, the draw layer's copies do not fade yet.
- Skating checks: hit and guard_break stop the victim dead (horizontal velocity zeroed). A hockey body check that
  should carry momentum uses impact + react/down + shove, or tune.push. I said this to the Director for N3.
- Wall-splat detection treats any StaticBody3D in the way as a wall: a crate that is a RigidBody3D does not splat; a
  static fence does.

## Questions for the Director
1. KERNEL_API 1.13 is taken in this tree. If another lane bumps it tonight, renumber at merge.
2. engine/kernel/feel/ is a new internal kernel folder (no class_name; packs reach it only through TLHit and TLCameras).
   Is that the right place, or should it sit under kernel/api?
3. The kernel selftest wall cap (1800 s) cannot hold the suite on a busy machine (81/82 units by the cap). Raise it, or
   run it per block on busy nights?

## Next three things this lane would do
1. Play the feel lab by hand in a window with a person's input: a small "duel tofu" with light, heavy, block, parry
   and bash on keys. Then tune the hit-stop shake (3.5 cm now) and the push distances by eye.
2. Fade by dither in the style shader instead of transparency, so that a faded pillar keeps its ink. This needs a style
   column.
3. Give the pushbox a per-pack default radius from the rig's shoulder width, and add an optional "both rebound" counter
   for a counter-bash within 8 f (playbook 6.3).

# The 09:00 loop (N1 engine needs, 01:00-07:45)

The owner extended the shift: the duel and hockey become the reference games, and what they needed from the engine
becomes kernel API. N1 turned their ENGINE-NEEDS rows into kernel API, one landable round at a time. Every round was
checked by a hash A/B: main at the round's base and n22-kit went through the same `packs` and `world` gate steps (base
extracted read-only with git archive), and every hashed verb run and the world table had to be identical.

## Round 1 (landed de6581e / c1cca38, KERNEL_API 1.14): E1 clip timing, E2 swing weight
- E1 `TLBiped.play_clip(clip, timing, blend)` ([frame, clip frame] knots; hit-stop holds the timeline; a kernel reaction
  ends it), `set_clip_speed(speed)`, `clip_now()`, `clip_frame()`; kernel/feel/clip_clock.gd; block 716 clock.* 4/4.
  The duel adopted it in its round 4 (shim deleted; 27 bot hashes identical before and after, N2's figures).
- E2 `strike` / `strike_heavy` re-posed by Astra R3 with timings unchanged: the heavy coils overhead on a loaded rear
  knee and folds 40 degrees into a long low lunge with the hands stalled near the knee; the light stays compact. Golden:
  old lines kept, new lines appended under a dated comment, the reader skips '#'. Evidence swing_weight.jpg / .mp4.
- A/B against 90ce6a4: world 8/8 identical, packs 117 hashed verb runs identical.

## Round 2 (landed 96ac91b / 8741c9a, KERNEL_API 1.15): E2b swing trail, E3 HUD colour, E4 HUD tag
- `TLHit.swing_trail(who, weight, frames, opts)` (on TLHit: tl_biped.gd sits at its 600 cap): the weapon's arc by weight
  (0.12-0.36 m wide, 5-12 frames long), freed by the kernel after `frames` unfrozen frames.
- `TLHud.set_color(id, Color or palette key)`, `TLHud.add_tag(id, node, text, offset)` (a label over a 3D node in the
  active camera), `TLHud.remove_widget(id)`. Lab ex_swing_lab, blocks 717 swing.* 4/4 and 718 hud.* 12/12.
- Evidence swing_trail_tag.jpg. A/B against 8042875: world 8/8 identical, packs 125 hashed verb runs identical.

## Round 3 (KERNEL_API 1.16): H1 a ball no contact can launch (hockey's row)
- `TLBall.set_max_gain(per_frame, floor_speed := 0.0)`, `TLBall.set_velocity(v)`; shoot, shoot_at, release and place
  declare their velocity. Off by default. Block 719 ball.gain_* 4/4: a 60 kg block slid at 24 m/s into a resting puck
  sends it off at 28.8 m/s without the limit, at 14 / 18 / 22 m/s with set_max_gain(4, 10).

## Every round's packs step failed one check, on main too
hockey invariants.many_budget (a wall-clock p50 budget of 1.0 ms) failed on both trees at 1.26-1.45 ms on this loaded
machine; it is not evidence either way (COMMON.md) and needs a quiet-machine run.

## Bug found (devx, not N1's column)
devx/test/check.test.mjs, the tests at line 148 ("hook: install/remove round-trip in a temp repo") and line 166 ("hook
script blocks a push"), call `git init` in a temp dir without checking it succeeded. When it fails (it did in Astra's
sandbox), devx/lib/commands/hook.mjs `hookPath()` asks `git rev-parse --git-path hooks` from that dir, git resolves an
enclosing or ambient repository, and the test installs and removes the pre-push hook of the REAL checkout
(C:/Users/kazda/kiro/third-life/.git/hooks/pre-push was rewritten once at 02:32; its content equals the managed hook,
`tl hook status` says installed). Fix: assert the init status, and run git with GIT_CEILING_DIRECTORIES set to the temp
dir's parent (and GIT_DIR unset) in both tests.

## Hockey rows left for the verdict (outside N1's claim, wider kernel surfaces)
- TLTrigger `entry_side` (goals only through the mouth); TLContext.history(frames) (bot perception lag);
  ctx.own_tick (a deterministic sub-rate equal alone and in a world). N3 has local shims for each.

## Round 3 LANDED (6c30148 / 69d0513, index 514f33d, KERNEL_API 1.16)
A/B against 2b9f404: world 8/8 identical, packs 126 hashed verb runs identical (hockey many_budget p50 FAIL on both,
busy). feel.pushbox_invariants failed once on its p50 budget (1.148 ms, busy); its determinism passed.

## E6: a game in a world does not always play as it does alone (Director's priority, 04:05). NOT FIXED: diagnosis
- Repro: N3's snapshot tree C:/Users/kazda/kiro/third-life/.claude/worktrees/n22-hockey/.tl/w_r2a, compared with
  N3's .tl/wcmp.sh (world.sh run --packs=hockey --mode=bot --frames=N against tl.sh bot --frames=N). In my runs frames
  up to 2049 hash the same, 2050 differs (bisect over 2030..2450; N3 saw 2016 on its run). Equal at 2016/2017/2018/2030,
  three times; the same at --space=own and --space=shared for 2016.
- Ruled out: law tables (the world's adopt() and the worker's node_added both call TLLaws.apply on the same bodies),
  gravity and damping of the pack space (pack.gd sets the four World3D parameters), the set of bodies (identical: 105
  colliders in both spaces at frame 3), the origin (0,0,0), frame counters.
- What differs: the ORDER of the bodies inside the physics space. A whole-space intersect_shape at frame 3 (probe in my
  copy of the tree, .tl/wr2a, and the two lists .tl/dbg_world.txt / .tl/dbg_alone.txt) returns the same 105 colliders
  in a different order: the sign_e1 bodies and the three goal_red/Frame bodies move. Jolt's broadphase tree and body
  ids are built in a different order in the world, because there every body is first created in the viewport's default
  space (on entering the tree) and then moved into the pack's own space by `body_set_space` in
  engine/kernel/world/pack.gd `adopt()` (called from world.gd `_on_node_added`), while alone it is created once in the
  default space. Contact pairs are then found and solved in another order, and a skater touching several boards/net
  shapes at once (skaters[4] behind red's goal line, against goal_red/Frame) rounds differently by ~1e-3 m. Hashes stay
  equal as long as no such multi-contact happens, which is why the landed hockey passes world 8/8 and an AI change can
  re-roll it.
- Fix direction (not built tonight): give the pack's bodies ONE insertion path in both runners. Either (a) the lone
  runner also creates its own space and moves every body into it through the same adopt() (cheapest, moves every
  pack's alone hash once, and both sides then match by construction), or (b) the world creates a pack's bodies directly
  in its space (an own World3D per pack holder), so no body is ever moved. After either: `world.sh same` over all
  games, plus a selftest that compares the body order of a pack's space in both runners at frame 3 (the probe above),
  which catches this class of bug without waiting for a rare contact.
- The repro is a pack-side probe in a copy of N3's tree (not in the gate). No selftest was added for it tonight.

## Astra tokens (whole night)
R1 127,486 (reaction clips) + R2 152,170 (labs) + R3 154,309 (swing weight) + R4 181,790 (trail, HUD) = 615,755.
