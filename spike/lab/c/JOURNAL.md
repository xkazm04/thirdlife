# Lane C journal (voxel hypothesis test)

Format: `HH:MM` wall clock (CEST, 2026-11-10), action, result, measurement. Resume point if killed: read this top to bottom.

- 13:26 start. Read BRIEF-COMMON, SCENE, BRIEF-C, ref/C_voxel.png. numpy 2.5.4 + scipy 1.15 in system python 3.12 (no venv needed). Godot 4.7.2 at gtai-spike/tools/godot. GPU RTX 4090 mostly idle.
- 13:30 PLAN: pure-python pipeline (no Blender). gen/vox.py = Grid (metre-space primitives, material ids from data/materials.json) + greedy mesher w/ vertex AO + .vxm writer. gen/kit.py parametric kit parts. gen/world.py terrain+track+layout.json. Godot: look.gd builds scene from layout.json; one voxel shader with palette texture from style.json (colour per voxel = hash(cell) -> ramp shade, so greedy quads keep per-voxel variation); skeleton w/ humanoid bone names + rigid voxel parts via BoneAttachment3D.
