# P5: patches to files outside my scope

None of these was applied. P5 works without them; each one names what it would remove.

## 1. `engine/kernel/host/host.gd`: let the loading options through

`MODE_OPTIONS` refuses any option it does not list. P5 has three for the world: `--load=queue|step|block` (how packs
arrive; today only the walk's `tiers.load.mode` or the environment can say it) and, for the windowed world, `--trip` and
`--dead` (the supervisor's two options, which `world` already has). Until then `tools/world.sh` hands `trip` and `dead`
to the window in the environment (`TL_WORLD_TRIP`, `TL_WORLD_DEAD`) and `view.gd` reads `TL_WORLD_LOAD`.

```gdscript
# line 32, "world": append
, "load"
# line 37, "world-view": append
, "load", "trip", "dead"
```

After that the three `TL_WORLD_*` reads in `kernel/world/draw/view.gd` (`start`) and the two variables in
`tools/world.sh` `window_mode` can go.

## 2. `engine/kernel/api/tl_context.gd`: two things a loader needs from the context

**a. `TLContext.current` is one static for the whole process.** That is what keeps the rest of a pack's build
(`_pack_setup` beyond the layout: rigs, parts made with `TLKit.build`, bodies, HUD) on the main thread: a worker thread
that runs `_pack_setup` would read the pack the main thread is ticking. Measured: with the layouts built ahead the
main-thread half of a build is 17 to 37 ms for a layout seed and 165 to 300 ms for `ex_walker` and `ex_kit` (no layout).
A thread-local `current` would let the whole build leave the main thread:

```gdscript
static var _by_thread: Dictionary = {}      # thread id -> TLContext, for threads other than the main one
static var _lock: Mutex = Mutex.new()
static func current_of_thread() -> TLContext:
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		return current
	_lock.lock(); var c: TLContext = _by_thread.get(OS.get_thread_caller_id(), null); _lock.unlock()
	return c
```

and every read of `TLContext.current` in `kernel/api/**` becomes `TLContext.current_of_thread()` (30 to 40 places).
It is not enough by itself: a pack built off the tree enters the tree in tree order, not in the order its nodes were
added, and `_ready` runs at the attach. Both must be proven not to move any hash before it is used. Not attempted.

**b. `ctx.load_script` keeps the engine's cached script.** `load(full)` returns the script as it was first compiled in
this process, so a RELOAD of a plot (`reload` event) picks up changed `data/*.json` (proven: selftest `world.reload`)
but not a changed `.gd`. `pack.gd` `_load_script` has the same `load`. A reload that must see new code needs both to
load with `ResourceLoader.CACHE_MODE_IGNORE` when the file's modified time changed since it was cached, and
`_script_cache` keyed by path and time. Not done in `pack.gd` alone, because the entry script would then be new and the
scripts it loads through `ctx.load_script` old.

## 3. `engine/kernel/world/landscape.gd`, `terrain/world_space.gd`: packs that arrive after the landscape

The landscape copies every pack's static colliders into the visitor's space when it is built. A pack that arrives later
had none, and the visitor fell through the hole the landscape leaves for a pack's own ground (seen: the tour ended with
the visitor at y = -432 m). `view.gd` now calls `world_space.add_pack` when the first pack of a plot arrives
(`_on_plot_event`, `rebuilt`). Two things remain for the landscape's owner:

- `add_pack` after `finish()` adds bodies to a space that was switched inactive; it worked in the tour (the visitor ends
  at y = 6.5 m again, see the report), but nothing in `world_space.gd` says it may be called late.
- The landscape of the 30-game village takes 3.8 s to build (terrain 0.85 s, colliders 0.8 s, the rest scatter and
  fences), all before the first frame. With the packs out of the way it IS the time to the first frame. It needs the
  same treatment as the packs: a first frame with the near ground, the rest in slices.

## 4. `engine/kernel/world/draw/draw.gd`: a plot without a pack, and the stand-in

- `set_tier(i, "backdrop" | "ledger")` on a plot whose holder has no nodes yet builds an EMPTY stand-in and keeps it
  for good (`replace_holder` keeps the stand-in). `view.gd` now does not pass a far tier on until a pack has stood on
  the plot. `draw.gd` could refuse to build a stand-in from a holder that is not `loaded`.
- "Until a pack is built its plot shows its pad (and its stand-in if one is cached)": the stand-in mesh is not cached
  between runs. `_build_standin` would write it to `user://tl_cache/standin_<pack directory hash>.res` and read it back
  for a plot whose pack is not there yet. Not built: `draw.gd` is not mine.
- `_build_standin` runs inside the frame in which a plot first goes far (a merge of every mesh of the pack). Not measured
  apart in P5; it is on the main thread and belongs on a worker like the layout.

## 5. `engine/rigs/**`, `engine/kernel/api/tl_biped.gd`: the rig is built on the main thread

`ex_walker` has no layout: its 165 to 300 ms of `_pack_setup` is the walker's rig. The kit side has a way now
(`TLKit.build_layout_ahead`); a rig needs the same (`TLRig.build_ahead(params)` keyed by its parameters, taken by the
next equal `build`), or patch 2a.

## 6. `engine/kernel/runner/worker.gd`: the contact pass by name (the other half of PATCHES-P2 entry 1)

In a world the pack's holder now calls the tracker's pass itself (`pack.gd` `contact_pass`, from the closing mark:
after every node of the pack, before its physics step) and switches the tracker's own processing off. A pack alone
(`worker.gd`) still has it ticked by the scene tree at priority 100. Same order, same hashes (13 packs, both modes,
A/B in the report). For one written order everywhere, `worker.gd` would do what `pack.gd` `tick()` and `contact_pass()` do.

## 7. `docs/PERF.md`: the new scenario and two metrics

Row for the scenario table:

```
| `walk30` | `world.sh tour walk30 --pictures-only`: a village of 30 games, the visitor runs its road, games are built by the queue as he approaches | world tick p50/p99/max, frame p50/p99/max, time to the first frame, time until six games are built, render cpu/gpu, draw calls, primitives |
```

`first_frame_ms` (process start to the end of the first drawn frame) and `six_built_ms` (world start until the sixth
pack is attached) are in `devx/lib/perf/ledger.mjs` `METRICS` with tolerances 30 % + 300 ms and 50 % + 500 ms. `tour6`
now reports `frame_ms_p99` and `worst_frame_ms` (PATCHES-P1 entry 1 is applied); both leave out the first two frames,
which are the start itself. The tour's pictures are encoded off the main thread, so its worst frame is no longer the
PNG of a `shot`.

## 8. `devx/arch.baseline.json` (information for the merge)

`world.gd` went from 684 to 672 lines and `pack.gd` stays at 626: the world file writer and the directory hash moved to
the new `kernel/world/plotfile.gd`. Both baselines may be lowered; nothing has to be raised.

## 9. `engine/kernel/world/WORLD.md`: what a pack author must know about loading

`WORLD.md` is not in P5's scope (only `TIERS.md` is, which has the whole model under "P5: loading is not simulation").
For its section "What a pack author must know":

```markdown
### Loading (P5)

- In a world your pack is built by a queue, nearest games first, and may arrive some ticks after the world started.
  Until then your plot shows its pad. You are not ticked before you are there, and your tick count starts at 0 when
  you arrive: nothing in a pack may depend on the world's tick.
- The venue you build with `TLKit.build_layout(ctx.read_json(...), ctx.root)` is built ahead on another thread when
  the layout file lies under `data/` and you pass it on unchanged. A layout you change in code before building it is
  built inside your `_pack_setup`, on the main thread, as before: it works, and it costs the visitor a frame.
- Everything else in `_pack_setup` still runs on the main thread: keep it small.
- A world may replace your pack by a fresh copy of its directory at any tick (`reload`): what `_pack_save` returns is
  handed to `_pack_load` of the new copy; nothing else survives. Keep no state in `static var`.
```
