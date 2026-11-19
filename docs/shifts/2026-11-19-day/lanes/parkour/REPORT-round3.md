# Lane parkour, round 3 (day of 19 Nov): stage 4 "Skyline" on the 1.10 walker moves, done at 13:35

Worktree d19-parkour3 (branch from main cc6b8d3, KERNEL_API 1.10). Route as before: Astra (codex gpt-6.2-astra, high,
session 01a1f2bc-fc0c-7ad0-bfd1-9d7f5f86d10a) designed and built the stage alone. The operator wrote no pack code,
re-ran every gate itself, ran its own omission probe and took the stills and the clip.

Codex round 4: 12:07:24-13:00:43 (53 min 19 s). The session total printed after the round is 1,193,432 tokens; the
counter is cumulative across resumes (it was 826,850 after round 3), so this round's share is about 366,600.

## What was built
Stage 4, Skyline, starts at the old summit stripe:
- **Headwall:** a 3.00 m concrete face. Jump, ledge-grab, then mantle (hold forward or tap Space). C drops you back to
  the approach.
- **Blue bar:** 1.30 m beyond the runway end, 3.05 m up. Swing, then release on the rising forward stroke.
- **Red bar:** 4.00 m further on, 1.55 m higher. Release again.
- **Catch ramp:** a timber ramp 3.50 m from red, between the finish flags.

The pack opts in to `moves: [ledge, bar]` and marks the two bars with TLBiped.mark_bar. It still does not opt in to fly.
The HUD shows four stage splits and bests. No kernel change. No new kit part: Astra checked ground_patch, kerb,
scaffold, arch_rib, flag, timber_frame, lumber and goal. The bars are horizontal kit flags with cylinder colliders,
carried on two arch_ribs.

## Acceptance (operator-verified)
| Criterion | Verdict | Evidence |
|---|---|---|
| Stills of each new obstacle, the overview and the village road, with a contact sheet | met | stills/contact-sheet-round3.jpg: before/after overview, village road, headwall grab, blue bar, transfer, red bar, catch ramp, finish with 4 splits. Raw JPGs in stills/round3-after/ and stills/round3-before/. Astra's own gallery: stills/astra-4/ |
| Windowed full-run clip of 20 s or less | met | clip-round3.mp4: 17.40 s, 1280x720, 60 fps, native speed, no speed-up. One perfect-hand run: 986 race frames, 0 falls, splits 338/286/182/180. Strip: clip-round3-strip.jpg |
| bot_course (perfect hand) finishes | met | 986 race frames (16.43 s), 0 falls, on seeds 1, 2 and 3 |
| Ladder per hand, 20 seeds, before/after | met | See the table below |
| Impossibility case per new obstacle | met | Each mutation makes both bot_geometry and bot_course exit 1 with only bot.ok red: ledge_rise_m 4.3, first_bar_rise_m 4.5, bar_spacing_m 19, landing_gap_m 21. All 8 older mutations still fail too: 24/24 in all (evidence/round3/operator/impossibility.txt) |
| Omission controls | met | Astra's bot_headwall: 75 ticks of pressing forward never reach the runway. Astra's bot_grips: running off the runway, releasing blue at the bottom, or releasing red backward all fall. My own probe: a perfect-hand runner that ignores the swing and mashes Space on a fixed rhythm past the headwall times out at 5 of 6 rhythms (every 5, 8, 11, 17 and 23 frames, 18-39 falls). Every 31 frames it finished once, in 1,111 frames against 986, with 1 fall (skyline-jump-mash-probe.txt) |

## Ladder (tl ladder, seeds 1-20; scripted hands, not a person)
| Level | Hand | Before Skyline (round 2 tree) | After (operator run) |
|---|---|---|---|
| Course | newcomer | 20/20, 1766 | 18/20 (90 %, 77..100), 2670 |
| Course | regular | 20/20, 970 | 20/20, 1291 |
| Course | sharp | 20/20, 841 | 20/20, 1081 |
| Forced C retry | newcomer | 20/20, 1698 | 17/20 (85 %, 69..100), 2467 |
| Forced C retry | regular | 20/20, 1062 | 20/20, 1378 |
| Forced C retry | sharp | 20/20, 898 | 20/20, 1186 |

