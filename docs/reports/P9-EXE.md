# P9 the executable: builder report and Director verification

Brief `briefs/BRIEF-P9-EXE.md`. Builder wall time 13:24 to 14:02 on 2026-11-11 (38 min; harness: 353,095 subagent tokens,
122 tool uses). Work done in the worktree `.claude/worktrees/core-p9` (branch `core-p9-exe`), started early so that the
export is proven before the night's merged tree exists.

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

P9 REPORT: the executable

STATUS

Done. `bash engine/tools/export.sh --commit <text>` makes `dist/ThirdLife/` in 9 to 18 s, unattended. `bash engine/tools/export.sh check` passes: all seven games reach the same state hash in the editor binary, in the exe, and in the exe copied to a folder with a space in its name. The exe started with no arguments shows the village, obeys the keys and ends cleanly. The hockey game is in as a seventh plot. `tl check --tier fast --changed` is green.

No person has started it. Keys were pressed by a script through the engine's input state. The nearest thing to a double click was a start through `explorer.exe`.

Start 13:23:57, end 14:01:58 (`date`): 38 minutes of the 100.

WHAT AN EXPORT NEEDS (measured with `export.sh probe`, editor binary against exe)

| question | editor binary | exe | consequence |
|---|---|---|---|
| JSON tables read by path (materials, style, tiers) | read | read, same bytes | the preset must include `*.json` |
| engine scripts as files and as text | yes, 30228 bytes | yes, 30228 bytes | preset exports scripts as text, so the exe compiles the same source |
| global classes | 44 | 44 | the class cache travels inside the pack file |
| class cache as a file on disk beside `res://` | yes | no | `host.gd` `_ensure_import` would start the exe again with `--import`; the host cannot be the exe's door |
| `ProjectSettings.globalize_path("res://")` | the `engine/` folder | empty string | every kernel lookup built on it finds nothing in the exe |
| the engine's own packs by `res://seeds/...` | found | not in the build | `seeds/` and `kernel/examples/` carry `.gdignore` |
| a pack inside the pack file: `file_exists`, `load(main.gd)`, run it | works | works | Godot itself can load a pack by `res://` |
| the same pack through `Manifest.resolve_dir` | its folder | "" | the kernel as written cannot, so games are folders on disk |
| a `.gd` written at run time outside the pack file: load, run, load its sibling, use `TLContext` and `TLKit` by name | compiles (570 ms) and runs | compiles (220 ms) and runs | a game can arrive after the game shipped |
| the same with a parse error | refused, process lives | refused, process lives | |
| GDScript compiled from a string | works | works | |
| shader load | works | works | |
| `cpuclock.gd` PowerShell helper | starts in 0.2 s | starts in 0.25 to 0.5 s, window handle 0 | the processor-time watchdog works in the exe, with no console window |
| drawing | | Direct3D 12, Forward+, RTX 4090 | no extra DLL beside the exe |

So the engine is in `ThirdLife.pck` and every game is a plain folder in `games/` beside the exe, loaded by absolute path.

Three premises of the brief were not as stated:
- **Esc:** `world.sh visit` does not quit on Esc; it only leaves the game on stage. `boot.gd` adds quit on Esc while walking, and a clean end on the window's close button.
- **Packs by `res://`:** this works in Godot but not through the kernel (table above).
- **The tour walk as it is:** it would write its ten `shot` pictures to the drive root in a live run, so the exe has its own walk without shots. This one is read in the code, not run.

WHAT `export.sh` DOES

- **Build** (`export.sh [--commit <text> | --commit-file <file>] [--out <dir>]`):
  - Checks Godot, node and the export template, then refreshes the class cache.
  - Exports the preset `ThirdLife` into a staging folder and copies the games listed in `engine/boot/games.json` into `games/`.
  - Writes `BUILD.txt` (commit, date, Godot version and kernelApi, sizes, the games) and `README.txt` (the keys).
  - Swaps the staging folder into place, so a failed export leaves the old build untouched.
  - Refuses a folder it did not make (exit 3, tested) and a build whose exe is running.
  - Runs no git. The commit defaults to `$TL_COMMIT`, else "unknown".
  - Exit codes: 0 done, 1 failed with the export's own error lines, 2 could not run, 3 refused.
- **Check** (`export.sh check`): the four steps shown below.
- **Probe** (`export.sh probe`): prints the table above.

