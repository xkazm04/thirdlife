# D2 arm a: Pip in the village (final report, 15:12)

Start 14:26:40, report 15:12: **about 45 min wall time** of the 120 min box. I can't see my token count.

## Acceptance
1. **Met.** The build script is `engine/tools/assets/pip_blender.py`. Run it in Blender 4.2.1 with `--background --factory-startup`
   and it rebuilds from an empty scene. The export is `assets/engine/pip.glb`: **986 triangles, 71,680 bytes**, 16 named
   parts, and two rebuilds give byte-identical files (sha256 0b63a6eb...). I set the budget at **2,500 triangles** for a 4.5 m
   hero prop: between the kit house (2,236) and the crane (3,168). Pip uses 40 % of that. The manifest entry is `engine.pip`
   (kind mesh, source imported, licence first-party, provenance tool `blender-4.2.1:engine/tools/assets/pip_blender.py`).
   `tl assets check` (full mode) passed all 6 steps: 37 assets, 1 foreign file, hashes match, within budget, hygiene clean.
   The triangle count in the manifest is the one I declared; the check does not count a .glb's triangles itself.
2. **Met.** Pip stands in the village of the exe at **(-38, -8.5)**: just south of the road, about 24 m ahead of the visitor's
   start position, front turned toward the visitor (yaw -60). It is in plain view from the start camera (sheet panel 2).
   It has the house look: toon bands, ink outline and palette colours, with no material, light or environment of its own.
   - Scale, measured headless in the engine: Pip is **4.500 m** sole to pennant tip, the housing's underside sits at **1.62 m**
     and its roof at **3.84 m**, and the gap between the shins is about 0.86 m. The walker's rig is **2.0 m** by its own
     metrics (RIGS.md); its mesh box is 2.18 m including the hair. The ratio is 2.25, as in the concept. The housing figures
     differ from the concept's 1.8 m and 3.7 m because the chamfer is included; see the note below.
   - The walker can walk up to Pip. A post 1.05 m wide stands in the visitor's physics space. A walk aimed at Pip's centre
     stopped 1.43 m short ("hit: landmark", 260 blocked ticks). The scripted walk to his side was never blocked.
3. **Not met, but nothing failed.** `tl check --tier full` passed **13 of 14 steps** with 940 of 940 units.
   - `world` passed: all 7 games hash the same in the world as alone.
   - kernel.selftest passed 180 of 180, seeds 39 of 39, kit 91 of 91 and packs 27 of 27 runs.
   - `perf` did not run: "could not run: machine BUSY". The machine was 59-80 % in use while other arms were running.
     The gate therefore exited with 2. I retried twice and it was still busy.
   - So I have 940 units, not the 942 of the last green run. The 2 missing units are perf's.
   - **Next:** run `tl check --tier full --only perf` on a quiet machine.
4. **The note on faithfulness:**
   - **Kept from the concept:**
     - **Housing:** the chamfered box, 2.1 m wide, with the rear wedge tail and a leaning mast with a pennant on the roof.
     - **Lens:** eight-sided rings with two accordion folds. The brow is fixed to the casing. The glass is plum and has one
       square amber glint.
     - **Wings:** a barrel hinge on each side, set out from the casing so the paddle clears the roof when it swings up. Each
       paddle is red, tapers to its tip and has one slanted ivory band.
     - **Legs:** two tapered orange segments with a faceted knuckle, an ankle block, and three wedge toes with dark tips.
     - **Colours:** yellow, flag_a, curb_white, orange and steel_dark, as the concept names them.
   - **Simplified:**
     - **Lens colours:** the style has no plum key, so the glass is `roof_slate` with one `cliff` facet as a reflection, and
       the glint is `beacon`. I did not add a palette key, because the two style files must keep the same keys in the same
       order.
     - **Housing heights:** the underside and roof are 1.62 m and 3.84 m with the chamfer included. The flat faces are at
       1.82 m and 3.64 m.
     - **Pose:** neutral standing only, with no signal pose and no wing raised.
     - **Toes:** no rear toe.
     - **Collider:** one post, not a body shaped like Pip.
   - **A next pass would add:**
     - **Animation:** the pivots are already at the joints (`wing_l` / `wing_r` at the hinges, `lens` and `lens_bellows`
       on the optical axis, the chain `leg_x` > `leg_x_shin` > `leg_x_foot` at hip, knee and ankle). It needs a wing raise,
       bellows that squash along the lens axis (scale `lens_bellows` on Z and slide `lens` back), and a step cycle.
     - **Collision:** a collider per leg and a box for the housing in the visitor's space.
     - **Exported game:** the asset in the exe. `export.sh` does not copy `assets/` yet, so the exe leaves Pip out with a
       warning.
     - **Pack assets:** a way to find a pack's own `assets/<pack>/` files at run time.

