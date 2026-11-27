# R4: what the Third Life engine can do today for a player-facing sandbox (evidence map, 27 Nov 2026)

Scout: Opus Explore, read-only, at main 8be26d61. A capability counts only if a player can reach it in the exe. Paths are relative to the repo root. Saved verbatim-in-substance by the Director.

## 0. How a player reaches the Home
- Menu World / Dungeons / Create / Quit (`engine/boot/menu.gd:66-75`, `hub.gd:6-12`); World -> `_open_world()` (`hub.gd:161-167`).
- `engine/boot/village.json:22` `"home": "wren"` -> `landscape.gd:523` `Home.grow(...)` -> `home/hook.gd:95` mounts build mode (`build_mode.gd:85-94`).
- The Home = Wren Valley, ±3,264 m (~6.5 x 6.5 km) (`home/valley.gd:3,220`); 8 live game plots, 5 lots + 2 "portal" sites (`valley.gd:36-42`).
- B toggles build mode; T / Shift+T cycle 9 tools: blocks, sculpt, paint, pieces, stamps, water, paths, plants, command (`build_mode.gd:21-25`; `build/BUILD.md:253`).

## 1. Building layers and tools
One edit log `tl.edit/1` with `author: hand|llm`, per-batch undo/redo (`contracts/BUILD.md:48-68`); each layer validates/applies/inverts/saves its own ops (`build/BUILD.md:78-108`).

| Layer / tool | Grain, counts | Limits | Evidence |
|---|---|---|---|
| Blocks | 1 m cells, y -16..111; 8 shapes (cube, slab, stair, ramp, post, window, roof, fence); 12 mat ids (9 open, 10 glass panes, 11 brick + 12 plaster unlockable); rot 0-3, flip on stair/ramp/roof | 32,768 / 96 m chunk, 400,000 / Home | `blocks.gd:9-28`; `contracts/BUILD.md:12-42,67-68` |
| Joining | stair/ramp/roof outer+inner corners from same-shape neighbours; fences link to fence/post/full face; posts grow rail stubs; 8x8 coverage masks hide faces; derived at meshing, never stored | | `build/BUILD.md:149-162`; `contracts/BUILD.md:44-46` |
| Blocks tool | LMB/RMB, drag = one batch ≤ 64 cells, wheel/1-8 shape, Tab material, R rot, F2 flip, reach 24 m | | `build/BUILD.md:250-263,290-301` |
| Land | 3 m lattice, cm heights; raise/lower/flatten/smooth brush 1-8 cells; 8 paints + eraser | ±24 m from the valley's height | `LAND.md:31-39,86-98` |
| Pieces | 17 kit parts (fence, tree, bush, rock, crate, lumber, pallet, sign, flag, stones, bench, street_lamp, cabin, house, timber_frame, watch_tower, light_mast); one knob `[ ]`, some a choice (V); 4 seeded looks | footprint ≤ 32 cells; ≤ 48 lit/breakable nodes | `piece_catalog.gd:17-31`; `piece_draw.gd:17` |
| Stamps | box select, G names, Enter saves `<home>/stamps/<slug>.json` (`tl.stamp/1`); place = one undo; X exports `.tlitem`, I imports `stamps/inbox/` | ≤ 128 cells a side | `PIECES.md:47-56`; `stamp_file.gd:21-24` |
| Water | still water on 3 m cells; pour floods a hollow to under its spill; drain | < 2,048 cells; no collider (wade the bed); does not follow later sculpt | `water_fill.gd:23-30` |
| Paths | splines 2-64 pts, 1.5-8 m, 6 paints incl. plank; grading in the same batch | points 1-48 m apart | `paths_layer.gd:20-26` |
| Plants | meadow, flowers, tall grass in the ground shader; tree/bush scatter as puts | | `plants_layer.gd:18-19` |

- Undo stacks are in memory only (empty after a load). Save `user://home/build.json` (tl.build/1-3) + `edits.jsonl`, temp -> read-back -> `.prev` -> rename; the lowest version that holds the content. Autosave on leaving build mode, 1,800 frames after the first unsaved change, and on quit.
- Protected: plots, lots, sites, authored structures, trees, the visitor (blocks); the village + 72 m, lots + 34 m, lanes 12 m, river 71 m, fields, 19 structures, block columns, the visitor (land).
- Walker: 4.5 m/s walk, 9 m/s run, jump, slide, mantle 0.4-1.2 m, hang/swing, fly (F) to 120 m; stairs collide as drawn, steps up risers ≤ 0.55 m on Home blocks.

## 2. The LLM builder
- Ask `tl.world-edit-ask/1`: sentence ≤ 400 chars, cursor + facing, region 32x24x32, its blocks, ground, refused columns, measured water, other layers' reads, unlocked tables, caps `{ops 4000, blocks_left}`.
- Ops: every layer's `offers()` (place, remove, land, paint, put, lift, pour, drain, path, unpath, plant) + Foreman-expanded `fill`/`clear` boxes; checked with feedback, 2 attempts.
- Ghost per layer, Enter = one `llm` batch (one Ctrl+Z), Esc reverts; never applied without the player; building continues while it thinks; ≤ 2 pending.
- Latency (Opus, 300 s timeout): bridge 39.0 s, 10.1k/3.9k tok, 134 ops; roof 39.3 s, 13.5k/4.0k, 132 ops; M5 bridge 26.4 s, 15.0k/2.6k, 136 ops. 30 calls/day default; `llm_calls.jsonl` -> `tl ledger`.
- Locks: the ask lists only unlocked items; Foreman refuses the rest; the exe re-checks at ghost and accept.
- Reach caveat: needs `foreman/dist/cli.js` above the exe + Node + settings (`engine/ui/foreman_door.gd:76-108`); a plain exe says "not connected".

