# Report digest

Generated from `docs/reports/**/*.md`, `briefs/` and `engine/kernel/runner/manifest.gd` by `node devx/bin/tl.mjs arch --index`; do not edit (rule `reports-index-fresh`).
The reports are history and stay as written; this page only collects them.

64 reports, 77 pack-author bullets (3 marked stale), 119 questions raised.

A stale mark is one of two mechanical tests on a pack-author bullet, nothing more:
- `[stale: path gone]`: the bullet cites in backticks a repo path (first segment a top-level directory of the repo, an optional `:line` dropped) that no file or directory of the tree matches now.
- `[stale: kernel now X]`: the bullet names a `kernelApi` version below `KERNEL_API` in `engine/kernel/runner/manifest.gd` (X = 1.6).

An unmarked bullet passed both tests; it was not read for being right.

## Reports

| Report | Date | Brief | Status |
|---|---|---|---|
| jam-lessons-home/T1 | 2026-11-16 | - | - |
| CORE-R2-MERGED | 2026-11-11 | - | - |
| JOB3-HOCKEY | 2026-11-11 | - | - |
| N1-LOOK | 2026-11-11 | `briefs/BRIEF-N1-LOOK.md` | - |
| N2-MANY | 2026-11-11 | `briefs/BRIEF-N2-MANY.md` | All six items are built and proven in my copy, `C:\Users\kazda\kiro\third-life\site\_work\n2\engine\`. The final gates on a quiet machine: ... |
| N3-FOREMAN | 2026-11-11 | `briefs/BRIEF-N3-FOREMAN.md` | All six items are built and green against the fake adapter and fake runner. Parts of items 1, 4 and 6 also ran on the real runner against ... |
| N3B-FOREMAN | 2026-11-11 | - | Both defects are fixed. `npx tsc --noEmit` exits 0. `npm test`, run once at the end with `TL_GODOT` and ... |
| N3C-FOREMAN | 2026-11-11 | - | The different-frame rule is built, and the four real reports classify as machine load for both rounds. `npx tsc --noEmit` exits 0. `npm` ... |
| N4-ITEM | 2026-11-11 | `briefs/BRIEF-N4-ITEM.md` | - |
| N5A-TIERS | 2026-11-11 | `briefs/BRIEF-N5A-TIERS.md` | All six items are built in my copy, `C:\Users\kazda\kiro\third-life\site\_work\n5a\engine\`, and items 1 to 5 are proven there. The last ... |
| N5B-DRAW | 2026-11-11 | `briefs/BRIEF-N5B-DRAW.md` | Items 1 to 4 and 6 are built and proven with pictures I looked at; item 5 is done as far as a flat ground with clean plot edges, and ... |
| N6-DESIGNER | 2026-11-11 | `briefs/BRIEF-N6-DESIGNER.md` | The panel is built and works end to end against the fake adapter and the real runner. It reads the real marble and hockey jobs correctly. ... |
| N7-WORLD | 2026-11-11 | `briefs/BRIEF-N7-WORLD.md` | Items 1 to 5 are built and proven by the tools; all four gates and `view.sh check` pass; seed hashes are unchanged. No person has walked ... |
| P1-MEASURE | 2026-11-11 | `briefs/BRIEF-P1-MEASURE.md` | - |
| P10-FOREMAN | 2026-11-11 | `briefs/BRIEF-P10-FOREMAN.md` | - |
| P11-CONTROLS | 2026-11-11 | `briefs/BRIEF-P11-CONTROLS.md` | All seven items are built and proven. The second full gate (`node devx/bin/tl.mjs check --tier full`) passed at 18:01: exit 0, foreman.test ... |
| P12-ARRIVALS | 2026-11-11 | `briefs/BRIEF-P12-ARRIVALS.md` | - |
| P13-FAR2 | 2026-11-11 | `briefs/BRIEF-P13-FAR2.md` | All seven items were built. The drawing check passes and the tour proof passes both headless and in a window, all on the final files. |
| P14-SEAM | 2026-11-11 | `briefs/BRIEF-P14-SEAM.md` | - |
| P2-HOTPATH | 2026-11-11 | `briefs/BRIEF-P2-HOTPATH.md` | - |
| P3-LOOK2 | 2026-11-11 | `briefs/BRIEF-P3-LOOK2.md` | - |
| P4-RELIEF | 2026-11-11 | `briefs/BRIEF-P4-RELIEF.md` | - |
| P5-LOADING | 2026-11-11 | `briefs/BRIEF-P5-LOADING.md` | Partly done. The build queue, the reload, the walk30 scenario, the supervised window and the two patch applications are built and proven, ... |
| P6-FAR | 2026-11-11 | `briefs/BRIEF-P6-FAR.md` | All six items were worked in the brief's order. Items 1, 2, 5 and 6 are done and proven. Item 3 is done only through geometry (no shader ... |
| P7-CONTRACT | 2026-11-11 | `briefs/BRIEF-P7-CONTRACT.md` | Items 1 to 5 are built and proven; item 6 (the visitor's keys) is not built. `node devx/bin/tl.mjs check --tier full` exits 0 on the final ... |
| P8-PROCESS | 2026-11-11 | `briefs/BRIEF-P8-PROCESS.md` | All five items are done and the acceptance checks pass. The paddle seed, the wall seed, the drive seed and the hockey game were each played ... |
| P9-EXE | 2026-11-11 | `briefs/BRIEF-P9-EXE.md` | - |
| JOB2-MARBLE | 2026-11-10 | - | - |
| WP1-KERNEL | 2026-11-10 | `briefs/BRIEF-WP1-KERNEL.md` | The whole priority list (items 1 to 7) is built, and `bash engine/tools/tl.sh selftest` passes 52 of 52 cases. I stopped at 19:54 CEST ... |
| WP2-KIT | 2026-11-10 | `briefs/BRIEF-WP2-KIT.md` | All five priorities are built and verified. Work ran 18:53:35 to 19:45:18 CEST by `date` (52 minutes); I stopped because the list was done. ... |
| WP3-FOREMAN | 2026-11-10 | `briefs/BRIEF-WP3-FOREMAN.md` | All seven items on the priority list are implemented and every acceptance check passes. Nothing was verified against the real engine, and ... |
| WP3B-FOREMAN | 2026-11-10 | `briefs/BRIEF-WP3B-FOREMAN.md` | All three parts are done. The real job ran end to end and finished `done`: three packages, each promoted in round 1, no re-plan. I finished ... |
| WP3C-FOREMAN | 2026-11-10 | `briefs/BRIEF-WP3C-FOREMAN.md` | All nine items are built and each has tests named by item number. No real job was run and no model was called; `foreman probe` ran once (0 ... |
| WP4-SEEDS | 2026-11-10 | `briefs/BRIEF-WP4-SEEDS.md` | Step 1 and Step 2 are both done and verified. I worked 19:59 to 20:56 CEST by `date` (57 minutes) and stopped because the list was ... |
| WP5-KERNEL | 2026-11-10 | `briefs/BRIEF-WP5-KERNEL.md` | All five items are done and proven, and `engine/` is green. I worked 21:14:54 to 21:39:26 CEST (25 minutes by `date`). The last code edit ... |
| astra-trial/d1/c | - | - | - |
| engine-world-next/C | - | - | - |
| engine-world-next/C-PATCHES | - | - | - |
| engine-world-next/C2 | - | - | - |
| engine-world-next/C2-PATCHES | - | - | - |
| engine-world-next/C3 | - | - | - |
| engine-world-next/C4 | - | - | - |
| engine-world-next/S | - | - | - |
| engine-world-next/S-PATCHES | - | - | - |
| engine-world-next/S2 | - | - | - |
| engine-world-next/S3 | - | - | - |
| engine-world-next/S4 | - | - | - |
| engine-world-next/S5 | - | - | - |
| jam-lessons-home/B | - | - | - |
| jam-lessons-home/H | - | - | - |
| jam-lessons-home/K | - | - | - |
| jam-lessons-home/k4-table | - | - | - |
| jam-lessons-home/L | - | - | - |
| jam-lessons-home/T2 | - | - | - |
| walker-feel/L | - | - | - |
| walker-feel/L-PATCHES | - | - | - |
| walker-feel/M | - | - | - |
| walker-feel/M-PATCHES | - | - | - |
| walker-feel/M2 | - | - | - |
| walker-feel/M2-PATCHES | - | - | - |
| walker-feel/T | - | - | - |
| walker-feel/T-PATCHES | - | - | - |
| walker-feel/T2 | - | - | - |
| walker-feel/T2-PATCHES | - | - | - |

## What changed for a pack author (newest report first)

### N2-MANY (2026-11-11)

- `docs/reports/N2-MANY.md:192` Nothing, for a pack that follows API.md. Seeds and examples run unchanged with the same hashes.
- `docs/reports/N2-MANY.md:193` `frame` and `ctx.frame` are the pack's own tick count, which may run slower than the world's.
- `docs/reports/N2-MANY.md:194` `TLContext.current` is null in a world outside kernel calls, tree ticks and kernel-primitive signals. A static kernel call such as `TLAudio.play`, made from a signal the pack wired to a raw engine node, has no pack.
- `docs/reports/N2-MANY.md:195` `RayCast3D`, `ShapeCast3D`, `SpringArm3D` and `get_world_3d().direct_space_state` look into the default space, where a world keeps no pack. No seed, example, kit or rig uses them.
- `docs/reports/N2-MANY.md:196` Keep the default `process_physics_priority`.
- `docs/reports/N2-MANY.md:197` Stay in pack coordinates: build under `ctx.root`, place with `position`.

### N5A-TIERS (2026-11-11)

- `docs/reports/N5A-TIERS.md:191` Nothing, for a pack that follows API.md: seeds and examples run unchanged with the same hashes.
- `docs/reports/N5A-TIERS.md:192` A game in a world is never switched off but may get fewer ticks. Each tick is a full 1/60 s step, and the pack sees only its own tick count.
- `docs/reports/N5A-TIERS.md:193` `on_leave` and `footprint` in `pack.json` are now read. Without a footprint the plot is 40 x 40 m.
- `docs/reports/N5A-TIERS.md:194` New optional pair `_pack_save()` / `_pack_load(data)`, both or neither. A world file and the ledger keep only seed, ticks, summary and that data. The pack is built again from its seed, then `_pack_start()`, then `_pack_load(data)`.
- `docs/reports/N5A-TIERS.md:195` A world may load a pack with `scenery = "plot"`: a layout read through `ctx.read_json` then has no scattered forest and no far terrain. Do not look scenery nodes up by name.
- `docs/reports/N5A-TIERS.md:196` `TLVfx.squash` and `TLVfx.trail` are new. Lint reports how many kit parts a pack uses and how often it reads world coordinates; these are figures, never findings.

### N5B-DRAW (2026-11-11)

- `docs/reports/N5B-DRAW.md:135` Nothing changes for a pack that follows API.md and takes every material from the style.
- `docs/reports/N5B-DRAW.md:136` Your pack is a venue, not a landscape. In a world it is cut to a circle; your terrain beyond it, your forest and your cliffs are not drawn. Keep what matters inside the radius and leave 9 m free at the edge.
- `docs/reports/N5B-DRAW.md:137` A material of your own is drawn at the right place, but it is not cut to the plot, is missing from the far stand-in, and costs work every frame.
- `docs/reports/N5B-DRAW.md:138` At a distance your pack is one still picture of itself: no moving parts, lights or particles.
- `docs/reports/N5B-DRAW.md:139` Do not use instance shader parameters or metas named `tl_plot`, `tl_clip`, `tl_draw`, and do not read `visible` of your nodes for game state: a far pack is hidden.
- `docs/reports/N5B-DRAW.md:140` Your HUD and cameras show only while the player is in your pack.

### N7-WORLD (2026-11-11)

- `docs/reports/N7-WORLD.md:127` Nothing in a pack changes; API.md 19 to 21 and DRAW.md section 10 hold.
- `docs/reports/N7-WORLD.md:128` `ctx.on_stage` is false from the first line of `_pack_setup` until the visitor enters. A HUD is created hidden. Do not set `visible` on a `TLHud` or make a camera current yourself.
- `docs/reports/N7-WORLD.md:129` On entering, your active view (the first registered, unless you activated another) becomes the picture. Register the play view first.
- `docs/reports/N7-WORLD.md:130` When your game is over and nobody is in your plot, you are rebuilt from your seed 3 s later with nothing carried over, not even `_pack_save` data. Keep no state in `static var`.
- `docs/reports/N7-WORLD.md:131` You bring a venue, not a landscape: in a world your layout has no far terrain and no scattered forest.
- `docs/reports/N7-WORLD.md:132` Declare `footprint` in `pack.json`. No seed or example does yet, so tonight's radii are in the walk script.
- `docs/reports/N7-WORLD.md:133` A big flat floor of your own reads as a disc from above.

### P1-MEASURE (2026-11-11)

- `docs/reports/P1-MEASURE.md:133` A pack that is slow because the machine is busy no longer fails.
- `docs/reports/P1-MEASURE.md:134` A pack with more than about 90 awake bodies now fails `many_budget`, and more than about 330 fails the stage budget.
- `docs/reports/P1-MEASURE.md:135` An endless loop is stopped at 250 ms of its own processor time, as before.
- `docs/reports/P1-MEASURE.md:136` A runaway in a world no longer hangs it.

### P10-FOREMAN (2026-11-11)

- `docs/reports/P10-FOREMAN.md:234` A plan with player input needs the `PLAYER CHECK:` line and a registered bot whose `ok` depends on what the player's side did.
- `docs/reports/P10-FOREMAN.md:235` After a change, a rebuilt package must pass every test of the pack with its files merged in, not only its own acceptance.
- `docs/reports/P10-FOREMAN.md:236` Put tunable numbers in `data/*.json` and declare them in `params`. A change request then shows the value and range; a number left in a script appears only as a raw script line.
- `docs/reports/P10-FOREMAN.md:237` No change to the pack format, the runner, or any engine file.

### P11-CONTROLS (2026-11-11)

- `docs/reports/P11-CONTROLS.md:197` [stale: kernel now 1.6] Write `"kernelApi": "1.0"`.
- `docs/reports/P11-CONTROLS.md:198` A `func _input` or `_unhandled_input` is now a lint error, and `play` refuses the pack.
- `docs/reports/P11-CONTROLS.md:199` A pack's hash in a world is now the hash `tl.sh` prints for it alone.
- `docs/reports/P11-CONTROLS.md:200` Every world hash changed once; the old and new values are in the table above.

### P12-ARRIVALS (2026-11-11)

- `docs/reports/P12-ARRIVALS.md:119` Nothing you write changes.
- `docs/reports/P12-ARRIVALS.md:120` The rigs and kit parts your `_pack_setup` makes are built ahead from the second arrival on a machine. A call with different params is built in your setup as before.
- `docs/reports/P12-ARRIVALS.md:121` A reload sees changed `.gd` files.
- `docs/reports/P12-ARRIVALS.md:122` In a window, a game the visitor walks into is there when he arrives. If it was not ready, that frame is long.

### P13-FAR2 (2026-11-11)

- `docs/reports/P13-FAR2.md:153` Nothing to change.
- `docs/reports/P13-FAR2.md:154` Far marks now move smoothly and figures look like figures.
- `docs/reports/P13-FAR2.md:155` To show the real score in a single-pack run, call `TLKitSite.bind_scoreboard(board, rules)` once.

### P14-SEAM (2026-11-11)

- `docs/reports/P14-SEAM.md:147` [stale: kernel now 1.6] Nothing changes in what you write. A pack may now say `"kernelApi": "1.1"` to use `bind_scoreboard`, and a 1.0 pack still runs.

### P2-HOTPATH (2026-11-11)

- `docs/reports/P2-HOTPATH.md:132` Nothing is required. `track = false` is now clearly worth using for moving scenery. A ray-based first-touch update for a slow body can come up to about 15 % of its reach later than before. Fast bodies are exact.

### P3-LOOK2 (2026-11-11)

- `docs/reports/P3-LOOK2.md:154` Skaters (`mode = skate`) now get a stick and a team helmet with a hem band and number patch, without any change. Pass `prop = none` or `headgear = none` to turn them off.
- `docs/reports/P3-LOOK2.md:155` All bipeds have bigger heads and hands. Colliders and metrics are unchanged.
- `docs/reports/P3-LOOK2.md:156` Walking and running feet are planted, because the swing now follows speed.
- `docs/reports/P3-LOOK2.md:157` The default chase camera is floatier (more lag, smoother).
- `docs/reports/P3-LOOK2.md:158` Dust and smoke are bigger and more visible, and flames and flashes grow in.
- `docs/reports/P3-LOOK2.md:159` New style keys: sky `cloud_puff`, `cloud_line`, `cloud_ink`; toon `rim2`, `rim2_k`.

### P4-RELIEF (2026-11-11)

- `docs/reports/P4-RELIEF.md:182` Your plot stands on a flat pad at the plot's height. The world's ground meets your rim at the same height, so there is no seam.
- `docs/reports/P4-RELIEF.md:183` If your own ground is a hollow, the visitor stops at its top.
- `docs/reports/P4-RELIEF.md:184` A copy of your static colliders is made when the world is built. A wall you remove later is still there for the visitor.
- `docs/reports/P4-RELIEF.md:185` Nothing in your pack or your state hash changes.

### P5-LOADING (2026-11-11)

- `docs/reports/P5-LOADING.md:228` In a world your pack is built by a queue, nearest games first, and may arrive some ticks after the world started. Until then your plot shows its pad.
- `docs/reports/P5-LOADING.md:229` You are not ticked before you are there, and your tick count starts at 0 when you arrive. Nothing in a pack may depend on the world's tick.
- `docs/reports/P5-LOADING.md:230` The venue you build with `TLKit.build_layout(ctx.read_json(...), ctx.root)` is built ahead on another thread when the layout file lies under `data/` and you pass it on unchanged. A layout you change in code first is built in your `_pack_setup` as before, and costs the visitor a frame.
- `docs/reports/P5-LOADING.md:231` Everything else in `_pack_setup` still runs on the main thread: keep it small.
- `docs/reports/P5-LOADING.md:232` A world may replace your pack by a fresh copy of its directory at any tick (`reload`). What `_pack_save` returns is handed to `_pack_load`; nothing else survives. Keep no state in `static var`.

### P6-FAR (2026-11-11)

- `docs/reports/P6-FAR.md:167` Nothing to do for a pack that follows API.md.
- `docs/reports/P6-FAR.md:168` At a distance your moving bodies and rigs are still seen, as boxes in their main colour. What must be seen from far has to be tall, large or moving.
- `docs/reports/P6-FAR.md:169` Place the kit `scoreboard` and use `TLRules`, and a world shows your real score on it. In a single-pack run it is still the prop.
- `docs/reports/P6-FAR.md:170` Up to two standing smoke emitters (no script, no children) are copied into your far pictures.
- `docs/reports/P6-FAR.md:171` DRAW.md section 10 has the wording.

### P7-CONTRACT (2026-11-11)

- `docs/reports/P7-CONTRACT.md:237` [stale: kernel now 1.6] Write `"kernelApi": "1.0"`; 0.1 still runs.
- `docs/reports/P7-CONTRACT.md:238` `ctx.input` values are multiples of 0.001: `press(&"left", 0.4567)` reads back as 0.457.
- `docs/reports/P7-CONTRACT.md:239` The mouse is `ctx.input` too: `TLInput.LOOK_X`, `LOOK_Y`, `ZOOM`. An orbit camera turns with them by itself. A bot injects with `press(TLInput.LOOK_X, 12.0)`.
- `docs/reports/P7-CONTRACT.md:240` A session can be recorded and replayed.
- `docs/reports/P7-CONTRACT.md:241` New lint errors: see the fence list. An `_input` handler in a pack never runs.
- `docs/reports/P7-CONTRACT.md:242` `tl.sh play` no longer ends on Esc while the designer panel is open, and typed keys do not reach the game.
- `docs/reports/P7-CONTRACT.md:243` Every state hash is new.

### P8-PROCESS (2026-11-11)

- `docs/reports/P8-PROCESS.md:255` Never branch on `ctx.headless` to skip a `TL*` call.
- `docs/reports/P8-PROCESS.md:256` Make visible things through the kit, rigs, `TLVfx`, `TLAudio` and `TLHud` only.
- `docs/reports/P8-PROCESS.md:257` Never wait for something only a window has.
- `docs/reports/P8-PROCESS.md:258` Expect `subject_px` and `frame` to change or go.

## Questions raised (119)

Numbered items under a report's Questions heading, as the builder asked them. This page cannot tell an answered question
from an unanswered one: where the Director answered, it is in that report's "Director's decisions on the builder's questions".

### N2-MANY (2026-11-11)

1. `docs/reports/N2-MANY.md:216` Should I apply the three-line sleeping-body change to `tl_contact.gd`? It cuts the cost of an asleep pack by about 14 times and left all 11 compared hashes unchanged. I held it back because it touches every pack's physics path and was not run through the full gates.
2. `docs/reports/N2-MANY.md:217` Way (b) needs the kernel to draw non-stage packs itself (mirror or proxy). Is that the direction, or should packs be made origin-free and the hash contract relaxed for way (a)? The measurement says way (a) cannot keep a pack comparable with its verified run.
3. `docs/reports/N2-MANY.md:218` Is `modes` the right place in verbs.json for `world` and `world-bench`, or does the Foreman want them under `verbs`?
4. `docs/reports/N2-MANY.md:219` Loading a seed pack blocks for about 3 s. Should the next step measure where that goes, before any work on tiers?

### N3-FOREMAN (2026-11-11)

1. `docs/reports/N3-FOREMAN.md:173` **Contract wording.** `contracts/JOB.md` is read-only for me. Proposed additions: events `change_requested {text, package?}` and `reopened {package, reason}`; cause `kit_regression`; `promoted.dest` is `promoted/<pack id>@<version>` for a later promotion, with version `0.1.<n>`; job-directory files ...
2. `docs/reports/N3-FOREMAN.md:179` **Linking a re-open to its request.** The `reopened.reason` starts with `change request (event N)` and the reducer reads N. Is a fixed prefix acceptable, or do you want a key?
3. `docs/reports/N3-FOREMAN.md:180` **Optional manifest fields.** Is reading `manifest.gd` for the key names acceptable as the test of what the engine accepts? A data file like `verbs.json` would be cleaner. `contracts/pack.schema.json` also lacks the five fields.
4. `docs/reports/N3-FOREMAN.md:181` **Kit figure.** Should lint report a kit-parts-used figure in `composability`? The Foreman would then use it instead of its own count.
5. `docs/reports/N3-FOREMAN.md:182` **Kit gate strictness.** A new package that adds any bypass must say why or loses a round. Is that what you want for hockey, or should the first merge of a package be exempt? `--no-kit-gate` exists for tonight.
6. `docs/reports/N3-FOREMAN.md:183` **Promotion directory.** A later promotion goes beside the first as `<id>@<version>`, and the last `promoted` event names the current one. With `--promote-to engine` the newer pack replaces the older. Acceptable?
7. `docs/reports/N3-FOREMAN.md:184` **Critic after a change.** Do you want the critic to look at the pictures taken after a change, at the cost of one call and possibly one round?

### N5A-TIERS (2026-11-11)

1. `docs/reports/N5A-TIERS.md:218` Should a pack in a world bring its own forest and far terrain at all? Making `scenery = "plot"` the default for worlds cuts loading by 67 to 90 % and left the three seeds' hashes unchanged; I kept `full` because it changes what the drawing builder sees.
2. `docs/reports/N5A-TIERS.md:219` Is 6 ms front plus 2 ms backdrop the right budget? It gives about 35 to 50 games before a far one drops below a tenth of real time, and the mix tick is only 4 ms of a 16.7 ms frame.
3. `docs/reports/N5A-TIERS.md:220` Should the 250 ms watchdog count wall-clock time on a shared machine? It failed 2 of 12 and 7 of 12 identical runs tonight, with and without my change.
4. `docs/reports/N5A-TIERS.md:221` Should the seed patch (entry 1) be applied to seed_paddle, or is the example in `ex_bounce` enough?
5. `docs/reports/N5A-TIERS.md:222` What should a game that ended by itself do in a world: start its next round at once, or wait for the player?

### N5B-DRAW (2026-11-11)

1. `docs/reports/N5B-DRAW.md:212` Who declares a pack's plot radius: the pack (`footprint` in `pack.json`), or the world?
2. `docs/reports/N5B-DRAW.md:213` Should the kit build no far terrain sheet and no forest beyond the plot when a pack is built for a world, with the world owning the landscape between venues? That would remove most of the primitives and is the way to hills and roads.
3. `docs/reports/N5B-DRAW.md:214` Should the scheduler pause far packs? Stand-ins save drawing but the frame time is mostly simulation.
4. `docs/reports/N5B-DRAW.md:215` Is yaw on plots wanted now? If so the sun rig and `g_sun_dir` must be turned per stage.
5. `docs/reports/N5B-DRAW.md:216` `toon.gdshader` was changed by N1 tonight and by me; does the Director merge it three ways?

### N6-DESIGNER (2026-11-11)

1. `docs/reports/N6-DESIGNER.md:174` **Answering while running.** A question can be open while the job is still `running`. Should the Foreman take answers and change requests through an inbox file, so the panel need not wait for the pause?
2. `docs/reports/N6-DESIGNER.md:175` **Chips.** Are `approve?`, `question`, `budget` and `stalled` acceptable beside the brief's six, or should the chip keep to the six and the extra word go in the figure column?
3. `docs/reports/N6-DESIGNER.md:176` **Stalled jobs.** Should Change be disabled on a stalled job until Resume has run? Today it is enabled (capture 14).
4. `docs/reports/N6-DESIGNER.md:177` **Tune writes.** The slider rewrites the whole data file with two-space indent. Is that acceptable, or must the original formatting be kept byte for byte around the changed number?
5. `docs/reports/N6-DESIGNER.md:178` **Foreman settings.** Where should the flags file live for a player: beside the jobs root, or in the engine's user settings?
6. `docs/reports/N6-DESIGNER.md:179` **Patch 3's key.** Is Tab the key you want for the panel?

### N7-WORLD (2026-11-11)

1. `docs/reports/N7-WORLD.md:182` Should the seeds and examples declare `footprint` now? Proposed: drive 128 x 128, wall 76 x 76, paddle, kit and car 80 x 80, walker 60 x 60.
2. `docs/reports/N7-WORLD.md:183` Is "next round carries nothing over, after 3 s" the rule you want, or should `_pack_save` data survive a round?
3. `docs/reports/N7-WORLD.md:184` Should the visitor get a body and the world a space of its own (fences, trees, a pack's ground under his feet)?
4. `docs/reports/N7-WORLD.md:185` Which view is the play view on entering: the first registered (today), or a manifest key?
5. `docs/reports/N7-WORLD.md:186` Are JPEG copies of the tour frames in the main tree acceptable, or do you want the PNGs?
6. `docs/reports/N7-WORLD.md:187` Should lint report a pack whose own floor fills its footprint (the disc)?

### P1-MEASURE (2026-11-11)

1. `docs/reports/P1-MEASURE.md:150` Are 4 ms (stage p99) and 1.0 ms (many, p50) the right limits, or should the many-limit stay looser until a physics-heavy game exists? The single number is `BUDGET_MANY_MS_P50` in `engine/kernel/host/invariants.gd`.
2. `docs/reports/P1-MEASURE.md:151` May the `world.gd` size baseline stay raised (675 to 684), or should the guard hooks move elsewhere?
3. `docs/reports/P1-MEASURE.md:152` Should the gate scheduler run steps in parallel (item 7)? It needs your agreement on step independence.

### P10-FOREMAN (2026-11-11)

1. `docs/reports/P10-FOREMAN.md:255` Bump the baseline, or assign the split of foreman.ts (entry 5)?
2. `docs/reports/P10-FOREMAN.md:256` Should a failed final verification of a first build also go back to a package? I kept `failed`, as the brief says "after a change".
3. `docs/reports/P10-FOREMAN.md:257` Should `--pack-tests always` be the default? It would have caught finding 7 at the AI's first merge, at the price of one bot run per test per merge.
4. `docs/reports/P10-FOREMAN.md:258` When a change ends "not made", `pack/` keeps the unpromoted files and the next request builds on them (as last night's second request did). Should it be put back to the promoted pack instead?
5. `docs/reports/P10-FOREMAN.md:259` May the second-line clock code go once the pre-P1 snapshot engines are retired?

### P11-CONTROLS (2026-11-11)

1. `docs/reports/P11-CONTROLS.md:211` Should a person's visit write a world log by default (`--log`), so that a measured-cost visit replays exactly?
2. `docs/reports/P11-CONTROLS.md:212` Is the Director content with the fourth Foreman line (`wp3b.test.ts:45`) and the edited P7 selftest lines?

### P12-ARRIVALS (2026-11-11)

1. `docs/reports/P12-ARRIVALS.md:137` Can `tl_mesh.gd` stay as edited, or should it move to a kit owner?
2. `docs/reports/P12-ARRIVALS.md:138` Should the recipe cache be cleared when a pack's directory hash changes, rather than only when its path changes?
3. `docs/reports/P12-ARRIVALS.md:139` Who takes PATCHES-P12 entry 6? It is now the whole remaining hitch.

### P13-FAR2 (2026-11-11)

1. `docs/reports/P13-FAR2.md:177` Keep the far picture's shadow, or set `far_shadow_m = 0`?
2. `docs/reports/P13-FAR2.md:178` Do you take the API 1.1 bump, together with the P7 case texts?
3. `docs/reports/P13-FAR2.md:179` Should the world-run hashes from the drawing check be recorded as the reference values?

### P14-SEAM (2026-11-11)

1. `docs/reports/P14-SEAM.md:160` Should the next package take the game's own setup in a window (patches entry 1) and the rebuild on entering an ended game (entry 2)?
2. `docs/reports/P14-SEAM.md:161` Should the shipped cache (19 MB, mostly pictures) stay in the build?

### P4-RELIEF (2026-11-11)

1. `docs/reports/P4-RELIEF.md:198` May the walk state heights once (patch 1), so the landscape can later place plots itself?
2. `docs/reports/P4-RELIEF.md:199` Should `ex_car`'s floor, and any pack whose ground is a hollow, declare a footprint or entry so the world can ramp to it?
3. `docs/reports/P4-RELIEF.md:200` Do you want the lot at (205, -34) and the dropped lot at (-62, -21)? I removed the second small lot between the walker room and the track because its pad overlapped its neighbours; one lot remains at (-146, 64), and a new small one is at (205, -34).

### P5-LOADING (2026-11-11)

1. `docs/reports/P5-LOADING.md:251` Is `step` (main thread, arrival ticks fixed by the walk) the right default without a window? The worker's path is then covered only by `world.queue` and by windowed runs.
2. `docs/reports/P5-LOADING.md:252` Who takes patch 2a (thread-local `TLContext.current`)? It is the only way the rest of `_pack_setup` leaves the main thread, and it changes the order in which a pack's nodes enter the tree.
3. `docs/reports/P5-LOADING.md:253` On `reload` I hand on what `_pack_save` returns. After a tuned value, should the game instead start clean?
4. `docs/reports/P5-LOADING.md:254` Asleep packs: telling the tracker from the kernel's wake paths still misses a pack that calls `apply_impulse` itself. Is a one-frame-late contact acceptable for such a pack, or must every body be read?
5. `docs/reports/P5-LOADING.md:255` Several builders' windows at 0,1440 throttle each other to about 270 ms a frame. Should windowed perf scenarios get their own position or a lock?
6. `docs/reports/P5-LOADING.md:256` The landscape (2.1 s for six games, 6.1 s for thirty) is now the time to the first frame. Whose package is that?

### P6-FAR (2026-11-11)

1. `docs/reports/P6-FAR.md:190` **Score at near distance.** The live score over the prop is drawn on near packs too, so it is the same at every distance. Is that wanted, or should near stay the pack's own business until the kit part is fixed (patch 3)?
2. `docs/reports/P6-FAR.md:191` **Pace of the marks.** Marks step at the pack's tick rate (four times a second at one tick in sixteen). That is the truth about the game's pace and it looks like stutter. Smooth them between ticks, or keep it honest?
3. `docs/reports/P6-FAR.md:192` **Middle to far threshold.** It is the camera's distance, so the high crane sees silhouettes everywhere while the scheduler decides near. Should the scheduler own this too (patch 1 keeps it drawing-only)?
4. `docs/reports/P6-FAR.md:193` **Road trees in an existing shot.** Trees along the road now stand in front of the fixed crane camera of `tour_views` shot `far_and_near` (`captures\p6\far_and_near_before_after.jpg`). Move that camera (the walk is not mine) or thin the trees there?
5. `docs/reports/P6-FAR.md:194` **Pads are still circles.** The plot cut is a circle and the fence follows it. A non-round plot is a change to the plot contract. Is it wanted?

### P7-CONTRACT (2026-11-11)

1. `docs/reports/P7-CONTRACT.md:260` Keep the 0.001 rounding of input? It makes a record exact in any reader and input cheap to send, but it moved bot results. Reversing it is one line in `_sample()`, and then the record needs an exact float encoding.
2. `docs/reports/P7-CONTRACT.md:261` Should `func _input` in a pack become a lint error (patch 4)? It changes PACK.md's bypass list and one example.
3. `docs/reports/P7-CONTRACT.md:262` `Timer` is now refused although PACK.md lists `Timer.new()` as a counted bypass. Is that acceptable?
4. `docs/reports/P7-CONTRACT.md:263` Is `replay` at level V2 right, and are the four extra record keys acceptable?
5. `docs/reports/P7-CONTRACT.md:264` Apply patch 1 at the merge? It changes every world hash once.
6. `docs/reports/P7-CONTRACT.md:265` How long should "0.1" stay an alias of 1.0?

### P8-PROCESS (2026-11-11)

1. `docs/reports/P8-PROCESS.md:278` Which purpose comes first? Multiplayer authority works today in the spike's form (D runs the setup). Sharing needs D to build from records, i.e. patches 3 to 5 plus a builder in D.
2. `docs/reports/P8-PROCESS.md:279` May `ctx.headless` change meaning in API v1 (contract text 2)? It is the one change that touches how kit, rigs and effects are written.
3. `docs/reports/P8-PROCESS.md:280` `TLCameras.subject_px`, `frame`, and `view()` returning the raw camera: remove, define on a nominal 16:9, or make the window's aspect an input?
4. `docs/reports/P8-PROCESS.md:281` Is a small native piece acceptable (a launcher or GDExtension for the pipe and the job object)? Without it the sandbox channel cannot exist; the multiplayer channel does not need it.
5. `docs/reports/P8-PROCESS.md:282` Should the spike stay in the tree as `engine/kernel/proc/` (it is off the game path and has its own scene), or be kept only as the report?
6. `docs/reports/P8-PROCESS.md:283` One extra frame of input delay per moved game: acceptable for all games, or only for games that are shared or remote, with local trusted games staying in process?

### WP1-KERNEL (2026-11-10)

1. `docs/reports/WP1-KERNEL.md:130` **Bot not done within `--frames`.** I report `bot.completed` false with outcome `watchdog`, exit 3, reading RUNNER's "frame budget exceeded". Is that right, or should it be `failed`, exit 1?
2. `docs/reports/WP1-KERNEL.md:131` **Additive report fields.** I added check `smoke.no_engine_errors`, `metrics.tick_ms_max`, `metrics.state_hash_b`, and the `smoke.*` checks inside `invariants`, `bot` and `capture` reports. Will WP3 validate `tl.verify/1` strictly? If so, bless or strike these.
3. `docs/reports/WP1-KERNEL.md:132` **Fence extensions.** I added `randf_range(`, `randi_range(`, `randfn(`, `.shuffle(`, `.pick_random(` and `WorkerThreadPool`. Proposed wording for PACK.md: "…`randf(`, `randi(`, `randomize(` and every other door to the global generator (`randf_range(`, `randi_range(`, `randfn(`, `.shuffle(`, ...
4. `docs/reports/WP1-KERNEL.md:133` **`capture --test=<bot>`.** I added it so V5 can show the game being played rather than idle. Keep it?
5. `docs/reports/WP1-KERNEL.md:134` **Capture driver.** Should captures be pinned to one rendering driver (`TL_RENDER_DRIVERS=d3d12`) so every V5 image comes from the same backend, given the Vulkan crashes?
6. `docs/reports/WP1-KERNEL.md:135` **Wall-clock limits.** Are the 250 ms tick limit and 8 ms p99 meant as written? A frame-counted watchdog cannot stop a loop that never yields a frame.
7. `docs/reports/WP1-KERNEL.md:136` **Bypass heuristic for "hand-rolled score or clock".** It matches variables named `score`, `clock`, `timer`, `lap` and similar. Is that enough?

### WP2-KIT (2026-11-10)

1. `docs/reports/WP2-KIT.md:151` **Dynamic props.** `puck`, `ball` and `paddle` return no body. The root carries `tl_dynamic`, `tl_shape`, `tl_shape_offset`, `tl_material` and `tl_mass_hint`. Proposed wording: "A part the game moves returns zero bodies and carries `tl_dynamic: true`, `tl_shape`, `tl_shape_offset`, `tl_material`, ...
2. `docs/reports/WP2-KIT.md:152` **`load_style` return value.** It mixes hard errors and `clamped: ` notes in one array. Is that acceptable, or should notes go elsewhere?
3. `docs/reports/WP2-KIT.md:153` **Particles and shader time.** `TLStyleFx` particles (chimney smoke, weld sparks in layouts) and the shader `TIME` (ice shine, grass sway) run on the engine clock. They are visual only and skipped headless. Is that acceptable, or should every effect go through the kernel's `vfx`?
4. `docs/reports/WP2-KIT.md:154` **Extra sockets.** Should `stick_blade` (biped) and `carry` (bot) be added to the contract's socket list?

### WP3-FOREMAN (2026-11-10)

1. `docs/reports/WP3-FOREMAN.md:162` **Manifest ownership.** `pack.json` belongs to one package, scopes are disjoint, and the whole pack must pass lint after every merge. A manifest that lists a later package's bot or generator therefore fails layout until that package lands, and no later package may register its own bot. The Planner ...
2. `docs/reports/WP3-FOREMAN.md:163` Should a failed package go back to the Planner, as FEASIBILITY says, and after how many rounds?
3. `docs/reports/WP3-FOREMAN.md:164` Is the candidate-first merge order acceptable, or do you want the literal merge-then-verify with an undo event?
4. `docs/reports/WP3-FOREMAN.md:165` Should `--hide-env` hide key-like variables by default for edit-mode runs?
5. `docs/reports/WP3-FOREMAN.md:166` Who triggers captures and the V5 critic at a milestone: the Foreman loop or a separate step?

### WP3B-FOREMAN (2026-11-10)

1. `docs/reports/WP3B-FOREMAN.md:124` RUNNER.md and capture: proposed wording "the supervisor always runs `--headless` and opens the capture window itself at `0,1440`".
2. `docs/reports/WP3B-FOREMAN.md:125` Builders got a copy of API.md, `pack_min` and `ex_slide` in `<job>/ref/`, not the snapshot path. `--restricted` confines the file tools, and a live test showed an `--add-dir` directory is writable. May `ref/` join the allowed job-directory entries? The law tables are now copied too, after the ...
3. `docs/reports/WP3B-FOREMAN.md:126` Should a "NOT ok" critic, or a "NO VISIBLE CHANGE" milestone, fail the milestone?
4. `docs/reports/WP3B-FOREMAN.md:127` Where does the manifest version come from, and is the fixed entry `scripts/main.gd` acceptable?
5. `docs/reports/WP3B-FOREMAN.md:128` Should the budget count cache reads at a lower weight?
6. `docs/reports/WP3B-FOREMAN.md:129` Should builder deviations become an event, for example `note {package, round, text}`?
7. `docs/reports/WP3B-FOREMAN.md:130` The CLI lets some harmless commands through without a grant (`echo`, `node --version`, one `grep`). Acceptable?
8. `docs/reports/WP3B-FOREMAN.md:131` The second run of a clock-based verdict is my decision, not the contract's. Proposed JOB.md wording: "a verification whose only failure is clock-based is run once more; both are logged".
9. `docs/reports/WP3B-FOREMAN.md:132` Capture frames are fixed at 120 and 480. Should a pack declare its own?
10. `docs/reports/WP3B-FOREMAN.md:133` The "tuned" milestone fired before "art_pass" because the packages ran in parallel. Are milestones ordered stages or labels?

### WP3C-FOREMAN (2026-11-10)

1. `docs/reports/WP3C-FOREMAN.md:99` **`tokensCacheRead`.** I added it as an optional key on `builder_run`, because the weighting needs the figure in the log. JOB.md does not list it. Proposed wording: "`tokensCacheRead` (the part of `tokensIn` read from the prompt cache, when the adapter reports it)".
2. `docs/reports/WP3C-FOREMAN.md:100` **`budget.state`.** The event enum has no closed value, so I closed it only in the derived state (`state.json`, `status`); the last `budget` event still says `running`. Do you want a `closed` value in the event instead?
3. `docs/reports/WP3C-FOREMAN.md:101` **`promoted.dest`.** In the job case it is `promoted/<id>` relative to the job directory, while the events table says `packs/<id>` relative to the engine. Is that acceptable?
4. `docs/reports/WP3C-FOREMAN.md:102` **Send-back logging.** `cause` is only allowed on `failed` and `blocked`, so no visible change is `failed` then `queued`, and the critic's round is `queued` with a `detail` starting "critic (V5) NOT ok, one extra round". Is a fixed `detail` prefix acceptable as the marker?
5. `docs/reports/WP3C-FOREMAN.md:103` **Cost of the critic's round.** In the first job the critic said NOT ok three times. With this rule that is up to one extra builder run per package, each up to 12 minutes. `--no-critic` switches the critic off entirely; there is no flag for a critic without the extra round. Do you want one before ...
6. `docs/reports/WP3C-FOREMAN.md:104` **Comparison gap.** Captures are compared only for the same camera and frame. If a package changes the frame at which the bot finishes, the frames differ and an art pass cannot fail for no visible change. Should the Foreman re-capture the previous milestone's frames in that case?
7. `docs/reports/WP3C-FOREMAN.md:105` **Stale dependants.** A package already building when its dependency is sent back keeps working on the older files; the merge gate (lint and smoke on the whole pack) is the only check. Acceptable for the spike?
8. `docs/reports/WP3C-FOREMAN.md:106` **First look's images.** A second look at a milestone overwrites the first look's capture files; only the first critique report is kept. Keep both sets?

### WP4-SEEDS (2026-11-10)

1. `docs/reports/WP4-SEEDS.md:143` Do you accept kernel changes 5 (`lock` and `TLBodies.drive`) and 6 (`README.md` at the pack root)? The Foreman's frozen engine snapshot still has the old lint and would reject the seeds' README files.
2. `docs/reports/WP4-SEEDS.md:144` Should `invariants` also replay a bot twice and compare hashes? Smoke-only determinism missed a real kernel bug.
3. `docs/reports/WP4-SEEDS.md:145` Should `TLVfx` delegate to `TLStyleFx` when the style layer is installed, so effects match the look?
4. `docs/reports/WP4-SEEDS.md:146` Should `tl.sh selftest` include the seeds, or stay kernel-only with `tl.sh seeds` beside it, as now?

### WP5-KERNEL (2026-11-10)

1. `docs/reports/WP5-KERNEL.md:122` **Lint figures.** The marble pack still reports `bypasses: []` and `kit_parts_added: 0`, although it makes its own `BoxMesh`, `StandardMaterial3D`, sun and environment. Should lint count `StandardMaterial3D.new()`, `BoxMesh.new()`, `DirectionalLight3D.new()` and `WorldEnvironment.new()` as ...
2. `docs/reports/WP5-KERNEL.md:123` **Contract wording.** I added `--bot-frames`, the three bot metrics, the `WARNING:` text in the `smoke.loads` detail, and the optional style keys `env.plain_ambient` and `env.ground_key`. Proposed lines for `RUNNER.md`: "`invariants` takes `--bot-frames=<max>` (default 36000)." "A `smoke.loads` ...
3. `docs/reports/WP5-KERNEL.md:126` **Default ground.** It is grass and sits just under the pack's lowest visual. A course built in the air floats above it, and a body that falls off passes through it. Is that the wanted behaviour, or should it be a neutral colour?
4. `docs/reports/WP5-KERNEL.md:127` **A fixed marble pack.** If a later job attaches `look_dress.gd` correctly, it will add its own sun, environment and `StandardMaterial3D`s on top of the style. The documents now say not to; nothing stops it.
