# Lane parkour: report (night of 19 Nov, done at 00:39)

The Director saved this from the lane's final message, because the agent could not write report files. Astra's own report
is in `evidence/astra-report.md`.

**How it ran:** Astra worked alone in one Codex run (`gpt-6.2-astra`, high effort, session
`01a1f0e8-29d2-7510-b3e4-3223465f62d4`). It ran from 00:05 to 00:21: 16 min 15 s and 183,350 tokens, with no resume. The
Opus operator wrote no pack code and drew no art; it re-ran every check from 00:22 to 00:38. The Director then re-ran lint
and all four bots on a new seed (3): all passed.

## Acceptance
| Criterion | Verdict | Evidence |
|---|---|---|
| Five views beside D's, plus a contact sheet | met | `stills/D-F-*.jpg`, `stills/contact-sheet.jpg`; the "before" shots in `stills/before/` |
| Bar run-up and a regular-hand retry | met | The beam sits 5.5 m into the landing deck (as in E). The new checkpoint is 4.5 m before the beam. `tl ladder --cells retry_regular --seeds 20`: 20/20 won with the regular hand, mean 468 race frames. Before: seed 1 timed out |
| Bot tests and the impossibility test | met | 4 bots on seeds 1, 2 and 3. `bot_course` (perfect hand): 338 frames, 0 falls, as on main. A second gap of 12 m makes `bot_geometry` and `bot_course` exit 1 |
| `check --tier full --only packs,world` | met on the 3rd run | Runs 1 and 2 under load 7-16: hockey `invariants.many_budget` 1.156 / 1.056 ms against 1.0 (hockey unchanged). Run 3: 34/34. World 8/8 every time |
| Clip of at most 20 s | met | `clip.mp4`: 6.6 s at 1280x720 in a window, start to FINISH in 5.63 s |
| No kernel change; kit only if needed | met | Only `engine/packs/parkour/**` changed; no new kit parts. It reuses scaffold, ground_patch, kerb, flag, crane, cabin, tree, tyre_stack, lumber, pallet and barricade |

## Behaviour changes
1. The course is turned 90° so its long side faces the village road. The footprint changed from 18x50 m to 50x28 m, and
   from 12 m to 20 m high.
2. Four checkpoints instead of three: landing the second gap now earns one.
3. New mechanic: a **C retry**. Stopped at the beam's near face, C sends you to the landing checkpoint. It does not count
   as a fall, and the clock keeps running. The HUD shows "C  Retry from checkpoint". This goes beyond E's run-up room.
4. The beam is thinner (0.68 m deep, built from kit pieces). The checkpoint counts only inside the opening.
5. The camera lifts over the chute; the runner is blue, as in D.
6. No test expectation moved. A fourth bot was added: `tests/bot_ladder_retry_regular.gd`.

## For the owner
`node devx/bin/tl.mjs play parkour`, or walk to the plot in the village. Walk into the beam standing up, then press C.
Every difficulty figure here comes from scripted hands, not from a person.

## Questions
1. Should the C retry stay, or the course keep only E's run-up? The retry bot uses C.
2. Hockey's `many_budget` (about 0.9 ms against 1.0) fails the packs step when lanes load the machine: should the gate
   retry under load, or the budget change? This is a gate question for the Director.
3. `tl ladder` prints "draws 20" for a one-runner race. That is a display quirk.

## Next
- Try the retry with the newcomer hand and with a person.
- Place D's cabin between the first two decks and thin the pines.
- Play it in a window from the village road.
