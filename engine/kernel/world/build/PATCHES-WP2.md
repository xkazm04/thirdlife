# PATCHES-WP2: changes outside WP2's scope that it proposes (the Director decides)

## B1. `boot/boot.gd`: the key line while building (made in round 2, +2 lines, 597)

KEYS_WALK names "B  build". While build mode is on (the landscape's meta `tl_build_mode`, `active`), boot hides its key
line and the hotbar's key line shows instead. The hotbar's corner hint is gone.

## B2. `docs/EXE.md`: the keys table (not edited: a doc outside the scope)

"keys while walking" should add `B` build mode, with a pointer to `engine/kernel/world/build/BUILD.md` "Build mode".

## B3. Recorded visits do not carry build actions (a question)

Build mode reads the engine's input state directly, not the visit's TLInput, so a `--record` visit does not hold B,
clicks or the pointer. A replay (`--input`) does not load the Home's save (`_person_walks` is false), so the visitor's
path can differ from the recording when blocks stood in his way. Pack hashes are not affected (blocks are only in the
visitor's space). If replays of building are wanted, the build actions belong in the visit's record as their own
actions plus an aim. That is a contract question for `tl.input/1`.

## B4. A window's glass beside its frame: found and fixed in round 2 (the cause is in the style's shaders)

The Director's hypothesis was that the pane runs across the wall. Measured, that is false. The house's window
(706, 35, -57) was placed with rot 1 between cubes at z -58 and -56. Its pane lies in the plane x = 706.5: along the
wall, inside it. In the exe, a lone window (rot 0) also drew its pane 1.15 m to +x of its frame, in both crisp and
classic. With the glass surface given the toon material, the pane sat in its frame. The mesh's glass vertices were
right (719.125..719.875 for the cell at 719).

The cause is instance uniform slots. `toon.gdshader` and `toon_cel.gdshader` declare `instance uniform float build`
first (slot 0, default 1.0), then `tl_plot`. `glass.gdshader` declares `tl_plot` first (slot 0). On one
MeshInstance3D holding both materials, the glass reads `build` as its plot: (1, 0, 0, 0), a 1 m shift along +x.

The fix in scope: `block_mesh.gd` draws the glass on a child instance ("Glass"), and 752 `build.glass` holds it.
Proposal for the style (not made: outside the scope): give `glass.gdshader`, the `water*` and `fx_add` / `fx_mix` shaders (each declares `tl_plot` first; holo.gdshader already declares `build` first)
`instance uniform vec4 tl_plot : instance_index(1)` (or declare `build` first), so that any pack or kit mesh mixing
toon and glass on one instance draws its glass in place. Kit parts with glass on a toon instance would show the
same shift today.

## B5. The walker (PATCHES-WP1 P2) still stands

Not touched (the brief kept it out). The house in the captures has a door gap whose sill is the foundation row (cell
y 33, nearly all in the ground). It was not walked through.
