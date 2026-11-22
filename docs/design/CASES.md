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
   you, and there is open ice between the players. Rules out a camera that loses your skater, a puck the size of a
   coin, figures so big the rink is a corridor, and scrums of merged bodies.

### Stage 3: the core loop
- **3 s:** carry, then pass or shoot; on defence, switch to the nearest skater and poke or burst-check. The decision:
  pass now, or carry one more stride into the hit.
- **30 s:** a rush: a zone entry, a pass across, the one-timer or the save; a turnover from a check and the rush the
  other way. The decision: the safe pass to the point or the risky pass across the crease.
- **3 min:** one continuous match to three goals (thirdjam [A9]), with a score state: protect a lead, press when
  behind (NHL '94's CPU pulls its goalie when it trails late [A3]).
- **Dynamics we want to see:** players pass to beat the check (because the carrier is slower), cut across the crease
  (because the goalie cannot get across in time), and switch defenders before the pass lands.

### Stage 4: the 30-second test
- **0-5 s:** the faceoff drops after a short countdown and a clean press wins it (thirdjam [A9]); a chevron and a ring
  mark the newcomer's skater; the controls panel stays on screen; he skates with a small skid.
- **5-15 s:** a slow first defender lets him carry; he passes once (RMB) and control jumps to the receiver: he made a
  play.
- **15-30 s:** a teammate cuts across the crease, he passes and shoots (LMB) as it arrives: the one-timer is in, the
  horn sounds, the camera holds the goal for a moment. "I scored off a pass."

