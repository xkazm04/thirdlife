# Lane editor: the minigame editor's UI/UX, as the backbone of player-made games (night of 19 Nov)

Shift `2026-11-19-night`, lane `editor`. Worktree `.claude/worktrees/n19-editor` (branch `n19-editor`). Time box 00:00-07:00.
Route: **Opus designs and builds; Astra alone draws the mockups.** Astra won the owner's eye for concept art in the trial,
and Opus directing Astra's art made it worse. So give Astra the problem and the constraints, not a picture, and show its
raw output.

## The owner's words, verbatim (18 Nov 20:40)
"UI/UX of minigame editor. It has very static and mediocre format for tooling which should be backbone for thoughtful
minigames and worldbuilding of player's game. Games like hockey, arena rpg games, or advanced parkour/puzzle gmaes like
Takeshi's castle. It will have need very good clarity and thought how to present information and extract needs from user,
and how to size and place the constructions in the world"

## What exists (read it first)
- The designer panel `engine/ui/` (panel.gd, sheet.gd, host.gd, job_model.gd, foreman_door.gd; history in
  `engine/ui/JOURNAL.md`): a job list and a sheet (brief, build, change, tune, notes), built in code, with colours from
  `engine/style/style.json`. `engine/tools/ui.sh` opens it, captures it (`shot`), self-tests it and drives it (`live`).
- Jobs: `contracts/JOB.md`. Recipe cards: `contracts/CARDS.md` and `engine/cards/`, one card per kind of game, saying
  what a builder must be told. The construction site in the village: `engine/kernel/world/site/` (a lot shows a job; the
  finished game arrives playable on its plot).

## Goal: three parts, in this order
1. **Design** (`lanes/editor/DESIGN.md`, by 02:30). First judge today's panel screen by screen, with captures. Then design
   the editor a player needs to make hockey, an arena RPG, or a Takeshi's Castle obstacle game:
   - how it draws out what the player wants (an interview shaped by the recipe cards, not a blank text box);
   - how it presents a game in progress: what is decided, what is open, what the builder is doing;
   - how it sizes and places the construction on a plot in the world: footprint, scale against the 2 m walker,
     neighbours, the road.

   Cover the information architecture, the flows, and every empty, waiting and error state. Query the registry
   (`registry_query`) for UX patterns before inventing your own.
2. **Mockups.** Astra alone (`codex exec`, image_gen) draws the 3-4 key screens, working from DESIGN.md's problem
   statement and the house look (`engine/style/STYLE.md`, stills of the village). Keep its raw images and its prompts in
   `lanes/editor/mockups/`. If you disagree with a mockup, say so in the report; do not redraw it.
3. **First slice, built** (Godot, in `engine/ui/`). Build the one flow that moves the owner's needle most. That is your
   call, argued in DESIGN.md; it is likely the needs interview from a card plus the size and placement preview on a site
   lot. It must work, be captured, and be driven by input events the way `ui.sh live` does; `ui.sh selftest` stays green.

## Acceptance
- DESIGN.md; the mockups; a contact sheet of the slice's captures in `lanes/editor/stills/`; a clip of at most 30 s of the
  slice in use, in a window (`lanes/editor/clip.mp4`).
- `bash engine/tools/ui.sh selftest` and `node devx/bin/tl.mjs check --tier fast` PASS. Run the full gate if you touched
  anything outside `engine/ui/`.
- Contracts (JOB.md, CARDS.md) are Director-only: any change they need goes into the report as a proposal.

## Scope
`engine/ui/**`, `engine/tools/ui.sh`, `docs/design/editor/**` (if you keep a durable copy), `docs/shifts/2026-11-19-night/lanes/editor/**`.

---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/<shift>/lanes/<lane>/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
  when the lane lands).
- Append one line at each milestone and at least every 60 minutes of work:
  `HH:MM | state: working|blocked|done|cut | did: <one line> | next: <one line> | gates: <last PASS/FAIL line or ->`
- `blocked` names the question in the same line. Then keep working on whatever the block does not touch.
- When you finish, write `REPORT.md` beside it (below) and set the last standup line to `done`.

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
- New selftest cases go in your own `engine/tools/selftest.d/NNN-<name>.sh` file.
- A kernel API addition updates `engine/kernel/API.md`; the Director regenerates docs on main (`tl arch --index`).
- Gates before `done`: `node devx/bin/tl.mjs check --tier fast`; when kernel, kits, rigs, style or seeds changed, also
  `node devx/bin/tl.mjs check --tier full` (perf alone if it says NOT RUN).

## REPORT.md
- Outcome against each acceptance criterion: met / not met, with its evidence.
- Gates with PASS/FAIL lines and counts.
- Changed files; behaviour changes; anything the owner should look at, and how.
- Questions for the Director; the next three things this lane would do.
