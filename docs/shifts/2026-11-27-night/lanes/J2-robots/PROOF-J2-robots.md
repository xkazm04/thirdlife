# J2-robots proof: Robot soccer gets a double-sledged hammer (27 Nov 2026, night)

Tree `.claude/worktrees/d25-robot` (branch n27-robot, main e66eb94e). Job `.tl/jobs/robot-soccer-3-v-20261125-1`
(v0.1.5, the menu's "Robot soccer"). Times are local (CET+1); the job log is UTC.

## Juice sheet (written 03:05, before the first sentence)

One ability with two targets. It is the owner's own example: "Robots with doublesledged hammer allowed to bash oponents".

### The double-sledged hammer (key F; bots too)

- **Key:** F (and the middle mouse button). Hold to wind up, release to swing. Not while carrying the ball: the hammer
  is the way to take the ball off a carrier, or to drive a loose ball.
- **Wind-up (anticipation):** the hammer, a shaft with an iron head at each end, rises over the robot's head and the
  body leans back. The robot slows to 40 % speed and cannot turn faster than 2 rad/s. The heads glow brighter as the
  charge builds. The minimum wind-up is 20 frames (the visible tell); a full charge is 50 frames. A rising servo whine
  plays.
- **Swing:** 6 active frames in an arc in front of the robot: reach 2.4 m, +-65 degrees.
- **Exaggeration (in numbers):**
  - Smash-style knockback grows with the charge: a robot hit at 20 f flies 7 m, at a full 50 f 16 m.
  - The arc is 3 to 5 m high (a robot is 1.8 m), with 2 to 3 full tumbling turns in the air. The current slide
    tackle throws 1.8 m high and about 3 m far.
  - The victim lies 90 to 120 frames, then clambers up.
- **Impact:**
  - hit-stop 5 to 9 frames by charge;
  - a camera kick of 0.25 to 0.45 m;
  - a spark burst at the contact point, and a metal clang whose pitch drops with the charge;
  - the victim tumbles and drops the ball;
  - the HUD flashes "BONK!".
- **The ball:** a swing that meets a loose ball drives it like a golf drive along the facing, at 30 to 42 m/s by
  charge, faster than any kick (a full shot is 36). It also leaves a spark trail.
- **Cost and counterplay:**
  - A miss buries the hammer head in the ground for 40 frames. The robot cannot move or act, so it is open to a slide
    or a poke.
  - Cooldown 150 frames (2.5 s) after any swing.
  - The 20 f wind-up is a tell: a hop (E) or a sidestep gets out of the arc, and a carrier who sees it can pass away.
- **What the bots do with it:**
  - A rival chaser within 4 m of a carrier, facing it, winds up. It releases when the carrier is in reach, holding
    longer the farther away the target is. A loose ball near the attacking third is driven at goal.
  - About 1 to 3 swings per robot a minute (to be measured).
- **What the bots do against it:**
  - A robot in the arc of a visible wind-up, within 3.5 m, sidesteps out of it after its reaction delay (level 0..2:
    14/11/8 f).
  - A carrier hops or passes away.
- **References:** Smash Bros (knockback grows with the charge; a hammer item), Gang Beasts (tumbling bodies), Rocket
  League's demolition (a hit that removes a player for a moment), golf (the drive).

**The sentence a person types** (Create's change box):
> Give every robot a double-headed sledgehammer. Hold F to raise it over the head (the robot slows down and the
> hammer glows), release to swing: a robot it hits is launched high in an arc, tumbling over and over, with sparks, a
> loud metal clang, a short freeze and a camera kick, and the longer I held it the farther it flies. Hitting the ball
> smashes it like a golf drive. A miss buries the hammer in the ground for a moment so I am open, and there is a
> cooldown of a couple of seconds. The rival robots should swing at me when I carry the ball, and dodge out of the way
> when they see a hammer going up.

## Editor round 1: the hammer sentence (03:06 to 03:2x)

Create's change box takes at most 240 characters (`create_build.gd`, `max_length = 240`). The juice sheet's sentence
(about 600 characters) does not fit, so a person cuts it. This is what I typed (238 characters):
> Give every robot a double-headed sledgehammer: hold F to raise it, release to swing. A hit launches a robot far,
> tumbling, with sparks, a clang, a freeze and a camera kick. It drives the ball too. A miss leaves me open. Bots swing, dodge.

The cut lost "the longer I hold it the farther it flies", the 2 s cooldown and the glow.

- 03:06:42: the change was recorded (event 930). The Planner named **core** in 6 s, and the reason is right: core owns
  the tumble, the ball, the camera and basic_ai.
- **core r13** took 4.7 min, 1.72M tokens in (1.61M cache reads) and 21k out. It built all of it:
  - an F action, with raise and swing states;
  - `scripts/sim/hammer.gd` (122 lines);
  - knockback through `knock()` plus a shove, 1.6 times the flight height, and a 6-frame hit-stop on both robots;
  - a 0.32 m shake, sparks, debris and two clangs;
  - a ball drive at 30 m/s;
  - a 40-frame recovery after a miss and a cooldown of 70 frames (bots +200);
  - bot swings at carriers, after a raise of at least 24 frames that serves as the tell;
  - a sidestep dodge;
  - a hammer modelled on every robot's right fist.

  Its note is honest. Bots decide inside the sim because `scripts/ai` is not its scope, and every hit freezes, not
  only the player's hits.
- **03:13:01: the tofu gate refused the merge.** `tells` was 2 (bound >= 3) and `close_rounds` was 0 (bound >= 1).
  Both are balance figures I did not ask about, and the player bot and the other bots passed.
- **core r14** (1.5 min) changed no files. It asked the owner a balance question: "Matches are won by two or three goals
  ... Should the losing side start getting up faster once it's one goal behind ...?" The job **paused**.
- I answered as a person: "Keep first to 5 as it is. I only asked for the hammer, so leave the match rules the way they
  were." Then resume.
- **core r15** (1.7 min) added the rival hammer raise to the tells counted by `tests/bot_tofu.gd`. That is a fair
  reading, since the raise is a 24-frame tell. The gate's own refusal text says "never the counting", though. The
  bounds then held, and the round **merged 8 files at 03:22:31**.

Two `blocked-editor` lines:

> blocked-editor: Create's change box cuts a juicy ability at 240 characters, so a person cannot say the charge, the
> cooldown and the tell in one sentence | evidence: engine/ui/create/create_build.gd:380 `cb.max_length = 240`; the
> juice sheet's sentence is ~600 characters

> blocked-editor: the tofu gate refused a hammer that was built whole (r13) on balance figures the request never
> touched (tells 2, close_rounds 0). The person got a balance question about comeback rules, and the round only
> merged once the builder changed the bot's counting | evidence: job events 943 (core-r13-tofu-bounds FAILED), 947
> (question), 963 (r15 note: tells now count the hammer)

### What the editor's hammer is like, played (merged into the job's pack at 03:22; thrown away at 04:07, see below)

Filmed through a person's hand (`tests/bot_hammer_hand.gd`, TLHand "regular": it plays the newcomer's policy and
holds F at a rival carrier in front within 4 m, longer the farther he is). Clip `clips/editor_hammer_discarded.mp4`
(20 s). Stills `stills/editor_hit_sheet_f56-144.jpg` (8 frames apart) and `stills/editor_hit_f68-86.jpg`. The game
hash is the same as the merged pack's (`638fa200...` at seed 1, 3600 f), so the film is the pack.

- **What reads:**
  - the hammer goes up over my head in 10 frames;
  - the blue carrier flies back off the blow, limbs out, in a puff of sparks, and lands on his back;
  - the head drives the ball, and the opening goal in the clip is a hammer drive from about 12 m.
- **What doesn't read:**
  - the flight is the slide tackle's 28-frame hop, made 1.6 times higher (2.9 m), so it lasts half a second;
  - most of the 15-19 m the victim travels is a slide along the ground afterwards;
  - the head is a small mallet (0.6 m), with no glow and nothing on the court to show the reach;
  - every hit is the same size: holding longer changes nothing;
  - the bots swing it 1-4 times a minute between all five (seeds 1-3).
- **As a person:** a good bash, and it is the editor's work end to end. It feels like a stronger tackle with a hammer
  drawn on, not yet a Smash hit.

### What the editor did after the merge (03:22 to 04:07): the change was NOT made

- Final verification then failed **4 times out of 4** on core's `tests/bot_tofu.gd`:
  - `frame_budget: not done within 36000 frames`. Hammer knockdowns make a first-to-5 match run 4-4.5 min, so 3
    matches no longer fit in 10 min;
  - the control run without the newest round fails too.
- Each time the Foreman sent the failure to the **show** package. Show's builders say they cannot change play
  ("No change made ... nothing in my scope can fix the cause"):
  - show r2 to r6 merged end-card and dust tweaks;
  - that came to 6.8M tokens in.
- Create shows the job "working" all that time.
- **04:07:26: the job ends `done`:** "the change was NOT made: the final verification still fails at bot (V4) after
  4 round(s) ... the job ends on the earlier promotion 0.1.5". `pack/` is put back to v0.1.5. The editor's hammer is
  kept only in `reports/change-not-made-s1130/pack/`.
- **So the editor did not make the hammer, as a person meets it.** The game in Create and the menu has no hammer.
  The hammer was built, merged, played and filmed once and then thrown away, because a balance bot ran out of frames.
  The person was asked one balance question, which did not help, and the request took 60.7 min and **14.15M tokens
  in** (86k out). The job total went from 26.69M to 40.84M in.

> blocked-editor: final verification routes a core test that runs out of frames (bot_tofu's 36000-frame budget;
> hammer knockdowns make matches longer) to the show package. Its builder cannot touch play, the job loops
> (show r2-r6, 6.8M tokens) and nothing is promoted | evidence: job events 1017-1022, 1045-1050, 1101-1106;
> reports/final-bot-bot_tofu-s1101.json

Editor cost of the hammer so far: core r13-r15 7.4M tokens in (cache reads 7.0M), 48k out; show r2-r6 6.8M in, 37k
out.

## By hand: `.tl/juice/robot_hand/` (03:20 to 04:15)

**Base.** It starts from the editor's own thrown-away hammer: core r13 to r15 and show r2 to r6, the files of
`reports/change-not-made-s1130/pack/`, on v0.1.5. My layer goes on top, written with the TL* API only. Files:
- `scripts/sim/hammer.gd`, rewritten from the editor's 122 lines to 183;
- the new `scripts/view/hammer_look.gd` (160 lines);
- five line-neutral edits in `scripts/sim/sim.gd`, which stays at 600 lines;
- `scripts/view/show.gd` (+14);
- `gen/robot.gd`, for the hammer model;
- the `hammer` keys of `data/tuning.json`;
- the F key, and the middle mouse button, in `scripts/main.gd`;
- `tests/bot_hammer_hand.gd`, a person's hand that swings.

Menu title "Robot soccer: sledgehammer", pack version 0.1.6.

What the hand layer adds to the editor's hammer:
- **The charge, Smash style.** The charge runs from 16 frames held to full at 50 frames. It scales:
  - launch speed, 9 to 15 m/s;
  - arc height, 3.1 to 5.4 m (the editor's is 2.9 m);
  - time in the air, 40 to 64 frames (the editor's is 28);
  - turns in the air, 1.5 to 3;
  - time down, 88 to 130 frames;
  - hit-stop, 5 to 9 frames;
  - shake, 0.25 to 0.45 m;
  - the ball drive, 30 to 42 m/s.

  A launched robot keeps its speed in the air (no ground friction until it lands). It lands with 45 % of its speed,
  bounces off the low walls with sparks and a clang (`hammer_wall`), and bowls over whoever it lands among (the
  existing skittle rule).
- **The tell:**
  - while the swing charges, the steel head heats to cherry red and the two striking faces to white-hot, in 4 steps;
  - a red ring of the swing's 2.3 m reach lies on the court in front of the swinger;
  - the ring swells and throbs faster as the charge fills;
  - an engine whine starts at the raise.
- **The impact:**
  - two clangs, plus a crash at more than half charge;
  - sparks thrown along the blow, plus a second burst and debris;
  - the camera kick is a shake plus a narrowing of the lens by up to 9 degrees that springs back over 12 frames. It
    is full at your own fight and at least 40 % across the pitch;
  - "BONK!" (or "KA-BONK!!" at three quarters of the charge) is printed where the blow landed, comic style, for 45
    frames;
  - when the captain is the one launched, the lens rises and looks up with him, so he never leaves the frame.
- **The miss:** from the strike on, the hammer's grip tips 62 degrees down, so the head follows through into the
  court. A miss buries it there for the 40-frame recovery (the editor's) in a cloud of dust and debris, with a wooden
  thud.
- **The bots:**
  - they swing at a carrier within 4 m (the editor's was 3.2 m);
  - they also drive a loose ball at goal when it is within 3.2 m in front, they face the goal within 40 degrees and
    they are within 24 m of it;
  - their extra cooldown is 90 frames (the editor's was 200);
  - a carrier who sees a rival raise the hammer passes away 40 % of the time and otherwise sidesteps. The editor's
    carriers only sidestep.
- **The hint line** teaches it once the opening is over: "Hold F: raise the hammer, let go: SMASH".

### Proof of the by-hand hammer (as a person meets it)

**Clip** `clips/hand_hammer.mp4` (19.0 s, window, d3d12, seed 1, `tests/bot_hammer_hand.gd`). It shows:
- my wind-up and hit (frames 56-100);
- my drive of the ball;
- a miss that a blue robot sidesteps (frames 214-270);
- a blue bot's full-charge KA-BONK on me while I carry the ball (frames 1000-1100).

**Stills I looked at:**
- `stills/hand_f70.jpg`: my wind-up. The head is cherry red with white-hot faces, and the red reach ring lies around
  me and the blue carrier. You can see it coming from across the pitch.
- `stills/hand_f88.jpg`: the hit. The blue carrier flies up and back in a fan of sparks, upside down, still holding
  his hammer, and "BONK!" stays where he was standing.
- `stills/hand_my_hit_sheet_f56-144.jpg` (8 frames a tile): raise, swing, launch, a flight of about a second, the
  landing at the goal mouth, and the ball driven off.
- `stills/hand_miss_sheet_f214-270.jpg`: the swing as the blue robot steps out of the ring, then me rooted in a cloud
  of dust while he walks off with the ball. That is the punishment for a miss.
- `stills/hand_bot_hits_me_sheet_f1000-1096.jpg` and `stills/hand_f1040.jpg`:
  - a blue bot's red-hot hammer rises behind me;
  - "KA-BONK!!";
  - I go up about 5 m, limbs spread and spinning, and the lens rises to keep me in frame;
  - I come down by the side wall while the ball rolls away;
  - "E while down: spring up" is on the hint line.

**As a person:** this is a toy I want to press again.
- The ring and the glowing head make the wind-up a promise you can read from across the pitch.
- The blow lands with a freeze, a burst and a word.
- The victim really goes up. Over a second of hang time, spinning, he becomes something you watch rather than a
  stumble.
- Being on the wrong end is funny rather than unfair: I saw the ring, and I could have run.
- What still feels thin:
  - the miss is seen as dust rather than a head stuck in the court, because the camera is behind me;
  - the swing itself is 4 frames and reads as a cut, not an arc;
  - the robots' hammers drag along the ground at rest.

**Headless figures** (`tests/bot_hammer_hand.gd`, 3600 frames = 1 match-minute, seeds 1-3). "Swings/min" is all five
bots together.

| | editor's hammer (discarded) | by hand |
|---|---|---|
| bots' swings/min | 2 / 1 / 4 (0.2-0.8 per bot) | 7 / 7 / 5 (1.0-1.4 per bot) |
| hits / ball drives / misses / dodges (all robots) | 5/3/5/4, 6/5/3/6, 3/2/10/7 | 4/4/8/2, 10/9/1/4, 4/4/9/5 |
| how high a hit robot flies | 2.9 m every time | 3.7-5.4 m, by the charge |
| frames from hit to standing | 95-110 | 103-138 |
| metres from hit to standing (along the ground) | 4.9-19.5 (mostly sliding) | 4.7-19.1 (mostly flying) |
| script errors | 0 | 0 |

- **Determinism:** seed 1, 3600 frames, run twice, gives `ac3f913b63d011cd...` both times. Seed 7 gives
  `6a221ada920abb22...` twice.
- **The pack's own tests** pass on the hand pack, all with 0 script errors:
  - bot_player (1508 f);
  - bot_hand_newcomer (18412 f);
  - bot_hand_perfect (6269 f);
  - bot_mash (19130 f);
  - bot_show (13276 f);
  - bot_hammer_hand.
- `tests/bot_tofu.gd` fails its 36000-frame budget on the hand pack too (2 of 3 matches, 270 s and 244 s each). That
  is the same failure that made the editor discard its hammer. A match with hammers runs about 4-4.5 minutes.

## Editor round 2, after lane T's fix (tree fast-forwarded to main 6c75354c at 04:2x)

foreman/ was rebuilt and the class cache re-imported. I sent the hammer again with its charge, in 240 characters:
> Give every robot a double-headed sledgehammer: hold F to charge, release to swing. The longer I charge, the higher
> and farther the hit robot flies, tumbling, with sparks, a clang. It drives the ball. Misses leave me open. Bots swing, dodge.

The glow, the cooldown and the reach ring did not fit.

- 04:31:17: the change was recorded (event 1132). The Planner named core again.
- **core r16** took 2.1 min, 0.92M tokens in and 7.8k out.
  - **The workspace still held the discarded r13-r15 hammer**, so the builder only added the charge:
    - the charge counts frames held past a 10-frame raise, full at 60;
    - launch 9 to 15 m/s;
    - shove 6 to 12;
    - lift 1.1 to 2.0 times the tackle's 1.8 m;
    - hit-stop 6 to 9 frames;
    - ball 24 to 34 m/s;
    - sparks, clang and shake from 30 % to 100 % of full.

    Flight time stays the tackle's 28 frames.
  - **T's fix showed:**
    - the balance moved by the change is now a note ("built as you asked; warned rival attacks: now 2, was 3. Say
      'make it fairer' to tune it");
    - the builder's edit to the tofu test was undone ("measure kept ... Change the game, never the test");
    - the round **merged at 04:35:16**, with no refusal and no question.
- Brain re-verified. Show's reverify then failed `bot_show`: the end card has no answer for the new loss cause
  "hammered", because the earlier answer was reverted with the discarded change. Show r7 started at 04:38.
- Final verification **passed on the first try**:
  - `bot_tofu` finished within its budget this time (the tap swing is weaker now, so matches fit);
  - the hands ran over 20 seeds each, and the promotion pictures were taken.
- **05:02:37: v0.1.6 promoted**, `promoted/game.robot_soccer_3_v@0.1.6`. This took **31.3 min** from the sentence
  (the Director's stop was 40) and **1.42M tokens in**, 11k out. There was no question, no hold and no loop.
- **The person's notes**, now notes instead of refusals:
  - "balance moved by your change: a newcomer player now wins 9 of 20 (was 17 of 20). Say 'make it fairer' to tune
    it";
  - four "unasked rule" lines.
- **The what-changed line is confusing.** It lists both sentences, including the discarded first one. Three of the
  "unasked rule" lines are the discarded round's notes about tofu bounds that no longer apply ("No files changed this
  round", "close_rounds is not fixed ... this check will fail again"). A person reading them cannot tell what is true
  of v0.1.6.

**The editor made the hammer on the second try** (v0.1.6). It played 3600 frames with 0 script errors and gave the
same hash twice (`4f771e4556bf4a3d...`, seed 1).

Film:
- `clips/editor2_hammer_charge.mp4` (12 s);
- `stills/editor2_my_hit_sheet_f56-144.jpg` and `stills/editor2_bot_hits_me_sheet_f580-668.jpg`, both looked at.

What it is like:
- My quick swing (about 15 frames held, charge about 0.1) looks like round 1's: the rival flies back and lands at the
  goal mouth.
- A bot's swing (released at about 24 frames, charge about 0.25) throws me up about two body heights, spinning. I land
  on my back within half a second, then lie there.
- There is no glow, no ring and no word, so the raise is hard to see at a distance.
- The charge is real in the numbers but short in the eye: flight time stays the tackle's 28 frames, so a full charge
  is higher and farther but not longer in the air.

> blocked-editor (minor): the promoted change's what-changed note mixes in the discarded first attempt's notes (both
> sentences, stale "tofu bound will fail again" lines), so a person cannot tell what v0.1.6 is | evidence: job event
> 1243

## Editor vs hand (what a person meets)

Headless figures are from `tests/bot_hammer_hand.gd`, 3600 frames, seeds 1-3. "Swings/min" is all five bots together.

| | editor v0.1.6 (promoted 05:02) | by hand (`.tl/juice/robot_hand`, 0.1.7) |
|---|---|---|
| made by | Create, 2 sentences (round 1 built then discarded; round 2 promoted) | the editor's discarded round-1 hammer plus my layer |
| the tell | arms up, 24-frame bot raise, an engine whine | the same, plus the head heating to red/white-hot and a red reach ring on the court |
| charge | 10 f to 60 f: speed 9-15, height 1.1-2.0 x 1.8 m, stop 6-9, ball 24-34 m/s | 16 f to 50 f: speed 9-15, height 3.1-5.4 m, air time 40-64 f, 1.5-3 turns, stop 5-9, ball 30-42 m/s |
| how high a hit robot flies (measured) | 2.0-3.6 m | 3.7-5.4 m |
| time in the air | 28 f (the tackle's) | 40-64 f, keeping its speed, bouncing off walls |
| frames from hit to standing | 98-113 | 103-138 |
| metres travelled | 10.6-26.5 (mostly sliding) | 4.7-19.1 (mostly flying) |
| impact | sparks, clang, shake scaled 30-100 % | the same, plus a lens kick, "BONK!"/"KA-BONK!!" at the spot, a crash at more than half charge, the lens rising with a launched captain |
| miss | 40 f rooted, a wood thud | 40 f rooted, the head driven into the court, a dust cloud |
| bots' swings/min | 6 / 5 / 5 | 7 / 7 / 5 |
| bots drive loose balls at goal | no (carriers only) | yes |
| a carrier under a raised hammer | sidesteps | sidesteps, or passes away (40 %) |
| hits / drives / misses / dodges | 3/2/9/4, 4/5/8/8, 5/3/7/2 | 4/4/8/2, 10/9/1/4, 4/4/9/5 |
| newcomer wins (job's 20 seeds) | 9 of 20 (was 17) | not measured over 20 seeds |
| script errors, determinism | 0; same hash twice | 0; same hash twice (`ac3f913b...`) |

**As a person:**
- **The editor's v0.1.6** is a real hammer, and the charge is there in the numbers. It still reads as "a stronger
  tackle with a hammer". The hit is half a second of air, and nothing on the court warns you.
- **The hand version** is the one that reads at a glance:
  - you see the wind-up coming (the glowing head and the ring);
  - the blow lands with a freeze and a word;
  - the victim gets about a second of spinning hang time;
  - a miss leaves you rooted in a dust cloud while the dodger walks off with the ball.

  It is the one I would show as "we can compose any idea".

**The editor made:** the hammer, the swing, the knockback, sparks, clang, hit-stop, shake, the ball drive, the miss
recovery, the cooldown, bot swings and dodges (round 1, discarded), and then the charge (round 2, promoted).

**By hand:**
- the long, charge-scaled flights (air time, turns, wall bounce);
- the glow and the reach ring;
- "BONK!" and the lens kick;
- the buried head;
- bots driving loose balls, and carriers passing away from a raised hammer;
- the lens following a launched captain.
