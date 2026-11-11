# P9 journal: the executable

Builder of package P9 (branch `core-p9-exe`). Start: 2026-11-11 13:23:57 (`date`). Time-box ends 15:03.

- 13:24 Read the brief, WORLD.md, world.sh, host.gd, view.gd, world.gd (start, `_resolve`, `_end`), cpuclock.gd, manifest.gd
  (`resolve_dir`), tl_context.gd (`load_script`, `read_json`). Findings before any measurement:
  - `host.gd` cannot be the exe's door: `_ensure_import` looks for `.godot/global_script_class_cache.cfg` on disk beside
    `res://` and, when it is missing, runs the executable again with `--import`. In an exported build that would start
    the game a second time. The boot scene therefore starts `kernel/world/draw/view.gd` and `kernel/world/world.gd`
    itself, exactly as `host.gd` `_start_mode` does (`new()`, `add_child`, `start(options)`).
  - `world.gd` `_resolve` and `manifest.gd` `resolve_dir` turn a pack name into a directory ON DISK
    (`ProjectSettings.globalize_path` + `DirAccess.dir_exists_absolute`), so a pack inside the pack file is never found
    by them; `seeds/` and `kernel/examples/` carry `.gdignore`, so the export leaves them out anyway.
  - `view.gd` writes a picture for every `shot` event of a walk into `--out-dir`; with `--live` and no out-dir the file
    name would begin with `/`. The exe's walk has no shots.
  - Esc in `view.gd` leaves the game on stage; nothing quits the window but closing it. The boot script adds: Esc while
    walking ends the world cleanly.
- 13:31 `godot --headless --import` in the worktree: 3 s. First trial export (`--export-release ThirdLife` to a temp
  folder): 5 s, exit 0, ThirdLife.exe 104 MB + ThirdLife.pck 1.3 MB. Preset: all resources + `*.json`, scripts as text,
  pack file beside the exe, no console wrapper, feature tag `thirdlife_exe`. The one line added to `project.godot`:
  `run/main_scene.thirdlife_exe="res://boot/boot.tscn"`.
- 13:32 `boot/probe.gd` run in the exe and in the editor binary (table in docs/EXE.md). The facts that decide the design:
  the exe compiles a `.gd` from a folder outside the pack file (and that script uses TL* classes by name and loads its
  sibling); `globalize_path("res://")` is EMPTY in the exe, so `Manifest.resolve_dir("res://...")` finds nothing: the
  kernel cannot load a pack from inside the pack file, although `load("res://.../main.gd")` itself works there;
  `seeds/` and `kernel/examples/` are not in the pack file at all (`.gdignore`); the cpuclock's PowerShell helper starts
  from the exe in 250 ms and has no window (handle 0). So: games are folders beside the exe, boot.gd writes the walk
  with absolute folder paths to `user://boot/village_<pid>.json` and removes it at the end.
- 13:32 Scripted check by hand, 4000 ticks, seven games (hockey as the seventh plot at [228, 2, -70], entered at tick
  3720): editor binary and exe give the same seven hashes. The exe with no arguments and TL_EXE_CAPTURE: picture
  looked at: the visitor on the road, the bank of the walker plot, flags, mesas, the key line at the bottom; d3d12.
- 13:35 `engine/tools/export.sh --commit test`: 18 s, dist/ThirdLife (105 MB). `export.sh check`: PASS in 1 min 54 s
  (three headless tours, the window with one picture, W for 180 frames = 13.50 m, Esc ends the process, nothing left).
  boot.gd got TL_EXE_KEYS (keys pressed at physics frames through `Input.parse_input_event`) and TL_EXE_TRACE so the
  keys can be tested without a person.
- 13:38 Keys tested in the exe without a person (TL_EXE_KEYS, trace of the body every 30 frames): W 180 frames = 13.50 m
  straight; D alone = a circle 3 m across; W + D = a circle 5.6 m across (60 frames turn him 90 degrees); S = straight
  back the other way. Route Shift+W east 31.5 m, W+D 60 frames, W south through the paddle court's gate, E at frame
  720: the paddle court came on stage at tick 721 (picture looked at: the court from above, the game's own HUD and
  hint, my line "Q or Esc leave the game"), Q at 1000: walking again, Esc at 1100: the process ended by itself, exit 0.
  This route is now step 3 of `export.sh check` (W and Esc decide; E and Q are shown and not counted).
