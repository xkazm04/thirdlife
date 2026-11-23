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

A button held across a change of possession needs a fresh press for its new action. A shoot press in the one-timer window arms the shot as the pass arrives.
Without a cursor on the ice (or with the mouse outside the window) the stick points where you skate.

**Level and mode** are chosen on the panel before the first face-off (and again after R, with your last choice kept):
1, 2, 3 pick the level (rookie, pro, all-star), A / D the mode (three against three; outnumbered, three against five;
sudden death; pond, no checks; big ice, two against two), each mode with its line from `data/modes/<id>.json`; Space or
the left button starts. Touch nothing and it starts by itself after 10 s (`menu.auto_start_frames` 600 in
`data/tuning.json`) with what it shows. The first panel shows the params `level` / `mode` of `data/tuning.json` (1 rookie
and 0 three against three by default; level 0 "Classic", the opponents of `data/ai.json`, is a param only) or the
Designer panel's sliders. Only a person's session shows it: a bot, a smoke run, a capture and a world's game nobody is in
start at once as before. The line at the bottom left of the screen names both once the match runs.

**The rings**: the green ring under your skater is your reach (1.45 m from your centre): you take a loose puck inside it when its speed relative to you is below 15 m/s. From 15 to below 20 m/s it bobbles (it keeps 40 % of its speed and is not yours for 10 frames). Faster pucks can pass through the ring. A pass meant for you is yours up to 28 m/s relative. A wider ring under a skater says he carries the puck,
in his team's colour (yours green; another carrier's ring shows after he has held it 20 frames). The puck itself has
an orange rim. L5 (21 Nov): an orange ring under a skater says he is down; a hard check is drawn (snow, ice chips) and
felt (hit-stop, shake): see "Fun".

**First minute (L5)**: a person's session starts with a short drill (the ring, a pass, a pass back, a shot into the empty
net), then the match; Enter skips it. The panel comes after R.

## Puck, speed and the bots' decisions (N3, night of 22 Nov)

