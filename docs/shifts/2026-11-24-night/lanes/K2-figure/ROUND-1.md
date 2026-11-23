# K2 figure, round 1: thirdjam's skater is out of Unreal and stands in our engine (23 Nov 2026, 16:51 to 18:55)

## What stands

- **The export was not blocked.** A copy of the runnable build (785 MB without `Saved`) in `.tl/tj-export`, HEAD's 11
  changed clips put over it (the mesh, the skeleton and the other 191 clips are byte-identical in HEAD and the build),
  the copy's `.uproject` given `PythonScriptPlugin` and `GLTFExporter`. One commandlet run of
  `engine/tools/skater/export_skater.py` (about two minutes, `-nullrhi`) wrote the mesh (glTF and FBX), **202 of 202
  clips** as glTF, every clip's bone poses per key as JSON (the raw keys), the three blend spaces' sample tables, the
  sockets and the nine material instances' colours.
- **Baked into the engine** by `engine/tools/skater/build_skater.gd` (headless Godot): `engine/rigs/skater/skater_body.scn`
  (0.23 MB: 24 bones, 9 slots, 12,040 triangles, top vertex at 1.6371 m) and `skater_clips.res` (1.67 MB: 202 clips,
  6,923 keys at 60 a second, 112 s). Nothing resampled or compressed by us. The folder is 2.6 MB with the source mesh.
- **`TLRigSkater`** (`engine/rigs/skater/tl_rig_skater.gd`): the body under a quarter turn (faces -Z), nine `TLStyle`
  toon materials in thirdjam's own slot colours, `play_clip` / `tick` / `pose_at`, thirdjam's three sockets. Frame-driven.
- **The gym** (`engine/rigs/skater/gym/skater_gym.tscn`): one skater on flat ice, four fixed cameras, stills, sheets,
  a shot list.
- **thirdjam's own render of the same shots** (`engine/tools/skater/reference_capture.py`): the Unreal editor poses its
  own figure from the clip at the key under the game's clay light rig and photographs it from the same four cameras.
  `pair_sheets.py` and `pair_film.py` put the two side by side.
- **The numbers that say it is the same figure in the same pose:**
  - 33 shots (rest, Stride every 3rd key, Glide, Shot_Slap) x 9 points (pelvis, head, hands, feet, stick bone, puck
    socket, head socket): Unreal's posed component against ours, worst **0.08 mm**; 59 shots of Stride, worst 0.09 mm.
  - Every bone of every key of all 202 clips against the raw keys read in Unreal: joints within **0.19 mm**, a point
    37 cm out on each bone's own axes within 1.42 mm (that gap is Unreal's own animation compression: the glTF holds
    the compressed clip the game plays; the raw keys lie up to 3.4 mm away at the puck socket, ours 0.08 mm from the
    posed component).
  - Over the whole Stride cycle the stick's lowest vertex is 1.3 to 4.5 mm above the ice and the skate blades' 1.2 to
    9.0 mm: never under it.
- **Gate:** selftest block 810 (`rig.skater.body`, `.clips`, `.ref`, `.play`) 4 of 4; `rig.skater.ref` shown red twice
  (the puck socket moved 1 cm: 0.01001 m; the body turned 0.18 degrees: 0.00500 m). Fast tier green. **The full tier
  is not green** (kernel selftest stopped by its 30-minute cap at 121 of 122 with 0 failed; the old hockey pack's
  frame budget 1.106 ms against 1.0, as in every full run on this machine since 22 Nov): REPORT.txt, "Gates".
- **K1's `SNAPSHOT.md` (draft v0, the file of 17:19):** every one of the 50 members of the skater's state that
  `AJamSkater::ApplySimFrame` reads (JamPawns.cpp:464-746) is in it. What the figure's calls need that is not a
  snapshot field is in the report (three items).
- **The shipped driver can be read.** `export_driver_text.py` wrote HEAD's `BP_SkaterVisual_TB1_P3` (13,300 graph
  nodes in 152 graphs) and `ABP_SkaterTB1_P3` as text into `.tl/skater-export/driver/`, and two first readers fold it
  into listings: `t3d_digest.py` the event graph (143 entries, 2,299 lines), `abp_digest.py` the animation graph (six
  states, 14 transitions, the layer stack; 219 lines). It is much larger than the brief's sketch of it.

## What my eye rejects (looked at: `media/r1_pair_*.jpg`, the film)

