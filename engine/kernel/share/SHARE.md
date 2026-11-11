# Sharing in the engine: the card, the tier, the package, and what the fence is

Built by N4 on 2026-11-11 from `docs/SHARING.md` sections 1 to 3. This file says what was built and where the spec
had to be read one way or another. Tool: `tools/item.sh`. Code: `kernel/share/item.gd` (card, tier, hash, limits,
check), `kernel/share/tlzip.gd` (the archive), `kernel/share/item_tool.gd` (entry). Nothing in `kernel/share/` loads
or runs a file of an item: files are bytes.

## 1. The fence is a guardrail, not a security boundary

**Lint is a text check. It stops mistakes and lazy shortcuts. It does not stop a person who wants to get out.**
A pack that passes lint still runs inside the game's own process with everything the player's account can do.
Nothing built here changes the owner's ruling: a scripted item (`tier: code`) travels only in its owner's own save
until packs run isolated. `item.sh unpack` and `item.sh check` do not make a code item safe; they only make sure the
card tells the truth about it.

What N4 closed is in section 6. What stays reachable after N4, each line checked by linting a probe pack that holds
it (exit 0), unless marked "not probed":

- **Reading by name**: `obj.get("name")`, `has_method`, `get_meta`, `emit_signal("name")`, `connect("name", ...)`,
  `Signal(obj, "name")`. A pack can read any property of any object it holds and emit a kernel object's signals.
- **Calling without a call site**: a method taken as a value (`node.get_child`) and handed to `map`, `filter`,
  `sort_custom`, a signal or `bind`. Fenced names are matched as words, so this reaches no fenced name, but it does
  reach every method that is not fenced. The contract's random functions (`randf(`, `.shuffle(` and the others) are
  still matched only with their bracket; `invariants` catches the result at run time, lint does not.
- **Everything the kernel hands over**: `ctx` and every object reachable from it by property. `ctx.pack_dir` is the
  pack's place on the disk, a machine path with the user's name in it; a pack can show it or fold it into its state.
  `get_script()` and `get_stack()` give script paths the same way.
- **The tree beside the pack**: `ctx.root.add_sibling(...)`, `reparent(...)`, `queue_free()` on a kernel node,
  `get_path()` (the absolute path as text), `.owner`, `find_child(...)`. The fenced roads up are `get_tree`,
  `get_parent`, `find_parent`, `get_root`, `get_window`, `get_viewport` and absolute or `..` node paths; a pack can
  still damage what it is given.
- **Windows and sub-viewports**: `Window.new()`, `SubViewport.new()` and other nodes that draw outside the game's
  picture.
- **Code for the graphics card**: `Shader.new()` with `code` set from a string. It cannot read files; it can stall
  or crash a driver.
