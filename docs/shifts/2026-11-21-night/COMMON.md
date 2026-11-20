# Night of 21 Nov 2026: common brief (every lane reads this first)

**Shift:** `2026-11-21-night`. Planned with the owner on 20 Nov, 19:40-20:05, through the spark `designer-and-two-worlds`.
- The whole design, with every decision and the rejected options: `.spark/Spark/ideas/designer-and-two-worlds.md`. That
  file is in the MAIN checkout (`C:/Users/kazda/kiro/third-life/.spark/...`, not tracked); read it there.
- **Base:** main `3a4580b`, which is:
  - crisp cel merged (`516f637`, d20-cel `8df936a`; crisp is the default look);
  - the assets manifest re-scan (`5144deb`);
  - the contract wire text (`3a4580b`).
- **Land-by:** the Director lands and pushes by 08:00. Lanes stop at 06:30 at a clean point.

## The owner's words (verbatim, the spark)

> Plan for this night's run, besides hardening and bugfixing of our new decided graphical engine Crisp cel for its
> physics, objects collisions handling, I have two major game design topics to develop:
>
> 1. Minigames are there physically, but not designed to be actually playable and fun
> - example: game design of thirdjam vs our hockey design (camera, ai, gameplay mechanics). The main potential of this
>   project is having powerful LLM to create content not possible with traditional sandboxes, yet our prompts and thought
>   processes for content designs stick to principles like Minecraft or Roblox
> - world designer should be robust enough to create quality games and game design proposals for user, user can then
>   quickly decide or use custom detailed input to talk about the solution. Designer's LLM always tries to create the
>   most fun output to entertain the player via
>   a) Wow effect: surprising how deeply player can design a game through one-shot vague idea
>   b) Levels of creativity: standard level working towards best current player goal, but also 'crazy' mode on top of
>      user prompts, putting creative and unexpected game design mechanisms into the plan
>   c) Multi-phases construction: each plan has multiple phases, player can go to construction side, check/try results
>      of each phase, let it pass or stop/pause and give more instructions to the builder
>   d) Game design breakdown in the designer: express key game aspects on a very high level so player can react to each,
>      without text overload. UX feasible for a 10 yo with vague needs, but masterable by 30-50 yo building
>      sophisticated games and levels
> 2. Two worlds principle
> - Main world (as-is): pure sandbox, tycoon-like, player is god/creator shaping environment open-ended, invites friends,
>   populates with AI characters. Challenge: building elements + layering architecture so the area can expand 100x.
> - Dungeons: standalone game levels and unique mechanics mutually unaffected with the main world. Enter via menu first;
>   player and interface transform to the game's shape (hockey arena, colosseum, racing circuit); play alone or share.
>   Designer may adopt main-world physics, but experience and graphics are open to model within the engine.

## What the owner decided (waves 1-3)

**Designer**
- The designer v2 is built tonight: a fun lens, LLM-chosen aspect cards (3-7), Standard/Crazy creativity, and LLM-chosen
  phases (2-5) that the player tries and passes.
- Every phase stops for the player by default; there is a run-through switch.
- The designer lives on a full-screen Create page in a new main menu, not inside the world.

**Dungeons**
- A dungeon is its own scene. The world is unloaded, and the dungeon brings its own avatar, camera, HUD and look.
- Hockey is the first dungeon, with a hand-made fun pass. The owner re-opened hockey for this; it replaces the 18 Nov
  "defer hockey" rule here.

**Crisp cel hardening**
- Rails, sign and fences become real bodies.
- Collision regression tests.
- Per-part kit colliders.
- The site fence follows the footprint.

**The night itself**
- Five Opus lanes.
- The Director runs two real proof jobs, standard vs crazy, and writes `docs/TWO-WORLDS.md`.

## The wire contract (all lanes build against ONE text)

Read these sections first. Where a lane needs a contract change, the question goes in its report; never edit `contracts/*`.
- `contracts/JOB.md` "Added 2026-11-20: the designer v2": `creativity`, `run_through`, `pitch`, `aspects`, `icon` enum,
  `aspect_reacted`, `plan_set.phases`, `phase_done`, `phase_reviewed`, and the commands `react`, `redesign` and `phase`.
