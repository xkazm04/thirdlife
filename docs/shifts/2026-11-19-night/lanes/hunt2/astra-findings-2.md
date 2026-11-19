# Third Life QA round 2, part 2

Twelve new findings reproduced twice. Five are high severity. B1 and B10 passed twice after concurrent fixes. The other ten remained reproducible at their latest checks. The focused fix block passed all 12 cases at the start of the review and all 14 after the two new regressions were added.

Run commands from the repository root in Git Bash. Each finding quotes the final verdict from each independent run. A numbered repro exits 1 when it demonstrates the defect. Godot tests run headless with a 180-second watchdog. Simulated times are physics frames.

## B2. A warm construction-site cache changes the game's tick count and hash

**High · May predate 17 Nov? No (18 Nov, `3c189de5` at arrival).** `engine/kernel/world/site.gd:361` restores the scheduler footprint from the display radius. Setup at line 72 can take that radius from the previous run’s mesh measurement. `engine/kernel/world/WORLD.md:413` promises the scheduler footprint comes from files so ticks and hashes are independent of cache state.

**Reach.** Two fresh processes run the same 240-tick walk with the shipped arrival fixture, seed 1 and step loading. The first process fills an empty private cache. The second uses it. Both read all 21 events and see promotion at tick 19. The test enlarges the lot and moves the visitor across the tier boundary so the radius difference affects scheduling.

[Repro](repro/B2.py) · `python docs/shifts/2026-11-19-night/lanes/hunt2/repro/B2.py`

```text
REPRO B2: FAIL 240 world ticks, lot radius 45/25 m, pack ticks 220/123, hashes 51b227f5682175d607b8d848d67debb438d1abb4cd63ae4b554bf25fa32dd681/7ad7462b1f901fdee4b38375df3d971bf7d4050d7c7c8b925e4f809bf82c58f5
REPRO B2: FAIL 240 world ticks, lot radius 45/25 m, pack ticks 220/123, hashes 51b227f5682175d607b8d848d67debb438d1abb4cd63ae4b554bf25fa32dd681/7ad7462b1f901fdee4b38375df3d971bf7d4050d7c7c8b925e4f809bf82c58f5
```

**Suggested fix.** Save the scheduler’s original footprint before holding the lot and restore that exact value on arrival. Exercise the walk across a tier boundary both cold and warm.

## B4. A Windows replay path silently drops the game’s stage recording

**High · May predate 17 Nov? Yes (11 Nov, `76025a1d`).** `engine/kernel/runner/visit.gd:69` joins the directory and filename with `/`, then compares that string with the original path prefix at line 70. A native Windows path can open the main record but fails this comparison for its stage file. Line 262 feeds an empty list. `contracts/RUNNER.md:135` promises the same game result on a fixed schedule.

**Reach.** `world-view --input` passes the supplied path to `Visit.setup`. The headless repro drives that same reader, writer and stage transition with a real Seed Drive holder on a fixed 75-frame schedule. The two paths name the same pair of files. Forward slashes reproduce the full state hash. The minimal view supplies the visitor pose for `finish()`.

