# The world's clock: tiers, the scheduler, the world file (N5a)

Every game in a world stays alive. A far game runs in slow motion: fewer ticks, each a full 1/60 s step. This file
says who decides how many ticks a pack gets, how that was proven, what it costs on this machine, and what a world
file keeps. Code: `kernel/world/tiers.gd` (the scheduler), `kernel/world/tiers.json` (every threshold),
`kernel/world/world.gd` (the host), `kernel/world/pack.gd` (one pack), `tools/world.sh` (the commands),
`kernel/world/walks/*.json` (the walk scripts used below).

## What it means for a player

- The game you stand in and the ones across the road run at full speed; a game far away keeps playing, in slow
  motion: with 12 games in the world a far one runs at a third to a half of real time, with 30 at about an
  eighth, with 60 at about a sixteenth, on this machine as it was tonight (shared with other work).
- Nothing you walk away from is switched off or reset. Come back and it is further along, exactly as if it had
  played alone for that many ticks. Only a game its author marked `pause` waits for you, and one marked `end` starts
  again.
- A saved world brings back your plots, their games and seeds, and remembers each game's score and clock. Every
  game starts its round again from its seed (positions and velocities are not saved) and gets its score back only
  if its author wrote the two save functions.

## The model

| tier (wire value) | when | ticks it gets |
|---|---|---|
| `stage` | the player is inside the plot's footprint | every world tick |
| `sideline` | the plot's edge is within `sideline_m` of the player, or the plot is next to the stage plot (gap up to `adjacent_gap_m`) | every world tick |
| `backdrop` | farther | one tick per `slice` world ticks, round-robin |
| `ledger` | farther than `backdrop_m` (0 = never for distance), or pinned there by a ticket | none: the pack is not in memory; ticks, summary and its own saved data are kept |

A pack only ever sees its own tick count. A tick it does not get is N2's switch-off (holder disabled, space
inactive), so a pack's state depends on its own ticks and inputs only.

`decide(tick, player position)` applies, in this order:

1. **The stage follows the player.** He is inside a plot's footprint. He has left it when he is more than
   `margin_m.stage` outside and either stands inside another plot or `dwell_ticks` have passed since it became stage.
2. **Tickets.** `{"tick", "plot", "tier", "ticks"}` in a walk script pins a plot at a tier for that many world ticks,
   against distance and against the valve. Nothing is pinned for good.
3. **Valve hold.** A plot the valve demoted stays at `backdrop` for `valve.hold_ticks`; it returns only when the
   world runs at full speed and stage + sideline with it would cost at most `valve.recover` of the front budget.
4. **Adjacency.** Plots next to the stage plot are `sideline` whatever the distance.
5. **Distance, with a margin and a dwell.** A plot is promoted the moment it is inside a boundary; it is demoted
   only when it is beyond the boundary plus `margin_m.<tier>` and has been `dwell_ticks` at its tier.
6. **The budget valve**, every `valve.every_ticks`: while stage + sideline cost more than `budget_ms.front`, the
   farthest sideline plot is demoted to `backdrop`; `slice` is set so the backdrop costs about `budget_ms.backdrop`
   per world tick (within `slice.min` .. `slice.max`); when nothing is left to demote and the world still costs more
   than both budgets together, `speed` drops in steps of `valve.speed_step_pm` (never below `valve.speed_min_pm`):
   every pack gets fewer ticks, equally (the packs take turns, so every world tick is cheaper, not every second one
   empty). Speed comes back one step at a time when the next step would stay under `valve.recover` of the budget.
   **No pack is ever switched off for good**: speed never reaches 0 and `slice` never exceeds `slice.max`.

A pack's cost is either `model` (`cost_model_ms` in tiers.json: the run is then a pure function of the walk script)
or `measured` (`--cost=measured`): the time the tree spent in the pack's nodes, the kernel's calls into it, and a
share of the rest of the iteration (the physics step) by awake bodies, smoothed over 16 ticks; one stalled
iteration counts for at most four times the estimate.

