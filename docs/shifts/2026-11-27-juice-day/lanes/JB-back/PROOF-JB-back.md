# JB-back proof: the hand juice sent back to Create as one sentence each (day of 27 Nov 2026)

Tree `.claude/worktrees/d25-shield` (branch d27-back, from main 8be26d61). I play the person on the editor path: each
sentence went through `engine/ui/foreman_run.mjs` (the Create door) as `foreman change <job> "<sentence>"` with the
`change` flags of `engine/ui/flags/real.json` (claude-cli, Sonnet builders, paid). Times are local (CET+1); job logs
are UTC. Job copies (plain recursive copies, the originals untouched):

| Game | Copied from | Copy in this tree | Version at copy |
|---|---|---|---|
| Robot soccer | `d25-robot/.tl/jobs/robot-soccer-3-v-20261125-1` (last event 1246) | `.tl/jobs/robot-soccer-3-v-20261125-1` | v0.1.6 |
| Shield wall | `d25-shield/.tl/jobs/shield-wall-3-v-20261125-1` (J19's, last event 750) | `.tl/jobs/shield-wall-3-v-20261125-1-jb` | v0.1.7 |
| Arsenal hockey | `d25-arsenal/.tl/jobs/three-against-three-hockey-20261125-1` (last event 1072) | `.tl/jobs/three-against-three-hockey-20261125-1` | v0.1.23 |

How I film and measure (the same for every version): a window run of the pack's own hand test through Godot's movie
writer under the machine's window lock (`.tl/jb/clip2.sh`, J19's clip script), 20 s, seed 1; side-by-side clips with
ffmpeg; headless runs through `engine/tools/tl.sh bot` (`.tl/jb/bot.sh`), 3600 frames, seeds 1-3, seed 1 twice.
Two window runs (robot hand and robot editor v0.1.6) ended with one kernel line, `SCRIPT ERROR: Cannot call method 'lock' on a null value` at
`kernel/runner/worker.gd:387` (`_wd_run`): the watchdog thread outlives its mutex when `--quit-after` ends the window.
It is the runner's shutdown, not the pack (the headless runs of the same packs report 0 script errors).

## The answer, in one paragraph
Yes, mostly. One sentence naming the hand juice, in a person's words, brought each game most of the way to its hand
version, and the one follow-up a person may send closed the biggest gap that was left. **Robots** v0.1.7 (one
sentence, 33 min, one core round) got the glowing head, the ring, BONK!/KA-BONK!!, the camera punch and follow, wall
bounces, loose-ball smashes and pass-aways; v0.1.8 (the follow-up, 32 min) put the ring under every robot and threw
hit robots 3.5-5.0 m (hand 3.7-5.4). **Shield wall** v0.1.8 (58 min) got the lane of rings, BOWLED!/BRACED!/SLAM! in
the middle of the screen, a drawn leap, a rising camera and the F/C buttons, and T's new rivals routing gave the crew
bots their part without a second sentence; v0.1.9 (51 min) made the bots charge as often as the hand version's
(12 / 11 / 6 a minute against 14 / 15 / 6). **Arsenal** v0.1.24 (27 min) got METEOR in the hint, the burning blade,
the fire ring, the fireball, METEOR! and FLOORED!; v0.1.25 (20 min) stopped the meteor off the opening faceoff, put
METEOR on the plate and drew its own net bag and glass. What is still short of the hand versions: a braced charge
stays rare in shield wall (0-2 a minute, hand 3-6), a charge floors fewer men (1-7, hand 8-10); the meteor's net and
glass were built but I never saw a meteor goal on screen; the rink bots still cannot use or block the meteor (C++).
Cost: 6 sentences; 3 h 42 min from sending to promotion, summed over the six (robots 33 + 32, shield 58 + 51, Arsenal 27 + 20 min); about 16.2M tokens in (robots 4.2M, shield 7.4M, Arsenal 4.7M; mostly cache reads), 0.13M out.

