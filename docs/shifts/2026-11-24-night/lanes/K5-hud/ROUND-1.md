# K5 screen, round 1: the inventory and the in-play HUD

## What stands
- **The inventory** (`HUD.md`): every element of thirdjam's match screen at HEAD 8dc713c6 with its words, show rule, place,
  size, colours, source lines and the snapshot fields it reads, and its status. Built from HUDWidget.h/.cpp and the HUD*.cpp
  files (the in-play set, read by me) and a read-only inventory of the flow, captions and menu (a subagent; its tables are
  the basis of HUD.md sections 2-3 and of round 2). The shipped state is every cvar at its default: the shot line
  (`jam.hud.ShotLine` 0), the pass meter (`PassMeter` 0), the stop line (`StopLine` 0), the stamina bar (`SprintOnIce` 0),
  the controls strip and the pill (replaced by the panel) and the contact line (`ContactPlate` 0, R-0070) are OFF as shipped
  and are not built. The brief's list named the shot line and the pass meter; the source turns them off.
- **The kernel gained a sports-HUD painter** (`TLHud.add_layer(id) -> TLHudLayer`, API 1.19, `engine/kernel/api/tl_hud_layer.gd`,
  API.md section 25): plates, text in Unreal points with tracking and shadow, a ring stretched into an ellipse (the ground
  ring), chevrons, polygons, lines, a bar, a minimap, `project()` through the camera pose of the frame and `ground_ring()`
  (ProjectGroundRing: a circle on the ground as the box of its four compass points). Layout units: 1080 a screen at any size.
  The faces are Roboto as Unreal 5.9 ships it (`engine/style/hud/faces.gd` and the four TTFs; Apache 2.0): Bold Condensed is
  device B's display face's Bold, which the one look draws every HUD word in.
- **The in-play HUD** (`engine/packs/hokej/scripts/hud/`: rules.gd, hud.gd, markers.gd, panel.gd, cards.gd, screen.gd): the
  score plates with PERIOD n / FIRST TO 3 (the game mode's take, not the sim's period), your ring, your double ring while you
  carry, the carrier's ring in his colour, the pickup pulse, the take grace's closing ring, the loose ring, the YOU chevron
  and the YOU tag (at a countdown), the far-net badge ("42 m"), the own-net badge ("OWN  24 M", own third only), the edge
  chevrons, the off-screen puck arrow, the edge-slot rule, the markers standing down under a card, the controls panel (the
  possession half with its 12-frame hold and 6-frame fade, lit rows, the dims), the radar with the downed men's marks, the
  faceoff dial (digit and HOLD, DROP, WON / LOST) and its hint, and (early, because the faceoff still needs it) the MATCH card.
- **One call site in K3's main.gd**: `_draw()`, after the camera pose is set, in match mode:
  `screen = Screen.frame_of(screen, ctx, snap, human, last_in, last_raw)` (plus its `const Screen` preload and `var screen`).
  pack.json: capability `ui`, kernelApi 1.19, the test `tests/bot_hud_rules.gd` appended last (the first test is unchanged).
- **Rules tested headless** (`tests/bot_hud_rules.gd`, selftest `830-hokej-hud.sh`): thirdjam's own assertions case for case
  (HUDControlsPanelTests, HUDPossessionTests, CameraTests, CarrierCueTests), then a whole recorded match (a second RinkCore,
  its human played by thirdjam's playerbot, 30,002 frames, 1:2) fed frame by frame to hud.gd: **151,407 checks, 0 failed**
  (MATCH card 390 frames, countdown 360, DROP 48, WON / LOST 160, panel 29,640, goal pause 360, end 2; possession you 4,048,
  mate 3,090, opponent 13,571, loose 9,291). One expectation of mine was wrong and the code right: a MATCH card opened by a
  take change on the drop frame stands 150 frames into play (DirectorsCallWidget.cpp:728-730); the test now models it.
- **Layout** at 1920 x 1080 and 1280 x 720: every element in layout units; measured on stills the 720p picture is the 1080p
  one x 2/3 (score plate 90 x 65 -> 59 x 43, panel 264 -> 176 wide, its top 824 -> 550). Table in HUD.md section 4.

## Stills (looked at): r1_sbs_sheet.jpg
thirdjam's submission stills (H43, 1080p, the last pictures of the game; taken before the one look landed, so its plates and
type are the older look) beside ours at the same kind of moment (the scripted hand, pro): the opening faceoff at countdown 1,
you carry, an opponent carries, the goal pause. Same elements in the same places at the same sizes: the panel (264 wide,
bottom left, the same rows), the radar frame bottom right, the dial at (1400, 713) with its hint 124 under it, the MATCH card
at y 190, your ring (435 x 220 theirs, 443 x 230 ours at the faceoff), the chevron and the YOU tag, the net badge.
What my eye rejects or notes:
1. The YOU tag and chevron stand higher than thirdjam's at the faceoff: the head anchor is the stand-in capsule's top (1.64 m)
   and thirdjam's figure crouches at the draw. It follows K2's figure once it has a head socket (the rule is thirdjam's).
2. The dial's ring is drawn (chalk ring, blue and orange arcs, four ticks), not thirdjam's T_UI_Ring texture: the same place,
   size and words, a plainer ring.
3. The plates and type differ from the H43 stills on purpose: HEAD's one look (smaller value type 40, label 14 / line 18,
   4-unit corners, hairline edges, the hint in capitals, no score under GOAL). No picture of HEAD's one look exists; the
   runnable build is older still.
4. At our frame 100 your ring is doubled and swollen (the double ring and a take grace that runs after the draw is won):
   that is the sim's TakeGraceLeft through thirdjam's rule; it reads loud. Not changed (port, do not reinterpret).
5. The goal pause has no GOAL banner and no caption yet (round 2); the badges and the panel correctly stand down.
Nothing technical is drawn on or in front of a skater beyond what thirdjam draws (R-0069/R-0070): no lines, no plates at hits.

## Deviations (also in REPORT.txt)
1. The ring texture T_UI_RingPlain is drawn as a band: 8.2 % of the box with 0.86 % ink edges, measured on h43-07 (350 x 152
   box: 28 / 13 px); the art itself is a uasset we cannot read.
2. T_UI_Ring (the dial) is drawn from primitives (see 2 above).
3. The head anchor is the stand-in's bounds top (thirdjam's source 1, the top of the bounds) until K2's head socket.
4. The take grace's ring reads TakeGraceLeft only: thirdjam's InTakeGrace also counts the frame the puck is won on
   (TakeOwner, not in the snapshot): our ring swells one frame later. Needs K1: `TakeOwner` or `InTakeGrace` per skater.
5. The pass target ring (HUDChargeLook) is not built: it needs UJamSim::HumanPassTarget, which RinkCore does not expose (K1).
6. The HUD projects with the camera pose of the frame (as thirdjam's widget reads its camera manager), while Godot renders the
   physics-interpolated pose: at 60 Hz render on 60 Hz physics the two agree; at other refresh rates the rings may lead the
   figures by a fraction of a frame.
7. Text tracking is rounded to whole pixels at the drawn size.
8. "MATCH 1": the season number is always 1 (no season yet); the level word from data/match.json.

## Next (round 2)
The GOAL banner (its art, a GAP: drawn or exported), the end card with the stats table and its 1.9 s wait, the pause card on
Esc and restart, the fade from black, IN THE BOX, the teach pulse (check half), the brake prompt, the one-line rule, the
commentator's captions (415 lines, seeded instead of clock-salted), the contested-puck rings (JamCarrierMarks.h).
