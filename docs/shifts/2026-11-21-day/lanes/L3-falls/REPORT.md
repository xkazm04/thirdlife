L3 falls: REPORT (Director: Opus; arms A, B and C on GPT 6.2 Astra; day of 21 Nov 2026, 10:35-15:45)

OUTCOME
All three arms were built, run for two rounds each, and measured by the Director on their final trees. All three are
ELIGIBLE: each is deterministic, world = alone holds, and each keeps every existing game's state hash. C has one caveat:
each figure in an active fall costs +0.32 ms per frame. No arm lands today. Each arm's work is uncommitted in its own
worktree, with its round-1 state kept in <tree>/.tl/r1/. The Director commits each arm to its branch for the owner's
pick.

WATCH (in docs/shifts/2026-11-21-day/lanes/L3-falls/)
- falls-side-by-side.mp4 (12.5 s, 2x2: base | A / B | C): the same scripted lab in every tree.
- falls-hockey-side-by-side.mp4 (13.2 s, 2x2): the real hockey bot_check, with the head-on and the side knockdown at
  8 m/s, seen in the broadcast camera.
- arm-a.mp4, arm-b.mp4, arm-c.mp4 and arm-*-hockey.mp4 show each arm alone; base-lab.mp4 and base-hockey.mp4 show the
  base.
- falls-sheet.jpg holds ten key frames per route.
- COMPARE.md has the per-hit and per-arm tables and the eligibility verdict.
Every clip was rendered in a window (d3d12, the movie writer at a fixed 60 fps). The Director judged each one frame by
frame: contact strips of every 2nd to 4th frame around every hit, and single frames at the impacts.

ACCEPTANCE (the brief)
- Three arms built and measured: MET.
  - A (authored clips) has 4 flinch, 4 fall and 2 get-up pose clips, chosen by from_dir in the victim's frame.
  - B (clips plus spring) has its own clips plus a 12-tick damped spring on the hit bone and its chain, with a landing
    bounce.
  - C (active ragdoll) has 12 Jolt bodies with motors. They run in a private physics space per struck figure, with a
    copied floor plane, stepped once per rig tick and frozen when the game is paused.
- The hit lab was built first and copied into the arm trees: MET, with one deviation from the brief.
  - The lab is the pack engine/kernel/examples/ex_hit_lab (pack.json, scripts/main.gd, tests/bot_lab.gd), plus selftest
    block 670-falls.sh.
  - The brief asked for engine/rigs/review/hit_lab.*. A scene in engine/rigs/ that calls TLBiped or TLHit fails tl arch
    module-walls (rigs reference nothing outside themselves).
  - Falls go to the right of the side-on camera when they fall away from the blow. The lab plays itself (750 frames)
    and measures the head socket per hit.
  - The state holds a digest of the victims' sockets every frame, so a drawn pose that differs between two runs fails
    the hash.
  - falls.lab_spec is RED on the base on purpose: the front big hit lies 1.11 m TOWARD the hitter, and the hockey check
    lies 0.41 m toward him.
- Measures per arm (re-run by the Director): MET.
  - Lab twice gives the same hash: base a6b31cf5, A 0065d638, B fec99b42, C c5d1d4fb.
  - Hockey bot_check hash is 5f1900dc in all four trees.
  - Hockey bot_hockey hash (invariants) is 3b372f91 in all four. C's round 1 moved it to 450d9612; round 2 restored it.
  - world: 8/8 PASS in all four trees.
  - packs: 60/61 verb runs in all four trees, including the base. The one FAIL is hockey invariants.many_budget (wall
    clock), BUSY: base 1.368, A 1.036, B 1.091, C 1.158 ms.
  - Frame cost A/B: 6 interleaved rounds of hockey invariants, BUSY (CPU 43-93 %).
    - Median p50: base 1.063, A 1.122, B 1.145, C 1.122 ms.
    - Paired versus base: +0.04, +0.09, +0.06 ms, inside a per-round spread of -0.14 to +0.21 ms. Base always ran first
      in a round, so the run order was not controlled.
    - Verdict: not distinguishable from base. A quiet A/B is still owed.
  - Astra's paired benches (raw data in each arm's .tl/):
    - B's spring costs +0.050 ms per tick for 12 springing figures.
    - C's ragdoll costs +0.32 ms per frame for one active fall among 12 figures (6 of 6 pairs positive).
  - Kernel blocks that run a biped (filters k2 k3 k6 k8 ex rig moves hockeyfun falls p11 hunt2 dungeon):
    - base 115/116 (the FAIL is falls.lab_spec, red by design);
    - A 117/118 (the FAIL is k2.down_invariants, the ex_down many_budget p50 at 1.071 ms under load; re-run alone it
      passed 4/4);
    - B 122/122;
    - C 120/120.
  - Rig selftest: base 95/95, A 107/107, B 105/105, C 95/95.
  - Fast tier: arch 12/12, assets 4/4, cards 3/3, devx 229/229 in every tree. foreman.typecheck is NOT RUN because no
    worktree has foreman's node_modules; no arm touches foreman.
  - tl_biped.gd went from 600 lines to A 562, B 567, C 569: split, never grown. Every .gd file is at 600 lines or fewer.
  - No public API change. The new kernel and rig members are underscore-private, there is no new class_name, and
    KERNEL_API stays 1.12.
  - The full kernel suite was NOT run per arm. B's own full-tier run hit the 1800 s cap (78 of 79 units under load).
    That is a stopped run, not a pass, so the Director ran the biped-touching blocks by filter instead (above).
