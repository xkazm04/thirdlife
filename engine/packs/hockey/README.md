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
| sprint | Shift (held) | |
| aim the stick (shot, pass, poke, cross-check go where it points) | | the cursor on the ice |
| with the puck: shoot | Space | left button |
| with the puck: pass (to the mate nearest where the stick points, aimed where he will be) | Q | right button |
| without the puck: cross-check (a stick shove: takes the puck, never knocks down) | C | left button |
| without the puck: body check (outcome by closing speed) | F | right button |
| brace (stand still and hold: a hit from the side becomes a bump) | F held | right button held |
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

## Fun (night of 21 Nov, lane L5)

Hockey is the first dungeon and the yardstick for "designed to be fun". Each ingredient below has a switch so it can be
seen with and without it (a key, or a value in `data/tuning.json` and a rerun). Every figure was taken headless on
seeds 1 to 20 unless the line says otherwise; the look was judged from clips recorded in a window
(`docs/shifts/2026-11-21-night/lanes/L5-hockey/`).

| ingredient | what it is | where | to compare without it |
|---|---|---|---|
| **Play camera** | A broadcast camera that follows the play. It looks down at 50 degrees from the near side, so W is still up the ice and D still right. It frames the puck or its carrier and leads 5 m in the attack direction plus 0.45 s of the puck's speed. It keeps you in the picture, pulling 35 % toward you and widening from 20 m to 30 m when you are far from the puck. It eases with a critically damped follow (no overshoot). In a goal's replay it follows the puck at 15 m. It cuts, never pans, to each face-off. L5c: each match opens with an establishing shot of the whole rink from 46 m, which swoops in to the play over 100 frames (the opening face-off does not cut it). While the horn goes after a goal it moves in close on the net at 12 m, then follows the replay. | `scripts/fun/cam.gd`, tuning `follow` | **V**: the old fixed top view (`arena`) and back |
| **Hit-stop** | A body check that closes at 5 m/s or more freezes the game for 4 to 9 frames (more for a harder hit, 10 m/s and up gets 9). All of these hold: the skaters' bodies and figures, a loose puck (its velocity is kept), and the clock. Then everything goes on exactly where it was. It counts physics frames and is in the state hash. A record of it replays to the same hash (selftest `hockeyfun.*`). It applies only within 24 m of you. | `scripts/fun/fun.gd`, tuning `fun.stop*` | `fun.stop` false |
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

## What the game is (16 Nov)

- **Possession by reach**: a loose puck inside a skater's 1.45 m ring is his; he carries it on the blade of his stick
  (measured on the rig: 2.77 m ahead, 1.24 m to his right; it slides out there over 8 frames after a take); he loses it
  to a shot, a pass, a poke (from 1.9 m to the puck), a hit, or behind his own net: after 1.5 s there an opponent in reach takes it, after 3 s it is put 2 m in front of the net.
