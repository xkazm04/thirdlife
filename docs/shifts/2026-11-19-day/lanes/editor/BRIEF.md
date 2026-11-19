# Lane editor (day of 19 Nov): the contracts in code, then the editor that places games with care

Worktree `.claude/worktrees/d19-editor` (branch `d19-editor`). Time box: about 08:55 to 16:45. **Route:** Opus directing
Astra. You read, decide and write each round's brief; Astra builds through `codex exec`, as in
`.claude/skills/shift/SKILL.md` § 3. You verify every claim and re-run every gate. Small fixes you make yourself.

## The owner's words (19 Nov, 08:20)
- E1: "it is right direction, but needs more care for LLM to pick positioning, pathing in the map, good fit in the map.
  As player develops the requirements in the builder, the map representation should change with it."
- E2: "Approve all". The contract text is already written: `contracts/CARDS.md` "Interview and footprint (added
  2026-11-19)" and `contracts/JOB.md` "Added 2026-11-19". Read both first. Contracts stay Director-only: propose any
  change in your report.

What exists: the editor from last night (`engine/ui/editor/`, with `docs/shifts/2026-11-19-night/lanes/editor/DESIGN.md`
and `REPORT.md`) and `site.gd` `draft_lot()`.

## Part 1, by about 11:30: E2 in code
1. Move each `engine/ui/interview/<card>.json` into its card (`engine/cards/<card>.json`, keys `interview` and `footprint`).
   `none.json` stays in the UI. The editor reads the questions from the card. `tl cards check` validates the new keys as
   CARDS.md says (shape, `propose` is one of its options, option ids unique), with a devx test that fails before the
   change.
2. In foreman: `foreman new --answers <json> --lot <json>` writes `job_created.answers` and `lot`, and
   `foreman change --decision <json>` writes `change_requested.decision`. Each value is validated, and a bad value is an
   error. The job-log readers accept the keys: foreman, `engine/ui/job_model.gd`, and
   `engine/kernel/world/site/event_schema.gd`. Add foreman tests.
3. The editor passes answers, lot and decision through those flags. `site.gd` builds a game on `job_created.lot` first,
   then falls back to the draft file. Extend `site.editor_lot` to cover both.

## Part 2, until about 16:30: E1, placement the LLM takes care over
The Director's design decisions (the owner is away; record any you overturn, with the reason):
- **Who proposes the lot.** "Find a place" in the workbench asks the Designer, through the Foreman's existing model door,
  for 2-3 lot proposals. Each proposal gives position, yaw, the path from the road to the gate, and a one-line reason
  in the player's terms ("beside the parkour yard, gate on the road, 40 m from the river").
  - A **deterministic fit scorer** in the editor model checks each proposal and ranks the valid ones, scored on
    overlap, river, road, slope under the footprint, path length and neighbour spacing. The scorer is the judge; the
    LLM never places anything unchecked.
  - Offline and in tests, the fake adapter returns fixed proposals. The fallback is today's free-spot search.
- **Pathing.** Draw the path from the road to the gate on the map, and in the world: a path strip that `landscape.gd`
  already knows how to draw for a lot, or a request to the blend lane via the Director.
- **The map follows the requirements.** Each answer changes what is drawn, live: footprint size and shape, stands,
  spectators' area, the entrance, the path, and the clearance ring. The score and its reasons update as the player
  answers. Show "why here" for the chosen lot.
- **Do not own the ring and terrain look.** Making constructions blend into the terrain is the `blend` lane. Your lot
  shape data (footprint polygon, yaw) is its input; agree the shape through the Director if needed.

## Acceptance
- Part 1:
  - `tl cards check` passes on the moved interviews and fails on a bad `propose`.
  - The foreman tests cover all three flags.
  - A job made in the editor has `answers` and `lot` in its log, and its game rises there in the village (selftest
    500-509).
- Part 2:
  - A driven session (input events only): idea → answers change the map → "Find a place" shows ranked proposals with
    reasons → place → Build it.
  - Selftest cases for the scorer: river, overlap, slope, and that the order of the proposals is deterministic.
- Clips of 30 s or less: `clip-place.mp4` (the map changing as answers change, then the proposals) and, if reached,
  `clip-village.mp4`.
- Gates: `ui.sh selftest` and the drives, `tl cards check`, foreman typecheck and tests, `--only world,packs`, and the
  fast tier. Run the full gate before you say done.

## Scope
`engine/ui/**`, `engine/tools/ui.sh`, `foreman/**`, `engine/cards/**`, `devx/lib/commands/cards*`, `devx/lib/cards/**`,
`devx/test/cards*`, `engine/kernel/world/site.gd`, `engine/kernel/world/site/**`, new
`engine/tools/selftest.d/50x-editor-*.sh`, and `docs/shifts/2026-11-19-day/lanes/editor/**`.

---

# Lane rules (pasted verbatim into every lane brief)

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
