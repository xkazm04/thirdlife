# P8 a spike: one game simulated in a second process: builder report and Director verification

Brief `briefs/BRIEF-P8-PROCESS.md`. Builder wall time 13:23 to 14:37 on 2026-11-11 (74 min; harness: 366,432 subagent tokens, 121 tool uses). Work done in the worktree `.claude/worktrees/core-p8` (branch `core-p8-process`).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

REPORT P8: one game simulated in a second process (spike)

Builder worktree: C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p8 (branch core-p8-process). Start 13:22:45, end 14:36:47 (2026-11-11).

Note for whoever saves this report: I do not write the figure lines' old schema name literally anywhere below. The arch rule `schema-versions` reads Markdown and fails the tree on an undeclared schema name; it failed my full gate once for that reason.

## STATUS

All five items are done and the acceptance checks pass. The paddle seed, the wall seed, the drive seed and the hockey game were each played to the end by their bot in a headless process S and drawn by a windowed process D, with no change to any pack. The state hash in S equals the hash in one process for all four.

The answer is a qualified yes:

- **Simulation half:** yes, measured.
- **Picture half:** yes when D may run the pack's own setup code, which is enough for multiplayer with one machine as the authority. Not yet for sharing with strangers: there D must build from records, and those are counted, not built.
- **Cost:** one extra frame from key to picture (2 instead of 1), a second engine process (1.3 to 3.5 ms of processor time per frame, 90 to 105 MB), and seven small kernel API changes.
- **Restriction on Windows:** on paper only. Nothing was run.

## PER ITEM

All commands run from the worktree root with TL_GODOT set.

### 1. The smallest version

- **Built:** S is the unchanged worker plus a tap after every tick. D builds the scene by running the pack's `_pack_setup` and `_pack_start` once in a window, switches every node of the pack off (no tick, no bot, no physics step), then follows S and sends one input sample per physics tick.
- **Channel:** TCP on 127.0.0.1, one message per tick, encoded by the engine's `var_to_bytes` behind a 4-byte length. Objects are never decoded. Sending never blocks S.
- **Proof:** `bash engine/tools/proc.sh run --pack=engine/seeds/seed_paddle` gives PASS, hash `cadd1cd9fffac7b1e3c823a2cfbd45cd3cc519e4ccc68a46baa7c3003f95ccaa` in both, 6776 frames, 0 processes left.
- **Capture:** C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p8\engine\kernel\proc\shots\paddle.png
- **Channel measurement:** `bash engine/tools/proc.sh chan` (round trip, both ends in one headless process, 1000 trips each):

| Payload | TCP | UDP |
|---|---|---|
| 300 B | 21 to 25 us | 17 to 18 us |
| 2 kB | 23 to 25 us | 23 us |
| 10 kB | 30 to 42 us | 46 to 52 us |
| 60 kB | 99 to 116 us | 179 to 252 us |

- A datagram cannot carry the first message of the paddle pack (70 kB against a 65,507 B limit), so TCP.
- A script cannot make a named pipe: `FileAccess.open` on a new pipe name returns error 7.

### 2. How the picture is rebuilt, and the crossing list

Neither candidate in the brief works as written:

- A recorded build list has no recorder: the kit does not log its calls.
- A generic description from S has nothing to describe: in a headless process the style hands out one empty material, and kit, rigs and effects skip their looks.

The spike uses the coarsest build list there is, the pack's own setup run in D. That draws all four games correctly:

- shots\hockey_rt.jpg: skaters posed by bone poses that crossed.
- shots\drive_rt.jpg: a chase camera computed in S.
- shots\wall_rt.jpg: fracture pieces.

It is not a sharing boundary, because the pack's code still runs once in the player's process.

The crossing list, class by class, is C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p8\engine\kernel\proc\CROSSING.md. Its short form for the API v1 builder:

**Crosses today (measured unless marked as read from the source):**
- `TLInput`: actions and strengths.
- `TLCameras`: pose, fov, offsets, which view is active.
- `TLChaseCam`.
- `TLHud`: text.
- `TLAudio`: as events.
- `TLVfx.burst` and `attach`: as events.
- `TLBall`, `TLBiped`, `TLVehicle`.
- Rig bone poses.
- `TLFracture`, once the stream can say "moved to another parent".
- `TLOrbitCam` and `TLVfx.squash`: read in the source, not measured.