Output of the last build:
```
export.sh: Godot 4.7.2.stable.official.ed1daf0bf, commit 'test'
commit: test
built: 2026-11-11 13:55:47 +0100 in 8 s
engine: Godot 4.7.2.stable.official.ed1daf0bf, kernelApi 0.1, release export template, Windows x86_64
what it opens: res://boot/boot.tscn (engine/boot/boot.gd), the walk res://boot/village.json
size: 105 MB (ThirdLife.exe 104 MB, ThirdLife.pck 1326 KB, games 217 KB)
games: seed_drive (seed.drive 0.1.0, plot drive), seed_wall (seed.wall 0.1.0, wall), seed_paddle (seed.paddle 0.1.0, paddle),
  ex_walker (example.walker 0.1.0, walker), ex_kit (example.kit 0.1.0, kit), ex_car (example.car 0.1.0, car),
  ice_hockey_three_against (game.ice_hockey_three_against 0.1.1, plot hockey, from site/ice-hockey-three-against-20261111-1/promoted/...)
export.sh: built in 9 s: C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p9\dist\ThirdLife\ThirdLife.exe
```

A second run replaced the first cleanly: a file planted in the old build was gone and `BUILD.txt` carried the new commit.

THE CHECK (last run 13:55:48 to 13:57:07, exit 0)

The scripted tour is 4000 world ticks, headless. The visitor enters the track at tick 990, the wall yard at 2460 and the hockey rink at 3720. Hashes are shortened to 16 characters.

| plot | game | own ticks | editor binary | exe | exe copied elsewhere | verdict |
|---|---|---|---|---|---|---|
| drive | seed.drive | 2969 | 9a76c18a6c394508 | 9a76c18a6c394508 | 9a76c18a6c394508 | same |
| wall | seed.wall | 1184 | 8478d42ca57a87b2 | 8478d42ca57a87b2 | 8478d42ca57a87b2 | same |
| walker | example.walker | 371 | 8d1831dc62dfe91a | 8d1831dc62dfe91a | 8d1831dc62dfe91a | same |
| paddle | seed.paddle | 2445 | 97868242bb563a09 | 97868242bb563a09 | 97868242bb563a09 | same |
| kit | example.kit | 332 | 34b19960cc4c5308 | 34b19960cc4c5308 | 34b19960cc4c5308 | same |
| car | example.car | 1872 | 9f4e65dac63e77ce | 9f4e65dac63e77ce | 9f4e65dac63e77ce | same |
| hockey | game.ice_hockey_three_against | 2338 | 32f204c65a40d58e | 32f204c65a40d58e | 32f204c65a40d58e | same |

```
editor binary: 4000 world ticks, 7 games, tick p50 1.889 ms, 0 script errors, 0 engine errors
exe: 4000 world ticks, 7 games, tick p50 1.607 ms, 0 script errors, 0 engine errors
exe copied elsewhere: 4000 world ticks, 7 games, tick p50 1.566 ms, 0 script errors, 0 engine errors
2. the exe with no arguments: picture written (d3d12, RTX 4090), exit code 0
3. W: the visitor ran 31.50 m in 210 frames of Shift+W (9 m/s would be 31.5 m)
   E: a game was on stage from frame 750 to 990 (plot index 3, the paddle court); Q: he was walking again at frame 1080
   Esc ended the process by itself at frame 1101, exit code 0
4. no process of the build is left
PASS export.check
```

- The same hashes came out of the check run before it, so they also held from run to run.
- This is one machine and one build. It is not proof for other processors.
- In step 3, W and Esc decide the verdict. E and Q are shown but not counted, because the route depends on where the landscape puts the paddle court's gate.
- The exe's logs from the check hold no ERROR or WARNING line.

THE CAPTURES (all looked at)

- `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p9\dist\ThirdLife-check\village.png` is the exe with no arguments at frame 120. The visitor is seen from behind on the dirt road running east, with his long shadow, grass, pines, the wall yard's crane, three mesas, and the paddle court's wall and flags up on its bank at the right, under an evening sky. The key line is at the bottom left: "W A S D walk  Shift run  E enter the game you stand in  Esc quit".
- `...\dist\ThirdLife-check\on_stage.png` is frame 900 of the key run. It shows the paddle court from above with its own score and hint, and my line "Q or Esc leave the game".
- `...\dist\P9-pictures\hockey_plot_from_a_crane.png` shows the rink on its pad at ground level with stands, masts, scoreboard, fence, gate and a spur to the road.
- `...\dist\P9-pictures\hockey_plot_inside_the_fence.png` shows the visitor on grass inside the fence at the back wall of a stand.
- `...\dist\P9-pictures\hockey_on_stage.png` shows the rink from above with six skaters and "BLUE 0 / RED 0".

The three hockey pictures were taken with the editor binary through `world.sh tour`, not with the exe.

SIZE AND DURATION

- Size: 105 MB (exe 104 MB, pck 1.3 MB, games 217 KB).
- Export: 9 to 18 s.
- Check: 1 min 19 s to 2 min 17 s, with other builders loading the machine.

FILES CHANGED

