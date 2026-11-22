# Hockey teardown: thirdjam (HOKEJ) against our `engine/packs/hockey`

Lane N1 of the night shift of 22-23 Nov 2026. Research only: nothing in `engine/` or `foreman/` was changed.

**The owner, 22 Nov about 18:35 (verbatim, from the brief):** "Hockey is unplayable garbage, analyze in deep thirdjam - it is a
mediocre hockey game we delivered but at least it has set basic gameplay mechanics, AI, bugless graphics and balanced speed ...
The fact players can skate and shoot puck does not mean we delivered entertaining hockey experience."

**Sources.**
- thirdjam: `https://github.com/xkazm04/thirdjam`, cloned read-only into this tree's `.tl/thirdjam` (957 commits, HEAD
  `8dc713c6`, 16 Nov 06:55). Paths below marked **TJ** are relative to that repo's root. The game ran from a built tree of
  15 Nov (section 1).
- ours: this worktree at main `1fa3b56`. Paths marked **OURS** are relative to `engine/packs/hockey/` unless they start with
  `engine/` or `docs/`.
- Abbreviations on the thirdjam side: `JamSim.cpp` = `Game/Source/JamCore/Private/JamSim.cpp`; `JamCartridge.h` =
  `Game/Source/JamCore/Public/JamCartridge.h`; `JamAICore.cpp` / `.h` = `Game/Source/JamCore/AI/JamAICore.*`;
  `DifficultyProfile.cpp` = `Game/Source/JamCore/AI/DifficultyProfile.cpp`; `HokejGameMode.cpp`, `CameraFollow.cpp`,
  `HUDWidget.cpp` = `Game/Source/JamGame/Private/*`; `regular.json` = `Game/Content/Cartridges/hockey.regular.cartridge.json`
  (what PLAY NOW plays, `Game/Source/JamGame/Private/MenuFlow.cpp:21`); `RULINGS` = `contracts/RULINGS.md`.

## 0. The verdict in ten lines

1. **Ours is not a smaller thirdjam: it is a different, much more crowded game.** Our skaters are drawn 2.2 times life size and
   collide as bodies of radius 0.879 m on a 60 x 30 m rink; thirdjam's are life-size bodies of radius 0.4 m on 90 x 45 m. In body
   widths, thirdjam's rink is 112 long, ours 34 (a real rink is about 100). Every other system sits inside this box.
