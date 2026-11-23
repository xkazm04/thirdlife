K2 figure: report of round 1 (23 Nov 2026, 16:51 to 18:55)
Worktree C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-figure, branch hk-figure, nothing committed (the Director lands).

THE ROUND IN ONE PARAGRAPH
The export was not blocked. thirdjam's shipped skater (SK_SkaterTB1_P3: 12,040 triangles, 24 bones, the stick skinned
in) and all 202 of its clips are out of Unreal and baked into engine/rigs/skater (2.6 MB). One skater stands on flat
ice in a gym at 1.637 m and plays the clips by physics frames. The Unreal editor was made to pose and photograph
thirdjam's own figure at the same keys from the same four cameras: over 92 shots no point of the figure (pelvis, head,
hands, feet, stick bone, puck socket, head socket) lies more than 0.09 mm from where Unreal puts it. No driver yet
(round 2): the figure plays a clip, it does not yet answer UpdateMotion or SetStickAim. Nobody but me has looked.

OUTCOME AGAINST ROUND 1 OF THE BRIEF ("get it out and in")
- Export mesh + skeleton + all clips: MET. export_skater.py, one commandlet run: clips found=202 gltf_done=202 failed=0;
  raw tracks of 202 clips (6,923 keys); blend-space tables (Skate 14, SkateReady 14, Aim 24 samples); 3 sockets; 9 slots.
- Import in Godot: MET. build_skater.gd: PASS, clips_found=202 clips_built=202, total_keys=6923, key_count_mismatch=[],
  check keys=6923 worst_joint_m=0.00019 worst_axes_m=0.00142 (against Unreal's raw keys; the gap is Unreal's own
  animation compression, see ROUND-1.md).
- One skater standing on flat ice at 1.637 m with a clip playing: MET. Gym report top_m=1.6371 at rest; Stride plays
  (media/r1_pair_Stride_side.jpg bottom rows, the film's right half).
- Filmed beside the same clip in thirdjam: MET. media/r1_stride_side_by_side.mp4 (12.8 s: Stride's 59 keys, five loops
  at speed and two at a quarter), reference shots 59 of 59 fresh, 531 points, worst 0.00009 m.

OUTCOME AGAINST THE LANE'S ACCEPTANCE (whole lane; round 1 can only meet the first in part)
- "The figure in our engine is thirdjam's figure: same proportions and silhouette side by side at three angles, same
  clips at the same frames": MET for the shape and the clips (four angles: media/r1_pair_rest.jpg,
  r1_pair_Stride_turn.jpg; 33 poses of four clips + 59 keys of Stride by numbers). NOT MET for the surface: no jersey
  number, no crest, flat cel instead of felt (ROUND-1.md, "What my eye rejects").
- "Every driver rule cites its source": NOT STARTED (round 2).
- "Defect tests green and red when broken": NOT STARTED as a set (round 3). One pose test exists and was shown red twice.
- "Your own eye's list of what is still wrong, with frames": ROUND-1.md, seven items.

GATES
- node devx/bin/tl.mjs check --tier fast (last run 18:53, after the last edit): PASS, exit 0: arch [12/12], assets [4/4], cards [3/3], devx.test [229/229],
  foreman.typecheck clean (248 units found, 248 completed). The first run said NOT RUN for foreman.typecheck (no
  foreman/node_modules in this worktree, exit 2); `npm ci` in foreman/ fixed that.
