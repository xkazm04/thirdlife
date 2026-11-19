# Timber Run, round 2

The site cabin now shows its door and lit window through the first jump. Its center is at local x = −13 m, inside the gap from −14 to −10.6 m. A broadleaf behind the start and two pines by the crane frame the three decks. Removing the yard's automatic scatter opens the hills, and moving the western mesa closer gives the airborne runner the cliff backdrop seen in D. All four pack comparisons use the original seed, cameras, bot and physics frames. [Contact sheet](../stills-r2/contact-sheet.jpg) · [Five D / before / after comparisons and four village pairs](../stills-r2/comparisons/)

## Village edge

**The yard blends into the village at the inspected edge.** Before the change, ochre dirt extended almost to the east fence. Now the dirt fades into grass before the village's worn fence path. A 34 m level pad supports the rim of the 28 m plot. A second, 18 m pad controls the dirt around the works. The visitor crossed the gate, followed the fence and turned at the rock-lined rim. Neither visit showed floating or cut parkour ground, a mesa crossing the fence, or a yard tree outside the plot. The short stone strips beyond the fence are visible in both runs. The village generates these kerbs 10.1 m outside the plot radius. [Gate](../stills-r2/comparisons/through-gate.jpg) · [Across the fence](../stills-r2/comparisons/edge-across-fence.jpg) · [Along the fence](../stills-r2/comparisons/edge-along-fence.jpg) · [Rock-lined rim](../stills-r2/comparisons/edge-facing-yard.jpg) · [Village kerb builder](../../../../../../engine/kernel/world/terrain/village_parts.gd)

The short road photograph uses the supplied 110-tick walk with its original loading behavior. For the longer matched comparison, both windowed tours load the village before movement and use the same path, visitor camera and shot ticks. The before tour uses a verbatim copy of the pack from `16534db426880a5ef0f3e24b1248730538dbd7ab`. Each tour produced five of five requested pictures across 740 world ticks. Each visitor reported zero blocked ticks and 0.0 m maximum path deviation. At the end of the after tour the visitor stood at (−159.54, 1.00, −42.22), 28.37 m horizontally from the plot center. [Walk](r2/plot-edge-walk.json) · [Before](r2/tour-before.log) · [After](r2/tour-after.log) · [Original road framing](r2/road-after.log)

An earlier default-loading tour reached the gate before the course appeared. The shot was at tick 243 and the scheduler built parkour at tick 378. The short default road run built parkour at tick 0. This timing difference is why the matched edge photographs use blocking load. [Late-build gate frame](r2/queued-gate-before-build.png) · [Default-loading log](r2/tour-queued-late-build.log)

To repeat the matched tour from the repository root in Git Bash, use the checked-in walk and a fresh output directory.

```bash
lane="$(pwd)/docs/shifts/2026-11-19-night/lanes/parkour"
bash engine/tools/world.sh tour "$lane/evidence/r2/plot-edge-walk.json" --load=block --pictures-only --out-dir="$lane/stills-r2/repeat"
```

## C retry

**The newcomer hand won 19 of 20 retry trials across seeds 1–20. All 20 races finished.** It uses the regular bot's input policy and success condition. A retry win requires a witnessed block, C return to the checkpoint, slide under the beam and lap finish. On seed 12 the bot saw the block and return, then saw slide mode end at station 30.07 m, before the beam's near face at 30.36 m. It crossed the beam checkpoint in ground mode and finished in 542 race ticks. The diagnostic run reproduced that seed's state hash. It counts as a completed trial and a retry loss. [Ladder output](r2/ladder.log) · [Individual seeds](r2/newcomer-seeds.json) · [Seed 12 trace](r2/seed-12-trace.json)

```text
PASS  ladder:retry_newcomer              0 ms  [20/20] 19 of 20 won (95 %, 85..100) through the newcomer hand
```

## Verification

| Check | Result |
|---|---|
| Fast gate | PASS, 5/5 steps, 245/245 counted units. [Log](r2/fast.log) |
| Full gate, packs and world | PASS, 2/2 steps, 10/10 counted units. Packs completed 35/35 verbs across 2/2 packs. World matched 8/8 games. Hockey's many-game frame budget passed at 0.922 ms against 1.0 ms on this run. [Full gate](r2/full.log) · [Hockey invariants](r2/hockey-invariants.log) |
| Parkour in the world and alone | Both produced `f0f8e8446029a098` at 340 runner frames. [World comparison](r2/world.log) |
| Parkour manifest | All 5/5 bots passed on gate seed 1, plus lint, 3,600-frame smoke and invariants, for 8/8 verbs. The perfect hand finished in 338 race frames with zero falls. The regular and newcomer retry bots finished in 394 and 413 race frames, respectively. [Eight verify reports](r2/pack-verbs.json) |
| Impossible chain jump | In a scratch copy, only `chain_gap_m` changed from 3.8 to 12.0. Both bots loaded and completed. Geometry measured 4.95 m of reach and exited 1. The course bot crossed gap one, fell at gap two and exited 1. Each failed only `bot.ok`. [Negative controls](r2/impossible.json) |
| Pack stills | 1920 × 1080, seed 1, clean-run bot. Overview at frame 1, jump at 73, bar at 228 and chute at 288. [Overview](r2/capture-course.json) · [Jump](r2/capture-jump.json) · [Bar](r2/capture-bar.json) · [Chute](r2/capture-chute.json) |
| Windowed clip | One uninterrupted orbit-camera run from the start stripe through FINISH at 5.63 s. H.264, 1280 × 720, 60 fps, 394 frames, 6.567 s including the finish hold. [Clip](../clip-r2.mp4) · [Movie result](r2/movie.json) · [Stream properties](r2/clip-stream.json) |

## Files and kit

The pack edits are `data/yard.json`, `pack.json`, `README.md` and the two `tests/bot_ladder_retry_*.gd` scripts. The newcomer bot inherits the regular bot and changes only the hand profile. Course geometry, cameras, checkpoints and test expectations are unchanged. The original `scripts/main.gd` retains A15's eight-sample, 10 cm beam check and C7's course-local to global respawn conversion.

The kit catalogue supplied the steel `cabin` and the pine and broadleaf variants of `tree`. I also checked `house`, `ground_patch`, `scaffold`, `kerb`, `flag` and `crane`. The pack uses the existing kit and toon style throughout. There are no kit or kernel edits. The yard layout validator reported one file checked and zero failures. [Kit catalogue](../../../../../../engine/kits/KIT.md) · [Layout validation](r2/layout.log)
