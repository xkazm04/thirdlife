K7 look, REPORT round 4 (24 Nov 2026): landable round 4
Worktree C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-look, on hokej b1ea774, nothing committed.

OUTCOME

Built: every shadow's rim is now the key light's source radius (hard at the caster's foot, wider with its height), so
the lying man has thirdjam's tight dark edge; a film of the shadows in motion; the puck's halo shown through the
hall's exposure (near white, as thirdjam's).
Measured and NOT built: the ice's reflection of the figures (2 to 9 per cent of the ice's level) and the boards'
bounce (it cannot move the patch or the shoulder the right way). Both are the Director's call; reasons below.

1. SHADOWS (media/r4_shadows_game_round3_round4.jpg: the game | round 3 | round 4, twice the size; LOOKED at)
- Lying: a tight dark edge under the legs and the arm, as thirdjam's (round 3: a faint wide halo).
- Striding: the same shadow as round 3, harder at the skates and soft at the head.
- Standing at the faceoff: still darker and more of a shape than thirdjam's faint streak.
- How: the engine's soft shadows with the light's 60 cm source; a key's shadow map covers 56 degrees instead of the
  light's 62 (texels 0.94 cm instead of 1.6, which is what took the steps out of the rim); beyond the map that key's
  light is not shadowed. Open ice unchanged to the grey level (18 points, the far corners among them: difference 0).
- My eye rejects: at twice the size a fine stair on the striding shadow's upper rim (not seen at the game's size);
  the faceoff shadow's darkness.

2. IN MOTION (media/r4_film_shadows_in_motion.mp4, 4 s; ours alone)
Looked at as stills: r4_film_shadows_every_20_frames.jpg and r4_film_12_frames_in_a_row.jpg. The shadow stays at the
skates, turns and lengthens with the stride; nothing pops or swims in those. Not compared frame by frame with
thirdjam's film. I cannot watch the mp4: for the Director's eye.
In the match itself: r4_match_stills_ours_halo_and_shadows.jpg (tl capture of the hokej pack, frames 90 and 400).

3. THE PUCK'S HALO: a tone question, settled
thirdjam's MI_Trim_PuckHalo (M_Trim, Emissive 18, TeamColour 0.75 / 1.0 / 0.15) through the hall's exposure and film
curve is #f7fbdd. Ours was the palette's emissive lime outside that curve. The hall now dresses the halo disc with
thirdjam's numbers through its own emissive surface. Brightest pixels: ours now #ebedd0, thirdjam's in lane K3's still
#e7eac2, ours before #e9f567. Not verified: that instance's ClayGlowMul and base tint (the master's are used).

4. THE ICE'S REFLECTION: measured, not built (media/r4_thirdjam_ice_reflection_close.jpg)
Under a figure thirdjam's ice changes by 2 to 9 per cent in linear light (three figures of frame 1500 against the ice
beside them). My round 3 line "half of what reads as shadow at the faceoff" was wrong: that streak is the two key
shadows, which ours has. The engine's screen-space reflections cannot see the felt figures; what would work is the
figure drawn a second time, mirrored and flattened onto the ice along the eye's ray, a tenth as strong: one more
shader and a second mesh a figure, for a tenth of a difference. Not done without your word.

5. THE BOARDS' BOUNCE: not built
The gap was the 7 of frame 5360: patch an eighth too dark, left shoulder a quarter too bright. The patch looks up and
back and the boards are 1.2 m high beside him; the too-bright shoulder is the one away from the boards. The bounce
would move neither the right way. I also doubt the comparison at that precision: one box a surface, two figures in
different poses. It needs both figures in one pose before more light is added.

GATES

selftest look.skater 8 passed, 0 failed; rig.skater 11 passed, 0 failed (the two that failed on f9d2db9 pass here);
core.rink.arena 5 of 5; surf.classic_source and celsurf.classic_files PASS.
tl check --tier fast: exit 0, arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck PASS.
Full tier NOT RUN. No test expectation moved this round.

KERNEL LINES: none. No new public member (tl arch passes): TLStyleHallKeys gained options only (size_k, cone_deg) and
its defaults changed (soft true, filter 5).

FILES OF OTHER LANES TOUCHED (marked "K7", round 4)
- engine/style/shaders/hall_ice.gdshader (K6): one uniform (key_cone_cos); a block at the end of fragment() between
  "K7 begin (round 4)" and "K7 end"; in light() the chosen key's share is zero outside the map's cone.
- engine/cores/rink/arena/rink_arena.gd (K6): in light(), inside the K7 block, the halo's material.
- engine/cores/rink/arena/review/figure_view.gd (mine): --film, size_k and cone_deg in --keyopt.
Nothing of lanes K2's or K3's: the halo is dressed from the hall's side, the pack's files are as they were.
Also: engine/style/tl_style_hall_keys.gd, engine/style/STYLE.md (mine).

COST
Ten striding skaters in the hall, 1280 x 720, RTX 4090, 600 frames, twice each: GPU 0.80 ms a frame with the keys
against 0.58 without (round 3: 0.74); render CPU 0.43 to 0.47 against 0.35 to 0.37. Not measured on a lesser card.

DEVIATIONS (ROUND-4.md)
A key's shadow map stops at 56 degrees (thirdjam's lights shadow to 62); the source's size is given as diameter x 4,
looked at beside 4 and 12, not derived from the engine's source; the halo's ClayGlowMul and base tint are the master's;
no reflection in the ice, no bounce off the boards.

FOR THE DIRECTOR
1. The reflection: build it (a tenth of a difference, one shader, a second mesh a figure) or leave it?
2. The colour comparison needs thirdjam's and our figure in ONE pose before any more light is added: lane K2's oracle
   can pose thirdjam's own figure; shall I take that as the next round?
3. Lane K3: the halo is no longer the pack's lime inside the hall; its DEVIATIONS note in gen/tj_rink.gd can go.
4. The film is for your eye.

NEXT THREE
1. Figure colours with both figures in one pose (the oracle's), every slot, then the light that is really missing.
2. The faceoff shadow's darkness against thirdjam's (theirs is fainter than the rig's numbers give us).
3. The reflection, if wanted.
