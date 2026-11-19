LANE hud / evening shift 19 Nov 2026 / REPORT (Opus operator; builder and designer: Astra, gpt-6.2-astra, high)
Worktree .claude/worktrees/e19-hud, branch e19-hud, from main 2950f03. Nothing committed (the Director lands).
Verdict: LANDABLE. Every gate passes on the final tree. Every state hash I could compare matches the 2950f03 baseline.

WHAT WAS BUILT
- Split Ticket, a house HUD look. It takes its shapes from race bibs and timing slips: a numbered stage tab, the next
  move on its own clipped paper ticket, the split on ink with the previous best and a signed delta chip under it
  (green when faster, red when slower, FIRST on a first split), checkpoint count plus punches, a keycap controls
  legend, and a finish docket with stage / split / best columns and the personal best. There are three themes
  (Signal red, Relay blue, Night meet) and three sizes (0.82x, 1x, 1.22x). The code is in engine/style/hud/
  (stock.gd = inks and type, layout.gd = validation, sheet.gd = fit and stacking, ticket.gd = drawing). The Archivo
  font and its OFL licence moved there from engine/ui/editor/fonts/, so the workbench and the HUD share one face.
  STYLE.md has a new HUD section.
- TLHud (kernel API 1.10 -> 1.11, opt-in, additions only): configure_widgets(catalog, layout), set_readout(id,
  reading), set_phase(run|finish). The existing add_score/clock/speed/label/bound and set_plate calls keep their
  signatures and data sources; they now draw in the house type and plates. That is why every TLHud pack (hockey
  included) gets the new look by default. If the style module is absent, the HUD falls back to plain labels.
