K6 arena and sound, round 1 (the hall): REPORT (23 Nov 2026, 19:49 to 21:55)
Worktree C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-arena, branch hk-arena, cut from hokej at 8f3a59f.
Nothing committed (the Director lands). LANDABLE ROUND 1.

OUTCOME
thirdjam's hall stands round the rink in our engine and in the pack: the barn, the stands, 664 fans, the lamps, the
benches, the penalty boxes with their clocks, the scorer's table, the goal lights, 73 board caps, and the rink's own
ice, boards, kick plate and red cap in thirdjam's materials, lit by thirdjam's rig by its numbers. First side-by-side
36 minutes into the two-hour box. The export was not blocked. The round is the hall only: no sound yet (round 2).
My tree does not have the figures, the HUD or the felt skater that hokej has gained since it was cut: every picture
of ours here shows K3's capsules or an empty rink.

LOOK AT (docs/shifts/2026-11-24-night/lanes/K6-arena/)
  r1_pair_boards.jpg           along the boards, full size: thirdjam's game | ours. Start here.
  r1_sbs_1.jpg, r1_sbs_2.jpg   8 poses from thirdjam's camera log: its game still | its world by scene capture | ours
  r1_pair_end_far.jpg          the far end close up (fans, goal light, boards)
  r1_pair_corner.jpg           a corner from above (ice, boards, kick plate, cap)
  r1_game_frames.jpg           the pack itself (`tl.sh capture`, frames 120, 300, 920, 1380) with K3's stand-ins
  r1_first_sbs.jpg             the first side-by-side of 20:25, before any look work (for the record)
  ROUND-1.md (what my eye rejects, deviations, the probe table), PIECES.md (the table of pieces)
To see it move: node devx/bin/tl.mjs play hokej

