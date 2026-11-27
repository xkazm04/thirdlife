# J2b proof: a second crazy ability for robot soccer and shield wall, through the fixed editor (juice day, 27 Nov 2026)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane` (branch d27-second-b, main f2d72951 with lane T's
items 1-22). Job copies (plain recursive copies at 16:18, `diff -rq` empty against the originals, which stay untouched)
in `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/`:
- `robot-soccer-3-v-20261125-1` (newest v0.1.9, from d25-shield; last event seq 1529);
- `shield-wall-3-v-20261125-1-jb` (newest v0.1.13, from d25-shield; last event seq 1330).

Each change is sent as Create sends it: `engine/ui/foreman_run.mjs` + `foreman change <job copy> "<sentence>"` with the
`change` flags of `engine/ui/flags/real.json` (claude-cli sonnet, real and paid). Sentences word for word:
`SENTENCES.md`. Times are local (CET).

## Verdict

Both games got a second crazy ability, **all by the editor, no hand build**: robot soccer a Rocket League Rumble magnet
yank on Q, shield wall a Total War catapult volley on G with the testudo answer. Each first sentence built every part
and the bots used it from the first version; each looked small on screen, and one follow-up that NAMED the juice
(big words, fireballs, a visible arc, the camera pulling back) made it read at a glance: J4b's and J2nd's lesson once
more.

| Game | Ability (reference) | Versions (sentence -> version, time, tokens in / out) | Pick | Bots per minute (pick) | Headless (pick) | Clips |
|---|---|---|---|---|---|---|
| Robot soccer | Rocket League Rumble magnet on Q: lightning beam, closing ring, the ball ripped off a robot's feet, YOINK!, block the beam (ZAP!) | 1 -> v0.1.10, 41 min, 3.19M / 37.5k / follow-up -> v0.1.11, 45 min, 2.76M / 22.2k | **v0.1.11** | rivals 7-9 yanks, mates 5-7, blocks 2-4 (seeds 1-3) | 3600 f, 0 errors, a4f04e48 twice; newcomer 15/20, perfect 20/20 | `clips/j2b_robot_v010_magnet.mp4`, `clips/j2b_robot_v011_magnet_yoink.mp4` |
| Shield wall | Catapult volley on G: LOOSE!, longship, red circles, fireballs, KABOOM!, men flung; walk out or TURTLE! | 1 -> v0.1.14, 16 min, 3.31M / 32.4k / follow-up "small on screen" -> v0.1.15, 14 min, 1.49M / 11.9k / follow-up "TURTLE! hidden, stones from nowhere" -> v0.1.16, 15 min, 1.89M / 19.2k | **v0.1.16** | gulls 1-2 volleys on my crew, 2-4 men thrown, 1-5 walk out, 0-1 turtle | 3600 f, 0 errors, 9fdaaac6 twice | `clips/j2b_shield_v014_volley.mp4`, `clips/j2b_shield_v015_fireballs.mp4`, `clips/j2b_shield_v016_launch_turtle.mp4` |

Total editor spend on this lane: 15 model calls (builders and the Planner) over 5 promotions, about 12.6M tokens in
(11.7M of them cache reads) and 123k out (from `builder_run` events, `.tl/j2b/cost.py`).

**For the owner to play** (pack paths for the Director's menu rows; keys: robots Q hold and let go = magnet yank, F
hammer; shield G = catapult volley, Space = shield up (overhead under the stones), Q call, F charge, C slam):
- `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.11`
  - "Robot soccer v0.1.11: magnet yank (made in Create, juice day)"
- `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/shield-wall-3-v-20261125-1-jb/promoted/game.shield_wall_3_v@0.1.16`
  - "Shield wall v0.1.16: catapult volley (made in Create, juice day)"
- In-between versions (robots v0.1.10; shield v0.1.14, v0.1.15) are in the same `promoted/` folders and need no rows.
  The pack ids are the existing rows' ids; these version numbers (robots 0.1.10-0.1.11, shield 0.1.14-0.1.16) exist only
  in my job copies.

Nobody has played these with real keys: every figure comes from scripted hands (the packs' own hands plus my counting
tests `.tl/j2b/tests/j2b_magnet.gd` and `j2b_volley.gd`, used only on film copies under `.tl/j2b/film/`), and every
"feels" line comes from film and stills I looked at.

## Juice sheets (written 16:15-16:21, before the first sentence)

### 1. Robot soccer: the magnet yank (Rocket League Rumble's Plunger and Magnetizer)
First ability: the sledgehammer (hold F, let go: a robot flies). That one hits robots; this one takes the BALL, from
range, even off a rival's feet. It changes who has the ball, not who is standing.
- **Key:** Q (free in v0.1.9: WASD move, Shift sprint, Space kick, E quick, F hammer, R rematch).
- **Wind-up (anticipation):** hold Q: a crackling blue lightning beam locks from my robot's chest onto the ball within
  15 m, and a blue ring tightens round the ball for a third of a second (20 frames). Everyone sees whose beam it is.
- **Exaggeration, in numbers:** on release the ball is ripped off the ground in a high arc at twice a shot's speed,
  straight to my feet, from up to 15 m; any robot in its path is knocked over.
- **Impact:** a zap sound, sparks, the robot it was ripped from spins round, YOINK! big mid-screen (lane T's rule:
  impact words mid-screen), a camera kick.
- **Bots with it and against it:** rival robots yank loose balls and steal mine when I dribble within range; defenders
  step into the beam's line to block it.
- **Counterplay / cost:** a robot standing in the beam's line breaks it and is zapped (stunned 1 s, ZAP!), so a mate
  can body-block for the carrier; one yank every 8 s, a blue meter over the robot's head shows when it is ready.
- **Copies:** Rocket League Rumble (the Plunger yanks the ball to your car; the Magnetizer), Mario Strikers'
  item steals (a ranged steal in a ball game).

### 2. Shield wall: the catapult volley (Total War fire pots, the testudo answer)
First ability: charge, brace, slam (a body move up close). Q is already a war horn (the rally call), so the brief's
horn idea is taken. The quay is flat (no slope to shield-surf). This one is a RANGED area attack called in from the
sea, and its answer is the oldest shield move there is: the shield over the head.
- **Key:** G (free in v0.1.13: WASD, J attack, Space guard, E/K heavy, Shift evade, Q call, F rush, C slam, R restart).
- **Wind-up:** I shout LOOSE!, a catapult on a longship on the sea swings its arm with a creak, three red target
  circles land on the thickest knot of rivals and pulse for 1.5 s (90 frames): long enough to see and run.
- **Exaggeration:** burning stones arc down from the sky trailing fire and smoke; everyone inside a circle is thrown
  high and spinning (well over his own height).
- **Impact:** BOOM, a fire burst, a dust ring, a big camera shake, KABOOM! big mid-screen.
- **Bots with it and against it:** Bram's gulls call volleys on my crew too; the bots run out of the circles or raise
  their shields over their heads.
