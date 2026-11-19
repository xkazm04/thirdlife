# Timber Run — Skyline

The fourth stage starts at the old summit stripe. The perfect hand completed the full course in **986 race frames (16.433 seconds)** on both seeds. It made both transfers without a fall or counterweight hit. The finish board recorded **338 / 286 / 182 / 180** frames for High line, Swing yard, Summit and Skyline. [Seed 1](final/bot_course-1.json) · [Seed 2](final/bot_course-2.json) · [Windowed full run](astra-run-4.mp4) · [Contact sheet](../../stills/astra-4/contact-sheet.jpg)

## What the player does

| Section | Geometry and controls | Perfect-hand observation |
|---|---|---|
| Headwall | Turn across the old high line, run toward the concrete face and jump. The lip is 3.00 m above the approach. Hold forward or tap Space to mantle. C drops back to the approach. | Hang at sample 843, mantle at 844, then stand on the runway. |
| Blue to red | Jump from the striped runway to a transverse steel bar. Blue is 1.30 m beyond the end and 3.05 m above it. Pump across the bar and use Space on the rising forward stroke. Red is 4.00 m further on and 1.55 m higher. | Blue caught at 921, released at 927. Red caught at 945. The transfer was airborne. |
| Red to finish | Release again and land on a timber ramp starting 3.50 m from red. Its 2.20 m rise over 3.90 m gives different trajectories a landing surface. Both coloured grips must be touched in sequence on this attempt. A fall takes the runner back to the runway. | Red released at 951. The final split was 180 ticks, or 3.00 seconds. |

The HUD gives the headwall, blue, red and landing cues. The whole-course clock and the current stage clock continue on a fall. The split test waits at the headwall only on lap one and at the start only on lap two. It produced splits of 338 / 286 / 182 / 224 and 418 / 284 / 182 / 180. Skyline’s stored best improved by 44 ticks. The four stored bests were 338 / 284 / 182 / 180. The moved expectation in `bot_splits` is four splits because Skyline adds a fourth finish. [Split and restart proof](final/bot_splits-1.json)

The kit catalogue offered `ground_patch`, `kerb`, `scaffold`, `arch_rib`, `flag`, `timber_frame`, `lumber` and `goal`. Ground patches form the wall, decks and bearing blocks. Kerbs mark the takeoff and landing. Two steel arch ribs carry the rods, and a scaffold carries the finish ramp. A horizontal kit flag has a bounded cylindrical steel collider. The pack marks its static body with `TLBiped.mark_bar`, with the pennant identifying the grip. All geometry uses existing kit parts. The pack walker opts into ledge and bar and keeps the walking controls. The operator’s earlier F check found only jump, forward and run in the stage input record, followed by 11.077 m of village flight after exit. [Flight boundary evidence](../round2/fly-probe-visit.txt)

## What happens to a missed move

- Against the headwall, holding run and forward for 75 grounded ticks never reached the runway. The same walker jumped, hung for 18 ticks, dropped back to the approach with C, then mantled and finished. [Headwall control](final/bot_headwall-1.json)
- Running off the runway missed blue. The runner descended 3.85 m below runway level. Releasing blue at the bottom missed red and descended 3.77 m below runway level. Releasing red at 0.81 rad while swinging back at −5.10 rad/s missed the ramp and descended 3.76 m. Each attempt returned to the runway with three splits intact. The fourth, timed attempt finished. [Bar controls](final/bot_grips-1.json)
- Enabling ledge catch exposed a handhold on the earlier run-up crest when its test rise was set to 2.40 m. I recessed the concrete pier by 0.82 m behind the timber nose. The playable 0.72 m crest still takes a running jump. The original 2.40 m mutation once again causes a physical fall. The perfect-run test also rejects a hang or mantle at this crest. [Crest mutation](impossibility/crest-bot_course.json) · [Walking jump control](final/bot_wall-1.json)
- A capsule can skim a pad or the beam with its feet outside the landing stripe. Previously a missed gate could remain pending while the walker ran all the way to the far wall. The pack now retries a grounded runner that has passed the complete landing. It grants the next checkpoint only under the original landing conditions. Replays on newcomer seeds 3, 7, 12 and 15 covered each of the four affected gates. Disabling the retry reproduces the 60-second timeout in a dedicated perfect-hand test. [Four replays](missed-landings.tsv) · [Passing control](final/bot_landing_recovery-1.json) · [Disabled control](omission-mutations/landing-disabled.json)

## Difficulty by hand

| Level | Hand | Wins before | Wins with Skyline | Mean frames before | Mean frames with Skyline |
|---|---|---:|---:|---:|---:|
| Course | newcomer | 20/20 | 18/20 | 1,766 | 2,670 |
| Course | regular | 20/20 | 20/20 | 970 | 1,291 |
| Course | sharp | 20/20 | 20/20 | 841 | 1,081 |
| Forced C retry | newcomer | 20/20 | 17/20 | 1,698 | 2,467 |
| Forced C retry | regular | 20/20 | 20/20 | 1,062 | 1,378 |
| Forced C retry | sharp | 20/20 | 20/20 | 898 | 1,186 |

Each level/profile cell completed all 20 seeded samples. Means include 3,600-frame timeouts. The figures compare the original three stages with the new four-stage race on API 1.10. The newcomer finished 18 open races and 17 forced-retry races. Both regular and sharp finished all 40 of their runs. [Three-stage ladder](ladder-before.txt) · [Four-stage ladder](ladder-after.txt)