- node devx/bin/tl.mjs check --tier full: NOT GREEN, exit 1 (17:44 to 18:48, other lanes' Godot and Unreal running):
    PASS  arch [12/12], assets [4/4], cards [3/3], devx.test [229/229], foreman.typecheck, foreman.test [325/325]
          (318 pass, 7 skipped), kit.selftest [120/120], perf [2/2], seeds [39/39], world [8/8] (8 games: world = alone)
    FAIL  kernel.selftest [121/122]: "selftest: 0 failed, 121 passed; timed out after 1800 s and was killed". A stopped
          run, not a pass. Nothing in it failed; the suite ran into its 30-minute cap one unit short. My block is the
          last in order and takes 10 s alone, so it is very probably the unit that was cut. Run by themselves after the
          gate: `selftest.sh rig.` 24 passed, 0 failed (108 s: every rig case, old and new); `selftest.sh rig.skater` 4/4.
    FAIL  packs [2/3]: hockey invariants.many_budget: frame p50 1.106 ms against a 1.0 ms budget (the old
          engine/packs/hockey, which this lane did not touch and which does not load the new class; its determinism
          check passed, d3398e69321487bc). Twice more by hand afterwards: 1.030 and 1.061 ms. The gate histories of
          this machine show `packs` at 2 of 3 in every full run of any worktree since 22 Nov 14:23 (twelve in a row,
          five of them today by other lanes): it was not green before this lane.
    NOT RUN  item.selftest, ui.selftest: "needs site/marble-run-three-marbles-20261110-2 (main checkout only)".
  So the full tier is not a pass. I do not claim it. What I can say is that neither failure is in code this lane
  wrote or changed, and that the kernel selftest must be run again where it can finish (a quieter machine, or main).
- bash engine/tools/selftest.sh rig.skater: 4 passed, 0 failed:
    PASS rig.skater.body  (bones=24 triangles=12040 slots=9 top=1.6371 low=0.0013 surfaces_with_colour=0)
    PASS rig.skater.clips (table=202 found=202 library=202 keys=6923)
    PASS rig.skater.ref   (poses=27 of 27 points=243 worst_m=0.00001 at=Shot_Slap key 24 puck_socket tolerance_m=0.0005)
    PASS rig.skater.play  (same_twice=true first_key_0=true one_key_a_tick=true wraps_at=59 one_shot_holds=true)
  Red when broken: PUCK_ON_STICK moved 1 cm -> FAIL rig.skater.ref worst_m=0.01001; the body's quarter turn off by
  0.18 degrees -> FAIL worst_m=0.00500; both restored, PASS again.
- The pose test found a real fault on its first run (a Skeleton3D call that does not exist in 4.7.2 on the path a
  figure takes outside the tree) and a loop that did not wrap exactly; both fixed before this report.

CHANGED FILES (all new except RIGS.md)
engine/rigs/skater/tl_rig_skater.gd            class TLRigSkater: body, materials, play_clip / tick / pose_at, sockets
engine/rigs/skater/skater_body.scn             0.23 MB  baked: SkaterBody > Skeleton3D > Mesh (9 named surfaces)
engine/rigs/skater/skater_clips.res            1.67 MB  baked: AnimationLibrary, 202 clips
engine/rigs/skater/skater_clips.json           the clip table (name, keys, seconds), bones, slots, sockets
engine/rigs/skater/source/                     0.67 MB  what the bake read: SK_SkaterTB1_P3.glb, meta.json,
                                               blendspaces.json, clips.json; .gdignore (Godot does not import it)
engine/rigs/skater/gym/skater_gym.gd, .tscn    the gym (stills, sheets, a shot list, play)
engine/rigs/skater/review/skater_case.gd       the headless checks of block 810
engine/rigs/skater/review/reference_poses.json where Unreal puts thirdjam's figure at 27 poses (the golden of rig.skater.ref)
engine/tools/skater/export_skater.py           inside Unreal: mesh, clips, tracks, blend spaces, sockets, materials
engine/tools/skater/build_skater.gd            the bake, with the check against the raw keys
engine/tools/skater/reference_capture.py       inside Unreal: thirdjam's figure at a shot list, with the pose numbers
engine/tools/skater/pair_sheets.py, pair_film.py  side-by-side sheets and film, the two sets of pose numbers compared
engine/tools/skater/export_driver_text.py      inside Unreal: the shipped Blueprint driver as text
engine/tools/skater/t3d_digest.py              that text as a listing: entries, assignments, calls, branches (first version)
engine/tools/skater/abp_digest.py              the animation graph of that text: the pose tree, states, transitions (first version)
engine/tools/selftest.d/810-skater.sh          rig.skater.body / .clips / .ref / .play
engine/rigs/RIGS.md                            a section "The skater" above the generated part
docs/shifts/2026-11-24-night/lanes/K2-figure/  STANDUP.md, ROUND-1.md, REPORT.txt, media/ (7 JPG sheets, 1 mp4; 5.6 MB)
Size of engine/rigs/skater: 2.6 MB (limit in the brief: 30 MB).
No rule table was edited (campaign rule 6): tl arch and tl assets pass with these homes as they are.
Not in git, in .tl/ of the worktree (kept for the next rounds): tj-export (the Unreal project copy, 0.8 GB),
skater-export (the 202 clip glTFs 122 MB, raw tracks 10 MB, the driver text 48 MB + 46 MB). Raw capture PNGs deleted.

BEHAVIOUR CHANGES
None to anything that existed: no existing file but RIGS.md is touched, TLRigs and the old hockey pack do not know the
new class.

DEVIATIONS (from thirdjam, each with its reason)
1. Materials: TLStyle flat toon materials per slot in thirdjam's base colours (jersey = team colour, helmet = team x
   0.75 in linear light: the shipped driver's SetTeam, read from its graph; the brief's 0.5 was the older figure's;
   the pictures of this round were made with 0.5 on both sides), not M_SkaterTB1Jersey / M_Toon: no felt, no clay bump, no rim,
   no emissive lift, no number, no crest. Reason: the brief asks for our cel look through TLStyle.
