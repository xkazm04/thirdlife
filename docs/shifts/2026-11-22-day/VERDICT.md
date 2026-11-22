# Day of 22 Nov 2026: verdict

**The owner, ~10:40:** "run next shift now with all three steps as daily shift, I will play the game after before major
directions for night shift"

Three lanes, 12:41 to 16:44. All three landed on main. Nobody has played any of it by hand yet: the walks, passes and
editor jobs below were read through scripted hands, clips and strips. Page: https://claude.ai/artifact/Hzud79BFgAamu4A5yS35dg

## For your hand first (about 15 minutes)
1. **The Home.** Start the exported game (`.claude/worktrees/d22-int/dist/PLAY-LATEST.cmd`, built from 48c4f59) or `boot.tscn`, choose World.
   You start facing east: turn round, walk west past the parkour course to the lane gate at x -404, follow the lane to
   the ford and over the mill bridge to Mill Green. F flies. Start with `TL_HOME=plain` to see the old landscape.
2. **Hockey.** `node devx/bin/tl.mjs play hockey`: does red pass when you close on the carrier? Then judge the clip
   `lanes/D2-e6/r2a/clip_red_pass_out_of_pressure_s1.mp4`.
3. **The editor's hockey.** Look at `lanes/D3-editor/hockey3-PAIR-final-build-poke_hit-f37-over-house-poked-f523.jpg`
   (the build above, your house hockey below).

## D1 home (Opus): landed, the Home is Wren Valley
- **Verdict:** landed in three rounds: merge efbf00f (built at boot, far plain gone, walkable), merge 2fdaee0 (solid
  trees and mill, a frame-time instrument). Arm A's code came from n22-world-a (Astra solo, last night).
- **What it is:** a 6.5 km valley around the village: river, farmland, woods, a ridge, a mill and a bridge. Colliders
  are the drawn triangles in 96 m chunks streamed round the visitor (valley ground, lanes, bridge deck), plus tree
  trunks and the mill's stone base, hall and porch. Houses, tower, portals, stalls and fences are still walk-through.
- **Evidence:** selftest 751 (re-run by the Director, home. 9/9): home.walk 518 m outside the village with 0 frames off
  the ground; home.bridge 817 frames on the deck; home.trees stops at every trunk (fails without them); home.drops 5/5.
  Integration at efbf00f in d22-int: world 8/8 = alone, tours headless and in a window PASS, export + check PASS.
  Stills `lanes/D1-home/round-1/sheet.jpg`, clips `round-2/` (20 s each).
- **Cost:** landscape build 1596 vs 613 ms, first frame 5069 vs 3489 ms, walking frame p50 1.53 vs 1.11 ms (busy
  machine, 3+3 interleaved windows).
- **Found:** a pink patch at the west road end (x about -295), on main before today (`findings/`). An intermittent leak
  of two audio objects at exit is TLAudio's, pre-existing (19 Nov tours show it), log noise only; fix written in the
  report, not built.

## D2 e6 (Opus; Astra not needed): landed, a game in a world plays as it does alone again
- **Verdict:** landed: merge 2fdfef2 (E6) and merge 59ada89 (hockey "pass out of pressure").
- **Cause, verified both ways:** a world moves each body into the game's own physics space; Jolt files a moved body as if
  it already stood at its next step, a first join where it stands. The two spaces then solved a skater touching the net
  and the boards in another order, 1 mm apart. Making the lone runner move its bodies made it match the world; keeping the
  world's bodies unmoved made it match alone. N1's "body order" reading was the symptom.
- **Fix:** two lines in `adopt()` state the transform again after the move. No lone hash moved (129/129), world 8/8.
- **Evidence:** selftest 760 (3 cases) passes on the fix and fails with main's pack.gd (Director re-ran both). Hockey
  r2a world = alone through 20000 frames on seeds 1-3 (main differs on 2 and 3). Uncapped kernel suite on the round-2
  tree 491/0. Integration at 2fdfef2: world 8/8, tours PASS, export + check PASS, e6. 3/3.
- **"Pass out of pressure":** landed as you asked; its measured effect is inside seed noise on 20 seeds x 4 cells (red
  passes per possession 1.4/1.9/2.1/1.5 -> 1.6/1.8/2.3/1.3; red hits kept). Last night's round 3 already makes the carrier
  re-decide every 7-8 frames. The clip shows three red passes under pressure. Spacing (keep_off_m) unchanged.
- **Contract:** RUNNER.md now names the rule and the `TL_BODY_ORDER` diagnostic (5e2fb42).

## D3 editor (Opus): landed, six rounds; both hockey jobs held for you
- **Verdict:** landed: 9f7f077 (the film checks bot claims), b0bb985 (the revise pair), d060ac8 (house cache key),
  9f9ca12 (two-bound rows), 167698c (hockey keeps the house camera and puck, spacing rows), 6fb5ea3 (job -3 notes).
  JOB.md amended each round.