Every ladder hand uses the same takeoffs, steering, release target and retry policy. The Skyline driver measures the interval from its last jump request to the observable pressed edge, smooths the measured delay and uses it to lead the next takeoff or release. At running entry speed it aims to deliver Space about five ticks into the forward swing, around 0.63 rad. It pumps using observed angle and angular speed if it misses that swing. Only the profile given to `TLHand.create` changes. The separately scripted perfect-hand course proof retains its original high-line takeoff and uses the shared return and Skyline driver.

## Impossibility checks

In each row one data value changed in a scratch copy. Each geometry check and actual course run exited **1** with only `bot.ok` failing. All nine older data cases also remain red in both tests. Removing the old counterweight contact still turns the phase test red. [All mutation runs](impossibility/results.txt) · [Contact control](omission-mutations/weight-disabled.json)

| Obstacle | Single mutation in `data/upper.json` | Geometry diagnosis |
|---|---|---|
| Headwall | `ledge_rise_m = 4.3` | Above the 3.80 m upper catch bound. |
| Blue grip | `first_bar_rise_m = 4.5` | Above jumping hands plus the 0.35 m catch tolerance. |
| Transfer to red | `bar_spacing_m = 19` | Exceeds the optimistic 10.10 m first-swing transfer bound. |
| Landing from red | `landing_gap_m = 21` | Exceeds the optimistic 11.56 m landing bound. |

## Verification

| Gate | Result |
|---|---|
| Original three-stage pack | PASS lint and 28/28 bot runs on seeds 1 and 2. [Baseline results](baseline/results.txt) |
| Fourth stage through the headwall | PASS lint and 30/30 bot runs on seeds 1 and 2 before adding either marked bar. [Headwall results](headwall/results.txt) |
| Final pack lint | PASS schema, layout, code fence, capabilities and size. [Lint report](final/lint.json) |
| Every registered pack test | PASS 34/34 runs, 17 tests on each of seeds 1 and 2. [Per-test exit lines](final/results.txt) |
| Full pack and world checks | PASS packs, 47/47 verb runs across both packs. PASS world, 8/8 registered games matched their solo hashes. Parkour matched at 988 sampled ticks including its finish. [Gate output](gate-full.txt) · [Per-game hashes](world-registry.txt) |
| Fast check | PASS arch 12/12, assets 4/4, cards 3/3, devx tests 229/229 and Foreman typecheck. [Gate output](gate-fast.txt) |
| Seeded replay | PASS two idle runs at 3,600 ticks matched `ddd6406508628e98`. Two perfect-hand runs at 988 ticks matched `f7abac006a45bd43`. [Invariants](invariants.json) |
| Six ladder cells | PASS 120/120 completed samples before the stage and 120/120 after. Wins are reported above. |
| Geometry and omission controls | PASS all 26 expected exit-1 results across 13 impossible geometries. Both disabled-mechanic controls also exit 1. The separate 3.05 m kernel repro is described below. |

## Findings for the Director

**Reachable floor rejected by the ledge standing-room check.** Starting from the shipped course, change only `upper.json`’s `ledge_rise_m` from 3.00 to 3.05 in a scratch copy. Run `tests/bot_geometry.gd` and `tests/bot_course.gd` at seed 1. Geometry exits 0. The runner arrives at the face with sufficient height, makes no catch and times out at checkpoint 12. At race tick 842 the face and its walkable top are present. The hang pose and its swept path are clear. The proposed standing pose overlaps the supporting top itself by **0.00000024179462 m** at the 0.001 m physics margin. Moving only the diagnostic query up by 0.0001 m clears it. The shipped 3.00 m wall uses ordinary kernel catches at the origin and at the translated test site. The kernel’s standing-room tolerance merits a regression fixture. [Geometry pass](impossibility/lip-fit-bot_geometry.json) · [Course failure](impossibility/lip-fit-bot_course.json) · [Probe and invocation point](ledge-fit-probe.gd.txt) · [Contact and clearance](ledge-fit.txt)

**Additional translated-physics diagnostic.** The isolated village simulation and the solo runner agree through the complete race. Forcing the *physics root* to `--at=-186:1:-32` also completes in 986 frames with the same four splits and zero falls. Its hash differs. The two differing public fields at the finish are `return_x` (44.1526 / 44.1525) and `station` (−1.5385 / −1.5383). The prior three-stage checkout also fails this artificial translation comparison. The village places its plot separately and simulates the pack at its own origin. The command for the additional check is `bash engine/tools/world.sh alone --packs=parkour --mode=bot --frames=1000 --at=-186:1:-32`. The translated-root hash discrepancy remains open. [Isolated world and solo](world-full-lap.txt) · [Translated comparison](world-translated.txt) · [Public field differences](translated-states.json) · [Before Skyline](world-baseline-translated.txt)

## Presentation

The gallery contains the village road, course overview, recessed crest support, headwall catch, blue swing, mid-air transfer, red catch, ramp landing and finish board. The village-road still is the first shot in the operator’s walk. [Road walk](../views/road-walk.json) The windowed full-run clip uses seed 1, the orbit camera and the live HUD. It plays at **60 fps for 17.400 s**, including the finish hold, with no speed-up. [Gallery](../../stills/astra-4/contact-sheet.jpg) · [Full run](astra-run-4.mp4) · [Recorded state](movie.json) · [Encoded stream](clip-stream.json)

The stage, tests, HUD, stills and clip are complete. The two engine observations above are open for the Director.