2. Vertex colour moved to CUSTOM1, COLOR left out: thirdjam's vertex colour is material data and our toon shader
   multiplies the albedo by COLOR.
3. Facing -Z (engine rigs) instead of +X: one quarter turn of the body node.
4. Loop wrap: a looping clip of N keys goes from key N - 2 to key 0 (period N - 1 ticks). Not yet held against Unreal's
   looping player. Settled in round 2 with the blend-space player.
5. Homes: baked .scn / .res under engine/rigs/skater, outside assets/ and assets/manifest.json (campaign rule 6;
   contracts/ASSETS.md says otherwise).
6. TLRigSkater is not a TLRigs family and not a TLRigNode: its entry will be thirdjam's interface.
7. The clips are Unreal's compressed data (what the game plays), not the raw keys: up to 3.4 mm apart at the puck
   socket. This is thirdjam as it runs, listed so nobody is surprised by the 1.42 mm in the bake's check.
8. Content: the mesh, skeleton and 191 clips are the 15 Nov build's, byte-identical to HEAD 8dc713c6; the 11 clips HEAD
   changed (Board_Hit, CrossCheck_Release / _Whiff / _Wind, Fall_Heavy, Knockdown_Back / _Left / _Right_Heavy,
   Pass_Snap, Ready_Glide, Receive) are HEAD's.

WHAT IS NOT KNOWN OR NOT DONE
- The owner has not seen any of it. The Director has not seen any of it.
- Colour against the real game: not compared. thirdjam's figure was rendered twice here under its clay light rig (the
  editor world: jersey #2d71d9; a Simulate session: about as dark as ours, #0d30ae) and the two disagree, and both
  stand on my stand-in ice plane. A still of the running game is the reference; not taken this round.
