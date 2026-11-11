# N4: patches for files outside the builder's scope

Each entry is a change the N4 work needs in a file the brief did not give to this builder. Nothing below was
applied; the Director decides. None of them is needed for the acceptance checks to pass.

## 1. `contracts/pack.schema.json`: the five optional manifest fields

Reason: `kernel/runner/manifest.gd` is the hand-written mirror of this schema and now accepts `footprint`, `params`,
`on_leave`, `subject` and `moments`. The schema has `"additionalProperties": false`, so until it is patched a tool
that validates against the JSON schema refuses a manifest the runner accepts. (There is no second copy of the schema
inside the engine: `manifest.gd` is the copy.)

Add these five properties after `"cameras"` (the `required` list does not change):

```json
    "cameras": { "type": "array", "items": { "type": "string", "pattern": "^[a-z][a-z0-9_]*$" } },
    "footprint": {
      "type": "object",
      "additionalProperties": false,
      "required": ["size_m", "height_m"],
      "properties": {
        "size_m": { "type": "array", "minItems": 2, "maxItems": 2, "items": { "type": "number", "exclusiveMinimum": 0 } },
        "height_m": { "type": "number", "exclusiveMinimum": 0 }
      }
    },
    "params": {
      "type": "array",
      "maxItems": 64,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["name", "file", "path", "min", "max", "step", "label"],
        "properties": {
          "name": { "type": "string", "pattern": "^[a-z][a-z0-9_]*$" },
          "file": { "type": "string", "pattern": "^data/[A-Za-z0-9_/]+\\.json$" },
          "path": { "type": "string", "pattern": "^[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)*$" },
          "min": { "type": "number" },
          "max": { "type": "number" },
          "step": { "type": "number", "exclusiveMinimum": 0 },
          "label": { "type": "string", "minLength": 1, "maxLength": 40 }
        }
      }
    },
    "on_leave": { "enum": ["bot", "pause", "end"] },
    "subject": { "type": "string", "pattern": "^[A-Za-z0-9_]+(/[A-Za-z0-9_]+)*$", "maxLength": 120 },
    "moments": {
      "type": "array",
      "maxItems": 32,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["name"],
        "properties": {
          "name": { "type": "string", "pattern": "^[a-z][a-z0-9_]*$" },
          "frame": { "type": "integer", "minimum": 0 },
          "event": { "type": "string", "pattern": "^[A-Za-z][A-Za-z0-9_.]*$" }
        },
        "oneOf": [ { "required": ["frame"] }, { "required": ["event"] } ]
      }
    }
```

What `manifest.gd` checks beyond what a JSON schema can say: `params[].name` and `moments[].name` are unique;
`params[].min` is below `max`; and lint (not the manifest reader) reports a `params[].file` that does not exist.

## 2. `contracts/PACK.md`: the fence list, the pack layout, the shapes

Reason: the contract's fence paragraph is the list a pack author reads; lint now refuses more than it names.

- In "Layout", after `examples/`: `preview/        optional pictures for the item card (thumb.jpg or thumb.png under 1 MB)`.
- In the amendment "README.md is allowed at the pack root": add `item.json` (the sharing card) as the third file
  allowed there.
