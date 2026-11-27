# Lane T (M6 tool): rules by hand, no code

Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-m6-t`, branch `d27-m6-t`, from the seam 6690ad32 (branch d27-m6). Opus. Time box ~4 h. Selftest blocks: `775-home-rules-tool.sh` (replace the seam's stub) and 782-784.
**Read `../M6-COMMON.md` (this folder's parent) first**, then `engine/kernel/world/build/LANES.md` (your row "T: tool" is the authority on your files), `BUILD.md` "Tools", `tools/stamp_tool.gd` (the box drag and the name field: the closest model), `tools/path_tool.gd`, `rules_layer.gd`, `rules_check.gd`.

## Goal
A person who never read a manual makes a door, a jump pad, a coin trail and a timed run in minutes with the hand tool. Research behind it (`docs/research/sandbox/THESIS.md`): presets first (Fortnite devices, Roblox templates), a readable text form (Hypixel Housing's players had to invent one), the hand can do everything the LLM can.
1. **The Rules tool** (the T cycle, between plants and command, already in the strip): drag a zone box on the ground like the stamp box, the wheel raises its top; then pick a preset from a small card row: **Start**, **Checkpoint**, **Finish**, **Coin**, **Door** (opens on use, closes after N s: `every` + a counter, or your cleanest form with the contract's verbs), **Jump pad**, **Hazard** (respawn), **Message**. Each preset writes zone + rule(s) as ONE batch (one undo) with sensible defaults; the zone's look follows the preset (start/checkpoint pad, coin coin, finish flag, others none). The run's name is asked once (a LineEdit like the stamp name field, `blocks_input()` true while open, the closing Enter/Esc neither opens the command bar nor leaves build mode: copy the stamp tool's guard) when the first Start is placed; later Starts/Finishes use it.
2. **Edit**: point at a zone to select it (outline); Delete removes it and the rules that name it (one batch); the side card lists its rules as sentences (`describe`) and a few knobs per preset (door seconds, pad strength, message text, coin value), each change one batch.
3. **Zones visible in build mode**: `zone_draw.gd`: box outlines and the look's icon in `TLStyle.material("holo")`, hidden in play (lane P draws the play looks). **`preview_node(sc)`** on `rules_layer.gd` (your one method there): an answer's or a preset's added zones/rules in holo, removed ones in red, `null` when none changed: the LLM bar shows it through `home_build.preview_nodes` with no change on lane C's side.
4. Keys: none the host has (B, Esc, T, Enter, Ctrl+Z / Y) and not E (the visit's use key). Name yours in BUILD.md's tool table section that LANES.md lets you touch, or in your report for the Director.

## The seam's hand-offs you build on (quoted from LANES.md)
```gdscript
# rules_layer.gd (layer id "rules"; build.layer("rules"); read only, except preview_node which you own)
var zones: Dictionary            # id -> {"id": int, "box": [[x0, y0, z0], [x1, y1, z1]], "look": "none|pad|coin|flag", "name"?: String}
var rules: Dictionary            # id -> {"id": int, "when": {...}, "if"?: [...], "do": [...]}
var revision: int                # +1 per applied record or clear (a drawer redraws when it moves)
func next_zone_id() -> int
func next_rule_id() -> int
func counters() -> Array
func zones_at(c: Vector3i) -> Array          # zone ids whose box holds cell c, ascending
func names() -> Dictionary                   # zone id -> name
func describe(n: int) -> String              # rule n as a line ("when you enter Door: open Door")
func preview_node(sc: Variant) -> Node3D     # YOURS
# rules_check.gd (static): malformed(op, strict), describe(rule, names), floor_centre(box), box_has(box, c), zones_named(rule),
# counters_of(rule), LOOKS, TRIGGERS, EFFECTS, SIDE_MAX 64, ZONES_MAX/RULES_MAX 512, COUNTERS_MAX 8, DO_MAX 8, IF_MAX 8, NAME_MAX 24, TEXT_MAX 60
# Ops go through build.apply(op_or_batch) (one batch, one undo). Zones refused in protected areas: protect.gd refusal_box(lo, hi) -> String.
# Optional, only after lane P lands (never wait for it): play_looks.gd static func look_of(zone: Dictionary) -> Node3D
```

## Acceptance
- `775-home-rules-tool.sh` -> `HOME rules-tool ok` (headless through the tool's own input path: each preset writes the expected ops in one batch, undo removes it, delete removes zone + rules, the name field's guard, describe lines, knobs, `preview_node` draws one node per changed zone and null when none).
- The exe (a window): make the tower course by hand from scratch (start, 3 coins, a door, a jump pad, a finish); count the clicks and frames from the first click to the last preset; captures `t6-presets.jpg`, `t6-zones.jpg`, `t6-ghost.jpg` (a preset's preview) in `docs/shifts/2026-11-27-day/lanes/T6-tool/`. Judge honestly: could a newcomer do it?
- Gates per M6-COMMON.
