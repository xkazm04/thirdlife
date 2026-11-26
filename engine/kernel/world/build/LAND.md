# Home land: sculpt and paint (M2)

Spark `world-sandbox`, milestone M2 (26 Nov 2026). A person in build mode sculpts the Home's ground (Wren Valley) on a
world-anchored 3 m lattice and paints its ground material per 3 m cell. The wire formats are `contracts/BUILD.md`
"More operations" (`land`, `paint`) and `tl.build/2` (`land`, `paint` keys); the layer interface is `BUILD.md`
"Layers". Selftest block 755 (`land_case.gd`) holds this code to both.

| File | What it is |
|---|---|
| `land_layer.gd` | the `land` layer: op checks and rules, apply/undo/journal, files, `height_at`, strokes, `step` |
| `land_store.gd` | the data: vertex -> height (cm), cell -> paint id; the file records (per chunk, int32 pairs, base64) |
| `land_ground.gd` | the Home's own ground, read only: the valley's drawn mesh (heights, colours, normals, codes); the render partition |
| `land_mesh.gd` | an edited chunk's own mesh and collider triangles; hides the valley's cells there |
| `land_scatter.gd` | trees, rushes, hedges follow the ground or are hidden |
| `land_protect.gd` | where land and paint are refused, with the reason (a protect.gd "area" rule) |
| `land_brush.gd` | what the two tools share: radius, the ring on the ground, the vertices under the brush |
| `tools/sculpt_tool.gd`, `tools/paint_tool.gd` | the tools (BUILD.md "Tools") |
| `land_case.gd`, `land_probe.gd` | the headless case (755) and what it measures |

Outside this folder: `home/ground.gd` keeps the valley's colours, normals and codes, a per-cell index table, and
`hide_cells` (degenerate triangles in the GPU index buffer, `RenderingServer.mesh_surface_update_index_region`);
`home/hook.gd` asks the land layer for an edited chunk's faces (`chunk_faces`), moves or drops trunks (`trunk_foot`),
rebuilds one loaded chunk's body (`refresh`), and `ground_y` sees the edits. Listed in `PATCHES-M2.md`.

## The model

- **Heights are absolute cm.** A vertex `[i, j]` (world `(3i, 3j)`) is stored only when its height differs from the
  ground's own there: `round(y * 100)` of the valley's drawn surface (not `valley.height`: the drawn 12 m triangles are
  what is seen and walked on, and what lanes and scatter already stand on). Setting it back removes the entry, so undo
  gives the exact float surface back. The file's `land` value is that same cm.
- **The surface** is `ground(x, z) + D(x, z)`: D is the lattice deltas (height minus the ground's own) on the lattice's
  triangles (split on the diagonal `(i, j)..(i+1, j+1)`, as the valley). `height_at(x, z)` returns it (M3's reader;
  `home/hook.gd ground_y`). On flat ground (a builder without a valley) the ground is 0.
- **Limit:** a vertex stays within 24 m (2400 cm) of the ground's own height ("height limit (24 m ...)").
- **Paint** is per cell; each painted cell gives a quarter of (paint colour - ground colour) to its four corners. The
  cel shader takes the nearest land paint per fragment, so the colour field becomes flat fields with the shader's
  wobbly edge. A one-cell feature reads as a blend; the brush's smallest radius paints at least 5 cells.

## Drawing and colliders

- **Which chunks are drawn by their own mesh.** The valley's cells belong to the 96 m chunk their centre lies in (the
  partition `home/hook.gd faces` uses for colliders). A chunk is *edited* when an entry lies within 3 m of its cells'
  rectangle (a vertex whose four cells reach in, or a painted cell whose corners do). D is then 0 on every rim an
  edited chunk shares with one that is not.
- **The mesh** covers exactly the chunk's valley cells. Its grid lines are the 3 m lattice's AND the valley's own
  lines inside the rectangle, so every valley vertex on the rim is a vertex of it with the valley's height: the rim is
  the valley's edge. Measured (755 `land.seam`): 792 rim vertices of 5 edited chunks, worst gap to the valley's edge
  0.000001 m (float rounding), to an edited neighbour 0.000000 m (both sides compute the same point the same way).
  The valley's cells there are hidden (320 of 320). Unedited parts of an edited chunk differ from the valley only by
  the triangles' split (a 3 m cell across a 12 m crease: millimetres).
