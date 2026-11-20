# The executable: a build you start by double click

Package P9, 2026-11-11. The owner's rule: every night run ends with a runnable exe. This page says where the build is,
how to start it, what is in it, how it is made and proven, what an export of this project needs, and what does not
work. Everything stated as a fact was measured on this machine (Windows 11, Godot 4.7.2, RTX 4090) on that day.
**No person has started the exe yet**: keys were pressed by a script through the engine's own input state.

```
bash engine/tools/export.sh --commit <text>      # makes dist/ThirdLife/ and prints the full path of ThirdLife.exe
bash engine/tools/export.sh check                # proves the build (hashes, a picture, the keys, nothing left behind)
bash engine/tools/export.sh probe                # the table "what an export needs", measured again
bash engine/tools/export.sh check --tag-only     # only: is the build there the build of this commit (headless, seconds)
```

## Which build am I playing

(Night jam-lessons-home T1, 16 Nov.) On the jam's last morning the owner played a build of the evening before,
believing it the newest; nothing on the screen said which build ran. Now:

- **The corner.** The window's top right corner shows the build tag, small: the commit's short hash and the time of
  the export, for example `4e20087 2026-11-16 01:19`. The editor binary shows `dev`. A build without a tag file shows
  nothing there (no path, no name: `boot.gd` shows the line only when it has exactly that shape).
