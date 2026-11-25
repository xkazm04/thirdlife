# E5e: the whole user path on the fixed code (25 Nov 2026, hk-proof at hokej 17c60a1)

One job, run as Create runs it:
- jobs root `.tl/proof-jobs-e/`;
- every step through `engine/ui/foreman_run.mjs` with real.json's flags (claude-cli, sonnet);
- holds answered on Create's cards, as a person would.

No code changed. Stills in `e5e/`; I looked at all of them. Raw captures deleted. Times are local.

**The result: a sentence became a playable game in 28 minutes, and a two-part change was promoted 8.5 minutes later.
The skin and match stayed byte-equal across the change. 37 minutes in all, of a 75-minute budget.**

## 1. The sentence: "hockey where the ice has slow and fast patches and bumpers in the corners"

| question | answer |
|---|---|
| Design passed on the first start? | **Yes** (10:24 to 10:30, 6 min). |
| Designer attempts | **1.** The run made 2 designer calls: the first answer, then the redesign after the design review. That is the review loop, not a failed check. No repair call, no refusal. |
| Concept | Candidate 1 of 5, likelihood 0.85: "arcade hockey where patchy ice changes your speed and corner bumpers bank the puck". |
| No extra twist? | **Yes, as a twist.** It is the sentence's game: 2 orange fast lanes, 2 blue slush circles, 4 bumpers (size 5) in the corners, and 4 green "pass from here onto pink" spots. Two small rule extras came with it: a "hot stick" comeback hook (the conceding side shoots 15 % harder for 10 s) and "live boards" once someone reaches 3. They are not a second game; noted, not refused. |
| pack.json carries `base`? | **Yes**: `"base": "rink_game"` in the job's pack/pack.json. |
| Does a script package fit now? | **The budget is free**: lint.size says "6277 lines of GDScript (0 game lines of its own over the base rink_game)", so the game's own 6,000 lines are untouched. This plan had no script package (base, slush_cartridge, slush_skin), so no script was actually written into that room. |
| Holds and questions | **No builder question.** **One quality hold**, raised **at once** (event 77-79): "the critic names the base ...: this is how the base plays; no package of this game can change it, so no revise round was spent". I answered "It's fine, go on" (`quality accept --note "the person plays it as it is"` + resume). |
| Did the critic judge something the person refused? | **No**: I refused nothing in this job. But the critic's main reasons are false; see defect 1. |

**Timeline**
- plan 1.7 min;
- base copied (43 files); its first lint still took **2.6 min** (09:32:18 to 09:34:52 UTC);
- slush_cartridge builder 2.1 min (951k tokens in), merged;
- **phase 1 at 17 min** (10:41), with figures at the pause.
- Phase 2: the skin builder, merged at 10:44; then the greybox look (16 captures, 5.8 min) and the critic verdict in
  0.6 min, followed straight away by the hold (10:50). Critic loop time: about 6.5 min, against job 1 of E5b's 89 min.
- "It's fine, go on", phase 2 passed: **v0.1.0 promoted at 10:52, 28 min.**

**Measured at the phase pauses** (`reports/core-phase-patchy_ice-s43.json`): ok, "no warning".
- rookie 10/10, pro 8/10, all_star 3/10;
- pro: 5.4 goals in 2.6 min (hokej 4.2 in 3.1), carry 0.8 s, shots 30.3, passes 1.8, speed 9.5 m/s, knockdowns 11.9;
- idle 0/16, skating alone 1/16.

## 2. The change: "make the bumpers bigger and add a fast lane through the middle"

