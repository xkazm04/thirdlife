Lane walker report (night of 19 Nov 2026)

Route: Opus directing GPT 6.2 Astra. Worktree .claude/worktrees/n19-walker, branch n19-walker (from main c8b88fc); nothing
committed. "D" = the Opus director. Paths are relative to docs/shifts/2026-11-19-night/lanes/walker/ unless they start with engine/.

OUTCOME PER ITEM (every check below was re-run by D: red on the old code, green now)
1a  Held run slide, the folded left foot 0.151 m under the floor (bugfix-37 new finding). Built by D.
    Lowest vertex of the held pose went from -0.151 to +0.006 m (left leg 56/-38/-118 -> 78/-26/-142 deg).
    Check: rig.walker.slide_floor (block 370). Old -0.151 fail, now 0.006 pass. Stills: stills/slide_held_{before,after}.png
1b  V channel narrower than the capsule: he wedged in air for good. Built by Astra in r2 and r2b.
    Cases: 62 and 75 deg V, asymmetric 62/75 V, a V turned 30 deg in yaw, a faceted triangle crease. Before, every one ended
    in air or slope and he never got out. Now he lands once, walks 8.7 m along it with 0 mode changes and jumps 0.94 m.
    A single steep face still gives a slope slide; a 0.6 m step edge still makes him fall.
    Village scan in a window (2,880 drops, walks and runs): 0 wedged before, 0 after.
    Check: walk.v_wedge / v_asymmetric / v_yaw / v_terrain (block 380) are red on the HEAD body. Controls single_face and
    step_edge print the same values on both.
1c  Pad swapped under him for a higher game floor. Built by Astra in r2.
    Standing still, he stayed INSIDE the floor for as long as he stood (60/60 ticks at +0.2 and +0.4 m), not for one tick.
    Now he is lifted onto it on the first tick (0/60), up to one step (0.55 m). Above one step nothing changed.
    Check: walk.pad_swap.
