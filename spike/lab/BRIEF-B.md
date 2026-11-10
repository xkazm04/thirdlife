# Lane B brief: "inked low-poly with painterly atmosphere" (primary, must achieve)

Lane directory: `spike/lab/b/`. Read `BRIEF-COMMON.md` and `SCENE.md` first.

## The direction
Take the **geometry budget of A** (`ref/A_lowpoly.png`: faceted, bevelled kit primitives, no texture reliance),
the **ink and toon language of B** (`ref/B_toon_ink.png`: clean outlines on silhouettes and creases, 2-3 flat
shading bands, hatched shadow accents), and the **light and atmosphere of E** (`ref/E_painterly_gouache.png`:
colour-temperature lighting, haze layers, big simple shapes, gradient sky, almost no small detail). The target
is "looks premium from simple shapes": shape and lighting carry it; no detail that has to be hand-modelled.
You are the **achievable primary** lane: this must run, look good, and be a plausible production look.

## Mandatory approach
1. Start from the proven toon + ink-post shaders and `look.gd`/`stage.gd` in gtai-3d-spike; adapt (copy into
   your lane; do not edit the original). Re-tune for a bright golden-hour landscape: that project's look was a
   dark comic city; this one is warm, hazy, readable at 100+ m distance. Add what is missing: atmospheric haze /
   depth gradient, a painterly colour grade, soft sun shadow, a sky, cheap grass/foliage that reads at range.
2. Build the scene from a **kit** of parametric Blender-Python/GDScript parts (road spline, curb, barrier block,
   arch rib, scaffold bay, crane, rink + boards + glass + goal, stand tier, house + timber frame, tree, rock,
   car chassis, bot, biped). The arena must be assembled from kit parts with parameters, so that a different
   rink or track could be assembled from the same parts. Record the kit's part list and parameters.
3. Holographic blueprint ribs: an emissive-edge / wireframe-style translucent material that visibly
   differs from built ribs; the `site_advance` dissolve from hologram to built is a shader/animation parameter.
4. Barrier destruction: **pre-fractured parts made at build time** (the wall block is a set of chunks authored
   by the generator, joined until `crumble`); on `crumble` the chunks become Jolt rigid bodies with dust. No
   runtime mesh slicing. Verify chunks settle and sleep (frame cost after settling must return to baseline).
5. Animated: crane load sway, bots (idle/work with sparks), avatar (idle/walk/run on the humanoid skeleton),
   car wheels/steering, nitro flame + trail, ice shine. Keep animation clip count small; shared rigs.
6. Outline cost is part of the experiment: measure the ink post pass at 1440p with and without it.

## Challenges you must settle with evidence (answer each in REPORT section 8)
- Does inked low-poly hold up on the **avatar and bots** (the most scrutinised pixels), or does it need a
  different treatment than the environment? Show a close capture.
- Does the painterly grade + haze survive the **overcast style** swap without becoming mud or breaking the ink?
- What does the look cost per additional kit asset (ledger), and which of the visible quality in the reference
  could NOT be reached with simple shapes?
- What breaks at the edges: aliasing on thin outlines at distance, ink noise on the road, shadow acne, haze
  banding. List and what fixed each.

## Acceptance (Director verifies independently by running `tools/g.sh` itself)
- `hero`, `site`, `track`, `crumble`, `avatar` captures exist and match their composition descriptions.
- `--style=overcast` changes the whole look via data only; `--stats` prints valid JSON; the movie plays.
- Barrier collapses on `crumble` and settles; `site_advance` converts a hologram rib; car B nitro works.
- REPORT.md complete per BRIEF-COMMON.
