# S2-juice spike: a standard juice pass for every new ability, automatic (A) or a choice in Create (B)

Juice day, 27 Nov 2026, 08:05-11:xx. Lane S2-juice (Opus).
- Arm A: tree `d25-robot`, branch d27-sp-juice.
- Arm B: tree `d27-sp-juice-b`, branch d27-sp-juice-b.
- Both arms start from main 8be26d61.

## 1. The question (the owner's words, ask 2 of last night's verdict)

> "Juice a sentence does not name: should the editor add a standard juice pass to every new ability (a wind-up tell,
> an impact word, a camera kick, a slow beat)? Or should Create offer it as a card choice ('make it juicy')?"

## 2. The two arms

Both arms share one pass, `foreman/prompts/juice_pass.md`, byte for byte (see `JUICE-PASS.md`). It writes down last
night's hand layers as builder text:
- size the move first (small, big or signature); a small move gets a small pass;
- a tell that grows;
- exaggeration in numbers;
- hit-stop, a camera kick and a lens kick, and a camera that follows a launched player;
- an impact word at the hit;
- particles and sound;
- a slow beat on the signature moment only;
- the world answering.

Guards are written into the pass:
- exaggerate the arc, not the rules: time out of play at most +25 %, matches at most +10 %;
- drawing never touches the state hash;
- the pass's numbers go into the tuning data;
- the builder ends with a `JUICE:` checklist line.

The two arms differ in exactly one line of `foreman/src/juicepass.ts`, `JUICE_MODE`, plus their Create parts.

- **A, automatic (`JUICE_MODE = "auto"`).**
  - Every person's change that ADDS a move runs the pass: a play change with "give / add / let ...", a move word and a
    key, or "give every X a ...".
  - "keep it plain" or "no juice" turns it off.
  - A change to the rules of a move the game already has never runs it, and neither does a look, view or fairness
    change.
  - The Foreman logs "[foreman] juice pass: your change adds a move ... Say 'keep it plain' to leave it out", and
    Create's done screen shows that line under the change box (`stills/A-create-done-note.jpg`). The person types
    nothing new.
