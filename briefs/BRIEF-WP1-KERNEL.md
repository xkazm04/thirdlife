# WP1: law kernel, host and runner

You are the builder of **WP1** in Phase 0 of the Third Life feasibility spike. Third Life is a single-player sandbox in
which an LLM designer and builder agents construct whole mini-games (hockey, racing) as verified **packs** over a frozen
**law kernel** in Godot. You build that kernel, its host and the runner that verifies packs. Later agents will write
packs against your API with no help from you, so the API and its documentation are the product.

## Read first, in this order
1. `C:\Users\kazda\kiro\third-life\contracts\README.md` (ownership, global rules), then `PACK.md`, `pack.schema.json`,
   `RUNNER.md`, `KIT-RIG-STYLE.md` in the same folder. `JOB.md` only for background.
2. `C:\Users\kazda\kiro\third-life\docs\FEASIBILITY.md` sections 4 to 6 (layers, verification stack, principles).
3. Skim, for proven patterns only (do not copy its structure): `C:\Users\kazda\kiro\third-life\spike\lab\b\src\sim.gd`,
   `player.gd`, `look.gd` (car on a path, pre-fractured wall woken and baked, chase camera, an input-driven play test)
   and `spike\lab\b\tools\g.sh`.

## Your scope
`engine/project.godot`, `engine/kernel/**`, `engine/tools/**`, `engine/packs/.gitkeep`, plus `engine/JOURNAL.md`.
Nothing else. Godot 4.7.2, Jolt physics, Forward+ renderer, fixed 60 Hz physics.

## What to build, in priority order
Stop at a clean point if time runs out; an honest partial kernel with a solid verification spine is worth more than a
wide one that lies.

1. **Host and runner** exactly as `contracts/RUNNER.md`: `res://kernel/host/host.tscn`, the five verbs, exit codes, the
   `tl.verify/1` report written to `--report` and printed as the last stdout line. `engine/tools/tl.sh` wrapper.
   Detecting script errors Godot only prints is the hard part: solve it properly (for example a custom `Logger` if
   4.7 has one, or the runner re-launching the sim as a child and reading its stderr). State which you used and why.
2. **Pack loader and context**: load a pack from an absolute directory or a `res://` path; manifest check against the
   schema (implement the checks in GDScript; unknown keys are errors); run `gen/` generators, then the entry
   lifecycle; `ctx` with the members named in `PACK.md`.
3. **Lint** (V0 + V1): layout, the fence patterns, capability use, size limits, and the composability figures
   (`gdscript_lines`, `kit_parts_added`, `bypasses[]`). Lint works on text, strips comments and strings before
   matching, and reports file and line.
4. **Determinism and watchdog**: seeded rng, a `state_hash` over body transforms, velocities and `_pack_state()`,
   stable to rounding (quantise before hashing); frame-counted watchdog and the V3 budgets.
5. **Law tables**: `res://kernel/data/materials.json` with the material ids in `KIT-RIG-STYLE.md` and columns density,
   friction, restitution, hardness, flammability, sound set, breaks_into; **surface rules** (pairwise friction and
   restitution overrides, for example rubber on ice); applied to any body tagged `tl_material`.
6. **Primitives** (each a small documented class with an example in `engine/kernel/examples/`):
   bodies and triggers; **ball/puck** (sliding and bouncing with material laws); **biped controller** (walk, run, and a
   `skate` mode with low lateral grip and momentum) and **vehicle controller** (raycast wheels sized from
   `rig.metrics()`, steer, throttle, brake, grip from the surface under each wheel, a nitro boost), both driving a rig
   through the duck-typed calls in `KIT-RIG-STYLE.md` and falling back to a plain stand-in rig when none is given;
   **input** (named actions a pack declares, readable by the player and injectable by bots through one door);
   **rules** (score, clock, periods or laps, win conditions as a small state machine with signals); **spawner**;
   **contact and damage** (impulse thresholds by hardness) and **fracture** (the `Intact`/`Pieces` convention: wake,
   sleep, bake); **cameras** (chase, orbit-limited pitch 30 to 60 degrees; fixed named capture views).
7. Then, only if time allows: steering helpers for AI (seek, pursue, avoid, keep-lane), HUD widgets (score, clock,
   speed), VFX and audio **presets** as names with stand-in implementations.

For every primitive ask: could a hockey game and a racing game both be built from this without changing the kernel?
You may not build hockey or racing yourself, and your examples must not be either (they are the later honest tests);
use neutral examples (a ball on a ramp, a box car on a slalom, a walker in a room, a wall that breaks).

## Stand-ins
WP2 builds kits, rigs and style in parallel in another project and you must not wait for it or touch it. Ship
`engine/kernel/standin/` with a minimal rig (capsule or box answering every method in the rig table) and no dependence
on `TLKit`, `TLRigs` or `TLStyle`: check `ClassDB`/script existence at run time and degrade with one clear log line.

## Documentation you owe (inside your scope)
- `engine/kernel/API.md`: every class, method, signal and data file a pack may use, with a short example each, the
  capability each belongs to, and a list "what the kernel does not do yet".
- `engine/kernel/examples/`: at least one tiny valid pack, `engine/kernel/examples/pack_min/`, that passes all five
  verbs, and one deliberately bad pack per failure kind you can detect (schema, fence, script error, watchdog,
  non-determinism) used by your self-test.
- `engine/tools/tl.sh selftest`: runs every verb on the good pack and each bad pack and checks exit code and report.

## Acceptance (the Director will run these)
- `bash engine/tools/tl.sh selftest` passes and prints one PASS/FAIL line per case.
- `smoke` on `pack_min` for 3,600 frames headless: exit 0, zero script errors; run twice with the same seed gives the
  same `state_hash`; a different seed gives a different one when the pack uses `ctx.rng`.
- `lint` rejects each fence pattern with file and line, rejects an unknown manifest key, and reports bypasses.
- A pack with an endless loop ends with exit 3 and `outcome: "watchdog"`, not a hang.
- Friction and restitution on a tagged body come from the table (show it with a measured slide distance on ice
  against asphalt in an example, as numbers in the report).
- No wall-clock dependence anywhere in checks.

## How to work
Work in small verified steps: write, run headless, read the output, fix. Journal after each step in
`engine/JOURNAL.md`. Kill every process you start; never kill others. No git. No network.

## Final message (your report, as text)
Status; what exists and what does not, against the priority list; the selftest output; the API surface as a short
table; how script errors are detected; determinism evidence; lines of code; what a pack author will find awkward;
questions for the Director; minutes spent from real timestamps.

## Time-box
Until the list is done or **21:45 CEST today**, whichever comes first (check with `date`). Leave the last 20 minutes
for the selftest, the API document and the report. A usage limit can cut you off without warning: keep the journal
current.
