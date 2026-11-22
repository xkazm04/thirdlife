# Two worked cases: arcade hockey and a duel, through the method (v1, 23 Nov 2026)

Each case takes one kind of game through the eight stages of `docs/design/METHOD.md`, as a designer should before
anything is built. What makes the reference fun is written as rules, numbers and moments, each with its source. Each
case ends with what our own build did instead, and the method lines a brief would carry (METHOD.md section 3).

Frames are at 60 Hz. A figure converted from milliseconds or from 30 fps says "(conv.)". "Unverified" means we could
not confirm it from a source; it is a starting number to tune by hand, not a fact. Sources are numbered per case.

Neither case is a plan to build tonight: the owner's rule for 22-23 Nov is no new minigame and no game work on duel or
hockey. They are the bar a future hockey or duel design is read against.

---

## Case A: arcade hockey (NHL '94, with NHL Hitz and Blades of Steel)

### What made NHL '94 fun: rules, numbers, moments

**Rules and numbers**
- **Three inputs carry the whole game.** Mark Lesser (programmer): "The core of the game is a joystick to move, a
  button to pass, a button to shoot" [A2]. The manual's map: on offence B passes, C shoots (held for a slap shot), A
  changes lines or clears; on defence B switches to the player nearest the puck (or poke-checks), C plus the stick is
  a "speed burst (body check)" [A3]. The same two buttons mean "make a play" on offence and "make a stop" on defence.
- **You always control the player who matters.** "Press B to activate player nearest to the puck"; after a long pass,
  press B to take the receiver "before the puck arrives" [A3].
- **The one-timer is the signature goal.** Pass with B, press C "as soon as the puck is free from the passer": the
  receiver lets the puck ricochet off his stick, and "one-timers are more powerful shots" [A3]. Lesser found it in
  play: "Suddenly, I pulled a one-timer, and it was perfect" [A1].
- **Skating has momentum you learn to read.** "When you reverse direction your player will skid a little before he
  actually turns around" [A3].
- **The burst is the risk.** The speed burst makes "your checks harder and your collisions more explosive" [A3]: the
  big hit and the penalty come from the same button.
- **Fun over the rule book.** Penalties and offsides can be switched off; with them off "the game is not interrupted";
  line changes off means "players do not tire" [A3]. Goalies were made invulnerable because pushing them around would
  "destroy the game" (Michael Brook, producer) [A1]. Producer and designer: "we went with what was fun" [A1].
- **Feel over looks.** Lesser: "You want to make it feel good, not look good", and "something specifically delicious
  about the slowness of the puck" [A1].
- **Short, restartable games.** Periods of 5, 10 or 20 minutes (default 10 in the manual) [A3]; players remember
  "10-15 games in a half hour" with "no loading time" (Keith Yandle, an anecdote) [A2].
- **A readable rink.** The camera looks down a vertical rink [A4]; the play reads from end to end.
- **Presentation sells the goal**: 72 pieces of local organ music [A3], hats on a hat trick, the glass breaking on a
  slap shot [A2].
- **The AI.** The manual lists "tougher computer defense", "tougher goalies" and "computer shooter scoring moves", and
  the CPU "sometimes removes its goalie in the third period when it is losing and the game is close" [A3].
- **Unmeasured**: goals per game, real minutes per game and the frame rate of NHL '94 were not found.

**Moments players remember**
1. The one-timer in the slot: "I'd go for the one-timer in the slot. That's the move." (Patrice Bergeron) [A2].
2. The cross-crease deke: "when you cut across the middle, you could always score" (Dan Boyle) [A2]. Players banned it
   among themselves, with the wraparound, or "it would be an all-out brawl" [A5].
3. The big check into the boards or the bench [A2], and the "wrecking ball" that a weight bug made of small players
   (lighter players hit harder: "just inverting two numbers", Lesser) [A1].
4. The hat trick: hats rain onto the ice [A2].

**From the arcade descendants**
- NHL Hitz 20-02: three skaters a side; three goals by one player make him "on fire" (harder to knock down, a
  stronger shot); three one-timers in a row make "team fire"; knock-downs are not penalised [A6].
