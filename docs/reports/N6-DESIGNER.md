# N6 the designer panel in the game: builder's journal and Director verification

Brief `briefs/BRIEF-N6-DESIGNER.md`. The builder started at 01:25 on 2026-11-11 in the engine copy
`site/_work/n6/engine/`. Its journal ends at 01:55 with every item done; **it never sent a final report**: the agent
went silent, no process of its own was running at 03:52, and a message asking for the report was not answered by
04:05. What follows is the builder's own journal, unchanged, then the Director's verification from the files on disk.
The usual builder sections "what a player still cannot do" and "what I did not verify" are therefore missing; the
Director's own list is at the end.

---

## Builder journal (verbatim, `engine/ui/JOURNAL.md`)

# N6 journal (designer panel)

Resume point. Newest entry last. Times are CEST from `date`.

- 01:25 start. Read the brief, JOB.md, N3 report, the marble job, STYLE, host.gd's windowed worker, the fake adapter.
- 01:31 ui/job_model.gd (reads job.jsonl itself, tolerant of a torn tail), ui/foreman_door.gd + ui/foreman_run.mjs
  (the door: one detached node process runs the Foreman steps in a chain and logs to <jobs root>/_ui_logs/).
- 01:35 ui/panel.gd (list + sheet, built in code, colours from style/style.json), ui/host.gd + host.tscn, tools/ui.sh.
- 01:37 first capture on the real site/ root (read only): the panel drew on the first run. Looked at it: list of 5 real
  jobs, marble Build with 3 packages, question + answer, 6 thumbnails. The first marble job shows as `stalled`
  (a real dead Foreman).
- 01:39 ui/selftest.gd: 61 checks; 4 failed on my own wrong expectations (core_run is 309.2 s not 313.6; 2 of 3 at
  event 60; 11 dirs; ints come back as floats). Fixed the expectations after recomputing each by hand.
- 01:40 ui/fixtures/make_fixtures.mjs (seven display states cut from the real marble log into site/_work/n6/fx) and
  make_fake.mjs (fake-adapter script: pack_min in two packages, with `params`; flags file). Pre-check of the chain
  approve -> plan -> run -> change through ui/foreman_run.mjs on the real runner (snapshot4): exit 0, 73 events,
  two promotions (site/_work/n6/precheck, deleted later).
- 01:42 captures of the empty list and the real marble job (site/ root, --readonly): looked at each.
- 01:43 ui/drive.gd: the live session through input events only. First run passed end to end in 160 s: describe,
  approve, mid-build, done, change request, second promotion, slider drag writes balls 9 -> 3 (valid JSON).
  Proof: site/_work/n6/live_shots/live_proof.txt.
- 01:46 looked at the fixture captures. Found and fixed: a stalled job kept counting time (now it stops at its last
  event); the tune label column was too narrow; "Foreman not found" was printed twice in the list; the enlarged
  picture never showed (its box had size 0: now sized by hand in _fit).
- 01:48 ui/PATCHES.md (kernel input polls the keyboard: three exact patches, none applied, none run).
- 01:49 second live session (live2): a builder's question answered in the panel, the session's own Foreman killed
  mid-run -> the row turns `stalled` in 3.6 s -> Resume -> done; a second game discarded. Passed in 80 s.
- 01:52 selftest now also checks the command lines each button starts (69 checks). 720p captures looked at.
- 01:53 the REAL hockey job (read only) taught two things: a builder's question can be open while the job is still
  `running` (other packages go on), and `foreman answer` refuses while a Foreman holds the lock. The list chip now
  says `question` whenever one is open, and the answer field is disabled with the reason until the job pauses.
- 01:55 drive: also clicks a picture (enlarge, close), the notes fold, and the "let it change core" choice.

---

## Director verification

