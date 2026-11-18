# D5 judge verdict: entries P, Q, R

Judged blind on 18 Nov 2026. Godot 4.7.2 console, `--headless` only, one `--import` per worktree first. No git, no engine edits,
no folders opened beyond the three worktrees and the brief. Every repro ran (50 runs), except two in P that need a window (below).
I read the code at each cited line before deciding whether a printed failure is a real defect.

## Coverage and method notes

- **P**: `python docs/reports/astra-trial/d5/repro/run.py <case>`, run one case at a time. 7 of 9 ran headless and printed exactly what the
  entry quotes. **P2 `coldpad` and P7 `flatpad`** replace `--headless` with a 320x180 window. My brief allows `--headless` only,
  so I did not run them windowed. Run headless, both stop with a SCRIPT ERROR because the headless build skips the ground
  material, as P warns. I judged them another way:
  - P2 is the same defect as Q6. Q6's headless repro (`b_unloaded_pad.gd`) reproduces it, and I confirmed it in the code
    (`view_seam.gd:99` closes the hole while `landscape.gd:517-522` leaves the collider open).
  - P7 is confirmed only by reading the code. `landscape.gd:52-58` `ground()` never sets `tl_ground_mat` on the parent, so
    `view_seam.gd:86` returns early on the `--landscape=off` path. The only setters are `landscape.gd:223` and a walk test.
  - I counted both as verified. The scores without them are given below.
- **Q**: I ran every command exactly as written (23 `.gd` files, `r_team` with its arguments, `a_camera_cut_wall` at
  `--fixed-fps 120`, 4 `.py` files, 5 `.sh` files). All 32 numbered findings printed what the entry quotes. The run-to-run
  differences were trivial: `b_bridge_endpoint` printed one extra out-of-bounds error, with index 17 as well as 16.
  `r_clip_input` (not accepted by Q itself) also printed its FAIL; it is not scored.
- **R**: I ran all 10 scripts. Every one printed what the entry quotes. `r6` differed only in run-dependent frame numbers
  (81 frames, in-between x 7.43 and 19.85), which R predicts.

## Verdict per finding

Columns: entry's severity -> my severity.

### P (9 findings)

| # | Finding | Verdict | Severity |
|---|---|---|---|
| P1 | rebuilt stage game: replay `length` = sparse rows, the session writer rejects it, the recording is lost (`visit.gd:270`) | verified | high -> **medium** |
| P2 | a shut pad is drawn but has no collider; the walker falls 46 m | verified (via Q6's headless repro and the code; P's own repro not run, window) | high -> **medium** |
| P3 | `ground_cover` uses the axis-aligned box (AABB) of a rotated floor, so the hole is cut over open air (`draw_base.gd:223`) | verified | medium |
| P4 | a jump beside a trunk carries the look point into the crown; the camera sits inside the crown for 32 ticks | verified (the M2 "not done" note covers drawn branches outside the core, not the camera inside the solid core; the header promises "never goes inside") | medium |
| P5 | placed on a 65 degree bank: stands there and can jump (`world_body.gd:183`) | verified | medium |
| P6 | entering a game mid-slide leaves the slide pose on after the gate | verified | medium |
| P7 | flat-ground path: `shut_holes` returns early, the hole stays open | verified by code only (repro needs a window) | medium -> **low** (`--landscape=off` single shots) |
| P8 | `avoid_min` rejected by `setup()`, although API.md:416 lists it | verified | low |
| P9 | `walk_case.gd -- walk.jump` selects 0 cases and exits 0 | verified | low -> **medium** (breaks found-0 law, filtered runs only) |

### Q (32 findings)

