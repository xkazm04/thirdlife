# N2 bench: several packs in one process

Written by `bash tools/world.sh bench` (kernel/world/bench.gd) on 2026-11-11 00:31:14. Godot 4.7.2-stable (official), Jolt, 60 Hz, headless, AMD Ryzen 7 7800X3D 8-Core Processor.
Every figure is from a fresh process started with the command printed under its table; nothing here is
estimated. Times are medians of one whole loop iteration (kernel calls into the packs, the scene tree's tick
of their nodes, the step of every active physics space); timed runs are taken twice and the lower median
is kept (the higher one is shown as "worst"), because other processes were using this machine.

An empty world (no pack) costs 0.0020 ms per iteration; it is subtracted where a per-pack cost is given.

## Cost per pack per tick (every pack ticked on every world tick)

Each seed is played by its own bot for 400 ticks; k copies run in one process, each in its own space.

| packs | what | iteration ms (median) | worst of two | ms per pack | packs inside 2 ms | packs inside 16.7 ms |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | seed_wall | 0.412 | 0.458 | 0.410 | 4 | 40 |
| 5 | seed_wall | 1.629 | 1.918 | 0.325 | 6 | 51 |
| 10 | seed_wall | 3.281 | 3.353 | 0.328 | 6 | 50 |
| 20 | seed_wall | 7.258 | 7.736 | 0.363 | 5 | 46 |
| 1 | seed_drive | 0.823 | 0.829 | 0.821 | 2 | 20 |
| 5 | seed_drive | 3.240 | 3.410 | 0.648 | 3 | 25 |
| 10 | seed_drive | 5.970 | 6.700 | 0.597 | 3 | 27 |
| 20 | seed_drive | 13.509 | 28.306 | 0.675 | 2 | 24 |
| 1 | seed_paddle | 0.275 | 0.280 | 0.273 | 7 | 61 |
| 5 | seed_paddle | 1.148 | 1.258 | 0.229 | 8 | 72 |
| 10 | seed_paddle | 1.944 | 2.016 | 0.194 | 10 | 85 |
| 20 | seed_paddle | 3.791 | 4.013 | 0.189 | 10 | 88 |
| 20 | 7 wall + 7 drive + 6 paddle | 10.099 | 15.098 | 0.505 | 3 | 33 |

`bash tools/world.sh run --packs=<7 x seed_wall, 7 x seed_drive, 6 x seed_paddle> --mode=bot --frames=400`

The last two columns divide a budget by the per-pack cost: how many such packs can be ticked on every world
tick. 2 ms is the project's physics target, 16.7 ms a whole 60 Hz frame with nothing drawn (headless).

## Test 1: active bodies in one space

The bench pack `w_pile` (kernel/world/packs/w_pile; the seed is the body count) keeps N wooden boxes awake by
throwing some of them every fourth tick. Every box comes from `TLBodies.make`, so each carries the kernel's
contact tracker (a GDScript `_physics_process` with a ray query), like every dynamic body of a real pack.

| bodies | awake at end | iteration ms (median) | worst of two | kernel calls ms | inside the 2 ms target | inside the 8 ms V3 budget |
| --- | --- | --- | --- | --- | --- | --- |
| 50 | 39 | 0.641 | 0.660 | 0.016 | yes | yes |
| 150 | 116 | 1.738 | 1.855 | 0.016 | yes | yes |
| 300 | 267 | 3.781 | 3.845 | 0.018 | NO | yes |
| 600 | 554 | 7.454 | 7.688 | 0.024 | NO | yes |

`bash tools/world.sh run --packs=w_pile --seeds=600 --frames=400`

One or several worker threads was not varied (the project setting was left as it is).

## Tests 2 and 3: packs asleep, and packs switched off

k copies of `w_pile` with seed 10030: 30 boxes that are left alone, settle and fall asleep. 900 ticks with
every space active and every pack ticked (the figure is the median of the last third, when all are asleep),
then 300 world ticks with every pack switched off (holder disabled, space inactive).

| packs | bodies in all | awake at end | asleep, ticked: iteration ms | per pack ms | switched off: iteration ms | per pack ms | static memory per pack (kB) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 10 | 350 | 0 | 2.005 | 0.2003 | 0.0140 | 0.00120 | 1210 |
| 30 | 1050 | 0 | 6.088 | 0.2029 | 0.0320 | 0.00100 | 1086 |
| 60 | 2100 | 0 | 13.848 | 0.2308 | 0.0560 | 0.00090 | 1058 |

`bash tools/world.sh run --packs=<60 x w_pile> --seeds=10030 --frames=900 --hold=300`

