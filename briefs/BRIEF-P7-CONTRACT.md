# P7: the simulation contract: API v1, recorded input, a hash that covers everything

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. The owner spends this day and night on **perfecting the core before content spreads it**: every engine change
gets more expensive with each game built. Round 1 landed today: limits that count processor time and a performance
ledger (`docs/PERF.md`, `docs/reports/P1-MEASURE.md`); one contact pass per pack instead of a script per body
(`docs/reports/P2-HOTPATH.md`); a second pass on the look with characters, sky and motion (`docs/reports/P3-LOOK2.md`);
land with relief, plots as terraces and a visitor with a body (`docs/reports/P4-RELIEF.md`). You own one of five
packages of round 2. The night ends with a Windows executable built from the merged result, so leave your part green.

## Why this package exists
Four games exist. Forty will exist, written by LLM builders against whatever the kernel offered on the day. Three
things are cheap to settle now and expensive later. (1) The kernel API has no compatibility rule: `kernelApi` is an
exact string, any change to a kernel signature silently breaks packs, and nothing fails when one is removed. (2)
Input is not a record: the kernel polls the keyboard (`engine/kernel/api/tl_input.gd`), the orbit camera reads the
mouse on its own (`tl_orbit_cam.gd`), Esc is polled in the worker, and a bot is code; so a play session cannot be
replayed, a bug a player hits cannot be reproduced, and playing together later has nothing to send. (3) The state
hash leaves out the random generator and the input state, so two runs can differ where the hash cannot see it. The
owner chose "seam now, move later" for where a game's code runs: a game reaches the engine only through the kernel
API and recorded input, so that it can be moved out of the game's process later without rewriting games.

## Read first
1. `engine/kernel/API.md` (all of it: it is the surface you freeze), `docs/generated/API-INDEX.md`, `contracts/PACK.md`,
   `contracts/RUNNER.md`, `engine/kernel/runner/lint.gd` (the fence: what a pack may not touch), `manifest.gd`.
2. `engine/kernel/api/tl_input.gd`, `tl_context.gd`, `tl_orbit_cam.gd`, `engine/kernel/runner/worker.gd`,
   `engine/kernel/host/statehash.gd`, `engine/kernel/world/visitor.gd` (how the live visitor reads keys),
   `engine/ui/PATCHES.md` (entries 1 and 2: keys typed into a field must not reach the game; Esc).
3. `devx/lib/` : how `tl arch` rules are written (data-driven rules, a baseline ratchet, the generated API index).
4. `reports/Living world layering for Third Life.md`, section "Multiplayer stays open if the host is the
   single-player simulation" (the list of decisions that are expensive to reverse).

## Scope
Yours: `engine/kernel/api/tl_input.gd`, `tl_context.gd`, `tl_orbit_cam.gd` (input only),
`engine/kernel/runner/worker.gd`, `manifest.gd`, `lint.gd`, `engine/kernel/host/statehash.gd`, `host.gd` (new verbs
only), `engine/kernel/runner/verbs.json`, `engine/kernel/world/visitor.gd` (input only), `engine/tools/tl.sh`,
`engine/tools/selftest.sh` (new cases), `engine/kernel/API.md`, `devx/**` (the API rule), `docs/generated/**`
(regenerated). Not yours: `engine/kernel/world/world.gd`, `pack.gd`, `tiers.gd`, `draw/**` (other builders),
`engine/kernel/api/tl_contact.gd` and the physics classes, `engine/seeds/**` (if a seed must change for your work,
that is a finding: say exactly why, and put the patch in your patches file), `foreman/**`, `contracts/**`.

## The work, in this order
1. **API v1, written down by a machine.** A generated, checked-in description of every kernel class, method,
   signal, property and constant a pack may use (the index exists: make it the contract), marked version 1.0.
   `kernelApi` in `pack.json` becomes `major.minor`: a pack runs when its major equals the engine's and its minor is
   not greater. A `tl arch` rule fails the gate when a v1 signature is removed or changed without a major bump, and
   says which one; an addition bumps the minor. Prove it with a test tree in which a method lost a parameter.