### Stage 5: the feel spec (starting numbers to tune by hand)
- **The size of the world first** (N1's first lesson [A9]): body size, the rink in body widths, speeds in body heights
  a second, the camera distance in body heights, written down before any mechanic. thirdjam: a 90 x 45 m rink and a
  contact circle of 0.4 m, so the rink is 112 body widths long (a real rink is about 100) and a cruising skater moves
  about 7 of his own heights a second. Ours: 60 x 30 m and a contact radius of 0.879 m (figures drawn 2.2x), 34 body
  widths, about 2.1 heights a second: the same crossing time, but it looks like a jog in a corridor [A9].
- Inputs: few, with a second meaning on defence (NHL '94's move, pass, shoot [A2, A3]; thirdjam's LMB shoot or
  cross-check, RMB pass or check [A9]). Visible response within 3 frames (METHOD.md section 8).
- The carrier slower than a free skater (thirdjam x0.92, ours x0.88 [A9]); everyone may sprint, bots too (thirdjam by
  level; ours: only the human [A9]).
- A skid on reversal before the turn [A3]: a deceleration the player can learn, not an instant stop.
- **The puck slows on the ice** (thirdjam: drag 0.5/s plus friction 0.147 m/s^2, so a 14 m/s pass stops after about
  26 m) and **a pass is solved to arrive** at about 8 m/s where the receiver will be, held to cross a third of the
  rink [A9]. Ours has no drag and fixed 18 or 23 m/s passes, patched by a dozen own-goal guards [A9].
- The one-timer window: the shot pressed while the pass is in flight, shooting harder than a wrist shot [A3]. The
  window length in NHL '94 is unmeasured; start wide and narrow it by hand.
- **Shooting forgives the screen**: thirdjam snaps the shot to the goal inside 8 degrees (16 on a one-timer) and
  doubled the shot speed on the owner's order [A9]; aiming exactly at a cursor through a moving camera is not a skill.
- The check: big in the body, with a quick get-up (NHL Hitz [A6]), but drawn as the figure only: the owner ruled out
  rings and boxes at a hit in thirdjam, "the player animation should reflect the crosscheck movement and that should
  be all" [A9]. Hit-stop is presentation only, only on a knockdown that involves you (thirdjam [A9]), never a freeze
  of the whole game.
- **The camera keeps YOU in one place on the screen** (thirdjam: behind and above you, 6 m back, 3.5 m up, a 4-frame
  lag, with an aim anchor so a still hand keeps its stick point through camera moves [A9]), and the screen points at
  the puck when it is off it (a far-net badge, edge chevrons, a radar [A9]). Ours follows the puck, and the stick swings
  when the hand does not [A9]. NHL '94's vertical rink [A4] is the other proven answer; the person decides between
  them on the greybox, as a tuning knob.
- The goal: a hold of the camera, the horn, the scorer's own reaction; a face-off after it, no replay in the way.

### Stage 6: the teardown (copy, change, drop)
- **Copy from NHL '94:** the few inputs with a second meaning on defence; switch to the nearest skater on the pass
  button; the one-timer as the loudest goal; momentum with a skid; invulnerable goalies; no offside and no penalties by
  default; a goal that is celebrated.
- **Copy from thirdjam** [A9]: the scale; the puck's friction and the solved pass; teammates who shoot and drive the
  net; difficulty by clumsiness, never by absence ("a level is easy by clumsiness, never by absence", the owner's
  ruling); the camera behind you with the aim anchor; the snap cone on shots; the controls panel that stays; one run
  to three goals; and the owner's 75 rulings, verbatim, as design assets.
- **Change:** NHL '94's five a side to three a side (NHL Hitz [A6]) only if the greybox shows the rink reads better;
  thirdjam plays five a side with no goalies.
- **Drop:** line changes, fatigue, icing, fights, loud hit effects, whole-game freezes, 36-second periods, and the
  dominant deke players had to ban [A5] (keep an AI answer to it instead).

### Stage 6b: thirdjam, our own reference (N1, 23 Nov)
thirdjam is the hockey game this studio shipped for a jam (15-16 Nov). The owner: "a mediocre hockey game we delivered
but at least it has set basic gameplay mechanics, AI, bugless graphics and balanced speed." N1 ran it on this machine
beside our `engine/packs/hockey` and read both system by system, with file and line on each side [A9]. Its top ten,
ranked by what each costs the player:
1. **There is no ice in ours**: 34 body widths of rink against thirdjam's 112; four or more of the six field skaters
   within 5 m of the puck in 15-16 % of live play. The scale came from a drawing fix on 16 Nov, never from a design
   decision.
2. **Our teammates refuse to play**: they shoot only within 4 s of your own pass or shot and hold 8 m out of the net, a
   rule made so an idle hand loses the ladder. thirdjam's mates shoot and drive the net.
3. **Our camera follows the puck, not you**, and the stick moves when the hand does not.
4. **Our puck has no friction and our passes leave at a fixed speed.**
5. **Our game keeps stopping**: 36-second periods, a whole-game freeze on hard hits 3.8 times a minute, goal holds,
   replays. thirdjam is one run to three goals.
6. **Our figures glitch**, and our own README lists it.
7. **Hits decide our game and are drawn loudly**, which the owner had ruled out in thirdjam.
8. **Our bots read the play 5-18 frames late, decide at 4 Hz, and never sprint**; thirdjam's decide every frame with
   no delay.
9. **Our shooting asks for a precision the screen cannot give**; thirdjam snaps to the net.
10. **Our screen stops explaining itself after the first key**; thirdjam keeps its controls panel, chevron and radar.

**The finding under all ten:** by thirdjam's own first-five-minutes measures ours scores better (first touch 0.6-0.7 s
against 1.8 s; the puck on your blade 18-21 % of the time against 10 %), and the owner calls ours garbage. Our
measures cannot see what he sees [A9]. thirdjam was judged differently: the owner played it five times and each verdict
became numbered rulings in his words; a standing "design eye" ranked "the ten things a first-time player feels in five
minutes", and that list outranked every lane's own bars [A9].

### Stage 7: the greybox
Flat rink at the scale of stage 5, boards, two nets, a big puck that slows on the ice, three skaters a side and
goalies as capsules with sticks; move, pass/switch, shoot/check; the camera behind you with the aim anchor and the
broadcast view as a tuning knob; the controls panel; the tuning file with every number above. The person plays it 5
minutes with the playtest card and ranks what he felt. Nothing else is built until he passes it.

### Stage 8: kill criteria
- KILL IF: after a turnover the newcomer cannot find the puck or his own skater within 2 seconds.
- KILL IF: in 5 minutes no goal comes from a pass; every goal is a long shot or a goalie error.
- KILL IF: skaters bunch into one scrum round the puck, so nobody can tell who has it or skate into open ice.
- KILL IF: the carrier is caught within 2 seconds every time, so nobody skates with the puck.
- KILL IF: the game stops (a freeze, a clock, a replay) more often than the newcomer gets the puck.