`on_leave` (from `pack.json`, default `bot`; a plot entry of a walk script may override it): when the stage leaves a
plot, `bot` plays on (in a headless run the bot is the player's stand-in throughout, so nothing changes), `pause`
holds the pack (no ticks until the player is back), `end` ends the run (hash taken) and the pack is built again
from its seed when the player returns.

### Every decision is an event

`tier`, `slice`, `speed`, `leave`, `return`, `ticket`, `over` (a game ended by itself), `restart`: each is one line
at a tick boundary, and `due(tick)` is a pure function of the events applied so far. `world.sh walk <script>
--log=<file>` writes them (`tl.worldlog/1`: the walk script, the thresholds used, the events);
`world.sh replay <file>` runs the same world from the log, applying the logged events instead of deciding.

### Files

- **Walk script** (`tl.walk/1`): `{name, ticks, mode: "smoke"|"bot", scenery?: "full"|"plot", tiers?: {overrides of
  tiers.json}, plots: [{id, pack, origin: [x, y, z], seed, yaw?, footprint?, on_leave?, mode?}], player: [[world tick,
  [x, y, z]], ...] (straight lines between the pairs), tickets?: [{tick, plot, tier, ticks}]}`.
- **tiers.json** (`tl.tiers/1`): `sideline_m` 100, `backdrop_m` 0, `margin_m` {stage 2, sideline 10, backdrop 40},
  `adjacent_gap_m` 8, `dwell_ticks` 120, `default_footprint_m` [40, 40], `budget_ms` {front 6, backdrop 2}, `slice`
  {min 2, max 16: the owner's floor of one sixteenth of real time for a far game, set 2026-11-11; it was 30 when the
  numbers below were taken}, `valve` {every_ticks 30, hold_ticks 600, recover 0.7, speed_step_pm 100, speed_min_pm 100}, `cost`
  "model", `ema_shift` 4, `cost_model_ms` per pack id. The distances are first values, not measured ones: nothing
  was drawn in this work, so "where slow motion becomes visible" is still open (test 14 of the layering report).

## The proof (item 3)

Commands (each prints the tier log, one line per pack, and for `proof` the table):

```
bash tools/world.sh proof proof --tiers-all     # the walk, each pack alone for the same ticks, the replay of the log
bash tools/world.sh walk heavy                  # the budget valve
bash tools/world.sh walk boundary               # a walk along two boundaries
bash tools/world.sh proof ledger                # unloaded for distance and rebuilt
bash tools/world.sh proof leave                 # on_leave: pause, end, bot
bash tools/world.sh proof tickets               # tickets: pinned at sideline, at backdrop, at ledger
bash tools/tl.sh selftest world.                # the cases world.walk_proof, world.walk_valve, world.walk_boundary, world.file
```

### Every pack hashes as it does alone, and the log replays

`walks/proof.json`: the three seeds 300 m apart, played by their bots; the player walks a -> b -> c and back in 2700
world ticks, so every seed is `stage`, `sideline` and `backdrop` and comes back. Cost model (no clock is read).
"Alone" is `world.sh run --packs=<pack> --mode=bot --seeds=1 --frames=<own ticks>`: the same pack by itself, in one
piece, for the same number of its own ticks. 24 events in the log.

| plot | pack | own ticks of 2700 | tiers seen | tier changes | hash in the walk | alone, same ticks | replay of the log |
|---|---|---|---|---|---|---|---|
| a | seed.paddle | 1880 | stage, sideline, backdrop | 4 | 59c7f07b104f7c6f | 59c7f07b104f7c6f | 59c7f07b104f7c6f |
| b | seed.drive | 1814 | backdrop, sideline, stage | 8 | 2962e9127af7ae3d | 2962e9127af7ae3d | 2962e9127af7ae3d |
| c | seed.wall | 1221 | backdrop, sideline, stage | 4 | 6366b88f838e3e78 | 6366b88f838e3e78 | 6366b88f838e3e78 |

seed.wall's bot won its game at its own tick 1221 (world tick 1878): the hash is the one `tl.sh bot` gives for the
seed. A game that ends by itself is an `over` event; in this build it then stays ended (a headless run has nobody to
start the next round).

The same holds when the schedule came from the clock. `bash tools/world.sh proof bench_mix_12` (12 packs, costs
measured, `scenery` "plot" in the walk): all 12 packs hash in the walk as they do alone (alone they are loaded with
FULL scenery: the forest and the far terrain are not part of the simulation) and as in the replay of the log, where
no clock is read: for example seed.drive 1200 ticks 5aa802966c22f6aa at `stage` and at `sideline`, seed.paddle 600
ticks 73832745050e1eb8 and seed.wall 600 ticks 7ad4b6701ab054be at `backdrop`.

### The valve engages and never drops a pack

`walks/heavy.json`: a stage pile, four piles within sideline range (40, 50, 60, 70 m), one pile and one small pack
at backdrop; cost model 4 ms per pile tick against budgets of 6 ms (front) and 2 ms (backdrop), `slice.max` 4.

- Tick 30: the valve demotes n4 (70 m), n3 (60 m), n2 (50 m), n1 (40 m), farthest first, until the stage pack alone
  (4 ms) fits the front budget; `slice` goes to 4 (its limit here); the world still costs 9.1 ms against 8, nothing
  is left to demote, so `speed` drops to 800 per mille.
- Over 1200 world ticks every pack kept ticking: the stage pack 966 ticks (0.805 of real time), the demoted ones 264
  (0.22), the two that started at backdrop 249 (0.21). The longest any pack waited between two of its ticks: 6 world
  ticks. 0 gate leaks, 0 errors.
- With `--cost=measured` the same world is light (30 boxes each: the whole tick is 2.2 ms) and the valve does
  nothing: 0 demotions. Under real load it engaged once by itself: in the first `bench_mix_30` run, on a machine at
  100 % CPU, it demoted all four sideline packs and went to 600 per mille. That was one stalled iteration moving every
  estimate; a sample is now limited to four times the estimate and it did not happen in the seven mix runs since.

### No flapping on a boundary

`walks/boundary.json`: plots a and b touch (the line between them is x = 20); c's edge is exactly 100 m (the sideline
boundary) from x = -10. The player zigzags 1.5 m either side of the a/b line for 1200 ticks, then 5 m either side of
c's 100 m line for 1000 ticks. Tier changes in 2400 world ticks: **a 0, b 0, c 1** (c is promoted once, the first
time the player comes within 100 m, and stays: it would be demoted only beyond 110 m).

