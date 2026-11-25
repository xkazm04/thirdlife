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
