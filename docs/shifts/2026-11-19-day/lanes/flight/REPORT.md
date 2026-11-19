Lane flight, day of 19 Nov 2026 (d19-flight from main 1b3e055), 08:35-10:05 by the worktree clock. Nothing committed.
Route: Opus directing Astra (Codex, gpt-6.2-astra) for the mechanics; I modelled the wings in Blender and wired them in.

WHAT THE OWNER GETS
In the village walker, F toggles flight. On take-off the mechanical wings unfold over 0.5 s (30 ticks) and he lifts
about 2.5 m. Space climbs and C descends. W cruises at 5 x the run speed (45 m/s), reached smoothly in 1 s. A, D and S
move at run speed. Turns arc at up to 140 deg/s. The figure leans into the flight (12 deg at hover, 62 at cruise) and
banks into turns (up to 28 deg). The wings flap slowly at hover, hold a glide pose at cruise and bank with the turn. At
top speed the wing tips draw a small wind trail (the style's own ribbon). Descending onto ground lands him: the wings fold
in 0.6 s and he straightens up in 24 ticks. F in the air ends flight and he falls. The camera pulls back to 1.8 x and
lowers 6 deg with speed, eased. The crown and terrain rules still hold. The key hint names F.
Flight respects collision with terrain, trunks, rocks, walls, fences, buildings, plots' copied colliders and tree crowns.
The ceiling is 120 m over the ground. Descending into a plot below 12 m puts him at its gate, the same place Q leaves you.
From there he walks in and presses E, as after Q.
Packs: TLBiped (feel: walker only) gets fly(on), is_flying(), climb(v), option fly_scale (5.0), drive_from_input keys
fly / climb / descend. Kernel API 1.9, opt-in. A biped that never calls fly is unchanged: same positions over 600 frames.

ACCEPTANCE
1. Windowed clip <= 30 s: MET. clip.mp4 is 21.0 s and 1280x720. It shows take-off on the road at (-60, 2), the climb,
   and 5x cruise east over the village. He turns north and runs west along the bluff, makes a banked S among the trees at
   about 10 m, then turns south, descends and lands. He stands at (-183.7, -73.6), 13.6 m north of the parkour plot's edge.
   The clip was recorded on the final tree. Two runs gave identical marks (the path is deterministic). Over the 44 marks of
   the run, the camera was in a crown 0 times.
   Reproduce with: world.sh visit-test <lane>/wf_flight.json --devices=<lane>/clip.devices.json, TL_WINDOW_ARGS=--write-movie.
2. Stills of the wings folded, unfolding and cruising, with contact sheets: MET.
   - sheet_world.jpg holds 10 in-world frames: folded on the road, unfolding at 8 / 16 / 26 ticks, climb, cruise, bluff,
     banked S, descent, landed and folded. The same frames are in stills/a_..j_.
   - sheet_wings.jpg holds 12 close-ups from kernel/world/flight_review.tscn: folded back / three-quarter / side, unfold
     25 / 50 / 75 %, spread at hover, cruise, bank. Five of them are in stills/0x_.
3. Measured, each a permanent case (blocks 520, 521, 522, 530). I re-ran them all on the final tree: 11/11 PASS.
   - flight.ratio: run 9.000 m/s, cruise 45.000 m/s, ratio 5.000 (target 5.0 +- 0.1).
   - flight.accel: 95 % of cruise at tick 60, largest per-tick speed change 1.500 m/s, lift 2.526 m, glide to hover
     89 ticks, turn rate +140.0 / -140.0 deg/s.
   - flight.ceiling: Space held for 1,800 ticks gives 119.993 m over ground, and no tick goes higher.
   - flight.sweep: 20,800 ticks over 80 legs and 16 headings, 2 to 25 m over the ground, through the bluff, trees and
     buildings. 20,795 ticks flying, 15,583 at cruise, 77 blocked (he met things and slid). Capsule overlaps: 0. Camera in
     a crown: 0. Camera under terrain: 0. Camera's largest per-tick swing: 2.098 deg yaw, 2.085 deg pitch. Arm 1.800 x,
     pitch drop 5.997 deg.
   - flight.collide: at cruise into the bluff face, a trunk and a wall, he ends 0.351 m short of each (the capsule radius).
   - flight.land: fly_land with no overlap. The mask is 5 (incl. crowns) in flight and back to 1 after. F in the air
     gives fly_end and he falls to the ground. A crown is slid off and never landed on.
   - flight.gate: from 12.08 m into plot 1 he is put at the gate with 0.0000 m error, in ground mode, wings folding. He
     walks 8.74 m in (3.74 m inside) and E enters stage 1.
   - flight.biped: a TLBiped that never flies has the same 600-frame sha256 as before (896a9c9d...). A flying one gets
     ratio 5.000 and climbs 12.25 m. The input mapping works.
   - flight.replay: a recorded visit with F, W, Space and C replays to the same feet (delta 0.000 m).
   - flight.pose: lean 61.995 deg at cruise, at most 5.000 deg per tick. Bank +23.3 left, -26.4 right. The fly clip plays
     on all 341 airborne ticks and leaves on the landing tick. 24 ticks after landing: lean, bank, pitch, roll and offset
     are all exactly 0. The wings are on the back socket.
   - flight.wings: 17 parts, 1,236 tris. Unfold 30 ticks, fold 36. Largest tip move 0.197 m per tick. Span 4.39 m.
     Folded it stays behind his back inside his shoulders. Two runs pose the same.
   Each case failed on the unmodified tree: Astra ran the flight suite on 1b3e055 and got 0 passed, 9 failed. Seven
   failed at compile (old drive()/wish() signatures). The biped case reported fly=missing. My wings case has no file
   there.

GATES (final tree)
- check --tier fast: PASS. arch 12/12, assets 4/4, cards 3/3, devx.test 226/226, foreman.typecheck clean.
- check --tier full: 13 PASS, 1 NOT RUN.
  - foreman.test 210/210.
  - kernel.selftest 288/288. Main's last green was 277 found; mine is 277 + 11 flight cases.
  - kit.selftest 92/92 (main 91).
  - packs 2/2, with 35/35 verb runs.
  - seeds 39/39, item.selftest 91/91, ui.selftest 128/128.
  - world 8/8: world = alone. Astra compared all 8 hash and frame rows with unmodified 1b3e055 and found them equal (.tl/baseline-world.log); I did not repeat that comparison.
  - perf: NOT RUN in that run (machine BUSY, 94 %). Re-run alone it PASSED 2/2 (mix30, pile600 within tolerance; quiet:
    use 34 %).
  The visitor is never in a bot-mode world, so no pack hash moves.
- Windowed tour (world.sh tour tour --out-dir): PASS world.tour. 10 of 10 pictures. Every pack hashes as alone and the
  log replays the same.
- Line endings: all 19 modified files keep theirs. git diff --check is clean except boot.gd's CR, which the file has
  always had.

FILES
Mechanics (Astra, verified by me):
- engine/kernel/world/terrain/world_body.gd: the fly mode (take-off, cruise, turn limit, vertical, ceiling, swept
  collision incl. crowns, landing, events fly_start / fly_land / fly_end).
- engine/kernel/world/terrain/world_space.gd: drive() passes the flight intent through.
- engine/kernel/world/terrain/walker_space.gd: ground_at for pack bipeds (ceiling).
- engine/kernel/runner/visit.gd: the `fly` action on F, Space/C as climb/descend in flight, gate arrival from the air
  (line kind visit_fly_gate). E is ignored while flying. visit_path feet are printed to 1 mm (was 1 cm).
- engine/kernel/world/visitor.gd: flying / fly_t / fly_turn / fly_speed_k, the flight camera (arm and pitch eased by speed),
  flight_step signal.
- engine/kernel/api/tl_chase_cam.gd: an overridable _limit_lift hook that changes nothing by itself.
- engine/kernel/world/terrain/crown_camera.gd: it limits the camera's lift to 2 deg per tick only while the target flies.
- engine/kernel/api/tl_biped.gd: the 1.9 flight API (walker feel only).
- engine/kernel/runner/manifest.gd and engine/kernel/API.md: KERNEL_API 1.9 and the "Flight (addition in 1.9)" section.
- docs/generated/API-INDEX.md, API-V1.json, REPORTS.md: regenerated by Astra for the version bump (arch needs API-V1).
  Regenerate on main as usual.
- engine/tools/world.sh: visit-test also prints visit_fly_gate lines.
- engine/kernel/runner/flight_case.gd, flight_biped_case.gd, flight.devices.json: the case scripts.
- engine/tools/selftest.d/520-flight-body.sh, 521-flight-replay.sh, 522-flight-pose.sh: the case blocks.
Wings and look (mine):
- assets/engine/wings.glb, built by engine/tools/assets/wings_blender.py (Blender 4.2.1, like Pip). Registered in
  assets/manifest.json as engine.wings: mesh, 1,236 tris, first-party.
- engine/kernel/world/flight_wings.gd: attaches the wings to the rig's `back` socket through TLKitAsset and folds,
  unfolds, flaps, glides, banks and trails them, all counted in ticks.
- engine/kernel/world/visitor.gd (my part): the wings, lean and bank about his middle, the `fly` clip, and the
  straighten-up after landing.
- engine/rigs/biped/tl_rig_biped_moves.gd, engine/rigs/tl_rig_biped.gd, engine/rigs/RIGS.md: the new `fly` clip (loops,
  1.6 s) and its table row.
- engine/kernel/world/flight_wings_case.gd and engine/tools/selftest.d/530-flight-wings.sh: the wings case.
- engine/kernel/world/flight_review.gd / .tscn: a windowed look scene for stills. It is not in any gate.
- engine/boot/boot.gd: the key hint "F  fly (Space up, C down)". Astra reflowed the header comment to keep the file at
  600 lines, which arch requires.
- Lane folder: STANDUP.md, REPORT.txt, clip.mp4, clip.devices.json, wf_flight.json, sheet_world.jpg, sheet_wings.jpg,
  stills/ (15 JPGs). 8.3 MB in all.
Outside the brief's scope list, named: engine/kernel/world/flight_wings*.gd and flight_review.*, engine/tools/assets/
wings_blender.py, engine/boot/boot.gd (the hint), engine/tools/world.sh (one grep pattern), docs/generated/*. All are
new files or one-line edits that no other lane claims. Round 1 also edited tiers.gd; I reverted that in round 2, and its
diff is empty.

WHY BLENDER, NOT RIG PARTS
The wings are 17 moving parts: harness, two spars with truss struts, brass hinge barrels and twelve slats. Each needs
its pivot at a joint so it can fold. A Blender script gives that cleanly, the same way Pip was built, with flat faces
and palette-key materials drawn by TLKitAsset in the house toon look. Rig parts would mean procedural meshes inside
rigs/. Rigs may reference nothing outside themselves, so a rig could not load an asset anyway. The wings are therefore
a kernel part worn on the rig's `back` socket. Pack bipeds get the flight but not the wings, and API.md says so.

BEHAVIOUR CHANGES
- The walker always wears the folded wings on his back, as a compact bundle behind the backpack, hips to shoulders.
  Every walker picture changes. It is the sign of the ability. Owner, say if you want them hidden until F is pressed.
- visit_path feet are printed to 1 mm (was 1 cm). The replay case needs that precision, and no existing test changed.
- Stage entry is unchanged: E works only inside a plot. The air arrival uses the Q gate.

FOR THE OWNER TO LOOK AT
- Watch clip.mp4 first, then sheet_world.jpg and sheet_wings.jpg.
- In a window: `bash engine/tools/world.sh visit compact_village`, then F, W, Space and C. Mouse turns arc at 140 deg/s.

QUESTIONS FOR THE DIRECTOR
1. The exported game: export.sh copies only the landmarks' assets beside the exe, so the exe would fly WITHOUT wings.
   It prints the warning "wings.glb not found, flying without wings". Proposed one-line patch to engine/tools/
   export.sh (outside my scope, so not made): in the loop over landmarks, iterate over
   [...((walk.landscape || {}).landmarks || []), {asset: "assets/engine/wings.glb"}].
2. Should the folded wings show on the ground, or only from take-off on (see the first behaviour change)?
3. Flight is always available in the village. Should it be gated (unlocked, a pickup)? That is a design question.

NEXT THREE THINGS THIS LANE WOULD DO
1. Land the export.sh patch, then check the exported exe flies with wings (export.sh check plus a windowed run).
2. A take-off and landing feel pass: a short dust burst on take-off and landing (TLStyleFx dust), and wind audio by
   speed if the audio layer has a preset.
3. Wings for pack bipeds that opt in (TLBiped option `wings`), and an owner play-test of the speed and turn rate. 140
   deg/s may feel slow under the mouse at 45 m/s.

CODEX TOKENS PER ROUND (session 01a1f2be-875b-7f13-a5cc-da3f6eab8eda)
- Round 1 (mechanics, cases 520/521, gates): 207,715.
- Round 2, aborted start: no token line. It came up on the default model (gpt-6.2-sol) because resume did not carry -m.
  I stopped my own process after it had reverted tiers.gd and visit.gd's arrival code, and checked those edits.
- Round 2 (gate without the scheduler special case, case 522 flight.pose): 535,183. The resumed context counts again.
- Total counted: 742,898.
Lesson: `codex exec resume` needs -c model="gpt-6.2-astra" again, or it starts on the default model.
