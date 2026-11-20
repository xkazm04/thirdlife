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

======================================================================================================================
L4b (after the landing of L4 as fe15b9c / d0d0bd9): the dungeon watchdog and a load screen that moves
======================================================================================================================

== What was asked (Director 22:50, corrected) ==
Reuse the kernel runner's watchdog for dungeons (an endless loop in one step, a step that never returns); the person
meets a card that says so, with Leave; nothing of a clock in a hash or a result; the selftest asserts the card and
Leave, never a time. Plus a load screen that keeps moving. Not started: the pack.json `dungeon` block (owner's ruling).

== What it is ==
- kernel/dungeon/watch.gd: the worker's rule, reused. A thread asks kernel/host/cpuclock.gd `verdict` about the call
  into pack code that runs now, with the worker's limits (a tick 250 ms, a setup call 10 s, of PROCESSOR time), through
  PackLife's on_begin / on_end hooks, exactly as worker.gd `_wd_run` does. "starved" (the machine, not the pack) stops
  nothing in a person's game.
- A runaway cannot be interrupted inside its own thread (the worker and the world's guard end their process for it).
  The dungeon does the same, but first writes a trip record (user dir, dungeon_trip_<pid>.json) and starts the same
  executable on it: `-- --tripped=<record> --back=<label> --then=menu|quit [--out=]`. That process shows the card
  "<title> was stopped by the watchdog: one step of the game (frame N) did not return within 250 ms of processor time"
  with Leave (to the menu) or "Back to Create" (a Try-it run: exit code 3, RUNNER.md's watchdog code). It deletes the
  record when read. Still: watchdog-card.jpg.
- More than 20 script errors (the runner's limit) now stop a dungeon in place: the game stands still (tree paused)
  under the same kind of card with Leave, instead of jumping back to the menu.
- The load screen moves: PackLife.load_steps() gives load_entry's load as steps (each asset generator, then the entry
  with _pack_setup); load_entry runs them in one go as before (worker and world unchanged). The dungeon draws a frame
  between steps: a bar sweeps the track (16 px per drawn frame) and a line says which step runs ("building its parts
  (2 of 5: gen/art_hook.gd)", "setting up the game"). Until the last step the pack's nodes are disabled and the
  physics server is off, so the stepped load is the worker's one-frame load. Still: load-screen-steps.jpg (frames 26-40
  of a --write-movie run of hockey). One long step (a big _pack_setup) still holds the picture for its own length.

== Evidence ==
- selftest 640, 6/6 PASS (dungeon.list, .bypass, .refused, .hash_alone, .trips, and the new .watchdog). hash_alone and
  trips give the same hashes as before the stepped load (hockey 1d939cd60eab / ba40751d726a / a2f701657d43, parkour
  1a399b4e5d06, paddle e54b1e3eec2b): the stepped load changes no hash.
- dungeon.watchdog: fixture engine/kernel/dungeon/fixtures/runaway (a floor, a ball, an endless step at frame 60;
  passes lint). Headless `--dungeon=<fixture> --frames=600 --out=<f>` with TL_EXE_KEYS pressing Enter: the record names
  reason tick_timeout, phase _pack_tick, frame 60; the card process writes --out with
  "card":{"kind":"tripped","text":"Runaway fixture: an endless step was stopped by the watchdog...","button":"Back to
  Create","pressed":true} and no state hash. No time is asserted (the case waits for the file with an upper bound).
- The same through the exported exe (ThirdLife.exe --headless -- --dungeon=<fixture> ...): the same card, pressed,
  "why":"tripped"; no record left in %APPDATA%\ThirdLife.
- In a window (editor binary): the card process opened and showed the card (watchdog-card.jpg), Enter on it ended it.
- `tl check --tier full --only world`: PASS 8/8 (world = alone; the same hashes as at 21:39). PackLife changed, so this
  is the proof that the world's load is unchanged.
- `tl check --tier fast`: arch 12/12, assets, cards, devx.test 229/229, foreman.typecheck: all PASS (on main's contract
  and assets fixes).
- export.sh build + check on the final tree (fixture imported): PASS export.build (tag d0d0bd9 2026-11-20 22:54), PASS
  export.check, step 1b: hockey a2f701657d4358ea, parkour fe29c683143553c3, paddle 6550cd894ead7dff in the exe and the
  editor binary (unchanged by the stepped load); step 4 no process left.
- seeds and packs steps (the worker loads through the refactored PackLife): PASS seeds 39/39 (+0 vs last green), PASS packs 2/2, 48/48 verb runs
  (hockey bot_hockey a29dcdf02a16dd1c@4186, the same as before).
- Not run for L4b: the whole kernel selftest (block 640 and the world step cover what changed; the full gate is the
  Director's pre-merge list).

== Behaviour changes ==
- A runaway step in a dungeon used to hang the game forever; now the window closes and comes back with the card.
- The process that hung ends with exit code 0 (it ends itself with OS.kill, which gives 0 on Windows); the card process
  ends with 3 when it was a Try-it run. L3's parent sees the first pid end with 0: the trip is in the card process.
- More than 20 script errors: a card in place instead of a jump to the menu.
- PackLife.load_entry is now load_steps run in one go (same order, same marks, same calls).
- The fixture's two scripts are imported (their .uid files are tracked): the arch rule uid-orphans wants every .gd
  outside the pack folders it lists to have one, so the fixture is not under .gdignore and travels in the pck (unused).

== Files ==
new: engine/kernel/dungeon/watch.gd (+ .uid), engine/kernel/dungeon/fixtures/runaway/{pack.json, scripts/main.gd (+ .uid),
     tests/bot.gd (+ .uid)}; lane: watchdog-card.jpg, load-screen-steps.jpg
changed: engine/kernel/dungeon/dungeon.gd (watch hooks, stepped load, moving bar, _halt card, open_tripped, one card
     builder), engine/boot/hub.gd (relaunch_args, tripped_start, exit code 3), engine/boot/boot.gd (+3 lines: --tripped,
     592 lines), engine/kernel/runner/pack_life.gd (load_steps), engine/tools/selftest.d/640-dungeon.sh (dungeon.watchdog),
     engine/kernel/API.md (section 23, two lines), docs/EXE.md (two paragraphs), lane WORLD-dungeons.md

== Questions ==
1. guard.gd (the world's) and the worker each keep their own watchdog thread; watch.gd is a third small one over the same
   cpuclock verdict. A shared "watch" for all three would be a kernel/host change (not L4's column).
2. For Try it, L3 sees exit code 0 from the process it started when the watchdog ends it; the record and the card are in
   the process the watchdog starts. If L3 wants the verdict in its own process, the record path could be passed with
   the launch (launch(dir, record_path)): a small change, not made.

======================================================================================================================
L4c (Director 23:35, on main 1187806): the menu at 1280x720, and export.sh check step 3
======================================================================================================================
1. Menu at 1280 x 720: the key line lay over Quit and the dungeon list ran off the right edge (the menu was laid out in
   1920 x 1080 pixels and the project sets no stretch mode). engine/boot/menu.gd now lays the screen out in 1920 x 1080
   units and scales it by min(1, width / 1920, height / 1080), again when the window changes size. Stills:
   menu-1280x720.jpg (nothing overlaps, the list is whole), menu-1920x1080.jpg (pixel for pixel the image before the
   change: PIL difference bounding box None).
2. Step 3 "E and Q: NOT SHOWN": not caused by L4. The same scripted keys, run by the editor binary on a git-archive of
   3a4580b (before the menu) and on 1187806, give the same trace: he stops at [-25.28, 1.99, 13.06] from frame 450, never
   on stage. The kit court's gate is centred on x = -20 with 4.4 m to each side (landscape.gd: entrance = centre +
   dir * (r + 3.6), wings from half * 0.8 + 2.0), so at x = -25.3 he walks into its left wing. The route moved, not the
   menu. Fix in export.sh: Shift+W to frame 298 (was 263), the turn at 305, W from 315. Now: "E: a game was on stage from
   frame 750 to 990 (plot index 4; he stood at [-20.03,2,30.82]); Q: he was walking again at frame 1080".
Gates: PASS export.build (tag 1187806 2026-11-20 23:30), PASS export.check (step 3 SHOWN, Esc ended it at tick 1101);
selftest 640 6/6 PASS (hockey hashes are new after L5's merge, still dungeon = alone: 3b76944a17a3 / 304ec388730e);
fast gate PASS (arch 12/12, devx.test 229/229).
Files: engine/boot/menu.gd, engine/tools/export.sh (step 3 keys and comment), docs/EXE.md (L4c paragraph), lane stills.
