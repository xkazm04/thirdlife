# Look-test builder brief: common rules (both lanes)

You are a builder in the **Third Life** feasibility spike. Third Life is a single-player sandbox in which an
LLM "designer" and builder agents construct whole mini-games (a hockey arena with AI skaters, a racing circuit
with destructible walls and nitro) inside the player's world, over hours, visibly, at a construction site.
Nothing about that is built yet. Your job is the **art-feasibility experiment**: build the look-test scene in
`SCENE.md` in one art direction, measure what it cost and how it performs, and report honestly. The product
question you serve: *can an LLM builder produce this look at game scale, and what does it cost?*

Read first, in order: `spike/lab/SCENE.md` (the wire contract), then your lane brief, then the reference
images named there (use the Read tool; look at them properly, they are the target).

## Decisions already made (do not reopen; counter-propose with evidence if one blocks you)
- Engine Godot 4.7.2 + Jolt; world is **objects with material tags**, not a voxel substrate (a voxel LOOK is
  allowed as an authoring style, that is exactly what lane C tests).
- **Chase camera**, orbit-limited pitch 30-60 degrees. Backs and undersides of assets may be cheap; LOD is legal.
- Assets are made by **scripts an LLM can write** (Blender-Python and/or GDScript/Python generators), not by hand
  and not by generative-3D models. Scripts are the source of truth; GLBs/meshes are build outputs. Parametric
  kit parts (wall, truss, rib, road spline, ice rink, car chassis, bot, biped) beat one-off models; build the
  scene FROM a kit so the same parts could build other arenas.
- Characters use shared standard rigs (biped with Godot humanoid bone names; small bot; vehicle). Do not author
  bespoke rigs per object.
- Style is global data (`data/style.json`), see SCENE.md.

## Reuse before building (read-only sources; copy what you need into YOUR lane)
`C:/Users/kazda/kiro/gtai-3d-spike/` is a previous Godot+Blender spike by the same owner with a proven pipeline:
`art/blender/common.py` (box/cyl/ball/torus/tube/armature/skin/export helpers and a PALETTE-keyed `mat`),
`shaders/toon.gdshader`, `shaders/ink_post.gdshader`, `shaders/paper.gdshader`, `src/look.gd`, `src/stage.gd`,
`tools/g.sh` and `tools/b.sh` (capture/build wrappers), `src/shot.gd`, `src/reel.gd`, `src/bot.gd`.
Its `docs/STATUS.md` records measured agent costs (a rigged character took 30-70 min and 10-20 rounds, and an
early pass was judged "undercooked"): so plan look-and-fix loops (render, LOOK at the image with the Read
tool, fix, repeat), never a single pass. Do not modify that project or any directory outside your lane.

## How to work
- Work ONLY inside `spike/lab/<lane>/` (+ read access elsewhere). The other lane runs in parallel in a sibling
  directory with its own Godot project; never touch it. Other unrelated Godot/GPU sessions may be running on
  this machine: never kill a process you did not start; kill every process you start when you finish. Use
  Godot's `--position 0,1440 --resolution ...` pattern from gtai g.sh so windows open on the secondary screen,
  and prefer headless where a window is not needed.
- **Journal as you go** in `JOURNAL.md` (timestamp, action, result, measurement). If you are interrupted you
  resume from it. Keep an **authoring ledger** (asset or system, tool used, wall minutes, number of render-and-fix
  rounds, tri/voxel count, what you hand-fixed) from the first asset: it is a deliverable.
- **Look at your own output.** After every visual change, capture and Read the PNG and critique it against the
  reference: silhouette readability, material richness, atmosphere, character appeal, destruction readability,
  consistency across assets. "It rendered" is not evidence that it looks right.
- **No git operations.** The Director commits. Do not create branches, stash or reset anything.
- No network and no downloaded binaries/assets. Python libs via pip into a lane-local `.venv` are OK; list them
  in the report. If you need something that is missing (a tool, a path, a decision), STOP and return the
  question, or counter-propose; never guess silently.
- Time-box: **pass 1 ends when acceptance is met or at about 5 hours of wall time, whichever comes first.**
  Spend effort where the scene's *look* is decided (hero composition, lighting, silhouettes, the arena, the
  car and the avatar) before polishing the long tail. Report where you ran out, not a polished fiction.

## Report (`REPORT.md`, required, written last, honest)
1. **Result in five lines**: does it run, does it look good, what are you proud of, what is weak, one-line verdict.
2. **Captures**: paths and a one-line caption each; say which frame is your best and which is your worst.
3. **Perf table** from `--stats` (and how measured); the labelled 1080p mid-range estimate.
4. **Authoring ledger table**: every asset/system with tool, wall min, rounds, tri/voxel count, hand-fixes.
   Total agent wall time and the share spent on look-and-fix loops vs first-time generation.
5. **Rubric** (1-5 each, with one sentence of EVIDENCE referring to a capture): silhouette readability,
   material richness, atmosphere/lighting, character appeal (avatar and bots), destruction readability,
   cross-asset consistency, "reads as a shipped indie game" overall. Then a list of "looks weaker than the
   reference, and why".
6. **Reusability test**: which parts are parametric kit pieces that could build a *different* arena or
   circuit, and which are one-offs. Estimate agent-hours to produce a new kit-class asset of average
   complexity, from your ledger.
7. **Style-as-data result**: how much of the look the data file really controls; what still needs code.
8. **Challenges and risks** specific to your lane (the brief lists the ones to settle) and the **recommendation**:
   what you would do for the real game, and what you would NOT do.
9. **Open questions** for the Director.

Return to the Director a short structured summary (not the report text): status (done / partial / blocked),
the five capture paths, the perf one-liner, ledger totals, the recommendation, and any questions.
