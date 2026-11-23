K3 SHELL, ROUND 4 REPORT (campaign night 23-24 Nov 2026; worktree .claude/worktrees/hk-shell, branch hk-shell, uncommitted,
on hokej 8f3a59f)

OUTCOME
hokej is in the exe: a Dungeons entry; the export carries the core's DLL; the exe runs hokej to the same hash as the
editor. The match opens from black as thirdjam's does, the shadows are grey, the ice grey; R restarts in place, Esc pauses.

THE COMMANDS AND THEIR RESULTS
  bash engine/tools/export.sh build --no-warm --out <dir>       PASS export.build; rink_core.windows.template_release.x86_64.dll
                                                                 beside ThirdLife.exe (no change to export.sh or the preset)
  bash engine/tools/export.sh check --no-window --out <dir>     PASS: 1b hokej bd182092f284e383 in the editor binary and the exe
                                                                 (600 frames); the 10-game village tour the same in the editor,
                                                                 the exe and the exe copied elsewhere; nothing left running.
                                                                 Steps 2-3 (windows) not run.
  ThirdLife.exe -- --dungeon=<absolute path>/games/hokej        in a window: the "Entering Hokej" card, then the match (filmed,
                                                                 700 frames). The menu: Dungeons > "Hokej: thirdjam's match,
                                                                 five against five" (not clicked by hand).

THE DIRECTOR'S POINTS
1. Reach it from the exe: DONE.
   - engine/boot/dungeons.json: hokej first, look crisp. engine/boot/games.json: hokej added. The rule: an exported dungeon
     must be one of games.json (contracts/README.md tl.dungeons/1; export.sh:210-216 refuses otherwise; only games.json's
     games are copied). games.json is not the village: no plot (export: "plot none (not in the village)").
     Its consequence: the full gate's `world` step plays hokej in one world too. Checked alone: world.sh alone
     --packs=engine/packs/hokej --mode=bot --frames=6000: 19657a920ad7853a in the world = the runner alone, same, PASS.
   - Found, not ours: a WINDOWED exe run ended by --quit-after exits 139 (crash at quit) for hokej, for parkour, and for
     parkour with the core's DLL removed: the dungeon's quit under the test flag, not the core. Headless counted runs exit
     cleanly (the check). A person's way out (Esc > card > Leave) was not tried by hand.
2. The three eye items: DONE.
   - First frame: thirdjam's light hold + fade (HokejGameMode.cpp:632-678; LightHoldSettleTicks 3, LightFadeSeconds 0.35):
     black frames 0-2, 21 frames of linear fade. Kernel 1.19: ctx.cameras.screen_fade(amount, color) (TLCameras; visual
     only; headless nothing; API.md). Measured: frame 2 (0, 0, 0), frame 12 (71, 64, 66), frame 20 (133, 121, 125).
   - Shadows: TLStyleHall options shade / shade_k (the existing globals g_shade, g_shade2; no shader byte touched):
     #8f8040: soft dark grey pools.
   - Ice at mid distance: hall light #ab956f: near (165, 155, 158), mid (165, 146, 154) vs film (158, 140, 150) near,
     (182, 168, 180) far. Boards now the palette's `cabin` (cream panels; `boards` read salmon under the warm light).
   Sheet: r4_sheet_fade_ice.jpg (ours f2, f12, f20, f400, f2160 beside thirdjam f1440, f2160, f6480).
3. Restart and pause: DONE.
   - R: RinkCore.reset(seed) is the in-place restart: UJamSim::Restart makes every skater fresh from Init's spawn and
     reseeds, "a first match is unchanged: Init builds default skaters and calls Restart" (JamSim.cpp:177-202), and reset
     rebuilds rules, zones, effects and the brain as RestartMatch does (HokejGameMode.cpp:800-818). Hit-stop cleared.
     New test bot_rule_restart PASS: R at frame 540 -> frame 0 at 0:0; 240 core frames after R hash as the untouched
     match's, 0 differ.
   - Esc: the exe's dungeon pause card freezes the tree (kernel/dungeon/dungeon.gd 235-260): the pack is not ticked, the
     core is not stepped: thirdjam's pause (GAMEMODE.md row 19). No pack code. tl play's Esc quits (the tool's rule).

GATES
hokej: lint PASS, smoke PASS, invariants PASS (idle 79a699ba1b92ec17 twice; bot_match_hand 19657a920ad7853a twice after
  5,460 frames: the state hash did not move with this round's look changes), bots 9/9 PASS (match_hand, rule_restart new,
  w_away, s_lock, aim, aim_anchor, gym_hand, tj_replay 0.54 cm).
world.alone (hokej): PASS (above). export build + check --no-window: PASS (above).
tl check --tier fast: arch 12/12 (api-v1 1.19: screen_fade), assets 4/4, cards 3/3, devx.test 229/229 PASS; foreman
  NOT RUN (no foreman/node_modules here).
Full tier: NOT RUN (the kernel changed by one visual member; the Director runs the uncapped suite at the verdict).

CHANGED FILES
engine/boot/dungeons.json, engine/boot/games.json (hokej); engine/kernel/api/tl_cameras.gd (screen_fade),
engine/kernel/runner/manifest.gd (KERNEL_API 1.19), engine/kernel/API.md; docs/generated/* (tl arch --index);
engine/style/tl_style_hall.gd (shade, shade_k); .claude/sessions.json (my claim narrowed to my files: tl arch's
scope-claims failed on hk-shell 'scripts/*.gd' overlapping hk-hud 'scripts/hud/**');
engine/packs/hokej: pack.json (title, kernelApi 1.19, bot_rule_restart), data/gym.json (light, shade), gen/tj_rink.gd
(boards key cabin), scripts/main.gd (light hold + fade, R restart), tests/bot_rule_restart.gd (new).
docs/shifts/2026-11-24-night/lanes/K3-shell: ROUND-4.md, REPORT.txt, STANDUP.md, r4_sheet_fade_ice.jpg.
Seams for K5 and K6 in main.gd: untouched by this round's structure (_pack_setup builds, _pack_tick steps and draws,
_light_hold is one function; a HUD or arena call site goes beside view.draw / the camera step).

DEVIATIONS (new this round)
1. The light hold has no "rig visible" wait (our hall's light is there from frame 0): 3 frames black, then the fade.
2. The boards' palette key is `cabin` (cream panels) for the colour under the warm roof light, not RinkActor's material.
3. The hall light's colour is chosen to match thirdjam's FILM ice (median pixels), not read from its rig (binary).

QUESTIONS FOR THE DIRECTOR
1. games.json now lists hokej, so the full gate's `world` step plays it (about 5,460 frames of a match). Keep it so, or
   mark it in games.json as a dungeon-only game the world step skips (a games.json key; contract wording yours)?
2. The windowed exe's crash at --quit-after in any dungeon (exit 139, with or without the core): a kernel/dungeon matter
   for whoever owns kernel/dungeon; it does not touch hokej's play.

NEXT
1. K1's raw glue when it lands (delete the port, signals 1-4, the button oracle against the glue).
2. K2's pawn in draw_skater; 3. the person's play through the exe.