### Ledger, on_leave and tickets

- `walks/ledger.json` (`backdrop_m` 250 for this walk): b (ex_bounce) and c (ex_wall) are unloaded at world ticks 366
  and 349 and rebuilt at 995 and 1015. c has no `_pack_save`: it starts again and its hash equals a fresh run of its
  new ticks (47e8042e7d6b9b47, 242 ticks). b has `_pack_save`/`_pack_load`: its score comes back, so its hash is
  NOT that of a run from the seed (7dca208f against d27b4ef8); the proof table says "restored" for it. Both replay.
- `walks/leave.json`: a (`pause`) got 145 + 285 = 430 ticks and none in the 515 world ticks between; b (`end`) ended
  when the player left at tick 545 and was built again at 1060 (440 ticks, hash of a fresh run of 440); c (`bot`)
  played on. All three equal their solo runs and the replay.
- `walks/tickets.json` (`bash tools/world.sh proof tickets`): the player stands still. b (backdrop by distance) is
  pinned at `sideline` from tick 100 for 300 ticks and falls back at 400; c (sideline by distance) is pinned at
  `backdrop` from 200 for 200 ticks and returns at 400; d is sent to `ledger` from 300 for 250 ticks and rebuilt at
  550. Own ticks 600, 800 and 175 (d's new run); all four packs equal their solo runs and the replay.

## The numbers (item 4)

Machine: Ryzen 7 7800X3D, headless, nothing drawn. **Every timing below was taken under load**: 13 Godot processes
of other sessions ran throughout and the CPU read 100 %. Hashes and tick counts do not depend on that; milliseconds
do. Where a figure was taken twice, both are given.

### Sleeping bodies (item 1)

`TLContact._physics_process` now returns at once for a sleeping body (`if body.sleeping and _pm != null`).
k copies of `w_pile` with seed 10030 (30 boxes left alone), 900 ticks, median iteration of the last third:

| packs asleep, every space active | N2, before | now (two runs) | per pack now |
|---|---|---|---|
| 10 | 2.0 ms | 0.17 / 0.26 ms | about 0.02 ms |
| 30 | 6.1 ms | 0.62 / 0.78 ms | about 0.023 ms |
| 60 | 13.8 ms | 1.60 / 1.57 ms | about 0.027 ms |
| 1 pack, 300 boxes asleep | 2.21 ms | 0.11 ms | |

An asleep pack costs about 0.027 ms per tick instead of 0.2 ms. The research's pass line (60 asleep packs under
0.2 ms) is still not met: what is left is the kernel's own per-pack nodes (the two marks, the probe, the input
record, the views, the call into `_pack_tick`), not the bodies. A pack on `backdrop` pays it once per slice.
Hashes: the three seeds idle (bc93a9a4, b9adbb19, da4bdc3f) and by bot (cadd1cd9 at 6776, 36635c04 at 3516,
6366b88f at 1221) are unchanged, and every gate was run (see the journal for the one wall-clock failure and why it
is not this change).

### World tick cost, 12, 30 and 60 packs

`walks/bench_all_N.json` and `walks/bench_mix_N.json` (written by `walks/make_bench.py`): a grid of plots 60 m apart;
packs in the order seed_paddle, seed_drive, seed_wall, w_pile with 60 boxes KEPT AWAKE (a busy scene), the three
seeds again, w_pile with 60 boxes asleep; seeds played by their bots; `scenery` "plot". "All" = the stage pack and
every other pack at `sideline` (every pack every tick). "Mix" = 1 stage, the 4 plots across the road at `sideline`,
the rest `backdrop`, costs measured, budgets 6 + 2 ms. Iterations after the first 120; p50 / mean / p99.

| packs | all at sideline: world tick (ms) | mix: world tick (ms), two runs | mix: slice (range seen, last) | slowest pack, share of world ticks (two runs) |
|---|---|---|---|---|
| 12 | 5.1 / 6.2 / 12.7 | 4.6 / 5.3 / 20.9 and 4.0 / 4.4 / 7.5 (a third run: 3.4 / 3.6 / 6.3) | 2 to 5, last 3 (third run: 2 throughout) | 0.28 and 0.47 (third run: 0.50) |
| 30 | 11.9 / 13.8 / 29.5 | 3.7 / 4.1 / 7.5 and 4.2 / 4.4 / 7.7 | 6 to 13, last 9 | 0.14 and 0.11 |
| 60 | 30.5 / 31.8 / 70.6 | 3.8 / 3.9 / 6.3 and 4.1 / 5.3 / 7.9 | 14 to 29, last 14 | 0.057 and 0.064 |

