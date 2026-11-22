# What b0 meets in our hockey: the probe's numbers (N1, 22 Nov night)

A copy of the pack (`.tl/probe/hockey`, not in `engine/`) with one test, `tests/probe_human.gd`, that extends the ladder bot
(`tests/bot_hockey.gd` through `TLHand`, cursor through the hand, shooting inside 16 m) and counts what the human meets on live
frames. Headless, 60 Hz, main `1fa3b56` code. Run: `.tl/probe/run.sh <level> <hand> <seeds> [tag]`; sum: `node .tl/probe/sum.mjs <dir>`.
**The hand is a bot that reads the puck's true position from the game state**: these are what a scripted person meets, not a person.

| cell (seeds) | won | live s / match (median) | first touch s (median) | first shot s (median) | his carry, median s | carries of 3 s+ / match | puck: his / mates' / opponents' / loose (share of live frames) | field skaters within 5 m of the puck (mean) | 4+ of 6 within 5 m (share of frames) | hit-stops / min | knockdowns / min (all) | he lies down (share of play) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| rookie newcomer (20) | 16 | 105.4 | 0.70 | 17.5 | 1.52 | 1.85 | 21 / 15 / 33 / 31 % | 2.22 | 15.9 % | 3.75 | 3.86 | 4.5 % |
| pro regular (20) | 11 | 103.0 | 0.57 | 25.8 | 1.23 | 1.00 | 18 / 13 / 37 / 33 % | 2.21 | 15.0 % | 3.84 | 4.55 | 5.6 % |
| rookie idle (12) | 0 | 164.6 | 17.2 | none | 3.65 | 2.92 | 28 / 21 / 27 / 24 % | 2.43 | 20.1 % | 2.60 | 3.03 | 0 % |

Speeds (second run, 12 seeds a cell, the same code plus a speed counter; field skaters, live frames, m/s):

| cell | won | mean speed: b0 / his mates / red | top speed seen: b0 / red | 4+ of 6 within 5 m |
|---|---|---|---|---|
| rookie newcomer | 10 of 12 | 6.23 / 5.95 / 4.92 | 11.7 / 10.2 | 16.3 % |
| pro regular | 6 of 12 | 6.00 / 5.86 / 5.69 | 11.7 / 10.9 | 14.6 % |
| all-star sharp | 5 of 12 | 5.84 / 5.69 / 6.03 | 11.5 / 11.0 | 15.9 % |

For comparison, thirdjam's own first-five-minutes review of its H26 build (`.tl/thirdjam/docs/design/REVIEW-1.md`, section 2 and
item 1, its novice playtester at rookie): first touch 1.8 s, first shot 81.9 s, the human's carry median 0.87 s, the puck on his
blade 10 % of play and on nobody's 63 %. By these numbers ours looks better than thirdjam did on the build its critic reviewed (H26, a day before its owner
called a later build "effectively unplayable"). The owner calls ours garbage. These measures do not see what he sees.

thirdjam's 15 Nov build, one filmed match (pro, its measured hand, 50 s; thirdjam's `tools/qa/eye/facts.py` on our log): his hit
presses 8 with 5 contacts; his passes 2 (1 to a mate); all passes 22, 45 % to a mate. One match is an anecdote, not a rate.

The puck (third run, rookie newcomer, 4 seeds, the same test plus a counter): a loose puck faster than 3 m/s with nobody within
3.5 m and away from the boards loses **0.97 / 1.05 / 1.00 / 0.98 m/s every second** (130-424 such frames a seed): the ice's contact
friction, constant, with `drag` 0 in `data/tuning.json:19`. thirdjam's law (`JamSim.cpp:4044-4057`, `regular.json:120,136`) is
dv/dt = -0.5 v - 0.147: 7.1 m/s2 at 14 m/s, 2.1 at 4 m/s.

## Scale arms (round 2; research only, in copies of the pack under `.tl/arms`, nothing in `engine/`)

The AI on all six skaters at pro (`tests/probe_ai.gd` = `bot_metrics_ai.gd`'s autopilot, measured by the probe), 8 seeds an arm,
headless. A = the pack as on main. B = life-size bodies (`body_scale` 1.0, contact 1.33, goalie 1.09: radius 0.40 m) on the same
60 x 30 m rink. C = our 2.2x figures on thirdjam's 90 x 45 m (goals at +-41, spawns x1.5). D = both. Nothing else retuned (reach,
carry, poke and check distances stay at the 2.2x figure's values), so B and D are a first look, not a design.

| arm | 4+ of 6 within 5 m of the puck | mean within 5 m | b0 within 6 m of the puck | knockdowns / min | hit-stops / min | b0 lies down | carry median s |
|---|---|---|---|---|---|---|---|
| A main | 16.2 % | 2.19 | 62 % | 5.29 | 4.83 | 3.9 % | 0.52 |
| B life-size bodies | 17.2 % | 2.38 | 61 % | 3.68 | 2.79 | 4.0 % | 0.53 |
| C 90 x 45 rink | 11.6 % | 2.11 | 57 % | 5.78 | 4.53 | 5.1 % | 0.97 |
| D both | 12.2 % | 2.05 | 49 % | 2.60 | 1.47 | 2.1 % | 1.00 |

Reading: in metres, the AI gathers round the puck about as much at any body size (B = A): the pile is AI behaviour, not only
geometry. With life-size bodies that same pile is about 6 body widths across instead of 3, and knockdowns fall by a third. The
bigger rink cuts the four-man piles by a quarter and doubles the carry. Both together halve the knockdowns and cut the freezes by
two thirds. Eight seeds an arm: directions, not figures to tune to.
