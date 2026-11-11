# N4 item card, package and fence: builder report and Director verification

Brief `briefs/BRIEF-N4-ITEM.md`. Builder wall time 00:04 to 00:48 CEST on 2026-11-11 (44 min; harness: 298,064 subagent tokens, 88 tool uses). Work done in the engine copy `site/_work/n4/engine/`.

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

STATUS: N4 is complete, all six work items are built and every acceptance check passes in my engine copy. One real job pack (the unpromoted first marble job) now fails lint on two new rules; that is reported as a finding below.

Start 00:03:47, last gate ended 00:47:24, report at 00:47:37 (local `date`): 44 minutes of the 80.

All work is in C:\Users\kazda\kiro\third-life\site\_work\n4\engine\. Nothing outside the scope was changed; `seeds/` in the copy holds no `item.json`; no process of mine is left running.

Files changed or added (all under that engine copy):
- kernel\runner\lint.gd (changed)
- kernel\runner\manifest.gd (changed)
- tools\tl.sh (changed)
- tools\item.sh (new)
- kernel\share\item.gd, tlzip.gd, item_tool.gd, item_tool.tscn (new)
- kernel\share\SHARE.md, PATCHES.md, JOURNAL.md (new)
- kernel\examples\bad_reach_assets, bad_reach_filetype, bad_reach_reflection, bad_reach_classes, bad_reach_tree, bad_reach_alias, bad_reach_load (new)

No `bad_item_*` folder was made: hostile items are forged into a temporary folder by the selftest, so no deliberately wrong card sits in the tree.

---

GATES (final runs, all after the last code edit at 00:36:50)

- `bash tools/item.sh selftest`: 91 passed, 0 failed (00:45:23 to 00:47:24).
- `bash tools/tl.sh selftest`: 63 passed, 0 failed (00:41:59 to 00:45:23).
- `bash tools/tl.sh seeds`: 24 passed, 0 failed (00:38:16 to 00:41:46).

One earlier `tl.sh selftest` run failed one case (`bad.fence_each_line`, line 28 reported twice): my new `Java*` rule also matched the contract's `JavaScriptBridge` line. Fixed with a lookahead and re-run from the start.

---

ITEM BY ITEM

**1. The card (`item.json`, `tl.item/1`)**

Built in `kernel/share/item.gd`, command `item.sh card <dir>`.
- All 21 top-level keys are always present, in the spec's order.
- `uid` is 26 characters from the engine's cryptographic random source. A second `card` run keeps `uid` and `created`.
- `capabilities` are the sorted copy of `pack.json`. `title`, `version`, `engine.kernelApi`, `requires` and `footprint` also come from `pack.json`.
- `--lint=` and `--bot=` (also `--smoke=`, `--invariants=`) fill `verify`; `--job=<job dir>` fills `provenance` from `job.jsonl`.
- Unknown values stay `""`, `[]` or `null`.
- The validator gives readable errors for missing or unknown keys, wrong shapes, `signature` (reserved), unsorted capabilities, and any e-mail address or machine path in any string.

Proof (selftest cases `card.*` and `validate.*`, all PASS):
- The card built from the second marble job has the sentence, the job name, `built_by: foreman`, `models: ["claude-sonnet-5-5"]`, lint and bot true, smoke null, the bot hash `cc031fae...` (64 characters), bypasses and script lines.
- A report about another pack is refused.
- A job log whose sentence holds a machine path gives an empty sentence and a note.

**2. The tier is computed**

Computed from bytes by `card`, `pack`, `check`, `unpack` and `tier`, never read from the command line.

Proof:
- A folder with only a layout file: `tier: data files=1`.
- seed_paddle: `tier: code`.
- seed_paddle's card edited to `data`: `MISMATCH tier: the card says 'data', the contents are 'code' (pack.json: a pack manifest: a pack names an entry script, and 2 more)`, exit 1, and `pack` refuses it.
- A venue with a `.gd`, a `.tscn`, a `.gdshader`, or a script named `picture.png` each computes to code.

**3. The package (`.tlitem`)**

The premise was wrong: Godot's `ZIPPacker` cannot make a reproducible archive. It stamps every entry with the wall clock and has no way to set the time. Measured: the same content packed three seconds apart gave two different sha256, differing in the DOS time fields.

I wrote a small canonical zip writer and a strict reader (`kernel/share/tlzip.gd`). The engine's own zlib does the work: `PackedByteArray.compress(COMPRESSION_GZIP)` yields the raw deflate stream and the CRC-32. `ZIPReader` is not used for unpacking either, because it gives no entry sizes before inflating; it is used in the selftest to prove the archive is a standard zip.

