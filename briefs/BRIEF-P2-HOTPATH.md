# P2: the kernel's physics hot path

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. Last night the kernel learned to hold many packs in one process, each in its own physics space and on its own
clock; a scheduler gives each pack ticks by tier (stage, sideline, backdrop, ledger); a drawing layer shows every pack
at its plot; a village landscape and a walking visitor exist; a real job built a hockey game from one sentence. The
owner now spends a day and a night on **perfecting the core before content spreads it**: every engine change gets more
expensive with each game built. You own one of four packages of round 1.

## Why this package exists
Simulation, not drawing, is what limits how many games run at full speed, and more than half of an active game's
cost is the kernel's own script, not the physics engine. Every dynamic body a pack makes through `TLBodies.make`
carries a `TLContact` child with its own `_physics_process` and a ray query per tick
(`engine/kernel/api/tl_contact.gd`). Measured last night (`engine/kernel/world/BENCH.md`, `TIERS.md`): 300 sleeping
boxes cost 2.21 ms a tick before a three-line early return and 0.16 ms after, so about 7 microseconds per awake body
per tick go to that script; one pack with 600 awake bodies costs 7.45 ms a tick; 50, 150, 300 bodies cost 0.64, 1.74,
3.78 ms. Jolt itself handles such counts in a fraction of that.

## Read first
1. `engine/kernel/world/BENCH.md` (test 1 and tests 2 and 3), `engine/kernel/world/TIERS.md` (item 1: sleeping
   bodies), `docs/reports/N2-MANY.md`.
2. `engine/kernel/api/tl_contact.gd`, `tl_bodies.gd`, `tl_laws.gd`, `tl_damage.gd`, `tl_trigger.gd`, `tl_ball.gd`,
   `tl_fracture.gd`, `tl_context.gd`; `engine/kernel/API.md` sections 3 to 5 and 19; `contracts/PACK.md`.
3. How a pack is ticked in a world: `engine/kernel/world/pack.gd`, `world.gd` (read only).

## Scope
Yours: `engine/kernel/api/tl_contact.gd`, `tl_bodies.gd`, `tl_laws.gd`, `tl_damage.gd`, `tl_trigger.gd`, `tl_ball.gd`,
`tl_fracture.gd`, `tl_spawner.gd`, `engine/kernel/world/packs/**` (bench packs), the physics sections of
`engine/kernel/API.md`, `engine/tools/selftest.sh` (only where a case prints or checks a hash that you change).
Not yours: `engine/kernel/runner/**`, `engine/kernel/host/**`, `engine/kernel/world/*.gd` (other builders change them
today), `tl_input.gd`, `tl_context.gd` beyond what a batched pass needs (say exactly what you added), seeds, kits,
rigs, style.

## The work, in this order
1. **Profile first.** Where do the 7.45 ms of a 600-body pack go: the per-body script, its ray query, signals,
   `TLLaws` lookups, Jolt's own step, the scene tree's transform sync? Give a table before you change anything. Use
   `bash engine/tools/world.sh run --packs=w_pile --seeds=600 --frames=400` and variants of the bench pack of your own.
2. **One pass per pack instead of a script per body.** Whatever the profile says is the cost, the target shape is: the
   pack's context owns the list of tracked bodies and does the contact, surface and law work in one loop per tick,
   called by the kernel in a fixed order (the order must be stable: it is part of determinism), with queries only
   where a body's situation changed. Consider reading contacts from the physics server instead of casting a ray per
   body; consider skipping bodies that did not move. Keep every public kernel call a pack uses today working
   (`TLBodies.make`, `TLContact` signals such as `hit`, `TLDamage`, `TLTrigger`): the seeds, the examples and the
   hockey pack must run unchanged.
3. **Determinism re-proven.** State hashes may change once because of this package; that is accepted by the owner.
   Then: every seed, every example and the hockey pack
   (`C:\Users\kazda\kiro\third-life\site\ice-hockey-three-against-20261111-1\promoted\game.ice_hockey_three_against@0.1.1`)
   pass all verbs; each new hash is the same three times; `invariants.bot_deterministic` holds; the world proofs
   hold (`world.same`, `world.sliced_and_paused`, `world.walk_proof`, `world.tour`): a pack in a world still equals
   itself alone. Give a table old hash, new hash, per pack and verb. If a bot that finished before no longer
   finishes, the change altered play, not only order: find out why before keeping it.
4. **The numbers.** 50, 150, 300, 600 awake bodies before and after; 10, 30, 60 asleep packs before and after; the
   three seeds per tick before and after; the tour's world tick before and after. Say which were taken under load.
5. If the script-level rewrite does not reach the target, say what a native extension would buy and what it would
   cost (toolchain on this machine, build, export); do not start one in this package.

## Acceptance (the Director will run these)
- One pack with 600 awake bodies costs at most 2.5 ms a tick (7.45 ms today), same command, quiet machine or the
  figure with its load stated; 300 bodies at most 1.3 ms.
- `bash engine/tools/tl.sh selftest`, `bash engine/tools/tl.sh seeds`, `bash engine/tools/k.sh selftest` pass.
- The hockey pack passes lint, smoke, invariants and both bots on your engine; the player's bot still wins.
- The old-to-new hash table, each new hash stable three times.
- `node devx/bin/tl.mjs check --tier full` green in your worktree.
- If the target is not reached: the profile, what was tried, what was withdrawn, and the honest figure.

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
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p2`** (branch `core-p2-hotpath`, cut from `main` this morning). Every path in
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
- Small verified steps. Journal each in ``engine/JOURNAL.md` under a "P2" heading`.
- Contracts (`contracts/**`) are the Director's: write proposed contract text into your report, do not edit them.
- For anything outside your file scope, write the exact patch and its reason to ``engine/kernel/api/PATCHES-P2.md`` instead of editing.
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