**Lives in S only, nothing to cross:**
- `TLRules`, `TLContact`, `TLDamage`, `TLTrigger`, `TLSteer`, `TLLaws`.
- The simulation side of `TLBodies`.
- Everything on `TLContext` except `headless`.

**Does not cross:**
- `ctx.headless` as defined. It tells code to skip looks in the one process that describes them.
- `TLCameras.subject_px`, `TLCameras.frame`, and the raw `Camera3D` from `view()`. They project through a window S does not have.
- `TLStyle.material`, `material_instance`, `flat_material`. A parameter set on them is written to a stub in S.
- Every `TLStyleFx` call that returns a node, and `TLVfx.trail`. They are null or empty headless and keep no record.
- Rig extras made only where there is a window (bot beacon and weld flash, vehicle nitro light).
- `TLSpawner` factories and any body made after setup, unless they carry a build record. D drew 48 + 16 such bodies as boxes.
- Engine-made node names such as `@Node3D@41`. The number is a per-process counter.
- Anything a pack waits on that only a window has (a `finished` signal, on-screen notifiers, `_process` smoothing).

**Build records (how much of a pack another process could rebuild from data):**

| Pack, nodes at start | Kit part or rig, or inside one | Kernel class | Kernel body or node | No record |
|---|---|---|---|---|
| seed_paddle, 377 | 331 | 10 | 13 | 23 |
| seed_wall, 266 | 216 | 16 | 11 | 23 |
| seed_drive, 144 | 95 | 13 | 11 | 25 |
| hockey, 306 | 266 | 14 | 12 | 14 |

- "No record" is the same list in every pack: the layout's own products, the HUD labels, the pack root and entry.
- That list comes from a 12-name sample per pack plus the counts. In no pack did the sample show a node made by the pack's own script.

### 3. Measurements

Full tables and commands are in engine\kernel\proc\PROCESS.md section 2. Four other builders were running; no run was quiet. None went through `tl perf run` because no two-process scenario exists.

**Key to picture** (`bash engine/tools/proc.sh latency --pack=engine/seeds/seed_paddle --n=12`, run twice):

| | Frames, each of 12 presses | Mean |
|---|---|---|
| One process | 1 | 17.4 and 17.7 ms |
| Two processes | 2 | 33.4 and 33.4 ms |

D's input round trip on every tick of every run: p50 16.7 to 17.1 ms.

**Per tick, S flat out** (`proc.sh run --pack=<pack> --fast`):

| Pack | Tick p50, one process | Tick p50, S | Tap, mean | Bytes per tick, mean | First message |
|---|---|---|---|---|---|
| paddle | 0.229 ms | 0.509 ms | 0.233 ms | 272 | 70,108 B |
| wall | 0.432 ms | 0.684 ms | 0.244 ms | 2,141 | 47,028 B |
| drive | 0.672 ms | 0.795 ms | 0.128 ms | 726 | 23,844 B |
| hockey | 0.893 ms | 1.321 ms | 0.340 ms | 9,412 | 61,748 B |

- The tap is a GDScript walk over every 3D node (163 to 364), so its cost follows node count, not movement.
- Paced at 60 Hz on the busy machine the tap was p50 0.21 to 0.56 ms.
- Hockey's 9.4 kB is six skeletons sent whole.

**Processor time per frame in real time** (`proc.sh run` against `proc.sh solo`):

| Pack | S | D | One windowed process |
|---|---|---|---|
| paddle (14:08, quiet moment) | 1.32 ms | 2.55 ms | 3.92 ms |
| wall | 2.65 ms | 3.84 ms | 3.35 ms |
| drive | 2.50 ms | 3.27 ms | 4.28 ms |
| hockey | 3.46 ms | 3.19 ms | 4.27 ms |
| hockey, again | 3.17 ms | 3.59 ms | 4.53 ms |

- The S + D to one-process ratio moved between 1.0 and 1.9 with the state of the machine. Take the order of magnitude only.
- D applies a tick in 0.03 to 0.36 ms.

**Memory and start:**
- Static memory peak: S 90 to 105 MB, D 115 to 127 MB, one process 115 to 126 MB.
- Start: S loads the pack in 2.4 to 4.4 s after D connects; D takes 3.7 to 5.2 s to build its scene.

**S slow** (`proc.sh run --pack=engine/seeds/seed_wall --stall-at=300 --stall-ms=1500`):
- D waited 1533 ms and 1517 ms for a tick.
- D's frame period p99 stayed at 16.9 and 18.7 ms.
- Hash equal at the end.

