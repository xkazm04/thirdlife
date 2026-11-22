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