New:
- `engine/export_presets.cfg`
- `engine/tools/export.sh`
- `engine/boot/boot.gd` and `boot.gd.uid`
- `engine/boot/boot.tscn`
- `engine/boot/probe.gd` and `probe.gd.uid`
- `engine/boot/run_log.gd` and `run_log.gd.uid`
- `engine/boot/probe/inner/pack.json`
- `engine/boot/probe/inner/scripts/main.gd` and `main.gd.uid`
- `engine/boot/village.json`
- `engine/boot/games.json`
- `engine/boot/JOURNAL.md`
- `engine/boot/PATCHES-P9.md`
- `docs/EXE.md`

Edited: `engine/project.godot`, exactly one line added under `[application]`:
`run/main_scene.thirdlife_exe="res://boot/boot.tscn"`

Not tracked: `dist/`, `engine/.godot/`, and `foreman/node_modules` (see question 6).

Additions beyond the brief:
- **Run log:** `run_log.gd` writes `ThirdLife-last-run.log` beside the exe. The engine's own log folder is shared with every engine process on the machine and was rotated away within seconds.
- **Test hooks:** `boot.gd` reads `TL_EXE_KEYS`, `TL_EXE_TRACE`, `TL_EXE_CAPTURE`, `TL_EXE_CAPTURE_AT`, `TL_EXE_QUIT_AT` and `TL_EXE_WINDOW_POS`, so the keys can be tested without a person.

PATCHES FILE (`engine/boot/PATCHES-P9.md`, condensed; nothing in it is needed for the exe to start)

1. **`kernel/host/host.gd`:** the host cannot be the exe's door. `_ensure_import` would run the exe again with `--import`, and the worker and child command lines pass an empty `--path`. This is read in the code, not run in the exe. First patch:
   ```gdscript
   func _ensure_import() -> String:
   	if not OS.has_feature("editor"):
   		return ""        # an exported build carries its class cache inside the pack file: nothing to import
   ```
2. **`world.gd` `_resolve` and `manifest.gd` `resolve_dir`:** both globalize `res://`, which is empty in the exe. `boot.gd` works round it by writing the walk with absolute folder paths to `user://boot/village_<pid>.json` and removing it at the end. A base for "`games` beside the executable" would make that file unnecessary:
   ```gdscript
   	if not OS.has_feature("editor"):
   		var beside: String = OS.get_executable_path().get_base_dir().replace("\\", "/") + "/games/" + p
   		if DirAccess.dir_exists_absolute(beside):
   			return beside
   ```
   For packs inside the pack file, `resolve_dir` would have to keep a `res://` path as it is, and the folder must not carry `.gdignore`.
3. **`view.gd`, three things a person meets:**
   - a. With `--live` and no `--out-dir`, shot pictures get the file name `/01_<name>.png` (read in the code).
   - b. A live walk's scripted `enter` and `leave` events still reach the scheduler (read in the code). `boot.gd` drops them.
   - c. Esc while walking does nothing. `boot.gd` adds it.
4. **Steering, measured in the exe:**
   - W: 13.50 m straight in 180 frames.
   - S: 21 m straight in 300 frames.
   - D alone: a circle about 3 m across.
   - W + D: a circle about 5.6 m across; 60 frames turn him 90 degrees.
   - After Q he stands where he pressed E.
   - No patch proposed: how a player moves is the chapter the owner set aside.
5. **`draw.gd` `edge_height`:** it takes any wide merged mesh for terrain. The hockey venue's dress mesh is 72.5 x 58.9 m, and at plot radius 30, 36 or 40 it gives a "rim" of 2.3, 3.9 and 10.6 m. The rink is then lowered into a pit and the terrain collider is left open, and a scripted visitor placed there fell through the world (feet y -376). At radius 44 and more the result is NaN and the plot is correct, so the hockey plot has radius 46. The patch would be to accept only the kit's terrain sheets by node name. Not written, because `draw.gd` is being changed tonight.
6. **`devx` arch rule `schema-versions`:** it refuses a `tl.`-prefixed schema name that no contract declares. My lines are therefore `thirdlife.exe/1` and `thirdlife.exe.games/1`.

KNOWN NOT TO WORK IN THE EXE

- **A and D do not sidestep.** A held D is a circle. Turn with a tap of A or D while holding W. There is no mouse look. `world.sh visit` behaves the same.
- **After Q** the visitor stands where he pressed E, inside the venue, not at the gate.
- **A finished game stays over.** Nothing restarts it but restarting the exe.
- **The window is 1920 x 1080** with no scaling, no fullscreen and no settings.
- **No icon or version resource** in the exe. Windows x86_64 only.
- **`host.gd` verbs** (lint, smoke, bot, capture) do not exist in the exe.
- **The hockey game is optional.** If `site/` is missing when the build is made, the build has six games and says so. Removing the folder was tested: six games, exit 0, the other hashes equal except the paddle court, which gets one tick fewer.
- **A read-only folder** runs without `ThirdLife-last-run.log`.

