# Lane hud (evening of 19 Nov): a HUD the player customizes in the world creator, designed beyond "first try"

Worktree `.claude/worktrees/e19-hud` (branch `e19-hud`). Time box: 19:20 to 23:00. **Route:** Astra alone designs and
builds the HUD's look, the customizing UI and their code; the look is judged by eye, and Astra won that twice. The Opus
agent operates the lane: it launches Codex (`codex exec -m gpt-6.2-astra -c model_reasoning_effort=high ...`, see
`.claude/skills/shift/SKILL.md` section 3), passes this brief on verbatim, verifies every gate itself (determinism, world =
alone), takes the stills and the clip, and writes the report. It does not direct the design. It may pass back measured
failures, and the owner's bar below.

## The owner's words, verbatim (19 Nov, 19:00)
"Parkour looks great, ability to customize HUD in world creator and improve UI from user perspective would be next step.
LLM itself should try to escape mediocre styling from try one". Also: "Astra usage over plan is not an issue ... if quality
needs it we can spend it".

## What exists
- `engine/kernel/api/tl_hud.gd`: plain labels on 9 anchors, a "stand-in look" (`engine/style/STYLE.md` has no HUD section).
- Parkour's HUD (`engine/packs/parkour/scripts/main.gd`): the stage, the next move, the split and its best, the run time
  and its best, and the finish board.
- The world creator is the workbench, `engine/ui/` (`ui.sh open`, "+ New game", `engine/ui/editor/`), with its own look
  (`engine/ui/editor/look.gd`, `presswork.gd`).

## Goal
1. **Escape mediocre styling on the first try.** Before building, make 2-3 distinct HUD design directions as concept
   boards (Codex image_gen), with a stated idea each. Reject the safe one and say why; build the strongest. The HUD
   becomes part of the house style: a HUD section in `STYLE.md`, and the tokens in `style.json` or `engine/style/hud/`.
   Every pack that uses TLHud gets the new look by default. Hockey's figures do not change; only the picture does.
2. **Customize it in the world creator.** In the workbench, a game's HUD can be arranged by the player: which widgets
   show (for parkour: stage, next move, split and best, run time, checkpoints, the finish board), where they sit, their
   size, and a theme or preset. A live preview shows it. The choice is saved with the game (as data the pack reads; keep
   unknown keys as errors). If a contract would need a new key, propose it in your report; the Director decides.
3. **Improve the UI from the player's view:** what a runner needs at a glance during a run (the next move, the split
   against the best, the checkpoint progress), readable at 1280x720 and 1920x1080, with no clutter.

## Laws
- Presentation only: no game's state hash may move (`world` 8/8, `packs`, parkour's 17+ bots).
- The kernel API change is opt-in or backward compatible, with `KERNEL_API` and `engine/kernel/API.md`.
- Packs use only the TL* API. No hand-made materials, lights or environments.

## Acceptance
- The concept boards, the chosen direction and the rejected ones with their reasons (`concepts/`).
- Before/after stills of parkour's HUD at 1280x720 and 1920x1080 during a run and at the finish, and hockey's HUD after
  the change, with a contact sheet.
- A windowed clip of 30 s or less (`clip-hud.mp4`): the workbench HUD editor changing the layout and theme, then the game
  running with that HUD.
- Selftest cases in blocks 550-559: the saved HUD data is validated (a bad key fails), the layout applies, and the
  hashes are unchanged with and without a custom HUD.
- Gates: `ui.sh selftest`, `--only world,packs`, the fast tier, then the full tier (`perf` alone if it says NOT RUN).

## Scope
`engine/kernel/api/tl_hud.gd`, `engine/kernel/API.md`, `engine/style/STYLE.md`, `engine/style/style.json`,
`engine/style/hud/**`, `engine/ui/**`, `engine/packs/parkour/**`, new `engine/tools/selftest.d/55x-hud-*.sh`, and
`docs/shifts/2026-11-19-evening/lanes/hud/**`.

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
