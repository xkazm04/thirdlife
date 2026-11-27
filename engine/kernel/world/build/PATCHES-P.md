# PATCHES-P: what lane P (paths and the plant scatter) needs in files it does not own

Lane P built `paths_layer.gd` (+ `path_shape.gd`, `path_mesh.gd`, `path_grade.gd`), `tools/path_tool.gd`,
`plant_scatter.gd`, `path_case.gd` and `engine/tools/selftest.d/762-home-paths.sh`. Nothing below is needed to land:
754, 757 and 762 are green with no other file changed. These are the changes the Director or another lane would make.

## P1 (Director, docs): `BUILD.md` names the paths layer and the path tool as stubs

`BUILD.md` (frozen) still says "Stubs until their lanes land" for `paths_layer.gd` and "M5 stubs (\"Water: coming in
M5\" ...)" for `tools/path_tool.gd`, and `plant_scatter.gd` "A stub until lane P lands". Proposed rows:

| File | What it is |
|---|---|
| `paths_layer.gd` | the `paths` layer (M5): `path`, `unpath`, ids (`next_id`), refusal along the samples (`refusal_of`), the drawing per 96 m chunk (made over frames: `VERTS` vertices a frame), `path_at`, `covers`, the ghost (`preview_node`, `ghost_of`), save `paths` |
| `path_shape.gd` | a path's spline sampled every metre (TLKitPath), the index of segments (distance to path k) |
| `path_mesh.gd` | the ribbon in the terrain material (rows: ground colour at h + 0.5 m, paint at h - 0.5 m), the boardwalk for `plank`, the hologram |
| `path_grade.gd` | the grading land op and `lay(build, op)`: path + grading as one batch |
| `tools/path_tool.gd` | LMB a point, RMB / Enter / a click on the last point lays it, Backspace drops a point, 1-6 paint, 0 remove (LMB on a path), wheel or [ ] width 1.5-8 m |

## P2 (build_mode.gd, optional): Enter for a tool with a draft

The host takes Enter for the command tool before any tool sees it (`build_mode.gd` `_poll`). The brief asks Enter to
lay a path. The path tool reads Enter in `tick` (which the host calls before `_poll`), lays the draft, and returns
`blocks_input() == true` until Enter is let go, so the host's edge never fires (762 `paths.enter`: Enter laid the path
and the tool is still `path`). It works through the published interface, but a host hook would be cleaner:
`if (e[KEY_ENTER] or e[KEY_KP_ENTER]) and not (t.has_method("takes_enter") and t.takes_enter()): switch_tool(0, "command")`,
with Enter handed to the tool's `key`. With an empty draft Enter still picks the command tool.

## P3 (lane L, land_protect.gd): a path may not come within 12 m of a valley lane

`refusal_area(rect, "path")` refuses "lane" within 12 m of a lane (and "river" within 71 m of the river's line), so a
person cannot join his path to the valley's lanes, which is the first thing one does with a path. The lane's
ribbon floats 0.22 m and would cover a terrain ribbon under it. Proposal: for `what == "path"` skip `_near_lane`
(the grading still asks `"land"` per vertex and skips the lane band's vertices), or use a band of the lane's half
width. Same question for "plant" (no tree within 12 m of a lane, 71 m of the river): lane L's call.

## P4 (lane L): the growth channel at a point

If the land mesh's UV carries the growth density (M5 plants), the ribbon's outer rows must carry the same value or a
band shows along every path. `path_mesh.gd` asks the plants layer (then the land layer) for `uv_at(x, z) -> Vector2`
when it has one, duck-typed; until then it writes UV (0, 0). Lane L: add `uv_at` with the value the land mesh writes.

## P5 (lane C, contract question): the LLM and paths

- The ask has no `paths` key (contracts/BUILD.md names none), so a model cannot write an `unpath` (it must name the
  whole path) and does not know which ids are taken. `paths_layer.gd read_region` returns `{}` today. Proposal:
  `paths: [{id, pts, width_cm, paint}]` of the paths meeting the box (a contract change: the Director).
- An answer's `path` ops should take the next free ids (`paths.next_id()`) before the dry run; a taken id is refused
  "id 1 is taken (the next free id is 3)".
- A path from the model arrives without grading. `path_grade.gd` `op(land, PathShape.sample(op.pts), width_m)` gives
  the land op the tool writes; the command tool could add it to the batch at accept (or `lay` it).

## P6 (lane L, look note): the verge and the tufts

toon_cel draws the darker verge and the tufts over the edge only where grass meets earth (`dirt`, `sand`). A
`rock_warm` path gets the crisp edge without a verge (and is the valley's mauve rock); `grass_dry` is a grass, so its
edge has tufts on both sides and no verge. If rock paths should have a verge, that is the shader's land branch (lane
L's file).

## P7 (Director, a decision changed by measurement): `stone` is a paved slab, not a terrain ribbon

The brief drew every path paint but `plank` as a terrain ribbon. `stone` is not one of toon_cel's eight land paints.
Drawn in the land's nearest stone-like paint (`rock`) it was a lavender-pink slab with purple strata in the exe
(capture `p-stone-rock.jpg`); in its own grey (#aa9e98) the nearest land paint is dirt at about 0.32 (linear rgb), so
the shader would leave it half snapped. `stone` is now drawn like `plank`: a TLMesh ribbon of the kit's masonry
(`stone`), 6 cm up, with a `stone_dark` kerb down into the ground (`path_mesh.gd SLABS`). The land layer's own `stone`
paint has the same question (lane L).