- **Colliders**: the same triangles, wound up, replace the valley's in that chunk's body (`hook.faces`); lanes and the
  deck stay; trunks follow `trunk_foot`.
- **Scatter**: an instance whose ground moved at most 0.5 m moves with it; more, it is hidden (basis scaled to 0), and
  its trunk is left out of the body. Undo restores the built transform.

## Rules (protect.gd "area" rule, `land_protect.gd`)

`outside the Home`, `village` (rectangle + 72 m), `game lot` (site footprint + 34 m; the footprints themselves are
protect.gd's rects), `lane` (12 m of a lane, verge or deck), `river` (71 m of the river's line: the water ribbon is
136 m wide and clipped by the ground's depth, so a hollow there would show water that is not there), `field` (land
only: a ploughed parcel's furrows are one mesh that cannot follow), `authored structure (<kind or name>)` (every drawn
thing of the valley that is not ground, water, lanes or scatter, by its drawn bounds: 19 found), `blocks` (a column
in the vertex's four cells, or the painted cell, holds a block), `too close` (the visitor, unless he is 26 m above).
A land op names one entry per vertex; one refused entry refuses the op. A stroke leaves refused vertices out.

## Tools and keys

Sculpt (T to it): **LMB held** works the ground every physics frame with a soft falloff: **1** raise, **2** lower,
**3** flatten (to the height under the first press), **4** smooth; **Shift** turns raise into lower and back; **wheel**
or **[ ]** the brush radius 1-8 cells (3-24 m). Paint: **1-8** grass, grass dark, grass dry, dirt, sand, stone, rock
warm, cliff; **0** or **Backspace** the eraser (`valley`); LMB held paints the cells the brush covers. A ring on the
ground shows the brush (red when a spot under it is refused, sampled at its centre and 8 rim points). One held stroke
is ONE op (each vertex from its height at the first touch to its last), one batch, one Ctrl+Z.
F (flatten) and S (smooth) of the brief are not used: they are flight and walking back in `visit.gd`.

## Cost (755 `land.cost`, headless, this machine, other lanes running)

- A whole edited chunk (first open, a load): mesh 2.7-2.9 ms, body 2.2 ms; ~3,000 triangles added per chunk (its own
  ~3,600 minus the valley's 2 per hidden cell).
- Sculpting without a break round a chunk corner (4 chunks): a mesh redraw (only the grid vertices the stroke changed)
  median 0.4-0.5 ms, max 0.8-2.3 ms; one body a frame while a stroke lasts (the oldest first) median 1.9-2.1 ms; the
  physics frame p50 5.2-5.8 ms, p99 6.9-7.1 ms (idle 1.8 / 2.0). Partial redraws hash equal to whole redraws.
- A Jolt ray exactly through an edge two triangles share can miss both (seen once at a lattice vertex on a chunk
  corner); the cursor ray is never exactly there in play, and the case aims off the lattice.

## In the exe (cooked build of this tree, 1920 x 1080, RTX 4090, vsync off by TL_EXE_FRAMES_TIMES=1)

A scripted session (`TL_BUILD_DEVICES`, `TL_EXE_START=484,-462,...`): a few blocks, a hill (raise 118 frames), a hollow
(lower 60), a mound raised 60 frames and flattened 78, a dirt path painted along 18 points; B saves; a restart loads it.
Drawn frames while sculpting (frames 213-600, 2,479 frames): p50 1.81 ms, p99 8.28 ms (building without a stroke:
p50 1.62, p99 4.93). The first press opening 4 chunks: one frame of 29.6 ms. Captures: `captures/m2-before.jpg`,
`m2-during.jpg`, `m2-after.jpg` (gitignored).

A held stroke keeps its brush on the level plane of its first press (`land_brush.gd on_plane`): with the brush on the
cursor's hit, a raised hill met the ray nearer the camera every frame and walked onto the visitor's feet (seen in the
first exe run). The brush's falloff is `1 - smoothstep(0.25, 1, t)`: `(1 - t^2)^2` made a cone on the 3 m lattice.
