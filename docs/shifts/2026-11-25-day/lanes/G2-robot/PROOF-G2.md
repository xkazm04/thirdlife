# G2 proof: Robot soccer from scratch through Create (25 Nov 2026)

Tree `.claude/worktrees/d25-robot` (branch d25-robot). Jobs root `.tl/jobs/`. Every step went through
`engine/ui/foreman_run.mjs` in `foreman_door.gd`'s order (new; react... approve, plan, run; phase; quality; change) with
the flags of `engine/ui/flags/real.json` (claude-cli, sonnet, billing: subscription max). Logs in `.tl/jobs/_ui_logs/`.
No code edited. Stills in `stills/`; I looked at every one I name. Times are local (CET+1 = UTC+1, the job log is UTC).

Targets: `docs/shifts/2026-11-24-night/concepts/robot_soccer_concept.jpg` and `robot_soccer_screenshot.jpg` (boxy enamel
yellow and blue robots with big eyes, a seaside rooftop pitch, striped awnings, sea and a white town, a red-white
goal with a rope net, A KICK / B SLIDE, a corner score 1 2 00:46). The hokej bar: the E5 strip
(`docs/shifts/2026-11-24-night/lanes/E5-proof/hokej_strip.jpg`), its tile at row 3, col 4 is the right third of each
`*_vs_target_hokej.jpg` here.

How I play: there is no keyboard here, so "play" is the pack's own newcomer hand (`tests/bot_hand_newcomer.gd`, a
person's slow reactions) for one whole match headless, then the same bot filmed in a window: the follow camera `play`
and the wide camera `overview`, 16 frames one second apart from frame 240 (`--strip=16x60`, HUD on), and a still at
frame 1500. Script: `tl.sh bot` + `tl.sh capture --test=tests/bot_hand_newcomer.gd`.

## 0. The sentence and the cards (12:40 to 13:10)

Typed in Create (Standard, not "Build straight through"):
> robot soccer: 3 v 3 boxy robots play arcade football with a ball, kicks and slide tackles, and robots that tumble and get back up

- **Design: 15.1 min** (11:40:28 to 11:55:34 UTC): concept 1 call, designer 5 calls (about 3 min each), design review
  2 (revise, then ok). 478k tokens in. No failure, no repair.
