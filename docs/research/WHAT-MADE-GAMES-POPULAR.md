# What made games popular (research of 21 Nov 2026)

For the owner's ruling of 21 Nov: our generated games are "mediocre slop: even though improved no real person would play
and enjoy the games, because they miss quality gameplay elements"; research "what's making games popular in videogame
history" before the next attempt. Graphics fidelity is not the ambition. Full sources are in the research transcript;
the key ones are linked here.

## Summary
The games that lasted share a short list of traits, and almost none is about graphics: **one verb that is fun with nothing
else around it**; **few rules that interact**; **cause and effect shown at once and clearly**; **opponents that behave
legibly, with personalities and tells**; **a built-in comeback or risk/reward tension**; **rounds short enough to restart on
impulse**; **one hook nobody else has**. Professionals find these in ugly prototypes and confirm them by watching strangers
play. The usual failure is a competent game with a feature list whose core verb was never fun alone: our "slop".

## Case studies (design reasons, abridged)
- **Pong:** one rule; the paddle split into segments makes the return angle a skill.
- **Space Invaders:** fewer invaders move faster: tension rises by itself; the march sound speeds up with them.
- **Pac-Man:** four ghosts with distinct targeting rules; chase/scatter waves with a visible reversal tell; the power pellet
  flips hunter and hunted ([Pac-Man Dossier](https://www.gamedeveloper.com/game-platforms/feature-the-i-pac-man-i-dossier)).
- **Tetris:** four-block pieces; clearing one problem creates the next.
- **Super Mario Bros.:** World 1-1 teaches by play; the first enemy is deliberately easy.
- **Street Fighter II:** combos from a kept "bug" (a skill ceiling); every fighter a distinct identity.
- **Halo:** "30 seconds of fun" repeated in changing contexts; AI with readable personalities (Grunts flee when their Elite
  dies), behaviour overplayed so players notice it ([Joystiq](https://www.engadget.com/2011-07-14-half-minute-halo-an-interview-with-jaime-griesemer.html)).
- **Smash:** rising percentage -> rising knockback, KO by ring-out: state always on screen, comeback always possible.
- **Counter-Strike:** one-life rounds; a loss bonus that keeps every round important (anti-snowball).
- **Wii Sports:** learnable in five seconds; depth from analogue variation; spectators queue for a turn.
- **Dark Souls:** deaths you understand and accept as justified; losing your souls creates suspense.
- **Rocket League:** one mode, no stats; physics built for predictability, not realism; 60 fps essential; "zero-second
  magic" ([Game Developer](https://www.gamedeveloper.com/business/smart-calls-timing-luck-poverty-how-i-rocket-league-i-succeeded)).
- **Fall Guys:** failing is the comedy (ragdoll); 80 % skill, 20 % chaos; a round must fit in three words.
- **Vampire Survivors, Hades, Celeste, Balatro:** one decision (position) with automatic attacks; dying turned into story or
  progress; hidden forgiveness (coyote time, buffers); a known vocabulary (poker) bent by ~150 rule-breaking jokers.
- **NBA Jam / NHL '94 / Sensible Soccer / Mario Kart:** on fire; the one-timer; aftertouch on a one-button control; a race
  where "everyone was in it until the end" (the blue shell you can at least avoid).

## Principles (all but R11 are independent of graphics; R11 is presentation, not fidelity)
- **R1** The core verb is fun in an empty room (Splatoon as tofu blocks; Mario 64 stalled until turning felt right).
- **R2** Cause and effect are readable and immediate ("if the AI didn't say it, it didn't happen": F.E.A.R. callouts).
- **R3** Low floor, high ceiling.
- **R4** Opponents are fair and learnable: personalities, tells, pressure in waves (Left 4 Dead's Director: build-up,
  peak, relax).
- **R5** Few rules, many interactions (emergence).
- **R6** Risk/reward and a comeback are part of the rules.
- **R7** It works socially and as a show (clips, rivalry).
- **R8** Short sessions, "one more go".
- **R9** Progress makes failure productive.
- **R10** Onboarding by play, not text.
- **R11** Strong feedback (juice) and forgiving controls.
- **R12** A distinct hook you can say in one line.
- **R13** Variety of context around a stable core (kishotenketsu: introduce, develop, twist, test).
- **R14** Decisions, not only execution (Sid Meier's "series of interesting decisions").

## Anti-patterns
1. A feature list with no core (Anthem). 2. No identity (Concord). 3. Variety that is only numbers: "10,000 bowls of
oatmeal" (No Man's Sky) — **the main risk for an LLM pipeline**. 4. Passive AI (Aliens: Colonial Marines: enemies "wander
around and forget you're there"). 5. AI that cheats where you can see it (visible rubber-banding). 6. Mushy controls
(Rocket League at 30 fps). 7. Stakes framed as punishment (WoW's rest penalty, accepted once reframed as a bonus).
8. Unreadable goals or state (Halo 3 testers wandered until objectives flashed). 9. No stakes and no end.

## How professionals test fun
Prototype the verb ugly and kill freely (Splatoon from ~70 ideas; Supercell celebrates kills). A prototype asks "is it
fun?", a vertical slice asks "can we build it to final quality?" — **our pipeline jumps to the slice**. Watch strangers
without helping. Metrics show where, feel shows why. The real test: would they play it without us? (Balatro's friend
played 40 hours unprompted.)

## Checklist: a small generated game a real person plays twice
[B] bot metric, [C] capture/log, [H] human playtest (no bot result can mark an [H] item PASS).

| # | Criterion | Verify |
|---|---|---|
| 1 | The core verb gives visible feedback within 3 frames, at a steady 60 Hz | [B] |
| 2 | With no opponent or goal, a newcomer keeps using the verb for >= 30 s | [H]; [B] proxy: >= 2 outcome dimensions |
| 3 | The verb has an analogue skill dimension (different inputs, measurably different results) | [B] |
| 4 | The rules fit in one sentence shown in the first 5 s | [C]; [H] |
| 5 | The first 30 s teach with a safe first threat, not a text wall | [C]; [B] newcomer survives >= 90 % |
| 6 | Win rate rises with skill: newcomer < regular < sharp < perfect, gaps >= 15 points | [B] ladder |
| 7 | The newcomer wins sometimes (10-20 %+) | [B] |
| 8 | The perfect hand keeps a ceiling (score still rising across levels) | [B] |
| 9 | Every opponent acts: none idle > 2 s | [B] |
| 10 | >= 2 opponent archetypes with distinct documented rules | [B] |
| 11 | Each dangerous opponent action has a tell >= 12 frames before it lands | [C] |
| 12 | Pressure in waves: >= 2 peaks and troughs per match | [B] |
| 13 | Most losses have a visible, nameable cause | [C]; [H] |
| 14 | No hidden cheating: AI within player limits; any catch-up is a visible rule | [B] |
| 15 | A comeback rule; leads change hands in >= 30 % of close matches | [B] |
| 16 | >= 1 risk/reward choice per 30 s | [B] |
| 17 | >= 3 rules or objects that interact into unscripted outcomes | [B] |
| 18 | Rounds of 30 s to 5 min; restart <= 2 s with one button | [B] |
| 19 | The ending has drama (share of rounds decided in the final 10 %) | [B] |
| 20 | Each round differs in context while the core stays | [B] |
| 21 | Variation is perceptual, not only numeric | [C]; [H] |
| 22 | Failure gives something: progress, unlock, knowledge or a laugh | [C]; [B] |
| 23 | Stakes framed as a bonus, not a penalty | [C] |
| 24 | Juice on every hit or score: >= 3 of hit pause, shake, particle, sound, number pop | [C] |
| 25 | Forgiveness windows: coyote time, input buffer, generous hitboxes | [B] |
| 26 | State readable at a glance: score, threat, goal | [C]; [H] |
| 27 | One-line hook absent from the genre baseline | [C] |
| 28 | A 10-s clip of the best moment is understandable to a non-player | [C]; [H] |
| 29 | Rivalry: 2-player or beat-my-score/ghost | [C] |
| 30 | Voluntary replay: offered "stop or play again", a tester plays again | **[H] only** — the owner's bar |

**The strongest single change the evidence suggests:** a "tofu stage" before any content: build the core verb with flat
shapes, and kill it unless items 1-3, 9-12 and 15 pass and someone actually plays it in an empty room.