- **The file.** `BUILD-TAG.txt` beside `ThirdLife.exe` is that one line; `BUILD.txt` has it as `tag:`. `export.sh`
  writes it at every export (no rebuild of anything for a tag); the commit is read from the repository's `.git`
  files (HEAD of the tree exported: a worktree's own branch), so a build made with uncommitted changes carries the
  commit they sit on. `export.sh build --dry-run` writes only the tag file, to `dist/ThirdLife-dry-run/`.
- **The log.** Every start prints `[boot] build: <tag>` first (in `ThirdLife-last-run.log` for a person's start);
  `ThirdLife.exe --headless -- tag` prints only that and ends.
- **The newest, by one double click.** Every export writes `dist/PLAY-LATEST.cmd` beside the build folder: it starts
  the build just exported (relative paths only, so `dist/` can be copied), prints its tag, and says so when the build
  is not there. It points at the folder of the last export (`--out` included): the newest is the last made.
- **The proof.** `export.sh check` begins with step 0: the exe, headless, says its tag; FAIL when that is not the tag
  the export wrote (BUILD.txt), when its commit is not the commit of the tree now (`--expect <hash>` names another),
  or when `PLAY-LATEST.cmd` does not start this build. `--tag-only` runs step 0 alone; `--no-window` steps 0, 1 and 4
  (nothing opens a window); both say what they did not run.
- `export.sh build --no-warm` (or `TL_EXPORT_NO_WARM=1`) skips the cache run, which opens a window; that build
  ships no cache (BUILD.txt says so) and a first start builds its rims and pictures itself.

What the tag does not say: whether the tree had uncommitted changes when it was exported (no git is run), and which
games' versions came from `site/` (BUILD.txt lists them). The corner text was not seen in a picture on the night it
was made (every run was headless); its presence is proven by the log line and the label is made from the same value.

## For a person

| | |
|---|---|
| where | `dist/ThirdLife/` at the repository root (`dist/` is ignored by git). The folder can be copied anywhere; it needs nothing from the repository |
| start | double click `ThirdLife.exe`. `ThirdLife.pck` and the folder `games` must stay beside it. No arguments, no console |
| what you see first | (L4, 21 Nov) the main menu on the crisp sky: World, Dungeons, Create, Quit (section "The main menu and dungeons" below). World is what follows in this table |
| what you see in World | (P14) a 1920 x 1080 window: the compact village of seven games close to one dirt road, the visitor standing on the road looking east into it (the drive track behind its fence at the left, the kit court and the paddle court's wall at the right, the wall yard's crane, three mesas), one line with the keys at the bottom left |
| keys while walking | (P11) `W` / `S` walk forward and back where the camera looks, `A` / `D` step aside, the mouse turns the view (0.15 degrees a pixel: 600 pixels are a quarter turn; up and down within -10 to 60 degrees, so he stays in the picture), `Shift` run, `E` enter the game whose plot you stand in, `Esc` back to the menu (L4; before it: quit). The mouse is captured while you walk and free while a game is on stage or the window is not in front |
| keys inside a game | `Esc` always leaves the game; `Q` leaves it only when the game declared no action on `Q` (hockey passes on `Q`), and the hint says which (16 Nov, K8); everything else belongs to the game (the paddle court says "A / D or the arrow keys move your paddle"). After `Q` you stand 5 m outside the plot at its gate, facing away from it, the camera behind you |
| the games | each stands on a fenced plot with a gate and a spur to the road. Walk through the gate, stand inside the fence, press `E`: the picture becomes the game's own camera and you play instead of its bot |
| quit | Quit in the menu, or the window's close button anywhere. Both end what is open cleanly (exit code 0 when no game had an error). `Esc` while walking ends the world and returns to the menu |
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
| `ice_hockey_three_against` | Ice hockey, three against three (0.1.1, the first night job; a tracked house game since 16 Nov, H0) | hockey, at the east end of the road, on the lot P13 left for it (radius 44) | `engine/packs/hockey` (before H0: `site/ice-hockey-three-against-20261111-1/promoted/`, optional) |

Size: 124 MB (`ThirdLife.exe` 104 MB: the engine's release template; `ThirdLife.pck` 1.5 MB: every script, shader and
JSON table of `engine/`; `games/` 217 KB; P14: `cache/` 19 MB, 20 files: the rims, the far pictures and the rig recipes
of these seven games, see "The first start"). The export takes 10 to 18 s (class cache 3 s, export 5 s, copying), the
check 1 min 20 s to 2 min, both with other builders loading the machine.

## The main menu and dungeons (L4, night of 21 Nov)

The owner's picks (spark `designer-and-two-worlds`): one main menu at boot; a dungeon is its own scene, the world is
unloaded, and the avatar, camera, HUD and look all come from the dungeon.

```
ThirdLife.exe                                    the main menu (a person's start: no argument, no TL_EXE_* instrument)
ThirdLife.exe -- --dungeon=<pack dir> [--look=<name>] [--seed=N]
                                                 that pack straight as a dungeon; "Back to Create" ends the process
ThirdLife.exe --headless --fixed-fps 60 -- --dungeon=<pack dir> --frames=N [--seed=N] [--out=<abs file>]
                                                 a counted dungeon without a window: its state hash, then the end
<godot> --headless --fixed-fps 60 --path engine res://boot/boot.tscn -- trips --out=<abs file> [--trips=3]
                                                 menu -> World -> menu -> dungeon -> menu, N times, a census each time
```

- **The menu** (`engine/boot/menu.gd`, colours read from `style/style_crisp.json` by `kernel/dungeon/look_ui.gd`):
  World, Dungeons, Create, Quit. Arrows or W/S move, Enter or Space opens, Esc goes back; the mouse works too. With
  the focus on Dungeons the list shows at the right (title, the look's name, and a still of the last frame you saw in
  that dungeon, `%APPDATA%\ThirdLife\dungeon_stills\<pack id>.png`, or a letter tile before the first visit). The
  build tag stays in the top right corner.
- **World** is the village exactly as before (the same `boot.gd` code path). Only Esc changed: the walk ends, the world
  prints its lines as it always did, its viewer and world are freed, and the menu is back.
- **Dungeons** come from `engine/boot/dungeons.json` (`tl.dungeons/1`: `{"pack", "title", "look"?}`; `pack` relative to
  `engine/`, `look` a `TL_STYLE` name: crisp, classic, diorama, overcast; absent: the default look). Today: hockey
  (crisp), parkour, the paddle court seed. A dungeon must be one of `boot/games.json` (export.sh refuses a build
  otherwise): in the exe it runs from its folder in `games/`. Picking one shows a load screen with its title for half a
  second, installs its look, and runs the pack alone (`kernel/dungeon/dungeon.gd`: the worker's lifecycle in mode
  `play`, the pack's own camera and HUD, no visitor). Esc opens the pause card (Resume, Leave); the tree is paused
  meanwhile. Leave frees every node of the pack, puts the default look back and shows the menu.
- **Create** mounts `res://ui/create/create.tscn` when the build has it (lane L3: its root has `open()` and emits
  `closed`); without it the button reads "Create (coming tonight)" and does nothing.
- **Try it** (L3): `load("res://kernel/dungeon/dungeons.gd").launch(<job dir>/pack)` starts the running executable again
  as a second process with `-- --dungeon=<dir>` (under the editor binary with `--path <engine> res://boot/boot.tscn`).
  Its pause card says "Back to Create", which ends that process (exit code 0). Its log is
  `ThirdLife-last-dungeon.log` beside the exe, so it does not overwrite the menu's `ThirdLife-last-run.log`.
- **What goes past the menu, as before:** every verb (`check`, `probe`, `tag`), every flag (`--record`, `--input`,
  `--site-job`, `--games`, `--edits`, `--ticks`, any other `--x`), a headless start, and every unattended instrument in
  the environment (`TL_EXE_CAPTURE`, `_CAPTURE_AT`, `_QUIT_AT`, `_KEYS`, `_WARM`, `_TRACE`, `_FRAMES`). `--menu` or
  `TL_EXE_MENU=1` shows the menu anyway; that is how the scripted clips of the menu are made (the keys of `TL_EXE_KEYS`
  work in the menu and in a dungeon, and keep counting while the pause card pauses the tree).

Measured (21 Nov, RTX 4090, other lanes loading the machine; selftest 640 and the runs named):

| what | figure |
|---|---|
| a dungeon hashes as the pack alone | hockey 600 and 1200 frames (seeds 1, 7), parkour 900, paddle 900 (seed 3): `--dungeon --frames=N` = `worker --mode=play --frames=N`, every one; the exe = the editor binary for all three dungeons (`export.sh check` step 1b) |
| three round trips, headless (`trips`, world 600 ticks, hockey 600 frames) | from the 3rd menu to the 7th: nodes 33 = 33, resources 159 = 159, objects 1870 = 1870, static memory +0.02 MB; the three hockey runs hash as alone, the three worlds' ten games hash alike |
| three round trips in a window (editor binary, scripted keys) | in the world 2869 nodes, 249 MB static, 897 MB video; back at the menu 33 nodes, 172.5 MB, 629 MB. Menu 3 to menu 7: nodes 0, resources 0, objects +10, static +0.09 MB, video +0.25 MB (`docs/shifts/2026-11-21-night/lanes/L4-dungeon/census-window-3-trips.jsonl`) |
| what is not given back | the first world and the first dungeon each leave caches (scripts, shaders, the shadow atlas: menu 94 MB static / 67 MB video before, 172 / 629 MB after the first round trip); later trips add nothing measurable |
| the clip | `lanes/L4-dungeon/exe-menu-dungeon-world.mp4` (28 s, the exe, scripted keys): menu, Dungeons, hockey (load screen, its camera and HUD, crisp), Esc, Leave, menu with the hockey still, World, walk, Esc, menu |

**The dungeon's watchdog (L4b).** Every call into a dungeon's pack code is watched as the runner's worker watches it:
a thread asks `kernel/host/cpuclock.gd` whether the call has used its limit of processor time (a step 250 ms, a setup
call 10 s). A runaway step cannot be interrupted, so the game writes why to `%APPDATA%\ThirdLife\dungeon_trip_<pid>.json`,
starts itself again on that record (`-- --tripped=<record>`) and ends: the person sees the window close and come back
with a card "<title> was stopped by the watchdog: one step of the game (frame N) did not return within 250 ms of
processor time" and Leave (to the menu; in a Try-it process "Back to Create", which ends it with exit code 3). The
process that hung ends with exit code 0 (it ends itself with OS.kill). More than 20 script errors stop a dungeon in
place: the game stands still under the same kind of card. Nothing of the watch reaches a hash or a game's result.
Selftest 640 `dungeon.watchdog` (fixture `engine/kernel/dungeon/fixtures/runaway`: an endless step at frame 60).

**The load screen moves (L4b).** The pack loads in steps (each asset generator, then the entry with its
`_pack_setup`: `PackLife.load_steps`) with a drawn frame between them, so the bar sweeps and the line under it says
which step runs ("building its parts (2 of 5: gen/art_hook.gd)"). One step that takes long (a big `_pack_setup`)
still holds the picture for its own length. While it loads, the pack's nodes do not run and the physics server is
off, so the stepped load is the worker's one-frame load: the dungeon still hashes as alone (selftest 640).

Not verified: a person's hands on the menu (keys and mouse were pressed by a script through the engine's input), a
dungeon whose pack loads for long (the load screen is drawn before the load and does not move during it), the exe's
static memory (a release template does not count it: the census leaves the key out there).

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
| `engine/boot/boot.gd`, `boot.tscn` | the exe's door. No arguments: the main menu for a person (L4; before it: the village). `-- check --out=<file>`: the scripted tour without a window. `-- probe --out=<file>`: the table above. It starts the same two nodes `host.gd` starts (`kernel/world/draw/view.gd` with `--live`, `kernel/world/world.gd`) with the same `start(options)` |
| `engine/boot/hub.gd`, `menu.gd`, `dungeons.json`, `frames.gd` | L4: the menu, `--dungeon`, `trips` and the census (`hub.gd`); the menu's screen (`menu.gd`); the dungeon list (`dungeons.json`, `tl.dungeons/1`); the TL_EXE_FRAMES instrument moved out of `boot.gd` unchanged (`frames.gd`). The dungeon itself: `engine/kernel/dungeon/` |
| `engine/boot/village.json` | the walk (`tl.walk/1`). P14: the compact village of P13 (`kernel/world/walks/compact_village.json`: six games about 4 m apart beyond their pads, both rows close to one road) with the hockey arena on the lot at its east end, and the scripted tour for the check (enter the kit court, the drive track and the hockey arena). `pack` is a folder name in `games/` |
| `engine/boot/games.json` | which games `export.sh` copies into `games/`, and from where. An `optional` game that is not found is left out with a warning, and `boot.gd` leaves its plot out |
| `engine/boot/probe.gd`, `probe/inner/` | the measurements of the table above; `inner` is a pack that travels inside the pack file, never run as a game |
| `engine/boot/run_log.gd` | a logger: everything the exe prints, and every engine error, into `ThirdLife-last-run.log` beside the exe, anew on every start by a person. The engine's own `user://logs/godot.log` is shared with every other engine process on the machine (same project name) and was rotated away within seconds while other builders ran |
| `engine/tools/export.sh` | build, check, probe |

`boot.gd` reads `res://boot/village.json`, replaces each plot's `pack` by `<folder of the exe>/games/<name>`, drops
plots whose folder is missing (and their pad height), and writes the result to
`%APPDATA%\ThirdLife\boot\village_<pid>.json` (P11: the exe has a user folder of its own, `%APPDATA%\ThirdLife`,
by the feature `thirdlife_exe` in `project.godot`; the editor binary keeps `Godot\app_userdata\Third Life Engine`), which the world host reads; the
file is removed when the process ends. `export.sh` builds into `dist/.ThirdLife.new.<pid>` and swaps at the end: a
failed export leaves the build before it untouched. It refuses to replace a folder whose `BUILD.txt` it did not write
(exit 3) and a build whose exe is running. It never runs git: the commit is `--commit <text>`, the first line of
`--commit-file <file>`, `$TL_COMMIT`, else "unknown". Exit codes: 0 done, 1 failed (the reason and the lines of the
export that say why), 2 could not run (no Godot, no export templates, no node), 3 refused.

For unattended starts `boot.gd` reads the environment: `TL_EXE_CAPTURE=<abs png>` (one picture after 120 physics
frames; `TL_EXE_CAPTURE_AT=<frame>`), `TL_EXE_QUIT_AT=<frame>` (a clean end at that frame), `TL_EXE_WINDOW_POS=x,y`,
`TL_EXE_KEYS="60:+W;240:-W;270:~600,0;300:+Escape"` (keys pressed and released, and P11 mouse movements `~dx,dy` in
pixels, at physics frames through `Input.parse_input_event`: the same input a keyboard and a mouse make),
`TL_EXE_TRACE=<abs file>` (where the visitor's body is, where he looks and who is on stage, every 30 frames).
P11: `ThirdLife.exe -- --record=<abs file>` writes the visit as an input record (`tl.input/1`; a game played on stage
is `<file>.<plot>.<n>.json` beside it) and `ThirdLife.exe -- --input=<abs file>` plays it again: the visitor's keys
and mouse are sampled once per world tick into one input of the world's own (`engine/kernel/runner/visit.gd`), and
nothing below that line reads a device.

## The construction site (S, engine-world-next, 17-18 November)

The village has one construction site: the lot south of the road at its east end, `(240, -55)`, radius 40
(`engine/boot/village.json`, `landscape.lots[0]`; the model is `engine/kernel/world/WORLD.md` section S). It shows a
Foreman job being built from that job's own `job.jsonl`, and the game its last `promoted` event names arrives on the
lot and is played like any other (walk up, E enters, Q or Esc leaves).

- **Which job: one key in one file.** `landscape.lots[0].job` in `engine/boot/village.json`: a job directory relative to
  the repository root (or absolute). Today: `site/ice-hockey-three-against-20261111-1` (the recorded job of 11 Nov;
  `site/` is job output in the main checkout: from a worktree export.sh and the editor binary look there too).
- **In the build:** `dist/ThirdLife/sites/<job folder name>/job.jsonl` and `.../promoted/<pack id>@<version>/` (only the
  game the LAST `promoted` event names). `export.sh` copies them and says so in `BUILD.txt` ("construction sites").
  `boot.gd` points the lot at `<folder of the exe>/sites/<job folder name>` (the editor binary with `--games=<dir>`
  looks beside that folder; without it, the walk's own job directory is used).
- **A job that is not found** (no `job.jsonl`) leaves a plain building site: `export.sh` warns and builds without it,
  `boot.gd` prints `[boot] lot 0 is a plain building site: ...` and lists it under `left_out` in its first line.
- The village's site is LIVE (no `replay`): the copied log is read at the start and looked at again every 60 ticks.
  The build holds the log as it was when the build was made; to watch a job that is running, see the next item.
- **Two sites (S4).** `landscape.lots[1]` at (310, 55), radius 42, shows the hockey job of 11 Nov
  (`site/ice-hockey-three-against-20261111-1`); export.sh copies it to `sites/` as it does the first. `--site-job`
  points only the first site lot at a running job.
- **Follow a running job (S2): `ThirdLife.exe -- --site-job=<abs job dir>`** (also after `-- check`). The village's
  first site lot then reads that job directory's `job.jsonl` live, as the Foreman writes it (looked at every 60
  ticks), and its last promoted game arrives from that directory's `promoted/`. Nothing is written there. A path that
  is not absolute or has no `job.jsonl`: `[boot] warning: --site-job=...` and the exported copy is shown. From a
  shortcut or a console: `ThirdLife.exe -- --site-job=C:/Users/<you>/kiro/third-life/site/<job id>`.
- **Test instrument (S3): `-- check --edits=<abs json file>`**: the walk's `edits` (`[[world tick, file, replacement
  file]]`, kernel/world/jobs.gd): a file is copied over another at a world tick. The selftest `site.follow_exe` grows a
  job's `job.jsonl` with it at ticks 100 to 400, so the live site's stages fall on the same ticks every run.

## The first minute (P14)

What a person sees and does, from the four pictures of P14 (`engine/captures/p14/`, taken from the exe by
`TL_EXE_CAPTURE_AT` with scripted keys):
1. Double click. After about 2.7 s on a first start (1.6 s on the next) the window shows the visitor from behind on
   the dirt road, looking east into the village: the drive track behind its fence at the left, the kit court's wall
   and the paddle court at the right, flags, a crane, mesas, an evening sky (`1_first_frame.png`). The key line is at
   the bottom left. The games around him are already running (their bots play).
2. `W` (and `Shift`) walks him along the road; the mouse turns him. After 10 s of walking the road runs on between the
   track and the courts (`2_road_after_10s.png`).
3. Turned south (600 pixels of mouse), `W` takes him through the gate into the kit court; `E` puts the game on stage:
   the picture is the game's own camera, the key line says "Q or Esc leave the game" (`3_on_stage.png`; the kit example
   is a test bench, an ice slab with a ball and broken wall pieces, not a game to play).
4. `Q`: he stands at the court's gate, facing the road and the drive track across it (`4_after_leaving.png`). `Esc` quits.

Known in that minute: entering a game that has ended by itself (the kit example ends after 332 ticks) restarts it,
and that rebuild is done at once in the frame: 107 to 163 ms. The road shows hard-edged patches of a lighter tone where
the soft ground patches meet it (`2_road_after_10s.png`). With vsync on, a frame is 16.7 to 17.0 ms, so the tour
line's count of frames over 16.7 ms says nothing in the exe; its worst frames are below.

## The first start (P14)

Measured with the same scripted keys (W along the road, Esc at frame 700), `%APPDATA%\ThirdLife` deleted before the
first start (it holds the user's cache and Godot's shader cache):

| | first start, no shipped cache (build of 18:40) | second start | first start, cache shipped (build of 18:48) | second start |
|---|---|---|---|---|
| process start to first frame | 4621 ms | 1654 ms | 2674 ms | 1614 ms |
| world start to first frame | 2635 ms | 606 ms | 640 ms | 613 ms |
| all seven games stand | before the first frame (all built there, 1.86 s) | 2573 ms | 2538 ms | 2171 ms |
| worst frames (the capture's own frame left out) | 82 ms (two far pictures made in the frame) | 41 ms | 56, 45, 39 ms | 38, 38, 36 ms |

(The two left columns used the check's keys, the right two W along the road; the first-start figures are what the
cache changes.) The cache: `export.sh` runs the new exe once in a window with `TL_EXE_WARM=1` and
`TL_CACHE_DIR=<build>/cache` (the village's scripted tour, about 70 s); every start copies what the user's cache lacks
from `cache/` beside the exe (`PlotFile.seed_cache`). Every key is a game folder's content (rims, pictures: P5/P13;
rig recipes: P14, before their path), so a changed game gets new keys and is never served a stale entry. What a first
start still costs: about 1 s more to the first frame (Godot's shader cache, which belongs to the driver and is not
shipped, and copying 19 MB).

## Proof (`bash engine/tools/export.sh check`, the last run of 2026-11-11)

P14, exit code 0, 1 min 10 s. The scripted tour of the compact village (4000 world ticks; the visitor enters the kit
court at tick 450, the drive track at 1500 and the hockey arena at 3570; hashes shortened to 16 characters):

| plot | game | own ticks | tiers seen | hash, editor binary | hash, exe | hash, exe copied elsewhere | verdict |
|---|---|---|---|---|---|---|---|
| walker | example.walker | 371 | backdrop | f1c7b53757c34040 | f1c7b53757c34040 | f1c7b53757c34040 | same |
| drive | seed.drive | 3062 | sideline,backdrop,stage | 386fa5c2b30abd28 | 386fa5c2b30abd28 | 386fa5c2b30abd28 | same |
| wall | seed.wall | 1221 | backdrop,sideline | cb75fb26a1e80254 | cb75fb26a1e80254 | cb75fb26a1e80254 | same |
| paddle | seed.paddle | 2057 | sideline,backdrop | d84d59860fd2b887 | d84d59860fd2b887 | d84d59860fd2b887 | same |
| kit | example.kit | 332 | sideline,stage,backdrop | 6b270cedbf59690d | 6b270cedbf59690d | 6b270cedbf59690d | same |
| car | example.car | 1872 | backdrop,sideline | 3a459d0fe25e7853 | 3a459d0fe25e7853 | 3a459d0fe25e7853 | same |
| hockey | game.ice_hockey_three_against | 2476 | backdrop,sideline,stage | dc7b01fb9ad8e1da | dc7b01fb9ad8e1da | dc7b01fb9ad8e1da | same |

```
editor binary: 4000 world ticks, 7 games, tick p50 1.473 ms, loaded in 2192 ms, 0 script errors, 0 engine errors, on stage: kit@450 drive@1500 hockey@3570
exe: 4000 world ticks, 7 games, tick p50 1.219 ms, loaded in 1733 ms, 0 script errors, 0 engine errors, on stage: kit@450 drive@1500 hockey@3570
exe copied elsewhere: 4000 world ticks, 7 games, tick p50 1.211 ms, loaded in 1774 ms, 0 script errors, 0 engine errors, on stage: kit@450 drive@1500 hockey@3570
export.sh check: 2. the exe with no arguments: one picture after 120 frames, then a clean end on request
export.sh check:    picture: dist\ThirdLife-check\village.png (2411688 bytes; driver:d3d12,adapter:NVIDIA GeForce RTX 4090), exit code 0
export.sh check: 3. the keys: Shift+W east along the road, the mouse turns him south, W into the kit court, E at frame 720, Q at 1000, Esc at 1100 (nothing else ends this run)
   W: the visitor ran 31.50 m in 210 frames of Shift+W (9 m/s would be 31.5 m), from [-60,0.06,2] to [-28.5,0.05,2]
   E: a game was on stage from frame 750 to 990 (plot index 4; he stood at [-24.88,2,33.37]); Q: he was walking again at frame 1080
export.sh check:    Esc ended the process by itself at tick 1101, exit code 0
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

The pictures were looked at (P14): `dist/ThirdLife-check/village.png` (the exe with no arguments at frame 120: the
same frame as `1_first_frame.png` above) and `dist/ThirdLife-check/on_stage.png` (frame 900 of the key run: the kit
example's own camera, and "Q or Esc leave the game").

## Known not to work, and not verified

- **No person has started it.** The nearest thing done: the build copied to `%TEMP%\tl exe manual\Third Life\` was
  started through the Windows shell (`explorer.exe "<path>\ThirdLife.exe"`, which is what a double click does: parent
  process `explorer`, no arguments, no console). After 10 s: the window "Third Life" was there and responding, the
  watchdog's PowerShell helper ran as its child with no window (handle 0); the close button's message ended the process
  by itself, its log ends with `[tl] world done`, nothing was left. Nobody looked at that window. Steering by hand, the
  feel of the camera, playing a game with real keys: not verified.
- (P11, fixed) A and D sidestep, the mouse looks, after `Q` he stands at the gate. Measured in the exe with scripted
  keys and mouse (`TL_EXE_KEYS`, trace every 30 frames): `W` 180 frames 13.50 m on one straight line; `D` 180 frames
  13.50 m on a straight line at 90.0 degrees to it; 600 pixels of mouse turned him 90.00 degrees and -600 back; after
  `Q` in the track he stood at (0, -21), 5.0 m outside its edge at its gate, facing away from it. Steering by a
  person's hand, the feel of the mouse (sensitivity, no smoothing): not verified.
- A fence stops him; the gate is where the spur from the road meets the plot. WORLD.md: the drive's hollow is too
  steep to walk into (its rim is 40 to 60 degrees). Only the kit court (P14; before it the paddle court) was entered through its gate by keys.
- A game that ended by itself stays over (WORLD.md: the owner paused the next round). Nothing in the exe starts a game
  again but starting the exe again. What a finished game looks like to a person who then enters it was not looked at.
- The window opens at 1920 x 1080 (the project's size; the project sets no stretch mode, so nothing scales the picture
  to another window size). On a smaller screen it does not fit. No fullscreen key, no settings. Nobody listened for sound.
- The exe's vsync is switched on by `boot.gd` (the project runs without, for captures); frame time in the check's
  window was 16.7 ms.
- (P14) The hockey plot has radius 44 m, the arena's own (P13 placed the lot for it); the fault of PATCHES-P9 5 was not
  seen in the compact village (the arena stands on its pad in every picture and the check enters it). Since H0 (16 Nov) the hockey
  game is the tracked `engine/packs/hockey` and no longer optional: a build without it fails. The hashes of the table
  above were taken with the `site/` copy (byte-identical pack) and are to be proved again from the new path.
- Only Windows x86_64. No icon and no version resource in the exe: the preset has `application/modify_resources=false`
  (changing them needs `rcedit`, which this tool does not look for).
- Windows SmartScreen or an antivirus may question an unsigned exe on another machine: not tested (no other machine).
- `host.gd` verbs (lint, smoke, bot, capture) do not exist in the exe: PATCHES-P9 1.
- The Jolt warning "job system exceeded the maximum number of jobs" was printed in two of three editor-binary windows
  with seven games (`world.sh tour`, while taking the hockey pictures; WORLD.md saw it once with six); engine errors 0,
  pictures fine. The logs of the exe's runs in the check hold no ERROR and no WARNING line.
- `ThirdLife-last-run.log` is written beside the exe: a build in a folder that cannot be written (a read-only share)
  runs without it. `boot.gd` also writes its walk to `%APPDATA%\ThirdLife\boot\` (P11; before: the editor's
  folder `Godot\app_userdata\Third Life Engine`, shared with every engine run on the machine).
- (P11) `host.gd` no longer starts the exe again when it looks for a class cache (`_ensure_import` returns at once
  outside the editor binary), and `Manifest.resolve_dir` keeps a `res://` folder as it is in an export (a game inside
  the pack file can be found). The host's verbs in the exe are still not tried: their worker command lines name
  `--path <engine>`, which is empty there (PATCHES-P9 1, second half).
