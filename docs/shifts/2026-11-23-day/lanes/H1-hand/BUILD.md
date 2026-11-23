# H1 build 1: the behaviour sheet built into the house hockey (23 Nov, day)

Branch `n23-teardown` (worktree `.claude/worktrees/n23-teardown`), on main a9f7477 + the round-2 merge f1659f1. The sheet is
`docs/research/hockey-teardown/BEHAVIOUR-HAND.md` section 4. Built: section 4.1 (rows S1-S17, S19) and route A (4.2, rows
A2-A4). Not built: route B (waits for the owner), S18 (withdrawn: see "Found while building" 5), A5 (it is `data/ai.json`:
"For H2" below). **No kernel change**: every row is pack data or pack code, so no other pack's hash moves and the world step
is untouched. Proof below is our own instruments, run on the pack before (main) and after (this branch), headless, plus one
window run.

## What changed, by row

| row | what | file : key, before -> after | kind |
|---|---|---|---|
| S1 | the check winds up 8 frames; its clip is timed so the clip's hit frame (12) lands on frame 8 | `data/tuning.json` `hits.check_windup` 12 -> 8; `scripts/hits.gd` `_clip` (play_clip timing), `BODY_CHECK_HIT` | data + pack code |
| S1 | (found) the check's pull is counted in the "meeting inside the wind-up" test, so a drawn attacker never runs into his man before the hit resolves | `scripts/hits.gd` `_step_windup` | pack code |
| S2 | no recovery after a check that lands | `hits.check_cooldown_frames` 40 -> 0 | data |
| S3 | after a whiffed check the same press works when the window closes (frame 21) | `hits.whiff_cooldown_frames` 20 -> 12 | data |
| S4 | the cross-check winds up 8 frames (the clip timed to it) | `hits.cross_windup` 10 -> 8; `cross_clip_hit` stays 10 (it is the clip's own frame) | data + pack code |
| S5 | the cross-check works again after 30 frames | `hits.cross_cooldown_frames` 45 -> 30 | data |
| S6 | a man met inside the cross-check's wind-up takes it at the meeting, on the velocities before contact; the man is chosen where the wind-up will bring him | `scripts/hits.gd` `_step_swing`, `try_cross` | pack code |
| S7 | the cross-check's stick takes an opposing carrier's puck at the press within 1.0 m of his body, inside the stick's cone, not through his back; the puck comes off toward the presser | new `scripts/contact.gd` `strip_at_press`; `data/tuning.json` new `contact.cross_strip_gap` 1.0 | pack code + data |
| S8 | two skaters on their feet who meet without a hit exchange speed (restitution 0.2, each man's brace as effective mass) instead of stopping dead | `scripts/contact.gd` `bounce_bodies`, called from `scripts/main.gd` after `hits.enforce()`; `contact.bounce` true, `bounce_min` 1.0 m/s | pack code + data |
| S9 | the victim's keys come back at thirdjam's frame: down time shortened by the kernel's 24-frame rise | `hits.down_frames_min` 60 -> 36, `down_frames_max` 150 -> 126 | data |
| S10 | no whole-game freeze on hits | `fun.stop` true -> false | data |
| S11 | a poke in reach always takes from the front or the side, never through his back; no chance after a cut | `carry.poke_chance` 0.65 -> 1.0, `poke_side` 0.7 -> 1.0, `poke_back` 0.4 -> 0, `poke_cut_mult` 0.6 -> 1.0 | data |
| S12 | the poke is live from the press for 8 frames | `carry.poke_first` 6 -> 0, `poke_last` 12 -> 7, `poke_frames` 24 -> 8 | data |
| S13 | the poke works again 14 frames after a take; a miss locks the stick 20 frames, no turning penalty | `carry.poke_cooldown_frames` 40 -> 14, `whiff_frames` 15 -> 20, `whiff_turn_mult` 0.5 -> 1.0; `scripts/poke.gd` (a miss sets the ready frame) | data + pack code |
| S14 | the poked puck is the poker's at once (thirdjam: it rolls to his blade) | `scripts/poke.gd`; keys `poke_speed`, `poke_carry_share` removed (unused) | pack code |
| S15 | the carrier is 0.80 of a free skater | `carry.carry_speed_scale` 1.012 -> 0.92 | data |
| S16 | the carrier sprints x1.08, capped as thirdjam's | `skate.sprint_carry_bonus` 0.15 -> 0.08, `carrier_sprint_cap` 1.012 -> 0.97 | data |
| S17 | turning 5 rad/s | `skater.skate_turn_rate` 4.5 -> 5.0 | data |
| A2 | thirdjam's build-up in frames (90 % of top in 34 frames) | `skater.skate_accel` 13 -> 8.73 | data |
| A3 | thirdjam's stop in frames (still in 29 frames from top) | `skate.reverse_decel` 26 -> **13** (the sheet's 18.9 measured 23 frames: our kernel's sideways grip takes speed during the turn as well; 13 was measured to give 29) | data |
| A4 | the hit law's speeds x 9.2 / 12.65 | `hits.stability_speed` 6.0 -> 4.36, `lunge_speed` 1.5 -> 1.09, `cross_thrust` 3.0 -> 2.18, `stand_speed` 1.0 -> 0.73, `behind_match` 3.0 -> 2.18 | data |
| (found) | the pass magnet bends only a pass heading at the receiver (within 45 degrees) | `scripts/carry.gd` `flight` | pack code |

`scripts/hits.gd` stays at its 600-line budget (599); the two new laws live in `scripts/contact.gd` (88 lines). The pack
README's rule lines for the poke, the hit-stop, the check and the cross-check are updated.

## Proof: sheet target / before / after / thirdjam

Instruments: `probes/hand_step.gd` + `hand_measure.mjs` (movement), `hand_hits.mjs` (hits, pokes), `hand_carry.mjs` and
`hand_match.gd` (24 ladder matches), the same as rounds 1 and 2. Before = main's pack (`.tl/h1/hockey`, round-2 runs); after
= this branch (`.tl/h1/hockey_after`). thirdjam = its law and its build's tests (round 1 and 2). Route A's targets are
thirdjam's in frames and in shares of the rink (60 m against 90 m).

| row | quantity | target | before | after | thirdjam |
|---|---|---|---|---|---|
| A2 | free: frames to 50 % / 90 % of top | 16 / 34 | 11 / 19 | **16 / 34** | 16 / 34 |
| A2 | free: metres to 90 % (share of the rink) | 2.5 m (0.042) | 1.41 (0.024) | 2.73 (0.046) | 3.8 (0.042) |
| A2 | sprint from rest: frames to 90 % | 33 | 19 | **34** | 33 |
| A2 | tap 6 frames: metres in the next second (share) | 1.7 m (0.028) | 2.76 (0.046) | 1.82 (0.030) | 2.54 (0.028) |
| A3 | stick reversed at top: frames to still | 29 | 19 | **29** | 29-30 |
| A3 | ... metres to still (share) | 2.2 m (0.033) | 1.39 (0.023) | 2.15 (0.036) | 2.97 (0.033) |
| A3 | ... frames to 90 % of top the other way | 61 | 46 | 65 | 61 |
| S17 | stick 90 degrees: frames until he faces / travels the new way | 19 / 50 | 21 / 53 | **19 / 49** | 19 / 50 |
| S17 | ... peak speed in the turn | +14 % | +27 % | **+14 %** | +14 % |
| S15 | carrier top, share of a free skater's | 0.80 | 0.88 | **0.80** (7.36 m/s) | 0.80 |
| S16 | carrier sprint, share of a free sprinter's | 0.75 | 0.88 | **0.75** (7.95 m/s) | 0.75 |
| A2+S15 | carrier: frames to 90 % of his top | 34 | 21 | 35 | 34 |
| S1 | check pressed 0.45 m from a standing man at 9 m/s: contact frame | at the meeting | 2 | 2 | 3 |
| S1+S3 | whiffed check: the press works again at frame | 21 | 33 | **21** | 21 (8 + 12, code) |
| S2 | landed check: the press works again at frame | at once | 42 | **2** | at once (code) |
| S4+S6 | cross-check timed from 1.5 m at 9 m/s: contact frame, outcome | 9, down | 12, stumble 0.50 (the bodies had collided first) | **9, down 2.56** | 9 (code), down (`JAMBRACE`) |
| S6 | cross-check pressed late, 0.45 m from him at 9 m/s | lands at the meeting | frame 11, stumble 0.50 | **frame 2, down 2.56** | not measured |
| S7 | cross-check on a carrier's side from 0.45 m: the puck | off him at the press | his until the swing landed (frame 11), then b0's | **loose at frame 1** | loose toward the presser at the press (code) |
| S8 | skate into a standing man at 9 m/s, no press: he leaves at / you keep (front) | 4.32 / 2.52 | 0 / 0 | **4.32 / 2.52** | 4.32 / 2.52 |
| S8 | ... into his side | 1.80 / 0 | 0 / 0 | **1.80 / 0** | 1.80 / 0.00 |
| S8 | ... into his back | 5.39 / 3.60 | 0 / 0 | **5.40 / 3.60** | 5.39 / 3.60 |
| S9+S10 | YOU hit from the front at 9 m/s: your keys move you at frame | 87 (thirdjam at our scale) | 104 | **88** | 70 at 9 m/s, 87 at the same share of top (12.4 m/s) |
| S10 | whole-game freeze on a 9 m/s check | 0 | 8 frames | **0** | 0 (a 3-frame picture hold) |
| S11-S14 | poke at a standing carrier from the front: takes, frame, the puck to | all, frame 1, the poker | 14 of 20, frame 7, loose | **20 of 20, frame 1, b0** | all, frames 1-8, the poker |
| S11-S14 | ... from his side | all, frame 1, the poker | 7 of 20, frame 7, loose | **20 of 20, frame 1, b0** | all, frames 1-8, the poker |
| S19 | pick-up and R-0069: 24 ring, 78 pick-up, 8 pass scenes | no change | | **identical rows** (every scene's take frame the same) | |

In matches (the ladder's TLHand "regular" at pro, 24 seeds, `hand_match.gd`; the hand is a script, not a person):

| per minute | before | after | thirdjam (round 2) |
|---|---|---|---|
| whole-game freezes | 3.97 | **0** | 0 |
| he is knocked down (per minute of play) | 1.68 | 1.19 | 1.99 |
| share of play he lies on the ice | 5.4 % | 3.3 % | 6.8 % |
| knockdowns of anybody | 4.70 | 4.23 | 5.45 (10 skaters) |
| body meetings resolved as a bounce | 0 | 85.7 | (every meeting) |
| his carry ends, per minute of carrying: poked / hit / his shot or pass / lost alone | 10.0 / 13.9 / 15.3 / 2.2 | **27.3 / 7.2** / 11.7 / 0.7 | ~30 (stick or touch) / 7.2 / 35.0 / - |
| his carry, median | 1.22 s | 1.00 s | 0.57 s (shortened by the trace's flicker, see 5 below) |
| matches won, goals for : against | 12 of 24, 39 : 39 | 9 of 24, 25 : 37 | |

The bots' pokes now always take in reach, and they poke the human's carries 2.7 times as often as before: a carrier in
reach of a red stick loses the puck. Hits strip him half as often (7.2, exactly thirdjam's). That is the sheet working as
written; whether the bots should poke that often is lane H2's call (below).

Window (as a person meets it): `build1_window.mp4` (18 s) and `build1_window_sheet.jpg`: start, the stop and reverse, a
90-degree turn, a carry through a turn, a check, a timed cross-check, a poke, rendered (d3d12, 60 fps movie writer) on the
after pack. The rows written in the window run are byte-identical to the headless ones for the stop, the turn, the check and
the cross-check; the poke took at frame 1 in both (the puck's coordinates differ in the third decimal).

## Rows that did not reach their target, plainly

- **A3, back to 90 % of top the other way:** 65 frames against 61 (the stop is right at 29 frames; the push back is 4 frames slow).
- **A2, the build-up in metres:** 2.73 m (0.046 of the rink) against 2.5 m (0.042): within 10 %.
- **A2 + S15, the carrier's build-up:** 35 frames against 34.
- **S1, contact frame from 0.45 m:** frame 2, thirdjam frame 3: our pull brings him in a frame sooner.
- **A3 needed a value the sheet did not give:** `reverse_decel` 13, not 18.9 (above).
- **The build-up a hand can feel beyond route A:** not built. Route A already gives thirdjam's 34-frame push in frames; the
  remaining difference (5.2 against 15.8 body widths a second) is the body and the rink, which is route B's.
- **In body widths nothing changed** (route A keeps our body): the figure still moves 5.2 body widths a second.

## Found while building

1. **The check's pull ran the attacker into his man** (a same-way check at equal speed: the bodies met in the pull, the
   kinematic collision stopped the attacker, and the check landed with closing speed -8 m/s). Fixed: the meeting test counts
   this frame's pull. Exposed by S1 (the 8-frame wind-up pulls harder).
2. **The cross-check had no man when pressed from more than 0.88 m**, so its swing waited a frame past its due frame and
   landed after the bodies had met. Fixed as part of S6: the man is judged where the wind-up brings him (thirdjam's lane A209).
3. **The pass magnet could make a pass orbit its receiver** at pass speed for ever (17.6 m/s, 1.7-3.1 m out): it bent every
   pass within 3.3 m toward the blade, also one going past. Seen in the first-minute drill (`bot_intro`) after the route A
   rows changed its timing. Fixed: only a pass heading within 45 degrees of his blade is bent.
4. **Open: a drill re-placed after a hit puts r0 0.2-0.35 m off his mark** (`bot_windup`'s second row, after its first row's
   stumble; absent on main, present with each tuning group I reverted, not caused by the new contact code). Not explained in
   this round; the test now starts that row from a fresh match. It may touch any set start that follows a hit (a face-off).
5. **Correction to round 1 and 2:** thirdjam's "the puck leaves his stick and comes back by itself 24.8 times a minute" is an
   artifact of its trace: at each of those 339 moments the puck sat 1.60-1.71 m from him, at the edge of thirdjam's 1.65 m carry
   reach, moving with him (`probes/hand_blip.mjs`). Sheet row S18 (a livelier carry) is withdrawn and not built; a note is in
   BEHAVIOUR-HAND.md section 0 line 5 and 3.2.

## Tests whose expectations moved, each with its row

| test | what changed | row |
|---|---|---|
| `bot_sprint.gd` | the carrier sprints 8 x 0.92 x 1.08 = 7.95 m/s (was 8 x 1.012 x 1.15 = 9.31) | S15, S16 |
| `bot_reverse_stop.gd` | still inside 30 frames over 2.3 m (was 22, 1.6); control thrust 10.04 m/s2 (was 14.95); the stop is read at 0.05 m/s (was 0.3: at 13 m/s2 a frame takes 0.22 m/s, so 0.3 fired a frame early) | A2, A3 |
| `crazy_pickups.gd` | the boosted free thrust 15.06 (was 22.425), unboosted 10.04 (14.95) | A2 |
| `bot_fun.gd` | no row wants a freeze now (row 0 did) | S10 |
| `bot_check.gd` | the speed ladder is driven at 9.2 / 12.65 of its old speeds (the same ratios under the scaled law); down 36-126 (was 60-150) | A4, S9 |
| `bot_contact.gd` | head-on 6.25 m/s is a knockdown (ratio 1.12), a sprint into a side-braced man a stumble with recoil (0.51), 8 m/s into his side a stumble with recoil (0.42); the cross lands at start + 9 (was + 11); down 36-126 | A4, S4, S9 |
| `bot_poke.gd` | presses come when the HUD says the poke can reach (was a fixed frame into the old 6-12 window); in front and at the side every press in reach takes, from behind none (was 18-34 of 40 and at most 16); the window is frames 0-8 of the press; a whiff no longer halves the turning; the press at 40 is taken after a miss (cooldown 14, lock to 28); trials wait out the 14-frame cooldown; drills: `poke_lock` r0 pokes at 12 (was 6) so the take falls where it did, `poke_cut` b0 0.5 m closer and r0's sideways speed 2.18 (was 3) so the carrier is in reach under route A's thrust | S11-S14, A2 |
| `bot_reach.gd` | the late poke is resolved in frames 0-7 (was 6-12); a whiff is the window running out (was the halved turn rate) | S12, S13 |
| `bot_windup.gd` | the second row starts from a fresh match (finding 4); the assertions are unchanged | S1 |
| `bot_hockey_ai.gd` | seed 1 now ends 2:2 at the 300 s limit (reason `time`, result DRAW); a played-out draw counts, as H9a writes it; the AI-acts checks are unchanged. **A judgement call: the Director may prefer another seed.** | all rows together |

Ladder cells (each test is seed 1 of its cell, read through the named TLHand profile; every cell still passes: the ladder tests
assert play, not a win). Before -> after, blue : red: rookie perfect 3:0 -> 2:0; rookie newcomer 3:0 -> 1:0; rookie regular 2:0
-> 3:0; rookie sharp 3:0 -> 1:3; rookie idle 0:1 -> 0:1; pro perfect 3:0 -> 3:0; pro newcomer 2:0 -> 0:1; pro regular 1:3 -> 3:0;
pro sharp 0:2 -> 1:0; pro idle 0:1 -> 0:1; all-star perfect 3:0 -> 2:2 (time); all-star newcomer 0:2 -> 0:1; all-star regular
1:2 -> 0:3; all-star sharp 0:3 -> 0:1; all-star idle 0:3 -> 0:1. bot_hockey (perfect, rookie) 3:0 in 5255 frames -> 3:0 in 640
frames. Over 24 seeds at pro with the regular hand: 12 -> 9 wins. Not tuned back (the owner: bot metrics are not the bar).

## For H2 (`data/ai.json`, `scripts/ai/**`: not touched here)

- A5, the bots' hit thresholds in route A's scale: `check_min_closing_red` 4 -> 2.9, `check_min_closing_blue` 8 -> 5.8,
  `cross_min_closing` 1.5 -> 1.09.
- The bots read the poke's odds (`poke_min_odds` 0.25): odds are now 1 or 0, so every bot pokes whenever a carrier is in
  reach and not facing away; they poked the human's carries 27 times a minute of carrying (10 before; thirdjam's bots ~30 by
  its trace). Whether that is the level ladder's aggression is H2's.
- The bots' strip at the press (S7) and the bounce (S8) apply to them too (thirdjam's laws are everyone's).

## Gates

- `node devx/bin/tl.mjs check --tier fast`: PASS arch [12/12], assets [4/4], cards [3/3], devx.test [229/229], foreman.typecheck
  (11:47, and again at 12:47 after the last change: the same five PASS lines).
- `node devx/bin/tl.mjs check --tier full --only packs` (11:58-12:27, machine load 14.5): **FAIL**, 128 of 129 verb runs passed;
  the one failure is `hockey invariants: invariants.many_budget: frame p50 1.382 ms (budget 1.0 ms)`. Every bot test of every
  pack passed. Measured back to back on this machine right after: **main's hockey pack fails the same check** (1.193 and 1.135
  ms, then 1.352 and 1.303 ms) while the build measured 1.272 / 1.292 ms; after making the bounce's pair loop arithmetic only
  (one pass over the bodies, a distance prefilter) the build measures 1.359 / 1.315 against main's 1.352 / 1.303 in the same
  minutes: the build costs no frame time that this check can see, and the budget fails on main under this load.
- Second full run (12:24-12:43, load 7.9): **FAIL** again on the same one check only, p50 1.101 ms; 128 of 129 verb runs passed.
  Back to back right after: main 1.180, 1.060, 1.047 ms; the build 1.076, 1.155 ms. Under today's load main fails this budget too;
  it needs a quiet machine (or the Director's call) to read the build against it.
- The pack's 56 tests through `.tl/h1/run_tests.sh` (seed 1, 36000 frames, the same verbs): 56 of 56 on main before; 56 of
  56 after.
- No kernel change, so the world step was not required.
