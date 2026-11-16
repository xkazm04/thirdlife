# Ice hockey, three against three (house game `hockey`)

`game.ice_hockey_three_against`, built by the Foreman on 11 Nov 2026 from one sentence; made a tracked house game and
rebuilt in the night of 15 to 16 Nov (lane H, packages H0 to H12; the look by lane L). Every figure below was measured
that night, headless, on seeds 1 to 20 (or 40 where said), unless the line says otherwise. `docs/reports/jam-lessons-home/H.md` holds the record.

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
| play again after a match | R | |

A button held while the puck changes hands does nothing until it is released and pressed again.
Without a cursor on the ice (or with the mouse outside the window) the stick points where you skate.

**Level and mode** are pack params, not keys: in `engine/packs/hockey/data/tuning.json` set `"level"` (0 none =
"Classic", the opponents of `data/ai.json`; 1 rookie, the default; 2 pro; 3 all-star) and `"mode"` (0 three against
three, the default; 1 outnumbered, three against five; 2 sudden death, one goal ends it; 3 pond, no checks; 4 big ice,
80 x 40 m, two against two), or move the sliders `level` / `mode` in the Designer panel. The line at the bottom left of
the screen names both.

**The rings**: the green ring under your skater is your reach (1.45 m from your centre): a loose puck inside it is
yours on that frame, whatever you face and whatever you hold. A wider ring under a skater says he carries the puck,
in his team's colour (yours green; another carrier's ring shows after he has held it 20 frames). The puck itself has
an orange rim. Nothing else is drawn on the ice: a hit is shown by the figures only.

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
| bot_hockey_ai | the AI on all six skaters: a winner, AI shots, everybody moved |
| bot_reach | 13 rows: a puck in the ring is his within 1 frame (still, behind, facing away, sliding in, skating through at walk / full / sprint, Space or Q held, after his own pass, a poke both ways); 8 of 10 passes reach the mate |
| bot_match | bot-only play, 6,000 frames: both sides score; no skater outside the rink |
| bot_check | the hit table: monotone by closing speed, head-on and side; a braced man holds; the carrier cannot check; the cross-check takes the puck |
| bot_modes | all five modes end by their rules, none inside 2 s, none over 9,000 frames |
| bot_dial | the dial in periods 1 and 2, a third try refused, the match paused while open |
| bot_aim | the shot goes where the aim points while he skates another way; a pass to the mate aimed at; the dead zone; a cleared aim |
| bot_buttons | the four held-button transitions |
| bot_goals | a puck carried in, released, lying in a net counts (own goal too); on the blade behind the net it does not |
| bot_faceoff, bot_faceoff_idle, bot_faceoff_allstar | nobody owns the puck at the drop; doing nothing he is not first to it; who wins the draw skating at it is a number (rookie, all-star) |

## Known limits (each measured or read in the code tonight)

- No goalies: an open net from the face-off dot can be scored on, on rookie as on the others.
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
