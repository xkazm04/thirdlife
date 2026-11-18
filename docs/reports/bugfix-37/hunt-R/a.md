# D5 arm a: final report (13:25, 18 Nov 2026; started 13:05:57)

## Acceptance
1. **findings.md: met.** Nine numbered findings, each with file:line, the failure, a severity, a reproduction command
   and what it printed. Four are medium, five low:
   1. medium: the slide pose is kept after a game visit (visitor.gd:208-216, 138-157). R4 prints rig clip 'slide'
      after 2 s standing at the gate and 2 s walking.
   2. medium: steep-walled pits trap him, because there is no jump in slope mode (world_body.gd:149). A 62 deg pit
      0.8 m deep: slope mode for 1200 of 1200 ticks, 0 jumps. Control, 45 deg walls: out at tick 62.
   3. medium: physics_interpolation=true is project wide, but TLBall/TLBiped/TLVehicle.place do not reset
      interpolation, so teleports are drawn as a glide. R6: 2 drawn frames with the puck between x 0 and x 30.
   4. medium: the visitor camera dives into his head under a pine crown 0.3-0.55 m above the point looked at (crowns
      are in the mask, visitor.gd:91). Camera 0.04-0.96 m from the point looked at; 8.71 m with mask 1, or 1 cm
      higher.
   5. low: on stage, a re-based landscape makes TLChaseCam avoid the ground at the wrong place
      (tl_chase_cam.gd:174-183 against view.gd:394). Pulled in 4.13 m.
   6. low: walking at an angle into a too-steep bank stops him dead instead of sliding along it like a wall
      (world_body.gd:331-333). 1.51 m along it, against 9.36 m along a wall.
   7. low: `avoid_min` is listed in API.md 1.6, but TLChaseCam.setup rejects it ("unknown option", stays 2.5).
   8. low: a slide pressed on the edge tick keeps the slide pose through the fall (visitor.gd:259-261).
   9. low: the jump buffer is 6 ticks before landing, not BUFFER 8 (world_body.gd:145-150). k7 and k8: no jump.
2. **Reproductions run from the worktree root as written: met.** All 10 scripts under `repro/` were rerun at 13:24
   with `"$G" --headless --path engine --script ../docs/reports/astra-trial/d5/repro/<file>.gd`. Every one printed what
   findings.md quotes. R6's frame count and positions change between runs (headless frame pacing); the glide shows in
   every run. r4, r6 and r8 need the class cache once: `"$G" --headless --path engine --import` (3 s, writes the
   gitignored engine/.godot).
3. **Suspicions I could not reproduce: met.** Four, labelled in findings.md: S1 ground_cover with rotated sheets, S2
   hole shutting lags up to 9 frames, S3 replay depends on wall-clock collider slices (older than this change), S4
   re-pressed keys after a focus loss.

## Files changed (all new, none in engine code)
- docs/reports/astra-trial/d5/findings.md
- docs/reports/astra-trial/d5/a.md (this file)
- docs/reports/astra-trial/d5/repro/r1_cam_in_crown.gd, r1b_cam_crown_band.gd, r2_slope_pit.gd, r3_cam_avoid_min.gd,
  r4_clip_after_stage.gd, r5_cam_rebase.gd, r6_place_interpolated.gd, r7_bank_diagonal.gd, r8_slide_at_edge.gd,
  r9_jump_buffer.gd
- engine/.godot/ (class cache made by `--import`; gitignored)

## Rule breach to know about
My first shell command ran `git status` and `git log --oneline -3` (read-only) before I had read common.md rule 3
("no git commands"). There were no git commands after that.

## What I would do next
- Look for a real steep-walled pit in the shipped landscape (pad cut banks, river channel, ponds). Probe the world
  space with `ground_at` normals over a grid to turn finding 2 from a mechanism into a place on the map.
- Check which seed packs have no camera of their own, to say how often finding 5 is seen.
- Render a hockey face-off with interpolation on and off to show finding 3 in pixels.

## Cost
- Wall time from start to report: about 20 minutes (13:05:57 to 13:25), well inside the 75-minute time box.
- Tokens: not visible to me.

---
# Status log (newest at the bottom)

- 13:05:57 start; read brief. Note: ran `git status`/`git log` once in first command before reading the no-git rule.
- 13:10 R1 measured: chase camera pulled to 0.04-0.96 m from the point looked at when a crown bottom is 0.3-0.55 m above it (mask 1|4), 8.71 m with mask 1 or 1 cm higher. Next: slope trap (no jump in slope mode).
- 13:12 R2 measured: 62 deg pit 0.8 m deep traps him in slope mode 1200/1200 ticks, 0 jumps (45 deg control: out at tick 62).
- 13:14 R3 (avoid_min rejected) measured. Reading view.gd stage re-base vs camera avoid casts; rig clip ends.
- 13:16 suspicion list started; building engine/.godot class cache in this worktree (headless --import) to run visitor/rig repros.
- 13:16 R4 measured: slide clip survives a stage visit and put(); still slide after 2 s standing and 2 s walking. Next R5: camera avoid casts in re-based global coordinates.
- 13:17 R5 measured: re-based landscape pulls the camera in 4.13 m.
- 13:17 R6 measured: TLBall.place glide drawn in 2 of 80 frames (x 6.42, 18.84) with physics_interpolation=true.
- 13:18 R7 measured: diagonal into a 65 deg bank moves 1.51 m along it (wall: 9.36 m).
- 13:21 findings.md written (7 findings, 6 suspicions). Next: S1/S2 measurement, rerun all repros.
- 13:22 S1, S2 proven -> findings 8 (slide pose at edge) and 9 (jump buffer 6 not 8).
- 13:24 all 10 repros rerun as written, outputs match findings.md (R6 figures vary per run, noted). Times for R4-R7 above corrected to the nearest date reading (13:14:46, 13:17:55, 13:18:57). Final report at top.