**S dies** (`proc.sh run --pack=engine/seeds/seed_paddle --die-at=400`):
- D reports the loss, draws 180 more frames, takes a picture and ends. PASS twice.
- Captures: shots\paddle_die.jpg and shots\paddle_die.lost.jpg.

**Hash equal for all four:**

| Pack | Frames | Hash |
|---|---|---|
| paddle | 6776 | `cadd1cd9…` |
| wall | 1221 | `6366b88f…` |
| drive | 3516 | `36635c04…` |
| hockey | 4888 | `5af10fbc…` |

Also equal three ways (headless, windowed, S) at 1800 frames: hockey `c8d98f80…`, drive `b609da2e…`.

**Bugs of mine the measurements found, all fixed:**
- S waited for D inside the engine loop, so physics stepped between setup and tick 0. Three of four hashes differed. S now waits before loading the pack.
- The reader took one socket buffer per frame, so a fast S ran 34 MB ahead.
- Closing a socket with unread input makes Windows reset the connection and discard the other side's unread data. D lost the goodbye once.
- The kernel reparents fracture pieces; the stream now carries "moved".
- My 30 s wall-clock wait for D failed two healthy runs when a window took 38 and 40 s to start. Both waits are now 180 s and both experiments passed again.

**Window stalls:** D's frame period p99 was 0.27 to 0.54 s in the paddle runs of 13:42 and 13:52 and one drive run. The evidence points at the machine, not D: at 14:05 a one-process control and at 14:08 the two-process run, both full length, were clean (p99 18.8 and 18.7 ms).

### 4. Restriction, on paper

File: C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p8\engine\kernel\proc\RESTRICT.md. Nothing in it was run.

- A job object takes away child processes and caps memory and processor, and ends S when D ends. It leaves files and network alone.
- A restricted token at low integrity blocks writing but not reading the user's files.
- Only an app container gives "no network, no file outside a folder".
- Expected denials: the loopback connection itself, the processor-clock helper process, the console wrapper executable, the user data folder, and reading the engine and pack folders without a grant.
- Consequence: the measured channel (loopback TCP) suits multiplayer but not the sandbox. The sandbox needs a pipe, and a script cannot make one, so a small native piece is needed.

### 5. The answer

File: C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p8\engine\kernel\proc\PROCESS.md. Section 1 is the answer, section 2 the measurements with commands, section 3 what is not verified.

## ACCEPTANCE CHECKS

1. **`bash engine/tools/proc.sh run --pack=engine/seeds/seed_paddle`: PASS.** It prints both processes' figure lines and the two hashes (equal), and writes one capture of D's window. Run four times in its final form; the first lost the goodbye (fixed).
2. **Crossing list, class by class: done** (CROSSING.md, 41 classes of the API index covered).
3. **Measurements of item 3 in PROCESS.md with commands: done** (sections 2.1 to 2.9).
4. **Nothing outside scope changed; nothing left open: yes.**
   - `bash engine/tools/proc.sh left` reports 0.
   - No engine process with this worktree on its command line.
   - No listener on the port range used.
   - The gate itself wrote `.tl/gate-history.jsonl` and `foreman/dist/`, both git-ignored.
5. **`node devx/bin/tl.mjs check --tier fast --changed`: PASS** (arch, 8 rules).

**Full gate** (`node devx/bin/tl.mjs check --tier full`, 14:11 to 14:35 with three other full gates running):
- PASS: assets, cards, foreman.typecheck, foreman.test (158), kernel.selftest (81 cases, 12.6 min), kit.selftest (87), seeds (24).
- perf: "machine BUSY, measured but not judged".
- item.selftest and ui.selftest: skipped by the gate (they need the main checkout).
- FAIL: arch, and devx.test through it (2 of 123). My journal had written the undeclared schema name out. Reworded; `--only arch` and `--only devx.test` (123 of 123) pass.
- The full tier was not run again as one command after that fix.
- No healthy step failed from load.

## FILES CHANGED

All new; nothing existing was edited.

