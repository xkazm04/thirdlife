# WP4 kit joined to the kernel, three seed packs: builder report and Director verification

Brief `briefs/BRIEF-WP4-SEEDS.md`. Builder wall time 19:59 to 20:56 CEST on 2026-11-10 (57 min; harness: 398,504 subagent tokens, 125 tool uses).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

# WP4 report: kit joined to the kernel, three seed packs

## Status
Step 1 and Step 2 are both done and verified. I worked 19:59 to 20:56 CEST by `date` (57 minutes) and stopped because the list was finished. No Godot process of mine is running, I ran no git command, and I did not read or write `foreman/` or `site/`.

**Not done:** `tl.sh play` was not run on any seed, because it opens an interactive window. The bots are the proof that each game can be played to the end; real keys were never pressed.

## Step 1 proof
Final runs, all after the last kernel edit:

| Check | Result |
|---|---|
| `bash engine/tools/tl.sh selftest` | 60 passed, 0 failed (the 52 old cases plus 8 new) |
| `bash engine/tools/k.sh selftest` | 86 passed, 0 failed, inside the engine project |
| `bash engine/tools/k.sh validate` | 7 files, 0 failed |
| "kitlab" anywhere under `engine/` | 0 hits outside the `.godot` cache, which was not searched |

**The move.**
- `kits/`, `rigs/` and `style/` are in `engine/` with unchanged `res://` paths.
- The lab scene is `engine/kits_lab/`, its GDScript tools are `engine/kits_lab/tools/`, and `k.sh` is `engine/tools/k.sh`.
- `kitlab/MOVED.md` is written; `kitlab/JOURNAL.md`, `captures/` and `project.godot` stay.
- `engine/project.godot` took the lab's rendering block (Direct3D 12, MSAA, shadow size, clear colour).

**New selftest cases** come from one new pack, `engine/kernel/examples/ex_kit`, and one bot run:

| Case | What the bot measured |
|---|---|
| `kit.ball_on_ice_slides_by_law` | a `TLKit` ball on a `TLKit` ice patch slid 4.57 m from 3 m/s: friction 0.1005 against the law's 0.10 |
| `kit.wall_and_crate_break` | `barrier_wall` into 16 pieces and `crate` into 6, settled and baked through `TLFracture` |
| `rig.biped_walks_and_skates` | real 29-bone rig, walk 2.30 m/s with a leg-bone swing of 0.57, skate 9.5 m/s, 9.2 m/s after 2 s of coasting |
| `rig.vehicle_drives` | real coupe rig, 1,150 kg, wheels spin, steering right turns the wheel -0.22 rad and the car right |
| `standin.fallback_still_works` | stand-in rigs given by hand: walk 2.30 m/s, car 10.3 m/s |
| `kit.lint`, `kit.bot`, `kit.invariants` | zero bypasses, bot ok, same hash twice |

**Frames I looked at** (five windowed `ex_kit` captures on Direct3D 12, as half-size sheets; they were written to a temp folder, not kept under `engine/`):
- The lane-B look is installed: painted sky, ink lines, toon bands.
- The biped is mid-stride on kit concrete and the skater is on the ice lane.
- The kit wall is cracked into pieces with the steel ball in it.
- The coupe sits on tarmac with its shadow.
- Kernel-made balls are plain black: the stand-in material.
- One `k.sh cap main hero` in the engine project matches `b_hero.png`.

## Kernel change list