- **A puck inside a goal volume counts**, carried, released or lying there; inside your own net it is an own goal.
- **Hits by closing speed**, shown by the figures alone: under 3 m/s a bump, up to 7.8 m/s a stumble (the puck comes
  loose), above it a knockdown (down 30 to 60 frames, then the kernel's get-up). The carrier cannot check.
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
N seeds and prints the table above. Each test below passed on 20 of 20 seeds (1..20) on 16 Nov 06:15.

| test | what it holds |
|---|---|
| bot_hockey | the key-only bot (perfect hand, rookie) plays a match to its result and takes the puck; the determinism anchor |
| bot_hockey_regular, bot_hockey_newcomer | the same through a person's hand against Classic: played to the end, the hand acted |
| bot_ladder_rookie_perfect | **blue wins** (the gate's one verdict about the game) |
| bot_ladder_rookie_newcomer, _pro_regular, _pro_perfect, _allstar_sharp, _allstar_perfect | played to the end, the hand acted; the win share is the ladder's figure |
| bot_hockey_ai | the AI on all six skaters: a winner, AI shots, every skater moved (L5: goalies keep to their crease and are not counted) |
| bot_reach | 13 rows: a puck in the ring is his within 1 frame (still, behind, facing away, sliding in, skating through at walk / full / sprint, Space or Q held, after his own pass, a poke both ways); 8 of 10 passes reach the mate |
| bot_match | bot-only play until both sides have scored (from 6,000 frames, at most 18,000; L5: a fixed 6,000 before goalies, red's first goal now comes at up to 12,267 frames on seeds 1..20): both sides score; no skater outside the rink |
| bot_check | the hit table: monotone by closing speed, head-on and side; a braced man holds; the carrier cannot check; the cross-check takes the puck |
| bot_modes | all five modes end by their rules, none inside 2 s, none over 9,000 frames |
| bot_dial | the dial in periods 1 and 2, a third try refused, the match paused while open |
| bot_aim | the shot goes where the aim points while he skates another way (L5: measured from the puck to the aim point, as the shot now flies at it); a pass to the mate aimed at; the dead zone; a cleared aim |
| bot_buttons | the four held-button transitions |
| bot_goals | a puck carried in, released, lying in a net counts (own goal too); on the blade behind the net it does not |
| bot_faceoff, bot_faceoff_idle, bot_faceoff_allstar | nobody owns the puck at the drop; doing nothing he is not first to it; who wins the draw skating at it is a number (rookie, all-star) |
| bot_goalie (L5) | four drills, goalies in their nets, level none: a shot straight at him from 12 m is saved; a shot to the far side from an angle scores; a one-timer after a pass across scores; a puck carried into his crease is poke-checked; he never leaves his crease |
| bot_fun (L5) | a hard check (10 m/s) stops the game: every skater still and the clock held for the stop's frames; a 2 m/s bump has no stop; a goal is replayed in the pause, then the face-off; L5b: a shot straight off a pass is a one-timer (24.3 m/s), held 16 frames it is not (18 m/s) |
| bot_intro, bot_intro_skip (L5) | the first-minute drill played through (skate, take, pass, back, shoot, a goal into the empty net), then the match from 0 : 0; Enter at frame 30 skips it to the match |
| bot_ladder_<level>_<hand> (L5: 15 cells) | levels rookie, pro, all-star x hands newcomer, regular, sharp, perfect, idle; idle presses nothing |
| bot_hand_newcomer, bot_hand_perfect | card.team_possession's hand checks (contracts/CARDS.md): level rookie through the hand, played to the end; `won` counted by `tl cards hands engine/packs/hockey --card team_possession` (18 Nov: 18 and 20 of 20 seeds) |

## Known limits (each measured or read in the code tonight)

- L5 (21 Nov): goalies stand in every mode but pond (16 Nov's "no goalies, an open net from the face-off dot" is gone).
  A goalie is placed by the pack each frame (TLBiped.place): his figure stands upright and does not animate a stance.
- L5: the replay moves bodies through recorded places; a skater who was down in it is drawn as he is now, not as he was.
- L5: TLVfx.burst one-shot effects came out at the pack's origin (the centre spot) in a window (physics interpolation;
  the node is placed after it is added): the pack puts each burst under a node placed first (fun.gd, fx.gd `burst`).
- A carried puck 3 m out is easier to poke than on real ice (from 3 to 4.9 m from its carrier).
- A taken puck slides 1.6 m to the blade over 8 frames: a short visible move.
- The stick is drawn through the boards when a skater stands at them (the rig's stick; the puck itself stays inside).
- Three or more skaters in a scrum draw as one figure (bodies 0.66 m, trunks 1 m ahead of the feet at scale 2.2);
  the puck can hide under them.
- Two bodies closing head on can sit up to 0.09 m inside each other for a step (the kernel's stated bound).
- A stumble and the get-up read in motion, not in a still.
- Nobody has played it with a real mouse or a real keyboard: everything above is bots.
- Sudden death can end in under 5 s from a breakaway at the first face-off (hockey, but short).
- In a world (`world.sh alone --mode=bot`) the game hashes differently from alone: under the kernel lane's study.
- The bots pass rarely (with the cursor they usually shoot first); the AI's play is simple roles, not hockey sense.
