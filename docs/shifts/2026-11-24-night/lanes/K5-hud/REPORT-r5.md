K5 screen, round 5: landable. Tree hk-hud on hokej f9d2db9; nothing committed (the Director lands).

WHAT CHANGED
- Panel possession reads Controls.ButtonsWithPuck (thirdjam's HasPuckForButtons, InputMapping.cpp:432-442) through the swap rule.
  HEAD's HUD does not read ButtonsCarrying or ButtonsInReach (only the button resolver does), so the screen leaves them unused.
- Take grace reads Controls.CarrierInTakeGrace.
  - On the frame the puck is won, TakeGraceLeft is still 0, so the ring uses the full 30 frames: 1.5 x, or 1.0 x when the
    grace was won by his own hit (HUDWidget.cpp:1904-1908).
- Pass target ring (new scripts/hud/charge.gd; HUDChargeLook.cpp:37-112):
  - While he holds the pass with the puck: a ring of 0.8 x 1.15 m under the target mate, in his team's colour, at z -1.
  - After the pass leaves: the ring stays under the pass's mate while the pass flies, at most 45 frames.
  - Never under a skater in the box.
- Teaching pulse (charge.gd plus R.teach_step; HUDTeach.cpp:42-98, h:597-616):
  - Each kind shows at most 3 times, for 90 frames, at least 900 frames apart, and never after he has done it.
  - It never shows while counting down, while he is down, or in the draw's first 60 frames.
  - The panel lights the taught row in look 1: yellow keycap with ink type, yellow word (HUDControlsPanel.cpp:318-331).

THE CONTROLS PANEL VERSUS THE FILM (K3's question), from HEAD's source
- The regular cut shows the block, bottom left, all match while play runs.
  - jam.hud.ControlsPanel defaults to 1 (HUDControlsPanel.cpp:34-35).
  - LegendFor returns Panel (HUDWidget.h:101-102). SETTINGS' CONTROLS PANEL defaults to ON (SettingsWidget.cpp:70).
  - It shows only in Play, not paused, with no GOAL banner (h:108).
  - No .ini or cartridge overrides any of this.
- The one-line strip at the faceoff and the two-word pill exist only under ControlsPanel 0. That is the 15 Nov film's
  screen of before.
- No change.

THE BARK PLATE'S HEIGHT
- The plate is 7 + line + 7 units (BarkWidget.cpp:147, 360; the lane has no tail). The line is 28.25 at Bold 18, so the plate
  is 42.25.
- thirdjam's hud/03 AFTER still measures 42.75. The height is equal, so no change.
- Observation: that still's bark text is Roboto Bold width (520 units, not condensed 457). The source says the kit font
  F_Hokej_Display, whose Bold is Bold Condensed (MenuWidget.cpp:106-117, MENU-3.md:141). We keep the source.

DEVIATION D5-1: needs K1
- The snapshot's PassTarget is BestPass (JamSim.h:903), the bots' pick with no cone.
- thirdjam's ring and teach ask HumanPassTarget (JamSim.cpp:3213): the mate within pass.aim.cone_deg 25 of the stick at the
  held power, and for the teach along his facing at full power.
- In the window, two of three held passes named a mate behind the camera, so no ring showed.
- The HUD already reads PassTargetHeld and PassTargetFacing first and falls back to PassTarget.
- K1's two lines, beside PassTarget in rink_core.cpp:
    const FJamSkaterState& Hs = S.GetSkaters()[Hi]; FVector2D AimH, AimF;
    C["PassTargetHeld"] = GV(S.HumanPassTarget(Hi, Hs.BladePos - Hs.Pos, FMath::Max(1, Hs.PassChargeFrames), AimH));
    C["PassTargetFacing"] = GV(S.HumanPassTarget(Hi, FVector2D(FMath::Cos(Hs.Yaw), FMath::Sin(Hs.Yaw)), S.GetConfig().Pass.PowerFullFrames, AimF));

TESTS
- bot_hud_rules.gd, Part A: adds thirdjam's Jam.Hud.Teach cases (HUDPossessionTests.cpp:150-191).
- Part B: two recorded matches. The playerbot never passes, so the second match uses thirdjam's regular playtester, which
  passes 16 times. The checks:
  - The panel half follows the swap rule over ButtonsWithPuck.
  - The grace ring is right on every CarrierInTakeGrace frame, including 8 first frames at left 30 and 1.5 x.
  - The pass ring shows only while held (18 frames) or in flight (408).
  - The teach limits hold: 3 pass pulses and 2 check pulses; the taught row was lit 144 frames.
  - Any of these found 0 times fails the test.
- 474,995 checks, 0 failed.

GATES (no full tier)
- hokej lint PASS
- smoke PASS
- 11/11 bots PASS
- invariants PASS: solo_budget p50 3.34 ms; determinism 3b762bc25ee35dbc
- selftest 830: 5/5 PASS
- fast tier: 5/5 PASS (arch 12/12, devx.test 229/229, foreman.typecheck clean)

FILES
- engine/packs/hokej/scripts/hud/charge.gd (new)
- engine/packs/hokej/scripts/hud/hud.gd
- engine/packs/hokej/scripts/hud/panel.gd
- engine/packs/hokej/scripts/hud/rules.gd
- engine/packs/hokej/scripts/hud/screen.gd
- engine/packs/hokej/tests/bot_hud_rules.gd
- docs/shifts/2026-11-24-night/lanes/K5-hud/: ROUND-5.md, STANDUP.md, REPORT.txt, r5_*.jpg
- No kernel lines this round. No main.gd change (the existing call site carries everything). No contract or version edits.

LOOK AT
- r5_sbs_sheet.jpg: the teach row, the grace first frame and the held pass, each beside thirdjam's.
- r5_bark_height.jpg
- r5_06_grace_first.jpg
- r5_05_teach_1.jpg
- r5_03_pass_held_0.jpg: no ring, because of D5-1.
- r5_02_after_drop.jpg
- r5_07_play_1200.jpg