| # | File and line | What | Why |
|---|---|---|---|
| 1 | `kernel/runner/worker.gd` ~228, `kernel/host/host.gd` ~148 | a bot not done within `--frames` ends as `failed`, exit 1, with an error of kind `bot` starting `frame_budget:` | Director's decision 1; `bad.bot_never_done` now expects 1 |
| 2 | `kernel/host/host.gd` ~322 | windowed worker driver order is Direct3D 12 three times | Director's decision 5 |
| 3 | `kernel/api/tl_vehicle.gd` 266, `kernel/standin/tl_standin_rig.gd` 112 | the controller sends `-steer` to the rig; the stand-in follows the rig's sign | controller counts + as right, `RIGS.md` counts + as left; wheels would have turned the wrong way |
| 4 | `kernel/standin/tl_standin.gd` 39 | new `standin_rig(family, params)` | the fallback was untestable once `TLRigs` was installed |
| 5 | `kernel/api/tl_bodies.gd` 105, 241 (+34 lines) | option `lock` on `make` and `from_part`; new `TLBodies.drive(body, velocity, max_accel)` | the kernel had no way to move a kit `paddle` under control |
| 6 | `kernel/runner/lint.gd` ~203 | `README.md` allowed at the pack root | the brief wants one per seed; lint rejected it |
| 7 | `kernel/api/tl_contact.gd` ~37 to 46 | a body touching several tagged surfaces follows the lowest-friction pair, alphabetical on a tie | determinism bug, below |
| 8 | `kernel/API.md` | sections 4, 13, 14, 15, 16, 17, 18 and the examples table | keeps the document true |
| 9 | `tools/selftest.sh`, `tools/tl.sh`, `tools/seeds.sh` (new), `tools/k.sh` | kit cases; `seeds` verb; paths | |

Changes 5 and 6 go beyond "integration fixes"; you may want to bless or strike them. Nothing else at the seam needed changing: laws on kit bodies, `TLBall` and `from_part` on kit dynamic props, `TLFracture` on kit `Intact`/`Pieces`, and the rig calls all worked as written.

**Change 7 is the main finding.** The `seed.wall` bot gave two different results for the same seed (19.8 s in 8 runs, 20.3 s in 3). `TLContact` took the pair law from the first colliding body the physics engine reported. I did not confirm that the reporting order varies; I inferred it, changed the rule, and the symptom stopped: 10 of 10 runs then gave one hash. `invariants` could not catch it because smoke presses nothing, so nothing breaks.

## The seeds
All three are under `engine/seeds/`. `bash engine/tools/seeds.sh` runs every verb on each: 24 passed, 0 failed.

| | `seed_paddle` | `seed_drive` | `seed_wall` |
|---|---|---|---|
| lint, smoke, invariants, bot | exit 0 | exit 0 | exit 0 |
| Fence errors | 0 | 0 | 0 |
| Script / test lines (lint) | 128 / 33 | 130 / 46 | 133 / 51 |
| Data lines | 77 | 87 | 80 |
| `kit_parts_added` | 0 | 0 | 0 |
| `bypasses` | none | none | none |
| Hash at seed 1, twice | `bc93a9a4c892f2ab` | `b9adbb1967e36108` | `da4bdc3f65cc07ae` |
| Hash at seed 2 | `000eda488e72f0fe` | `e6662471f07f7d94` | `4b2de68d7beff849` |
| What the seed changes | first serve and serve angles | cone jitter | block toughness, piece scatter |
| Bot at seed 1 | wins 5 : 0 in 6,775 frames | 3 laps in 58.6 s of 90 | 40 pieces down in 20.3 s of 60 |
| Bot at other seeds | 5 : 0 at seeds 2 and 3 | same at seed 2 | wins at seeds 2 to 5 (40 to 45 pieces) |
| Five repeated bot runs, seed 2 | one hash | one hash | one hash |

- **`seed.paddle`:** the bot presses only `left` and `right`, predicts where the ball crosses its line, and offers the paddle edge away from the rival. The court is ice and the ball is `planar`, so it glides by the rubber-on-ice law.
- **`seed.drive`:** the bot steers to a near point and slows for a far point. It visited the pad 3 times, used 3 nitro bursts, and stayed within 1.2 m of the centre line.
- **`seed.wall`:** the bot lines up, creeps forward to face the wall, and throws; 16 throws broke 6 of 6 blocks.

Each seed has a `README.md`. `engine/seeds/README.md` is the "how to write a pack" page with ten mistakes I actually made.

## Captures
- Contact sheet: `C:\Users\kazda\kiro\third-life\engine\seeds\captures\seeds_sheet.png` (3 seeds x 2 cameras x 2 frames, bot playing). `seeds.sh sheet` rebuilds it.
- The 12 single frames are in the same folder (`paddle_court_f400.png`, `drive_chase_f110.png`, `wall_yard_f900.png` and so on).
- Lab check: `C:\Users\kazda\kiro\third-life\engine\kits_lab\captures\wp4_check_main_hero.png`.