- **Counterplay / cost:** step out of the circle in the 1.5 s, or hold the shield overhead so the stones glance off
  in gold sparks (TURTLE!); one volley every 20 s, G READY or the seconds on screen.
- **Copies:** Total War (onager fire pots, the testudo against missiles), Clash Royale / Worms (the target marker
  before an area strike).

## Log

### Sends (both dry starts checked within 2 minutes: the Planner answered, a builder runs)
- **Robots**, 16:22:14, log `.tl/jobs/_ui_logs/1795792934-j2b-robot-change.log`, event 1530. The Planner (5 s) named
  core ("The yank is a new player verb with its own range, cooldown, ball flight, knockdown and stun rules, which
  belong in core's sim, tuning and robot files"); core r20 running at 16:22:20.
- **Shield wall**, 16:22:17, log `.tl/jobs/_ui_logs/1795792937-j2b-shield-change.log`, event 1331. The Planner (5 s +
  40 s for the plan) **added a new package `volley`** (scope `gen/mod_volley.gd`, `scripts/volley/**`,
  `data/volley.json`, `tests/bot_volley.gd`; "added through the core module API only; no wire": its gen script appends
  itself to the `sw_mods` list the core already loads). volley r1 running at 16:23:04.

## Shield wall: the catapult volley

### Change 1 -> v0.1.14 (sent 16:22:17, promoted 16:37:57: 15.7 min)
- Path: Planner -> volley r1 (one round, merged 16:32:40, 9 files) -> final checks V0-V5 -> promotion 15.
  **Cost: 3 model calls (two Planner calls and volley r1), 3.31M tokens in (3.05M cache reads), 32.4k out.**
  No refusal, no bend, no question. Unlike the karts' items package this morning (J2nd finding 2), the new package
  is wired: `gen/mod_volley.gd` is in `pack.json` assets and the core's module loop picks it up.
- The done card, as a person reads it (the builder's own words): smoke and invariants NOT RUN inside the round (time
  ran out; the Foreman's own V2/V3 ran after and passed); a stone hit is told only to the call module, so "volley hits
  do not appear in `state().events`" and crew damage scaling does not apply to stones; "the 720 degree spin turns the
  rig's child node named `Rig`, if there is one. I did not check that name, so the spin may not show at all"; the rings
  are flat red cylinders and the stones grey spheres (`TLBodies.make`); only a fire trail, no separate smoke; the
  longships are hand-made boxes ("the kit has no ship part"); LOOSE! plays the `cheer` sound (no shout preset). The
  gulls fire when ready and at least 2 of my crew stand within 3 m of one of them; AI caught in a circle runs out with
  its tier's defend chance or holds its shield if it cannot get out. In round 1 neither side can volley before my
  first captain's call.
- "a test was changed to pass: tests/bot_volley.gd" is listed on the card; it is volley's own new test.
- The Foreman's capture (`captures/promotion15-play-f2385.png`, looked at): a red longship with a dark catapult arm
  sits on the sea to the right of the quay; "G 10" in white at the right edge.
- v0.1.14 = my film copy `.tl/j2b/film/shield_v14` byte for byte except my test (`diff -rq`: only `pack.json`'s tests
  list and `tests/j2b_volley.gd`).
- **Measuring hand** (`.tl/j2b/tests/j2b_volley.gd`, film copies only): JB-back's `bot_braced_count` captain (shield up,
  bash, F into a lane, C into a crowd), plus a person who has learnt Q and G: Q whenever the captain's call is ready,
  G whenever the crew's volley is ready. It reads the volley's published state (`fired` per side, `thrown`,
  `turtled`, `escaped`). (A first try that pressed Q on a timer never blew the call, so the volley stayed locked in
  round 1: 0 volleys. That was my hand, not the game; the lock is on the card.)
- **Headless, v0.1.14** (3600 frames each, **0 script errors** on every run):

  | seed | hash | volleys crew / gulls | men thrown | turtled | escaped | bots' charges / slams |
  |---|---|---|---|---|---|---|
  | 1 | d45ff736 (three runs) | 2 / 2 | 3 | 2 | 1 | 12 / 10 |
  | 2 | 134304f1 | 3 / 2 | 2 | 0 | 4 | 14 / 12 |
  | 3 | 3ba6cc9a | 3 / 2 | 5 | 1 | 4 | 14 / 11 |

  So per minute: **Bram's gulls call 2 volleys on my crew**, my hand 2-3; 2-5 men thrown; the bots answer it (1-4
  walk out of a circle, 0-2 turtle under the shield). The charge and slam stay busy (bots 12-14 charges and 10-12 slams
  a minute; v0.1.13 was 11.0 charges a minute in JB-back's six seeds).
- **On film** (`clips/j2b_shield_v014_volley.mp4`, 30 s, 800 wide, crf 32, window, d3d12 movie writer, seed 1, frames
  1000-2800; 0 script errors in the window run). Stills I looked at: `stills/shield_v014_crew_volley_f1045-1141.jpg`,
  `stills/shield_v014_crew_impact_f1128-1172.jpg`, `stills/shield_v014_kaboom_f1155.jpg`,
  `stills/shield_v014_volley2_f2380-2468.jpg`, `stills/shield_v014_turtle_f2740-2784.jpg`.
  - G READY turns into G 20; LOOSE! comes up; big solid red discs land on the stones under the knot of fighters;
    dark stones drop out of the sky; on impact orange embers burst and float, white rubble scatters, a gull in yellow
    is lifted to head height and flung sideways; KABOOM! in orange.
  - The gulls' volley on me (round 2): red discs under my crew, a big dark stone drops right past the camera; my man
    holds his shield over his head, gold sparks, TURTLE!. The answer to the volley reads.
  - How it feels (from film, not my hands): a real new thing in the fight; both crews use it and men are flung. But it
    is **small on screen**: KABOOM!, LOOSE! and TURTLE! are small words off to the side, much smaller than the core's
    BOWLED!; the stones are plain grey-black balls with little fire; a thrown man rises only to about head height; the
    play camera sits close behind my man, so the circles over the rivals are often out of the frame.
  - J4b's lesson again: the sentence named the juice ("big", "high", "burning"); the first version built every part,
    but small.

### Follow-up 1 (sent 16:53:24, log `.tl/jobs/_ui_logs/1795794804-j2b-shield2-change.log`), as a person who watched it
> The volley works and both crews use it, but it is small on screen. KABOOM! is a small orange word ... let the camera
> rise and pull back until it lands ...
- The Planner (5 s) named volley again ("All of the requested changes belong to the volley package's files").
  volley r3 (one round, merged 17:02:36; `data/volley.json`, `scripts/volley/shot.gd`, `scripts/volley/show.gd`),
  in its own words: the words now use the core's own big word layer; head-over-heels spin, 720 degrees over 80
  frames; `throw_up` 5.5 -> 7.8 m/s ("a throw's height grows with the square of the upward speed, so this doubles
  it"); stones 0.3 -> 0.42 m and orange #ff6a10 with flame and smoke trails and a burst every 4 frames; the camera
  through the shared `g.tune["cam"]`.

### Follow-up 1 -> v0.1.15 (sent 16:53:24, promoted 17:07:47: 14.4 min) **<- the shield pick**
- volley r3 only, first round; no refusal, no bend, no question. **Cost: 2 model calls (the Planner and volley r3),
  1.49M tokens in (1.39M cache reads), 11.9k out.**
- v0.1.15 = my film copy `.tl/j2b/film/shield_c2` (the job's pack after volley r3's merge) byte for byte except my test.
- **Headless, v0.1.15** (3600 frames each, **0 script errors** on every run; the hash changes from v0.1.14 because the
  throw is stronger):

  | seed | hash | volleys crew / gulls | men thrown | turtled | escaped | bots' charges / slams |
  |---|---|---|---|---|---|---|
  | 1 | d7b1e462 (twice) | 2 / 1 | 2 | 0 | 1 | 9 / 9 |
  | 2 | dfcf85cd | 3 / 2 | 5 | 2 | 2 | 15 / 12 |
  | 3 | 17bd88e1 | 3 / 2 | 6 | 1 | 2 | 14 / 16 |

  Per minute: **gulls 1-2 volleys on my crew**, my hand 2-3; 2-6 men thrown; the bots walk out (1-2) or turtle (0-2).
- **On film** (`clips/j2b_shield_v015_fireballs.mp4`, 30 s, 800 wide, crf 32, window, seed 2, frames 800-2600, four
  volleys; 0 script errors in the window run). Stills I looked at: `stills/shield_v015_crew_volley_f830-926.jpg`,
  `stills/shield_v015_fireballs_f894.jpg`, `stills/shield_v015_impact_f892-936.jpg`,
  `stills/shield_v015_kaboom_flip_f919.jpg`, `stills/shield_v015_gull_volley_f2150-2246.jpg`.
  - LOOSE! now big, white with a black outline; the camera rises and pulls back, so the quay, the red circles and the
    longship are all in the frame; orange fireballs with long white flame-and-smoke streaks come down out of the sky;
    KABOOM! big orange with an outline, above the fight; a gull is flipped head over heels at about one and a half
    times his height and lands in a heap.
  - The gulls' volley on my crew: fireballs on the red discs under my men; KABOOM!; my men flat on the stones; one of
    mine flung high right past the camera.
  - How it feels (from film): now it reads at a glance and it is a moment, like the karts' juice follow-up in J2nd.
    Still short of the sentence in two small ways: the fireballs come in from the upper left of the frame, not visibly
    from the longship on the right; TURTLE! was counted (0-2 a minute) but I did not catch it on film this time.
  - Why TURTLE! hides (read in `scripts/volley/shot.gd` `impact()`): `_turtle()` puts TURTLE! up, then, after the
    loop, KABOOM! replaces it in the same frame whenever anyone else in the volley was thrown (one shared word layer).

### Follow-up 2 -> v0.1.16 (sent 17:50:19, log `.tl/jobs/_ui_logs/1795798219-j2b-shield3-change.log`, promoted 18:05:29: 15.2 min) **<- the shield pick**
> Much better ... show TURTLE! in gold over the man who turtled, on top of the KABOOM! ... let me see each one leave the
> longship, the catapult arm whipping up and a flaming stone flying from it in a high arc over the sea onto the quay.
- The Planner (3 s) named volley; volley r4 (4.8 min, one round, merged 18:00:21; `data/volley.json`,
  `scripts/volley/ship.gd`, `shot.gd`, `show.gd`), in its own words: the arm whips once per stone (whips at f6, f20,
  f34, each 7 frames to 100 degrees), each stone loaded into a cup and burning from the cup, arc 9 -> 13 m, the ships
  moved further out to be in the lifted view, the arm turned toward the court; "TURTLE! now goes over the turtled man
  in gold on a new HUD painter layer ... KABOOM! has the centre and each turtle keeps the gold word over his own head".
  It says it changed the contract's timing ("change request wins over the contract's f20..f90") and that no kit part is
  a catapult. **Cost: 2 model calls (the Planner and volley r4), 1.89M tokens in (1.78M cache reads), 19.2k out.**
- v0.1.16 = my film copy `.tl/j2b/film/shield_c3` (`diff -rq`: only `pack.json`'s tests list and my test).
- **Headless, v0.1.16** (3600 frames each, **0 script errors**): seed 1 **9fdaaac6 twice** (crew 2 / gulls 1 volleys,
  2 thrown, 1 escaped); seed 2 510a939f (3 / 2, 4 thrown, 4 escaped); seed 3 93d5cd48 (3 / 2, 3 thrown, 1 turtled, 5
  escaped). Per minute: gulls 1-2 volleys, 2-4 men thrown, the bots walk out (1-5) or turtle (0-1). Charges 7-15 and
  slams 7-15 a minute.
- **On film** (`clips/j2b_shield_v016_launch_turtle.mp4`, 10.5 s, 800 wide, crf 32, window, seed 3, frames 780-1410;
  0 script errors in the window run). Stills I looked at: `stills/shield_v016_launch_f811-907.jpg`,
  `stills/shield_v016_gull_volley_turtle_f975-1071.jpg`, `stills/shield_v016_turtle_f1065.jpg`.
  - The gulls' longship on the right: its arm whips up with a burning stone in the cup and flings it high over the sea,
    a white smoke column rising behind it; three times; the fireballs come down on the red disc under my crew.
  - At the impact (frame 1065): **TURTLE!** in gold over my man who held his shield up, and **BRACED!** over Bram,
    both readable at once; embers and gold sparks everywhere.
  - How it feels (from film): the volley is now a whole story a person can follow: the ship fires, the stones arc in,
    the circles fill, men fly or turtle. Crew volleys still come from my own ship off the left edge of the frame, so
    for my own volleys the launch is not seen from the play camera.

## Robot soccer: the magnet yank

### Change 1 -> v0.1.10 (sent 16:22:14, promoted 17:03:29: 41.2 min)
- Path: Planner (5 s) -> core r20 (3.8 min, built it; its note: "No bot test of my acceptance counts it ... yet")
  -> the "new attack must land" check failed (event 1546) -> core r21 (counted it in `tests/bot_player.gd`, which core
  owns; failed on a **KIT REGRESSION**: four `BoxMesh.new()` in `scripts/view/magnet_look.gd`) -> core r22 (moved the
  meshes into `gen/robot.gd`'s shared helpers; "new move lands in the Foreman's bot run: magnet_on landed 1 of 3,
  yank_hit landed 1 of 1"; merged 16:38:14) -> dependents re-verified -> 40 hand matches -> promotion 11.
  **Cost: 4 model calls (the Planner and core r20-r22), 3.19M tokens in (2.93M cache reads), 37.5k out.**
  J2nd's finding 1 (landcheck vs the frozen tofu bot) did not recur: core owns `bot_player.gd`, a test the check reads.
- The done card, as a person reads it: two balance notes: "matches now run longer (the Foreman's test needed about 1.6
  times the frames it planned). Say "make matches shorter""; and **"a newcomer player now wins 7 of 20 (was 15 of
  20). Say "make it fairer""** (the card's bound is 13). The builder: only team 1 (the rivals) decide to yank, never
  during the opening; the rings and beam segments are hand-made meshes through `gen/robot.gd` ("no kit part draws a
  ring or a beam").
- v0.1.10 = my film copy `.tl/j2b/film/robot_c1` (made from the job's merged pack at 16:55) byte for byte except my
  test (`diff -rq`: only `pack.json`'s tests list and `tests/j2b_magnet.gd`).
- **Measuring hand** (`.tl/j2b/tests/j2b_magnet.gd`, film copies only): the pack's own perfect hand
  (`tests/ai_support/play.gd`) plus a person who has learnt Q: with the ball loose or a rival's, 4-13 m away, hold Q 26
  frames (the lock is 20) and let go, then wait 3 s. Counts every magnet event by side.
- **Headless, v0.1.10** (3600 frames each, **0 script errors** on every run; one minute each):

  | seed | hash | rivals: beams / YOINK! / bowled by the ball | my hand: beams / YOINK! | blocks (zapped in a beam's line) |
  |---|---|---|---|---|
  | 1 | cac479a8 (twice) | 12 / 4 / 1 | 7 / 3 | 2 rivals in my beam, 2 of my mates in theirs |
  | 2 | 98a4ccfc | 15 / 5 / 1 | 7 / 4 | 1 rival |
  | 3 | db9cef5c | 13 / 5 / 0 | 6 / 5 | 0 |

  So **the rival bots yank the ball 4-5 times a minute** (12-15 beams; the rest break on range or a blocker); they
  step into my beam (ZAP) and my mates into theirs. My bot mates never yank (as built: rivals only, as the sentence
  said). (A first run of my test stopped "not done" because the test waited for the match end; fixed to end at the
  frame budget, the same figures.)
- **On film** (`clips/j2b_robot_v010_magnet.mp4`, 30 s, 800 wide, crf 32, window, seed 1, frames 1180-2980; 0 script
  errors in the window run). Stills I looked at: `stills/robot_v010_yoinks_f1236-1302.jpg`,
  `stills/robot_v010_rival_beam_f2223.jpg`, `stills/robot_v010_yoinked_f2253.jpg`,
  `stills/robot_v010_rival_yoink_zap_f2230-2326.jpg`.
  - My yank: a blue beam runs from my yellow robot to the ball far ahead, a ring round the ball, and the ball is at my
    feet a blink later; a rival rips it straight back: YOINK!, the ball jumps out of my feet.
  - The rival's yank (frame 2223): a big blue ring closes round the ball at my feet and a blue beam comes in from
    behind the camera: a warning a person can read in time. At 2253 my robot is thrown upside down in white sparks
    while the ball flies up past the camera, YOINK! over me; my robot cartwheels and a blue rival arrives.
  - How it feels (from film): the steal is the picture: you lose the ball and get flipped. Weaker than asked: YOINK!
    and ZAP! are mid-size white words, not big; the beam looks like a flat blue hose on the grass, not lightning in
    the air; the ball arrives in about 10 frames, too fast to see a "high arc"; the rival who yanks is usually off
    screen behind the camera.

### Follow-up 1 (sent 17:04:04, log `.tl/jobs/_ui_logs/1795795443-j2b-robot2-change.log`), as a person who watched it
> The yank works and the rivals rip the ball off me often, but it reads small. YOINK! and ZAP! are small white words
> ... And my own bot teammates should use the magnet too.
- The Planner named core (r23 running at 17:04:10) and, by lane T's rivals routing, sent "And my own bot teammates
  should use the magnet too." to brain (r4) as its own request (event 1656).
- core r23 (3.6 min, one round, merged 17:10:25; `data/tuning.json`, `scripts/sim/magnet.gd`,
  `scripts/view/magnet_look.gd`, `scripts/view/show.gd`), in its own words: a yank now takes at least 30 frames (half a
  second; was 10); arc 4.0 -> 5.5; a thicker jagged beam with a white core; a trail; the words on their own HUD layer
  with size, outline, pop and fade keys; the camera pulls back on a `yoink` where a rival rips the ball from me; and
  "the magnet bot logic now runs for team 0 mates (ids 1 and 2) as well as rivals. Mates never yank from the captain".
- brain r4 (merged 17:20:52, `tests/ai_support/play.gd` only): "The mates' and rivals' magnet decisions ... stay in
  core's `scripts/sim/magnet.gd` ... No values in `data/ai.json` or scripts under `scripts/ai/` were changed"; it added a
  `mate_yanks` figure to its test. So the routed request cost a round (0.6M tokens in) that found core had already done
  it: the same pattern as JB-back's finding 1 (a duplicate hand-off), here from the rivals routing alone.
- show r8 (reopened: "its dependency core was changed ... bot (V4) now fails on the merged pack"): the end card's
  loss-cause answers for core's new causes (hammered, yanked, zapped). Its pack check then met the frozen tofu bot not
  finishing 3 matches in 36000 frames (event 1720, "2 matches"); the Foreman re-ran it longer (event 1721, ok) and
  merged (17:27:02). The card had said for core r22 and brain r4 "matches now run longer ... (not judged in this
  change)"; here it was judged, then passed on a longer run. Not a refusal, but the same measure J2nd's finding 5 hit.
- **Measured on the merged pack** (`.tl/j2b/film/robot_c2`, the job's pack after show r8's merge; 3600 frames each,
  **0 script errors** on every run):

  | seed | hash | rivals: beams / YOINK! | mates: beams / YOINK! | my hand: beams / YOINK! | ZAP (blocks) |
  |---|---|---|---|---|---|
  | 1 | a4f04e48 (twice) | 14 / 7 | 9 / 5 | 8 / 5 | 4 |
  | 2 | cff85edc | 16 / 9 | 7 / 5 | 8 / 5 | 3 |
  | 3 | 7f571b6b | 13 / 8 | 10 / 7 | 8 / 5 | 2 |

  So **rival bots now yank 7-9 times a minute and my bot mates 5-7** (v0.1.10: rivals 4-5, mates 0). The longer
  flight gives a beam more time to be broken, but more beams start.
- **On film** (`clips/j2b_robot_v011_magnet_yoink.mp4`, 26.7 s, 800 wide, crf 32, window, seed 1, frames
  1950-3552; 0 script errors in the window run). Stills I looked at: `stills/robot_v011_mate_yank_zap_f1950-2046.jpg`,
  `stills/robot_v011_my_yank_f2090-2186.jpg`, `stills/robot_v011_my_yank_arc_f2127.jpg`,
  `stills/robot_v011_rival_yanks_me_f3440-3536.jpg`.
  - **ZAP!** now big fat yellow comic letters with a dark outline, mid-screen over the zapped robot.
  - My yank: a thick zig-zag bolt of white and blue blocks rises through the air from my robot to the ball; the ball
    then sails in a high arc over the camera, trailing a column of blue cubes.
  - A rival rips the ball off me: the camera pulls far back over the pitch so I see the blue robot who did it, and
    **YOINK!** fills the middle of the screen in fat yellow letters.
  - How it feels (from film): now it reads at a glance, like the hammer's KA-BONK!!: the steal is an event the whole
    screen shows. Weaker points: the bolt and the trail are built of chunky boxes (no kit part draws a beam), so the
    lightning looks like stacked blocks rather than a glow; my own yank of a loose ball shows no word (YOINK! comes
    when the ball is ripped off a robot); with rivals 7-9 and mates 5-7 yanks a minute the ball changes hands very
    often, which a person should judge by hand (it may now be too much).

### Follow-up 1 -> v0.1.11 (sent 17:04:04, promoted 17:49:22: 45.3 min) **<- the robots pick**
- core r23, brain r4, show r8, each first round; no refusal, no question. **Cost: 4 model calls (the Planner, core
  r23, brain r4, show r8), 2.76M tokens in (2.52M cache reads), 22.2k out.**
- v0.1.11 = my measured and filmed `robot_c2` (`diff -rq`: only `pack.json`'s tests list and my test), so the figures
  and the clip above are v0.1.11's.
- **Hands over 20 seeds (the Foreman's final checks, read from its reports): newcomer 15 of 20, perfect 20 of 20**
  (v0.1.10: newcomer 7 of 20, perfect 20 of 20; v0.1.9: newcomer 15 of 20 by the v0.1.10 card). The newcomer hand
  never presses Q: with only the rivals yanking (v0.1.10) a newcomer lost most matches; with his own mates yanking for
  him too (v0.1.11) the balance is back where it was before the magnet. The card for v0.1.11 carries no balance note.

## Editor findings (for the Director and lane T; none blocked the lane, so no blocked-editor line)

1. **The rivals routing ran a no-op round.** Robots follow-up: "And my own bot teammates should use the magnet too."
   went to brain (r4, event 1656) as the rivals' part, while the Planner gave the whole change to core. Core r23 did it
   (the magnet decisions live in `scripts/sim/magnet.gd`); brain r4 found nothing to do ("No values in `data/ai.json`
   or scripts under `scripts/ai/` were changed") and added a figure to its test: about 0.6M tokens in and 6 min for
   nothing. The same shape as JB-back's duplicate hand-off, from the routing alone this time: when the moving decisions
   for a verb live in the package that builds the verb, the rivals copy is redundant.
2. **The frozen tofu bot judges longer matches one way, then another.** The magnet makes robot matches longer. For core
   r22 and brain r4 the Foreman wrote a balance note ("matches now run longer ... not judged in this change"); for show
   r8 the same whole-pack tofu run was a failed V4 (event 1720, "2 matches" in 36000 frames), then passed on a
   "longer" re-run (event 1721) and merged. It cost only minutes here, but it is J2nd's finding 5 from the other side:
   the frozen measure does not fit a change that makes matches longer, and the Foreman answers that differently per
   package.
3. **Hand-made meshes pass the kit-regression check by moving into an existing helper.** Robots core r21 failed KIT
   REGRESSION (four `BoxMesh.new()` in a new view script); core r22 moved them into `gen/robot.gd`'s shared `ring` and
   `box` helpers ("so they add no new places where the pack builds a mesh by hand") and passed. The check counts
   places, not meshes. Shield's longship, catapult arm and cup are `TLBodies.make` boxes for the same reason ("the kit
   has no ship part", "no kit part is a catapult"). Question for the Director: is that the intended reading of
   "look in KIT.md before making a mesh", or should a beam, a ring and a catapult become kit parts?
4. **A builder says it overrode its contract, and the card does not flag it as a rule.** Shield volley r4: "change
   request wins over the contract's f20..f90 and arm swings 100 degrees over 18 f" (the stone timing). It is in the
   builder's note, said plainly; a person reading only the card's first lines would not see it. Cosmetic.
5. **Balance swings are visible on the card and a follow-up fixed one without asking.** Robots v0.1.10's card: "a
   newcomer player now wins 7 of 20 (was 15 of 20). Say "make it fairer"". My follow-up asked for my own mates to
   yank too, for juice, and v0.1.11 is back at 15 of 20 (perfect 20 of 20 both). Worth knowing: the newcomer hand
   never presses Q, so the bots' use of a new ability moves that figure both ways.

## Machine notes
- At 16:19 C: fell from 11 GB to 5.5 GB free in four minutes (an `ffmpeg` process I did not start, PID 23692, was the top
  writer) and came back to 10 GB at 16:20; at 16:48 it was 109 GB. room.sh held my first headless run about 5 minutes
  (disk under the 12 GB floor). The Foreman's own Godot runs in both jobs went on during that time.
- My raw film was deleted after each clip was cut (`.tl/j2b/raw` empty; `.tl/j2b` is 25 MB with the five film copies
  and the counting tests). The lane folder holds 5 clips (15 MB, 800 wide, crf 32, 10.5-30 s) and 21 stills I looked at (7.5 MB).

---

# Round 2 (Director, 18:10): a second crazy ability for Arsenal hockey, on the rink core

Job copy (plain recursive copy at 18:10, `diff -rq` empty; original untouched):
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/three-against-three-hockey-20261125-1` (newest
v0.1.27, from d25-shield; last event seq 1254). Its packages: base (everything), cartridge (`data/harbour.cartridge.json`,
`data/match.json`), harbour (`scripts/main.gd`, `harbour.gd`, `harbour_toys.gd`, `data/tuning.json`, ...), skin.

## What the core lets a cartridge give the bots (read first: `engine/cores/rink/CARTRIDGE.md`, the core's sources)
- `game.abilities[]` (shotgun, hip_check, shield, slow_puck on F): **"Bots never hold one."** The first ability (the
  meteor) is a shotgun mode entry: the hand's half only.
- `game.effects[]` with a trigger the core fires for every skater: `check_landed` is fired from the sim's `check` event,
  whoever checked (`JamEffectSystem.cpp:106`), so bots trigger it by playing. Stats an effect may move: speed, accel,
  turn rate, grip, mass, shot speed and aim, `check_speed_min`, `knockdown_frames`, puck and ice values.
- `game.pickups[]`: any skater who skates over one takes it, but only all_star bots seek them (`JamAICore.cpp:874`).
- The frame tells a pack who has what: `EffectEvents` (`effect_start` with the effect id and the skater), `Boosts`
  (`SNAPSHOT.md` v1.4), so the pack's own GDScript can draw the juice.
- Measured on v0.1.27 with JB-back's scoring hand (`bot_meteor_blind.gd`) and my event counter (`.tl/j2b/tests/
  j2b_rink.gd`, film copies only), 3600 frames, seeds 1-3, 0 script errors: the rival bots land **2 checks a minute**,
  my bot mates almost none; my hand 3-5; knockdowns 4-5 rivals (mostly the meteor), 1-2 me.
So an ability **earned by a landed check** is one the core's bots use without C++.

## Juice sheet (18:25, before the sentence): MEGA (Mario Kart's Mega Mushroom, earned by a hit as in NHL Hitz)
First ability: the meteor (a shot, the hand's only). This one is a body state any skater earns, bots included.
- **Key:** no new key: it is earned by landing a body check (right mouse button for the hand); F stays the meteor.
- **Wind-up:** the hit itself; the hitter flashes white with a boing and balloons to twice his size over a third of
  a second; MEGA! over him (mid-screen when it is me).
- **Exaggeration, in numbers:** twice the size for 5 s (300 frames); twice as heavy, about 1.2 x speed; every bump
  knocks a man flat (the knockdown speed threshold far down).
- **Impact:** a thud, FLATTENED! and a small camera shake per man he flattens; the ice trembles under his strides; a pop
  when he shrinks back.
- **Bots with it and against it:** every bot who lands a check goes mega (rivals about twice a minute on today's
  figures), my mates too; against it the core's bots have no new move (no C++): they play on as before.
- **Counterplay / cost:** he turns wide (turn rate down), so a quick skater slips past; pass the puck away from a giant;
  it lasts 5 s.
- **Copies:** Mario Kart Wii (Mega Mushroom: grow, flatten whoever you touch), NHL Hitz (big hits power you up),
  Smash Bros (the Super Mushroom).

## Arsenal hockey: MEGA

### Change 1 (sent 18:17:02, log `.tl/jobs/_ui_logs/1795799822-j2b-ars2-change.log`, event 1255)
(A stray command of mine at 18:16:44 ran the Create door on a job folder that does not exist, with an empty sentence:
`_ui_logs/1795799804-j2b-ars-change.log`, "no job.jsonl", exit 2. No model was called and nothing was created.)
- **The Planner (5 s) named harbour**, the GDScript package ("a new power-up effect on the ice, so it belongs in the
  harbour package"), not the cartridge package that owns `data/harbour.cartridge.json`.
- **harbour r20** (3.3 min, 1.51M in, 12.3k out; merged 18:24:42, `data/tuning.json`, `scripts/harbour.gd`,
  `scripts/harbour_toys.gd`): "RULE: MEGA is drawing only": any landed check (read from the victim's `ContactOutcome`
  and `ContactBy`) makes the checker's figure twice the size for 300 frames, with a white flash, YOU ARE MEGA! (me) or
  MEGA! (others) and FLATTENED!; "NOT DONE: "twice as heavy and a bit faster, every bump knocks a man flat, turns
  wide" needs `data/harbour.cartridge.json` ... I found no cartridge key for a modifier that starts on a check" (there
  is one: an effect with trigger `check_landed`). Sounds are stand-ins (no boing or pop preset).
- **Measured, harbour's merge alone** (`.tl/j2b/film/ars_h20`, seed 1, 3600 frames, 0 script errors): **the core's hash
  is the same as v0.1.27's (3ffb30ec)**: drawing only, the game plays exactly as before. MEGA came on 5 times in the
  minute (`harbour.marks.mega_on` 396, 1256, 1782, 3078, 3104), one FLATTENED!.
- **On film, harbour's merge alone** (window, seed 1, frames 360-1596; stills `stills/arsenal_h20_mega_on_f380-476.jpg`,
  `stills/arsenal_h20_mega_camera_flatten_f1500-1596.jpg`, looked at): my green #7 lands a check, flashes white and
  balloons to twice the size, YOU ARE MEGA! big at the top; an orange rival lies flat. **But the camera does not know I
  am a giant**: for about a second my own huge legs and backside fill the frame (frames 1500-1540), then FLATTENED!
  appears at the left. So the hand's half reads, the body is visual only.
- **T's routing (event 1277-1281):** the Foreman sent harbour's NOT DONE on to cartridge as its own request, with a
  list of "candidate keys" from the catalog (bump_ratio, cross_any_man, turn_rate, check_cooldown_restart,
  check_reach_m): none of them is the one that does it (`game.effects[]` with `check_landed`).
- **Then a pre-check asked the person a question nobody asked for (event 1282-1285, job paused, no builder ran):**
  "Your side already wins 10 of 10 at rookie, 10 of 10 at pro, 10 of 10 at all star ... so weaker bots would hardly
  show. Did you mean something else ... or should the bots be weaker still?" The request never asked for weaker bots.
- **My answer as the person** (18:26:37, `answer` then `resume` as Create's door does; log
  `.tl/jobs/_ui_logs/1795800378-j2b-ars-answer.log`): "No, I did not ask for weaker bots. I asked for MEGA: any skater,
  a bot or me, who lands a body check becomes a giant for five seconds: twice as heavy, a bit faster, turning wide, and
  every man he bumps is knocked flat. That is a timed boost on the skater who lands the check; the bots must get it from
  their own checks too. Keep the bots' level as it is."
- After the answer the Foreman's quick cartridge diff said "no key says it" and passed it to the builder. **cartridge
  r14** (2.3 min, 0.41M in, 4.3k out) then wrote exactly the effect: `mega`, trigger `check_landed`, target self, 300
  frames, mass x2, speed x1.1, turn rate x0.6, `check_speed_min` x0.25, "for the human and bots of both teams"; "Partly
  built: every bump knocks a man flat is approximated by check_speed_min x0.25 together with mass x2 under the core's
  momentum law"; "Not measured ... rink.sh check-cartridge is outside the commands I'm allowed to run".

### Change 1 -> v0.1.28 (sent 18:17:02, promoted 18:38:31: 21.5 min, about 1 min of it waiting for my answer)
- Path: Planner -> harbour r20 (drawing) -> T's hand-off -> pre-check question (paused) -> my answer -> cartridge diff
  ("no key says it") -> cartridge r14 (the effect) -> data-only change: "the pack tests, the re-verification of
  harbour, skin and the milestone's re-look are skipped" -> final checks -> promotion 29. **Cost: 4 model calls (the
  Planner, harbour r20, the cartridge diff, cartridge r14), 1.93M tokens in (1.79M cache reads), 18.1k out.**
- v0.1.28 = my film copy `.tl/j2b/film/ars_c14` (`diff -rq`: only `pack.json`'s tests list and my two tests).
- **So the editor did BOTH halves**, but only because T's hand-off routing carried harbour's NOT DONE to the cartridge
  package, and only after I answered a question about weaker bots that I never asked. The Planner itself put a
  cartridge-only rule in the GDScript package.
- **Headless, v0.1.28** (`j2b_rink.gd`: JB-back's scoring meteor hand plus my counter; 3600 frames each, **0 script
  errors**):

  | seed | hash | MEGA starts (sim `effect_start mega`): me / rivals / my mates | checks landed: me / rivals / mates | knockdowns of rivals (v0.1.27) |
  |---|---|---|---|---|
  | 1 | 7df3f5a1 (twice) | 4 / 1 / 1 | 8 / 1 / 1 | 10 (5) |
  | 2 | 57e41c10 | 3 / 1 / 0 | 3 / 1 / 0 | 4 (4) |
  | 3 | f0c6699b | 2 / 1 / 0 | 2 / 1 / 0 | 4 (5) |

  The sim effect starts on every landed check, for bots too: **the rival bots go mega once a minute** (each time on
  the check that knocks me or a mate down), my bot mates 0-1. On seed 1 my mega flattened two more rivals in a row
  (frames 1396, 1440, 2514, 2555: knockdowns by check 44-96 frames after my mega started).
- **On film** (`clips/j2b_arsenal_v028_mega.mp4`, 18.5 s, 800 wide, crf 32, window, seed 1, frames 370-1480; 0 script
  errors in the window run). Stills I looked at: `stills/arsenal_v028_rival_mega_f420-516.jpg`,
  `stills/arsenal_v028_my_mega_flattens_f1380-1476.jpg`.
  - My green #7 is a giant when an orange rival checks me (frame 432): I go down, and he balloons into a giant who
    towers over me lying on the ice: the game answers the ability with the ability.
  - Later, mega again, I skate through two orange rivals at their net and both go flat; FLATTENED! pops up each time.
  - How it feels (from film): crazy in the good way, and it reads at once: a giant hockey player is a picture. Wrong:
    YOU ARE MEGA! stays on screen while I lie on the ice and the rival is the giant; FLATTENED! is a small word that
    piles onto YOU ARE MEGA!; the camera at times sits inside my giant legs (harbour's merge, frames 1500-1540); the
    rivals' giants come only about once a minute.

### Follow-up 1 (sent 18:42:31, log `.tl/jobs/_ui_logs/1795801351-j2b-ars3-change.log`), as a person who watched it
> MEGA works and the giants read at once, but four things are wrong. ... pull the camera back and up while I am mega
> ... show FLATTENED! big over the man who goes down ... take it away the moment I fall ... I want to face their giants
> about twice as often, so they should land their body checks on me and my mates more often.
- The Planner named harbour for all of it, including "the bots' body-check rate in scripts/main.gd" (the bots are the
  C++ core's). **harbour r21** (2.5 min, 0.83M in, 10.2k out; merged 18:48:53; `data/tuning.json`,
  `scripts/harbour_toys.gd`, `scripts/main.gd`): MEGA! and FLATTENED! drawn on their own HUD layer at the man's screen
  point (FLATTENED! 72 pt yellow); the follow view's eye moves back 3.5 m and up 2 m while I am mega ("This goes against
  the contract line "Camera numbers are the cartridge's", because the player asked for it"); a downed skater's mega is
  cut short in the drawing ("The core's mega effect may still be running"); "A skater who is already mega does not get
  a new MEGA start from another check" (drawing; the core's effect refreshes); "NOT DONE: ... raise
  `game.ai.body_check` from 0.6 to 0.9" (the cartridge already says 1; the builder guessed).
- T's routing again carried the NOT DONE to cartridge (event 1342). The Foreman's cartridge diff (one quick model
  call, no builder round) chose a different, valid key: **`game.contact.bot_check_windup_frames` 12 -> 6** ("the red
  Crane Gulls now wind up their body checks in half the time, so more of their hits land"), with the measured check
  before and after (knockdowns at pro 32 -> 35; its standing warnings, a goal flood at 17-19 goals a match and trivial
  at all_star, were there before). cartridge r15 verified it; merged 17:52 (data only).

### Follow-up 1 -> v0.1.29 (sent 18:42:31, promoted 18:58:55: 16.4 min) **<- the Arsenal pick**
- **Cost: 3 model calls (the Planner, harbour r21, the cartridge diff), 0.85M tokens in (0.77M cache reads), 11.2k
  out.** v0.1.29 = my film copy `.tl/j2b/film/ars_c15` (`diff -rq`: only `pack.json`'s tests list and my two tests).
- **Headless, v0.1.29** (3600 frames each, **0 script errors**):

  | seed | hash | MEGA starts: me / rivals / my mates | checks landed: me / rivals / mates |
  |---|---|---|---|
  | 1 | 45fa13fd (twice) | 2 / 1 / 1 | 2 / 1 / 2 |
  | 2 | 468e8acb | 2 / 1 / 1 | 2 / 1 / 1 |
  | 3 | 9bced1db | 2 / 4 / 2 | 2 / 4 / 2 |

  Rival giants 1-4 a minute (mean 2; v0.1.28: 1, 1, 1); my bot mates 1-2 (v0.1.28: 0-1). About twice as often, as
  asked, on three seeds only.
- **On film, v0.1.29** (`clips/j2b_arsenal_v029_mega_camera.mp4`, 16.5 s, seed 3, frames 370-1360, and
  `clips/j2b_arsenal_v029_rival_mega_on_me.mp4`, 3.8 s, seed 3, frames 3340-3568; both window, 800 wide, crf 32, 0
  script errors). Stills I looked at: `stills/arsenal_v029_my_mega_cam_f385-473.jpg`,
  `stills/arsenal_v029_flattened_f826-870.jpg`, `stills/arsenal_v029_rival_mega_f1265-1361.jpg`,
  `stills/arsenal_v029_rival_mega_on_me_f3370-3466.jpg`.
  - My check, a white flash, and my giant #7 now stands in a camera that has risen and pulled back: the whole giant, the
    net and the rivals around him are in the frame, with the meteor's ring of fire as I wind up; no more legs filling
    the screen. A second mega check drives a rival into the net for a goal; YOU ARE MEGA! sits on top of the GOAL
    banner (clutter).
  - Frame 3382: an orange rival checks me, balloons into a giant at the edge of the frame and skates on; I lie flat,
    with no YOU ARE MEGA! left on screen. The follow camera stays on me, so his giant is on screen for under a second.
  - At frame 1277 a rival went mega checking my mate far away while the camera followed me along the boards: not seen.
  - How it feels (from film): the camera fix is the big one; MEGA is now a readable, funny moment both ways. Not seen in
    these takes: the new big FLATTENED! over a man flattened by a giant (my mega checks here were the ones that START
    it; FLATTENED! comes for later bumps, as in v0.1.28's film).

## Round 2 verdict
- **The editor made both halves of the second ability** (the look in GDScript, the rule in the cartridge, so the core's
  C++ bots use it with no C++), but not by its own plan: the Planner gave a cartridge rule to the GDScript package
  twice; the cartridge half arrived only through T's NOT DONE routing, and the first time only after the person
  answered a question about weaker bots that he never asked.
- The ability: MEGA (Mario Kart's Mega Mushroom earned by a hit, NHL Hitz). Any skater who lands a body check is a
  giant for 5 s: twice the size, twice the mass, a bit faster, wide turns, and his checks knock men flat. The rival
  bots go mega 1-4 times a minute (v0.1.29), my mates 1-2, my hand 2.
- Versions: v0.1.28 (one sentence + one answer, 21.5 min, 4 calls, 1.93M in / 18.1k out), v0.1.29 (one follow-up,
  16.4 min, 3 calls, 0.85M in / 11.2k out). **Pick: v0.1.29.** 0 script errors; seed 1 45fa13fd twice.
- Menu row (for the Director):
  `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.29`
  - "Arsenal hockey v0.1.29: MEGA from a big hit (made in Create, juice day)"; keys: the body check (right mouse
    button) lands a hit and makes you MEGA; F stays the meteor.
  - v0.1.28 is in the same folder (no row needed). The pack id is the existing row's id; 0.1.28-0.1.29 exist only in my
    job copy.

## Round 2 editor findings (for the Director and lane T)
6. **The Planner puts a cartridge rule in the GDScript package.** Twice (the MEGA stats; the bots' check rate, "in
   scripts/main.gd") it named harbour for something only `data/harbour.cartridge.json` can do; harbour then wrote it as
   drawing only and a NOT DONE. On the rink core the Planner should know that rules and bots live in the cartridge.
7. **A pre-check asks the person a question about something he did not ask.** Event 1283: "should the bots be weaker
   still?", before any builder ran on the cartridge hand-off; the job paused until I answered. The hand-off text was
   harbour's NOT DONE ("every bump knocks a man flat, turns wide"), which the check seems to have read as a request to
   make the bots weaker.
8. **The catalog hint misses the key that does it.** The Foreman's "candidate keys" for harbour's NOT DONE (bump_ratio,
   cross_any_man, turn_rate, check_cooldown_restart, check_reach_m) left out `game.effects[]` with trigger
   `check_landed`, the one key that makes a per-skater boost start on a check; and the quick cartridge diff said "no
   key says it" before the builder (cartridge r14) found it in 2.3 minutes.
9. **The drawing and the rule can disagree.** harbour draws MEGA from the victim's contact fields, the cartridge starts
   the `mega` effect from `check_landed`; harbour also says an already-mega skater gets no new MEGA start and a downed
   human's MEGA is cut short "while the core's mega effect may still be running". They agree on every start I counted
   (on v0.1.28, seeds 1-3, `harbour.marks.mega_on` 6 / 4 / 3 equals the sim's `effect_start mega` 6 / 4 / 3), but nothing ties them.
10. **A harbour builder guessed a value it could not read** ("raise `game.ai.body_check` from 0.6 to 0.9"; the cartridge
   says 1); the cartridge diff then chose a valid key (`bot_check_windup_frames` 12 -> 6) instead. Harmless here.

---

# Round 3 (Director, 19:10): see a rival's giant off screen; film the big FLATTENED!

## The big FLATTENED! on v0.1.29 (filmed, no change)
- Found by headless counting on v0.1.29 (seeds 4-7, 3600 frames, 0 script errors each: 6d6bffba, cb69b038, 1617ac71,
  68766c1b): checks landed by a skater already mega: seed 4 frames 510 and 1594, seed 5 frame 289, seed 7 frames 1788
  and 1793 (my giant from 1593). On seeds 1-3 my mega checks were the starting checks, which is why round 2's takes
  never showed it.
- **On film** (`clips/j2b_arsenal_v029_flattened.mp4`, 4.3 s, window, seed 7, frames 1580-1838, 800 wide, crf 32, 0
  script errors; stills `stills/arsenal_v029_flattened_f1776-1820.jpg`, `stills/arsenal_v029_flattened_f1800.jpg`,
  looked at): my giant #7 strides through two orange rivals at their net; both drop flat under his skates, ice spray,
  and **FLATTENED!** in big yellow letters with a dark outline over them, replacing YOU ARE MEGA! for the moment, then
  sliding with them. Met: big, one word at a time, over the man.

## The sentence (sent 19:11:17 on v0.1.29, log `.tl/jobs/_ui_logs/1795803076-j2b-ars4-change.log`), 502 characters
> When a rival goes MEGA where my camera cannot see him ... show a big orange arrow at the edge of the screen pointing
> at him, with MEGA! and how many metres away he is on it, pulsing faster as he gets closer. When he comes back on
> screen, drop the arrow and keep his MEGA! big over his head until he shrinks. Do not move my camera for it ...
(My call as the person: an edge arrow, not a camera glance, so the player keeps his own view.)

### -> v0.1.30 (promoted 19:22:08: 10.9 min) **<- the Arsenal pick now**
- The Planner (4 s) named harbour; **harbour r22** (one round, merged 19:16:56; `data/tuning.json`, `scripts/harbour.gd`,
  `scripts/harbour_toys.gd`): the arrow for rivals only, shown when his point 1 m above the ice is behind the camera
  or within `edge_px` of the edge; behind the camera it "points along his left/right offset and downward"; the
  distance between the drawn figures; a rival's MEGA! now lasts his whole MEGA; a `mega_arrow` mark. No hand-off, no
  question. **Cost: 2 model calls (the Planner and harbour r22), 1.04M tokens in (0.97M cache reads), 10.1k out.**
- v0.1.30 = my film copy `.tl/j2b/film/ars_h22` (`diff -rq`: only `pack.json`'s tests list and my two tests).
- **Headless, v0.1.30** (3600 frames, **0 script errors**): seed 1 **45fa13fd twice**, seed 2 468e8acb, seed 3 9bced1db:
  **the same hashes as v0.1.29** (drawing only, as it should be). The arrow mark fired on seeds 1-3 (2, 4 and 18 marks;
  seed 3 had four rival giants).
- **On film** (`clips/j2b_arsenal_v030_mega_arrow.mp4`, 14.5 s, window, seed 3, frames 1265-2135, the very moment round
  2's take could not show (a rival goes mega at 1277 while my camera follows me along the boards); stills
  `stills/arsenal_v030_arrow_f1308.jpg`, `stills/arsenal_v030_arrow_f1270-1366.jpg`,
  `stills/arsenal_v030_arrow_f1812-1908.jpg`, looked at):
  - an orange arrowhead appears at the bottom edge with **MEGA! 24 m** beside it, and the metres count up as he skates
    away (24, 25, 27 ... 44 m) and down as the next giant comes (14, 12, 11, 10 m): I know a giant is out there and how
    far.
  - Weaker than asked: the arrow is mid-size, not big (about a tenth of the screen height); while the giant is behind
    the camera it jumps between the bottom and the left edge from frame to frame; at times it sits under the controls
    panel at the bottom left, and its label overlaps the puck's own distance marker ("31 m" over "MEGA! 30 m"). The
    pulse cannot be judged from stills. The giant never came back on screen in this take, so "his MEGA! big until he
    shrinks" is built (the builder's note) but not seen.
- How it feels (from film): the warning works as information, and it is honest to the person's ask (the camera is left
  alone). As juice it is small and restless; a second sentence would ask for it bigger, steady at one edge while he is
  behind me, and clear of the HUD panels. (Round 3 was one sentence; I stopped here as asked.)
