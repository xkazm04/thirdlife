# P8: one game simulated in a second process

A spike, a measurement and a report (brief: `briefs/BRIEF-P8-PROCESS.md`). Nothing here is on the path a game runs
on. Companions: `CROSSING.md` (what crosses the boundary, class by class: the list for API v1), `RESTRICT.md` (taking
rights away from the process, on paper), `PATCHES-P8.md` (exact changes outside this folder, not applied),
`JOURNAL.md`. Tool: `engine/tools/proc.sh`. All figures: 2026-11-11, this machine, four other builders running the
engine at the same time (the gate reported a load of 12 to 15); no run was quiet, and none went through
`tl perf run` because no scenario for two processes exists.

## 1. The answer

**Can a pack run in a second, headless engine process while the first draws it and feeds it input, without the
pack's code knowing?** The simulation half: **yes, shown on four packs with no change to any of them.** The three
seeds and the hockey game were each played to the end by their bot in process S and drawn by process D; the state
hash in S equals the hash of the same run in one process, every time (section 2.1). The picture half: **yes when D
may run the pack's own setup code, not yet when it may not.** That difference is the whole result, so it comes first.

**How the picture is rebuilt.** Neither candidate of the brief works as written. A *recorded build list* has no
recorder: the kit does not log its calls. A *generic description sent by S* has nothing to describe: in a headless
process the style hands out one empty material for everything and the kit, the rigs and the effects skip their
looks, so S has the geometry and no picture. What the spike does instead is the build list at its coarsest grain: D
loads the same pack, runs its `_pack_setup` and `_pack_start` once in a window, switches every node of it off
(no tick, no bot, no physics step), and from then on follows S. That draws all four games correctly (captures in
section 2.6) and it is enough for **playing together with one machine as the authority**, where both machines have
the pack and trust it equally. It is **not a boundary for sharing**: a stranger's code still runs in the player's
own process, once. For that, D has to build from records instead of code, and the measurement says the records
nearly exist: of the nodes a pack has at its start, 83 to 95 % are a kit part or a rig (already tagged with the two
values that rebuild them) or a kernel object, and the rest are what `TLKit.build_layout` makes from a data file
the pack ships, plus the HUD's labels (section 2.5). In none of the four packs, the LLM-built hockey game included, did the pack's own script
make a visible node by hand.

**What it costs, per game**