| # | Finding | Verdict | Severity |
|---|---|---|---|
| Q1 | a stopped `world.sh same` child still prints PASS `world.same` (`selftest.sh:205`) | verified (`why` is empty when the child prints nothing; its exit status is never read; the gate's PASS-line count cannot catch it because a PASS line is printed) | high |
| Q2 | primitive shapes copied into the world space die with the pack's holder (`world_space.gd:263,317`) | verified (`_static` keeps no reference; `_keep` holds only concave shapes; colliders are re-copied only on first arrival, `view.gd:351`) | high -> **medium** (reach not run end to end) |
| Q3 | = P1 | verified | medium |
| Q4 | the bot's held `press` survives the hand-over to the person (`visit.gd:239-250`, no `release_all`) | verified | medium |
| Q5 | the camera is placed inside a body that the query sphere already overlaps at the look point (`tl_chase_cam.gd:158`) | verified (same root as P4) | medium |
| Q6 | = P2 | verified | medium |
| Q7 | = P3 | verified | medium |
| Q8 | = P5 | verified | medium |
| Q9 | = P6 | verified | medium |
| Q10 | a clip that omits a bone leaves its old rotation; the gaze correction accumulates (172 degrees); shoulder 12 degrees off after `cheer` | verified (`mix` treats a missing bone as identity, `_apply` writes only the present ones) | medium |
| Q11 | turning in the air twists the newly planted feet on landing | verified (`_yaw_seen` is not updated in the air; `land()` plants the feet, then `step()` applies the stale dyaw) | medium -> **low** (cosmetic) |
| Q12 | `boil.py` on a 720p clip: odd crop height, the frames are misaligned, a still picture reads as 100 % flips | verified | medium |
| Q13 | `selftest.sh walk.jmup`: 0 cases, exit 0 | verified | medium |
| Q14 | = P9 | verified | medium |
| Q15 | a road ending near the river: out-of-bounds read aborts `build()` (`landscape.gd:288-289`) | verified | medium -> **low** (no shipped input does this) |
| Q16 | a 2-triangle floor covering the plot is dropped by the corner-only "wholly outside" test (`draw_pictures.gd:396-401`) | verified | medium |
| Q17 | `pad_h` falls back to the LIFTED plot origin (`landscape.gd:103`) | verified (`view.gd:176-185` lifts by `-rim`). The entry's "Reach" text for this item is a corrupted copy of Q2's | medium -> **low** (shipped walks set `pad_h`) |
| Q18 | = P8 | verified | low |
| Q19 | `snap()` keeps a stale `_heading`, so the first tick after a teleport and turn is wrong | verified | low |
| Q20 | `use_velocity`: an exact reversal never turns the camera (`lerp(h,-h,0.07)` normalises back to `h`) | verified (latent public option) | low |
| Q21 | every road is graded with the first road's half width (`village_terrain.gd:131-133`) | verified | low |
| Q22 | a filtered `rig.*` claim reads a stale `kit.bot.json` | verified | low |
| Q23 | `blink_detect.py` erosion uses 4 neighbours, not the 8 its docstring promises | verified | low |
| Q24 | `blink_detect.py` drops the exact sky mask when no sampled frame has more than 50 magenta pixels | verified (heuristic edge) | low |
| Q25 | `blink_detect.py` crashes when the capture size changes mid-run | verified | low |
| Q26 | a stale `_slide_t` makes a later walk-off emit a second `end_slide` | **repro-ok-not-a-defect** (Q states it has no visible effect; the only consumer, `visitor.gd:259`, ignores it; harmless today) | low -> none |
| Q27 | a biped first ticked late keeps its eyes shut until its next blink cycle (`tl_rig_biped.gd:255-265`) | verified | low |
| Q28 | `expression=blink` at build is ignored (`_face(1,0)` instead of `_expr()`, line 73) | verified | low |
| Q29 | runtime `colors` does not recolour the stick | verified | low |
| Q30 | `review.gd:105`: a red skater cannot be shown | verified (tool) | low |
| Q31 | in the held run-slide pose the trailing hand is 0.31 m above the floor; doc and RIGS.md say "on the floor" | verified (cosmetic) | low |
| Q32 | a 90 degree turn in one tick: one interpolated camera frame lands inside a box | verified | low |

### R (9 findings)

| # | Finding | Verdict | Severity |
|---|---|---|---|
| R1 | = P6 | verified | medium |
| R2 | a pit with walls steeper than 55 degrees: slope mode refuses every jump, trapped for good (`world_body.gd:149`) | verified (a soft-lock; whether the shipped terrain has such a pit is not shown, as R says) | medium |
| R3 | `TLBall.place` / `TLBiped.place` / `tl_vehicle` never call `reset_physics_interpolation()`; now that interpolation is on project-wide, a teleport is drawn as a glide | verified (`project.godot:30`; the only resets are in visitor, chase cam, view and draw) | medium |
| R4 | crown 0.3-0.55 m above the look point: the camera ends 0.04-0.96 m from the look point (inside his head) and pops to 8.71 m one cm higher | verified (same family as P4/Q5, plus the in-head symptom of the swing-up failing) | medium |
| R5 | on stage, the visitor camera avoids geometry in global coordinates against a space in landscape coordinates (`view.gd:394`) | verified | low |
| R6 | walking diagonally into a too-steep bank stops him dead instead of sliding along it | **repro-ok-not-a-defect**: the code says so on purpose (`world_body.gd:338` "refused, he stays where he was (a wall, as before)"; `:201` "he stops there"), and R itself notes it is kept behaviour. A feel complaint, not a bug | low -> none |
| R7 | = P8 | verified | low |
| R8 | a slide pressed on the edge tick keeps the slide pose through the fall | verified (`visitor.gd:259` gates `end_slide` on the previous mode) | low |
| R9 | the jump buffer is effectively 6 ticks, not BUFFER = 8 | verified (the decrement and the can-jump check run before landing in the same tick) | low |

## Distinct verified defects (de-duplicated)

| ID | Defect | My severity | Found by |
|---|---|---|---|
| D1 | `world.same` reports PASS when the world child stopped before hashing | high | Q |
| D2 | stage recording lost when the holder is rebuilt on stage | medium | P, Q |
| D3 | a shut pad is drawn with no collider under it: fall-through | medium | P, Q |
| D4 | the AABB of a rotated floor counts as rim coverage, so the hole opens over open air | medium | P, Q (R: unscored suspicion S1) |
| D5 | the chase camera ends inside, or nearly inside, a crown near the look point (start overlap ignored; in-head pull) | medium | P, Q, R |
| D6 | put at rest on ground steeper than the limit: he stands there and can jump | medium | P, Q |
| D7 | the slide pose stays on after a game visit | medium | P, Q, R |
| D8 | walk_case / selftest filter selecting 0 cases exits 0 | medium | P, Q (walk_case); Q (selftest.sh) |
| D9 | the world's copy of a pack's primitive colliders loses its shapes when the holder is freed | medium | Q |
| D10 | the bot's held injected press survives the hand-over to the person | medium | Q |
| D11 | bones a clip omits keep a stale rotation; the gaze accumulates | medium | Q |
| D12 | `boil.py` misreads odd-height crops (720p default) | medium | Q |
| D13 | a floor of a few large triangles is dropped from far pictures | medium | Q |
| D14 | slope-mode trap: no jump out of a steep-walled pit | medium | R |
| D15 | kernel `place()` teleports are interpolated (a glide) | medium | R |
| D16 | flat-ground path never shuts pending holes | low | P |
| D17 | `avoid_min` rejected by `setup()` | low | P, Q, R |
| D18 | visitor camera avoidance in the wrong frame while on stage | low | R |
| D19 | a slide on the edge tick: the pose is held through the fall | low | R |
| D20 | jump buffer 6 ticks, not 8 | low | R |
| D21-D35 | Q's other lows: land-turn foot twist, bridge endpoint crash, `pad_h` lifted fallback, `snap` heading, `use_velocity` reversal, first-road width, stale kit.bot, 4-neighbour erosion, sky-mask threshold, capture-resize crash, late-spawn eyes, build-time blink, stick colour, review red skater, slide hand height, interpolated camera frame in a box | low | Q |

That makes 37 distinct verified defects: 1 high, 14 medium, 22 low.

## Scores (verified high x5 + medium x3 + low x1, minus 2 per not-a-defect / not reproduced)

| Entry | Claims | Verified H/M/L | Not-a-defect / not repro | Score |
|---|---|---|---|---|
| **Q** | 32 | 1 / 13 / 17 | 1 (Q26) | **59** |
| **P** | 9 | 0 / 7 / 2 | 0 | **23** (19 if the two windowed repros P2 and P7 are not counted) |
| **R** | 9 | 0 / 4 / 4 | 1 (R6) | **14** |

Scope caveat: the task asked for defects in today's walker and terrain changes. Without git I cannot tell for certain what
changed today.
- Q marks five of its findings "may predate today": Q1, Q2, Q4, Q15, Q22. Without them, Q scores 46.
- Several of Q's rig and tool items (Q27-Q30, review.gd) look older than the gait work as well.
- P and R stayed in the named areas.
- Even counted strictly in scope, Q leads.

## Characterisation

**P**: Shallow in count but tight. Nine findings, every one real, with no false claims, a single runner script and short
printed proofs. Its severities run a notch high (the record and pad items are medium, not high), and two repros need a
window, so a headless-only reviewer cannot run them. For a developer it is very usable: each item names the exact line and
compares against a control, and it found most of the important walker defects (pad fall-through, steep rest, slide pose,
crown camera, rotated coverage).

**Q**: By far the deepest and broadest. 32 findings across kernel, world, rigs and the review tooling, every repro ran as
written, and it alone found the one gate-honesty high (`world.same`) plus several medium bugs nobody else saw (collider
shape loss, held bot press, gaze accumulation, boil.py, crossing faces). Precision is good but not flawless: Q26 is harmless
by its own admission, a few severities are inflated, one item's "Reach" text is a pasted copy of another's, and some items
fall outside today's change. For a developer it is the most useful backlog, though one that needs triage, and it wins
clearly.

**R**: Thoughtful physical reasoning: the slope-pit trap, the project-wide interpolation teleport and the jump-buffer
off-by-two are real and unique, and its prose explains mechanisms and reach honestly. It covers fewer areas than the others,
missed the pad, steep-rest and coverage defects that P and Q both found, and lost points on R6, behaviour the code documents
as intended. Its repros are clean, deterministic and easy to rerun, so its unique items are useful to a developer.

## Ranking

1. **Q** (59)
2. **P** (23)
3. **R** (14)
