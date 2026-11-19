# Third Life QA round 2

**15 defects reproduced twice on the affected code.** One high, twelve medium and two low. The high-severity finding (A1) lets a stopped camera suite report a pass. A3 and A15 show opposite failures at the same parkour beam. A11 clears a single 56° bank using two slope jumps.

| Last focused rerun in this worktree | Finding IDs |
|---|---|
| Still reproduce (7) | A1, A3, A5, A11, A12, A13, A15 |
| Pass after concurrent edits (8) | A2, A4, A6, A7, A8, A9, A10, A14 |

The defect and blame citations identify the failing lines at `9ea78b0`. Findings that changed during the hunt also name the current implementation and the retest result. Commands run from the worktree root in Git Bash. Each output block gives the observed final line on two separate runs. A proved failure exits 1. The GDScript wrapper runs Godot 4.7.2 headless through `timeout 180` and checks that its exit code agrees with the verdict. IDs retain their original assignments so other lanes can refer to them.

## A1. A stopped camera suite passes the kernel selftest

**High · Gate verdict · May predate 17 Nov? No.** Blame dates `engine/tools/selftest.d/310-bugfix-cam.sh:14` to 18 Nov. The pipeline loses the child status and line 22 issues a verdict from the selected case row alone. A child stopped immediately after that row still gets a green result. The suite promises a completion trailer in `engine/kernel/world/walks/bugfix_cam_case.gd:5`. A stopped run must never pass under `docs/GATE-HONESTY.md:17`.

**Reach.** The real `bash engine/tools/selftest.sh cam.wall_start` sources this block. The test substitutes only the child executable, emits the first row and terminates that child with SIGTERM. The signal is sent only to the fixture child itself.

**Repro.** `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/A1.sh`

```text
REPRO A1: FAIL child terminated by signal 15 after 1 case and 0 trailers; selftest exited 0
```

**Suggested fix.** Capture the child status before filtering output and require its completion trailer with matching counts before accepting any selected row.

## A2. The editor village drops the installed hockey game

**Medium · May predate 17 Nov? No (18 Nov).** `engine/boot/boot.gd:182` constructs a source path from the export name. The catalog explicitly maps `ice_hockey_three_against` to `engine/packs/hockey` at `engine/boot/games.json:11`. The hockey plot uses that export name at `engine/boot/village.json:16`. The other seven installed games resolve because their names match their source directories.

**Reach.** `boot.tscn` started in the editor binary without `--games` calls `_make_walk()`, which drops the unresolved plot at `boot.gd:208`. An export with the renamed game folder takes a different lookup branch.

