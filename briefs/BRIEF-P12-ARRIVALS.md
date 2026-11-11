# P12: a game arrives without a hitch, second half

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. The owner is spending a day and a night on perfecting the core before the project spreads into many games,
because every engine change gets more expensive after that. Two rounds have landed today (reports
`docs/reports/P1-*.md` to `P10-*.md`). You are one of three builders of round 3. Each of you owns files; the other two
are changing the engine at the same time in their own worktrees.

## Why this package
Round 2 built the queue (`docs/reports/P5-LOADING.md`): a pack's venue is prepared on a worker thread and attached at
a tick boundary. The frame target was missed. On the 30-game walk the worst frame is still about 360 ms (it was 760
to 840 ms), because everything in `_pack_setup` except the layout still runs on the main thread: 17 to 37 ms for a
layout seed, 75 to 120 ms for `seed_wall`, 165 to 310 ms for the two examples built around a rig, about 600 ms for
the hockey game with its six rigs. The builder named the cause: `TLContext.current` is one static for the process.
The target stands: **in a quiet run of `walk30` no frame over 16.7 ms and no world tick over 8 ms after the first two
frames.** If it cannot be reached, the figure you reached and exactly what stands in the way.

## Read first
1. `docs/reports/P5-LOADING.md`, `engine/kernel/world/PATCHES-P5.md` (entries 2a, 2b, 5 and the asleep-pack item are
   yours), `engine/kernel/world/TIERS.md` section "P5", `engine/kernel/world/jobs.gd`, `pack.gd`, `world.gd`.
2. `engine/kernel/api/tl_context.gd` and every read of `TLContext.current` under `engine/kernel/api`, `engine/kits`,
   `engine/rigs`, `engine/style`; `engine/rigs/RIGS.md`, `engine/kits/tl_kit_layout.gd` (`build_ahead`).
3. `docs/reports/P2-HOTPATH.md` (the tracker; "60 asleep packs" figure), `engine/kernel/api/tl_contact.gd`,
   `tl_bodies.gd`, `docs/PERF.md`, `devx/lib/perf/**`.
4. `docs/reports/P8-PROCESS.md` section on build records (83 to 95 % of a pack's start nodes are kit parts, rigs or
   kernel objects): it tells you how much of a setup is kernel-made.

## Scope
Yours: `engine/kernel/api/**`, `engine/kernel/world/world.gd`, `jobs.gd`, `plotfile.gd`, `tiers.gd`, `tiers.json`,
`TIERS.md`, `WORLD.md`, `engine/kernel/world/pack.gd` EXCEPT `state_hash()` and its helpers (`_q`, `_put_v3`,
`_hash_node`: another builder, P11, replaces them), `engine/rigs/**`, `engine/style/**`, `engine/kits/tl_kit.gd` and
`tl_kit_layout.gd`, `engine/kernel/world/walks/walk30.json` and `queue.json`, `devx/lib/perf/**`, `perf/**`,
`docs/PERF.md`. `engine/tools/selftest.sh`: append your cases in one block at the end, marked `# --- P12 ---`.
Patches file: `engine/kernel/world/PATCHES-P12.md`.
Not yours: `engine/kernel/world/draw/**`, `landscape.gd`, `terrain/**`, `engine/kits/tl_kit_site.gd` (P13);
`draw/view.gd`, `visitor.gd`, `engine/kernel/host/**`, `engine/kernel/runner/**`, `engine/boot/**`, the tools (P11).

## The work, in this order
1. **Measure on the merged tree first.** For each of the seven games of the exe's village: the main-thread
   milliseconds of one arrival, split into what is in it (rigs, kit parts built outside a layout, own bodies, HUD,
   laws, the attach). One table, in `TIERS.md`. It decides the order of what follows.
2. **The queue must not hang on the frame rate, and a game that is needed must be there.** This afternoon's
   verification (`docs/reports/P5-LOADING.md`, "What failed in the re-run") ran the windowed tour in queue mode three
   times: once well, once with the wall game never built inside the run's ticks, once not ending inside 600 seconds.
   At those minutes other windows throttled the frame to about 270 ms. The Director's reading, yours to prove or
   refute: the worker's calls that need the main thread wait one frame each, so preparation time is a multiple of the
   frame time; with vertical sync (the exe) or a throttled window a game then takes seconds to tens of seconds to
   arrive. Reproduce it on purpose (cap the frame rate: 60 Hz, then 4 Hz) and measure prepare time against frame
   time. Then make preparation independent of the frame rate, and give the design its missing answer: when the
   visitor enters a plot, a walk event puts a game on stage, or a tour ends, and that game is not built yet, the
   world finishes that one game now (it jumps the queue and the main thread may block for it, counted and reported),
   never a game that silently is not there. A selftest case for each.
3. **Take the main-thread half down.** The candidates, by what the last builder found; choose by your table:
   a. a context per thread (PATCHES-P5 2a) so that the whole `_pack_setup` runs on the worker and only the attach is
      left; it must be PROVEN that no hash moves (a pack built off the tree enters it in tree order, `_ready` runs at
      the attach): every seed, example and the hockey game, smoke and bots, old hash = new hash;
   b. rigs built ahead like layouts (`TLRig.build_ahead`), the same for kit parts built with `TLKit.build`;
   c. whatever your table shows that neither covers.
   No change to what a pack author writes, and no change to any hash. If a change must alter the order in which
   nodes enter the tree, stop and prove the hashes before going on.