- **B, a choice (`JUICE_MODE = "choice"`).** The pass runs only when the person's words say "make it juicy". Create
  writes those words for them:
  - **The card:** a "Make it juicy" card on the change row, off until picked. Picked, it turns honey with a check, a
    line under it says what it adds, and the change is sent with " Make it juicy." at its end
    (`stills/B-create-card-picked.jpg`).
  - **The follow-up:** a change that adds a move and was built plain gets the Foreman's note "[foreman] juice pass
    offered". The done screen then shows a "Juice that move" button beside Play. One click sends `Make it juicy: the
    move I just added ("<the change>"). Keep its rules as they are.` (`stills/B-create-followup.jpg`).

Code per arm (the Director commits each on its branch):

| | arm A | arm B |
|---|---|---|
| shared, identical | `foreman/prompts/juice_pass.md` (new); `foreman/src/juicepass.ts` (new, 79 lines, `JUICE_MODE` apart); `foreman/src/test/juicepass.test.ts` (new, 5 tests); `foreman/src/foreman.ts` (+2 lines, 2004 of its 2005 ratchet); `foreman/src/boundlift.ts` (+2: the pass's words count as asked for, for the rows that measure hit-stop, launch and tell); `engine/ui/create/create_model.gd` (+23: `juice_of`, `juicy_follow_up`) | same |
| Create | `create_build.gd` +4 (the done-screen note) | `create_build.gd` +20 (card, follow-up, `juicy` pick; 599 of 600 lines) |
| selftest block 812 | `engine/tools/selftest.d/812-create-juice.sh` + `engine/ui/create/create_juice_case.gd(.uid)`: create.juice.note, create.juice.plain | same files, B's own checks: create.juice.card, create.juice.follow, create.juice.none |

## 3. The test

- **Robots.** Base: the job `robot-soccer-3-v-20261125-1` set back honestly to **v0.1.5**, on a copy. Foreman has no
  rollback command, so I did it by hand on the copy (`d25-robot/.tl/spike/rollback_robot_v015.py`, kept with the cut
  parts in `.tl/spike-base/robot-v015/...cut`):
  - the log was cut after event 929 (the v0.1.5 promotion and its `job_state done`, 25 Nov 17:21 UTC), before J2's
    hammer change (event 930);
  - `pack/` is `promoted/game.robot_soccer_3_v@0.1.5` byte for byte;
  - `promoted@0.1.6` was moved aside;
  - `ws/` was emptied. The Foreman re-cuts each workspace from `pack/` (`ensureWs`), because last night's `ws/core`
    still held the discarded r13-r15 hammer;
  - reports and captures newer than event 930 were moved aside;
  - `foreman status` then reads v0.1.5, core round 12, 26.69M tokens: the job's figures before J2's first sentence.

  The sentence is J2's exact promoted hammer sentence, round 2, 240 characters:
  > Give every robot a double-headed sledgehammer: hold F to charge, release to swing. The longer I charge, the higher
  > and farther the hit robot flies, tumbling, with sparks, a clang. It drives the ball. Misses leave me open. Bots
  > swing, dodge.
- **Shield wall.** Base: `shield-wall-3-v-20261125-1` **v0.1.7** (copied from d25-shield at 08:09). The sentence is a
  new crazy ability, a Captain America shield throw. It names behaviour only, and no juice:
  > Give every fighter a shield throw on G: he hurls his shield straight ahead like a discus. It knocks down the first
  > rival it hits, ricochets to the next rival within a few metres, knocks him down too, and flies back to his hand.
  > Until it comes back he cannot guard, so he is open. A raised shield stops it: it bounces off and drops to the
  > ground, and he has to run and pick it up. The rivals throw theirs at me too, and raise their shields when one flies
  > at them.
- **Runs.** One copy per run, each copied from the same base copy. All six were sent 08:34-08:42 and ran in parallel
  under the same machine load. Each used real.json's change flags (claude-cli, Sonnet builders, round limit 4).
  - A: the sentence as typed.
  - B-juicy: the sentence plus " Make it juicy." (what the card sends).
  - B-plain: the sentence as typed, with no pass, to show B stays plain. This is also the spike's control.
- **The same measures for every pack:**
  - headless, seeds 1 (twice), 2 and 3, one match-minute each:
    - robots: `tests/bot_hammer_measure.gd`. This is J2's `bot_hammer_hand` (TLHand "regular", which swings at a
      carrier in reach) with one change: a swing is counted at its hit or miss event, because the plain build sends no
      `hammer_swing`;
    - shield: `tests/bot_throw_hand.gd`, J19's captain hand pressing G when a rival stands 3-7 m ahead;
  - the same window film for each arm: the same seed and frames, cut the same way;
  - references, measured with the same robot test: last night's editor v0.1.6 (`proof-games/robot_v016_hammer`) and
    the hand version (`proof-games/robot_hammer_hand`). Their seed-1 hashes, `4f771e45...` and `ac3f913b...`, are the
    ones J2 recorded, so the measure reproduces last night's.

## 4. Results, A against B

### Cost of the change (job log; wall time from the sentence to promotion, under the same parallel load)

| | robots A (pass) | robots B-juicy (pass) | robots B-plain | shield A (pass) | shield B-juicy (pass) | shield B-plain |
|---|---|---|---|---|---|---|
| promoted | v0.1.6 | v0.1.6 | v0.1.6 | v0.1.8 | v0.1.8 | v0.1.8 |
| builder rounds | core r13 | core r13 + show r2 (end-card answer) | core r13 | core r17 | core r17 | core r17 |
| wall time | 84 min | 96 min | 74 min | 66 min | 65 min | 64 min |
| tokens in / out | 2.47M / 24k | 3.29M / 31k | 1.69M / 20k | 1.97M / 25k | 2.89M / 26k | 2.16M / 20k |
| pack lines vs base | +254 -23 (8 files) | +333 -23 (9 files) | +155 -8 (8 files) | +255 -10 (8 files) | +271 -11 (8 files) | +179 -11 (9 files) |
| refusals, questions | none | none | none | none | none | none |
| Foreman's balance notes | matches 1.1x longer (39160 f for 3 matches) | skill_spread 0.21 (was 0.69) | tells 2 (was 3); matches 1.1x longer (40599 f) | gulls win 2 of 3 (was 1 of 3) | none | none |
| final verification | passed (bot_tofu with 3x frames) | passed | passed (bot_tofu with 3x frames) | passed | passed | passed |

The pass's cost over the plain run:
- robots: +0.8M tokens and +10 min (A), +1.6M and +21 min (B-juicy, which includes one extra show round);
- shield: -0.2M and +2 min (A), +0.7M and +1 min (B-juicy).

Builder variance between runs is about as large as the pass. Wall times are long for every run because six jobs and
another session's lanes shared a CPU at 100 %.

### What a person sees: the juice checklist

Sources: each builder's `JUICE:` line, its code (grep) and the films I looked at.

**Robots: hammer**

| part | A | B-juicy | B-plain | editor v0.1.6 (night) | by hand (night) |
|---|---|---|---|---|---|
| tell that grows | yes: head heats in 4 steps, throbbing reach ring, rising whine | yes: the same, the head grows | no glow, no ring | no | yes: red-to-white head, reach ring |
| exaggeration: hit robot's highest point (measured, m) | 2.8-3.4 (28 f in the air, the slide's) | **4.4-4.6** (42-58 f in the air) | 1.9-2.5 | 2.0-3.6 | 3.7-5.4 |
| hit-stop | 5-9 f | 5-9 f | (none named) | 6-9 f | 5-9 f |
| camera | shake 0.25-0.45 + lens kick 8 deg; no follow when launched | shake + lens kick 5-9 deg + **follows you up** | shake | shake | shake + lens kick + follows you up |
| impact word | BONK! / KA-BONK!! | BONK! / CLANG! / KA-BONK!! | none | none | BONK! / KA-BONK!! |
| particles and sound | sparks, dust, debris, clangs | the same | sparks, dust, clangs (asked) | sparks, clang | the same + a crash |
| slow beat | full-charge hit on you: sim at half rate 24 f, every 300 f at most, no close-in | the same + lens closes 6 deg | none | none | none |
| world answers | tumble, ball driven, skittles | the same | tumble, ball driven | the same | + wall bounces |
| bots' swings a minute, seeds 1/2/3 (all five) | 12 / 18 / 14 (mostly misses: 14 of 17 on seed 1) | 4 / 4 / 2 | 0 / 3 / 4 | 6 / 4 / 5 | 7 / 7 / 5 |
| frames down after a hit | 85-111 | 83-87 | 84-108 | 98-113 | 103-138 |

**Shield wall: shield throw (no hand version exists for a throw)**

| part | A | B-juicy | B-plain |
|---|---|---|---|
| tell | the shield heats in 3 spark steps, a rising whirr, a red ring sliding out along the line | red lane rings growing in 4 steps, rising beeps, warming sparks, a swing trail | none |
| exaggeration | no: the victim is pushed 1.4 m, with no launch | small: the disc spins, no launch | no |
| hit-stop | 7 f, both bodies | 8 f, both bodies and the disc | 10 f |
| camera | shake 0.25 / 0.35 (ricochet) + lens kick 5 / 8 deg | shake 0.3 + lens kick 7 deg | shake 0.1 |
| impact word | BONK! / KA-BONK!! | BONK! / KA-BONK!! / CLANG! | none |
| particles and sound | sparks, dust on the ricochet, thud, clang, catch | sparks, dust, a second burst, whoosh, clang, catch | dust, sounds |
| slow beat | no ("not done") | no (sized BIG, not signature) | no |
| world answers | small | yes: bowled over, the blocked shield drops | falls |
| bots throw a minute, seeds 1/2/3 | 6 / 3 / 6 (Pip, Bram, Sable, Finn) | 0 / 0 / 0 | 0 / 1 / 0 |
| throw knockdowns (all, seeds 1/2/3) | 5 / 2 / 5 | 0 / 4 / 3 | 2 / 3 / 2 |

The bots' throws are not the pass. In shield A the builder added a rule that makes every mind throw and brace (its
`RULE:` line). B's builders left the crew's minds alone: another package owns them, the same J19 finding that lane T
fixes today. In robots A the bots swing 2-3 times as often as anywhere else, and miss far more often. That is the
builder's bot rule ("they check every 20 frames"), and the pass says nothing about bots.

### Headless (3600 frames, 0 script errors, the same hash twice on seed 1)

| pack | seed 1 hash (run 1 = run 2) | script errors, seeds 1, 1, 2, 3 |
|---|---|---|
| robots A | `09136eff24309ce1` | 0, 0, 0, 0 |
| robots B-juicy | `93d5dbff92f3e144` | 0, 0, 0, 0 |
| robots B-plain | `1ac790b9e31d585c` | 0, 0, 0, 0 |
| robots editor v0.1.6 (reference) | `4f771e4556bf4a3d` (= J2's) | 0, 0, 0, 0 |
| robots by hand (reference) | `ac3f913b63d011cd` (= J2's) | 0, 0, 0, 0 |
| shield A | `f7d3732b9f080d53` | 0, 0, 0, 0 |
| shield B-juicy | `e967495b931e9dac` | 0, 0, 0, 0 |
| shield B-plain | `eeb12cca56634f44` | 0, 0, 0, 0 |

Every promoted pack also passed the Foreman's whole final verification: lint, smoke, invariants, every pack bot, and
the card's hand checks over 20 seeds.

### By eye (films in `clips/`, stills in `stills/`, all looked at)

Clips (each 30 s or shorter; the same seed, frames and hand in every panel):
- `clips/robot-hammer-A-Bjuicy-Bplain-s1.mp4` (29 s, seed 1, frames 60-1800);
- `clips/robot-hammer-5up-s1.mp4` (29 s): the same three on top, and last night's editor v0.1.6 and the hand version
  below, played by the same hand;
- `clips/shield-throw-A-Bjuicy-Bplain-s3.mp4` (11 s, seed 3, frames 1200-1860: the captain's throw at frame 1321 that
  ricochets and floors two).

Stills:
- `robot-hammer-side-by-side-windup.jpg`: the wind-up, the same frame in all three.
  - **A:** a big red reach ring lies on the court around me.
  - **B-juicy:** the hammer is up over the head, its head a big glowing yellow-hot block.
  - **B-plain:** the hammer hangs low at my side, and nothing tells the rival what is coming.
- `robot-hammer-side-by-side-hit.jpg`: the same hit, 33 frames later.
  - **A:** "BONK!" at the spot, and the blue robot flies back to the goal mouth about two body heights up.
  - **B-juicy:** "BONK!" and the highest flight of the three: the blue robot spins above the crossbar.
  - **B-plain:** the robot is thrown back lower, with a few sparks and no word.
- `shield-throw-side-by-side-f1350.jpg` and `-f1377.jpg`: the throw and the ricochet.
  - A and B-juicy put "BONK!" over the first man down and a spark burst at the hit.
  - B-plain shows a grey dust puff and nothing else.
  - The B-juicy and B-plain scenes match frame for frame up to the throw: the same base, seed and hand. A's scene
    differs, because its builder also gave every mind a throw.
- `robot-hammer-5up-hit.jpg`: the same hit in all five. The night's editor v0.1.6 throws the robot lowest, with no word. The hand version's BONK! sits low by the ball.
- Sheets made from the clips (`.tl/spike/stills/`, looked at, not copied):
  - robots A: the opening hit, and a bot's BONK on my mate (the mate goes up upside down, filling the lens);
  - robots B-juicy and B-plain: the opening hit;
  - shield A, B-juicy and B-plain: the throw.
- Create:
  - `B-create-card-picked.jpg`: the card picked, with its line under the change row;
  - `B-create-followup.jpg`: "Juice that move" beside Play, on the real robots B-plain job, after the Foreman's offer
    note;
  - `A-create-done-note.jpg`: A's done screen line, on the real robots A job.

**As a person:**
- **Robots, B-juicy** is the one I would show. Its glowing raised head and its high, spinning flight are close to the
  hand version (4.4-4.6 m against 3.7-5.4 m), and the camera follows you when you are the one launched.
- **Robots, A** reads clearly: the ring, BONK!, the lens kick. Its flight is the slide's half second, and its bots
  flail. Hammers go up every few seconds, and most of them miss.
- **Robots, B-plain** is last night's editor again: a stronger tackle with a hammer drawn on.
- **Shield wall:** both pass runs turn a dusty shove into a readable hit, with a ring that shows the line, a word and
  sparks. Neither got the launch or the slow beat, so the throw is juicier but not yet crazy. The plain throw is hard
  to see happen at all.

## 5. What each arm broke, or risks

- **Neither arm broke a test.**
  - Every final verification passed.
  - Fast tier 5/5 in both trees.
  - foreman npm: A 465 / 458 pass / 0 fail / 7 skipped. B 465 / 457 / 1 / 7. B's one fail is `cli: kill the Foreman
    mid-run, then resume`, a kill-timing test: it passed 10/10 when run again alone, and A has the same code.
  - create.: A 31/0, B 32/0 (29 existing + block 812). The first run of each had `create.pause.path` stop after 7
    steps at CPU 100 %; the reruns passed.
- **The pass does not make matches slower here.** Robots A needed 39160 frames for the Foreman's 3 test matches and
  plain needed 40599: the hammer lengthens matches, the pass does not. The shield runs gave no frame note.
- **The pass makes the editor's output bigger and costs tokens.** It adds 60-180 lines of drawing per ability. Tokens
  run -9 % to +95 % over plain, inside builder variance on shield and clearly above it on robots.
- **It is not always obeyed.**
  - Shield A and B-juicy skipped the launch exaggeration and the slow beat: "sized BIG, not signature"; "not done".
  - Robots A kept the slide's 28-frame flight and gave no camera follow.
  - The pass's `JUICE:` line says honestly what was left out.
- **Arm A's risk is the detector.**
  - Audit over every real change sentence in every tree's job logs (65 sentences): the pass would run on 9. All 9 are
    the new moves of the last two nights (karts jump, loop, dunk, block, hammer x2, ground-pound, shield moves,
    meteor). Look, camera, teammate, ball, fairness and text changes never run it (`.tl/spike/audit.txt`).
  - Misses: a change that reworks an existing move ("make the barrel roll a real Star Fox roll") or adds a state with no
    key ("add NBA Jam's on fire") does not run it.
  - A person who wants none must know to say "keep it plain". The done screen tells them only after the fact.
  - I tightened the detector at 09:15, after the six jobs had started. The first version would also have run the pass
    on two Arsenal rule changes. Both versions give the same answer on this spike's two sentences (checked).
- **Arm B's risks are discoverability and two similar buttons.**
  - A person who never picks the card gets last night's editor output.
  - The follow-up costs a second full change: about 1 hour and 2M tokens at today's pace. It was not run today: shown
    in the window and by selftest, not run as a real job.
  - The card and the follow-up sit on one screen ("Make it juicy" for the next change, "Juice that move" for the last
    one).
- **Seen in passing:**
  - The orange balance note on the done screen wraps under the Play row; this is not from this spike.
  - Robots B-juicy's what-changed card says "the same as the list in my previous message" because its builder wrote
    DEVIATIONS that way; this is not from this spike.
  - In shield A, "KA-BONK!!" is cut off at the screen's left edge when the victim stands at the edge.

## 6. How to play each arm

Pack paths and menu titles for the Director's rows:

| menu title | pack |
|---|---|
| Robot soccer: sledgehammer (S2 A, juice pass automatic) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-robot/.tl/jobs-a/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.6` |
| Robot soccer: sledgehammer (S2 B, "make it juicy" picked) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-juice-b/.tl/jobs/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.6` |
| Robot soccer: sledgehammer (S2 B, plain) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-juice-b/.tl/jobs-plain/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.6` |
| Shield wall: shield throw (S2 A, juice pass automatic) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-robot/.tl/jobs-a/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.8` |
| Shield wall: shield throw (S2 B, "make it juicy" picked) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-juice-b/.tl/jobs/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.8` |
| Shield wall: shield throw (S2 B, plain) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-juice-b/.tl/jobs-plain/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.8` |

The six share two pack ids (`game.robot_soccer_3_v`, `game.shield_wall_3_v`) with the night's rows. If the menu needs
distinct ids, copy them as the night did for the hand packs.

Keys:
- robots: F, hold to charge and let go to swing (only without the ball in A and B-juicy);
- shield wall: G to throw (F charge, C slam, Q call, as before).

To feel the difference:
- hold F a full second near a blue carrier, and let a blue bot hit you;
- in shield wall, throw at two Gulls standing close together.

Create:
- arm B's Create runs from the B tree (`bash engine/tools/ui.sh` there). The card and the follow-up show on any done
  screen;
- arm A's note shows on the done screen of a job the pass ran on.

## After round 2 (27 Nov, 15:45-18:10): main's editor, the Foreman's juice check, the hammer again

**What changed under both arms**
- Both branches now carry main's editor, with lane T's items 1-22 merged by the Director (A eeecbf42, B d27-sp-juice-b).
  Among them, a rivals' sentence now reaches the bot package too: `brain` builds the bots' part.
- **A3 / B3 (57ddcf32 / 06b80f0b), the same in both arms: the Foreman reads the builder's `JUICE:` line.**
  - After the merge of a change round the pass ran on, a big move whose line says it skipped the launch, the slow
    beat or the camera follow gets one more round for the same package, with the pass. This happens once per change.
  - The pass text now says every big move has a biggest moment, so it gets all three.
  - Code: `juicepass.ts` (juiceGaps, juiceMore) and `halfmade.ts` afterMerge (+2 lines); tests juice 6-7 use round
    1's real lines.
  - On round 1's lines it would have sent robots A back for the launch and the camera follow, and both shield runs
    back for the launch and the slow beat.
- B's Create split: the card and the follow-up moved into `create_juice.gd`, so `create_build.gd` is at its
  600-line budget. Behaviour is unchanged (create. 32/0).

**The test.** J2's exact hammer sentence again:
- each on a fresh copy of the v0.1.5 base (the same rolled-back copy as round 1);
- A as typed, B with " Make it juicy." (the card);
- run together at 16:17, on a lighter machine than round 1.

**Results**

| | round 2 A (auto pass + check) | round 2 B (juicy picked + check) | by hand (night) | round 1 B plain (no pass) |
|---|---|---|---|---|
| promoted | v0.1.6, 41 min | v0.1.6, 31 min | - | v0.1.6, 74 min (loaded machine) |
| rounds | core r13, brain r4, show r2 (end card) | core r13, brain r4 | - | core r13 |
| tokens in / out | 4.26M / 47k | 3.44M / 28k | - | 1.69M / 20k |
| pack lines vs v0.1.5 | +359 -26 (14 files) | +218 -5 (11 files) | - | +155 -8 |
| the builder's `JUICE:` line | all yes; world answers small | tell small (pose only); exaggeration "yes (height and spin; flight time no)"; camera small (shake only); word no; slow beat yes | - | - |
| did the check send a round? | no: nothing big skipped | **no: it could not see the line** (see below) | - | - |
| tell | head heats, a reach ring, rising whine (ring small and orange in the film) | raised-hammer pose only | big red reach ring, red-to-white head | none |
| how high a hit robot flies (m, seeds 1/2/3) | **4.7-5.3 / 4.6-4.8 / 4.6** | 1.8-2.3 / 1.9-2.3 / 0.4-2.2 (*) | 3.7-5.4 | 1.9-2.5 |
| frames down after a hit | 100-110 | (*) about 26 in the air | 103-138 | 84-108 |
| camera | shake + lens kick + rises with you | shake only | shake + lens kick + follows you | shake |
| impact word | BONK! / KA-BONK!! (a centre label) | none | BONK! / KA-BONK!! | none |
| slow beat | full charge on you: half rate for 24 f | the same | none | none |
| bots' swings a minute (seeds 1/2/3) | 5 / 6 / 3 | 21 / 18 / 27 (*) | 7 / 7 / 5 | 0 / 3 / 4 |
| Foreman's balance notes | matches 1.2x longer; a newcomer wins 10 of 20 (was 17); timing spread 1 (was 0.69) | warned rival attacks 2 (was 3) | - | tells 2 (was 3); matches 1.1x |
| headless: seed 1 hash twice, errors in seeds 1, 1, 2, 3 | `bcc03b43ec7d4ccc` twice; 0, 0, 0, 0 | `91ee8d8915159de0` twice; 0, 0, 0, 0 | `ac3f913b63d011cd` | `1ac790b9e31d585c` |

(*) Robots B2 publishes no hammer events. Its `hammer.tick` emits them before `sim.step`, which clears the event list
at its start. So B2 is measured with `tests/bot_hammer_state.gd`:
- a swing is counted when a robot enters `hammer_swing`;
- a flight is the peak of a robot that leaves the ground within 30 frames of a rival's swing and is knocked down;
- on the hand pack this gives the same peaks as the event measure (4.0, 5.4, 3.7 m);
- a swing state that lasts several frames may be counted on more than one swing start, so B2's swing counts are high,
  not exact.

**Why the check missed B2.**
- B2's builder ended its last answer with "Unchanged from my previous answer". The Foreman's note holds only the last
  answer, so it had no `JUICE:` line to read.
- The real line was in an earlier message of the transcript. It says exactly what B2 lacks: no word, shake only,
  flight time no.
- I fixed this in both trees (A4 / B4, not committed; tests juice 8):
  - the pass now asks for the line in the LAST answer, repeated even if it was given before;
  - "flight time no", "no flight", "camera small" and "shake only" count as skipped;
  - a pass round with no line in its last answer gets a "[foreman] juice pass not checked" note, so nobody believes it
    was checked.
  - the check now runs after the rest of a half-made change is handed on (`afterMerge` wraps `mergeRest`), so the
    Foreman's hand-off notes still come first (lane T's test D27 2 reads the first note).
  - On B2's real line the fixed check sends one more round, for the launch and the camera follow.
- The B2 job was not re-run with the fix.

**By eye** (`clips/r2-robot-hammer-A2-B2-hand-plain-s1.mp4`, 800 x 452, crf 32, 29 s, the same seed and hand in all
four; stills `stills/r2-robot-hammer-t0.02.jpg` (the wind-up) and `-t0.55.jpg` (the hit), looked at):
- **Round 2 A** now matches the hand version on the numbers: flights of 4.6-5.3 m and about 100 frames down, and its
  bots swing 3-6 times a minute.
  - In the window the hit robot sails up past the goal and "BONK!" shows.
  - Its wind-up tell is smaller than the hand's: a small orange ring, against the hand's big red reach ring.
- **Round 2 B** looks like round 1's plain build with a slow beat: the hammer hangs low with no tell, the hit robot
  goes up about 2 m, and no word shows.

**What round 2 says about the question**
- The pass is not reliably obeyed: one of two runs did everything, the other about half. The difference is the
  builder, not the arm.
- The Foreman's check turns that into a second round only when the builder reports honestly in its last answer. With
  B4/A4 a missing report is at least visible.
- None of this depends on WHEN the pass runs (A or B). The A/B question is unchanged; round 2 is about making the pass
  stick once it runs.

**To play round 2** (menu rows for the Director):

| menu title | pack |
|---|---|
| Robot soccer: sledgehammer (S2 round 2 A, auto pass + check) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-robot/.tl/jobs-a2/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.6` |
| Robot soccer: sledgehammer (S2 round 2 B, juicy picked + check) | `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-juice-b/.tl/jobs2/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.6` |

