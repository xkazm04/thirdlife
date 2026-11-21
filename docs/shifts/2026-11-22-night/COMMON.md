# Night of 22 Nov 2026: common brief (every lane reads this first)

**Shift:** `2026-11-22-night`. Planned with the owner on 21 Nov at 18:50-19:00, after the day verdict.
- **Base:** main `c7dad86`. It contains:
  - everything from the 21 Nov day;
  - falls arm A merged (`aa82c4f`): `TLHit.react`/`TLHit.down` now fall away from the blow, with directional get-ups;
  - the three research files in `docs/research/`.
- **Times:**
  - land-by 08:00, with a push;
  - lanes stop at 06:30;
  - standups hourly at :17;
  - verdict at 07:15.

## The owner's words (verbatim, 21 Nov ~18:50)

> The games are still mediocre slop. even though improved no real person would play and enjoy the games, because they
> miss quality gameplay elements. Arena mutual reaction on attacks and collision is almost non-existing, we don't need to
> reinvent wheel, there are hundreds of duel games (souls like, for honor duels) with well known game design paths we can
> mimic. We don't have ambition to reach the amount of graphical detail, but regarding gameplay elements and rules our
> engine is much more flexible to reach similar level of choices and creativity. [...] 1. Falls - A authored 2. Colosseum
> retry, we need to research know how first as we lack understanding what's making games popular in videogame history
> 3. Engine 'feel kit' into next shift 4. a) Big puck - add engine call to set radius. 5. Hockey bots and body checks -
> keep it. THe game is unplayable through inbalancing of puck stickiness, players speed, ability AI to decide what to do,
> when to pass and shoot.

> Night shift, start now. Think please also how to use Astra agents, I reset its limit, we can create track for it to put
> world builder in use and grind loops to shape the world in different directions. We still have docs with followups
> regarding the two-world building we should continue with

**His standing bar (memory):**
- a game is judged by a person's hand and eye, not by bot win rates;
- mimic proven genre designs for the rules and the reactions;
- the gameplay depth is the ambition, not the graphics.

## The research (read the one for your lane IN FULL; it is your spec)
- `docs/research/DUEL-PLAYBOOK.md`: Souls / Sekiro / For Honor / Smash duel models, including:
  - the MUTUAL REACTION table (every contact changes both fighters);
  - frame data;
  - the state machine and the interaction matrix;
  - AI tiers and 3 rival archetypes.
- `docs/research/HOCKEY-ARCADE.md`: puck carry as a state with readable loss causes, a speed table, a utility AI for
  pass/shoot/carry, 3v3 roles, and 5 bot metrics.
- `docs/research/WHAT-MADE-GAMES-POPULAR.md`: principles R1-R14, anti-patterns, the 30-item "plays twice" checklist, and
  the "tofu stage".

## The wire (all lanes build against ONE text)
- **The feel kit (N1 owns the kernel side; N2 and N3 consume it).** Proposed names, which N1 may refine:
  - `TLHit.impact(attacker: TLBiped, victim: TLBiped, frames: int)`: hit-stop that freezes BOTH bodies and their rigs for
    `frames`. It is deterministic, counted in frames, and in the hash.
  - Mutual-reaction helpers covering DUEL-PLAYBOOK §6.3:
    - blockstun with pushback, and the attacker's recoil on a blocked heavy;
    - parried (a weapon knock-away pose);
    - clash rebound for both;
    - guard-broken;
    - wall-splat.
    They are built on falls arm A's directional clips and L2's fight clips.
  - A pushbox: bodies of one pack never overlap. They are pushed apart by half the penetration each frame, in a fixed
    order; a stunned body does not push back.
  - The play camera fades what blocks the line to its subject (occluder fade).
  - `TLBall.set_radius(r)`, for the hockey big puck (owner 21 Nov 4a).