### What our build did instead (16-22 Nov)
- The house hockey has skating, passing, pokes, checks, one-timers and goals through the mouth; its metrics are in band
  (shots 2.2 to 3.0 a minute, 2.6 to 3.4 goals a match, a ladder that rises with skill; 22 Nov night verdict), and it
  beats thirdjam on thirdjam's own first-five-minutes measures [A9].
- The owner played it twice and called it "unplayable" both times (21 Nov; 22 Nov, 18:35: "unplayable garbage"). He
  had named the causes: "puck stickiness, players speed, ability AI to decide what to do, when to pass and shoot"
  (HOCKEY-ARCADE.md).
- It ported thirdjam's skating and contact line by line into a world three times smaller, with another camera:
  "ports move numbers, not experience" (N1 [A9]). Rules were added to pass bot metrics (teammates who hold back so an
  idle hand loses) without a person ever facing them.
- The editor's hockey jobs (-2, -3) passed every tofu row and still showed board scrums, a puck too small to find and
  no hit-stop (D3 report).
- What the method would have caught: stage 5's scale sheet (34 body widths is a corridor), the third pillar and the
  kill lines on the scrum and the lost puck are things a person sees in the first minute; no person was asked to look.

### The method lines a hockey brief carries
```
FANTASY: I'm the playmaker: I slip the big hit and thread the pass across the crease for a one-timer. Sensation, challenge.
TEARDOWN: NHL 94: pass, then press shoot while the pass travels: the receiver one-times it, harder than a wrist shot.
TEARDOWN: thirdjam: a 90 x 45 m rink, 112 body widths long; the puck slows on the ice and a pass arrives at 8 m/s.
30 SECONDS: 0-5 s a countdown, you win the draw, a chevron marks you; 5-15 s you pass and control jumps to the receiver; 15-30 s a teammate cuts across, you pass and one-time it in, the horn sounds.
KILL IF: after a turnover a newcomer cannot find the puck or his own skater within 2 seconds.
KILL IF: in 5 minutes no goal comes from a pass.
KILL IF: skaters bunch into one scrum round the puck, so nobody skates into open ice.
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
- A8. Our own: `docs/research/HOCKEY-ARCADE.md`, the 22 Nov night and day verdicts, the D3 editor report.
- A9. N1 (night of 22-23 Nov), the thirdjam teardown: interim
  `docs/shifts/2026-11-23-night/lanes/N1-teardown/INTERIM.md` (20:09), full text with
  file and line on both sides `docs/research/hockey-teardown/TEARDOWN.md`, and the owner's 75 thirdjam rulings
  distilled, verbatim, `docs/research/hockey-teardown/RULINGS.md` (both on main);
  thirdjam itself: https://github.com/xkazm04/thirdjam (HEAD 8dc713c6, read and run by N1).

---

## Case B: a melee duel (For Honor, with Souls, Sekiro and fighting games)

### What makes a duel fun: rules, numbers, moments

**Rules and numbers**
- **Defence is a choice, not a button.** For Honor guards and attacks in three directions; you "brace on the same side
  they attack", with no "magical 'block button'". Jason VandenBerghe (creative director): "You choose where you block,
  you choose where you attack, you can bluff, you can strategize, you can adapt on the fly" [B1].
- **Attacks are timed for a human eye.** For Honor's neutral lights were slowed from 400 ms (24 frames) to 500 ms (30)
  in 2020; heavies take 800 to 1000 ms (48 to 60) [B18, B6]. A person's average reaction is about 250 ms (15 frames), and
  reacting reliably to 20 frames of startup is good [B25]. A Souls attack's signal plus attack lasts at least 340 ms
  (20 frames), its hitbox is live 2 to 4 frames, and then comes the punish window, "generally the longest" phase [B26].
- **The reaction window is designed.** For Honor keeps at least 100 ms between a successful and a failed block because
  33 ms "felt too close" [B5]; the first 100 ms of an attack are hidden, so parrying a fast attack "becomes a read
  rather than a reaction" [B4]. Sekiro's deflect window is 12 frames, shrinking to 4 with repeated presses and reset
  after about 30 frames ([CM]) [B20].
- **The body tells; a glyph confirms.** "Its silhouette should be discernable and naturally hints the incoming attack"
  (the opening pose of a Souls attack [B26]). Where For Honor and Sekiro draw a signal, it is a colour or a glyph on the
  weapon or the guard icon (an unblockable's red trail; Sekiro's red "Danger" kanji, each perilous attack with ONE
  answer) [B19, B20], read at a glance while the body does the attack. Never words.
- **The reward is uneven, so the guess matters** (Sirlin: rock-paper-scissors needs "way different payoffs for winning
  with each option" [B9]). For Honor: a parried heavy leaves the attacker 600 ms (36 frames) unable to block, parry or
  dodge (a free light); a parried light 900 ms (54 frames), a free heavy, because "parrying a Light is generally more
  difficult and should lead to a larger punishment" [B17].
- **Passive play loses.** Blocks take 18 % chip damage "to make blocking less effective as a stalling tool"; stamina
  regeneration pauses 400 to 600 ms after a dodge and 500 ms after a block; a runner gets -20 % speed and the chaser
  +30 % [B3]. Its known flaw all the same: "predictable defensive play is unpunishable" [B28].
- **Pressure has a rhythm.** "An enemy attacks the player every two-to-three seconds on average" (120 to 180 frames),
  in a survey of melee games [B23].
- **Evasion pays in recovery.** Elden Ring's roll has 14 invulnerable frames at 30 fps at light or medium load (about 28
  at 60 Hz, conv.) [B7]; Dark Souls' fat roll lasts 46 to 48 frames against a fast roll's 21 to 24 [B8].
- **Weight comes from hit-stop.** Sakurai: "both parties momentarily freeze, emphasizing the power of impact" [B27];
  Smash's hitlag is about 6 frames at 1 % damage, 12 at 10 %, 19 at 20 % [B27]; Capcom's illustration is 8 / 12 / 16 for
  light / medium / heavy ([search]) [B13].
- **Teaching waits for you.** For Honor's tutorial runs dummies, then the guards, then one easy soldier, and repeats each
  task "two or three times, from each side, before progressing" [B19]; Sekiro's practice partner, Hanbei, cannot die
  [B22]. (For Honor later "drastically shortened" its tutorial and replaced it with a match against the AI [B29]: long
  scripted teaching is not the goal either.)
- **A loss feels justified.** Miyazaki: players should "understand why they were killed ... and it feels justified"
  [B24]; FromSoftware gets there through an attack whose body tells it, not through a card afterwards.
- **Few meters.** Sekiro builds its whole duel on two bars, vitality and posture [B21].
- **Minimal duels prove the core**: FOOTSIES has one attack button and movement, and "spacing, hit confirm and whiff
  punish are keys to achieve victory" [B14]; Divekick has two buttons and one hit ends a round [B15].
- **Not found in any source** (N1 [B30]): how long a duel round should last, and that a tutorial opponent waits until
  the player succeeds. Both are OUR design calls below, to be tested by hand.

**Moments players remember**
1. Holding your ground. VandenBerghe: "The most important emotion of battle is the decision to not run", and of the
   1v1, "that moment is the entire point of the game" [B2].
2. The parry punish: reading his heavy as he coils, parrying, landing the free heavy [B17].
3. The whiff punish: his attack misses at the edge of reach and you hit his recovery [B14].
4. The last-instant roll through a swing [B7, B8].
5. The feint that lands: a heavy cancelled into a guard break while he committed to the parry [B3].

### Stage 1: the fantasy
"I read him like a book: I see him coil for the heavy, parry it, and punish him while he staggers." Aesthetics:
challenge and fantasy (the duellist). N1's sentence for the first minute: "I see him coil, I hold block, he bounces off,
I hit him, he is hurt, I am pleased" [B30].

### Stage 2: pillars
1. **His body tells you everything.** Rules out words over his head, tells shorter than a person can read (under 20
   frames from a rival), and two generic clips slowed down to stand for every attack.
2. **Holding your ground is the decision** [B2]. Rules out kiting and running as a winning plan (For Honor's runner
   penalty [B3]) and a round so short there is no second exchange.
3. **A mistake shows, and it costs.** Rules out safe whiffs, moves without recovery, and damage the player cannot see
   coming or name afterwards.

### Stage 3: the core loop
- **3 s:** at the edge of reach, attack or wait; the rival coils, and the player blocks, parries or rolls. The
  decision: commit now, or wait for his whiff. A rival attacks about every 2 to 3 seconds [B23].
- **30 s:** a few exchanges in which the player learns this rival's habit: his defence (absorb, parry, avoid;
  DUEL-PLAYBOOK 6.7) AND his own moves (For Honor's moves are per hero; each of Sekiro's perilous attacks has one named
  answer [B20]). The decision: press him, or bait his habit.
- **3 min:** best of three rounds [B10] of **45 to 90 seconds each (our design call: no source gives a duel round length;
  tested by hand)**, then the next rival, a new problem, not the same fighter faster.
- **Dynamics we want to see:** players bait the heavy because its recovery is long; they space at the edge of reach;
  they mix a parry with a roll because a repeated parry shrinks its window.

### Stage 4: the 30-second test
- **0-5 s:** the ring, your fighter over the shoulder, the Wall 3 m away, **waiting**; press light and the sword moves
  within 3 frames; one hint line: "LMB light, SPACE guard (tap it to parry)" (the house duel's keys).
- **5-15 s:** the Wall coils for a slow heavy, **in his body** (a wind-up of 48 frames or more, the weapon drawn far
  back); you hold guard, his weapon bounces off and he recoils; you strike him. **He does not attack again until you have
  blocked once (our design call: For Honor repeats each task, Sekiro's partner cannot die, but no source says the
  partner waits [B19, B22, B30]; tested by hand).**
- **15-30 s:** he coils again; you tap guard as it lands: his weapon is knocked away, he staggers, your heavy lands with
  both bodies held still for a moment. "I parried him."

### Stage 5: the feel spec (starting numbers to tune by hand; the house duel's in brackets)
- **Wind-ups timed for a person**: a rival's light at least 24 frames of readable wind-up, ideally 30 (For Honor
  [B18]); a heavy 48 to 60 [B6]; a chained follow-up never under 20 (the reliable-reaction floor [B25]). [House: light
  18, chained light 12, heavy 32: about 40 % faster than For Honor's, and the plays-twice checklist accepts a 12-frame
  tell [B30].]
- **The tell is in the body**: a coil of the weapon and the torso that a person reads from the shoulder camera; at most
  a colour or glyph on the weapon for the unblockable (For Honor's red trail [B19]); no words over the head. [House:
  HEAVY / BASH / UNBLOCKABLE / OPEN tags, cue lines and banners carry the tell; every attack is one of two rig clips
  through a frame map [B30].]
- **The answers**: a parry window of about 12 frames that shrinks when spammed (Sekiro [B20]); a parried heavy leaves
  the attacker open about 36 frames, a parried light about 54 (For Honor [B17]); roll i-frames about 28 (Elden Ring
  [B7]) with a punishable recovery; chip on a held block. [House: parry frames 2-13 of a guard press.]
- **Weight**: hit-stop on both bodies, about 6 to 8 frames on a light and 12 to 16 on a heavy (Smash, Capcom [B27,
  B13]). [House: 5 and 9 [B30].]
- **Pacing**: a rival attack every 2 to 3 seconds [B23], with room between exchanges for the player to try something;
  rounds of 45 to 90 seconds (our call). [House: 93 of 93 measured rounds ended by a knockout, median 18 to 24 s,
  against a 70 s clock; the rival never idles past 120 frames [B30].]
- **The screen**: two bars a fighter (vitality and posture, Sekiro [B21]) and the round state. [House: health,
  stamina and posture bars, EXHAUSTED, RALLY, BROKEN, stars, a crowd meter, tags, cues, banners, a key strip, cause
  cards: a dashboard [B30].]
- Input buffer 8 frames (house; SF6's dash buffer is 7 [B12]). The camera over the shoulder, offset, looking between
  the fighters, over a low ring wall (the duel's `data/tuning.json` `camera`).

### Stage 6: the teardown (copy, change, drop)
- **Copy:** For Honor's attack speeds (lights 24 to 30 frames, heavies 48 to 60) and its uneven parry reward; chip on
  a held block and a stamina pause after it; Souls' attack anatomy (a readable opening pose, a short live hitbox, the
  longest phase the punish window); Sekiro's two bars, its shrinking deflect window and one named answer per perilous
  attack; a practice partner who cannot hurt you while you learn; FOOTSIES' whiff punish as the first skill; best of
  three.
- **Change:** For Honor's three-direction guard becomes one guard with lock-on (one stick, mouse and keyboard); its
  glyph over the guard becomes a colour on the weapon at most, because the shoulder camera shows the weapon.
- **Drop:** feints and guard-break mix-ups until the core is called fun (the ceiling, not the floor); Revenge (a team
  mechanic); ledges; every meter beyond two bars; tags, cue lines and banners as the carrier of a tell; 2D fighting
  games' 4-frame normals [B11], which work only on a side view where both bodies are whole on screen [B30].

### Stage 6b: our house duel, torn down (N1, 23 Nov)
N1 played the house duel in a window and set it beside For Honor, Souls, Sekiro and fighting-game basics [B30]. "On
paper ours is a faithful copy of the right rules ... The rules are not what fails. What fails is everything a person
reads the rules through: the bodies, the timing, the tutorial, the pace." Its top ten, ranked by cost to the player:
1. **The bodies do not tell; text does.** A wind-up is a 3-frame pose of one generic clip, stretched about five times;
   the rival's intent is written over his head.
2. **The tutorial beats you up while it teaches**, and moves on when you fail: a newcomer who has not found the keys is
   at 14 of 100 health 19 s into his first match.
3. **A round is over in 20 seconds**: no time to read the opponent.
4. **The rival's fastest threats are faster than a person can react** (12-frame chains and tells), and the checklist
   was set to accept them, below its own research's floor of 16.
5. **Too many systems, all on the screen at once.**
6. **Three rivals are one fighter in three hats**: one move set, three reaction speeds, gear.
7. **The figures are toys and the weapons are sticks**: no weight, synthesised beeps, a light hit-stop.
8. **Difficulty is a reaction dial and a cliff**: the newcomer hand wins 4 of 8 against the Wall and 1 of 8 against
   the Duelist.
9. **Rounds end in a KO show, not in a story**: a person learns why he lost from a card, not from a moment.
10. **Nobody has played it**: built in five hours by twelve self-graded loops that only added.

### Stage 7: the greybox
A flat ring with a low wall, two fighters with their weapons and their own silhouettes, light, heavy, guard/parry and
roll, the Wall alone, two bars a fighter, the over-the-shoulder camera, every number of stage 5 in the tuning file,
and **a wind-up clip of the rival's own** for his heavy (the body is the work: when a game needs a body to speak, the
rig is the first package, not the HUD [B30]). The person plays it 5 minutes with the playtest card and ranks what he
felt.

### Stage 8: kill criteria
- KILL IF: a newcomer needs a word over the rival's head to know a heavy is coming.
- KILL IF: the newcomer loses health in the first lesson before he has once pressed guard.
- KILL IF: a round ends before the player has tried two different answers.
- KILL IF: in 5 minutes the newcomer never parries on purpose, because he cannot see the heavy coming.
- KILL IF: from the shoulder camera a hit and a block look the same (no recoil, no stagger, no different sound).

### What our build did instead (21-22 Nov)
- The house duel landed 13 rounds: every contact changes both bodies, hit-stop on both, the Wall, the Duelist and the
  Dancer, threat tags, lesson rounds, a loss card; its ladder rises from newcomer to perfect (22 Nov night verdict;
  its numbers in `engine/packs/duel/data/moves.json` [B16]).
- Its own lane: "a readable, teachable duel with distinct opponents ... not yet a game that sells itself by its feel.
  It is still one shared move set, re-dressed per rival."
- The owner, playing it: "the fact players can punch in arena and take damage does not mean we delivered fun fighting
  game" (22 Nov, 18:35).
- N1's lessons that the method takes from it [B30]: a spec is not a game, and a faithful build of a spec is not either;
  the identity sat in the HUD because the rig could not carry it; the rubric was set below the research (a checklist
  number must come from the human limit it protects); "teach by play" was built as "teach while hitting" (a copied idea
  needs its conditions copied with it); a loop that only adds is decoration; acceptance by mechanic clips, judged by the
  lane that built them.
- What the method would have caught: pillar 1 and kill lines 1 to 3 are a 5-minute check by hand on the greybox,
  before any rival, tag or lesson was built on it.

### The method lines a duel brief carries
```
FANTASY: I read him like a book: I see him coil for the heavy, parry it, and punish him while he staggers. Challenge, fantasy.
TEARDOWN: For Honor: lights wind up 24-30 frames, heavies 48-60; a parried light gives a free heavy.
TEARDOWN: Sekiro: two bars, a 12-frame deflect that shrinks when spammed, and a practice partner who cannot hurt you.
30 SECONDS: 0-5 s the Wall waits 3 m away, light swings within 3 frames; 5-15 s he coils a slow heavy, you guard, he bounces off, you strike; 15-30 s you tap guard as it lands, he staggers, your heavy lands.
KILL IF: a newcomer needs a word over the rival's head to know a heavy is coming.
KILL IF: the newcomer loses health in the first lesson before he has once pressed guard.
KILL IF: a round ends before the player has tried two different answers.
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
- B6. For Honor patch notes 2.39.0 (2022), heavies [search]:
  https://www.ubisoft.com/en-us/game/for-honor/news-updates/2203fmh7jD1gohfN25aDRi/patch-notes-2390-for-honor
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
- B17. Ubisoft, "Season 5 core fight update" (parry rewards):
  https://www.ubisoft.com/en-us/game/for-honor/news-updates/1ZO1qG5mqCaURiMFVgwlJl/season-5-core-fight-update
