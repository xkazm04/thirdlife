# P4: land with relief, and a visitor with a body

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. Last night the kernel learned to hold many packs in one process, each in its own physics space and on its own
clock; a scheduler gives each pack ticks by tier (stage, sideline, backdrop, ledger); a drawing layer shows every pack
at its plot; a village landscape and a walking visitor exist; a real job built a hockey game from one sentence. The
owner now spends a day and a night on **perfecting the core before content spreads it**: every engine change gets more
expensive with each game built. You own one of four packages of round 1.

## Why this package exists
The village built last night is flat: discs on a plain, a dirt road, fences, a forest belt, stacked mesas far away
(`docs/reports/img/n7_village_overview.jpg`, `n7_village_vs_concept.jpg`). The concept
(`spike/lab/ref/B_toon_ink.png`) lives on relief: a rink on a terrace above a track that winds below a cliff, a cabin
on a rise, a river and a bridge behind, rock faces between everything. The owner ruled that the land between venues
belongs to the world, so relief is the world's job, and it changes how plots are placed, which is cheaper to change
before more games exist. The visitor who walks this world has no body: he hovers at a dipped plot's rim and walks
through fences and trees (`docs/reports/N7-WORLD.md`, "still wrong").

## Read first
1. Look first: the concept; `docs/reports/img/n7_village_overview.jpg`, `n7_visitor_at_track.jpg`,
   `C:\Users\kazda\kiro\third-life\engine\kernel\world\captures\tour\` (the ten tour frames, main checkout).
2. `engine/kernel/world/WORLD.md` (start with the owner's rulings at its head), `draw/DRAW.md` (how a pack is drawn at
   its plot: the offset in the shaders, the plot cut, the lift to the world's ground, the bent rim),
   `docs/reports/N7-WORLD.md`, `docs/reports/N5B-DRAW.md`.
3. `engine/kernel/world/landscape.gd`, `visitor.gd`, `world.gd`, `draw/draw.gd`, `walks/tour.json`,
   `engine/kits/tl_kit_terrain.gd` and the nature parts, `engine/tools/world.sh`, `engine/tools/view.sh`.

## Scope
Yours: `engine/kernel/world/landscape.gd`, `visitor.gd`, new `engine/kernel/world/terrain/**`, the plot placement
part of `engine/kernel/world/draw/draw.gd` (lift, rim, cut: keep to it, the build paths are another package's
tonight), the visitor part of `engine/kernel/world/world.gd` (another builder adds a watchdog to that file today:
keep your edit in the visitor's functions), `engine/kernel/world/walks/**`, `engine/kits/tl_kit_terrain.gd` and the
nature parts, `engine/tools/world.sh`, `engine/tools/view.sh`, `engine/kernel/world/WORLD.md`,
`engine/kernel/world/captures/**`. Not yours: `engine/style/**` and the other kit parts (the look builder), every
`engine/kernel/api/**` file, `tiers.gd`, `pack.gd`, `engine/kernel/runner/**`.

## Laws of this world that you must keep
- A pack is simulated at its own origin in its own physics space and drawn at its plot. The land never touches a
  pack's simulation: with your land in place every pack's state hash equals its headless hash
  (`bash engine/tools/view.sh check ...`) and the tour proof passes (`bash engine/tools/world.sh tour tour --headless`
  and in a window).
- A far game runs slower and is never switched off; an ended game stays over (`tiers.json`); how games start is not
  yours to design.

## The work, in this order
1. **The world's ground has height.** A terrain of its own for the village (a few hundred metres across is enough):
   rolling ground, at least one cliff or rock face and one low valley, in the style (the kit's terrain shading and
   strata). Built once; its cost and build time measured (N5a measured that a seed's own forest and far terrain were
   87 to 95 percent of its loading time: do not repeat that at world scale).
2. **Plots as terraces.** Each plot sits on the land at its own height: the ground is cut or filled to a level pad
   under it with a drawn bank, a retaining wall or a rock edge, so a venue reads as a place set into the land and not
   as a disc. The plot's own pack ground meets the pad without a seam or a black rim line (the line is visible in
   last night's pictures 04 and 06). Plots may stand at different heights; the concept's rink stands above its track.
3. **Roads on the ground.** The dirt road follows the terrain with a spur and a gate to every plot.
4. **Water.** One river or pond in the valley with the style's water material, and a bridge where the road crosses.
5. **A body for the visitor and a space for the world.** The visitor is a kernel-owned character with a collider in
   a physics space that belongs to the world: he walks on the terrain, stops at fences, trees, rocks and walls, and
   inside a plot stands on that plot's ground. A pack's bodies live in another space and must stay untouched: find a
   clean way to give the visitor the venue's static ground and walls (a collider built once from the pack's static
   geometry in the world's space is one candidate) and say what you chose. The scripted tour still drives him by
   positions; with a body he must end where the script says or the walk is adjusted.
6. **Scatter with sense.** Trees, rocks and bushes follow the land (tree lines on ridges, rocks on banks, none on
   the road, none inside a plot), fewer and better placed rather than more.
7. **Pictures.** Under `engine/kernel/world/captures/p4/`: the overview you would put beside the concept and the two
   side by side; the visitor at eye level on a slope with a venue above or below him; the tour's ten frames again;
   one from a stage pack looking out at the land.

## Acceptance (the Director will run these and look)
- `bash engine/tools/world.sh tour tour --headless` and the windowed tour pass: every pack equals itself alone and
  the replay; `bash engine/tools/view.sh check ...` (the command in `WORLD.md`) passes.
- The visitor does not pass through a fence, a tree or a wall on a walk you script for that purpose, and his feet
  are on the ground on a slope and inside a dipped plot (pictures).
- World cost in the tour before and after: tick and frame medians and the worst frame; landscape build time.
- The pictures of item 7, each looked at, with an honest list of what is still wrong against the concept.
- `node devx/bin/tl.mjs check --tier full` green in your worktree.

## The repository's laws (verbatim from `CLAUDE.md`; they bind you)

## Laws that bite (details in the contracts)

- **Time is physics frames** (60 Hz). Tests, bots, captures, watchdogs count frames, never wall clock.
- **Determinism**: same pack + seed + frames = same `state_hash`. Randomness only from the kernel's seeded generator.
- **Unknown keys are errors** in every JSON schema. **Absent value = omit the key** (never `null`, never `0`).
- **Lists, not singletons** for anything a game may have more than one of.
- **Class names**: `TL*` belongs to the kernel except `TLKit`, `TLRig`, `TLStyle`, `TLMesh` (kit/rigs/style). Packs never declare `class_name`.
- **Packs use only the `TL*` API.** No hand-made materials, lights, environments (the runner counts them as bypasses). Look in `engine/kits/KIT.md` before making a mesh.
- **kit, rigs, style reference nothing outside themselves.**
- **Reuse before building**: kit part, seed pack, `engine/kernel/API.md` (generated index: `docs/generated/API-INDEX.md`).
- Windows 11 + Git Bash. Godot console exe via `TL_GODOT` or `.tl/local.json` (`tl doctor` says what it found). Other sessions load this machine: never kill a process you did not start; prefer `--headless`.

## How to work
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p4`** (branch `core-p4-relief`, cut from `main` this morning). Every path in
  this brief is relative to it unless it is written in full. Never edit anything under the main checkout
  `C:\Users\kazda\kiro\third-life` outside your worktree; you may read there (`site/` holds the real jobs' packs
  and is not in your worktree).
- **No git command of any kind.** The Director stages and commits your files. The `tl` tool may call git for you;
  that is fine. Do not run git yourself, and make sure no test of yours runs git against anything but a temporary
  repository with `GIT_DIR` unset.
- Godot: `export TL_GODOT="C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"`. Your
  worktree has no `.godot` cache yet: the first engine run builds it.
- Gates: `node devx/bin/tl.mjs check --tier fast --changed` while you work; `node devx/bin/tl.mjs check --tier full`
  once at the end. Three other builders and other sessions run Godot on this machine today: a failure that is only a
  time limit is re-run alone before you believe it, and you say which figures were taken under load.
- Kill every process you start; never kill others; never leave a window behind (windows go to `--position 0,1440`;
  an orphan window there slowed every later capture for 43 minutes last night). No network. No model calls. Never
  read, use or print any `ANTHROPIC_KEY_*` variable.
- Small verified steps. Journal each in ``engine/JOURNAL.md` under a "P4" heading`.
- Contracts (`contracts/**`) are the Director's: write proposed contract text into your report, do not edit them.
- For anything outside your file scope, write the exact patch and its reason to ``engine/kernel/world/PATCHES-P4.md`` instead of editing.
- **Your measurement outranks this brief.** Where a premise here is wrong, say so with the evidence and build the
  right thing; do not guess and do not tune a fix that makes the measured result worse: withdraw it and say so.

## Final message (your report, as text; the Director saves it to a file)
Status; per item what you built and the command, figure or picture that proves it (full paths); the acceptance
checks one by one with their result; the list of files changed with a line each; proposed contract text; the contents
of your patches file; what changed for a pack author; what you did not verify; questions; minutes spent from real
timestamps (`date`).

## Time-box
Until the list is done or **110 minutes after your start** (run `date` first and often). The first items proven
are worth more than all of them half done. Leave the last fifteen minutes for the full gate and the report. A usage
limit can cut you off without warning: keep the journal current, and if you are resumed, re-read this brief and your
journal and continue.