- **N1 rules:**
  - N1 lands its API EARLY (target 23:30). It messages the Director with the final names, and the Director tells N2 and N3.
  - Until then, N2 and N3 code against the names above, behind one small adapter file in their pack, so a rename is a
    one-file change.
  - Kernel API additions bump the minor version at merge (the Director settles it).

## Lanes, worktrees, selftest blocks

| Lane | Worktree = branch (`.claude/worktrees/`) | Route | Files it owns | Selftest |
|---|---|---|---|---|
| N1 feel-kit | `n22-kit` | Opus-directed Astra | `engine/kernel/api/tl_hit.gd` and new kernel files for the kit, `engine/kernel/api/tl_biped.gd` (600 cap: split, never grow), `engine/kernel/api/tl_ball.gd`, the camera code in `engine/kernel/**`, `engine/rigs/biped/**` (reaction poses only), `engine/kernel/API.md` (own section) | 710-719 |
| N2 duel-reference | `n22-duel` | Opus | new `engine/packs/duel/**`, new `engine/cards/duel.json` (card text; CARDS.md is a contract: questions to the Director), `docs/research/DUEL-PLAYBOOK.md` (notes only) | 720-729 |
| N3 hockey-play | `n22-hockey` | Opus-directed Astra | `engine/packs/hockey/**` | 730-739 |
| N4 editor-knowhow | `n22-editor` | Opus | `foreman/**`, `docs/GAME-QUALITY.md`, `devx/lib/cards/**` | foreman tests |
| N5 world-chunks | `n22-chunks` | Opus-directed Astra | `engine/kernel/world/landscape.gd`, `engine/kernel/world/terrain/**`, new `engine/kernel/world/land/**`, `engine/kernel/world/WORLD.md` | 740-749 |
| N6 world-directions | `n22-world` (director) + arms `n22-world-a/-b/-c` | Opus director, 3 Astra-solo arms | in the ARM trees only (no arm lands tonight): new `engine/kernel/world/home/**`, its walk/tour files, and `docs/shifts/2026-11-22-night/lanes/N6-world/**` | 750-759 (each arm) |

- A file outside your column is another lane's. Put what you need in `docs/shifts/2026-11-22-night/lanes/<lane>/PATCHES.md`.
- N5 and N6 both live in `engine/kernel/world`, so N6's arms write only to the new `home/` folder and read the rest.

## Calling Codex (Opus directors only)
```
codex exec -m gpt-6.2-astra -c model_reasoning_effort=high --dangerously-bypass-approvals-and-sandbox \
  --skip-git-repo-check -C <worktree> "<brief>" < /dev/null > <worktree>/.tl/codex-<round>.log 2>&1
```
- Always `< /dev/null`.
- Resume by session id, never `--last`.
- Tell Astra "read-only git is fine; do not commit".
- You re-run every gate yourself; Astra's report is a claim.
- Budget: about 0.8 M Astra tokens a lane, 0.8 M per world arm. The owner reset the limit tonight.

## Hard-won rules of the last two shifts (they bind you)
- **ABSOLUTE PATHS ONLY.** Never `cd` inside a backgrounded line, and never write a relative path. A lane wrote into the
  main checkout twice on 21 Nov and blocked a merge.
- **Your own wrapper timeouts stop runs.** A stopped run is not a pass. Run long suites without a wrapper and wait for
  the notification.
- **Run the fast tier after every round.** It catches size caps: `tl_biped.gd` and `lint.gd` sit at 600.
- **On a busy machine, wall-clock checks are not evidence.** That covers the hockey frame budget, the kernel 1800 s cap
  and perf. A/B them against the base and label them busy.
- **Edit tracked JSON by text,** never by re-serialising it.
- **The owner's hand is the bar.** Play what you change in a window, and leave clips of 20 s or less.


# Pasted verbatim: CLAUDE.md "Laws that bite"
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

The overlay `.claude/spark/config.md` (`## Gates`, `## Repo law`) binds you; read it in the main checkout.


# Pasted verbatim: Lane rules

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
