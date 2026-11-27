# J19-shield proof: Shield wall gets a shield charge and a leaping slam (27 Nov 2026, night, 05:10-07:00)

Tree `.claude/worktrees/d25-shield` (branch n27-shield, main b1ee0b1d). Job `.tl/jobs/shield-wall-3-v-20261125-1`
(v0.1.4 at the start; the menu's "Shield wall" is v0.1.3). Times are local; the job log is UTC.

## Juice sheet (written 05:15, before the first sentence)

Two abilities and one answer to them. Existing keys: WASD, LMB/J attack, RMB/Space guard, E/K heavy, SHIFT evade, Q call.

### 1. Shield charge (key F; bots too)
- **Wind-up (anticipation):** 14 frames: the fighter drops into a crouch behind the lowered shield, feet scrape, a
  dust puff kicks out behind; a red arrow lane shows on the stones in front (the line he will run).
- **The run (exaggeration):** 40 frames straight ahead at 11 m/s (walk is 3.6, so three times), barely steerable
  (60 deg/s). He covers about 7 m, a third of the court.
- **Impact:** every rival in the lane (within 1.1 m of the run) is bowled like a pin: thrown 4 m along the run and
  sideways off it, 1.5 m up, a tumble, down 100 frames, a slow get-up. The charge goes on through, so one run can
  flatten a whole line. Each body hit: a wood-and-metal thud, hit-stop 4 frames, a camera kick, dust.
- **Counterplay (the brace):** a rival who faces the charge with his shield raised (guard held) stops it dead: a loud
  clang, sparks, the bracer slides back 0.6 m, and the charger bounces 1.5 m back and staggers 70 frames, guard wide
  open. SHIFT also sidesteps out of the lane.
- **Cost:** a 30-frame winded stop at the end of the run; cooldown 240 frames (4 s).
- **Bots:** a bot charges when two or more rivals stand in a rough line in front of it within 8 m and none of them is
  braced facing it; a bot that sees a charge coming at it (after its reaction delay, 10-14 frames) raises its shield
  facing the charger, or sidesteps. Target: 1-3 charges a minute a bot.
- **Reference:** For Honor's shoulder bash / Shugoki charge, Mordhau's shield bash, Gang Beasts' bowled-over bodies.

### 2. Leaping overhead slam (key C; bots too)
- **Wind-up:** 12 frames crouch, weapon drawn back over the head.
- **The leap (exaggeration):** 2.6 m high (more than a fighter's height), 4 m forward, 40 frames of hang with the
  weapon high. A red ring on the ground marks where he will land (radius 3.2 m), throbbing as he falls.
- **Impact:** the crash sends a ground shockwave ring of dust and stone chips out to 3.2 m over 12 frames: everyone
  inside is knocked off his feet, thrown out 2-3.5 m from the centre (farther the nearer he stood), down 80 frames;
  hit-stop 8 frames, a big camera kick, a boom.
- **Counterplay:** the red ring gives 40 frames to run out of it; a braced shield inside the ring only staggers (no
  floor) at the outer half.
- **Cost:** the weapon is stuck in the stones for 40 frames after landing (open to a blow); cooldown 360 frames (6 s).
- **Bots:** slam when two or more rivals are within 4 m in front; run out of a slam ring they are in.
- **Reference:** Mordhau / For Honor overhead slam, Smash's ground pound, Diablo's leap.

**The sentence a person types** (Create's change box, 800 characters):
> Give every fighter two big moves. F is a shield charge: crouch behind the lowered shield for a moment, then sprint straight ahead three times as fast; everyone in the way is bowled over like pins, thrown back tumbling, and gets up slowly, so one charge can flatten a whole line. A fighter facing it with his shield raised stops it dead: the charger bounces off with a loud clang and staggers wide open. C is a leaping overhead slam: jump high with the weapon over my head, a red ring shows where I land, and the landing sends a shockwave ring of dust that knocks everyone near off their feet, with a freeze and a camera kick. After each move I am open for a moment, with a cooldown. The rivals charge an open line, raise shields when charged, slam a crowd and run out of the ring.

(780 characters; it fits the change box's new 800-character cap whole, so nothing was cut.)

## Editor round 1

- **05:10:41** the change was recorded (event 593). In 4 s the Planner named **core**: "The shield charge, leaping slam,
  knockdowns, block-bounce, cooldowns, camera kick and rival AI responses all belong to the core fighter, contact,
  moves, camera and brain files".
- **core r14** (3.1 min, 1.63M tokens in, 1.54M cache reads, 18k out) built it all:
  - `rush` on F: an 18-frame crouch with the `body_check` clip, then 30 frames straight along the facing at 10.8 m/s;
  - `slam` on C: a 54-frame wind-up while the body jumps and moves 2.6 m forward, then a 2.8 m landing ring, with a
    red ring where it will land;
  - a rush into a raised shield from the front counts as `blocked_heavy`: the charger is knocked back 1.2 m and
    GUARDBROKEN for 60 frames;
  - brain: brace against a charge (tier defend + 0.3, its "RULE:" line), run out of a slam ring, slam a crowd of 2+,
    charge a foe 3-6.5 m away whose shield is down;
  - no F or C key buttons on the HUD (its own words).
- Its invariants run stalled twice at frame 5915 (a 255-272 ms tick). The Foreman said so in plain words ("the same
  stall twice ... in the pack's own code"). **core r15** (2.4 min, 0.50M in) found it: R on the end screen rebuilt every
  fallen body in one frame. It spread the rebuild over a 14-frame pause. Merged at **05:20:31** (7 files), no refusal,
  no balance question.
- One package only: the Planner sent the whole sentence to core. In the 3 v 3 game four of the five bots (Oda, Finn,
  Sable, Pip) think in `scripts/crew/mind.gd`, which belongs to the crew package, so only core's `brain.gd` (Bram)
  learned to charge, slam, brace and flee. (Measured below.)
- **05:31:39: v0.1.5 promoted** (`promoted/game.shield_wall_3_v@0.1.5`): 21 min from the sentence, core r14 + r15
  about 2.14M tokens in (2.0M cache reads), 22k out, plus the Planner's 4k. No refusal, no balance note, no question,
  no hold. The what-changed card (event 649) quotes the sentence and the builder's first lines.

> blocked-editor: a sentence that names what the rivals do went to core only; in the 3 v 3 game 4 of 5 bots think in
> the crew package's `scripts/crew/mind.gd`, so they never charge, slam or brace (bots rush 0 a minute and slam 0-1 a
> minute over seeds 1-3, all of it Bram) | evidence: job event 596 (Planner names core), 619 (merge: no
> scripts/crew file), `.tl/j19/es1.json`..`es3.json`

### The editor's v0.1.5, measured with a hand (`tests/bot_juice_editor.gd`, 3600 frames = one match minute)

The hand is the same captain as the by-hand test below (shield up and bash; F when a rival stands in a lane 2.5-7.5 m
in front; C when two or more are within 4 m in front). It counts every fighter's rush and slam starts from the state
the pack publishes, and the knockdowns from its events.

| seed | bots' rushes / min | bots' slams / min | the captain's rushes -> knockdowns | the captain's slams -> knockdowns |
|---|---|---|---|---|
| 1 | 0 | 1 (Bram) | 3 -> 0 | 1 -> 2 |
| 2 | 0 | 1 (Bram) | 3 -> 0 | 1 -> 1 |
| 3 | 0 | 0 | 4 -> 0 | 2 -> 2 |

- 0 script errors on every run; seed 1 gives `98730759e4dd5b92...` twice; smoke 3600 frames passes.
- A rush that knocks someone down is rare (seeds 4 and 5: one in 15). Its reach is 1.15 m in the 60-degree arc of an
  ordinary blow, so a rival a step off the line is missed, and the lane is never shown before it comes.

**Film of v0.1.5** (`clips/editor_v015_rush_slam.mp4`, 8.6 s, window, seed 2, frames 2740-3260, the hand test;
sheets `stills/editor_v015_my_rush_f2746-2801.jpg`, `editor_v015_my_slam_f2980-3046.jpg`,
`editor_v015_bram_slam_f3196-3229.jpg`, all looked at):
- My rush: the captain lunges at Bram in the `body_check` pose and stops against him. Nobody falls, and nothing on
  the stones says a charge is coming.
- My slam: the captain hops about a body height with the weapon up and comes down on Bram, who goes over. A big red
  barrel and Oda's head fill much of the low camera's frame, so the jump is hard to read.
- Bram's slam: a short rise with "OPEN: HIT NOW" over him; the landing falls just after the clip ends.
- As a person: the slam is there but small, and the charge is a shove that never lands.

## Editor round 2: "all six, not only Bram" (05:47-06:01)

The sentence (331 characters):
> All six fighters, not only Bram, must use the shield charge and the slam: Oda, Finn, Sable and Pip also charge an
> open line and slam a crowd, and each of them raises his shield when a charge comes at him or runs out of the red
> ring. Show a red lane on the stones in front of a charger while he crouches, so I see the charge coming.

- The Planner named **crew** this time, in 4 s: the right owner.
- **crew r4** (3.3 min, 1.37M tokens in) gave Oda, Finn, Sable and Pip rush, slam, brace and flee in
  `scripts/crew/mind.gd`, with its own numbers in `data/crew.json`. It added a red lane drawn while a charger crouches,
  built in `scripts/crew/mod.gd`. Its RULE: line keeps the "defend + 0.3" brace chance. It said plainly that the
  core's 18-frame crouch is under the 20-frame tell minimum and outside its files.
- Merged 05:53:17 (3 files); **v0.1.6 promoted 06:01:30**, 14 min from the sentence. No refusal, no question.

**v0.1.6 measured** (same hand, 3600 frames, seeds 1-3; 0 script errors; seed 1 `bfdd762d9fd616b3` twice):

| seed | bots' rushes / min | bots' slams / min | knocked down by a slam | knocked down by a rush | rushes stopped by a shield |
|---|---|---|---|---|---|
| 1 | 1 | 6 | 7 | 0 | 0 |
| 2 | 4 | 10 | 14 | 0 | 0 |
| 3 | 3 | 9 | 8 | 0 | 0 |

- The bots now answer the sentence: every crew slams, and the slams floor people every few seconds.
- The charge still never lands, for the captain or the bots: 0 knockdowns from 15 rushes, and 0 braced. The reason
  is in its numbers. The rush's reach is 1.15 m, but two fighters' pushboxes (0.7 m each) keep their centres 1.4 m
  apart, so the charger stops against the body before his blow can reach it.

> blocked-editor: the editor's shield charge never lands: 0 knockdowns and 0 braced from 15 rushes over seeds 1-3 of
> v0.1.6 (and 0 of 10 on v0.1.5). Its reach (1.15 m) is shorter than the bodies' pushbox gap (1.4 m); the person asked
> for "everyone in the way is bowled over like pins" | evidence: `.tl/j19/e2s1-3.json`, `es1-3.json`; moves.json
> `rush.reach` 1.15, tuning.json `pushbox` 0.7; `stills/editor_v015_my_rush_f2746-2801.jpg`

## Editor round 3: "the charge never knocks anyone over" (06:02-06:17)

The sentence (329 characters), what a person says after trying it:
> The shield charge never knocks anyone over: my fighter runs into a rival and just stops against his body, and
> nobody falls. Anyone the charge runs into must be bowled over, thrown back tumbling and slow to get up, and the
> charge keeps going through to the next man, unless he faces it with his shield raised, which stops it dead.

- The Planner named **core** (moves, contacts, fighter), and core r16 started at 06:02:59.
- **core r16** (3.0 min, 0.80M tokens in) found the cause itself. The charge got its own lane hit test: anyone
  between 0.2 m behind and 1.3 m ahead, within 1.1 m of the line. Its words: "reach changed from 1.15 to 1.3 so a body
  in front is reached before the capsules stop the charger". A victim is now thrown along the line and off it
  (`rush.scatter`), and a charge that a module cancels tries again on the next frame.
- The Foreman said in plain words that `tell_min_f` was already outside its bound before the change, so it was not
  judged as this change's regression (event 712). Merged at 06:08:36 (2 files).
- **v0.1.7 promoted 06:17:39**: 15 min from the sentence, no refusal, no question. The promoted pack is file for
  file the one measured and filmed below. Seed 1 gives `d7211da4317c8ffe` twice; smoke 3600 frames passes with 0
  errors.

**v0.1.7 measured** (the job pack after the merge, identical to the promotion, seeds 1-3, 3600 frames, 0 script errors): rush knockdowns
2 / 1 / 5, slam knockdowns 6 / 12 / 4, bots' rushes 3 / 2 / 4 and slams 8 / 12 / 6 a minute, 2 rushes braced (seed 2).
Seed 3: Oda's rush floors Sable and then Pip 8 frames apart, a line bowled by the editor's own charge.

**Film** (`clips/editor_r3_rush_slam.mp4`, 8.8 s, window, seed 3, frames 870-1400, 0 script errors; sheets
`stills/editor_r3_oda_rush_f891-946.jpg` and `editor_r3_pip_slam_f1170-1236.jpg`, looked at):
- Oda's charge: a broad red strip on the stones while he crouches (crew r4's lane), then a blur of dust. Two Gulls
  fall, but the camera is on my own fight, so they fall at the edge of the frame. "OPEN: HIT NOW" goes up.
- Pip's slam lands on our crew. I am thrown upside down with my shield flung out, and Sable lies on the stones
  beside the crates.
- As a person: now it is a charge. It still reads smaller than the hand version. The victims slide and fall rather
  than fly, nothing names the hit, and the lens does not follow a leap.

## By hand: `.tl/juice/shield_hand/` (05:12 onward, in parallel with the editor)

**Base:** v0.1.4, the job's newest pack when I started (the editor's v0.1.5 did not exist yet). Pack version 0.2.0.
Files (TL* API only):
- `scripts/juice/mod.gd` (new, about 520 lines), a module the core already loads (`sw_mods`), registered by
  `gen/mod_juice.gd`; its numbers in `data/juice.json`. It owns a fighter through its own states while a move runs
  (CHARGE_WIND, CHARGE, SLAM_WIND, SLAM_AIR); any blow that lands changes his state and drops the move.
- `scripts/main.gd`: `restart_match` rebuilds the fallen over a short pause (the same stall the editor's core r15 met:
  seed 3, frame 3419, a 255-273 ms tick when R restarted a match with four bodies on the stones).
- `tests/bot_juice_hand.gd` (new): the person's hand.
- `pack.json`: version, the module, the test.

What the hand layer is, ability by ability (numbers from `data/juice.json`):
- **Shield charge (F).**
  - Wind-up: 14 frames crouched behind the raised shield (the `block` clip), leaning 20 degrees forward, a squash, a
    dust kick behind and a scrape.
  - The tell: a lane of five red rings on the stones, 1.2 to 6.8 m ahead of the charger, shown from the first
    wind-up frame. Everyone can see where he will run, so a bot (or you) has the wind-up and the run's first frames
    to brace or step aside.
  - The run: 40 frames at 11 m/s (walk 3.6), leaning 30 degrees, steerable 60 deg/s by the hand, dust every 5
    frames. It stops at the court's edge.
  - Bowling: every rival within 1.1 m of the line, 1.55 m ahead, is thrown 4.2 m along and off the line over 20
    frames. He rises 1.6 m in a 26-frame arc while spinning a full turn, and lies 100 frames, then takes 40 to rise.
    The charge runs on through him, so a line goes down one after another.
  - Impact on each body: 4 frames of hit-stop, a wood crack and a break, sparks, a dust burst, a red shock ring,
    a 0.22 camera shake, "BOWLED!" over him for 45 frames, 8 damage.
  - End: 30 winded frames (the `recoil` clip), open to a blow. Cooldown 4 s for the hand, 3.3-5.3 s for a bot.
- **The brace.** A rival who holds his shield up and faces the charger within 70 degrees stops it dead:
  - 9 frames of hit-stop, a loud iron clang over wood and stone, a big gold spark burst, a 0.3 shake;
  - "BRACED!" over the bracer;
  - the bracer slides back 0.6 m in blockstun;
  - the charger bounces 1.6 m back, GUARDBROKEN for 70 frames, with his shield flung wide. The pack already marks
    that state "OPEN: HIT NOW", and its bots already punish it.
  - The hint tells the person both ways round: "Bram braced: a raised shield stops a charge dead. SHIFT away!" or
    "BRACED! Sable is wide open: LEFT MOUSE".
- **Leaping overhead slam (C).**
  - Wind-up: 12 frames crouched (the `land` clip), a squash.
  - The leap: 40 frames, 2.6 m high at the top (taller than a fighter), 4 m forward, the weapon held cocked over the
    head (`strike_heavy` held at its high frame).
  - The tell: a red ring of the blast's 3.2 m radius where he will land, from the first wind-up frame, growing and
    throbbing as he falls.
  - Landing: 8 frames of hit-stop, a boom (a break and stone, iron), a 0.45 camera shake for 18 frames, "SLAM!" over
    him, a dust column and sparks, 14 dust puffs thrown outward on the ring, and a yellow shock ring spreading to
    3.2 m.
  - Everyone inside is floored and thrown out from the centre, 2.0 m at the edge and 3.6 m at the centre, up to
    1.65 m high with a half turn. They lie 80 frames and take 36 to rise. Damage is 6-10.
  - A braced shield in the outer half only reels (22 frames of blockstun, pushed out 1.1 m).
  - Cost: 40 frames with the weapon driven into the stones (`strike_heavy` held at its end). Cooldown 6 s for the
    hand, 8-12 s for a bot.
  - The lens rises with a captain in the air (camera.gd), so the leap is not lost off the top of the screen.
- **The bots** (all five, decided in the module after their own minds, so every crew and every habit gets it):
  - **Charge** a lane of rivals 2.5-8 m ahead with no raised shield facing them: 4 % a frame with two or more in it,
    0.8 % with one.
  - **Slam** a crowd: 1 % a frame with two or more within 4.5 m in front, 0.08 % with one.
  - **Answer a charge** that has run for 12 frames (their reaction time) and is aimed within 1.6 m of them. They
    brace, turning the shield to the charger without dropping their own lock, or they sidestep with SHIFT. The brace
    chance is set per man: Bram 85 %, Oda 75 %, Sable and the captain's AI 60 %, Finn 45 %, Pip the dancer 30 %.
  - **Run out of a slam ring** they stand in: 75 % of the time, after 12 frames.
  - They do not start a big move while their crew's captain's call or surge runs (the rally's own play).

### Proof of the by-hand juice (as a person meets it)

**Clips** (window, d3d12, seed 1, `tests/bot_juice_hand.gd`, 0 script errors in the windowed runs):
- `clips/hand_bots_charge_slam.mp4` (20 s, frames 330-1530). It shows:
  - Pip's charge floors Finn (364), and Oda's floors Sable (403);
  - my slam (395) floors Bram and Pip (446);
  - Finn's charge bowls a line: Pip, then Bram, 12 frames apart (559, 571);
  - Sable's charge floors me (749), then Finn braces Oda's (761);
  - three bot slams (807, 904, 1219), each flooring one or two.
- `clips/hand_my_charge_braced.mp4` (3.7 s, frames 2240-2460, from the first take, before the lens follow). My charge
  into Bram and Sable, who both brace: clang, sparks, "BRACED!" twice, and I reel back open with the hint "Bram
  braced: a raised shield stops a charge dead. SHIFT away!".

**Stills I looked at:**
- `stills/hand_bowl_line_f541-585.jpg` (4 frames a tile): Finn crouches behind his shield with the red lane in front.
  Two Gulls go up, limbs out, a body height off the stones, with "BOWLED!" over each, and come down in a heap. It
  reads as pins.
- `stills/hand_my_slam_f392-458.jpg` (6 frames a tile, after the lens follow): I go up well over Bram's head with the
  shield and weapon high, and the lens rises with me. The red landing ring is on the stones. Then "SLAM!", a dust
  column and sparks, and Bram is down at my feet.
- `stills/hand_my_charge_braced_f2262-2317.jpg`: the lane rings run out ahead of me toward Bram and Sable. They turn
  their shields to me; gold sparks; "BRACED!" over both; I bounce back.
- `stills/hand_f1217_slam_lands_two.jpg`: Pip's slam lands among my crew. Dust, two of us on the stones, the yellow
  shock ring spreading, red lane rings from another charge.

**Headless figures** (3600 frames = one match minute; "a minute" counts all five bots together):

| seed | bots' charges / min | bots' slams / min | bowled | braced (charge stopped) | slammed | slam braced | bots brace / sidestep / flee | script errors | state hash |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 14 | 11 | 10 | 5 | 15 | 1 | 11 / 6 / 19 | 0 | `e0b41355a5253458` (twice) |
| 2 | 15 | 4 | 9 | 6 | 11 | 1 | 16 / 9 / 10 | 0 | `88aad209477b4f3f` |
| 3 | 6 | 8 | 8 | 3 | 7 | 0 | 8 / 5 / 9 | 0 | `8080ea2ad2675d4c` |

- Per bot that is 1.2-3 charges and 0.8-2.2 slams a minute.
- About a third of all charges are stopped by a brace, so the brace is a real answer, not a rare one.
- Determinism: seed 1, 3600 frames, run twice: `e0b41355...` both times. Smoke 3600 frames: 0 errors. Lint passes
  with no bypasses. The worst tick is 62-88 ms.
- **The pack's own tests on the hand pack** (each to its own end, 0 script errors):
  - bot_player passes (2349 f), bot_crew passes (4186 f), bot_look passes (900 f), bot_tofu passes (9001 f, 3 rounds).
  - **bot_call FAILS** (5410 f) on one row: "charged together" is 1 (it needs 2). Its other rows pass, but the first
    captain's call comes at frame 5299 instead of 349 on v0.1.4.
  - The cause: the scripted captain is bowled and slammed before his meter fills, so his call comes late. This is a
    behaviour change of the juice, not a script error. The test was not touched.
  - bot_crew failed on my first version: gang_max 3, because bracing bots switched their lock to the charger. I fixed
    it in the game (a bracing bot turns its shield to the charger and keeps its own lock), not in the test.

## Editor vs hand (what a person meets)

| | editor v0.1.5 (round 1) | editor v0.1.6 (round 2) | editor v0.1.7 (round 3) | by hand, `.tl/juice/shield_hand` 0.2.0 |
|---|---|---|---|---|
| charge key, wind-up | F, 18 f crouch (`body_check`) | same | same | F, 14 f crouch behind the shield, lean, squash, dust kick |
| charge tell | none | a red lane while crouching (crew's mod) | same | a lane of 5 red rings, wind-up and run |
| charge run | 30 f at 10.8 m/s | same | same | 40 f at 11 m/s, steerable 60 deg/s |
| does the charge floor anyone | no: 0 from 10 rushes | no: 0 from 15 | yes: 1-5 a minute, two in a row seen | yes: 8-10 a minute, lines of two |
| hit on a body | knockdown, 2.2 m push | same | thrown along the line and off it | 4.2 m throw, 1.6 m arc, a full spin, 100 f down, BOWLED!, sparks, shock ring |
| brace | blocked_heavy: charger back 1.2 m, open 60 f | same | same | dead stop, clang, BRACED!, charger back 1.6 m, open 70 f; a third of charges braced |
| slam | 54 f wind-up while it hops 2.6 m forward, ring 2.8 m | same | same | 12 f crouch + 40 f leap 2.6 m high, red landing ring, 3.2 m blast, SLAM!, dust ring, shake 0.45, the lens follows |
| slam cost | 40 f recovery, cooldown 6 s | same | same | 40 f stuck, cooldown 6 s (bots 8-12 s) |
| bots use them | Bram only: rush 0, slam 0-1 a minute | all: rush 1-4, slam 6-10 a minute | rush 2-4, slam 6-12 a minute | all: charge 6-15, slam 4-11 a minute |
| bots answer them | Bram braces and flees | all brace (defend + 0.3) and flee | same | brace 30-85 % by man, or sidestep; flee a ring 75 % |
| HUD | no F/C buttons | same | same | F/C with READY or seconds, top right |
| errors, determinism | 0; `98730759...` twice | 0; `bfdd762d...` twice | 0; `d7211da4...` twice | 0; `e0b41355...` twice |
| time, tokens | 21 min, 2.14M in | 14 min, 1.37M in | 15 min, 0.80M in | about 75 min of my work |

## Which abilities the editor made and which were made by hand

- **The editor made:**
  - **the leaping slam** (round 1, v0.1.5): a hop forward, the red landing ring, a knockdown ring, dust, a shake;
  - **the brace** (round 1): a charge into a raised shield bounces the charger open;
  - **every bot using and answering them** (round 2, v0.1.6, after I named it);
  - **the red lane tell** (round 2);
  - **a charge that actually bowls people** (round 3, v0.1.7). Rounds 1 and 2 made a charge that could never land.
  - Three sentences, about 4.3M tokens in, 50 min from sentence to promotion in all (21 + 14 + 15). No refusal, no question, no hold. The
    one-package routing of round 1 and the unreachable reach of rounds 1-2 are the two `blocked-editor` lines above.
- **By hand** (`.tl/juice/shield_hand`, built in parallel from the start because the editor bent the charge and
  missed the four crew bots in round 1), all three abilities:
  - the charge's crouch, lean, lane of rings, steering, bowling arc with a spin, the run going on through a line, and
    the BOWLED! word;
  - the brace's dead stop, clang and BRACED!, with per-man brace chances and sidesteps;
  - the slam's real leap (2.6 m up for 40 frames, weapon high), the blast ring of thrown bodies, SLAM!, the
    stuck-weapon cost;
  - a lens that rises with a leaping captain, and F/C ready labels.

**How each feels to a person:**
- **Charge (hand):** the best toy here. You see the lane of red rings and know what is coming. The run is fast
  enough to cross a third of the court in two-thirds of a second. Two men going up in turn, "BOWLED!" over each, is
  Gang Beasts on a quay. Being bowled yourself is funny, not unfair, because the lane showed it. The editor's charge
  (round 3) now floors people too, but they slide and fall at the edge of the frame. It reads as a hard shove.
- **Brace (hand):** the counter is obvious and satisfying. The clang, the gold burst and "BRACED!" stop the charge
  dead, and the charger reels back with "OPEN: HIT NOW". A charge into a raised shield is a real mistake, a third of
  charges end that way, and the hint tells you to SHIFT away. The editor's brace works in the numbers, but you rarely
  see one.
- **Slam (hand):** the leap is the most "crazy" moment. The captain goes up over Bram's head, the lens rises with
  him, and the red ring tells everyone where he comes down. SLAM!, a dust ring and two men on the stones. The
  editor's slam is a hop of about a body height, hard to see behind the low camera's foreground.
- **Too much?** In the hand version the bots slam often (4-11 a minute across five), so a minute has a lot of men on
  the stones. It is chaotic in the way the night asked for. A calmer setting is two numbers in `data/juice.json`
  (`bots.slam_p`, `slam.bot_cooldown`).

## Landable

- **Best pack:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/juice/shield_hand` (game.shield_wall_3_v
  0.2.0). Menu title: **"Shield wall: charge and slam (juice by hand)"**.
- **Optional editor row:** v0.1.7, promoted 06:17:39,
  `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.7`. Title: **"Shield wall: charge and slam
  (editor)"**.