- **Exhaustion**: `PackedByteArray.resize(1 << 30)`, node floods, log floods, an endless loop. Only the endless loop
  has a guard (the worker's watchdog), and only in runs the runner started.
- **Whatever the fence does not name.** It is a deny list over an engine with several hundred classes. N4 named
  the ones a scout found and the ones seen while closing them. A class nobody thought of is open. Not probed: every
  engine class was not walked.
- **Whatever text cannot show**: a node path or a script path kept in a variable is refused where lint sees it
  used (`get_node(x)`, `load(x)`), but `ctx.load_script(x)` takes any `.gd` of the pack by a computed name. All of
  them are read by lint now, so this reaches only checked scripts.
- **`play` outside `tl.sh`**: only `tools/tl.sh play` lints first. Starting the worker directly skips lint
  (PATCHES.md, patch 4).
- **Data read by the game**: a `data` item is inert to the engine, not to the game. A layout or a tuning file is
  still hostile input to the code that reads it; that code must check it against its schema.

## 2. The card: `item.json`, schema `tl.item/1`

As `docs/SHARING.md` section 2: all 21 top-level keys always present, in the spec's order, two-space indent.

Readings and choices where the spec was silent:

| Field | Built as |
|---|---|
| `uid` | 26 characters from `0123456789ABCDEFGHJKMNPQRSTVWXYZ`, each from the engine's cryptographic random source (130 bits, no time in it). Made when a folder first gets a card; `item.sh card` on a folder that has a valid card keeps `uid` and `created`. |
| `kind` | `game` when the folder holds `pack.json`; otherwise told from a JSON file's `schema` (`tl.layout/` venue, `tl.world/` world, `tl.style/` look, `tl.tuning/` tuning) or given with `--kind=`. Never guessed further. |
| `tier` | computed (section 3), never read from the command line |
| `title`, `version`, `engine.kernelApi`, `capabilities`, `requires`, `footprint` | copied from `pack.json`; `capabilities` sorted, duplicates dropped |
| `engine.kit`, `engine.style` | `""`: the kit and the style carry no version number today |
| `footprint` when unknown | `{"size_m": [], "height_m": 0}` |
| `author.handle` | `player` unless `--handle=`; lower case letters, digits, `_`, `-` |
| `licence` | `all-rights-reserved` unless `--licence=` (SHARING.md open question 1) |
| `provenance` | from a job's `job.jsonl` only (`--job=<job dir>`): `job` and `sentence` from the `job_created` line, `models` from the `builder_run` lines (as logged, sorted), `built_by` `foreman`. Without `--job` all of it is empty. |
| `provenance.human_code` | `null` when nobody said (`--human-code=true|false`). The spec's example shows `false`; a job's log cannot prove that no person edited a file, so the tool does not claim it. |
| `verify` | from `tl.verify/1` reports given with `--lint=`, `--bot=`, `--smoke=`, `--invariants=`. A verb with no report is `null`, not `false`. `bypasses` and `script_lines` come from the lint report (`null` without one). `bot_state_hash` is the bot report's full 64-character `state_hash` (the spec's example shows 8). A report about another pack id or version is refused. When the contents change, old `verify` evidence is dropped. |
| `content` | `files` and `bytes` count every file except `item.json` (and the sidecars of section 4) |
| `preview` | `thumb` is `preview/thumb.png|jpg|jpeg|webp` when present; `shots` the other pictures under `preview/`, at most 8 |

`content.hash` is `"sha256:"` + SHA-256 of the UTF-8 text made of one line per file, sorted by path (byte order):
`<path>\t<bytes>\t<sha256 of the file, hex>\n`. Paths use `/`. `item.json` is not in it.

The validator (`item.sh check`) refuses: a missing or unknown key, `signature` (reserved), a wrong shape in any
field, unsorted or unknown capabilities, and, in any string of the card, an e-mail address, a machine path (drive
letter, network share, `/home/`, `/Users/`, `\Users\`), or a `file://`, `res://` or `user://` address. A job
sentence that holds one of these is left empty with a note.

`check` then compares the card with the contents and reports each difference as one `MISMATCH` line: `tier`, `kind`
(a venue, look, tuning or world must be `data`; a game or kit `code`), `content.hash`, `content.files`,
`content.bytes`, the preview files, and against `pack.json`: `capabilities`, `version`, `engine.kernelApi`.

## 3. The tier rule

An item is **`data`** when every file in it, other than `item.json`, is inert. A file is inert when all of this
holds:

1. its name ends in `.json`, `.md`, `.txt`, `.png`, `.jpg`, `.jpeg` or `.webp` (case does not matter) and does not
   start with a dot;
2. it is not `pack.json` at the root (a pack manifest names an entry script: a pack is code by definition);
3. its bytes are what its name says: `.json` is UTF-8 text that parses as JSON; `.md` and `.txt` hold no NUL byte;
   `.png` starts with the PNG signature, `.jpg`/`.jpeg` with `FF D8 FF`, `.webp` with `RIFF....WEBP`.

Anything else makes the item **`code`**: GDScript (`.gd`), shaders (`.gdshader`, `.gdshaderinc`), scenes (`.tscn`,
`.scn`), resources (`.tres`, `.res`; both can carry a script), libraries and extensions (`.gdextension`, `.dll`,
`.so`, `.dylib`), archives (`.zip`, `.pck`, `.tlitem`), `.svg`, `.cfg`, a file with no extension, a dot file, and
every type not on the inert list. The list is an allow list on purpose: a type nobody thought of counts as code.

The table lives in one place, `kernel/runner/lint.gd` (`INERT_EXT`, `file_class`), and lint uses the same table to
refuse non-script, non-inert files inside a pack.

The tier is computed by `card`, `pack`, `check` and `unpack` from the bytes, each time. A card whose `tier` differs
is refused with the first reason (`MISMATCH tier: the card says 'data', the contents are 'code' (hook.gd: a GDScript
file)`), and nothing is packed or unpacked.

## 4. The package: `.tlitem`

A zip that mirrors the item's folder: `item.json` at the root, every other file at its own path. (SHARING.md says
"the item's folder beside it"; this was read as "the files of the folder", not a second folder level.)

