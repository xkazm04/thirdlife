# N4: an item gets a card and a package, and the fence closes its known holes

You are the builder for **sharing** in Third Life, a single-player sandbox on Godot 4.7.2 in which an LLM builds small
games ("packs") over a law kernel. The owner wants a metadata standard and a package for the things a player is proud
of: first carried in the player's own cloud save, later offered in a community store. The owner has also ruled on
trust: **data-only items install freely; items with scripts may reach another player only once they run isolated.**
Tonight you build the card, the package and the computed tier, and you close the holes a scout found in the fence.

## Read first
1. `C:\Users\kazda\kiro\third-life\docs\SHARING.md` (the strategy and the card: sections 1 to 3 are your spec).
2. The last section of `contracts\PACK.md` (the optional manifest fields you validate).
3. `engine\kernel\runner\lint.gd`, `engine\kernel\runner\manifest.gd`, `contracts\pack.schema.json`,
   `engine\kernel\API.md` near line 510 (limits and "No real sandbox"), `engine\tools\tl.sh`.

## Where you work
**In your own copy of the engine: `C:\Users\kazda\kiro\third-life\site\_work\n4\engine\`** (made from the main tree a
few minutes ago). Set `TL_GODOT=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe` and
run its own tools: `bash site/_work/n4/engine/tools/tl.sh ...`. Two other builders change the engine in the main tree
and in another copy at the same time; the Director merges by file, so the scope is strict.

Yours: `kernel/runner/lint.gd`, `kernel/runner/manifest.gd`, new `kernel/share/**`, new `tools/item.sh`,
`tools/tl.sh`, new bad packs named `kernel/examples/bad_item_*` and `kernel/examples/bad_reach_*`.
**Not yours:** every other file under `kernel/` (including `host/host.gd`, `runner/worker.gd` and `tools/selftest.sh`:
give your tool its own entry scene under `kernel/share/` and its own `item.sh selftest`), `kits/`, `rigs/`, `style/`,
`seeds/`. If one of those needs a change, write the exact patch and its reason to `kernel/share/PATCHES.md`.
Read-only test inputs: `site\marble-run-three-marbles-20261110-1\pack\` and
`site\marble-run-three-marbles-20261110-2\promoted\game.marble_run_three_marbles\` (the two packs real jobs made).

## The work, in this order
1. **The card.** `item.json`, schema `tl.item/1`, exactly as `docs\SHARING.md` section 2: every key always present,
   `uid` made once (26 characters, random), `capabilities` sorted and copied from `pack.json`, `content.hash` over the
   sorted list of `(path, bytes, sha256)` of every file except the card. A validator with readable errors. A card for a
   pack is filled from `pack.json`, from a lint and a bot report when given, and from a job's log when given
   (`provenance`); what is unknown stays empty, never invented.
2. **The tier is computed.** `data` or `code`, from the folder's contents, at pack time and again at install. Decide
   and write down exactly what makes an item `code` (scripts, shaders, scenes, resources that can carry scripts,
   anything the engine would execute). A card whose `tier` disagrees with the contents is refused.
3. **The package.** `.tlitem`: a zip with `item.json` at the root, entries sorted, fixed timestamps, so that packing
   the same folder twice gives the same bytes. Use Godot's `ZIPPacker` and `ZIPReader` if they can do it; say so if
   they cannot and what you used. Unpacking treats the archive as hostile: no absolute paths, no `..`, no entry outside
   the target, size and count limits (the pack limits that exist, a thumbnail under 1 MB, an archive under 8 MB).
4. **The tool.** `bash tools/item.sh card <dir> [--lint=<report>] [--bot=<report>] [--job=<job dir>]`,
   `item.sh pack <dir> --out=<file.tlitem>`, `item.sh unpack <file> --to=<dir>`, `item.sh check <dir or file>`
   (validates the card, recomputes hash and tier, reports each mismatch), `item.sh selftest`. A library layout for
   later use: `<library>/<uid>-<version>.tlitem`, never rewritten.
5. **Close the fence's known holes.** The fence is a text check that only `lint` runs. A scout found: `assets/` is
   never inspected, so `load("assets/x.gd")` reaches unchecked code; reflection is open (`call`, `callv`, `set`,
   `Callable(obj, "name")`, `set_script`); these classes are not covered: `ResourceLoader`, `ConfigFile`, `ZIPReader`,
   `ZIPPacker`, `PCKPacker`, `XMLParser`, `Image.load`/`save`, `MultiplayerAPI`, `ENetMultiplayerPeer`, `WebRTC*`,
   `Crypto`, `DisplayServer`, `RenderingServer`, `PhysicsServer3D`, `AudioServer`, `Performance`, direct `Input.*`,
   `get_tree().get_root()`, `get_node("/root")`, `Engine.*` beyond `get_singleton`, `Time.get_datetime*`; and
   `play` never lints. Verify each claim first (some may be wrong, and some of these calls are used legitimately by
   the seeds: check before you ban). Then: inspect every script wherever it sits in the pack; extend the deny list
   where the seeds and the two job packs do not need the call; make `tl.sh play` lint first and refuse a pack that
   fails the fence. Add a bad pack per closed hole that passes lint today and fails after. Write plainly in
   `kernel/share/SHARE.md` that this is still a guardrail and not a security boundary, and list what stays reachable.
6. **Optional manifest fields.** `manifest.gd` and `contracts`' schema copy in the engine accept and shape-check
   `footprint`, `params`, `on_leave`, `subject`, `moments` as in `contracts\PACK.md`; `kernelApi` matches on
   major.minor. A pack without them behaves as before. (Do not edit `contracts/`: put the schema change in
   `kernel/share/PATCHES.md`.)

## Acceptance (the Director will run these in your copy)
- `bash tools/item.sh selftest` passes and prints one PASS or FAIL line per case; `bash tools/tl.sh selftest` still
  passes; `bash tools/tl.sh seeds` still passes.
- `item.sh pack` of `seeds/seed_paddle` twice gives byte-identical files (show the two sha256); `unpack` then `check`
  passes, and the unpacked pack passes `tl.sh lint`.
- A folder with only a layout file is tiered `data`; a seed is tiered `code`; a card edited to say `data` on a seed is
  refused; an archive with a `..` entry is refused.
- Each new bad pack: lint exit 0 on the main tree's engine today, exit 1 on yours.
- The three seeds and both job packs still pass lint on your engine, or you list exactly which rule each one trips
  and why the rule is right (a real job's pack tripping a new rule is a finding, not a reason to drop the rule).

## How to work
Small verified steps; journal each in `kernel/share/JOURNAL.md`. Headless runs only. Kill every process you start;
never kill others. No git. No network. Never read, use or print any `ANTHROPIC_KEY_*` variable. No e-mail address,
machine path or account id ever goes into a card. Where a step's premise is wrong, say so with the evidence.

## Final message (your report, as text)
Status; item by item what was built and the proof; the tier rule as you wrote it; the selftest counts; the list of
fence rules added, with for each the bad pack that proves it and whether any seed or job pack trips it; what stays
reachable; the contents of `PATCHES.md`; what you did not verify; questions; minutes spent from real timestamps
(`date`).

## Time-box
Until the list is done or **80 minutes after your start** (run `date` first and often). Items 1 to 4 proven, then
item 5, are worth more than all six half-done. Leave the last ten minutes for the gates and the report. A usage limit
can cut you off without warning: keep the journal current.
