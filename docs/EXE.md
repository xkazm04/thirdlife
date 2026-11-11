# The executable: a build you start by double click

Package P9, 2026-11-11. The owner's rule: every night run ends with a runnable exe. This page says where the build is,
how to start it, what is in it, how it is made and proven, what an export of this project needs, and what does not
work. Everything stated as a fact was measured on this machine (Windows 11, Godot 4.7.2, RTX 4090) on that day.
**No person has started the exe yet**: keys were pressed by a script through the engine's own input state.

```
bash engine/tools/export.sh --commit <text>      # makes dist/ThirdLife/ and prints the full path of ThirdLife.exe
bash engine/tools/export.sh check                # proves the build (hashes, a picture, the keys, nothing left behind)
bash engine/tools/export.sh probe                # the table "what an export needs", measured again
```

## For a person

| | |
|---|---|
| where | `dist/ThirdLife/` at the repository root (`dist/` is ignored by git). The folder can be copied anywhere; it needs nothing from the repository |
| start | double click `ThirdLife.exe`. `ThirdLife.pck` and the folder `games` must stay beside it. No arguments, no console |
| what you see | a 1920 x 1080 window: the village of seven games along a dirt road, the visitor standing on the road looking east, one line with the keys at the bottom left |
| keys while walking | `W` walk, `S` walk back the other way, `A` / `D` turn (see "known not to work"), `Shift` run, `E` enter the game whose plot you stand in, `Esc` quit |
| keys inside a game | `Q` or `Esc` leave the game; everything else belongs to the game (the paddle court says "A / D or the arrow keys move your paddle") |
| the games | each stands on a fenced plot with a gate and a spur to the road. Walk through the gate, stand inside the fence, press `E`: the picture becomes the game's own camera and you play instead of its bot |
| quit | `Esc` while walking, or the window's close button. Both end the world cleanly (exit code 0 when no game had an error) |
| if the window closes at once | a message box should say why (for example: the folder `games` is not beside the exe; the box is written and was not seen: the same refusal was tested headless, where it is a log line and exit code 2). Everything the last start printed is in `ThirdLife-last-run.log` beside the exe |

What is in it (`BUILD.txt` in the build says the same, with the commit and the date):

| folder in `games/` | game | plot | from |
|---|---|---|---|
| `seed_drive` | Drive-around: three laps against the clock | drive | `engine/seeds/` |
| `seed_wall` | Knock the wall down: sixty seconds | wall | `engine/seeds/` |
| `seed_paddle` | Paddle court: first to five | paddle | `engine/seeds/` |
| `ex_walker` | a walker in a room, a skater on ice | walker | `engine/kernel/examples/` |
| `ex_kit` | kit parts under the laws | kit | `engine/kernel/examples/` |
| `ex_car` | a box car on a slalom, then ice | car | `engine/kernel/examples/` |
| `ice_hockey_three_against` | Ice hockey, three against three (0.1.1, the first night job) | hockey, east of the wall yard | `site/ice-hockey-three-against-20261111-1/promoted/` |

Size: 105 MB (`ThirdLife.exe` 104 MB: the engine's release template; `ThirdLife.pck` 1.3 MB: every script, shader and
JSON table of `engine/`; `games/` 217 KB). The export takes 10 to 18 s (class cache 3 s, export 5 s, copying), the
check 1 min 20 s to 2 min, both with other builders loading the machine.

## What an export of this project needs (measured: `export.sh probe`, `engine/boot/probe.gd`)