- `contracts/CARDS.md`: the `fun` block.

**Launch seam (L4 owns the code; L3 calls it).** `--dungeon=<pack dir>` is a boot flag. It opens any pack dir as a
dungeon, a WIP job's pack included: `<job dir>/pack`.

**Dungeon list (L4 owns the file).** `engine/boot/dungeons.json` holds
`{"schema":"tl.dungeons/1","dungeons":[{"pack","title","look"?}]}`. `pack` is a path relative to `engine/`; `look` is a
`TL_STYLE` name, and when absent the dungeon takes the default.

**Menu seam (L4 owns the menu; L3 owns the Create scene).** The main menu mounts `res://ui/create/create.tscn`. Its root
node has `func open() -> void` and emits `signal closed`. Until L3 lands, L4 mounts it only if the file exists, and shows
"Create (coming tonight)" otherwise.

**Try-it seam (L3 calls, L4 implements).** For v1, Create's "Try it" starts a second game process with
`--dungeon=<job dir>/pack` (the same exe or Godot binary that is running, via `OS.create_process`). That process shows a
"Back to Create" exit and quits. An in-process switch is L4's choice, made later; if L4 adds one, it writes the call in its
STANDUP and the Director wires it at landing.

## Lanes, worktrees, selftest blocks

| Lane | Worktree (`.claude/worktrees/`) | Branch | Files it owns | Selftest block |
|---|---|---|---|---|
| L1 crisp-harden | `n21-harden` | `n21-harden` | `engine/kits/**`, `engine/kernel/world/terrain/**`, `engine/kernel/world/site/draw.gd`, `engine/kernel/world/landscape.gd`, `engine/style/**`, `engine/kernel/world/WORLD.md` | 620-629 |
| L2 designer-foreman | `n21-designer` | `n21-designer` | `foreman/**`, `engine/cards/**`, `devx/lib/**` (only `tl cards check` for `fun`) | none (foreman tests) |
| L3 create-screen | `n21-create` | `n21-create` | `engine/ui/**`, `engine/kernel/world/site/event_schema.gd`, `engine/kernel/world/site.gd` | 630-639 |
| L4 dungeons-menu | `n21-dungeon` | `n21-dungeon` | `engine/boot/**`, new `engine/kernel/dungeon/**`, `engine/kernel/runner/**` (only what the dungeon needs), `engine/tools/world.sh` and `export.sh` flags | 640-649 |
| L5 hockey-fun | `n21-hockey` | `n21-hockey` | `engine/packs/hockey/**` | 650-659 |

A file outside your column is another lane's: put what you need from it in
`docs/shifts/2026-11-21-night/lanes/<lane>/PATCHES.md`, and the Director lands it. `engine/kernel/API.md` is shared:
append-only, in your own section.


# Pasted verbatim: CLAUDE.md

## Laws that bite (details in the contracts)

- **Time is physics frames** (60 Hz). Tests, bots, captures, watchdogs count frames, never wall clock.
- **Determinism**: same pack + seed + frames = same `state_hash`. Randomness only from the kernel's seeded generator.
- **Unknown keys are errors** in every JSON schema. **Absent value = omit the key** (never `null`, never `0`).
- **Lists, not singletons** for anything a game may have more than one of.
- **Class names**: `TL*` belongs to the kernel except `TLKit`, `TLRig`, `TLStyle`, `TLMesh` (kit/rigs/style). Packs never declare `class_name`.
- **Packs use only the `TL*` API.** No hand-made materials, lights, environments (the runner counts them as bypasses). Look in `engine/kits/KIT.md` before making a mesh.
- **kit, rigs, style reference nothing outside themselves.**
- **Reuse before building**: kit part, seed pack, `engine/kernel/API.md` (generated index: `docs/generated/API-INDEX.md`).
- **A game in a world plays as it does alone.** `tl check --tier full` includes `world`: every game of `engine/boot/games.json` played in one world must hash as it does alone (about 2 minutes). A kernel query asks the pack's own physics space (`TLContext.space_state_of`), never the viewport's.
- **A stopped run is never a pass.** A gate step reports found and completed; found 0, fewer completed, a timeout or a kill is never PASS; "could not run" is exit 2 (`docs/GATE-HONESTY.md`).
- **A bot with a perfect hand measures the game, not the player.** Quote a difficulty figure with the hand it was read through (`TLHand`: perfect, sharp, regular, newcomer; `tl ladder`).
- **Never hand a worktree with a junction to `git worktree remove`** (it follows the link and empties the target): `tl trees remove` unlinks links first.
- Windows 11 + Git Bash. Godot console exe via `TL_GODOT` or `.tl/local.json` (`tl doctor` says what it found). Other sessions load this machine: never kill a process you did not start; prefer `--headless`.