I looked at the final sheet. All three seeds hold the lane-B look: forest, mesas, cabin, ink lines. One blemish: the kernel's stand-in `TLVfx` particles are unlit squares that fly wide, visible in the wall frames.

## Not verified
- `tl.sh play` on the seeds, and so the real-key path of `TLInput`.
- The HUD was never seen: captures hide it, and the bots check only its text.
- Sound was checked through the event log only.
- Only one `k.sh cap` was run in the engine project; the `sheet`, `owed`, `stats` and `swaptest` paths were edited but not run.
- No seed uses rule periods, pause/resume, `standings()`, biped `jump`, vehicle reverse, or two vehicles touching.
- The bot-determinism fix rests on 25 identical runs, not on a proof.

## Where the documents misled me (proposed wording)
1. **`KIT-RIG-STYLE.md`, vehicle `steer`:** the sign is not stated. Proposed: "`steer` (-1..1, + = left). `TLVehicle.set_controls` takes + = right and converts."
2. **`PACK.md` layout:** add "`README.md` (optional): the only file besides `pack.json` allowed at the pack root."
3. **`API.md` section 17:** "follows one" did not say which, and it was not repeatable. Now written as the lowest-friction pair. Consequence worth stating: a ball on ice bounces off a wall with the ice pair's restitution, not the wall's.
4. **`API.md` HUD:** widget ids were not documented; I added "`score_<side>`, `clock`, `speed`, or your own id".
5. **`KIT.md`, `cone`:** nothing says how to get a cone a car can knock over. `seed.drive` re-tags it by hand (`_loose_cone`). Proposed: a `loose: true` param on small props.
6. **`LAYOUT.md`, `walls[]` with `p` + `yaw`:** it reads as one part, which would break all at once under one `TLFracture`. I did not test this; I used one `barrier_wall` prop per block instead. Worth one sentence either way.
7. **`LAYOUT.md`:** say that `cams` values are `Vector3`, and that the layout has no way to mark places for the game. Checkpoints, cone places and the start had to go into `tuning.json`. Proposed: `markers[]: {id, p | on, yaw, r}`.
8. **`API.md`, `nitro_charge`:** documented as a member, but not as writable. The pad writes it.

## What is still missing

**For hockey**
- One physics material per body means a puck on ice hits the boards with the ice pair's bounce.
- No link between a rig clip and a game event: `shoot` has contact at 0.42 s, but nothing calls back at that moment or reports clip time.
- No possession beyond `hold`/`release`: no pick-up on stick contact, steal, or shot charge.
- Biped against biped contact (checks) is untested; there is no goalie and no backward skating.
- Rules have no stoppage-and-restart helper; I wrote the serve reset by hand. Periods and pause/resume are unexercised.
- `TLSteer.intercept_point` ignores walls, so the paddle rival misjudged banked shots. There are no team roles.
- No helper turns the kit goal's `tl_mouth` into a trigger; the layout has one `spawn`, not a list.
- Twelve 9,652-triangle rigs ticking together are unmeasured.

**For racing**
- No speed planning in `TLSteer`: `keep_lane` gives no curvature ahead. My bot left the road at 12.5 to 14 m/s on a 22 m bend until I gave it a speed-scaled far point.
- Two vehicles colliding is untested.
- No reset-to-track or wrong-way detection; my first bot wandered on grass for 100 s.
- No start countdown; `standings()` is untested.
- Kit roads have no banking or height profile, and kerbs are tagged asphalt.
- Cones and tyre stacks are static; there is no start gantry or grid.
- Vehicle damage and `walls[]` along a circuit as crash barriers are untested.

## Questions
1. Do you accept kernel changes 5 (`lock` and `TLBodies.drive`) and 6 (`README.md` at the pack root)? The Foreman's frozen engine snapshot still has the old lint and would reject the seeds' README files.
2. Should `invariants` also replay a bot twice and compare hashes? Smoke-only determinism missed a real kernel bug.
3. Should `TLVfx` delegate to `TLStyleFx` when the style layer is installed, so effects match the look?
4. Should `tl.sh selftest` include the seeds, or stay kernel-only with `tl.sh seeds` beside it, as now?

The journal is current at `C:\Users\kazda\kiro\third-life\engine\JOURNAL.md`, under the "WP4" heading.

---

## Director verification