| question | editor binary | exported exe | consequence |
|---|---|---|---|
| JSON tables read by path (`res://kernel/data/materials.json`, `style/style.json`, `kernel/world/tiers.json`) | read | read, same bytes | the preset must include `*.json`: they are not resources and an export leaves them out by default |
| scripts of the engine as files (`FileAccess.file_exists("res://kernel/host/host.gd")`, its text) | yes, 30228 bytes | yes, 30228 bytes | the preset exports scripts as text (`script_export_mode=0`), so the exe compiles the same source the editor binary compiles |
| global classes (`TLContext`, `TLKit`, ...) | 44 known | 44 known | the class cache travels inside the pack file |
| the class cache as a file on disk beside `res://` | yes | **no** | `host.gd` `_ensure_import` would start the executable again with `--import`: the host cannot be the exe's door (PATCHES-P9 1) |
| `ProjectSettings.globalize_path("res://")` | the `engine/` folder | **the empty string** | every place the kernel finds a pack with `globalize_path` + `dir_exists_absolute` finds nothing in the exe |
| the engine's own packs by `res://` (`res://seeds/seed_drive/pack.json`) | found | **not in the build** | `seeds/` and `kernel/examples/` carry `.gdignore`; an export skips them |
| a pack that IS inside the pack file (`res://boot/probe/inner`): `file_exists`, `load(".../main.gd")`, run it, list its folder | works | works | Godot itself can load a pack from inside the pack file by its `res://` path |
| the same pack through the kernel (`Manifest.resolve_dir("res://boot/probe/inner")`) | its folder | **"" (not found)** | the kernel as written cannot: it globalizes the path first. So games are folders on disk |
| a `.gd` file written at run time into a folder outside the pack file: `load(<abs path>)`, run it, it loads its sibling script and uses `TLContext` and `TLKit` by name | compiles (570 ms under load) and runs | **compiles (220 ms) and runs** | a game can arrive after the game shipped: the release template has the GDScript compiler |
| the same with a parse error | refused, the process lives | refused, the process lives | a broken game does not take the exe down at load |
| GDScript compiled from a string | works | works | |
| shaders (`res://style/shaders/toon.gdshader`) | load | load | |
| the watchdog's helper process (`kernel/host/cpuclock.gd` starts PowerShell) | starts in 0.2 s, answers | starts in 0.25 to 0.5 s, answers, **no window** (window handle 0) | the processor-time watchdog works in the exe as in the editor; measured in a headless start from a shell, see "not verified" |
| the folder of the exe | | writable; `games/` lists seven folders | |
| drawing | | Direct3D 12, Forward+, the same as `world.sh` windows | no extra DLL beside the exe was needed |
| the main scene | `kernel/host/host.tscn` | `boot/boot.tscn` | one feature-tagged line in `project.godot` (below) |

So the build is: the engine inside `ThirdLife.pck`, every game a plain folder in `games/` beside the exe, loaded by its
absolute path exactly as the runner loads a pack directory today.

## How it is put together

| file | what it is |
|---|---|
| `engine/export_presets.cfg` | one preset, `ThirdLife`: Windows Desktop x86_64, all resources plus `*.json`, scripts as text, the pack file beside the exe (not embedded), no console wrapper, the feature tag `thirdlife_exe` |
| `engine/project.godot` | one line added under `[application]`: `run/main_scene.thirdlife_exe="res://boot/boot.tscn"`. Only a build with that feature tag starts in the boot scene; the editor binary and every tool still start in `kernel/host/host.tscn` |
| `engine/boot/boot.gd`, `boot.tscn` | the exe's door. No arguments: the village for a person. `-- check --out=<file>`: the scripted tour without a window. `-- probe --out=<file>`: the table above. It starts the same two nodes `host.gd` starts (`kernel/world/draw/view.gd` with `--live`, `kernel/world/world.gd`) with the same `start(options)` |
| `engine/boot/village.json` | the walk (`tl.walk/1`): the six plots, road and landscape of `kernel/world/walks/tour.json`, the hockey rink as a seventh plot, and the scripted tour for the check (enter the track, the wall yard and the rink). `pack` is a folder name in `games/` |
| `engine/boot/games.json` | which games `export.sh` copies into `games/`, and from where. An `optional` game that is not found is left out with a warning, and `boot.gd` leaves its plot out |
| `engine/boot/probe.gd`, `probe/inner/` | the measurements of the table above; `inner` is a pack that travels inside the pack file, never run as a game |
| `engine/boot/run_log.gd` | a logger: everything the exe prints, and every engine error, into `ThirdLife-last-run.log` beside the exe, anew on every start by a person. The engine's own `user://logs/godot.log` is shared with every other engine process on the machine (same project name) and was rotated away within seconds while other builders ran |
| `engine/tools/export.sh` | build, check, probe |