- 13:44 Second `export.sh` run replaced the first (a file planted in the old build was gone, BUILD.txt says the new
  commit); a foreign folder is refused with exit 3 and left alone; `--commit-file` works. The exe with the hockey
  folder removed: six games, the hockey plot left out and said so, the other hashes equal except the paddle court
  (one tick fewer: the scheduler shares ticks among fewer games), exit 0. With no `games` folder: exit 2 and the reason.
- 13:45 `tl check --tier fast --changed`: FAIL arch schema-versions (my schema name, `tl.` + `exe` + version 1, is declared in no contract; written apart here because the rule reads this file too). The lines
  are now `thirdlife.exe/1` (and `thirdlife.exe.games/1`): PASS, 8 rules.
- 13:47 Final run on the finished files: export 10 s, probe, check PASS in 1 min 20 s.
- 13:48 The hockey plot. A scripted visitor placed inside it (radius 40) fell through the world (feet y -376). Cause
  found with a scratch script: `draw.gd` `edge_height` takes the venue's merged dress mesh (72.5 x 58.9 m: stands,
  masts, scoreboards) for terrain; at radius 40 the "rim" is 10.6 m (the masts), so the plot counts as having ground of
  its own: the rink is lowered 10.6 m into a pit and the world's terrain collider is left open inside the plot. At
  radius 44 and more `edge_height` is NaN. The plot is now radius 46 at [234, 2, -78]; pictures looked at: the rink
  stands on the pad at ground level with stands, masts and scoreboard, a spur and a gate; the visitor stands on grass
  inside the fence at y 2.0 and is stopped by the back wall of the stand. PATCHES-P9.md entry 5.
- 13:51 `export.sh check` on the build with the moved hockey plot: PASS (2 min 17 s); the hockey and wall hashes
  changed with the plot's place (other ticks by tier), and are again the same in editor binary, exe and moved exe.
  The exe's opening picture now looks east along the road (boot.gd keeps the scripted path for a person: its second
  point is where he looks).
- 13:52 The nearest thing to a double click: the build copied to `%TEMP%\tl exe manual\Third Life\`, started with
  `explorer.exe "<exe>"` (parent process explorer, no arguments, no console). After 10 s: window there and responding,
  PowerShell helper a child with window handle 0, `CloseMainWindow()` ended the process by itself, nothing left.
  Found there: the window's title was the project's ("Third Life Engine"), now `get_window().title`; and the engine's
  own log (`user://logs/godot.log`) had already been rotated away by other builders' engine processes (five files,
  all of other runs). So `boot/run_log.gd`: a Logger that writes `ThirdLife-last-run.log` beside the exe. Run again:
  title "Third Life", the log beside the exe holds the boot line, `[view] start`, `[boot] ending the world at frame
  222`, the seven pack lines, `[tl] world done`.
- 13:56 Temp folders of the trials removed; three pictures of the hockey plot kept in `dist/P9-pictures/`.
  Final export + check + `tl check --tier fast --changed` started on the finished files.
- 13:57 Final run on the finished files: export 9 s, `export.sh check` PASS in 1 min 19 s (seven hashes equal in
  editor binary, exe, moved exe; the same hashes as the run before: also the same from run to run).
- 13:58 The gate: `docs/EXE.md` matches no step, so `tl check --tier fast --changed` runs every fast step. Two things
  failed: arch (this journal and PATCHES-P9.md quoted the undeclared schema name: reworded) and foreman.typecheck
  (`foreman/node_modules` missing in this fresh worktree). `npm ci --offline` in `foreman/` (from the local npm cache,
  no network; 8 packages, ignored by git). Then: arch, assets, cards, devx.test (123 pass), foreman.typecheck all PASS.
- 14:01 docs/EXE.md has the final check; pictures `dist/ThirdLife-check/village.png` and `on_stage.png` looked at.
  No ThirdLife.exe is running; trial folders in %TEMP% removed. Report follows.
- 14:03 PATCHES-P9.md entry 1 marked as read in the code; the fast gate run again on the final files: see the report.
