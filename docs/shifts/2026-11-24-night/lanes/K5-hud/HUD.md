# thirdjam's screen: the inventory (lane K5, round 1)

Source: thirdjam HEAD 8dc713c6 (`.tl/thirdjam`, read-only). `h:` = `Game/Source/JamGame/Public/HUDWidget.h`, `cpp:` =
`Private/HUDWidget.cpp`, other files by name (all under `Game/Source/JamGame/`). The SHIPPED state is every console
variable at its default; an element whose cvar is off by default is listed as "off as shipped" and is not built (building
it would be inventing). Layout units: Slate's 1920 x 1080 at every 16:9 size (the DPI curve scales by the short side:
720p draws 2/3 of a unit a pixel). Type sizes are Unreal points; Slate draws a point as 4/3 of a unit.

Look: the one look (`jam.hud.OneLook` 1, HUDOneLook.cpp:27-113): plates on the menu's panel fill #141821 at the plate's
alpha, a 4-unit corner, a 1-unit white@0.12 edge ("OL plate(a)"); type in the menu's face (device B's F_Hokej_Display:
Regular = Roboto Regular, **Bold = Roboto Bold Condensed**, Black = Roboto Black; MenuWidget.cpp:90-117, ASSETS.md:1935-1938)
with a (0, 1) black@0.45 shadow; three sizes: label 14, line 18, value 40 (h:1146-1148). Colours: Text #F5F6F8, TextDim
#A3ABB8, Home #2F6BFF, Away #F26A1B, Ink #0A0C10 (MenuWidget.cpp:71-80); HUD yellow #FFD966, paper #F4F4F0, muted
#9AA0A8 (MenuStyle.h:30-39); team colours from the cartridge (#1D4ED8, #E8651A).

Status: **R1** built this round (`engine/packs/hokej/scripts/hud/`), **R2** / **R3** the brief's later rounds, **OFF** off as
shipped (not built), **GAP** needs something another lane owns (named).

## 1. In play (round 1)

