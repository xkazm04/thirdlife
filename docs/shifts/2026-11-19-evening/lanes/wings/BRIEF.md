# Lane wings (evening of 19 Nov): wings summoned by magic, not worn

Worktree `.claude/worktrees/e19-wings` (branch `e19-wings`). Time box: 19:20 to 23:00. **Route:** Astra alone designs and
builds the summon and dismiss look; the look is judged by eye, and Astra won that twice. The Opus agent operates the
lane: it launches Codex (`codex exec -m gpt-6.2-astra -c model_reasoning_effort=high ...`, see
`.claude/skills/shift/SKILL.md` section 3), passes this brief on verbatim, verifies every gate itself, takes the stills
and the clip, and writes the report. It does not direct the design. It may pass back measured failures only.

## The owner's words, verbatim (19 Nov, 19:00)
"Flight: looks great, I would remove the wings by default and rather use key binding and 'magical' animation to summon the
wings or dismiss". Also: "Astra usage over plan is not an issue ... if quality needs it we can spend it".

## The Director's design decisions (the owner may overturn them on the verdict)
- **Default:** no wings on the figure while it walks: not drawn, and nothing on its back.
- **Summon:** F, the flight key, summons the wings with a magical animation, then flight starts as today. Astra designs
  the magic: motes or light assembling the frame, a glyph, a shimmer, all in the toon house look. It must read as
  magic, not as a pop or a fade. About 0.5-0.8 s; the take-off may wait for it.
- **Dismiss:** landing folds the wings, then they dismiss with the matching magic. F in the air dismisses them and you
  fall, as today.
- **Same for packs:** a pack biped that flies (TLBiped fly) gets the same summon and dismiss.
- **Presentation only:** no state hash moves. The figures of flight (5 x, the 1 s acceleration, the 120 m ceiling) and
  the `flight.*` / `moves.*` cases stay as they are. If the summon delays the take-off, name the ticks, and move a case's
  expectation only with the reason.
- **Look law:** use the style layer (TLStyle, TLVfx, its shaders). No hand-made lights or environments. A new shader goes in
  `engine/style/shaders/`, through the style layer.

## Acceptance
- A windowed clip of 20 s or less (`clip-summon.mp4`): walk without wings, press F, the summon, fly, land, the dismiss.
- Stills: a contact sheet of the summon frames and the dismiss frames, close up and in the world (from the road).
- A permanent case in blocks 540-549: no wings drawn before the first F and after a dismiss; wings fully shown at the
  end of the summon; the summon and dismiss are deterministic (same frames, same pose).
- Gates: `flight.` and `moves.` selftests, `--only world,packs`, the fast tier, then the full tier (`perf` alone if it
  says NOT RUN). Counts never below main's.

## Scope
`engine/kernel/world/flight_wings.gd`, `engine/kernel/world/visitor.gd`, `engine/kernel/api/tl_biped.gd` (the wings part
only), `engine/kernel/api/tl_vfx.gd`, `engine/kernel/api/tl_vfx_node.gd`, `engine/style/tl_style_fx.gd`,
`engine/style/shaders/**`, `assets/**`, new `engine/tools/selftest.d/54x-wings-*.sh`, and
`docs/shifts/2026-11-19-evening/lanes/wings/**`. `engine/kernel/API.md` belongs to the hud lane tonight: if an API line is
needed, put it in your report and the Director adds it.

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
