# N1: raise the look toward the concept, with no generative model

You are the builder for the **look** of Third Life, a single-player sandbox on Godot 4.7.2 in which an LLM builds small
games ("packs") over a law kernel. The look is an inked low-poly toon style made entirely in code. The owner has set
the target: **the level of the concept image is acceptable**, and tonight's work uses shader, camera, light, palette,
post-process and motion only. No image or 3D generation, no imported asset.

## Read first
1. `C:\Users\kazda\kiro\third-life\spike\lab\ref\B_toon_ink.png` (the concept) and
   `C:\Users\kazda\kiro\third-life\spike\lab\b\captures\b_pass4_ref.png` (concept beside the art lane's best frame),
   then `C:\Users\kazda\kiro\third-life\engine\seeds\captures\seeds_sheet.png` (what the seed games look like today).
   Look at all three before reading code.
2. `engine\style\STYLE.md`, `engine\kits\KIT.md` (skim), the camera section of `engine\kernel\API.md`,
   `engine\seeds\README.md`, `engine\tools\tl.sh`, `engine\tools\k.sh`.
3. `spike\lab\b\REPORT-PASS4.md` lines 127 to 147 and 200 to 227 (what four art passes left weaker than the concept).

## What the Director sees wrong today (your work list, in priority order)
1. **No way to compare.** The engine's own frames have never been put beside the concept. First build
   `engine/tools/look.sh`: `look.sh shots <dir>` captures a fixed set (each seed's two cameras at two frames, plus the
   kit lab hero through `k.sh cap`), `look.sh sheet <before dir> <after dir> <out.png>` lays them out beside the concept
   with ffmpeg. Take the **before** set first and keep it in `engine/look/before/`.
2. **Lines.** The concept has bold, even, dark outlines on every object and clear interior lines. Ours are thin, wiry
   and turn lattices, fences and scaffolds into noise; the ink pass is a post-process at native resolution with no
   smoothing (`engine/style/shaders/ink_post.gdshader`). Make near outlines bold and even, smooth the line edge, give
   the inner line a distance rule, and stop lines from swallowing thin members.
3. **Colour.** The concept keeps cool violet shadows against warm light and clean local colours. Our grade pushes
   everything orange, tints ice and tarmac purple and crushes greens in the seed frames
   (`shaders/grade.gdshader`, `style.json` `grade`, `toon`, `sun`, `palette`). Fix it in the style data and shaders,
   and keep `style_overcast.json` working.
4. **Scale and framing.** The concept draws actors large. Ours are a few dozen pixels. Nothing frames a subject or
   measures its size. Add to `engine/kernel/api/tl_cameras.gd`:
   `TLCameras.frame(subject: Node3D, fill: float = 0.35)` (place the active view so the subject's bounds fill that
   fraction of frame height), `TLCameras.subject_px(subject: Node3D) -> float` (fraction of frame height the subject
   covers now, 0 when off screen), `TLCameras.shake(amount: float, frames: int)` (visual only). Give the chase and
   orbit cameras a deliberate field of view (they inherit Godot's 75 today) and smoothing. Then make the three seeds'
   cameras frame their main actor (seed data and seed scripts are yours to edit for cameras only).
5. **Ground and surfaces.** The concept has drawn tufts, rocks, edges and paths. Ours shows large flat triangles.
   Improve what the toon shader and the kit draw on ground and terrain.
6. **Light.** There is no contact shading, no depth of field, no volumetric light. The toon shader disables ambient
   light, so screen-space ambient occlusion may have no effect: find out, and keep only what visibly helps.
7. **Motion**, if time remains: squash and stretch, a trail helper, impact shake. Visual only, never simulation state.

## Scope
You work in the main tree. Yours: `engine/style/**`, `engine/rigs/**` (visuals only: no change to a rig's metrics or
clips' timing), `engine/kits/**` (surface and ground detail only), the three files
`engine/kernel/api/tl_cameras.gd`, `tl_chase_cam.gd`, `tl_orbit_cam.gd`, camera data and camera lines in
`engine/seeds/**`, new `engine/tools/look.sh`, new `engine/look/**`.
**Not yours:** every other file under `engine/kernel/` (another builder is rebuilding the kernel in a separate copy
tonight), `engine/tools/tl.sh`, `foreman/`, `contracts/`, `briefs/`, `docs/`, `site/`, `spike/` (read only).
Do not edit `engine/kernel/API.md`: write the camera section's new text to `engine/look/API-cameras.md` and the
Director merges it. `TLOrbitCam` reads the mouse outside the input record; leave that alone.

## Acceptance (the Director will run these)
- `bash engine/tools/tl.sh selftest`, `bash engine/tools/k.sh selftest` and `bash engine/tools/tl.sh seeds` pass.
- **No seed's state hash changes**: the look never touches simulation. Smoke hashes today begin `bc93a9a4` (paddle),
  `b9adbb19` (drive), `da4bdc3f` (wall). If a camera change moves a hash, you changed simulation: undo it.
- `TLCameras.subject_px` of each seed's main actor in its play camera is at least 0.08.
- Frame cost: `bash engine/tools/k.sh stats <layout> <cam>` before and after; draw calls and primitives reported;
  the after figure is within 1.5 times the before figure. Report GPU time only if you can measure it honestly.
- `engine/look/before/`, `engine/look/after/` and `engine/look/sheet_before_after.png` exist, and you have looked at
  the sheet yourself after every change that mattered. A change you did not look at does not count.
- A rubric table: lines, colour, scale, ground, light, motion, "shipped indie game": each scored 1 to 5 before and
  after, with the frame that shows it. Be hard on yourself: the Director scores the same sheet.

## How to work
Small steps, each followed by a capture you look at. Journal each step in `engine/look/JOURNAL.md`. Kill every process
you start; never kill others (other sessions run Godot and a GPU benchmark on this machine; a wall-clock failure is
re-run once before it is believed). No git. No network. No interactive window: pictures come from the runner
(`tl.sh capture`, `k.sh cap`). Never read, use or print any `ANTHROPIC_KEY_*` variable. If the constraint in a step is
wrong, say so with the evidence and propose the alternative; do not guess.

## Final message (your report, as text)
Status; per item what you found, what you changed and the frame that proves it (full paths); the rubric; the selftest,
kit and seeds counts from your last run; whether any hash changed; frame cost before and after; what is still weaker
than the concept; what you did not verify; questions; minutes spent from real timestamps (`date`).

## Time-box
Until the list is done or **80 minutes after your start** (run `date` first and often). Items 1 to 4 finished and
looked at are worth more than seven half-done. Leave the last ten minutes for the gates and the report. A usage limit
can cut you off without warning: keep the journal current.
