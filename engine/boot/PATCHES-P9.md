# P9: patches for files that are not P9's

Nothing here is needed for the exe to start: `engine/boot/boot.gd` works with the kernel as it is. Each entry is
something the export showed and a file outside P9's scope would have to change. Measured 2026-11-11 on Godot 4.7.2.

## 1. `kernel/host/host.gd`: the host cannot be the door of an exported build

Measured (`boot/probe.gd`): in the exe `ProjectSettings.globalize_path("res://")` is the EMPTY string and the class
cache is not a file on disk (it is inside the pack file). By the code (not run in the exe: it would start a second
game), `_ensure_import` therefore sees "no cache" and runs
`OS.execute(OS.get_executable_path(), ["--headless", "--path", "", "--import"])`: the game starts itself again.
`_run_worker_once` and `world_supervisor.gd` build `--path <engine_dir> res://kernel/host/host.tscn` with the same
empty `engine_dir`. So no verb and no mode of `host.gd` works in the exe; `boot.gd` starts `view.gd` and `world.gd`
directly instead. If the host should work there one day (a game verified inside the shipped build), the first patch is:

```gdscript
func _ensure_import() -> String:
	if not OS.has_feature("editor"):
		return ""        # an exported build carries its class cache inside the pack file: nothing to import
```

and the worker and child command lines must leave out `--path <engine_dir>` when `engine_dir` is empty (the exe finds
its own pack file). Not written, not tested.

## 2. `kernel/world/world.gd` `_resolve`, `kernel/runner/manifest.gd` `resolve_dir`: where a pack is looked for

Both turn a name into a folder with `ProjectSettings.globalize_path("res://...")` and `DirAccess.dir_exists_absolute`.
In the exe that is `"" + "seeds/seed_drive"`: never found. `boot.gd` works round it: it writes the walk with absolute
folder paths (`<exe folder>/games/<name>`) to `user://boot/village_<pid>.json` and removes the file at the end.
A base "the folder `games` beside the executable" in `_resolve` would make that temporary file unnecessary:

```gdscript
	if not OS.has_feature("editor"):
		var beside: String = OS.get_executable_path().get_base_dir().replace("\\", "/") + "/games/" + p
		if DirAccess.dir_exists_absolute(beside):
			return beside
```

A pack INSIDE the pack file is a different matter: `load("res://boot/probe/inner/scripts/main.gd")`,
`FileAccess.file_exists` and `DirAccess.dir_exists_absolute("res://boot/probe/inner")` all work in the exe, and
`Manifest.resolve_dir("res://boot/probe/inner")` returns "" there, because it globalizes first. If built-in games are
ever wanted inside the pack file, `resolve_dir` must keep a `res://` path as it is when the engine is not the editor,
and the folder must not carry `.gdignore` (`seeds/` and `kernel/examples/` do: they are not in the pack file at all).

## 3. `kernel/world/draw/view.gd`: three things a person meets

a. `_tour_shot` builds the file name from `out_dir`; with `--live` and no `--out-dir` it is `/01_<name>.png` (the
   root of the drive). `world.sh visit tour` would run the tour's ten `shot` events that way (read in the code, not run). The exe's walk has no
   shots. Patch: in `_start_tour`, `if not out_dir.is_empty():` round the loop that collects `shots`.
b. In `--live` the walk's scripted `enter` / `leave` events still reach the scheduler (read in the code, not run: tick 990 of `tour.json` puts the track on
   stage under a person who stands elsewhere, and is `refused`, or not, by where he happens to stand). `boot.gd` drops
   `events` from the walk it writes. Patch: `world.gd` should not hand `walk["events"]` to the scheduler when
   `player_live` is set, or `view.gd` should say that a live walk must not have them.
c. Esc while walking does nothing in `view.gd` (only "Q or Esc leaves the game on stage"); the window has to be
   closed. `boot.gd` adds it: Esc while nobody is on stage calls `world._end()`, which stops the watchdog and its
   PowerShell helper, and the viewer quits with the world's exit code. The same for the window's close button.

## 4. `kernel/world/draw/view.gd` `_live_input` and `kernel/world/visitor.gd`: how he steers (measured, not judged)

Keys were pressed by `boot.gd` through `Input.parse_input_event` in the exe (TL_EXE_KEYS) and the body traced:

| keys | what he does |
|---|---|
| W, 180 frames | 13.50 m in a straight line (4.5 m/s); with Shift 9 m/s |
| S, 300 frames | 21 m in one straight line (4.3 m/s); what the camera does meanwhile was not looked at |
| D alone, 430 frames | a circle about 3 m across, again and again |
| W + D, 300 frames | a circle about 5.6 m across, one lap in about 240 frames; 60 frames of W + D turn him 90 degrees |
| after Q | he stands where he stood when he pressed E (the viewer's "back at the plot's edge" moves the body 0.5 m, then the body's place is written back) |

A and D are "strafe relative to the camera", the visitor turns to where he moves and the chase camera follows his
back, so a held A or D is a circle and there is no way to sidestep or to look round without walking. It is usable
(W to walk, a tap of A or D with W to turn), and it is the first thing a person will notice. No patch is proposed:
how a player moves and engages is the chapter the owner set aside.

## 5. `kernel/world/draw/draw.gd` `edge_height`: a venue without ground of its own can be taken for one that has it

`edge_height` calls every mesh "terrain" that is at least `max(30, radius)` metres wide both ways and wider than tall.
The hockey game's merged dress mesh (stands, four light masts 39 m from the centre, two scoreboards at 36 m, flags) is
72.5 x 58.9 m and 15.6 m tall: with a plot radius of 30, 36 or 40 m its vertices in the ring `radius - 3 .. radius + 4`
give a "rim height" of 2.3, 3.9 and 10.6 m (measured with a scratch script that calls `edge_height`). The plot then
counts as `has_ground`: `view.gd` lowers the pack by the rim (`lift = -rim`; in the crane picture at radius 40 the
rink lay in a pit), `landscape.gd` leaves the world's terrain collider open inside the plot, and the pack has no ground
collider there (its only floor bodies are the ice and the apron boxes, 67 x 37 m). A scripted visitor placed inside
that plot fell through the world (feet y = -376 after 418 ticks; in the picture he hangs in the sky colour). With
radius 44 or 48 `edge_height` is NaN and the plot is treated correctly: at radius 46 the rink stands on the world's
pad and the visitor stands on the pad's grass at y 2.0 (pictures looked at). `boot/village.json` gives the hockey plot
radius 46 for that reason. A patch would be for `_wide_meshes` to accept only the kit's terrain sheets (by node name,
as `Layout_paddle_court/TerrainNear`) and not any wide merged mesh. Not written: `draw.gd` is being changed tonight.

## 6. `devx` arch rule `schema-versions`

`tl check --tier fast` refuses a `tl.<name>/<n>` string that no file in `contracts/` declares. The lines `boot.gd`
prints (what the build is, the capture, the probe) are therefore `thirdlife.exe/1`, and `boot/games.json` is
`thirdlife.exe.games/1`. If the build's identity line should be a contract (a `tl.`-prefixed name, exe, version 1, declared in `contracts/`; it is written apart here because the rule reads this file too), that is the
Director's edit; the names in `boot.gd`, `probe.gd` and `games.json` follow in three places.