| | measured |
|---|---|
| Delay from a key to the picture | **2 frames instead of 1** (33.4 ms against 17.4 to 17.7 ms; 12 of 12 presses, both ways, in two runs). The extra frame is one hop each way meeting a 60 Hz tick; the channel itself is 10 to 15 microseconds. |
| S, added work per tick | 0.13 to 0.34 ms flat out; paced at 60 Hz on the busy machine 0.21 to 0.56 ms at p50, means up to 0.92 ms (a GDScript walk over every 3D node of the pack, 163 to 364 of them), on top of a tick that takes 0.23 to 0.89 ms in one process |
| Data | 0.27 to 9.4 kB per tick (16 to 565 kB/s), 24 to 70 kB once at the start |
| D, work per drawn frame | 0.03 to 0.36 ms to apply a tick; D runs no script of the pack and no physics |
| Processor time, both processes against one | 1.0 to 1.9 times one windowed process (the machine's noise is as large as the effect); the second engine costs 1.3 to 3.5 ms a frame whatever the game (section 2.3) |
| Memory, start-up | 205 to 232 MB of engine memory where one process holds 115 to 126 MB; 6 to 10 s to the first picture where one process takes 3.4 to 5.7 s (section 2.4) |
| When S is slow or dies | D keeps its picture and its frame rate and says so (section 2.7) |
| The simulation | unchanged: equal hashes |

**What in the kernel API must change before a game can move** (detail and exact text in `CROSSING.md` and
`PATCHES-P8.md`). Seven things, none of them large, all cheaper now than after more games exist:

1. `ctx.headless` must stop meaning "this will not be seen". In S it is true, and it tells kit, rigs, effects and
   packs to skip the look. Looks must always be *asked for*; the kernel decides in which process they are made.
2. Every factory that returns a node leaves a build record on it. `TLKit.build` and `TLRigs.build` do. Missing:
   `TLKit.build_layout` (patch 4), `TLVfx` options (patch 3), `TLStyleFx.*`, `TLVfx.trail`.
3. Every node of a pack gets a number in the order it entered the tree (patch 5). Two processes cannot agree on
   `@Node3D@41`.
4. `TLInput` gets a door for samples from the drawing process, separate from the bot's (patch 1).
5. Nothing may be read back from the picture: `TLCameras.subject_px`, `frame`, and the raw `Camera3D` from `view()`
   project through a window S does not have. The window's aspect becomes an input, or these calls go.
6. A parameter set on a material is written to a stub in S and never arrives. It needs a kernel verb that keeps it
   as node state.
7. The stream needs "moved to another parent": the kernel reparents fracture pieces when a block breaks.

What does **not** need to change is the larger half: rules, bodies, contacts, triggers, steering, the laws, input by
named action, sounds and effects with lifetimes counted in frames, the HUD as text. The kernel was already written
as if the picture were somewhere else.

**What the owner would be buying.** (a) A place where an operating-system boundary can stand between a shared
game's code and the player's account; the fence stays a guardrail and stops being the only thing there. (b) The
same seam is the multiplayer seam: D does not care whether S is a process or another machine, and the stream is
small enough for a network (hockey: 565 kB/s as sent, most of it whole bone poses with no packing at all). (c) A game that
hangs or crashes no longer takes the world with it, and its watchdog can be a process that cannot be starved by the
game it watches. (d) A distant game can be ticked at a lower rate, or not drawn, without the pack knowing. The price
is one frame of input delay per game moved, roughly a second engine process of processor time and memory per
simulating process, and the seven changes above. "Seam now, move later" is the right order: the seam is items 1 to
7, and it can be held without ever starting a second process.

**The premises of the brief that the measurement corrected**: the two candidates for rebuilding the picture (above);
"choose the channel by measurement (a local TCP or pipe)": the engine gives a script no pipe to choose (section 2.8);
and the measured channel, TCP on the loopback address, is the one an app container forbids (`RESTRICT.md`, item 1),
so the multiplayer channel and the sandbox channel are two different channels.

## 2. Measurements, with the commands

Every command is run from the worktree root with `TL_GODOT` set. Each run prints one JSON line per process (S:
`"role":"sim"`, D: `"role":"draw"`, one process: `"role":"solo"`), the two hashes, and how many of its processes
are still alive (always 0).

### 2.1 The state hash: equal
`bash engine/tools/proc.sh run --pack=<pack> --fast` (S as fast as it can go; without `--fast`, in real time)

| Pack | Bot frames | One headless process (`tl.sh bot`) | Process S |
|---|---|---|---|
| seed_paddle | 6776 | `cadd1cd9fffac7b1...` | equal |
| seed_wall | 1221 | `6366b88f838e3e78...` | equal |
| seed_drive | 3516 | `36635c049bc6acd8...` | equal |
| hockey (`site/.../game.ice_hockey_three_against@0.1.1`) | 4888 | `5af10fbc23df0d76...` | equal |

Also equal at a cut of 1800 frames in real time, three ways (one headless process, one windowed process, S): hockey
`c8d98f80...`, drive `b609da2e...`. The first runs were NOT equal for wall, drive and hockey: S waited for D inside
the engine's loop, so the physics stepped between the pack's setup and its tick 0. That was the spike's bug (S now
waits before it loads the pack), and it is worth remembering as a rule: **between setup and tick 0 nothing may run.**

### 2.2 Bytes and milliseconds per tick
Same command, `--fast`. "Tick" columns are the whole physics iteration at p50; "tap" is S reading the tree, encoding
and sending.

