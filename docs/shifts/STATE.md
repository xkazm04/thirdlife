# Third Life: shift state

The campaign memory for `/shift` (`.claude/skills/shift/SKILL.md`). Read in full at the start of every shift; the wrap
writes it back. Newest shift-log entry last.

## Now
- Focus (owner, 18 Nov): the game must become playable and fun before anything is measured. The walking figure (look, jump,
  slides, run), camera and terrain immersion, the parkour course, and the minigame editor as the backbone of player-made
  games. Hockey decisions and win measurement deferred; the construction process later.
- Next 3: (1) the owner plays the morning exe (Pip by the road, parkour plot west, walker feel); (2) the editor's design
  direction, judged from the night's mockups and slice; (3) parkour fun pass after the owner plays it.

## Open owner verdicts
- Play exe f871d0c (or tomorrow's): Pip at the start, parkour plot at the west end of the road, `tl play parkour`.
- Walker: A/D sidestep or turn (walker-feel retro).
- The night of 19 Nov's verdict page (asks per lane).

## Backlog (accepted by the owner, not yet scheduled)
- Site Boss modelled in Blender (approved concept, second to Pip; Opus solo).
- Pip as a character with a role (concept: the photo-finish judge; the parkour finish is a natural home).
- A second real Foreman job through the hand checks; the construction process (deferred by the owner).
- ex_car asphalt look (held back 18 Nov: looked worse than grass).

## Decisions
- 2026-11-18: Astra trial routes (memory `project-astra-trial-results`): Opus directing Astra for code/review/tools; Astra
  alone for concept art and look by eye; Opus alone for Blender.
- 2026-11-18: losing trial arms removed on the owner's word; D's and E's parkour code was uncommitted and went with them
  (reports and stills kept in `.spark/Spark/briefs/astra-trial/results/`). Lesson: archive an arm's diff before removing it.
- 2026-11-18 20:40: night of 19 Nov handshake: lanes parkour polish, walker & terrain residue, bug hunt round 2, and the
  minigame editor UI/UX (owner's words in its brief); 3 lanes at once, mixed models; land + push by 08:00; verdict page
  with short videos.

## Shift log

### 2026-11-19 night: plan
Handshake 18 Nov 20:40: lanes parkour (Astra alone), walker (Opus directing Astra), editor (Opus + Astra mockups); hunt2
queued after the first landing. Start 00:03, standups hourly at :47, verdict 07:12, land + push by 08:00, verdict page with
clips. Plan: `docs/shifts/2026-11-19-night/PLAN.md`. Before the shift: `bugfix-37` (one Opus builder, the 37 hunt defects)
lands on main.
- 21:25 pre-shift: bugfix-37 landed (main `120208a`): 35 of 37 fixed, Q24 partly, Q31 deferred to the owner; full gate on
  main 14/14 green (kernel.selftest 219, +39), windowed tour PASS. Owner asks from it: slope jump (D14), camera near
  crowns (D5, three choices), slide hand (Q31); see `docs/reports/bugfix-37/REPORT.md` "For the owner".
- 00:08 launched parkour, walker, editor from c8b88fc (agents recorded in PLAN.md); hunt2 waits for the first landing.
- 00:55 parkour landed (merge `9ea78b0`, Astra alone 16 min, 183 k tokens); hunt2 launched from it.
- 00:47 merged tree after parkour: fast, kit 91/91, packs 34/34, world 8/8, headless tour PASS.
