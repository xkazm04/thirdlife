# N2: many games alive in one process

You are the builder for the **kernel** of Third Life, a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz
fixed tick) in which an LLM builds small games ("packs") over a law kernel. Today the engine runs exactly one pack per
process and quits when it ends. The owner has ruled that **every game in the world stays alive**, and that cost is
controlled by layers, not by switching games off. Your job tonight is the first half of that: the kernel can hold
several packs in one process, each isolated, each still deterministic.

## Read first
1. `C:\Users\kazda\kiro\third-life\reports\Living world layering for Third Life.md`: sections "Godot's physics gives
   per-pack isolation but one global timestep", "Recommended layering model", "Thresholds the spike should measure"
   and the unverified list at the end. This is research from documentation and source reading; **nothing in it was
   measured**. You measure.
2. `engine\kernel\API.md` (especially sections 0 and the limits near line 510), `engine\JOURNAL.md` (WP4, WP5),
   `engine\kernel\runner\worker.gd`, `engine\kernel\host\host.gd`, `engine\kernel\api\tl_context.gd`.
3. `contracts\RUNNER.md` and the last section of `contracts\PACK.md`.

## Where you work
**In your own copy of the engine: `C:\Users\kazda\kiro\third-life\site\_work\n2\engine\`** (made from the main tree a
few minutes ago). Set `TL_GODOT=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe` and
run its own tools: `bash site/_work/n2/engine/tools/tl.sh ...`. Two other builders change `engine/` in the main tree
and in another copy at the same time; the Director merges by file afterwards, so the file scope below is strict.

Yours: `kernel/**` **except** `kernel/runner/lint.gd`, `kernel/runner/manifest.gd`, `kernel/api/tl_cameras.gd`,
`kernel/api/tl_chase_cam.gd`, `kernel/api/tl_orbit_cam.gd`; new `kernel/world/**`; new `tools/world.sh`;
`tools/selftest.sh`; `JOURNAL.md`. If a camera file, a kit, a rig or the style needs a change for your work, **do not
edit it**: write the exact patch and its reason to `kernel/world/PATCHES.md` and the Director applies it. (You may
edit those files in your copy to keep your tests running, as long as every such edit is in `PATCHES.md`.)

## What the scout found (static state a second pack collides with)
`TLContext.current` (`kernel/api/tl_context.gd:7`, read by TLAudio, TLOrbitCam, TLBiped, TLVehicle, TLFracture,
TLSpawner, TLVfx, `require()`); `TLAudio.events/_streams/_warned`; `TLHud._all` and `hide_all()`; `TLLaws` tables;
`TLVfx._warned`; `TLStandin` caches and the fixed node names `TLLook`, `Layout_<name>`; `TLKitLayout._schema`;
`TLStyle` and `TLStyleFx` statics and 14 global shader parameters (shared look: fine to stay global); the tree-wide
`tl_ball` group (`kernel/api/tl_trigger.gd:46`, `tl_ball.gd:117`); one default physics space; `worker.gd:603` quits the
process at the end of a run. Verify this list yourself with grep; it was read, not run.

## The work, in this order
1. **A pack instance.** Everything a running pack owns hangs off one object (its context): its nodes, its input
   record, its seeded generator, its tick counter, its HUD, its audio, its groups. No pack reaches another pack's
   state through a static or a tree-wide group. Shared, read-only things (law tables, the style, schemas) may stay
   shared. `TLContext.current` may survive only as "the pack the kernel is calling right now", set and cleared by the
   kernel around every call into a pack.
2. **The kernel drives every tick.** Kernel nodes that tick themselves in `_physics_process` (biped, vehicle, HUD,
   cameras, spawners and so on) must advance only when their pack is ticked, so that a pack can later be given fewer
   ticks than the world. Find the cleanest mechanism and prove it: a pack that is not ticked for N world ticks and then
   ticked again must give the same state hash as the same pack ticked continuously for the same number of its own
   ticks.
3. **One physics space per pack.** `PhysicsServer3D.space_create()`, bodies and areas moved to it, ray and shape
   queries of the kernel directed at it, `space_set_active(false)` when the pack is not ticked. Measure both ways of
   placing a pack away from the origin and report: (a) bodies at their world position inside the pack's own space;
   (b) bodies at a pack-local origin with only the picture offset (say plainly if you find no workable mechanism).
4. **Several packs in one process.** A new mode of the worker or a new host under `kernel/world/` that loads a list of
   packs, each with a seed and a position, and ticks them. `bash tools/world.sh run --packs=<a>,<b>,... [--frames=N]`
   prints one JSON line per pack with its state hash.
5. **The measurements.** `bash tools/world.sh bench` runs what you can of tests 1 to 9 of the report's table and
   writes `kernel/world/BENCH.md` plus `kernel/world/bench.json`: cost per pack per tick at 1, 5, 10, 20 packs;
   cost of a pack whose bodies are asleep; cost of an inactive space; hash stability against neighbours; offset
   stability; pause and resume; a pack ticked 1 world tick in N for N of 2, 8, 30; whether any pack script ran on a
   tick its pack did not get; engine warnings about dropped contacts (any such warning fails the test).
6. **`verbs.json`.** `kernel/runner/verbs.json` (`tl.verbs/1`) is now the one list of verbs and options, and the
   Foreman reads it. Add a selftest case that fails when it and `host.gd`'s `OPTIONS` disagree. When you add a verb or
   an option, add it to the file.

## Acceptance (the Director will run these in your copy)
- `bash tools/tl.sh selftest`, `bash tools/k.sh selftest`, `bash tools/tl.sh seeds` pass. The single-pack verbs behave
  as before. **If a state hash of a seed changes** (smoke hashes today begin `bc93a9a4` paddle, `b9adbb19` drive,
  `da4bdc3f` wall), say exactly which change caused it and show that the new hash is stable over three runs.
- `world.sh run` with `seed_paddle`, `seed_drive`, `seed_wall` together, and with two copies of `seed_wall`: every
  pack's hash equals the hash of the same pack run alone through the same host, three runs in a row.
- The pause proof of item 2 and the offset report of item 3 are in `BENCH.md` with their commands.
- A grep that shows no remaining mutable static shared between packs, or a list of the ones left and why.

## How to work
Small verified steps; journal each in `JOURNAL.md` of your copy under an "N2" heading. Headless runs; a window only
where a measurement needs one, placed with `--position 0,1440`. Kill every process you start; never kill others
(other sessions run Godot and a GPU benchmark here: re-run a wall-clock figure before you believe it, and say which
figures were taken under load). No git. No network. Never read, use or print any `ANTHROPIC_KEY_*` variable. Where the
research is wrong, say so with the measurement: your measurement outranks it.

## Final message (your report, as text)
Status; per item what you built and the proof; the hash table (solo against together); the bench table with what it
means for how many games can run at full speed on this machine; the list of files changed with a line each; the
contents of `PATCHES.md`; what changed for a pack author; what you did not verify; questions; minutes spent from real
timestamps (`date`).

## Time-box
Until the list is done or **90 minutes after your start** (run `date` first and often). Items 1 to 4 proven are worth
more than a wide bench on a shaky base. Leave the last ten minutes for the gates and the report. A usage limit can cut
you off without warning: keep the journal current.