In ours:
1. **The back patch is blank and the chest has no crest.** thirdjam's jersey material draws the number (7) and a round
   crest; ours is a flat toon material. A skater without a number is not finished.
2. **The face is inked too hard.** The mouth line and the nose outline are as heavy as the body's contour; from the
   front the mouth reads as a moustache. thirdjam's face is two dots and a soft smile.
3. **Cream trim in shade turns grey-brown** (the back patch at Shot_Slap keys 8 and 16 beside the cream stripes).
4. **Flat cel, no felt.** thirdjam's figure is felt and clay (mottled, soft rim); ours is flat colour with an ink line.
   Same shape, another material. I do not reject cel on this mesh (it reads cleanly at 4.6 m), but the owner knows the
   felt one: he should see both (`r1_pair_Stride_turn.jpg`).
5. **The palette is not settled.** Under the editor's light thirdjam's jersey measures #2d71d9 and ours #0d30ae, its
   stick is light wood and ours dark; in the Simulate session its jersey is as dark as ours. Neither of thirdjam's two
   renders here is the game. A still of the running game is the reference for colour (next round).
6. The gym's light is a low sun with a long shadow, not an arena.
7. A pale drop on the cheek in the side views (the toon highlight on the ear piece): it reads as a tear.

In the reference pictures (my tool, not thirdjam): the figure stands on a stand-in plane with thirdjam's ice material
(wet ripples in the Simulate session, a red band), not on the game's rink.

No defect of shape or pose in any of the 92 pairs (33 at 480 px a tile, the 59 Stride keys at 240 px and as the film):
same silhouette, blade on the ice, hands on the stick.

## What went wrong on the way (kept, because the tools now guard it)

- `-ExecutePythonScript` quits the editor as soon as the script returns: the capture is started by the copy's start-up
  script and runs on editor ticks.
- **The first Stride film's reference was wrong for 21 of 59 keys**: the editor had not refreshed the bones and kept
  the pose of key 29; a later run stayed at the rest pose for all 59. The numbers showed it (0.41 m at the foot), not
  the picture at a glance. The capture now poses in a Simulate session, takes a shot only when the component stands
  where the clip's own pose says (within 1 mm), marks a shot stale otherwise, and `pair_sheets.py` fails on a stale
  shot. The two final runs: 59 of 59 and 33 of 33 fresh.
- My first reading of raw against compressed was the wrong way round (corrected in `build_skater.gd`).
- A script error in a headless Godot `-s` run does not end the process: every such run is under `timeout`.

## Deviations (so far)

1. Materials: `TLStyle.flat_material` per slot in thirdjam's base colour (jersey = the team colour, helmet = team x
   0.75 in linear light, from the shipped driver's `SetTeam`; this round's pictures were made with the brief's 0.5 on
   both sides, so both helmets are a little darker in them than they will be), not `M_SkaterTB1Jersey` / `M_Toon` (felt, clay bump, rim, emissive, number, crest). Reason: our
   look is cel through TLStyle (brief); the number and the crest need a shader piece.
2. The mesh's vertex colour (thirdjam's material data: felt mask, panel number, edge mask) is moved to CUSTOM1 and
   COLOR left out: our toon shader multiplies the albedo by COLOR.
3. The figure faces -Z (engine rigs); thirdjam's faces +X. A quarter turn of the body node, nothing else.
4. A looping clip of N keys wraps to key 0 after key N - 2 (period N - 1 ticks). Not yet held against Unreal's own
   looping player (which may show key N - 1 in place of key 0 on the wrap; the two differ by the loop join, 0.42 cm for
   Stride). To be settled with the blend-space player in round 2.
5. The baked resources live in `engine/rigs/skater/` (campaign rule 6), not under `assets/`, and are not in
   `assets/manifest.json`; `contracts/ASSETS.md` forbids `.scn` / `.res` in an asset directory. No rule table needed
   an edit (the gate looks only at `assets/`). The Director words the contract.
6. `TLRigSkater` is not a `TLRigs` family and does not extend `TLRigNode`: its entry will be thirdjam's interface.

## Next (round 2)

1. The driver: `IJamSkaterVisual` call for call, the Skate / SkateReady / Aim blend spaces from the exported tables
   (`engine/rigs/skater/source/blendspaces.json`: 14 + 14 + 24 samples with their rate scales), the states and the
   action takes from the ledger, a gym harness that drives every state from scripted motion.
2. Port from the shipped driver's own graphs (the two listings), not from notes.
3. A still of the running game for the colour, and the number and crest on the jersey.
