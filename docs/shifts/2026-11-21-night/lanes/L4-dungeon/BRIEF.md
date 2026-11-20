# L4 dungeons-menu: a main menu, and dungeons as their own scenes

Read `docs/shifts/2026-11-21-night/COMMON.md` first. It covers the owner's words, the seams with L3 (menu, try-it), your file
column and selftest block 640-649.
- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n21-dungeon`, branch `n21-dungeon`, base main `3a4580b`.
- **Route:** Opus solo.
- **Time box:** until 06:30.
- **Standups:** write them in `lanes/L4-dungeon/STANDUP.md`. Message the Director when the lane is landable.

## Owner's words
"Second world would be the dungeons, space where we can reshape reality to build standalone game levels and unique
mechanics mutually unaffected with the main world. Player can have option to enter the game via menu at first, player and
interface can transform for the shape of the game (hockey arena, colosseum fight arena, racing circuit) ... the world
designer can adopt law of physics from main world, but the experience and graphics could be open to model within
possibilities of our engine".

**The owner's picks:**
- A dungeon is its own scene and the main world is unloaded (a load screen is accepted).
- Full transform: the avatar, camera, HUD and look all come from the dungeon, and the walker is gone until you leave.
- One main menu at boot: World, Dungeons, Create.

## What exists (scout)
- **Boot.** The exe uses `engine/boot/boot.tscn` + `boot.gd`, and boots straight into the village (`engine/boot/village.json`,
  `games.json`, 8 games).
- **No menu anywhere.** `visit.gd:22,174` uses E to enter a plot and Q/Esc to leave.
- **A pack alone** already runs via the runner/host (`engine/kernel/host/host.tscn`, `kernel/runner/`). "A game in a world
  plays as it does alone" is a gate law, so a dungeon = the pack alone, which is the proven path. Its own physics space and
  global gravity are inherited.
- **Look.** TLStyle is static and process-wide (`style/tl_style.gd`), but `load_style` + `install` swap it at run time; the
  `TL_STYLE` names are crisp (default), classic and diorama.
- **HUD.** Packs bring their own camera views and HUD (`ctx.huds`, parkour `data/hud.json`). Hockey's player is its own
  object, so the avatar swap = no visitor, the pack's player is the body.
- **Scripts.** `engine/tools/world.sh` (tour, alone) and `engine/tools/export.sh` drive the exe and must stay green.

## Work
1. **Main menu** (crisp-styled, keyboard and mouse): World / Dungeons / Create / Quit.
   - World = today's village boot.
   - Dungeons = a list from `engine/boot/dungeons.json` (COMMON schema): title, a still or icon, and the look name.
   - Create mounts `res://ui/create/create.tscn` if it exists (seam in COMMON); otherwise show "Create (coming tonight)".
   - The exe's default boot shows the menu.
   - Every existing flag path (tour, alone, test, headless, capture, `--world`, `--save`, `--site-job`) bypasses the menu
     and behaves exactly as before; prove it with the tour and the `world` gate step.
2. **Dungeon launch:**
   - Picking a dungeon frees the world scene (memory back, measured).
   - Show a load screen with the dungeon's title.
   - Install its look (`TL_STYLE` name via load_style + install).
   - Load the pack alone with its camera and HUD, and no visitor.
   - Esc opens a pause card (Resume / Leave). Leave restores the default look and returns to the menu.
   - World → menu → dungeon → menu → World must work three times in a row without leaks: count nodes and memory each time.
3. **`--dungeon=<pack dir>`** opens any pack dir straight into a dungeon (a WIP job's `pack/` too), with a "Back" that quits
   the process when it was started this way (L3's Try it).
4. **First entries in `dungeons.json`:**
   - `packs/hockey`, with `look` crisp. L5 works on hockey in parallel; you use main's hockey, and the files stay disjoint.
   - `packs/parkour`.
   - One seed, as the proof that a seed runs too.
5. **Determinism:** a dungeon run hashes as the pack alone (same seed, same frames). Add a 64x selftest that boots
   `--dungeon=engine/packs/hockey` headless for N frames and compares to the alone hash.
6. **Docs:** write a "Dungeons" section to `lanes/L4-dungeon/WORLD-dungeons.md` (L1 owns WORLD.md; the Director merges it),
   plus `docs/EXE.md` for the menu and flags.

## Acceptance
- [ ] `tl check --tier full` green (the `world` step included), with counts >= base; `world.sh tour tour --headless` green;
      `export.sh --commit <sha>` + `export.sh check` green on your branch.
- [ ] Headless selftests (64x):
  - the menu bypass for every old flag;
  - dungeon hash = alone hash;
  - three round trips with no growth beyond a stated tolerance.
- [ ] A 20-30 s clip from the exported exe: menu → Dungeons → hockey (load screen, hockey camera and HUD, crisp) → Esc
      Leave → menu → World.
- [ ] `--dungeon=<seed dir>` works from a second process; its exit returns cleanly.
- [ ] REPORT: what the "transform" contains today, and what a pack would declare for its own avatar or look (a proposal for
      a PACK.md field, for the Director).
