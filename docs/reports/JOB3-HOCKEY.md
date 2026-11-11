# Third real job: ice hockey from one sentence (Phase 1, Director's record)

Run by the Director on 2026-11-11, 01:22 to 03:30 local time, with the command lines from
`docs/reports/N3-FOREMAN.md`. The sentence: "Ice hockey, three against three: skaters, a puck, two goals, first to
three goals wins. I play one skater with WASD and shoot with space." Claude CLI builders on `sonnet`, at most
4 packages, 4 rounds (raised to 6 on the last resume), 15 minutes per run, 2 in parallel, on the owner's subscription.
There is no hockey seed: builders had the three seed games (paddle, drive, wall), the kit, rig and style documents and
the kernel API, which since tonight includes the stricter fence.

- Job directory: `site/ice-hockey-three-against-20261111-1/` (log `job.jsonl`, 231 events to the first `done`, 331 with the two change requests)
- Engine: `site/_engine_snapshot4/`, a copy of `engine/` at 01:20 (the new look and the item and fence work merged;
  not the kernel's world work)
- Result pack: `site/ice-hockey-three-against-20261111-1/promoted/game.ice_hockey_three_against/`
- Final state: `done` twice: version 0.1.0 at 03:30, version 0.1.1 at 03:49 after two change requests
- Pictures: `docs/reports/img/job3_hockey_blockout.jpg` (first), `job3_hockey_round4.jpg` (after two critic rounds),
  `job3_hockey_final.jpg` (final)

## The three jobs side by side

| | Job 1, marble (20:22) | Job 2, marble (21:55) | Job 3, hockey (01:22) |
|---|---|---|---|
| Engine | kernel only | kernel, kit, rigs, style, seeds | the same plus tonight's look and fence |
| Seed for this kind of game | none existed | none (three other seeds) | none (three other seeds) |
| Packages | 3 | 3 | 4: core, AI, look, effects |
| Wall time, `new` to `done` | 14 min 22 s | 14 min 45 s | 2 h 08 min, of which about 60 min running and the rest paused |
| Builder (edit) runs | 3 | 7 | 14, 36.4 builder-minutes |
| Tokens in (cache reads) | 2.68 M (2.46 M) | 2.01 M (1.69 M) | 6.37 M (5.72 M) |
| Tokens out | 99 k | 85 k | 130 k |
| Weighted (cache reads at 0.1) | about 570,000 | about 574,000 | about 1,350,000 |
| GDScript lines in the pack | 660 | 385 | 723 |
| Bypasses | 7 | 1 | 0 |
| Critic | NOT ok 3 times, no effect | NOT ok 6 times, extra rounds on the wrong package | NOT ok at all 4 milestones; named `hockey_core` each time; 4 re-opens of it, 3 of them merged |
| Questions | 0 | 1 | 2, both caused by a busy machine |
| Pauses | 0 | 1 | 3: two questions, one `machine_busy` |
| Foreman defects found and fixed during the job | 0 | 0 | 3 (see below) |

## Director verification (03:31 to 03:36)

- The five verbs on the promoted pack, spawned directly against `site/_engine_snapshot4`: lint, smoke, invariants and
  bot exit 0; frame p99 1.2 ms; `invariants.bot_deterministic` true.
- Three bot runs at seed 1 give one hash (`35413c78...`): blue 3 : 0 red in 9,879 frames (165 s), the player's bot
  took 5 shots, result WIN. Seeds 2 and 7 give the same hash: the game uses no randomness.
- `promoted/game.ice_hockey_three_against/` is identical to `pack/`.
- 15 files: 5 data files, 3 generators, 4 scripts (`main.gd`, `rink_api.gd`, `ai/brain.gd`, `fx/fx.gd`), 2 bots.
- Looked at: `captures/blockout-arena-f1201.png`, `tuned-arena-f2487.png`, `greybox-arena-f7410.png`.

## What the pictures show

- First picture, after 7 minutes: a kit rink with markings, boards, two goals and six skaters about 15 pixels tall, on
  a bare plane, seen from far.
- After two critic rounds on the core: skaters large and readable, stands and their shadow, but the camera cut off
  both goals.
- Final: the whole rink, both goals, stands, three blue and three red skaters in play in front of the red goal. The
  puck is a small dark dot and hard to find, which the critic still says.
- Not there: a scoreboard in the world, goalies, sticks that read as sticks, a crowd, anything around the arena.

## How it went

1. **01:22 to 01:55, 33 minutes running.** Core built in 5 min, failed its bot, fixed in 35 s. The critic said
   "skaters tiny, nearly static" and named the core: re-opened, merged larger skaters. Look and effects merged in one
   round each. The AI's first round failed the frame budget at 15 ms; the automatic second run failed too; the builder
   asked whether another package's code was to blame. Paused.
2. **The Director measured the same files at 1.2 ms.** Twelve Godot processes were running: three of the Director's
   own builders, a second session, and this job. The failure was the machine.
3. **Three Foreman defects, found by this job and fixed while it was paused** (`docs/reports/N3B-FOREMAN.md`,
   `N3C-FOREMAN.md`):
   - A re-opened package was verified against a manifest without its dependants' capabilities, so the core's fifth
     round failed lint on the effects package's file and was thrown away.
   - A repeated clock failure was blamed on the pack. The first fix (measure a reference pack) still blamed the pack
     twice, because a short reference run seldom meets a stall.
   - The rule that held: a deterministic pack that stalls at different frames on two runs is being stalled from
     outside. On its first live use it paused the job with cause `machine_busy` after five stalls at five different
     frames, without spending a round.
4. **The one real failure** was hidden behind the stalls: with the AI merged, the core's bot ended "0 shots", because
   AI skaters always reached the puck first. The Director answered in the player's role: the human-controlled skater
   must get to play. The AI builder made blue teammates and red forwards yield while the player is near the puck.
5. **03:21 to 03:30, on a quieter machine:** the AI's files passed unchanged. The critic named the core once more
   (goals out of frame): the core re-opened with the full manifest, merged, its three dependants were verified again
   and none needed a rebuild. Final checks passed. `done`.

## Findings

1. **A new kind of game worked without a seed of its own.** Hockey needs input, opponents, teammates and rules, and no
   seed has all four. The builders took the rink, the puck and the skate clips from the kit and rigs and wrote 723
   lines. This is the result Phase 1 was for. It is one job; it is not a rate.
2. **The change path is what made the picture.** The critic named the package at fault every time, and three of its
   re-opens merged a visible improvement (skater size, framing). In job 2 the same criticism changed nothing. The
   critic still ends on NOT ok, and it is right about the puck.
3. **The stricter fence did not get in the way.** No verification failed on a fence rule (of 14 failed checks: 8 bot,
   5 invariants, 1 lint on capabilities); the pack has 0 bypasses. What builders ran into inside their own rounds is
   not recorded.
4. **The kit gate never fired.** No round lowered kit use or raised bypasses, so it is still untested live.
5. **The machine was the main cost.** About an hour of pause and four wasted or thrown-away builder rounds came from
   wall-clock limits on a machine running ten to twelve engine processes. The 250 ms watchdog and the 8 ms frame
   budget measure wall time. They need to measure processor time, or real jobs need the machine to themselves.
6. **A builder under a false failure does damage.** Told twice that the time was "this pack's own", the AI builder
   rewrote working code and blamed a neighbour. A wrong verdict from the verifier is worse than no verdict.
7. **The player's part was nearly lost without anyone noticing.** The AI package passed its own bot while taking the
   puck from the player every time. Only the core's bot, which requires the player's skater to shoot, caught it. A
   game needs a check that the human has something to do.
8. **Never seen live yet:** a re-plan, a builder timeout, a `kit_regression`. Nobody has pressed WASD.

## Two change requests after `done` (03:32 to 03:49)

The Director wrote both in the player's role, through `foreman change`.

| | First request | Second request |
|---|---|---|
| Words | "I can hardly see the puck. Make it bigger and much darker so it stands out on the ice, and move the camera so both goals and the whole rink stay in view." | "The puck is now far too big and the game got worse: with it my skater loses 1 to 3. Make the puck about a third of that size (radius about 0.12 m), keep it near-black, keep the new camera with both goals in view. The match must stay winnable for the player as before." |
| Owner | chosen by the Planner in 3 s: `hockey_core`, with the reason that puck and camera live in its files | named in the request |
| Owner's round | 30 s: puck radius 0.35 m and near-black, camera higher | 34 s: puck radius 0.12 m, size moved into `data/tuning.json` |
| Dependants verified again | `hockey_ai`'s bot failed on the merged pack, so it was re-opened and rebuilt (108 s); look and effects passed | the same: `hockey_ai` rebuilt (219 s); look and effects passed |
| Final verification | **failed**: the player's bot lost 1 : 3 | passed |
| End | job `failed` after 6 min; the first promotion untouched | job `done` after 9 min; `promoted/game.ice_hockey_three_against@0.1.1` beside the first |

- The Director reproduced the 1 : 3 loss twice on the job's `pack/`: a real result, not load. A puck 70 cm wide
  changed how the game plays.
- Director verification of 0.1.1: lint, smoke, invariants and bot exit 0 against `site/_engine_snapshot4`; one bot
  hash three times (`5af10fbc...`): blue 3 : 1 red in 4,887 frames, 3 shots, WIN; 739 script lines; 0 bypasses.
- Picture: `docs/reports/img/job3_hockey_after_change.jpg`: the whole arena in view, both stands, scoreboards, light
  masts, both goals. The skaters are smaller again, which is what "the whole rink in view" costs; the puck is dark
  and still small.
- Whole job with both changes: 331 events, 18 builder runs, 42.9 builder-minutes, 7.30 M tokens in (6.53 M cache
  reads), 145 k out, about 1.56 M weighted.

What the two requests show:

9. **The conversation converges.** A vague request, an overshoot, a gate that refused it, a sharper request, a
   verified result: 15 minutes for both, with no human code. This is the loop the product is.
10. **A defect in the change path.** After the owner's change the AI package was rebuilt and checked against its own
    bot only. The pack's other bot, which belongs to the owner, was not run again until the final verification, which
    then failed the whole job. A dependant's rebuild must be checked against every bot of the pack, and a failed
    final verification after a change should send the failure back to a package, not end the job.
11. **A failed change is safe.** The earlier promotion stayed in place and still passes; `foreman change` works on a
    `failed` job and brought it back.
12. **A builder takes "bigger" further than a player means.** Nine times the contract's radius. A change request
    could carry the current value so that "bigger" has a scale.

## What this says about the ambition

- Phase 1's acceptance, as written in `docs/SPIKE-PLAN.md`: a headless bot match runs to full time with consistent
  scoring and determinism: yes. V5 pictures pass the rubric: no, the critic's last word is NOT ok (readability 0.5).
  A human can play it with the keyboard: not tested. No human wrote game code: true for the pack; the Director wrote
  two answers in the player's role.
- Cost: about 1.35 M weighted tokens and an hour of running time for a four-package game, against 0.57 M and 15
  minutes for a three-package marble run. Without the machine trouble the hour would have been about 40 minutes.