- B18. Ubisoft, "Testing Grounds fight system improvements debrief" (lights 400 to 500 ms):
  https://www.ubisoft.com/en-au/game/for-honor/news-updates/3zofBwXiVX8PXzYZv6PBAA/testing-grounds-fight-system-improvements-debrief
- B19. Kotaku, "For Honor's tutorial is very good" (2017): https://kotaku.com/for-honors-tutorial-is-very-good-1792358053 ;
  For Honor terminology guide (the unblockable's red trail):
  https://www.ubisoft.com/en-us/game/for-honor/news-updates/6XEM2qUiwcokp753uCzgkz/for-honor-terminology-guide
- B20. Sekiro wiki (Fextralife), "Deflection" and "Perilous Attacks" [CM]:
  https://sekiroshadowsdietwice.wiki.fextralife.com/Deflection ;
  https://sekiroshadowsdietwice.wiki.fextralife.com/Perilous+Attacks
- B21. Activision support, "Sekiro: Shadows Die Twice game mechanics":
  https://support.activision.com/sekiro/articles/sekiro-shadows-die-twice-game-mechanics
- B22. Sekiro wiki (Fextralife), "Hanbei The Undying": https://sekiroshadowsdietwice.wiki.fextralife.com/Hanbei+The+Undying
- B23. Bart Vossen, "Enemy design and enemy AI for melee combat systems", Game Developer (2015):
  https://gamedeveloper.com/design/enemy-design-and-enemy-ai-for-melee-combat-systems
- B24. Game Informer, Hidetaka Miyazaki on his approach to difficulty (2024):
  https://gameinformer.com/interview/2024/06/24/from-softwares-hidetaka-miyazaki-discusses-his-approach-to-difficulty
- B25. Infil's fighting game glossary (reaction time, frame data): https://glossary.infil.net/
- B26. Jerry Zhang, "Anatomy of an Enemy Attack in Dark Souls 3", Game Developer (2022):
  https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3
- B27. Masahiro Sakurai on hitstop (Source Gaming translation, 2015):
  https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/ ; SmashWiki, "Hitlag":
  https://www.ssbwiki.com/Hitlag
- B28. "Rock, paper, guard breaks: a mechanics deep dive into For Honor", Game Developer:
  https://gamedeveloper.com/design/rock-paper-guard-breaks-a-mechanics-deep-dive-into-for-honor
- B29. Ubisoft, "New onboarding process FAQ" (For Honor):
  https://www.ubisoft.com/en-gb/game/for-honor/news-updates/2WLJVU7sD6bHeX721QFxdW/new-onboarding-process-faq
- B30. N1 (night of 22-23 Nov), the duel teardown, with file and line on our side and the references' URLs:
  `docs/research/duel-teardown/TEARDOWN.md` and `docs/research/duel-teardown/media/` (rounds.md: 93 rounds, all KO,
  median 18-24 s; clips of the first 25 s and of a newcomer against the Wall).
