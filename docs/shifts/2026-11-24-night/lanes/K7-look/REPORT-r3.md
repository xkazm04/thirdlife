K7 look, REPORT round 3 (24 Nov 2026): landable round 3
Worktree C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-look, on hokej f9d2db9, nothing committed.

OUTCOME

The figures' shadows on the ice are thirdjam's now: one a key light, away from that light's foot, long where the game's
are long. The blue's hue and the line at the figure's edge are closed as well. Two things are not at parity: the lying
man's shade is softer and fainter than thirdjam's, and the level of the shoulder and patch near the boards.
Two of lane K2's selftests (rig.skater.verbs.oracle, .pin) fail in my tree; they fail the same on a clean export of HEAD
without any of my edits, so they are not this round's. See GATES.

HOW THIRDJAM MAKES THEM (found)

- Four key spots cast them (Key_P3_Clay_1..4: 13 m up, x = -33.75, -11.25, 11.25, 33.75, straight down, 5200 cd,
  cones 16 / 62 degrees, radius 30 m, source radius 60 cm, virtual shadow maps); the other fourteen lights cast none.
  A 1.6 m figure 10 m from a key's foot throws a 1.4 m shadow; between two keys he throws two, half strength each.
- The skater's contact shade, widened to 2.2 x 0.95 m and turned along the body while he is down.
- The streak towards the camera under a standing figure is mostly the ice's screen-space reflection. Not ported.
Ours had one shadow, from the style's sun straight down: a blob under the feet, nothing beside a lying man.

WHAT WAS BUILT

1. TLStyleHallKeys (engine/style/tl_style_hall_keys.gd, new): the rig's shadow-casting lights as real spot lights with
   shadow maps (4096 px a key). They light nothing; hall_ice.gdshader reads each one's shadow and takes away that key's
   own share of the rig's light there. Open ice is unchanged to the grey level.
2. The contact shade's lying form (TLRigSkaterLook.ContactShade), driven by the flag lane K2's falls already keep.
3. hall_film.gdshaderinc (new): Unreal 5.9's whole film pipeline; the felt figure goes through it. The game's blue has
   red as high as green; the curve alone left red at half of green.
4. With felt figures the hall's ink lines end at the eye (thirdjam draws none).

PAIRS, LOOKED AT (the running game | ours before | ours now); figures stand where the game's stood (its camera log; the
others by the ray through their feet)

- Striding, 10 m from a key (media/r3_shadow_striding_game_before_after.jpg): same side, same length, about as dark;
  ours a little crisper at the rim.
- Standing, the faceoff between two keys (r3_shadow_standing_...): the streak towards the camera and the wingers'
  sideways shadows are there; ours a little darker and more of a shape under the centre man.
- Lying (r3_shadow_lying_...): a wide soft shade round him where there was none; fainter and softer than thirdjam's.
- In the match itself (r3_match_still_ours.jpg, tl capture of the hokej pack).
- Colour of the 7 at the game's frame 5360 (r3_colour_ink_7_game_round2_round3.jpg): jersey #101347 (game #121242,
  round 2 #111847), helmet #14164e (#181746, was #141c4e), shoulder #1c1e5e (#16174a, was #1c245f), patch #b09066
  (#c5a373, was #ac8f69). Hue closed; the shoulder is still about a quarter too bright, the patch an eighth too dark.
  He stands a metre from the lit boards there; what they throw on him is not in our light.
- The edge line (r3_edge_ink_on_and_off.jpg): gone.
Not looked at: shadows in motion (no film), a shadow across the boards' foot or a goal, the far end of the rink.

GATES

selftest look.skater (block 850): 8 passed, 0 failed (new: look.skater.shadow ratio 0.805 with the keys;
  look.skater.shadow_red: the same check fails with the keys off, ratio 0.944)
selftest core.rink.arena: 5 passed, 0 failed.  surf.classic_source, celsurf.classic_files: PASS
selftest rig.skater: 8 passed, 2 FAILED:
  FAIL rig.skater.verbs.oracle: worst 210.86 cm at frame 552 skater 0 puck_socket, 5341 of 5400 rows within 1 cm
  FAIL rig.skater.verbs.pin: worst 152.86 cm at frame 119 skater 0 puck_socket, 682 of 720 rows within 1 cm
  NOT this round's: a clean export of HEAD f9d2db9 (git archive, none of my edits, its own import) fails the same two
  cases with the same figures (210.86 cm at frame 552; 152.86 cm at frame 119), and rig.skater.verbs passes with the same
  state hash af496e74ecbfdcba in both. The native core's DLL is not the cause either (the integration tree's newer
  build gave the same). So the two fail on hokej f9d2db9 as it stands on this machine: lane K2's to look at.