| Element | What / words | When it shows (rule, cvar default) | Where / size (units) | Look | thirdjam | Reads | Status |
|---|---|---|---|---|---|---|---|
| Score plates | home "00" (the human's side), centre "PERIOD n" over "FIRST TO 3", away "00" | always (the timer line only in timer mode) | top centre, y 14; plates 18 + max(56, digits) + 18 wide, 2 + line + 2 high, centre 24 + text + 24, gaps 6, all one height | team plates: FillBrush(white, edge) tinted with the team colour; digits Bold 40 Text; centre OL plate(0.9), PERIOD Bold 14 tracked 60 TextDim, rule Bold 18 tracked 60 Text | cpp:522-569, 906-924; HUDOneLook.cpp:59-78; h:354-355 | Score, HumanIndex's Team; the take (below) | R1 |
| Take (PERIOD n) | n = clamp(1 + the leading score, 1, 3) | changes only on a Playing frame; forced at build and restart | (scoreboard, MATCH card) | | HokejGameMode.cpp:372-397, 560, 815, 1679 | Score, Phase | R1 |
| Your ring (R2: thirdjam's T_UI_RingPlain, exported) | an ellipse of a 1.1 m circle at your feet | play and goal pause; alpha 1 to 0 as the camera is 20 to 24 m away; 0 while down, back over 12 frames; none in the box (`BoxedRing` 0); 30 % within 2.5 m of the camera's eye (`RingNearCam` 1) | the four compass points' box, z = 3 cm | T_UI_RingPlain: a chalk band (8.2 % of the box) with an ink edge (0.86 %), tinted team colour; measured on h43-07 (350 x 152 box: 28 / 13 px band) | cpp:1601-1627, 1575-1599; h:234-252, 789-796; HUDPossession.cpp:31-34, 143-153 | Pos, IsDown, PenaltyFrames | R1 |
| Your double ring | your ring x 1.25 at 0.75 of its alpha | while you carry (the sim's carrier), until your pass or shot leaves (`PulseOnPossess` 1) | | team colour | HUDPossession.cpp:156-171; h:506-507 | Carrier, Passes, Shots | R1 |
| Carrier ring | 0.8 m ring under a carrier who is not you | a mate or an opponent carries, not in the box | | his team colour at 0.95 | cpp:1689-1705; HUDPossession.cpp:174-179 | Carrier | R1 |
| Pickup pulse | the new carrier's ring x (1 + 0.6 t²) for 14 frames | on a carrier change or a `possess` event | | | h:513-521; HUDPossession.cpp:108-118 | Events `possess` | R1 |
| Take grace | the carrier's ring from 1.5 x closing to 1 x over 30 frames; not when the grace was won by his own hit (`SwellAtHit` 0) | while the carrier's TakeGraceLeft > 0 | | carrier's colour (Possess recolours A163's yellow) | cpp:1895-1932; h:459-468 | TakeGraceLeft, Events `check`, ContactBy | R1 (see DEVIATIONS 4) |
| Loose ring | 0.42 m ring round the puck, at least 40 units wide | nobody carries, play, no countdown, no pass in flight, not over your figure, not over the contested mark | | paper at 0.9, yellow past 22 m | HUDPossession.cpp:181-205; h:508-512 | Carrier, Puck.Pos, Puck.PassFrames | R1 |
| YOU chevron | a V of two bars, 48 square, its tip 4 over the head | play and goal pause, the whole match (`YouMarker` 1); a ghost (0.3) while the puck projects into its box, eased 0.12 a frame | the head anchor: the figure's head socket, else the top of its bounds (`MarkerAnchor` 1) | yellow, ink edge 2.5, bars max(3, 0.2 s) x 0.78 s at 40 degrees | cpp:325-350, 1629-1674; h:194-197, 316-341 | Pos (head), Puck.Pos | R1 (head = the stand-in's 1.64 m top) |
| YOU tag | "YOU" | while a faceoff counts down (`ClearMiddle` 1); not while the puck is in its box | over the chevron: bottom at head - 56 | plate team colour, 4 corner, ink edge 2, padding 12/3/12/4; Black 18 tracked 60 Text | cpp:641-646, 1675-1687; h:344-347; HUDOneLook.cpp:101, 264-267 | FaceoffCountdown | R1 |
| Far-net badge | a diamond 22 and "NN m" (to the net) | not in the goal pause (`LabelPlates` 1); the label not in the middle third (`ClearMiddle` 1); all hidden under a card (`OneLook` 1) | 1.2 m over the crossbar (0.61 m), at least 40 over the crossbar's projection; clamped 48 + 44 from the sides, 120 from the top, 64 + 48 from the bottom; off the panel's band; the label 24 beside, on the side away from the near edge | diamond yellow, ink 0.9 edge 2, turned 45; label Bold 18 Text on a plate #141821 @ 0.80 padding 8 / 2 | cpp:597-614, 1724-1805, 1284-1304; h:207-214, 808-812, 838-843 | Pos, the attack side | R1 |
| Own-net badge | a diamond 12 and "OWN  NN M" under it | only while that net is off the frame (`OwnMarkOnNet` 0), only in your own third (`OwnThird` 1), not when its label meets the radar's corner (410 x 246) | clamped 40 / 150 / 56; the label 10 under | diamond muted, edge 1.5; label as the far net's | cpp:616-625, 1952-2000; HUDOneLine.cpp:32-59; h:548, 1184 | Pos | R1 |
| Edge chevrons | a chevron 22 (far, yellow) / 16 (own, muted) on the edge towards a clamped net | the badge was clamped or is behind the camera | 22 beyond the clamped point, turned to the side | | cpp:1708-1722 | | R1 |
| Off-screen puck | a chevron 28 at the frame's edge and "NN m" (to the puck) | the puck outside the inner 85 % or behind, in play, no card, no countdown, not before frame 150, not paused; and only while the puck projects OFF the screen (`PuckLabelOnScreen` 0); fades over 6 frames | on the rectangle 64 / 150 / 64 / 170 in from the edges; lifted over the radar corner and the panel | carrier's team colour, grey #6B727A loose | cpp:1306-1368; HUDOneLine.cpp:34-47; h:844-860 | Puck.Pos, Carrier | R1 |
| Edge slots | a far / own group within 48 of a placed one, or overlapping it, slides along its edge in 24-unit steps | always | | | cpp:1374-1465 | | R1 |
| Controls panel | head (a team dot, WITH THE PUCK / WITHOUT THE PUCK); rows LMB SHOOT, RMB PASS, WHEEL DEKE, E SPIN or LMB CROSS-CHECK, RMB CHECK, SPACE POKE; a hairline; WASD SKATE, SHIFT SPRINT, CTRL BRAKE (F ABILITY with one) | in play (also the countdown), not paused, no GOAL banner (`ControlsPanel` 1, the setting ON); the half swaps at once on gaining, 12 frames after losing or at once on a two-role press (`PanelHoldFrames` 12); the half fades in over 6 frames; dims to 0.3 while down or boxed | bottom left at (24, -24); 264 to 300 wide; keycaps 84 x 22 at least | team rule 3 (Home / Away); OL fill 0.78; keycap Text@0.92 fill, Black 14 tracked 40 Ink; word Bold 16 tracked 60 Text; head Bold 12 tracked 60; lit row Away fill, white type; SPRINT lit while sprinting, dim while the legs are spent (`SprintOnIce` 0) | HUDControlsPanel.cpp:56-60, 87-104, 140-337, 339-411; h:85-137 | the buttons, Carrier / LastTouch (HasPuckForButtons), IsDown, PenaltyFrames, bSprinting, Stamina | R1 (the teach pulse: R2) |
| Radar | 200 x 100 mini-rink: skaters 9 (you 12 over a 16 yellow square), puck 6 white, downed men 15 (a hollow square for a mate, an X for an opponent; `jam.hit.OffScreen` 1) | always | bottom right at (-24, -24): frame 212 x 112 (padding 6) | frame OL plate(0.82); field linear (0.02, 0.05, 0.10)@0.65, centre line white@0.45, edge white@0.35 | cpp:724-733; RadarWidget.cpp:1-118; HUDOneLook.cpp:110-112; HokejGameMode.cpp:1583 | Pos, Team, IsDown, KnockDir, Puck.Pos | R1 |
| Faceoff dial | the digit (ceil(frames / 60)) over HOLD; DROP for 30 frames at zero; WON / LOST for 40 frames after the draw | in play; not for a man in the box (`FaceoffCueInBox` 0) | centre (0.5 W + 440, 0.66 H), 220 square | T_UI_Ring (art); digit Black 72 outlined paper; HOLD Black 24 tracked 60 outlined yellow; DROP 44 yellow; WON / LOST 44 in his team colour | cpp:741-770, 1017-1062, 1545-1564; h:772-804, 431-435 | FaceoffCountdown, Phase, Events `faceoff` (drop / won) | R1 (the ring art drawn: DEVIATIONS 2) |
| Faceoff hint | "PRESS SHOOT AT THE DROP, NOT BEFORE" | while counting, the first 3 faceoffs of a session (process) | top centre at (0.5 W + 440, 0.66 H + 124) | OL plate(0.86) padding 16 / 6; Bold 18 tracked 60 Text | cpp:764-770, 1061; HUDOneLook.cpp:82-87 | FaceoffCountdown | R1 |
| MATCH card | "MATCH 1" over "PERIOD n   -   FACEOFF   -   PRO" | 150 frames from the build, a restart or a take change; gone on the first frame after a countdown it saw (`CardAtDrop` 1); never on the end card | centred at (0.5 W, 190) | team rule 3 over OL plate(0.9) padding 32/4/32/10; MATCH Black 42 tracked 60 Text; line Bold 18 tracked 60 TextDim | DirectorsCallWidget.cpp:597-678, 695-737; h(DirectorsCallWidget):213-223; HUDOneLook.cpp:198-232; DirectorsCallController.h:31 | Score, Phase, FaceoffCountdown, the level | R1 (a flow element, built early: the faceoff still needs it) |
| Markers stand down | far / own / puck badges hidden | MATCH card, GOAL banner, pause, end card (`OneLook` 1) | | | HUDOneLook.cpp:277-295 | | R1 (card, end); R2 (banner); pause: not built (below) |
| Pass target ring | 0.92 m ring (0.8 x 1.15) under the mate a held pass goes to, and under him while it flies (45 frames) | while he holds the pass with the puck (`ChargeLook` 1; game.pass power on by default: PowerFullFrames 30) | | his team colour | HUDChargeLook.cpp:24-101 | PassChargeFrames, Puck.PassFrames / PassBy, **UJamSim::HumanPassTarget** | **GAP**: RinkCore has no pass-target query (lane K1) |
| Contested puck rings | 1.8 m and 1.1 m rings round the loose puck, 1.0 m under the opponent coming; pulse 1 to 1.2 every 20 frames; 24 frames at least | JamCarrierMarks' rule (`Marks` 1; the stop line `StopLine` 0) | | the opponent's colour | HUDMarks.cpp; JamCore/Public/JamCarrierMarks.h:19-96; h:663-701 | Puck, Skaters | R2 (port the rule from JamCarrierMarks.h) |
| Shot line | a line on the ice 1.5 to 4.5 m along the stick while the shot is held | `ShotLine` 0 | | | HUDChargeLook.cpp:12-14, 103-135; h:636-643 | | **OFF** |
| Pass meter | the pass's reach line on the ice | `PassMeter` 0 | | | HUDPassMeter.cpp:11-14 | | **OFF** |
| Stop line | a line across his path 8 m ahead | `StopLine` 0 | | | HUDMarks.cpp:35-36 | | **OFF** |
| Stamina bar | 240 x 8 bottom centre | `SprintOnIce` 0 (the panel's SPRINT row carries it) | | | cpp:648-654, 925-933 | | **OFF** |
| Controls strip, buttons pill | the 8-second strip and the LMB / RMB pill | only with `ControlsPanel` 0 | | | cpp:670-688, 997-1010; InputMapping.cpp | | **OFF** (the panel replaces them) |
| Contact line, carrier cues, brace line | JUST GOT UP, BOUNCED OFF, NOT WITH THE PUCK, TOO SOFT, TOO SOON, MISSED, STICK LOCKED, HE JUST GOT IT, BRACED HIT, RUN THROUGH | `ContactPlate` 0 (R-0070: at a hit only the figures speak) | | | cpp:1816-1876, 1895-1950; HUDBrace.cpp | | **OFF** |
| Ability plate, effects row | "F: SHOTGUN  READY"; "SPEED  2.8" | with an ability / an effect: the regular cartridge has none | bottom right over the radar; top centre y 158 | | cpp:656-668, 935-948, 571-589, 857-888 | | not in the regular cartridge |
| IN THE BOX | "IN THE BOX  n" | the human boxed (`BoxFollowsPlay` 1): the regular cartridge has penalties off | top centre y 122, 300 x 44 | | cpp:578-586, 836-845 | PenaltyFrames | **R2 built** (flow.gd; never shows in the regular cartridge: penalties off) |
| Toast | a notice top left, 240 frames | a rejected `-cut` cartridge, drill lines | | | cpp:690-697, 985-992 | | not in a regular match |
| RULE CHANGE READY (CallText) | | never set by the live feed | | | cpp:735-739; HUDFeed.cpp:70 | | never shown |

## 2. The flow (round 2)

| Element | Words / rule (shipped) | Status |
|---|---|---|
| Fade from black | a real-time hold (the light rig visible 3 ticks, 2 s at most), then a 0.35 s fade; at the match's build only (HokejGameMode.cpp:581, 607-673) | built by K3 (main.gd, cameras.screen_fade): not duplicated |
| GOAL banner | the kit's T_UI_Banner_Goal plate (it carries the word GOAL) tinted lerp(white, scorer team, 0.25), 760 x 176 centred at 0.30 H (0.205 H when the scorer's figure is under the band); in over 12, out over 12, gone 6 before the pause ends; only when a score grew (HUDGoalBanner.cpp:34-252) | **R2 built** (flow.gd; the art exported to assets/hud/; also in the end card's wait on the match-ending goal) |
| End card | after 1.9 s: "YOU WIN" (in his team's accent) / "BEATEN" / "NO WINNER"; "YOU  3 : 1  THEM"; the stats table SHOTS, GOALS, PASSES THAT ARRIVED a OF p, HITS LANDED, WITH THE PUCK m:ss; key caps "R / VIEW REMATCH", "ESC / START MENU"; panel 704 wide at (0.5 W, 0.4 H) (cpp:446-497, 772-799, 952-982; HUDEndWait.cpp; HUDEndStats.cpp; HUDOneLook.cpp:123-181) | **R2 built** (flow.gd; the panel is device B's T_UI_Panel, exported; the wait is 114 frames) |
| Pause card | Esc: PAUSED, "PERIOD 1   -   PRO (YOUR LEVEL)", RESUME / CHANGE A RULE / RESTART / CONTROLS / QUIT TO MENU, the stick lines, key hints (DirectorsCallWidget.cpp:174-252, 373-382) | **R3 built** (pausecard.gd on kernel 1.24: the pack owns the card, the frame keeps the freeze; CHANGE A RULE and CONTROLS stand disabled: not ported; the rule line not shown) |
| Restart | R: the sim back to frame 0, the MATCH card again, no light hold (HokejGameMode.cpp:789-816) | the core's glue restarts (K1/K3); the HUD resets on the frame count going back and opens the MATCH card (tested) |
| Commentator captions | 415 lines on ~30 events; one line per 150 frames; held for the line's duration then a 30-frame fade; docked bottom centre (-24), OL plate(0.72), Regular 18 TextDim (CommentarySystem.cpp; HUDWidget.cpp:1467-1525). Its choice is clock-salted in thirdjam (not deterministic): ours will draw from a seeded stream | **R2 built** (captions.gd + generated commentary_lines.gd, its own seeded stream; barks and the bark lane: not built) |
| Teach pulses | the panel's PASS / CHECK row lights yellow 90 frames, 3 times a session, 900 apart (HUDTeach.cpp) | not yet (the pass half needs HumanPassTarget: GAP) |
| One-time prompts | the brake prompt "S AGAINST YOUR MOTION, OR HOLD CTRL: STOP, THEN GO" once a session (the kept prompt is spent unseen, `KeptPrompt` 0) | not yet |
| One line at a time | prompt > faceoff hint > caption (the contact line is off) (HUDOneLine.cpp) | **R2 built** for hint > caption (no prompt yet) |

## 3. The menu (round 3)
| Element | Words / rule (shipped) | Status |
|---|---|---|
| Title (landing) | the barn backdrop under the scrim; HOKEJ (Black 176 tracked 120), the team rule 480 x 6, HOCKEY WITH THE WHISTLE TAKEN OUT., PRESS ENTER breathing 0.55 to 1 over 1.6 s, OR A, OR A CLICK; footer ENTER / A START, CLICK START (MenuWidget.cpp:806-846, 2378-2412) | **R3 built** (front.gd; Esc leaves to the exe's menu: thirdjam's title has no way out) |
| HOME: header, footer | T_UI_HeaderBar 80 high: HOKEJ, the rule, HOME, LEVEL and its chip; team rule 8; footer ENTER / A PLAY, LEFT / RIGHT LEVEL, UP / DOWN MOVE, ESC / B TITLE (MenuWidget.cpp:773-804, 1266-1276) | **R3 built** |
| HOME: PLAY NOW, level row, the level's line | PLAY NOW (Black 48) "ONE MATCH, <LEVEL>.  ENTER / A, OR CLICK."; ROOKIE / PRO / ALL-STAR on the kit's segments; the level's line (MenuWidget.cpp:877-921; MenuFlow.cpp:408-425); Enter plays at the lit level (ChooseCut, 2138-2150) | **R3 built** (the level feeds the core: ctx.cores.opened("rink").set_difficulty + reset; the MATCH card says it) |
| HOME: ONE MATCH panel, YOUR STICK | the feature panel and the first-run stick panel (MenuWidget.cpp:1448-1452, 2795-2800) | **R3 built** |
| HOME: SEASON, MODES, PLAY WITH A FRIEND, CONTROLS, SETTINGS, CREDITS, QUIT | the other entries and their screens | not yet (not drawn) |
| The lit level kept for the next time | FJamSettings save | not yet (data/match.json's level is the default each time) |
| The level in the record | (ours: the run must replay from its record) | **R4 built**: PLAY NOW taps a key-less action (level_rookie / level_pro / level_all_star) for frame 0; the shell applies it before the first step (selftest hokej.level_record) |

## 4. Layout: thirdjam against ours (layout units; px = units x 1 at 1920 x 1080, x 2/3 at 1280 x 720)

Ours measured on our stills (`.tl/k5/f60.png` 1080p, `f60_720.png` 720p); thirdjam's from its source (the rule) and, where a
still exists, its submission still h43-02 / h43-07 (1080p, before the one look landed).

| Element | thirdjam (rule) | ours 1920 x 1080 (px) | ours 1280 x 720 (px) |
|---|---|---|---|
| home score plate | top y 14, 18 + 56 + 18 = 92 wide (value 40 pt) | x 779-868, y 15-79 (90 x 65) | x 520-578, y 10-52 (59 x 43) |
| controls panel | bottom left (24, -24), 264 wide (the widest row) | team rule x 24-155 + 156-287 (264), top y 824 | x 16-103 (+88: 176), top y 550 |
| radar frame | bottom right (-24, -24), 212 x 112 | x 1684-1896, y 944-1056 | (2/3) |
| faceoff dial | centre (1400, 712.8), 220 | centre (1400, 713) | centre (933, 475) |
| faceoff hint | top centre (1400, 836.8) | plate top 838 | (2/3) |
| MATCH card | centre y 190 | centre y 190 | centre y 127 |
| your ring at the opening faceoff | h43-02: 435 x 220 at (818, 860) | 443 x 230 at (818, 860) | (2/3) |
| YOU tag | bottom at head - 56 | bottom 472 (head of the 1.64 m stand-in) | (2/3) |
| far-net badge | at most y 120, beside the label 24 | y 153 at the opening (under the MATCH card: hidden) | (2/3) |

## 5. Round 2 additions
- thirdjam's own UI textures exported once from its project (one Unreal 5.9 pythonscript commandlet on a copy in `.tl/tj-ui`,
  closed at once): T_UI_RingPlain (512), T_UI_Ring (512), T_UI_Banner_Goal (2048 x 640), device B's T_UI_Panel (256), in
  `engine/packs/hokej/assets/hud/`; drawn with the kernel's `TLHudLayer.image_of / image / nine` (1.21).
- The YOU chevron and tag anchor to the figure's `head_socket` lifted -18 cm along the head's axis (YouMarkerHeadLiftCm, h:322)
  once a figure with thirdjam's sockets (K2's TLRigSkater body) stands at the human's place; the stand-in's top until then.
- The panel's possession reads the glue's `Controls.HasPuckForButtons` (asked of K1; absent today, so the panel shows WITHOUT THE PUCK).
- Bark bubbles and the bark lane (UJamBarkWidget, BarkWidget.cpp; `jam.hud.BarkLane` 1: a team's bark beside its score plate) are
  thirdjam screen elements not in this inventory's first pass: not built (thirdjam's one-look still 03 shows one).

## 6. Round 3 additions
- The front end and the pause card run on kernel 1.24 (API.md section 26): the pack pauses itself during its load (the title
  and HOME come before the match's frame 0), owns its pause card, reads Up / Down / Left / Right / Enter / Esc / click while
  paused, resumes, restarts (the R key the glue restarts on) and leaves (ctx.leave_game).
- More of device B's kit exported once (buttons, segments, header bar, backdrop) into assets/hud/.
- The bark bubbles and the bark lane: built in round 4 (section 7).

## 7. Round 4: the barks (HEAD ships them on: `jam.Barks` -1 = the cartridge's game.barks {enabled, normal}; `jam.hud.BarkLane` 1)
| Element | Rule | thirdjam | Status |
|---|---|---|---|
| Bank | 1,340 lines (situation, speaker, tone, text): goal_for, goal_against, check_landed, check_received, steal, stall, near_miss, faceoff, win, lose, directors_call, signal_ack_defend/space/pass, praise_reply | BarkData.inl = Content/Barks/barks.json | **R4** data/hud_barks.json |
| Triggers | a goal (the human's: a mate praises; a bot mate's: an opponent complains; against: the scorer or the nearest opponent); the human's check landed; the human knocked down; a faceoff; the end (win: a mate, lose: an opponent); a near miss (a shot, then a board hit by the net within 45 frames); a steal (the puck changes team: the taker mocks, or an opponent complains when the human took it); a stall (300 frames untouched, puck under 2 m/s, at most every 600) | BarkSystem.cpp:212-256, 418-505 | **R4** barks.gd (directors_call, the signal acks and praise replies: not yet: the call and the signals' replies are not ported) |
| Picker | at most one bark each 240 frames, one speaker each 480; the tone by a roll (normal: an opponent mocks 50 %, complains 30 %, bravado 20 %; a mate encourages 40 %, praises 35 %, complains 25 %), else the first tone of the side with lines; a line not among the last ten | BarkSystem.cpp:182-328 | **R4** (its own seeded stream) |
| The lane | one bubble a side, the newest of a team whose speaker (2.35 m over his feet) is in the frame and within 24 m of the camera; bottom at y 84, its near end 262 from the centre (8 from the edge at most); no tail; never over a figure (feet to 1.8 m), the puck or the human's box; never while a HUD line of words stands (the caption, the faceoff hint); held 150, faded over 90; a pause clears them | BarkWidget.cpp:18-38, 78-86, 240-370 | **R4** |
| Look | the panel at 0.9, a 4 corner, the team's edge 2 (#1D4ED8 / #E8651A), Bold 18 text, padding 14 / 7 | HUDOneLook.cpp:241-251; BarkWidget.cpp:184-216 | **R4** |
| The booth yields | a bark at the human (all but goal_against, a faceoff, and a goal_for of the other side) holds the commentator 150 frames and cuts a line older than 30 frames, except a priority-5 call | CommentarySystem.cpp:520-534, 735-742 | **R4** captions.gd |
