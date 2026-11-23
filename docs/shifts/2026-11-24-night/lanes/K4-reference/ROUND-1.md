# K4 reference, rounds 1-3 in one pass (18:40-21:00)

The brief's three rounds (tempo map and ladder; ablation; weak list and harness) ran as one pass: the instrument was the
long pole, and once it stood the match runs (about 31,000 matches, 6 processes) ran while the page was written.

## What stands

- **The lab runner** `engine/cores/rink/lab/` (`rinklab.exe`, built by `bash engine/tools/rink.sh lab-build`, MSVC through
  SCons, no godot-cpp). It compiles `native/thirdjam/` (HEAD 8dc713c6, unchanged; `git status` shows nothing under
  `native/`) and adds only: `FLabSimAdapter`, a subclass of thirdjam's `FJamSimAdapter` whose `Step` filters the human's
  input before the base copies it into `FJamInput` (and whose `View` can hold a team signal); read-only counters; scripted
  gym probes. thirdjam's own `RunPlaytestMatch` runs the match.
- **Sameness.** Empty filter: 60 of 60 playtest lines equal `rinkcli` HEAD (K1's build), hash for hash, at three levels and
  three hands; re-checked after every rebuild (20 of 20). Determinism: the 12 ladder cells run twice, 2,400 of 2,400 match
  hashes equal.
- **PLAY.md** (`docs/research/hockey-teardown/PLAY.md`): the tempo map (gym + matches), the mechanic matrix (every verb from
  the source with file:line, then 114 ablation cells and 32 skate-plus-one-verb cells, 200 seeds each), the skill ladder
  (12 cells x 200), the team signal held all match, the weak list (12 entries, each with a figure or a traced match and
  frame), the harness.
- **The harness** `bash engine/tools/rink.sh balance` (12 cells x 50 seeds + 43 gym probes against
  `engine/cores/rink/lab/balance.baseline.json`).

## What my eye rejects

Nothing to look at: this lane draws nothing (the core is measured headless; K2/K3 draw). Rule 3's frames do not apply; the
evidence is figures and traces.

## Deviations from thirdjam (measurement only; the shipped core is untouched)

1. An ablated verb is a key the game never hears; the hand is not re-planned (a hand without the pass still decides to
   pass and keeps the puck that frame). Two are conversions, not cuts: charge -> tap on the release frame, saucer -> tap pass.
2. The stop ablation carves the reversed stick to 115 degrees off the velocity (the playtester's own carve angle).
3. Every ablation but "draw" leaves the faceoff phase unfiltered (the hand's draw press is a poke).
4. `-only` keeps skating, the stick's aim and the draw.
5. The signal arm holds one intent all match, aimed at every mate (a person would signal at moments).
6. The gym cuts the roster to 2 v 2 and runs no brain; bots get |Move| 1 except the probes that say 1.5.
7. The lab builds with its own SConstruct (plain MSVC, /O2 /MT /std:c++20 /fp:precise) instead of godot-cpp's environment;
   sameness is shown by equal playtest lines, not assumed.
8. `rink.sh`: my block sits just before the `*)` arm of the case (after `esac` it would never run: `*)` exits first). Nothing
   else in the file changed.

## Next

Round 4 (if sent on): a person-like hand that re-plans without a verb (the ablation's honest second arm); the walk-in goal and
the pass's loss traced against the Unreal build's film of the same seed; the harness wired as a `tl check` step.