Done 03:52 to 04:05 on 2026-11-11, from the files the builder left.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash tools/ui.sh selftest` in the copy | 69 passed, 0 failed |
| the same on the main tree after merging `ui/**` and `tools/ui.sh` | 69 passed, 0 failed |
| the builder's live-path record `site/_work/n6/live_shots/live_proof.txt` read | a scripted session against the Foreman's fake adapter: a click on "New game...", 64 key events typed into the field, Enter, the brief appears, a click on "Approve and build", mid-build, done, a milestone picture enlarged and closed, notes folded, a change request typed and sent. Steps are marked `UI event`, `read` or `direct` (screenshots) |
| the Director's own captures on the main tree: `ui.sh shot --jobs=site --select=ice-hockey-three-against-20261111-1 --section=build` and `--section=change`, read only | the panel shows tonight's real hockey job: `done`, 4 of 4 packages with rounds, minutes and tokens, both questions with the Director's answers, five milestones with their pictures, 2 change requests, 5 tunable values |

**Looked at:** `ui/captures/03-marble-build.png`, `07-marble-tune.png` (builder's, in the copy) and the Director's two
hockey captures (`docs/reports/img/n6_panel_hockey.jpg`).

### What the Director saw

- It follows the owner's taste as briefed: a list of short rows (name, state chip, packages done, a thin bar, time) and
  a sheet for the selected game with folding sections. Small type, tight rows, ink-dark panels in the style's palette
  over the game picture. Nothing reads as a chat log.
- A stalled job (a Foreman that died) shows as `stalled` in red and stops counting time, as the brief asked.
- The second marble job's question and the Director's answer appear as two one-line rows.
- The hockey pack declares 5 tunable values, so the builder prompt added in N3 reached a real builder and the Tune
  section has real content.

### What is not verified

- The second live session (a question answered in the panel, a killed Foreman, Resume): its record was not read.
- A slider's write to a pack's data file: covered by the selftest, not looked at by the Director.
- The 1280x720 captures and every capture not named above.
- No person has clicked it. Nothing here ran with a real model.
- The panel inside a running game: tonight it runs in its own host scene with a still picture behind it.

### What a player still cannot do (Director's reading)

- Open the panel while playing: the kernel polls the keyboard, so typing in a field would steer the game behind it.
  The builder's three exact patches for that are in `engine/ui/PATCHES.md`; none is applied and none has run.
- See a tuned value take effect without starting the game again.
- Point at something in the world and ask for a change to it.

### Merged

`engine/ui/**` (without the 42 MB of captures, which stay in the builder's copy) and `engine/tools/ui.sh`, both new.
Nothing else was touched.

---

## The builder's patches (verbatim, `engine/ui/PATCHES.md`; none applied)

# N6: patches the kernel needs before the panel can live inside a running game

None of these is applied. N6 touched nothing outside `ui/` and `tools/ui.sh`; tonight the panel runs in its own host
scene (`ui/host.tscn`). Each patch below is exact text against this engine copy (`site/_work/n6/engine`, the kernel
as of 2026-11-11 01:25). **None of them has been run.**

## 1. Keys typed into a field must not reach the game

**Why.** `kernel/api/tl_input.gd` does not use input events: `_sample()` polls the keyboard with
`Input.is_physical_key_pressed()` every physics frame (line 120). A `LineEdit` that consumes a key event changes
nothing about that poll, so typing "wasd" or a space into "Describe a game..." would steer and shoot in the game
behind the panel.

**Patch, `kernel/api/tl_input.gd`**, in `_sample()`:

```gdscript
# before
func _sample() -> void:
	for name: StringName in _actions.keys():
		var a: Dictionary = _actions[name]
		var v: float = float(a["injected"])
		if accept_devices:

# after
func _sample() -> void:
	var devices: bool = accept_devices and not keys_taken()
	for name: StringName in _actions.keys():
		var a: Dictionary = _actions[name]
		var v: float = float(a["injected"])
		if devices:
```

and one new function in the "kernel side" part of the same file:

```gdscript
## True while a text field has the keyboard (the designer panel's fields): the game sees no key then.
func keys_taken() -> bool:
	var vp: Viewport = get_viewport()
	var f: Control = vp.gui_get_focus_owner() if vp != null else null
	return f is LineEdit or f is TextEdit
```

Injected input (bots) is not touched, so no verify verb changes.

## 2. Esc must not end the game while the panel is open

**Why.** `kernel/runner/worker.gd` line 247 ends a `play` run when Esc is down, again by polling. With the panel open,
Esc should give the keyboard back to the game (or close the enlarged picture), not quit.

**Patch, `kernel/runner/worker.gd`**, in `_physics_process()`:

```gdscript
# before
	if mode == "play" and Input.is_physical_key_pressed(KEY_ESCAPE):
# after
	if mode == "play" and Input.is_physical_key_pressed(KEY_ESCAPE) and not _designer_open():
```

with

```gdscript
func _designer_open() -> bool:
	var layer: Node = get_node_or_null("TLDesigner")
	return layer != null and (layer as CanvasLayer).visible
```

## 3. Show the panel over a running pack

**Why.** There is no place in the kernel where a 2D layer of the game's own interface is mounted, and no key for it.
The panel is a plain `Control` (`ui/panel.gd`) that needs a jobs root and a door (`ui/foreman_door.gd`).

**Patch, `kernel/runner/worker.gd`**, at the end of the scene set-up in `start()` (after `TLStandin.install_look`):

```gdscript
	if mode == "play" and not ctx.headless and opts.has("jobs"):
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "TLDesigner"
		layer.layer = 50
		layer.visible = false
		add_child(layer)
		var door: RefCounted = (load("res://ui/foreman_door.gd") as GDScript).new()
		var flags: Variant = (load("res://ui/job_model.gd") as GDScript).call("read_json", str(opts.get("foreman-flags", "")))
		door.call("setup", str(opts["jobs"]), {"flags": (flags as Dictionary).get("flags", {}) if flags is Dictionary else {},
			"flags_name": str((flags as Dictionary).get("name", "")) if flags is Dictionary else ""})
		var panel: Control = (load("res://ui/panel.gd") as GDScript).new()
		panel.call("setup", str(opts["jobs"]), door, {})
		layer.add_child(panel)
```

and the key that shows and hides it (Tab), in the same file:

```gdscript
func _unhandled_key_input(event: InputEvent) -> void:
	if mode == "play" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		var layer: CanvasLayer = get_node_or_null("TLDesigner") as CanvasLayer
		if layer != null:
			layer.visible = not layer.visible
			if not layer.visible and get_viewport().gui_get_focus_owner() != null:
				get_viewport().gui_get_focus_owner().release_focus()
```

`tools/tl.sh play` then needs two options passed through to the worker: `--jobs=<dir>` and `--foreman-flags=<json>`
(the worker already takes every `--name=value` into `opts`; `fix_arg` in `tl.sh` must also treat `--jobs=` and
`--foreman-flags=` as paths). Two things to check when this is tried: the worker runs with
`process_mode = PROCESS_MODE_ALWAYS`, so the panel's one-second poll keeps running when the game is paused; and
`tl_orbit_cam.gd` reads the mouse in `_unhandled_input`, so clicks and the wheel on the panel do not reach it (the
panel's two boxes stop the mouse), while a drag that starts on the game and crosses the panel still orbits.

## 4. Tune: a value takes effect at the next start, because nothing can restart a pack

**Why.** A slider writes the number into the promoted pack's data file (through a temporary file, then a rename).
Packs read their data once, in `_pack_setup`; the kernel has no call that loads a pack a second time in the same
process, so the sheet says "A change takes effect at the next start of the game" and that is true.

**Proposal (not exact text, it needs a kernel builder's judgement):** a `restart_pack()` in `worker.gd` that frees
`pack_node`, clears `ctx.input`'s declared actions and the cameras, and runs `_load_pack()` and the `_pack_setup` /
`_pack_start` sequence again with the same seed; the panel would call it 300 ms after the last slider movement. I
did not find a cleaner live path: a per-value "set" hook would need every pack to implement it.

## 5. Which pack does the game play?

Not a patch, a gap: the panel tunes `<job>/promoted/<pack id>[@version]/`, the directory the last `promoted` event
names. When the Foreman promotes into the engine (`--promote-to engine`, `dest: packs/<id>`), the panel shows "no
promoted pack" for that job, because it does not know the engine directory the Foreman used. The door should then be
told the engine directory (the same `TL_ENGINE_DIR`), and `job_model.gd read_job()` should resolve `packs/<id>`
against it.
