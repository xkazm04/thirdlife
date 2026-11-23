# K5 screen, round 3: the pause card, the menu, the first 30 seconds

## What stands
- **Kernel: a pack's own pause card and front end in the dungeon frame** (API.md section 26, numbered 1.24 by the Director;
  the version lines are left at the branch's 1.22 for him to set):
  - `ctx.own_pause()`: Esc freezes the tick as before, and the frame draws no card of its own.
  - `ctx.can_pause()`, `ctx.pause()` (called during the load, it takes effect before frame 0), `ctx.resume()`,
    `ctx.leave_game()` (the frame's Leave, run deferred), and `ctx.paused`.
  - `TLHud.on_paused(handler)`: the pack's painter, called every drawn frame while paused.
  - `ctx.input.menu_keys()`: up, down, left, right, enter, esc and click, gathered while paused. Never latched, recorded or
    hashed.
  - `ctx.cores.opened(id)`.
  - Every other pack keeps the frame's card unchanged. Selftest 830: `hokej.pause_own` (a fixture pack: freeze, no frame
    card, the keys arrive, resume, leave_game -> left("leave")) and `hokej.pause_frame` (seed_paddle: the frame's own card)
    both pass.
- **thirdjam's pause card** (pausecard.gd; DirectorsCallWidget.cpp:170-232, 373-382, 772-792):
  - Layout: the scrim over device B's panel, 808 wide. PAUSED, "PERIOD 1   -   ROOKIE (YOUR LEVEL)", then RESUME,
    CHANGE A RULE, RESTART, CONTROLS and QUIT TO MENU. Under the rows: the two mouse buttons by possession, EVERY KEY, AND TO
    REBIND IT: CONTROLS, the team rule, and the key hints.
  - Up / Down skip the disabled rows. Enter selects. Esc resumes.
  - RESTART resumes and presses the R the glue restarts on.
  - QUIT TO MENU asks LEAVE THE MATCH? with its sentence wrapped at the card's width; NO, KEEP PLAYING has the focus, and
    YES, LEAVE TO THE MENU leaves the dungeon.
  - Under the card the HUD stands still: the panel hidden, the markers down, the caption gone, the banner and end clocks
    stopped.
- **thirdjam's front end** (front.gd; MenuWidget.cpp; MenuFlow.cpp):
  - Title: the barn backdrop under the scrim, HOKEJ, the team rule, the tagline, PRESS ENTER breathing over 1.6 s, the footer.
  - HOME: the header bar with LEVEL and its chip, PLAY NOW with "ONE MATCH, <LEVEL>.  ENTER / A, OR CLICK.", the level row on
    the kit's segments with the level's line, the ONE MATCH panel, YOUR STICK, and the footer.
  - Left / Right change the level. Enter plays: the core gets the lit level (set_difficulty + reset before frame 0), the
    MATCH card says it, and K3's light hold opens the match from frame 0. Esc on HOME goes back to the title.
  - Not ported, and not drawn: SEASON, MODES, PLAY WITH A FRIEND, CONTROLS, SETTINGS, CREDITS, QUIT.
- **More of device B's kit, exported once** (one Unreal commandlet, closed): T_UI_Button_Normal, Focused and Disabled,
  T_UI_Segment_Lit and Unlit, T_UI_HeaderBar, T_UI_MenuBackdrop. The Unreal copy in .tl/tj-ui is deleted.
- **The human's keep-clear box is the figure's bones** (FigureBoxOnScreen source 2: every joint projected, plus 14 cm), now that
  thirdjam's figures stand in. The stand-in's bounds remain only as the fallback.
- **A caption yields to a distance label** it would lie on (the one-line rule, HUDOneLine.cpp:88-114). Seen in a still.
- **The head point through the call**: `Screen.frame_of(..., head)` takes K3's `match_view.head_world(HumanIndex)` and applies
  thirdjam's -18 cm along the head's axis (h:316-322).

## Stills (looked at): r3_sbs_sheet.jpg, plus r3_*.jpg (our first 30 seconds in the exe's dungeon frame)
The references are thirdjam's front-end stills (menu-3, lane A195) and its one-look HUD stills.
- Title: the same composition. thirdjam's menu-3 still predates its barn backdrop; HEAD ships the barn
  (`jam.menu.KitBackdrop` 1), as h43-01 shows.
- HOME: the same header, PLAY NOW, level row and ONE MATCH panel. Ours lacks the other entries.
- MATCH card and dial: the same.
- Pause card: the same panel, rows and hints. Ours greys CHANGE A RULE and CONTROLS (not ported) and has no rule line.
  thirdjam's menu-3 pause still shows a five-line key table; HEAD replaced it with the two stick lines we draw
  (DirectorsCallWidget.cpp:220-227).
- What my eye rejects:
  1. The title's PRESS ENTER reads a little lower and smaller than thirdjam's.
  2. The level segments are flatter than thirdjam's: the kit art is stretched at half its pixels.
  3. Captions still lack thirdjam's barks.

## Answers to the Director's eye notes (K3's film)
- The controls panel: HEAD ships the panel (`jam.hud.ControlsPanel` 1, HUDControlsPanel.cpp:34). The one-line strip and the pill
  in K3's film are the 15 Nov runnable build, from before the panel. The submission stills h43-02 and h43-07 show the panel.
- The score plates: HEAD's one look sets the value type to 40 pt (HUDOneLook.cpp:59-78, h:1148), where the film's older look
  used 56. thirdjam's own one-look stills (docs/experiments/hud/*, the AFTER halves) show the same smaller plates. HEAD is
  the target.
- "HE JUST GOT IT": a carrier cue on the contact line, which HEAD ships off (`jam.hud.ContactPlate` 0, R-0070:
  HUDWidget.cpp:1823-1835). It is not shown, correctly.
- "Blue shoots!": a commentator line. It is built (round 2) but gated to one line per 150 frames, so many shots go
  uncalled, as in thirdjam.
- Barks (BarkSystem.cpp, BarkWidget.cpp; `jam.hud.BarkLane` 1): HEAD ships them. Not built yet; round 4.
- The chevron's tip on the helmet: thirdjam puts the tip 4 px over head_socket lifted -18 cm. Device B's socket is about 19 cm
  over the helmet's top (h:316-321), so the tip floats about 1 cm plus 4 px over the helmet. If K2's exported socket sits
  lower than B's, the -18 cm sinks the tip into the helmet: that is K2's check, and the rule here is thirdjam's.

## Deviations (new)
1. CHANGE A RULE (the Director's Call) and CONTROLS (rebinding) stand disabled on the pause card. The rule line
   ("One rule change is ready this period: make them pay.") is not shown.
2. The title's Esc leaves to the exe's menu; thirdjam's title has no way out.
3. HOME's other entries are not drawn. The lit level is not kept for the next time: data/match.json is the default.
4. Mouse: only a click on the title is read (thirdjam's items take hover and clicks).
5. The pause card's keys and the front end run outside the pack's tick and the watchdog. The frame calls the painter.
6. A level chosen on HOME is not in an input record: a recorded session replays at data/match.json's level. This is a
   question for the contract.
7. The YOU marker's lift falls back to the world's up when no head bone is known.

## Found on the way (for the Director)
- hokej's invariants: the state hashes are unchanged (ad03a2add6ce42c1 / 4685cd21e60096f0). `invariants.many_budget` FAILS at
  p50 2.75 ms (budget 1.0; round 2 measured 0.50), and frame p99 is 3.8 ms against a 4 ms budget. The same run with the HUD's
  call taken out of main.gd (a temporary local copy, restored) gives the same 2.75 ms, so the cost is in the branch's drawing
  side added since round 2 (thirdjam's figures through K2's pawn), not the screen. seed_paddle measures 0.17 ms on the same
  machine at the same time (CPU at 71 % from other sessions).
- `dungeon.trips` (640) fails on the branch as it stands, and not because of this lane. The trips open dungeon index 0,
  which K3's 39c6a39 made hokej, but the case compares them with packs/hockey's alone hash. The trip's hash 6e9c32c23eaf
  is hokej's own alone hash (worker, 600 frames, seed 1). Fix the case: hash index 0's pack, or pass --dungeon-index.
- The crash on quit (exit 139) under --quit-after: not seen in dungeon.gd while in it. My window probes quit cleanly. They
  print "4 RID allocations of type Texture leaked" and "6 resources still in use" at exit; those are probably HUD textures
  freed late, not a crash.