Static memory is Godot's own allocator (`OS.get_static_memory_usage`) after loading, divided by the packs; it
does not include what Jolt allocates for a space, and the OS working set was not read. `max_bodies` was left
at the project default.

## Test 4: a pack's hash against its neighbours

| run | packs in the process (each in its own space, all at the origin) | seed_wall | seed_drive | seed_paddle | verdict |
| --- | --- | --- | --- | --- | --- |
| alone | one process each | 6366b88f838e3e78 | 36635c049bc6acd8 | cadd1cd9fffac7b1 | the reference |
| 1 | seed_wall, seed_drive, seed_paddle | 6366b88f838e3e78 | 36635c049bc6acd8 | cadd1cd9fffac7b1 | same |
| 1 | seed_paddle, seed_drive, seed_wall | 6366b88f838e3e78 | 36635c049bc6acd8 | cadd1cd9fffac7b1 | same |
| 1 | seed_drive, seed_wall, seed_wall, seed_paddle, seed_wall | 6366b88f838e3e78 | 36635c049bc6acd8 | cadd1cd9fffac7b1 | same |
| 2 | seed_wall, seed_drive, seed_paddle | 6366b88f838e3e78 | 36635c049bc6acd8 | cadd1cd9fffac7b1 | same |
| 2 | seed_paddle, seed_drive, seed_wall | 6366b88f838e3e78 | 36635c049bc6acd8 | cadd1cd9fffac7b1 | same |
| 2 | seed_drive, seed_wall, seed_wall, seed_paddle, seed_wall | 6366b88f838e3e78 | 36635c049bc6acd8 | cadd1cd9fffac7b1 | same |
| 3 | seed_wall, seed_drive, seed_paddle | 6366b88f838e3e78 | 36635c049bc6acd8 | cadd1cd9fffac7b1 | same |
| 3 | seed_paddle, seed_drive, seed_wall | 6366b88f838e3e78 | 36635c049bc6acd8 | cadd1cd9fffac7b1 | same |
| 3 | seed_drive, seed_wall, seed_wall, seed_paddle, seed_wall | 6366b88f838e3e78 | 36635c049bc6acd8 | cadd1cd9fffac7b1 | same |

`bash tools/world.sh run --packs=seed_drive,seed_wall,seed_wall,seed_paddle,seed_wall --mode=bot --frames=36000`

Bot runs to the end of each bot (wall 1221 ticks, drive 3516, paddle 6776). Every hash equals the solo hash in every run: a pack in its own space does not feel its neighbours, whatever the order they were added in.
The table's 20 runs and the varied job-thread count were not done: 3 runs per order here.

| ex_bounce at the origin | state hash | against its own-space run |
| --- | --- | --- |
| alone, own space, idle | 7bb3aefa5eae9953 | the reference (idle) |
| alone, the shared default space, idle | 7bb3aefa5eae9953 | same |
| alone, own space, bot | d27b4ef860ebf000 | the reference (bot) |
| shared space, seed_wall (bot) 300 m away, added after | 3bbf7c20136b9aa7 | DIFFERENT |
| shared space, seed_wall (bot) 300 m away, added before | 3bbf7c20136b9aa7 | DIFFERENT |

`bash tools/world.sh run --packs=seed_wall,ex_bounce --frames=1800 --space=shared --at=300:0:0,0:0:0 --mode=bot`


## Test 5: a pack away from the origin

Way (a): the pack's holder stands at the offset, so its bodies are simulated at their world position inside
the pack's own space; the hash is taken relative to the holder. Way (b) is the row at 0, 0, 0: bodies at the
pack-local origin (in every other table of this file all packs stand at the origin of their own space, on top
of each other, and do not meet). Each cell: `same` when the hash equals the origin's, else where the hash trace
(every 60 ticks) first differs.

`w_pile` has no world coordinate in its code (it places boxes with `position` and its state is three counts),
so its two columns show the arithmetic alone: 300 boxes kept awake, and 100 boxes left to fall asleep.