Proof by hand, on a copy of seed_paddle, three seconds apart:
- sha256 `8690fe73c56af607add301eb8222d7a55f481e12405c498f011cd8a7479956a8` both times, 9032 bytes, `cmp` identical.
- `unpack` exit 0 (8 files), `check` exit 0, `tl.sh lint` on the unpacked pack exit 0.
- `content.hash` of folder and archive: `sha256:f373130b5aa11652326beff64d45b729689ea5fcef110ba89490e55a2f78898b`.

Hostile archives, each refused with exit 1 and nothing written: `..` entry, absolute path, drive letter, backslash, duplicate path, unsorted entries, engine sidecar, trailing data, foreign timestamp, declared size of 1 GiB, truncated file, archive over 8 MB.

Limits tested: thumbnail over 1 MB and a script over 600 lines are refused. The 6,000-line, 2 MiB and 512-file limits are coded and not tested.

**4. The tool**

`tools/item.sh` has `card`, `pack --out=`, `pack --library=`, `unpack --to=`, `check`, `tier`, `selftest`. Exit codes: 0 done, 1 refused, 2 could not run. It has its own entry scene (`kernel/share/item_tool.tscn`) and does not touch `host.gd`.

The library writes `<library>/<uid>-<version>.tlitem`. The same bytes again change nothing; other bytes under the same name are refused (selftest `library.*`).

`pack` on a folder with no card makes the card first and says so. That writes `item.json` into the folder once, which is why the second packing is identical. Running the acceptance command directly on `seeds/seed_paddle` will therefore add `item.json` there; I ran it on copies.

**5. The fence**

See the rules table below. `tl.sh play` now lints first and refuses with the findings (selftest `fence.play_lints_first`: exit 1, no worker started). With a stub in place of Godot, the launch line after a passing lint is unchanged.

`SHARE.md` section 1 says plainly that this is a guardrail and not a security boundary, and lists what stays reachable.

**6. Optional manifest fields**

`manifest.gd` accepts and shape-checks `footprint`, `params`, `on_leave`, `subject`, `moments`. `kernelApi` is compared on major and minor. Lint also reports a `params[].file` that is not in the pack.

Proof: 11 selftest cases `manifest.*`. All five fields together pass; each wrong shape fails with its message; an unknown key is still an error; and `tl.sh selftest` and `tl.sh seeds` pass unchanged.

There is no separate schema copy inside the engine: `manifest.gd` is the copy. The `contracts/` change is PATCHES.md entry 1.

---

THE TIER RULE (as written in SHARE.md section 3)

An item is `data` when every file in it, other than `item.json`, is inert. A file is inert when all of this holds:
1. Its name ends in `.json`, `.md`, `.txt`, `.png`, `.jpg`, `.jpeg` or `.webp` (case does not matter) and does not start with a dot.
2. It is not `pack.json` at the root (a pack manifest names an entry script: a pack is code by definition).
3. Its bytes are what its name says: `.json` is UTF-8 text that parses as JSON; `.md` and `.txt` hold no NUL byte; `.png` starts with the PNG signature, `.jpg`/`.jpeg` with FF D8 FF, `.webp` with RIFF....WEBP.

Anything else makes the item `code`: GDScript, shaders, scenes (`.tscn`, `.scn`), resources (`.tres`, `.res`), libraries and extensions, archives, `.svg`, `.cfg`, a file with no extension, a dot file, and every type not on the inert list. It is an allow list on purpose: a type nobody thought of counts as code.

The table lives in one place (`lint.gd`: `INERT_EXT`, `file_class`), and lint uses the same table. A card whose tier differs is refused. A kind must also match its tier: venue, look, tuning and world must be data; game and kit must be code.

Not part of an item (never hashed, counted or packed, and refused inside an archive): `*.uid`, `*.import`, `.gitkeep`, `.gdignore`.

---

FENCE RULES ADDED

Each bad pack exits 0 on the main tree's engine and 1 on mine. "Main tree's engine" here is a snapshot of its `kernel`, `kits`, `rigs`, `style` and `tools` copied to a scratch folder at 00:21, so the main tree itself was not run.

Trips: none of the three seeds (my copy's, and the main tree's as changed by another builder since), the second job's promoted pack, pack_min or the seven ex_* packs trips any rule. Only job 1's pack trips, on the reflection rules.