- Blades of Steel: five a side, icing but no offside; a fight's loser takes the penalty, so a fight decides a power
  play; games end in a shootout [A7].

### Stage 1: the fantasy
"I'm the playmaker: I slip past the big hit and thread the pass across the crease, and the one-timer is in before the
goalie can move." Aesthetics: sensation (speed, the hit, the goal) and challenge.

### Stage 2: pillars
1. **Every goal is a play you made** (a pass, a deke, a one-timer). Rules out goals from long, unscreened shots, goalie
   blunders as the main source of goals, and lucky deflections.
2. **Speed with the puck is a risk you chose.** The carrier is slower than a free skater, a pass beats skating, the
   burst check punishes a carrier who holds on. Rules out a glued puck, a carrier who outruns everyone, and random
   turnovers with no cause the player can name.
3. **You can read the rink at a glance.** You always know which skater is yours, where the puck is and who will hit
   you. Rules out a low chase camera, a puck the size of a coin, and scrums of merged bodies.

### Stage 3: the core loop
- **3 s:** carry, then pass or shoot; on defence, switch to the nearest skater and poke or burst-check. The decision:
  pass now, or carry one more stride into the hit.
- **30 s:** a rush: a zone entry, a pass across, the one-timer or the save; a turnover from a check and the rush the
  other way. The decision: the safe pass to the point or the risky pass across the crease.
- **3 min:** a period with a score state (protect a lead, press when behind; the CPU pulls its goalie when it trails
  late [A3]).
- **Dynamics we want to see:** players pass to beat the check (because the carrier is slower), cut across the crease
  (because the goalie cannot get across in time), and switch defenders before the pass lands.

### Stage 4: the 30-second test
- **0-5 s:** the faceoff drops by itself; the newcomer's skater has a ring under him; the stick moves him with a small
  skid; one hint line: "B pass, C shoot".
- **5-15 s:** a slow first defender lets him carry; he passes once (B) and control jumps to the receiver: he made a
  play.
- **15-30 s:** a teammate cuts across the crease, he passes and shoots as it arrives: the one-timer is in, the organ
  plays, the camera holds the goal for a moment. "I scored off a pass."

### Stage 5: the feel spec (starting numbers to tune by hand)
- Inputs: three (move, pass/switch, shoot/burst) [A2, A3]. Visible response within 3 frames (METHOD.md section 8).
- The carrier at about 0.88 of a free skater's speed, a pass about twice cruise speed (HOCKEY-ARCADE.md section 5.2,
  house numbers, not NHL '94's own).
- A skid on reversal before the turn [A3]: a deceleration the player can learn, not an instant stop.
- The one-timer window: the shot pressed while the pass is in flight, shooting harder than a wrist shot [A3]. The
  window length in NHL '94 is unmeasured; start wide and narrow it by hand.