## 3. Behaviour (what makes a build do something)
| Thing | State | Evidence |
|---|---|---|
| Doors, switches, triggers, logic | absent | `grep -rniE "logic|wire|signal_block|trigger" kernel/world/build` = 0 |
| Interactive pieces (sit/open/toggle) | absent | static MultiMeshes + one static body per section (`piece_draw.gd:2-10`) |
| Physics objects | absent in the Home | breakable crate drawn as a node, bodies freed (`piece_draw.gd:4-7`) |
| Lights | real (house, street_lamp, light_mast), capped 48, but always day | `piece_draw.gd:4-6,17` |
| Day/night | absent (fixed sun `style_crisp.json` elev 40 azim 176) | `TWO-WORLDS.md:138` proposal only |
| Weather | absent; ambient cloud shadows + tree sway | `style_crisp.json:46-51` |
| NPCs / residents | absent (proposal `TWO-WORLDS.md:158-177`) | grep = 0 |
| Vehicles | only inside games (`TLVehicle`) | |
| Audio in the Home | absent | `grep AudioStreamPlayer kernel/world` = 0 |

## 4. Games in the world
- 8 village packs, E enters a game on stage; dungeons (4 shipped) open alone; the player's own dungeons in `user://dungeons.user.json` via Create's "Add to menu".
- Create: sentence (≤ 800 chars) -> Standard/Crazy -> Designer aspect cards -> Foreman phases -> "Try it" (child process `--dungeon`) -> Play / Add to menu / change box. Templates duel, rink_sport, arcade_sport, own; games on a core = a cartridge over a base + skin. Night of 27 Nov: karts, biplane etc. made by Create, 29-61 min per change, 1.4-14 M tokens per run.
- A build cannot host or become a game: `grep -rniE "venue|tl\.layout|to_layout" build/*.gd` = 0; portals are drawn arches with no trigger (`home/landmarks.gd:38-60`).
- Unlocks: dungeon ends write `trophies.json` (plays, wins, best); village plots write nothing; results card; `unlocks.json` 5 rules (bench, street_lamp, watch_tower, light_mast, house, brick, plaster).
- Sharing: stamps as `.tlitem` (data tier); no store/friend transfer ("No sharing option is offered to players now", `SHARING.md:165-166`).

## 5. The look
- Style is data (one JSON: palette, sun, bands, fog, sky, ink, grade); crisp cel default; 4 style files; 105 palette keys.
- Cel: flat bands, cut shadows, land painted by numbers (8 paints), strata on rock, cel water.
- Player content shares the look: blocks one toon surface + glass; pieces use kit TLStyle materials; sculpted land the same ground shader; a style swap recolours without a rebuild.
- Kit: 38 generated parts (venue/sport 6, road/race 7, construction 7, nature 6, town 9, dynamic 3); the Home offers 17.

## 6. Multiplayer: absent (net classes only in lint fixtures; a TCP spike `kernel/proc/proc_chan.gd`; design `TWO-WORLDS.md:179-191`).

## 7. Performance (RTX 4090, exe)
Walking p50 1.36 / p99 5.26 ms; near 5,000 blocks 1.41 / 6.55; building 1.43 / 6.70, worst click 18.7 ms; save of 5,000 blocks 16.7 ms. Section rebuild 1.30 ms median; 20,000 placements 357 ms. Land chunk 3.4-5.9 ms; sculpting p50 1.81 / p99 8.28. 700 pieces 144 ms apply, 128 draw calls, 0.14 ms CPU.

## 8. Ten gaps vs Minecraft/Roblox (ranked by what a player misses)
1. No multiplayer / friends in your Home.
2. Builds cannot DO anything (no doors, levers, logic, scripts, triggers).
3. A build cannot become or host a game; portals do not open.
4. No life (residents, animals).
5. No time or weather (lamps never matter).
6. No survival/progression loop in the Home (unlocks only from dungeons).
7. No physics toys or vehicles in the Home.
8. Small palette (8 shapes, 11 mats, 17 pieces, 8 paints; no colour picker, no custom meshes; no caves).
9. No sharing or discovery (folder only; one Home).
10. No sound, no avatar expression, no select/copy/move/mirror tool beyond stamps.

## 9. Five unique capabilities
1. Hand and LLM share one edit log: a sentence at the cursor -> a measured, checked ghost in every layer -> one undoable batch, adjustable by hand; replay never calls the model.
2. Sentence -> playable game with no code (Create; cartridges on cores; changes as sentences).
3. Determinism as a product feature (state hashes, world = alone, input records, byte-stable saves; the base for lockstep).
4. The look is data and reaches player content (one JSON restyles everything; per-dungeon looks).
5. Play unlocks building; items carry their origin (sentence + parent chain); smart blocks join themselves; parametric pieces.
