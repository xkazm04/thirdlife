# Lane C brief: high-resolution voxel (hypothesis test: is it worth chasing?)

Lane directory: `spike/lab/c/`. Read `BRIEF-COMMON.md` and `SCENE.md` first.

## The direction and the point of this lane
Target the look of `ref/C_voxel.png`: a world made of small cubes (Teardown/Minecraft-with-modern-lighting
lineage), lit richly (sun, soft shadows, volumetric light shafts, ambient occlusion), where the barrier wall
breaks into individual voxel debris. The Director's **prior** is that this direction is gorgeous and great for
destruction but is **harder to build and run than lane B** for LLM-authored assets. Your job is to **test that
prior honestly**, not to defend it: build it as well as it can be built in the first pass, measure it, and say
whether it is worth a 1-2 day second pass. A well-argued "this is not worth chasing, here is the evidence" is
a fully successful outcome. Do not pad the look to flatter the direction, and do not sandbag it.

World model note: the game's substrate is objects with material tags (Jolt), NOT a voxel world. Voxel is an
**authoring and rendering style** here: voxel models are baked to meshes (greedy meshing, chunked), kept as
ordinary objects with Jolt colliders; destruction by voxel debris is pre-authored chunking or voxel-cluster
fracture into rigid bodies. State clearly where this fights the object model.

## Mandatory approach
1. Authoring pipeline an LLM can drive: scripts (Python) generate voxel grids for each kit part (terrain
   chunks, arch rib, scaffold, crane, rink/boards, house + frame, trees, rocks, car, bot, biped) into a simple
   voxel format, then a **greedy-meshing baker** produces Godot meshes (per-material, vertex colours or a
   palette atlas, chunked for culling). Choose and justify voxel size (e.g. 0.1-0.25 m); report the effect of
   voxel size on look, voxel count, triangles and frame time. Scripts are the source of truth.
2. Terrain and large structures at a resolution that still reads in the hero shot without millions of
   unnecessary voxels: use chunking, LOD or coarser voxels for the distance, and say how.
3. Characters: voxel avatar and bots **bound to the standard skeletons** (rigid voxel parts per bone, humanoid
   bone names). Animated clips idle/walk/run. Voxel cars: rotation of voxel meshes (shimmer, aliasing), steering.
4. Lighting: use the most credible Godot 4.7 options (SDFGI, VoxelGI, baked lightmaps, or a clever cheap
   alternative), plus fog/volumetric light shafts and SSAO. Record what each option cost and which you kept.
5. Barrier destruction: on `crumble` the wall breaks into voxel debris (rigid bodies of voxel clusters, plus
   cheap dust/fragment particles). Report debris count, simulation cost, settle/sleep behaviour.
6. Holographic blueprint ribs (translucent edges), `site_advance` dissolve, crane sway, bots working,
   nitro flame: same requirements as in SCENE.md, in the voxel style.

## Concerns to settle with evidence (answer each in REPORT section 8; this is the heart of the lane)
- **Authoring cost**: agent minutes and rounds per asset class vs the numbers in gtai-3d-spike STATUS.md (and
  lane B's ledger when available); does an LLM produce good voxel art from scripts, or does it look
  procedural and noisy? Which asset classes (organic trees, rocks, faces, car curves) are weakest?
- **Render cost**: voxel/triangle counts, VRAM, p50/p99, with each lighting choice; what it would be on a
  1080p mid-range GPU (labelled estimate). Greedy-meshed chunks vs instancing.
- **Animation and rotation**: do voxel characters and cars look right when they rotate, and is the standard
  skeleton workable? Does a "vehicle on a curved road" read well with axis-aligned voxels?
- **Destruction**: real benefit vs lane B's pre-fractured chunks; cost of making any structure destructible
  (e.g. is the arena roof destructible, or only specially authored walls?).
- **Fit with the game**: how voxel fights the Jolt-objects world model, material tagging (does a voxel carry
  a material id usable by the future law tables?), and scale ("a hockey rink is 60 m: at 0.15 m voxels that is
  400 voxels long").
- **Differentiation vs crowd**: from your capture, does it look like a distinct game or like "another voxel game"?
  (your honest visual judgement against the reference).

## Acceptance (Director verifies independently by running `tools/g.sh` itself)
Same as lane B (`hero`, `site`, `track`, `crumble`, `avatar` captures, `--style=overcast`, `--stats`, movie,
crumble/site_advance/nitro working, REPORT.md complete) PLUS a clear **recommendation**: *continue for a
1-2 day second pass* / *drop* / *use voxel only as a destruction-debris technique inside lane B's look*, with
the evidence that supports it and an estimate of what the second pass would deliver.
