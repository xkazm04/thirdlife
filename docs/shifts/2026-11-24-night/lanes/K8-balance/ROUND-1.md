# K8 balance, round 1 (23 Nov 21:00-23:00; closed 24 Nov 21:00)

Nobody has played `hockey.thirdlife`. Every figure below is a hand's (named each time).

## What stands

- **The design**: `docs/design/HOCKEY-BALANCE.md`. The fantasy, six pillars (each with the owner's words, a proven game, a
  measured fault and what it rules out), the tempo frame (what may not move), the target matrix for every verb, ten measurable
  targets (T1-T10), the cuts decided before any number (the brake key, the ability key, the saucer as a verb, the walk-in goal,
  the take with no key), three questions for the owner.
- **The planning hand** `engine/cores/rink/lab/lab_plan.{h,cpp}` (`rinklab match ... -plan=novice|regular|good`). No script: it
  rolls the real simulation forward under up to eighteen plain intents and plays the best, with a person's limits (it sees
  300 / 233 / 167 ms late, decides every 0.5 / 0.33 / 0.2 s, misjudges, aims off, presses a limited number of keys a second).
  It never reads the bots' brain. Its copies of the simulation are exact (`-plancheck`: 0 of 10,847 frames hashed differently).
  `-remove=<verb>` takes a verb out of its menu, so it re-plans without it (K4's open question).
- **Validated on `hockey.regular`** (100 seeds a cell; `tables/plan_ladder.hockey.regular.seeds1-100.json`). Calibrated on one
  number only (its regular setting at pro: 77 % against thirdjam's regular hand's 75.5 %). Unprompted it found, at pro: the
  walk-in goal (0.33 of its 2.27 goals a match), the take with no key (4.4 a minute of its 8.3 takes), the carry of two thirds
  of a second (0.68 s; 38 % lost to an opponent), 4.0 knockdowns and 8.0 s on the ice a match, the one-timer that never comes
  (0.22 a match), rookie won by every setting (99 / 100 / 100 %). **Six of PLAY's findings.**
- **Where it contradicts PLAY** (so those were the script's, not the game's): its three settings spread at pro (55 / 77 / 97 %,
  where thirdjam's hands are 24.5 / 75.5 / 76 %); it passes as often as thirdjam's hand (5.3 a minute) and completes 58 %, not 38 %.
- **The thirdlife variant**: `engine/cores/rink/native/patches-thirdlife/*.patch` (two patches), applied to a copy of
  `native/thirdjam` by `engine/cores/rink/lab/thirdlife-tree.sh`, built as `rinklab-thirdlife.exe` (`rink.sh
  lab-build-thirdlife`). thirdjam's files are untouched (`git status` shows nothing under `native/thirdjam`). The patched tree
  with every switch off plays `hockey.regular` hash for hash: `rink.sh balance-thirdlife --parity`.
- **The cartridge** `native/content/Cartridges/hockey.thirdlife.cartridge.json` (a valid thirdjam cartridge: the numbers) and
  `hockey.thirdlife.rules.json` beside it (what thirdjam's schema cannot say: the patch switches and, later, the level table).
- **The ledger** `engine/cores/rink/lab/experiments/` (`run.mjs`, one `E*.json` per experiment, `LEDGER.md` generated from them).

## The experiments (60 seeds a cell; figures and standard errors in `LEDGER.md`)

- **The hand's own ablation on `hockey.regular`** (`tables/plan_ablation.hockey.regular.pro.seeds1-60.json`): skating alone
  -58.3 points; no shot -8.3 (PLAY -8); no pass **+8.3** (PLAY +9); no tap shot **+11.7** and no brace **+13.3** (both over two
  standard errors: keys that cost the hand that presses them); every other single verb inside ±5, the sprint and the stop
  included (PLAY: -12, -13 for the script). A screen cannot see a verb worth less than about 15 points.
- **E01, rejected**: the goal line closed while the puck rides with its carrier. It leaked: walked goals halved, not gone.
  A second form (held until released) was spot-checked on six matches and leaked too: traced with `-debuggoals` to the
  carry pulling the puck round a post towards a blade already inside the net, where the net's side wall pushed it in.
- **E01b, kept**: the goal line closed to a held puck (held until shot, passed or touched by another). No goal without a
  release in any full-hand cell, either side. A hand with no shot loses 35 points of wins at pro (thirdjam's hand) and 58
  (the planning hand), where it lost 8. thirdjam's regular hand, which cannot re-plan, loses 11.7 points at pro (75 -> 63.3);
  the planning hand does not (76.7 -> 85, +8.3 ±6.0). Still dead after it: the deke.
- **E02, rejected**: a tap pass that arrives at 12.5 m/s instead of 8 (a 15 m tap in 45 frames instead of 63). Passes
  completed rose 8 to 20 points, but the number is every bot's: all-star collapsed (38 -> 7 %, 67 -> 27 %) and the pass still
  did not pay the hand that made it.

## What my eye rejects

Nothing to look at (no frames). What my reading of the figures rejects: the planning hand keeps pressing two keys that cost
it; its ablation at 60 seeds cannot tell a dead verb from one worth ten points; thirdjam's scripted hand is punished by E01b
for a habit, which says more about the script than about the rule but moves the ladder all the same.

## Deviations from thirdjam (the reference is untouched; these are the thirdlife cartridge and the lab)

1. **Rules** (`hockey.thirdlife` only, each a switch that is off in `hockey.regular`): the ledger's kept experiments, nothing else.
2. **The planning hand** is this lane's instrument, not thirdjam's. Its copies of the simulation have the rule hooks, zones
   and effects unbound (`hockey.regular` and `hockey.thirdlife` have none; `-plancheck` proves the copies exact). It moves
   with a free direction, not eight keys; it never signals its mates; its limits were set once against thirdjam's ladder.
3. **The rules sidecar** (`<cartridge>.rules.json`) is a file thirdjam does not have: thirdjam's cartridge schema is embedded
   in its source and rejects unknown keys, so switches of the patches cannot live in the cartridge file itself.
4. **The patched tree** adds one member to thirdjam's `FJamGameConfig` (`Tl`, the switches) and one to `FJamPuckState`
   (`TlHeldBy`, hashed only while its switch is on). In a copy; `native/thirdjam` is byte for byte.
5. **The lab's observer** gained read-only counters (goals by how they crossed the line, takes with and without a key) and
   `rinklab` gained options (`-plan`, `-plancheck`, `-tl`, `-tune`, `-debuggoals`); `cells.mjs` and `balance.mjs` gained
   `--exe`, `--cartridge`, `--baseline`. With none of them given the harness is K4's: `rink.sh balance` PASS, hash for hash.
6. **A screen is 60 seeds a cell**, not PLAY's 200: enough for a rule's events and a large swing in wins, not a small one
   (the ledger prints the standard error of every paired difference).
7. `foreman/node_modules` was installed in this worktree with `npm ci` (ignored by git) so the fast gate could run.

Rule 3 of the campaign (frames beside the reference's) does not apply: this lane draws nothing. Its evidence is figures.

## The stop and the resume

The lane stopped on a usage limit at about 23:00 on 23 Nov, after the last experiment and during the closing gate chain
(which finished by itself at 22:59: every line PASS). Resumed on 24 Nov at 20:50. An Opus stand-in was started in this
tree in between and stopped: it left nothing here (no file in the worktree, `.tl` included, is newer than 23 Nov 22:59, and
`git status` shows only this lane's files), so there was nothing of its to keep or to discard. On resume the whole gate
chain was run again on the unchanged tree; the report quotes that run.

## Next

Round 2: possession and contact (the take with no key; a carry that skill can keep; pokes, checks and knockdowns with a price
and an answer), then the dead verbs.