tl check --tier fast: FAIL arch (api-v1: new class TLStyleHallKeys; api-index-fresh) and the 3 devx tests that mirror
  it, as expected until the class has its kernel number; assets 4/4, cards 3/3, foreman.typecheck PASS.
Full tier NOT RUN.

A TEST EXPECTATION MOVED

look.skater.shaders_kept now also leaves engine/style/shaders/hall_ice.gdshader out of "must equal HEAD": this round
edits it in marked lines, as the Director allowed. Every other tracked shader and style file is still held.

KERNEL LINE (1.28, for the Director; I edited no version line and no generated file)

New class TLStyleHallKeys (engine/style/tl_style_hall_keys.gd): static install(anchor, lights, opt) -> int,
receive(mesh_instance), count(anchor) -> int, clear(anchor); constants NODE, DEFAULTS, WIDER_DEG, RANGE_K.
tl arch reports this one finding. TLRigSkaterLook gained an inner class ContactShade; arch did not list it.

FILES OF OTHER LANES TOUCHED (all marked "K7")

- engine/style/shaders/hall_ice.gdshader (K6): one uniform (key_shadows), one header line, light(): the directional
  branch gated, a spot-light branch between "K7 begin" and "K7 end".
- engine/cores/rink/arena/rink_arena.gd (K6): in light() the lines between "K7 begin" and "K7 end" (the keys, the
  receive, the ink); in rig_lights() one key (source_radius_m).
- engine/cores/rink/arena/review/figure_view.gd (mine, in K6's folder): --keys, --ink, --keyopt, --cost,
  --check=shadow, "down" in a shot.
Nothing of lane K2's.

COST

Ten striding skaters in the hall, 1280 x 720, RTX 4090, 600 frames, twice each: with the keys GPU 0.74 ms and render
CPU 0.60 to 0.63 ms a frame; without 0.58 and 0.39 to 0.46. About 0.3 ms. Shadow atlas 8192 px (32-bit).
Not measured on a lesser card.

DEVIATIONS (ROUND-3.md has the eight with reasons)

One filtered rim width instead of the 60 cm source's widening penumbra; the shadow's darkness shared out by each key's
luminance share (exact for one key); 4096 px maps; no reflection in the ice; the keys change the game viewport's
shadow atlas and the renderer's spot shadow filter; the film pipeline's saturation and contrast left to the screen
grade; figure and hall go through two film functions; the hall's ink ended when the look is felt.

FOR THE DIRECTOR

1. rig.skater.verbs.oracle and .pin fail on hokej f9d2db9 itself here (see GATES): for lane K2.
2. Lane K6: hall_film is there for the hall's own shaders (one call a shader in place of hall_tone). Neutrals do not
   move; its wood and crowd would. K6 should look before switching.
3. HALL_INK is overridden when the look is felt. If K6 wants lines on the boards back, it is one "if" in light().
4. The keys set the viewport's shadow atlas to 8192 px; in a world of several games that is the whole world's
   viewport. Meant for a game alone, as TLStyleHall is.

NEXT THREE

1. The lying shade against thirdjam's (darker and tighter), and a film of shadows in motion.
2. The ice's reflection of the figures (with lane K6): it is half of what reads as shadow at the faceoff.
3. The boards' bounce on a figure beside them (the shoulder and patch level).