2. **Input is a record.** Everything a pack reads from a device goes through `ctx.input`, sampled once per tick, and
   every sample that differs from "nothing pressed" is appended to a record: `tl.input/1`,
   `{schema, pack, seed, frames: [[frame, action, value], ...]}`. Mouse motion and wheel for the orbit camera become
   actions like any other (today they bypass the record and can change a game's result through `yaw_basis()`).
   `tl.sh play --record=<file>` writes the record of a session; `tl.sh replay --pack=... --input=<file>` runs it
   headless and prints the state hash. A bot's run can be saved as a record too, and its replay gives the bot's hash.
3. **The hash covers what can differ.** The generator's state and the input state are in the state hash. This
   changes every hash once; the owner accepts a one-time change when it is re-proven: every seed, every example and
   the hockey pack pass all verbs, each new hash is stable three times, the world proofs pass, and your report lists
   old against new. (The hot-path package of round 1 changed no hash; this package may.)
4. **The fence follows the seam.** A pack that reads a device directly, or takes time from anywhere but its tick
   count, already fails lint; check that list against v1 and close what you find (`_process(delta)` used for
   simulation is one known gap). Add what a world needs: a pack must not find another pack's nodes.
5. **Keys and the panel.** Apply `engine/ui/PATCHES.md` entry 1 (a text field that has focus takes the keyboard: the
   game sees no key) and entry 2 (Esc while the panel is open does not end the game), with a test for each.
6. If time remains: the live visitor's keys go through the same record, so a walk a person did can be replayed as a
   scripted walk.

## Acceptance (the Director will run these)
- `node devx/bin/tl.mjs arch` fails on a deliberately broken v1 signature in a test tree and names it; passes on
  the real tree; the API description is generated and stable (two runs, no diff).
- A recorded session replays to the same hash: record the paddle seed's bot run as input, replay it, same hash;
  the same for a session with orbit-camera mouse input injected into the wall seed.
- A pack with `kernelApi` `1.0` runs; `2.0` is refused with a readable message; `0.1` packs (every existing one) are
  either migrated by a one-line change you make in your patches file, or accepted by a stated rule. Say which.
- The old-to-new hash table; all gates; `world.same`, `world.walk_proof`, `world.tour` pass.
- `node devx/bin/tl.mjs check --tier full` green in your worktree.
- Proposed text for `contracts/PACK.md` (the API version rule, `tl.input/1`) and `contracts/RUNNER.md` (`replay`).

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
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p7`** (branch `core-p7-contract`, cut from the merged round 1). Every path in
  this brief is relative to it unless it is written in full. Never edit anything under the main checkout
  `C:\Users\kazda\kiro\third-life` outside your worktree; you may read there (`site/` holds the real jobs' packs
  and is not in your worktree: the hockey game is at
  `C:\Users\kazda\kiro\third-life\site\ice-hockey-three-against-20261111-1\promoted\game.ice_hockey_three_against@0.1.1`).
- **No git command of any kind**, not even a read-only one. The Director stages and commits your files. The `tl` tool
  may call git for you. No test of yours runs git against anything but a temporary repository with `GIT_DIR` unset.
- Godot: `export TL_GODOT="C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"`. Your
  worktree has no `.godot` cache yet: the first engine run builds it. `foreman/node_modules` is linked.
- Gates: `node devx/bin/tl.mjs check --tier fast --changed` while you work; `node devx/bin/tl.mjs check --tier full`
  once at the end. Four other builders run the engine on this machine tonight. Limits now count processor time, so a
  busy machine should no longer fail healthy code: if it still does, that is a finding for your report. Timing figures
  go through `node devx/bin/tl.mjs perf run` where a scenario exists, and you say whether the run was marked quiet.
- Kill every process you start; never kill others; never leave a window behind (windows go to `--position 0,1440`).
  No network. No model calls. Never read, use or print any `ANTHROPIC_KEY_*` variable.
- Small verified steps. Journal each in ``engine/JOURNAL.md` under a "P7" heading`.
- Contracts (`contracts/**`) are the Director's: write proposed contract text into your report.
- For anything outside your file scope, write the exact patch and its reason to ``engine/kernel/api/PATCHES-P7.md`` instead of editing.
- **Your measurement outranks this brief.** Where a premise here is wrong, say so with the evidence and build the
  right thing; a fix that makes the measured result worse is withdrawn and documented, not tuned.

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
