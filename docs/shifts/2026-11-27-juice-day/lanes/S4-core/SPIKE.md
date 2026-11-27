# S4-core spike: a C++ lane for the rink core's bots? (27 Nov 2026, juice day)

Lane S4-core, Opus. Arm A in `.claude/worktrees/d25-arsenal` (branch d27-sp-core), arm B in
`.claude/worktrees/d27-sp-core-b` (branch d27-sp-core-b), both from main 8be26d61. Nothing is committed: the Director
commits each arm on its own branch. Times are local (CET).

## 1. The question, in the owner's words

> "Rink core: bots that use abilities, and a dive block. Is it worth a C++ lane?" (ask 4, `docs/shifts/2026-11-27-night/VERDICT.md`)

Last night (J1) the hand's meteor slapshot worked; the rival bots used it 0 times a minute, because thirdjam's core gives
abilities to the human only ("Bots never hold one", CARTRIDGE.md) and has no dive verb.

## 2. The two arms

**A, C++ (a native core patch).** `engine/cores/rink/native/patches-thirdlife/0005-bot-abilities-dive.patch` (+260 / -2
lines in thirdjam's `JamSim.cpp`, `JamSim.h`, `JamCartridge.h`, applied to a copy as patches 0001-0004 are). Seven new
switches in a game's `data/<name>.rules.json` sidecar, so Create can write them (Foreman's `ruleSwitches()` reads them and
their ranges from the patch; CARTRIDGE.md section 1 says them in player words):
- `bot_ability_share` 0..1 (how often), `bot_ability_skill` 0..1 (how well), `bot_ability_team` 0..2 (both / rivals / mates).
  Bots then hold the cartridge's ability and use it from their own reads, as thirdjam's own playtester does: the shotgun
  from a carry facing the net inside range, with a body in the lane, a clear lane or a shot their brain wanted, after a
  visible wind-up (the shot held, so a winding bot can be checked off his feet at `contact.spin_stability`); the hip check
  on a carrier in reach; the shield under pressure; the slow puck on a pass.
- `dive_share` (meteor shots), `dive_shot_share` (ordinary shots), `dive_reach_m`, `dive_down_frames`: a new verb. A bot
  that reads a shot heading into its net and passing within reach in the next 0.6 s throws itself across the lane, lies
  there (the price: it cannot act), and its laid-out body stops one shot: the puck rings off at a quarter of its speed and
  a meteor stops being a meteor. Events `dive`, `dive_block`; snapshot fields `TlWindupLeft`, `TlDiveFrames`,
  `TlDives`, `TlDiveBlocks`.
- Every switch at 0 is thirdjam, bit for bit (proved below). The pack's own part is one sidecar file plus the drawing.