Slowest pack as a share of REAL time:

- All at sideline: 1.0 for 12 and for 30 packs (the tick fits a 16.7 ms frame at the median; at the 99th percentile
  the 30-pack world does not). With 60 packs a world tick is 30.5 ms, so the whole world, every pack alike, would run
  at about 0.55 of real time, before anything is drawn. The valve exists for this: it would demote and slice.
- Mix: the world tick stays near 4 ms whatever the size (that is the point of the budgets), so world ticks are real
  time and the share above is the share of real time: a far game runs at about a third to a half of real time among
  12, a seventh to a ninth among 30, a fifteenth to a seventeenth among 60. The first run's figures are lower
  because the estimate of a rarely ticked pack started at the model's 4 ms and came down slowly (fixed between the
  two runs: the first 16 samples are now a plain mean).

**How many games before the far ones drop below a tenth of real time.** `slice` is the backdrop's summed cost over
the backdrop budget, so the far games reach a tenth when the backdrop costs 20 ms a round at 2 ms a tick. Measured
cost per pack tick tonight (mean of each kind in the mix runs): paddle 0.26 to 0.39, wall 0.31 to 0.74, drive 0.55
to 0.71, a pile of 60 awake boxes 1.15 to 1.57, the same asleep 0.06 to 0.34 ms; the mix averages 0.45 to 0.65 ms.
That is **30 to 45 backdrop games, so a world of about 35 to 50 games**, on this machine under tonight's load, with
5 games at full speed. The runs agree: with 30 games the far ones were just above a tenth (0.11 and 0.14), with 60
below it (0.06). It is the budget that sets it, not a wall: each further millisecond of backdrop budget buys
about 20 more games at a tenth of real time, and the mix tick is 4 ms of a 16.7 ms frame. A quiet machine should
do better (N2 measured 0.19 to 0.68 ms per seed pack on the same hardware); not re-measured.

A sliced tick costs more than a continuous one, because the pack is switched on and off around it (the holder's
process mode over the whole subtree, the space): 12 seed packs, per round of 12 pack ticks, 4.7 to 5.3 ms at every
tick, 6.4 ms at one tick in 2, 5.5 ms at one in 8 (two runs each). About 0.05 to 0.14 ms per pack per sliced tick.
N2 did not measure this; it is inside the "measured" costs above.

### Loading (item 4, second part)

Where the 3 s per seed pack go (`load_ms` in every pack line: `assets`, `script`, `enter_tree`, `setup`, `laws`,
`bot`; then an instrumented scratch copy of the engine for the inside of `setup`):

| part | seed_paddle | seed_drive | seed_wall | w_pile (305 bodies, no kit) |
|---|---|---|---|---|
| scripts: first pack of the process / every later one | 411 ms / 0.3 ms | 56 / 0.4 | 66 / 0.3 | 7 / 0.4 |
| the pack's `_pack_setup`, whole | 2140 to 2515 ms | 3550 to 4314 | 2064 to 2081 | 19 |
| of it: `_build_nature` (the scattered forest) | 1076 | 2286 | 819 | |
| of it: `_build_terrain` (grid, near mesh, collision patch, far mesh) | 783 | 1099 | 1011 | |
| of it: walls, props, actors, road (everything a game touches) | 230 | 92 | 106 | |
| of it: building the ArrayMeshes (of that: content hashes) | 64 (31) | 53 (27) | 71 (40) | |
| laws on the finished tree | 0.3 | 0.1 | 0.3 | 1.0 |
| the bot (script and setup) | 3 | 4 | 4 | 2 |
| the first world iteration (first physics step), 8 packs | 25 ms in all | | | |

- **It is the scenery.** 85 to 95 % of a seed's loading is the terrain and the forest around the plot, generated
  triangle by triangle in GDScript, per pack. Scripts, laws, the bot and the first physics step are nothing.
- **Nothing is shared**: the second copy of the same seed takes as long as the first.
- **The simulation does not need it.** Scratch copies of the three seeds with `forest.scatter` off load in 0.9 to
  1.2 s, with `terrain.far` off as well in 0.4 to 0.7 s, and end in the same bot hashes (cadd1cd9, 36635c04,
  6366b88f).
- **Fixed here, the cheap part**: the world option `--scenery=plot` (walk script key `"scenery": "plot"`). The kernel
  hands a `tl.layout/1` file to the pack with both switches off. Three seeds by bot: loaded in 2.1 s instead of
  9.7 s, same hashes; 60 packs in 26 s instead of 122 s. Default is still `full`: whether a pack in a world should
  bring its own forest and far hills at all is a question for whoever draws the world (plots stand 60 m apart; a
  seed scatters forest over 400 x 380 m).