[Repro](repro/B4.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh B4`

```text
REPRO B4: FAIL 75 frames; recorded/forward-slash/native-path gas ticks 71/71/0; hashes 56025ee7e23c5f8b5ec404ea83dd1f755a7db46c8aa32b6b17edd99d5acf4e10/be731e8e41517779a0a9a75dc5a4ef291e259c546c64ac51d47826adf42abe58
REPRO B4: FAIL 75 frames; recorded/forward-slash/native-path gas ticks 71/71/0; hashes 56025ee7e23c5f8b5ec404ea83dd1f755a7db46c8aa32b6b17edd99d5acf4e10/be731e8e41517779a0a9a75dc5a4ef291e259c546c64ac51d47826adf42abe58
```

**Suggested fix.** Normalize the input path once or compare sibling basenames. Test both separators against the same recorded stage session.

## B5. The seed suite exits successfully when its filter selects nothing

**High · May predate 17 Nov? Yes (10 Nov, `b9a1443`).** `engine/tools/seeds.sh:94` checks only the failure counter after printing the trailer. An unmatched filter skips all ordinary, hash and hand cases. The found-zero rule is at `docs/GATE-HONESTY.md:14`.

**Reach.** `bash engine/tools/tl.sh seeds <filter>` forwards the shell exit unchanged. This affects filtered callers. The aggregate DevX gate has a separate zero-count check.

[Repro](repro/B5.sh) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/B5.sh`

```text
REPRO B5: FAIL 0 cases selected, 0 completed, tl.sh seeds exited 0
REPRO B5: FAIL 0 cases selected, 0 completed, tl.sh seeds exited 0
```

**Suggested fix.** Check the selected count before returning and distinguish an unmatched filter with exit 2, as `selftest.sh` does.

## B6. The import wrapper reports success when Godot cannot start

**High · May predate 17 Nov? Yes (10 Nov, `b9a1443`).** `engine/tools/tl.sh:84` pipes the import output through two filters and unconditionally exits 0. The runner wrapper documents its status convention at `engine/tools/tl.sh:20`; `docs/GATE-HONESTY.md:19` assigns exit 2 to missing Godot.

**Reach.** The documented `tl.sh import` command rebuilds the class cache. The probe points `TL_GODOT` at a nonexistent lane-local filename. No import runs and no cache changes.

[Repro](repro/B6.sh) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/B6.sh`

```text
REPRO B6: FAIL 0 Godot processes started, import exited 0
REPRO B6: FAIL 0 Godot processes started, import exited 0
```

**Suggested fix.** Check the executable before launching it. Preserve the import process status before filtering diagnostics.

## B8. The ladder publishes a passing cell after the real verifier rejects its run

**High · May predate 17 Nov? Yes (16 Nov, `3681b4b4`).** `devx/lib/commands/ladder.mjs:85` drops the runner exit code, line 46 reads only `bot.completed`, and line 103 turns that completion into a passing step. `contracts/RUNNER.md:71` includes the smoke checks in bot reports. Lines 86–87 require a reported script error to fail verification even if the pack carries on.

**Reach.** The repro invokes the actual `tl.sh bot` and `node devx/bin/tl.mjs ladder` on one lane-local copy of `pack_min`. Its bot finishes and returns `ok:true`, `won:false`, after calling `push_error`. The verifier rejects the script error. The ladder counts the same invalid sample as a completed loss.

[Repro](repro/B8.py) · `python docs/shifts/2026-11-19-night/lanes/hunt2/repro/B8.py`

```text
REPRO B8: FAIL bot exited 1 with smoke.no_script_errors=false; ladder credited 1/1 and exited 0
REPRO B8: FAIL bot exited 1 with smoke.no_script_errors=false; ladder credited 1/1 and exited 0
```

**Suggested fix.** Carry the process status and verify checks through `realRunBot`. Exclude failed engine checks from the measurement and fail the cell. Keep legitimate game losses as measured outcomes.

## B1. Hockey unload leaves the benched skaters alive (fixed during review)

**Medium · May predate 17 Nov? Yes (16 Nov, `3df10a27`).** `engine/packs/hockey/scripts/main.gd:228` detaches the previous roster. Only players on the new roster get a parent again. At the first two runs the predelete handler cleaned up venues and dress nodes and omitted `pool`. The current handler at line 143 includes the pool. `engine/kernel/world/TIERS.md:28` requires unload to retain only the ledger record.

**Reach.** The shipped base → big ice action takes a six-player roster down to four. After the real holder unloaded, weak references to both benched bipeds still resolved. The repro counts their descendants and then frees the survivors.

[Repro](repro/B1.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh B1`

```text
REPRO B1: FAIL 2/2 benched skaters still own 54 nodes after unload
REPRO B1: FAIL 2/2 benched skaters still own 54 nodes after unload
```

**Suggested fix.** Include detached pool members in teardown and assert that weak references to every original player clear after a roster reduction. A concurrent edit applied this change. The same unload now gives `REPRO B1: PASS` on both reruns.

## B3. The site accepts incomplete job events and unknown package fields

**Medium · May predate 17 Nov? No (18 Nov, `3c189de5`).** `engine/kernel/world/site/log.gd:80` checks supplied top-level key names and returns success at line 83. It never checks required fields or keys inside plan packages. `contracts/JOB.md:34` defines the envelope, line 39 requires `packId` on creation, and line 42 defines the package fields. The accepted malformed lines increment the public event count and reach the fold.

**Reach.** `site.gd:328` feeds this reader in live and replay mode. The inputs change one field at a time in shipped fixture rows. The valid creation row is accepted and an unknown top-level key is rejected.

[Repro](repro/B3.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh B3`

```text
REPRO B3: FAIL 6/6 invalid job events accepted (5 missing required fields, 1 unknown package key)
REPRO B3: FAIL 6/6 invalid job events accepted (5 missing required fields, 1 unknown package key)
```

**Suggested fix.** Validate required fields, nested keys and field types against the Foreman event schema before advancing the fold. Share valid and invalid fixtures with the writer.

## B7. A visible plot floor can lose all its collision triangles

**Medium · May predate 17 Nov? No (18 Nov, `7c130baa`).** `engine/kernel/world/terrain/world_space.gd:271` and line 330 discard concave faces by their centroid. A triangle can support the visitor well inside the plot with its centroid outside. The contract at `world_space.gd:10` and `engine/kernel/world/draw/view_seam.gd:60` gives the visitor the game’s static collision once the temporary pad goes away.

**Reach.** The immediate landscape copy and the arriving-game copy both feed the village walker. The controlled 120 m floor has four coplanar triangles. The rendered ground passes the real rim/coverage test and the uncut copy supports the ray at y=0. Both clipped paths drop a stationary walker. The geometry is a fixture, so this is medium severity. No shipped village floor is claimed here.

[Repro](repro/B7.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh B7`

```text
REPRO B7: FAIL 4 visible floor triangles, rim 0.00 m; visitor y after 90 ticks: immediate -26.60 m, arriving -26.60 m
REPRO B7: FAIL 4 visible floor triangles, rim 0.00 m; visitor y after 90 ticks: immediate -26.60 m, arriving -26.60 m
```

**Suggested fix.** Test triangle–disc overlap in both copy paths. Use the draw layer’s crossing-triangle case to exercise collision and the visitor after pad removal.

## B10. The regular hand can count two presses as one game-visible tap (fixed during review)

**Medium · May predate 17 Nov? Yes (16 Nov, `b61ace06`).** `engine/kernel/api/tl_hand.gd:363` could delay a release beyond the next queued press. The loop at line 351 then applied both before `TLInput._sample()`. Only the final down state reached the game. `engine/kernel/API.md:613` defines tap as an input intent, and `tl_hand.gd:116` describes each call as one press.

**Reach.** Hockey’s `bot_hockey.gd:175` taps `shoot` through this API. The fixture sends pairs of consecutive intents on seed 1, spaced 100 frames between pairs, with the regular profile’s lapse rate set to zero. It measures the game’s public `just_pressed` edge. The stock hockey bot’s actual loss rate was not measured.

[Repro](repro/B10.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh B10`

```text
REPRO B10: FAIL 64 requested taps, 64 internal presses, 45 shoot edges, 0 lapses, 0 taps_lost
REPRO B10: FAIL 64 requested taps, 64 internal presses, 45 shoot edges, 0 lapses, 0 taps_lost
```

**Suggested fix.** When a queued release is postponed, shift the following press far enough to leave a sampled up frame. Check observed input edges alongside the hand’s internal press count. The concurrent fix at `tl_hand.gd:364` moves the pending events. Both reruns gave `REPRO B10: PASS`, and the new focused check counted 64 game-visible edges.

## B9. A live site never revisits a promotion whose manifest arrived late

**Low · May predate 17 Nov? No (18 Nov, `3c189de5`).** `engine/kernel/world/site.gd:347` remembers a missing promoted directory. Line 344 skips that directory on every subsequent tick even after the manifest appears. `engine/kernel/world/WORLD.md:376` says the plot is held until the logged promotion names a pack, then released for building.

**Reach.** The live site reader sees a torn final event, receives the rest of the log at its next poll, and then receives all files of the real promoted fixture. The model uses a ledger-tier holder to observe the arrival decision independently of building. Reloading the same on-disk job releases it immediately. This requires the log to become visible before its files, as can happen when copying a job.

[Repro](repro/B9.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh B9`

```text
REPRO B9: FAIL 21 events, 5 polls; manifest available for 180 ticks; arrivals live 0, fresh load 1
REPRO B9: FAIL 21 events, 5 polls; manifest available for 180 ticks; arrivals live 0, fresh load 1
```

**Suggested fix.** Suppress duplicate warnings separately from the existence check. Retry missing destinations at the live polling interval.

## B11. Scaled camera parents change the actual wall clearance

**Low · May predate 17 Nov? No (18 Nov, `120208a4`).** `engine/kernel/api/tl_chase_cam.gd:207` uses `avoid_margin` directly as a sphere radius in the parent’s query space. Its public field at line 37 specifies metres kept from the obstacle. The A10 fix reports the resulting pull correctly. The camera itself still moves to a different physical distance.

**Reach.** The village visitor passes its own avoidance space to the chase camera. The repro holds the wall and target fixed in world metres and varies uniform parent scale. The shipped stage rebase uses unit scale. This case measures camera-to-wall clearance, independently of the `avoid_pull` readout.

[Repro](repro/B11.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh B11`

```text
REPRO B11: FAIL requested 0.30 m wall clearance; scales 0.5/1/2 leave 0.15/0.30/0.60 m
REPRO B11: FAIL requested 0.30 m wall clearance; scales 0.5/1/2 leave 0.15/0.30/0.60 m
```

**Suggested fix.** Convert the margin to query-space units for a uniformly scaled parent, or perform the sweep in world metres. Assert the physical gap at scales below and above one.

## B12. A rejected first style load disables the default palette

**Low · May predate 17 Nov? Yes (10 Nov, `b9a1443`).** `engine/style/tl_style.gd:78` sets `_loaded` before checking that the requested file exists. The next palette lookup calls `ensure()` at line 66, which now skips the default. `engine/style/STYLE.md:8` documents first-use loading and line 17 describes retention after a failed style change.

**Reach.** `engine/rigs/review/review.gd:55` tries an optional `--style` before installing the look. The headless repro calls that same public loader with a missing file, then reads its palette. A rejected reload after loading the default preserves all keys.

[Repro](repro/B12.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh B12`

```text
REPRO B12: FAIL first rejected style leaves 0 palette keys; default 100, rejected reload after default 100
REPRO B12: FAIL first rejected style leaves 0 palette keys; default 100, rejected reload after default 100
```

**Suggested fix.** Mark the style initialized only after installing valid data. Keep any guard against repeated attempts to load a missing default separate from failure of a caller-supplied override.

## Fix review: held

- **A2, editor game lookup.** All eight village plots resolved. The hockey export alias resolved to the `hockey` source folder, and feeding that absolute path back into the resolver returned the same directory. An explicit empty games directory correctly hid the editor copy.
- **A4 and A10, chase camera.** Travel at 0.6 and 3 m/s put the camera 7.00 m behind the target even after 30 stationary ticks. Snapping restored the target’s facing at both speeds. Reported pull matched measured movement at scales 1 and 2 (4.30 and 4.60 m). B11 covers the wall clearance itself.
- **A6, ball possession.** Freeing the holder let the ball drop 1.27 m in 30 ticks. Detaching a live holder and later queue-freeing a new possession emitted one release each. The first signal carried the still-live node, the second carried null, and a redundant release emitted nothing. The ball ended unfrozen.
- **A7, hockey goal height and translated pack.** At 1.75 m above the ice the score held. At 1.0 m inside the goal it advanced once. In a pack translated by (300, 2, −40), a puck 0.3 m above its own ice also scored once.
- **A8 and A14, hockey cleanup.** The checking helper resolved through its weak reference while it had an owner and returned null after the last owner released it. After a mode switch and unload, all four helper references and the first rink had cleared. B1 tracks the separately owned benched players and their subsequent fix.
- **A9, Seed Drive nitro.** Alternating Shift for 60 frames with an empty tank produced zero boost ticks before any pad. A full tank delivered exactly 70 ticks of boost and stopped. This checks the short recharge path and full-tank duration.
- **A15, parkour retry.** Against the fixed pack, holding forward at the beam then tapping C moved the runner from 0.34 to 4.50 m short, with zero falls. The exact block assertion failed with the pre-fix entry script from `git show HEAD:engine/packs/parkour/scripts/main.gd` in a lane-local pack copy (0.34 to 0.32 m). The part 1 contact repro and all seven retry guards passed. Two fresh regular-hand runs retained the part 1 seed-1 hash `dbc04e2c47dbcfd4ec56d92c9e56b39916c550271fa6cafad5cb671f721d9e9f` at 396 pack ticks, one retry and 394 race ticks.
- **Focused block verdicts.** `bash engine/tools/selftest.sh hunt2.` exited 0 at 12/12 before the concurrent changes and at 14/14 afterward. With the single-case filter `hunt2.nitro_crumb`, the real harness rejected an otherwise passing selected row with no trailer (child exit 0), and rejected a child exiting 3. Both harness runs exited 1.

## Probed and sound

- **Site logs.** The failed fixture folded 11 events into a failed job with 0/2 packages built. The 33-event unmade-change fixture retained its promotion with 1/2 built. B9 also checked growing input. Nineteen complete events were visible before the poll at tick 60, with the partial promotion withheld until its line was complete.
- **Stage handover and lengths.** In the stock `bugfix_runner_stage.gd` rebuild, one sparse row at frame 12 produced a record of length 20. A bot-held key persisted 30/30 frames without a handover and 0/30 on stage without a physical key. B4’s 75-frame forward-slash replay matched the original pack hash. The stock teleport check sampled 57 drawn frames per body over 24 placements, with 0.000 m worst error for ball, biped and vehicle. Its uncorrected twin glided on all 51 qualifying control frames.
- **Terrain and drawing.** All eight assertions in `bugfix_world_case.gd` reported success, including the 60-tick temporary pad, immediate and sliced box copies, rotated rim coverage of 48/144 samples, and the drawn crossing-floor triangles. This suite also printed a two-instance ObjectDB leak warning at shutdown. B7 exercises the corresponding concave collision geometry. The shipped village’s Pip GLB produced 16 mesh instances, one landmark, a 4.0 m post top and a clear ray 2 m from the post centre.
- **Caches.** A headless rim lookup selected the `|cover2` value with an old `|cover` value present. Disabling cover selected the unsuffixed key. A clean PIC_VERSION 15 disk round trip reloaded all 12 triangles of a far mesh. Changing radius changed its key. This verifies geometry and cache selection headless. No screen capture was taken.
- **Gate accounting.** The targeted `devx/test/gate-honesty.test.mjs` and `devx/test/count-drop.test.mjs` suites passed all 25 tests. Their synthetic history checks included an undeclared drop from 169 to 165 and an explicitly declared drop of the same size. B5, B6 and B8 concern separate command paths.
- **Seed hand.** The regular-hand Seed Drive bot ran to three laps in 3,868 frames on seed 1. The two processes produced `ebb575ab347f3454b8059a5cbdca224f12500810256eba1c86e1e2eab26f545c`. The filtered seed suite reported 3/3, including the hash comparison.
- **Rig and style.** All six headless `bugfix_rig_cases.gd` assertions passed for rest pose, gaze, turning on landing, spawn face, build blink and stick colour. A rejected style change after valid initialization preserved all 100 palette keys. B12 covers a rejected first load.

The windowed visit entry point at `engine/kernel/world/draw/view.gd:112` refuses headless execution. B4 therefore tests the production visit recorder and replay with a real pack holder and a minimal view. The floor in B7 is controlled geometry. Coverage was targeted throughout, with no full gate or graphical tour.