## Working in parallel with other sessions

The checkout is shared with other Claude sessions (a visual-look session and the Foreman night plan have used it). Rules:
1. Run `git status` first; foreign uncommitted files are never yours: stage per file, never `git add -A`, never stash.
2. Claim a scope in `.claude/sessions.json` (see `docs/OWNERSHIP.md`) and keep inside it; `tl arch` fails on overlapping claims.
3. Multi-file work goes in a worktree: `git worktree add .claude/worktrees/<name> -b <branch> main`.
4. Never edit a contract (`contracts/*`) from a builder role; put the question in your report.


# Pasted verbatim: .claude/spark/config.md

## Gates
- always: `node devx/bin/tl.mjs check --tier fast`
- when engine/kernel, kits, rigs, style or seeds changed: `node devx/bin/tl.mjs check --tier full`
- builder: `node devx/bin/tl.mjs check --tier fast --changed`
- before a merge to `main`, on the merged tree: the full gate, `bash engine/tools/world.sh tour tour --headless`,
  the same tour in a window, `bash engine/tools/world.sh alone --packs=<the exe's games> --mode=bot --frames=20000`
  (a game in the world hashes as it does alone), `bash engine/tools/export.sh --commit <sha>` and
  `bash engine/tools/export.sh check`. In the main checkout only: `node devx/bin/tl.mjs check --tier full --only
  item.selftest,ui.selftest` (they need last night's job under `site/` and are skipped in a worktree).
- a performance figure counts only from `node devx/bin/tl.mjs perf run --quiet-only --wait <s>`; a figure taken
  while builders run is labelled busy and decides nothing.

- the pre-merge list, as it runs since 2026-11-16: the full gate now holds `world` (every game of `engine/boot/games.json` in one
  world = alone; it replaced the hand-run `world.sh alone`); the tour in a window is `bash engine/tools/world.sh tour tour
  --out-dir=<abs dir>` (without `--out-dir` it exits 2). Run the WHOLE list on the first merged tree of a night, not at the end:
  a kernel fault of 03:31 was found by it at 05:39.
- a worktree runs the whole full gate after `npm ci` in its `foreman/` and plain copies (no links) of
  `site/marble-run-three-marbles-20261110-1` and `-2` into its `site/`; with only one of the two, a devx ledger test fails.
- a win-or-lose test enters the gate only after its verdict held on 20 of 20 seeds (two of tonight's were coins: 10 and 19 of 20);
  a difficulty figure comes from `tl ladder` and is quoted with the hand profile and the seed count.

- before committing a builder's new directory: `git check-ignore -v <dir>/<a file>`; an ignore pattern for job output
  (`/site/`) once hid `engine/kernel/world/site/` and the commit would have dropped the site's code silently.

## Repo law
Read CLAUDE.md "Laws that bite" and paste it verbatim into every builder brief. Walls: contracts/* are Director-only;
other sessions' uncommitted files are never touched; worktree for multi-file work; stage per file.
Builders run no git command of any kind (the Director stages and commits); a test may run git only against a temporary
repository with `GIT_DIR` unset. Scripts and briefs with quoted passages are written to a file with the Write tool and
run from there, never as a bash heredoc (the trap was hit three times on 2026-11-11).
Dispatch by tier (owner's rule, 2026-11-11): development packages to `model: "opus"` builders, re-runs of checks to
`model: "sonnet"` verifiers given a fixed, numbered command list with expected values and the instruction to report
what was printed; the Director writes briefs, reads results, looks at the pictures and decides. A verifier is told:
one step at a time, one repeat on failure, never explain a failure away.
Parallel builders get disjoint FILES, named in each brief with who owns the neighbours; what sits between them goes
to a patches file, and a last single-builder package owns the seam (P14 of the core run closed what three parallel
builders each had to leave). Each builder picks an unused number for `engine/tools/selftest.d/NNN-<lane-or-topic>.sh`
and puts its cases there. Close every shell construct in that file. The selftest runner discovers blocks in sort order.
The kernel API is versioned (`tl arch` rule `api-v1`): a builder that adds a public member says so; the Director
settles the version on the merged tree. `tl.sh` takes the pack as `--pack=<dir>`.

A lane's state lives on disk, never only in the agent: every lane writes `status/<lane>.md` as it goes, so a Director restart (13:23 on 2026-11-13 lost three
running lanes; 02:00 the same night lost the dispatch for seven hours) resumes a lane from its worktree and its status file with a new agent, and the Director's
chain scripts live in files (`land.sh`, `export.sh`), not in a shell's memory.

Since 2026-11-16 a lane's status file is `docs/reports/<slug>/<lane>.md` in its worktree (not a top-level `status/`); stills
stay out of git (a table in a README and one sheet under 1 MB are committed; the rest is copied to the vault). A number in a
brief is a thing to measure, and the brief says so: builders corrected three of the Director's premises that night (a hash that
could not stay, a blade at 3.0 m not 1.9, a tolerance needing 100 seeds). A second builder on a pack another builder is in gets
its own worktree and a list of files it stays out of: five such merges were clean. A kernel helper that asks the physics
world asks the pack's own space (`TLContext.space_state_of`), and anything new in the kernel is proven in a world, not only alone.


# Pasted verbatim: Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/<shift>/lanes/<lane>/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
  when the lane lands).
- Append one line at each milestone and at least every 60 minutes of work:
  `HH:MM | state: working|blocked|done|cut | did: <one line> | next: <one line> | gates: <last PASS/FAIL line or ->`
- `blocked` names the question in the same line. Then keep working on whatever the block does not touch.
- When you finish, write `REPORT.txt` beside it (the harness refuses agent writes to files named REPORT.md), return the
  full report as your final message too, and set the last standup line to `done`.

## Honesty
- Evidence or it is not done: a gate line, a test count, a still, a video, a repro before and after.
- A stopped run is never a pass. NOT RUN is not PASS. Fewer tests completed than on main is a stopped run.
- Unmeasured is not zero. Never fake a frame, a figure or a hash.
- A behaviour change that moves a test expectation is named, with why. Never loosen a test to make it pass.
- What the player sees or feels is judged as a person meets it (a window, the exported game), not only headless.

## Laws (CLAUDE.md)
- Work only in your worktree. No git that writes (read-only `git diff`/`git status` are fine). The Director lands.
- Never kill a process you did not start. Prefer `--headless`. Build the class cache once: `"$G" --headless --path engine --import`.
- Time is physics frames; determinism (same pack + seed + frames = same state_hash); unknown keys are errors; packs use only
  the TL* API and never declare class_name; kit, rigs, style reference nothing outside themselves.
- Contracts (`contracts/*`) are Director-only: put the question in your report.
- New selftest cases go in your own `engine/tools/selftest.d/NNN-<name>.sh` files, numbered inside the block range your brief
  assigns (two lanes once collided on 360).
- Raw captures (frame folders, long or uncompressed clips, mkv/avi) stay under `.tl/` in your worktree. The lane folder
  gets only sheets, notes, JPG stills and mp4 clips of 30 s or less.
- A kernel API addition updates `engine/kernel/API.md`; the Director regenerates docs on main (`tl arch --index`).
- Gates before `done`: `node devx/bin/tl.mjs check --tier fast`; when kernel, kits, rigs, style or seeds changed, also
  `node devx/bin/tl.mjs check --tier full` (perf alone if it says NOT RUN).

## REPORT.md
- Outcome against each acceptance criterion: met / not met, with its evidence.
- Gates with PASS/FAIL lines and counts.
- Changed files; behaviour changes; anything the owner should look at, and how.
- Questions for the Director; the next three things this lane would do.
