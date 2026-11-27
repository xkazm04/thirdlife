# S35-packs: two spikes on the packs (juice day, 27 Nov 2026)

Lane S35-packs (Opus), tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane` (branch d27-sp-packs, main
8be26d61, Foreman built and class cache imported at 08:00). I played the person on the Create path: every editor arm is one
Create change sentence sent through Create's door (`engine/ui/foreman_run.mjs` with the `change` flags of
`engine/ui/flags/real.json`, claude-cli sonnet) on a job copy. A hand arm exists only where the editor could not make the
arm, and it says why. Times are local (CET). Raw runs are in `.tl/s35/runs/` of the tree, the measuring tests in
`.tl/s35/tests/`, the measurement copies (pack + my tests) in `.tl/s35/m/`.

Jobs copied once to `.tl/s35/base/` and then per arm into `.tl/jobs/s35-<arm>/`:
- biplane `biplane-duel-two-biplanes-20261125-1` from this tree, at v0.1.4;
- karts `bumper-kart-football-3-20261125-1` from `d25-kart`, at v0.1.7;
- shield wall `shield-wall-3-v-20261125-1` from `d25-shield`, at v0.1.7.

---

# Spike 3: the old bends

## 1. The question (the owner's words, last night's verdict)
"Old bends: biplane's edited test pilot and karts' reversal rule are still in those packs. Clean them with one change each,
or leave them?"

## 2. The arms
**3A clean.** One Create change sentence per game, as a person who read last night's verdict would say it, asking to take
the bend out and keep everything else. Biplane: put the test pilot (`tests/support/pilot.gd`) back as it was before core
r15 added five lines ("she hangs in a stall turn: a person who stayed on her puts a burst into the slow plane"). Karts:
take out what core r16 added with the aerials to pass the old balance bounds: the rule that makes any bot kart sitting
nearly still for 50 frames reverse for 20 and drive forward for 20 (`main.gd`, `bot.pinned_f` / `pinned_out_f`), and the
sweet-spot bump raised from 20 to 23 (`bump.sweet_add`).

**3B leave.** The packs as they are: biplane v0.1.4 and karts v0.1.7, both made by the editor last night.

## 3. The test
- Sentences (sent 08:19 and 08:26):
  - biplane: "Clean up something the old balance check made a builder do that I never asked for: in the round that made
    the barrel roll, it edited the test pilot (tests/support/pilot.gd) so the test hand fires a burst at Vesper whenever
    she hangs in a stall turn. Put the test pilot back the way it was before that edit, and change nothing in the game
    itself."
  - karts, first wording (copy `s35-3A`): "Take out two things the old balance check added with the aerial hits that I
    never asked for: the rule that makes any bot kart sitting nearly still for a moment reverse and then drive forward,
    and the stronger sweet-spot bump (put it back to how hard it was before the aerials). Keep everything else, the
    jumps, the aerials and the air bumps, as it is."
  - karts, second wording (copy `s35-3A2`, the arm): the same sentence with "the old balance check" replaced by "a
    builder". Why a second wording: see 5 below; the first wording is kept as evidence.
- Measures, the same for both arms, on measurement copies (the arm's pack plus my tests, never landed):
  - biplane: `tl ladder` through a REGULAR hand (`bot_ladder_match_regular.gd`: one whole match, lesson and all, flown by
    the pack's own pilot on `TLHand` regular), 20 seeds; J11's `bot_juice.gd` (the pack's sharp pilot + a person's loop on
    E) 18000 frames seed 1 for Vesper's stunts; the Foreman's own `bot_tofu.gd`; 3600 frames twice for the hash.
  - karts: `tl ladder` through a REGULAR hand (`bot_ladder_first_regular.gd`: the first match, lesson and all, the pack's
    own `bot_teams` play on `TLHand` regular), 20 seeds; `s35_kart.gd` (a regular hand that also hops for a high ball,
    J5's play) to the end of a match, seeds 1-5: goals and aerial goals (a goal whose last touch was an aerial or a
    smash), bots' jumps and aerials a minute, bots' reversing runs a minute, bots' still runs that reach 51 frames (the
    point where the reversal rule fires), the longest still run; 3600 frames twice for the hash.

## What the freeze does when a person asks to restore the pilot (an answer in itself)
The biplane sentence reached core r24 (Planner 4 s, "the test pilot file belongs to core"). The builder restored the
pilot and said "deviations: none (test pilot only; no game file changed)". Then the Foreman's measure freeze put the
bent pilot back before verifying: "[foreman] measure kept: tests/support/pilot.gd is a measure the Foreman judges by
(merged before this round); this round's edit was undone ... Change the game, never the test that measures it." (event
751). The job then promoted **v0.1.5, byte for byte v0.1.4 except the version number**, 41 min and 0.43M tokens later.
What a person sees in Create: the job is done, a new version exists, and the what-changed card says "none (test pilot
only; no game file changed); files: data/moves.json, data/rivals.json, ... (16 files)". Create does not show the
"measure kept" note (`engine/ui/create/create_model.gd` knows "balance moved" and "change not finished", not "measure
kept"), and the card lists 16 files that did not change. So: **the freeze protects a bent measure as firmly as a good
one, and a person cannot undo an old bend through Create; worse, Create tells him it was done.**

## 4. Results, A against B

### Biplane
| | **3B leave: v0.1.4** | **3A clean, editor: v0.1.5** | **3A clean, by hand** (`.tl/juice/biplane_3A_hand`) |
|---|---|---|---|
| what changed | - | nothing (the freeze undid it; version number only) | `tests/support/pilot.gd` back to v0.1.1's (5 lines out); no game file |
| why by hand | - | - | the editor cannot make it (the freeze) |
| sentence to promotion / tokens | - | 40.8 min, 0.43M in (0.37M cache reads), 2.9k out | 5 min of my work |
| play for a person | the game | identical files | identical game files: **nothing a person sees or feels changes** |
| regular hand, `tl ladder` 20 seeds (one match, lesson and all) | 13 of 20 (65 %, 44..86), rounds 1.40 : 1.15 | = 3B | 13 of 20 (65 %, 44..86), rounds 1.40 : 1.15, every column identical |
| the Foreman's `bot_tofu` seed 1 (sharp pilot) | `545c586a`, landed 33, perfect rolls 4 | = 3B | `545c586a`, identical |
| J11's `bot_juice` 18000 f seed 1 (sharp pilot + loop): Vesper's loops / rolls / deflects a minute | 0.8 / 3.4 / 1.0 (hash `2c993bfe` = J11's c7) | = 3B | 1.0 / 3.6 / 1.0 (hash `87c5e30c`) |
| when the bent line first acts | - | - | the two test hands' event logs part at f~17,250 of 18000 (minute 4.8, round 3): the first time Vesper hangs in a stall turn in the pilot's cone |
| 3600 f twice, seed 1 | `66997af2` x2, 0 errors | = 3B | `66997af2` x2 (the same), 0 errors |
| lint, smoke 3600 | (job's V1/V2 passed) | passed | pass, pass (`cf1f1d3e`) |

No clip of the biplane bend: the bend lives in the test hand, so there is no moment a person can see. The first place it
acts at all is the test bot's own burst at minute 4.8 of a seed-1 run, and a picture of that would show the test bot, not
the game.

### Karts
| | **3B leave: v0.1.7** | **3A clean, editor: v0.1.8** (copy `s35-3A2`) |
|---|---|---|
| what changed | - | exactly what was asked: `main.gd` loses the pinned-bot override (14 lines out, 1 in), `bot.pinned_f` / `pinned_out_f` gone, `sweet_add` 23 -> 20; nothing else (the promoted pack is file for file the one measured) |
| balance note in Create | - | "balance moved by your change: built as you asked; the share of test rounds where the lead changes hands: now 0.17, was 0.33. Say 'make it fairer'" |
| sentence to promotion | - | 121 min (08:26 -> 10:28): core r19 built in 9.5 min; then teams and show were re-run because the merged pack's invariants (V3) "did not finish within 600000 ms" (they took 90-150 s last night); teams r8 changed nothing ("I found no cause in this package's scripts"), show r2 nothing; 40 hand matches |
| tokens | - | 2.63M in (2.42M cache reads), 18k out |
| the Foreman's hand checks, 20 seeds | newcomer 18, perfect 18 (J5) | newcomer 18, perfect 16 |
| regular hand, `tl ladder` 20 seeds (first match, lesson and all, rookie) | **20 of 20** (100 %), goals 2.95 : 0.40, 6877 frames a match | **18 of 20** (90 %, 77..100), goals 2.35 : 0.80, **10899 frames a match** |
| `s35_kart` regular hand + hops, seeds 1-5 (to the end of a match) | 14 goals, 3 from aerials (red_3, mint_1 smash, mint_2); red won 3 of 5; mean 11288 frames | 17 goals, 2 from aerials (p1, mint_2 smash); red won 2 of 5; mean 13085 frames |
| bots' jumps / aerials a minute (all five) | 23.7 / 18.2 | 20.4 / 15.7 |
| bots' reversing runs a minute (all causes) | 34.7 | 39.2 |
| bot still runs that reach 51 frames (the reversal rule's trigger) | **1 in 5 seeds** (seed 5, mint_1 at f6939); longest still run 42 f in seeds 1-4, 66 f in seed 5 | **0**; longest still run 42 f in every seed |
| 3600 f twice, seed 1 | `3ff4a06c` x2, 0 errors | `c8d6e6fc` x2, 0 errors |

(At 3600 frames `s35_kart` reports ok false: the match is not over yet. That is the test's end condition, not a failure.)

Seen: `clips/3B_kart_v017_seed5_pinned_bot_backs_out.mp4` (10 s, f6700-7300; `stills/3B_kart_v017_seed5_f6880-7010.jpg`):
the one time the reversal rule fired in my runs. A corner scrum at the boards, two mint karts jammed against the rail, a
high ball, red karts hopping; at f6939 one mint kart backs out and swings round. As a person it reads as an ordinary
scramble: nothing says a rule fired. `clips/3A_kart_v018_seed5_same_frames.mp4` (`stills/3A_kart_v018_seed5_f6880-7010.jpg`)
is the same seed and frames on v0.1.8: by then the match has gone another way (red leads 2-0, open deck), because the
first sweet hit already flies differently. There is no frame-matched "after".

### The first kart wording, kept as evidence (copy `s35-3A`)
"... the old balance check added ..." made the change a **fair** change: the Foreman reads `balanc\w*` as a fairness ask
(`foreman/src/boundlift.ts`, `FAIR_WORDS`) and keeps the balance rows as a guard. So the old gate came back:
- core r19 built exactly the clean-up, and the tofu gate refused it (lead_change_share 0.17 < 0.3, event 1308), with no
  balance note;
- r20 and r21 changed nothing ("I found no fix this round that worked"); core merged after its rounds;
- then V3 timed out, and **teams r8 changed bot play nobody asked for**: `shoot.range_max` 40 -> 30,
  `shoot.angle_max_deg` 75 -> 55, the rookie and pro `block` chances 0.25 -> 0.17 and 0.55 -> 0.37, to shorten matches;
- it promoted v0.1.8 with those changes: 125 min, 5.89M tokens in. The what-changed card quotes only core's words, so a
  person does not see the teams change. Hand checks: newcomer 15 of 20, perfect 18 of 20.
- Pack: `.tl/jobs/s35-3A/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.8`. Not an arm;
  not for the menu.

## 5. What each arm broke, or risks
- **3A biplane, editor:** nothing changes, but it cost 41 min and 0.43M tokens, and Create tells the person it was done.
- **3A biplane, by hand:** changes only how the test hand plays, at a moment that comes 4.8 minutes into a seed-1 run;
  play is untouched. It edits a frozen measure by hand, which the Foreman would undo on the next change of this job if the
  job's `pack/` kept the old file (the hand copy is outside the job).
- **3A karts:** a weaker sweet-spot bump makes matches through the regular hand about 60 % longer (6877 -> 10899 frames)
  with fewer goals for the player (2.95 -> 2.35 a match); wins 20 -> 18 of 20. Longer matches made the Foreman's
  invariants run slower: on today's loaded machine (CPU 100 %, ~80 Godot processes across the trees) it timed out at
  600 s and sent teams and show unasked rounds (they changed nothing in the arm, but in the first wording teams changed bot
  play). The reversal rule itself was nearly dormant: once in 5 seeds, and with it gone no bot sat still 51 frames.
- **3B karts:** keeps a rule nobody asked for that fires about once in 15 match minutes, and a sweet bump 15 % stronger
  than the contract. **3B biplane:** keeps a test-only line that acts once in about 5 minutes of test flying.
- Other games: none (pack-only changes, no engine, foreman or contract file touched).

## 6. How to play each arm (menu rows are the Director's)
| arm | pack path | menu title |
|---|---|---|
| 3B biplane | already on the menu (v0.1.4) | "Biplane duel v0.1.4 (made in Create)" (as now) |
| 3A biplane, editor | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/s35-3A/biplane-duel-two-biplanes-20261125-1/promoted/game.biplane_duel_two_biplanes@0.1.5` | "Biplane duel v0.1.5: pilot clean-up asked, freeze kept it (spike 3A, Create)" |
| 3A biplane, by hand | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/juice/biplane_3A_hand` (id `game.biplane_duel_clean_pilot` 0.2.0) | "Biplane duel: clean test pilot (spike 3A, by hand)" |
| 3B karts | already on the menu (v0.1.7) | "Bumper-kart football v0.1.7: jumps, aerials, air bumps (made in Create)" (as now) |
| 3A karts | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/s35-3A2/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.8` | "Bumper-kart football v0.1.8: bends cleaned (spike 3A, made in Create)" |