- `engine/tools/proc.sh`: the tool (run, latency, solo, chan, left). Every process it starts carries a tag and only tagged processes are ever stopped.
- `engine/kernel/proc/proc.tscn`, `proc_boot.gd`: the experiment's own door, so `host.gd` is untouched.
- `engine/kernel/proc/proc_wire.gd`: the channel and the node naming both processes agree on.
- `engine/kernel/proc/proc_sim.gd`: S (extends the worker; the tap, the rebuild census, stall and die options).
- `engine/kernel/proc/proc_draw.gd`: D (build by setup, follow, input out, capture, survive).
- `engine/kernel/proc/proc_solo.gd`: the one-process comparison with the same instruments.
- `engine/kernel/proc/proc_chan.gd`: the channel benchmark.
- Seven `*.gd.uid` files, made by the engine.
- `engine/kernel/proc/PROCESS.md`, `CROSSING.md`, `RESTRICT.md`, `PATCHES-P8.md`, `JOURNAL.md`.
- `engine/kernel/proc/shots/`: `.gdignore`, `paddle.png`, and six JPEGs (`hockey_rt`, `drive_rt`, `wall_rt`, `paddle_die`, `paddle_die.lost`, `wall_stall`).

## PROPOSED CONTRACT TEXT

Not applied; contracts are the Director's.

1. **contracts/RUNNER.md, frame order.** "Nothing runs between `_pack_setup` and tick 0. A host that has to wait (for another process, for a window) waits before it loads the pack. A physics step in that gap changes the state hash."
2. **contracts/PACK.md and API.md, `ctx.headless`.** "True when this process spends no time on looks. It never means the pack is not being watched. A pack must not skip a `TL*` call because of it; kit, rigs and style may skip the realisation but must leave the record."
3. **contracts/KIT-RIG-STYLE.md.** "Every factory that returns a node tags it with `tl_kind` and `tl_params` sufficient to build it again. No node under a pack keeps an engine-made name. Nothing that exists only where there is a window may be read back by a pack (viewport size, on-screen size, a material's parameters, the end of a sound or an effect)."
4. **Only if the seam is adopted, a new contracts/PROC.md** declaring a schema for the per-tick stream. Fields as the spike sends them: frame, changed local transforms, visibility, added, removed, moved, HUD text, bone poses, camera lens, sound events, active camera, echo of the last input number. The return message carries input number, actions, strengths. The spike's figure lines deliberately carry no schema name (`{"proc":1,"role":…}`).

## CONTENTS OF THE PATCHES FILE

engine/kernel/proc/PATCHES-P8.md, in summary. The exact text is in the file. None is needed to run the spike.

1. **`engine/kernel/api/tl_input.gd`.** A `remote` field per action, a kernel-side `_feed(action, value)`, `_sample()` taking `maxf(injected, remote)`, and `_bindings()` so D can learn the keys without running the pack. Reason: `press()` is the bot's door, and a bot and a remote player overwrite each other on it.
2. **`engine/kernel/api/tl_audio.gd`, `_play`.** Record `volume_db` when it is not 0. Reason: it is played but not recorded, so a sound crossing as an event loses it.
3. **`engine/kernel/api/tl_vfx.gd`, `_make`.** Keep `opts` on the node as meta `tl_fx_opts`, and give `trail` the same record. Reason: a headless process throws them away.
4. **`engine/kits/tl_kit_layout_build.gd`, `run`, after line 26.** `root.set_meta("tl_kind", "layout")` and `root.set_meta("tl_params", L)`. Reason: the layout's products are the largest group of nodes with no build record.
5. **`engine/kernel/runner/worker.gd`, `_on_node_added`.** A serial number `tl_n` for every node of a pack in the order it entered the tree (three lines plus one field). Reason: engine-made names differ per process. To go with the move, not before; `worker.gd` "may not grow".
6. **`engine/kernel/host/host.gd` and `verbs.json`.** A `proc` mode, only if the experiment should be reachable through the host. I would not.
7. **`CLAUDE.md`, "Where things are".** One row pointing at `engine/kernel/proc/PROCESS.md` and `engine/tools/proc.sh`.

## WHAT CHANGED FOR A PACK AUTHOR

Nothing. No pack, kit, kernel or contract file was touched.

If the seam is adopted for API v1, a pack author gets these rules:

- Never branch on `ctx.headless` to skip a `TL*` call.
- Make visible things through the kit, rigs, `TLVfx`, `TLAudio` and `TLHud` only.
- Never wait for something only a window has.
- Expect `subject_px` and `frame` to change or go.

## WHAT I DID NOT VERIFY