**B, no C++.** The pack and the data do what the existing core allows. A rival "meteor" is a cartridge effect,
`meteor-heat` (shot speed x2 for 10 s), lit when a skater crosses the west ring (`zone_enter`) or lands a check
(`check_landed`); the pack draws a lit bot's stick on fire and its next shots as meteors (fireball, trail, METEOR!). The
"dive" is the pack's decision on the same read as A's, drawn by laying the figure out in a copy of the snapshot (the base's
fall pose), with DIVE! over it; a levels tune (`opp.block_min_dist_m=0`, mates too) makes thirdjam's backs step into every
shot's lane so a drawn dive sometimes coincides with a real standing block. **What B cannot do:** a bot cannot hold or fire
the cartridge's ability, so a B "meteor" fells nobody and has no wind-up (the pack cannot hold a bot's shot); lighting is
positional, not a bot's read; the hot shot stays under the puck's 30 m/s cap (an effect cannot lift a puck cap for one
skater; the hand's meteor flies at up to 56); the effects light anyone who crosses the ring or lands a check, the hand and
his mates included; a drawn diver's body stays upright in the sim (the figure lies while its body skates on) and a dive can
never stop a meteor (the core's shotgun goes through every body it fells).

The drawing is shared (`scripts/s4_bots.gd`, one file, `data/tuning.json` "s4".source = core | pack), so the owner
compares what the bots do, not two looks. It also fixes J1's meteor.gd calling a diver "FLOORED!".

## 3. The test

- Packs (copied once into `d25-arsenal/.tl/s4-base` and `.tl/jobs/s4-base-arsenal`, then per arm):
  - the J1 hand pack `.tl/proof-games/arsenal_meteor_hand` (v0.1.22) -> `.tl/s4/hand_a` (A tree), `.tl/s4/hand_b` (B tree);
    the unchanged copy `d27-sp-core-b/.tl/s4/hand_base` is the control;
  - Create's v0.1.23 (`three-against-three-hockey-20261125-1`, copied whole, lastSeq 1072) -> `.tl/s4/editor_a`, `.tl/s4/editor_b`.
- The sentence for both arms is J1's own last line, word for word: "The rival bots should try a meteor of their own from
  distance, and dive in front of mine to block it." (A: `bot_ability_team` 1 = rivals; B: the same read for its drawn dives.)
- Seeds 1-3, 3600 frames (one minute), twice; the scripted hand `bot_meteor` (F when ready, a full wind-up from 26 m),
  its blind twin on the editor copies. `tl ladder`: 10 whole matches (3-minute timer, rookie as `match.json` says) through
  `TLHand` regular and sharp (`tests/bot_s4_ladder.gd`: bot_meteor's decisions through a person's hand).
- The core lab: `rink.sh check-cartridge` (thirdjam's playtester, 10 seeds a level, the cartridge alone, no pack) and
  `rink.sh balance-thirdlife --parity` / its own baseline.
- Generality: a new Create sentence on a copy of the job in tree A (another ability, the hip check).

## 4. Results, A against B

| measure (hand pack unless named) | unchanged (J1) | **A: C++ patch** | **B: no C++** |
|---|---|---|---|
| rival bot meteors a minute (seeds 1/2/3) | 0 | **1 / 2 / 3** (each after a wind-up of 7-33 frames) | 0 / 3 / 0 hot shots (no wind-up) |
| mates' bot meteors a minute | 0 | 0 (team 1 = rivals, by the sentence) | 0 / 1 / 0 (the effect lights anyone) |
| goals from a bot meteor (3 min of play) | 0 | 3 | 1 (a mate's) |
| skaters a bot meteor felled | 0 | 3 (seed 3) | 0 (cannot: no shotgun) |
| bot dives a minute (mates / rivals) | 0 | 0/1, 1/3, 0/0 | 1/2, 0/0, 0/0 (drawn) |
| dive blocks a minute | 0 | 0, 4, 0 | 0, 0, 0 |
| **the hand's meteors stopped by a dive** | 0 | **3 of 10** (seed 2: 3 of 4) | **0 of 13** |
| editor copies v0.1.23 (blind hand), rival meteors / goals / hand meteors stopped | 0 | 3,0,3 / 3,0,1 / **6 of 7** | 0,2,1 hot shots / 1 / 0 of 11 |
| hand wins, rookie, 10 matches, **regular** hand (goals for:against) | 6/10 (4.8:4.7) | **2/10 (3.7:6.3)** | 7/10 (5.8:5.3) |
| hand wins, rookie, 10 matches, **sharp** hand | 8/10 (6.6:4.0) | 7/10 (5.1:5.3) | 8/10 (7.2:4.0) |
| same run hash twice, seeds 1-3 (hand) | 097fcaa8 / 1554514d / f10b538d (once today; seed 1 = J1's, twice) | 37ff52a2 / 1edeb56d / 24bd9a9e, each twice | c057ff20 / 48a7ee0a / 1e1aa07d, each twice |
| the core's own hash (seeds 1-3) | 8a2b5987 / fd1ed5be / a99ddcc7 | 7b013934 / f1718471 / cb80e65d, each twice | 7a420707 / 44d2a07b / bbb6716d, each twice |
| editor copies, run hash seeds 1-3 (twice each) | - | fe6725c1 / 9abfc056 / 8119ddc0 | 91108602 / 75ad7f2c / 74ad7d87 |
| script errors, 24 runs + 3 control | 0 | 0 | 0 |
| frame cost alone, seed 1 twice, p50 / p99 ms | 4.36, 4.41 / 23.2, 30.9 | 4.44, 4.52 / 28.8, 25.1 | 4.17, 4.62 / 28.8, 23.8 |
| lab, thirdjam playtester wins rookie/pro/all_star (goals a match) | 10/10/10 (18.9/19.0/19.7) | 10/9/10 (14.1/12.5/13.1) | 10/10/10 (22.1/17.7/19.2) |
| lab balance check | - | **PASS** parity: switches off = thirdjam, 600 of 600 matches + 43 gym probes hash for hash; hockey.thirdlife baseline PASS 600/600 | core untouched |
| hockey house pack (hokej, 14 tests, seed 1) | - | 14 of 14 pass, **same state hash** as main's core | (main's core) |
| core selftest | - | `rink.bot_abilities` PASS (814): off = RinkCore every frame; on: bots use + dive; same hash twice; bad values refused | - |
| plays in | - | an exe exported from tree A (main's exe refuses the new switch) | main's exe |

Notes, honestly:
- Frame cost is the shared machine's noise; neither arm moves it measurably (A adds a few loops over 6 skaters a frame).
- The ladder is 10 matches a cell (95 % intervals 20-45 points wide): A against the regular hand is the only clear
  move (6/10 -> 2/10, goals against 4.7 -> 6.3). The scripted hand never pays the wind-up's price in these runs.
- A's meteors at the far end read as words and a fire burst at the follow camera's distance (`A_sheet_f2650-2706`);
  a dive near the camera can put its word above the picture (the near mate's dive at 1422 shows no word in the film; the
  rival's at 1671 does). Both are drawing details, not the mechanism.
- The lab's playtester wins everything at this cartridge (a goal flood, J1's finding); A's dives cut its goals by about
  a third; B's lighting adds goals (anyone lit shoots harder).

**Generality (one real Create change, on a copy in tree A).** Sentence (367 characters): "Swap my meteor on F for a hip
check: my next check knocks him down twice as long and shoves him 3 m, and it comes back 10 seconds after each use. The
rival bots get the same hip check and use it on me when I carry the puck close to them, often and well. Any bot that is
not carrying should now and then throw itself in front of a hard shot at its own net to block it." The job copy's `ref/`
was refreshed with A's CARTRIDGE.md (a job made after A lands would have it).
- The Planner sent it to the cartridge package; its builder made the hip check (v0.1.24 promoted) and **named the A
  switches exactly** ("`bot_ability_share` 0.7, `bot_ability_skill` 0.8, `bot_ability_team` 1, `dive_shot_share` 0.3"),
  then wrote NOT BUILT: "That file is outside this package's scope ... and the contract says no sidecar". It asked; I
  answered as a person ("Yes, add that file ..."); the next round still could not write it. 45.8 min, 1.63M tokens in
  (1.46M cache reads), 16.8k out.
- With the builder's own values written by hand into a copy of v0.1.24 (`.tl/s4/gen_hip`): the rival bots hip-check
  **5 / 4 / 5 times a minute**, and dive at ordinary shots (seed 2: 2 dives, 2 blocks). So the core side generalises to
  another ability with no new C++; the editor side is blocked by package scope (a blocked-editor finding for lane T, below).

**Cost.**
- A: C++ patch +260 / -2 lines (3 files), selftest + check tool 134 lines, docs +28 / -3 lines; the DLLs rebuilt (debug 45 s, release
  6 m 22 s under load; the first build from nothing 1 m 39 s, godot-cpp cloned at its pin). The lab rebuilds with it. A
  future thirdjam update re-applies 0005 with `patch -p1` like 0001-0004; a hunk that no longer applies fails the build
  (never a half-patched core), and `balance-thirdlife --parity` + `rink.bot_abilities` prove switches-off parity again.
  Ships only in an exe built from the tree (main's exe refuses `bot_ability_share`).
- B: data only (2 effects, a levels tune) plus the pack drawing; no build, ships in main's exe today. Depends on effect,
  zone and event semantics that thirdjam already exports.
- Shared by both: `s4_bots.gd` 410 lines (about 150 of them B-only: heat, fake dives, the fireball), main.gd +7, meteor.gd +1.
- Lane wall time: A's patch, build, parity and selftest about 2 h of the day; B's data and drawing about 45 min; measuring
  and filming both about 2 h. Lane tokens: not counted by the lane (the harness has them).

## 5. What each arm broke, or risks

- **A:** nothing measured for other games: switches off = thirdjam (lab parity 600/600, selftest, hokej 14/14 same hashes).
  The thirdlife core's snapshot gains four fields and two events (SNAPSHOT.md says so); the plain core is untouched. A pack
  that uses the switches cannot run in an exe without the patched DLL: main's exe refuses the rule and then crashes on the
  null core (`exe_main_a.log`: "unknown rule bot_ability_share", then a segfault: a base/kernel robustness bug of its own).
  Balance: at 0.6 / 0.6 the rivals' dives stop many of the hand's meteors (3 of 10 by the scripted hand, 6 of 7 by the blind
  one) and the regular hand's wins fall to 2/10; the numbers are data and Create can change them.
- **B:** no core risk. In this pack the effects also light the hand and his mates (anyone crossing the west ring or landing
  a check shoots twice as hard for 10 s), the lit-tag and the drawn dive can lie (a lying figure that slides with a skating
  body), and the rules sidecar opens main's thirdlife core for this pack (switches off; only the bots' block tune moves).

## 6. How to play each arm

Keys: WASD skate, Shift sprint, left button shoot (hold to wind up), right button check, Space poke, F lights the meteor
(a second after the drop).
- **A** (needs the patched core): the exe exported from tree A, `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-arsenal/.tl/s4/exe/ThirdLife/ThirdLife.exe -- --dungeon=C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-arsenal/.tl/s4/hand_a`
  (or `bash engine/tools/tl.sh play --pack=.tl/s4/hand_a` in tree A). Menu title, for an exe built after the Director
  commits branch d27-sp-core: **"Arsenal hockey: rival meteors and dives (C++ arm A)"**, pack
  `d25-arsenal/.tl/s4/hand_a`. The editor copy: `d25-arsenal/.tl/s4/editor_a` ("Arsenal hockey v0.1.23: rival meteors (C++ arm A)").
- **B** (main's exe): pack `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-core-b/.tl/s4/hand_b`, menu title
  **"Arsenal hockey: hot-shot rivals, drawn dives (no C++ arm B)"**; the editor copy `d27-sp-core-b/.tl/s4/editor_b`.
- Clips: `clips/A_core_dive_blocks_and_bot_meteor.mp4` (11.4 s: a rival winds up with a heat ring, fires, the hand's mate
  dives and stops it; the hand's meteor, a rival dives across it, BLOCKED!, the meteor put out, twice; a rival's meteor
  scores at the far end), `clips/B_pack_drawn_dive_and_hot_shots.mp4` (7.3 s: a drawn DIVE! and the hand's meteor scores
  through it; a lit rival's hot shot with METEOR! and a fireball that fells nobody).
- Stills looked at: `stills/A_sheet_f1670-1690_hand_meteor_blocked.jpg` (DIVE!, the rival laid out across the lane,
  BLOCKED!, smoke where the meteor died), `A_sheet_f1395-1440_rival_meteor_mate_dive.jpg` (a rival's heat ring and burning
  stick, the fireball, METEOR!, a figure down), `A_sheet_f2650-2706_bot_meteor_goal.jpg` (STICK ON FIRE far up the ice,
  METEOR!, GOAL), `B_sheet_f2300-2352_hot_rival_shot.jpg` (#9's stick alight, METEOR!, a fireball at the hand: nobody
  falls), `B_sheet_f1090-1140_drawn_dive.jpg` (DIVE! over a rival, GOAL anyway).
- How it feels (headless and on film): in A the rink answers the meteor: a rival lights up and winds up in front of you
  (a target for your check), a defender throws himself across your shot and the fire goes out on his body; in B the rivals
  sometimes shoot a hotter puck with fire drawn on it and a figure falls in the picture, but your meteor goes through as
  before and nobody falls to theirs.

## 7. Lane's recommendation (separate from the evidence)

**A.** The question "is it worth a C++ lane" turned out cheaper than it sounded on this machine: the native build works
from nothing in under two minutes, the patch system K8 built carries a new verb with a proof that switches off are
thirdjam (lab parity, selftest, the house game's hashes), and Create already reads new switches from the patch with no
Foreman change. The difference the owner asked for only exists in A: bots that fire the real ability (with a wind-up you
can punish) and a dive that really stops a meteor; it moved the regular hand's results (6/10 -> 2/10) where B did not
move them at all. B is a drawing over the same game, and its honest ceiling is visible in the clip (a drawn dive, the goal
goes in). Before A ships to the owner: (1) lane T makes a rules sidecar writable by the cartridge package (the generality
run shows the builder already knows the exact keys); (2) the Director decides the default numbers (0.6 / 0.6 is strong
against a regular hand); (3) the exe is rebuilt from a main that has the DLL, and the base stops crashing when a rules file
is refused.

## A after T's fix (round 2, 27 Nov 15:31-16:10)

The first results above are kept as they were. This round asks one question: with lane T's item 7 on the tree, can Create
drive arm A's switches?

- **The tree:** d27-sp-core at 9e565f8e (main merged in by the Director, lane T items 1-22). Foreman rebuilt, engine
  re-imported (0 errors), patched core still in bin/ (debug 1613824 bytes, release 1536512). Foreman's `knownRules()` lists
  all seven 0005 switches.
- **The job:** a fresh copy of the v0.1.23 job (`d25-arsenal/.tl/jobs/s4a2-arsenal` from the untouched `s4-base-arsenal`,
  promoted 0.1.23 the latest), its `ref/cores/rink/` refreshed with A's CARTRIDGE.md and SNAPSHOT.md as before. The
  hip-check sentence was sent word for word (`.tl/s4/gen_sentence.txt`, 367 characters), with the same change flags. One job only.
- **Time and tokens:** 15:32:38 to 15:51:23, 18.7 min (round 1: 45.8 min). 0.87M tokens in (0.78M cache reads), 9.5k out.
- **What Create did:**
  - The Planner named the cartridge again (event 1076).
  - This time the change took the **quick cartridge diff**, not a builder round (event 1080). The diff edits only
    `data/harbour.cartridge.json`:
    - F became `hip_check`, magnitude 2, `cooldown_frames` 600;
    - `game.rink.goal_width_m` 2.8 -> 2.3 and `game.skater.goalie.reach_m` 1.4 -> 1.7 (the measured check found a goal flood);
    - `game.ai.body_check` "1 -> 1", a no-op: the diff took "the rival bots use the hip check" for the body-check key.
  - The diff's own words: "These keys can't set the 3 m shove or make bots dive in front of shots, so a builder needs to
    add both."
  - No builder round followed. The cartridge was promoted at r13, and only the dependent drawing package (harbour) was
    rebuilt (r16).
  - v0.1.24 was promoted (event 1131). Its what-changed card lists the cartridge keys and says "part of your change was NOT
    made" only about the moves landing.
- **Whether the builder wrote the rules file:** no. No `data/harbour.rules.json` exists anywhere in the job (ws, pack or
  promoted). No package ever saw the sidecar: lane T's item 7 widens the cartridge **builder's** scope and prompt, and this
  change never reached a builder.
- **The rival bots' hip checks a minute** (v0.1.24 as promoted, plus the shared drawing/counting, `.tl/s4/gen_hip2`, the
  blind hand, 3600 frames, seeds 1-3 twice):

  | | value |
  |---|---|
  | hip checks a minute | **0 / 0 / 0** (no sidecar, so the plain core, where bots never hold one) |
  | dives | 0 |
  | script errors | 0 |
  | run hash, twice each | 2789a91a / 626117b3 / e8b054bd |
  | core hash, twice each | 980486f9 / 5499fbbe / ea941d5c |

  For comparison, round 1's builder values written by hand gave 5 / 4 / 5 hip checks a minute.
- **Answer to the round's question: not yet.** The sidecar path works when the cartridge change goes to a builder, but this
  sentence went down the quick diff. That path cannot see the sidecar, and its "a builder needs to add both" was not carried
  to a builder.
- **Blocked-editor for lane T** (job s4a2-arsenal, events 1076, 1080, 1081, 1090, 1131). Two fixes would close it:
  1. When a person's change asks for a bot behaviour or a new verb that only a rules switch says, the quick diff should
     either include the rules sidecar (`ruleSwitches()` already lists the keys and their ranges) or hand the remainder to the
     cartridge builder, which item 7 now lets write the file.
  2. The diff's own "a builder needs to add ..." should open that builder round instead of promoting.