- The clips were judged by the Director in a window: MET (what was seen is in COMPARE.md).

WHAT THE DIRECTOR SAW (short; details in COMPARE.md)
- A has the richest front fall: knees give, seat first, roll back, sit up, knee under, stand. In round 2 the side fall
  became a sprawl. Taps snap clearly (0.22 m). Every fall from the same direction is the same fall.
- B falls like A but plainer. In round 2 its spring became visible in the lab: a tap rings once (out 0.18 m, back
  0.10 m), and the head and gloves bounce on landing. The side get-up now goes through hands and a knee. The spring is
  invisible at the hockey camera.
- C's falls are really physical: a stiff topple, a floppy landing, the lowest lie (head 0.23 m), and never the same
  twice. Its taps are the smallest (0.11 m). In the side fall the neck bends to an odd angle for a few frames. It also
  carries the per-hit cost above.
- At hockey's broadcast camera all three read about the same, and all are better than the base: the victim goes
  horizontal away from the hitter instead of forward into him. He is small, though, and partly under the hitter.

ASTRA TOKENS (session totals over 2 rounds; budget about 800 k each)
A 517 k (r1 310 k), B 457 k (r1 227 k), C 678 k (r1 389 k).

CHANGED FILES
- My tree (n21d-falls, uncommitted): engine/kernel/examples/ex_hit_lab/** (new); engine/tools/selftest.d/670-falls.sh
  (new); the lane folder (briefs arm-common.md, arm-a/b/c.md; STANDUP.md, COMPARE.md, REPORT.txt; clips; sheet).
- Arm A: engine/kernel/api/tl_hit.gd, tl_biped.gd, engine/kernel/API.md (own paragraph), engine/rigs/tl_rig_biped.gd,
  engine/rigs/RIGS.md, engine/rigs/biped/authored_hits.gd and hit_contacts.gd (new, with .uid),
  selftest.d/671-falls-a.sh, plus the lab and 670 copies.
- Arm B: the same kernel files plus engine/kernel/api/biped_hit.gd (new, no class_name), engine/rigs/biped/
  hit_clips.gd, hit_spring.gd, fall_support.gd and side_get_up.gd (new), engine/rigs/biped/tests/hit_spring_case.gd,
  and 671-falls-b.sh.
- Arm C: the same kernel files plus biped_hit.gd (new), engine/rigs/biped/ragdoll.gd and hit_rig.gd (new), small edits
  to clay_rig.gd and tl_rig_biped_moves.gd, engine/rigs/biped/tests/ragdoll_case.gd, and 671-falls-c.sh.

BEHAVIOUR CHANGES (in every arm; visual only, so every state hash is unchanged)
- TLHit.react now shows a flinch away from the blow, scaled by strength. From 0.4 up it keeps the stub's stumble of
  8 + 10 x strength frames.
- TLHit.down falls away from the blow.
- TLBiped.down(frames) with no direction now infers the blow from his velocity above 0.5 m/s. That makes the hockey
  pack's existing checks directional with no pack change.
- Timings, signals and down-while-down are unchanged (ex_down still reports down_frames 113).

FOR THE DIRECTOR (commit time)
- Arm B's diff has CR/LF noise: 13 lines differ only at end of line (git diff --ignore-cr-at-eol is smaller).
  Normalise to the repo's CRLF before committing.
- Arms A and B left scratch copies under .tl/ab-base and .tl/timing-base. They are gitignored, and there are no
  junctions in any arm tree (checked).
- The lab, 670-falls.sh and the briefs are untracked in my tree. They belong on main whichever arm wins: the lab is the
  yardstick, and its spec case is red on main today by design.
  - Main's 670 case will be RED until an arm lands. Either land the lab together with the picked arm, or land it with
    falls.lab_spec marked as expected-red.

QUESTIONS
1. The lab's location: will you accept engine/kernel/examples/ex_hit_lab instead of engine/rigs/review/hit_lab.* (the
   module-walls rule)?
2. C: is +0.32 ms per falling figure acceptable for hockey's 1.0 ms p50 budget? A quiet p99 measurement during a
   3-skater pile-up should come first.
3. The hockey pack still calls victim.stumble() directly for its stumble class, not TLHit.react, so the arms' flinches
   do not show in hockey stumbles. That is for L4 (hits.gd) to switch.

NEXT THREE THINGS THIS LANE WOULD DO
1. Run a quiet frame-cost A/B (base, A, B, C, randomised order): hockey p50 and p99, plus a 3-skater pile-up for C.
2. After the owner's pick, rebase the chosen arm on main with L2's fight clips (strike, block, body_check), wire hockey
   hits.gd stumbles through TLHit.react (with L4), and regenerate API-INDEX/RIGS.
3. Make the get-up readable at game scale: let a pack ask for a longer rise for big hits (thirdjam: 20 f get-up after
   a 40 f knockdown), and add the 120 f post-get-up grace from thirdjam's contact model with L4.
