N3 world | night shift 22-23 Nov 2026 | tree .claude/worktrees/n23-world (branch n23-world) | Opus director, Astra read-only

The owner's three findings in the World (Wren Valley), each reproduced in a boot.tscn window with scripted keys
(.tl/cap.sh: TL_EXE_START, TL_EXE_KEYS, every drawn frame kept), its cause found with file:line, then fixed and shot
again from the same spots. Six rounds; rounds 1-5 are landed, round 6 (the verdict's four failures) is sent as landable.

ROUNDS
1. Far structures cut at 2 km (finding 3, "incomplete structures in the far"). LANDED (74f935a).
   Cause: kernel/api/tl_chase_cam.gd:69 `far = 2000.0`; the visitor's camera is a TLChaseCam and the Home is
   6528 x 6528 m, so peaks, far hills and woods beyond 2 km were sliced and slid in and out as he moved.
   Fix: kernel/world/visitor.gd: with the Home on, cam.far = 9300 m (the valley's diagonal 9232 m). kernel/api untouched.
   Evidence: round-1/far_before_after_f209_f536_f863.jpg (the twin peak cut in half at frame 863 before, whole after).
   Selftest 770 n3.sight, seeded red on the old visitor.gd.
2. Venue floors dark far / grass near (finding 3, "green ground closer up"), and grass tufts all on or all off by the
   village middle (finding 2). LANDED (3e60be5).
   a) engine/style/shaders/toon_cel.gdshader:433, toon.gdshader:501 dropped a live instance whole when its ORIGIN lay
      outside the plot radius; ex_car's asphalt is centred 65 m out yet covers the plot: grass near, a bare dark slab
      in its picture far. Pre-existing (TL_HOME=plain too). Fix: drop by origin only without the draw layer's
      reaches_in bit (tl_clip.w < 1.5). Evidence in both looks (crisp and classic): round-2/car_*_before_after.jpg.
   b) kernel/world/landscape.gd:458-462: ONE multimesh for all 1385 village tufts with a 120 m range: they appeared and
      went together, and both village ends never had tufts. Fix: village_parts.gd multi_near, 38 cells of 32 m.
      Evidence: round-2/tufts_before_after_4_spots.jpg; selftest n3.tufts (304.0 m before, 18.9 m after).
3. Objects sinking or rising at the mid <-> far picture switch (finding 1, where it is proved). LANDED (a96f42f).
   Found with Astra's read-only survey, then measured: draw_pictures.gd:393-430 with draw_base.gd far_cell 6 snapped a
   pack's own ground to a 6 m grid; seed_drive's far ground moved up to 2.07 m under objects that kept their height.
   Fix: far_cell 0. Selftest n3.far_ground (0.21 m red, 0.00 m after). At 250-280 m 2 m is a few pixels, so the
   figure is the evidence (round-3/drive_mid_vs_far_before_after.jpg).
4. After-clips from the four before spots (final/), and road rails (finding 2). LANDED (4b57b71).
   terrain/road_rails.gd: rail pieces of 31 m (12 posts about 11 px tall) popped whole at 108 + 8 m; now each fades
   (dithered) over 108..132 m. round-4/rails_fade_side_on_100_to_140m.jpg.
