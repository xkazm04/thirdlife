# N4 journal (sharing: card, package, tier, fence holes)

Builder start: 2026-11-11 00:03:47 (local clock, `date`). Time-box 80 minutes: stop at 01:23.
Work happens only in this engine copy (`site/_work/n4/engine`). Scope: `kernel/runner/lint.gd`,
`kernel/runner/manifest.gd`, `kernel/share/**`, `tools/item.sh`, `tools/tl.sh`, `kernel/examples/bad_item_*`,
`kernel/examples/bad_reach_*`.

- 00:04 read the brief, docs/SHARING.md, contracts/PACK.md (last section), lint.gd, manifest.gd, pack.schema.json,
  API.md sections 16 to 18, tl.sh, selftest.sh.
- 00:07 scanned the three seeds, the kernel examples and both job packs for every call the scout listed.
  Used by real packs: `set_script` and `.set("ctx", ...)` (job 1: gen/look.gd, gen/sound.gd), `Image.create`
  (job 1: scripts/look_dress.gd, not `Image.load`/`save`), `get_node_or_null("WheelFL")` (ex_kit, a relative
  literal), `set_meta`/`get_meta`/`has_meta`, `.bind(`, `.connect(`, Dictionary `.get(`. Used by none: `call(`,
  `callv(`, `Callable(`, `get_tree(`, `get_parent`, `get_viewport`, `get_window`, `Engine.`, `Input.`, `Time.`,
  any `*Server`, `load(`/`preload(` (packs use `ctx.load_script`).
- 00:09 experiment: Godot's `ZIPPacker` stamps every entry with the wall clock. Same content packed twice three
  seconds apart: two different sha256, the bytes that differ are the DOS time fields (offsets 11 and 58). It has no
  way to set the time. So `ZIPPacker` cannot make a reproducible archive; the package gets its own small writer.
  `PackedByteArray.compress(COMPRESSION_GZIP)` gives a 10-byte header, the raw deflate stream, then CRC-32 and the
  length: both things a zip entry needs, from the engine's own zlib. An empty array compresses to nothing (handled
  as a stored entry with CRC 0).
- 00:11 lint.gd: every file of the pack is listed (hidden ones too) and classed script / inert / ignored / other;
  every .gd is read by the fence wherever it sits; an "other" file is a fence error. New fence rows for reflection,
  engine classes and the tree above the pack; node path literals that are absolute or climb with '..'. `item.json`
  and `preview/` allowed at the pack root. Lint by hand after the edit: seed_paddle, seed_drive, seed_wall, job 2's
  promoted pack, pack_min and the seven ex_* packs exit 0; bad_fence still reports the same lines; job 1's pack
  exits 1 on `set_script` (gen/look.gd:8, gen/sound.gd:8) and `.set(` (gen/look.gd:9, gen/sound.gd:9 and 12).
- 00:16 kernel/share/tlzip.gd (canonical zip writer and strict reader), item.gd (card, validator, tier, hash,
  limits, check), item_tool.gd + item_tool.tscn (entry), tools/item.sh (commands and selftest), tl.sh play lints
  first. Five bad packs: bad_reach_assets, bad_reach_filetype, bad_reach_reflection, bad_reach_classes,
  bad_reach_tree.
- 00:20 first full `item.sh selftest`: 77 passed, 6 failed; the 6 are the manifest cases of work item 6, not yet
  built. Items 1 to 5 pass: card, tier, package (same sha256 twice, three seconds apart), unpack + check + lint,
  ten hostile archives, the five bad packs, play refusing.
- 00:22 manifest.gd: `footprint`, `params`, `on_leave`, `subject`, `moments` accepted and shape-checked;
  `api_compatible` compares major and minor. lint.gd: a `params[].file` that is not in the pack is a layout error.
  `item.sh selftest manifest`: 11 passed.
- 00:23 the five bad packs against a snapshot of the main tree's engine (kernel, kits, rigs, style, tools copied to
  a scratch folder at 00:21, so the main tree itself was not run or touched): exit 0 each; on this engine exit 1.