## For the menu (pack path and title; the Director copies to proof-games and adds the rows)
| Game | Pack | Title |
|---|---|---|
| Robot soccer | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.8` | Robot soccer: sledgehammer v0.1.8 (made in Create from one juice sentence) |
| Shield wall | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/shield-wall-3-v-20261125-1-jb/promoted/game.shield_wall_3_v@0.1.9` | Shield wall: charge and slam v0.1.9 (made in Create from one juice sentence) |
| Arsenal hockey | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.25` | Arsenal hockey: meteor slapshot v0.1.25 (made in Create from one juice sentence) |

Each of these is the sentence plus its one follow-up. The one-sentence versions, if the owner wants to see what one
sentence alone gave: robots `.../promoted/game.robot_soccer_3_v@0.1.7`, shield `.../promoted/game.shield_wall_3_v@0.1.8`,
Arsenal `.../promoted/game.three_against_three_hockey@0.1.24` (same job folders). Keys: robots F (hold, release);
shield F charge, C slam; Arsenal F lights the stick, hold shoot to wind up.

## 1. Robot soccer: the sledgehammer

### What the hand version has that editor v0.1.6 lacks (played 10:20-10:29)
Packs: hand `C:/Users/kazda/kiro/third-life/.tl/proof-games/robot_hammer_hand` (game.robot_soccer_hand 0.1.7); editor
v0.1.6 from my job copy, with the hand's own test `tests/bot_hammer_hand.gd` added to a film copy (`.tl/jb/robot/ed016`).
Clip `clips/robot_before_editor_vs_hand.mp4` (20 s, editor left, hand right, seed 1); sheets
`stills/robot_ed016_sheet_f56-144.jpg` and `stills/robot_hand_sheet_f56-144.jpg` (my first swing, 8 frames a tile),
`stills/robot_hand_f1040.jpg` (a bot's KA-BONK!! on me), all looked at.

In a person's words, the hand version has and v0.1.6 lacks:
1. the hammer head heating cherry red to white-hot while it charges;
2. a red ring on the court showing the swing's reach, swelling and throbbing faster as the charge fills, under every
   robot that winds up (you see a rival's swing coming);
3. a hit robot that really flies: up to a second in the air, 3.7-5.4 m high, spinning, keeping its speed, bouncing
   off the walls with sparks and bowling over whoever it lands on (v0.1.6: 2.0-3.6 m, half a second, then a slide);
4. BONK! / KA-BONK!! printed where the blow lands;
5. a lens punch on the hit, and the camera looking up and following me when I am the one launched;
6. a miss driving the head into the court in a cloud of dust;
7. bots smashing loose balls at goal, and a carrier who sees a hammer go up passing away;
8. the hint "Hold F: raise the hammer, let go: SMASH".

### The sentence (768 characters, sent 10:30:07, event 1247)
> Make the hammer hit like Smash Bros: while I charge, the hammer head heats from cherry red to white-hot and a red
> ring on the ground shows its reach, swelling and pulsing faster as the charge fills. A robot I hit should fly high
> and long, up to a second in the air at full charge, spinning two or three times, keeping its speed, bouncing off the
> walls with sparks and bowling over whoever it lands on. Print BONK! where the blow lands, KA-BONK!! for a big one,
> and punch the camera in; when I am the one launched, the camera looks up and follows me. A miss drives the head
> into the ground in a cloud of dust. Bots should also smash loose balls at goal with the hammer, and a carrier who
> sees a hammer go up should pass the ball away. Add a hint: Hold F, let go: SMASH.

### What the editor did (v0.1.7)
- The Planner (4 s, 4.2k tokens) named **core**. **core r17**: 5.9 min, 3.17M tokens in (3.05M cache reads), 24k out,
  files `scripts/sim/hammer.gd`, `scripts/sim/sim.gd`, `scripts/view/show.gd`, `gen/robot.gd`, `data/tuning.json`.
  Its note, in short: five heat colours on every robot's head; a red ring "under you" that grows and pulses faster;
  flight time per robot, 30-60 frames by charge, 1-3 spins, speed kept in the air; a new `wall_bang` bounce that keeps
  80 % of the speed and may bowl one more robot; BONK!/KA-BONK!! as floating 3D text; a camera punch on your own hits
  and a look-up when you are launched; dust on a miss; bots smash loose balls when they face the rival goal within 60
  degrees; a carrier within 6 m of a raised hammer passes away; the hint after the opening. It also said the contract
  forbade words at a hit ("the change request wins").
- Merged 10:38:50, no refusal, no question. Notes instead of refusals: "balance moved by your change: frames a side
  keeps the ball: now 236, was 273", and in final verification "matches now run longer (the Foreman's test needed
  about 1.2 times the frames it planned)" after one bot_tofu run ran out of frames (it then finished in 42687 frames).
- **v0.1.7 promoted 11:03:32**, 33.4 min from the sentence, one builder round: about 3.17M tokens in, 24k out.
  The promoted pack is file for file the one I measured and filmed (`diff -rq`: only my added test and its manifest line).

### Judged against the hand version (11:00-11:05)
Clip `clips/robot_v017_vs_hand.mp4` (20 s, Create v0.1.7 left, hand right, seed 1). Sheets I looked at:
`stills/robot_ed017_sheet_f56-144.jpg` (my swing), `stills/robot_ed017_bot_hits_me_f996-1095.jpg` beside
`stills/robot_hand_bot_hits_me_f996-1095.jpg` (a bot's hit on me), `stills/robot_ed017_f200-332.jpg` (a bot winding up).

| juice part (hand) | v0.1.6 | Create v0.1.7 (one sentence) |
|---|---|---|
| head heats red to white-hot | no | **yes**, every robot |
| red reach ring that swells and throbs | no | **half**: only under my robot; a rival's wind-up shows the red head but no ring |
| a hit robot flies long, spins, keeps speed | no (28 f) | **yes at a strong charge** (a bot's hit throws me cartwheeling into the side wall); an ordinary hit still measures 2.0-3.6 m high, the same as v0.1.6 (hand 3.7-5.4) |
| wall bounce with sparks, bowling on landing | no | **yes** (`wall_bang`) |
| BONK! / KA-BONK!! at the blow | no | **yes** (white floating text; the hand's is yellow comic text) |
| lens punch; camera follows me when launched | no | **yes** (the camera swings up and round to keep me in frame) |
| miss: head into the court, dust | wood thud | **dust yes**; the head into the court not visible from behind |
| bots drive loose balls; carriers pass away | no | **yes** (bot ball smashes 6-7 a minute; dodges 3-7) |
| hint "Hold F, let go: SMASH" | no | **yes**; it prints on top of the "Hammered: dodge off its line or pass" / "E while down" line (overlapping text) |

Headless (`tests/bot_hammer_hand.gd`, 3600 frames, 0 script errors on every run):

| | hand | editor v0.1.6 | Create v0.1.7 |
|---|---|---|---|
| bots' swings a minute (all five), seeds 1/2/3 | 7 / 7 / 5 | 6 / 5 / 5 | 12 / 8 / 6 |
| hits / ball drives / misses / dodges, seed 1 | 4 / 4 / 8 / 2 | 3 / 2 / 9 / 4 | 7 / 7 / 7 / 7 |
| how high a hit robot flies (all seeds) | 3.7-5.4 m | 2.0-3.6 m | 2.0-3.6 m |
| frames from hit to standing | 103-138 | 98-113 (and one outlier of 1140, not looked into) | 83-113 |
| seed 1 hash, twice | `f5f4e2e8b8c5f683` x2 | `4c30c827f0819b24` x2 | `27cbe84a35b6e571` x2 |

**As a person:** one sentence moved v0.1.7 most of the way to the hand version. The wind-up now glows, the hit has a
word, the camera punches and follows me when a bot launches me into the wall, and the bots use the hammer more than
the hand version's bots do. What I still miss: I cannot read a rival's swing from across the pitch (no ring under him),
and an ordinary hit still looks like a tackle hop. The editor read "up to a second in the air at full charge" exactly:
only a full charge flies long, and nobody (bot or my hand) holds that long in play.

### The one follow-up (443 characters, sent 11:04:21, event 1343)
> Two things are still missing: I cannot see a rival's swing coming, because the red reach ring shows only under me,
> so draw it under every robot that raises a hammer; and a quick swing still just hops the robot it hits, so even the
> smallest hit should launch it higher than its own height with a clear moment in the air, and a full charge much
> higher still. Also the two hint lines at the bottom print on top of each other; show one at a time.

- The Planner (4 s) named core. **core r18**: 3.2 min, 2 files (`scripts/view/show.gd`, `data/tuning.json`): one ring
  per robot under anyone in `hammer_raise`; `hammer.lift` 1.1 -> 1.6, `lift_max` 2.0 -> 2.8, `fly_min` 30 -> 38 ("the
  weakest swing now throws a robot to about 2.9 m ... a full charge about 5 m"); the hammer hint goes blank while the
  other package's cue line or end card shows. Merged 11:10:13; the note says "waves of rival pressure: now 0, was 2"
  (a balance note, not a refusal).
- Measured on the merged pack (seeds 1-3, 3600 frames, 0 script errors; seed 1 `d7325572e8968dda` twice): a hit robot
  now flies **3.5-5.0 m** high (hand 3.7-5.4; v0.1.7 2.0-3.6); bots swing 11 / 10 / 11 a minute.
- In the window (`clips/robot_v018_vs_hand.mp4`, Create top, hand bottom; `stills/robot_ed018_f200_f200-332.jpg`,
  `robot_ed018_my_f56-144.jpg`, looked at): a blue bot winding up now has its own red ring swelling on the grass, as in
  the hand version; my first KA-BONK!! throws the Docker up above the goal's crossbar.
- **v0.1.8 promoted 11:36:28**, 32.1 min from the follow-up, one builder round: 1.01M tokens in, 8k out. The promoted
  pack is file for file the merged pack I measured and filmed. Final verification passed first time.

## 2. Shield wall: the charge, the brace and the slam

### What the hand version has that editor v0.1.7 lacks (played 10:31-10:36)
Packs: hand `C:/Users/kazda/kiro/third-life/.tl/proof-games/shield_charge_hand` (game.shield_wall_3_v 0.2.0, test
`tests/bot_juice_hand.gd`); editor v0.1.7 with J19's measuring hand `tests/bot_juice_editor.gd` added (`.tl/j19/ed3`, copied
to `.tl/jb/shield/ed017`). Clip `clips/shield_before_editor_vs_hand.mp4` (20 s, editor top, hand bottom, seed 1, frames
330-1530); stills `stills/shield_hand_bowl_f535-623.jpg` (Finn's charge bowls two: BOWLED! twice, the lane of red
dashes), `stills/shield_hand_slam_f392-480.jpg` (my leap, the red landing ring, SLAM!, the dust),
`stills/shield_ed017_overview.jpg` (the editor's 20 s, a tile every 48 frames), all looked at.

In a person's words, the hand version has and v0.1.7 lacks:
1. a charger crouching behind his shield with a dust kick, and a lane of red rings ahead for the whole run (v0.1.7:
   a red strip only while he crouches);
2. victims flying up and back off the line with a full spin, BOWLED! over each, a crack, sparks and dust, a slow
   get-up, the charge running on to the next man (v0.1.7: they slide and fall);
3. a brace that stops the charge dead: a big clang, gold sparks, BRACED!, the charger bouncing back wide open (v0.1.7:
   the rule exists, 0-2 braces a minute, nothing on screen names it);
4. a slam that is a real leap (2.6 m, 40 frames, weapon cocked) with the camera rising, a red landing ring that throbs
   as he falls, SLAM!, a dust ring and a shock wave that throws everyone out, a big shake (v0.1.7: a hop forward);
5. bots that charge and slam often and brace or sidestep a charge;
6. F and C on the HUD, READY or counting down.

Headless (3600 frames, seeds 1/2/3, 0 script errors on every run):

| | hand (`bot_juice_hand.gd`) | editor v0.1.7 (`bot_juice_editor.gd`) |
|---|---|---|
| bots' charges a minute | 14 / 15 / 6 | 3 / 4 / 2 |
| bots' slams a minute | 11 / 4 / 8 | 8 / 6 / 12 |
| floored by a charge | 10 / 9 / 8 | 2 / 5 / 1 |
| charges braced | 5 / 6 / 3 | 0 / 0 / 2 |
| seed 1 hash | `e0b41355a5253458` (J19's night figure too) | `d7211da4317c8ffe` (J19's night figure too) |

### The sentence (798 characters, sent 11:32:07 after the fast-forward to T's fixes, event 751)
> Make the charge and slam hit like Gang Beasts. A charger crouches behind his shield with a dust kick, and a lane of
> red rings lies ahead of the run. Everyone the charge hits flies up and back off the line with a full spin, BOWLED!
> over him, a crack, sparks and dust, and gets up slowly; the charge runs on to the next man. A raised shield facing
> it stops it dead with a big clang, gold sparks and BRACED!, and the charger bounces back wide open. The slam is a
> real leap, higher than a man for near a second, weapon cocked, the camera rising too; the red ring throbs as I
> fall, and the landing shows SLAM!, a dust ring and a shock wave that throws everyone in it out, a big shake. All
> bots charge and slam often, brace or sidestep a charge, and run out of the ring. Show F and C READY or counting down.

- The Planner named **core**, and T's rivals routing (new today) at once gave **crew** "the rivals' part of change
  request 751, for the bots your files drive (scripts/crew/mind.gd)", to run after core's merge (events 754-758).
  Last night J19 needed a second sentence for that.

### What the editor did (shield v0.1.8)
- **core r17** (3.4 min, 1.71M tokens in, 14k out; `scripts/show.gd`, `scripts/camera.gd`, `data/tuning.json`,
  `data/moves.json`, `data/ai.json`), merged 11:40:48:
  - the charge: a puff of dust at the crouch and a lane of five red rings ahead until the run ends; each victim flies
    1.1 m up with a full turn (drawn: "they lift and turn the rig node and never move the physics body"), a crack,
    orange sparks, dust, a shake and **BOWLED!** big mid-screen; BRACED! with a clang and gold sparks on a brace;
  - the slam: a drawn leap up to 2.2 m over the 54-frame wind-up, weapon cocked, the camera rising with the captain,
    the red ring throbbing faster as he falls, **SLAM!**, a dust ring and the shock wave;
  - F and C buttons beside RMB / LMB / Q, READY or the seconds;
  - the crouch 18 -> 22 frames (a tell of at least 20), Bram's `rush_p` 0.3 -> 0.45 and `slam_p` 0.6 -> 0.8;
  - honest: "Your rivals didn't charge in the test run ... I can't vouch for those effects until you play it", and
    NOT DONE: the crew's rates are in `data/crew.json`, another package's.
- **T's two new routes both fired, into the same package:** the rivals' part of the sentence went to crew at once
  (event 754), and core's NOT DONE was handed to crew too (event 773).
  - **crew r5** (2.7 min, 0.65M in): `rush_p` 0.3 -> 0.45, `slam_p` 0.35 -> 0.5, `rush_from` 2.6 -> 2.2 m, `crowd`
    2 -> 1, a new 35 % sidestep off a charge line.
  - **crew r6** (2.9 min, 0.65M in): T's "a new attack must land in the bot run" sent it back. It changed its own
    `tests/bot_crew.gd` so the scripted captain charges and slams and the test counts `metrics.moves`: "rush landed 2
    of 4, slam landed 18 of 30". Its own words: a first version where the captain used the moves three times as often
    failed the light-mashing round, so it made the test's captain use them less ("treat that check as fragile").
  - **crew r7** (5.2 min, 0.71M in): the NOT DONE hand-off arrived after r5 had already done it: "No change this
    round. The requested values are already in place". The Foreman still logged "merge crew 7 files"; the pack is
    byte-equal before and after (checked with `diff -rq`).
- **v0.1.8 promoted 12:30:22**, 58.3 min from the sentence; 3.71M tokens in, 29k out over five builder runs (Planner,
  core r17, crew r5, r6, r7). The promoted pack is file for file the merged pack I measured and filmed.

### Shield v0.1.8 judged (12:05-12:30)
Clips `clips/shield_v018_vs_hand.mp4` (Create top, hand bottom, seed 1, frames 330-1530) and
`clips/shield_v018_oda_charge_bowls_pip.mp4` (2.7 s); stills `stills/shield_ed018_overview.jpg` and
`stills/shield_ed018_oda_rush_f3260-3348.jpg`, looked at. Oda crouches with the red ring lane in front, runs, and Pip
goes up off the stones with a turn while a big red BOWLED! fills the middle of the screen; my F button greys out and
counts down. SLAM! comes up red and big in the middle of the fights, and the F and C buttons sit beside Q.

| juice part (hand) | v0.1.7 | Create v0.1.8 (one sentence) |
|---|---|---|
| crouch with a dust kick; lane of red rings for the whole run | red strip while crouching | **yes** (five rings, the whole run) |
| victims fly up with a full spin, BOWLED!, crack, sparks, dust | slide and fall | **yes**, but low (1.1 m, drawn on the rig; hand 1.6 m) |
| the charge runs on through a line | yes (r3) | yes |
| brace: dead stop, clang, gold sparks, BRACED! | rule only | **yes on screen**, but rare (0-3 charges into a shield a minute) |
| slam: a real leap with the weapon cocked, the camera rising | a hop | **drawn leap 2.2 m**, camera rises |
| red ring throbbing as he falls; SLAM!, dust ring, shock wave, shake | ring, knockdown | **yes** |
| bots charge and slam often, brace or sidestep | charge 3/4/2, slam 8/6/12 | charge 4/3/6, slam 8/8/7 a minute; a 35 % sidestep (crew) |
| F and C READY or counting down | no | **yes** |

Headless (`tests/bot_juice_editor.gd`, 3600 frames, 0 script errors): floored by a charge 1 / 3 / 2, charges into a
shield 0 / 2 / 3, floored by a slam 5 / 7 / 6; seed 1 `626cab5f5bb62d37` twice. Hand version (`bot_juice_hand.gd`):
charges 14 / 15 / 6, bowled 10 / 9 / 8, braced 5 / 6 / 3.

**As a person:** the words, the lane and the buttons now say what is happening, which v0.1.7 never did. The charge
still rarely happens and rarely floors anyone, and a braced charge is a rare sight. That is what the follow-up asks.

### The one follow-up (426 characters, sent 12:32:40, event 866)
> The charge is still rare and rarely lands. Bots should charge an open line several times a minute each, and the
> charge should bowl over everyone within a step of its line, not only the man straight in front, throwing each one
> higher than his own head before he lands. Braces are so rare I never see BRACED!: a rival who sees a charge coming at
> him should turn his raised shield to it most of the time, and the rest step aside.

- The rivals' part went to crew again at once (event 869). Its quoted text lost a sentence: "... before he lands. : a
  rival who sees ..." (the words "Braces are so rare I never see BRACED!" are cut out of the crew's copy).
- **core r18** (3.6 min, 1.55M in): `rush.width` 1.1 -> 1.6 m, the drawn throw `fly_h` 1.1 -> 2.1 m and 50 frames,
  the ring lane wider; Bram's `rush_p` 0.45 -> 0.7, a new `brace_p` 0.8; and the cause of the missing BRACED!: "while
  blocking, a computer-run fighter turns his shield to face a charge on his line, even if he is locked on someone
  else. Without this a raised shield usually pointed the wrong way". Its NOT DONE (the crew's brace numbers) was
  handed to crew.
- **crew r8** (4.9 min, 0.88M in): `rush_p` 0.45 -> 0.7, `brace_k` 0.3 -> 0.5, `sidestep_p` 0.35 -> 0.2, `rush_from`
  2.2 -> 2.5; "rush landed 6 of 21" in the Foreman's bot run.
- **rally r3** (2.4 min, 0.69M in), reopened because its `bot_call`/`bot_crew` check failed on the merged pack after
  core r18: it changed nothing and found every check passing on the current files ("the verifier ran against files
  from before crew round 8"). Its `bot_call` passes on these files: the captain's first call at frame 420, two
  floored, both mates charging together (last night's hand version fails that test; ask 5 of the night verdict).
- **crew r9** (6.0 min, 0.57M in): the NOT DONE hand-off arriving after r8 had already done it, the second time today:
  "All three were already in place in the working copy; no file was edited this round."

**Measured on the merged pack** (`tests/bot_juice_editor.gd`, 3600 frames, seeds 1/2/3, 0 script errors; seed 1
`1ffe169a89f2b43f` twice):

| | hand | v0.1.7 | v0.1.8 | v0.1.9 |
|---|---|---|---|---|
| bots' charges a minute | 14 / 15 / 6 | 3 / 4 / 2 | 4 / 3 / 6 | **12 / 11 / 6** |
| bots' slams a minute | 11 / 4 / 8 | 8 / 6 / 12 | 8 / 8 / 7 | 12 / 15 / 13 |
| floored by a charge | 10 / 9 / 8 | 2 / 5 / 1 | 1 / 3 / 2 | 3 / 7 / 1 |
| charges into a raised shield (braced) | 5 / 6 / 3 | 0 / 0 / 2 | 0 / 2 / 3 | 2 / 0 / 0 |
| floored by a slam | 15 / 11 / 7 (slammed) | 6 / 4 / 12 | 5 / 7 / 6 | 16 / 17 / 11 |

(The two hands differ: `bot_juice_hand.gd` and `bot_juice_editor.gd` play the same captain but each counts from its
own pack's events, so read the rows as the same kind of count, not the same instrument.)

**In the window** (`clips/shield_v019_vs_hand.mp4`, seed 1 frames 1100-2300; stills
`stills/shield_ed019_charge_bowled_f1190-1250.jpg`, `shield_ed019_my_leap_slam_f2150-2210.jpg`,
`shield_ed019_f1490-1550.jpg`, looked at; the window run does not follow the headless frame list move for move):
a charge through a knot of fighters throws a Gull up past the others' heads under a big BOWLED!; my slam goes up
above the crowd with the camera rising, the red ring of dashes on the stones, SLAM!, two men thrown out of the dust.
The bots now charge as often as the hand version's do; a braced charge is still a rare sight.
- **v0.1.9 promoted 13:23:23**, 50.7 min from the follow-up; 3.68M tokens in, 28k out over five builder runs (Planner,
  core r18, crew r8, rally r3, crew r9). The promoted pack is file for file the merged pack I measured and filmed.

## 3. Arsenal hockey: the meteor slapshot

### What the hand version has that editor v0.1.23 lacks (played 10:37-10:47)
Packs: hand `C:/Users/kazda/kiro/third-life/.tl/proof-games/arsenal_meteor_hand` (test `tests/bot_meteor.gd`); editor
v0.1.23 from my job copy with J1's blind hand `tests/bot_meteor_blind.gd` added (byte-equal to J1's
`.tl/j1-raw/editor_v0123`, copied to `.tl/jb/arsenal/ed0123`). Clip `clips/arsenal_before_editor_vs_hand.mp4` (20 s,
editor top from frame 600, hand bottom from frame 300, seed 1); stills `stills/arsenal_hand_goal_f1310-1398.jpg` (STICK ON
FIRE, WINDING UP 2 % / 20 % in the heat ring, METEOR!, the fireball, GOAL, "METEOR BACK IN 11") and
`stills/arsenal_ed0123_shot_f850-938.jpg` (the editor's meteor straight off the faceoff drop: DROP, WON, a flash on the
keeper, GOAL from centre ice; the hint says "F: CANNON Your next shot flattens", the plate "F: SHOTGUN 12s"), looked at.

In a person's words, the hand version has and v0.1.23 lacks:
1. one name: METEOR on the plate and in the hint (v0.1.23: CANNON in the hint, SHOTGUN on the plate);
2. a burning stick blade with sparks once F lights it;
3. a ring of fire that grows round me while I hold shoot, pulsing when full, with WINDING UP and the percent;
4. on release a white-hot flash, a boom, a camera kick and METEOR! over me;
5. a fireball puck with a long fire trail, sparks and smoke (v0.1.23: flame puffs every 3 frames);
6. on every skater it floors a burst of fire, a clang and FLOORED!;
7. a goal that bulges the net and rattles the glass (by hand too small to see from the follow camera; the sentence asks
   for a full metre and glass you can see);
8. "METEOR BACK IN" with the seconds;
9. no meteor off a faceoff (v0.1.23 seed 1 fires it at frame 92 off the opening drop, and at 869 off a later drop,
   which scores from centre ice in the sheet).
Not asked: bots lighting their own meteor or diving to block it. The rink core cannot do either (C++, S4-core's spike).

Headless (3600 frames, seeds 1/2/3, 0 script errors on every run): the hand fires 3 / 5 / 2 meteors (goals 1 / 1 / 2,
skaters floored 3 / 2 / 0); the editor pack's blind hand fires the cannon 4 / 4 / 4 times, the first of each run at
frame 92 off the opening faceoff. Bots' meteors: 0 in both (the core).

### The sentence (743 characters, sent 11:32:58 after the fast-forward, event 1073)
> Make the meteor look and sound like one, NHL Hitz style, and call it METEOR everywhere, not cannon or shotgun. When I
> light it with F my stick blade burns with flame and sparks; while I hold shoot a ring of fire grows round me and
> pulses when full, with WINDING UP and the percent in the hint. On release: a white-hot flash, a boom, a camera kick
> and METEOR! over me; the puck becomes a fireball with a long fire trail, sparks and smoke. Every skater it floors gets
> a burst of fire, a clang and FLOORED! over him. A meteor goal makes the net bulge back a full metre and the glass
> shake hard enough to see, with fire and confetti in the mouth. Show METEOR BACK IN and the seconds. No meteor off a
> faceoff: F lights only a second after the drop.

- The Planner named **harbour** (the drawing package, which also runs the hint and the input), harbour r16.

### What the editor did (v0.1.24)
- **harbour r16** (3.5 min, 1.69M tokens in, 17k out; `scripts/harbour_toys.gd`, `scripts/harbour.gd`,
  `data/tuning.json`, `tests/bot_harbour.gd`): drawn from the core's snapshot, so the game is unchanged (the core hash
  of every seed is the same as v0.1.23's: `dec45815...`, `fa74e2b1...`, `b06af959...`). Flame and sparks at the blade
  when lit; a ring of fire that grows with `ChargeFrames` and pulses when full; on release a white flash, sparks, a boom,
  a 0.25 m kick and METEOR! over the shooter; a fireball puck (flame every frame, sparks, smoke); FLOORED! and a fire
  burst and clang on each floored skater; a goal flash, fire and confetti and a 0.4 m kick; the hint now F: METEOR,
  METEOR LIT - HOLD SHOOT, WINDING UP n%, METEOR BACK IN n. It also changed `tests/bot_harbour.gd` (its own test) to
  accept the lit meteor as the answer to F, since the cartridge has no bubble since v0.1.23; named in its note.
- Its two NOT DONE lines, and what T's hand-off (new today) did with them:
  - "the net bulges ... and the glass shakes": the net and glass are the base's (`scripts/match_view.gd`, the kit's
    rink). **Not handed on**; the person reads it in the note. (By hand, J1 drew its own net bag and 66 panes.)
  - "F lights only a second after the drop": "a rule, not drawing ... `scripts/human_input.gd` is outside my scope".
    **Handed to cartridge** (event 1097), with six candidate keys from the catalog. **cartridge r13** (0.35M in) read
    them all and changed nothing: no key holds F after a drop. So the hop reached a package that could not do it.
    The real owners: `scripts/human_input.gd` is the base's (`scripts/**`), and `scripts/main.gd`, where J1 put the
    same gate by hand (filtering the person's own F key), is **harbour's own file**.
- **v0.1.24 promoted 12:00:22**, 27.4 min from the sentence; 2.06M tokens in, 21k out (Planner, harbour r16,
  cartridge diff try and r13). The promoted pack is file for file the one I measured and filmed.

### v0.1.24 judged (11:58-12:02)
Clip `clips/arsenal_v0124_vs_hand.mp4` (Create top from frame 600, hand bottom from frame 300, seed 1); sheet
`stills/arsenal_ed0124_shot_f850-938.jpg`, looked at: the faceoff, DROP, WON, and straight off the drop a meteor: the
flash, METEOR! and FLOORED! over the far skaters (they stack under the MATCH 1 banner at the top), the fireball, GOAL.
The hint says "F: METEOR" and "METEOR BACK IN 12"; the corner plate still says "F: SHOTGUN 12s".
Headless (`tests/bot_meteor_blind.gd`, 3600 frames, 0 script errors): meteor releases at 92 / 869 / 2064 / 3072 (seed 1),
meteor goals at 130, 907, 2075, 3110: the first two come straight off faceoff drops. Seed 1 `00d115e546d43734` twice.

### The one follow-up (392 characters, sent 12:02:44, event 1141)
> Three things are still wrong. I can still light the meteor at a faceoff and score straight off the drop, so ignore my
> F key until a second after each drop. The plate in the corner still says SHOTGUN; call it METEOR there too. And on a
> meteor goal the net and the glass do not move at all: draw a net bag and glass panes of your own that bulge back and
> rattle big enough to see from my camera.

- The Planner named harbour for all three. **harbour r17** (4.8 min, 2.59M in, 19k out; `scripts/main.gd`,
  `scripts/harbour_toys.gd`, `data/tuning.json`, `tests/bot_harbour.gd`):
  - "RULE: after each drop, the player's F key is not passed to the core until `f_lock_after_drop_f` (60) frames have
    gone by ... `scripts/main.gd` `_lock_f` removes F from the raw input" (the same place and the same way J1 did it by
    hand). It says plainly that this changes play and the core hash, and that its own drill still saw the meteor lit
    in the first second after a drop (77 frames over 5 drops), cause not found;
  - the plate's names set each frame from `harbour.meteor.plate_names` ("F: METEOR ...");
  - its own net bag at each net (hidden until a meteor goal, then bulging 1.0 m back for 48 frames) and a row of glass
    panes over each end board that rattle up to 0.22 m and 5 degrees for 54 frames; "not checked on screen".
- **v0.1.25 promoted 12:22:48**, 20.1 min from the follow-up; 2.60M tokens in, 19k out.
- Measured (`tests/bot_meteor_blind.gd`, 3600 frames, seeds 1-3, 0 script errors; seed 1 `75547f8a1a99b7c8` twice):
  the first meteor of each run now comes at 333 / 706 / 397 (v0.1.24: 92, 92, 92, off the opening drop). I did not
  log the later drops' frames, so the lock is shown for the opening drop only. Meteor releases a minute: 3 / 3 / 2.
- In the window (`clips/arsenal_v0125_vs_hand.mp4`, `stills/arsenal_ed0125_meteor_f310-442.jpg`, looked at): the
  plate reads "F: METEOR READY", the hint "F: METEOR Light your stick, then hold shoot to wind up"; a meteor in open
  play floors two skaters with a fireball, sparks, METEOR! and FLOORED! over them, and "METEOR BACK IN 12".

### Arsenal: the juice parts against the hand version

| juice part (hand) | v0.1.23 | Create v0.1.24 (one sentence) | Create v0.1.25 (+ follow-up) |
|---|---|---|---|
| one name, METEOR | CANNON / SHOTGUN | hint yes, plate still SHOTGUN | **yes**, plate too |
| burning blade, sparks when lit | a puff at the feet | **yes** | yes |
| fire ring growing with the wind-up, pulsing full; WINDING UP n% | no | **yes** (not seen: the blind hand never winds up) | yes (same) |
| release: flash, boom, kick, METEOR! | no | **yes** | yes |
| fireball puck, fire trail, sparks, smoke | puffs every 3 frames | **yes** | yes |
| FLOORED!, fire burst, clang on each floored skater | flash, kick | **yes** (words stack under the top banner when far away) | yes |
| net bulge, glass rattle on a meteor goal | no | NOT DONE (said so) | **built** (own bag 1.0 m, own panes); **not seen**: no meteor goal in my two window takes |
| METEOR BACK IN n | no | **yes** | yes |
| no meteor off a faceoff | scores off the drop | NOT DONE (the hop went to the cartridge, which could not) | **yes** for the opening drop (first meteor at 333 / 706 / 397, was 92) |
| bots light or block a meteor | cannot (core) | cannot | cannot |

**As a person:** v0.1.25 reads as a meteor. You see it lit, you see it fly as a fireball, the word over the shooter and
over each man it floors tells you what happened, and the name is METEOR everywhere. The faceoff gift is gone from the
opening drop. What I could not check: the net bag and the glass (no meteor goal in my takes, and the builder did not
check them on screen either), and the wind-up ring (the editor pack has no read-out a hand can use to hold a charge).
One thing for the owner's eye: in one take (seed 2, about frame 1820) the camera dips behind my own net and looks
down at the ice with a big pale pane at the edge of the frame (`.tl/jb/stills/arsenal_ed0125_s2_f1820.jpg`); I did
not check whether that pane is one of the new ones or how v0.1.24 frames the same spot.

## What T's fixes did today, and what the editor still gets wrong (for the Director and lane T)
- **Rivals routing works.** Both shield sentences sent the rivals' words to crew at once (events 754, 869); last night
  J19 needed a second sentence for it.
- **The NOT DONE hand-off works, but it duplicates.** In shield wall, core's NOT DONE went to crew while crew already
  had the rivals' part of the same sentence. Crew then ran a second round that found its own work already done, twice
  today: crew r7 (5.2 min, 0.71M in) and crew r9 (6.0 min, 0.57M in). Suggestion: when a hand-off targets a package
  that already holds a request from the same change, merge it into that request, or skip it once that package's round
  has merged.
- **The hand-off can reach the wrong owner.** Arsenal's "F lights only a second after the drop" went from harbour to
  the cartridge (the hop "to the cartridge's owner"), which has no key for it and changed nothing. The file harbour
  named (`scripts/human_input.gd`) is the base's, and harbour's own `scripts/main.gd` could do it (it did, in r17,
  after my follow-up named the symptom again).
- **A NOT DONE with no owner is just a note.** Arsenal's "net bulges ... glass shakes" (the base's net and the kit's
  rink) was not handed anywhere in r16. The follow-up's "draw ... of your own" made harbour build it.
- **The rivals' copy can lose a sentence.** Event 869's text reads "... before he lands. : a rival who sees ...": the
  sentence "Braces are so rare I never see BRACED!" was cut out of crew's copy.
- **"merge crew 7 files" / "merge rally 8 files" when the builder wrote nothing** and the pack is byte-equal: the count
  is misleading in the log a person may read.
- **A builder changed its own test's hand to make a check pass** (shield crew r6: "my first run had the captain
  charging and slamming about three times as often. That run failed ... Using the moves less often fixed it"). It said
  so; the test is a crew test the T freeze does not cover.
- **Literal reading.** "Up to a second in the air at full charge" gave long flights only at full charge, which play
  rarely reaches (robots v0.1.7); "a red ring ... shows its reach" while "I charge" gave a ring only under me. A person
  meets both gaps at once; the follow-up fixed both in one round.

## Gates
- `node devx/bin/tl.mjs check --tier fast` on this tree (main 658eb637 + my docs), 12:43: **PASS**, 5/5 steps:
  arch 12/12, assets 4/4, cards 3/3, devx.test 230/230, foreman.typecheck clean.
- No code changed by this lane (docs and `.tl/` only), so no full tier.
- Every editor version above: 3600 headless frames on seeds 1-3 with 0 script errors, seed 1 run twice with the same
  hash; every promoted pack is file for file the one measured (only my added measuring test and its manifest line
  differ). Window runs: three of them ended with the runner's `_wd_run` shutdown line (see the top), the rest 0.

## Where things are
- Lane folder (this folder): `SENTENCES.md`, `STANDUP.md`, `REPORT.txt`, `clips/` (10 clips, 960 wide, crf 30-34,
  20 s or less; top = the editor's version, bottom = the hand version), `stills/` (sheets and frames I looked at).
- Raw captures, film copies and measuring runs: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jb/`
  (`robot/`, `shield/`, `arsenal/`: the `*_s<seed>.json` reports; `clips/` full-size takes; `bot.sh`, `clip2.sh`,
  `vs.sh`). Job logs: `.tl/jobs/_ui_logs/*-jb-*.log`.

---

# Round 2 (27 Nov, 13:29-14:3x): a meteor goal on film, shield braces, robots' words

## 4. Arsenal v0.1.25: a meteor goal, the net bag and the glass
**How I got a goal on film.** The blind hand on v0.1.25 never scored a meteor in my takes. On a film copy only
(`.tl/jb/arsenal/ed0125g`, the promoted pack plus the blind hand with two numbers changed: F within 19 m instead of
30, a full wind-up from 15 m instead of 26) it scores a meteor goal in every headless seed (frames 508 / 3518 / 2158 /
2436, seeds 1-4, 0 script errors). Its window take of seed 1 (`.tl/jb/clips/arsenal_ed0125g_s1.mp4`, 40 s) scores the
same goal at the same moment (window runs of one pack and seed repeat each other exactly; they differ from headless
runs of that hand, because the hand steers by the camera's yaw).

Clip `clips/arsenal_v0125_meteor_goal.mp4` (5.5 s, 960 wide); stills `stills/arsenal_g_s1_goal_f470-602.jpg` (6
frames a tile) and `stills/arsenal_g_s1_net_crops.jpg` (the net at frames 548, 560, 580, 600), looked at:
- The shot reads: METEOR! over me, the fireball, the keeper floored with FLOORED! over him, GOAL, the fire and confetti
  in the mouth, and the camera swinging round to the net.
- **The net bag:** for a moment (about frame 548) a **solid white box** stands out behind and above the goal frame,
  then it is gone by 560. It does not read as a net bulging: it reads as a white block popping out of the goal. From
  the follow camera, about 25-30 m away when the puck goes in, it is visible but not as a net.
- **The glass:** the panes are a pale grey, see-through band above the end boards. Across frames 536-600 I cannot see
  them move; a rattle of 0.22 m at that distance does not show.
- **The pale pane of round 1** (`stills/arsenal_ed0125_s2_f1820.jpg`): **yes, it is one of the new panes.** A copy with
  the panes turned off (`glass_half_w_m` 0, everything else equal) filmed the same seed: at frame 1820 the frame is
  identical except that the pale rectangle over my own net is gone (`stills/arsenal_ed0125_s2_f1820_panes_vs_nopanes.jpg`).
  The same check at the goal (`stills/arsenal_g_s1_panes_vs_nopanes.jpg`) shows the pane band over the end boards, and
  the bag the same in both. So when the camera swings behind my own net the new glass lies across the view: a defect of
  v0.1.25 for the owner to know. (The hand version also has its own glass, J1's 66 panes on the straight runs.)

**As a person:** the meteor goal is a moment now (word, fireball, floored keeper, fire and confetti), but the net and
the glass do not read as a net and glass: a white block and a band I cannot see move. One sentence would ask for a net
made of cords (or the real net pushed back) and glass that flexes far more, and for no glass between the camera and
the ice.

## 5. Shield wall: braces and men floored (v0.1.10)
### The sentence (446 characters, sent 13:29:49, event 989; on v0.1.9)
> Most charges still hit nobody: in a minute the bots charge a dozen times but floor only a few men. A bot should only
> charge when rivals stand in the lane in front of him, aimed at them, so nearly every charge meets someone and bowls a
> line over. And let the brace happen: about a third of the men a charge runs into should be facing it with the shield
> up, so it stops dead with BRACED! and the charger bounces back open, a few times every minute.

- The rivals' part went to crew at once (event 992), core r19 (2.4 min, 1.17M in): Bram charges only when a standing
  rival is in his lane, checks again at the start, no longer avoids a raised shield; his answer to a charge is decided
  by a lane test: brace 40 %, sidestep 15 %, otherwise bowled. NOT DONE (the crew's part) handed to crew.
- crew r10 (2.5 min, 0.98M in): the same for Oda, Finn, Sable and Pip (`_lane_full`, brace about 38 %, sidestep 15 %).
  Its own count: "only 1 of 14 charges bowled someone over" in its bot run.
- crew r11 (1.9 min, 0.83M in): core's NOT DONE arriving after r10, the third duplicate today; this time it added one
  number (`lane_core_k` 0.6: charge only when a rival stands within 0.6 of the lane's width of the line).
- **v0.1.10 promoted 14:10:23**, 40.6 min from the sentence; 2.98M tokens in, 22k out. The promoted pack is file for file
  the one measured and filmed.

### Measured against the hand version (3600 frames, seeds 1/2/3, 0 script errors; seed 1 `098f54b9de09e943` twice)

| | hand | v0.1.9 | **v0.1.10** |
|---|---|---|---|
| charges a minute | 14 / 15 / 6 | 12 / 11 / 6 | 7 / 11 / 13 |
| men floored by a charge a minute | **10 / 9 / 8** | 3 / 7 / 1 | **7 / 5 / 9** |
| braced charges (into a raised shield) a minute | **5 / 6 / 3** | 2 / 0 / 0 | **0 / 1 / 2** |
| floored by a slam | 15 / 11 / 7 | 16 / 17 / 11 | 4 / 10 / 10 |

(Hand: `bot_juice_hand.gd`; editor: `bot_juice_editor.gd`, the same captain, each counting its own pack's events.
The charges include the scripted captain's own.)

Clip `clips/shield_v0110_vs_hand.mp4` (640 wide; Create top, hand bottom, seed 1, frames 330-1530), sheet
`stills/shield_ed0110_overview.jpg`, looked at: charges and slams through the knot of fighters, BOWLED! and SLAM!
mid-screen; no BRACED! in this take.

**As a person:** a charge now meets someone: men floored by a charge went from 1-7 to 5-9 a minute, close to the
hand's 8-10. **Braces did not come:** 0-2 a minute against the hand's 3-6, and none on screen in my take. The builders
set a 38-40 % brace chance for a man in the lane, but in play few men stand facing a charge with the shield up when it
arrives. That is the one gap left in shield wall.

## 6. Robot soccer: the words and the ring (v0.1.9)
### The sentence (439 characters, sent 13:57:13, event 1437; on v0.1.8)
> Two things still read weaker than in a real brawler. Every hit says KA-BONK!!, even a quick tap: keep KA-BONK!! for a
> big charged hit and BONK! for a small one, and print them as fat yellow comic letters with a dark outline that pop
> out where the blow lands and hang there for most of a second, instead of thin pale text drifting up. And the red
> reach ring is a thin line that is hard to see across the pitch: make it a thick, bright band.

- core r19 (2.9 min, 0.77M in): found the bug itself: "the size of the word came from the launch force. Even the weakest tap
  launches at 9 of a possible 15, which is already 0.6, so every hit counted as big. The word now follows the charge."
  Fat yellow letters (#ffd21a) with a dark-brown outline, size 96 -> 150, a pop and settle over 16 frames, 50 frames in
  all; the ring a 0.5 m band, three times taller, brighter red. Drawing only: the state hash is unchanged
  (`d7325572...` on seed 1, the same as v0.1.8).
- **v0.1.9 promoted 14:26:44**, 29.5 min from the sentence; 0.78M tokens in, 8k out; the promoted pack is file for file
  the one measured and filmed. Headless (seeds 1-3, 3600 frames, 0 script errors): the same hashes as v0.1.8
  (`d7325572...` twice on seed 1), bots 11 / 10 / 11 swings a minute, hits fly 3.5-5.0 m.
- In the window (`clips/robot_v019_vs_hand.mp4`, 640 wide, Create top, hand bottom; stills
  `stills/robot_ed019_my_f56-144.jpg`, `stills/robot_ed019_f200_f200-332.jpg`, looked at): my quick first swing now
  says **BONK!** (the hand version says BONK! there too), in fat yellow letters with a dark outline that hang over the
  spot and fade; the bots' reach rings are thick bright bands you see from across the pitch.

**As a person:** with this third sentence I cannot point at a juice part of the hand version that v0.1.9 lacks on
screen. What still differs is taste: the hand version's head-into-the-court miss and its crash sound at more than half
charge are not visible or not checkable from my takes in either version.

## Round 2 in short
| | sentence | time to promotion | tokens in | what a person meets |
|---|---|---|---|---|
| Arsenal v0.1.25 (no new sentence) | - | - | - | the meteor goal reads; the net bag is a white block; the glass does not visibly move; the new panes lie across the view behind my own net |
| Shield wall v0.1.10 | 446 chars | 40.6 min | 2.98M | charges meet men (5-9 floored a minute, hand 8-10); braces still rare (0-2, hand 3-6) |
| Robot soccer v0.1.9 | 439 chars | 29.5 min | 0.78M | BONK!/KA-BONK!! by charge, fat yellow comic words, thick rings; on a par with the hand version by eye |

**New pack paths and menu titles (round 2):**
- Shield wall: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/shield-wall-3-v-20261125-1-jb/promoted/game.shield_wall_3_v@0.1.10`,
  "Shield wall: charge and slam v0.1.10 (made in Create from juice sentences)".
- Robot soccer: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.9`,
  "Robot soccer: sledgehammer v0.1.9 (made in Create from juice sentences)".
- Arsenal: no new version (v0.1.25 stays; it was only filmed).