`boot.gd` reads `res://boot/village.json`, replaces each plot's `pack` by `<folder of the exe>/games/<name>`, drops
plots whose folder is missing (and their pad height), drops the scripted events when a person walks, and writes the
result to `%APPDATA%\Godot\app_userdata\Third Life Engine\boot\village_<pid>.json`, which the world host reads; the
file is removed when the process ends. `export.sh` builds into `dist/.ThirdLife.new.<pid>` and swaps at the end: a
failed export leaves the build before it untouched. It refuses to replace a folder whose `BUILD.txt` it did not write
(exit 3) and a build whose exe is running. It never runs git: the commit is `--commit <text>`, the first line of
`--commit-file <file>`, `$TL_COMMIT`, else "unknown". Exit codes: 0 done, 1 failed (the reason and the lines of the
export that say why), 2 could not run (no Godot, no export templates, no node), 3 refused.

For unattended starts `boot.gd` reads the environment: `TL_EXE_CAPTURE=<abs png>` (one picture after 120 physics
frames; `TL_EXE_CAPTURE_AT=<frame>`), `TL_EXE_QUIT_AT=<frame>` (a clean end at that frame), `TL_EXE_WINDOW_POS=x,y`,
`TL_EXE_KEYS="60:+W;240:-W;300:+Escape"` (keys pressed and released at physics frames through
`Input.parse_input_event`: the same input state a keyboard sets), `TL_EXE_TRACE=<abs file>` (where the visitor's body
is and who is on stage, every 30 frames).

## Proof (`bash engine/tools/export.sh check`, the last run of 2026-11-11)

Exit code 0, 1 min 19 s. The scripted tour (4000 world ticks; the visitor enters the track at tick 990, the wall yard
at 2460 and the hockey rink at 3720; hashes shortened to 16 characters):

| plot | game | own ticks | tiers seen | hash, editor binary | hash, exe | hash, exe copied elsewhere | verdict |
|---|---|---|---|---|---|---|---|
| drive | seed.drive | 2969 | backdrop,sideline,stage | 9a76c18a6c394508 | 9a76c18a6c394508 | 9a76c18a6c394508 | same |
| wall | seed.wall | 1184 | backdrop,sideline,stage | 8478d42ca57a87b2 | 8478d42ca57a87b2 | 8478d42ca57a87b2 | same |
| walker | example.walker | 371 | sideline,backdrop | 8d1831dc62dfe91a | 8d1831dc62dfe91a | 8d1831dc62dfe91a | same |
| paddle | seed.paddle | 2445 | sideline,backdrop | 97868242bb563a09 | 97868242bb563a09 | 97868242bb563a09 | same |
| kit | example.kit | 332 | backdrop,sideline | 34b19960cc4c5308 | 34b19960cc4c5308 | 34b19960cc4c5308 | same |
| car | example.car | 1872 | backdrop,sideline | 9f4e65dac63e77ce | 9f4e65dac63e77ce | 9f4e65dac63e77ce | same |
| hockey | game.ice_hockey_three_against | 2338 | backdrop,sideline,stage | 32f204c65a40d58e | 32f204c65a40d58e | 32f204c65a40d58e | same |

```
editor binary: 4000 world ticks, 7 games, tick p50 1.889 ms, loaded in 4019 ms, 0 script errors, 0 engine errors, on stage: drive@990 wall@2460 hockey@3720
exe: 4000 world ticks, 7 games, tick p50 1.607 ms, loaded in 3260 ms, 0 script errors, 0 engine errors, on stage: drive@990 wall@2460 hockey@3720
exe copied elsewhere: 4000 world ticks, 7 games, tick p50 1.566 ms, loaded in 3360 ms, 0 script errors, 0 engine errors, on stage: drive@990 wall@2460 hockey@3720
export.sh check: 2. the exe with no arguments: one picture after 120 frames, then a clean end on request
export.sh check:    picture: dist\ThirdLife-check\village.png (2201558 bytes; driver:d3d12,adapter:NVIDIA GeForce RTX 4090), exit code 0
export.sh check: 3. the keys: Shift+W east along the road, W+D to turn, W into the paddle court, E at frame 720, Q at 1000, Esc at 1100 (nothing else ends this run)
   W: the visitor ran 31.50 m in 210 frames of Shift+W (9 m/s would be 31.5 m), from [-95,0.15,1] to [-63.5,0.21,0.46]
   E: a game was on stage from frame 750 to 990 (plot index 3; he stood at [-59.46,6.02,32.69]); Q: he was walking again at frame 1080
export.sh check:    Esc ended the process by itself at frame 1101, exit code 0
export.sh check:    picture at frame 900: dist\ThirdLife-check\on_stage.png
export.sh check: 4. no process of the build is left
PASS export.check: the exe runs the same games to the same hashes as the editor binary, shows the village, obeys W and Esc, and leaves nothing behind (dist/ThirdLife-check)
```

