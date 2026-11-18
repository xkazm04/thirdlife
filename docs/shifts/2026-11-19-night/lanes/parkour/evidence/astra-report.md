# Timber Run

F’s 5.63 s clean run now takes place on a scaffold yard facing the village road. A blue-shirted runner crosses two timber decks, slides through a red-and-white gate, and descends beside a crane and a row of tyres. The bar is centred 5.50 m into the landing deck. A blocked player can hold forward, tap C to return to the stripe, then run and slide again. The clock continues throughout the retry.

## Acceptance

| Requirement | Result | Evidence |
|---|---|---|
| Five views beside D | Met | [Contact sheet](../stills/contact-sheet.jpg) and individual pairs for the [course](../stills/D-F-course.jpg), [jump](../stills/D-F-jump.jpg), [bar](../stills/D-F-bar.jpg), [chute](../stills/D-F-chute.jpg) and [road](../stills/D-F-village-road.jpg). The F originals are 1920 × 1080 window captures. |
| Retry after a miss | Met | The regular hand deliberately hit the beam, returned to the checkpoint, slid under the beam and finished on **20/20 seeds**, averaging 468 race ticks. On seed 1 the same probe previously reached the time limit at 3,600 ticks. The revised run finished in 394 ticks and observed 4.50 m remaining to the near face just after respawn. [Before](retry-before.json) · [After](bot_ladder_retry_regular.json) · [Ladder](ladder.log) |
| Original bot expectations | Met | All three original test scripts run as written. The perfect hand finished in **338 race frames** with zero falls, landed the second jump at frame 179 and entered the slide at 180. Running and jumping upright kept the runner behind the beam for 85 ticks. [Clean run](bot_course.json) · [Obstacles](bot_obstacles.json) · [Geometry](bot_geometry.json) |
| Impossibility | Met | In a scratch copy, only `chain_gap_m` changed, from 3.8 to 12.0. Both probes loaded, completed and exited 1 as expected. Geometry measured 4.95 m of reach. The runner crossed gap one and fell at gap two. [Geometry](impossible-bot_geometry.json) · [Traversal](impossible-bot_course.json) |
| Gates | Met | Fast **244/244** units and **5/5** steps. Full `--only packs,world` **10/10** units and **2/2** steps. [Fast](fast.log) · [Full](full.log) |
| Full-run clip under 20 s | Met | One continuous windowed run, from the start stripe to the finish HUD. Godot rendered a 1280 × 720 viewport at 60 fps. Its movie writer stored a 1920 × 1080 intermediate, which FFmpeg encoded at 1280 × 720. The H.264 file contains 394 frames over 6.567 s, including the finish hold. [Clip](../clip.mp4) · [Movie result](movie.json) · [Stream properties](clip-stream.json) |
| House kit and toon style | Met | All new scenery uses existing kit parts and the kit terrain layout. The kernel and kit have no edits. |

## Gate results

```text
PASS  arch              [12/12]
PASS  assets              [4/4]
PASS  cards               [3/3]
PASS  devx.test       [225/225]
PASS  foreman.typecheck   tsc --noEmit clean
PASS  packs               [2/2]  verb runs 34 of 34
PASS  world               [8/8]  world = alone
game.parkour | bot | 340 | d1256f49895f2b73 | d1256f49895f2b73 (340 frames) | same
```

The pack gate exercised 27 hockey verbs and seven parkour verbs. Main’s manifest has three parkour bots. This manifest runs those three and the new retry bot. The 3,600-frame smoke and invariants runs passed, and lint reported an empty bypass list. [Smoke](smoke.json) · [Invariants](invariants.json) · [Lint](lint.json) · [World comparison](world.log)

The first full attempt finished with 33/34 verbs green. Hockey’s invariant recorded a 1.124 ms frame median against its 1.0 ms budget. The complete rerun after rendering recorded 0.898 ms and passed. An early fast run also flagged the temporary widened-gap pack under the evidence directory. Both negative probes had completed, so that scratch copy was removed before the final fast run. [First full attempt](full-first.log)

## Files and behaviour

| Pack file | Change |
|---|---|
| `data/yard.json` | House terrain, dirt pad and mesas, a crane over the chute, cabin behind the gap, trees, tyres and supplies. |
| `scripts/course.gd` | Turned the decks east to present their full length to the road. The lengthwise scaffold galleries carry the visible guardrails. Upright and horizontal kerbs make the gate. The original 3.4 m and 3.8 m gaps, 1.52 m clearance, chute lip, 65° descent and finish distance are preserved. |
| `scripts/main.gd` | Added the landing checkpoint and a blocked-beam C prompt. The gate checkpoint is inside the opening and respawns on its far side. The HUD now counts four checkpoints including the finish. The orbit lifts over the chute lip and returns to the player’s pitch on the finish deck. |
| `tests/bot_ladder_retry_regular.gd` | Exercises the entire run with an unmodified regular hand and only forward, run, jump and slide inputs. It requires the block, checkpoint return, observed slide under the beam and lap win. |
| `pack.json`, `README.md` | Registered the fourth test, updated the footprint, documented the controls and listed the new capture frames. |

The four pack stills use seed 1 and the clean-run bot at frames 1, 73, 228 and 288. The road still uses the visitor camera, the eight plots and landscape from the boot village, and the parkour plot at its existing coordinates. The walk positions the visitor on the road facing the course. [Before stills](../stills/before/) · [Road walk](road-walk.json) · [Road capture](village-road.log)

The kit catalogue supplied `scaffold` for braced towers and rails, `ground_patch` for the running surfaces, `kerb` for the gate, stripes and chute edges, and `flag` for course markers. The yard uses `crane`, `cabin`, `tree`, `tyre_stack`, `lumber`, `pallet` and `barricade`. The layout's built-in terrain provides the hills and dirt pad. [KIT.md](../../../../../../engine/kits/KIT.md)

## Director handoff

The lane raised no contract questions. The next three playtest checks would be to have a first-time player find the C retry from the HUD, watch a player steer through the chute with a manually turned camera, and measure the same retry with the newcomer hand.