**Repro.** [repro/A2.gd.txt](repro/A2.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A2`

```text
REPRO A2: FAIL editor boot resolves 7/8 installed village games; missing ice_hockey_three_against
```

**Suggested fix.** Resolve source-checkout plot names through the catalog’s `from` field. Keep the export-name lookup for packaged folders.

**Worktree retest.** `REPRO A2: PASS` after a concurrent edit. The changed code is at `engine/boot/boot.gd:182`.

## A3. C retries before the parkour runner touches the beam

**Medium · May predate 17 Nov? No (19 Nov).** `engine/packs/parkour/scripts/main.gd:109` checks speed, grounded state, checkpoint and a 0.6 m band. A runner who stops voluntarily inside that band qualifies. The pack promises a retry when the beam stops the player (`engine/packs/parkour/README.md:16`). At the test position the nearest capsule surface is still 20 cm from the beam.

**Reach.** The shipped pack’s `_pack_tick` and `_update_hud` share this predicate. The repro uses the built course, earns the two preceding checkpoints through the race logic, places the character at rest and taps the real slide action.

**Repro.** [repro/A3.gd.txt](repro/A3.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A3`

```text
REPRO A3: FAIL C sent a stationary runner 3.96 m backward with 0.20 m of clear air between capsule and beam
```

**Suggested fix.** Check for a recent blocked move into the near face, including the lateral extent and height of the opening. Use that result for the HUD and the retry.

## A4. A velocity-following camera faces the wrong way during slow travel

**Medium · May predate 17 Nov? Yes (10 Nov).** `engine/kernel/api/tl_chase_cam.gd:251` requires more than 0.02 m of travel in a single tick. Below 1.2 m/s it uses the target’s facing every frame, even during sustained sideways motion. The `use_velocity` option promises to stay behind the direction of travel (`tl_chase_cam.gd:33`, public option at `engine/kernel/API.md:427`).

**Reach.** Pack authors reach this through `ctx.cameras.chase`. The shipped `cam.reverse` regression enables the option but moves 0.1 m per tick. The seed-drive and hockey chase views use the default facing mode.

**Repro.** [repro/A4.gd.txt](repro/A4.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A4`

```text
REPRO A4: FAIL velocity camera trails by 0.00 m at 0.60 m/s and 7.00 m at 3.00 m/s; wanted 7.00 m at both speeds
```

**Suggested fix.** Accumulate sub-threshold travel or use a much smaller numerical tolerance. Preserve the facing fallback in `snap()` when no travel sample exists.

**Worktree retest.** `REPRO A4: PASS` after a concurrent edit. The changed code is at `engine/kernel/api/tl_chase_cam.gd:255`.

## A5. A downed walker accelerates on the ground

**Medium · May predate 17 Nov? No (18 Nov).** `engine/kernel/world/terrain/world_body.gd:156` restores a cached movement request whenever the incoming request is zero during the nine-tick minimum step. `TLBiped` sends exactly that zero when down. The cached run therefore overrides the forced brake. The public `down()` contract requires the figure to slide to a stop throughout the fall and rise (`engine/kernel/API.md:265`).

**Reach.** This is the public `TLBiped.create({feel = "walker"})` plus `down()` path. Parkour ships the walker controller and hockey calls `down()` on skaters. The repro combines the two supported options on a real grounded biped.

**Repro.** [repro/A5.gd.txt](repro/A5.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A5`

```text
REPRO A5: FAIL downed walker accelerated from 0.57 to 3.97 m/s in 6 ticks with movement released
```

**Suggested fix.** Give a forced brake or a down state a way to cancel the cached minimum step before the walker computes its speed.

## A6. Freeing the holder leaves a loose ball frozen in midair

**Medium · May predate 17 Nov? Yes (10 Nov).** `engine/kernel/api/tl_ball.gd:213` tests the holder against null before running the invalid-holder recovery. A freed Godot node compares equal to null, so recovery never clears `freeze`. The API describes possession followed by free motion (`engine/kernel/API.md:240`), and `tl_ball.gd:217` explicitly tries to release a missing holder. The test removes the hand ten metres above any floor.

**Reach.** `rink_api.gd:256` carries a hockey puck this way. Hockey keeps its skaters alive during normal play. A pack that despawns the held socket or carrier while keeping the ball reaches the failure.

**Repro.** [repro/A6.gd.txt](repro/A6.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A6`

```text
REPRO A6: FAIL ball has 0 holders but remains frozen for 30 ticks; drop 0.000 m
```

**Suggested fix.** Track possession independently of the node reference, or release on the holder’s `tree_exiting` signal. Make release unfreeze the ball even after the original holder is invalid.

**Worktree retest.** `REPRO A6: PASS` after a concurrent edit. The changed code is at `engine/kernel/api/tl_ball.gd:216`.

## A7. Hockey awards a goal above the net

**Medium · May predate 17 Nov? Yes (16 Nov).** `engine/packs/hockey/scripts/rink_api.gd:440` compares the puck’s x and z against the goal and ignores y. Its stated rule is that the centre lies inside the trigger volume (`rink_api.gd:434`, `engine/packs/hockey/README.md:54`). The real trigger is only 1 m tall. The test positions a loose puck above the trigger so that even its bottom clears it, then observes the score on the next pack tick.

**Reach.** `engine/packs/hockey/scripts/main.gd:468` calls this fallback on live match ticks. The repro starts the shipped match and stages the puck altitude directly. It does not establish how often a human shot reaches that height.

**Repro.** [repro/A7.gd.txt](repro/A7.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A7`

```text
REPRO A7: FAIL blue gained 1 goal with puck bottom 1.00 m above the goal volume
```

**Suggested fix.** Test y against the goal’s vertical bounds. Derive all three bounds from the same dimensions and centre used to construct the goal trigger.

**Worktree retest.** `REPRO A7: PASS` after a concurrent edit. The changed code is at `engine/packs/hockey/scripts/rink_api.gd:448`. The corrected clearance uses the cylinder’s shape centre and half-height. I repeated the measurement twice with the baseline scorer in a lane-local pack copy.

## A8. Hockey retains both match helpers after every unload

**Medium · May predate 17 Nov? Yes (16 Nov).** `engine/packs/hockey/scripts/main.gd:273` gives the possession helper a strong reference to the checking helper. `engine/packs/hockey/scripts/hits.gd:35` already holds the reverse reference. Both extend `RefCounted`, so neither reaches zero when its pack is destroyed. The ledger tier promises to keep only the plot record while the game is unloaded (`engine/kernel/world/TIERS.md:28`).

**Reach.** The repro loads the shipped hockey pack three times, calls the world holder’s production `unload()`, frees each holder and checks weak references. The same pair is constructed by `_build()` on a mode switch or match restart.

**Repro.** [repro/A8.gd.txt](repro/A8.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A8`

```text
REPRO A8: FAIL 6/6 match helpers survived 3 hockey pack unloads
```

**Suggested fix.** Make one direction a weak reference, or give one helper ownership and pass the other as an argument on the calls that need it.

**Worktree retest.** `REPRO A8: PASS` after a concurrent edit. The changed code is at `engine/packs/hockey/scripts/rink_api.gd:56`.

## A9. Seed Drive can boost repeatedly before its first nitro pad

**Medium · May predate 17 Nov? Yes (10 Nov).** `engine/kernel/api/tl_vehicle.gd:189` grants a whole tick of boost for any positive charge, and line 252 applies full nitro force. Releasing Shift for one tick in Seed Drive regenerates 0.000001 tanks, enough to trigger it again. The seed starts empty and specifies that only its pad refills the tank (`engine/seeds/seed_drive/scripts/main.gd:51`, `engine/seeds/seed_drive/data/tuning.json:12`).

**Reach.** The repro starts the shipped seed, holds gas and alternates the declared nitro action for 60 physics frames. All 29 active ticks occurred with wheels on the ground and zero pad visits.

**Repro.** [repro/A9.gd.txt](repro/A9.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A9`

```text
REPRO A9: FAIL 29 boost ticks in 60 frames before first pad (29 grounded); maximum charge on press 0.000001 tanks
```

**Suggested fix.** Require enough charge for the boost applied, or scale force to the energy available. Give this seed an explicit way to disable automatic recharge.

**Worktree retest.** `REPRO A9: PASS` after a concurrent edit. The changed code is at `engine/kernel/api/tl_vehicle.gd:191`.

## A11. Repeated jumps clear a single bank above the 55° walk limit

**Medium · May predate 17 Nov? No (18 Nov).** `engine/kernel/world/terrain/world_body.gd:302` adds a fixed outward impulse, then restores the full vertical jump at line 305. Touching the same face in slope mode permits another jump. Holding uphill run and tapping every 18 ticks clears an ordinary 56° bank and lands more than a metre past its rim. This contradicts the explicit D14 guarantee in `world_body.gd:12` and `docs/reports/bugfix-37/REPORT.md:93`. The fixture has one open face and no channel.

**Reach.** The village visitor’s `world_space.gd:409` and parkour’s `TLBiped._walker_tick()` use this mover. The bank is a controlled geometry fixture. The prior regression uses a 65° bank 8 m high.

**Repro.** [repro/A11.gd.txt](repro/A11.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A11`

```text
REPRO A11: FAIL topped a 2.8 m bank at 56 degrees on tick 304 with 2 slope jumps; ground-only control 0/800 ticks on top
```

**Suggested fix.** Track whether the walker has already used an escape jump on the current steep face, or constrain the launch and air steering so recontact cannot gain ground uphill. Retain the shallow-pit escape case as a control.

## A12. The game catalog accepts misspelled keys and explicit null

**Medium · May predate 17 Nov? Yes (16 Nov).** `devx/lib/gate/steps/world.mjs:23` iterates the catalog without validating the root key set, game key set or optional field types. The isolated fixture uses the shipped parkour manifest and changes one field per trial. All three malformed catalogs produce the same one-game list as the valid control. `contracts/README.md:39` requires omission for absent values and line 40 requires errors for unknown keys.

**Reach.** The `world` gate calls `readGames(ctx.REPO)` before launching the world comparison. The test exercises that reader directly with a lane-local catalog and does not run the full gate.

**Repro.** [repro/A12.sh](repro/A12.sh)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/A12.sh`

```text
REPRO A12: FAIL catalog reader accepted 3/3 invalid catalogs (extra root key, extra game key, null optional)
```

**Suggested fix.** Validate the catalog version, permitted keys, required strings and optional boolean before resolving paths. Reuse that validator in the export path.

## A14. An inactive hockey rink survives destruction of its pack

**Medium · May predate 17 Nov? Yes (16 Nov).** `engine/packs/hockey/scripts/main.gd:203` detaches the previous venue for reuse. A detached Godot node lives until explicitly freed. When hockey unloads, the holder frees its children, but the cached rink is outside that tree and its dictionary disappears with the entry. The ledger contract requires the pack to leave memory (`engine/kernel/world/TIERS.md:28`). The repro counts the old rink’s node tree after the holder itself has been freed.

**Reach.** The shipped `mode_big_ice` action rebuilds hockey with a different rink. The repro switches from the default venue, unloads the real holder, and observes the old rink through a weak reference. This leak concerns scene nodes, independently of the two RefCounted helpers in A8.

**Repro.** [repro/A14.gd.txt](repro/A14.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A14`

```text
REPRO A14: FAIL old rink still owns 63 live nodes after 1 mode switch and 1 pack unload
```

**Suggested fix.** When tearing down hockey, explicitly free detached cached venue roots. Apply the same ownership rule to other off-tree assets in the pool.

**Worktree retest.** `REPRO A14: PASS` after a concurrent edit. The changed code is at `engine/packs/hockey/scripts/main.gd:141`.

## A15. A runner holding forward against the beam can lose the retry prompt and the C press

**Medium · May predate 17 Nov? No (19 Nov).** `engine/packs/parkour/scripts/main.gd:109` requires instantaneous speed below 0.5 m/s. The walker repeatedly accelerates into the solid near face and is stopped again. Over 40 ticks its x position spans only 2.8 cm, yet the predicate hides the cue on 27 ticks. A C press on one of those ticks does nothing. `engine/packs/parkour/README.md:16` tells a blocked player to tap C. A3 covers a voluntary stop short of the beam. This case walks into the actual obstacle and keeps pressing forward.

**Reach.** The real race uses this predicate for input at `main.gd:72` and HUD text at `main.gd:119`. The regular-hand bot samples repeatedly and can eventually retry; a human’s single tap can be lost.

**Repro.** [repro/A15.gd.txt](repro/A15.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A15`

```text
REPRO A15: FAIL blocked for 40 ticks across 0.028 m; retry hint shown 13/40 ticks; one C press moved runner back 0.00 m
```

**Suggested fix.** Keep the blocked state stable while forward input meets the same face. Clear it when the character steps away, clears the obstacle or retries.

## A10. Camera avoidance uses parent-local units for a distance reported in metres

**Low · May predate 17 Nov? No (18 Nov).** `engine/kernel/api/tl_chase_cam.gd:122` measures the wanted distance after transforming it into parent coordinates. Line 156 publishes the difference directly as `avoid_pull`, documented as metres closer than wanted at `tl_chase_cam.gd:41`. Scaling the parent by two halves the reported retreat. The control uses the same wall and 31° parent yaw at unit scale.

**Reach.** `TLChaseCam.setup` with `avoid_space` reaches this through the D18 parent-frame path. The visitor uses that path for stage rebasing. Its shipped rebase test uses unit scale, so this case affects callers with scaled camera parents.

**Repro.** [repro/A10.gd.txt](repro/A10.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A10`

```text
REPRO A10: FAIL at parent scale 2 camera moved 4.60 m closer but avoid_pull reported 2.30 m; scale 1 error 0.00 m
```

**Suggested fix.** Measure the wanted and actual radii in world space for `avoid_pull`. Convert metre-valued avoidance settings consistently when building parent-space queries.

**Worktree retest.** `REPRO A10: PASS` after a concurrent edit. The changed code is at `engine/kernel/api/tl_chase_cam.gd:158`.

## A13. The six-tick coyote jump also fires on tick seven

**Low · May predate 17 Nov? No (18 Nov).** `engine/kernel/world/terrain/world_body.gd:161` tests `air_ticks <= COYOTE` before incrementing the counter. The departure tick sets it to zero, so the seventh subsequent tick still sees six. The specified allowance is six ticks after leaving walkable ground (`docs/reports/walker-feel/M.md:46`). The repro measures from the first returned `air` tick and checks an immediate jump before landing.

**Reach.** The village visitor and the parkour biped both call the shared `drive()`. The existing ledge test samples offsets four and twelve, which both give their expected results.

**Repro.** [repro/A13.gd.txt](repro/A13.gd.txt)

`bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A13`

```text
REPRO A13: FAIL airborne jump accepted 7 ticks after leaving the ledge; limit 6 ticks (offsets 6/7/8 accepted 1/1/0)
```

**Suggested fix.** Use the elapsed offset of the current tick when checking the coyote limit. Keep the last permitted and first expired offsets as paired cases.

## What held in the focused probes

- **Walker jump buffer and ledges.** In the stock `walk_case_b.gd` suite, a second press eight ticks early jumped on landing tick 38. Nine and ten ticks early expired. Starting at rest on 65° gave 0 grounded ticks out of 60 and 7.54 m of descent. At 50° the walker stayed grounded for all 60 ticks with 0.00 m of drift. The 62° pit escape, the 65°/8 m bank fixture, clearing the slide pose at stage handover, and sliding on the exact departure tick all passed. A11 and A13 document different geometries or tick boundaries.
- **Camera avoidance and snap.** The seven stock `bugfix_cam_case.gd` cases passed, including walls 0.1 and 0.2 m behind the look point, 21 crown heights, the canopy jump, translated/yawed unit-scale rebase, snap heading and exact reversal. `bugfix_cam_cut.gd` sampled 31 interpolated poses over 16 physics ticks across a 90° turn, with zero inside the box. In the [additional API control](repro/api_control.gd.txt), a stationary target turned 90°, snapped, and held the velocity camera 3.00 m behind for 30 ticks. An unobstructed 3 m orbit with `avoid_min = 9` had 0.00 m of pull.
- **Parkour retry, clock, checkpoint order, restart and hash.** Two fresh Godot processes ran the real regular-hand retry bot with seed 1. Both reported 396 pack ticks, 394 race ticks, one retry at race tick 228, checkpoints `[0, 1, 2, 3, 0]`, and the full state hash `dbc04e2c47dbcfd4ec56d92c9e56b39916c550271fa6cafad5cb671f721d9e9f`. The accepted retry preserved the clock, fall count and checkpoint. C after finishing preserved the finish HUD. R restored 0/4 and 0.00 s while retaining the session best. The [race control](repro/race_control.gd.txt) uses the world holder with its default physics space and plot scenery.
- **Parkour negative cases.** Standing on the finish stripe first earned zero gates. While falling before the beam, C kept the runner in place horizontally and retained checkpoint 2. After an accepted retry, five fresh C taps at the landing stripe advanced zero gates. C at the beam after the rules finished on time left the runner there with TIME UP on the HUD. All seven assertions passed on both runs of the [retry control](repro/retry_control.gd.txt).
- **Seed manifest validation.** The real runner manifest reader accepted the shipped Seed Drive manifest and an omitted optional subject. It rejected an extra top-level key, an extra nested footprint key and a null subject. A12 concerns the separate executable game catalog. [API and manifest control](repro/api_control.gd.txt)
