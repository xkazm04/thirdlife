# P14: patches for what P14 leaves

P14 owned the whole engine; this file holds what it found and did not do, and the leftover patches of round 3 it did
not apply (with the reason). Nothing here is applied unless it says so.

## 1. The remaining hitch of an arrival is the pack's own setup in a window (not the view)

Measured with the per-frame notes of P14 (`view.gd`, the tour line's `slow_frames` = [tick, ms, notes, render cpu]):
after P13 and P14 the view's part of an arrival is 2 ms of collider copy a frame plus 2 to 9 ms of the draw layer's
adoption on the next tick. The rest of every slow frame of walk30 and tour6 is the world tick that attaches the pack:
`load_ms.setup` (the pack's `_pack_setup`) is 18 to 96 ms in a window for the same packs that P12's headless arrival
probe measures at 2 to 30 ms. `--render-thread separate` (tried through `TL_WINDOW_ARGS`) changed nothing, so it is
not the uploads of meshes alone. Next step, not done: time the inside of `_pack_setup` in a window (kit `build`,
`TLLaws.apply_tree`, node creation, materials) with a probe that writes to a file, and build ahead on the worker what
is found there, as P12 did for rigs and parts.

## 2. Entering a game that has ended rebuilds it in the frame

A game that is over (`over`) and is entered again is rebuilt from its seed at once (`jobs.gd` `_force_needed`, event
`restart`): 107 to 163 ms in the exe (the kit example, ended after 332 ticks), 413 ms for the wall seed in a windowed
tour. Proposal: when the visitor comes within the sideline distance of a plot whose game is over, queue its rebuild
(`jobs.want(i, true)`) so that the enter finds it prepared; the event stays the same `built` at the enter tick, so a
replay does the same. Files: `kernel/world/world.gd` or `tiers.gd` (world.gd is over 600 lines and may not grow).

## 3. A cached far picture is loaded in the frame

`draw_pictures.gd` `_cache_load` loads a picture `.res` (about 1.5 MB) with `ResourceLoader.load` on the main thread:
19 to 21 ms in the exe when a plot first goes far (`set_tier` notes). Proposal: `ResourceLoader.load_threaded_request`
in `_ensure_pictures`, draw the pack in full (or its pad) until it is there, as `far_pending` already does for pictures
merged on a worker.

## 4. Leftover patches of round 3

| entry | applied? | why |
|---|---|---|
| PATCHES-P11 1 (`item.sh` line 303) | applied | the brief's item 5 |
| PATCHES-P11 2 (`world.gd` live visits) | no | world.gd is over 600 lines; the view's line works |
| PATCHES-P11 3 (`script_errors` with two packs) | no | an investigation, not a patch |
| PATCHES-P11 4 (gate directions from the landscape) | no | not needed by any check; P11 measured both ways equal for the drive plot (near a bend they may differ by degrees) |
| PATCHES-P11 5 (`TL_DRAW_PICTURE`) | no | `far_cost.sh` and `far_study.mjs` still set the variable |
| PATCHES-P11 7 (`w_pile` `kernelApi`) | no | "0.1" is read as 1.0; nothing to gain |
| PATCHES-P11 8 (WORLD.md keys) | applied | text only |
| PATCHES-P11 9, 10 | no | need an API addition / the host's verbs in the exe |
| PATCHES-P12 3 (`worker.gd` `_load_fresh`) | no | changes how a pack alone loads its scripts; wants its own hash run |
| PATCHES-P12 4 (a lock in `world.sh`) | done differently | item 4: one lock for world.sh, view.sh and tl perf |
| PATCHES-P12 6 (the view's arrival work) | applied | item 2 (and entry 1 above: it was not the main part) |
| PATCHES-P13 2 (API 1.1) | applied | item 5 |
| PATCHES-P13 3 (WORLD.md landscape keys) | applied | text only |
| PATCHES-P13 4 (`_rim_of` hashes in the frame) | applied | a directory is hashed once per process (`view_seam.gd`) |
| PATCHES-P13 5 (far tier before arrival) | no | the draw layer is safe either way; nothing to gain now |

## 5. Contract text (the Director's)

- WORLD.md / tl.view/1 tour line: `slow_frames` entries are `[world tick, ms, [notes], render cpu ms]`; a note is
  "<what> <ms>" for every part of the frame that took 1 ms or more ("tick" = the world's ticks of the frame, timed
  from SceneTree.physics_frame to the viewer's own step; "colliders", "replace pN", "set_tier pN", "tier pN <tier>",
  "pic_collect", "pic_finish", "pic_cache", "draw_frame", "land_arrive", "shot_read").
- The world's caches (`<user dir>/tl_cache` or `TL_CACHE_DIR`): every key is a pack directory's content; a build ships
  them in `cache/` beside the exe.
