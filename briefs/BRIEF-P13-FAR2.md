# P13: the far picture in motion, and what the land costs

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. The owner is spending a day and a night on perfecting the core before the project spreads into many games,
because every engine change gets more expensive after that. Two rounds have landed today (reports
`docs/reports/P1-*.md` to `P10-*.md`). You are one of three builders of round 3. Each of you owns files; the other two
are changing the engine at the same time in their own worktrees.

## Why this package
Round 2 gave far games life (`docs/reports/P6-FAR.md`): beyond the sideline a game is a merged picture of its venue
plus a mark per moving body, its smoke and its real score. Four things are open, and one is new from the loading
package: (1) nobody has seen it MOVE: every picture was a still, the change between the middle and the far picture
was never watched; (2) the marks are boxes that step at the game's sliced tick rate, and they are crude where a
small sideline lets the middle picture come close; (3) both pictures of a game are built in the frame in which it
first goes far (about 160 ms) and are thrown away at the end of the run; (4) the land: no soft ground, the village is
spread thin against the concept image; and (5) the landscape is now the whole time to the first frame: 2.1 s for six
games, 6.1 s for thirty (`docs/reports/P5-LOADING.md`).

## Read first
1. `docs/reports/P6-FAR.md`, `engine/kernel/world/draw/FAR.md`, `DRAW.md`, `PATCHES-P6.md`, the four `draw*.gd`.
2. `docs/reports/P5-LOADING.md` (acceptance 2 and patches 3 and 4), `engine/kernel/world/landscape.gd`,
   `terrain/**`, `docs/reports/P4-RELIEF.md`.
3. `engine/boot/PATCHES-P9.md` entry 5 (`edge_height` takes meshes that are not terrain),
   `engine/kits/tl_kit_site.gd` (`add_scoreboard`), `engine/kits/KIT.md`.
4. The concept image the look is measured against, as it appears in `docs/reports/img/p6_overview_vs_concept.jpg`.

## Scope
Yours: `engine/kernel/world/draw/draw.gd`, `draw_base.gd`, `draw_pictures.gd`, `draw_life.gd`, `FAR.md`, `DRAW.md`,
`far_study.mjs`, `far_cost.sh`, `engine/kernel/world/landscape.gd`, `engine/kernel/world/terrain/**`,
`engine/kits/tl_kit_site.gd`, `engine/kits/KIT.md`, new walk files under `engine/kernel/world/walks/` (do not edit
existing ones: other builders' proofs run on them). `engine/tools/selftest.sh`: append your cases in one block at the
end, marked `# --- P13 ---`. Patches file: `engine/kernel/world/draw/PATCHES-P13.md`.
In `engine/kernel/world/draw/view.gd` (another builder's, P11) you may change ONLY the place where the landscape is
built and stepped, and only if item 5 needs it; mark the lines `# P13`. Everything else there goes to your patches file.
Not yours: `world.gd`, `pack.gd`, `jobs.gd`, `tiers.*`, `engine/kernel/api/**`, rigs, style, the other kit files (P12);
`visitor.gd`, host, runner, boot, tools (P11).

## The work, in this order
1. **See it move.** A tool that renders a short run of consecutive frames (for example 90 frames of a camera
   approaching a game from 320 m to 180 m, across the middle-to-far threshold, and 90 frames standing still at
   260 m while the game plays) and writes a contact sheet and a small video with ffmpeg. Look at them. Write down
   what pops, shimmers or stutters. This decides items 2 and 3.
2. **Marks that read as the game.** They move smoothly between the game's ticks (the Director's decision: a far
   picture is a picture, drawn every frame from the last two known positions; it never feeds back into the game).
   A figure's mark is a slim figure and not a box where it is larger than about 12 pixels. The middle picture at a
   30 m sideline is acceptable to look at.
3. **The change between pictures does not pop.** Whatever item 1 shows: a cross-fade over a few frames, a wider
   margin, or matching the two pictures' tone. State the rule in `FAR.md`.
4. **Pictures are built off the frame and kept.** Built on a worker or sliced under a budget of 2 ms a frame; cached
   on disk under the user data folder by the hash of the pack's directory, so a plot whose game is not built yet
   shows its last known picture instead of an empty pad (PATCHES-P5 entry 4). A holder with no pack is refused a far
   tier. Figure: the worst frame at the moment a game first goes far, before and after.
5. **The land's cost.** Measure where the 2.1 s and 6.1 s go. Then: build what the first view needs first and the
   rest over the following frames under a budget, or on a worker, or from a cache keyed by the walk's landscape
   block; your measurement decides. Target: time from the world's start to the first frame under 1 s for six games
   and under 1.5 s for thirty, with no frame over 16.7 ms while the rest arrives. The visitor must never stand on
   ground that has no collider yet.
6. **The land's look.** Soft ground patches (worn earth, darker grass, flowers: low and cheap), and one new walk
   file with a more compact village of the same seven games (plots closer, roads shorter, the hockey plot at its
   natural radius once `edge_height` reads only terrain sheets). Overview from the crane beside the concept image,
   and one frame from the visitor's eye. Trees do not stand in front of a fixed camera of an existing walk.
7. **The scoreboard part tells the truth alone too** (PATCHES-P6 entry 3): the kit's scoreboard can be bound to the
   pack's rules so that a single-pack run shows the real score. This adds to the kit's public surface: see the
   lesson about API version 1 below. No hash may move for a pack that does not use it.

## Acceptance (the Director will have these re-run and will look at the pictures)
- The contact sheets and videos of item 1, before and after items 2 and 3, with their full paths.
- The drawing check passes with unchanged hashes:
  `bash engine/tools/view.sh check --packs=seed_drive,seed_paddle,seed_wall,<hockey dir> --standins=auto --far=60`
  (take the full form from `draw/JOURNAL.md`); the hashes are P7's new ones, the same drawn and headless.
- `bash engine/tools/world.sh tour tour --headless` and in a window: proof passes.
- The cost table of `far_cost.sh` for 6, 12 and 30 games: not worse than P6's in draw calls and primitives.
- Time to the first frame for six and thirty games, before and after; worst frame while the land arrives.
- The overview beside the concept image, looked at, with what is still wrong.
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
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p13`** (branch `core-p13-far2`, cut from `main` after round 2 landed). Paths in
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
