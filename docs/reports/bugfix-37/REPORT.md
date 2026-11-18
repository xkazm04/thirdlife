# bugfix-37: the 37 defects of the astra-trial bug hunt (18 Nov 2026, 20:20-21:05)

One Opus builder. It ran five Opus sub-lanes on disjoint files (cam, walker, world, rig, runner) and did the gate-honesty
defects (D1, D8, Q22), the two Python tools and the seams itself. Each sub-lane's details are in `lane-<lane>.md`. The
evidence is in `JUDGE-D5.md` and the hunters' folders `hunt-P/`, `hunt-Q/` and `hunt-R/`. Their repro `.gd` files are
renamed `.gd.txt`, the house convention for scripts kept as evidence. This report was saved by the Director from the
builder's final message, because the builder could not write report files.

**Result:** 35 fixed, 1 fixed with an edge left (Q24), 1 deferred to the owner (Q31). Q26 and R6 were ruled not defects
and left alone. The judge's "D21-D35" row lists 16 items, so they are named here by their Q number. Every new regression
case was checked against the unfixed code, where it fails.

| D-id | defect | status | regression check | before -> after |
|---|---|---|---|---|
| D1 | `world.same` says PASS when the world child stopped | fixed; the same guard added to the bare world verdicts in blocks 090, 120, 130, 140, 150 | `gate.world_same_stopped`, `gate.stopped_{world_walk_proof,world_compact,p11_world_alone}` | PASS -> `FAIL world.same: world.sh same exited 143; hash lines alone 0 of 4, together 0 of 12` |
| D2 | stage recording lost on a rebuild on stage | fixed (runner/visit.gd) | `runner.stage_record_rebuilt` | no file -> length 20 |
| D3 | shut pad drawn with nothing to stand on | fixed | `ground.shut_pad_solid` | feet -11.80 -> 0.00 |
| D4 | bounding box of a rotated floor counted as rim cover | fixed | `ground.rotated_cover` | cover 1.000 / hole 42.5 m -> 0.333 / 0 |
| D5 | camera inside or nearly inside a crown | fixed (owner choices below) | `cam.wall_start`, `cam.crown_band`, `cam.canopy_jump` | in-wall 7.00 -> 0.05; band 0.04-0.96 m -> 8.71 m; ticks in crown 32 -> 22 (only while the look point itself is inside) |
| D6 | at rest on a too-steep bank: stands and can jump | fixed | `walk.steep_rest` | grounded 120/120 -> 0/120, slides 9.6 m |
| D7 | slide pose stays on after a game visit | fixed | `walk.stage_pose` | `slide` -> `''` |
| D8 | a filter selecting 0 cases exits 0 | fixed (selftest.sh exits 2; walk_case) | `gate.empty_filter`, `gate.walk_case_filter` | exit 0 -> exit 2 |
| D9 | world copy of primitive colliders loses its shapes | fixed | `ground.ledger_shapes` | nan -> 0.5 |
| D10 | bot's held press survives the hand-over | fixed | `runner.stage_handover` | held 120/120 -> 0/120 |
| D11 | bones a clip omits keep a stale rotation; gaze piles up | fixed | `rig.bugfix.pose_rest`, `rig.bugfix.gaze` | neck 172 deg -> 28 deg; shoulder 12 deg -> 0 deg |
| D12 | boil.py misreads odd-height crops | fixed | `rigs/review/boil_check.py` (tool test) | 100 % flips on a still -> 0 % |
| D13 | a few-triangle floor dropped from far pictures | fixed | `ground.crossing_faces` | 0/0 -> 2/2 triangles |
| D14 | no jump out of a steep-walled pit | fixed (feel question below) | `walk.slope_pit` | never out -> out at tick 44 |
| D15 | `place()` teleports drawn as a glide | fixed | `runner.place_no_glide` | 2-3 in-between frames -> 0; hashes unchanged |
| D16 | flat-ground path never shuts pending holes | fixed | `ground.flat_holes` | hole 27.5 m -> 0 |
| D17 | `avoid_min` rejected by `setup()` | fixed | `cam.avoid_min` | 2.5 m -> 4.0 m |
| D18 | visitor camera avoids in the wrong frame on stage | fixed | `cam.rebase` | pulled to 4.58 m -> 8.71 m |
| D19 | slide on the edge tick keeps its pose through the fall | fixed | `walk.edge_slide` | `slide` -> `''` |
| D20 | jump buffer 6 ticks, not 8 | fixed | `walk.jump_buffer` | 7-8 ticks early lost -> jumps |
| Q11 | in-air turn twists the feet on landing | fixed | `rig.bugfix.land_turn` | -30 deg -> 0 deg |
| Q15 | road ending near the river aborts `build()` | fixed | `ground.bridge_end` | SCRIPT ERROR -> builds, no bridge |
| Q17 | `pad_h` falls back to the lifted plot origin | fixed | `ground.pad_lift` | -5.00 -> 0.00 |
| Q19 | `snap()` keeps a stale heading | fixed | `cam.snap_heading` | 0 m -> 8 m behind |
| Q20 | exact reversal never turns the camera | fixed | `cam.reverse` | 7 m ahead -> 7 m behind |
| Q21 | every road graded with the first road's half width | fixed | `ground.road_width` | 7.19 -> 19.98 |
| Q22 | a filtered `rig.*` claim reads a stale kit.bot.json | fixed | `gate.stale_kit_claim` | stale 99 m/s passed -> re-run, 10.4 m/s |
| Q23 | blink_detect erodes with 4 neighbours, not 8 | fixed | `walks/blink_detect_check.py` | 14 px -> 0 |
| Q24 | exact sky mask dropped when few sky pixels show | fixed with an edge left (`--skymask` flag) | `blink_detect_check.py` | with the flag 0 holes; the hunter's repro without the flag still FAILs |
| Q25 | blink_detect crashes on a capture size change | fixed | `blink_detect_check.py` | traceback -> totals |
| Q27 | late-spawned biped keeps its eyes shut | fixed | `rig.bugfix.spawn_face` | 0.07 -> 1.00 |
| Q28 | build-time `expression=blink` ignored | fixed | `rig.bugfix.build_blink` | 1.00 -> 0.07 |
| Q29 | runtime `colors` does not recolour the stick | fixed | `rig.bugfix.stick_color` | false -> true |
| Q30 | review scene cannot show a red skater | fixed | `rig.bugfix.review_team` | blue -> red |
| Q31 | slide's trailing hand 0.31 m above the floor | deferred to the owner (look); doc comment and RIGS.md corrected | none | no arm angle gets the hand below 0.095 m without leaning the torso |
| Q32 | one interpolated camera frame inside a box on a 90 deg turn | fixed | `cam.cut_wall` | 1 frame -> 0 |

