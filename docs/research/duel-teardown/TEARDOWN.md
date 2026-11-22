# Duel teardown: our `engine/packs/duel` against For Honor, Souls and fighting-game basics

Lane N1, round 3, night of 22-23 Nov 2026. Research only: nothing in `engine/` or `foreman/` was changed. Companion to
`docs/research/hockey-teardown/TEARDOWN.md` (same method) and `RULINGS.md` there (the owner's standing rulings).

**The owner, 22 Nov about 18:35 (verbatim):** "The fact players can skate and shoot puck does not mean we delivered entertaining
hockey experience, the fact players can punch in arena and take damage does not mean we delivered fun fighting game. Both are
slop nobody would touch for fun and we should prepare processes and prompts to go much deeper in game design".
**And 21 Nov:** "Arena mutual reaction on attacks and collision is almost non-existing, we don't need to reinvent wheel, there are
hundreds of duel games (souls like, for honor duels) with well known game design paths we can mimic." (`docs/research/DUEL-PLAYBOOK.md`:3-5)

There is no jam duel to tear down, so **the floor is a real reference read from public sources** (section 2): For Honor's duels,
the Souls games and Sekiro, and a 2D fighting game's frame-data basics. Every reference number carries its URL.

Paths marked OURS are relative to `engine/packs/duel/` unless they start with `engine/` or `docs/`.

## 0. The verdict in ten lines

1. **On paper ours is a faithful copy of the right rules**: For Honor's guard, parry, bash and wall splat, Souls' stamina and poise,
   Sekiro's posture, the 2D games' hit-stop and frame advantage, three archetypes by their defence (`README.md`:109-160). The rules
   are not what fails.
2. **What fails is everything a person reads the rules through**: the bodies, the timing, the tutorial, the pace.
3. **The bodies do not tell.** Every attack is one of two generic clips slowed through a frame map; the rival's intent is written
   over his head in words (HEAVY, BASH, UNBLOCKABLE), where For Honor and Sekiro use a glyph or a colour over a body that does the
   telling.
4. **The tutorial hits you while it teaches**: a newcomer who has not found the keys is at 14 of 100 health 19 s into his first match.
5. **A round lasts 20 seconds**: 93 of 93 measured rounds ended by a knockout, median 18-24 s, against a 70 s clock.
6. **The fastest threats are below human reaction** (12-frame chains and tells; the playbook's own floor is 16), and the checklist was
   set to accept them.
7. **The screen is a dashboard**: three bars a fighter, a crowd meter, stars, rally, tags, cues, banners, a key strip, cause cards.
8. **Three rivals are one fighter in three hats**: one move set, three reaction speeds, gear added so they stop looking recoloured.
9. **Its own builder knew**: "It is not yet a game that sells itself by its feel. Nobody has played it." (N2 `REPORT.md`). It was built
   in five hours by twelve self-judged loops that only added.
10. **The references are the floor and say what to do first**: bodies that telegraph, a practice partner that does not punish you
    while you learn, attacks timed for a human eye, exchanges spaced by seconds (section 2).

## 1. How this was read and played

- **Ours, read:** `README.md`, `data/*.json` (moves, contacts, tuning, rivals, lessons, causes), `scripts/fighter.gd`,
  `scripts/lessons.gd`, `scripts/brain.gd`, `scripts/show.gd`; the spec `docs/research/DUEL-PLAYBOOK.md`; the lane's brief and
  report `docs/shifts/2026-11-22-night/lanes/N2-duel/BRIEF.md`, `REPORT.md`; the rig's clip table `engine/rigs/RIGS.md`.
- **Ours, played as a person meets it (in a window, d3d12, Godot movie writer, `.tl/n1/clip2.sh`):**
  - `tl play duel` with nothing pressed: the first 25 s a newcomer who does not yet know the keys meets
    (`media/sheet_duel_first25s.jpg`).
  - the ladder bot through the **newcomer** `TLHand` against the Wall, seed 1, 45 s (`media/duel_wall_newcomer_s1.mp4`,
    `media/sheet_duel_wall_newcomer.jpg`).
- **Ours, measured:** the ladder cells headless, 8 seeds each, kept for their round records (`.tl/duel/run.sh`,
  `.tl/duel/sum.mjs`, `media/rounds.md`).
- **References, read:** public sources only (section 2), gathered by a research scout with URLs and spot-read.
- **What this cannot see:** a person's hands. Nobody, including the lane that built it, has played our duel with a keyboard
  and a mouse (`README.md`:204-205; N2 `REPORT.md`: "NOBODY HAS PLAYED IT BY HAND"). The newcomer `TLHand` does not read
  on-screen cues (N2 `REPORT.md`).

## 2. The floor: what the references do (public sources)

Gathered from public sources on 22 Nov by a research scout and spot-read here; frames at 60 fps (1 f = 16.7 ms). (CM) marks a
community-measured figure; "snippet" marks a number read only in a search result because the page refused automated reading.
"Not found" is said where no source was found.

**For Honor (Ubisoft)**
- **F1 attack speed.** Neutral lights were slowed from 400 ms (24 f) to 500 ms (30 f) in the 2020 Testing Grounds; "Light attacks:
  fast, hard to block, meant to open / Heavy attacks: slow, easier to block, meant to deal damage, bait"
  ([Ubisoft](https://www.ubisoft.com/en-au/game/for-honor/news-updates/3zofBwXiVX8PXzYZv6PBAA/testing-grounds-fight-system-improvements-debrief)).
  The fastest found: 400 ms (24 f) chained lights ([patch 1.19](https://www.ubisoft.com/en-us/game/for-honor/news-updates/4Gac0PdHqfVBpbfa3UeWmF/patch-notes-v119)).
  Heavies 800-1000 ms (48-60 f) ([patch 2.39](https://www.ubisoft.com/en-us/game/for-honor/news-updates/2203fmh7jD1gohfN25aDRi/patch-notes-2390-for-honor)).
- **F2 parry and its reward.** A parried heavy: 600 ms (36 f) in which the attacker "cannot block, parry or dodge" (a free light); a
  parried light: 900 ms (54 f), a free heavy, because "Parrying a Light is generally more difficult and should lead to a larger
  punishment" ([Season 5](https://www.ubisoft.com/en-us/game/for-honor/news-updates/1ZO1qG5mqCaURiMFVgwlJl/season-5-core-fight-update)).
  The input window has no official number (forum claims of 200-400 ms, CM:
  [Steam](https://steamcommunity.com/app/304390/discussions/0/3647273545691576235/)).
- **F3 block and guard break.** Chip 18 % of a blocked attack, "to make blocking less effective as a stalling tool"; a guard break
  only in an attack's first 0-100 ms, because "Because Parry reward is so high, Players are encouraged to bait attacks and punish
  instead of choosing to initiate" ([public test, 2017](https://www.ubisoft.com/en-us/game/for-honor/news-updates/1IZoiczWorTTTsrEYprgzR/public-test-meta-changes)).
- **F4 what tells you.** The guard's direction icon over the opponent flashes red when he attacks (guides); an unblockable is
  "marked by a red trail on the weapon" plus a symbol ([terminology](https://www.ubisoft.com/en-us/game/for-honor/news-updates/6XEM2qUiwcokp753uCzgkz/for-honor-terminology-guide));
  a bash shows an orange indicator (CM). Glyphs and colours on the weapon and the guard, not words.
- **F5 teaching.** The tutorial runs dummies, then the three guard directions, then one easy soldier, then very easy AIs, then a
  moderate one, and each task is repeated "two or three times, from each side, before progressing"; the opponent's cues (an arrow,
  a grunt) are much softer later ([Kotaku](https://kotaku.com/for-honors-tutorial-is-very-good-1792358053)). Whether the opponent waits
  for you: not stated.
- **F6 its known flaw.** "predictable defensive play is unpunishable ... the ball is always in the court of the defender after an attack
  is thrown" ([Game Developer](https://gamedeveloper.com/design/rock-paper-guard-breaks-a-mechanics-deep-dive-into-for-honor));
  turtling at high level ([PC Gamer](https://www.pcgamer.com/au/the-rise-and-fall-of-for-honor)).

**Souls and Sekiro (FromSoftware)**
- **S1 the anatomy of an enemy attack** (Dark Souls 3, Zhang): five phases; the opening pose: "Its silhouette should be discernable
  and naturally hints the incoming attack"; signal plus attack at least 340 ms (20 f); a hitbox live 2-4 frames; an end pose of at
  least 170 ms (10 f); then the return, the punish window, "generally the longest" phase; these rules "lay the solid foundation for
  the fairness of the combat" ([Game Developer](https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3)).
- **S2 i-frames.** Elden Ring rolls: 14 frames at 30 fps (28 f at 60, about 467 ms) light and medium, 13 heavy
  ([wiki.gg](https://eldenring.wiki.gg/wiki/I-Frame), CM).
- **S3 Sekiro.** The deflect window is "12 frames by default (0.2 seconds before the attack hits)", shrinking to 4 with repeated
  presses, reset after about 30 frames or by a good deflect ([Fextralife](https://sekiroshadowsdietwice.wiki.fextralife.com/Deflection), CM);
  posture rises on hits "whether they're blocked or not", recovers slower as vitality drops, and a broken posture opens a deathblow
  ([Activision](https://support.activision.com/sekiro/articles/sekiro-shadows-die-twice-game-mechanics)); perilous attacks show a red
  "Danger" kanji and each has one answer ([Fextralife](https://sekiroshadowsdietwice.wiki.fextralife.com/Perilous+Attacks)).
  Training: Hanbei the Undying, an immortal practice partner
  ([Fextralife](https://sekiroshadowsdietwice.wiki.fextralife.com/Hanbei+The+Undying)).
- **S4 pacing.** "an enemy attacks the player every two-to-three seconds on average" (120-180 f) in a survey of melee games
  ([Game Developer, Vossen](https://gamedeveloper.com/design/enemy-design-and-enemy-ai-for-melee-combat-systems)).
- **S5 fairness.** Miyazaki: players should "understand why they were killed ... and it feels justified"
  ([Game Informer](https://gameinformer.com/interview/2024/06/24/from-softwares-hidetaka-miyazaki-discusses-his-approach-to-difficulty)).

**Fighting-game basics**
- **G1 reaction.** "average human reaction time is around 250 milliseconds (about 15 frames)"; reacting reliably to about 20 frames of
  startup is good; world-class players miss reactions to 45-frame jumps ([Infil's glossary](https://glossary.infil.net/json/glossary.json)).
- **G2 frame data.** Startup, active, recovery; plus and minus; punish; whiff punish; neutral; mix-up (Infil, same glossary).
  Street Fighter 6's fastest normals start in about 4 frames (Ryu's light punch, CM:
  [GameSkinny](https://www.gameskinny.com/tips/street-fighter-6-ryu-frame-data-analysis-guide/)): a 2D game makes them readable by
  spacing and by the fact that both players see the whole field, not by reaction.
- **G3 hit-stop.** Sakurai: "both parties momentarily freeze, emphasizing the power of impact"
  ([Source Gaming](https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/)); Smash's hitlag is
  about 6 frames at 1 % damage, 12 at 10 %, 19 at 20 %, capped at 30 ([SmashWiki](https://www.ssbwiki.com/Hitlag)); Capcom's example
  8 / 12 / 16 for light / medium / heavy (snippet, [Capcom](https://game.capcom.com/cfn/sfv/column/131545?lang=en)).
- **G4 yomi.** Sirlin: "Knowing the mind of the opponent" (via [a mirror](https://www.gwern.net/docs/www/www.sirlin.net/c86d4e92f616d6acbf8c65cd5c57484967b1d6eb.html)).

**Not found:** a public duel round length for For Honor; a source saying any of these games' tutorial opponents wait until the player
succeeds (For Honor repeats each task two or three times; Sekiro's partner cannot die).

## 3. Side by side, per system

Each row: what the references do (section 2 label), what ours does (file:line), and what a player feels.

| System | References (section 2) | Ours | What the player feels |
|---|---|---|---|
| Attack speed | For Honor lights 24-30 f, heavies 48-60 f (F1); a Souls attack's signal plus attack at least 20 f (S1) | light 18 frames (chain 12), heavy 32, charged 54, bash 14 (`data/moves.json:3-20`) | lights and chains arrive before a newcomer can see them start |
| What the body shows | the opening pose's silhouette hints the attack (S1); an unblockable marked on the weapon (F4) | two rig clips (`strike` 16 frames with a 3-frame anticipation, `strike_heavy` 30 with 10; `engine/rigs/RIGS.md:77-78`) mapped onto every move (`data/moves.json:7-29`); rivals share them (N2 `REPORT.md`) | the wind-up is a slow small pose; the word over his head is the real tell |
| Guard and parry | Sekiro's deflect is 12 frames before the hit (S3); For Honor's window is not published (F2) | hold SPACE = block in a 120 degree front; the first frames of a press (2-13) are the parry; a tap that meets nothing = 20 frames open (`data/moves.json:21-22`) | one button, Sekiro-like; fair on paper, unseen in practice because the timing cue is the glint and a word |
| Reward for a parry | For Honor: a parried heavy 36 f, a parried light 54 f (F2) | a parried light leaves him open 52 frames (+44, a heavy guaranteed), a heavy 36 (+28, a light) (`data/contacts.json:8-10`; `README.md`:131-132) | close to For Honor; this part is right |
| Hit-stop and reactions | Smash 6-19 f by damage, Capcom 8 / 12 / 16 (G3) | 3-14 frames on both fighters, then a flinch, stagger, bounce, fling or splat (`data/contacts.json:3-22`; `README.md`:106-107) | in the normal range; reads as a freeze of toys (N2 `REPORT.md`) |
| Recovery / punish window | the return is the longest phase of an enemy attack (S1); an attack every 2-3 s (S4) | whiff recovery 16 / 28 / 36 frames (`data/moves.json`); the rival stands open for `return` 36 / 28 / 22 / 18 frames after each string (`data/rivals.json:3-40`) | there are openings; with a 20 s round there are few of them |
| Round length and damage | not found (section 2) | 100 health, light 9, heavy 20, charged and finisher 30 (`data/moves.json`, `data/contacts.json:19`); every measured round a KO in 18-24 s (`media/rounds.md`) | over before a pattern can be learned |
| Teaching the first minute | each task two or three times before moving on (F5); an immortal practice partner (S3) | the Wall's three lessons with real damage, a cue 75 frames before each blow, one retry, then the real fight (`scripts/lessons.gd:1-9`, `data/lessons.json`) | hit while reading; 14 of 100 health after 19 s with nothing pressed |
| Telling intent | a glyph or a colour on the guard icon or the weapon (F4); a red kanji for a perilous attack (S3) | tags over the rival (HEAVY gold, BASH orange, UNBLOCKABLE red, OPEN blue: `scripts/show.gd:49, 112-115`), a glint 16 frames before a hit, banners, cue lines (`README.md`:26-27, 62-66) | reading words in a fight decided in 12-18 frames |
| AI | an attack every 2-3 s on average (S4); easy by clumsiness (RULINGS R-0067) | sees the player's state `react` frames late (30 / 22 / 18 / 15), answers a share `defend` (0.30-0.70), reads the commonest answer with `read`, never the same string three times, stands open `return` frames (`scripts/brain.gd:1-14`; `data/rivals.json:3-40`) | built on the right principles; the difficulty is a reaction dial |
| Roster | per-hero speeds and moves (F1); one named answer per perilous attack (S3) | one move set with per-rival number overrides; gear on head and back sockets (`gen/arms.gd`); arenas and drums (`data/arenas.json`) | three costumes |
| Sound and weight | hit-stop as weight (G3) | kernel presets (`hit_metal`, `cheer`, `horn`, `beep`: `scripts/show.gd:175, 256-257, 292`); "synthesised beeps" (N2 `REPORT.md`) | no impact |

## 4. The top 10: why ours is not fun

### 1. The bodies do not tell; text does. A wind-up is a 3-frame pose of one generic clip, stretched.
- **Ours:** every attack is one of two rig clips played through a frame map: the light is `strike` (16 frames, anticipation
  0-3; `engine/rigs/RIGS.md:77`), mapped so clip frames 0-2.6 fill move frames 0-14 (`data/moves.json:7`): the 18-frame wind-up
  is the clip's 3-frame draw-back slowed about five times. The heavy and the charged heavy are both `strike_heavy` (`data/moves.json:9-16`);
  the charged one holds clip frames 8-10 for 30 frames. The Duelist's signature "taps his blade" tell (`data/rivals.json:216`) is
  `strike_heavy`'s first 5 frames over 24 (`data/moves.json:29`; `data/rivals.json:353-356`): a half-raised heavy, not a tap.
  What carries the tell is drawn over him: the tags HEAVY / BASH / UNBLOCKABLE / OPEN over his head (`scripts/show.gd:49, 112-115`;
  `README.md`:62-66), a glint 16 frames before the hit, cue lines and banners.
- **References:** a Souls attack's opening pose: "Its silhouette should be discernable and naturally hints the incoming attack", and its signal plus attack last at least 20 frames (S1). For Honor and Sekiro do put a signal over the fight, but as a glyph or a colour on the guard icon or the weapon (F4, S3), read at a glance while the body does the attack.
- **Our own lane said so:** "The three rivals differ in AI, timing and gear, not in their animations: no rival-specific strikes"; "The
  bodies are toys: contact reads by freeze, flinch and fall, not by weight or blade on armour" (N2 `REPORT.md`, "Still short of the
  reference").
- **Cost:** the duel's whole skill is reading the other body. Ours asks the player to read words over a body that barely moves.
  The owner ruled on exactly this in thirdjam: "the player animation should reflect the crosscheck movement and that should be all"
  (`docs/research/hockey-teardown/RULINGS.md`, R-0070).

### 2. The tutorial beats you up while it teaches, and moves on when you fail.
- **Ours:** "The attacks are real: they hit, block, parry and count like any other" (`scripts/lessons.gd:8`); a failed lesson is
  shown once more, then "he fights for real" (`scripts/lessons.gd:8`, `data/lessons.json`). The cue goes up 75 frames (1.25 s) before
  the blow (`data/lessons.json` `read_frames` 75) and is a sentence of 9-14 words ("Watch for the glint on his mace, then TAP SPACE as it
  lands: PARRY."). A newcomer who has not found the keys: 100 health at 0:01, 80 at 0:03, 60 at 0:05, 42 at 0:09, 14 at 0:19
  (`media/sheet_duel_first25s.jpg`, `media/rounds.md`).
- **References:** For Honor's tutorial runs dummies, then the guards, then one easy soldier, and repeats each task "two or three times, from each side, before progressing" (F5); Sekiro's practice partner cannot die (S3). Neither puts a newcomer's health on the line while he learns his first answer. No source says the opponent waits until the player succeeds (section 2, Not found): that rule would be ours to make, and it is the cheaper one.
- **Cost:** the first 20 s a person meets are being hit while reading a sentence that went up 1.25 s before the blow.

### 3. A round is over in 20 seconds; there is no time to read the opponent.
- **Ours:** 93 of 93 rounds measured ended by a knockout, median 18-24 s (`media/rounds.md`), against a 70 s clock
  (`data/tuning.json:5`). 100 health; a heavy takes 20, a charged 30, a finisher 30, a light 9 (`data/moves.json:4-17`;
  `data/contacts.json:19`).
- **References:** no public duel round length was found (section 2). What was found: "an enemy attacks the player every two-to-three seconds on average" (S4), and For Honor's exchanges are spaced by 30-frame lights and 36-54-frame parry punishes (F1, F2). Ours goes the other way: the rival may never stand idle more than 120 frames (the checklist's item 9, `tests/support/pilot.gd:174`), and his longest idle in a measured match was 35 frames (wall newcomer, seed 1, `idle_max_f`).
- **Cost:** a duel is a conversation: the player tries something, the rival answers, the player adapts. Five heavies end ours;
  the round is over before the second sentence of that conversation.

### 4. The rival's fastest threats are faster than a person can react, and the spec knew it.
- **Ours:** the rival's chained lights wind up 12 frames (`data/moves.json:3`); the shortest dangerous wind-up measured in a match
  is 12 frames (metrics `tell_min_f` 12, wall newcomer seed 1); the checklist accepts 12 (`scripts/brain.gd:50`: ">= 12: plays-twice
  item 11"). The playbook itself says "a single known stimulus takes ~16 frames, so moves faster than that must be READ"
  (`docs/research/DUEL-PLAYBOOK.md`, section 3). The parry window is 12 frames of a block press (`data/moves.json:22`).
- **References:** For Honor's lights take 400-500 ms (24-30 frames) and its heavies 800-1000 ms (48-60) (F1); a Souls attack's signal plus attack takes at least 340 ms (20 frames) (S1); a person's average reaction is about 15 frames and reacting reliably to 20 is good (G1). Our light (18), chained light (12) and heavy (32) are about 40 % faster than For Honor's.
- **Cost:** for a newcomer the chain is not a puzzle; it is damage from nowhere. The game's rubric item was set below its own
  research's floor.

### 5. Too many systems, all on the screen at once.
- **Ours:** for each fighter health, stamina and posture bars plus EXHAUSTED, RALLY, BROKEN and stars; a crowd meter; a round clock;
  poise tiers; counter-hits; chip; finishers; rally; a key strip; cue lines; banners; tags; a loss card with the top three causes
  (`README.md`:102-107, 142-150; `scripts/show.gd`). A newcomer meets all of them in round 1 (stills: `media/sheet_duel_wall_newcomer.jpg`).
- **References:** Sekiro builds its whole duel on two bars, vitality and posture (S3); For Honor's in-fight signal is one indicator over the opponent (F4).
- **Cost:** depth comes from few verbs with many situations; ours has many meters and few situations a person can read.

### 6. Three rivals are one fighter in three hats.
- **Ours:** one move file for everybody (`data/moves.json`), per-rival overrides of numbers (`data/rivals.json` `moves`); the
  difference is mind parameters (`react`, `defend`, `read`, `return`; `data/rivals.json:3-40`), gear made in round 9 so they would
  stop being "the player recoloured" (`gen/arms.gd`; N2 `REPORT.md` round 9), and arenas and drums (round 6).
- **References:** For Honor's speeds and moves are per hero (F1); each of Sekiro's perilous attacks has its one named answer (S3). A new opponent is a new set of moves to learn.
- **Cost:** a ladder of rivals is a ladder of new problems to solve. Ours is one problem at three reaction speeds.

### 7. The figures are toys and the weapons are sticks.
- **Ours:** the kernel's big-headed biped in hoodies and jeans (stills), a sword, mace or blades built from kit primitives on the
  hand sockets (`gen/arms.gd`), reach 2.05-2.4 m (`data/moves.json:6,11,15`), contact "by freeze, flinch and fall, not by weight or
  blade on armour", "the sound is synthesised beeps" (N2 `REPORT.md`; `scripts/show.gd:175` plays `beep`).
- **References:** hit-stop is the references' first weight tool: Smash about 6-19 frames by damage, Capcom's example 8 / 12 / 16 by strength (G3); ours is 5 on a light hit and 9 on a heavy (`data/contacts.json:3-4`), lighter than either.
- **Cost:** no weight, no impact; a heavy and a light differ by a number and a tag.

### 8. Difficulty is a reaction dial and a cliff.
- **Ours:** the rivals differ mainly by `react` 30 / 22 / 18 / 15 frames and `defend` 0.30-0.70 (`data/rivals.json:3-40`). The
  newcomer hand wins 4 of 8 against the Wall and 1 of 8 against the Duelist, the regular hand 8 of 8 against the Duelist and the
  Dancer (`media/rounds.md`); N2 called it "a newcomer cliff at the Duelist" (`REPORT.md`).
- **References:** "A level is easy by clumsiness, never by absence" was the owner's ruling for thirdjam (`docs/research/hockey-teardown/RULINGS.md`, R-0067); For Honor's tutorial steps from very easy AIs to a moderate one (F5).
- **Cost:** the rung after the tutorial rival is a wall for a newcomer and nothing for a regular.

### 9. Rounds end in a KO show, not in a story.
- **Ours:** the KO freeze, a low camera, dust and a roar (`README.md`:97-100); a loss card that lists causes ("his heavy swings 40,
  hits after a broken guard 36", `README.md`:80-85). Every round is the same shape: one or two exchanges, then a KO.
- **References:** Miyazaki: players should "understand why they were killed ... and it feels justified" (S5). FromSoftware answers that with an attack whose body tells it (S1); we answer it with a card.
- **Cost:** a person learns why he lost from a sentence, not from a moment he remembers.

### 10. Nobody has played it; it was built in five hours by twelve self-graded loops.
- **Ours:** 13 commits between 00:55 and 05:54 on 22 Nov (`git log -- engine/packs/duel`), twelve "gap -> build" rounds each named and
  judged by the building lane against a checklist and its own window clip (N2 `REPORT.md`); acceptance by clips of mechanics ("a parry
  into a riposte; a blocked heavy punished by a light; a bash into a wall-splat; a clash ...", N2 `BRIEF.md`); "NOBODY HAS PLAYED IT
  BY HAND" (N2 `REPORT.md`).
- **References:** Zhang: the five phases "lay the solid foundation for the fairness of the combat" (S1). The references design fairness into the body's timing first; we designed rules first and dressed them.
- **Cost:** every defect above is visible in the first minute to a person, and none can fail a bot's acceptance.

## 5. What the references themselves get wrong (the floor is not the bar)

- **For Honor's duel favours the defender**: "predictable defensive play is unpunishable" (F6); its own developers moved the guard
  break and the chip to stop turtling (F3). A copy of its parry reward (ours: +44 / +28) inherits the same pull.
- **Its tutorial was later "drastically shortened"** and replaced by a match against the AI
  ([Ubisoft](https://www.ubisoft.com/en-gb/game/for-honor/news-updates/2WLJVU7sD6bHeX721QFxdW/new-onboarding-process-faq)): long
  scripted teaching is not the goal either.
- **Souls and Sekiro are single-player boss design**, tuned per boss by hand over years; their numbers transplant, their fairness
  comes from animation work we have not done (S1).
- **2D fighting games are read from a side view where both bodies are whole on screen** (G2): their 4-frame normals work there and
  would not work behind a shoulder.
- **No reference publishes how long a duel round should last**, or that a tutorial opponent must wait: those are our decisions to
  make and to test by hand.

## 6. Lessons for HOW we build games

The hockey teardown's lessons hold here almost word for word (`docs/research/hockey-teardown/TEARDOWN.md`, section 5). What the
duel adds:

1. **A spec is not a game, and a faithful build of a spec is not either.** The duel implements `DUEL-PLAYBOOK.md` section 6 with care:
   every frame number, the matrix, the archetypes (`README.md`:109-152). Section 6 is marked "**Rec.** our own choice for the 60 Hz
   kernel, with no source behind it" (`DUEL-PLAYBOOK.md`:5-6). The references were read for their rules and not for their timing,
   their animation or how they teach, and the numbers that make or break the feel were ours, never played.
2. **The game's identity sat in the HUD because the rig could not carry it.** Every round of the night that needed the player to see
   something added a word (tags, cues, banners, cards) because the fight clips are two generic strikes. The ask that would have fixed
   it ("Give each rival one signature animation of his own", N2 `REPORT.md`, next three) was left for later. When a game needs a body
   to speak, the body is the work, not the HUD.
3. **The rubric was set below the research.** Plays-twice item 11 accepts a tell of 12 frames (`scripts/brain.gd:50`); the same
   research names 16 frames as the reaction floor (`DUEL-PLAYBOOK.md`, section 3). A checklist number must come from the human
   limit it protects, not from what the build already does.
4. **"Teach by play" was built as "teach while hitting".** The lane copied For Honor's and Sekiro's idea of a sparring partner but not
   their rule that the partner waits for you (For Honor repeats each task two or three times before moving on; Sekiro's partner cannot die: section 2, F5 and S3). A copied design idea needs its conditions copied with it.
5. **Twelve 20-minute loops, each adding, none removing.** Lessons, a camera, a roar, cause cards, a KO show, arenas, drums, tags,
   hats, a second camera rule, two more rivals' lessons, a breath per tier: each answered a gap the lane named itself, judged by its own
   clip. Nothing was taken away, and the base exchange (wind-up, answer, punish) was never shown to a person. A loop that only adds
   is decoration.
6. **Acceptance by mechanic clips again** ("a parry into a riposte; a blocked heavy punished by a light; a bash into a wall-splat; a
   clash; the Duelist's tell puzzle; a round won", N2 `BRIEF.md`, Acceptance). "If a clip does not read as Souls / For Honor feel, it
   is not done" was judged by the lane that built it. The owner's verdict on the result was "slop".
7. **A game is accepted on a minute a person plays, from the menu, with a stated feeling for each part of that minute.** For the duel:
   "I see him coil, I hold block, he bounces off, I hit him, he is hurt, I am pleased", and the first person who plays it says whether
   that happened.

## 7. Recommendations (accept or reject each; none is built)

1. **No more systems on the duel until the core exchange plays by hand.** The exchange is: a wind-up you can see in the body, an
   answer (block, parry, dodge), a punish. The owner plays one rival for five minutes; that is the acceptance.
2. **Animation first:** per rival, a light, a heavy and one signature move with their own anticipation poses, timed to the
   reaction floor (wind-ups of at least 24 frames for anything a newcomer must answer on sight); the HUD tags go when the bodies tell.
3. **The tutorial waits:** a lesson blow deals no damage, and the next lesson starts only after the player has done the answer once
   (or chose to skip); one short line per lesson, read before the rival moves.
4. **Longer rounds:** damage scaled so a round takes 45-90 s of trading for two even hands, measured by hand, not by the clock.
5. **Fewer meters:** health and one resource visible (stamina or posture, not both, plus poise as a hidden rule); crowd, stars and
   rally off until a person asks for them.
6. **Each rival is a new problem:** one rival-specific mechanic each (the Wall's shield wall that only a bash opens, the Duelist's
   delayed parry stance, the Dancer's rolls that a delayed heavy catches), not only a reaction number.
7. **Weight:** a sound per material (blade on shield, blade on body, a body on the wall) and a weapon that reads as a weapon at the
   camera's distance; the beep goes.
8. **Difficulty by behaviour:** the next rung asks a new answer, not a faster one; the newcomer cliff is measured by a person.
9. **The plays-twice rubric gets its floors from human limits** (tell >= 16-24 frames, a cue readable at 250 words a minute), and a
   rubric item never passes on a number below its research.
10. **The method's rulings apply:** the owner's thirdjam rulings marked ANY (`docs/research/hockey-teardown/RULINGS.md`) are the
    acceptance for every game lane, the duel's first.

## 8. Evidence index

| What | Where |
|---|---|
| the first 25 s with nothing pressed (window) | `media/duel_first25s_idle.mp4`, `media/sheet_duel_first25s.jpg`, `media/duel_still_heavy_tell.jpg` |
| the newcomer hand against the Wall, seed 1 (window, 25 s) | `media/duel_wall_newcomer_s1.mp4`, `media/sheet_duel_wall_newcomer.jpg` (45 s) |
| round lengths, 5 cells x 8 seeds | `media/rounds.md`; `.tl/duel/run.sh`, `.tl/duel/sum.mjs`, `.tl/duel/out/` |
| the spec and the build's own record | `docs/research/DUEL-PLAYBOOK.md`; `docs/shifts/2026-11-22-night/lanes/N2-duel/BRIEF.md`, `REPORT.md`, `clips/` |
| the owner's standing rulings | `docs/research/hockey-teardown/RULINGS.md` |
