# Day of 21 Nov 2026: common brief (every lane reads this first)

**Shift:** `2026-11-21-day`. Planned with the owner on 21 Nov, 10:00-11:00, through the spark `game-quality-bar`.
- **The whole design** (every decision, every rejected option, three scout digests and the brief):
  `.spark/Spark/ideas/game-quality-bar.md`. It is in the MAIN checkout
  (`C:/Users/kazda/kiro/third-life/.spark/Spark/ideas/game-quality-bar.md`) and not tracked: read it there, ALL of it.
- **Base:** main `df58f0b`, which is:
  - last night's five lanes;
  - the contract `contracts/JOB.md` "Added 2026-11-21: the design room and the quality loop";
  - the kernel stub `TLHit` (API 1.12).
- **Thirdjam,** the reference hockey game: a read-only clone at
  `C:/Users/kazda/AppData/Local/Temp/claude/0251139bc1345a0c/73d79642-7e1a-48cb-be9d-365e23bb89ae/scratchpad/ref/thirdjam`.
  - Unreal C++: `Game/Source/JamCore/Private/JamSim.cpp` and `Public/JamCartridge.h`.
  - Design docs: `docs/VISION.md`, `docs/HOCKEY.md`, `docs/experiments/{BOOSTS,ABILITIES,NEON}.md`, `contracts/RULINGS.md`.
  - Its git index is broken; read the files.
- **Times:**
  - Lanes stop at 18:30 at a clean point; the Director lands by 19:00 and pushes.
  - The colosseum proof re-run starts when L1 lands.
  - Standups hourly at :17.

## The owner's words (verbatim, 21 Nov morning, after last night's verdict)

> Crisp looks well, continue with opne items during this day to harden. The mini games do look and play horrible, you
> ignored all notes I passed before to the game quality and design we need to achieve via the prompt and thought process
> changes, there is no reason why would anyone be entertained by playing these games. a) For hockey try to look at
> mechanics thirdjam has: tackle, movement balance, crosschecks, failing physics and animations, puck sticking to the
> player. For crazy modes there are in thirdjam for inspiration neon areana, boosts like a shotgun or speed boosts. For
> arena there are no skill/playstyle design, reactivity on hits, movement roll. Editor should never produce slop like
> this, we need to give the projects care like it is a real standalone game we need to design and market.

**His earlier notes, which the pipeline dropped** (from the scout; every lane keeps them in view):
- animations are part of the design (10 Nov);
- raw tackles, random boosts on ice (speed, shooting precision), neon art (12 Nov);
- physics and animation around collisions, with the sim rule and the figure's reaction designed together (13 Nov);
- hits obey inertia against stability; skill in movement and stick control, not speed stats (13 Nov, R-0045);
- the cross-check is shown by the player's animation, never by a technical rectangle; the puck is controlled by the
  player (15 Nov);
- his hand is the bar (15 Nov): judge as a person meets it;
- "LLM itself should try to escape mediocre styling from try one" (19 Nov).

## What the owner decided today

- **Scope:** all four tracks: the editor quality system, a fight-animation kit, hockey thirdjam mechanics, hockey crazy
  modes with neon. Plus crisp hardening.
- **Critic:** a NOT ok verdict gets up to 2 revise rounds, keeping the better version; still NOT ok, the job holds for
  the owner.
- **Falls:** three Astra arms experiment in parallel (authored clips; clips plus a physics blend; active ragdoll). They
  share a hit lab, and the owner picks by eye. No arm lands today.
- **Editor:** a 3-step design room (concept with 5 candidates; a game design doc with a feel sheet; a producer review).
  The feel sheet reaches every builder.
- **Proof:** "a fight in a colosseum", standard and crazy, re-run on the merged tree beside last night's.

## The wire contract (all lanes build against ONE text)

- `contracts/JOB.md` "Added 2026-11-21: the design room and the quality loop" (L1 implements it; the Director owns it).
- **`TLHit` (`engine/kernel/api/tl_hit.gd`, `engine/kernel/API.md` §6):**
  - `TLHit.react(who: TLBiped, from_dir: Vector3, strength: float)`;
  - `TLHit.down(who: TLBiped, frames: int, from_dir := Vector3.ZERO)`.
  - `from_dir` points from the victim toward the blow. `strength` is about 0.3 a tap, 0.7 solid, 1.2 and up big.
  - Packs (L4, L5) call these for every hit. The falls arms (L3) replace the bodies; the signatures stay.
