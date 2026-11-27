# Lane C (M6 LLM): say what it does

Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-m6-c`, branch `d27-m6-c`, from the seam 6690ad32 (branch d27-m6). Opus. Time box ~4 h. Selftest blocks 785-787 (Director's answer to the seam's Q12).
**Read `../M6-COMMON.md` (this folder's parent) first**, then `engine/kernel/world/build/LANES.md` (your row "C: LLM" is the authority on your files), `COMMAND.md`, `command_ask.gd`, `command_answer.gd`, `tools/command_tool.gd`, `foreman/src/world_edit*.ts`, `foreman/prompts/world_edit.md`.

## Goal
"make this tower a parkour course with three checkpoints and a finish at the top" and "put a door here that opens when I press E" work from the command bar on the first try, and the ghost shows what will happen before accept. Research behind it (`docs/research/sandbox/THESIS.md`): LLMs fail at space, not syntax, so the grammar and a space check carry the geometry; the AI proposes, the person accepts; hand edits survive.
1. **The ask**: top-level `zones`, `rules` from `ask_part(lo, hi)` and `rules_room` (move them out of `ask.layers`, where `home_build.read_region` puts them today); the M6 ops in the prompt facts; the answer's counts in the note ("4 zones, 6 rules: Tower climb").
2. **The Foreman** (`foreman/src/world_edit*.ts`, only you edit foreman): validate zone/unzone/rule/unrule exactly as the contract (every limit and refusal, fed back; two attempts); ids are the answer's own (the exe renumbers via `home_build.expand_input`).
3. **The prompt** (`foreman/prompts/world_edit.md`): teach zones and rules in the same style as the other ops, with 2 worked examples (a door on use; a short course: start pad, coins, a checkpoint, a finish flag), and the rule that pads and flags stand on blocks the answer places or that exist, coins float 1 m above a floor. Keep it tight: measure the prompt (~19 KB) and grow it by at most 4 KB.
4. **The space check before accept** (contract M6; `command_space.gd`, shown with the ghost by `tools/command_tool.gd`, never a refusal): blocks resting on nothing, a pad or a flag with no floor, a coin inside a solid block, a run's finish unreachable from its start (an estimate over standable cells: walking, steps of at most 0.55 m, jumps of at most 1.2 m up and 4 m across). Markers on the problem cells in the ghost and a line in the note ("2 blocks float; finish not reachable").

## The seam's hand-offs you build on (quoted from LANES.md)
```gdscript
# rules_layer.gd (read, never write)
func ask_part(lo: Vector3i, hi: Vector3i) -> Dictionary      # read_region + {"rules_room": room()}: the ask's M6 keys
func room() -> Dictionary                    # {"zones_left": int, "rules_left": int, "counters": [String]}
var zones: Dictionary; var rules: Dictionary
# home_build.gd (seam, frozen): expand_input(ops) -> {"ops", "refused"}: calls the rules layer's renumber(ops)
# home_build.preview / preview_nodes(r, skip): shows every layer's ghost; lane T's rules_layer.preview_node(sc) draws the rules part (T, no change on your side)
# rules_check.gd (static): malformed(op, strict), describe(rule, names), floor_centre(box), box_has(box, c), LOOKS, TRIGGERS, EFFECTS and the limits
```
The seam added only the Foreman wire names (`zone`, `unzone`, `rule`, `unrule` in `ASK_OPS`, the answer schema keys, the ask schema's optional `zones`, `rules`, `rules_room`, shape-only checks): you write the prompt and the full checks.

## Acceptance
- foreman `npm test` green with counts and new tests (each M6 op good + fed-back bad; locks unchanged); `node --test dist/test/world_edit.test.js` counts.
- `785-home-command-m6.sh` -> `HOME command-m6 ok` (fixture answers: a course answer shows zones in the ghost note and accept writes one batch; renumbered ids; a floating-block answer shows the warning; the reachability estimate on 3 fixtures: reachable, a gap too wide, a wall too high).
- ONE real Opus call in the exe (a window) at a flat spot near the spawn: "build a small stone tower with stairs and make it a parkour run: a start pad at the bottom, three coins on the way up and a finish flag on top". Report duration, tokens, ops, refused, warnings; accept it and walk/run it (lane P's play may not be in your tree: a headless replay of the run's rules over a scripted walk is enough to say whether the finish is reachable); captures `c6-ghost.jpg`, `c6-built.jpg` in `docs/shifts/2026-11-27-day/lanes/C6-llm/`. Judge honestly: did it build a course a person can finish?
- Gates per M6-COMMON (the full foreman suite: main had 454/1 load flake in explain.test that passes alone; say which).
