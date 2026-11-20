L4 dungeons-menu: report (night of 21 Nov 2026)
Worktree .claude/worktrees/n21-dungeon, branch n21-dungeon, base d5967cc (main 3a4580b + the shift plan). Opus solo.
Nothing committed (the Director lands); branch tip d5967cc, the work is the worktree's changes. All figures below were measured on this machine tonight, other lanes running.

== What a person meets now ==
ThirdLife.exe opens a main menu on the crisp sky: World, Dungeons, Create (coming tonight), Quit. Arrows or W/S, Enter,
Esc back; the mouse works. With the focus on Dungeons the list shows at the right: Ice hockey (look crisp), Parkour,
Paddle court, each with a letter tile, or after a first visit a still of the last frame you saw there.
- World = the village exactly as before. Esc there now returns to the menu (the world and its viewer are freed).
- A dungeon: a load screen with its title (half a second), then the pack alone: its camera, its HUD, its look, no
  walker. Esc: pause card (Resume / Leave), the tree and the physics paused. Leave: back to the menu, default look back.
- Clip from the exported exe (28 s, scripted keys through the engine's input):
  lanes/L4-dungeon/exe-menu-dungeon-world.mp4, contact sheet exe-clip-sheet.jpg
  (menu -> Dungeons -> hockey: load screen, hockey's start panel and rink camera, crisp -> Esc -> Leave -> menu with the
  hockey still -> World -> walk -> Esc -> menu).

== Acceptance ==
[met, with named inherited reds] `tl check --tier full` with the world step, counts >= base:
  - world PASS 8/8 (every game of games.json in one world = alone), seeds 39/39, kit 95/95, item 91/91, ui 166/166,
    foreman.test 223/223 (6 skipped), packs PASS 2/2 with 48/48 verb runs (re-run once under the clock rule; the first
    run's only failure was hockey invariants.many_budget p50 1.140 ms on a machine at 96 % use), perf NOT RUN (machine
    BUSY both times: measured, not judged; it decides nothing).
  - kernel.selftest: the gate step was cut at its 1800 s limit after 121 cases (0 failed) on a machine the hockey lane
    loaded with ladders: a stopped run, NOT a pass. The whole suite run directly without that limit:
    353 found, 353 completed, 351 PASS, 2 FAIL: blend.car_origin and surf.model, both failing with the identical
    message on a `git archive d5967cc` copy of the base (inherited; the Director says fixed on main by dc9024b).
    This branch adds block 640 (5 cases) and removes or changes no case; the base's whole-suite count was not measured
    tonight (the last full run in main's gate history, 19 Nov, had 324).
  - arch FAIL on this branch only for schema-versions `tl.dungeons/1` (needed a contracts/ line; the Director landed it
    on main 342ca06 from PATCHES.md 1, so it passes on the merged tree). size-ratchet passes (boot.gd 589 lines).
  - devx.test 226/229: 2 are the arch real-tree tests (same cause), 1 is the assets scan, known-red-inherited (the
    base's assets/manifest.json, fixed on main dd1064f; assets/ not touched).
[met] `bash engine/tools/world.sh tour tour --headless`: PASS world.tour, world.same, world.sliced_and_paused,
  world.walk_proof (2 min 48 s).
[met] `export.sh --commit d5967cc` + `export.sh check` on the final code: PASS export.build (tag d5967cc 2026-11-20 21:39),
  PASS export.check: steps 0 to 4 and the new 1b, the three dungeons hash the same in the exe and the editor binary
  (hockey a2f701657d4358ea, parkour fe29c683143553c3, paddle 6550cd894ead7dff, 600 frames; the same as `worker --mode=play`).
  Step 3 printed "E and Q: NOT SHOWN" (not counted, as designed): see question 3.

[met] Headless selftests, block 640 (engine/tools/selftest.d/640-dungeon.sh), `bash engine/tools/selftest.sh dungeon.`:
  PASS dungeon.list      the list reads; 10 bad files refused (unknown keys, null look, bad look, absolute or ../ pack,
                        twice, wrong schema, not a list); packs resolve; look names map; launch args shape
  PASS dungeon.bypass    19 decisions (no arguments = menu; headless, 8 flags, 7 TL_EXE_* instruments = village;
                        --menu and TL_EXE_MENU=1 = menu) + real runs: tag, headless no-args refusal (exit 2 as before),
                        --record headless, check --ticks=120 (pack lines, no menu)
  PASS dungeon.refused   headless without --frames 2, missing folder 2, pack outside the fence 2, script error 1
  PASS dungeon.hash_alone  dungeon = worker --mode=play: hockey 1200 f seed 1 (1d939cd60eab), hockey 600 f seed 7
                        (ba40751d726a), parkour 900 f (1a399b4e5d06), paddle 900 f seed 3 (e54b1e3eec2b); --look=diorama
                        installed and crisp back after
  PASS dungeon.trips     3 round trips menu -> World (600 ticks) -> menu -> hockey (600 frames) -> menu, headless:
                        menu 3 vs menu 7: 33 = 33 nodes, 1870 = 1870 objects, 159 = 159 resources, 107.14 -> 107.17 MB
                        static; the 3 hockey runs = the alone hash a2f701657d43; the 3 worlds' 10 games hash alike.
                        Tolerance stated in the block: nodes 0, resources 0, objects +16, static +2 MB, orphans 0.
  In a window (editor binary, scripted keys, census-window-3-trips.jsonl): world 2869 nodes / 249 MB static / 897 MB
  video -> menu 33 / 172.5 / 629 (the world freed); menu 3 -> menu 7: nodes 0, resources 0, objects +10, static
  +0.09 MB, video +0.25 MB. The exe: dungeon 348 nodes / 704 MB video -> menu 34 / 620; world 2859 / 891 -> 34 / 631.

[met] 20-30 s clip from the exported exe: exe-menu-dungeon-world.mp4 (28.3 s), made with `ThirdLife.exe --write-movie`
  and TL_EXE_MENU=1 + TL_EXE_KEYS. Every scripted step is visible in the sheet. Not a person's hands.

[met] `--dungeon=<seed dir>` from a second process: a headless parent (.tl/l4/second.gd) called the launch seam
  `load("res://kernel/dungeon/dungeons.gd").launch(engine/seeds/seed_paddle)`; the child opened a window with the paddle
  court, Esc showed the card with "Back to Create" (still: second-process-back-to-create.jpg), Enter on it ended the
  child with exit code 0 after 8.7 s. The same with the exe: `ThirdLife.exe -- --dungeon=<dir>` (export.sh 1b runs it).

[met] REPORT: the transform today, and a PACK.md proposal: below.

== Gates ==
FAIL  arch            [12/12] schema-versions tl.dungeons/1 only (contract landed on main 342ca06)
PASS  assets          [4/4]
PASS  cards           [3/3]
FAIL  devx.test       [229/229] 226 pass, 3 fail (2 = the arch finding above; 1 = assets scan, known-red-inherited)
PASS  foreman.typecheck
PASS  foreman.test    [223/223] 217 pass, 6 skipped
CUT   kernel.selftest [121/122] cut at 1800 s on a busy machine: NOT a pass. Direct run: 353/353 completed, 351 PASS,
                      2 FAIL inherited (blend.car_origin, surf.model; fixed on main dc9024b)
PASS  kit.selftest    [95/95]
PASS  packs           [2/2] 48/48 verb runs (re-run; first run: clock-only hockey invariants.many_budget, machine busy)
NOT RUN perf          machine BUSY (96 %, 93 %): measured, not judged
PASS  seeds           [39/39]
PASS  item.selftest   [91/91]
PASS  ui.selftest     [166/166]
PASS  world           [8/8] world = alone
PASS  world.tour (world.sh tour tour --headless)
PASS  export.build, PASS export.check (with step 1b)
PASS  selftest dungeon. 5/5 (block 640)

== What the "transform" contains today ==
- Scene: the world is never loaded with a dungeon (the menu is between them); World's Esc frees the viewer, the world,
  the hint layer and the world's logger (world.gd adds one and never removed it: the process used to end there).
- Avatar: none of the kernel's. The pack's own player is the body (hockey's skater, parkour's runner, the paddle).
- Camera and HUD: the pack's TLCameras views and TLHud layers, exactly as `tl play` shows them (mode "play", on_stage).
- Look: the dungeon list's `look` (a TL_STYLE name) is loaded with TLStyle.load_style on entry and the default on leaving;
  sky, sun and post are installed under the dungeon's node (TLStandin.install_look) and freed with it; the exe's
  antialiasing follows the installed look's env.exe_aa. Proof: --look=diorama vs crisp on the paddle court
  (dungeon-look-diorama-vs-crisp.jpg); selftest checks the look is installed and crisp is back after.
- Interface: the main menu, the load screen and the pause card are drawn by the kernel in the crisp 2D look; inside the
  dungeon only the pack's HUD and the pause card.
- Physics: the viewport's default space, the kernel's laws and gravity: the pack alone, which is why it hashes alone.

== Proposal for PACK.md (Director): an optional `dungeon` object in pack.json ==
  "dungeon": {
    "look": "crisp",                 // a TL_STYLE name; absent: the default. dungeons.json's `look` overrides it
    "avatar": "own",                 // "own": the pack's player is the body (all packs today); "walker": the kernel
                                     //  lends the village walker (the visitor's rig and moves) as ctx.avatar, so a
                                     //  dungeon can be "the main world's person in another place" without a rig of its own
    "stills": ["data/still_1.png"],  // menu pictures made by the pack's author or by `capture` (a list; at most 3,
                                     //  inside the size limits); absent: the menu keeps the last frame the person saw
    "pause": "kernel"                // "kernel" (default): Esc opens the kernel's card; "pack": the pack gets the action
                                     //  `pause` and must offer Leave itself (a game with its own pause screen)
  }
  Unknown keys are errors; absent = omit. Nothing here reaches the hash. `dungeons.json` stays the menu's list (which
  packs, in what order, with which title); a pack's `dungeon` block says how it wants to be entered.

== Changed files (all in the L4 column) ==
new:      engine/kernel/dungeon/dungeon.gd (+ .uid)   the driver: PackLife in the worker's order, mode play, load screen,
                                                      pause card, leave, still, census of errors, look in/out
          engine/kernel/dungeon/dungeons.gd (+ .uid)  tl.dungeons/1 reader, resolve, look_path, launch / launch_args
          engine/kernel/dungeon/look_ui.gd (+ .uid)   crisp 2D look (colours read from style/style_crisp.json)
          engine/boot/hub.gd (+ .uid)                 menu flow, --dungeon, trips verb, census lines, menu_decision
          engine/boot/menu.gd (+ .uid)                the main menu screen
          engine/boot/frames.gd (+ .uid)              TL_EXE_FRAMES instrument moved out of boot.gd unchanged
          engine/boot/dungeons.json                   hockey (crisp), parkour, seeds/seed_paddle
          engine/tools/selftest.d/640-dungeon.sh      5 cases
changed:  engine/boot/boot.gd                         589 lines (budget 600): dispatch to hub, _visit split into
                                                      _read_env/_window_setup/_open_world, Esc-to-menu wiring
          engine/tools/export.sh                      dungeons must be games (export refuses otherwise), BUILD.txt lists
                                                      them, README for a person, check step 1b (dungeon hashes exe = editor)
          docs/EXE.md                                 section "The main menu and dungeons", the person's table
          engine/kernel/API.md                        section 23 (append-only; no API member added, kernel API stays 1.11)
lane:     STANDUP.md, REPORT.txt, PATCHES.md, WORLD-dungeons.md (for WORLD.md), census-window-3-trips.jsonl,
          exe-menu-dungeon-world.mp4, exe-clip-sheet.jpg, second-process-back-to-create.jpg, dungeon-look-diorama-vs-crisp.jpg

== Behaviour changes ==
- The exe with no arguments shows the menu (it showed the village). The editor binary started on res://boot/boot.tscn
  with no arguments does too. Every verb, every flag, a headless start and every TL_EXE_* instrument go to the village
  as before (export.sh check steps 2 and 3 are unchanged and pass).
- Esc while walking in a World opened from the menu returns to the menu (it ended the process). The key line says "Esc menu".
- A `--dungeon` start writes ThirdLife-last-dungeon.log, not ThirdLife-last-run.log.
- No test expectation was moved.

== Questions for the Director ==
1. Contract: done by the Director (main 342ca06, "## Exe-side files", from PATCHES.md 1).
2. devx.test "scan twice gives identical rows, and they match the committed manifest" (assets): known-red-inherited.
   The base carries a wrong assets/manifest.json, fixed on main in dd1064f (Director's note). Confirmed here: the same
   36 hashes fail in a `git archive d5967cc` copy. assets/ was not touched.
3. export.sh check step 3 printed "E and Q: NOT SHOWN (no game came on stage)" (not counted, as designed): the scripted
   route no longer reaches the kit court's gate in the 10-game village. Not L4's code path (unattended runs go past the
   menu), not checked on main.
4. Try it is a second process (as COMMON says). An in-process switch was not added. The call for L3:
   load("res://kernel/dungeon/dungeons.gd").launch(<job dir> + "/pack") (PATCHES.md 2).
5. blend.car_origin and surf.model fail on the base too (identical messages); the Director says fixed on main dc9024b.

== Next three things this lane would do ==
1. The pack.json `dungeon` block (after the Director rules on the proposal): stills, avatar "walker", pause "pack".
2. A watchdog for dungeons (the worker's processor-time guard on _pack_tick), so a runaway WIP pack from Try it cannot
   hang the game; and the load in a thread or in slices so the load screen can move.
3. Dungeon share: a dungeon entry in an item.json (docs/SHARING.md) so a friend's menu lists it.