**Godot's `ZIPPacker` cannot make it.** It stamps each entry with the wall clock and has no way to set the time:
the same content packed three seconds apart gave two different files (JOURNAL.md, 00:09). `ZIPReader` is not used
to unpack either: it gives no sizes before it inflates. `tlzip.gd` writes and reads the archive itself, with the
engine's own zlib doing the work: `PackedByteArray.compress(COMPRESSION_GZIP)` returns the raw deflate stream and the
CRC-32 a zip entry needs. The result is a standard zip; the selftest opens it with `ZIPReader` and compares bytes.

Canonical form, which is also the only form `unpack` and `check` accept: entries sorted by path, each once; method
stored or deflate (deflate only when smaller); flags 0; time 00:00:00, date 1980-01-01; no extra fields, comments,
data descriptors, encryption, zip64 or second disk; entries back to back from offset 0, then the central directory,
then the end record, then nothing.

Reading treats the archive as hostile. Before anything is inflated: archive size, entry count, every path, every
declared size and the sum of them, the layout of the file. A path is refused when it is absolute, holds `\`, `:`,
`.` or `..` as a segment, an empty segment, a character outside `A-Z a-z 0-9 _ - .`, a trailing dot, a Windows
device name (`con`, `nul`, `com1`, ...), more than 8 levels or 180 characters, or when two paths differ only in
case. Each entry is inflated into a buffer of exactly its declared size and checked against its CRC. `unpack`
writes nothing unless the whole archive and the whole `check` pass, and never into a folder that is not empty.

Limits, at pack time and again at unpack: an archive under 8,000,000 bytes; at most 512 files; a script at most
600 lines and all scripts together at most 6,000 (the pack limits, read from `lint.gd`); everything that is neither
a script nor under `preview/` at most 2 MiB together (the pack's `data/` limit, widened to the whole item); each
picture under `preview/` under 1,000,000 bytes.

Not part of an item, so never hashed, counted or packed, and refused inside an archive: `*.uid` and `*.import`
(the engine writes them beside files it has seen; with them the hash would depend on whether an editor had opened
the folder), `.gitkeep`, `.gdignore`.

Library layout: `item.sh pack <dir> --library=<dir>` writes `<library>/<uid>-<version>.tlitem`. The same bytes
again change nothing; other bytes under the same name are refused ("raise the version").

`item.sh pack` on a folder without a card makes the card first and says so. That writes `item.json` into the
folder, once; the second packing reuses it, which is why the two archives are the same.

## 5. Optional manifest fields

`kernel/runner/manifest.gd` accepts and shape-checks `footprint`, `params`, `on_leave`, `subject`, `moments`
(contracts/PACK.md, amendments of 2026-11-11). A pack without them reads as before. `kernelApi` is compared on
major and minor. Lint reports a `params[].file` that is not in the pack. Shapes: PATCHES.md, patch 1.

## 6. What N4 closed in the fence

Each row: the hole, the rule, the bad pack under `kernel/examples/` that passed lint before and fails now.

| Hole | Rule now | Bad pack |
|---|---|---|
| `assets/` (and `data/`, `preview/`, dot directories, the root) never read; `ctx.load_script("assets/x.gd")` loads from there | every `.gd` of the pack is read, hidden files included | `bad_reach_assets` |
| a scene, resource, shader or library in the pack can carry code lint cannot read | a file that is neither `.gd` nor inert is a fence error | `bad_reach_filetype` |
| reflection | `call`, `callv`, `call_deferred`, `call_group`, `propagate_call`, `Callable(`, `.set`, `set_deferred`, `set_indexed`, `set_script`, `.script =`, `.source_code`, `.reload`, `instance_from_id`, `dict_to_inst` | `bad_reach_reflection` |
| engine classes not named | `ResourceLoader`, `ConfigFile`, `ZIPReader`, `ZIPPacker`, `PCKPacker`, `XMLParser`, `load_from_file`, `save_png` and its kin, `save_to_wav`, `PackedScene`, `Marshalls`, `Multiplayer*`, `ENet*`, `WebRTC*`, `WebSocket*`, `UPNP*`, `DTLSServer`, `multiplayer.`, `rpc(`, `Crypto*`, `HashingContext`, `AESContext`, `HMACContext`, `X509Certificate`, `TLSOptions`, `DisplayServer`, `RenderingServer`, `RenderingDevice`, `PhysicsServer2D/3D`, `AudioServer`, `Performance`, `Input`, `InputMap`, `Engine` (any use but the already fenced `get_singleton`), `Time.get_datetime*`/`get_date*`/`get_time*`, `IP`, `CameraServer`, `CameraFeed`, `AudioStreamMicrophone`, `AudioEffectCapture`/`Record`, `GDExtension*`, `GLTF*`, `FBX*`, `load_dynamic_font`, `Java*`, `JNISingleton`, `EngineDebugger`, `FileDialog`, `LinkButton` | `bad_reach_classes` |
| the tree above the pack | `get_tree` (any use), `get_root`, `get_parent`, `find_parent`, `get_window`, `get_viewport`; in `get_node(`, `get_node_or_null(`, `has_node(`, `NodePath(` and after `$`: a path that is absolute, holds `..`, is not a literal, or is built from pieces | `bad_reach_tree` |
| a fenced name kept in a variable (`var o = OS`), a method taken without brackets (`get_tree`) | `OS`, `ProjectSettings`, `ClassDB`, `Engine`, `Input` match as bare words; `Time`, `GDScript`, `load` used as a value | `bad_reach_alias` |
| `load("kernel/runner/worker.gd")` (a relative path is read from the engine's root), `load("res://kits/" + "../...")` (only the first piece was judged), a call broken over two lines with `\` | relative `load(` refused; the literal must be the whole argument; a line break with `\` is white space to every pattern | `bad_reach_load` |
| `play` never lints | `tools/tl.sh play` lints first and refuses with the findings | selftest case `fence.play_lints_first` |

Scout's claims checked: all true except one detail. `load("assets/x.gd")` as written does not reach the pack's
`assets/` (the engine reads a relative `load` from its own root); the working road was `ctx.load_script("assets/x.gd")`.
The relative `load` was a hole of its own: it reached the kernel's scripts.

Collateral, known: a lambda kept in a variable can no longer be run with `.call()`; `Dictionary.set(k, v)` and
`Array.set(i, v)` are refused with the reflection rule (write `d[k] = v`); a node path must be a literal;
`get_viewport()` and `get_tree().create_timer()` are refused. No seed, kernel example or promoted pack used any of
them. One unpromoted job pack did: PATCHES.md, entry 6.