| Hole | Rule now | Bad pack | Tripped by a real pack |
|---|---|---|---|
| Scripts outside `scripts/`, `gen/`, `tests/`, `examples/` were never read | Every `.gd` of the pack is read, hidden files included | bad_reach_assets | none |
| A scene, resource, shader or library can carry code lint cannot read | A file that is neither `.gd` nor inert is a fence error | bad_reach_filetype | none |
| Reflection | `call`, `callv`, `call_deferred`, `call_group`, `propagate_call`, `propagate_notification`, `Callable(`, `Callable.create`, `.set`, `set_deferred`, `set_indexed`, `set_script`, `.script =`, `.source_code`, `.reload`, `instance_from_id`, `dict_to_inst` | bad_reach_reflection (12 lines, each reported once) | job 1's pack: `set_script` at gen/look.gd:8 and gen/sound.gd:8; `.set(` at gen/look.gd:9, gen/sound.gd:9 and 12 |
| Engine classes not named | See the list below | bad_reach_classes (41 lines, each once) | none (job 1 uses `Image.create`, which stays allowed) |
| The tree above the pack | `get_tree` (any use), `get_root`, `get_parent`, `find_parent`, `get_window`, `get_viewport`; a node path in `get_node(`, `get_node_or_null(`, `has_node(`, `NodePath(` or after `$` that is absolute, holds `..`, is not a literal, or is built from pieces | bad_reach_tree (12 lines) | none (ex_kit's relative literals pass) |
| A fenced name kept in a variable, or a method taken without brackets | `OS`, `ProjectSettings`, `ClassDB`, `Engine`, `Input` match as bare words; `Time`, `GDScript`, `load` used as a value | bad_reach_alias (12 lines) | none |
| `load(` paths | Relative `load(` refused; the literal must be the whole argument; a `\` line break is white space to every pattern | bad_reach_load (3 findings) | none |
| `play` never lints | `tl.sh play` lints first | selftest `fence.play_lints_first` | n/a |

Class rules: `ResourceLoader`, `ConfigFile`, `ZIPReader`, `ZIPPacker`, `PCKPacker`, `XMLParser`, `load_from_file`, `save_png`/`jpg`/`exr`/`webp`, `save_to_wav`, `PackedScene`, `Marshalls`, `Multiplayer*`, `ENet*`, `WebRTC*`, `WebSocket*`, `UPNP*`, `DTLSServer`, `SceneMultiplayer`, `multiplayer.`, `rpc(`, `@rpc`, `Crypto*`, `HashingContext`, `AESContext`, `HMACContext`, `X509Certificate`, `TLSOptions`, `DisplayServer`, `RenderingServer`, `RenderingDevice`, `PhysicsServer2D/3D`, `AudioServer`, `Performance`, `Input`, `InputMap`, `Engine` (any use), `Time.get_datetime*`/`get_date*`/`get_time*`, `IP`, `CameraServer`, `CameraFeed`, `AudioStreamMicrophone`, `AudioEffectCapture`/`Record`, `GDExtension*`, `GLTF*`, `FBX*`, `load_dynamic_font`/`load_bitmap_font`, `Java*`, `JNISingleton`, `EngineDebugger`, `FileDialog`, `LinkButton`.

Scout's claims checked: all true, with one correction and three additions.
- Correction: `load("assets/x.gd")` as written does not reach the pack's `assets/`, because the engine reads a relative `load` from its own root. The working road was `ctx.load_script("assets/x.gd")`.
- Addition: that relative `load` was a hole of its own. `load("kernel/runner/worker.gd")` passed lint.
- Addition: the contract's own rules `OS.`, `ProjectSettings.` and `ClassDB.` needed the dot, so `var o = OS` passed lint.
- Addition: `load("res://kits/" + "../kernel/host/host.gd")` passed, because only the first literal was judged.

Known collateral (no seed, example or promoted pack uses any of these):
- A lambda kept in a variable can no longer be run with `.call()`.
- `Dictionary.set` and `Array.set` are refused.
- A node path must be one plain literal.
- `get_viewport()` and `get_tree().create_timer()` are refused.
- Direct `Input.` is refused.

---

WHAT STAYS REACHABLE

A probe pack holding these constructs passes lint with exit 0. Full text is in SHARE.md section 1.

- **Reading by name:** `obj.get("name")`, `has_method`, `get_meta`, `emit_signal("name")`, `connect("name", ...)`, `Signal(obj, "name")`.
- **Calling without a call site:** a method value handed to `map`, `filter`, `sort_custom`, a signal or `bind`. This reaches every method that is not fenced by word. The contract's random functions are still matched only with their bracket; `invariants` catches that at run time.
- **Everything the kernel hands over:** `ctx` and what hangs off it. `ctx.pack_dir`, `get_script()` and `get_stack()` give machine paths to pack code.
- **The tree beside the pack:** `add_sibling`, `reparent`, `queue_free` on a kernel node, `get_path()`, `.owner`, `find_child`.
- **Windows and viewports:** `Window.new()`, `SubViewport.new()`.
- **Shader code:** `Shader.new()` with `code` set from a string.
- **Exhaustion:** a 1 GiB resize, node floods, log floods. Only the endless loop has a guard, and only in runs the runner started.
- **Any engine class nobody named.** It is a deny list, and I did not walk every class.
- **Computed script names:** `ctx.load_script(x)` takes a computed name, but every `.gd` of the pack is now read.
- **`play` outside `tl.sh`:** starting the worker directly skips lint (PATCHES entry 4).
- **Data read by the game:** a `data` item is inert to the engine, not to the game code that reads it.

---

CONTENTS OF PATCHES.md

Nothing below was applied; none is needed for the acceptance checks.

**1. `contracts/pack.schema.json`: the five optional fields.** The schema has `additionalProperties: false`, so a JSON-schema validator refuses what the runner now accepts. Add after `"cameras"` (the `required` list does not change):

```json
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

Beyond what a schema can say, `manifest.gd` checks that `params[].name` and `moments[].name` are unique and that `min` is below `max`; lint reports a `params[].file` that does not exist.

**2. `contracts/PACK.md`.**
- Add `preview/` to the layout.
- Add `item.json` as the third file allowed at the pack root.
- Add a fence paragraph: lint reads every `.gd` wherever it sits and refuses any file that is neither a script nor inert, followed by the full list of newly fenced names as in the table above. `OS`, `ProjectSettings` and `ClassDB` are now bare words; `Time`, `GDScript` and `load` are fenced as values; a `\` line break counts as white space.
- State the shapes of the five optional fields as built.

**3. `engine/kernel/API.md`.**
- Section 16: append the N4 list and "`tl.sh play` runs lint first and refuses a pack that fails it."
- Section 17: point to `kernel/share/SHARE.md` and say a scripted item from another player must not be installed until an isolation boundary exists.
- Section 18: add `TL_ITEM_SELFTEST_DIR`.

**4. `engine/kernel/runner/worker.gd`: lint inside the worker (not required tonight).** Only `tl.sh play` lints first; anything that starts the worker directly skips the fence. In `start(options)`, directly after `pack_dir = Manifest.resolve_dir(str(opts.get("pack", "")))`:

```gdscript
	if mode == "play" and not pack_dir.is_empty():
		var fence_errors: Array = (load("res://kernel/runner/lint.gd") as GDScript).run(pack_dir)["errors"]
		if not fence_errors.is_empty():
			print("[tl] play refused: lint did not pass (%d finding(s)); first: %s" % [fence_errors.size(), str(fence_errors[0])])
			get_tree().quit(1)
			return
```

Written against the file as it is in my copy; not applied and not run.

**5. `engine/tools/selftest.sh` (optional).** One gate instead of two; add after `bad.nondeterminism_lint`. The file as written lists five packs; extend the loop with `alias load` to cover all seven.

```bash
for p in assets filetype reflection classes tree; do
  check "bad.reach_$p" 1 lint "--pack=$EX/bad_reach_$p" -- '"id":"lint.fence","ok":false'
done
```

**6. A job pack that no longer passes lint (a finding, no patch).** `site/marble-run-three-marbles-20261110-1/pack` trips `set_script` and `.set(` at the five places named in the table. The same thing without reflection is `var node = ctx.load_script("scripts/sound_fx.gd").new()`, then `node.ctx = ctx` and `node.cfg = cfg`. The Foreman's builder prompt should say so, or the next job will write the same lines and fail V1.

---

WHAT I DID NOT VERIFY

- `tl.sh play` of a good pack with a real window (headless runs only); the launch line was checked with a stub.
- The worker patch (entry 4) and the `selftest.sh` patch (entry 5): written, not run.
- The bad packs against the live main tree engine: a snapshot was used.
- The other builder's copy (`site/_work/n2`): not linted.
- Archive bytes across engine versions or machines: the deflate stream comes from the engine's zlib. `content.hash` does not depend on it.
- A link or junction inside an item folder at pack time. Archives cannot carry links.
- File names outside ASCII: refused, not supported.
- The 6,000-line, 2 MiB and 512-file limits: coded, not tested.
- `--smoke=` and `--invariants=`, a normal `preview/thumb` picture, a `kit` item, `provenance.parent`: coded or allowed by the validator, not exercised by a case.
- That the fence names every dangerous engine class: it does not; the class list was not walked.
- `item.sh` outside Git Bash on Windows.

Incident: the session's scratch folder is shared with the other builders. One of my preview logs was overwritten by a file of the same name from another builder. I moved my files under `scratchpad/n4/` and changed nothing of theirs. The final gate logs are mine alone.

---

QUESTIONS

1. Unknown evidence is `null`: `provenance.human_code`, each `verify.verbs.*`, `verify.bypasses`, `verify.script_lines`. The spec names only `parent` as null, and its example shows `human_code: false`. A job log cannot prove no person edited a file. Keep null, or do you want false?
2. `verify.bot_state_hash` holds the full 64 characters; the spec's example shows 8. Which?
3. `pack` on a folder without a card writes `item.json` into it. Keep that, or should `pack` refuse and require `card` first?
4. The archive holds the item's files at its root beside `item.json`. SHARING.md's "the item's folder beside it" could also mean a sub-folder. Which was meant?
5. `*.uid`, `*.import`, `.gitkeep` and `.gdignore` are left out of the hash and the package (the spec says "every file except the card"). With them, the identity would depend on whether an editor had opened the folder. Accept?
6. The 2 MiB data limit is applied to everything in an item that is neither a script nor a preview picture, including `README.md` and `pack.json`. Accept?
7. The reflection rules fail job 1's pack and will fail common LLM habits (`Input.is_action_pressed`, `get_tree().create_timer`, `lambda.call()`, `dict.set`). The hints say what to write instead, but the Foreman's builder prompt needs the list. Who updates it?
8. Should lint also run inside the worker (entry 4), so that no path into `play` skips it?
9. `ctx.pack_dir` gives pack code a machine path. This is harmless while packs have no way out, but relevant on the day code items are shared. Not my file.

---

## Director verification

Done 00:50 to 01:20 CEST on 2026-11-11, after the builder had stopped: first in the builder's copy, then on the main tree
after merging its files.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash tools/item.sh selftest` in the copy | 91 passed, 0 failed |
| `bash tools/tl.sh selftest` in the copy | 63 passed, 0 failed |
| `bash tools/tl.sh seeds` in the copy | 23 of 24: `seed.wall.invariants` frame budget at p99 30 ms under load (three runs shared the machine); 24 of 24 after the merge |
| pack a copy of `seed_paddle` twice, three seconds apart | identical sha256 `20a760f7...` (the builder's own figure differs because each card gets a fresh `uid`) |
| unpack, `check`, lint of the unpacked pack | exit 0, 0, 0 |
| card edited to `tier: data` on the seed | refused: "the card says 'data', the contents are 'code'", exit 1 |
| the seven `bad_reach_*` packs: lint on the main tree's engine before the merge, and on the copy | exit 0 before, exit 1 after, all seven |
| the two job packs on the new fence | job 1's pack fails (reflection: `set_script`, `.set(`), job 2's promoted pack passes |
| after the merge, on the main tree: `tl.sh selftest`, `item.sh selftest`, `k.sh selftest`, `tl.sh seeds` | 63, 91, 86 and 24 passed, 0 failed |

**Read:** the archive reader in `engine/kernel/share/tlzip.gd`. It walks the central directory before inflating anything
and refuses on size, count, path, ordering, flags, timestamps, gaps and overlaps, then bounds each inflate by the
declared size and checks its CRC.

### What is not verified

The hostile-archive cases one by one (covered by the builder's selftest, which the Director ran but did not read case by
case); the 6,000-line, 2 MiB and 512-file limits; `tl.sh play` with a real window; that the deny list names every
dangerous engine class (it does not, as the builder says).

### Director's decisions on the builder's questions

1. Unknown evidence is `null`. `docs/SHARING.md` is to say so.
2. `verify.bot_state_hash` holds the full 64 characters.
3. `pack` on a folder without a card writes the card first: kept for the spike.
4. The archive holds the item's files at its root beside `item.json`: accepted.
5. Engine sidecar files are left out of hash and package: accepted.
6. The 2 MiB limit covers everything that is neither a script nor a preview picture: accepted.
7. The Director put the refused habits and what to write instead into `engine/kernel/API.md` (section 0 and
   section 16), which is what a Foreman builder reads.
8. Lint inside the worker for `play`: yes, applied with the N2 merge (the file is N2's).
9. `ctx.pack_dir` exposing a machine path is recorded for the isolation work.

Merged into the main tree by file: `kernel/runner/lint.gd`, `kernel/runner/manifest.gd`, `kernel/share/**`,
`tools/item.sh`, `tools/tl.sh`, `kernel/examples/bad_reach_*`. Patches 1 to 3 applied by the Director
(`contracts/pack.schema.json`, `contracts/PACK.md`, `engine/kernel/API.md`). The stricter fence will cost model builders
rounds until they learn it: the hockey job is the first measurement.
