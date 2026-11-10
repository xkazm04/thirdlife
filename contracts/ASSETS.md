# Asset spine (tl.assets/1)

Today the kit generates everything from GDScript; no imported asset exists (`engine/kits/KIT.md`). Imported and
AI-generated textures, meshes, audio and voxel data will arrive from builders and players. This contract governs that
growth from the first file: one manifest, budgets by tier, and hygiene rules for foreign files.

Tools: `node devx/bin/tl.mjs assets list | check [--static] | scan | add <file> ...`. Library: `devx/lib/assets/`.
Reference schema: `contracts/assets.schema.json` (the validator is hand-written in devx, there is no ajv there).

## Files

| File | Meaning |
|---|---|
| `assets/manifest.json` | every registered asset; written only by `tl assets scan` and `tl assets add`, sorted by id, canonical bytes |
| `assets/budgets.json` | limits by tier and kind (schema `tl.assets.budgets/1`, with a `derivation` note) |
| `assets/<owner>/...` | the files of imported or generated assets; `<owner>` is `engine` or a pack id. Nothing else may live there |

## Entry

`id` (namespaced: `kit.rink`, `pack.marble.ramp`), `kind` (`kit_part|mesh|texture|audio|material|rig|data`),
`source` (`procedural|imported|generated`), `origin`, `hash`, `bytes`, `tris` (kit_part and mesh), `px` (textures),
`license`, `provenance {tool, model?, prompt_hash?, author}`, `owner`, optional `params` and `tier`.

- **procedural**: `origin` is `<generator>:<name>` (`tlkit:rink`). `hash` is `TLKit.hash` of the part built from its
  default params: **SHA-1 hex (40 chars), not SHA-256**, because that is the identity the kit already defines and
  determinism tests already compare. `bytes` is 0. `kit_part` is always procedural and owned by `engine`.
- **imported / generated**: `origin` is the repo-relative path of the file, inside `assets/<owner>/`. `hash` is the
  SHA-256 of its bytes. A **generated** asset (made by a model) must carry `provenance.model` and
  `provenance.prompt_hash`. An imported texture declares `px: [w, h]`; a PNG's header must agree.
- **tier**: `engine` for owner `engine`; else `pack` by default, `player_pack` when the entry says so. Tiers only differ
  in budgets: player packs get the strictest.

## Checks (`tl assets check`)

One PASS/FAIL line per step, JSON verdict last, exit 0/1 (2 = could not run). `--static` needs no Godot and is what
the gate step `assets` runs; without it the kit is re-scanned and `kit_part` hashes and triangle counts must equal the
manifest.

1. **manifest**: both files parse; schema, namespaced unique ids, required provenance and license, kit_part rules, sorted.
2. **files**: every foreign file exists, size and SHA-256 match, PNG dimensions match `px`.
3. **budgets**: triangles, texture px and bytes per asset by tier and kind; total bytes per owner.
4. **hygiene**: see below, for every registered file and every file lying in any `assets/<dir>/`, registered or not.
5. **procedural** (full mode): the kit and the manifest agree.

## Hygiene (devx/lib/assets/hygiene.mjs)

`checkPath(rel, {ownerDir})`, `checkFile(abs, {kind, maxBytes})`, `checkTree(dir, {maxBytes})`: pure functions
returning problem strings, reusable by a pack installer. They are the first piece of clean packaging on a player's
computer. Rules:

- a path is relative, has no `..`, no backslash, no drive letter, no URL scheme, no control characters, and stays inside
  `assets/<owner>/`;
- extension allowlist per kind (mesh `.glb .gltf .obj .vox .vxm`, texture `.png .jpg .jpeg .webp .ktx2`, audio
  `.ogg .wav .mp3`, material/rig/data `.json`);
- never, in any asset directory: `.gd .dll .exe .sh .bat .so .cmd .ps1` and also `.dylib .com .msi .vbs .js .mjs .py
  .jar .apk .gdextension .tscn .tres .res .scn .pck` (scene and resource files can embed scripts);
- executable content behind a harmless extension is rejected by magic bytes (PE `MZ`, ELF, Mach-O, `#!`);
- symbolic links are rejected; a single file may not exceed 64 MiB, and never exceeds its kind's `maxBytes`;
- a file in an owner directory that the manifest does not list is a failure.

## Budgets

See `assets/budgets.json` and its `derivation` field. Measured: the 36 kit parts at default params peak at 19,688
triangles (`kit.stands`); the kit_part limit is that plus 25 %. Everything about imported files (textures, audio, bytes)
is a policy number until real imports exist, tightening engine, pack, player_pack.

## Commands

- `tl assets scan` rebuilds the engine-owned `kit_part` entries by running `engine/tools/assets/scan_kit.gd` (every part
  built twice from defaults; a non-deterministic part fails the scan). Output is sorted; two runs are byte-identical.
- `tl assets add <file> --id --kind --owner --license --tool [--model --prompt-hash --author --tris --px WxH]` registers
  a file that is already in place. It refuses a duplicate id, reports same-hash duplicates, validates the whole result
  and leaves the manifest untouched on any problem of the new entry.
- `tl assets list [--kind k] [--owner o]`.