"Editor binary" is `Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path engine res://boot/boot.tscn
-- check` on the source tree with the build's `games/` folder; "exe" is `ThirdLife.exe --headless --fixed-fps 60 --
check`; the third is the whole build copied to `%TEMP%\tl exe copy <pid>\Third Life\` (a path with spaces, outside the
repository) and run there. The research had flagged editor against export determinism as never tested: for these
seven games over 4000 world ticks (Jolt, the scheduler's tiers, three games entered and played by their bots) the
state hashes are identical. One build, one machine, one run of each: not a proof for other machines or other
processors.

The pictures were looked at: `dist/ThirdLife-check/village.png` (the exe with no arguments at frame 120: the visitor
seen from behind on the dirt road that runs east in front of him, his long shadow, grass and tufts, pines, the wall
yard's crane, three mesas, the paddle court's wall and flags up on its bank at the right, clouds in an evening sky, the
key line at the bottom left) and `dist/ThirdLife-check/on_stage.png` (frame 900
of the key run: the paddle court from above with its own score and hint, and "Q or Esc leave the game").

## Known not to work, and not verified

- **No person has started it.** The nearest thing done: the build copied to `%TEMP%\tl exe manual\Third Life\` was
  started through the Windows shell (`explorer.exe "<path>\ThirdLife.exe"`, which is what a double click does: parent
  process `explorer`, no arguments, no console). After 10 s: the window "Third Life" was there and responding, the
  watchdog's PowerShell helper ran as its child with no window (handle 0); the close button's message ended the process
  by itself, its log ends with `[tl] world done`, nothing was left. Nobody looked at that window. Steering by hand, the
  feel of the camera, playing a game with real keys: not verified.
- **A and D do not sidestep.** They are "move relative to the camera", the visitor turns to where he moves and the
  camera follows his back: a held `D` is a circle 3 m across, `W` + `D` a circle 5.6 m across (measured). Turn with a
  tap of `A` or `D` while holding `W`. There is no mouse look. This is `kernel/world/draw/view.gd` as it is
  (`world.sh visit` behaves the same); PATCHES-P9 4.
- After `Q` the visitor stands where he pressed `E` (inside the venue, possibly among its bodies), not at the gate.
- A fence stops him; the gate is where the spur from the road meets the plot. WORLD.md: the drive's hollow is too
  steep to walk into (its rim is 40 to 60 degrees). Only the paddle court was entered through its gate by keys.
- A game that ended by itself stays over (WORLD.md: the owner paused the next round). Nothing in the exe starts a game
  again but starting the exe again. What a finished game looks like to a person who then enters it was not looked at.
- The window opens at 1920 x 1080 (the project's size; the project sets no stretch mode, so nothing scales the picture
  to another window size). On a smaller screen it does not fit. No fullscreen key, no settings. Nobody listened for sound.
- The exe's vsync is switched on by `boot.gd` (the project runs without, for captures); frame time in the check's
  window was 16.7 ms.
- The hockey plot has radius 46 m because a smaller one trips a fault in the draw layer (PATCHES-P9 5). If `site/` is
  not there when the build is made, the build has six games and says so.
- Only Windows x86_64. No icon and no version resource in the exe: the preset has `application/modify_resources=false`
  (changing them needs `rcedit`, which this tool does not look for).
- Windows SmartScreen or an antivirus may question an unsigned exe on another machine: not tested (no other machine).
- `host.gd` verbs (lint, smoke, bot, capture) do not exist in the exe: PATCHES-P9 1.
- The Jolt warning "job system exceeded the maximum number of jobs" was printed in two of three editor-binary windows
  with seven games (`world.sh tour`, while taking the hockey pictures; WORLD.md saw it once with six); engine errors 0,
  pictures fine. The logs of the exe's runs in the check hold no ERROR and no WARNING line.
- `ThirdLife-last-run.log` is written beside the exe: a build in a folder that cannot be written (a read-only share)
  runs without it. `boot.gd` also writes its walk to `%APPDATA%\Godot\app_userdata\Third Life Engine\boot\`.