2. **The scale was never a design decision.** It came from fixing a drawing fault (16 Nov, H7: "figures that overlapped by half
   their width now meet") and nobody re-sized the ice. Every later lane tuned its numbers inside it.
3. **Our teammates were made disengaged on purpose**, to make an idle hand lose a bot ladder; thirdjam's owner called exactly that
   "disengaged" and "not interested in game", and thirdjam fixed it the same night.
4. **Our camera chases the puck and zooms, and the stick is the cursor's point on the ice through that moving camera**: the stick
   turns when the hand does not move. thirdjam hit the same fault: the owner named the camera's self-correction (R-0064), its
   camera lane found that each correction swung the stick, and it was fixed with an aim anchor.
5. **Our puck hardly slows (no drag; the ice takes about 1 m/s2, measured) and our passes leave at a fixed speed**; thirdjam's
   puck slows with its speed (drag 0.5/s plus friction) and its pass speed is solved so it arrives at 8 m/s. Our answer to the consequences was a dozen own-goal guards, not the physics.
6. **Our game stops all the time**: 36-second periods, a whole-game freeze on every hard hit near you (about 3.8 a minute),
   goal holds, replays, a swoop. thirdjam is one run of play, first to three.
7. **We re-added what the owner had removed from thirdjam**: rings round downed men and bursts at hits. He ruled them out in
   thirdjam on 14-15 Nov ("the player animation should reflect the crosscheck movement and that should be all", R-0070); our "fun pass" of 20-21 Nov put them back, with a camera
   punch and a whole-game freeze on top.
8. **No lane has played ours; only the owner has, twice, and both times it was "unplayable"** (21 Nov: "unplayable through
   inbalancing of puck stickiness, players speed, ability AI to decide what to do, when to pass and shoot"; 22 Nov: "unplayable
   garbage"). Between the two, N3 tuned it to five bot metrics. thirdjam's owner played at least five builds in its 93 hours (H7,
   H18, H31, H34, and H34 again on the last morning) and each verdict became numbered rulings; ours was tuned to scripted hands
   that read the true puck position from the game state.
9. **By thirdjam's own first-five-minutes measures, ours scores well** (first touch 0.6-0.7 s, puck on your blade 18-21 % of play):
   the numbers we measure cannot see what the owner sees. That, not any one mechanic, is the finding.
10. thirdjam is the floor, not the bar: it still has a weak puck rule for the passer under pressure, a steep camera at the boards,
    no goalies, and its owner never played its final build either (section 4).

## 1. How this was read and played (and what that cannot see)

- **thirdjam, read:** its docs (`docs/VISION.md`, `docs/HOCKEY.md`, `GAME.md`, `docs/PLAY-ME.md`, `docs/EVOLUTION.md`,
  `docs/design/REVIEW-1..3.md`, `docs/experiments/EYE.md`, `BRAIN-*.md`, `contracts/RULINGS.md` R-0010 to R-0075) and its sim, AI
  and screen code. Three read-only scouts mapped `JamSim.cpp`, the AI and the screen code with file:line; the lines this report leans
  on were re-read by hand.
- **thirdjam, played:** it runs on this machine. The packaged zip is not in git and no package is left on disk, but a thirdjam
  worktree of 15 Nov 11:41 with an editor build (`C:/t/t5`, a worktree of the deleted `C:/Users/kazda/kiro/thirdjam`) was found.
  Its runtime (Binaries without PDBs, Content, Config, Plugins, the `.uproject`; 785 MB) was copied to `.tl/tj-run`, and run as
  `UnrealEditor.exe .tl/tj-run/Game/ThirdJam.uproject /Game/Maps/Rink -game -windowed -nosound -Multiprocess -cut=hockey.regular
  -ExecCmds="jam.ScriptHuman 2, jam.screen.StillEvery 2"` (UE 5.9, shaders compiled in about a minute). `jam.ScriptHuman 2` is
  thirdjam's own "measured hand in the rendered game" (`docs/experiments/EYE.md`, "the headless playtester's decision through a
  person's buttons", lane A209's hand); the log says `JAMSCRIPT human=2 kind=regular level=pro`. Frames are the game's own
  viewport stills (no window grab), every 2nd sim frame, made into a 30 fps clip. **That build is about H39-H44, not the submitted
  H47** (H47 is the same day's evening); `C:/t/t5/Game/Source` differs from the clone's HEAD in 78 files.
- **ours, played:** `tl play hockey` in a window with nothing pressed (the first 25 s a person meets), and the ladder bots in a
  window through `TLHand` (rookie + newcomer, pro + regular), Godot movie writer at 60 fps (`.tl/n1/clip.sh`, a copy of N3's).
- **ours, measured as a person meets it:** a copy of the pack in `.tl/probe/hockey` (not in `engine/`) with one extra test,
  `tests/probe_human.gd`, that extends the ladder bot and counts what b0 meets: first touch, first shot, his carries, who has the
  puck, how many skaters stand within 5 m of it, hit-stops, knockdowns. 20 seeds a cell, headless (`.tl/probe/run.sh`,
  `.tl/probe/sum.mjs`; raw JSON in `.tl/probe/out/`).
- **What none of this can see**: a person's eyes and hands. Neither game was played by me with a mouse: thirdjam's hand is its own
  scripted person, ours is `TLHand` driving a bot that reads the puck's true position from the game state. Where a claim is about
  feel, the evidence is code, a still or a clip, and it says so. The owner's hand is the bar (memory: "His hand is the bar").

## 2. Side by side, per system

Each row: what thirdjam does (TJ file:line), what ours does (OURS file:line), and the difference a player feels.

### 2.1 The match: rules, length, rhythm

| | thirdjam | ours |
|---|---|---|
| Who plays | Five a side, no dedicated goalie (`regular.json:152-235`; `JamAICore.h:782-787`: "the back is the net's last line (no goalies)") | Three a side plus two goalies (`data/tuning.json:27-34`, `scripts/keeper.gd:28-51`) |
| Win | First to 3, no periods; a horn at 30,000 frames (8:20) (`regular.json:145-150`; `JamSim.cpp:57-60, 1208-1224`) | First to 3 or the better score after three periods of **36 s**, 2 s between (`data/tuning.json:2`) |
| Restarts | Face-off after a goal (120-frame pause) | Face-off after a goal (2 s, with a 24-frame hold and a slow replay: `scripts/fun/fun.gd:8-12`) **and** at every period (`scripts/main.gd:456-460`) |
| Freezes | Hit-stop 3 frames, presentation only ("the sim runs on"), only on a knockdown involving the human (`Game/Source/JamCore/Private/JamPawns.cpp:144-150`) | The whole simulation and clock stop for 4-9 frames on any stumble or knockdown closing at 5 m/s or more within 24 m of you (`scripts/fun/fun.gd:140-152`, `data/tuning.json:23` `stop_radius` 24) |
| Measured | REVIEW-1: take-1 at rookie lasted 4.2 min for 2.3 goals (`docs/design/REVIEW-1.md`, section 2) | Probe: a match is 103-105 s of live play (median, rookie newcomer and pro regular, 20 seeds each); **3.7-3.8 hit-stops a minute** |

**What the player feels.** thirdjam is one continuous run of play that ends at three goals. Ours is cut every 36 s by the clock,
after every goal by a hold and a replay, and about every 16 s by a freeze of the whole game. A newcomer's first match is over in
under two minutes of play, so the game ends before the player has learned it.

### 2.2 Rink, figures and scale (the box every other system lives in)

| | thirdjam | ours |
|---|---|---|
| Rink | 90 x 45 m, corners 3.75 m (`regular.json:116-118`; operator's choice R-0010 on measured pacing, `docs/HOCKEY.md:27`) | 60 x 30 m, corners 5 m (`data/tuning.json:42`, `data/venue.json`) |
| Body | Contact circle 0.4 m (`Game/Source/JamCore/Public/JamSim.h:494`); a life-size figure (the clay figure "is shorter than 1.8 m", `HUDWidget.cpp:1631-1632`) | Drawn at 2.2x (`data/tuning.json:4` `body_scale`), contact at 2.93/2.2 of that: radius **0.879 m** (`data/tuning.json:5`; README "Contact and skating"); the README calls it "our 4.4 m figure" (README, N3 section) |
| Rink length in body widths | 90 / 0.8 = **112** | 60 / 1.76 = **34** |
| Free ice per field skater, in body-width squares | 4050 m2 / 10 / 0.64 = **633** | 1800 m2 / 6 / 3.09 = **97** (goalies not counted) |
| Goal | 4 m wide, 0.61 m high, 1.5 deep (`regular.json:121`; `JamCartridge.h:37`) | 4 m wide, 1.5 high, 1.5 deep (`data/tuning.json:26`, `data/venue.json`): a little more than two of our body widths |

A real rink is 61 x 26 m with players about 0.6 m wide: about 100 body widths long. thirdjam is at real scale; ours is a third of
it.

**How ours got here** (git): the Foreman's pack had no `body_scale` (`3249be7`, H0, 16 Nov 01:25). H7 (`9a1eb64`, 16 Nov 03:54)
added `"body_scale": 2.2` with the message "figures that overlapped by half their width now meet within 0.1 m; reach, carry, poke
and check distances re-read". L1 (`a37ca43`) then pointed a near-vertical narrow camera at it so "the ice is 95 % of the frame".
L4 (21 Nov) set the contact body at 2.93 on top, "the skate pose spreads beyond the rig metric" (`scripts/main.gd:256-257`), and
scaled the research's lengths by 1.65 for "our 4.4 m figure". At no point did anyone ask how big the ice is for the players.

**Measured (probe, 20 seeds a cell):** a mean of 2.2 field skaters (of six) stand within 5 m of the puck in every live frame, and
in **15-16 % of live frames four or more of the six are within 5 m of it** (rookie newcomer 15.9 %, pro regular 15.0 %; idle hand
20.1 %). N3 saw it in its own clips: "the bots still bunch round the puck in scrums of four or five" (README, Known limits). The
stills (`media/sheet_ours_rookie_newcomer.jpg`, `media/sheet_ours_pro_regular.jpg`) show the scrums; thirdjam's
(`media/sheet_thirdjam_pro_regular.jpg`) show open ice.

**Speed reads in body lengths.** Our free skater cruises at 9.2 m/s (`data/tuning.json:4,6`: 8 x 1.15) = **2.1 of his own heights
a second**; thirdjam's at 12.65 m/s (`regular.json:125` 11 x 1.15, `JamCartridge.h:67-85`) = about **7 heights a second**. Both
cross their rink in 6.5-7 s, but ours looks like a jog because the figure is 2.6 times bigger. This is the most likely reading of
the owner's "balanced speed": in thirdjam the body moves fast for its size and the puck faster; in ours the puck (24-32 m/s) moves
5-7 heights a second and the body 2.

### 2.3 Skating

| | thirdjam | ours |
|---|---|---|
| Speeds | 11 m/s base, free x1.15, sprint +0.15, carrier x0.92 (+0.08 sprinting, capped at 0.97 of a free sprinter), breakaway +0.3 for 60 frames (`regular.json:124-130`; `JamCartridge.h:67-85`; `JamSim.cpp:1283-1298`) | 8 base, free x1.15, sprint +0.15, carrier x0.88 (`data/tuning.json:4,6`; `scripts/skate.gd:65-75`). The ratios were ported from thirdjam by L4 |
| Turn, stop, burst | Turn 5 rad/s; reverse-input stop 26 m/s2; burst x1.8 for 20 frames (`regular.json:126`; `JamCartridge.h:90-125`; `JamSim.cpp:1299-1330, 1393-1418`) | Turn 4.5 rad/s; the same stop and burst, ported line for line (`scripts/skate.gd:212-261`, citing `JamSim.cpp`) |
| Bots sprint | Yes, by level: share 0.2 / 0.35 / 1.0 (`DifficultyProfile.cpp:58`) | **Never**: only the human and drills call `skate.pace` with a held sprint (`scripts/player.gd:23`, `scripts/drills.gd:83-87`); README rule 5: "The match AI never requests sprint" |
| Bots' thrust | Opponent forwards move at `SpeedScale x RedSkill`, floored at `OppPace9` 1.0 at rookie (`DifficultyProfile.cpp:67`: "rookie's opponents skate at full pace and stay clumsy by aim, poke and reach") | Every bot's intent is scaled by `speed_scale` 0.9, red's again by `red_skill` (rookie 0.55, pro 0.795, all-star 0.83) (`scripts/ai/brain.gd:137-138`; `data/ai.json:2`; `data/levels/*.json`). In the kernel the intent's length scales the **thrust**, not the top speed (`engine/kernel/api/tl_biped.gd:521-522`), so the README's "rookie at 55 % of your speed" is really 49.5 % of your push |

**Measured (probe, 12 seeds a cell):** mean speed on live frames, b0 / his mates / red: rookie 6.2 / 6.0 / 4.9 m/s, pro
6.0 / 5.9 / 5.7, all-star 5.8 / 5.7 / 6.0; the top speeds seen are 10-11 m/s for red at every level (collisions and the burst add
to the push). So the half push costs rookie's opponents about a fifth of their mean speed, not half, and at pro and all-star the
speeds are even. **Everybody's mean is about 6 m/s: 1.4 of our figures' heights a second.**

**What the player feels.** The skating rules are thirdjam's (L4 ported them faithfully). Nobody but you ever sprints, the rookie
opponents push softer, and every bot reads the play 5-18 frames late and decides every 15 frames (2.7). With the scale of 2.2
(figures of 4.4 m), the whole rink seems to move at a walk.

### 2.4 The puck: friction, possession, carry

| | thirdjam | ours |
|---|---|---|
| Friction | Drag 0.5/s plus ice friction 0.147 m/s2 (`regular.json:120,136`; `JamSim.cpp:4044-4057`); a 14 m/s pass stops after about 26 m, an 18 m/s one after about 34 m (from that law) | **Drag 0** (`data/tuning.json:19`) on a rigid body (`engine/kernel/api/tl_ball.gd:118-119`); the ice's contact friction alone slows a free loose puck by **1.0 m/s2** (probe, 4 seeds, 130-424 free frames each: 0.97, 1.05, 1.00, 0.98), so an 18 m/s pass would need about 160 m to stop: it reaches the boards; the pack's own comments record "a 47 m zero-friction rebound" (`scripts/rink_api.gd:537-538`) and "a pass to a downed b0 that slid 50 m into the far net" (README, L5b ladder) |
| A loose puck becomes yours | The human's ring 1.1 m at up to 18 m/s relative, a stick arc 1.5 m +-60 deg, a body that meets it (`JamSim.cpp:3935-4029`; `JamCartridge.h:225-241`). After the owner's "puck is not controlled by player if in his circle area" (R-0069), any loose puck in the human's ring is his on that frame (`JamSim.cpp:3921-3952`) | Ring 1.45 m, clean under 15 m/s relative, bobble 15-20, faster passes through (`scripts/carry.gd:183-222`; `data/tuning.json:7-16`) |
| Carry | Blade at body + aim x (0.4 + 0.5..1.0 x 1.2 m), x0.75 when not sprinting; carry assist pulls the puck 25 % a substep to the blade (`JamSim.cpp:1478-1497, 4162-4178`; `JamCartridge.h:187, 295`) | A critically damped spring (k 400) to the drawn blade 1.98 m out at full aim, dangle 0.82 m on turns (`scripts/carry.gd:84-127`) |
| What takes it from you | A poke, a lift, a check; **no passive take** by a touch (`JamCartridge.h:196-198` `bPassiveTake = false`, after REVIEW-1 found "a puck changes hands with no press at all"); take grace 30 frames (`JamSim.cpp:1242-1252`); body shield, sweep shield (`JamSim.cpp:1500-1582`) | A poke (65 / 45.5 / 26 % by angle), a check, a sprint plus hard turn, a bobble, an intercept (`scripts/poke.gd`, `scripts/carry.gd:113-117`); a new owner cannot be poked for 24 frames; bots give a fresh carrier 60 frames before a stick, 15 before a check (`data/ai.json:18-19`) |

**What the player feels.** In thirdjam a missed pass dies on the ice near where it was aimed; in ours it travels to the boards or
the far net. Our answer was not drag but guards: no bot pass whose path runs within 3.5 m of its own net or "into the corner
boards within 8 m of our goal line" (`scripts/ai/carrier.gd:84-109`), goalies that take slow pucks sliding into their mouth
(`scripts/keeper.gd:106-112`), a cap on a loose puck gaining speed between bodies (`scripts/carry.gd:169-181`), goals only through
the mouth (`scripts/rink_api.gd:526-545`). Each guard is commented with the idle-hand win that caused it. They work, and they
constrain the bots' passing further (2.7).

### 2.5 Passing

| | thirdjam | ours |
|---|---|---|
| Your pass picks | The mate nearest the stick's line inside 25 deg; under pressure it leaves from the far side of the blade and prefers an open lane (`JamSim.cpp:3360-3446`; `JamCartridge.h:368`) | The mate nearest where the stick points inside 50 deg (`scripts/rink_api.gd:360-376`; `data/tuning.json:15` `pass_cone_deg`) |
| Speed | **Solved**: the speed at which the puck arrives at 8 m/s where the receiver will be, between the tap (14 m/s) and full; holding adds power up to a third of the rink (`JamSim.cpp:3224-3299`), the owner's order "passes need to be able to be hold enough to cross 1/3 of arena length" (RULINGS R-0067) | **Fixed**: 18 m/s, 23 beyond 15 m (`data/tuning.json:15`; `scripts/rink_api.gd:382-385`); with no friction it arrives at about the speed it left |
| Reception | A mate's blade within 1.2 m catches it in flight; an opponent only at his blade after 6 frames and 2.5 m (`JamSim.cpp:3522-3550, 3708`) | Intended receiver: +0.6 m window, an 18-frame magnet, clean up to 28 m/s relative (`scripts/carry.gd:129-167`) |

**What the player feels.** In thirdjam a pass is slow enough to take and the receiver keeps it. In ours a 5 m pass and a 15 m pass
both leave at 18 m/s; the receiving rules are generous, so the scripted hands take it, but every miss is a long loose puck.

### 2.6 Shooting and the net

| | thirdjam | ours |
|---|---|---|
| Aim | Along the skater's facing; **snaps to the goal centre inside 8 deg** (16 deg on a one-timer; to the open post after a deke) (`regular.json:143`; `JamSim.cpp:2828-2845`) | Exactly at the cursor's point on the ice when it is 4 m or more ahead of the stick (`scripts/rink_api.gd:350-358`); bots aim at the far side with 1.5 m (`data/ai.json` `corner_z`) |
| Speed | x2 by the owner's order "shoot speed should double" (`JamCartridge.h:340-343`, R-0067): tap 36, full charge 52 m/s, the extra fading after 8 m | Wrist 24, full charge 32, one-timer 28.8 (`data/tuning.json:10`) |
| Who stops it | Whoever stands within 3 m of his net in a crease stance (`JamSim.cpp:4351-4401`) | A goalie per side, drawn at 2.4x, placed every frame (`scripts/keeper.gd:147-183`), catching within a 0.9 m glove, poking a carrier within 2.2 m (`data/tuning.json:24`) |

### 2.7 The AI

| | thirdjam | ours |
|---|---|---|
| Cadence | **Every bot decides every frame** (`JamAICore.cpp:356-396`) | Every 15 frames, staggered; the carrier every 7-8; plus on events (`scripts/ai/brain.gd:96-124`) |
| Perception | **No reaction delay at any level** (`DifficultyProfile.cpp:38` `ReactionFrames = 0`); possession read late at rookie (24 frames) (`DifficultyProfile.cpp:56`) | Every bot sees the world 5 (mates), 18 / 12 / 7 frames (red by level) ago (`data/ai.json:9`, `data/levels/*.json`; `scripts/ai/sense.gd:44-51`) |
| Levels differ by | Execution: aim error, shot reach, poke timing, hits, hunting, sprint (`DifficultyProfile.cpp:55-82`); the owner's ruling "a level is easy by clumsiness, never by absence" (RULINGS R-0067 point 3) | Reaction, thrust, aim and score noise (`data/levels/*.json`) |
| Carrier | Pressure (an opponent arriving within 0.6 s or within 5 m), a wall ahead, or a better mate: pass; else carry; inside 22 m with a lane: drive the net (`JamAICore.cpp:671-684, 1761-1810`) | Utility scores SHOOT / PASS_x / CARRY / PROTECT / DUMP with noise and a commitment bonus (`scripts/ai/carrier.gd:1-82`) |
| Shape | Five-a-side jobs: close support level with the carrier 6 m to the side, net front, weak side, backs at the points; counter-press for 90 frames after a loss (`JamAICore.cpp:2255-2546`) | Roles F1-F3 / D1-D3 by time to the puck; F2 on a support grid 6-14 m out, F3 high, D1 pressure, D2 lane, D3 slot (`scripts/ai/roles.gd:25-131`) |
| Anti-scrum | A stall rule (puck moved under 2 m in 60 frames), `SplitClump` (mates within 1.5 m for 45 frames separate to 3 m), separation 1.5 m, support at least 4 m from the chaser (`JamAICore.cpp:302-332, 635-664, 1152-1176`) | Separation 4 m x 1.2 among mates in `_execute` (`scripts/ai/brain.gd:256-260`); the contest role runs straight at the puck and skips it (`scripts/ai/brain.gd:254-255`). N3 tried two keep-off rules and reverted them because they cut red's hit rate (README N3 section; commit `4fcdf37`) |

### 2.8 Your teammates

| | thirdjam | ours |
|---|---|---|
| Yield | Mates leave a puck you are nearer to (by 2-4 m, within 15-25 m) (`JamAICore.cpp:908-912`) | The same rule (`scripts/ai/brain.gd:153`), inherited from the Godot job (`docs/HOCKEY.md:28` of thirdjam names it as "what the Godot job taught") |
| Feed you | When you are set up they always pass; otherwise in 0.6 / 0.4 / 0.2 of the chances by level (`JamAICore.cpp:1686-1733`; `DifficultyProfile.cpp:80`) | A pass to you gets +0.4 (`scripts/ai/carrier.gd:44-45`) |
| **Shoot themselves** | **Yes**: 16.5 m reach, aim cone, one-timers (`JamAICore.h:451-456`), after the owner's "AI ... disengaged" (R-0067) and BRAIN-9's "mates never shot" | **Only within 240 frames of your own pass or shot** (`scripts/ai/carrier.gd:20,25`; `scripts/ai/brain.gd:196`; `data/ai.json:25`); a mate who carries never takes it inside 8 m of the net, he "holds 8 m out for the feed" (`scripts/ai/carrier.gd:71-74`) or turns away from it (`scripts/ai/brain.gd:192-193`) |

**Why ours does this:** "Before this, the idle hand won 17 of 20 against rookie: your mates won it" (README, Fun table, "Your mates
set you up"); the commit that added it is titled "...idle hand wins 0/20" (`30c1372`). The rule exists to fix a bot metric.

### 2.9 Contact

Ported faithfully from thirdjam by L4 (README, "Contact and skating", each rule with its `JamSim.cpp` lines): impulse by closing
speed and mass against stability, the attacker pays, three outcomes, the cross-check and its held brace, a downed body others go
round. Two differences a player meets:
- **Rate and timing.** thirdjam's rookie never hits in the 90 frames after a drop, checks only from 6 m/s of closing, never from
  behind (`DifficultyProfile.cpp:59, 70`; `JamAICore.cpp:1540-1549`). Ours: bots may body-check a fresh carrier after 15 frames
  (`data/ai.json:19`, kept "the owner: keep the hit rate", `scripts/ai/brain.gd:281`). Probe: **3.9 knockdowns a minute at rookie,
  4.6 at pro** (all skaters), b0 lying down 4.5-5.6 % of play; checks are 43-57 % of all turnovers (README N3 section).
- **Presentation.** thirdjam ended with "Nothing is drawn at a hit ... Only the figure" (`docs/PLAY-ME.md:30`, `HitRead.cpp:26-40`)
  after the owner's "Crosscheck still displays blue line/rectangle in front of player. This should player never see" (R-0069) and "the player animation should reflect the crosscheck movement and that should be all" (R-0070); the Director's ruling: "Nothing technical is ever drawn on or in front of a skater" (RULINGS R-0069 point 3). Ours draws snow bursts, ice chips, a squash, a camera
  shake and a 12-22 % camera punch at every hard hit within 24 m, and an orange ring under every downed man
  (`scripts/fun/fun.gd:140-152`; `data/tuning.json:25` `down_ring`).

### 2.10 Camera and the stick

| | thirdjam | ours |
|---|---|---|
| Camera | Behind and above **you**: 6 m back, 3.5 m up, 5 m look-ahead, FOV 70, 4-frame lag, 0.7 m off-axis (`regular.json:249-257`; `CameraFollow.cpp:102-121, 169`); WASD read in the camera's yaw (`HokejGameMode.cpp:937-959`) | A broadcast camera from the near side at 50 deg, 20-30 m away, FOV 46, framing **the puck or its carrier** plus a 5 m attack lead plus 0.45 s of puck speed, pulled 35 % toward you, widening when you are far from the puck, a 12-22 % punch on hits, an establishing swoop from 46 m (`scripts/fun/cam.gd:57-125`; `data/tuning.json:22`) |
| Stick aim | The cursor projected on the ice; **a still hand keeps its point on the ice through camera corrections** (`HokejGameMode.cpp:746-752`, lane A191 `AimAnchor`), after the owner's "autocorrecting unnaturally" at the boards (`docs/experiments/CAMERA-3.md`: "each camera turn swung the cursor's blade and the W key with no hand movement") | The cursor projected on the ice through whatever camera is on screen (`scripts/player.gd:27-51`); the camera moves every frame with the puck (above); no anchor |
| Off screen | A far-net badge with metres, edge chevrons, a radar 200 x 100 px (`HUDWidget.cpp:612-628, 1724-1736`; `Game/Source/JamGame/Public/RadarWidget.h:43-44`) | None (no radar, minimap or marker in `scripts/`: searched) |

**What the player feels.** In thirdjam you are always at the same place on the screen and the puck may be off it (the HUD points
at it). In ours the picture follows the puck; your skater slides around the frame, the frame changes scale, and with the mouse still
your stick swings as the camera pans and zooms. N3 noted "in a hard turn the drawn stick can point away from the puck" (README,
Known limits).

### 2.11 Controls and what the screen tells you

| | thirdjam | ours |
|---|---|---|
| Buttons | LMB shoot / cross-check, RMB pass / check, Space poke, wheel deke, E spin, F ability, Shift sprint, Ctrl or S-against-motion brake, 1-4 signals (`docs/PLAY-ME.md:73-89`, generated from `InputMapping.cpp:104-118`) | LMB or Space shoot / LMB or C cross-check, RMB or Q pass / RMB or F check, E poke, Shift sprint, T rule dial, V view (README "How to play") |
| Keys on screen | A controls panel bottom left **all match**, swapping between WITH and WITHOUT THE PUCK, lighting the row of a held button (`docs/PLAY-ME.md:32`; `HUDControlsPanel.cpp`) | Three lines at the top until **the first key you press**, then gone (`scripts/look.gd:10, 90-96, 129-132`) |
| You | A yellow chevron over your helmet all match, YOU for 5 s and after every drop, a ring (`HUDWidget.cpp:636-644, 1611-1687`) | A green ring under you (README "The rings") |
| Voice | A commentary bank with captions (`CommentarySystem.cpp`), crowd, skate loop | Event sounds through the fx hook; no commentary |

### 2.12 The first 30 seconds

- **thirdjam:** HOME with PLAY NOW lit ("ONE MATCH, ROOKIE"), one click, a MATCH card, a 1.5 s face-off countdown in which you are
  the centre and a clean press wins the draw (`JamSim.cpp:724-735, 1038-1076`), the controls panel, the chevron, then play.
  Hints ("RMB PASS: A MATE IS OPEN", "RMB CHECK HIM") at most three times each (`HUDTeach.cpp:62-88`). Stills:
  `.tl/thirdjam/submission/shots/h45-contact.jpg` (copied as `media/thirdjam_h45_contact.jpg`).
- **ours:** a drill: "[ W A S D ] skate to the ring", take LEO's pass, pass back, take it, shoot into an empty net; Enter skips
  (`scripts/intro.gd`, `data/tuning.json:48`). Then the match at rookie; the level and mode panel only after R. Our clip of a person
  who touches nothing (`media/sheet_ours_first25s.jpg`): 25 s of the same still picture, the drill line on top, the camera close
  over three blue figures; no net and no opponent move. A person who does skate meets the first match: probe, rookie newcomer, the
  first touch at 0.7 s (median), the first shot at 17.5 s, the match over in 105 s of play.

### 2.13 How each was tested

| | thirdjam | ours |
|---|---|---|
| The owner | Played H7, H18, H31, H34 and, on the last morning, H34 again while told it was H39 (RULINGS R-0013, R-0032, R-0064, R-0067, R-0069; `docs/PLAY-ME.md:14-16`); each verdict turned into numbered rulings with his verbatim words | Played twice by the owner (21 Nov evening and 22 Nov 18:35), "unplayable" both times (`README.md` N3 section quotes 21 Nov); never by a lane. The README says "Nobody has played it with a real mouse or a real keyboard: everything above is bots" (README, Known limits) and "Nobody has played this with his own hands yet: every figure is a scripted hand" (README, N3 ladder) |
| A critic | A standing "design eye" track: "the ten things a first-time player feels in five minutes, ranked" (`docs/EVOLUTION.md`, F0; `docs/design/REVIEW-1..3.md`); on the last night an "eye" lane that films PLAY NOW as the owner meets it and whose list "outranks a lane's own bars" (RULINGS R-0068 point 3; `docs/experiments/EYE.md`) | Lanes judge their own work; L5 judged the look from its own window clips; N3 by five bot metrics (`tests/metrics.gd`) and the ladder |
| The bar | After the owner's "effectively unplayable": "The operator's eye is the bar. The day measured the game with scripted players and a win-rate ladder and shipped a game its player called unplayable" (RULINGS R-0067 point 2) | The ladder (wins per level and hand) and the five arcade metrics of `docs/research/HOCKEY-ARCADE.md` 5.5 |

## 3. The top 10: why ours is "unplayable garbage" to the owner

Ranked by how much each costs the player. Each names its evidence on both sides and the process that produced it (section 5).

### 1. There is no ice. Giant bodies on a small rink make every play a scrum.
- **Ours:** bodies of radius 0.879 m on 60 x 30 m (`data/tuning.json:4-5, 42`): the rink is 34 body widths long; 97 body-width
  squares of ice per field skater. Probe: four or more of the six field skaters within 5 m of the puck in 15-16 % of live frames.
  Clips: `media/ours_rookie_newcomer_s1.mp4` 0:09-0:12, `media/ours_pro_regular_s1.mp4` throughout.
- **thirdjam:** 0.4 m bodies on 90 x 45 m: 112 body widths, 633 squares per skater, and still five a side (`regular.json:116-118`,
  `JamSim.h:494`). The operator chose the bigger rink on measured pacing (R-0010).
- **Cost:** law 3 of thirdjam's vision ("the carrier wins by changing speed and direction") needs room; passing lanes need room;
  speed needs room to be seen. In ours, a carrier is inside someone's reach almost always, the puck is decided by pokes, bobbles
  and checks in a pile, and the figures look slow (2.1 heights a second against about 7).
- **Measured arms (round 2, copies of the pack in `.tl/arms`, the AI on all six at pro, 8 seeds; `media/probe.md`):** life-size
  bodies alone leave the four-man piles where they are (17 % against 16 % of play: the AI gathers round the puck in metres
  whatever the body size; the pile is AI behaviour too) but cut knockdowns by a third; thirdjam's 90 x 45 m rink alone cuts the
  piles to 12 % and doubles the AI's carry; both together halve the knockdowns (5.3 to 2.6 a minute) and the freezes (4.8 to 1.5).
  So scale is necessary and not sufficient: the AI's own pull to the puck is the second half of item 1.
- **Process:** a drawing fix (H7) changed the game's geometry, and no lane owned "how big is the world for its players".

### 2. Your teammates refuse to play.
- **Ours:** mates shoot only within 4 s of your own pass or shot, never carry it to the net, "hold 8 m out for the feed"
  (`scripts/ai/carrier.gd:20-25, 71-74`; `scripts/ai/brain.gd:192-197`; `data/ai.json:25`). Idle probe: the idle human still
  holds the puck 28 % of play, with carries of 3.65 s (median): his mates pass it to him and wait.
- **thirdjam:** mates shoot from 16.5 m, take one-timers, drive the net (`JamAICore.h:451-456`; `JamAICore.cpp:671-684`).
- **Cost:** two of your three skaters look "not interested in game" (the owner's word for thirdjam's H34, R-0067). In a 3v3 on a
  crowded rink that is most of the hockey on screen.
- **Process:** a bot metric (the idle hand must lose) was turned into a rule of the game, and the rule was never looked at by a
  person.

### 3. The camera follows the puck, not you, and your stick moves when your hand does not.
- **Ours:** `scripts/fun/cam.gd:57-125` (puck focus, leads, distance 20-30 m, punch, swoop) with the stick = cursor projected
  through that camera (`scripts/player.gd:27-51`), no anchor.
- **thirdjam:** a chase camera behind the human (`regular.json:249-257`); `AimAnchor` keeps a still hand's point on the ice
  (`HokejGameMode.cpp:746-752`); the owner rejected camera self-correction (CAMERA-3.md, R-0064 point 1).
- **Cost:** the mouse is the stick in both games; in ours the stick is not where the hand left it. The frame's scale changes with
  the distance between you and the puck, so the same pass looks different each time.
- **Process:** the camera was prescribed as "fun" in a brief ("It frames the puck carrier and the attack direction",
  `docs/shifts/2026-11-21-night/lanes/L5-hockey/BRIEF.md:30-31`) and kept over thirdjam's on judgement ("Keep what is better than
  thirdjam: ... the broadcast camera", `docs/shifts/2026-11-21-day/lanes/L4-hockey/BRIEF.md:58`), without anyone holding the
  mouse in either game.

### 4. The puck behaves like a pinball: almost no slowing, fixed-speed passes.
- **Ours:** `data/tuning.json:19` (drag 0; the ice takes 1.0 m/s2, measured), `data/tuning.json:15` (18 / 23 m/s), the guards in `scripts/ai/carrier.gd:84-109`,
  `scripts/keeper.gd:106-112`, `scripts/carry.gd:169-181`, `scripts/rink_api.gd:526-545`.
- **thirdjam:** drag 0.5 plus friction (`regular.json:120,136`; `JamSim.cpp:4044-4057`); pass speed solved to arrive at 8 m/s
  (`JamSim.cpp:3242-3299`).
- **Cost:** a missed pass or a poked puck travels the rink; a short pass arrives hot; the play keeps resetting to the far end.
- **Process:** each consequence was found by an idle-hand win and fixed where it showed up, never at its cause.

### 5. The game keeps stopping.
- **Ours:** 36-s periods with a face-off each (`data/tuning.json:2`; `scripts/main.gd:456-460`); a frozen simulation 4-9 frames
  on hard hits near you, 3.7-3.8 a minute (probe; `scripts/fun/fun.gd:140-152`); a 2 s goal pause with a hold and a slow replay;
  an establishing swoop at match start (`scripts/fun/cam.gd:107-112`).
- **thirdjam:** one run to three goals; a 3-frame presentation-only hit-stop on knockdowns involving the human
  (`JamPawns.cpp:144-150`); no replay (scout: `docs/experiments/CAMERA.md:114-115`).
- **Cost:** play never flows for long enough to learn it; freezes on other men's hits read as stutter.

### 6. The figures glitch, and the README lists it.
- **Ours, by its own README (Known limits):** a goalie "stands upright and does not animate a stance" (placed every frame,
  `scripts/keeper.gd:155-183`), "the stick is drawn through the boards", "two bodies closing head on can sit up to 0.09 m inside
  each other", "a floored man falls FORWARD whatever the hit ... he lies under the hitter's skates", "figures overlap in contact",
  "the drawn stick can point away from the puck", "with an aim swung across the body ... the puck swings round him over about
  three frames".
- **thirdjam:** device B's rigged figure with directional falls and get-ups, the hits' takes timed to the sim
  (`HitRead.cpp:63-64`), a stick that reads (R-0021); the owner called its graphics "bugless".
- **Cost:** each glitch is small; together they tell the player the game is unfinished.

### 7. Hits decide the game, and they are the one thing drawn loudly.
- **Ours:** checks 43-57 % of turnovers (README N3 table), 3.9-4.6 knockdowns a minute (probe), bursts, shake, punch and a down ring
  on each (2.9).
- **thirdjam:** fewer early hits at rookie (none within 90 frames of a drop, 6 m/s minimum, never from behind); nothing drawn at a
  hit (R-0069, R-0070). Honestly: the 15 Nov build filmed here still draws a few marks (a WON badge at the draw, a "BRACED HIT"
  label, a dashed ring at a fold; `media/sheet_thirdjam_pro_regular_50s.jpg`); the submitted H46/H47 removed the last of them
  (`docs/PLAY-ME.md:34-41`).
- **Cost:** the loudest thing on screen is a crash in a pile; the owner had asked, twice, for the figure to show the hit and nothing
  else.
- **Process:** the owner's rulings in thirdjam did not travel to third-life (section 5).

### 8. The opponents read the play late, and nobody but you ever sprints.
- **Ours:** 18-frame perception lag, decisions every 15 frames, thrust 0.9 x 0.55 at rookie, no bot sprint (`data/levels/rookie.json`;
  `scripts/ai/brain.gd:96-138`; `scripts/player.gd:23`).
- **thirdjam:** every frame, no delay, rookie at full pace, sprint by level (`JamAICore.cpp:356-396`; `DifficultyProfile.cpp:38,
  58, 67`); "a level is easy by clumsiness, never by absence" (R-0067 point 3).
- **Measured:** the soft push costs rookie's red about a fifth of its mean speed (4.9 against your 6.2 m/s); at pro and all-star
  the speeds are even (probe, `media/probe.md`). The lag and the 4 Hz decisions remain.
- **Cost:** the bots answer late and all together; when they arrive they arrive in a heap (item 1). Less costly than the items
  above: the measured speeds are close.
- **Process:** the research spec (`docs/research/HOCKEY-ARCADE.md` 5.3) prescribed "perception lag 18/12/7/5 f" for difficulty;
  thirdjam had measured that a late read breaks the game and dropped it (`DifficultyProfile.cpp:62-63`, BRAIN-9). The research did
  not read thirdjam's own results.

### 9. Shooting asks for precision the screen cannot give.
- **Ours:** the shot flies exactly at the cursor's point (`scripts/rink_api.gd:350-358`) through a moving camera (item 3), at 24 m/s,
  at a 4 m net with a goalie 2.4 times life size in it.
- **thirdjam:** the shot follows your facing and snaps to the goal centre inside 8 deg (`JamSim.cpp:2828-2845`), at 36-52 m/s by
  the owner's order (R-0067).
- **Cost:** a newcomer's shot is a guess; the scripted hand's is not (it reads the goal's coordinates).

### 10. The screen does not explain itself after the first key.
- **Ours:** the key lines vanish on the first press (`scripts/look.gd:90-96, 129-132`); no radar, no off-screen marker; the level
  and mode line in the corner.
- **thirdjam:** a controls panel all match that swaps with possession, a chevron, a radar, a far-net badge with metres, captions
  (`docs/PLAY-ME.md:32`; `HUDWidget.cpp:612-644`).
- **Cost:** a person who forgot which button cross-checks has to quit to the README.

## 4. What thirdjam itself still lacks (the floor, not the bar)

Against NHL 94, NHL Hitz, Blades of Steel, Hockey Heroes and the like:
- **Its owner never played its final build.** PLAY-ME ends: "all of it was measured and filmed by scripted hands. Nobody has
  played H40 to H47 with a mouse. You are the first." (`docs/PLAY-ME.md:155`).
- **No goalie.** Every arcade hockey game builds its saves, its rebounds and its one-timers on a goalie; thirdjam has a crease stance
  that any skater takes (`JamSim.cpp:4351-4401`). NHL 94's one-timer against a sliding goalie, the game's signature, cannot exist.
- **Possession is still fragile for the human under pressure:** "Your passes under pressure still arrive about one time in three to
  one in two" (`docs/PLAY-ME.md:126`); REVIEW-1 found the human's median carry under a second at H26 (fixed partly later).
- **Camera at the side boards** "goes steep and close" (`docs/PLAY-ME.md:128`), unfixed.
- **Difficulty by hand only:** rookie "close to a walkover for the scripted hand (no lever found)" (`docs/PLAY-ME.md:118`).
- **Little team play the player directs:** signals exist (1-4), but no set plays, no line changes, no player types (NHL 94's
  distinct players), no on-fire streaks (NHL Hitz), no rivalries.
- **Feedback is mostly text:** commentary captions and HUD lines; the "attacker pays" bounce is invisible (REVIEW-1, item 3).
- **Rookie's mates take the human's pucks** (`BRAIN-3.md`: 51.5 % vs 39.2 % idle, scout) and a bot "can press against a net's
  frame for a second or two" (`docs/PLAY-ME.md:127`).
- **Twelve modes, one depth.** Breadth (modes, Designer, season, online) grew faster than the core match.

## 5. Lessons for HOW we build games (process, not hockey)

1. **A game has a size, and someone must own it.** Our scale came from a drawing fix (H7) and stayed for a week of tuning. Every
   game needs a one-page "world in the player's units" before any mechanic: body size, the arena in body lengths, speeds in body
   lengths per second, the camera's distance in body heights, the screen height of a figure. A change that moves one of them is a
   design change, reviewed as such.
2. **A metric that a scripted hand can pass is not evidence of fun.** Our five arcade metrics, our ladder and our idle-hand check
   are all inside their bands or close; by thirdjam's own first-five-minutes measures (REVIEW-1) ours even looks better (first
   touch 0.6-0.7 s against thirdjam's 1.8 s; carry median 1.2-1.5 s against 0.87 s; puck on your blade 18-21 % against 10 %). The
   owner calls it garbage. thirdjam learned this on 14 Nov ("The operator's eye is the bar", R-0067 point 2), our memory carries it
   ("His hand is the bar", 15 Nov; and on 21 Nov "judge playability (balance, AI decisions) by hand, not by bot win rates"), and
   N3 that same night answered his "unplayable" with a spec of five bot metrics (`docs/research/HOCKEY-ARCADE.md` 5.5) and
   measured its success by them. The lesson was written down four times and lost each time it crossed into a brief.
3. **A rule invented to pass a metric is a design decision and must face a person.** "Mates set you up" (the idle hand must lose)
   produced disengaged teammates; "keep the body-check rate" vetoed N3's anti-scrum rules (README N3 section). Neither was looked at
   in a window by someone holding the controls.
4. **Ports move numbers, not experience.** L4 ported thirdjam's contact and skating line by line, with `JamSim.cpp` citations, onto
   a world three times smaller, a camera of another kind, three a side and goalies. The numbers came; the game did not. Port the
   reasons (VISION's laws, the rulings) and the frame of reference (rink, scale, camera) first, numbers last.
5. **The owner's rulings are design assets; keep them where the next game's builders read them.** thirdjam has 75 rulings with his
   verbatim words; at least five apply to our hockey directly (R-0010 rink size, R-0067 points 2-3, R-0069 / R-0070 nothing drawn at
   a hit, R-0064 the camera). Our L5 fun pass (20-21 Nov) re-added rings at downed men and bursts at hits six days
   after he had ruled such marks out in thirdjam. Its brief said why: "What thirdjam aimed for (second-hand; the repo is not on disk)"
   (`docs/shifts/2026-11-21-night/lanes/L5-hockey/BRIEF.md:26-27`). The next day's L4 brief had the repo and still ruled "Keep what
   is better than thirdjam: the goalies, the broadcast camera, the goal replay, the fun layer" (`docs/shifts/2026-11-21-day/lanes/
   L4-hockey/BRIEF.md:58`): a Director's judgement of what is better, made without a hand on either game.
6. **"Fun" is not a list of juice.** L5's brief asked for "juice on checks: a hit-stop, shake, a drawn effect" and a camera that
   "frames the puck carrier" (`L5-hockey/BRIEF.md:30-38`); its fun pass (hit-stop, shake, burst, replay, swoop, cards) is
   presentation on top of a match whose core (space, teammates, puck) did not work. Juice makes a working loop feel good; it cannot
   make a scrum into hockey.
7. **Research that does not read the last game is rediscovery.** `docs/research/HOCKEY-ARCADE.md` (21 Nov) cites NHL 94, Rocket
   League and Buckland, not thirdjam's own BRAIN and CURVE files, which had already measured that a late read broke rookie's play
   (`DifficultyProfile.cpp:62-63`) and that a passive take makes nobody keep the puck (`docs/design/REVIEW-1.md`, item 1).
8. **The first five minutes must be a measured, watched product.** thirdjam had a standing critic that wrote "the ten things a
   first-time player feels in five minutes, ranked" for every build and an eye lane whose list outranked the lanes' own bars. We
   have neither. Our probe in this lane is a start; it still plays with a bot that reads the state.
9. **Breadth hides the core.** Both games grew modes, abilities, menus and cards while the base match was unplayable (thirdjam:
   twelve modes by H34, when the owner said "effectively unplayable"; ours: eight modes and four abilities by 21 Nov).
10. **One hand on the controls per change.** A lane that changes a verb the player uses must show a clip of that verb played through a
   person's hand in the window, from the player's camera, before and after; and the owner plays the package, not the description of
   it (thirdjam's H34-for-H39 mix-up: he played a build he was not told about, `docs/PLAY-ME.md:14-16`).
11. **Our briefs ask for proof that a mechanic exists, not that a match is worth playing.** N3's brief (the Director's, written from
   the research spec) took the scale as given ("Scale the anchor and radii to our 4.4 m figure", `docs/shifts/2026-11-22-night/
   lanes/N3-hockey/BRIEF.md:24`), prescribed the difficulty lever ("perception lag and noise by difficulty", line 30), made five
   bot metrics the acceptance ("Tune until each is inside its band", lines 35-46), kept two metric-born constraints ("keep the
   body-check rate", line 12; "The idle hand still wins nothing", line 49), and asked for clips of mechanics ("a passing play ending
   in a one-timer; a poke that frees the puck; the carrier losing it on a hard sprint turn; a defensive rotation", lines 50-54). It
   did say "the owner's hand decides 'playable'" (line 55), but nothing in the acceptance could fail on what the owner meets. This
   is the owner's sentence made concrete: "The fact players can skate and shoot puck does not mean we delivered entertaining
   hockey experience." A brief for a game must name the experience it accepts (a minute of a match from the player's camera,
   with what he should feel at each moment) and the mechanics' clips are only its parts.

12. **The jam's lessons were written down for reuse and still did not reach the next brief.** On 16 Nov thirdjam's last lane filed
   40 lessons for the registry (`.tl/thirdjam/docs/registry/LESSONS.md`, 33 leads in `.ai/registry-leads.jsonl`). Two of them
   name what our hockey did afterwards: J18 "draw nothing of the mechanics on or in front of them (no bar, arc, ring, plate or
   streak)" (`LESSONS.md:62`), broken by L5's down ring and bursts on 21 Nov; J01 "reproduce the fault as the person meets it"
   (`LESSONS.md:30`), absent from N3's brief. J07 ("clumsy, never absent", `LESSONS.md:36`) allows "a later read" as clumsiness,
   which weakens our item 8. A registry query tonight for those lessons returns generic techniques, not these: the leads may not
   have landed, and no hockey brief queried it. Lessons are only useful where the next brief is written.
13. **A world's constraint set a game's size.** Our big-ice mode says why it stops at 80 x 40 m: "the largest rink that fits the
   village plot (88 m)" (`data/modes/big_ice.json`, `about`). The world's plot, not play, capped the ice. A game's size is
   decided by its play first; the world makes room for it or the conflict goes to the owner.

## 6. Recommendations (accept or reject each; none is built)

1. **Stop all game-feature work on hockey until a one-page "world in the player's units" for it is agreed with the owner**: body
   width, rink in body lengths, players a side, speeds in body lengths a second, camera distance and a still at that scale.
2. **Re-scale before re-tuning**: try ours at thirdjam's proportions (figures at life size on 60 x 30 m, or the 2.2x figure on a
   rink 2.6 times bigger) as a measured arm, with the probe's crowding figure and a window clip, before touching the AI again.
3. **Undo "mates set you up"** as a rule of the game; keep the idle-hand check as a reported number, not a gate.
4. **Camera: try thirdjam's chase camera, or an anchored aim**, before any further camera "fun".
5. **Puck: give it drag (it slows with its speed) and solve pass speed to arrive receivable**; then delete the own-goal guards that
   only existed for a puck that does not slow, each with its test, as a measured arm.
6. **Bots: drop perception lag as the difficulty lever**; difficulty by execution (aim, reach, poke timing, hits), bots at full pace,
   bots that sprint.
7. **Remove the hit presentation the owner ruled out in thirdjam** (rings at downed men, bursts, punches) and make the hit-stop
   presentation only; no whole-game freeze for hits not involving the player.
8. **One continuous match to three goals** (no 36-s periods) as the default.
9. **Carry thirdjam's rulings into third-life**: done as a draft in round 2: `docs/research/hockey-teardown/RULINGS.md` (the
   owner's verbatim words, the rule each became, ANY or HOCKEY, and whether ours follows it). Recommendation: every game lane's
   brief cites the rulings marked ANY.
10. **A standing "eye" for every game**: a lane that plays PLAY NOW as a stranger, films it, and writes a ranked list that outranks
    the building lanes' own metrics; and a probe like this lane's in `tl` that reports what the player meets (first touch, first
    shot, his time on the puck, crowding, stoppages) next to the bot metrics.

## 7. Evidence index

| What | Where |
|---|---|
| thirdjam clone (read-only) | `.tl/thirdjam` (HEAD `8dc713c6`) |
| thirdjam runtime (15 Nov build) and run logs | `.tl/tj-run/Game`, `.tl/tj-run/logs/run4.log` |
| thirdjam clip, pro, its measured hand (first 20 s; 50 s filmed) | `media/thirdjam_pro_regular.mp4`, sheets `media/sheet_thirdjam_pro_regular.jpg` (20 s), `media/sheet_thirdjam_pro_regular_50s.jpg` (50 s) |
| thirdjam's own stills (H45) | `media/thirdjam_h45_contact.jpg` (from `.tl/thirdjam/submission/shots/h45-contact.jpg`) |
| ours, the first 25 s a person meets (nothing pressed) | `media/sheet_ours_first25s.jpg` |
| ours, rookie + newcomer hand, seed 1, 20 s | `media/ours_rookie_newcomer_s1.mp4`, `media/sheet_ours_rookie_newcomer.jpg` |
| ours, pro + regular hand, seed 1, 20 s | `media/ours_pro_regular_s1.mp4`, `media/sheet_ours_pro_regular.jpg` |
| the probe (test, runner, summary) | `.tl/probe/hockey/tests/probe_human.gd`, `.tl/probe/run.sh`, `.tl/probe/sum.mjs`; results `.tl/probe/out/*/s*.json`; summary table in `media/probe.md` |
| the owner's thirdjam rulings, distilled (round 2) | `RULINGS.md` (this folder) |
| scale arms (round 2): A main, B life-size bodies, C 90 x 45 rink, D both | `.tl/arms/{A,B,C,D}/hockey` (tuning and venue edited in the copies), `.tl/arms/run.sh`, results `.tl/arms/out/`; table in `media/probe.md` |
| thirdjam's own lessons for the registry (16 Nov) | `.tl/thirdjam/docs/registry/LESSONS.md` |