- Concept: candidate 1 of 5 (likelihood 0.85), template `arcade_sport` (NHL '94 + Simple Soccer as 3 v 3 football).
  Faithful: "Captain three boxy robots: pass, blast, slide rivals flying, then score while they scramble up."
- **7 aspect cards**: Slide And Steal, Pick Your Corner, Robot Skittles, Cross And Blast (one-timer), Three Robot Gangs,
  Behind Your Bot (chase camera), First To Three. The brief is about 10k characters of rules: frame tables for every
  verb, a contact table, a scripted 30-second opening, utility-AI scores. It is a serious design.
- **The place**: "a scrapyard football cage ... a bright, cheeky scrapyard night match". The sentence named no place, so
  that is fair; but no card is about the place, so a person cannot steer the look before the build (see 3).
- My cards, as a person: kept six; **dropped Three Robot Gangs** ("one rival team is enough for now, keep it simple");
  **kept Behind Your Bot with a note** ("a little higher, so I see my two teammates in front of me too"). Build it.
- The brief's estimate, **9 packages, 480 min, 6.5M tokens**, is in job.jsonl but Create never shows it
  (blocked-editor line in STANDUP).

## 1. Plan and phase 1, the greybox (13:10 to 14:09)

- Plan 3.1 min: `card.team_possession` (its worked example is the old house hockey, `engine/packs/hockey`, not hokej),
  4 packages: core, brain (phase 1 "tofu"), show (phase 2 "match"), look (phase 3 "yard").
- core r1 8.1 min, failed only `many_budget` (frame p50 1.33 ms over 1.0, on a machine at 77-100 % CPU); r2 3.5 min,
  merged. brain r1 7.3 min, merged. The pack: 1,273 lines of GDScript before brain (sim.gd at exactly the 600-line cap).
- Greybox look (16 captures in 2.4 min) -> critic NOT ok three times: camera_hides_exchange, no hit-stop, house_game
  0.35-0.5 against `engine/packs/hockey`; and the tofu stage NOT ok (feedback_f 99 frames, wants <= 3; pressure_waves 0;
  the film check contradicts bot_tofu's one_timer). Two core revise rounds (camera to 6.5 back / 5 up, a plain grey
  pitch with box and halfway lines), then **paused: quality at 13:09 UTC, 55 min after the run started, 89 min after
  the sentence.** 9.14M tokens in (7.68M cache reads), 335k out, weighted 2.56M.

**What I saw** (`stills/p1_greybox_strip_play.jpg`, `p1_greybox_strip_overview.jpg`, `p1_greybox_vs_target_hokej.jpg`):
- It is football: 3 blue-and-yellow box robots against 3 red ones on a grey walled pitch with two small goals, a
  stamina bar, a score 0:0 then 1:0, "< BALL" and "rival >" edge arrows. My team scores a goal in the first 20 s.
- Bodies are stacked boxes with a stiff leg swing; one slide with a dust trail is on film (row 4); no cartwheel or
  clamber reads at a second per tile. The ball is a small yellow puck-like disc, often lost among the yellow torsos.
- A scoreboard prop behind the goal always shows **3 : 2** and the HUD's 1 : 0 is drawn over it: two scores that
  disagree. The radar is rows of text dots (`....D....`) in the corner.
- The follow camera is behind me, upfield; a red robot is often cut by the bottom edge of the frame, close to the lens.
- The newcomer hand won **3:1 in 3,545 frames (59 s)** with 10 presses and 3 touches of the ball: my teammates won it.

**As a person**: it moves and it is football; I would not play it again yet. It is short, the ball is hard to see,
and the tackles are too small to enjoy. Far from the target (no seaside, no faces on the robots, no colour) and far
from hokej's figures, rink and readable hits.

Gap to the target, three lines:
1. Tumbles: the promise is "slide a robot flying"; on film a tackle is a small slide and a tip-over of boxes.
2. Look: a sunny meadow and grey asphalt, red vs blue-yellow boxes; the target is a seaside rooftop with enamel
   yellow and blue robots with big eyes.
3. Readability: a tiny ball, a lying scoreboard prop, a text radar.

## 2. Phases 2 and 3 to v0.1.0 (14:48 to 15:58)

- Fast-forward to main d537e2d at 14:47 (H1 + H1b; foreman rebuilt). Quality hold accepted as a person ("the person
  plays it as it is"), phase tofu passed.
- **show** (phase 2) 4.5 min, merged r1. The greybox look ran again: critic NOT ok; it named the fake 3 : 2 board, the
  text radar, camera_hides_exchange and robots passing into each other, and sent core r5. **Core r5 was thrown away**:
  its frame p50 was 1.10 ms against the 1.0 ms "one of many" budget, the reference pack passed, so "machine not shown
  busy" (blocked-editor line). Phase match passed. Then the greybox critic's round 2 (core r6: a HUD screen layer, a
  drawn radar) merged.
- **look** (phase 3) 4.4 min, merged r1: stands with a crowd, cranes, flags, crates, robots with chest panels, a
  score panel "0 0:00 0 FIRST TO 3", a drawn mini-pitch radar, a blue stamina bar. art_pass critic NOT ok twice
  (core r7, r8 merged). **Two more quality holds** (greybox, art_pass), each accepted as a person.
- **v0.1.0 promoted 14:58:50 UTC**: 3 h 18 min from the sentence, 2 h 45 min of runs; 11 rounds, 6 critic verdicts,
  3 quality holds, 0 builder questions. Ledger: **18.12M tokens in (15.51M cache reads), 493k out, weighted 4.66M.**

**v0.1.0 as I saw it** (`stills/v010_strip_play.jpg`, `v010_strip_overview.jpg`, `v010_still_overview.jpg`,
`v010_vs_target_hokej.jpg`, `v010_slidehit_f250_2f.jpg`: the slide at frame 257, 2 frames a tile, HUD off):
- The look moved a long way from the greybox: a real score panel, a radar of dots, crowd stands, chest-panel robots.
- **The game underneath did not move at all.** The newcomer match is frame for frame the greybox's: 3:1 in 3,545 frames,
  the same slide_hit, pass and goal frames (69, 257, 1700 / 499 ... / 728, 1627, 3155, 3544), 10 presses, 3 touches.
  Every critic round after the greybox changed the view (`show.gd`, tuning look keys, HUD), never the sim.
- The slide at frame 257 (2 frames a tile): my robot drives into a red carrier, the two bodies **merge into one clump**,
  the red one tips and staggers; nothing flies, nothing cartwheels, no clamber reads. Kill line 3 ("a tackle reads as
  two boxes sliding past, with no flight, cartwheel, clang or visible clamber") is what I see.
- With the HUD off the fake **3 : 2** board is back over the goal; with the HUD on it peeks out behind the score panel.
- The ball is still a small yellow disc at the captain's feet, the same yellow as our torsos.
- A match lasts one minute and my side wins it for me.

**As a person**: nicer to look at, the same thin game. Would I play again? Once, to see the slide; not twice.

Gap to the target, three lines:
1. The tackle: no flight, cartwheel or clamber; bodies interpenetrate.
2. The place: a sunny meadow stadium on grey asphalt, not a seaside rooftop with a green court and terracotta.
3. The robots: red vs blue-yellow box men with chest panels; the target's are rounded enamel yellow vs blue with big eyes.

## 3. Change round 1 (behaviour: the tackle) -> v0.1.1 (16:08 to 16:27)

Typed in the change box:
> When I slide into a robot it should be launched into the air, spin over and crash on its back, then slowly clamber
> up. Right now the robots just bump and push through each other.

- **Time 19 min 9 s** (15:08:04 to 15:27:13 UTC). The owner question took 2.9 s and chose **core** ("the slide-tackle
  collision, tumble physics, get-up behaviour and animation clips belong to the root package").
- **Path: full, not fast.** One builder round (core r9, 5.6 min), merged 4 files (data/tuning.json,
  scripts/sim/sim.gd, scripts/view/show.gd, tests/bot_player.gd). Then brain was re-verified (5 bots), the final
  verification ran the hands over 12 seeds (newcomer and perfect), and 4 promotion pictures were taken. No critic
  round, no hold, no question.
- What-changed line, as the person reads it: "what changed in v0.1.1 (since v0.1.0): asked "When I slide ..."; files:
  data/tuning.json, scripts/sim/sim.gd, scripts/view/show.gd, tests/bot_player.gd". It names files, not effects. The
  builder's own note does say it in words: any slide at 6 m/s or more now floors the robot hit, ball or not;
  launch height 1.2 -> 1.8 m, flight 20 -> 28 frames, bounce 0.25 -> 0.35 m; down 60-90 -> 75-105 frames, clamber
  30 -> 45; the figure tips over during the flight; a metal clang on landing. **The captain's slide now also floors
  his own mates** (the builder's choice, not asked).
- Tokens for the round: about 1.9M in (job total 20.05M in, 515k out, weighted 4.99M).

**What I saw** (`stills/v010_vs_v011_hit_row2.jpg`: the same slide, 2 frames a tile, v0.1.0 left, v0.1.1 right;
`v011_slidehit_f240_2f.jpg`, `v011_strip_play.jpg`, `v011_strip_overview.jpg`, `v011_vs_target_hokej.jpg`):
- **The change shows.** At frame 247 a red rival slides into my captain: in v0.1.0 the two bodies merged into a clump;
  in v0.1.1 my robot is thrown up about a body height, turns over in the air with its limbs out, its shadow spread on
  the ground, lands on its back, and lies there while the red robot gets the ball.
- In 20 s of play there are now four or five falls on film (v0.1.0: one), slides with dust trails, the rival scoring
  at 0:11. The hint line teaches ("Tap Space: pass", "E: hop the crouch", "Slid while carrying: HOP"), but at 0:17 two
  hints are drawn over each other into an unreadable line.
- The behaviour moved: the newcomer hand now **loses 1:3** in 3,787 frames (63 s), 14 presses, 1 touch, 5 slide hits
  (v0.1.0: won 3:1, 3 hits). Rivals' slides now floor me, so I lose the ball more.
- Unchanged: the fake **3 : 2** board (HUD off), the small yellow ball, the meadow stadium, a one-minute match.

**As a person**: this is the first version where a tackle is a moment I would want to see again: the robot really flies.
But I lose the ball without seeing why, the ball is hard to follow, and the match is over in a minute. I would play it
once more, not five times.

Gap to the target, three lines:
1. The ball: small, yellow on yellow robots; the target's is a big white-and-red football.
2. The match: one minute, first to 3, the newcomer touches the ball once; hokej's pro match runs about 3-4 min.
3. The look: meadow stadium on grey asphalt, red vs blue box men; the target is a seaside rooftop with enamel yellow and
   blue robots with big eyes.

Where it converges so far: the change box moved the thing I named, in 19 minutes, through the right package. The
critic rounds before v0.1.0 (6 verdicts, about 70 min) never moved the sim at all.

## 4. Change round 2 (behaviour: the ball) -> v0.1.2 (16:32 to 16:49)

Typed in the change box:
> The ball is too small and the same yellow as my robots, so I keep losing it. Make it a big white football with red
> patches, about knee high, that rolls, bounces off the low walls and pops up a little when it is kicked hard.

- **Time 17 min 1 s** (15:32:39 to 15:49:40 UTC). The owner question (3.7 s) chose **core**. One builder round (core
  r10, 3.3 min), merged 5 files (tuning, sim.gd, a new `scripts/view/football.gd`, screen.gd, show.gd). The same full
  path as round 1 (brain re-verified, the hands over 12 seeds, 4 promotion pictures). No question, no hold.
- The builder's note, which the person does not see: the ball is 0.66 m (was 0.55), white with 12 red patches on the
  kit `ball` part; the hot rim lies flat under it; wall bounce 0.7 -> 0.75 and a small hop on a hard wall hit.
  **The pop-up is drawn only**: "the sim's ball stays on the ground, so pickups, saves and goals ignore height", and
  the rules still test a 0.275 m ball while a 0.33 m one is drawn. An honest note; a person would not know it.

**What I saw** (`stills/v011_vs_v012_still.jpg`: frame 1500, v0.1.1 left, v0.1.2 right; `v012_strip_play.jpg`,
`v012_strip_overview.jpg`, `v012_vs_target_hokej.jpg`):
- **The ball reads now**: a white football with red patches, clear on the grey pitch and away from the yellow torsos;
  white dot and arrow on the radar. It is the first thing my eye finds in the still. It is still smaller than the
  target's (a big chest-high ball in the concept).
- The match itself: the newcomer won 3:2 in 4,047 frames (67 s), 12 presses, 2 touches, 5 slide hits.
- Still there: the 3 : 2 prop peeking under the HUD panel, bodies overlapping in the tackle at frame 1500 (blue and
  red share one space with two rings under them), the doubled hint line ("Slid while down ... spring up" twice at 0:16).

**As a person**: I can follow the ball now. I still barely touch it myself, and it is over in about a minute.

Gap to the target, three lines:
1. Team play: my mates and the rivals mostly run at the ball; I touched it twice in a match.
2. Length: about a minute a match.
3. The look: meadow stadium, grey asphalt, red vs blue box men.

## 5. Change round 3 (behaviour: team play + "about 3 minutes") -> v0.1.3 (16:52 to 17:13)

Typed in the change box:
> My teammates do too little: they should run into open space, call for the ball and pass it back to me, and the
> rivals should pass to each other too instead of only running at me. And a match is over in one minute: make it
> first to 5 so a match lasts about 3 minutes.

- **Time 20 min 13 s** (15:52:58 to 16:13:11 UTC). The owner question (4.4 s) named ONE package, **core**: "the
  request spans team AI (brain) and the match's win rule and length ... since brain and show depend on core, core is
  the package to name". Core r11 (3.6 min) merged 3 files; full path again (the final check ran 20 longer matches).
- **Half of it was not built.** core's builder wrote: "NOT DONE here (change request 3): teammates running into open
  space, calling and passing back, and rivals passing to each other. These decisions are in scripts/ai/** ... and
  belong to another package". It added a `got_from` field for the AI package to use. The job still ended **done**, and
  the what-changed line repeats my whole request: a person reading it believes both halves were made
  (blocked-editor line).
- The figure I named, checked myself over the final verification's 20 matches per hand (`reports/final-hand-*`):

| version | newcomer median (range) | newcomer scores | perfect median (range) |
|---|---|---|---|
| v0.1.1 | 59 s (44-124) | 15 of 20 won, first to 3 | 30 s (19-74) |
| v0.1.2 | 71 s (31-118) | 16 of 20 won | 36 s (23-71) |
| v0.1.3 | **150 s (82-240)** | 13 of 20 won, 7 lost 3:5 or 4:5 | 72 s (41-112) |

  "About 3 minutes" is reached about halfway for a newcomer (2.5 min median; my film: 4:5 lost in 8,986 frames,
  150 s, 27 presses, 5 touches). The builder said so itself ("not reliably met ... I did not slow goals or restarts").
  hokej's pro match is 3.1-4.1 min.
- On film (`stills/v013_strip_play.jpg`, `v013_strip_overview.jpg`) the first 20 s are frame for frame v0.1.2's
  except "FIRST TO 5": team play did not change, as the note says.

**As a person**: the longer, closer match (4:5) is better; my mates play exactly as before, and nothing told me that
part was skipped. I would type it again, which is what I did next.

## 6. Change round 4 (behaviour: team play, asked again) -> v0.1.4 (17:16 to 17:56)

Typed in the change box, as a person who saw nothing change in v0.1.3:
> My teammates still just chase the ball like before. Change how the robots think: when I have the ball my two
> teammates should spread out into open space and call for it, and give it back to me after I pass to them; the red
> team should pass to each other too.

- **Time 39 min 21 s** (16:16:37 to 16:55:58 UTC). The owner question (3.0 s) now named **brain** ("team AI behaviour,
  which the brain package owns"). brain r2 (6.7 min) built spread positions, a give-back rule, a pass-share term, more
  frequent calls with a spark above the caller; **its merge was refused**: core's `bot_tofu` failed on the whole pack
  with it and passed without it (the control run), so nothing merged. brain r3 (9 min) slowed both guards to 70 % to
  get the tofu bot under its 36,000-frame budget, merged 6 files. Full path after (20 longer matches per hand).
- The builder's note (unseen by the person): "give_backs is 0 in the newcomer, perfect and mash runs ... I did not
  establish whether those bots never give it the chance or the rule fails to fire. Please try it by hand. Rivals do pass
  to each other (35 to 107 rival passes per run)."
- Figures, the final verification's 20 matches per hand, v0.1.3 -> v0.1.4:

| | v0.1.3 | v0.1.4 |
|---|---|---|
| newcomer match, median (range) | 150 s (82-240) | **203 s (118-289): "about 3 minutes" met** |
| newcomer, my captain's touches | 1-5 | **5-13** |
| give-backs to me (newcomer / perfect) | not counted | **0 / 0-2: not met** |
| rival passes a match (newcomer) | not counted | 59-137 |
| newcomer wins | 13 of 20 | 17 of 20 |

**What I saw** (`stills/v013_mid_f3600.jpg` vs `v014_mid_f3600.jpg`: 16 tiles half a second apart from minute 1;
`v014_strip_play.jpg`, `v014_strip_overview.jpg`, `v014_vs_target_hokej.jpg`):
- v0.1.3 at minute 1: the two teams in one clump around my captain; rivals stuck to my back.
- v0.1.4 at minute 1: the radar shows my mates far out on the wings; I carry the ball alone up the middle with space
  around me. The game has room in it now.
- But my mates are almost never on my screen: the camera note from the cards ("so I see my two teammates in front of
  me") was never met, so the spreading is seen on the radar, not on the pitch. Near my own goal the camera drops
  behind the goal and films down through the net (tiles 7-9).
- Still there: the 3 : 2 prop peeking out, bodies overlapping in tackles, the doubled hint line.

**As a person**: the match now lasts three minutes or so and I have the ball more; it is a better game than v0.1.1. I
cannot see the passing play I asked for, and nobody passes back to me.

## 7. Change round 5 (the look: seaside rooftop) -> v0.1.5 (18:00 to 18:21), added to the menu

Typed in the change box:
> Make it look like a sunny seaside rooftop: a pale green court with white lines, terracotta roof tiles around it,
> red-and-white striped awnings on wooden poles, potted pink flowers on a low wall, and the blue sea with a white
> hillside town behind. Make my team bright yellow and the rivals blue, with rounded box bodies and big round eyes.

- **Time 21 min 10 s** (17:00:33 to 17:21:43 UTC). The owner question (6.0 s) named **core** again: "the court,
  props, backdrop and colours point to the look package, but the rounded box bodies and big round eyes involve core's
  gen/robot.gd, and since look depends on core ...".
- core r12 (4.8 min) built all of it itself:
  - a pale green court;
  - yellow #ffd414 against blue #2468f2, with bigger rounded bodies and eyes;
  - a new `scripts/view/rooftop.gd` (tiles, parapet, pots, awnings, sea, town);
  - the scrapyard cranes, fences and tyres removed, and 20 kit bushes used as pot leaves.
- Full path, no hold. Behaviour untouched: the newcomer match is frame for frame v0.1.4's (16,175 frames, 4:5).
- The builder said what it could not do. The look package's dressing (the old stands, crowd, floodlights, the dusk
  sky, the panels on the robots) "should re-dress or remove them, and recolour the crowd and floodlights for
  daytime". Nothing re-dressed them: one change goes to one package.

**What I saw** (`stills/v015_vs_target_hokej.jpg`, `v015_overview_vs_target_hokej.jpg`, `concept_v010_v015.jpg`,
`v015_strip_play.jpg`, `v015_strip_overview.jpg`):
- **The biggest single step toward the target today**:
  - yellow robots with big round eyes against blue ones;
  - a pale green court with white lines, terracotta all round;
  - red-and-white striped awnings and pink flower pots on the low wall;
  - in the wide view, the blue sea and white houses behind the pitch.
- Against the target it is half there:
  - the follow camera looks straight at the old grandstand, which hides the sea;
  - the sky is still the pink-purple dusk of the scrapyard night, not a blue sunny day;
  - the crowd stands, floodlight masts and scaffolds of the old stadium are still there;
  - **the 3 : 2 prop is now more visible.** It was moved to clear the view of the town and now stands in the
    top-left of every follow frame;
  - the robots are rounded boxes with eyes, far from the target's dented enamel, rubber hoses and treads;
  - the court has no centre circle.

**Added to the menu** the way Create's "Add to menu" does it:
- `Dungeons.add_user(<promoted/game.robot_soccer_3_v@0.1.5>, "Robot soccer", <job>)`, into the person's list
  (`.../app_userdata/Third Life Engine/dungeons.user.json`), read back ok.
- The pack is still in this tree's `.tl/jobs/`; the Director copies it out like the other proof games.

## 8. The answer: can editor iterations alone lead a person to hokej's quality?

**Not today, and not by more rounds of the same kind.**

Five change rounds (v0.1.1 to v0.1.5) each moved what I named, in 17 to 39 minutes. The game went from "boxes that
merge" to a three-minute seaside match with flying tackles and a readable ball. That is real convergence on what a
person can *name*.

It stops converging where the person cannot name the problem, or where one sentence spans packages:

1. **The critic loop does not converge on behaviour (the critic and the route).**
   - Before v0.1.0, 6 critic verdicts and about 70 min of revise rounds changed only the view. The newcomer match at
     v0.1.0 is frame for frame the greybox's.
   - The critic judged a football game against the house *hockey* (70 contact rows, a hockey one_timer).
   - A revise round that did change things was thrown away on a 1.10 ms frame budget.
2. **One change goes to one package (the editor's route).**
   - "Team play + first to 5" went to core. Core built the half it owned and wrote "NOT DONE ... belongs to another
     package"; the job ended done and told the person nothing.
   - "Seaside rooftop" went to core, which could not re-dress the look package's stadium.
   - A person has to find the missing half by playing and ask again. Round 4 did, and it took 39 min.
3. **What the builder knows does not reach the person (the editor).**
   - The builders' notes are honest and precise: "give_backs is 0 ... please try it by hand", "the pop-up is drawn
     only", "the captain's slide now floors his own mates".
   - The person sees only "what changed: files ...".
   - A measured promise can fail without anyone saying so: 0 give-backs over 20 matches.
4. **The builders' depth (the builders and the engine).**
   - This pack is about 2,000 lines on flat boxes, under a 600-line script cap, and the ball's height is drawn only.
     That cannot reach hokej's hand-tuned skaters, sticks, puck physics and reactive bodies.
   - The team AI is a scored-option brain whose give-back the builder could not prove (give-backs 0).
   - Bodies still pass into each other in tackles in every version.
   - Hokej got its quality from a ported, measured core. This card has none.
5. **Defects nobody asks about survive every round.**
   - The 3 : 2 prop (all six versions), the doubled hint line, the camera that never shows my teammates.
   - The critic names some of them, but no change round looks for them, and a person would have to name each one.

Cost of the whole game:
- 5 h 41 min wall clock;
- 26.7M tokens in (23.3M of them cache reads), 622k out, weighted 6.33M;
- per change round, 1.0M to 3.1M tokens in (round 4 took two brain rounds: 3.1M).

| version | what changed | time | tokens in | the person's verdict |
|---|---|---|---|---|
| v0.1.0 | sentence -> 4 packages, 3 phases, 6 critic verdicts, 3 holds | 3 h 18 min | 18.1M | nice stadium, thin game; one look |
| v0.1.1 | the tackle launches, spins, lands on its back | 19 min | 1.9M | the first moment worth seeing again |
| v0.1.2 | a white football with red patches | 17 min | 1.2M | I can follow the ball |
| v0.1.3 | first to 5 (team play NOT built) | 20 min | 1.0M | longer, closer; mates unchanged |
| v0.1.4 | team play: spread wide, rivals pass; median 203 s | 39 min | 3.1M | a better game; no give-backs; mates off screen |
| v0.1.5 | seaside rooftop, yellow vs blue robots with eyes | 21 min | 1.4M | closest to the target; old stadium and dusk remain |

Would I play v0.1.5 again? Yes, a second and maybe a third match, which no earlier version earned. It is not hokej:
- hokej's hits read as two bodies, each with its own reaction;
- its bots make hockey decisions;
- its look is whole.
