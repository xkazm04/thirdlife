# P7: patches outside the package's files

P7 (the simulation contract: API v1, recorded input, a hash that covers everything) touched only its own files. What
it found in files of other owners is here as exact text. **None of these patches has been applied, and none has been
run** unless its entry says so.

## 1. `engine/kernel/world/pack.gd`: the world's hash of a pack follows the worker's

**Why.** `pack.gd` has its own copy of the state hash (`_q`, `_put_v3`, `_hash_node`, `state_hash`). The worker's hash
now also covers the seeded generator and the input state (`kernel/host/statehash.gd`), the world's does not. The world
proofs (`world.same`, `world.proof`, `world.tour`) compare the world with the world, so they pass either way; but a
pack in a world can still differ in its next random number where the world's hash cannot see it, and a pack's hash in
a world is no longer the hash `tl.sh smoke` prints for it. `statehash.gd` takes the pack's origin, so the copy can go
(about 30 lines of a file the size ratchet holds).

**Patch.** Delete `_q`, `_put_v3` and `_hash_node` and replace `state_hash()`:

```gdscript
## The worker's state hash (kernel/host/statehash.gd): every physics body under the pack with positions relative to the
## pack's origin, `_pack_state()`, the seeded generator and the input state.
func state_hash() -> String:
	var tail: String = str(WorkerScript.call("_canon", entry.call("_pack_state"))) if entry != null and entry.has_method("_pack_state") else ""
	return (load("res://kernel/host/statehash.gd") as GDScript).call("hash", pack_node, tail, ctx.rng, ctx.input, ctx.origin)
```

Every world hash changes once (as every worker hash did in P7). Afterwards a pack alone in a world at the origin
hashes exactly as `tl.sh smoke` does; the figures in `kernel/world/*.md` and `docs/reports` that quote world hashes go
stale and should be taken again.

## 2. `engine/kernel/world/pack.gd` or `world.gd`: a pack script's own event handlers are switched off in a world too

**Why.** A pack script that defines `_input` or `_unhandled_input` reads a device past `ctx.input`, so past the
input record. Lint counts it as a bypass and lets it through (the pack contract says so). In a single-pack run the
worker now switches such handlers off when the node is ready (`worker.gd`, `_on_node_added` / `_mute_events`). The
world loads packs through `pack.gd`, which has no such hook.

**Patch, `pack.gd`**, where the pack's nodes are made (after `pack_node` exists, before the entry is added):

```gdscript
	get_tree().node_added.connect(_p7_node_added)
```

and

```gdscript
## P7: a pack script's own event handlers would read a device past ctx.input: off, when the node is ready.
## Only scripts of this pack (by path, as worker.gd does), and once per node.
func _p7_node_added(n: Node) -> void:
	var sc: Script = n.get_script() as Script
	if sc != null and not n.is_node_ready() and (sc.resource_path.begins_with(pack_dir) or sc.resource_path.begins_with(ProjectSettings.localize_path(pack_dir))):
		n.ready.connect(func() -> void:
			n.set_process_input(false)
			n.set_process_unhandled_input(false)
			n.set_process_unhandled_key_input(false)
			n.set_process_shortcut_input(false), CONNECT_ONE_SHOT)
```

Cost: one path comparison per scripted node added, per pack of the world (the test is by the script's path, so no
walk up the tree). With 40 packs every node added is looked at 40 times; if that shows in the loading figures, one
handler in `world.gd` is cheaper. The worker's version of this was verified (case `p7.fence_handler_switched_off`,
with a control run in which the line was taken out and the handler ran); this one for the world was not run.

## 3. `engine/kernel/world/draw/view.gd`: the live visitor's keys through the record (item 6 of the brief, not built)

**Why.** `_live_input()` polls `Input.is_physical_key_pressed` for W, A, S, D, Shift, E, Q and Esc, and
`view.gd` flips `ctx.input.accept_devices` of the pack on stage. So a walk a person did cannot be replayed.
`visitor.gd` reads no key itself: the keys are all in `view.gd`, which is another builder's file tonight.

**Proposal (not exact text).** Give the world one `TLInput` of its own (`world.input`, actions `forward`, `back`,
`left`, `right`, `run`, `enter`, `leave` with those keys, `accept_devices` true in `--live`), sample it once per world
tick before `_live_input()`, and let `_live_input()` read `strength()` instead of polling. `world.input._record()`
then gives `[tick, action, value]` for the walk, written with `kernel/runner/session.gd` `write()` (`pack` would be
the world's name, `mode` `"play"`). A replay feeds it back with `_feed()`; because the walk moves `player_pos` by
`pace / 60` per tick from those values, the positions are the same and the result can also be written out as a
`tl.walk/1` script. `ctx.input.keys_taken()` already keeps typed keys from the pack on stage; the world's input gets
the same rule for free.

## 4. `engine/kernel/examples/bad_bypass` and the pack contract: should an `_input` handler be a fence error?

**Why.** The brief says a pack that reads a device directly already fails lint. Measured: `bad_bypass` has
`func _input(_event: InputEvent)` and passes lint with exit 0 (`"pattern":"_input handler"` in `bypasses[]`), as
`contracts/PACK.md` says. P7 closed it at run time (the handler never runs) and made everything else a fence error
(`InputEventKey` and siblings, `_gui_input`, `_unhandled_key_input`, `set_process_input`, mouse positions, controls).
To make the handler itself an error, three places change together:

- `engine/kernel/runner/lint.gd`: move the row `["(?m)^[ \\t]*func\\s+_(unhandled_)?input\\s*\\(", ...]` from `BYPASS`
  to `FENCE` (label `_input handler`, hint `input goes through ctx.input (P7)`), and change `"\\bInputEvent\\w+"` to
  `"\\bInputEvent\\w*"`;
- `engine/kernel/examples/bad_bypass/scripts/main.gd`: delete line 24 and its body;
- `engine/tools/selftest.sh`, case `bad.bypass`: drop `'"line":24,"pattern":"_input handler"'`; add the handler to
  `bad_fence/scripts/fence.gd` between `# FENCE BEGIN` and `# FENCE END`.

## 5. `foreman/`: the Foreman still writes and expects `kernelApi` 0.1

**Why.** The engine's reports now say `"kernelApi":"1.0"`. Packs that say `"0.1"` run (the stated rule: 0.1 is the
old name of 1.0), so nothing breaks tonight. Three places name the old value:

- `foreman/src/manifest.ts` line 12: `export const KERNEL_API = "0.1";` -> `"1.0"` (new packs then say 1.0);
- `foreman/src/test/engine.test.ts` line 90: `assert.equal(r.report?.["kernelApi"], "0.1");` -> `"1.0"`. Today this
  test runs against `site/_engine_snapshot3` (an engine from before P7) unless `TL_ENGINE_DIR` is set, so it is green;
  it fails as soon as it is pointed at the live engine or a new snapshot is taken;
- `foreman/src/testing/fake-runner-core.ts` line 113: the fake report's `kernelApi: "0.1"` -> `"1.0"`.

The new verb `replay` and the option `--record` of `bot` are in `kernel/runner/verbs.json`, which the Foreman reads;
its fixture copy `foreman/fixtures/engine/kernel/runner/verbs.json` does not have them (nothing needs them there).

## 6. Seeds, examples, world bench packs: `"kernelApi": "0.1"` -> `"1.0"` (optional)

Not needed (see 5). For the record, the one-line change in each `pack.json`:
`engine/seeds/seed_{paddle,drive,wall}`, `engine/kernel/examples/*` (30 packs), `engine/kernel/world/packs/w_pile`,
`w_pile_x`: `"kernelApi": "0.1"` -> `"kernelApi": "1.0"`. `devx/templates/pack/pack.json` (mine) already says 1.0.
`engine/tools/item.sh` line 303 (case `kernel_api_patch_level`) rewrites 0.1 to 0.2 and expects a refusal: it is
still refused (major 0 is not major 1), so the case passes as it is; if the packs move to 1.0 its `sed` must match
`"1.0"` and write `"2.0"`.

## 7. `contracts/`: what to paste, and what to take out of the baseline afterwards

Proposed text for `contracts/PACK.md` (the API version rule, `tl.input/1`) and `contracts/RUNNER.md` (`replay`,
`--record`) is in the P7 report. Until it is in, `devx/arch.baseline.json` holds four findings:
`schema-versions: tl.input/1` and `verbs-contract: doc-verb:replay, doc-opt:input, doc-opt:record`. Once the contract
text names `` `replay` ``, `--input`, `--record` and `tl.input/1`, run `node devx/bin/tl.mjs arch --update-baseline`:
the four entries disappear by themselves. `contracts/pack.schema.json` needs no change (`kernelApi` is already
`^\d+\.\d+$`); its description of the field should say major.minor and the rule.

## 8. `engine/ui/PATCHES.md`: entries 1 and 2 are applied

Entry 1 as written (`TLInput.keys_taken()`, `_sample()` reads no key while a `LineEdit` or `TextEdit` has focus).
Entry 2 with the same rule in another place: `worker.gd` asks `session.ends_now()` (`kernel/runner/session.gd`), which
is Esc down and no visible `CanvasLayer` named `TLDesigner` under the worker. Both have a selftest case
(`p7.keys_field_takes_keyboard`, `p7.keys_esc_panel_open`). The header of `ui/PATCHES.md` ("None of these is applied")
is stale for 1 and 2. Entry 3 (mounting the panel) is not applied; when it is, `tl.sh` `fix_arg` must treat
`--jobs=` and `--foreman-flags=` as paths (P7 added `--input=`, `--record=`, `--devices=`, `--result=` there).

## 9. After the merge of the night's other packages: the API description

`docs/generated/API-V1.json` describes the surface of this worktree. Another package that added a public method,
signal, property or constant to `kernel/api`, the kit, the rigs or the style makes `tl arch` fail after the merge with
`api-v1: ... An addition needs a new minor version`. Since 1.0 has not been released to any pack author yet, the
merged surface can be frozen as 1.0 once: `node devx/bin/tl.mjs arch --index --freeze` (it writes the current
surface as the description of the current version). After tonight `--freeze` should not be used again: an addition
is 1.1, a removal or a change is 2.0. A package that removed or changed a public signature shows up as
`api-v1: ... was removed` / `changed: it was ..., it is ...` and deserves a look before the freeze.
