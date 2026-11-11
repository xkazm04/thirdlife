# N5b: draw many games in one landscape

You are the builder for **drawing the world** of Third Life, a single-player sandbox on Godot 4.7.2 in which an LLM
builds small games ("packs"). The look is an inked low-poly toon style made in code: one shared palette material, an
ink pass on depth and normals, a grade pass. Earlier tonight builder N2 proved that many packs can run in one process,
each in its own physics space, **and measured that a pack must be simulated at its own origin**: placed even 64 m away
its results change and bots stop finishing. So every pack's nodes sit at the origin of its own space, on top of each
other. Nobody has drawn a world yet. You do: several games standing apart in one landscape, in one picture.

## Read first
1. `docs\reports\N2-MANY.md` (its "Per item" section 3 and "Not verified"), then in the engine
   `kernel\world\world.gd`, `kernel\world\pack.gd`, `kernel\world\BENCH.md` (test 5), `kernel\API.md` section 19.
2. `engine\style\STYLE.md`, `engine\style\tl_style.gd`, `engine\style\shaders\toon.gdshader` and `ink_post.gdshader`
   (the look was reworked tonight: `docs\reports\N1-LOOK.md`), `engine\look\sheet_before_after.png`.
3. The concept the owner wants to reach, which shows a rink, a track and a house in one landscape:
   `spike\lab\ref\B_toon_ink.png`.
4. `reports\Living world layering for Third Life.md`, section "Godot streams by hand" only.

## Where you work
**Your own copy of the engine: `C:\Users\kazda\kiro\third-life\site\_work\n5b\engine\`** (a copy of the main tree
with N1, N2 and N4 merged). `TL_GODOT=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe`.
Yours: new `kernel/world/draw/**`, `style/**`, `kits/**` (only what a stand-in mesh needs), new `tools/view.sh`.
Another builder is changing the scheduler in `kernel/world/world.gd` and `pack.gd` in a different copy tonight: **read
them, do not edit them**; if you need a hook there, write the exact patch and its reason to
`kernel/world/draw/PATCHES.md`, and build your viewer so that it works with the files as they are (it may create and
drive N2's world and pack objects itself).

## The problem, and two candidate answers to measure
Each pack is simulated at its own origin; the picture must show pack i at its plot, `origin_i` and `yaw_i`. Godot gives
a node one transform for both physics and drawing, and a `World3D` ties one drawing scenario to one physics space.

- **Candidate A: offset in the shaders.** Every material of the look comes from the style layer. Give the style's
  shaders a per-instance plot transform (an `instance uniform`: an offset and a yaw) applied in world space in
  `vertex()`, set once on each `GeometryInstance3D` of a pack when the pack is placed, and never touched per tick.
  Things to settle: culling (the engine culls with the unshifted bounds: `custom_aabb`, `extra_cull_margin`, or a
  pack-level test by the kernel), shadows (the shadow pass runs the same vertex shader: check), the ink pass, lights
  inside a pack (not geometry: they need another way), particles, skinned rigs, glass, water and hologram shaders,
  a pack that brought its own `StandardMaterial3D` (a counted bypass: it will not move; say what happens).
- **Candidate B: mirror instances.** The kernel hides a pack's own visuals and creates, through `RenderingServer`,
  one instance per visual at `plot_i * node.global_transform`, updated on the ticks the pack steps.
- **The stage rule, for both:** the pack the player is in is drawn at zero offset (its own cameras, its HUD and the
  player's precision stay native), and everything else, the ground included, is drawn relative to it. Changing the
  stage pack re-bases every offset once.

Build the smallest version of A first and measure it; build B only as far as needed to compare, or where A cannot
work. Your measurement decides, not this brief.

## The work, in this order
1. **A viewer.** `bash tools/view.sh shot --packs=<a>,<b>,... --at=<x:y:z,...> --stage=<index> --cam=<name|overview>
   --frame=<n> --out=<abs png>`: a window at `--position 0,1440`, `--rendering-driver d3d12`, 1920x1080 (see how
   `kernel/host/host.gd` spawns a windowed worker), packs loaded through N2's world host, each played by its bot, the
   style installed once. `--cam=overview` is a high crane view over all plots; a name is one of the stage pack's own
   views.
2. **The offset**, candidate A then B as above, until the three seeds and two example packs stand on five plots 80 m
   apart on one ground and the picture is right from the stage pack's camera and from the overview: positions,
   shadows, ink lines, lights, rigs, particles, HUD of the stage pack only. Look at every capture.
3. **Simulation is untouched.** With drawing on, every pack's state hash equals its headless hash from
   `world.sh run`. A drawing change that moves a hash is a bug.
4. **Far games.** A stand-in for a far pack: one merged low-detail mesh built by the kernel from the pack's own
   visuals when the pack is placed (palette colours kept, small parts dropped), shown instead of the full pack beyond a
   distance, with a margin so it does not flicker. Compare draw calls, primitives and frame time for 6, 12 and 24 packs
   with all drawn in full, and with the far ones as stand-ins. Check the ink lines on stand-ins at 200 and 500 m.
5. **The landscape between plots**, as far as time allows: one continuous ground under all plots in the style, plots
   that do not show a seam where a pack's own ground ends, the sky and far scenery drawn once. The concept shows hills
   and a road between venues; a flat, well-drawn ground with clean plot edges is enough tonight.
6. **The picture for the owner.** `kernel/world/draw/captures/world_overview.png` and
   `world_from_<stage>.png` for two different stage packs, plus one with 12 or more packs. Put the best one beside the
   concept in `kernel/world/draw/captures/world_vs_concept.png`.

## Acceptance (the Director will run these in your copy and look at the pictures)
- `bash tools/tl.sh selftest`, `bash tools/k.sh selftest`, `bash tools/tl.sh seeds` pass; seed hashes unchanged; a
  single pack run through `tl.sh capture` looks as it did (compare one frame per seed with `engine/look/after/`).
- The five-plot world: `view.sh shot` from two stage packs and the overview, each pack at its plot, nothing drawn at
  the wrong place, shadows and lines present, and the hash check of item 3 printed for each pack.
- `kernel/world/draw/DRAW.md`: which candidate you kept and why, with the measurements; what does not move with a
  pack (lights, foreign materials, anything else) and what you did about it; the cost table of item 4; the limits.

## How to work
Small steps, each followed by a capture you look at; journal in `kernel/world/draw/JOURNAL.md`. Kill every process
you start; never kill others (a real job, other builders and other sessions run Godot and a GPU benchmark here
tonight: say which figures were taken under load). No git. No network. No interactive window: pictures come from
`view.sh shot`. Never read, use or print any `ANTHROPIC_KEY_*` variable. Where a premise is wrong, say so with the
evidence and propose the alternative.

## Final message (your report, as text)
Status; the mechanism you kept and the evidence; per item what was built and the capture that proves it (full paths);
the hash check; the cost table; what a pack author must know; the contents of `PATCHES.md`; what is still wrong in the
picture against the concept; what you did not verify; questions; minutes spent from real timestamps (`date`).

## Time-box
Until the list is done or **90 minutes after your start** (run `date` first and often). Items 1 to 3 with pictures
you have looked at are worth more than the rest. Leave the last ten minutes for the gates and the report. A usage
limit can cut you off without warning: keep the journal current.