- 00:23 preview run of `tl.sh selftest` in this copy: 63 passed, 0 failed (before the stricter rules below).
- 00:26 found while writing the "stays reachable" list, and closed: (a) the contract's own rules `OS.`,
  `ProjectSettings.`, `ClassDB.` needed the dot, so `var o = OS` passed: now bare words; `Engine`, `Input`, `Time`,
  `GDScript`, `load` as values; method names as words, so `get_tree` without brackets is seen; (b) `load("kernel/
  runner/worker.gd")` passed (relative paths were let through and the engine reads them from its root) and
  `load("res://kits/" + "../kernel/host/host.gd")` passed (only the first literal was judged); (c) a `\` line break
  between a name and its bracket hid `load \ (...)`; (d) a node path that is not one plain literal. More classes:
  IP, CameraServer, microphone, GDExtension, GLTF/FBX, WebSocket*, ENet*, UPNP, Java*, EngineDebugger, FileDialog,
  LinkButton. Two more bad packs: bad_reach_alias, bad_reach_load; bad_reach_tree and bad_reach_classes extended.
  Lint again: three seeds, job 2's pack, pack_min, seven ex_* exit 0; bad_fence 36 findings as before; job 1's
  pack exit 1 with the same 5 findings.
- 00:30 a probe pack in the scratch folder holding what is still reachable (reading by name, method values through
  map, add_sibling, Shader code, Window.new, a 1 GiB resize, ...): lint exit 0. That list is in SHARE.md section 1.
- 00:31 the scratch folder is shared with the other builders (a log of mine was overwritten by one of theirs); my
  files moved under scratchpad/n4/. Nothing of theirs was changed.
- 00:33 SHARE.md, PATCHES.md written. Selftest case added: a job log whose sentence holds a machine path.
- 00:35 full `item.sh selftest`: 91 passed, 0 failed.
- 00:36 `tl.sh selftest` (run after the stricter rules) failed one case: bad.fence_each_line, line 28 reported twice.
  My new `Java*` rule also matched the contract's own `JavaScriptBridge` line. Fixed with a lookahead
  (`Java(?!ScriptBridge)`); bad_fence by hand: 36 findings, no line twice. Both gates are run again from the start.
- 00:38 acceptance by hand, on copies in the scratch folder (seeds/ in this copy untouched):
  pack of seed_paddle twice, three seconds apart: sha256 8690fe73c56af607add301eb8222d7a55f481e12405c498f011cd8a7479956a8
  both times, 9032 bytes, `cmp` identical; unpack exit 0 (8 files), check exit 0, `tl.sh lint` on the unpacked pack
  exit 0. A folder with only a layout file: tier data. seed_paddle: tier code. The card edited to `data`: check
  exit 1 with `MISMATCH tier`. An archive with `../evil.txt`: unpack exit 1, nothing written.
  The seven bad packs: exit 0 on the snapshot of the main tree's engine, exit 1 here.
  Lint here: this copy's three seeds exit 0; the main tree's three seeds as they are now (another builder changed
  them since this copy was made) exit 0; job 2's promoted pack exit 0; job 1's pack exit 1 (set_script x2, .set x3).
- 00:38 `tl.sh play` with a stub in place of the Godot executable: after lint passes, the launch line is the one it
  was (`--position 0,1440 --path <engine> res://kernel/host/host.tscn -- worker --mode=play --pack=... --seed=3`).
  A real window was not opened (headless runs only).
- 00:47 final gates, all after the last code edit (lint.gd, 00:36:50):
  `tl.sh seeds` 24 passed, 0 failed (00:38:16 to 00:41:46);
  `tl.sh selftest` 63 passed, 0 failed (00:41:59 to 00:45:23);
  `item.sh selftest` 91 passed, 0 failed (00:45:23 to 00:47:24).
  N4 complete against the brief; report returned as the final message. No code edit after 00:36:50.
