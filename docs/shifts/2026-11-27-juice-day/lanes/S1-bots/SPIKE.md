# S1-bots spike: should a new move tell the bots to use it, and to answer it, by default?

Lane S1-bots, juice day 27 Nov 2026 (08:10 to 15:00). Both arms start from main 8be26d61 and use the same job copies,
the same sentences word for word, the same seeds and the same counting hands. Arm A's code is committed as `381de1cb`
on branch `d27-sp-bots`; arm B is main unchanged (branch `d27-sp-bots-b`). The owner decides; the lane's pick is at the
very end, kept apart from the evidence.

## 1. The question, in the owner's words
Last night's verdict, ask 1: "**Bots and new moves:** should the Planner tell the bots to use, and react to, every new
move by default? Karts, basketball and shield wall needed a second sentence."

## 2. The two arms
**A, on by default** (tree `d25-court`, branch `d27-sp-bots`, commit 381de1cb). The Planner already asks one question
per change: which package owns it. That question now also answers four things:
- does the change ADD a move;
- do the words say what the bots do with it ("said"), keep it to the player ("only_me"), or say nothing ("unsaid");
- which packages drive a bot;
- for "unsaid", one sentence on when a bot uses it and one on how a bot answers it.

When the words say nothing about the bots:
- the owner's builder brief gets a "bots by default" section;
- every other package that drives a bot (a crew's mind, a team brain) gets a Foreman wire request. It waits until the
  owner's change is merged, then teaches its bots the move as the owner built it.

"Only I can do it" turns the use off (the bots still answer). Words that do name the bots also reach every bot package;
that is a minimal routing, and lane T builds the general fix on main. The what-changed card gets one line: what the
Foreman added and how to turn it off. No extra model call: the same Planner call answers it.

Code:
- `foreman/src/botsdefault.ts` (new, 127 lines);
- the owner prompt and schema in `foreman/src/grow.ts`;
- a few lines in `foreman/src/foreman.ts` (it stays at its 2005-line size ratchet);
- 1 card line in `foreman/src/fastchange.ts`;
- a test `foreman/src/test/s1_bots_default.test.ts` (3 cases; fake builder, a whole change on the phases fixture).
- In all: +262 / -11 over 5 files.

**B, as now** (tree `d27-sp-bots-b`, main unchanged). The person types the move. When the bots fall below the bar
below, the person types the second sentence a person would: "The rivals use the X too, and dodge it when they see it
coming." When that still leaves them below, a third: "The others still almost never <use / dodge> the X. Every <kart /
fighter>, my mates and the rivals, ...".

The same follow-up sentences go to arm A whenever an A version falls below the bar too.

## 3. The test
`SENTENCES.md` holds everything, written before any job ran, with dated additions made during the day, none after an
arm A count:
- the bar (09:00), and that it applies to both arms (09:52);
- the third sentences (09:58 shield, 11:27 karts, 13:40 court);
- A court's retry (11:47).
- **Jobs.** Copied once into `d25-court/.tl/s1/base/`, then copied per arm into `<tree>/.tl/s1/jobs/`; the off switch has
  its own copy in `d25-court/.tl/s1/jobs-off/`:
  - karts `bumper-kart-football-3-20261125-1` v0.1.7;
  - half-court `half-court-3-v-20261125-1` v0.1.6;
  - shield wall `shield-wall-3-v-20261125-1` v0.1.7.
- **Moves.** Karts: a spring boxing glove on F. Half-court: an NBA Jam shove on C. Shield wall: a Captain America
  shield throw on G. Each sentence has no word about bots or rivals, and each names a counter (hop/whirl, spin away
  with turbo, a raised shield).
- **Sending.** `foreman change <job> "<sentence>"` with the `change` flags of `engine/ui/flags/real.json` (claude-cli
  sonnet), as Create sends it, each through `d25-court/.tl/s1/door.sh`, detached.
- **Measures.** Seeds 1, 2, 3, 3600 frames each; seed 1 twice for the hash. One counting hand per game, the same on both
  arms (`d25-court/.tl/s1/hands/`):
  - karts: the pack's perfect hand, which also fires the move at a mint kart 3-9 m dead ahead, at most every 180
    frames;
  - half-court: the pack's perfect hand, which also shoves a rival within 1.8 m in front, at most every 180 frames;
  - shield wall: J19's captain, who also throws at a foe 2.5-8 m ahead, at most every 180 frames.

  Every event a pack publishes is counted by who did it and to whom. Uses are counted from the pack's events, or from
  its fighter state (shield: WINDUP starts). Answers are dodges, hops, swats, spin-aways and blocks of the move,
  counted from the pack's events. From 11:15 the kart hand also counts, for each of my presses, the targeted bot
  hopping (within 70 frames) or whirling (within 40), because B's kart dodges publish no event. Observers only: every
  version re-counted with it hashed the same as before.
- **The bar ("bots use it").** Over seeds 1-3: at least 3 of the 5 bots use the move; the bots together use it 2 or
  more times a live minute; and they answer it at least once a live minute.
- **Cost.** Wall time from sending to promotion. Tokens are summed from the job's builder_run events. Machine noise is
  counted from the job log: runner timeouts at 600 s, and builder timeouts.

## 4. Results, A against B
### Karts: a spring boxing glove on F (from v0.1.7)
| | **A, on by default** | **B, as now** |
|---|---|---|
| sentences to reach "bots use it" | **1** | **3** (the bar was missed after sentences 1 and 2) |
| version that reached it | v0.1.8 | v0.1.10 |
| wall time, all sentences | 124.9 min | 226.8 min (135.4 + 40.9 + 50.5) |
| tokens in / out (cache reads in "in") | 4.43M / 39k | 7.13M / 57k (4.34M + 1.50M + 1.29M) |
| rounds | core r19, teams r8-r10, show r2 | core r19-r20, then teams r8, then teams r9 |
| machine-noise rounds (600 s runner timeouts, builder timeouts) | 2 rounds + 1 builder timeout | 1 round |
| bots' uses / live min | **18.7 fires** (11.6 hits), **5 of 5 bots**, at most 7 a bot a minute against a 180-frame cooldown | 8.8 hits (fires are not published), 4 of 5 bots |
| spam? | no: each bot below its cooldown rate. To a person it is a lot: I am punched 3-6 times a match minute (POW!) | no |
| bots' answers / live min | **11.1** (evented hop, whirl or swerve, then rush the puncher); swats 0.8 | swats 0.4; hops, whirls and swerves leave no event. My glove landed 1 of 27 presses (4 of 27 on v0.1.8): they dodge |
| hands over 20 seeds (Foreman) | newcomer 18, perfect 16 | newcomer 17, perfect 18 (v0.1.7: 18, 18) |
| what changed on the card | the "bots by default" line, plus a balance note (lead changes 0.17, was 0.33) | the builder's own words per sentence |

After sentence 1, B was already halfway: the core builder made the bots fire the glove on its own ("Bots (red_2 and red_3
as well as the mint karts) decide to throw the glove in core") at 7.8 hits a minute. Nothing answered it: 0 swats, and
targeted hops at the off-switch baseline (0.8 a minute). Sentence 2 ("dodge it") gave a read chance of 0.25-0.7 with no
visible effect (my glove landed 6 of 28). Sentence 3 raised the read chance to 0.8-0.97.

**A's off switch, karts** (sentence 1 + "Only I can do it.", own job copy):
- v0.1.8 in 112.9 min, 4.28M / 37k, 1 noise round;
- the bots fire the glove **0** times over seeds 1-3, while my hand fires it 7-9 times a match;
- the card says "bots by default: off, as you said: no bot uses "spring boxing glove punch"; they still dodge or block it";
- the teams builder gave the bots a whirl read against my glove, but no swat was seen in 3 seeds (0 a minute);
- hands: newcomer 18 of 20, perfect 18 of 20.

### Shield wall: a Captain America shield throw on G (from v0.1.7)
| | **A, on by default** | **B, as now** |
|---|---|---|
| sentences to reach "bots use it" | **3** (A's v0.1.8 and v0.1.9 were below the bar too) | **3** |
| version that reached it | v0.1.10 (borderline: see answers) | v0.1.10 |
| wall time, all sentences | 153.8 min (75.4 + 43.5 + 34.9) | 122.2 min (32.6 + 55.9 + 33.7) |
| tokens in / out | 8.35M / 67k (3.30M + 1.36M + 3.69M) | 3.37M / 33k (1.75M + 0.49M + 1.13M) |
| rounds | s1: core r17 + crew r5 (the wire); s2: core r18 + crew r6 (routed to both); s3: core r19, then crew r7 and rally r3 (re-verify fixes) | s1: core r17; s2: core r18; s3: core r19 (every time core only) |
| machine-noise rounds | 0 | 0 |
| after sentence 1: uses / answers per min | 0.7 / 1.3 (finn, pip: 2 of 5) | 1.7 / 1.0 (oda, finn: 2 of 5); "the mates' mind ... does not use the throw" |
| after sentence 2 | 1.0 / 1.7 (2 of 5) | 1.7 / 0.7 (2 of 5) |
| after sentence 3 (final) | **2.0 / 0.7** (4 of 5); the pack's own answer counter reads 4.0 a minute (blocks and the new sidesteps, which publish no event) | **5.7 / 1.3** (4 of 5); no answer counter |
| bot throws that floor someone (3 min) | 5 | 14 |
| my throws (presses) that floor a bot | 10 of 18 | 9 of 21 |

On shield wall, A's default did reach the crew's mind after sentence 1 (crew r5 built the throw for Oda, Finn, Sable and
Pip). But the Planner's default "use" line was cautious: "only when ... a foe stands clear and straight ahead with their
guard down". In a melee of six that moment is rare. The bots threw less than B's (0.7 a minute against 1.7). Both arms
needed the same third sentence ("throws it when a foe stands open a few steps away"). B's core-only round 19 put a
"reflex" on every computer fighter and ended with more throws.

### Half-court: an NBA Jam shove on C (from v0.1.6)
| | **A, on by default** | **B, as now** |
|---|---|---|
| sentences | 2 (sentence 1, then the same sentence again after "change not finished") | 3 |
| outcome | **not promoted, twice**: the Foreman's newcomer hand check refused it (7 of 20, then 12 of 20 after a rebalance round; 12 of 20 again on the retry; the card asks 13). The built change is kept unpromoted in `reports/change-not-made-s1679/pack` | v0.1.7 (no bot shoves), v0.1.8 (rivals shove), v0.1.9 (all 5 bots shove; promoted) |
| wall time | 328.0 min (191.4 + 136.6), and no version | 389.8 min (223.9 + 94.3 + 71.6) |
| tokens in / out | 4.74M / 46k (3.58M + 1.16M) | 5.74M / 48k (3.89M + 1.20M + 0.65M) |
| rounds | try 1: court_exchange r13, crews_stakes r13 (the wire) + r14 (rebalance); retry: court_exchange r14 ("identical to request 6"), crews_stakes r15 + r16 (rebalance) | s1: court_exchange r13 + r14 (a runner-timeout round), crews_stakes r13 (rebalance); s2: court_exchange r15 (+ viaduct_art r2, runner noise); s3: court_exchange r16 |
| machine-noise rounds | 0, but 2 of the retry's 20 newcomer runs did not finish (counted against it) | 2 (court_exchange r14, viaduct_art r2) |
| after sentence 1: uses / answers per min | **4.0 / 9.7**; try 1's final pack **4.3 / 12.3**, 4 of 5 bots (dex, crane, mags, pip). Answers are spin-away dodges plus punishing a whiffed shove | **0 / 4.0**. The builder: "Bots do not shove. The request did not ask for it". The 4.0 "dodges" are chance turbos |
| after sentence 2 | (same pack) | 1.7 / 6.0, rivals only (crane, moss: 2 of 5) |
| after sentence 3 | none | **13.0 / 12.3, 5 of 5 bots** (both crews) |
| newcomer hand (the card asks 13 of 20) | 7, then 12, then 12 of 20: refused | 16 (s1), 9 (s2, kept as a "built as you asked" note), 6 of 20 (s3, a note again); perfect 16 of 20 (v0.1.6: 12 and 20) |

**Why A was refused and B was not, with bots that shove in both:** lane T's `changeKind` (main,
`foreman/src/boundlift.ts` FAIR_WORDS) reads sentence 1 as a FAIRNESS change because of the words "stand off
balance". A fairness change keeps the card's hand bound as a guard, so the hand check refuses. B's later sentences
("The rivals use the shove too ...") read as play changes, so the same drop became a note: "built as you asked; a
newcomer player now wins 9 of 20 (was 16 of 20). Say "make it fairer"". The difference is that sentence's words, not the
arms. A's default shoves made the drop happen under a sentence the gate treats as fairness. This is a finding for lane
T: "off balance" is not a fairness ask.

### A after fixes (round 2, 15:18-16:30): A got two fixes B did not need, and now also carries lane T's fixes
The first results above stand as they are. This row is arm A again, but it is **not the same A**. On top of commit
381de1cb, arm A now has:
1. **A2 (091f956f):** its own default promises a rate a person sees ("each bot that can use it does so about once every
   10 to 20 seconds of play"). It asks the builders for an event per bot use and per bot answer, and for a bot test
   that passes only at 2 uses and 1 answer a live minute.
2. **Main merged in (474d9e91):** lane T's items 1-16. Among them, item 10: "off balance" now reads as a play change,
   so the card's hand bound becomes a note instead of a refusal. That was the cause of A's two half-court refusals.

Arm B's runs had neither fix. No B sentence was re-run.

Arm A's **first sentence only**, word for word, on fresh copies of the same base copy (`d25-court/.tl/s1/jobs-a2/`),
measured the same way (seeds 1-3, 3600 frames, seed 1 twice). The counting hands also read the pack's `notes` list,
where the new use and answer events are published; for the earlier versions that list was empty or absent.

| | **A after fixes, sentence 1** | A, first run (for reference) | B (for reference) |
|---|---|---|---|
| **Shield wall** sentences to the bar | **1** (v0.1.8) | 3 | 3 |
| wall time / tokens in, out | 27.4 min / 4.35M, 42k (core r17 + crew r6, 0 noise rounds) | 153.8 min / 8.35M, 67k | 122.2 min / 3.37M, 33k |
| bots' uses / answers per live min | **4.0 / 4.7** (4 of 5 bots: Oda, Finn, Sable, Pip; Bram 0). Uses are WINDUP starts. Answers are 3.7 a minute from the new `throw_answer` events plus 1.0 a minute of blocks | 2.0 / 0.7 after 3 sentences | 5.7 / 1.3 after 3 sentences |
| bot throws that floor someone (3 min) | 7 | 5 | 14 |
| **Half-court** sentences to the bar | **1**, **promoted** (v0.1.7) | 2, never promoted | 3 (v0.1.9) |
| wall time / tokens in, out | 72.9 min / 3.97M, 35k (court_exchange r13 + r14, crews_stakes r13; 0 noise rounds) | 328 min / 4.74M, 46k, no version | 389.8 min / 5.74M, 48k |
| bots' uses / answers per live min | **10.3 / 17.0**, **all 5 bots**, from `shove_start`, `shove_answer` and `shove_dodge` events | 4.3 / 12.3 (4 of 5), unpromoted | 13.0 / 12.3 (5 of 5) |
| newcomer / perfect hand (the card asks 13 newcomer wins of 20) | 12 / 20 of 20, kept as a note: "built as you asked; a newcomer player now wins 12 of 20 (was 12 of 20)" | refused at 7, then 12 | 6 / 16 (a note) |

What the builders did with the new default:
- **Shield wall.** Core put the throw's use and answer events on a new `game.note` channel. The crew package taught the
  four crew bots to throw and answer, with `throw_start` and `throw_answer` events. The crew builder said plainly
  that its rate stayed under "every 10-20 s": core's `ai.json` gaps of 10-18 s, round resets and the open-shot
  condition gave each bot 1-2 throws in about 80 s.
- **Half-court.**
  - Core's first round tripped a guard row (a bot tell of 14 frames, against the bound of 20). Round r14 fixed it with
    no change to the move.
  - The crew package found that the first-match lesson flag kept Dex and Moss from ever shoving, and fixed it.
  - The card lists the default bot rules as an "unasked rule (the builder's words; you did not ask for it): bots
    shove only when the target has the ball or blocks their own carrier's path ...". That is honest, but it sits beside
    the "bots by default" line that says the Foreman asked for it.
  - The WHAM! banner is now a compact label: the builders read main's updated card juice line ("never padded ... into a
    tall slab"). It is not part of this spike.
- **Same shield camera.** Thrown shields now show in the air more often (`stills/a2_shield_flying.jpg`), because more
  bots throw.

Clips: `clips/a2_shield_v018_throw.mp4` (seed 2, 10-30 s), `clips/a2_court_shove.mp4` (seed 1, 8-28 s); stills
`a2_shield_sheet.jpg`, `a2_shield_flying.jpg`, `a2_court_sheet.jpg`, `a2_court_wham.jpg`, all looked at.

### B on main's fixes (round 3, 16:42-19:15): B gets what A got from main
Arm B's tree was moved to main f5e30ff4, which carries lane T's items 1-22: the rivals routing, and "off balance" read as
a play change. B's first sentence was sent word for word on fresh copies of half-court v0.1.6 and shield wall v0.1.7.
B's second sentence ("The rivals use the X too, and dodge it when they see it coming.") was sent only where the bots
stayed under the bar.
- The runs went one job at a time, each behind `room.sh`, after the disk was freed. They were counted the same way
  (seeds 1-3, 3600 frames, seed 1 twice).
- The counting runs used B's own engine (`S1_ENGINE`).
- No third sentence was sent in this round.
- B does NOT have arm A's own fixes (the default itself, and A2's rate and events): that is the difference under test.

| | **A after fixes, sentence 1** (round 2) | **B on main's fixes** (round 3) |
|---|---|---|
| **Half-court**, sentence 1 | at the bar: all 5 bots shove 10.3 a minute, answer 17.0 a minute; promoted v0.1.7 (72.9 min, 3.97M in) | **0 / 0**: no bot shoves or answers; the sentence names no bots, so the rivals routing has nothing to route. Promoted v0.1.7 (55.1 min, 1.46M in; court_exchange r13 only). Newcomer 12, perfect 20 of 20 |
| half-court, sentence 2 | not needed | routed to court_exchange AND crews_stakes (lane T's "rivals' part" request). Rivals shove **1.3 / min** (crane, moss: **2 of 5**), answer 4.3 / min (`shove_read`, sprint away). Promoted v0.1.8 (53.2 min, 1.46M in). Newcomer 12, perfect 19 of 20. **Still under the bar** after 2 sentences |
| **Shield wall**, sentence 1 | at the bar: 4 of 5 bots throw 4.0 a minute, answer 4.7 a minute; v0.1.8 (27.4 min, 4.35M in) | **1.7 / 1.0**: only Oda throws (**1 of 5**); core r17 only. v0.1.8 (15.9 min, 1.47M in) |
| shield wall, sentence 2 | not needed | routed to core AND crew. **3 of 5 bots** (Sable, Pip, Finn) throw **3.0 / min**, answer 2.0 / min (blocks; the new sidesteps publish no event). **At the bar after 2 sentences**. Promoted v0.1.9 (26.0 min, 4.56M in; core r18 + crew r5, then rally r3 re-verify; the measured pack hashed the same as the promoted one) |
| sentences to the bar | **1 and 1** | **shield 2; half-court more than 2** (not reached in this round) |
| tokens in, all sentences | half-court 3.97M (72.9 min); shield 4.35M (27.4 min) | half-court 2.92M (1.46M + 1.46M), 108.3 min, and not at the bar; shield 6.03M (1.47M + 4.56M), 41.9 min |

**What this says, plainly.**
- Lane T's routing fix does what it promises: a sentence that names the rivals now reaches every package that drives a
  bot (crews_stakes, crew). On shield wall that cut B from 3 sentences (round 1) to 2.
- It does nothing for the first sentence, because a person who adds a move does not name the bots. On both games B's
  first sentence gave bots that do not use the move (half-court 0, shield one bot of five).
- The second sentence ("the rivals use it too") then reaches only the rivals. On half-court that is 2 of 5 bots at
  1.3 a minute: the person's own mates never shove, and a person would type a third sentence.
- Arm A's default (with its A2 rate and events) gave 4-5 of 5 bots on the FIRST sentence on both games, mates and
  rivals alike.
- So yes: with T's fixes in, the default still earns its place. It saves one sentence on shield wall and at least two
  on half-court, and it reaches the mates, which no "rivals" sentence does.
- The cost is unchanged: the bots change difficulty unasked. Half-court's newcomer hand read 12 of 20 on both arms here,
  so the card note appears either way.

### Every count above
- 3600 frames per seed, seeds 1-3, seed 1 run twice with the same hash, 0 script errors on every run (reports in
  `d25-court/.tl/s1/film/<arm>-<game>-<version>.out/`).
- Wall times include a machine at CPU 96-100 % all day: the other lanes plus up to 8 of these chains at once.
- B's first sentences started 08:18-08:19 and A's at 08:27-08:28, under the same load.

## 5. What each arm broke, or risks
**A (on by default)**
- **It changes the game's balance, unasked, through the bots.** The bots that now use and answer the move are a
  difficulty change.
  - Half-court: the newcomer hand fell from 12 of 20 to 7 of 20 the moment the rivals shoved. The Foreman's hand gate
    then refused the change twice (see the court table): a person met "change not finished" for a sentence that never
    mentioned the bots.
  - Karts: the "lead changes hands" share fell from 0.33 to 0.17, and the perfect hand fell from 18 to 16 of 20.
  - Arm B met the same gate on half-court as soon as ITS second sentence made the rivals shove (newcomer 9 of 20): the
    cost is the bots using the move, not arm A as such. A pays it on the first sentence, when the person did not ask.
- **The default "use" line is the Planner's guess.** On shield wall it guessed a cautious moment ("a foe stands clear
  and straight ahead with their guard down"). The bots then threw less than B's builder made them after sentence 1.
  On karts it guessed well: all 5 bots, and the hardest-hitting version.
- **More rounds per first sentence.** A wire round per extra bot package (teams r8, crew r5, crews_stakes r13), and more
  re-verification:
  - karts 124.9 min against B's 135.4 for sentence 1;
  - shield 75.4 min against 32.6;
  - court 191 min and failed, against 224 min and promoted without shoves.
- **Only a NEW move triggers it.** A follow-up sentence about an existing move ("the others still almost never throw
  the shield") routes to one package, as on main: A's shield sentence 3 went to core only. Lane T's routing fix is the
  general answer. A overlaps T where words that name the bots reach every bot package; it does that only for a new
  move, in `foreman.ts applyChangeRequests`.
- **Code risk for other games:**
  - the owner prompt grew by a section; the same single call answers it, with no new model call;
  - the extra JSON keys are optional, so fake scripts and the old answers stay valid;
  - foreman npm test 463 tests, 456 pass, 0 fail, 7 skipped; `tl check --tier fast` 5/5;
  - a rink-core (C++) game: its bot packages are hidden behind the base, so the hint finds only the cartridge owner.
    Not tried here (S4's question).
- **The off switch works for use, not yet for answers.** On karts the bots did not fire the glove at all, but no bot swat
  was seen in 3 seeds. The card promises "they still dodge or block it".

**B (as now)**
- **More sentences, and the person must know which ones.**
  - karts: 3 (use came for free; answers took two more);
  - shield: 3 (the second, "the rivals use it too", went to core only and changed nothing measurable);
  - court: sentence 2 brought the rivals' shoves (1.7 a minute, rivals only), and with them the same newcomer gate.
- **Routing stays a lottery.** B's "rivals" sentences went to one package each time: core on shield, teams on karts,
  court_exchange on court. In a 3 v 3 game the crew's mind is reached only when a sentence happens to name the right
  package. Lane T fixes that on main.
- **Answers are invisible when the builder adds no event.** B's kart dodges and shield sidesteps publish nothing, so
  only a person's hand (or a hit-rate) shows them.
- **What B does well:** a sentence that names exactly what is wrong ("almost never throw ... every fighter") produced
  the strongest bots of the day on shield wall (5.7 throws a minute, 14 knockdowns in 3 minutes).

## 6. How to play each arm
Every pack is an ordinary pack (arm A changed only the Foreman, not the engine), so the main exe plays them as dungeons.
For the Director, the menu rows (pack path -> menu title):

| arm | pack | menu title |
|---|---|---|
| A karts | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-court/.tl/s1/jobs/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.8` | Bumper-kart football: boxing glove, bots by default (S1 A, 1 sentence) |
| A karts, off | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-court/.tl/s1/jobs-off/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.8` | Bumper-kart football: boxing glove, only I can do it (S1 A off) |
| B karts | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-bots-b/.tl/s1/jobs/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.10` | Bumper-kart football: boxing glove, as now (S1 B, 3 sentences) |
| A shield | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-court/.tl/s1/jobs/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.10` | Shield wall: shield throw, bots by default (S1 A, 3 sentences) |
| B shield | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-bots-b/.tl/s1/jobs/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.10` | Shield wall: shield throw, as now (S1 B, 3 sentences) |
| A court (not promoted) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-court/.tl/s1/jobs/half-court-3-v-20261125-1/reports/change-not-made-s1679/pack` (lint and smoke passed in the final verification; the Foreman refused only the newcomer hand count) | Half-court: NBA Jam shove, bots by default (S1 A, refused by the hand check) |
| A2 shield (round 2) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-court/.tl/s1/jobs-a2/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.8` | Shield wall: shield throw, bots by default after fixes (S1 A2, 1 sentence) |
| A2 court (round 2) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-court/.tl/s1/jobs-a2/half-court-3-v-20261125-1/promoted/game.half_court_3_v@0.1.7` | Half-court: NBA Jam shove, bots by default after fixes (S1 A2, 1 sentence) |
| B2 court (round 3, main's fixes) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-bots-b/.tl/s1/jobs-b2/half-court-3-v-20261125-1/promoted/game.half_court_3_v@0.1.8` | Half-court: NBA Jam shove, as now on main's fixes (S1 B2, 2 sentences) |
| B2 shield (round 3, main's fixes) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-bots-b/.tl/s1/jobs-b2/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.9` | Shield wall: shield throw, as now on main's fixes (S1 B2, 2 sentences) |
| B court | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-bots-b/.tl/s1/jobs/half-court-3-v-20261125-1/promoted/game.half_court_3_v@0.1.9` | Half-court: NBA Jam shove, as now (S1 B, 3 sentences) |

To feel what one first sentence gives on each arm, these rows too (optional):
- A shield v0.1.8: `.../d25-court/.tl/s1/jobs/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.8`;
- B shield v0.1.8: `.../d27-sp-bots-b/.tl/s1/jobs/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.8`;
- B karts v0.1.8: `.../d27-sp-bots-b/.tl/s1/jobs/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.8`.

**Keys:**
- karts: F boxing glove (Q hop over it, E whirl to swat it aside), Space bump, Shift boost;
- half-court: C shove (Shift turbo to spin away from one), Space shoot, Q pass, F dunk;
- shield wall: G shield throw (Space or the right mouse button raises the shield and blocks one), J or the left mouse
  button attack, F rush, C slam.

**Clips** (`clips/`, window captures, 20 s each, 0 script errors) and the stills I looked at (`stills/`):
- `a_kart_v018_glove.mp4` (seed 1, 27.5-47.5 s): mint karts punch me (POW!) and the ball; my glove at 12 s is
  answered. `stills/a_kart_bot_pow.jpg`: a mint glove on its zigzag spring hitting my tub, POW!.
  `stills/a_kart_sheet_0-6s.jpg`.
- `b_kart_v0110_glove.mp4` (seed 1, 20-40 s). `stills/b_kart_sheet.jpg`: B's glove is a small red ball on the nose,
  harder to see from the follow camera than A's red box on a spring; a kart hops over the ball near the camera.
- `a_kart_off_only_me.mp4` (seed 1, 17-40 s). `stills/a_kart_off_sheet.jpg`: no mint kart carries a glove.
- `a_shield_v0110_throw.mp4` (seed 3, 25-45 s) and `b_shield_v0110_throw.mp4` (seed 1, 5-25 s); `stills/a_shield_sheet.jpg`,
  `stills/b_shield_sheet.jpg`, `stills/a_shield_camera_blocked.jpg`, `stills/b_shield_melee_dust.jpg`. On both arms
  the low camera behind the captain hides most bot throws: they happen between other fighters, behind bodies and dust.
  A person will see the throw in their own hands, not the bots'.
- `a_court_shove.mp4` (A's built pack, seed 1, 10-30 s); `stills/a_court_sheet.jpg`, `stills/a_court_down.jpg` (a rival flat on
  the court after a shove, the shover off balance).
- `b_court_shove.mp4` (B v0.1.9, seed 1, 10-30 s); `stills/b_court_sheet.jpg`, `stills/b_court_wham.jpg`. On both arms
  WHAM! sits on a tall black slab over the hoop and hides the play (last night's banner, unchanged).
- How it reads to a person, from the film (nobody has played these with real keys yet):
  - karts: A's mint karts punch me and the ball often enough that the glove feels like part of the game from the first
    version (POW! several times a match); B's v0.1.10 punches as often, but its small glove reads less clearly.
  - court: A's first sentence already has rivals and mates shoving and spinning away; B's v0.1.9 shoves three times as
    often (13 a minute) and the court turns into a brawl.
  - shield: neither arm shows the bots' throws well on this camera.

## Lane's recommendation
(The lane's view, kept apart from the evidence above; the owner decides.)

**Round 2 addendum (16:30).** Both fixes asked for below were then made: A2 in arm A, and lane T's on main, merged in.
With them, arm A reached the bar with ONE sentence on all three games (karts already in round 1; shield wall and
half-court in round 2), and promoted on all three. Arm B needed three
sentences on each. The pick stands, now without its conditions open. The cost remains: every new move also changes
difficulty through the bots, as a note the person must read (half-court newcomer 12 of 20 against the card's 13).

The first-round text follows, unchanged:

**Pick: A, on by default. Two fixes go with it before it is the default on main.**

Why A:
- **The owner's own complaint is the bots, and A answers it on the first sentence where a move is simple.**
  - Karts: one sentence gave a glove that all five bots fire and answer; B took three sentences and 227 min to get
    there, and its answers still publish nothing.
  - Half-court: one sentence gave 4 of 5 bots shoving and answering, where B's first sentence gave none ("the request
    did not ask for it").
  - The person never has to know that "the rivals" live in a crew package, nor which follow-up wording reaches it.
- **Where it was no better, it was no worse in sentences.** Shield wall took 3 sentences on both arms. A's default reached
  the crew's mind at once, but the Planner's cautious "use" line made the bots throw rarely. That is a tuning of the
  default line, not of the idea.

What has to go with it (from the evidence, in order):
1. **The balance gate must count the Foreman's own bot default as part of what the person asked.** A on half-court was
   refused twice and B was not. The cause is lane T's classifier: "stand off balance" reads as a fairness ask. A
   default that makes the rivals better is a play change: "built as you asked ... say 'make it fairer' / 'only I can
   do it'", not "change not finished". For lane T: drop "balancw*" as a fairness word when it is "off balance", and
   let a bots-by-default note make the change a play change.
2. **The default "use" line should promise a rate a person sees**, not only a condition. Shield's "only when a foe
   stands clear ... guard down" gave 0.7 throws a minute. Something like "about once every 10-20 s a bot, when it pays"
   would do it; karts landed at about 4 a bot a minute without being asked.

Also:
- Keep the off switch: "only I can do it" gave 0 bot uses on karts. Its card line promises answers that 3 seeds did not
  show.
- A follow-up sentence about an existing move still routes to one package. That is lane T's fix, and A needs it too.

Cost of A: about the same wall time as B's first sentence (more re-verification, fewer later sentences). On shield
wall it cost more tokens (8.4M against 3.4M over three sentences). And there is the risk above: every new move also
changes difficulty through the bots, unasked.
