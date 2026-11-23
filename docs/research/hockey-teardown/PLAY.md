# What thirdjam's play is made of: tempo, mechanics, skill (lane K4, night of 23-24 Nov 2026)

thirdjam is the hockey game the owner knows. Its simulation and its bots now run inside our engine unchanged (lane K1: its
traces equal the Unreal build's line for line). This page measures that running game: how fast it is, which skill moves
matter, how much skill shows, and where it is weak. It is the floor every later change is held to. Nothing here was tuned.

## How it was measured (read this once)

- **Source.** thirdjam HEAD 8dc713c6 (the game the owner played). `S/` below is its `Game/Source/`. Our copy
  `engine/cores/rink/native/thirdjam/` is byte for byte the same file (checked with `cmp`), so every `file:line` holds for both.
- **Instrument.** `rinklab.exe` (`engine/cores/rink/lab/`, built by `bash engine/tools/rink.sh lab-build`). It compiles
  thirdjam's JamCore unchanged and adds only code around it: an input filter on the human's slot, read-only counters, and
  scripted gym scenes. With an empty filter it plays the shipped game: 60 of 60 playtest lines equal `rinkcli` (HEAD), hash for
  hash; re-running the 12 ladder cells gave 2,400 of 2,400 equal match hashes, and four of them a third time 800 of 800.
  About 37,000 matches in all (6 processes, about 2 hours).
- **Hands.** thirdjam's own human-like playtester (`S/JamCore/AI/JamPlaytester.cpp`): **novice** (reacts 12 frames late,
  aims 10 degrees off, stops pressing for half a second every 10 s), **regular** (6 frames, 5 degrees), **good** (3 frames,
  2 degrees), and **idle** (no input at all). It plays through the same input struct the keys fill (`FJamInput`), sees only
  the world a player sees, and every hand presses sprint (`-playersprint`; the novice's profile never sprints).
  These hands are thirdjam's measuring sticks, not people. A figure is a statement about a hand, never about the owner.
- **Matches.** `hockey.regular` (90 x 45 m, 5 v 5, first to 3 goals, a 10 minute hard stop), levels rookie / pro / all_star,
  **200 seeds a cell** (seeds 1-200), the same seeds in every cell, so an ablation is compared match for match with the full
  hand. "a minute" = a minute of live play (the puck in play, pauses and faceoffs excluded).
- **Units.** Time in frames (60 a second; seconds in brackets). Distance in metres, in body widths (bw = 0.80 m, the
  skater's diameter, `S/JamCore/Public/JamSim.h:494`) or in rink lengths (90 m).
- **Gym.** Scripted scenes on the same simulation (2 v 2 cut of the same cartridge, every number as shipped, no brain;
  `engine/cores/rink/lab/lab_gym.cpp`). Raw probe lines: `media/play_gym.jsonl`.
- Raw match output stays under `.tl/` and was deleted once the tables existed; the tables are `media/play_*.json`.

## 1. The tempo map

All from the gym (`rinklab gym`) unless the row says "matches". Free = a skater without the puck.

| What | Measured | In the player's units | Source of the rule |
|---|---|---|---|
| Free skater, top speed | 12.65 m/s | 15.8 bw a second; one rink in 427 f (7.1 s) at speed | skater.speed 11 x free_speed_mult 1.15, `JamSim.cpp:1336-1337`, `JamCartridge.h:70` |
| ... from a standing start | 95 % of top after 36 f; 10 m in 64 f, 30 m in 159 f, 60 m in 301 f | a third of the rink in 2.65 s | first-step burst x1.8 accel for 20 f, `JamSim.cpp:1300-1329`, `JamCartridge.h:93-94` |
| Sprint (held) | 14.55 m/s; 30 m from rest in 140 f | +15 %; one rink in 6.2 s | `JamSim.cpp:1285-1298`, `JamCartridge.h:80` |
| Sprint bar | empties in 180 f (3.0 s), refills in 359 f (6.0 s); a spin costs 25 % of it | 3 s of sprint, then 6 s to recharge | `JamSim.cpp:1289-1290`, `JamCartridge.h:81-82`, spin `JamSim.cpp:1608` |
| Speed after the bar is empty | 14.54 m/s still 60 f later; a glide loses only 0.15 m/s a second | a sprint's speed outlives the bar by many seconds on a straight line | no thrust above top, only glide drag 0.147 m/s², `JamSim.cpp:1426-1430` |
| Puck carrier, top speed | 10.12 m/s (carry_sprint 10.93) | 0.80 of a free skater (0.86 sprinting) | carry_speed_mult 0.92, `JamSim.cpp:1284`; sprint cap `JamSim.cpp:1293-1298`, `JamSim.h:505` |
| Breakaway burst (carrier past the last defender, past centre, 30 f of carry) | 13.15 m/s for 60 f | the only time a carrier outruns a free skater | `JamSim.cpp:2946-2992`, `JamCartridge.h:76-77` |
| Bots' speed ceiling | a bot may send a stick 1.5 long: 18.97 m/s in the gym | 1.5 x the human's top | `JamSim.cpp:1379-1384` |
| Bots' speed in matches (mean while the puck is live) | opponents 8.3 (rookie), 9.6 (pro), 11.0 m/s (all_star); the human 9.4-9.7 at every level | all_star's opponents skate 15 % faster than the human on average | matches, ladder cells (section 3) |
| Stop by reversing the stick | from 12.65 m/s: 29 f, 3.0 m | 3.7 bw | reverse_brake_decel 26 m/s², `JamSim.cpp:1397-1418`, `JamCartridge.h:90` |
| Stop with the puck | from 10.12 m/s: 23 f, 1.9 m, puck kept 42 of 42 frames | 2.4 bw | the same rule |
| Stop button | 119 f, 12.9 m | 16 bw: a third of the rink width | brake_decel 6 m/s², `JamSim.cpp:1430-1433` |
| Turn 90 degrees at full speed | 50 f, speed kept (12.83 m/s) | | turn_rate 5 rad/s, lateral_grip 3 |
| About-turn (to 5 m/s the other way) | 43 f | | reverse brake, then the burst |
| Chaser (free) on a carrier, both at cruise | closes at 2.53 m/s: a 5 m gap to stick range (2 m) in 76 f, to the body in 103 f; 10 m: 194 f / 222 f (the carrier runs 38 m) | 3.2 bw a second | top speeds above |
| ... a 20 m gap | not closed in 44 m of rink (measured); 427 f and 72 m by the closing speed | a 20 m lead is safe for 0.8 of a rink length | |
| ... the chaser sprints | 5 m: 44 f; 10 m: 113 f; 20 m: 248 f to stick range | sprinting halves the chase | |
| ... the carrier sprints | 5 m: 105 f; 10 m: 279 f | | |
| Body check, head on (closing 22.9 m/s) | lands (always a knockdown) when pressed 0 to 19 f before contact: from 8.5 m to 1.5 m out | a 20 frame window: 8 of wind-up and 12 of window | `JamSim.cpp:1118-1146`, `JamCartridge.h:461`, `JamSim.h:514` |
| Body check from behind (closing 2.5 m/s) | lands (a stumble, never a fall) when pressed 2 to 19 f before contact: 2.75 m to 1.0 m | | |
| Cross-check / lift, head on | lands when pressed 0 to 7 f before contact: 4.5 m to 1.0 m | an 8 frame window | `JamSim.cpp:1729-1739`, `1847-1941`, `JamCartridge.h:462` |
| ... from behind | 2.5 m to 1.0 m (a stumble) | | |
| Poke, head on | clean when pressed 2 to 12 f before contact: 6 m to 2 m | an 11 frame window | `JamSim.cpp:1648-1727`, `JamCartridge.h:159-161` |
| ... from behind | never clean (0 of 19) | the carrier's body is between | body shield, `JamSim.cpp:1570-1582` |
| No button at all, head on | the attacker ends with the puck in 20 of 20 trials | skating into an oncoming carrier takes his puck | the puck meets the body (pickup) |
| Pass, a tap | 5 m: 9 f; 15 m: 63 f (1.05 s); 30 m: 112 f (1.9 s); it leaves at 13.9-22 m/s and arrives at about 8.6 | the tap is solved to arrive at 8 m/s | `JamSim.cpp:3095-3130`, `3187-3240`, `JamCartridge.h:363-365` |
| Pass, held 30 f (full power) | 23.1 m/s: 5 m in 4 f, 15 m in 34 f, 30 m in 102 f, plus the 30 f hold | | `JamSim.cpp:3061-3081`, `3232-3240` |
| A defender stepping into the lane, from rest | 1 m in 17 f, 2 m in 24 f, 3 m in 30 f, 10 m in 64 f | a 15 m tap can be cut by anyone within 10 m of its line who starts at once; the bots react in 0 frames at every level | `JamAICore.h:495` (ReactionFrames 0, pro's default), `DifficultyProfile.cpp:38,91` (rookie, all_star) |
| Shot, a tap | 35.7 m/s: 10 m in 17 f, 20 m in 55 f | | shot.speed 18 x speed_scale 2, `JamSim.cpp:2848`, `JamCartridge.h:314,343` |
| Shot, full charge (30 f hold) | 51.6 m/s: 10 m in 11 f, 20 m in 34 f; lifted 0.49 m | the hold costs 30 f, in which a defender at speed covers 6.3 m | `JamSim.cpp:2786-2809`, `JamCartridge.h:320-321` |
| A shot against a reaction | the hands react in 3 / 6 / 12 f; the goalie read waits 21 f (0.35 s) | a charged shot from 10 m is in before the goalie reads it | `JamSim.h:542`, `JamPlaytester.cpp:52,71,93` |
| A carry (matches, regular hand, pro) | 0.82 s; 16 carries a minute; 39 % end with an opponent carrying, 32 % in a pass, 18 % in a shot | | ladder cell pro.regular |
| A possession (matches, pro) | 2.35 s; the puck changes teams 27 times a minute; it is loose 34 % of live time | | ladder cell pro.regular |
| Between events (matches, pro) | 1.4 s between a shot, a landed hit, a goal or a change of possession; a 10 s stretch with none 0.3 times a match | | ladder cell pro.regular |
| Decisions a minute (presses, matches, pro) | novice 26, regular 56, good 70 (plus 17-21 reverse-brake stops) | about one press a second for the regular hand | ladder cells |

What the table says, in short:
- **The game is fast and twitchy, not flowing.** A possession lasts 2.4 s and a carry under a second. The puck is loose a
  third of the time. Nothing lasts long enough for a plan.
- **Speed is a ladder of four steps:** carrier 10.1 < free skater 12.65 < breakaway 13.15 < sprint 14.55. A defender is
  always faster than the carrier (by design, `JamSim.cpp:1278-1282`), so the carrier's defence is his stick and his stop,
  not his feet.
- **Stops are near instant** (3 m from full speed). Turning is slow by comparison (50 f for 90 degrees).
- **A hit forgives timing head on** (a 20 frame window, a sure knockdown) and **the poke never works from behind.**

## 2. The mechanic matrix

### 2a. Each verb as the source writes it

Every line is thirdjam's rule (`S/JamCore/Private/JamSim.cpp` unless named; numbers from `hockey.regular` and the defaults in
`S/JamCore/Public/JamCartridge.h`). "How the hand uses it" is the playtester's own rule (`S/JamCore/AI/JamPlaytester.cpp`).

| Verb (key) | Cost | Reward | Window | What beats it | How the hand uses it |
|---|---|---|---|---|---|
| Skate (`Move`) | none; a carrier is 0.92x (`:1284`) | free 12.65 m/s, carrier 10.12 | always | a faster skater; bots may push the stick to 1.5 (`:1383`) | everywhere |
| Sprint (`bSprint`, held) | the bar: 180 f of sprint, 359 f to refill (`:1289-1290`); a sprinter is 0.7x as stable in a hit (`:2552`); a sprinting carrier's sweep shield is halved (`:1528-1533`) and his puck rides at full stick length (`:1496`) | +15 % top speed and thrust; a carrier +8 % (`:1285`, cap `:1296`) | while the bar lasts | the bar; a hit (lower stability) | regular 50 %, good 100 % of the chances: on a breakaway or a chase of a far loose puck, and the carrier on an open lane (`JamPlaytester.cpp:794-803`) |
| Stop by reversing the stick (no key) | the speed (from 12.65 to 0 in 29 f) | a 3 m stop; it earns the first-step burst x1.8 accel for 20 f (`:1439-1443`, `:1300-1329`) | instant | nothing: no answer in the rules | regular and good stop-and-go; the novice only to stop on a target behind it (`JamPlaytester.h` BrakeIntent) |
| Brake (`bBrake`, held) | slow (119 f, 12.9 m) | sideways grip (`:1430-1433`) | held | | **never pressed** by any hand (0 presses in 2,400 matches) |
| Deke (`bDeke`) | a 30 f lockout (`JamSim.h:548`) | the puck 1 m to the blade side over 6 f; the crease back commits to the old side for 15 f and a shot then aims at the open post (`:2919-2944`, `:2836-2839`); a one-tap sweep shield | the 15 f commit | a poke on the new side after the shield (12 f); a body check | 50 % (regular) / 100 % (good) of the chances near the net; the novice never |
| Spin (`bSpin`) | 25 % of the sprint bar, 90 f cooldown, speed capped at 0.7x for 24 f (`:1600-1623`, `:1635-1646`); a check mid-spin fells 1.5x as long (`:2771-2772`); 0.8x stability (`:2553`) | the puck on the far side of the body: no poke or lift takes it (`:1550`) | 19 of its 24 f (the last 5 are exposed, `JamCartridge.h:144`) | a body check (bodies are never shielded); the exposed tail | when a defender closes from behind at speed (regular, good) |
| Shield / sweep (the stick's aim while carrying) | none | a sweep (the blade crossing > 6 deg a frame) shields the puck from pokes and lifts for 12 f (`:1500-1543`); the body between needs no key (`:1570-1582`) | 12 f a sweep (6 f sprinting) | a body check; a poke from the front | carries on the far side of a defender within 2.5 m in front (regular, good) |
| Stick aim (`Stick`) | none | where the blade is: pokes, receptions, which mate a pass goes to (`:1478-1497`, `:3213-3221`) | always | | aims at the puck or the target |
| Pass (`bPass` tap, `bPassHeld` power) | 12 f cooldown (`JamSim.h:529`); a hold of up to 30 f for full power | a tap is solved to arrive at 8 m/s; full power 23 m/s reaches a third of the rink (`:3224-3240`, `JamCartridge.h:363-365`) | the flight (63 f over 15 m for a tap) | an opponent's blade within 1 m of its path takes it (`:3581-3593`); bots react in 0 f (`JamAICore.h:495`) | when a mate is 5 m (regular) / 3 m (good) / 8 m (novice) nearer the net, open, and a defender closes |
| Saucer (the held pass, sim's choice) | the hold (8 f) | lifted 0.35 m over blades in the lane (`:3061-3081`, `:3130`) | | | the human's hold is power; the sim lifts it when it must |
| One-timer (a shot inside 10 f of a reception) | timing | full charge without the hold and +8 deg of aim help (`:2829-2833`) | 10 f after a pass lands (`JamCartridge.h:325`) | the pass has to reach him first: mates pass to the human in 0.4 of the chances at pro (`DifficultyProfile.cpp:19`) | 50 % / 100 % of the chances |
| Tap shot (`bShoot` or a hold of 4 f or less) | 24 f cooldown (`JamCartridge.h:315`); must face within 60 deg (`JamSim.h:509`) | 35.7 m/s on the ice, 8 deg of aim help to the goal centre (`:2846-2848`) | | a skater's body or blade in the line; the crease stance (`:4351-4357`, `:3771`) | deke shots and one-timers |
| Charged shot (`bShootHeld`, up to 30 f) | the hold (0.5 s for full); 0.8x stability while fully charged (`:2553`); the charge dies if the puck is lost (`:3088-3093`) | 51.6 m/s, lifted 0.45-0.5 m over the goalie's block height 0.4 (`:2786-2809`, `JamCartridge.h:134`) | release | a hit or a poke during the hold | from 14 / 20 / 26 m (novice / regular / good), released when lined up or after 24 / 40 / 60 f |
| Poke (`bPoke`) | 8 f window, 14 f to the next; a miss locks the stick for 20 f (human) or stumbles a bot for 20 f (`:1648-1727`, `JamCartridge.h:161,167,212`) | the puck, clean, within the stick's reach and 60 deg of the aim (human only, `:1662-1672`) | 8 f | the sweep, the spin, the body between, the 30 f take grace of a puck just won (`:1545-1563`) | regular and good poke only when it can land (`bPokeRead`); the novice whenever the puck is near; also the draw |
| Lift / cross-check (`bLift`) | 30 f cooldown (`:1732`) | a stick lift strips a carrier within 1.0 m and 70 deg (`:1852`, `:1900-1905`); its cross-check shoves the man after an 8 f wind-up (12 f for bots), thrust 3 m/s (`:1876-1891`, `JamCartridge.h:387,462,470`); the human's lands on any man in front (`:1915-1918`) | the wind-up, then 10 f live (`JamCartridge.h:484`) | the spin and the sweep refuse the stick; a back is not shoved from behind (`:1881`) | when an opposing carrier is within 2 x 0.4 + 0.9 m |
| Body check (`bCheck`) | 8 f wind-up, then a 12 f window (6 for bots); the carrier cannot check (`:1105-1146`, `:2523-2531`) | impulse against stability: a stumble from ratio 0.4, a knockdown of 60-150 f from 1.0 (`:2603-2764`, `JamCartridge.h:396-401`) | 20 f from the press | the 120 f release grace after a fall (`:2637-2644`); a braced or standing skater (`:2534-2570`); the attacker recoils when he is the less stable (`:2668`) | rarely: the hand prefers the cross-check (0.3 presses a minute against 9) |
| Brace (`bCrossHold`, held) | 0.9x speed and turn, no sprint, no poke or lift (`:1286-1287`, `:1155-1156`, `JamSim.h:756`); hit by a faster man it is exposed (`:2621`) | hits out of the brace (`:1946-1964`) | from 10 f of hold | | on a long run at an opposing carrier, closing at 6 m/s or more, 2.5-6 m out |
| Ability (`bAbility`) | | | | | **does nothing in `hockey.regular`**: the cartridge has no `game.abilities` (`JamCartridge.h:680`); 0 uses |
| Draw (any press at the faceoff) | moving early loses (`:786`) | the puck to the winner, who cannot be felled for 90 f (`:827`) | the first press after the drop; bots press 6-18 f after it (`:796-806`) | a quicker press | the regular hand presses 4 f after the drop plus its reaction |
| Signal to mates (HUD) | | the bots read the human's team intent: defend, space, pass, praise (`JamAICore.cpp:294-299`, `JamGame/Private/HokejGameMode.cpp:1319-1330`) | 600 f | | **never**: the playtester has no signal (it is not in `FJamInput`); measured by holding one all match (2d) |

### 2b. Measured by ablation

The regular and the good hand play the same 200 seeds with one verb taken away (`rinklab match -remove=<verb>`); each match
is compared with the same seed played by the full hand. A removed verb is a key the hand still "presses" but the game never
hears (the filter sits between the hand and the sim, `engine/cores/rink/lab/lab_filter.cpp`); the hand does not re-plan.
Two verbs are converted instead of cut: **charge** (the hold is dropped, its release becomes a tap shot on the same frame)
and **saucer** (the held pass becomes a tap pass). **stop** turns a reversed stick into a 115 degree carve (the
playtester's own carve). **shield** zeroes the stick's aim while he carries (the blade rests ahead at half reach) except on
a pass or a shot. **stick** zeroes the aim always. **draw** drops every press while the draw is open; every other ablation
leaves the faceoff alone. Numbers: wins in percentage points and goal difference, mean of (variant - full) over the 200
pairs; `*` = at least two standard errors from zero. R / P / A = rookie / pro / all_star. Full data:
`media/play_ablate.json` (every figure, every cell, with the paired differences).

| verb removed | regular R / P / A: wins pp | regular: goal diff | good R / P / A: wins pp | good: goal diff | presses lost a match (regular, pro) |
|---|---|---|---|---|---|
| sprint | 0 / -12* / -10* | -0.01 / -0.47* / -0.32 | 0 / -1 / -14* | 0.00 / -0.05 / -0.60* | 961 frames of sprint |
| brake | 0 / 0 / 0 | 0.00 / 0.00 / 0.00 | 0 / 0 / 0 | 0.00 / 0.00 / 0.00 | 0 (all 200 matches identical) |
| stop | -1 / -13* / 5 | -0.03 / -0.54* / 0.28 | 0 / -19* / -10* | -0.04 / -0.89* / -0.44* | 526 frames carved |
| deke | 0 / -2 / -4 | -0.03 / -0.09 / -0.18* | 0 / 3 / 2 | 0.01 / 0.02 / 0.09 | 1.4 (72 of 200 identical) |
| spin | -1 / -2 / 0 | -0.01 / -0.03 / 0.18 | 0 / 6 / 3 | 0.03 / 0.07 / 0.10 | 59 |
| shield | 0 / -14* / -5 | 0.06 / -0.57* / -0.04 | 0 / 11* / 11* | -0.01 / 0.41* / 0.48* | 1,306 frames of aim |
| stick (all aim) | -2 / -27* / -13* | -0.11 / -1.10* / -0.48* | -1 / -7 / -6 | -0.12* / -0.44* / -0.24 | 7,928 frames of aim |
| pass | 0 / +9* / +7 | +0.12* / +0.49* / +0.41* | 0 / +9* / +4 | +0.07 / +0.37* / +0.04 | 32 |
| saucer | -1 / -3 / -1 | -0.04 / -0.07 / -0.02 | 0 / -1 / -2 | 0.03 / -0.09 / -0.11 | 21 (37 of 200 identical) |
| onetimer | 0 / 1 / 2 | -0.01 / 0.03 / 0.03 | 0 / -1 / 0 | -0.02 / -0.03 / 0.00 | 3 (153 of 200 identical) |
| tap | -1 / -2 / -3 | -0.04 / -0.06 / -0.10 | 0 / 1 / -1 | -0.01 / -0.10 / -0.01 | 6 (123 of 200 identical) |
| charge | 0 / -9* / -8 | 0.00 / -0.38* / -0.21 | -1 / -3 / -13* | -0.01 / -0.23 / -0.57* | 201 |
| shoot (every shot) | 0 / -8* / -14* | +0.07* / -0.30* / -0.53* | 0 / -10* / -14* | 0.02 / -0.55* / -0.80* | 274 |
| poke | -1 / -8 / 2 | -0.04 / -0.30 / 0.15 | 0 / -1 / -3 | -0.04 / -0.07 / -0.08 | 184 |
| lift (and its cross-check) | -1 / -12* / -6 | -0.02 / -0.41* / -0.10 | 0 / 2 / -6 | -0.03 / 0.01 / -0.31 | 258 |
| check (body) | 0 / -3 / -6* | -0.01 / -0.14 / -0.26* | 0 / 1 / 3 | 0.00 / -0.04 / 0.07 | 0.9 (96 of 200 identical) |
| brace | 0 / -4 / -3 | -0.01 / -0.07 / -0.06 | 0 / -1 / 1 | 0.00 / -0.08 / 0.04 | 258 frames braced |
| ability | 0 / 0 / 0 | 0.00 / 0.00 / 0.00 | 0 / 0 / 0 | 0.00 / 0.00 / 0.00 | 0 (all 200 matches identical) |
| draw | 0 / 1 / 5 | 0.00 / 0.08 / 0.23 | 0 / +14* / +13* | -0.02 / +0.60* / +0.39 | (the draw press) |

What moved, regular hand at pro (per minute of live play; same pairing):

| verb removed | possession pp | goals for / min | goals against / min | the hand's shots / min | carries lost / min | knockdowns taken a match |
|---|---|---|---|---|---|---|
| sprint | -1.1 | -0.12 | 0.15 | -0.23 | -0.09 | -0.04 |
| stop | -1.0 | -0.22* | 0.10 | -0.36* | -0.23 | 0.40 |
| deke | -0.8* | -0.08 | 0.04 | -0.26* | 0.14 | -0.01 |
| spin | -0.5 | 0.02 | 0.11 | 0.24 | 0.07 | -0.58 |
| shield | -5.1* | -0.20 | 0.19 | -0.63* | +2.05* | -0.07 |
| stick | -5.7* | -0.51* | 0.33* | -1.08* | +1.56* | -0.21 |
| pass | -0.5 | +0.40* | -0.12 | +1.46* | 0.10 | +0.89* |
| saucer | -0.4 | -0.12 | 0.07 | 0.05 | -0.04 | -0.16 |
| onetimer | 0.3 | 0.02 | 0.01 | 0.04 | 0.03 | -0.07 |
| tap | -0.1 | -0.03 | 0.00 | -0.13* | 0.03 | -0.01 |
| charge | -0.6 | -0.17* | 0.09 | -0.08 | 0.14 | 0.51 |
| shoot | -0.5 | -0.20* | 0.07 | -3.20* | +1.13* | +1.10* |
| poke | -0.5 | -0.05 | 0.02 | -0.06 | -0.01 | 0.29 |
| lift | -2.7* | -0.13 | 0.11 | -0.54* | -0.88* | -0.33 |
| check | -0.5 | -0.12* | 0.01 | -0.13 | -0.09 | +0.60* |
| brake, ability | 0 | 0 | 0 | 0 | 0 | 0 |

### 2c. The reverse: skating plus one verb

The hand keeps skating, the stick's aim and the draw, plus the named verbs; everything else is cut (`-only=`). Pro and
all_star only: at rookie the idle hand already wins 60.5 % and both full hands 100 %. 200 seeds a cell; `media/play_only.json`.

| hand keeps | regular P / A | good P / A |
|---|---|---|
| nothing (idle) | 9.5 / 5.5 | 9.5 / 5.5 |
| skating only | 29.5 / 18 | 31.5 / 20.5 |
| shoot | 30.5 / 19.5 | 46 / 30.5 |
| pass | 28 / 16.5 | 40 / 31 |
| pass + shoot | 29 / 21.5 | 42.5 / 27 |
| check | 26 / 19 | 32.5 / 19 |
| lift | 37 / 22.5 | 47.5 / 27 |
| poke | 26 / 19 | 37 / 29.5 |
| lift + check + poke + brace | 42.5 / 21.5 | 53 / 35.5 |
| everything (full hand) | 75.5 / 39.5 | 76 / 53.5 |

- **No verb wins alone.** The best single verb (the lift, with its cross-check) reaches half of what the full hand wins;
  all four hits together 42.5 / 53 % at pro. The whole hand is far more than its parts: the game asks for the mix.
- **Skating alone is worth 20 points.** A hand with no button at all wins 29.5 % at pro (the idle hand 9.5) and scores
  0.94 goals a match: it carries the puck into the net (3.9 % of its carries end in a goal) and takes pucks by skating
  into carriers (the gym: 20 of 20 head on).
- **Shooting alone adds nothing for the regular hand** (30.5 against 29.5 for skating only); it adds 14.5 points for the
  good hand, whose aim is finer.

### 2d. The team signal (the verb the hand never uses)

thirdjam's player can signal his team-mates (HUD keys; `AHokejGameMode::GatherInputs` writes the active intent into the
brain's world, `JamGame/Private/HokejGameMode.cpp:1319-1330`; the brain reads it at `JamAICore.cpp:294-299`): **defend**
(mates other than the backs fall back 8 m in front of their net while the puck is in the attacking half, `:957-962`),
**space** (mates go to free ice 12 m ahead of the puck, `:964-975`), **pass** (a mate with the puck passes to the open human
in 0.9 of the chances instead of 0.4 at pro, and even the backs pass, `:1680-1690`), **praise**. The playtester never
signals. The lab holds one signal all match (`-signal=`, the brain's world as the HUD would fill it; 200 seeds, paired):

| signal held all match | hand | level | wins pp | goal diff | passes received a match |
|---|---|---|---|---|---|
| pass | regular | rookie / pro / all_star | 0 / -13* / -16* | 0.04 / -0.53* / -0.63* | -0.57* / -2.32* / -2.88* |
| pass | good | rookie / pro / all_star | 0 / +5 / -16* | -0.01 / 0.04 / -0.69* | -0.46* / -1.42* / -2.46* |
| defend | regular | pro | -21* | -0.86* | -1.36* |
| space | regular | pro | -74* | -3.56* | -5.18* |
| praise | regular | pro | -4 | 0.04 | 0.01 |

The signal is a real verb: it moves the game more than most keys. Held all match it always costs (space throws the
defence away: 2 % wins). Even "pass" makes the human receive fewer passes, not more; why is not traced here (the same signal
also lets the backs pass, `:1690`, which may lose the puck before it reaches him). How much a well-timed signal is worth needs a hand that signals at moments,
which thirdjam does not have (a later lane's arm).

### 2e. Verdict per verb

| Verdict | Verbs | Evidence (2b, 2c) |
|---|---|---|
| **Carries the game** (losing it costs both hands, at more than one level) | the stick's aim; the stop (reversing the stick); the sprint; the shot (charged above all) | stick -27 / -13 pp (regular P / A); stop -13 (regular P), -19 / -10 (good P / A); sprint -12 / -10 (regular), -14 (good A); shoot -8 to -14 everywhere it can show; charge -9 (regular P), -13 (good A) |
| **Matters for one hand only** | the lift and its cross-check (regular); the far-side carry (regular) | lift -12 (regular P), not significant for the good hand; shield -14 (regular P) but **+11 for the good hand** at P and A |
| **Hurts the hand that uses it** | the pass; the good hand's far-side carry; the good hand's draw | no pass: +9 pp (both hands, P), +0.41 goal difference (regular A); no far-side carry: +11 (good P and A); never taking the draw: +14 / +13 (good P / A) (section 4, item 5) |
| **Dead in play** (taking it away changes nothing measurable) | brake button, ability, one-timer, tap shot, saucer, deke, spin, brace, poke; the body check nearly (one cell) | every cell within two standard errors of zero except deke's goal difference at regular A (-0.18) and check at regular A (-6 pp); the brake button and the ability: all 1,200 matches identical (never pressed / no ability in `hockey.regular`) |
| **Wins alone** | none | the best single verb (lift) wins 37 / 47.5 % at pro against 75.5 / 76 for the full hand (2c) |
| **An answer nobody uses** | the brake button (the reversed stick stops in 29 f against its 119 f); the body check (the cross-check does the same job: 9 presses a minute against 0.3); the team signal (2d); the poke from behind (never works: the carrier's body is between, gym) | 2a, gym, ladder press counts |
| **No answer** | none found in the rules for the carry into an empty crease other than a body in the way: with no shot at all the regular hand still scores 1.85 goals a match at pro | section 4, item 1 |

## 3. The skill ladder

Four hands x three levels, 200 seeds a cell (seeds 1-200), `hockey.regular`, every hand presses sprint. "±" is one standard
error of the win share. First goal: the median frame of the hand's team's first goal, in seconds of match time, and the
share of matches in which it scored at all. Table: `media/play_ladder.json` (every figure of every cell).

| hand | level | wins % | loss % | goal diff | goals for / against a min | first goal for (median s; share of matches) | first goal against (s) | possession % | the hand's shots / min | opp shots / min | match (s) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| idle | rookie | 60.5 ±3.5 | 39.5 | 0.52 | 0.469 / 0.359 | 90.5 (93 %) | 84.6 | 42.2 | 0 | 3.66 | 297.5 |
| idle | pro | 9.5 ±2.1 | 90.5 | -1.87 | 0.332 / 0.982 | 65.7 (60.5 %) | 46.2 | 37.4 | 0 | 5.22 | 183.9 |
| idle | all_star | 5.5 ±1.6 | 94.5 | -2.22 | 0.3 / 1.265 | 49.6 (46 %) | 37.8 | 38.4 | 0 | 6.91 | 148.6 |
| novice | rookie | 97.5 ±1.1 | 2.5 | 2.55 | 1.397 / 0.196 | 31.1 (100 %) | 74.4 | 45.9 | 2.44 | 1.48 | 137.2 |
| novice | pro | 24.5 ±3 | 75.5 | -1.18 | 0.461 / 0.842 | 75.1 (72.5 %) | 39.4 | 38.5 | 0.89 | 3.66 | 198.2 |
| novice | all_star | 10.5 ±2.2 | 89.5 | -1.93 | 0.374 / 1.186 | 60.7 (54.5 %) | 35.5 | 38.2 | 0.59 | 6.34 | 153.6 |
| regular | rookie | 100 ±0 | 0 | 2.81 | 2.382 / 0.155 | 20.6 (100 %) | 48.6 | 58.3 | 4.96 | 1.13 | 84.7 |
| regular | pro | 75.5 ±3 | 24.5 | 1.05 | 1.116 / 0.657 | 39.8 (94 %) | 33.3 | 47 | 3.04 | 4.03 | 149.6 |
| regular | all_star | 39.5 ±3.5 | 60.5 | -0.53 | 0.792 / 1.029 | 43.5 (80.5 %) | 38.9 | 44.1 | 1.68 | 6.69 | 146 |
| good | rookie | 100 ±0 | 0 | 2.85 | 2.959 / 0.153 | 18.5 (100 %) | 43.6 | 62.5 | 7.87 | 0.95 | 69.9 |
| good | pro | 76 ±3 | 24 | 1.26 | 1.567 / 0.805 | 21.8 (95.5 %) | 31.7 | 54.5 | 4.5 | 4.1 | 110.9 |
| good | all_star | 53.5 ±3.5 | 46.5 | 0.23 | 1.125 / 1.003 | 26.7 (90.5 %) | 40.7 | 49.6 | 2.9 | 5.97 | 127.8 |

What it says:
- **Rookie is won without the player.** A human who stands still all match still wins 60.5 % of rookie matches: his four
  team-mates beat the five rookie opponents alone. Every hand that plays wins 97.5-100 %. At rookie skill does not show
  above the novice: the regular and the good hand both win every one of 200 matches (they differ only in speed of
  winning: 85 s against 70 s a match).
- **Pro is flat at the top.** idle 9.5, novice 24.5, regular 75.5, good 76.0 %. The step from idle to regular is 66 points;
  the step from regular to good is half a point (inside the noise: ±3). The good hand reacts twice as fast, aims more
  finely and uses every chance to sprint, deke and one-time, and wins no more matches. It wins them sooner (first goal at
  22 s against 40 s) and by a little more (goal difference 1.26 against 1.05).
- **All-star is the only level where skill shows from bottom to top:** 5.5, 10.5, 39.5, 53.5 %.
- **The levels are made harder mainly by speed.** The opponents' mean speed while the puck is live is 8.3 m/s at rookie,
  9.6 at pro and 11.0 at all_star; the human's stays 9.4-9.7 at every level (`media/play_ladder.json`, `bot_mean_mps`).
  The rookie opponents skate at 0.85 x 0.80 of the human's top speed (`DifficultyProfile.cpp:80`, `JamAICore.cpp:385`); the
  all_star ones at 1.15 x 0.9 (`DifficultyProfile.cpp:136`). Rookie bots are also clumsy by rule (they never lift, check
  only from 6 m/s of closing, poke 10 frames late: `DifficultyProfile.cpp:35-59`, `JamAICore.h:504`), but the idle figure says the level is
  mostly easy by the opponents being slow: a rookie match is decided before the player's hands come into it.
- **The steps are uneven by hand.** For the idle and the novice hand nearly the whole ladder is the step from rookie to pro
  (60.5 to 9.5; 97.5 to 24.5); for the good hand the two steps are equal (100, 76, 53.5).

## 4. What thirdjam is weak at

Ranked by how hard a player runs into it. Each with its evidence (cells are 200 seeds; "traced" lines name the command
that replays the match frame by frame). This is where the "surpass" step starts. Nothing was changed.

1. **You can score without shooting: carry the puck into the net.** A carry that crosses the goal line is a goal. With
   every shot taken away the regular hand still scores 1.84 goals a match at pro (2.02 with shots) and still wins 67.5 %
   (75.5); at rookie it scores more without shooting (2.73 against 2.42) and wins faster (70 s against 85 s). A hand with no
   button at all scores 0.94 a match at pro. In the full game a quarter of the hand's goals are walked in: 0.87 of 2.42 a
   match at rookie, 0.54 of 2.02 at pro, 0.29 of 1.27 at all_star (carries that end in a goal, `media/play_ladder.json`).
   Traced: rookie, regular hand, shots removed, seed 2, frames 498-548: the human carries from x = 29 m straight down the
   middle (y = 0) at 13.1 m/s (the breakaway burst) over the goal line; nobody is in the way
   (`rink.sh lab match -seeds=2-2 -difficulty=rookie -player=regular -playersprint -remove=shoot -trace=1`).
2. **Passing gives the puck away.** At pro the regular hand's passes reach a team-mate 38 % of the time (the good hand's
   46 %); taking the pass away wins 9 more points for both hands (75.5 to 84; 76 to 84.5) and the hand then carries 1.5 s
   instead of 0.8. The tempo says why: a 15 m tap pass flies 63 frames, a defender from a standstill covers 10 m in 64, and
   the bots react in 0 frames at every level (`JamAICore.h:495`, `DifficultyProfile.cpp:38,91`).
3. **The puck never settles.** At pro it changes teams 27 times a minute (every 2.2 s), a carry lasts 0.8 s, 39 % of the
   regular hand's carries end with an opponent carrying, and the puck is loose 34 % of live time (42-46 % at all_star). There
   is no time for a plan; the game is a scramble of hits and loose pucks (9.7 landed hits a minute at pro).
4. **At pro, skill stops showing above the regular hand** (75.5 against 76.0 %, ±3), and **at rookie above the novice**
   (97.5 / 100 / 100). The good hand reacts in half the time and aims more finely and does not win more matches at pro.
5. **The good hand's finer play costs it.** Its far-side carry (the stick sweeping the puck away from a defender): taking
   it away wins 11 more points at pro and at all_star. A plausible reason, not proven here: a puck carried on the far side
   is outside the shot's 60 degree front gate (`JamSim.h:509`, `JamSim.cpp:2818`), and without the sweep the good hand
   shot more (8.11 against 7.44 a match) and scored more (2.35 against 2.12). Its quick draw press: never pressing at the
   faceoff wins it 14.5 more points at pro and 13 at all_star, although at pro the human wins every draw either way (784 of
   784 pressing, 764 of 764 not) and the regular hand shows no such effect. The cause of the draw figure is not found
   (an open question, below).
6. **Rookie is won without you.** A human who stands still all match wins 60.5 % of rookie matches. The rookie opponents
   skate at 0.68 of the human's top speed (8.3 m/s on average against his 9.5).
7. **Half the keys do nothing measurable.** Taking away the brake button, the one-timer, the tap shot, the saucer, the deke,
   the spin, the brace or the poke changes no win share or goal difference by two standard errors in any of the six
   cells (regular and good x three levels), and the body check in only one. The brake button is never pressed; the
   ability does nothing in `hockey.regular`; the one-timer comes 0.1-0.3 times a match; the body check is pressed 0.3 times
   a minute against the cross-check's 9.
8. **Skating into a carrier takes his puck, no key needed.** Head on, the attacker ends with the puck in 20 of 20 gym
   trials without pressing anything; a hand that only skates wins 29.5 % at pro (idle 9.5).
9. **The poke almost never works.** About 9-10 presses a minute at pro, 0.5 clean (5 %); from behind never (0 of 19 in the
   gym: the carrier's body is between, `JamSim.cpp:1570-1582`). Taking it away changes nothing significant.
10. **All-star is harder by speed, not by play.** Its opponents average 11.0 m/s while the puck is live against the human's
    9.5; his top is 12.65 (14.55 sprinting for 3 s) while a bot may push its stick to 1.5 and reach 19 m/s
    (`JamSim.cpp:1383`, gym). The same bots' rules otherwise differ little between pro and all_star
    (`DifficultyProfile.cpp:88-136`).
11. **The human spends 8-14 s of every match lying on the ice.** 5.6 knockdowns a match for the regular hand at pro, 4.0
    for the good hand, each 60-150 frames down (`JamCartridge.h:400-401`): 11.2 s of a 137 s match at pro.
12. **A sprint outlives its bar.** The bar empties in 3 s, but the speed above top is lost only to glide drag (0.15 m/s a
    second, `JamSim.cpp:1426-1430`): a sprinter going straight keeps 14.5 m/s for many seconds after the bar is empty
    (gym chase probe: 14.55 m/s at frame 180, 14.54 at frame 240). Only a turn or a stop takes the sprint's speed away.

Open questions this page could not close: why the good hand wins more by never taking the draw (item 5); why the "pass"
signal makes the human receive fewer passes (2d); whether a person-like hand that re-plans around a missing verb (instead
of pressing a dead key) would change the dead verbs' verdict.

## 5. The harness

```
bash engine/tools/rink.sh balance            # PASS when every match hash and every gym line equals the baseline
bash engine/tools/rink.sh balance --update   # after a deliberate change: writes the new baseline (review the diff)
```

- What it runs (`engine/cores/rink/lab/balance.mjs`, plan `balance` in `cells.mjs`): the gym probes (all of section 1's rows
  that come from the gym), the ladder at pro and all_star (novice, regular, good), the idle hand at pro, and five ablations
  of the regular hand at pro: the stick's aim (the largest loss), the stop and the sprint (the feet), the pass (its loss
  is a gain) and the shot (its loss costs little). 12 cells x 50 seeds (1-50) = 600 matches, 6 processes.
- What it prints: one line per cell with 18 figures (wins, goal difference, goals for / against a minute, first goal,
  possession, shots both ways, carries, carries lost, passes completed, possession changes, knockdowns, hits, piles, dead
  puck, match length) and "= baseline (hashes equal)" or "MOVED" with the baseline's figures under it; a moved gym probe is
  printed now / baseline. Last line: `PASS  balance: ...` or `FAIL  balance: n of 12 cells and m of 43 gym probes moved`.
- A stopped run is never a pass: fewer than 600 completed matches is FAIL. No `rinklab.exe` and no compiler is exit 2.
- It builds `rinklab.exe` first if it is missing (`rink.sh lab-build`: SCons and MSVC; godot-cpp not needed). Measured from a
  clean tree (no objects, no exe): build and run 2 min 22 s, `PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes
  equal the baseline, hash for hash (132 s)`.
- Baseline: `engine/cores/rink/lab/balance.baseline.json` (every figure plus a digest of the 50 match hashes of each cell).
- Seeds 1-50 make it a detector of change, not a measurement: the figures in this page are the 200-seed cells. To
  re-measure a whole table: `node engine/cores/rink/lab/cells.mjs run ladder|ablate|only|signal` then
  `node engine/cores/rink/lab/tables.mjs` (about 25 minutes for the ladder, 2 hours for the ablation with 6 processes).
