# Ice hockey, three against three (house game `hockey`)

`game.ice_hockey_three_against`, built by the Foreman on 11 Nov 2026 from one sentence; made a tracked house game and
rebuilt in the night of 15 to 16 Nov (lane H, packages H0 to H12; the look by lane L). Every figure below was measured
that night, headless, on seeds 1 to 20 (or 40 where said), unless the line says otherwise. `docs/reports/jam-lessons-home/H.md` holds the record.
It is the worked example of the recipe card `card.team_possession` (`engine/cards/team_possession.json`; `tl cards brief team_possession`).

## How to play

```
node devx/bin/tl.mjs play hockey          # a window; Esc quits (or: bash engine/tools/tl.sh play --pack=engine/packs/hockey)
```
You are the blue skater with the green ring. First to 3 goals, or the better score after three periods of 36 s (2 s
between them; a draw at full time plays on to the next goal; a match stops as a draw at 5 minutes of play).

| | keyboard | mouse |
|---|---|---|
| skate | W A S D | |
| sprint while moving (ten-step stamina bar at bottom centre) | hold Shift | |
| aim the stick (shot, pass, poke, cross-check go where it points) | | the cursor on the ice |
| shoot with the puck (hold to charge, release to fire) | Space | left button |
| with the puck: pass (to the mate nearest where the stick points, aimed where he will be) | Q | right button |
| without the puck: cross-check (tap to strike after eight frames) | C | left button |
| without the puck: body check (momentum against stability) | F | right button |
| hold the cross-check across the body until one opponent meets it | C held | left button held |
| brace against a visible body check | automatic while standing | |
| poke the carrier's puck loose | E | |
| rule dial, once a period: open / close | T | |
| in the dial: choose a dial / move it one step for both teams (and close) | A, D / W, S | |
| play again after a match (back to the panel) | R | |
| the old fixed top view and back (L5) | V | |
| skip the first-minute drill (L5) | Enter | |
| on the panel: level / mode / start | 1 2 3 / A, D / Space | left button starts |

A button held while the puck changes hands does nothing until it is released and pressed again.
Without a cursor on the ice (or with the mouse outside the window) the stick points where you skate.

**Level and mode** are chosen on the panel before the first face-off (and again after R, with your last choice kept):
1, 2, 3 pick the level (rookie, pro, all-star), A / D the mode (three against three; outnumbered, three against five;
sudden death; pond, no checks; big ice, two against two), each mode with its line from `data/modes/<id>.json`; Space or
the left button starts. Touch nothing and it starts by itself after 10 s (`menu.auto_start_frames` 600 in
`data/tuning.json`) with what it shows. The first panel shows the params `level` / `mode` of `data/tuning.json` (1 rookie
and 0 three against three by default; level 0 "Classic", the opponents of `data/ai.json`, is a param only) or the
Designer panel's sliders. Only a person's session shows it: a bot, a smoke run, a capture and a world's game nobody is in
start at once as before. The line at the bottom left of the screen names both once the match runs.

**The rings**: the green ring under your skater is your reach (1.45 m from your centre): a loose puck inside it is
yours on that frame, whatever you face and whatever you hold. A wider ring under a skater says he carries the puck,
in his team's colour (yours green; another carrier's ring shows after he has held it 20 frames). The puck itself has
an orange rim. L5 (21 Nov): an orange ring under a skater says he is down; a hard check is drawn (snow, ice chips) and
felt (hit-stop, shake): see "Fun".

**First minute (L5)**: a person's session starts with a short drill (the ring, a pass, a pass back, a shot into the empty
net), then the match; Enter skips it. The panel comes after R.

## Crazy modes (L5, 21 Nov)

Three modes on the start panel (A / D, then Space) turn the house game into an arcade game. They are reached only from the panel (no
keyless mode_<id> action: a declared action is in the input hash, and the base game must hash as before). F is the ability key in them;
the right mouse button still body-checks.