Done 20:56 to 21:12 CEST on 2026-11-10, after the builder had stopped.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash engine/tools/tl.sh selftest`, first run (20:56, while the other builder's real job and its Godot runs loaded the machine) | **57 passed, 3 failed**, 307 s. All three failures are the wall-clock frame budget: `ex.car.invariants` p99 45.5 ms, `kit.invariants` p99 13.7 ms against 8 ms, with p50 at 0.5 to 0.7 ms |
| the same, second run (21:04, machine quiet) | 60 passed, 0 failed, 114 s |
| `bash engine/tools/k.sh selftest` | 86 passed, 0 failed |
| `bash engine/tools/k.sh validate` | 7 files, 0 failed |
| "kitlab" under `engine/` (scripts, scenes, JSON, docs, shell) | no hit |

The Director's own run of each seed, spawned directly as `RUNNER.md` says (script
`seedtest.py` in the session scratchpad), not through `seeds.sh`:

| | `seed_paddle` | `seed_drive` | `seed_wall` |
|---|---|---|---|
| lint, smoke, invariants | exit 0 | exit 0 | exit 0 |
| lint `composability` | scripts 128, tests 33, 0 kit parts added, no bypass | 130, 46, 0, none | 133, 51, 0, none |
| frame p99 (quiet) | 0.58 ms | 0.92 ms | 0.59 ms |
| bot, seed 1, three runs | one hash; wins 5 : 0 in 6,775 frames | one hash; 3 laps in 58.6 s | one hash; 40 pieces in 20.3 s |
| bot, seed 2 and seed 7 | hash differs; wins 5 : 0 both | hash differs; 3 laps both | hash differs; 45 and 40 pieces |

Smoke hashes at seed 1 match the builder's table (`bc93a9a4...`, `b9adbb19...`, `da4bdc3f...`).

**Looked at:** `engine/seeds/captures/seeds_sheet.png`. All three seeds are in the lane-B look (painted sky, ink lines,
forest, cabin, stands). The paddle court and the drive loop read at once. In the wall frames the white squares of the
stand-in particles are visible, as the builder says. The rigged biped is small in both wall cameras.

### What is not verified

- `tl.sh play` on any seed, so real keys through `TLInput`; the HUD (captures hide it); sound beyond the event log.
- Kernel change 7 (which surface law a body follows when it touches several) rests on repeated runs, 25 by the builder
  and 9 by the Director, not on a proof of the cause.
- The Director did not re-run a capture of a seed; the sheet is the builder's.

### Findings the builder did not report

1. **The wall-clock budget misfires under load** (first table row). With two or more builder sessions running Godot at
   once, a correct pack can fail V3. The Foreman now re-runs a clock-based verdict once (WP3b); that is a patch, and the
   risk stays open for Phase 1.
2. **A pack that makes its own materials renders almost black on this engine.** The marble-run pack from the first real
   job (built against the 20:00 copy of the engine, before the kit and the style were in it) passes every verb on the
   live engine, but its capture shows near-black wood, ice and marbles against the painted sky:
   `docs/reports/img/marble_on_live_engine_f1000.png`. The style layer and plain `StandardMaterial3D` or stand-in
   materials do not go together. To fix before any job runs on this engine.
3. For that same pack the smoke hash is equal on the old and the new engine and the bot hash is not (`10ea52e9...`
   against `dda2bb9e...`) while the bot's result is the same. Hashes are not comparable across kernel versions; the
   cause is most likely change 7.

### Director's decisions on the builder's questions (contracts amended 2026-11-10, second round)

1. **Kernel changes 5 and 6 are accepted.** `lock` and `TLBodies.drive` are a primitive a paddle game needs; without
   them packs would bypass. `README.md` is allowed at the pack root (`PACK.md` amended).
2. **`invariants` replays the first bot twice and compares the hashes**, in addition to the idle run. Smoke-only
   determinism missed a real kernel bug. To build.
3. **`TLVfx` uses the style layer's effects when the style is installed.** To build.
4. **`selftest` stays kernel-only, `seeds` stays beside it**; the acceptance gate is both.
5. The steer sign is written into `KIT-RIG-STYLE.md` as proposed. Layout `markers[]` and a `loose` prop parameter are
   recorded as kit gaps for Phase 1, not built now.