NOT VERIFIED

- **No person has started it or looked at its live window.** The nearest test was the build copied to `%TEMP%\tl exe manual\Third Life\` and started with `explorer.exe "<exe>"`: parent process explorer, no arguments. After 10 s the window "Third Life" was responding, and the PowerShell helper was a child with window handle 0. The close message ended the process by itself, its log ends with `[tl] world done`, and nothing was left. That window appeared on the desktop for about 11 s, twice.
- **Steering by hand,** the feel of the camera, and playing a game with real keys.
- **Entering by keys** was done only for the paddle court. The hockey rink, track and wall yard were entered only by the scripted tour.
- **The message box** for a failed start is written but was not seen. The same refusal was tested headless: log line, exit 2.
- **Sound,** other machines, SmartScreen and antivirus.
- **The merged tree.** If another builder changes `view.gd` or `world.gd` (`start(options)`, or the properties `world`, `draw`, `stage`, `visitor`, `player_pos`, `_ended`, `_end()`), `boot.gd` must follow. The check will say so.
- **A Jolt warning** ("job system exceeded the maximum number of jobs") printed in two of three editor-binary windows with seven games. It did not appear in the exe's logs.

QUESTIONS

1. Should the build's identity line be a contract (a `tl.`-prefixed schema in `contracts/`)? I used `thirdlife.exe/1` to keep the gate green without touching contracts.
2. Should the exe have its own user data folder? It shares `Third Life Engine` with every dev process. That needs more `project.godot` lines than the one I was allowed.
3. Is radius 46 for the hockey plot acceptable until `edge_height` is fixed (patch 5)?
4. Should the pack file be embedded in the exe (one file fewer to lose)? I left it beside, which is Godot's default.
5. `export.sh check` opens three windows at position 0,1440 for about 50 s in total. Is that acceptable in the Director's end-of-night run? `TL_WINDOW_POS` moves them.
6. The gate ran every fast step because `docs/EXE.md` matches no step, and `foreman.typecheck` failed on a missing `foreman/node_modules` in this fresh worktree. I ran `npm ci --offline` there (local cache, no network, 8 packages, ignored by git). Say if that should not have been done.
7. `C:\Users\kazda\AppData\Local\Temp\p9.patch` exists and is not mine. I left it.

MINUTES

38, from 13:23:57 to 14:01:58 by `date`. No ThirdLife.exe process and no Godot process of this worktree is running. The trial folders in `%TEMP%` are removed.

---

## Director verification

Done 14:03 to 14:10 on 2026-11-11 in the builder's worktree, with five other builders running the engine.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash engine/tools/export.sh --commit d110f18` | built in 27 s: `dist/ThirdLife/ThirdLife.exe` (109 MB), `ThirdLife.pck` (1.4 MB), `games/` with seven games, `BUILD.txt`, `README.txt` |
| `bash engine/tools/export.sh check` | PASS. The scripted tour of seven games, 4,000 world ticks: every game's hash is the same from the editor binary, from the exe and from the exe copied to a folder with a space in its name (the builder's seven hashes). The exe with no arguments wrote its picture and ended with exit code 0. Scripted keys: 31.5 m on Shift+W, a game on stage between E and Q, Esc ended the process. No process of the build left |

**Looked at:** `dist/ThirdLife-check/village.png`: the exe's first view. The visitor stands on the dirt road with his
shadow, rolling land with a cliff at the left, a crane and mesas ahead, the paddle court's wall and flags on its
terrace at the right, drawn clouds, and the line of keys at the bottom left.

### What this settles

- The project exports and the export is the same game: seven games, equal hashes in the editor binary and in the exe.
  The research had listed editor against export determinism as never tested.
- Games are folders beside the exe, compiled by the exe at start: a game can arrive after the game shipped. The
  processor-time helper works in the exe without a console window.
- The kernel's own entry (`host.gd`) cannot be the exe's door and two lookups return nothing in an export; the boot
  script works round both. The patches are small and go to the next kernel pass.

### What is not verified

A person starting it and walking. Steering is as the builder says: A and D turn in a circle, there is no sidestep and
no mouse look, and after leaving a game the visitor stands where he entered. Sound. Another machine. The final build
of the night is made by the Director with the same two commands on the merged tree and recorded in the run's report.

### Director's decisions on the builder's questions

1. The build's identity line keeps the name `thirdlife.exe/1` outside the contracts.
2. A user data folder of its own for the exe: yes, with the next change to `engine/project.godot`.
3. Radius 46 for the hockey plot stands until `edge_height` takes only terrain sheets (the builder's patch 5).
4. The pack file stays beside the exe.
5. Three windows at 0,1440 during the check are accepted.
6. `npm ci --offline` in the worktree was fine: the Director had not linked `foreman/node_modules` there.
