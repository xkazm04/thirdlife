# Second real job: the marble run on the full engine (Director's record)

Run by the Director on 2026-11-10, 21:55 to 22:10 CEST, with the command lines from `docs/reports/WP3C-FOREMAN.md`.
Same sentence and limits as the first job: "A marble run: three marbles of different materials roll down a zig-zag
wooden ramp onto an ice sheet, and the one that slides furthest wins."; Claude CLI builders on `sonnet`, at most
3 packages, 3 rounds, 12 minutes per run, one re-plan, 2 in parallel, on the owner's subscription.

- Job directory: `site/marble-run-three-marbles-20261110-2/` (log `job.jsonl`, 126 events)
- Engine: `site/_engine_snapshot2/`, a copy of `engine/` made at 21:54 after WP5 (kit, rigs, style, seeds, fixes)
- Result pack: `site/marble-run-three-marbles-20261110-2/promoted/game.marble_run_three_marbles/`
- Final state: `done`, promoted under the job directory

## The two jobs side by side

| | Job 1 (20:22) | Job 2 (21:55) |
|---|---|---|
| Engine | copy from 20:00: kernel only | copy from 21:54: kernel, kit, rigs, style, seeds |
| What builders were given | `API.md`, two kernel examples | the same plus the three seed games, their guide, kit, layout, rig and style documents |
| Wall time, `new` to `done` | 14 min 22 s | 14 min 45 s, of which 29 s paused on a builder's question |
| Packages | 3, each promoted in round 1 | 3, each promoted in round 1 and again after one critic round |
| Builder (edit) runs | 3 | 7 |
| Root package, first run | 646 s, 7 files | 228 s, 5 files |
| Tokens in | 2,682,580 (2,457,191 cache reads) | 2,009,179 (1,689,227 cache reads) |
| Tokens out | 98,790 | 85,150 |
| Weighted (cache reads at 0.1), in + out | about 570,000 | about 574,000 |
| GDScript lines: scripts / gen / tests | 551 / 18 / 91 | 324 / 4 / 57 |
| Bypasses (lint of 21:53) | 7 | 1 (`StandardMaterial3D.new()` at `scripts/main.gd:99`) |
| Kit parts added | 0 | 0 |
| Planner calls | 1 | 2 (first plan refused by the Foreman, see finding 5) |
| Critic | "NOT ok" 3 times, no effect | "NOT ok" 6 times: 3 first looks, each gave an extra round; 3 second looks |
| Builder notes (`DEVIATIONS:`) | none recorded | 6 `note` events |
| Questions | 0 | 1, answered by the Director in the player's role |
| Failures, re-plans, timeouts | 0 | 0 |

## Director verification (22:10 to 22:14)

- The five verbs on the promoted pack, spawned directly against `site/_engine_snapshot2`: lint, smoke, invariants and
  bot exit 0. `invariants.bot_deterministic` true. Three bot runs at seed 1 give one hash (`cc031fae...`): winner steel
  at 4.07 m, wood 2.41 m, rubber 1.10 m, 1,505 frames. Seeds 2 and 7 give the same hash: the game uses no randomness.
- `promoted/game.marble_run_three_marbles/` is identical to `pack/` (`diff -rq`).
- `job.jsonl` read in full: every line parses; the order of events is consistent; `budget` closes on `done`.
- Looked at: `captures/art_pass-side-f1129.png`, `captures/tuned-side-f376.png`, `captures/tuned-side-f1129.png`.

## What the pictures show

Job 1: a brown void, a ramp that reads as a pile of planks, a plain ice slab, three dots.
Job 2: the shared inked look, a three-leg zig-zag ramp, an ice sheet with wooden rims and a runout, kit lumber, a
pallet and a sign behind, coloured markers where marbles settled.

Still wrong in job 2, as the critic also said every time:
- The three ramp legs float apart in the air. The marbles do reach the ice (the bot proves it), but it does not look
  like one ramp.
- The marbles are a few pixels wide. The tall cylinders in the last frame are the "settled" markers, which read as
  pegs and hide which object is the marble.
- A flat backdrop wall and tabletop hide the painted sky and the forest: the pack shut out most of the look it was
  given.
- At the first capture frame the marbles are hidden inside the ramp trough.

## Findings

1. **The reference material worked.** Same sentence, same model, same limits: the root package took a third of the
   time, the pack has 40 % fewer script lines and 1 bypass against 7, and the picture is in the shared look. The
   difference is the seeds, the guide and the kit documents in `ref/`, and the Planner being told what exists.
2. **The critic's extra round ran live three times and changed little.** Each second look was "NOT ok" again with
   nearly the same scores (readability 0.4 to 0.55). The round does act: cameras moved, clutter changed. It cannot fix
   what it complains about, because the complaint lands on the package that just merged, and the cause is usually in
   the root package.
3. **A critic round made the kit use worse.** In its second round the root builder removed the kit `barrier_wall`,
   `lumber` and `crate` props, switched off the trees and the far scenery, and rebuilt rims, tabletop and backdrop as
   script boxes, to "make the marbles read larger". The venue file ends as two ground patches. Nothing guards kit use.
4. **The question path works, and shows the missing piece.** `workshop_look` asked whether `core_run` could enlarge the
   marbles and join the ramp legs. The job paused; the Director answered "no, do what your own files allow"; it
   resumed and finished. The right answer in the product is "yes": a change request to a finished package. That needs
   a re-plan or a re-open of the root, which does not exist. In hockey this will be the normal case.
5. **A Foreman and kernel mismatch from two parallel builders.** WP5 added `--bot-frames` to the engine's `invariants`
   and documented it; the Foreman's plan check (WP3c) does not know the option and refused the Planner's first plan
   with "is not a plain --key=value". The Planner's second plan dropped it. Cost: one Planner call (70 s, 73 k tokens).
   The Foreman's list of runner options should come from the engine, not from a copy.
6. **"No visible change" was caught and did not gate.** The `tuned` milestone's captures are byte-identical to the
   `art_pass` ones (sound and a confetti burst at the end do not show at frames 376 and 1,129). The rule gates only
   `art_pass`, as decided; the note is in the milestone summary.
7. **The winner effects were never built.** `workshop_look` says its contract has no winner event; `slide_feel` adds a
   confetti burst on `finished`. Nobody checked that the game's ending shows a winner. No gate asks "does the picture at
   the end show the result".
8. **Capture frames are still badly placed.** 25 % and 75 % of the bot's finishing frame (376 and 1,129 of 1,505): the
   first hides the marbles in the trough, the second is before they settle. A pack should be able to name the moments
   worth a picture.
9. **Cost is flat.** Twice the builder runs for the same weighted token total, because the runs were short. The
   subscription's own report in the transcripts: 55 % of the five-hour window and 49 % of the seven-day window used at
   21:57 (all of today's work, not only these jobs).

## What this says about Phase 1 (hockey)

- The loop is real: sentence to promoted, verified pack in 15 minutes with no human code, twice.
- Verification proves "runs, deterministic, a bot can finish it". It does not prove "looks right" or "is the game the
  sentence asked for". The critic sees the problems and the Foreman has no way to act on them at the right package.
- The first things to build for hockey are therefore in the Foreman, not the kernel: a change request that re-opens
  the package owning the cause; a critic that names the package at fault; a kit-use figure that cannot silently fall;
  capture moments declared by the pack.
