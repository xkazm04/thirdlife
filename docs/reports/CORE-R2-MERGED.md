# Core run, round 2: the merged tree

Round 2 of the core run of 2026-11-11: packages P5 (loading), P6 (far games), P7 (simulation contract), P8 (process
spike), P9 (the executable) and P10 (the Foreman's change path), each with its own report in this folder. This file
records what was checked on the tree with all six merged (commit `23ea4a7`), between 15:55 and 16:36, on a machine
with no builder running. The runs were made by a Sonnet subagent from a fixed list and read by the Director.

## Checks

| Check | Result |
|---|---|
| `node devx/bin/tl.mjs check --tier full` | green: arch 9 rules, devx tests 126, Foreman tests 174 pass and 0 fail, kernel selftest 103 cases, kit selftest 87, seeds 24. `item.selftest` and `ui.selftest` are skipped in a worktree (they need last night's marble job in the main checkout) |
| `world.sh tour tour --headless` | PASS, six of six the same in the walk, alone and in the replay |
| the same tour in a window with its proof, alone on the screen | PASS, 10 of 10 pictures, no error line; worst frame 225 ms, 99th percentile 7.1 ms |
| `world.sh tour walk30 --pictures-only` | ran to its end: 30 games built, worst frame 281 ms, 99th percentile 3.8 ms |
| the hockey game 0.1.1 through lint, smoke, invariants and both bots | all pass with the hashes of P7's table |
| the drawing check on three seeds and hockey | PASS: drawn equals headless for all four, 0 gate leaks, 0 errors |
| `export.sh` and `export.sh check` | PASS: a build of 105 MB; seven games give the same hash from the editor binary, from the exe and from the exe in a copied folder; the exe showed the village, obeyed W and Esc and left no process |

The two windowed proofs that failed during the packages' own verification (P5 and P6 reports) pass here, with one
window on the screen at a time.

## The quiet performance line (`perf/ledger.jsonl` line 8), against round 1's (line 6)

| Scenario | Metric | Round 1 | Round 2 | |
|---|---|---|---|---|
| tour6 | worst tick | 838 ms | 259 ms | better |
| tour6 | time inside ticks spent loading | 1,937 ms | 19 ms | better |
| tour6 | worst frame | about 1,100 ms (not in the ledger then) | 258 ms | better; target 16.7 ms not met |
| tour6 | frame, 99th percentile | not reported | 7.8 ms | |
| tour6 | time to the first frame | not reported | 1.15 s | |
| tour6 | draw calls | 249 | 379 | named a regression by the tool: marks, smoke, lights and scores of far games, and trees. Primitives are level (1.91 M) and GPU time is 1.2 ms |
| walk30 | worst frame | new | 339 ms | |
| walk30 | time to the first frame | new | 3.46 s | |
| mix30 | worst tick | 21.6 ms | 40.0 ms | named a regression by the tool; one tick in a run; cause not known |
| pile600 | tick, median | 2.45 ms | 2.69 ms | inside the tool's tolerance; cause not known |
| load6 | load | 2,828 ms | 1,198 ms | better |

The two unexplained figures (mix30, pile600) are given to round 3's P12 to trace.

## What the gate's output still says wrongly

A skipped step and the perf step on a busy machine are printed with the word PASS. Both say in their detail that
nothing was judged, but a reader of the first word is misled. Noted for the tool's owner.

## Next

Round 3: `briefs/BRIEF-P11-CONTROLS.md`, `BRIEF-P12-ARRIVALS.md`, `BRIEF-P13-FAR2.md`.