| offset (m) | w_pile, 300 awake | w_pile, 100 asleep | ex_bounce | ex_wall | ex_car | ex_walker | ex_slide | seed_wall | seed_drive | seed_paddle |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0, 0, 0 | 0ad08385 | cddf2315 | d27b4ef8 | 477b7e7b | 9f4e65da | 8d1831dc | 85bd1392 | 6366b88f | 36635c04 | cadd1cd9 |
| 64, 0, 0 | differs by tick 60 | differs by tick 60 | differs by tick 60 | differs by tick 60; BOT FAILS | differs by tick 0; BOT FAILS | differs by tick 300 | differs by tick 0 | differs by tick 0 | differs by tick 0; BOT FAILS | differs by tick 0; BOT FAILS |
| 1000, 0, 0 | differs by tick 0 | same | differs by tick 60 | differs by tick 60; BOT FAILS | differs by tick 0; BOT FAILS | differs by tick 240 | differs by tick 0 | differs by tick 0 | differs by tick 0; BOT FAILS | differs by tick 0; BOT FAILS |
| 2000, 0, 3000 | differs by tick 0 | differs by tick 0 | differs by tick 60 | differs by tick 60; BOT FAILS | differs by tick 0; BOT FAILS | differs by tick 0 | differs by tick 0 | differs by tick 0 | differs by tick 0; BOT FAILS | differs by tick 0; BOT FAILS |
| 4000, 0, 4000 | differs by tick 0 | differs by tick 0 | differs by tick 60 | differs by tick 60; BOT FAILS | differs by tick 0; BOT FAILS | differs by tick 0 | differs by tick 0 | differs by tick 0 | differs by tick 0; BOT FAILS | differs by tick 0; BOT FAILS |
| 10000, 0, 0 | differs by tick 0 | differs by tick 0 | differs by tick 60 | differs by tick 60; BOT FAILS | differs by tick 0; BOT FAILS | differs by tick 300 | differs by tick 0 | differs by tick 0 | differs by tick 0; BOT FAILS | differs by tick 0; BOT FAILS |

`bash tools/world.sh run --packs=w_pile,w_pile,ex_bounce,ex_wall,ex_car,ex_walker,ex_slide,seed_wall,seed_drive,seed_paddle --mode=bot --frames=7200 --at=10000:0:0 --trace=60 --seeds=300,10100,1`

Reading the table. The `w_pile` columns are rounding and nothing else: single-precision positions are coarser
away from the origin, a contact resolves a hair differently, and a pile of boxes amplifies it. "By tick 0" in
those columns means that even the starting positions no longer round to the same millimetre. The other
columns mix that with a second cause: the pack's own code reads world coordinates (`global_position` in
`_pack_state`, in its bot, or a literal position handed to a call that wants a world position). Where it says
BOT FAILS the game itself went wrong: the bot, which plays from `_pack_state`, could not finish.

This section was measured again at 01:00 with the two `w_pile` columns added (7 more world processes, 146 s);
the other eight columns came out as in the first pass.

## Test 6: pause and resume

Each pack is played by its bot; at world tick 300 (bodies awake, mid-play) it is switched off for M world ticks
(holder `PROCESS_MODE_DISABLED`, `space_set_active(false)`), then switched on again and played to the end.
`w_pile` (seed 10100, 100 boxes left alone, 900 ticks, nobody playing) is switched off at tick 700, asleep.

| off for M world ticks | seed_wall | seed_drive | seed_paddle | ex_bounce | ex_wall | w_pile (asleep) |
| --- | --- | --- | --- | --- | --- | --- |
| 0 (uninterrupted) | 6366b88f838e3e78 | 36635c049bc6acd8 | cadd1cd9fffac7b1 | d27b4ef860ebf000 | 477b7e7bd2bc7679 | cddf23155ea6c59c |
| 1 | same | same | same | same | same | same |
| 60 | same | same | same | same | same | same |
| 3600 | same | same | same | same | same | same |

`bash tools/world.sh run --packs=seed_wall,seed_drive,seed_paddle,ex_bounce,ex_wall --mode=bot --frames=36000 '--pause=0:300:3600;1:300:3600;2:300:3600;3:300:3600;4:300:3600'`

Switching a pack off and on again is an exact pause here: every hash equals the uninterrupted run's. The variant that restores transforms and velocities by hand was not built.

## Test 7: a pack that gets one world tick in N

The same packs and bots; every pack is ticked (and its space stepped) on one world tick in N and switched
off on the others, until it has had as many ticks of its own as the continuous run. `ex_bounce` has a
trigger (area signals), a spawner (bodies added while running) and rules; the bots read the HUD and audio.

| N | seed_wall | seed_drive | seed_paddle | ex_bounce | ex_wall | world ticks | iteration ms (median over all world ticks) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 (continuous) | 6366b88f838e3e78 | 36635c049bc6acd8 | cadd1cd9fffac7b1 | d27b4ef860ebf000 | 477b7e7bd2bc7679 | 6776 | 0.888 |
| 2 | same | same | same | same | same | 13551 | 0.209 |
| 8 | same | same | same | same | same | 54201 | 0.011 |
| 30 | same | same | same | same | same | 203251 | 0.010 |

`bash tools/world.sh run --packs=seed_wall,seed_drive,seed_paddle,ex_bounce,ex_wall --mode=bot --frames=36000 --every=30`

