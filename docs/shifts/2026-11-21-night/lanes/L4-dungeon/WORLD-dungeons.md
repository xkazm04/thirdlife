# Dungeons (for engine/kernel/world/WORLD.md; L1 owns that file, the Director merges this section)

## Dungeons: the second world (L4, night of 21 Nov)

The owner's two-worlds principle: the main world is the sandbox (the village, its plots, its construction sites); a
**dungeon** is a standalone game level with its own mechanics, untouched by the main world and not touching it. Entered
from the main menu, it is its own scene: the world is not loaded while it runs, and the avatar, camera, HUD and look are
the dungeon's.

**What a dungeon is in the engine.** A dungeon is one pack alone, in the game's own process: `engine/kernel/dungeon/
dungeon.gd` drives the same lifecycle core the lone worker and a world's holder drive (`kernel/runner/pack_life.gd`), in
the worker's frame order, in mode `play`. The gate law "a game in a world plays as it does alone" has a third side now:
a game in a dungeon plays as it does alone too. A counted dungeon (`-- --dungeon=<dir> --frames=N`) hashes as
`worker --mode=play --frames=N` (selftest 640 `dungeon.hash_alone`: hockey, parkour, the paddle court; the exe and the
editor binary agree, `export.sh check` step 1b).

**Physics.** The pack runs in the viewport's default space (as alone; no world exists to share it with), with the
project's global gravity and the kernel's laws (`TLLaws` on every body, as alone). A dungeon "adopts the law of physics
of the main world" by construction: the same kernel, the same tables. What a pack builds inside it is its own.

**Look.** A dungeon names its look in `engine/boot/dungeons.json` (`look`: a `TL_STYLE` name, crisp, classic, diorama,
overcast); without it, the default. `TLStyle` is process-wide and static, so the dungeon loads its style file on entry
and loads the default again on leaving (`TLStyle.load_style`); the sun, sky and post of the look are installed under
the dungeon's own node and freed with it.

**Avatar, camera, HUD.** No visitor: the walker is not loaded. The pack's player is the body; its `TLCameras` views and
its `TLHud` layers are the screen. Hockey shows its own start panel (level, mode), its rink camera and its score line.

**Entering and leaving.**
- From the main menu: Dungeons, pick one. A load screen with the title (half a second, then the load, which blocks),
  then the game. Esc: the pause card (Resume, Leave), the tree and the physics paused. Leave: the pack's teardown,
  every node of the pack freed, the default look back, the menu.
- From a second process (Create's "Try it", lane L3): `kernel/dungeon/dungeons.gd` `launch(<job dir>/pack)` starts the
  running executable with `-- --dungeon=<dir>`; its card says "Back to Create" and ends that process.
- World and dungeon never coexist: World's Esc returns to the menu (the world and its viewer freed, its logger
  removed), and a dungeon is opened from the menu.

**Leaks, measured.** Three round trips menu -> World -> menu -> dungeon -> menu (selftest 640 `dungeon.trips`
headless; the same in a window with scripted keys): after the first round trip nothing grows (nodes and resources
equal, objects +10 of 2000, static memory +0.1 MB, video memory +0.25 MB in the window). The first world and the first
dungeon leave caches behind (scripts, shaders, the shadow atlas). The three worlds' games hash alike, and the dungeon
between them hashes as alone each time: a dungeon leaves nothing in the process that changes the world after it.

**What a dungeon does not have yet.** No watchdog thread (a pack whose tick runs away hangs the game, as in `tl play`);
no input record; a pack cannot yet declare its own avatar, its look or its menu card (a proposal for `pack.json` is in
the L4 report); no in-process switch from Create (Try it is a second process); no sharing of a dungeon with a friend.