- **Arsenal** (neon arena, amber accent): beacons of light appear in three zones (first after 2 s, then every 4 s, up to 5 on the ice; seeded).
  Skate over one (0.5 m plus your body radius) to take it; bots take them too and peel off for a near one. Effects: speed (skate speed and
  acceleration x1.5, 5 s), precision (a shot within 30 degrees of the goal centre goes to it, 8 s), big puck (radius x1.5, 10 s), heavy puck
  (drag 0.8, top speed x0.5, 6 s). Ability beacons give one charge of: shotgun, hip check, shield or slow puck.
- **Shotgun** (daylight hall): every skater holds the shotgun; F loads it, the next shot leaves at x1.5 and knocks down every standing skater
  within 1 m (plus his body radius) of its path for up to 2 s of flight, team-mates and goalies too. It comes back after 20 s.
- **Glow Ice** (neon arena, the base rules): a dark sheet with lines of light, the blue half solid cyan and the red half dashed red, a faint grid,
  light trails behind skaters and the puck (the puck's the brightest), blue and brick-red suits with light trim. Plays exactly like base
  (seed 1: the same state, frame by frame, but for "mode" and "game_line").

| Ability (F) | What it does | Numbers (data/boosts.json) |
|---|---|---|
| Shotgun | the next shot x1.5, downs everybody on its path | 90 frames down, path 1.0 m + body radius, 120 frames of flight, ends under 6 m/s |
| Hip check | armed 60 frames; lands on the first opponent in reach even from a standstill | down 60 x 1.5 frames, the victim slides 3 m |
| Shield | 6 s in which no check or cross-check lands on you (a bubble shows it) | 360 frames |
| Slow puck | the next pass or shot leaves at half speed and wakes up after 2 s | x0.5 for 120 frames |

Abilities have a 20 s cooldown (1200 frames); the plate at the bottom right says READY, NEXT SHOT, the seconds left, or the shield's time.
Tests: tests/crazy_shotgun.gd (two defenders on the line go down, a plain shot downs nobody), crazy_hipcheck.gd (3.0 +- 0.5 m, 1.5x down),
crazy_shield.gd (the check is blocked, the shield ends at 360 frames), crazy_slowpuck.gd (half speed, wakes at 120), crazy_pickups.gd (spawn,
take, effects, expiry), crazy_modes.gd (Arsenal and Shotgun to the end with bots, abilities used, pickups taken). Each held on seeds 1 to 20.

## Fun (night of 21 Nov, lane L5)

Hockey is the first dungeon and the yardstick for "designed to be fun". Each ingredient below has a switch so it can be
seen with and without it (a key, or a value in `data/tuning.json` and a rerun). Every figure was taken headless on
seeds 1 to 20 unless the line says otherwise; the look was judged from clips recorded in a window
(`docs/shifts/2026-11-21-night/lanes/L5-hockey/`).

| ingredient | what it is | where | to compare without it |
|---|---|---|---|
| **Play camera** | A broadcast camera that follows the play. It looks down at 50 degrees from the near side, so W is still up the ice and D still right. It frames the puck or its carrier and leads 5 m in the attack direction plus 0.45 s of the puck's speed. It keeps you in the picture, pulling 35 % toward you and widening from 20 m to 30 m when you are far from the puck. It eases with a critically damped follow (no overshoot). In a goal's replay it follows the puck at 15 m. It cuts, never pans, to each face-off. L5c: each match opens with an establishing shot of the whole rink from 46 m, which swoops in to the play over 100 frames (the opening face-off does not cut it). While the horn goes after a goal it moves in close on the net at 12 m, then follows the replay. | `scripts/fun/cam.gd`, tuning `follow` | **V**: the old fixed top view (`arena`) and back |
| **Hit-stop** | A stumble or knockdown that closes at 5 m/s or more freezes the game for 4 to 9 frames (more for a harder hit, 10 m/s and up gets 9). All of these hold: the skaters' bodies and figures, a loose puck (its velocity is kept), and the clock. Then everything goes on exactly where it was. It counts physics frames and is in the state hash. A record of it replays to the same hash (selftest `hockeyfun.*`). It applies only within 24 m of you. | `scripts/fun/fun.gd`, tuning `fun.stop*` | `fun.stop` false |
| **Shake, burst, punch** | The same hard check shakes the camera (0.12 to 0.4 m at the lens), throws blue snow and inked ice chips at the contact, squashes the victim's figure, and pulls the camera 12 to 22 % closer for 40 frames. A small bump stays quiet. | `scripts/fun/fun.gd`, `scripts/fun/cam.gd` | `fun.shake` false |
| **A man down reads as down** | An orange ring (1.25 m) lies under a skater for as long as he is down (lying and rising), under his flat fall pose. | `scripts/look.gd`, tuning `look.down_ring` | `look.down_ring` 0 |
| **Goalies** | One per side, white pads, a bigger figure (body scale 2.4). He stands 1.0 m out on the line from his goal's centre to the puck as he saw it `reaction_frames` ago, never more than 1.4 m off the middle. He moves there at `speed` and faces the puck. **Saves:** a puck shot at his net whose path passes within `glove` (0.9 m) is caught; a goalie on the move (faster than 1.2 m/s) reaches only 0.6 of that. A carrier who brings the puck within `poke` (2.2 m) of him loses it to a poke check. His body stops the rest, which gives a rebound. He holds a caught puck 40 frames, then passes to the mate with the most room, and to you when you have it. He passes only to a mate at least 8 m up ice; with nobody there he clears the puck up the middle. He covers a mate's puck at his own goal mouth. A puck a goalie holds is never a goal. These three came from own goals that won matches for an idle hand. Nobody checks him or pokes his puck. **Beaten by:** a shot to the far side from an angle; a one-timer after a pass across, while he is still moving; a shot outside his glove; a rebound. The level changes the red goalie only. | `scripts/keeper.gd`, tuning `goalie`, levels `goalie` | the mode key `"goalies": false` (pond hockey has none) |
| **Shots go at the cursor** | With the mouse on the ice a shot leaves the blade at the point under the cursor. This applies when that point is at least 4 m away and in front of the stick. Before, the shot flew parallel to the stick from the blade, 1.24 m right of the cursor. | `scripts/rink_api.gd` `shot_dir` | none (the old way was a bug a goalie made visible) |
| **Your mates set you up** | A blue mate shoots only within 240 frames (`ai.json` `assist_frames`) of your own pass or shot: a give-and-go, or the rebound of your shot. Otherwise he passes to you: at once from out of range, when pressed, or after `feed_frames` (40) of carrying. A match you do not play is not won for you. Before this, the idle hand won 17 of 20 against rookie: your mates won it. | `scripts/ai/brain.gd` (`feed`) | `assist_frames` 100000 |
| **One-timer (L5b)** | A shot taken within 14 frames of taking your own side's pass flies 1.35x as hard (18 to 24.3 m/s). The card shows "ONE-TIMER!" with a crack and a kick of the camera. Against a goalie who is still moving across, this is the shot that scores. | `scripts/rink_api.gd` `try_shoot`, tuning `shoot.one_timer_frames` / `one_timer_scale` | `one_timer_frames` 0 |
| **Nobody swarms a goalie (L5b)** | While a goalie holds the puck, the other side's skaters wait 10 m out (`ai.json` `goalie_gap`), each in his lane; nobody may check or poke him anyway. The clips showed five figures round a goalie with the puck. | `scripts/ai/brain.gd` | `goalie_gap` 0 |
| **A save is an event** | When a goalie catches a shot (8 m/s or more), the card shows "SAVE!  VLAD" for 45 frames, with a small shake, snow at the glove and the glove's thump. | `scripts/fun/fun.gd` `_save`, `scripts/fx/fx.gd` | `fun.shake` false (the card stays) |
| **The goalie's figure (L5b)** | His own biped step is off (the pack places him), so his figure is ticked by the fun layer. It holds a stance, and on a caught shot it stabs (the pass clip) and squashes. | `scripts/fun/fun.gd` `_tick_goalie_rigs` | - |
| **AI shoots at corners** | The red and blue AI shoots at the far side from the goalie (`ai.json` `corner_z` 1.5), with the level's spread. | `scripts/ai/brain.gd` | `corner_z` 0 |
| **Goal moment** | The pause after a goal (2 s) holds the net for 24 frames. It then replays the shot in slow motion: the bodies' recorded places, interpolated, from 10 frames before the shot, at 1.5x to 3x slower to fit the pause. The goal card stays over it: "GOAL!  LEO", "BLUE 2 : 1 RED", then "REPLAY". The face-off follows as before, with the camera cut there. The replay moves only bodies the pause already holds. The face-off then places everybody, so the next live frame is as it was without the replay. | `scripts/fun/fun.gd`, tuning `fun.hold_frames` .. `slow_max` | `fun.replay` false |
| **Match-end card** | It shows the result and the score ("YOU WIN   3 : 1"), the best moment and "R: rematch \| Esc: leave". The best moment is the hardest check of the match ("LEO flattened IGOR at 9.3 m/s"), else the longest goal ("YOU scored from 14 m"). The winning goal's replay runs under it. | `scripts/fun/fun.gd` `card` | - |
| **Names** | Every skater has a name on the cards: YOU, LEO, MAX against BRUNO, IGOR, OTTO; KUBA and VLAD in goal. | tuning `look.names` | - |
| **First minute** | A person's session starts with a drill that is playable at once: skate to the ring (W A S D), take LEO's pass, pass it back (Q), take it again and shoot into the empty net (click). The match then starts at the default level and mode; R after a match opens the panel. Each step is one line on the screen: a key and a few words. **Enter** skips it. The drill's goal is no score. | `scripts/intro.gd`, tuning `intro`, drill `intro` | **Enter** |

## Contact and skating (thirdjam port)

The simulation runs at 60 physics frames per second. The skater rig is drawn at 2.2×. Its contact scale of 2.93 gives a 0.879 m radius at the shoulders and back. Goalies are drawn at 2.4× and use the same ratio for a 0.959 m radius. Each numbered rule gives its thirdjam source.

1. **Carry and sweep.** A loose puck enters possession within 1.45 m. The carrier's blade lies along the aim, or 24.1° to his right at half reach without aim. Distance is `max(1 m, (0.66 + reach_fraction × 1.98) × pace)`, with pace 0.75 normally and 1 while sprinting. The minimum also clears the holder's capsule plus the 0.12 m puck radius (1.079 m for a goalie). Full aim gives 1.98 m walking and 2.64 m sprinting. The puck closes 60% of the local gap each frame, including on a take, using an inside point at the boards. A sweep over 6° renews poke protection for 12 frames, or six when sprinting. A blocked poke spends its cooldown. Losing possession clears protection. `JamSim.cpp:862–869,1478–1545,4160–4177`, `JamCartridge.h:159,182–189,295`, `JamSim.h:494`.
2. **Reverse and first step.** Input over 0.05 more than 120° against velocity cuts up to 26 m/s² times input strength and suspends thrust while the skater turns. Above 1 m/s, entering the stop throws ice spray and requests the skate-stop clip. Below 0.5 m/s he can pivot in place. His own brake below 2 m/s, a cut over 60° in ten frames, or six frames resting below 1 m/s earns 20 frames at 1.8× acceleration. A rested skater can drift below 3 m/s and keep the first push. Downed or stumbling skaters cannot earn a cut. Field bots use the same rules. `JamSim.cpp:1302–1335,1378–1412,1430–1452`, `JamCartridge.h:90–125`, `JamSim.h:499–504`.
3. **Body contact.** F winds up 12 frames (L4b, 21 Nov: thirdjam `CheckWindupFrames` 8, here the body_check clip's hit frame 12; `JamSim.cpp:1968-2177`): the human is drawn up to 1.0 m toward the man he pressed at (`check_pull_m`), so the bodies meet as the wind-up ends and the hit lands on the frame the clip shows it; a meeting inside the wind-up is the hit, resolved before the bodies touch. Bots press when their man will be in reach as the wind-up ends. Then it opens a 12-frame window (six for a bot) within a 0.43 m surface gap and a 60° cone (2.188 m between the two skater centres). A hit costs 40 frames of recovery and a miss costs 20. Only a skater off puck can hit. Goalies are shielded. Impulse is attacker mass times the sum of closing speed and push, floored at zero. A body check adds 1.5 m/s of push. Within 1.5 m of the rounded boards an outward hit gains up to 25% on the victim. Stability begins at mass × 6. Below 1 m/s the visible front brace is 1.5× and a free skater's side brace rises to 5×. Moving stability falls to 0.85× at top speed. Sprint, full shot charge, and an unseen hit multiply it by 0.7, 0.8, and 0.8 respectively. A held cross-check meeting a faster opponent also multiplies it by 0.75. `JamSim.cpp:2523–2601`, `JamCartridge.h:386–405,526`, `JamSim.h:510–514,750–758,788`.

   Divide impulse by stability. Below 0.4 gives a bump. From 0.4 a stumble halves the victim's speed, and from 0.7 it frees the puck. From 1.0 the victim goes down for 60 frames, rising to 150 at ratio 3. Loose velocity combines half the victim's current velocity, a seeded 1 m/s scatter and 1 m/s back toward the hitter. A renewed stumble caps at bump. For 120 frames after getting up, the skater takes bumps and bots decline to initiate a check on him. On a stumble or fall the hitter gives half his lunge (cross-check uses positive closing plus thrust), with mass setting the victim's speed change. Body checks exchange remaining closing velocity at restitution 0.2, counting standing brace as effective mass. A less stable attacker whose free impulse reaches his own stability recoils to half speed if the victim stays up. `JamSim.cpp:2603–2784`, `JamCartridge.h:396–405,533–537`.
4. **Cross-check.** A tap winds up for eight frames, 12 for bots. The aimed opponent has priority within a 0.88 m surface gap and 70° (2.638 m between the two skater centres), then a miss stays live ten frames. Cross-check recovery is 45 frames, independent of body-check recovery. Thrust is 3 m/s. Into the back (direction dot facing above 0.5), it scales by closing speed up to 3 m/s. A front cross to the chest bypasses the standing brace. A human rear tap on a carrier, including one who carried in the last 12 frames, stumbles him. Other rear taps cap at bump. A stick lift on a carrier strips toward the hitter unless the sweep shield holds. A physical fall or sufficiently hard stumble can still dislodge it. A chaser can tap when a body check is unavailable or too slow. The closing threshold for the cross is above 0 m/s in Classic, 2 on Rookie, 1 on Pro and 0.25 on All-star. `JamSim.cpp:1742–1845,2559–2570,2596–2601`, `JamCartridge.h:165,171,461–488`.

   Holding for ten frames puts the shaft across the body. The first opponent within both body radii plus 0.2 m takes one momentum hit. Release rearms the hold. The held skater has 90% top speed, 70% turn rate and cannot sprint. The cross-check clip plays at wind-up and refreshes every 20 frames while braced, with the shoot clip as fallback. Body checks request the body-check clip. `JamSim.cpp:1946–1972,2350–2356`, `JamSim.h:750–758`.
5. **Sprint and stamina.** Free skaters get 1.15× speed and thrust, including bots. Shift adds another 15% while moving and able to act. The carrier instead gets 0.92×, with an 8% sprint bonus capped at 0.97 × 1.15 of base. At the default 8 m/s the sprinting defender reaches 10.58 m/s and the carrier 7.95 m/s. The skate dial scales the base. Each sprint frame spends 360 of 64,800 ticks and each recovery frame returns 180, emptying in 180 frames and filling in 360. Sprint can resume once stamina is positive. The bottom-centre bar shows the human's stamina in ten steps. The match AI never requests sprint. `JamSim.cpp:1266–1300,1338–1346`, `JamCartridge.h:67,70,80–85`, `JamSim.h:505`.
6. **Flat shot on release.** A fresh carrier press starts a hold. Only shot-ready frames count. Releasing after one to four frames fires at the ordinary 18 m/s. Longer holds add 8 × held frames / 30 m/s, capped at 30 frames. A half charge gives 22 m/s and a full charge 26 m/s. Losing the puck cancels the press even if the same player recovers it. A new press rearms the shot. A release within 14 frames of receiving a mate's pass gets the larger of charged speed and 1.35× ordinary speed (24.3 m/s by default). The puck stays on the ice and the shoot clip plays on release. Match AI shoots a tap.
7. **The goalie holds it on the ice side.** A goalie carries a caught puck on the side of his body away from his own net (L4 director, 21 Nov: his outlet pass left from a blade inside the net, and the idle hand won rookie seed 6 by it). `JamSim.cpp:2786–2809,2811–2895`, `JamCartridge.h:73,320–321,340`.
8. **Nobody stands in a man who is down** (L4b; thirdjam `DownedRadiusM`, `JamCartridge.h:416-422`). A lying man is the segment from his feet 3.1 m along his facing (`hits.lying_length`, measured on the fall clip; TLHit.down v1 falls forward, so this follows the falls experiment's direction when it lands), 0.6 m thick (`hits.downed_radius`); a man who fell onto the hitter's line pushes him out to one side; a skater on his feet is moved out of it (at most 0.3 m a frame) and the speed he had into it is taken off, so he goes round. tests/bot_downed.gd.

## What the game is (16 Nov)

- **Possession by reach**: a loose puck inside a skater's 1.45 m ring is his; he carries it on the blade of his stick
  at the reach described above. He loses it
  to a shot, a pass, a poke (from 1.9 m to the puck), a hit, or behind his own net: after 1.5 s there an opponent in reach takes it, after 3 s it is put 2 m in front of the net.
- **A puck inside a goal volume counts**, carried, released or lying there; inside your own net it is an own goal.
- **Five modes** as data files (`data/modes/*.json`), **three periods**, **the rule dial** (skate speed, shot speed,
  ice grip, bot sharpness; one step a period, for both teams).
- **Face-offs are won, not given**: at the start of a match, of each period and after each goal the puck drops up to
  0.4 m off centre and the two centre men stand 3.0 m from the centre, at least 2.4 m from it, outside the 1.45 m reach:
  nobody owns it at the drop; whoever skates to it first takes it. Measured on 20 seeds (the opening face-off): nobody
  owned it at the first live frame in 60 of 60 runs; doing nothing, the human was never first to it; skating straight at
  it he took it 20 of 20 against rookie and 12 of 20 against all-star.
- **Three levels** of opponents (`data/levels/*.json`; red only): rookie reacts 40 frames late at 55 % of your speed;
  pro 16 frames at 79.5 %; all-star 13 frames at 83 %, longer range, tighter shots, readier to check.

The ladder (20 seeds a cell, `tl ladder --pack engine/packs/hockey --seeds 20`, 16 Nov 06:08; the human side is one
bot's decisions pressed through TLHand of the named profile, with the cursor through the hand, shooting only inside
16 m; 95 % intervals by the normal approximation):

| level | read through | wins | win % (95 %) | target band |
|---|---|---|---|---|
| rookie | newcomer (the hand it is meant for) | 18 / 20 | 90 (77..100) | 80..90 |
| rookie | perfect | 20 / 20 | 100 | - |
| pro | regular (meant) | 8 / 20 | 40 (19..61); on 40 seeds 21 / 40 = 53 (37..68) | 45..55 |
| pro | perfect | 18 / 20 | 90 | - |
| all-star | sharp (meant) | 5 / 20 | 25 (6..44) | 20..30 |
| all-star | perfect | 16 / 20 | 80 | - |

Pro through the regular hand is below its band on these 20 seeds and inside it on 40: at 20 seeds the interval is wider
than the band. The lever is pro's reaction and speed in `data/levels/pro.json`.

**The ladder with goalies (L5b, 22 Nov 00:00; L5's table of 23:00 is in lanes/L5-hockey/REPORT.txt).** Command:
`tl ladder --pack engine/packs/hockey --seeds 20`, 20 seeds a cell, 95 % intervals by the normal approximation. The
human side is one bot's decisions pressed through TLHand of the named profile, with the cursor through the hand,
shooting at the goal's side away from the goalie (z 1.5). Idle presses nothing. The figures moved with goalies, shots
at the cursor and mates who feed you. They were not tuned back to 16 Nov. The rookie goalie was weakened once so the
perfect hand wins every rookie match (the must-win cell).

| level | newcomer | regular | sharp | perfect | idle |
|---|---|---|---|---|---|
| rookie | 18 / 20 (90, 77..100) | 20 / 20 (100) | 20 / 20 (100) | **20 / 20** (100) | 0 / 20 (13 drawn at the time limit) |
| pro | 5 / 20 (25, 6..44) | 12 / 20 (60, 39..81) | 12 / 20 (60, 39..81) | 19 / 20 (95, 85..100) | 0 / 20 |
| all-star | 3 / 20 (15, 0..31) | 10 / 20 (50, 28..72) | 12 / 20 (60, 39..81) | 14 / 20 (70, 50..90) | 0 / 20 |

Goals for : against per match: rookie perfect 3.00 : 0.05, pro regular 2.05 : 1.45, all-star sharp 1.70 : 1.50,
all-star newcomer 0.85 : 1.90. The idle hand wins nothing, because your mates set you up instead of scoring for you.
It took four rounds: mates who scored alone, then red own goals from a goalie's outlet and a carrier circling his net,
then a pass to a downed b0 that slid 50 m into the far net.
Reading it: rookie is a level for anyone who presses keys. Pro and all-star order the hands newcomer, then regular and
sharp (level with each other within the interval at 20 seeds), then perfect.

The hand profiles (reaction, taps, lapses) and the cursor's numbers (lag, speed, miss) are the kernel lanes' reasoning,
not measured on a person. Against "none"/Classic a person's hand lost almost always (regular 1 of 20, newcomer 2 of 20).

## How it is tested

`tl check --tier full --only packs` runs lint, smoke, every test below on seed 1, and invariants (the first test twice,
equal hashes). `tl ladder --pack engine/packs/hockey [--seeds N] [--cells level_hand,..]` runs the six ladder cells over
N seeds and prints the table above. The original table dates to 16 Nov. The two round-3 mechanics tests run on seeds 1–20 for admission.

| test | what it holds |
|---|---|
| bot_hockey | the key-only bot (perfect hand, rookie) plays a match to its result and takes the puck; the determinism anchor |
| bot_hockey_regular, bot_hockey_newcomer | the same through a person's hand against Classic: played to the end, the hand acted |
| bot_ladder_rookie_perfect | **blue wins** (the gate's one verdict about the game) |
| bot_ladder_rookie_newcomer, _pro_regular, _pro_perfect, _allstar_sharp, _allstar_perfect | played to the end, the hand acted; the win share is the ladder's figure |
| bot_hockey_ai | the AI on all six skaters: a winner, AI shots, every skater moved (L5: goalies keep to their crease and are not counted) |
| bot_reach | 13 rows: a puck in the ring is his within 1 frame (still, behind, facing away, sliding in, skating through at walk / full / sprint, Space or Q held, after his own pass, a poke both ways, including a reaction 12 frames after the poke becomes available); 8 of 10 passes reach the mate |
| bot_match | bot-only play until both sides have scored (from 6,000 frames, at most 18,000; L5: a fixed 6,000 before goalies, red's first goal now comes at up to 12,267 frames on seeds 1..20): both sides score; no skater outside the rink |
| bot_sprint | free and carrier speed, every drain/refill tick, and a defender landing a body check from six metres behind a sprinting carrier on open ice |
| bot_charge | one-, four-, five-, 15-, 30- and 40-frame holds, a one-timer, and loss, reacquisition and re-press after an opponent’s poke |
| bot_carry_turn | both stick sweeps through a skating turn, uninterrupted possession, normal and sprint reach and shield duration |
| bot_reverse_stop | stopping distance and frames, a single stop, first-step acceleration against an unearned push and red-chaser bursts in a bot match |
| bot_contact | 13 set starts measure recoil, head-on and matched 8 m/s glides, the standing brace, the front cross-check, one spent hold and the get-up grace. After each hit the standing pair must stay at least 1.71 m apart |
| bot_check | the hit table on live play frames: monotone by closing speed, head-on and side; a braced man holds; the carrier cannot check; the cross-check takes the puck |
| bot_windup (L4b) | a press from 1.6 m lands on the body_check clip's hit frame 12 (the pull brings him); from 0.33 m the meeting inside the wind-up is the hit |
| bot_downed (L4b) | after a head-on knockdown b0 skates on through where r0 lies: his centre stays his radius + 0.45 m off the lying body, and he gets past |
| bot_modes | all five modes end by their rules, none inside 2 s, none over 9,000 frames |
| bot_dial | the dial in periods 1 and 2, a third try refused, the match paused while open |
| bot_aim | the released shot goes where the aim points while he skates another way (L5: measured from the puck to the aim point, as the shot now flies at it); a pass to the mate aimed at; the dead zone; a cleared aim |
| bot_buttons | the four held-button transitions through a take and a loss, then a fresh press |
| bot_goals | a puck carried in, released, lying in a net counts (own goal too); on the blade behind the net it does not |
| bot_faceoff, bot_faceoff_idle, bot_faceoff_allstar | nobody owns the puck at the drop; doing nothing he is not first to it; who wins the draw skating at it is a number (rookie, all-star) |
| bot_goalie (L5) | four drills with a real aim and tap on release, goalies in their nets, level none: a shot straight at him from 12 m is saved; a shot to the far side from an angle scores; a one-timer after a pass across scores; a puck carried into his crease is poke-checked; he never leaves his crease |
| bot_fun (L5) | a hard check (10.58 m/s on round-3 seed 1) stops the game: every skater still and the clock held for the stop's frames; a 2 m/s bump has no stop; a goal is replayed in the pause, then the face-off; L5b: a shot straight off a pass is a one-timer (24.3 m/s), a tap after carrying for 16 frames is ordinary (18 m/s) |
| bot_intro, bot_intro_skip (L5) | the first-minute drill played through (skate, take, pass, back, release a shot from in front of the goal line, a goal into the empty net), then the match from 0 : 0; Enter at frame 30 skips it to the match |
| bot_ladder_<level>_<hand> (L5: 15 cells) | tap shots release through the hand; levels rookie, pro, all-star x hands newcomer, regular, sharp, perfect, idle; idle presses nothing |
| bot_hand_newcomer, bot_hand_perfect | card.team_possession's hand checks (contracts/CARDS.md): level rookie through the hand, played to the end; `won` counted by `tl cards hands engine/packs/hockey --card team_possession` (18 Nov: 18 and 20 of 20 seeds) |

## Known limits (each measured or read in the code tonight)

- L5 (21 Nov): goalies stand in every mode but pond (16 Nov's "no goalies, an open net from the face-off dot" is gone).
  A goalie is placed by the pack each frame (TLBiped.place): his figure stands upright and does not animate a stance.
- L5: the replay moves bodies through recorded places; a skater who was down in it is drawn as he is now, not as he was.
- L5: TLVfx.burst one-shot effects came out at the pack's origin (the centre spot) in a window (physics interpolation;
  the node is placed after it is added): the pack puts each burst under a node placed first (fun.gd, fx.gd `burst`).
- The stick is drawn through the boards when a skater stands at them (the rig's stick; the puck itself stays inside).
- Two bodies closing head on can sit up to 0.09 m inside each other for a step (the kernel's stated bound).
- A stumble and the get-up read in motion, not in a still.
- L4 (21 Nov day): a floored man falls FORWARD whatever the hit (TLHit.down v1 ignores `from_dir`; the pack passes it, the falls
  experiment replaces the body): after a head-on check he lies under the hitter's skates.
- L4b: headless (tests, gate, world) the figures play no clips and the stick is not posed: drawing only, and no hashed value
  reads a pose (the lying body is read from the body). This is what keeps hockey at the frame budget.
- L4: the drawn blade is steered onto the puck through `stick_yaw` in a loop on the blade socket (scripts/rink_api.gd
  `pose_sticks`); with an aim swung across the body (a 180-degree flip) the puck swings round him over about three frames.
- L4: the contact body is the drawn body (radius 0.879 m at 2.2x); with arms and sticks out in a hit the figures still touch
  visibly; a lying figure is kept clear (rule 8) but during the fall itself (about 15 frames) the hitter can stand in it.
- Nobody has played it with a real mouse or a real keyboard: everything above is bots.
- Sudden death can end in under 5 s from a breakaway at the first face-off (hockey, but short).
- In a world (`world.sh alone --mode=bot`) the game hashes differently from alone: under the kernel lane's study.
- The bots pass rarely (with the cursor they usually shoot first); the AI's play is simple roles, not hockey sense.