- The burst check: a big, loud hit with a quick get-up (NHL Hitz [A6]; GAME-QUALITY.md section 4).
- The camera: a broadcast view down the rink at about 50 degrees (the house hockey's `follow` numbers), the puck drawn
  bigger with a rim (GAME-QUALITY.md section 13).
- The goal: a hold of the camera, the horn and organ, the scorer's own reaction.
- Periods: short (2 to 5 minutes for us), restart within 2 s.

### Stage 6: the teardown (copy, change, drop)
- **Copy:** the three inputs with a second meaning on defence; switch to the nearest skater on the pass button; the
  one-timer as the loudest goal; momentum with a skid; the burst check; invulnerable goalies; no offside and no
  penalties by default; short periods; a goal that is celebrated.
- **Change:** five a side to three a side (NHL Hitz [A6]) so the rink reads and the AI has room; the "on fire" streak
  as a visible comeback rule (three goals, ended when the other side scores).
- **Drop:** line changes, fatigue, icing, the fight minigame (until the core plays), and the dominant deke the players
  had to ban [A5] (keep an AI answer to it instead).

### Stage 6b: thirdjam, our own reference (N1, 23 Nov)
(N1's teardown interim is due at about 01:00; its findings go here: the controls, the numbers, the AI and what it got
right that the house hockey lost.)

### Stage 7: the greybox
Flat rink, boards, two nets, a big puck, three skaters a side and goalies as capsules with sticks; move, pass/switch,
shoot/burst; the broadcast camera; the tuning file with every number above. The person plays it 5 minutes with the
playtest card. Nothing else is built until he passes it.

### Stage 8: kill criteria
- KILL IF: after a turnover the newcomer cannot find the puck or his own skater within 2 seconds.
- KILL IF: in 5 minutes no goal comes from a pass; every goal is a long shot or a goalie error.
- KILL IF: skaters merge into one blob at the boards, so nobody can tell who has the puck.
- KILL IF: the carrier is caught within 2 seconds every time, so nobody skates with the puck.

### What our build did instead (19-22 Nov)
- The house hockey has skating, passing, pokes, checks, one-timers and goals through the mouth; its metrics are in band
  (shots 2.2 to 3.0 a minute, 2.6 to 3.4 goals a match, a ladder that rises with skill; 22 Nov night verdict).
- The owner played it and called it "unplayable garbage" (22 Nov, 18:35). Earlier he named the causes: "puck
  stickiness, players speed, ability AI to decide what to do, when to pass and shoot" (21 Nov, HOCKEY-ARCADE.md).
- The editor's hockey jobs (-2, -3) passed every tofu row and still showed board scrums, a puck too small to find and
  no hit-stop (D3 report).
- What the method would have caught: stage 2's third pillar (read the rink at a glance) and the kill lines on the blob
  and the lost puck are things a person sees in the first minute; no person was asked to look for them.

### The method lines a hockey brief carries
```
FANTASY: I'm the playmaker: I slip the big hit and thread the pass across the crease for a one-timer. Sensation, challenge.
TEARDOWN: NHL 94: pass with B, press C while the pass travels: the receiver one-times it, harder than a wrist shot.
TEARDOWN: NHL 94: B on defence switches to the skater nearest the puck; C bursts into a body check.
30 SECONDS: 0-5 s the puck drops, a ring marks you, B passes and C shoots; 5-15 s you pass and control jumps to the receiver; 15-30 s a teammate cuts across, you pass and one-time it in, the horn sounds.
KILL IF: after a turnover a newcomer cannot find the puck or his own skater within 2 seconds.
KILL IF: in 5 minutes no goal comes from a pass.
KILL IF: skaters merge into one blob at the boards.
```

### Sources (Case A)
- A1. Sal Barry, "The Making of NHL '94: An Oral History", The Hockey News (2018):
  https://thehockeynews.com/news/all-access/the-making-of-nhl-94-an-oral-history
- A2. David Satriano and Daniel O'Leary, "NHL '94 video game has enduring popularity 25 years later", NHL.com (2018):
  https://nhl.com/news/nhl-94-enduring-popularity-25-years-later-301326816
- A3. NHL Hockey '94, Sega Genesis manual (EA Sports, 1993), archive.org scan read from the page images:
  https://archive.org/download/SEGAGenesisMegaDriveManuals/NHL%20%2794%20%28USA%2C%20Europe%29.pdf
- A4. "NHL '94", Wikipedia: https://en.wikipedia.org/wiki/NHL_%2794
- A5. Arda Ocal, "Inside the decision to revive NHL '94", ESPN (2020):
  https://africa.espn.com/nhl/story/_/id/30151120/inside-ea-sports-decision-revive-nhl-94
- A6. "NHL Hitz 20-02", Wikipedia: https://en.wikipedia.org/wiki/NHL_Hitz_2002
- A7. Greg Wyshynski, "Blades of Steel vs. Nintendo Ice Hockey, 30 years later", ESPN (2018):
  https://www.espn.com/nhl/story/_/id/25155303
- A8. Our own: `docs/research/HOCKEY-ARCADE.md`, the 22 Nov night and day verdicts, the D3 editor report, N1's thirdjam
  teardown (23 Nov).

---

## Case B: a melee duel (For Honor, with Souls and fighting games)

### What makes a duel fun: rules, numbers, moments

**Rules and numbers**
- **Defence is a choice, not a button.** For Honor guards and attacks in three directions; you "brace on the same side
  they attack", with no "magical 'block button'". Jason VandenBerghe (creative director): "You choose where you block,
  you choose where you attack, you can bluff, you can strategize, you can adapt on the fly" [B1].
- **Reaction windows are designed, in milliseconds.** For Honor runs at 30 fps; guard switch takes 100 ms; the team
  keeps at least 100 ms between a successful and a failed block because 33 ms "felt too close" [B4, B5]. Since 2020 the
  first 100 ms of every attack is hidden, so a 500 ms light shows 400 ms, and after the 100 ms guard switch about 200 ms
  are left to react: parrying fast attacks "becomes a read rather than a reaction" [B4]. A 500 ms light is 30 frames
  (conv.).
- **The reward is uneven, so the guess matters** (Sirlin: rock-paper-scissors needs "way different payoffs for winning
  with each option" [B9]). For Honor: parrying a heavy gives a fast punish, parrying a light a free heavy (2018 notes,
  [search]) [B6].
- **Passive play loses.** Blocks take 18 % chip damage (it cannot kill); stamina regeneration pauses 400 to 600 ms
  after a dodge and 500 ms after a block; a player who runs gets -20 % speed and the chaser +30 %; at the timeout the
  higher health share wins [B3].
- **Out of stamina is a visible state**: no parry, dodges 200 ms longer, attacks "much slower", throws knock you down
  [B3].
- **Evasion pays in recovery.** Elden Ring's roll has 14 invulnerable frames at 30 fps at light or medium load, 13 at
  heavy (about 28 and 26 at 60 Hz, conv.) [B7]; Dark Souls rolls all have 11 i-frames, but a fat roll lasts 46 to 48
  frames against a fast roll's 21 to 24, with 25 frames of extra damage taken [B8].
- **Fighting-game timing**: Street Fighter 6's standing light punch has 4 frames of startup, 3 active, -1 on block
  ([search]) [B11]; SF6 widened its dash input buffer from 4 to 7 frames [B12]. Hit-stop figures of 8/12/16 frames for
  light/medium/heavy appear in a Capcom column only as an illustration ([search]) [B13]; our house range is 3 to 8,
  scaled by force (GAME-QUALITY.md section 2).
- **Short rounds with a clear end**: first to two rounds; on time over the round goes to more health (Street Fighter
  II) [B10].
- **Minimal duels prove the core**: FOOTSIES has one attack button and movement, and "spacing, hit confirm and whiff
  punish are keys to achieve victory" [B14]; Divekick has two buttons and one hit ends a round [B15].

**Moments players remember**
1. Holding your ground. VandenBerghe: "The most important emotion of battle is the decision to not run", and of the
   1v1, "that moment is the entire point of the game" [B2].
2. The parry punish: reading his heavy, parrying, landing the free heavy [B6].
3. The whiff punish: his attack misses at the edge of reach and you hit his recovery [B14].
4. The last-instant roll through a swing [B7, B8].
5. The feint that lands: a heavy cancelled into a guard break while he committed to the parry [B3].

### Stage 1: the fantasy
"I read him like a book: I see his heavy coming, parry it, and punish him while he staggers." Aesthetics: challenge
and fantasy (the duellist).

### Stage 2: pillars
1. **Every exchange is a read.** Rules out attacks with no readable wind-up (under 20 frames from a rival), auto-block,
   and hit outcomes decided by chance.
2. **Holding your ground is the decision** [B2]. Rules out kiting and running as a winning plan (For Honor's runner
   penalty [B3]) and attacks from out of reach.
3. **A mistake shows, and it costs.** Rules out safe whiffs, moves without recovery, and damage the player cannot see
   coming or name afterwards.

### Stage 3: the core loop
- **3 s:** at the edge of reach, attack or wait; the defender blocks, parries or rolls. The decision: commit now, or
  wait for his whiff.
- **30 s:** a round against one rival whose habit is his defence (the Wall absorbs, the Duelist parries, the Dancer
  avoids; DUEL-PLAYBOOK 6.7). The decision: press him, or bait his habit.
- **3 min:** best of three against him, then the next rival; the rally rule (under 35 % health) as the comeback.
- **Dynamics we want to see:** players bait the heavy because its recovery is long; they space at the edge of reach;
  they mix a parry with a roll because a repeated parry shrinks its window.

### Stage 4: the 30-second test
- **0-5 s:** the ring, your fighter over the shoulder, the Wall 3 m away; press light and the sword moves within 3
  frames; one hint line: "LMB light, SPACE guard (tap it to parry)" (the house duel's keys).
- **5-15 s:** the Wall walks in and winds up a slow heavy (32 frames, the tag HEAVY over his head); you hold guard, his
  weapon bounces off and he recoils; OPEN shows; you strike him.
- **15-30 s:** he winds up again; you tap guard on the swing: his weapon is knocked away, he staggers, your heavy lands
  with both bodies held still for a moment. "I parried him."

### Stage 5: the feel spec (the house duel's numbers, `engine/packs/duel/data/moves.json`)
- light 18 / 4 / 16 (wind-up, active, recovery), chained follow-ups 12; heavy 32 / 5 / 28; charged 54 / 6 / 36,
  unblockable; bash 14 / 6 / 24; parry frames 2 to 13 of a guard press (Sekiro's deflect: press = window, hold =
  block), a repeated tap shrinks it; roll 3 / 18 / 15.
- A rival's dangerous attack shows at least 20 frames of wind-up in the body (For Honor's readable floor is about 24
  visible frames for a 500 ms light, conv. [B4]).
- Hit-stop 3 to 8 frames on both bodies, scaled by force; every contact changes both bodies (DUEL-PLAYBOOK section 2).
- Input buffer 8 frames (house; SF6's dash buffer is 7 [B12]).
- Stamina pauses after a block or a dodge (For Honor's 400 to 600 ms [B3], about 24 to 36 frames, conv.).
- The camera over the shoulder, offset, looking between the fighters, over a low ring wall (the duel's
  `data/tuning.json` `camera`).

### Stage 6: the teardown (copy, change, drop)
- **Copy:** the uneven parry reward (parry a heavy: a light is guaranteed; parry a light: a heavy); chip damage on a
  held block and a stamina pause after it, so turtling loses; roll i-frames with a punishable recovery; best of three;
  FOOTSIES' whiff punish as the first skill.
- **Change:** For Honor's three-direction guard becomes one guard with lock-on (one stick, mouse and keyboard); its
  500 ms lights become 18-frame wind-ups we can read on our camera; posture from Sekiro replaces a long stamina game.
- **Drop:** feints and guard-break mix-ups until the core is called fun (they are the ceiling, not the floor); Revenge
  (a team mechanic); ledges.

### Stage 7: the greybox
A flat ring with a low wall, two fighters with their weapons and their own silhouettes, light, heavy, guard/parry and
roll, the Wall alone, the health, stamina and posture bars, the over-the-shoulder camera, every number in the tuning
file. The person plays it 5 minutes with the playtest card.

### Stage 8: kill criteria
- KILL IF: in 5 minutes the newcomer never parries on purpose, because he cannot see the heavy coming.
- KILL IF: from the shoulder camera a hit and a block look the same (no recoil, no stagger, no different sound).
- KILL IF: mashing light beats the Wall in more than one round of three.
- KILL IF: the newcomer loses a round and cannot say why.

### What our build did instead (21-22 Nov)
- The house duel landed 13 rounds: every contact changes both bodies, hit-stop on both, the Wall, the Duelist and the
  Dancer, threat tags, lesson rounds, a loss card; its ladder rises from newcomer to perfect (22 Nov night verdict).
- The lane's own read: "a readable, teachable duel with distinct opponents, a vertical slice of the For Honor loop at
  toy scale; not yet a game that sells itself by its feel. It is still one shared move set, re-dressed per rival."
- The owner, playing it: "the fact players can punch in arena and take damage does not mean we delivered fun fighting
  game" (22 Nov, 18:35).
- What the method would have caught: nobody played the greybox before the rivals, the tags and the lessons were built
  on it. Kill lines 1 and 2 are a 5-minute check by hand; the ladder figures were read through scripted hands only.

### The method lines a duel brief carries
```
FANTASY: I read him like a book: I see his heavy coming, parry it, and punish him while he staggers. Challenge, fantasy.
TEARDOWN: For Honor: parry a heavy and a light is guaranteed; parry a light and a heavy is; blocks chip 18 percent.
TEARDOWN: FOOTSIES: one attack and movement; the round is won by spacing and punishing the other's whiff.
30 SECONDS: 0-5 s the Wall stands 3 m away, light swings within 3 frames; 5-15 s he winds up a slow heavy, you guard, he recoils, you strike; 15-30 s you tap guard on his swing, he staggers, your heavy lands.
KILL IF: in 5 minutes a newcomer never parries on purpose, because he cannot see the heavy coming.
KILL IF: from the shoulder camera a hit and a block look the same.
KILL IF: mashing light beats the Wall in more than one round of three.
```

### Sources (Case B)
- B1. Emile Gauthier, "For Honor: The Art of Battle", Ubisoft (2015):
  https://www.ubisoft.com/en-us/game/for-honor/news-updates/3i9GE9e7XGWHqKQH2wUtZc/for-honor-the-art-of-battle
- B2. Jeremy Peel, "For Honor making of", PCGamesN (2017): https://www.pcgamesn.com/for-honor/for-honor-making-of
- B3. Ubisoft, "Public Test Meta Changes" (2017):
  https://www.ubisoft.com/en-us/game/for-honor/news-updates/1IZoiczWorTTTsrEYprgzR/public-test-meta-changes
- B4. Ubisoft, "Testing Grounds: How attacks are changing" (2020):
  https://www.ubisoft.com/en-us/game/for-honor/news-updates/9OPowoU28h2YRO8zSvw5z/testing-grounds-how-attacks-are-changing
- B5. Ubisoft, "Input delay in For Honor" (2018):
  https://www.ubisoft.com/en-us/game/for-honor/news-updates/4qgcoZf3m61lpWD8GlN4JO/input-delay-in-for-honor
- B6. For Honor patch notes v1.19 (2018) [search]:
  https://www.ubisoft.com/en-us/game/for-honor/news-updates/4Gac0PdHqfVBpbfa3UeWmF/patch-notes-v119
- B7. Elden Ring wiki, "Invincibility Frames": https://eldenring.wiki.gg/wiki/Invincibility_Frames
- B8. Dark Souls wiki, "Equip Load": https://darksouls.wiki.fextralife.com/Equip+Load
- B9. David Sirlin, "Designing Yomi" (2014): https://www.sirlin.net/articles/designing-yomi
- B10. "Street Fighter II", Wikipedia: https://en.wikipedia.org/wiki/Street_Fighter_II
- B11. SF6 Ryu frame data, GameSkinny [search]:
  https://www.gameskinny.com/tips/street-fighter-6-ryu-frame-data-analysis-guide/
- B12. Street Fighter 6 update 1.05 notes, MP1st:
  https://mp1st.com/news/street-fighter-6-update-1-05-slithers-out-to-add-aki-and-more
- B13. Capcom, "SF Seminar" column on hit-stop [search; the page refused the fetch]:
  https://game.capcom.com/cfn/sfv/column/131545?lang=en
- B14. HiFight, FOOTSIES (source and readme): https://github.com/hifight/Footsies
- B15. "Divekick", Wikipedia: https://en.wikipedia.org/wiki/Divekick
- B16. Our own: `docs/research/DUEL-PLAYBOOK.md`, `engine/packs/duel` (README, `data/moves.json`), the 22 Nov night
  verdict.