Keys: biplane arrows steer, W throttle, Space short burst, F long burst, E loop, Shift roll; karts Q jump (again in the air to flip), Space bump,
E whirl, Shift boost. The three biplane rows play the same: they are listed so the owner can see that for himself. In
karts, compare how hard a well-timed bump (the sweet spot) sends the ball, and how long a match runs.

---

# Spike 5: shield wall's `bot_call`

## 1. The question (the owner's words, last night's verdict)
"Shield wall `bot_call`: accept it as a behaviour change, or have bots hold their big moves while a call charges?"

## Which version fails, and why (shown)
`tests/bot_call.gd`, untouched, seeds 1-5, 18000 frames max:

| pack | seed 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| editor v0.1.7 (`promoted/game.shield_wall_3_v@0.1.7`) | pass (first call f349) | pass | pass | pass | pass |
| hand pack (`C:/Users/kazda/kiro/third-life/.tl/proof-games/shield_charge_hand`) | **FAIL**: first call f5299, charged together 1 | pass | pass | **FAIL**: first call f4149, floored 1, charged together 0 | pass |

Only the hand pack fails. The cause, from a probe of seed 1 (`.tl/s35/tests/s35_callprobe.gd`, frames 286-312): Pip, a
rival, starts a shield charge at f~280 (the lesson is over, `lesson.on` false, but its protection window `hold_f` still
runs); the captain's meter is full at f300 and he blows the lesson's call at f301; Pip's charge, already running, bowls
him at f303 and the call is broken at f304. The lesson's first call is meant to be unbreakable: the rally module cancels
every blow on a "safe" caller (`scripts/rally/call.gd`, `gate`), but the hand juice's charge and slam floor their victims
directly and never ask that gate. Seen: `stills/5A_hand_lesson_call_broken_f286-345.jpg` (f302 READY and "Q: captain's
call"; f306 BOWLED!, CALL BROKEN; f345 the captain on the stones), clip `clips/5A_hand_lesson_call_broken.mp4` (6 s).
In the editor's v0.1.7 the core sends rush and slam contacts through the same gate, so the lesson's call holds there.

## 2. The arms
**5A accept.** A Create sentence accepting that a charge or a slam may break a captain's call, even the lesson's first
one, and that the call test should expect it. On the hand pack (which the editor cannot reach: it is not a job), "accept"
is the pack as it is.

**5B hold.** A Create sentence: while a captain's call charges (horn raised to burst), his own crew's bots hold their
charge and slam; the rivals may still charge or slam him to break it, but the lesson's first call stays unbreakable, also
against a charge or a slam. The last clause is mine: it names the actual cause above, so the arm can work on the hand
pack; it is what a person who saw the failure would add. On the hand pack I built it by hand, because the editor cannot
reach the hand pack.

## 3. The test
- Sentences (both sent 08:19-08:20 on two copies of the v0.1.7 job):
  - 5A: "Now that fighters charge and slam, I accept that a big move can break a captain's call: if a shield charge or a
    leaping slam floors the captain while his call charges, the call is broken, even the first one in the lesson, and he
    builds it up again. That is the game I want, not a bug. The captain's call test should expect that: a call broken by
    a charge or a slam is a broken call, not a failed test."
  - 5B: "While a captain's call charges, from the moment he raises the horn until it bursts, the bots on his own crew hold
    their shield charge and their leaping slam, so the call fills and his crew can charge together after it; once it has
    burst they use them again. The rival bots may still charge or slam him to try to break the call, but the first call,
    the one the lesson teaches, stays unbreakable as it is today, also against a charge or a slam."
- Measures, the same for every arm (measurement copies in `.tl/s35/m/sh*`):
  - `bot_call` as it was (v0.1.7's file, `s35_call_orig.gd`) seeds 1-5, and each pack's own `bot_call` where it changed;
  - `s35_shield.gd`: J19's captain hand (before I added Q it gave J19's own hashes at 3600 frames: `d7211da4` on v0.1.7,
    `e0b41355` on the hand pack, so the play is J19's) plus Q when the call is ready; 10800 frames (3 match
    minutes) seeds 1-3: each crew's calls started, filled (burst) and broken; bots' charges and slams a minute by side;
    big moves a bot starts while his own crew's call charges; knockdowns by big moves a minute;
  - 3600 frames twice for the hash, 0 script errors;
  - a clip each, at the lesson call (seed 1, `bot_call`'s captain) and, for the editor arms, at f6051 of seed 2, the one
    moment in 9 match minutes where a bot starts a big move during his own crew's call.

## 4. Results, A against B

Editor arms (both v0.1.8, from v0.1.7), with v0.1.7 as the reference:

| | v0.1.7 (reference) | **5A accept, v0.1.8** | **5B hold, v0.1.8** |
|---|---|---|---|
| sentence to promotion | - | 21.1 min (08:20-08:41) | 21.4 min |
| tokens (builder + Planner) | - | 0.98M in (0.89M cache reads), 9.5k out | 1.04M in (0.96M cache), 6.9k out |
| what changed | - | `call.gd`: a lesson call can be broken by moves in `call.big_moves` (`rush`, `slam`, new key); a broken lesson call ends the lesson; `state.call.big_broken` count; **`tests/bot_call.gd` rewritten**: a lesson call broken by a big move no longer needs "floored 2" | `call.gd` `_hold_big()`: from horn to burst the caller's own bots' rush/slam presses are dropped; nothing else |
| lines changed (diff lines, + and -) | - | game 19, test 20 | game 15 |
| `bot_call` (old meaning) seeds 1-5 | 5 of 5 | 5 of 5 | 5 of 5 (hashes identical to v0.1.7) |
| `bot_call` (its own) seeds 1-5 | 5 of 5 | 5 of 5 (no seed met the new branch: "broken by charge or slam before first 0") | same file as v0.1.7 |
| crew calls started / filled / broken (3 seeds x 3 min) | 17 / 15 / 2 | 17 / 15 / 2 | 18 / 15 / 3 |
| bots' big moves a minute, crew / rivals | 2.9 / 7.3 | 2.9 / 7.3 | 2.5 / 7.2 |
| big moves started during the bot's own crew's call | 1 (Oda's slam, seed 2 f6051) | 1 (the same) | **0** |
| knockdowns by big moves a minute | 11.1 | 11.1 | 10.9 |
| 3600 f twice, seed 1 | `77a8ceb6` x2, 0 errors | `60e9f0e5` x2, 0 errors (differs only by the new state key) | `77a8ceb6` x2 (= v0.1.7) |
| watchdog | - | one trip, seed 3 f7431 (`_pack_tick` 381 ms, 260 ms processor) on the loaded machine; the same seed re-run twice: passed, `221013d8` both | - |

Hand arms (the version that fails), with the hand pack as the reference:

| | **5A accept = the hand pack as it is** | **5B hold, by hand** (`.tl/juice/shield_hand_5B`) |
|---|---|---|
| made by | nothing to make: the hand pack already lets a big move break any call | me, 15 min: the juice module asks the rally call's safe gate before a charge or slam floors a man (`_protected(v)`, 17 diff lines in `scripts/juice/mod.gd`); its bots already held big moves while their crew's call or surge ran |
| why by hand | the editor cannot reach the hand pack (no job) | same |
| `bot_call` (untouched) seeds 1-5 | 3 of 5: s1 first call f5299 (lesson call broken f304), together 1; s4 first call f4149, floored 1, together 0 | 3 of 5: **the lesson call is never broken**, the first call fills on time in all 5 (f340, 561, 401, 239, 379); still fails other rows: s1 floored 1 (Pip's charge carries him out of the ring before the burst), s4 moved 0.4 (needs 0.5) |
| crew calls started / filled / broken (3 seeds x 3 min) | 12 / 9 / 3 (s3: the lesson call broken 1 frame after the horn) | 14 / 9 / 5 (s3: the lesson call fills; three later calls are broken by rivals, which the sentence allows) |
| bots' big moves a minute, crew / rivals | 7.7 / 14.8 | 8.0 / 13.4 |
| knockdowns by big moves a minute | 22.5 | 22.9 |
| 3600 f twice, seed 1 | `d482d8e1` x2, 0 errors | `d482d8e1` x2 (nothing differs in that first minute), 0 errors |

How it feels (clips looked at, frame by frame in the stills):
- **Hand, 5A (as is)** `clips/5A_hand_lesson_call_broken.mp4`: the lesson tells me "Q: captain's call", I press it, and in
  the same breath Pip's charge, which I never saw start, bowls me: BOWLED!, CALL BROKEN, I am on the stones. As the
  game's first lesson about the call it reads as a cheat, not as a rule: the lesson promised this call is safe.
- **Hand, 5B** `clips/5B_hand_lesson_call_holds.mp4` (`stills/5B_hand_lesson_call_holds_f286-360.jpg`): the same Pip
  charge runs past me while I hold the horn up; at f341 the call bursts, gulls fly, and Pip's charge bowls one of my mates
  beyond me. The charge is still there and still loud; only the lesson's promise is kept.
- **Editor, both arms, the lesson** `clips/5A_editor_v018_lesson_call.mp4`: identical in 5A and 5B on seed 1 (no big move
  reaches the caller in the lesson); the editor's rivals charge far less than the hand's.
- **Editor, seed 2 f6051** `clips/5A_editor_v018_seed2_oda_slams_during_call.mp4` against
  `clips/5B_editor_v018_seed2_oda_holds.mp4` (`stills/5*_editor_v018_seed2_f6030-6150.jpg`): in 5A Oda leaps with his
  shield over his head, a red slam ring on the stones, while my horn is still up; the burst comes at f6090 and his slam
  lands after it. In 5B Oda stays on his feet trading blows at the side, there is no slam ring, the burst is the only big
  thing on screen. The difference is real but small: on the editor's pack it happened once in 9 match minutes.

## 5. What each arm broke, or risks
- **5A (editor)**: it rewrote a pack test to a new meaning on a person's word, and the Foreman let it (the test is not a
  "measure"; only the tofu bot and what it loads are frozen). The new branch never ran in 5 seeds, so the rewritten test
  is unproven. A broken lesson call now ends the lesson early (`end_lesson()`, the builder's own addition, named in its
  note). Adds a `big_broken` state key, so every v0.1.7 hash of this pack changes. One watchdog trip under load, not
  reproduced.
- **5B (editor)**: none seen; hashes equal v0.1.7 wherever no bot would have started a big move during its own call. It
  drops a bot's queued big move rather than delaying it (the builder said so).
- **5A (hand, as is)**: the lesson's call can be broken by a move the player has not seen start; `bot_call` fails 2 of 5.
- **5B (hand)**: a rival charge now passes through a protected caller as if he were not there (no clang, no word). The
  test still fails 2 of 5 on rows the hold does not touch (where bodies stand at the burst). Other games: none (pack-only).

## 6. How to play each arm (menu rows are the Director's)
| arm | pack path | menu title |
|---|---|---|
| 5A editor | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/s35-5A/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.8` | "Shield wall v0.1.8: big moves break a call (spike 5A, made in Create)" |
| 5B editor | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/s35-5B/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.8` | "Shield wall v0.1.8: bots hold big moves while a call charges (spike 5B, made in Create)" |
| 5A hand | `C:/Users/kazda/kiro/third-life/.tl/proof-games/shield_charge_hand` (already on the menu) | "Shield wall: charge and slam (juice by hand)" (as now) |
| 5B hand | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/juice/shield_hand_5B` (id `game.shield_wall_hand_hold` 0.2.1) | "Shield wall: charge and slam, the call holds (spike 5B, by hand)" |

Keys: WASD, right mouse / Space guard, left mouse bash, F charge, C slam, Q the captain's call. To feel the question:
play the lesson until "Q: captain's call" shows and press Q with rivals near you; in the hand packs a rival charge is
often already running at that moment.

---

# Lane's recommendation (separate from the evidence)
**Spike 3, biplane: leave it (3B).** The bent pilot line changes nothing a person meets (identical game files) and
almost nothing the Foreman measures (identical 20-seed ladder, identical tofu hash; the test hand first differs 4.8 minutes
into a run). Create cannot clean it anyway: the freeze keeps the bent file, and Create then reports a version that changed
nothing as done. What I would fix instead is the editor: Create should show the "measure kept" note to the person, the
what-changed card should not list files that did not change, and a person should be able to say "put the test back as it
was in vN" (an explicit restore of an earlier merged measure is not a builder bending a test). Those are questions for
lane T and the Director, not for this pack.

**Spike 3, karts: leave it (3B), or clean only the reversal rule.** The editor cleaned it exactly and honestly (one
sentence, nothing extra), so the editor path works. But the evidence says the two parts of the bend are not alike: the
reversal rule is dead weight (it fired once in 5 seeds, and without it no bot ever sat still 51 frames), while the
stronger sweet-spot bump is doing work: without it a regular hand's first match runs about 60 % longer with fewer goals,
and the longer matches pushed the Foreman's invariants run past its time limit. If the owner wants the packs free of
anything nobody asked for, I would send only the first half ("take out the rule that makes a still bot kart reverse")
and keep the sweet bump, which a player is likely to call the better game.

**Spike 5: hold (5B), in both packs.** On the editor's v0.1.7 nothing fails today; 5B costs 14 lines, changes no test,
leaves every hash as it was until the moment it acts, and removes the one case seen (Oda's slam during his own crew's
horn). 5A makes the lesson's first call breakable, ends the lesson early when that happens, and rewrites a pack test whose
new branch never ran: it trades a promise the lesson teaches for nothing a person asked to feel. On the hand pack, the
failure the owner was told about is exactly that promise broken by a charge nobody saw start; the hand 5B keeps the
promise (0 broken lesson calls, the first call on time in 5 of 5). `bot_call` still fails 2 of 5 on the hand pack for a
different reason (where bodies stand when the horn bursts, in a much busier game): that part is a real "accept the
behaviour change" question, and I would ask the owner it separately, with the 5B hand pack as the base.

**For the editor (both spikes):** the word "balance" in a person's sentence turns a play change into a guarded "fair"
change (`FAIR_WORDS` matches `balanc\w*`), and with it the old gate's refusals and unasked bends come back (the first kart
wording: three refusals, then teams changed shooting and blocking, 5.9M tokens). A sentence that only mentions "the old
balance check" is not asking for fairness. That is the most useful finding of the day for lane T.