- Only 4 of 202 clips were seen as pictures (rest pose, Stride, Glide, Shot_Slap). The other 198 are held by numbers
  alone (every key of every bone against Unreal's raw keys). Falls, get-ups, checks: nobody has looked yet.
- Cost per frame: not measured. Ten skaters: not tried.
- skater_body.scn is not byte-stable between two bakes (Godot gives scene nodes random ids); its content is (block 810).
  skater_clips.res and the table are byte-identical between bakes.
- The reference capture depended on an editor tick that did not always refresh the bones (21 stale shots in one run,
  59 in another). It now runs in a Simulate session and refuses a stale shot; two runs clean since. Two is not many.

FOR K1 (engine/cores/rink/SNAPSHOT.md, draft v0, the file as it stood at 17:19)
Checked against what the figure's caller reads, thirdjam's AJamSkater::ApplySimFrame (S/JamCore/Private/JamPawns.cpp:
464-746): the function reads 50 members of the skater's state (47 fields and the helpers IsDown, InBox,
SpinVisualYawDeg) plus StumbleFrames through StumbleFramesFor and the sim's frame number; every one of them is named in
the draft (checked by a script over the function's text, not by eye). Missing or to name:
 a. the constant ContactStumble = 2 (JamSim.h:719; ContactNone 0, ContactBump 1): the caller compares ContactOutcome
    with it; the draft gives the field, not the values.
 b. the helper InBox is described in the text but not in the "Skaters" shape line (PenaltyFrames > 0 does it).
 c. two inputs of the caller are not the sim's and so are rightly absent, but somebody must own them: the hit-stop
    frames (AJamSkater::ArmHitStop -> HoldArmed, JamPawns.cpp:231, called by the game mode) and the shown carrier
    (SetShownCarrier, S/JamGame/Private/PuckRead.cpp:140). That is K3's shell, or mine if the Director says so.

FOR K3 (placing the figure; not yet in code, to be fixed in round 2 with the driver)
With K1's suggested mapping (rink x -> Godot x, rink "z" -> Godot z, one metre = one metre) and the sim's Yaw (radians,
0 faces +x, growing towards +z), a figure that faces -Z at rest stands at Vector3(Pos.x, 0, Pos.y) with
rotation.y = -Yaw - PI / 2. The ice is y = 0 for the figure: its skate blades' lowest vertex is 1.3 mm above its origin.
The carried puck is drawn at socket_transform("puck_socket") (5.4 to 5.7 cm above the ice through the stride).

QUESTIONS FOR THE DIRECTOR
1. Who ports AJamSkater::ApplySimFrame (JamPawns.cpp:464-760: about 300 lines that turn a skater's state into the
   figure's calls, with the aim smoothing, the hit-stop hold, the whiff and hold timers)? It sits between K1's snapshot
   and my interface mirror. I propose it lives beside the figure (engine/rigs/skater), fed one snapshot skater a frame,
   so K3 passes the dictionary straight in. It needs K3's two inputs of point c above.
2. The driver is bigger than the brief knew, and it can be read. thirdjam's shipped driver is not a small state
   machine: HEAD's BP_SkaterVisual_TB1_P3 exports as 45 MB of text with 13,300 graph nodes in 152 graphs, and
   ABP_SkaterTB1_P3 has six states (Idle, Skate, Fall, FallForward, GetUp, GetUpFront) with 14 transitions under a
   stack of layers (aim, hold, pass, charge, carry, look-at, the stick's own bone, a whip on spine and neck), 37
   sequence players, 14 blend-space players and 18 bone modifiers. Two first readers fold the text into listings:
   engine/tools/skater/t3d_digest.py the Blueprint's event graph, 143 entries in 2,299 lines (UpdateMotion,
   SetStickAim, SK2Tick, SK3Fix, HoldTick, StopTick, FallPick, PlayGetUp, KnockDown, ...) with every constant in it
   (.tl/skater-export/driver/digest_bp/EventGraph.txt); engine/tools/skater/abp_digest.py the animation graph as a
   pose tree with the states and their rules, 219 lines (digest_abp/AnimGraph.txt). Example, as shipped:
   "Idle -> Skate when (Speed > 0.3) [crossfade 0.3]"; in SetStickAim "AimSent = FClamp(AngleDeg, -70, 70)" and
   "AimOver = FClamp(AimDes - AimAngle, -12, 12)" (the ledger's +-70 and 12 degrees, now with their lines). So round
   2 ports the graph itself instead of rebuilding from ledger notes. The listings are first versions and unchecked
   beyond the entries I read against the ledger (UpdateMotion, SetStickAim, the state rules). A call-for-call port of
   2,300 lines plus the animation graph is more than one round. Proposed order: skating (UpdateMotion, the
   Skate / SkateReady blend spaces, stops, braking), the stick (SetStickAim, SK2Tick, SK3Fix), then the puck verbs,
   then contact (checks, falls, get-ups), with the weapons, dash, dive, goalie and celebrations last or never (the
   stair's step 9: no ability until the plain game is good). Is that the order, and may the toys be left out?
3. The look: do we keep flat cel on this figure, or give it thirdjam's felt (a skater shader in engine/style, which is
   outside my scope)? Either way the number and the crest need a shader piece that reads the patch's UVs. Whose?
4. contracts/ASSETS.md against campaign rule 6 (deviation 5): the baked files are not in the asset manifest.
5. The exported Blueprint text is thirdjam's source in another form (93 MB, in .tl, not tracked). Track a digest of it
   in the repo for citations, or keep it out?

WHAT THE DIRECTOR SHOULD LOOK AT (all under docs/shifts/2026-11-24-night/lanes/K2-figure/media/)
- r1_pair_Stride_turn.jpg            the same key from four cameras, thirdjam above, ours below (the Simulate light)
- r1_pair_Stride_turn_editor_light.jpg  the same under the editor's light: the two thirdjam renders disagree in colour
- r1_pair_rest.jpg                   the rest pose at four angles: proportions and silhouette
- r1_pair_Shot_Slap_three.jpg        a slap shot at keys 0, 8, 16, 24
- r1_pair_Stride_side.jpg            Stride every third key from the side (19 pairs)
- r1_pair_Glide_side.jpg             the glide
- r1_stride_side_by_side.mp4         the film
To see it live: godot --path engine --position 0,1440 --resolution 1280x720 res://rigs/skater/gym/skater_gym.tscn --
--mode=play --clip=Stride --cam=three   (any of the 202 clip names; --team=1 for orange)

THE NEXT THREE THINGS THIS LANE WOULD DO
1. Port skating from the two listings: UpdateMotion, the Idle / Skate states, the Skate / SkateReady blend spaces with
   their rate scales, stops and braking, in the gym under speed ramps and turns, beside the running game.
2. The stick: SetStickAim with the Aim blend space (24 holds), SK2Tick / SK3Fix, the blade on the ice as a per-frame test.
3. A still of the running game for the colour, the number and the crest, and the eye over every clip family (falls,
   get-ups, checks) as sheets beside thirdjam's.
