# K3 shell, round 4: reach it from the exe; the fade, the shadows, the ice; restart and pause

## From the exe
- `engine/boot/dungeons.json`: "Hokej: thirdjam's match, five against five" (look crisp), first in the Dungeons list.
- `engine/boot/games.json`: `{"name": "hokej", "from": "engine/packs/hokej"}`. The rule that forces it: an exported dungeon
  must be one of the exe's games (contracts/README.md tl.dungeons/1; export.sh refuses a dungeon not in games.json, and only
  games.json's games are copied into games/). games.json is NOT the village: no plot in boot/village.json; the export lists
  it as "plot none (not in the village)". Its consequence: the `world` gate step plays hokej in a world too. Checked:
  `world.sh alone --packs=engine/packs/hokej --mode=bot --frames=6000`: in the world 19657a920ad7853a after 5,460 ticks =
  the runner alone: same, PASS.
- `bash engine/tools/export.sh build --no-warm --out <dir>`: the build carries `rink_core.windows.template_release.x86_64.dll`
  beside ThirdLife.exe (no change to export.sh or the preset was needed); PASS export.build.
- `bash engine/tools/export.sh check --no-window --out <dir>`: PASS. 1b: hokej bd182092f284e383 in the editor binary and
  in the exe (600 frames); the village tour of 10 games the same in the editor, the exe and the exe copied elsewhere;
  nothing left running. Steps 2 and 3 (windows) not run.
- The exe in a window: `ThirdLife.exe -- --dungeon=<abs path>/games/hokej` loads the card "Entering Hokej", then the match.
  Found: a window run ended by `--quit-after` exits 139 (a crash at quit), for hokej AND for parkour, also with the core's
  DLL removed: not the core; the test flag's quit in a dungeon. A person leaves through Esc's card; not tried by hand.

## The three things my eye rejected
1. The first frame: thirdjam's light hold and fade ported (HokejGameMode.cpp:632-678, .h:250-262): black on frames 0-2,
   then a 21-frame fade (0.35 s). Kernel 1.19 `ctx.cameras.screen_fade(amount, color)` draws it (visual only). Measured:
   frame 2 black (median 0, 0, 0), frame 12 at 48 % (71, 64, 66), frame 20 at 86 % (133, 121, 125).
2. The shadows: `TLStyleHall` gained `shade` / `shade_k` (the cel shade band's colour through the existing globals g_shade
   and g_shade2; no shader byte touched): data/gym.json shade #8f8040: the pools are soft dark grey (r4_sheet_fade_ice.jpg).
3. The ice: the hall light #ab956f: near (165, 155, 158), mid (165, 146, 154) against the film's (158, 140, 150) near and
   (182, 168, 180) far: grey, no longer lavender at mid distance. The boards' key `boards` read salmon under that light;
   now `cabin` (cream panels), closer to thirdjam's cream boards.

## Restart and pause
- R: RestartMatch in place. RinkCore.reset(seed) is UJamSim::Restart's match (JamSim.cpp:177-202: "a first match is
  unchanged: Init builds default skaters and calls Restart"); the hit-stop state clears; the camera snaps on the jump.
  Test `bot_rule_restart`: R at frame 540 -> frame 0 at 0:0; 240 core frames after R hash as the untouched match's
  (0 differ).
- Esc: the dungeon's pause card freezes the tree (kernel/dungeon/dungeon.gd: SceneTree.paused, the physics server off):
  the pack does not tick, so the core does not step: thirdjam's pause (GAMEMODE.md row 19: "do not call step() while
  paused"). Nothing in the pack. (`tl play`'s Esc quits; the exe's Esc is the card.)