- Parkour declares its HUD in data/hud-widgets.json (the author's catalogue: 7 widgets) and reads the player's choices
  from data/hud.json (theme, plus per-widget visible / anchor / size overrides). Unknown keys are errors: the pack
  refuses the file and smoke fails with "unknown key '...'". Absent means default; no nulls are written.
- The workbench has a HUD workshop. A button opens it from the village board header, the workbench and a promoted
  game's sheet. You can show or hide each widget, place it by drag or on a 9-cell grid, set Small / Regular / Large,
  and pick a theme. The live preview shows the HUD over a course still for During run and At finish. Save layout
  writes data/hud.json atomically and refuses a file changed on disk. Save & play opens the game with that layout.

ACCEPTANCE (each one checked by me unless marked otherwise)
1. Concept boards, the choice and the rejection: MET. concepts/split-ticket.jpg (chosen) and concepts/glass-rail.jpg
   (rejected: the safe one, a smoked-glass broadcast strip) were made with image_gen before any code. DECISION.md
   gives the reasons: on Glass Rail the next move weighs the same as five other readings, and the strip breaks once
   a widget is moved. PROMPTS.txt has the generation briefs. Astra made 2 boards; the brief asked for 2-3.
2. Before/after stills: MET. stills/contact-sheet.jpg pairs the before and after captures in 6 rows: parkour at
   1280x720 and 1920x1080 at run frame 520 and finish frame 987, and hockey at frame 1500 at both resolutions. All
   are capture --hud=on on the real bots, seed 1. The single JPGs are in stills/. stills/after-splits-crops.jpg shows
   the delta chip on bot_splits: frame 1770 is 04.73 against best 04.77, -00.03, green; frame 1490 is 06.97 against
   05.63, +01.33, red.
   Hockey shows the same figures (BLUE 1, RED 0, 00:11 P1, Level: Rookie | Mode: Three against three); only the
   picture changed.
3. Windowed clip: MET. clip-hud.mp4: 16.70 s, 1280x720, 501 frames, 12 MB (strip: clip-hud-strip.jpg).
   - I recorded it with Godot Movie Maker from real windows (--write-movie, --fixed-fps 30).
   - Part 1, the workshop: scripted mouse input (ui/editor/hud/drive.gd, launched with --hud-pack on a scratch copy
     of parkour). It drags Next move to bottom centre, sets Large, picks Relay blue and hides Controls. The log says
     "saved take: PASS" and the saved hud.json holds exactly those 4 choices.
   - Part 2: the game runs from that saved copy with bot_course, using that HUD. 0 errors.
   - Caveat: the clip opens the workshop directly, not by clicking through the village. That path is covered by
     selftest hud550.editor_save.
4. Selftest cases in block 550: MET. engine/tools/selftest.d/550-hud-layout.sh adds 6 cases:
   - editor_save (real workbench input saves to a copy)
   - strict_data
   - layout_applies
   - village_clearance
   - state_hash (bot_course: default layout = custom layout = f7abac006a45bd43...@988)
   - bad_key (a pack with an unknown hud.json key fails smoke)
   They are counted in kernel.selftest: 323, up from 317 on main.
5. Goal 3, readable at a glance: MET after round 2.
   - Round 1 measured (my 4x crops at 720p): the split's best and delta and the checkpoint count were 9 px cap height,
     captions 7.5-8 px, punches 7 px. I passed back only these measurements and the XAG 101 floor.
   - Round 2 (Astra's measurement at native 720p, consistent with my crops):
     - next move 20 px
     - split 23 px
     - previous best 16 px
     - delta 17 px
     - checkpoint count 18 px
     - captions and keycaps 12 px
     - punches 12 px
     - hockey status 24 px
   - At 1080p everything scales uniformly. Before this lane, the 1080p HUD was half the size it was at 720p (see the
     contact sheet).

GATES (all my own runs, on the final tree, with fingerprints in .tl/final-tree.sha1)
- node devx/bin/tl.mjs check --tier full: 14/14 steps, 1197/1197 units, exit 1 ONLY because arch and devx.test ran
  before the Director allowed me to regenerate the indexes (see below). Every other step passed:
  PASS foreman.typecheck; PASS foreman.test [223/223] 217 pass, 0 fail, 6 skipped; PASS kernel.selftest [323/323];
  PASS kit.selftest [95/95]; PASS packs [2/2] verb runs 48 of 48; PASS perf [2/2] mix30, pile600 within tolerance
  (machine quiet: use 9%); PASS seeds [39/39]; PASS item.selftest [91/91]; PASS ui.selftest [166/166];
  PASS world [8/8] world = alone; PASS assets [4/4]; PASS cards [3/3].
- After `tl arch --index` in the worktree, run as the Director allowed at 21:10:
  `tl check --tier fast` exit 0: PASS arch [12/12], PASS assets [4/4], PASS cards [3/3],
  PASS devx.test [229/229] 229 pass, 0 fail, PASS foreman.typecheck.
  The API-V1 change is three additions only (configure_widgets, set_phase, set_readout) plus the version.
- Hashes against the pristine 2950f03 baseline (taken from a git-archive copy at the start of the lane):
  - world + packs: 56 units (8 world rows, 48 pack verb runs), each with full state hash and frame count. IDENTICAL.
  - Parkour, 18 bots x seeds 1 and 2 = 36 runs, default layout: IDENTICAL (64-hex hash, outcome and frames).
  - Parkour, the same 36 runs with the clip's custom layout (relay, next bottom large, controls hidden): IDENTICAL.
- ui.sh selftest is the ui.selftest step: 166/166, the same as main.
- foreman.test skips 6 here against 5 on main's 17:32 run. The extra skips come from what this worktree's site/ lacks
  ("no kernel/examples under ...e19-hud/site/_engine_snapshot" and "site/marble-run... is not there"). The lane did
  not touch foreman.

CHANGED FILES
Modified:
- engine/kernel/api/tl_hud.gd, engine/kernel/API.md, engine/kernel/runner/manifest.gd (KERNEL_API "1.11").
  manifest.gd is outside the listed scope, but the brief requires the KERNEL_API bump.
- engine/packs/parkour/{pack.json (kernelApi 1.11), scripts/main.gd, README.md}
- engine/style/STYLE.md
- engine/ui/host.gd, engine/ui/editor/{look.gd, village_board.gd, workbench.gd, game_sheet.gd}
Moved: engine/ui/editor/fonts/{Archivo.ttf, OFL.txt} -> engine/style/hud/
New:
- engine/style/hud/{stock,layout,sheet,ticket}.gd (+ .uid)
- engine/packs/parkour/data/{hud-widgets.json, hud.json}
- engine/ui/editor/hud/{workshop,model,proof,drive,selftest}.gd (+ .uid), timber-run.jpg and timber-finish.jpg
  (the preview stills, 354 KB together)
- engine/tools/selftest.d/550-hud-layout.sh
Regenerated (do not stage; the Director regenerates on main): docs/generated/{API-INDEX.md, API-V1.json, REPORTS.md}.
Lane folder (18 MB): BRIEF.md, STANDUP.md, REPORT.txt, ASTRA-NOTES.txt (Astra's claims and reproduction commands),
concepts/, stills/, clip-hud.mp4, clip-hud-strip.jpg.

BEHAVIOUR CHANGES (presentation only)
- Every TLHud pack now draws in Split Ticket type and plates, and its labels scale with the window (they did not
  before). TLHud's old INK, PLATE_ALPHA and PLATE_MARGIN constants are kept but are no longer what draws the plate.
- Parkour's HUD is new: it is split into widgets, the delta holds for 150 ticks after a gate, and the finish docket
  replaces the old text block. No test expectation moved.
- In the village, the HUD keeps clear of the build tag and the leave-game hint.

FOR THE DIRECTOR / THE OWNER
- To look at it yourself: `TL_WINDOW_POS=48,48 bash engine/tools/ui.sh open --res=1280x720`, then HUD workshop in the
  header, then Save & play. Or watch clip-hud.mp4. Nobody has played a run with it by hand yet.
- Caution: the workshop edits the pack it opens. From the village it lists the installed games, so Save layout on the
  house parkour writes the tracked engine/packs/parkour/data/hud.json. That is "saved with the game", but a
  developer's save will show up in git status.
- Merge: KERNEL_API 1.11 is also a likely number for any other lane that bumps the API tonight. If one lands first,
  renumber to the next minor at merge time.
- The preview is a live render of the real HUD code over two stored course stills, not a running game.

QUESTIONS
- None for the contracts. The layout is ordinary pack data, so no contract key is needed. Should PACK.md name
  data/hud.json and data/hud-widgets.json as a convention for packs that want a player-editable HUD?

NEXT THREE
1. Give hockey a widget catalogue (score bibs, clock, mode) so its HUD can be arranged in the workshop too.
2. Show the workshop's preview on a live paused frame of the game instead of stored stills.
3. Have a person run Timber Run with the new HUD at 720p (his hand is the bar) and tune the delta hold and sizes.

Astra tokens: about 597 k in total over 2 rounds of one session (01a1f501-75b5-7743-9ff4-0a962c6e4eec): round 1 about 508 k, round 2 about 89 k.