5. Venues in full to 60 m in the village (finding 2: a car became a box from 38 m). LANDED (c6d7f8a).
   engine/boot/village.json tiers.sideline_m 30 -> 60, margin_m.sideline 8 -> 10 (the Director's go).
   round-5/drive54_crop.jpg: 54 m from the track, before a static blue box, after the real car driving.
6. The verdict's uncapped kernel suite found four failures from rounds 2 and 4 (494 passed, 4 failed). SENT as landable.
   - Round 2's shader change broke the 19 Nov blend (blend.car_origin live_grass 0.0 %) and two classic sha pins
     (surf.classic_source, celsurf.classic_files). The Director kept the blend: the two shader lines and STYLE.md are
     back to 1fa3b56 byte for byte, and the PICTURES now drop a slab that reaches in, as the live draw does
     (draw_pictures.gd, PIC_VERSION 2311). ex_car's course is village grass near and far; no dark square anywhere.
     blend.car_origin's expectation moved from "distant asphalt" to "distant grass" (named in the test): 99.8 / 97.2 %.
   - Round 4's rails fade drew rails under 0.75 px (celsurf.rails drawn_under_0.75_px=12). Fitted, test unchanged:
     the fade runs 92..116 m, ending where the old piece popped (drawn_under_0.75_px=0).
   - round-6/car_r6_crisp.jpg, car_r6_classic.jpg: 22 Nov main | round 2 | round 6 at the same four frames.
   Lesson for this lane: I ran the blocks my rounds touched by name, not the whole uncapped kernel suite, so a test
   that pinned the old behaviour (blend.car_origin) and two byte pins were found only by the verdict.
OUTCOME AGAINST THE ACCEPTANCE
- Before and after clips and stills from the same spots, all three findings: MET.
  before/ (4 clips + sheets, before any fix), final/ (the same 4 routes after rounds 1-3 + rails), and per round the
  same-frame sheets above. Judged by eye in each round's NOTES.txt.
  Honest limits: finding 1 ("objects blinking below/above the ground") is covered by what was measured to move:
  the tufts appearing out of the ground as one field (round 2), the far ground under the drive (round 3), and the
  far plane slicing hills and woods (round 1). Several other suspects were measured and ruled out (below).
- World = alone: MET every round. tl check --tier full --only world PASS [8/8], the same hashes each time
  (drive a2940a17@3441, wall 5896844e@1221, paddle dff1a390@4486, walker f1c7b537@371, kit ca698e71@332,
  car 3a459d0f@1872, hockey bcc1f5dc@5256, parkour f7abac00@988). Round 2 also under TL_STYLE=classic: same.
  Round 5: world.sh tour tour --headless PASS, and the village itself at 60 m (resolved walk) --headless PASS, 10/10
  plots = alone = replay.
- Every pack verb hash unchanged: world,packs under crisp and classic (round 2): 128 of 129 verb runs; the one FAIL
  both times is hockey invariants.many_budget, a wall-clock check (p50 1.323 / 1.445 ms against 1.0) on a busy
  machine, as on the day shift. No hash moved; every change is drawing or the visitor's camera, except round 5,
  which changes which packs tick in full (proved = alone above).
- home. and land. selftests: home. 9/9, land. 7/7 (round 2); harden 15/15 (round 2), harden.rail* 3/3 (round 4);
  n3. 3/3 (n3.sight, n3.tufts, n3.far_ground), each seeded red on the code before its fix.
- Frame cost before and after, labelled: every read BUSY (other sessions' Godot processes, CPU 28-82 %).
  Round 1 far plane: p50 5.62/3.65 -> 4.20/4.86 ms (noise). Round 2 tufts: 7.79 -> 5.24 ms p50 (one pair, noise).
  Round 5 sideline 60: 3 + 3 interleaved, p50 median 3.24 -> 3.89 ms (+0.65 ms), p99 11-20 -> 15-18 ms.
  No quiet read was possible tonight; the +0.65 ms of round 5 should be read again on a quiet machine.
- Fast and full tier: fast PASS 5/5 on every round's tree. Full: world PASS each round; packs as above (busy-only
  wall-clock fail); the uncapped kernel suite and perf were not run by this lane (the Director's verdict run).

MEASURED AND RULED OUT (so nobody chases them again)
- Camera depth precision: near 0.05 vs 0.5 over the valley fields gave the same flicker count to 0.1 %.
- Sky-mask blink detector (walks/blink_detect.py --skymask) on a valley flight: 0 holes, 0 sky blinks.
- Shadows: the curved olive/yellow ground regions stay with shadows off; crane shots 0.5 m apart show them fixed in
  the world: they are the painted meadow patches, not a camera-dependent band.
- Full vs mid picture at 40 m from 7 venue edges: the same picture (one red block extra in kit's mid).
- Start of the World: every pack shows its picture, then full, then picture inside one frame: no visible blink.

CHANGED FILES (all landed except round 5)
engine/kernel/world/visitor.gd, engine/kernel/world/landscape.gd, engine/kernel/world/terrain/village_parts.gd,
engine/kernel/world/terrain/road_rails.gd, engine/kernel/world/draw/draw_base.gd, engine/kernel/world/draw/FAR.md,
engine/style/shaders/toon_cel.gdshader, engine/style/shaders/toon.gdshader, engine/style/STYLE.md,
engine/kernel/world/home/n3_case.gd (+.uid), engine/tools/selftest.d/770-n3-world-look.sh,
engine/boot/village.json (round 5), engine/kernel/world/draw/draw_pictures.gd, DRAW.md,
engine/tools/selftest.d/513-blend-car-origin.sh (round 6; the round-2 shader and STYLE.md changes are reverted), this lane folder.

BEHAVIOUR CHANGES THE OWNER WILL SEE
- The far peaks, hills and woods of Wren Valley are whole; nothing is cut 2 km away.
- ex_car's course is village grass near AND far (round 6; the 19 Nov blend). The dark slab seen from 38 m is gone.
- Grass tufts stand along the whole village road and appear by 32 m cells, not all at once.
- Road rails thin out between 92 and 116 m instead of popping by 31 m pieces (round 6 fit).
- (Round 5) venues within 60 m play in full, real bodies instead of boxes; about one more pack ticks in full on average.

HOW TO LOOK
Start the exe or `--path engine res://boot/boot.tscn`, choose World. Fly (F, Space) west from the village and look
back east (the peaks); walk the village road east from the west bridge (tufts, rails); walk south from (85, 200)
toward the car course; stand 50 m off the drive track (round 5).

ASTRA (gpt-6.2-astra, codex exec, high effort)
- One read-only survey, 176,996 tokens (.tl/codex-a1.log in the lane tree): every remaining distance- or
  camera-dependent show/hide or vertical mechanism, ranked. Of its six items: #2 (far ground grid) became round 3,
  #3 (rails) round 4, #1/#4 (picture switch, marks) round 5; #5 (thin overlays) and #6 (conditional pops) checked,
  not shown to move anything a person sees. All building was done by hand (faster for one-line fixes).
- Total Astra tokens: 176,996.

QUESTIONS FOR THE DIRECTOR
1. Round 5's frame cost is a busy read (+0.65 ms p50): keep 60 if a quiet re-read stays under 1 ms.
2. ex_car: grass near and far now (round 6); the owner ask about its asphalt is no longer needed unless he wants the course drawn.
3. Marks are still boxes beyond 70 m (P13 design). If the owner still sees "blinking with distance levels" in the
   village, the next lever is the mark's shape (a low-poly copy of the body instead of a box), in draw_life.gd.

NEXT THREE THINGS THIS LANE WOULD DO
1. A quiet frame-cost read of the whole night (visitor far plane + tufts cells + rails fade + sideline 60) against
   1fa3b56, in the exported exe.
2. Marks shaped like their bodies (a merged low-poly copy) so the mid picture keeps cars and figures, not boxes.
3. A window selftest that walks the village road and counts drawn-object pops per metre (render info), seeded red on
   1fa3b56, so a distance pop is a gate failure, not an owner report.
