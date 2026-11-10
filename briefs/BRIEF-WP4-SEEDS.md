# WP4: bring the kit into the engine, then three seed games

You are the builder of **WP4** in Phase 0 of the Third Life feasibility spike. Third Life is a single-player sandbox in
which an LLM designer and builder agents construct whole mini-games (hockey, racing) as verified **packs** over a frozen
**law kernel** in Godot. Three builders before you made the kernel (`engine/`), the kit, rigs and style (`kitlab/`) and
the Foreman (`foreman/`). The kernel and the kit have **never run together**. You join them, then write the three
**seed packs**: small complete games that later builder agents will learn from by analogy, with nobody to ask.

## Read first, in this order
1. `C:\Users\kazda\kiro\third-life\contracts\README.md`, `PACK.md`, `RUNNER.md`, `KIT-RIG-STYLE.md` (binding; several
   have "Amendments of 2026-11-10" sections that are newer than the code).
2. `engine\kernel\API.md` (the whole document: it is what pack authors get), then one good example pack end to end:
   `engine\kernel\examples\ex_car\` or `ex_walker\`. `engine\tools\tl.sh` for the verbs.
3. `kitlab\kits\KIT.md`, `kitlab\kits\LAYOUT.md`, `kitlab\rigs\RIGS.md`, `kitlab\style\STYLE.md`, `kitlab\tools\k.sh`.
4. The Director verification sections at the end of `docs\reports\WP1-KERNEL.md` and `docs\reports\WP2-KIT.md`: what was
   never verified, the decisions to apply, and one known trap (a `Skeleton3D` posed outside the scene tree stops
   updating; a rig must be in the tree before its first `tick` or `play`).

## Your scope
`engine/**` (all of it, including `engine/kernel/**` for the integration fixes below) and the move out of `kitlab/`.
Do not touch `foreman/`, `contracts/`, `briefs/`, `docs/`, `spike/` or `site/`.

Another builder is finishing the Foreman at the same time. It tests against a frozen copy of the engine in
`site/_engine_snapshot/`, not against `engine/`, so you are the only one running Godot in `engine/`.

## Step 1: join kit and kernel (do this first and prove it before any seed)
1. Move `kitlab/kits`, `kitlab/rigs`, `kitlab/style` into `engine/` (same names, so every `res://` path holds). Move
   the kit's lab scenes to `engine/kits_lab/` and its tool to `engine/tools/k.sh`, fixing paths, so
   `bash engine/tools/k.sh selftest` and `validate` still pass inside the engine project. Leave `kitlab/JOURNAL.md`,
   `kitlab/captures/` and `kitlab/project.godot` where they are, with a one-line `kitlab/MOVED.md` saying where things went.
2. Make the kernel use the real thing: `TLKit` parts become bodies with law-table physics from their `tl_material`
   tags; dynamic props (`tl_dynamic`) get kernel bodies; a fracturable kit part (`barrier_wall`, `crate`) breaks, sleeps
   and bakes through `TLFracture`; `TLBiped` and `TLVehicle` drive real `TLRigs` rigs (sizes from `metrics()`,
   `set_locomotion`, `play`, `set_param`, `tick`); `TLStyle.install` gives the look in windowed runs and does nothing
   harmful headless. Stand-ins stay as the fallback.
3. Apply the Director's decisions from the WP1 report: a bot that does not finish in its frame budget is exit 1,
   `failed`; captures default to Direct3D 12.
4. Prove it: `bash engine/tools/tl.sh selftest` and `bash engine/tools/k.sh selftest` both pass; add selftest cases
   for each item in point 2 (a kit ball on kit ice slides by the ice law; a kit wall breaks; a rigged biped walks and
   skates; a rigged vehicle drives). Capture one windowed frame of each and **look at it**.

**Every change you make under `engine/kernel/` goes in a list** in your journal and your report: file, what, why, lines.
That list is a finding about how well the two contracts fitted, not a failure.

## Step 2: three seed packs under `engine/seeds/`
Each is a complete small game with a win condition, built **from kit parts, rigs, kernel primitives and data**, passing
all five verbs, with at least one bot that plays it to the end through input actions, and two named cameras.

| Pack id | Game | Must exercise |
|---|---|---|
| `seed.paddle` | Ball-and-paddle in a walled court: the player moves a paddle, an AI moves the other, first to 5 wins | `ball`, `rules` (score, win), `input`, `ai`, `ui`, `kit` |
| `seed.drive` | Drive-around sandbox: a car on a small road loop with cones and checkpoints, three laps against the clock, a nitro pad | `vehicle`, `rules` (laps, clock), `camera` (chase), `kit` layout, `spawn` |
| `seed.wall` | Destructible wall: a biped throws or kicks balls to knock down a barrier wall within 60 seconds; score by pieces down | `biped`, `fracture`, `physics`, `vfx`, `audio`, `rules` (clock) |

Rules for the seeds:
- **They must not be hockey or racing**, and must not contain a skating player with a stick, a puck game, or cars racing
  each other: those are the later honest tests. A solo timed drive and a ball-and-paddle court are fine.
- **Data first.** Tuning, layout and rules live in `data/*.json`; scripts are glue. Use `TLKit.build_layout` for the
  venue. Zero `bypasses` in lint is the target; if you must bypass, the lint figure will say so and you explain it.
- **Written to be read.** Short scripts, a `README.md` per seed (what it shows, which API calls, how the bot decides it
  won), comments where a reader would otherwise guess. A later agent gets these three and `API.md` and nothing else.
- Each seed gets a `play` check: `tl.sh play --pack=...` opens it with real keys. You cannot hand-play; make the bot the
  proof and say so.

Also write `engine/seeds/README.md`: **how to write a pack**, ten minutes of reading: the lifecycle, data first, the
verbs to run in order, how to write a bot, the ten mistakes you actually made while writing the seeds.

## Look at your output
For each seed capture both cameras with the bot playing (`capture --test=...`) at two different frames and look at the
images. The look is lane B's; `spike/lab/b/captures/director/pass4_builder/b_hero.png` is the bar. Put a contact sheet
at `engine/seeds/captures/seeds_sheet.png`.

## Acceptance (the Director will run these)
- `bash engine/tools/tl.sh selftest` and `bash engine/tools/k.sh selftest` pass.
- For each seed: `lint`, `smoke`, `invariants`, `bot` exit 0; `lint` reports zero fence errors; the composability
  figures are in your report (script lines, kit parts added, bypasses).
- Same seed gives the same `state_hash` twice; a different seed changes it where the game uses `ctx.rng`.
- `engine/seeds/captures/seeds_sheet.png` exists and you have looked at it.
- Nothing in `engine/` references `kitlab/`.

## How to work
Small verified steps; journal after each in `engine/JOURNAL.md` (append under a "WP4" heading; the WP1 journal above it
is history). Kill every process you start; never kill others (other sessions run Godot and a GPU benchmark here). No
git. No network. No interactive window; captures go through the runner. If your context is getting full, stop at a
clean point with the journal current and return what you have: Step 1 finished and proven is worth more than three
half-seeds.

## Final message (your report, as text)
Status; Step 1 proof (both selftests, the new cases, what you saw in the frames); the kernel change list; per seed:
verbs passed, bot summary, script and data lines, kit parts added, bypasses; where `API.md`, `KIT.md` or the contracts
misled you (proposed wording); what the kernel or kit still lacks for a hockey game and for a racing game, as you now
see it, without building either; capture paths; minutes spent from real timestamps; questions.

## Time-box
Until the list is done or **22:45 CEST today**, whichever comes first (check with `date`). Leave the last 20 minutes
for the selftests, the sheet and the report. A usage limit can cut you off without warning: keep the journal current.