- **New biped clips (L2 owns `engine/rigs/**`):** `strike`, `strike_heavy`, `block`, `roll`, `dodge`, `body_check`,
  `cross_check`, `taunt`, and the rig property `stick_yaw` (radians). They are played with `rig.play(&"<name>")` as
  today (RIGS.md).
  - Until L2 lands they do not exist on main. A pack checks before it plays:
    `rig.has_method("clips") and (rig.call("clips") as PackedStringArray).has("strike")`. That is the same check
    `TLBiped._rig_has` uses.

## Lanes, worktrees, selftest blocks

| Lane | Worktree (`.claude/worktrees/`) = branch | Route | Files it owns | Selftest |
|---|---|---|---|---|
| L1 editor-quality | `n21d-editor` | Opus | `foreman/**`, `devx/lib/cards/**`, `engine/cards/**`, `engine/ui/job_model.gd`, `engine/ui/job_v2.gd`, `engine/kernel/world/site/event_schema.gd`, the capture path of `engine/kernel/runner/**` (strips only), new `docs/GAME-QUALITY.md` | foreman tests |
| L2 fight-clips | `n21d-clips` | Opus | `engine/rigs/**` | 660-669 |
| L3 falls (director + 3 Astra arms) | `n21d-falls`, arms `n21d-falls-a/-b/-c` | Opus director, Astra arms | in the ARM trees only: `engine/kernel/api/tl_hit.gd`, `engine/rigs/biped/**`, `engine/kernel/api/tl_biped.gd` (it sits at the 600-line cap: split, never grow), new `engine/rigs/review/hit_lab.*` | 670-679 (each arm) |
| L4 hockey-mechanics | `n21d-hockey` | Opus-directed Astra | `engine/packs/hockey/**` except L5's files | 680-689 |
| L5 hockey-crazy | `n21d-crazy` | Opus-directed Astra | `engine/packs/hockey/scripts/{boosts,abilities}.gd`, `scripts/modes.gd`, `data/boosts.json`, `data/modes/**`, `scripts/look.gd` and `scripts/fx/**` (neon only); `main.gd` wiring goes to L4 through your PATCHES.md | 690-699 |
| L6 crisp-harden | `n21d-harden` | Opus | `engine/kernel/world/**` (not `site/event_schema.gd`), `engine/kits/**` | 700-709 |

A file outside your column is another lane's: put what you need from it in
`docs/shifts/2026-11-21-day/lanes/<lane>/PATCHES.md`, and the Director lands it. `engine/kernel/API.md` is shared:
append-only, in your own section. The hockey pack is shared by L4 and L5, so name every file you touch in your STANDUP.

**Calling Codex (L3, L4 and L5 are Opus directors who build through Astra):**

```
codex exec -m gpt-6.2-astra -c model_reasoning_effort=high --dangerously-bypass-approvals-and-sandbox \
  --skip-git-repo-check -C <worktree> "<brief>" < /dev/null > <worktree>/.tl/codex-<round>.log 2>&1
```

- Always use `< /dev/null`. Resume by the session id printed in its log, never `--last` (several lanes run at once).
- Tell Astra "read-only git is fine; do not commit".
- You re-run every gate yourself and re-grade every claim: Astra's report is a claim, not a proof.
- Astra verifies only what its change needs; you run the suites.
- Budget: about 800 k Astra tokens a lane (3 arms: about 800 k each). Say your spend in the standup.


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

# Pasted verbatim: .claude/spark/config.md `## Gates` and `## Repo law`

Read them in the main checkout (`C:/Users/kazda/kiro/third-life/.claude/spark/config.md`); they bind you.
Three of them matter most today:
- Run the fast tier on your tree after every round, not only at the end. Last night a lane's late round broke the
  600-line size budget at merge.
- On a busy machine, wall-clock checks (hockey `invariants.many_budget`, the kernel suite's 1800 s cap, perf) are not
  evidence either way. Label them busy and A/B them against the base.
- Edit tracked JSON by text, never by re-serialising it (re-serialising turned 7.0 into 7 across a whole file).


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