ACCEPTANCE (round 1's share)
1. The hall is thirdjam's, same pieces in the same places: MET.
   PIECES.md lists 48 groups (980 instances, 516,834 triangles) with their thirdjam actor and component, 11 rink
   surfaces, 18 lights. Selftest core.rink.arena.places holds the places to thirdjam's SOURCE numbers, not to the
   export (benches at +-0.0833 x length on the +y side scaled 0.1 x length / 12, boxes at x = -+3, the table between,
   goal lights behind each end, round(perimeter / 3.6) = 73 caps on the board top's middle line, 56 stand pieces and
   664 fans from ASSETS.md, the four key spots and eight side lamps where M_Ice's own lamp table has them).
   8 poses looked at (6 asked): no piece missing or out of place.
2. My eye's list of what still differs: ROUND-1.md, nine items. The three that matter most:
   a. K3's markings lie on the ice in K3's paint (solid blue crease, a 4.5 m blue centre circle thirdjam does not
      show, a darker goal), and the centre line and blue lines are now painted twice.
   b. Our darks are lighter and bluer than thirdjam's (the roof and upper walls show plank edges as dots; crowd coats
      are grey-blue, not black).
   c. No mirror in the ice (thirdjam: screen-space reflections), no bloom on the lamps, a contour line on the near hall.
3. Frame cost stated: MET. 1280 x 720, RTX 4090, shared machine, mean of 90 frames a pose over 8 poses: the hall
   adds 0.18 ms GPU and 0.08 ms CPU a frame; the 664 fans are 0.07 ms GPU and 0.04 ms CPU of that. A first run under
   other load read 0.63 to 0.98 ms GPU for the hall. Not measured: any other machine, any other resolution.
4. Size stated: MET. engine/cores/rink/arena 5.0 MB (limit 40): arena.scn 0.86, four textures 4.1, arena.json 0.09.
5. Existing style shaders unchanged, new files only: MET. No file under engine/style/shaders is modified (git); the
   style pin blocks pass (below).
6. hokej lint, smoke, bots: MET. `tl check --tier fast`: NOT MET, red on `arch` and `devx.test` for the reasons below.
Not in this round: the event-to-sound table, the audio files and the kernel audio API (round 2), the commentator,
the goal lamp, the net shake and the rocking caps (round 3).

GATES (all on the final tree, 21:47 to 21:55, after the Director's list of 21:45)
  tl.sh lint  --pack=engine/packs/hokej     PASS (0 bypasses)
  tl.sh smoke --pack=engine/packs/hokej     PASS (3600 frames, state hash 79a699ba1b92ec17)
  tl.sh invariants                          PASS (79a699ba1b92ec17)
  tl.sh bot, the pack's seven tests         7 of 7 PASS: bot_match_hand (5460 frames, 19657a920ad7853a), bot_gym_hand,
                                            bot_rule_w_away, bot_rule_s_lock, bot_rule_aim, bot_rule_aim_anchor,
                                            bot_tj_replay
  The idle and the match hashes are K3's round-3 values: the hall is visual only.
  selftest block 840 (new)                  5 of 5 PASS: core.rink.arena.pieces, .places, .materials, .rink, .light.
                                            Shown red once: TL_ARENA_EXPECT_FANS=665 -> FAIL core.rink.arena.places
                                            "664 fans, expected 665".
  style pin blocks (selftest filter surf.)  14 of 14 PASS: surf.model, .model_classic, .edges, .keys; celsurf.
                                            classic_files, .model, .model_classic, .pic_key, .pic_key_classic,
                                            .palette, .globals, .paint, .rails
  tl check --tier fast                      FAIL, exit 1:
    FAIL arch [12/12]: three rules red.
      scope-claims: .claude/sessions.json on this branch has hk-shell and hk-hud overlapping. Not this lane's file.
      api-v1: the new public class TLStyleArena and the new method TLCores.part need a new KERNEL_API. Left to the
        Director, who numbers it (1.25).
      api-index-fresh: docs/generated/API-INDEX.md is stale for the same additions (not regenerated, as ordered).
    FAIL devx.test [229/229]: 226 pass, 3 fail, the same causes read through the tests (arch.test.mjs: "the
      checked-in API description is what the sources say", "scope-claims", "real tree: green").
    PASS assets [4/4], PASS cards [3/3]. NOT RUN foreman.typecheck (foreman/node_modules missing in this worktree).
  tl check --tier full                      NOT A RESULT. Started 20:50, stopped by me at 21:46 on the Director's
                                            order while it was in `packs`; no step line was written. Nothing is
                                            claimed from it.
  After those runs one change was made: the plot rule moved out of hall_rig.gdshaderinc into hall_plot.gdshaderinc
  (for K7, below). Checked after it: the four poses compared are pixel-identical to the sheets (max difference 0),
  selftest 840 5 of 5, smoke PASS with the same hash, `tl.sh capture` PASS.

CHANGED FILES
New, the core:   engine/cores/rink/arena/rink_arena.gd, arena.scn, arena.json, tex/T_Clay_WoodGrain_M.png,
                 tex/T_Ice_Scratch_M.png, tex/T_Clay_Dent_N.png, tex/T_Clay_Thumb_N.png, review/arena_case.gd
New, the style:  engine/style/tl_style_arena.gd (class TLStyleArena), engine/style/shaders/hall_rig.gdshaderinc,
                 hall_plot.gdshaderinc, hall_surface.gdshader, hall_ice.gdshader, hall_crowd.gdshader,
                 hall_bulb.gdshader
New, the tools:  engine/tools/arena/bake.sh, export_arena.py (inside Unreal), arena_prep.py, build_arena.gd, shots.gd,
                 pair_sheets.py, probe_pixels.py, master_digest.py
New, the test:   engine/tools/selftest.d/840-rink-arena.sh (block 840; 845 is not used)
Edited:          engine/kernel/api/tl_cores.gd (+17 lines appended), engine/kernel/API.md (+7 lines in section 24),
                 engine/style/STYLE.md (+23 lines appended), engine/packs/hokej/scripts/main.gd (three call sites)
Lane folder:     STANDUP.md, ROUND-1.md, PIECES.md, REPORT.txt, seven JPG sheets
Not in git:      .tl/tj-export (the build copy with HEAD's content, 824 MB, kept for the audio export),
                 .tl/arena-export (the dump, 28 MB). The 680 raw game stills are deleted; the 8 used are in .tl/ref-game.
Rebake: `bash engine/tools/arena/bake.sh - <dump folder>` gives arena.json byte for byte; arena.scn has the same
content with other internal resource ids (its bytes differ from run to run).

FOR THE MERGE
1. main.gd, three call sites (my tree's line numbers; hokej's file has moved, so by the text they sit next to):
   a. a member, after `var replay_i: int = -1` (my line 39):
        var arena                # lane K6: thirdjam's hall, the core's own part (ctx.cores.part("rink", "arena")); visual only
   b. in _pack_setup, IN PLACE OF the line `rink_gen.build(ctx.root, rk, gym.get("hall", {}))` (my lines 50-53):
        arena = ctx.cores.part("rink", "arena")
        rink_gen.build(ctx.root, rk, {} if arena != null else gym.get("hall", {}))
        if arena != null:
            arena.build(ctx.root, {"rink": rk})
      (the plain dark box of gym.json "hall" must not be built with the hall: its walls stand 6 m from the boards,
      inside the stands)
   c. in _pack_tick, IN PLACE OF the line `if frame == 0 and gym.get("hall", {}).has("light"):` (my lines 89-91):
        if frame == 0 and arena != null:
            arena.light(ctx.root)
        elif frame == 0 and gym.get("hall", {}).has("light"):
      (K3's `TLStyleHall.apply(ctx.root, gym["hall"]["light"])` stays under the elif)
2. Kernel API lines added (no version line and nothing under docs/generated touched):
   engine/kernel/api/tl_cores.gd, appended at the end:
        const PARTS: Dictionary = {"rink": {"arena": "res://cores/rink/arena/rink_arena.gd"}}
        func part(id: String, pname: String) -> GDScript
   engine/kernel/API.md, section 24: one bullet (7 lines) on `ctx.cores.part`, above the `ctx.cores: TLCores` bullet.
   engine/style/tl_style_arena.gd, a new public class TLStyleArena: set_rig(lights, exposure, gain, gain_shadows),
        tone(c, gain, gain_shadows), set_exposure(exposure), set_cheer(plus, minus, seconds), post(anchor, opt),
        surface(p), ice(p), crowd(p), bulb(p); constants MAX_LIGHTS, SURFACE_KEYS, ICE_KEYS, CROWD_KEYS, BULB_KEYS,
        POST_GRADE, POST_INK.
   hokej's 1.21 `ctx.cores.view_script` is not in my tree: if it is the same kind of door, fold `part` into it.
3. K7's felt skater in the hall's light. How I want it done:
   a. One include. `engine/style/shaders/hall_rig.gdshaderinc` now holds only the rig (uniforms rig_n, rig_keys,
      rig_pos[24], rig_dir[24], rig_col[24], rig_exposure, rig_wrap, rig_gain, rig_gain_shadows; rig_lux_part,
      rig_lux) and the film curve (hall_tone). body_felt.gdshader should `#include "hall_rig.gdshaderinc"` and drop
      its own copy of those. The plot rule (`instance uniform vec4 tl_plot`) is no longer in that file, so a figure
      shader with its own plot include does not declare it twice.
   b. One value. `rink_arena.rig(tone_gain)` returns {lights, exposure, gain, gain_shadows, sky}; the hall itself
      now takes its rig from it. The one line to add is in rink_arena.gd `build`, straight after
      `TLStyleArena.set_rig(r["lights"], r["exposure"], r["gain"], r["gain_shadows"])`:
          TLStyleFelt.set_rig(r["lights"], r["exposure"], r["gain"], r["gain_shadows"], r["sky"])
      (`sky` = {intensity 0.35, colour linear from sRGB 255, 200, 150}; shape it as K7's parameter wants).
      I did not add it: TLStyleFelt is not in my tree and the file would not parse.
   c. Two things K7 must know. `exposure` already carries TONE_GAIN 6.0: a figure lit at the rig's bare exposure
      would be six times darker than the hall. And TLStyleArena.set_rig puts the lights that cast shadows first
      (rig_keys = 4): if TLStyleFelt keeps its own arrays it should take them in the same order or ignore rig_keys.
   I can do a and b myself as the first act of round 2 once my tree is on the merged hokej.
4. Not checked against the merged hokej: K5's HUD under the hall's grade, K2's figures on my ice (their shadow comes
   from the style sun, which arena.light points straight down), K7's skater beside the hall's surfaces.

BEHAVIOUR CHANGES
- `tl play hokej` and every windowed run of the pack show the hall in place of K3's plain dark box; the roof light
  K3 set from data/gym.json (#a88b7e x 1.0) is replaced by the rig's (#ffe6ba x 1.22); data/gym.json is not edited
  and its "hall" block is not read while the core has the arena part.
- While the hall is up the installed style's grade and ink are changed for the whole picture (no plum wash, no olive
  fill, no split toning, saturation and contrast 0.95, vignette 0.15, contours gone by 34 m). This reaches the
  figures too. Whether it reaches K5's HUD depends on the HUD's canvas layer against the grade's (layer 1): not checked.
- No test expectation moved. No state changed: the hall draws, the core simulates.

DEVIATIONS (full list with reasons: ROUND-1.md)
1. TONE_GAIN 6.0, a factor on thirdjam's exposure that is not derived (the picture is six times too dark without it).
2. Unreal's film curve per channel on sRGB primaries; no AP1 space, glow, red modifier, bloom, depth of field, SSR.
3. The sky light is not ported. 4. No engine light; no shadows from the rig; one sun shadow on the ice for four.
5. Vignette 0.35 set as 0.15. 6. The style's grade and ink changed for the whole picture. 7. Felt fibre at its mean.
8. M_Trim by parameters only. 9. The fans' far level unused. 10. Ice, boards, kick plate drawn twice (over K3's).
11. HEAD's content on the 15 Nov binaries. 12. Baked files in engine/cores/rink/arena, outside assets/.
13. TLCores.part added in K1's file.

FOR THE OWNER TO LOOK AT
r1_pair_boards.jpg first (his game on the left, ours on the right, same camera), then `tl play hokej` on the merged
branch. There is no sound yet.

QUESTIONS FOR THE DIRECTOR
1. The markings. thirdjam's clay ice paints its own centre line, blue lines, goal lines and a 9 m centre circle; the
   crease is pale with a red rim; nothing shows a 4.5 m centre circle. My ice now paints the first four. Should K3's
   tj_rink.gd drop what the ice paints and take thirdjam's marking colours (arena.json: MID_BasicShapeMaterial_0 red
   (0.6, 0.02, 0.02), _1 blue (0.02, 0.08, 0.6), _2 light blue (0.35, 0.55, 0.85)), or should the arena draw them?
2. The skins. Should tj_rink.gd stop drawing the ice, boards and kick plate (an option of its build) now that the
   arena draws them in thirdjam's materials? And the goals: thirdjam's own goal and net meshes are in arena.scn,
   hidden (`build(..., {"goals": true})` shows them over K3's).
3. Is `ctx.cores.part` the door you want for a core's presentation (the sound table of round 2 would be the second
   part), or should it be `view_script`?
4. The style's grade and ink for a hall are set for the whole process by TLStyleArena.post. Is that the wanted
   place, or should a style file for the hockey hall carry them?
5. TONE_GAIN: do you want a lane to find the factor in Unreal's chain, or does a measured 6.0 stand? K7's figure
   stands or falls with the same number.

NEXT THREE
1. Round 2, the sound: export the sources, the event table and the MetaSound rules; kernel audio files, loops,
   music and voice channels; wire from the snapshot events; a minute beside a minute.
2. First in round 2, on the merged hokej: the shared rig include and the one `TLStyleFelt.set_rig` line; then look
   at the figures and the HUD in the hall and write what my eye rejects.
3. Round 3: the cheer driven by goal events, the goal lamp, the net shake, the rocking caps, the commentator; the
   fans' far level and the darks on the way.