| | v0.1.1 |
|---|---|
| time | **8 min 30 s** (09:52:43 to 10:01:13 UTC) |
| package | **slush_cartridge** (not the base): "Bumper size and the ice's fast patches are defined by the cartridge package ..." |
| path | **The diff round was refused at the merge, then a builder round, then the fast path.** Details below. |
| runner calls | 15: lint 5, smoke 4, bot 5, capture 1 |
| model calls | owner 2.9 s; diff 17.8 s + 13.6 s; one builder round 1.7 min (511k tokens in) |
| what-changed note | "[foreman] what changed in v0.1.1 (since v0.1.0): asked "make the bumpers bigger and add a fast lane through the middle"; game.rink.obstacles[0..3].size: 5 -> 7; game.rink.zones: [...] -> [... + lane-middle ...]; files: data/slush.cartridge.json" |
| data/skin.json, data/match.json against v0.1.0 | **byte-equal** (cmp); diff -rq shows only the cartridge and pack.json differ |
| cartridge keys | bumper size 5 -> 7 (x4); bumper centres (+-28, +-12) -> (+-28.64, +-12.76) to keep the bank point; + zone `lane-middle` fast_ice 44 x 4 m at the centre; zone `spot-nw` removed (the core allows at most 8 zones) |
| measured before / after (pro) | 5.4 goals, 2.6 min, speed 9.5 / 5.7 goals, 2.2 min, speed 9.7; all_star wins 3 -> 6; no warning |

How the path went:
- The cartridge diff made bumpers 7 and added lane-middle. To stay under 8 zones it removed **two** boost spots.
- The **kit gate refused the merge** (event 110): "KIT REGRESSION: kit parts used fell from 14 to 13 ("kind" entries
  in data/*.json ...)". The kit gate counts every `"kind"` in the cartridge's zones as a kit part, so dropping a zone
  looks like losing a kit part.
- A builder round (r3) then redid it, removing only one spot (the zone count stayed 8). It merged 1 file, and from
  there the fast path ran: "data-only change: the pack tests, the re-verification of slush_skin and the milestone's
  re-look are skipped", final = lint + smoke + one picture.
- Without the kit-gate refusal this would have been about 3 min with no builder (E5d's figure).

## 3. What I saw
- **`e_top_hokej_vs_phase1.jpg`** (hokej left, this game right, the clean top view): two orange lanes with speed
  dashes, two blue dotted slush circles, four pink-topped bumper drums in the corners, four green "+" spots, nets on
  the goal lines of the 70 x 35 rink.
- **`e_phase1_strip.jpg`** (20 s, follow camera, HUD on):
  - Gold against Green, "FIRST TO 4", the player's ring;
  - #7 skating down an orange lane, a goal by Gold;
  - the bumpers and green spots seen from the ice.

  As a player: the game the sentence names.
- **`e_top_v010_vs_v011.jpg`** (v0.1.0 left, v0.1.1 right):
  - the corner bumpers are clearly bigger;
  - a new orange lane runs through the middle across both slush circles;
  - one green spot is gone (three remain).
- **`e_v011_strip.jpg`**: the middle lane from the ice (tiles 6, 7, 10). The skin's names are in the commentary
  ("Welcome to the rink: the Gold Foxes against the Bog Walruses", "In! Bog Walruses score!"). Still its own game.

## Cost
`TL_SITE_DIR=.tl/proof-jobs-e node devx/bin/tl.mjs ledger`: one job, done, wall 36 min 41 s, run 28 min 55 s.
- 2.53M tokens in (1.73M cache reads), 95k out, weighted 1.07M;
- 5 rounds, 3 edit runs, 1 critic.

## Defects for the Director
1. **The critic judges the HUD from captures that have no HUD.** Its main reasons on the greybox look:
   - "no capture has a ring, score, clock, goal target, hint or goal banner";
   - "no ring or arrow is drawn under anyone";
   - "check that the HUD layer is on during play".

   The Foreman's look captures are taken with the HUD off (the capture verb's default), but my HUD-on strips of the
   same pack show the ring, the score, FIRST TO 4, the radar and the hints. The verdict was routed to the person
   correctly (base), but the reasons the person reads on the card are false.
2. **The kit gate refuses a cartridge diff that drops a zone.** It counts `"kind"` entries in data/*.json as kit parts.
   A cartridge change that must remove a zone (the 8-zone limit) fails as a "KIT REGRESSION" and costs a builder round:
   +1.7 min and 511k tokens here, and it turned a 3-minute fast change into 8.5 minutes. Cartridge zones and obstacles
   are not kit parts.
3. **A change can remove something the person did not mention.** The diff dropped two, then the builder one, of the
   game's "pass from here" spots to fit the 8-zone limit. The what-changed note lists it inside a long JSON line; a
   person would not find it. A one-line "removed: spot-nw (8-zone limit)" in the note would.
4. **The first lint of a fresh job workspace is still about 2.6 min.**

landable E5e