- **Not fixed** (kit code, outside this builder's scope; `PATCHES-N5A.md` entry 3): a cache of the scatter
  prototypes and of the terrain grid (would make the second copy of a seed cheap), and building the scenery after
  the bodies, a piece per frame (would take the 0.4 to 1 s that is left out of the blocking call). Loading itself is
  still one blocking call per pack: a pack coming back from `ledger` stops the world for as long as it takes.

## The world file (item 5)

`tl.world/1`, written by `world.sh save <file> ...` (or `--save=<file>` on any world run):

```
{schema, name, rev, device, seed,
 plots: [{id, origin: [x, y, z], yaw, footprint, pack: {dir, uid, version, hash}, seed, ticks, summary, data?}],
 player: {plot, position: [x, y, z]}}
```

- `pack.dir` is what is loaded today; `uid` (the manifest id), `version` and `hash` (SHA-256 over the pack's files)
  are written and the hash is checked on load (a changed pack is reported as an error line, and still loaded).
  Loading by `uid` from a library is not built.
- `ticks` is the plot's lifetime count. `summary` is `{ticks, over, phase, score, clock, clock_frames, winner?}`,
  the last five from the pack's `TLRules` when it has one. `data` is what `_pack_save()` returned.
- **Saving**: the whole file goes to `<file>.tmp`, is read back and parsed, the file that was there is copied to
  `<file>.prev`, then the temporary file is renamed over it. `rev` is the old file's `rev` + 1.
- **Loading rebuilds every pack from its seed. Its live state is not restored.** Bodies, positions, velocities and
  the pack's own variables start as on the first tick; the pack's own clock (`frame`) starts at 0. What comes back:
  the plot, the seed, the lifetime tick count, the summary, and whatever the pack takes from `_pack_load(data)`.
- A file that is not whole JSON, or not a `tl.world/1` file, is refused: exit code 2, one readable line, nothing
  loaded, the file left as it is, and the line names `<file>.prev` when there is one.
- `ledger` is the same path: `unload()` keeps the same plot record (ticks, summary, data) in memory instead of in a
  file, and the pack is rebuilt from it.

Checked (`tl.sh selftest world.file`, and by hand):

```
bash tools/world.sh save w.json --packs=ex_bounce,pack_min,ex_wall --mode=bot --frames=300 --plot-spacing=60
  plot p0: pack example.bounce seed 1 origin [0.0,0.0,0.0] ticks 241
  plot p1: pack example.pack_min seed 1 origin [60.0,0.0,0.0] ticks 228
  plot p2: pack example.wall seed 1 origin [120.0,0.0,0.0] ticks 300
bash tools/world.sh load w.json                    # the same three lines
bash tools/world.sh load w.json --frames=50 --save=w.json     # rev 2, ticks 291 / 278 / 350; w.json.prev is rev 1
head -c 700 w.json > cut.json; cp cut.json w.json; bash tools/world.sh load w.json
  world.sh: "world file .../w.json is not a whole JSON object (700 bytes, line 36: Unterminated string). It looks
  cut short. Nothing was loaded and the file was left as it is. The revision before it is intact at .../w.json.prev."
  (exit code 2; w.json byte for byte as it was; `world.sh load w.json.prev` gives the first three lines)
```

Note `--plot-spacing`, not `--spacing`: N2's `--spacing` and `--at` move the SIMULATION (its way a), which changes
the game (pack_min's bot is "past the finish line" at tick 1 when the pack stands at x = 60).

## Not built, not verified

- Anything with a window. The distances in tiers.json are first values; nobody has looked at a far game.
- The watchdog: a runaway `_pack_tick` still hangs the whole world.
- Routing the player's real input to the stage pack: in a headless walk the bot (or nobody) plays every pack. So
  `on_leave: bot` changes nothing in these runs; `pause` and `end` are real.
- A game that ended by itself stays ended (`over`); starting the next round is not built.
- `ledger` promotion blocks the world while the pack is rebuilt (0.4 to 4 s for a seed).
- Tickets come from the walk script only; there is no call for a pack or the player to ask for one.
- `world.sh bench` (N2's 23-minute bench) was not run again on these files; its hash tests are covered by the
  selftest cases `world.same` and `world.sliced_and_paused`, which pass.
- The asleep figures and every other timing: under load, two runs at most.

## N7: what changed in the scheduler

- **A visitor** (walk script `"visitor": true`, WORLD.md): rule 1 is replaced. The stage does not follow the
  player's position; it follows his requests: `enter` (he must stand inside the plot, within `margin_m.stage`) and
  `leave`, from the walk's `events` or from `request()`. A request that cannot be met is logged as `refused`. A plot
  that is left goes to `sideline` and gets its `leave` event with its `on_leave`, as before.
- **Next round** (visitor worlds only): a plot whose game is `over`, that is not on stage, not held, not `ledger` and
  not `on_leave: end`, gets a `restart` event `restart_pause_ticks` after it ended or was left. **Paused by the owner on 2026-11-11:
  `tiers.json` now ships 0, so a finished game stays over.** The mechanism stays in the code, untested by the selftest.
- **A rebuilt pack rests one tick** (every world): `restart`, and a `tier` event from `ledger`, set `rest_until =
  t + 1`; `due` skips the plot on tick `t`. Reason: the rebuild runs inside the world's `_physics_process`, the new
  nodes are not ticked by the scene tree in that frame, but the kernel's calls and the physics step would run. Seen
  as three different hashes in the first headless tour (packs with self-ticking nodes: bipeds, vehicles). The
  proofs `ledger`, `leave` and `tickets` were not re-run after this change.
- `scenery = "plot"` is the world host's default; `world.sh proof` and `tour` share one table (`prove` in world.sh).

## P5: loading is not simulation (the build queue)

Code: `kernel/world/jobs.gd` (the queue), `tiers.gd` (`unbuilt`, the events `built` and `reload`), `world.gd` (the
hooks), `pack.gd` (`stub`), `kits/tl_kit_layout.gd` (`build_ahead`), `draw/view.gd` (plots without a pack, the rim
cache), `tiers.json` `load`. Walks: `walks/walk30.json`. Selftest: `world.reload`.

### Where a load goes (measured before anything was changed; 11 November 13:24, headless, scenery plot)

| part | seed_drive | seed_wall | seed_paddle | hockey | ex_bounce | where it may run |
|---|---|---|---|---|---|---|
| the entry script, first time in the process / later | 342 / 0.2 ms | 31 / 0.2 | 24 / 0.2 | 28 / 0.1 | 14 / 0.2 | a worker thread (`load`) |
| `_pack_setup`, whole | 358 | 371 | 413 | 771 | 1.5 | |
| of it: `TLKit.build_layout` (the venue: meshes, bodies, rigs of the layout) | 354 | 274 | 398 | 18 + 155 | none | a worker thread: it builds off the scene tree and the kit references nothing outside itself |
| of it: the rest (bodies, rigs and parts the pack makes itself, HUD, cameras) | 4 | 97 | 15 | about 600 | 1.5 | the main thread only: `TLContext.current` is one static, `_ready` and the physics space need the tree |
| attaching a built venue to the tree (its bodies enter the space) | 13 to 23 | 13 | 13 to 14 | 0.1 | | the main thread; one call, not sliced |
| the laws on the finished tree | 0.1 | 0.2 | 0.3 | 0.2 | 0.04 | main thread |
| the first physics steps after the attach (two) | 0.1 | 0.15 | 0.13 | 0.03 | | main thread |

First draw: the first drawn frame of a world costs 52 to 55 ms (every pipeline, with the landscape). The frame in which
a pack arrives costs its attach; nothing above the run-to-run noise was seen on top of it (no quiet run: see below).

The worker-thread build of a layout was compared with the main-thread build of the same file: the same counts of
nodes, bodies and mesh instances, the same `Static` mesh hash, no error, 5 to 35 % slower, the main thread running on.

### What the queue does

A pack of a scheduled world is built in two halves. PREPARE, on the queue's one worker thread: every script of the pack
is loaded and every `tl.layout/1` file under its `data/` is built ahead (`TLKit.build_layout_ahead`; the result waits
under the hash of the layout's JSON text). ATTACH, on the main thread at a tick boundary: the holder, `_pack_setup`
(whose `build_layout` finds the venue built ahead and only attaches it), the laws. Until then the plot holds a STUB
(`pack.gd` `stub`: directory, manifest, plot record; for everything else a pack in the ledger).

- **Order**: tier first (stage, sideline, backdrop), then distance to the player. A plot in `ledger` is not built; a
  job whose plot goes to the ledger is dropped and what was built ahead for it is freed.
- **The scheduler** treats a pack that has not arrived as not there: a plot is `unbuilt` from the start, after
  `restart`, after `reload` and after a return from the ledger, until its `built` event; `due` leaves it out. Tiers,
  the valve and the budget do not look at it, so the tier log of a walk is what it was, plus the `built` lines.
- **The log says when it arrived**: `{"t": N, "e": "built", "plot": id}`. The pack's first tick is N + 1 (the one-tick
  rest of N7). A replay attaches at the same tick: when the worker is not done it waits for it.
- **Rebuild, next round, back from the ledger** go through the same queue. The pack that is over stays (and stays
  drawn) until the new one is attached.
- **Modes** (`tiers.json` `load.mode`, a walk's `tiers.load.mode`, `TL_WORLD_LOAD` for a window): `queue` attaches
  what is ready, at least one pack per tick, more while this tick's attaches used less than `load.budget_ms` (4);
  `step` builds one pack per world tick in queue order, whole, on the main thread (the worker would only be waited
  for), so the arrival ticks are a pure function of the walk (time is physics frames: scripted runs without a window)
  and a run costs what it did before; `wait` is `step` with the worker's prepare, waited for (the selftest case
  `world.queue`: a run without a window is over before a worker is done); `auto` (shipped) is `queue` in a window and
  `step` without one. What a `step`, `wait` or replayed tick spends on a build is taken out of the tick's time and
  counted as `load_ms`; `block` makes no queue (every pack before the first tick, no `built` events: as before P5).
  The mode a run used is in its log, so a windowed run replays headless.
- **Reload** (`{"t": N, "e": "reload", "plot": id}` in a walk's `events`): the plot's pack is replaced by a freshly
  loaded copy of the same directory; what the pack saves itself (`_pack_save`) is handed on, its tick count goes on.
  A walk's `edits` (`[[tick, file, replacement file]]`) copies a file at a world tick: a scripted "the designer saved a
  tuned value". Changed `data/*.json` takes effect; a changed `.gd` does not (the engine's script cache: `PATCHES-P5.md`
  entry 2b).

### What it buys, and what still stands in the way (11 November, 13:40 to 14:00; four other builders on the machine, no run was quiet)

| | before | after |
|---|---|---|
| in a window: world start to the first tick, six games (`load_ms`, tour) | 1.7 to 1.9 s | 15 to 25 ms |
| in a window: world start to the first drawn frame, six games (one run each, machine busy) | 5.8 s | 2.3 s, of it the landscape 2.1 s |
| in a window: the same, thirty games (`walk30`) | 15.7 s | 6.4 s, of it the landscape 6.1 s |
| without a window (`step`): loading, 30 games (`mix30` `load_ms`, machine busy) | 9.8 to 15.8 s before the first tick | 16.2 s, one pack per tick over the first 30 ticks: the same work, not a saving |
| the frame in which a seed arrives or is rebuilt | 762 to 921 ms | 17 to 37 ms (drive, paddle, car), 75 to 120 ms (wall) |
| the frame in which `ex_walker` / `ex_kit` arrives | 165 / 190 ms | the same: no layout, all of it is `_pack_setup` on the main thread |
| the frame in which the hockey game arrives | about 770 ms | about 600 ms: six skaters' rigs and its own parts |
| the frame of a `shot` (a 1920x1080 PNG) | 690 to 850 ms | not a slow frame: the PNG is encoded on a worker thread |
| the tour's hashes | | tour = alone = replay, in a window with real arrivals (ticks 73 to 572 in different runs) and headless |
| `tl perf run`, tour6 (ledger line 7, machine BUSY) | worst frame 762 to 838 ms (quiet) | worst frame 286 ms, frame p99 10.4 ms |
| `tl perf run`, walk30 (ledger line 7, machine BUSY) | did not exist | worst frame 359 ms, frame p99 7.6 ms, tick p50 2.9 ms, six games built 8.0 s after the world started |

- **Not hitch-free.** The half that is left on the main thread is over a frame for every pack measured: the attach of
  a venue's bodies (13 to 23 ms in one call) and everything a pack builds outside its layout. `PATCHES-P5.md` entries
  2a and 5 say what it takes (a thread-local `TLContext.current`, rigs built ahead).
- **The worker waits for the main thread.** A call from the worker into the rendering or physics server that returns
  a value is run by the main thread, once per frame. In a window a prepare took 0.65 to 1.1 s instead of 0.4 s (a
  few hundred frames at 2 to 3 ms); at 60 frames per second with vertical sync it would be seconds. A main thread that
  only sleeps while it waits for the worker waits for ever: `jobs.gd` `attach` flushes both servers in its wait loop.
- **A plot's rim is needed before the landscape is built** (the hole for a pack's own ground, the lift). `view.gd`
  keeps a rim cache (`user://tl_cache/rims.json`, keyed by the pack directory's content hash, the radius and the
  scenery); a pack whose rim is not in it is built before the first frame, once per machine (`TL_RIM_CACHE=off`
  measures again).
- **The time to the first frame is now the landscape**: 1.3 to 1.4 s for the six-game village, 3.8 s for thirty.

## P12: a game arrives without a hitch, second half

### What one arrival costs the main thread (item 1)

Measured with `kernel/world/arrival_probe.gd` (headless, scenery `plot`, output to a file: `print` into a pipe costs up
to 15 ms a line and spoiled the first readings). The probe does what the queue does: PREPARE on a worker, waited for,
then the holder and `load_pack` on the main thread. Milliseconds of the main-thread half; a second arrival of the same
pack in the same process in brackets. The machine was busy (other builders, another project's window): not quiet.

| game | before P12: whole | rigs | parts outside a layout | layout attach | rest (own bodies, HUD, laws, tree) | after P12: whole, first arrival ever | after, recipe known |
|---|---|---|---|---|---|---|---|
| seed_drive | 28.6 (26.4) | 6.1 | 0 | 17.0 | 5.5 | 72 | 29 (26) |
| seed_wall | 70.3 (78.3) | 48.3 | 5.7 | 13.4 | 2.9 | 90 | 22 to 29 |
| ex_walker | 146.8 (140.2) | 101.3 | 0 | 0 | 45.5 | 139 | 1.7 (2.0) |
| seed_paddle | 16.2 (19.7) | 0 | 0 | 13.8 | 2.4 | 20.5 | 19.0 (19.4) |
| ex_kit | 211.8 (224.4) | 133.6 | 18.3 | 0 | 59.9 | 231 | 3.0 |
| ex_car | 19.2 (15.8) | 16.6 | 0 | 0 | 2.6 | 25.5 | 2.9 (2.6) |
| hockey 0.1.1 | 594.6 (618.1) | 311.9 | 0.3 | 0.6 | 281.8 | 618 | 11.5 (8.3) |

The split into rigs, parts and layout was taken with timers inside `TLRigs.build`, `TLKit.build` and
`TLKitLayout.build`; they were removed again (kit, rigs and style may not read a clock: kit.selftest). On the final
code, without them (17:38, busy, recipe known): seed_drive 20 to 31 ms, seed_wall 17 to 19, ex_walker 1.8,
seed_paddle 23 to 29, ex_kit 4.0 to 4.4, ex_car 2.8 to 3.4, hockey 6.5 to 6.7.

What was in the rows:
- **rigs**: `TLRigs.build` on the main thread. Now built ahead on the queue's worker from a recipe: each attach records
  the pack's `TLRigs.build` and outermost `TLKit.build` calls (`TLRigs.record`, `TLKit.record`), `jobs.gd` keeps them
  in the process and in `user://tl_cache/rigs/<md5 of the directory>.txt`, and the next preparation of that directory
  builds them ahead (`TLRigs.build_ahead`, `TLKit.build_ahead`); `build` with equal params takes one. The first arrival
  ever of a pack on a machine has no recipe and pays as before.
- **rest of ex_walker, ex_kit and hockey (45, 60, 282 ms)**: every TLBiped in `skate` mode rebuilt its rig's whole
  skinned mesh at `_ready` (the rig was built in `walk` and the helmet came with `skate`), about 50 ms a skater.
  `TLBiped.create` now builds the rig in the controller's mode. Hashes unchanged (P7 table, all 24 runs).
- **layout attach (13 to 23 ms)**: adding a venue that was built ahead to the scene tree. Still on the main thread; it
  is what is left of a seed's arrival.

### The queue and the frame rate (item 2)

`kernel/world/jobs_probe.gd` prepares one pack on a worker while the main thread holds frames of a fixed length.
Before P12 the preparation took about 20 frames whatever their length: seed_paddle 621 ms with free frames and 4517 ms
with 250 ms frames, seed_wall 744 / 5034 ms. The waiting calls were `ArrayMesh.surface_get_arrays` in `TLMesh.merge`
(a value-returning call of the renderer; on a worker it waits for the main thread's next frame). After P12:
seed_paddle 549 / 507 ms, seed_wall 547 / 478 ms, seed_drive 532 / 541 ms. Selftest `world.prepare_capped`.

A game that is needed is there: in `queue` mode a plot on `stage` that is not built yet is built at once (the main
thread blocks for it) and on the walk's last tick every game still wanted is built. Each is an ordinary `built` event
(a replay does the same), counted in the world line's `load.forced`, `forced_ms` and `forced_list`. Selftest
`world.needed_now`. `step` and `wait` need no such rule: their arrival ticks are fixed by the walk.

### Asleep packs (item 5)

`world.sh bench --only=asleep`, 60 copies of `w_pile` (2100 bodies, all asleep), median iteration of the last third,
interleaved on a busy machine: before 1.259 and 1.177 ms, after 0.992 and 0.991 ms. The tracker's pass does the asleep
body's case of `TLContact._step` inline: the same two reads (`sleeping`, `linear_velocity`) in the same order, no
function call per body. No rule about who woke a body changed: a body woken by the pack itself (`apply_impulse`) is
read exactly as before, so every hash stays (P7 table, 26 runs). The skip of a whole asleep pack (P2, withdrawn)
was not brought back.

### Windowed figures on the final code (busy: other builders' and another project's windows were open)

| run | worst frame | frames over 16.7 ms | frame p99 | slowest arrival's attach |
|---|---|---|---|---|
| `world.sh tour walk30 --pictures-only` at 1920,1440 (17:10) | 295 ms (P5: 359) | 22 of 12,000 | 9.4 ms | 150 ms (layout seeds) |
| `world.sh tour tour` with its proof at 1920,1440 (17:19) | 214 ms | 10 | 9.7 ms | 141 ms (seed_wall) |

The slow frames are the arrivals of the layout seeds. The pack's own part of them is 19 to 30 ms in a window; the
rest is what the view does on the `rebuilt` event (PATCHES-P12 entry 6).