- **What the editor does now:** measures stillness from the strips it already films and fails a bot's claim the film
  contradicts (proof -3: four "never idle" claims against strips still for 55 frames); sends builders their contact strip
  beside the house strip of the same kind; re-measures the house game when it changes; holds the hockey template to the
  house camera and the readable puck.
- **Evidence:** npm test 310 (305 pass, 0 fail, 5 skip), re-run by the Director each round; fast tier 5/5 per merge.
- **Hockey jobs** (all held at their first look; not accepted, not retried):

  | Job | Result | Scores | Tokens in / out |
  |---|---|---|---|
  | -1 | failed in design (named a clip as the move; fixed) | - | 0.24 M / 0.06 M |
  | -2 | held; kept round 0 | house_game 0.35, feel 0.25 | 10.8 M / 0.16 M |
  | -3 | held; kept revise round 2 | house_game 0.25, feel 0.1 | 14.7 M / 0.22 M |

  -3 took the house camera and puck word for word and now looks down on the play like your hockey. Still wrong: skaters
  merge, the puck and bodies leave the rink, no hit-stop, the dog twist never appears, summer grass.
- **Found:** the spacing rows trust the build's own bot (it reported no scrums while the critic saw blobs); a
  wall-clock invariant on a busy machine threw away one revise round; "the boards hold the puck" is not yet a rule.

## Gates on main (final list, d22-int at 48c4f59)
- **Full gate** at 48c4f59 (d22-int, 16:45-17:13): arch 12/12, assets 4/4, cards 3/3, devx 229/229, foreman.typecheck,
  foreman.test 310 (304 pass, 0 fail, 6 skip), kit 120/120, seeds 39/39, item 91/91, ui 201/201, **world 8/8 = alone**.
  packs: 128/129 verb runs; the one failure is hockey invariants.many_budget (frame p50 1.072 ms against 1.0, wall clock,
  the gate's own load). Its re-read alone was stopped by the system at 18:05 (machine down to 1.7 GB free RAM, other
  sessions' Godot processes running) and was not restarted: **not read quietly today**. Every lane and integration run
  measured it 1.07-1.22 ms on main and on its tree alike; the night of 22 Nov read 0.979 ms quiet.
- **Kernel selftest, uncapped:** 492 passed, 0 failed (17:13-17:55).
- **Perf, quiet machine:** 6/6 PASS (tour6 frame p50 2.95 ms, walk30 2.67 ms, load6 777 ms).
- **Export** at 48c4f59: built; `export.sh check` PASS (same games and 3 dungeons to the same hashes as the editor, the
  village shown, W and Esc obeyed, nothing left behind). The exe is
  `.claude/worktrees/d22-int/dist/PLAY-LATEST.cmd` (the main checkout's dist/ was not re-exported: low memory).
- **Per landing:** fast tier 5/5 on every merged tree; integration lists at efbf00f (Home) and 2fdfef2 (E6): world 8/8,
  tours headless and in a window PASS, export + check PASS.

## Your answers
1. **Hockey possession bar.** The research band is 4-10 s; your house hockey plays about 2.7-4 s. Keep the research band
   as the editor's target (the house game shows as below it), or make the house game the target?
2. **A build that fails only a wall-clock check** (hockey many_budget on a busy machine): re-run it once before it costs
   a quality round (recommended), or count it as inconclusive?
3. **Home details:** should the village tours (`world.sh` walks) also use Wren Valley? Lower the valley lanes from 0.22 m
   to 0.05 m (removes the ramps; a visible change)?
4. **Editor hockey jobs -2 and -3:** leave held (recommended until the spacing measure and the boards rule exist),
   accept, or retry?

## Route scoreboard
| Route | Lanes | Result |
|---|---|---|
| Opus solo | D1 home, D3 editor | held: 3 and 6 landable rounds with stills, clips and re-run tests |
| Opus-directed Astra | D2 e6 | the director built it by hand (two lines) after verifying the cause; Astra 0 tokens. A small kernel fix is Opus solo work |

## Cost
Astra 0. Claude: 3 lane agents (about 0.4 M subagent tokens each); Foreman hockey jobs about 25.7 M tokens in, 0.44 M out
(subscription).

## Next shift
1. **You play** the Home walk and hockey; your answers above set the night.
2. **Editor:** a spacing measure the Foreman owns (from the runner's body positions), a clock-only failure re-run, a
   "the boards hold the puck and skaters" rule; then hockey job -4.
3. **Kernel:** TLTrigger entry_side (goals through the mouth), a long all-AI test in the world gate (`world.sh --test`),
   the TLAudio exit leak; Home: colliders for the remaining kit parts, far ground built after the first draw, tl.land/1.