My figures match Astra's exactly. Every hand uses one input policy; only the TLHand profile differs. One thing to
know: the Skyline driver measures its own delay from a jump request to the pressed edge, and leads the next take-off or
release by that delay. A person who learns their own timing does the same, but the figures measure "hand plus that
learning", and the report should say so when they are quoted.

## Gates (operator runs)
- lint: PASS.
- Pack tests: 17 bots x seeds 1, 2 and 3 = 51/51 pass.
- `tl check --tier full --only packs,world`: packs PASS 2/2, verb runs 47 of 47; world PASS 8/8, on the first run.
- `tl check --tier fast`: PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck).
- The rest of the full tier was not run: only the pack changed.

## Behaviour changes (moved expectations, named)
1. The race now ends at the Skyline catch ramp (986 frames), not at the stage-3 summit stripe (806). bot_splits expects
   four splits.
2. The runner opts in to the ledge and bar moves. Ledge catch exposed a handhold on the old summit crest when its rise was
   mutated to 2.40 m, so Astra recessed the concrete pier 0.82 m behind the timber nose. The playable 0.72 m crest still
   takes a running jump, the 2.40 m mutation fails again, and bot_course rejects a hang or mantle at that crest.
3. A missed-landing retry: a grounded runner who has passed a pad's or the beam's whole landing without its checkpoint
   registering is sent back. The checkpoint itself is still granted only under the original landing conditions.
   Before, such a runner could run to the far wall and time out (newcomer seeds 3, 7, 12 and 15 hit it). New test:
   tests/bot_landing_recovery.gd.
4. pack.json: version 0.3.0, kernelApi 1.10, 17 tests, 15 cameras.

## Changed files
- Modified in engine/packs/parkour: README.md, pack.json, scripts/main.gd, scripts/return_lane.gd, tests/bot_course.gd,
  tests/bot_geometry.gd, tests/bot_splits.gd, tests/support/run_hand.gd.
- New: data/upper.json, tests/bot_headwall.gd, tests/bot_grips.gd, tests/bot_landing_recovery.gd.
- Lane: STANDUP.md, REPORT-round3.txt, clip-round3.mp4, clip-round3-strip.jpg, stills/contact-sheet-round3.jpg,
  stills/round3-*, stills/astra-4/, evidence/round3/ (Astra's report astra-report-4.md, its run video astra-run-4.mp4 of
  about 11 MB, operator/).

## Findings for the Director (kernel or world, not parkour)
1. **Ledge standing-room tolerance (Astra; I have not reproduced it).** Set upper.json ledge_rise_m to 3.05 in a
   scratch copy. bot_geometry then passes, but bot_course makes no catch and times out at checkpoint 12. Astra's probe
   says the standing pose overlaps the top by 2.4e-7 m at the 0.001 m margin. The shipped 3.00 m wall works.
   Repro and probe: evidence/round3/ledge-fit*.
2. **Translated physics root (`--at`) changes every pack's hash, not only parkour's.** I reproduced it:
   `world.sh alone --packs=parkour --mode=bot --frames=1000 --at=-186:1:-32` reports DIFFERENT
   (9e90a1f38601b700 against f7abac006a45bd43). The same check at 600 frames is also DIFFERENT for seed.paddle and
   for hockey, so it is a world/kernel float effect. The village placement the `world` gate uses passes 8/8.
   Evidence: evidence/round3/operator/translated-at.txt.

## For the owner
Run `node devx/bin/tl.mjs play parkour`, or watch clip-round3.mp4. Nobody has played the bars or the headwall yet.
Things a person should judge:
- The release timing on the bars.
- Whether the orbit camera frames the swing. In the clip the bars sit high in the frame.
- The newcomer losses. Which obstacles cost the new 2 of 20 is not yet traced.

## Next three things this lane would do
1. Trace the newcomer's 2 course losses and 3 retry losses on Skyline, as in round 2: bot or game.
2. Have a person play Skyline in a window with the orbit camera.
3. If finding 1 is confirmed, add a kernel regression fixture: the flight/kernel lane, not this one.
