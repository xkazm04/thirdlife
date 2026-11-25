# For lane E2: the planning hand's short ladder inside `rink.sh check-cartridge` (lane K8, 25 Nov)

What it can tell you about a generated cartridge: whether it **ends**, whether **skill shows**, and whether there is a
**way to win without playing**. What it cannot tell you: whether it is fun. Its figures are a hand's, never a person's.

## The cells (planning hand, `lab_plan.h`; pro level; 16 seeds each; about 3 minutes on 6 processes)

```
rinklab match <content> -cartridge=<name> -difficulty=pro -seeds=1-16 -playersprint -plancheck  + one of:
  -player=regular -remove=idle      the hand that never moves
  -plan=novice | -plan=regular | -plan=good
  -plan=regular -remove=shoot       the same hand with every shot taken away (it re-plans without it)
  -plan=regular -only=none          skating and nothing else
```
Each match prints thirdjam's `thirdjam.playtest/1` line and the lab's `rinklab.cell/1` line (with `planstats`: which intents
the hand chose, and `clone_checked` / `clone_mismatch`). `cells.mjs` `summarize()` turns a cell into figures.

## What should FAIL a cartridge (gross defects only: 16 seeds see nothing finer than about 25 points)

| Check | FAIL when | What it means | Seen on |
|---|---|---|---|
| The run completed | any cell has fewer matches than asked, or a process exited non-zero | a stopped run is never a pass | - |
| The game ends | more than a quarter of a cell's matches reach the 10-minute hard stop (`over` false / `frames` 36000) | nobody can score | - |
| It needs the player | the idle hand wins half or more of its matches at pro | won without you | `hockey.regular` at rookie: 60 % |
| It needs its verbs | the skating-only hand wins a third or more | you can win with no key | `hockey.regular` at pro: 29.5 % (PLAY) |
| Goals need the scoring verb | the hand without shots wins within 15 points of the full hand | the scoring verb is a decoration | `hockey.regular`: -8 points |
| Skill is not upside down | the good setting's goal difference is below the novice's by more than 1 goal a match | the game punishes skill | - |

## What it should only PRINT (with the hand named and the seeds; never a pass)

Wins and goal difference of novice / regular / good; a goal every how many seconds; a carry's seconds and the share lost;
passes that reach a mate; knockdowns and seconds on the ice; which intents the regular hand never chose in the whole cell
(a key it never reaches for is a candidate dead key, to look at, not a verdict).

## Three things that will bite

1. **The hand is only valid where its copies of the game are exact.** Its look-ahead steps a copy of `UJamSim` with the rule
   hooks, zones and effects unbound. `hockey.regular` and `hockey.thirdlife` have none, and `-plancheck` proves the copies
   exact there (0 of about 30,000 frames differ). A generated cartridge with pickups, effects, zones or rule hooks will
   show `clone_mismatch` above 0: then the hand's foresight is wrong, and the check must say
   **"planning hand NOT VALID for this cartridge"** and fall back to thirdjam's scripted hands (`-player=`), not pass.
   Making the hand valid there means cloning the systems with the sim (`FJamSystems`): a known gap, not done.
2. **It is fitted to one number on one cartridge** (its regular setting wins at pro on `hockey.regular` what thirdjam's own
   regular hand wins: 75.5 %). On a cartridge with other rules its three settings are still "slow, average and quick
   person", but "average wins 78 %" is not a target for other games: read the SPREAD and the defects, not the level.
3. **Its ablation leans.** A planner without a verb re-plans and often loses nothing (it leans toward "this verb is worth
   nothing"); the same hand still pressing a dead key (`-plankeep`) leans the other way. For a check, use only the two
   coarse ones above (no shots, skating only), whose effects are tens of points.

## What I would not put in the check

Any figure of fun, any target band for wins, any single-verb verdict at 16 seeds, and anything that reads the bots' brain.