## Route (how a mesh asset gets the house look) and a premise that was wrong
The brief asks me to "find how a mesh asset gets the house look". There was no such route: KIT.md says "no imported asset
exists", and the toon material reads its palette column from CUSTOM0, which only `TLMesh` writes. I built the route:
- **Loader:** `TLKitAsset.build(path)` in `engine/kits/tl_kit_asset.gd`. Each glTF material NAME is a palette key. Every
  triangle goes through `TLMesh.tri`, so it gets a flat face, the palette column and the style's one toon material; the file's
  own materials are never used. Each glTF node keeps its name and transform, so the moving parts stay separate. It works
  headless.
- **API version:** adding the class required a version bump under `tl arch`'s api-v1 rule, so **KERNEL_API is now 1.7**.
  I added a paragraph to API.md section 14 and to KIT.md, and regenerated API-INDEX and REPORTS.
- **Placement:** the world places such a model with `landscape.landmarks` (in `engine/kernel/world/terrain/landmarks.gd`,
  called from landscape.gd). Pip is world scenery, not a pack, so no pack hash can move: the `world` step confirms it.
- **Scatter finding:** excluding the spot from the scatter reshuffled the whole village. The scatter shares one random
  generator, so the far mesas moved, which the before/after stills show. Exclusion (`clear_m`) is now opt-in and the village
  does not use it. Apart from Pip, the before and after stills are identical.

## Files
- **New:**
  - `engine/tools/assets/pip_blender.py`
  - `assets/engine/pip.glb`
  - `engine/kits/tl_kit_asset.gd` and its `.uid`
  - `engine/kernel/world/terrain/landmarks.gd` and its `.uid`
  - `docs/reports/astra-trial/d2/pip_stills.json` and `pip_stills_before.json` (the still walks: `bash engine/tools/world.sh tour <abs path> --out-dir=<abs dir> --pictures-only`)
- **Changed:**
  - `assets/manifest.json`
  - `engine/kernel/world/landscape.gd` (600 lines, at the ratchet)
  - `engine/boot/village.json` (`landscape.landmarks`)
  - `engine/kernel/runner/manifest.gd` (KERNEL_API 1.7)
  - `engine/kernel/API.md`, `engine/kits/KIT.md`
  - `docs/generated/API-INDEX.md` and the other files `tl arch --index` writes (API-V1.json, REPORTS.md)
- **Pictures:**
  - `docs/reports/astra-trial/d2/pip_sheet.jpg`: 409 KB, 6 panels: before and after on the same visitor camera, the visitor
    beside Pip, the crane three-quarter view, the crane view beside the walker, and the concept.
  - `stills/pip_stills/` and `stills/pip_stills_before/` (full size, not committed).

## Cost
About 45 min wall time. Machine time: one full gate (about 26 min, mostly kernel.selftest), 5 windowed tours of about 15 s
each, Blender runs of about 2 s each.

## Log
- 14:26 start. Read brief, concept, ASSETS.md, KIT.md, STYLE.md, landscape.gd, village.json.
- 14:30 finding: no route exists yet for an imported mesh to get the house look (KIT.md: "no imported asset"). The toon
  material reads the palette column from CUSTOM0 that TLMesh writes. Plan: Blender script names each material after a
  palette key; a kit-side loader re-emits the glb's triangles through TLMesh (flat faces, palette column, TLStyle
  material), one MeshInstance3D per Blender part. Pip is a landmark of the world's landscape (visual + visitor
  collider, never a pack), so no pack hash can move.
- 14:33 Blender script builds Pip: 16 parts, 986 tris, 4.50 m; TLKitAsset loader (engine/kits/tl_kit_asset.gd) reads it headless with the same tris and pivots.
- 14:35 first stills (stills/after1): Pip stands in the village in the house look (ink, bands); faults: lens glass and parts of the paddles/brow drawn inside out (Blender recalc_face_normals on open pieces). Fixing winding in the build script.
- 14:37 winding made explicit in the build script (each face told its outside); lens glass, paddles and brow right in
  game (stills/pip_stills). Measured headless: Pip 4.500 m tall, 4.56 wide (wings), 3.08 deep, 986 tris; the visitor's
  biped rig is 2.0 m by its metrics (RIGS.md; its mesh AABB is 2.18 m with the hair).
- 14:39 asset registered (engine.pip, mesh, 71,680 bytes); tl assets check full green; glb rebuild is byte-identical.
- 14:40 tl check fast: arch needed landscape.gd under 600 lines (landmark code moved to terrain/landmarks.gd), uids, and
  KERNEL_API 1.6 -> 1.7 for the new class TLKitAsset (api-v1 rule); then fast tier green 5/5.
- 14:41 finding: excluding Pip's spot from the scatter reshuffled the whole village (one shared generator: the mesas
  moved, seen in the before/after stills). clear_m is now opt-in and the village uses none: before and after stills
  differ only by Pip.
- 14:42 collider: visitor walked at Pip's centre, stopped 1.43 m from it (hit:landmark, 260 blocked ticks).
  Full gate started.
- 14:43 sheet docs/reports/astra-trial/d2/pip_sheet.jpg (409 KB, six panels incl. before/after on the same camera). Waiting for the full gate.
- 15:12 full gate 13/14 PASS (940/940 units, world PASS); perf NOT RUN, machine BUSY, 3 tries. Report written.