| Pack | 3D nodes | Tick, one process | Tick, S | Tap, mean (p99) | Bytes per tick, mean (max) | First message | Nodes moved per tick |
|---|---|---|---|---|---|---|---|
| seed_paddle | 364 | 0.229 ms | 0.509 ms | 0.233 ms (0.366) | 272 (324) | 70,108 | 2.8 |
| seed_wall | 339 | 0.432 ms | 0.684 ms | 0.244 ms (1.083) | 2,141 (6,456) | 47,028 | 15.7 |
| seed_drive | 163 | 0.672 ms | 0.795 ms | 0.128 ms (0.225) | 726 (1,496) | 23,844 | 11.3 |
| hockey | 299 | 0.893 ms | 1.321 ms | 0.340 ms (1.101) | 9,412 (9,968) | 61,748 | 42.7 |

The tap's cost follows the number of nodes it walks, not the number that moved: it compares every 3D node's
transform every tick in GDScript. Walking only bodies and what hangs under them, or doing it in native code, is the
obvious saving and was not tried. A transform is sent as 12 numbers (48 B) and a bone as 10 (40 B); hockey's 9.4 kB
is six skaters' skeletons, each sent whole whenever one bone changed. Position plus rotation, and only the bones
that changed, is the obvious saving; not tried.

### 2.3 Processor time per frame in real time: S and D against one process
`bash engine/tools/proc.sh run --pack=<pack> [--frames=1800]` and `bash engine/tools/proc.sh solo --pack=<pack>
[--frames=1800]` (the same pack and bot in ONE windowed process). Processor time is read from the operating system
for the whole process (granularity 15.6 ms, so a figure over 1200 or more frames is good to about 0.01 ms).

| Pack, frames | S | D | S + D | One windowed process | Ratio | D applies a tick in (mean) | D's frame period p99 |
|---|---|---|---|---|---|---|---|
| seed_paddle, 6776 (the acceptance run, 13:52) | 2.15 ms | 4.99 ms (*) | 7.14 ms | 3.58 ms (1800 frames) | 2.0 (*) | 0.055 ms | 273 ms (*) |
| seed_paddle, 6776 (the same command, 14:08) | 1.32 ms | 2.55 ms | 3.87 ms | 3.92 ms (6776 frames, 14:05) | 1.0 | 0.062 ms | 18.7 ms |
| seed_paddle, 1040 (the latency run, no bot) | 1.83 ms | 3.08 ms | 4.91 ms | 3.67 ms | 1.3 | 0.054 ms | 16.8 ms |
| seed_wall, 1221 | 2.65 ms | 3.84 ms | 6.49 ms | 3.35 ms | 1.9 | 0.176 ms | 18.4 ms |
| seed_drive, 1800 | 2.50 ms | 3.27 ms | 5.77 ms | 4.28 ms | 1.3 | 0.080 ms | 17.1 ms |
| hockey, 1800 | 3.46 ms | 3.19 ms | 6.65 ms | 4.27 ms | 1.6 | 0.240 ms | 17.6 ms |
| hockey, 1800, again | 3.17 ms | 3.59 ms | 6.76 ms | 4.53 ms | 1.5 | 0.356 ms | 18.9 ms |

(*) the machine held D's window up in this run (see 2.7); the row under it is the same command at a quieter moment.

Reading: D alone costs about what the one process costs, because a windowed engine's processor time is the engine
and the renderer, not the pack (whose whole tick is 0.2 to 0.9 ms, table 2.2). S costs 1.3 to 3.5 ms a frame, most
of it a headless engine turning its loop 60 times a second. So **a second engine process is about 1.3 to 3.5 ms of
processor time per frame, whatever the game**, and moving the pack out saves D almost nothing. The ratio moved
between 1.0 and 1.9 with the state of the machine: its noise is as large as the effect, and only the order of
magnitude should be taken from this table. The tap in S was
slower paced than flat out (p50 0.21 to 0.56 ms, means up to 0.92 ms, against means of 0.13 to 0.34 ms): cold
caches and a busy machine.

