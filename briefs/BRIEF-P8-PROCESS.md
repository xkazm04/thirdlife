# P8: a spike: one game simulated in a second process

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. The owner spends this day and night on **perfecting the core before content spreads it**: every engine change
gets more expensive with each game built. Round 1 landed today: limits that count processor time and a performance
ledger (`docs/PERF.md`, `docs/reports/P1-MEASURE.md`); one contact pass per pack instead of a script per body
(`docs/reports/P2-HOTPATH.md`); a second pass on the look with characters, sky and motion (`docs/reports/P3-LOOK2.md`);
land with relief, plots as terraces and a visitor with a body (`docs/reports/P4-RELIEF.md`). You own one of five
packages of round 2. The night ends with a Windows executable built from the merged result, so leave your part green.

## Why this package exists
A game's code runs inside the game's own process today. Two things the product will want need it elsewhere: sharing
a scripted game with another player safely (the fence is a guardrail, not a boundary: `engine/kernel/share/SHARE.md`
section 1, `docs/SHARING.md` section 5), and playing together with one machine as the authority. The owner chose
"seam now, move later": games stay in process, the boundary is made strict, and **this spike measures what moving
would cost**. It is a measurement and a report. Nothing here is merged into the path the game runs on.

## Read first
1. `docs/SHARING.md` section 5, `engine/kernel/share/SHARE.md` section 1 (what stays reachable for a pack),
   `reports/Living world layering for Third Life.md` sections on multiplayer and on physics spaces.
2. `engine/kernel/world/pack.gd`, `world.gd`, `draw/DRAW.md` (a pack is already simulated at its own origin and drawn
   elsewhere by the draw layer; mirror instances were measured there as candidate B), `engine/kernel/host/host.gd`
   (how a worker process is spawned and supervised), `engine/kernel/host/statehash.gd`, `engine/kernel/API.md`.

## Scope
Yours: new `engine/kernel/proc/**`, new `engine/tools/proc.sh`. Read everything, edit nothing else; what the spike
would need changed elsewhere goes into your patches file as exact text.

## The question, and the experiment
Can a pack run in a second engine process (headless, no window, later restricted) while the first process draws it
and feeds it input, at a cost and a delay a player would accept, without the pack's code knowing?

1. **The smallest version.** Process S loads one seed and ticks it. Each tick it sends the draw state (which nodes
   exist, their transforms, the few properties the picture needs, HUD text, sounds and effects as events) over a
   local channel; process D shows it. D sends input samples to S each tick. Choose the channel by measurement (a
   local TCP or pipe; the engine's own packet classes). The pack is unchanged.
2. **How is the picture rebuilt in D?** A pack builds its visuals through the kit and the kernel (`TLKit`,
   `TLBodies.make`, rigs). Candidates: D runs the same build calls from a recorded build list and then only follows
   transforms; or S describes the scene tree generically and D mirrors it. Say which parts of the kernel API cross
   cleanly, and which do not (anything where a pack holds a node and reads it back: cameras, HUD, particles, a rig's
   animation state, `get_children` on its own nodes). That list is the main result: it is what "the seam" means for
   API v1, and another builder is freezing that API tonight.
3. **Measure:** the delay from a key to the picture, in frames; bytes and milliseconds per tick for the three seeds
   and the hockey game; S's and D's cost per tick against the same pack in one process; what happens when S is slow
   or dies (D must survive it); the state hash of the pack in S against its hash in one process (it must be equal:
   the simulation did not change).
4. **Restriction, on paper.** What the operating system offers to take rights away from S on Windows (a job object,
   a restricted token, an app container; no network, no file access outside a folder), what Godot needs at start that
   such a process would be denied, and what you could not test. Do not weaken anything on this machine to try it.
5. **The answer.** One page, `engine/kernel/proc/PROCESS.md`: can it be done, what it costs per game, what in the
   kernel API must change before it can, and what the owner would be buying. A "no, because" backed by numbers is a
   full result.

## Acceptance (the Director will run these)
- `bash engine/tools/proc.sh run --pack=engine/seeds/seed_paddle` shows the paddle seed played by its bot in one
  process and drawn by another, and prints both processes' figures and the two hashes; one capture of D's window.
- The crossing list of item 2 for the kernel API, class by class.
- The measurements of item 3 in `PROCESS.md`, with the commands.
- Nothing outside your scope changed; no process, port or pipe of yours is left open.
- `node devx/bin/tl.mjs check --tier fast --changed` green in your worktree.

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
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p8`** (branch `core-p8-process`, cut from the merged round 1). Every path in
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
- Small verified steps. Journal each in ``engine/kernel/proc/JOURNAL.md``.
- Contracts (`contracts/**`) are the Director's: write proposed contract text into your report.
- For anything outside your file scope, write the exact patch and its reason to ``engine/kernel/proc/PATCHES-P8.md`` instead of editing.
- **Your measurement outranks this brief.** Where a premise here is wrong, say so with the evidence and build the
  right thing; a fix that makes the measured result worse is withdrawn and documented, not tuned.

## Final message (your report, as text; the Director saves it to a file)
Status; per item what you built and the command, figure or picture that proves it (full paths); the acceptance
checks one by one with their result; the list of files changed with a line each; proposed contract text; the contents
of your patches file; what changed for a pack author; what you did not verify; questions; minutes spent from real
timestamps (`date`).

## Time-box
Until the list is done or **100 minutes after your start** (run `date` first and often). The first items proven
are worth more than all of them half done. Leave the last fifteen minutes for the full gate and the report. A usage
limit can cut you off without warning: keep the journal current, and if you are resumed, re-read this brief and your
journal and continue.