"same" means: the same state hash, the same number of pack ticks to the bot's end, and the same number of
recorded sounds. A pack given fewer world ticks runs the same game, later.

## Tests 8 and 9: script gating and engine warnings, over all 73 runs above

Every pack holder carries a probe: a script node in the pack's subtree, ticked by the scene tree like any
script of the pack (`_physics_process` and `_process`). It counts a leak when it runs on a world tick its pack
did not get, and a wrong-pack call when `TLContext.current` is not its own pack while it runs.

| check | result |
| --- | --- |
| probe calls on a tick the pack did not get | 0 |
| probe calls with another pack as "the pack being called" | 0 |
| probe `_physics_process` calls / pack ticks | 587904 / 588018 (a bot run ends inside its last tick, before the tree ticks: one less per bot run) |
| engine warnings about dropped contacts, body pairs or the body limit | 0 |
| script and engine errors logged | 0 |
| other engine warnings (distinct texts) | none |


73 world processes, 1393 s.

## What the numbers mean (written by the builder, not by `world.sh bench`; a re-run of the bench overwrites it)

**How many games at full speed.** On this machine (Ryzen 7 7800X3D, headless, nothing drawn) a seed pack that is
being played costs 0.19 to 0.82 ms per tick, and the cost adds up almost linearly: 20 mixed seeds cost 10.1 ms.

| budget for all simulation | packs ticked on every world tick (mixed seeds, 0.5 ms each) |
| --- | --- |
| 2 ms (the project's physics target) | 3 (2 `seed_drive`, 5 `seed_wall` or 10 `seed_paddle`) |
| 8 ms (half a 60 Hz frame, the rest left for drawing) | 15 |
| 16.7 ms (a whole frame, nothing drawn) | 33 |

One pack at the entity budget does not fit the 2 ms target at all: 600 awake bodies cost 7.5 ms, 300 cost 3.8 ms,
150 cost 1.7 ms. That is about 12 microseconds per awake body per tick, and at least half of it is not Jolt: every
dynamic body carries a `TLContact` whose `_physics_process` runs in GDScript every tick (about 7 microseconds per
body, from the sleeping-body experiment at the end of this file).

**Asleep is not cheap here; switched off is free.** 60 packs of 30 sleeping boxes cost 13.8 ms per tick (0.23 ms
per pack) while their spaces are active and their holders enabled. The report's pass line was 0.2 ms for all 60.
The same 60 packs switched off (`set_running(false)`) cost 0.056 ms in all, under a microsecond each. So the cost
ladder of the layering model holds only if "not on stage" means switched off between slices, not "asleep".

**The research was right about the clock and about isolation, measured:**
- deactivating a space together with its holder is an exact pause (1, 60 and 3600 ticks, mid-play and asleep);
- one world tick in N at an unchanged delta is the same game, later (N of 2, 8, 30; same hash, same tick count
  to the bot's end, same number of sounds);
- a pack in its own space does not feel its neighbours (three orders, three runs each), while in ONE shared
  space a neighbour 300 m away did change a pack's hash (one run in each order; the cause was not isolated);
- no script of a pack ran on a tick its pack did not get: 0 of 588,018 pack ticks.

**The research was too kind about offsets.** It expected trouble at kilometres. A pack simulated 64 m from the
origin already hashes differently within 60 ticks, and at 1 km its starting positions round to another
millimetre. Way (a) cannot keep a pack comparable with its verified run; a pack has to be simulated at its own
origin (way b).

## Measured by hand, outside `world.sh bench`

**Loading.** `bash tools/world.sh run --packs=<pack> --frames=2`, field `load_ms`: seed_wall 2.1 s on a quiet
machine (2.9 s under load), seed_paddle 4.1 s and seed_drive 5.6 s under load; 20 mixed seeds 65 s, about 3.3 s
each, all in one blocking call. Godot's static memory after loading: 18 to 24 MB per seed pack (Jolt's own
allocations and the OS working set were not read). Loading, not ticking, is why the full bench takes 23 minutes.

**The sleeping-body experiment (not kept in the code).** With three lines at the top of
`TLContact._physics_process` (`if body.sleeping:` / `_prev_velocity = body.linear_velocity` / `return`),
`bash tools/world.sh run --packs=w_pile --seeds=10300 --frames=900` (300 boxes asleep) went from 2.21 ms to
0.16 ms per tick (`iter_ms_p50_last_third`), and the eleven hashes compared did not change (the three seeds idle
and played by their bots, `ex_bounce` idle and by bot, `ex_wall` by bot, `w_pile`). `kernel/api/tl_contact.gd` was
restored byte for byte afterwards; the full gates were not run on the change.
