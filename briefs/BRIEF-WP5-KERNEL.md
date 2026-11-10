# WP5: close-out fixes in the engine before the second real job

You are a **new builder taking over `engine/`** (Godot 4.7.2 project: law kernel, kit, rigs, style, three seed packs) in
Phase 0 of the Third Life feasibility spike. Third Life is a single-player sandbox in which an LLM designer and builder
agents construct whole mini-games as verified **packs** over a law kernel. Four builders before you made everything in
`engine/`; all of it is verified. The first real job (Claude CLI builders writing a marble-run pack from one sentence)
exposed four defects. You fix them. Right after you finish, the Director copies `engine/` and runs a second real job
on it, so leave it green.

## Read first, in this order
1. `C:\Users\kazda\kiro\third-life\contracts\README.md`, then the **last "Amendments of 2026-11-10, second round"
   section** of `contracts\RUNNER.md`, `contracts\KIT-RIG-STYLE.md` and `contracts\PACK.md`: they are your work list.
2. The "Director verification" section at the end of `docs\reports\WP4-SEEDS.md` (findings 1 to 3, decisions 1 to 5).
3. `engine\JOURNAL.md` ("WP4" section), `engine\kernel\API.md`, `engine\seeds\README.md`, `engine\tools\tl.sh`.
   Grep before you read source.

## Your scope
`engine/**` only. **Read-only:** `site/marble-run-three-marbles-20261110-1/pack/` (the pack from the first real job; use
it as a test input, never edit it). Do not touch `foreman/`, `contracts/`, `briefs/`, `docs/`, `kitlab/`, `spike/`, or
anything else under `site/`. Another builder works in `foreman/` at the same time and does not run Godot in `engine/`.

## The work, in this order

1. **Pack-made geometry renders almost black.** Reproduce first:
   `bash engine/tools/tl.sh capture --pack=<abs path of the marble pack> --cam=course --test=tests/bot_race.gd --frame=1000 --out=<abs png>`
   and look at the image (the Director's copy: `docs\reports\img\marble_on_live_engine_f1000.png`: near-black wood, ice
   and marbles against the painted sky). The pack builds boxes with `TLBodies.make(..., {"color": ...})` and its own
   `StandardMaterial3D`, and builds **no kit layout**. Find the real cause (no light when no layout is built? the
   post-process? stand-in materials?) and fix it in the kernel or style layer so that:
   - a body made by `TLBodies.make` / a stand-in from a material id and a `color` gets a style material
     (`TLStyle.material`) when the style is installed;
   - a pack that builds no venue still gets a lit, readable scene (a default sun, ambient and ground the style owns);
   - a pack's own plain `StandardMaterial3D` is lit sensibly too.
   Prove it with a before and an after capture of the marble pack, both looked at. Headless behaviour and state
   hashes of the seeds must not change because of a visual fix; say so if they do, and why.
2. **`invariants` replays the pack's first bot twice** with the same seed and compares the state hashes: check id
   `invariants.bot_deterministic`. Add a bad pack whose bot run is non-deterministic while its idle run is not, and a
   selftest case that expects exit 1 for it. Keep the idle check.
3. **`TLVfx` presets render through the style layer's effects** when the style is installed (today: unlit white squares
   that fly wide, see the wall frames in `engine\seeds\captures\seeds_sheet.png`). Capture `seed_wall` before and after
   and look.
4. **What a pack author reads.** A later builder agent gets copies of `engine\kernel\API.md`, `engine\seeds\**`,
   `engine\kits\KIT.md`, `engine\kits\LAYOUT.md`, `engine\rigs\RIGS.md`, `engine\style\STYLE.md` and nothing else, and
   has 12 minutes. Make sure `API.md` opens with a half-page "start here": use `TLKit.build_layout` for the venue and
   kit parts for objects before making boxes; let the kernel give materials (never create `StandardMaterial3D`); copy
   the nearest seed; the verbs to run in order. Fix anything in those documents that the marble-run builder would have
   tripped on (it made every shape from `BoxMesh` because nothing told it about the kit). Do not rewrite them.
5. If time remains: `set_script` after `add_child` in a generator silently did nothing in the marble pack
   (`gen/look.gd` there). Find out whether the kernel can warn about a generator or dressing script that ran and
   changed nothing, and say what you found; build it only if it is small.

## Acceptance (the Director will run these)
- `bash engine/tools/tl.sh selftest` passes on a quiet machine, with the new case from item 2.
- `bash engine/tools/k.sh selftest` and `bash engine/tools/tl.sh seeds` pass; every seed gives one hash for the same seed
  three times.
- The marble pack still passes lint, smoke, invariants and bot on your engine, and its capture is lit and readable.
- Every change under `engine/kernel/` and `engine/style/` is in a list: file, what, why, lines.

## How to work
Small verified steps; journal after each in `engine/JOURNAL.md` (append under a "WP5" heading). Kill every process you
start; never kill others (other sessions run Godot and a GPU benchmark here; wall-clock checks can fail under load, so
re-run a clock-only failure once before you believe it). No git. No network. No interactive window; captures go through
the runner. Never read, use or print any `ANTHROPIC_KEY_*` variable.

## Final message (your report, as text)
Status; per item what you found, what you changed and the proof; the change list; both selftest counts and the seeds
count from your last run; what you saw in each capture, with full paths; whether any seed hash changed; what you did not
verify; questions; minutes spent from real timestamps (`date`).

## Time-box
Until the list is done or **22:10 CEST today**, whichever comes first (check with `date` at the start and often). Order
is the priority: items 1 and 2 finished and proven are worth more than five half-done. Leave the last ten minutes for the
selftests and the report. A usage limit can cut you off without warning: keep the journal current.