The owner, 21 Nov: "unplayable through inbalancing of puck stickiness, players speed, ability AI to decide what to do,
when to pass and shoot". Spec: `docs/research/HOCKEY-ARCADE.md` section 5, scaled to our 4.4 m figure (lengths x1.65).
The body-check model and its rate were kept (the owner's ruling).

- **The puck is a state** (`possession.puck_state`: loose, carried, pass, shot) with readable loss causes
  (`possession.last.kind`): `poked`, `hit` (a check), `pass` taken by the other side (intercept), `lost` (the carrier's own
  mistake), `bobble`, `dump`, `shot`. `scripts/carry.gd`, `scripts/poke.gd`.
- **Carry**: a critically damped spring (k 400) to the drawn blade; the puck swings out of a turn (dangle, up to 0.82 m).
  Only a **sprint plus a hard turn** loses it (6 frames past 90 % of the dangle): cruising, you can turn as hard as you like.
- **Pickup** by relative speed: under 15 m/s clean, 15-20 a bobble (the puck keeps 40 % of its speed, 10 frames not
  yours), faster it passes. A pass meant for you: a wider window in front (+0.6 m, +-100 deg), a soft magnet in its last
  18 frames (3.3 m), clean up to 28 m/s relative.
- **One-timer**: shoot pressed up to 8 frames before a pass arrives or 6 after: it fires 4 frames after the take at 1.2 x
  the wrist shot (28.8 m/s).
- **Poke (E)**: a 24-frame action, live on frames 6-12, cooldown 40; reach 2.3 m inside +-35 deg of the stick; odds 65 %
  from in front, 45.5 % from the side, 26 % from behind, x0.6 on a carrier who just cut; a whiff halves your turn rate for
  15 frames. **Anti ping-pong**: a new owner cannot be poked for 24 frames; the old owner and opponents within 2.5 m cannot
  steal for 30. Bots give a fresh carrier `fresh_frames` before a stick (H2, 23 Nov: by level, rookie 60,
  pro 6, all-star 0; the mates 6; it was 60 for everybody) and 15 before a body check (`fresh_check_frames`).
- **Speeds** (research ratios): cruise 9.2 / sprint 10.58 m/s; carrier x0.88 (8.1 / 9.31) with 0.8 of the thrust; turn
  4.5 rad/s, x0.85 carrying, x0.67 sprinting; pass 18 m/s (23 beyond 15 m); wrist shot 24, full charge 32; puck cap 34.
- **The bots** (`scripts/ai/`: `brain.gd`, `sense.gd`, `carrier.gd`, `roles.gd`): decide every 15 frames (staggered; the
  carrier every 7-8, loop round 3 of 22 Nov: he saw the pressure late and was hit before his pass; and
  at once on a change of carrier, a pass toward them, a loose puck within 3 m, a hit, and, for the carrier, the moment
  an opponent he saw comes inside `pressure_m` 3.5 m: the pass out of pressure, N3's r2a, landed 22 Nov after E6),
  from what anybody could see
  `reaction_frames` ago, with aim and score noise by level (rookie 18 f / 6 deg / 0.08, pro 12 / 4 / 0.05, all-star
  7 / 2.5 / 0.03; Classic and your mates 5 / 1.5 / 0.02). The carrier scores SHOOT, PASS to each mate, CARRY, PROTECT and
  DUMP (utility, research 5.3; weights in `ai.json`). Roles F1/F2/F3 and D1/D2/D3 by time to the puck; F2 takes the best
  support spot on a 1.5 m grid, F3 stays high; D1 pressures from the inside, D2 stands in the lane to the best receiver,
  D3 guards the slot. A mate who is open calls for your pass (a light ring under him). Goalie depth 1-2 m by the puck's
  distance, lateral speed under 4 m/s.
- **The behaviour pass (H2, 23 Nov; `docs/research/hockey-teardown/BEHAVIOUR-BOTS.md` section 4.1, the line numbers in
  the code; before / after figures in `docs/shifts/2026-11-23-day/lanes/H2-bots/BUILD.md`).** Spacing: mates keep
  `sep_m` 8 m apart with weight `sep_weight` 2.5, the man contesting a loose puck included; two mates within `clump_m`
  2.5 m for `clump_frames` 45 split to `split_m` 5 m (the higher id gives way, anybody gives way to you); the lane-blocker
  stays 5 m off the carrier. Support spots 9-18 m from the carrier (ideal 12-15), re-chosen every 10 frames; the high man
  12 m behind the puck. A carrier settles the puck `settle_frames` 10 before a pass or dump (no one-touch re-pass). Passes
  need a lane of `pass_min_lane` 0.25, weight `pass_weight` 1.8, and a pass up ice counts 0.45 (0.3 before). Your mates shoot like
  anybody and carry it in; when you are open ahead a mate feeds you in `feed_share` of his carries by level (rookie 0.6,
  pro 0.4, all-star 0.2). The level is clumsiness, not slowness: red skates at full pace (`red_skill` 1.0 / 1.0 / 1.05),
  reads 10 / 7 / 5 frames late, aims 8 / 4 / 2 deg wide, shoots from `shoot_min_xg` 0.25 / 0.15 / 0.05 with
  `shoot_weight` 1.6 / 1.9 / 3.0 (all-star shoots from anywhere), pokes after 60 / 6 / 0 frames (all-star at
  `poke_min_odds` 0.15), checks from 6 / 2 / 2 m/s closing and never cross-checks at rookie. Pressure grows with the level: a
  hunter (the nearest non-D1 defender within `hunt_m` 0 / 6 / 20 m) goes at the carrier and may poke and cross-check;
  `forecheck_men` 1 / 2 / 2 enter the carrier's end (the second in `forecheck_share` 1 / 0.6 / 1 of his carries), the
  rest hold at the blue line. Chasers and pressers sprint in `sprint_share` 0.2 / 0.35 / 1.0 of their chases. A skater
  brakes onto his spot only above `brake_above` 3 m/s and keeps his feet moving on it. The sheet's share rolls (feed, forecheck, sprint)
  hash the run's seed and the decision (`brain.gd` `roll`) instead of drawing from `ctx.rng`.
- **Own-goal guards** (each from an idle hand's win in the measurements): no bot pass across its own goal mouth and no
  shot or dump from behind its own net (`carrier.gd` `_near_own_net`; H2 removed the back-pass and corner guards and the
  rule that your mates never carry it into the net themselves); a goalie takes a slow puck, or his
  own side's pass, sliding into his mouth; a loose puck can gain at most 4 m/s a frame without a stick's release (bodies
  squeezed a face-off puck out at 27 m/s); a puck counts only through the mouth, not in from behind the goal line.
- **Big puck** (Arsenal): `TLBall.set_radius` (kernel API 1.13), through `scripts/boosts.gd` `resize`.

**The five bot metrics** (research 5.5; `tests/metrics.gd` reads them from the state in every ladder test and in
`tests/bot_metrics_ai.gd`, the AI on all six at pro; `docs/shifts/2026-11-22-night/lanes/N3-hockey/metrics.mjs` runs and
sums them). 20 seeds a cell, headless, 22 Nov night. Before = this pack on main c7dad86; after = this lane's last code.
Possession is a side's, from its first take until the other side takes the puck or play stops. OZ share = frames in a
side's offensive zone (past x = +-10 m) / frames in either end zone. The hits column is red's stumbles plus knockdowns.

| cell | run | possession median (4-10 s) | passes per possession (1.5-3) / completion (70-85 %) | shots /min/team (1.5-3) / slot or one-timer (>= 40 %) | turnovers /min by cause (none > 45 %, self < 15 %, bobble < 15 %) | OZ share blue / red (35-55 %), entries kept (50-70 %) | goals /game (3-7) | hits /min by red (stumble+down) |
|---|---|---|---|---|---|---|---|---|
| rookie_newcomer | before | 0.8 s | 0.8 / 83% | 2.3 / 27% | 27.2: poke 77%, intercept 14%, check 8%, goalie 1% | 18% / 82%, 36% | 2.0 | 2.5 |
| rookie_newcomer | after | 3.5 s | 1.2 / 64% | 2.3 / 46% | 8.5: check 44%, intercept 28%, poke 12%, bobble 11%, goalie 4%, steal 0% | 48% / 52%, 63% | 2.6 | 2.7 |
| pro_regular | before | 0.8 s | 0.9 / 84% | 4.4 / 22% | 22.8: poke 68%, intercept 17%, check 14%, goalie 1% | 17% / 83%, 70% | 2.4 | 4.3 |
| pro_regular | after | 3.2 s | 1.2 / 66% | 2.6 / 49% | 7.9: check 54%, intercept 18%, poke 17%, bobble 7%, goalie 4% | 37% / 63%, 66% | 3.0 | 4.2 |
| allstar_sharp | before | 0.8 s | 0.8 / 79% | 4.8 / 20% | 19.0: poke 59%, intercept 23%, check 15%, goalie 3% | 23% / 77%, 75% | 2.8 | 4.9 |
| allstar_sharp | after | 3.5 s | 1.3 / 72% | 2.3 / 45% | 7.9: check 54%, poke 19%, intercept 13%, bobble 9%, goalie 5% | 41% / 59%, 62% | 3.4 | 3.7 |
| pro_perfect | before | 0.8 s | 0.5 / 65% | 6.0 / 14% | 25.1: poke 61%, intercept 24%, check 11%, goalie 4% | 35% / 65%, 76% | 3.0 | 3.6 |
| pro_perfect | after | 3.0 s | 1.2 / 75% | 3.0 / 31% | 7.7: check 43%, intercept 27%, poke 11%, goalie 11%, bobble 9% | 49% / 51%, 69% | 3.1 | 3.6 |
| rookie_idle | before | 0.4 s | 0.5 / 53% | 0.9 / 19% | 31.5: poke 62%, intercept 23%, check 15%, goalie 0% | 37% / 63%, 21% | 0.2 | 5.7 |
| rookie_idle | after | 4.1 s | 1.7 / 54% | 0.8 / 68% | 7.8: check 43%, poke 25%, intercept 24%, bobble 8%, goalie 1% | 68% / 32%, 54% | 1.1 | 2.1 |
| ai_pro | before | 0.5 s | 0.3 / 85% | 5.2 / 10% | 27.1: poke 54%, check 40%, intercept 5%, goalie 1% | 43% / 57%, 42% | 2.9 | 8.1 |
| ai_pro | after | 3.5 s | 1.8 / 61% | 2.2 / 67% | 8.1: check 57%, intercept 24%, bobble 10%, poke 6%, goalie 3% | 71% / 29%, 54% | 2.8 | 4.8 |

Inside the band after (the six cells above): bobble and self-loss shares (7-11 %, 0 %), the bots' slot or one-timer
share (red 55-68 % in every cell; the ladder's scripted hand shoots from 16 m, which pulls the blue and mixed shares
down), entries kept (54-69 %), shots per minute per team (2.2-3.0; idle 0.8), goals per match (2.6-3.4 in first-to-3
matches of 108 s; idle 1.1). Outside: **possession median 3.0-4.1 s against 4-10** (it was 0.4-0.8), **passes per
possession 1.2-1.8 against 1.5-3**, **completion 54-75 % against 70-85**, **checks 43-57 % of turnovers against at most
45**, and the OZ share where the sides are not even (the AI-only match 71 / 29: blue's mates read the play at 5 frames,
pro's red at 12). Possession and the check share pull against the owner's "keep the body-check rate": with the bots'
body checks held back 60 frames on a fresh carrier (night run t15) possession was 3.5-4.4 s and checks 37-44 % of
turnovers, but red's hits fell by a third. This table keeps the hits: red's stumbles and knockdowns a minute against a
person's hand are 2.7 / 4.2 / 3.7 at rookie / pro / all-star (21 Nov: 2.5 / 4.3 / 4.9). The dial is `ai.json`
`fresh_check_frames` (15).

**The ladder** (same runs; wins of 20, the human side through `TLHand`; 16 Nov bands in brackets): rookie newcomer
15 (80-90 %), regular 19, sharp 19, perfect 20, idle 0; pro newcomer 6, regular 14 (45-55 %), sharp 14, perfect 19,
idle 0; all-star newcomer 0, regular 3, sharp 7 (20-30 %), perfect 17, idle 0. Nobody has played this with his own
hands yet: every figure is a scripted hand.

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
| **Goalies** | One per side, white pads, a bigger figure (body scale 2.4). He stands on the line from his goal's centre to the puck as he saw it `reaction_frames` ago. His target depth increases linearly from 1 m at 6 m or closer to 2 m at 20 m or farther. He stays within 1.4 m of the middle and moves at up to 4 m/s and faces the puck. **Saves:** a puck shot at his net whose path passes within `glove` (0.9 m) is caught; a goalie on the move (faster than 1.2 m/s) reaches only 0.6 of that. A carrier who brings the puck within `poke` (2.2 m) of him loses it to a poke check. His body stops the rest, which gives a rebound. He holds a caught puck 40 frames, then passes to the mate with the most room, and to you when you have it. He passes only to a mate at least 8 m up ice; with nobody there he clears the puck up the middle. He covers a mate's puck at his own goal mouth. A puck a goalie holds is never a goal. These three came from own goals that won matches for an idle hand. Nobody checks him or pokes his puck. **Beaten by:** a shot to the far side from an angle; a one-timer after a pass across, while he is still moving; a shot outside his glove; a rebound. The level changes the red goalie only. | `scripts/keeper.gd`, tuning `goalie`, levels `goalie` | the mode key `"goalies": false` (pond hockey has none) |
| **Shots go at the cursor** | With the mouse on the ice a shot leaves the blade at the point under the cursor. This applies when that point is at least 4 m away and in front of the stick. Before, the shot flew parallel to the stick from the blade, 1.24 m right of the cursor. | `scripts/rink_api.gd` `shot_dir` | none (the old way was a bug a goalie made visible) |
| **Your mates set you up** | When you are open ahead of a mate who carries, he passes to you in `feed_share` of his carries by level (0.6 / 0.4 / 0.2). Otherwise your mates play: they shoot and carry it in themselves (H2, 23 Nov: the 240-frame shooting ban and the 8 m hold are gone; the idle hand may win rookie again, which the ladder reports and does not tune back). An open supporting mate signals with a light ring. | `scripts/ai/carrier.gd` | `feed_share` 0 |
| **One-timer** | Press shoot up to eight frames before receiving a pass or six frames after taking a teammate’s pass. The shot fires four frames after the take, or immediately on a later press, at 1.2× wrist speed (28.8 m/s by default). | `scripts/rink_api.gd`, `scripts/carry.gd`, tuning `shoot.one_timer_before`, `one_timer_after`, `one_timer_release`, `one_timer_scale` | Shoot after the reception window for an ordinary shot. |
| **Nobody swarms a goalie (L5b)** | While a goalie holds the puck, the other side's skaters wait 10 m out (`ai.json` `goalie_gap`), each in his lane; nobody may check or poke him anyway. The clips showed five figures round a goalie with the puck. | `scripts/ai/brain.gd` | `goalie_gap` 0 |
| **A save is an event** | When a goalie catches a shot (8 m/s or more), the card shows "SAVE!  VLAD" for 45 frames, with a small shake, snow at the glove and the glove's thump. | `scripts/fun/fun.gd` `_save`, `scripts/fx/fx.gd` | `fun.shake` false (the card stays) |
| **The goalie's figure (L5b)** | His own biped step is off (the pack places him), so his figure is ticked by the fun layer. It holds a stance, and on a caught shot it stabs (the pass clip) and squashes. | `scripts/fun/fun.gd` `_tick_goalie_rigs` | - |
| **AI shoots at corners** | The red and blue AI shoots at the far side from the goalie (`ai.json` `corner_z` 1.5), with the level's spread. | `scripts/ai/carrier.gd` | `corner_z` 0 |
| **Goal moment** | The pause after a goal (2 s) holds the net for 24 frames. It then replays the shot in slow motion: the bodies' recorded places, interpolated, from 10 frames before the shot, at 1.5x to 3x slower to fit the pause. The goal card stays over it: "GOAL!  LEO", "BLUE 2 : 1 RED", then "REPLAY". The face-off follows as before, with the camera cut there. The replay moves only bodies the pause already holds. The face-off then places everybody, so the next live frame is as it was without the replay. | `scripts/fun/fun.gd`, tuning `fun.hold_frames` .. `slow_max` | `fun.replay` false |
| **Match-end card** | It shows the result and the score ("YOU WIN   3 : 1"), the best moment and "R: rematch \| Esc: leave". The best moment is the hardest check of the match ("LEO flattened IGOR at 9.3 m/s"), else the longest goal ("YOU scored from 14 m"). The winning goal's replay runs under it. | `scripts/fun/fun.gd` `card` | - |
| **Names** | Every skater has a name on the cards: YOU, LEO, MAX against BRUNO, IGOR, OTTO; KUBA and VLAD in goal. | tuning `look.names` | - |
| **First minute** | A person's session starts with a drill that is playable at once: skate to the ring (W A S D), take LEO's pass, pass it back (Q), take it again and shoot into the empty net (click). The match then starts at the default level and mode; R after a match opens the panel. Each step is one line on the screen: a key and a few words. **Enter** skips it. The drill's goal is no score. | `scripts/intro.gd`, tuning `intro`, drill `intro` | **Enter** |

## Contact and skating (thirdjam port)

The simulation runs at 60 physics frames per second. The skater rig is drawn at 2.2×. Its contact scale of 2.93 gives a 0.879 m radius at the shoulders and back. Goalies are drawn at 2.4× and use the same ratio for a 0.959 m radius. Each numbered rule gives its thirdjam source.

1. **Carry and dangle.** The blade is 24.1° to the skater’s right at half reach, or at full reach along his aim. Full aim puts it 1.98 m away at cruise and 2.64 m at sprint. A critically damped spring follows that point. The puck swings up to 0.82 m outward as his velocity turns. Six consecutive sprint frames above 90% of that displacement shed the puck, with a 20-frame recovery lock. At the boards the spring uses an inside point.
2. **Reverse and first step.** Input over 0.05 more than 120° against velocity cuts up to 26 m/s² times input strength and suspends thrust while the skater turns. Above 1 m/s, entering the stop throws ice spray and requests the skate-stop clip. Below 0.5 m/s he can pivot in place. His own brake below 2 m/s, a cut over 60° in ten frames, or six frames resting below 1 m/s earns 20 frames at 1.8× acceleration. A rested skater can drift below 3 m/s and keep the first push. Downed or stumbling skaters cannot earn a cut. Field bots use the same rules. `JamSim.cpp:1302–1335,1378–1412,1430–1452`, `JamCartridge.h:90–125`, `JamSim.h:499–504`.
3. **Body contact.** F winds up 12 frames (L4b, 21 Nov: thirdjam `CheckWindupFrames` 8, here the body_check clip's hit frame 12; `JamSim.cpp:1968-2177`): the human is drawn up to 1.0 m toward the man he pressed at (`check_pull_m`), so the bodies meet as the wind-up ends and the hit lands on the frame the clip shows it; a meeting inside the wind-up is the hit, resolved before the bodies touch. Bots press when their man will be in reach as the wind-up ends. Then it opens a 12-frame window (six for a bot) within a 0.43 m surface gap and a 60° cone (2.188 m between the two skater centres). A hit costs 40 frames of recovery and a miss costs 20. Only a skater off puck can hit. Goalies are shielded. Impulse is attacker mass times the sum of closing speed and push, floored at zero. A body check adds 1.5 m/s of push. Within 1.5 m of the rounded boards an outward hit gains up to 25% on the victim. Stability begins at mass × 6. Below 1 m/s the visible front brace is 1.5× and a free skater's side brace rises to 5×. Moving stability falls to 0.85× at top speed. Sprint, full shot charge, and an unseen hit multiply it by 0.7, 0.8, and 0.8 respectively. A held cross-check meeting a faster opponent also multiplies it by 0.75. `JamSim.cpp:2523–2601`, `JamCartridge.h:386–405,526`, `JamSim.h:510–514,750–758,788`.

   Divide impulse by stability. Below 0.4 gives a bump. From 0.4 a stumble halves the victim's speed, and from 0.7 it frees the puck. From 1.0 the victim goes down for 60 frames, rising to 150 at ratio 3. Loose velocity combines half the victim's current velocity, a seeded 1 m/s scatter and 1 m/s back toward the hitter. A renewed stumble caps at bump. For 120 frames after getting up, the skater takes bumps and bots decline to initiate a check on him. On a stumble or fall the hitter gives half his lunge (cross-check uses positive closing plus thrust), with mass setting the victim's speed change. Body checks exchange remaining closing velocity at restitution 0.2, counting standing brace as effective mass. A less stable attacker whose free impulse reaches his own stability recoils to half speed if the victim stays up. `JamSim.cpp:2603–2784`, `JamCartridge.h:396–405,533–537`.
4. **Cross-check.** A tap winds up for eight frames, 12 for bots. The aimed opponent has priority within a 0.88 m surface gap and 70° (2.638 m between the two skater centres), then a miss stays live ten frames. Cross-check recovery is 45 frames, independent of body-check recovery. Thrust is 3 m/s. Into the back (direction dot facing above 0.5), it scales by closing speed up to 3 m/s. A front cross to the chest bypasses the standing brace. A human rear tap on a carrier, including one who carried in the last 12 frames, stumbles him. Other rear taps cap at bump. A stick lift on a carrier strips toward the hitter when the hitter’s steal lock and the carrier’s new-owner immunity have expired. A physical fall or sufficiently hard stumble can still dislodge it. A chaser can tap when a body check is unavailable or too slow. The closing threshold for the cross is above 0 m/s in Classic, 2 on Rookie, 1 on Pro and 0.25 on All-star. `JamSim.cpp:1742–1845,2559–2570,2596–2601`, `JamCartridge.h:165,171,461–488`.

   Holding for ten frames puts the shaft across the body. The first opponent within both body radii plus 0.2 m takes one momentum hit. Release rearms the hold. The held skater has 90% top speed, 70% turn rate and cannot sprint. The cross-check clip plays at wind-up and refreshes every 20 frames while braced, with the shoot clip as fallback. Body checks request the body-check clip. `JamSim.cpp:1946–1972,2350–2356`, `JamSim.h:750–758`.
5. **Sprint and stamina.** Free skaters cruise at 9.2 m/s and sprint at 10.58 m/s. A carrier gets 88% of those speeds (8.10 and 9.31 m/s) and 80% of free thrust (11.96 versus 14.95 m/s² at cruise). Free turn rate is 4.5 rad/s, multiplied by 0.85 when carrying and 0.67 while sprinting. The skate dial scales the base speed. Each sprint frame spends 360 of 64,800 ticks and each recovery frame returns 180, emptying in 180 frames and filling in 360. Sprint can resume once stamina is positive. The bottom-centre bar shows the human's stamina in ten steps. The match AI never requests sprint. `JamSim.cpp:1266–1300,1338–1346`, `JamCartridge.h:67,70,80–85`, `JamSim.h:505`.
6. **Flat shot on release.** A one- to four-frame hold fires the 24 m/s wrist shot. Longer holds add 8 × held frames / 30 m/s, capped at 30 frames (28 m/s at half charge, 32 m/s at full charge). Losing possession cancels the charge. A fresh press in the reception window arms the one-timer described above.
7. **The goalie holds it on the ice side.** A goalie carries a caught puck on the side of his body away from his own net (L4 director, 21 Nov: his outlet pass left from a blade inside the net, and the idle hand won rookie seed 6 by it). `JamSim.cpp:2786–2809,2811–2895`, `JamCartridge.h:73,320–321,340`.
8. **Nobody stands in a man who is down** (L4b; thirdjam `DownedRadiusM`, `JamCartridge.h:416-422`). A lying man is the segment from his feet 3.1 m along his facing (`hits.lying_length`, measured on the fall clip; TLHit.down v1 falls forward, so this follows the falls experiment's direction when it lands), 0.6 m thick (`hits.downed_radius`); a man who fell onto the hitter's line pushes him out to one side; a skater on his feet is moved out of it (at most 0.3 m a frame) and the speed he had into it is taken off, so he goes round. tests/bot_downed.gd.

## What the game is (16 Nov)

- **Possession and passing.** The puck is loose, carried, passing or shot. A pass leaves at 18 m/s, or 23 m/s beyond 15 m. An intended receiver has 0.6 m extra reach within 100° of facing, takes a pass below 28 m/s relative and bobbles a harder reception. Close to his blade the pass bends toward it. A deflection ends the pass. A carrier behind his own net still loses protection after 1.5 s and the puck is moved out after 3 s.
- **Pokes.** E starts a 24-frame action with a 40-frame cooldown. Frames 6–12 can hit within 2.3 m and 35° of the stick. Against a straight carrier the chance is 65% from the front, 45.5% from the side and 26% from behind. A recent cut multiplies these by 0.6. A whiff halves the poker’s turn rate for 15 frames. On a turnover the new carrier has 24 frames of poke immunity, and the bots give any fresh carrier 60 frames before a stick (poke, cross-check) and 15 before a body check. The former owner and nearby opponents have a 30-frame steal lock.
- **A puck inside a goal volume counts**, carried, released or lying there; inside your own net it is an own goal.
- **Five modes** as data files (`data/modes/*.json`), **three periods**, **the rule dial** (skate speed, shot speed,
  ice grip, bot sharpness; one step a period, for both teams).
- **Face-offs are won, not given**: at the start of a match, of each period and after each goal the puck drops up to
  0.4 m off centre and the two centre men stand 3.0 m from the centre, at least 2.4 m from it, outside the 1.45 m reach:
  nobody owns it at the drop; whoever skates to it first takes it. Measured on 20 seeds (the opening face-off): nobody
  owned it at the first live frame in 60 of 60 runs; doing nothing, the human was never first to it; skating straight at
  it he took it 20 of 20 against rookie and 12 of 20 against all-star.
- **Three levels** of opponents (`data/levels/*.json`; red only): rookie reacts after 18 frames at 55 % of your speed,
  pro after 12 at 79.5 %, and all-star after 7 at 83 %. Their aim spread is 6, 4 and 2.5 degrees respectively.
  Classic and your mates react after 5 frames with a 1.5-degree spread. Every 15 frames, or when the play changes, the carrier
  weighs a shot, passes, skating into space, protecting the puck and dumping it. Teammates fill support and safety
  positions on attack. On defence they pressure the puck, block a passing lane and guard the slot.

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
| bot_metrics_ai (N3) | the AI on all six skaters at pro (autopilot), played to the end: the five metrics of the game itself (tests/metrics.gd) |
| bot_own_net (N3) | no bot pass toward its own net or corner; a red pass sliding into red's mouth and a slow loose puck are the goalies'; the pinch guard holds an undeclared 27 m/s jump to 14 m/s and keeps a declared one |
| bot_ai_play | a full Pro autopilot match measures passes, receptions, shots, slot shots and the six roles. A second match checks the pass-call ring under human control. |
| bot_match | bot-only play until both sides have scored (from 6,000 frames, at most 18,000; L5: a fixed 6,000 before goalies, red's first goal now comes at up to 12,267 frames on seeds 1..20): both sides score; no skater outside the rink |
| bot_sprint | free and carrier speed, every drain/refill tick, and a defender landing a body check from six metres behind a sprinting carrier on open ice |
| bot_charge | one-, four-, five-, 15-, 30- and 40-frame holds, a one-timer, and loss, reacquisition and re-press after an opponent’s poke |
| bot_carry_turn | both stick sweeps through a skating turn, uninterrupted possession, normal and sprint reach, outward dangle and settling |
| bot_poke | 40 pokes each from in front, behind and after a cut, plus frame-by-frame recovery and turnover locks |
| bot_dangle | cruise, hard sprint cut and straight sprint on open ice |
| bot_reception | clean, assisted and bobbled receptions, recovery, and shoot presses before arrival |
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
| bot_fun (L5) | a hard check (10.58 m/s on round-3 seed 1) stops the game: every skater still and the clock held for the stop's frames; a 2 m/s bump has no stop; a goal is replayed in the pause, then the face-off; L5b: a shot straight off a pass is a one-timer (28.8 m/s), a tap after carrying for 16 frames is ordinary (24 m/s) |
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
- ~~The bots pass rarely~~ N3 (22 Nov): the bots pass 1.2-1.8 times a possession and shoot from the slot; see the N3
  section for the metrics still outside their bands (possession length, completion, the check share).
- N3, judged from window clips (not by hand): the bots still bunch round the puck in scrums of four or five; figures
  overlap in contact (the kernel's opt-in `TLHit.pushbox` is not used: it would move every hash); in a hard turn the
  drawn stick can point away from the puck for a few frames; a self-loss is visible only briefly before play goes on.