### 2.4 Memory and start-up
From the same lines (`mem_peak_mb`: the engine's own count of its static memory at its peak; graphics memory and
the operating system's share are not in it. `ready_ms`).

| | S | D | One windowed process |
|---|---|---|---|
| Static memory, peak (seeds; hockey) | 105 MB; 90 MB | 127 MB; 115 MB | 126 MB; 115 MB |
| Start | 2.4 to 4.4 s to load the pack once D has connected | 3.7 to 5.2 s from engine start to the scene built | 3.4 to 5.7 s |

Two processes hold 205 to 232 MB where one holds 115 to 126 MB: the second engine is the cost, the pack is small.
Starts are sequential in the spike (D builds, connects, then S loads: about 6 to 10 s to the first picture) and
could overlap.
**A wall-clock limit failed healthy runs**: three times a window took 26 to 40 s to start on this busy machine
(26 s the one-process comparison; 40 s and 38 s D). The two slow starts of D outran the spike's own 30 s wait and
both runs ended with no picture. Both waits are 180 s now, and both experiments passed when run again. It is round 1's finding again: a limit in seconds of wall time is a limit on
the machine, not on the code.

### 2.5 How much of a pack could be rebuilt from records instead of code
S counts, for every node, how another process could make it again (the `rebuildable` field of S's line).

| Pack, nodes at the start | Kit part or rig, or inside one | Kernel class | Kernel body or kernel node | No record |
|---|---|---|---|---|
| seed_paddle, 377 | 331 | 10 | 13 | 23 |
| seed_wall, 266 | 216 | 16 | 11 | 23 |
| seed_drive, 144 | 95 | 13 | 11 | 25 |
| hockey, 306 | 266 | 14 | 12 | 14 |

"No record" is the same list in every pack: the layout's own products (its root and holders, terrain, the scattered
forest, the merged static mesh), the HUD's labels, the pack's root and entry. None was made by a pack's script.
After the start: wall adds 48 rigid bodies for the pieces of broken blocks and moves the 48 piece meshes under them
(the stream's `moved`), drive builds 16 cones again as kit parts with bodies, hockey adds only effects (142). D drew
a small box for each of the 48 + 16 late bodies, because D never ran the code that made them
(`bodies_without_picture`): this is what "D builds from the setup" cannot do and "D builds from records" can.

### 2.6 Pictures of D's window
`engine/kernel/proc/shots/paddle.png` (the acceptance run, tick 600); and, converted to JPEG to keep the folder
small, `hockey_rt.jpg` (skaters posed by bone poses that crossed), `drive_rt.jpg` (a chase camera computed in S),
`wall_rt.jpg` (fracture pieces after "moved"), `paddle_die.jpg` and `paddle_die.lost.jpg` (before and after S
ended without a word), `wall_stall.jpg`. The tool itself writes PNG wherever `--out` points (default: the temp folder).

### 2.7 S is slow, S dies
- `bash engine/tools/proc.sh run --pack=engine/seeds/seed_wall --stall-at=300 --stall-ms=1500`: S sleeps 1.5 s at
  frame 300. D's longest wait for a tick: 1533 ms and, run again, 1517 ms. D's frame period over the run: p99
  16.9 ms and 18.7 ms. D shows "NOT ANSWERING for n ms; the picture stands" and goes on; the hash at the end is equal.
- `bash engine/tools/proc.sh run --pack=engine/seeds/seed_paddle --die-at=400`: S ends its own process at frame 400
  with no goodbye. D reports `s_lost`, draws 180 more frames, takes a picture, ends by itself. PASS, twice.
- The other direction: when D goes away, S notices on its next tick and ends its run (seen in every `latency` run).
- Sending never blocks S: what the socket does not take waits in a queue (`backlog_max`; 0 in every real-time run,
  up to 1.9 MB when S ran 13 times faster than D drew). A real S would drop D past a limit; the spike does not.
- Found on the way: a process that closes a socket with unread input in it makes Windows reset the connection, and
  the reset discards what the other side had not read yet. S now reads D's input until D has closed.
- Not a finding about two processes, but seen: in some real-time runs this machine held windows up for seconds
  (D's frame period p99 0.27 to 0.54 s in the two full paddle runs of 13:42 and 13:52 and in one of two drive
  runs; in the same minutes one windowed process took 26 s to start and D took 38 and 40 s). The evidence says
  the machine, not D: at 14:05 the one-process control and at 14:08 the two-process run of the same pack, full length, were
  both clean (frame period p99 18.8 and 18.7 ms, 6766 and 6734 frames drawn of 6776). Hashes were equal in the
  disturbed runs too.

### 2.8 The channel
`bash engine/tools/proc.sh chan` (both ends in one headless process, busy polling, 1000 round trips each)

| Payload | TCP 127.0.0.1, no delay | UDP 127.0.0.1 | Named pipe |
|---|---|---|---|
| 300 B | 21 to 25 us | 17 to 18 us | cannot be made by a script (`FileAccess.open`: error 7) |
| 2 kB | 23 to 25 us | 23 us | |
| 10 kB | 30 to 42 us | 46 to 52 us | |
| 60 kB | 99 to 116 us | 179 to 252 us | |

TCP: a datagram cannot carry the first message of the larger packs (limit 65,507 B; paddle's is 70 kB), UDP is no
faster above 2 kB, and order and delivery come for free. The messages are the engine's own encoding of a Variant
(`var_to_bytes`; objects are never decoded) behind a 4-byte length. One way costs 10 to 15 us against a tick of
16,667: the channel is not where the frame goes.

### 2.9 The delay from a key to the picture
`bash engine/tools/proc.sh latency --pack=engine/seeds/seed_paddle --n=12`. A press is set in a physics tick of the
process that has the window; the clock stops in the first drawn frame in which the player's paddle has moved.

| | Frames, each of 12 presses | Mean | Longest |
|---|---|---|---|
| One windowed process, first run | 1, twelve times | 17.4 ms | 18.0 ms |
| One windowed process, second run | 1, twelve times | 17.7 ms | 18.5 ms |
| Two processes, first run | 2, twelve times | 33.4 ms | 33.5 ms |
| Two processes, second run | 2, twelve times | 33.4 ms | 33.5 ms |

Why one frame and not two: D's sample reaches S before S's next tick (the hop is microseconds), S's tick applies it,
and what S sends after that tick reaches D before D's next frame. Each hop waits for the other side's 60 Hz clock
once. D's input round trip, measured on every tick of every run (sample sent to "a tick that had seen it" arrives):
p50 16.7 to 17.1 ms.

## 3. What was not verified
- **Anything about restricting the process** (`RESTRICT.md`): no job object, token or container was made.
- **D building from records instead of from the pack's code.** Counted (2.5), not built. It is the step that turns
  this from a multiplayer seam into a sharing boundary, and it needs patches 3 to 5 first.
- **A real player.** Input came from bots (in S) and from presses the tool set (in D). Nobody held a key.
- **A network.** Both processes were on one machine; nothing is known yet about loss, jitter or prediction.
- **More than one simulating process**, a world of several packs, the visitor, tiers. One S, one D, one pack.
- **Sound.** D plays the events it receives; nothing checked that a sound is heard at the right moment.
- **Rig extras that exist only where there is a window** (beacon, welding flash, nitro light): read in the source
  as not crossing, not looked at in a picture.
- **The matching of unnamed nodes** ("class and ordinal among unnamed siblings") was right for these four packs
  (every node of S found its partner but the bot); nothing proves it for a pack built differently.
- **A quiet machine.** Every figure was taken with four other builders running; times are upper bounds, and the
  window stalls of 2.7 were not traced to a process: they went away when the machine was quieter.
- **An exported build.** Everything ran from the project folder with the console executable.