- In "The fence", add a paragraph:
  "Since 2026-11-11 lint reads every `.gd` file of the pack wherever it sits (also `assets/`, `data/`, `preview/`,
  dot directories and the root), and refuses any file that is neither a script nor inert (`.json`, `.md`, `.txt`,
  `.png`, `.jpg`, `.jpeg`, `.webp`). Also fenced, as whole words unless a bracket or dot is shown: `call`, `callv`,
  `call_deferred`, `call_group`, `propagate_call`, `propagate_notification`, `Callable(`, `Callable.create`, `.set`,
  `set_deferred`, `set_indexed`, `set_script`, `.script =`, `.source_code`, `.reload`, `instance_from_id`,
  `dict_to_inst`, `ResourceLoader`, `ConfigFile`, `ZIPReader`, `ZIPPacker`, `PCKPacker`, `XMLParser`,
  `load_from_file`, `.save_png`/`save_jpg`/`save_exr`/`save_webp`, `.save_to_wav`, `PackedScene`, `Marshalls`,
  `Multiplayer*`, `ENet*`, `WebRTC*`, `WebSocket*`, `UPNP*`, `DTLSServer`, `SceneMultiplayer`, `multiplayer.`,
  `rpc(`, `@rpc`, `Crypto*`, `HashingContext`, `AESContext`, `HMACContext`, `X509Certificate`, `TLSOptions`,
  `DisplayServer`, `RenderingServer`, `RenderingDevice`, `PhysicsServer2D`/`3D`, `AudioServer`, `Performance`,
  `Input`, `InputMap`, `Engine` (any use), `Time.get_datetime*`/`get_date*`/`get_time*`, `IP`, `CameraServer`,
  `CameraFeed`, `AudioStreamMicrophone`, `AudioEffectCapture`, `AudioEffectRecord`, `GDExtension*`, `GLTF*`,
  `FBX*`, `load_dynamic_font`, `load_bitmap_font`, `Java*`, `JNISingleton`, `EngineDebugger`, `FileDialog`,
  `LinkButton`, `get_tree` (any use), `get_root`, `get_parent`, `find_parent`, `get_window`, `get_viewport`; a node
  path in `get_node(`, `get_node_or_null(`, `has_node(`, `NodePath(` or after `$` that is absolute, holds `..`, is
  not a literal or is built from pieces; `load(` of a relative path or of a path built from pieces. `OS`,
  `ProjectSettings` and `ClassDB` are now fenced as bare words (not only with their dot), and `Time`, `GDScript`
  and `load` are fenced when used as a value. A `\` line break counts as white space."
- In the optional-fields table, the shapes as built: `footprint` both numbers above 0; `params` all seven keys
  required, `min` below `max`, `step` above 0, names unique, at most 64; `subject` a node name or a `/`-separated
  path of names, no `..`; `moments` exactly one of `frame` (whole number, 0 or above) and `event`, names unique, at
  most 32.

## 3. `engine/kernel/API.md`: sections 16 and 17

Reason: API.md is where a pack author learns what lint refuses, and it still says `play` is not checked.

- Section 16, the line "fence, beyond the contract's list": append the N4 list of patch 2 and the sentence
  "`tl.sh play` runs lint first and refuses a pack that fails it."
- Section 17, "No real sandbox": add "See `kernel/share/SHARE.md` for what stays reachable; a scripted item from
  another player must not be installed until an isolation boundary exists."
- Section 18, "Environment": add `TL_ITEM_SELFTEST_DIR` (used by `tools/item.sh selftest`).

## 4. `engine/kernel/runner/worker.gd`: lint inside the worker (not required tonight)

Reason: only `tools/tl.sh play` lints first. Anything that starts the worker directly (`-- worker --mode=play`, the
Foreman, a future in-game "play this item" button) skips the fence. The fence belongs where the pack is loaded.

Exact change in `start(options)`, directly after the line
`pack_dir = Manifest.resolve_dir(str(opts.get("pack", "")))`:

```gdscript
	if mode == "play" and not pack_dir.is_empty():
		var fence_errors: Array = (load("res://kernel/runner/lint.gd") as GDScript).run(pack_dir)["errors"]
		if not fence_errors.is_empty():
			print("[tl] play refused: lint did not pass (%d finding(s)); first: %s" % [fence_errors.size(), str(fence_errors[0])])
			get_tree().quit(1)
			return
```

Written against the file as it is in this copy (the variables `mode`, `opts`, `pack_dir` and the `Manifest` constant
exist there); not applied and not run. Whether lint should also gate `smoke`, `bot` and `capture` inside the worker
is a design question: today the Foreman runs `lint` as its own step before them.

## 5. `engine/tools/selftest.sh`: one line for each new bad pack (optional)

Reason: the kernel's own selftest does not know the N4 packs; they are covered by `item.sh selftest` (cases
`fence.*`). If the Director wants one gate instead of two, add after `bad.nondeterminism_lint`:

```bash
for p in assets filetype reflection classes tree; do
  check "bad.reach_$p" 1 lint "--pack=$EX/bad_reach_$p" -- '"id":"lint.fence","ok":false'
done
```

## 6. A job pack that no longer passes lint (a finding, no patch written)

`site/marble-run-three-marbles-20261110-1/pack` (the first marble job, never promoted) trips two new rules:
`set_script` at `gen/look.gd:8` and `gen/sound.gd:8`, and `.set(` at `gen/look.gd:9`, `gen/sound.gd:9` and
`gen/sound.gd:12`. The same thing without reflection is `var node = ctx.load_script("scripts/sound_fx.gd").new()`
followed by `node.ctx = ctx` and `node.cfg = cfg`. The Foreman's builder prompt should say so, or the next job will
write the same lines and fail V1.
