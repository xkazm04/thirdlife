# N7 one world you can walk through: builder report and Director verification

Brief `briefs/BRIEF-N7-WORLD.md`. Builder wall time 03:23 to 04:10 on 2026-11-11 (46 min; harness: 458,155 subagent tokens, 141 tool uses). Work done in the main tree.

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

**N7 report: one world you can walk through**

## Status

Items 1 to 5 are built and proven by the tools; all four gates and `view.sh check` pass; seed hashes are unchanged. No person has walked the world: the WASD path is written and has only been run for 200 ticks with no key pressed. All timing figures were taken under load (other sessions' engine jobs ran throughout).

Work was in the main tree, `C:\Users\kazda\kiro\third-life\engine\`. No git command was run, no network used, no process of anyone else killed, never two engine processes of mine at once, no window left behind (checked by command line at 04:10).

## Per item: what was built and what proves it

**1. One host.**
- N5b patches 1 to 4 are applied:
  - 1: `ctx.on_stage` is set in `pack.gd` `load_pack` before the pack's scripts load; `world.gd` passes it.
  - 2: a HUD of a non-stage pack is created hidden (`tl_hud.gd`).
  - 3: `world.gd` has `signal ended`, `quit_on_end`, `exit_code`.
  - 4: host mode `world-view` in `host.gd` and `verbs.json`; `view.gd` takes `start(options)`; `tools/view.sh` starts the host.
- The windowed world runs the scheduler. `world.gd` emits `plot_event` at the tick boundary of each tier event, so the event that changes a plot's ticks also changes its drawing:
  - `stage`: zero offset, its own camera, its HUD.
  - `sideline`: drawn in full at its plot.
  - `backdrop`: its stand-in, ticked on its slice.
  - `ledger`: its stand-in, built just before the pack is unloaded.
- `draw.gd` gained `set_stage(-1)` (nobody on stage), `set_tier`, `forget_nodes`, `replace_holder`.
- `scenery = "plot"` is now the world host's default in every mode (`--scenery=full` brings it back).
- A plot's size comes from the walk's `footprint`, else `footprint` in `pack.json`, else 40 x 40 m.
- Proof: `bash tools/view.sh check --packs=seed_drive,seed_paddle,seed_wall,ex_kit,ex_walker --at=0:0:0,110:0:0,-110:0:0,0:0:105,0:0:-100 --radius=64,40,38,40,30 --stage=1 --cam=court` passes through the host mode with the five hashes of DRAW.md section 6 (36635c04 at 3516, cadd1cd9 at 6776, 6366b88f at 1221, 16db2bf1 at 332, 8d1831dc at 371), 0 leaks, 0 errors. `tl.sh selftest verbs` passes (5 verbs, 3 world modes).
- Ledger drawing was run once in a window with a scratch tiers file (`backdrop_m` 70): PASS, five packs unloaded and three rebuilt, four of its pictures looked at and not kept.

**2. The visitor.**
- `kernel\world\visitor.gd` is a kernel-owned biped rig with a chase camera at the world's `player_pos`. It is visual only and has no body.
- `tiers.gd` has a visitor mode (walk script `"visitor": true`): the stage follows `enter` and `leave` requests, not position. `enter` needs him inside the plot.
- A request that cannot be met is logged as `refused` with its reason; all four kinds were checked with a scratch walk.
- A game that is over and not on stage gets a `restart` event `restart_pause_ticks` (tiers.json: 180) after it ended or was left; on stage it waits.
- In scripted runs the stage pack is played by its bot.
- Live (`bash tools/world.sh visit tour`): WASD, Shift, E, Q or Esc; the stage pack's bot is switched off and its input opened; leaving puts him at the plot's edge. Not verified beyond the 200-tick smoke run.

**3. The proof.**
- `bash tools/world.sh tour tour --out-dir=<abs dir>` runs the window, writes the numbered pictures and the tier log, then proves each pack against itself alone and against the replay.
- `--headless` is the selftest case `world.tour`; `--pictures-only` skips the proof.
- Walk: `C:\Users\kazda\kiro\third-life\engine\kernel\world\walks\tour.json`. Six games, 2900 ticks, 44 events. The visitor walks past the walker room and the paddle court, enters the track at tick 990, leaves at 1440, walks on, enters the wall yard at 2460, leaves at 2800. There were 9 next-round restarts.
- Full log: `C:\Users\kazda\kiro\third-life\engine\kernel\world\captures\tour\world_log.json`.
- Final windowed run at 04:03: PASS, 10 of 10 pictures, 4 stage changes, 0 gate leaks, 0 wrong-pack calls, 0 script errors, 0 engine errors.

**A real bug found by this proof.** The first headless tour failed for exactly the three packs that had been rebuilt for a next round. `_rebuild` runs inside the world's `_physics_process`; the new pack's nodes are not ticked by the scene tree in that frame, but the kernel's calls and the physics step run, so the first tick is half a tick. N5a's return from `ledger` and from `on_leave: end` use the same rebuild. Fix in `tiers.gd`: a rebuilt plot rests one tick (`rest_until`), as schedule state, so the replay does the same. `world.sh proof ledger`, `leave` and `tickets` were re-run afterwards and pass; own ticks differ by one from N5a's figures where a pack was rebuilt.

**4. A landscape.**
- `kernel\world\landscape.gd`, built once, visual only:
  - one ground with the plots cut out;
  - a dirt road with a spur to every plot;
  - around every plot a ring of worn ground, a fence, and a gate with two flags and a sign;
  - pines, broadleaf trees, rocks, bushes, tufts and grass patches between plots, never inside one or on the road;
  - a forest belt and 18 layered mesas;
  - two fenced building lots with a crane, scaffold and timber;
  - haze at 0.4 of the style's fog, set on the world's environment only.
- Plots stand 8 to 11 m apart at their edges; the village is about 310 x 225 m.
- Three passes, a capture looked at after each.

**5. The pictures**, in `C:\Users\kazda\kiro\third-life\engine\kernel\world\captures\` (with `.gdignore`), every one looked at:
- `world_overview.png`: the village from a low hill, the one to put beside the concept.
- `world_vs_concept.png`: the concept and that picture side by side.
- `far_and_near.png`: the walker room at 45 m in full, the track at 150 m as its stand-in, the visitor on the road.
- `world_from_above.jpg`
- `tour\01_on_the_road.jpg` to `tour\10_overview_end.jpg`
- `check_from_paddle.jpg`

The tour frames and the check picture are JPEG copies (18 MB in all instead of 48); `world.sh tour` itself writes PNG. The three crane views come from `bash tools/world.sh tour tour_views --out-dir=<abs dir> --pictures-only`.

**Document.** `C:\Users\kazda\kiro\third-life\engine\kernel\world\WORLD.md` covers how the pieces fit, the walk and tour format, what a pack author must know, cost, pictures, and what is not built. `kernel\API.md` sections 19 and 20 are updated and 21 is new.

## Hash table (final windowed tour, drawing on)

| plot | pack | own ticks | tiers seen | in the tour | alone, same ticks | replay of the log |
|---|---|---|---|---|---|---|
| drive | seed.drive | 2750 | backdrop, sideline, stage | f3407ff79de7f5ed | same | same |
| wall | seed.wall | 789 | backdrop, sideline, stage | b292d65189cfb7e3 | same | same |
| walker | example.walker | 371 | sideline, backdrop | 8d1831dc62dfe91a | same | same |
| paddle | seed.paddle | 2361 | sideline, backdrop | 2ae96170ccdc177d | same | same |
| kit | example.kit | 8 | backdrop, sideline | 0b8e94244b9e3323 | same | same |
| car | example.car | 1864 | backdrop, sideline | bf2f98da41aff5d7 | same | same |

The headless tour gives the same six hashes.

## Gates

- On the files of 03:46: `tl.sh selftest` 78 passed, 0 failed; `tl.sh seeds` 24 / 0 with hashes bc93a9a4, b9adbb19, da4bdc3f (seed 2: 000eda48, e6662471, 4b2de68d), unchanged; `k.sh selftest` 86 / 0; `item.sh selftest` 91 / 0; `view.sh check` PASS.
- On the final files at 04:08: `tl.sh selftest world.` 7 / 0, `tl.sh selftest verbs` 1 / 0, `view.sh check` PASS. `world.walk_proof` still gives N5a's hashes (59c7f07b, 2962e912, 6366b88f).
- Between the two rounds only `landscape.gd`, the two walk scripts, `world.sh` (WARNING lines, one verdict's wording, `--pictures-only`), `selftest.sh` (one verdict's text) and documents changed. Seeds, k and item were not re-run after that.

## Cost per tick in the tour (under load)

| | p50 | mean | p99 |
|---|---|---|---|
| headless, simulation only | 1.69 ms | 2.35 ms | 3.02 ms |
| window 1920x1080, whole frame | 2.69 ms | 5.69 ms | 10.26 ms |

- The kernel's own calls into the packs are 0.55 ms p50.
- Per picture: 141 to 508 draw calls, 0.88 to 1.67 million primitives; render CPU 0.35 ms, GPU 1.2 ms.
- The mean sits above the median because a rebuild from the seed and a pack's first stand-in happen inside one tick. The longest headless tick was 433 ms.
- The landscape builds in 0.36 to 0.74 s.

## Still wrong in the picture against the concept

- The ground is flat: no hills, cliffs, river or bridge between venues. The concept's composition lives on relief.
- Venues are small in the frame and far apart at their centres (radii 30 to 64 m). The concept packs a rink, a track and a house into about 150 m.
- Plots are still circles; a fence and a ring help at eye level, but from above they read as discs.
- `ex_car`'s own floor is a plain beige disc; `ex_kit` and `ex_walker` are grey test rooms, not venues.
- Mesas are stacked prisms with no trees or detail; a few came out as thin towers.
- The grass is one saturated lime tone; the patches are angular.
- Nothing is being built: the lots have a crane and a scaffold, but no crew bots and no hologram frame.
- The visitor stands at y = 0 while a pack's ground dips inside its plot (he hovers at the track's rim), and he walks through fences and trees.
- A black ink line shows along a plot's bent rim seen close (pictures 04 and 06).
- Stand-ins have no moving parts.
- From the high crane the top of the picture is washed by haze.

## What a pack author must know

- Nothing in a pack changes; API.md 19 to 21 and DRAW.md section 10 hold.
- `ctx.on_stage` is false from the first line of `_pack_setup` until the visitor enters. A HUD is created hidden. Do not set `visible` on a `TLHud` or make a camera current yourself.
- On entering, your active view (the first registered, unless you activated another) becomes the picture. Register the play view first.
- When your game is over and nobody is in your plot, you are rebuilt from your seed 3 s later with nothing carried over, not even `_pack_save` data. Keep no state in `static var`.
- You bring a venue, not a landscape: in a world your layout has no far terrain and no scattered forest.
- Declare `footprint` in `pack.json`. No seed or example does yet, so tonight's radii are in the walk script.
- A big flat floor of your own reads as a disc from above.

## Files changed (under `C:\Users\kazda\kiro\third-life\engine\`)

- New:
  - `kernel\world\landscape.gd`
  - `kernel\world\visitor.gd`
  - `kernel\world\WORLD.md`
  - `kernel\world\walks\tour.json`
  - `kernel\world\walks\tour_views.json`
  - `kernel\world\captures\**`
- Changed:
  - `kernel\world\world.gd`
  - `kernel\world\pack.gd`
  - `kernel\world\tiers.gd`
  - `kernel\world\tiers.json`
  - `kernel\world\TIERS.md`
  - `kernel\world\draw\draw.gd`
  - `kernel\world\draw\view.gd`
  - `kernel\world\draw\DRAW.md`
  - `kernel\world\draw\PATCHES.md`
  - `kernel\host\host.gd`
  - `kernel\runner\verbs.json`
  - `kernel\api\tl_hud.gd`
  - `kernel\API.md`
  - `tools\world.sh`
  - `tools\view.sh`
  - `tools\selftest.sh`
  - `JOURNAL.md` (section "N7")
- Not touched: `kernel\api\tl_context.gd`, `kits\**`, `style\**`, seeds, share, lint, manifest, cameras.
- Not mine: `ui\` and `tools\ui.sh` arrived in the main tree at 03:52 while I worked. The engine's import during one of my runs created `ui\*.gd.uid` at 03:57.
- One slip: I briefly wrote ten preview JPEGs into an existing scratch folder `v1` that held someone else's files, then moved mine out. Nothing else there was touched.

## Not verified

- A person walking it, and the stage pack played by a person.
- One engine warning: one windowed tour printed a trace `CreateJob (modules/jolt_physics/spaces/jolt_job_system.cpp:123)`. Its text was not kept; the tools print WARNING lines now. Engine errors were 0 and the hashes equal in that run. It did not return in two more windowed runs or headless.
- No selftest case draws a ledger; the ledger run was a one-off.
- A stage pack with yaw; more than six games in a window; `world.sh bench`.
- Frame times on a quiet machine.
- `foreman\fixtures\engine\kernel\runner\verbs.json` was not updated (not my scope): it must follow the engine's file (new mode `world-view`, `scenery` default `plot`).

## Brief premises that did not hold

- "A pack's plot comes from its `footprint`": the world reads it, but no pack declares one.
- "The kit has road and ground parts": `TLKitRoad` builds a tarmac circuit with kerbs. The dirt road is built in `landscape.gd` from `TLKitPath` and `TLMesh`; the kits are unchanged.

## Questions

1. Should the seeds and examples declare `footprint` now? Proposed: drive 128 x 128, wall 76 x 76, paddle, kit and car 80 x 80, walker 60 x 60.
2. Is "next round carries nothing over, after 3 s" the rule you want, or should `_pack_save` data survive a round?
3. Should the visitor get a body and the world a space of its own (fences, trees, a pack's ground under his feet)?
4. Which view is the play view on entering: the first registered (today), or a manifest key?
5. Are JPEG copies of the tour frames in the main tree acceptable, or do you want the PNGs?
6. Should lint report a pack whose own floor fills its footprint (the disc)?

## Minutes

Start 03:23:16, end 04:09:37 (from `date`): 46 minutes of the 100.

---

## Director verification

Done 04:10 to 04:25 on 2026-11-11, after the builder had stopped, on the main tree where it worked.

### What was re-run, and the result

| Check | Result |
|---|---|
| `world.sh tour tour --headless` | six packs, each: in the tour = alone for the same ticks = replay of the log (`f3407ff7...` drive 2750 ticks, `b292d651...` wall 789, `8d1831dc...` walker 371, `2ae96170...` paddle 2361, `0b8e9424...` kit 8, `bf2f98da...` car 1864): the builder's six hashes |
| `world.sh tour tour --out-dir=<scratch>` in a window | PASS with the same verdict; 10 of 10 pictures, 4 stage changes, 44 events, 0 gate leaks, 0 wrong-pack calls; frame median 2.6 ms (simulation and drawing), mean 5.5 ms, p99 8.8 ms |
| `view.sh check` through the new host mode | PASS: every pack's hash with drawing on equals its headless hash |
| `tl.sh selftest`, `tl.sh seeds`, `item.sh selftest`, `k.sh selftest`, `ui.sh selftest` | 78, 24, 91, 86 and 69 passed, 0 failed |

**Looked at:** `kernel/world/captures/world_overview.png`, `far_and_near.png`, `world_vs_concept.png`,
`tour/04_at_the_track_edge.jpg`.

### What the Director saw

- It is a place now. From a low hill: the paddle court with its stand and scoreboard in front, the track with its
  cabin behind, a crane over a fenced lot, dirt roads with fences and gates, a forest belt, mesas, the painted sky.
  Beside the concept the kinship is plain: the same kinds of things in the same light.
- What separates it from the concept: the land is flat, the venues are small and spread out where the concept packs
  them tightly on relief, the grass is one lime tone, the mesas are stacked prisms, and nothing is under construction
  (no crew, no hologram frame).
- At eye level the visitor stands at the track's rim with the game running below him. He hovers a little above the
  dipped ground, and a black line runs along the plot's bent edge.
- The tour's proof is the strongest result of the night: a windowed world with a walking visitor, six games changing
  tier, two of them entered and left, nine next-round restarts, and every game still equal to itself alone.

### What is not verified

A person walking it (WASD ran for 200 ticks with no key pressed); the ledger tier in a window (a one-off by the
builder, no selftest case); more than six games in a window; the cost figures on a quiet machine; the one Jolt
`CreateJob` warning the builder saw once and could not reproduce.

### Director's decisions on the builder's questions

1. Seeds and examples should declare `footprint`; the builder's proposed sizes go into the next kernel pass.
2. A next round that carries nothing over, after 3 s, is accepted for now.
3. The visitor needs a body and the world a space of its own (fences, trees, a venue's ground under his feet): next step.
4. The play view on entering stays the first registered view until a pack can name one.
5. JPEG copies of the tour frames are tracked; the PNG originals are ignored by git.
6. A pack whose own floor fills its plot reads as a disc from above: recorded as a lint idea.

The builder's finding about rebuilt packs (a half tick in the frame of the rebuild, now a one-tick rest in the
schedule) also corrects N5a's ledger and `on_leave: end` paths; their proofs were re-run by the builder and pass.
`foreman/fixtures/engine/kernel/runner/verbs.json` follows the engine's file again.