- Anything about restricting the process. No job object, token or container was made.
- D building from records instead of the pack's code. Counted, not built.
- A real player. Input was bots in S and tool-set presses in D.
- A network. Both processes were on one machine.
- More than one simulating process, a world of several packs, the visitor, tiers.
- That sounds are heard at the right moment. D plays the events; nothing checked timing.
- The headless-only rig extras in a picture. Read in the source only.
- The matching of unnamed nodes beyond these four packs. Here every node of S found its partner except the bot.
- A quiet machine. Every time is an upper bound.
- An exported build.
- The full gate as one green run after the journal fix. The two failed steps were rerun alone and pass.
- `item.selftest` and `ui.selftest`. Skipped by the gate in a worktree.
- Whether `FileAccess` can open a pipe that a native launcher made first.

## QUESTIONS

1. Which purpose comes first? Multiplayer authority works today in the spike's form (D runs the setup). Sharing needs D to build from records, i.e. patches 3 to 5 plus a builder in D.
2. May `ctx.headless` change meaning in API v1 (contract text 2)? It is the one change that touches how kit, rigs and effects are written.
3. `TLCameras.subject_px`, `frame`, and `view()` returning the raw camera: remove, define on a nominal 16:9, or make the window's aspect an input?
4. Is a small native piece acceptable (a launcher or GDExtension for the pipe and the job object)? Without it the sandbox channel cannot exist; the multiplayer channel does not need it.
5. Should the spike stay in the tree as `engine/kernel/proc/` (it is off the game path and has its own scene), or be kept only as the report?
6. One extra frame of input delay per moved game: acceptable for all games, or only for games that are shared or remote, with local trusted games staying in process?

## MINUTES SPENT

74 minutes of the 100 (13:22:45 to 14:36:47, from `date`). Of those, 24 were the full gate running beside three other full gates.

---

## Director verification

Done 14:38 to 14:50 on 2026-11-11 in the builder's worktree. By the owner's rule of this day the command runs were
made by a Sonnet subagent and read by the Director; the picture was looked at by the Director. Four builders were
running the engine at the time.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash engine/tools/proc.sh run --pack=engine/seeds/seed_paddle` | PASS. The hash from the simulating process and the hash from one process are the same (`cadd1cd9fffac7b1e`), 6,776 frames |
| the same for the promoted hockey game 0.1.1 (an LLM-built pack, unchanged) | PASS. Both hashes `5af10fbc23df0d76`, 4,888 frames |
| `proc.sh run --pack=engine/seeds/seed_paddle --die-at=400` | PASS: the simulating process ended without a word after 400 ticks, the drawing process noticed, went on drawing (572 frames) and wrote its "lost" picture |
| `proc.sh latency --pack=engine/seeds/seed_paddle --n=12` | one process: 12 of 12 key presses on screen after 1 frame (17.4 ms mean); two processes: 12 of 12 after 2 frames (33.4 ms mean) |
| `proc.sh left` | 0 processes of the tool left |
| `node devx/bin/tl.mjs check --tier fast` | PASS, five steps |

**Looked at:** `engine/kernel/proc/shots/hockey_rt.jpg`: the hockey rink from above with the six skaters, both goals,
the scoreboards showing 2:3, the stands and the floodlight shadows on the ice, with the line "drawn by process 33132,
simulated by another (tick 900, 9460 B/tick)". It is the game as it looks in one process.

The pictures in `shots/` are the builder's (13:53 to 14:14); the re-run wrote its captures to the temporary folder and
did not replace them.

### What this settles

- "Seam now, move later" holds up: a game can run its simulation in another process today, with no change to the
  game, and end in the same state. The seam is real; nothing has to move tonight.
- The price is known: one more frame from key to picture, a second engine process, about 9.5 kB a tick for hockey.
- For games shared between strangers the drawing side must be built from records, not from the game's own setup
  code. 83 to 95 % of a game's start nodes already carry such records; the rest is listed in `CROSSING.md`.

### What is not verified

Restricting the simulating process on Windows (examined on paper only, `RESTRICT.md`). Two machines. A world of many
games with some of them in other processes. Sound. Any figure under a quiet machine.

### Director's decisions on the builder's questions

1. Which purpose first (playing together or sharing with strangers) is the owner's: it goes to the morning page.
   Neither is built in this run.
2. The meaning of `ctx.headless` and 3. the camera calls that depend on the window: decided with the simulation
   contract package (P7) of this round, which owns API version 1; this report's crossing list is its input.
4. A small native piece for the pipe and the job object: not before community sharing is on the plan; the owner's
   call then.
5. The spike stays in the tree under `engine/kernel/proc/`. It is off the game path, has its own scene, and is the
   only test that a game crosses the boundary unchanged.
6. The extra frame is paid only by games that are remote or not trusted. A local game the player built stays in
   process.