4. **A changed script is seen by a reload** (PATCHES-P5 2b): cache keyed by path and modified time in `ctx.load_script`
   and in `pack.gd`'s loader, entry script and the scripts it loads together. A selftest case: reload after a `.gd`
   changed gives the changed pack's hash.
5. **Asleep packs are cheap again** (the item P5 did not reach): 60 packs whose bodies are all asleep cost 1.33 ms a
   world tick or less in total, hashes unchanged. State what you decided about a pack that wakes a body itself.
6. **Small things the last round found:** a guard for the style's lazily filled tables when two threads write them;
   the Jolt message "job system exceeded the maximum number of jobs" on walk30 (does it predate the queue, what
   limit is it, does anything get lost); `world.gd` `_resolve` finding a game in the folder `games` beside the
   executable (PATCHES-P9 entry 2, the `world.gd` half).
   And two figures of the quiet line taken on the merged round-2 tree (`perf/ledger.jsonl` line 8 against line 6,
   `node devx/bin/tl.mjs perf compare 6 8`): `mix30` worst tick 21.6 ms to 40.0 ms, and `pile600` median 2.45 ms to
   2.69 ms. Find out whether they are real and which package brought them (the queue's step mode, the contact pass
   called by name, the input sampling or the wider hash of P7), by A/B on a quiet machine; fix what is yours.
7. **A quiet figure.** Three builders run tonight instead of six. `node devx/bin/tl.mjs perf run --quiet-only --wait 900`
   for `walk30` and `tour6` at least once after your last change; `perf compare` against the last quiet line.

## Acceptance (the Director will have these re-run)
- The table of item 1 before and after.
- `walk30` and `tour6`: worst frame, frames over 16.7 ms, worst tick, time to the first frame; quiet or stated busy.
- Every seed, example and the hockey game: smoke and bot hashes before = after (the hashes of P7's table).
- World proofs pass (`world.sh tour tour --headless`, `world.sh proof ledger`, the `world.*` selftest cases, in a
  window once on your final code).
- The cases of item 2 (a capped frame rate; a game needed before it is built).
- The reload case of item 4; the asleep figure of item 5.
- `node devx/bin/tl.mjs check --tier full` green.

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

## Lessons of this run that bind you too
- **Every state hash changed once today (P7)** and the kernel API is frozen as version 1.0: `tl arch` rule `api-v1`
  fails when a public member of `kernel/api`, kit, rigs or style is removed or changed, and when one is added without
  a new minor version. If your work adds a public member, regenerate with `node devx/bin/tl.mjs arch --index` as the
  rule's message says and list every added member in your report; the Director settles the version at the merge.
  Do not remove or change a member of version 1.
- Limits count processor time, not wall time (P1). A busy machine does not fail a run; a figure taken on a busy
  machine is still not a quiet figure: say which of your figures are which.
- `captures/` folders are ignored by git. A picture you want kept as evidence: say its full path in the report.
- A file over 600 lines may not grow (`tl arch` size ratchet); new files stay under 600. Split, do not ask for more.
- Windows Git Bash: do not write files through heredocs that contain quotes; use your file-writing tool.
- Schema names of the form `tl.<name>/<n>` in any tracked file, Markdown included, must be declared ones.

## How to work
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p12`** (branch `core-p12-arrivals`, cut from `main` after round 2 landed). Paths in
  this brief are relative to it unless written in full. Never edit the main checkout or another worktree.
- **No git command of any kind.** The Director stages and commits your files.
- **Stay inside your files** (section "Scope"). For anything outside: write the exact patch to your patches file and
  say so in the report. Two builders editing one function is the failure this rule exists for.
- Godot console executable: `export TL_GODOT="C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"`.
  The hockey game built by an LLM last night, used as the real-world test pack (read only):
  `C:/Users/kazda/kiro/third-life/site/ice-hockey-three-against-20261111-1/promoted/game.ice_hockey_three_against@0.1.1`.
- Kill every process you start; never kill others; never leave a window behind (give windows `--position 0,1440`
  where the tool allows). No network. No model calls. Never read, use or print any `ANTHROPIC_KEY_*` variable.
- Never run two engine suites at once. The full gate takes 15 to 25 minutes on this machine tonight.
- Small verified steps. Journal each in `engine/JOURNAL.md` under a section of your package's name (append only).
- **Your measurement outranks this brief.** Where a premise here is wrong, say so with the evidence and build the
  right thing. Round 2's builders each found one such premise.

## Final message (your report, as text; the Director saves it to a file)
Status in three lines; per item: what was built, the command that proves it, the result; the acceptance list one by
one (met / not met / not done, with figures); files changed; proposed contract text; the contents of your patches
file; what changed for a pack author; what you did NOT verify; questions; minutes spent from real timestamps (`date`).
Plain sentences. A miss stated with its figure is worth more than a claim.

## Time-box
Until the list is done or **120 minutes after your start** (run `date` first and often). Work the list in its
order: the first items carry the package. Leave the last twelve minutes for `node devx/bin/tl.mjs check --tier full`
(start it early enough) and the report. A usage limit can cut you off without warning: keep the journal current, and
if you are resumed, re-read this brief and your journal and continue.