1d  Q31 (the slide's hand does not reach the floor) and D14 (how hard a slope jump pushes): look and feel calls for the
    owner. Left unchanged.
2   L2, camera inside or just under a crown. Built by Astra in r1 and r1b; D fixed one crash.
    The camera-only crown solid is now padded convex hulls of the DRAWN foliage (engine/kernel/world/terrain/tree_crown.gd),
    replacing the core cylinder.
    Head outside a crown, camera inside / within 0.5 m of leaves, before -> after:
      slope sweep (6,720 poses): 4,197 / 15,930 frames -> 0 / 0
      pitch sweep: 2,052 / 7,054 -> 0 / 0
      wf_canopy: 12 / 20 -> 0 / 0
      tour: 0 / 0 -> 0 / 0
    Head inside a crown (D5 choice 1, kept): 5,205 -> 3,913.
    Check: walker.crown (block 360, headless, 8.6 s). HEAD gives 1,292 / 2,935, now 0 / 0.
    Cost: _avoid mean 26 -> 56 us in wf_canopy, 21 -> 24 us in the tour. Crown build lap 106 / 126 / 133 ms (busy machine).
    Crown bodies 845 -> 358, because far pines out of reach get none.
3a  L1, the walker's ink outline goes missing against a near background. Built by Astra in r3.
    Silhouette coverage: village bank 45.2 -> 94.8 %, against a wall 8.9 -> 95.5 %, on the floor 65-75 -> 91-95 %.
    Cost: 0 extra taps.
    Crawl: his frozen rear outline 3.24 -> 2.85 grey levels; the STYLE.md thin pan is unchanged (2.625 %).
    Check: style.walker.ink (block 390). The HEAD shaders fail it ("wall to the right expected 1.0 got 0.0").
3b  L1, terrain crests against land just behind them. Built by Astra in r3b and r3c; D sent r3b back because it thinned
    the bold skyline.
    Crest pixels with a 5-15 % depth gap: bluff 0 -> 80/82, shoulder 33 -> 299/299, bank 6 -> 60/64.
    HEAD's strong contours keep their opacity (0.958 -> 0.958 over 36,076 px).
    False ink on flat grazing ground: 6,344 -> 0 px.
    COST: terrain crawl on the bluff walk went up, 2.010 -> 2.217 % flips. The bank is unchanged.
    +5 conditional taps, about 1.7-2.0 per pixel on average.
    Check: block 390 terrain profiles, plus a case that a strong silhouette keeps full weight.
    Sheet: r3/terrain/crest-comparison.jpg
4   A/D sidestep or turn (the owner's question). Built by D.
    Both live behind TL_AD_KEYS. Absent = today's behaviour; no default changed.
      sidestep: he keeps facing the camera and the gait steps sideways or back.
      turn: A/D turn him and the view at 150 deg/s.
    Clips from the same device keys: ad/ad_face.mp4, ad/ad_sidestep.mp4, ad/ad_turn.mp4. Still: stills/ad_modes_t300.jpg.
    No gate check (it needs a window). The default path is the one world.visit_proof and the tour already cover.

CLIP: clip.mp4, 16.6 s, three windowed visits: toward the bank (wf_feel), among the trees (wf_canopy), down the bluff
(wf_bluff). Script: make_clip.sh. Frames: stills/clip_frames.jpg.

GATES (final tree)
Full gate run 2 (02:52):
  PASS arch 12/12, assets 4/4, cards 3/3, devx.test 225/225, foreman.typecheck, foreman.test 210/210
  PASS kernel.selftest 229/229 (main has 219; +10 new cases)
  PASS kit 91/91, seeds 39/39, item 91/91, ui 77/77, world 8/8
  FAIL packs 32/33: hockey invariants.many_budget frame p50 1.024 ms against a 1.0 ms budget, on a busy machine.
       Run alone right after: PASS packs 2/2, 33/33, with the same hockey hashes as main.
  NOT RUN perf (machine busy). Run alone with `tl perf run --quiet-only --wait 900`: PASS 6/6 on a quiet machine
       (tour6, walk30, mix30, pile600, hero1440, load6), recorded in perf/ledger.jsonl line 11.
Run 1 failed only ground.pad_lift: r1b read world.walk on a World that has none. D fixed it with a safe get; ground. now 9/9.
Parkour state hashes are unchanged through r2 and r2b. No pack hash moved, no test was loosened, KERNEL_API was not bumped.

CHANGED FILES
engine/kernel/world/terrain/world_space.gd, tree_crown.gd (new), crown_clearance.gd (new), crown_camera.gd (new: extends
TLChaseCam; tl_chase_cam.gd itself unchanged), engine/kernel/world/landscape.gd, terrain/village_parts.gd (Parts.multi,
camera_region), engine/kernel/world/visitor.gd, engine/kernel/runner/visit.gd, terrain/world_body.gd, WORLD.md,
engine/rigs/biped/tl_rig_biped_moves.gd, RIGS.md, engine/style/shaders/ink_post.gdshader, toon.gdshader (ground writes
roughness 0.9), STYLE.md, perf/ledger.jsonl (the perf run).
New: walks/walk_case_c.gd, crown_case.gd, crown_oracle.gd; engine/rigs/review/walker_slide_floor.gd, walker_ink_case.gd;
selftest.d/360-walker-crown.sh, 370-walker-slide.sh, 380-walker-body.sh, 390-walker-ink.sh.

FOR THE OWNER
- Watch clip.mp4, then the stills. Compare ad/ad_face.mp4 with ad_sidestep.mp4 and ad_turn.mp4.
  Live: TL_AD_KEYS=sidestep bash engine/tools/world.sh visit tour
- The terrain crest lines cost a little crawl on the bluff (2.0 -> 2.2 % flips): keep or drop.
- Near crowns the camera can still swing sideways round him as a last resort (D5 choice 2):
  0 frames in wf_canopy and the tour, about 2.6 % of sweep frames, up to 120 deg.
  This is still your call, along with Q31 and D14.

QUESTIONS FOR THE DIRECTOR
1. Should API.md:310 (TLBiped walker feel) say that the body now stands in a narrow V and rises onto a floor that arrives
   under him? Parkour hashes are unchanged.
2. r3/ holds 775 MB of measuring clips (CRF 4). Commit the .md files, scripts and sheets; the clips belong in the vault.
3. Astra wrote scope claims into the worktree's .claude/sessions.json twice. D reverted them each time.

CODEX TOKENS (as each run printed them; a resumed run may include earlier context)
r1 233,075 | r1b 548,934 | r2 146,520 | r2b 238,456 | r3 164,492 | r3b 291,807 | r3c 415,999 | total 2,039,283
Sessions: r1 01a1f0ea-3b69-7793-bc67-4df64060323e, r2 01a1f0f0-8751-7c10-b041-4832713e53e2, r3 01a1f0f1-bac5-7d30-9f36-e53d7fa1af05.
D built: 1a, item 4, the clip, and the review fixes (CRLF churn, the landscape header, the world.walk crash, sessions.json).

NEXT THREE
1. Give the owner the camera's sideways swing near crowns behind a flag, as with A/D, after a windowed mouse walk.
2. Bring the bluff terrain crawl back to HEAD's level or lower while keeping the crest lines.
3. Fix the slide entry blend: a foot dips 0.148 m under the floor for about 6 frames.