## Gates on the final worktree tree
`tl check --tier full` exited 0. Every step completed what it found:

| step | result |
|---|---|
| arch | 12/12 |
| assets | 4/4 |
| cards | 3/3 |
| devx.test | 225/225 |
| foreman | typecheck clean; 210/210 tests |
| kernel.selftest | 219/219 (main had 180: 39 new cases) |
| kit.selftest | 91/91 |
| packs | 2/2 packs, 33/33 verb runs; hockey hash unchanged |
| perf | 2/2 on a quiet machine |
| seeds | 39/39 |
| item.selftest | 91/91 |
| ui.selftest | 77/77 |
| world | 8/8: world = alone |

## Test figures that moved (nothing was loosened)
- `walk.canopy`: nearest camera distance 1.91 -> 2.83 m (D5).
- `walk.jump`: the buffered second jump fires on tick 38, not 39 (D20).
- Village terrain (Q21): 5 of 58,015 vertices moved, by at most 3.1 cm, near a spur road.
- D11: shoulders return to rest after `cheer`.
- D14: a slope jump also pushes him away from the face (`SLOPE_JUMP_PUSH`).
- Caches rebuild once per machine: the rim cache key is now `|cover2`; PIC_VERSION is 15.
- No state hash moved.

## Questions for the Director
1. KERNEL_API stays 1.8 and no `TL*` member was added. `TLRigBipedMesh._stick_mesh` is underscored to avoid a 1.9 bump
   even though another file calls it. D18 makes the chase camera work in its parent's frame when the parent is a 3D node;
   an explicit `avoid_frame` option would be 1.9.
2. New internal members: `SLOPE_JUMP_PUSH`, `add_pads()`, `pad_rim()`, `faces_in_disc()`, `bridge_span()`, and an
   optional `stat` argument on `add_faces()`. Should API.md:310 say that TLBiped can jump from a slope?
3. D2: an input freed outside the tree is recorded with length = last frame + 1. Making it exact needs a hook in tl_input.gd.
4. Q24: boot.gd sits exactly at its 600-line budget. One more line would let the sky mask be detected automatically.
5. The Python tool checks need numpy, PIL and ffmpeg, so they are not in the gate.
6. An early version of block 350 nested itself: about 230 of the builder's own bash processes ran for a few minutes before
   it stopped them. The block now has a guard against nesting.

## For the owner
- D14: he can jump out of a steep pit, but not hop up a steep bank (he might wall-jump up a narrow V). Keep it, lower the
  push, or allow one slope jump per touch of walkable ground?
- D5 camera, three choices for his eye: the camera ignores a crown while his head is inside it; with a wall right behind
  him it comes close to his head, never inside the wall; it never swings below head height.
- Q31: should the slide's trailing hand touch the floor? That needs the torso to lean.
- New findings, not fixed: in a V channel narrower than his capsule he wedges in the air for good (same on main); in the
  held slide the lowest body point is 0.151 m below the floor; when a pad is swapped for the game's floor under him, a
  higher floor may hold him inside it for one tick.
- Not run (they need a window): repros P2 and P7, `site.solid`, the windowed tour.