## Lane's recommendation

**A, the automatic pass, with B's buttons turned round.**

Why:
- Last night's finding was that the juice is exactly what the person does not think to say. A choice the person must
  know to pick leaves the default where the editor already fails: robots B-plain and shield B-plain are last night's
  "stronger tackle", and the follow-up costs a second full change, about 1 hour and 2M tokens.
- When the pass runs, it moves every game toward the hand version: the tell, the word, the hit-stop and camera kick in
  all four pass runs, and hand-level flight in robots B-juicy. It breaks nothing: no test, no refusal, no slower
  matches. It costs about what builder variance costs: +0 to +1.6M tokens, 1 to 21 min.
- A's detector picked exactly the 9 new moves among the 65 real sentences. A look, camera, rules or fairness change
  never pays for it.

What I would add before landing A:
- a "Keep it plain" card on the change row, in place of B's "Make it juicy" card (the same code, turned round);
- a one-click "make it plain" follow-up on the done screen, for a person who did not want the noise;
- a Foreman check that reads the builder's `JUICE:` line and sends one more round when the big parts (launch, slow
  beat, camera follow) are "no" on a move sized big. Shield's two pass runs skipped both, and robots A skipped the
  flight and the follow.

What would change my pick:
- if the owner wants the editor to build exactly the words (a person who writes "plain" juice should get plain juice),
  B is the honest one. Its card and follow-up work and cost nothing until they are used.

**After round 2:** still A. Round 2 A is the first editor-made hammer that matches the hand version's numbers, made
from one sentence with no person's second sentence. B's card produced a thin build that the check could not catch,
because the builder did not repeat its report. Land A4/B4 (the report in the last answer, the broader skipped words,
the "not checked" note) with whichever arm the owner picks.

