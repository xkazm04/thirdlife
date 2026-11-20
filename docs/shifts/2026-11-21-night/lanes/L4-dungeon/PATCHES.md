# L4 patches for the Director (files outside the L4 column)

## 1. contracts: declare `tl.dungeons/1` (needed: `tl arch` schema-versions FAILS without it)

`tl arch` rule `schema-versions`: every `tl.<name>/<n>` string used in engine/ must be declared in a contracts/ doc.
`engine/boot/dungeons.json` uses `tl.dungeons/1` (the COMMON seam). Proposed text, for `contracts/README.md` (or wherever
the Director keeps exe-side schemas):

```
### tl.dungeons/1 (engine/boot/dungeons.json; L4, 21 Nov)
The dungeons of the main menu: {"schema": "tl.dungeons/1", "dungeons": [{"pack", "title", "look"?}]}.
- pack: a folder relative to engine/ (for example "packs/hockey"); no absolute path, no "..". Listed once.
  In the exported game it must be one of engine/boot/games.json (export.sh refuses a build otherwise).
- title: a non-empty text of at most 80 characters, shown in the menu and on the load screen.
- look: a TL_STYLE name (crisp, classic, or N for style/style_N.json); absent = the default look.
Unknown keys are errors; an absent value is an absent key (never null). Reader: engine/kernel/dungeon/dungeons.gd.
```

## 2. Wiring L3's "Try it" (no file of L4 changes)

L3 calls `load("res://kernel/dungeon/dungeons.gd").launch(<job dir> + "/pack")` (returns the pid or -1). It starts the
running executable again: the exe as `ThirdLife.exe -- --dungeon=<dir>`, the editor binary as
`<godot> --path <engine> res://boot/boot.tscn -- --dungeon=<dir>`. `launch_args(dir)` gives the arguments only.
No in-process switch was added tonight.
