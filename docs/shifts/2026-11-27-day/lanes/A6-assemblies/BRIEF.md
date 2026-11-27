# Lane A (M6 round 3): assemblies: the LLM places big shapes, the grammar writes the cells

Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-m6-a`, branch `d27-m6-a`, from the integration tip 9ca10076 (branch d27-m6). Opus. Time box ~3.5 h. Selftest blocks 794-796. **Read `../M6-COMMON.md` first** (the lane rules, standups stamped from `date +%H:%M`, keep each file's line endings as in git, do NOT run the uncapped suite: the Director runs it on the merged tree).

## Why
The research (`docs/research/sandbox/THESIS.md`, R1#1-2, R3#2-3): LLMs fail at space, not syntax; the 2026 GDMC winners placed hand-made templates by terrain rules; Townscaper: the player controls the large shapes, the system writes the small ones. Today's real calls place every cell: the tower took 92-106 s and 41k/10-11k tokens for 335-418 blocks (548 ops), and its finish needed jumps at the check's very limits. With assemblies, the model says "a tower 7 wide, 12 high, stairs outside, crenels" and the grammar builds it the same correct way every time: cheaper, faster, walkable by construction.

## Contract
`contracts/BUILD.md` "Assemblies (M6, round 3)" (input-only `assemble`: wall, tower, house, stair, bridge, platform; expanded to `place` ops like `pour` to `flood`; deterministic). Questions go to your report; never change a wire name.

## Do
1. **The expander** `engine/kernel/world/build/assembly.gd` (+ `assembly_kinds.gd` etc.): each kind from the contract as `place` ops in the block grammar (stairs as stair blocks with real steps that the walker climbs, roofs as roof blocks, railings as fences, windows as window blocks, crenels), turned by `rot`, materials `mat` / `trim`; blocks in protected or occupied cells left out with reasons. Every kind must be WALKABLE where it says so: a tower's stairs reach the top with landings, a bridge's steps reach the ground, a stair run's steps are 1 per cell; prove it with the same reachability estimate lane C wrote (`command_space.gd`, read-only) over each kind at 3 sizes.
2. **Wire it as an input op**: `home_build.gd` `INPUT_OPS` gains `"assemble": "blocks"` (you may edit that one line; the blocks layer or a small new layer-side helper gets `expand_input(op)` returning `{"ops": [...]}`/`{"error"}`: choose the cleanest; `blocks_layer.gd` is frozen except a new `expand_input` if you go that way: say so).
3. **Teach the model** (you own the command files and the Foreman this round: `command_*.gd`, `tools/command_tool.gd`, `foreman/src/world_edit*.ts` + tests, `foreman/prompts/world_edit*.md`): the ask offers `assemble` with the kinds; the Foreman checks its shape exactly as the contract (feedback on bad kinds/sizes/mats/opts); the prompt says "prefer assemblies for walls, towers, houses, stairs, bridges and platforms; place single blocks only for details", with one worked example; the prompt grows by at most 2 KB.
4. **The hand gets it too** (the thesis: the hand can do everything the LLM can): a "Shapes" mode in the blocks tool OR a small new tool — you may edit `build_mode.gd` TOOLS and `seam_lists.gd` for a new tool (754/757 must stay green); pick a kind, drag its footprint, the wheel sets the height, [ ] cycles an opt; one batch, a ghost first.
5. **Measure**: ONE real Opus call in a window, the same tower sentence lane C used ("build a small stone tower with stairs and make it a parkour run: a start pad at the bottom, three coins on the way up and a finish flag on top"): duration, tokens, ops, blocks, refused, warnings, and whether the replay finishes with hops of at most 2 m (lane C's tower did not); compare with lane C's two calls (106.2 s / 41.8k+11.6k; 92.5 s / 41.3k+10.1k). And ONE call "a small stone bridge with railings across the stream here" (lane C: 32.2 s, 18.4k+3.3k, 154 blocks). Captures `a6-tower.jpg`, `a6-bridge.jpg`, `a6-shapes-tool.jpg`.

## Acceptance
- `794-home-assembly.sh` -> `HOME assembly ok`: each kind at 3 sizes x 4 rots: deterministic op lists, walkable by the reachability estimate, protected cells left out; the input op expands in `expand_input`; the hand tool's batch.
- foreman `npm test` green with counts (the assemble checks, the feedback).
- The two real calls with their figures and an honest judgement (cheaper? better? walkable?).
- Gates per M6-COMMON: fast, `home.` (build foreman first: `npm run build`), world 9/9.
