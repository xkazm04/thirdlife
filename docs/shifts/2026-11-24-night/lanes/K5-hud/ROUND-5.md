# K5 screen, round 5: K1's Controls fields wired, the panel question settled, the bark plate measured

## What stands
- **The panel's possession** reads `Controls.ButtonsWithPuck` (screen.gd `ui_of`). That is thirdjam's HasPuckForButtons
  (InputMapping.cpp:432-442): he carries, or the puck is loose and his team touched it last.
  - The swap rule (HUDControlsPanel.cpp:87-104) runs over that value, as before.
  - `ButtonsCarrying` and `ButtonsInReach` are not read by HEAD's HUD. They feed only the button resolver
    (InputMapping.cpp:476-487), so the screen does not use them.
- **The take grace's first frame** reads `Controls.CarrierInTakeGrace` (UJamSim::InTakeGrace, JamSim.h:879-884).
  - The count is `TakeGraceLeft`, or the full 30 when it is still 0 on the frame the puck is won (HUDWidget.cpp:1904-1908).
  - The ring starts at 1.5 x. It stays at 1.0 x when the grace was won by his own hit (h:462). Before this round the ring
    missed that first frame.
- **The pass's target ring** (charge.gd, from HUDChargeLook.cpp:37-112):
  - While he carries and holds the pass, a ring of radius 0.8 x 1.15 m stands under the target mate. It is in his team's
    colour at full alpha, at z -1.
  - When his pass count grows, the ring moves under the mate the pass was aimed at (the last held target, else the tap's).
    It stays while that pass flies (`Puck.PassFrames` > 0, `PassBy` = him), for at most 45 frames.
  - Never under a skater in the box (lane A224).
  - The shot's line stays off: HEAD ships `jam.hud.ShotLine` 0 (HUDChargeLook.cpp:26).
- **The teaching pulse** (charge.gd, from HUDTeach.cpp:42-98; the rule `R.teach_step` from h:604-616):
  - Pass is due when he carries and the target mate stands 6 to 30 m away, within 45 degrees of his facing (dot > 0.7).
  - Check is due when he has no puck and an opposing carrier is within 2.6 m, within 60 degrees of his facing (dot > 0.5).
  - Each kind shows at most 3 times a session, for 90 frames each, at least 900 frames apart. It never shows again once
    he has done the thing: a pass of his, or his check or lift (the step's buttons or his event).
  - It never shows during a countdown, while he is down, or in the draw's first 60 frames.
  - With the panel there is no pill. The panel lights the taught row in look 1 (HUDControlsPanel.cpp:318-331): the yellow
    keycap with ink type and the word in yellow. A lit row (look 2) still wins over it.

## The controls panel versus the film (K3's question), settled from HEAD's source
HEAD's regular cut shows **the block, bottom left, all match while play runs**:
- **The rule's switch.** `jam.hud.ControlsPanel` defaults to 1 (HUDControlsPanel.cpp:34-35): "the controls panel bottom
  left all match ... no 8-second strip, no pill".
- **The settings switch.** `LegendFor(rule, setting)` gives Panel when the rule is on and the setting is on
  (HUDWidget.h:101-102). SETTINGS' CONTROLS PANEL is on when nothing is saved (SettingsWidget.cpp:70).
- **When it shows.** Play phase, not paused, no GOAL banner (`ShowControlsPanel`, h:108).
- **Where the rest comes from.** The one-line strip ("SKATE WASD ...", 8 seconds at the first faceoff) and the two-word
  pill ("LMB CROSS-CHECK RMB CHECK") exist only under `jam.hud.ControlsPanel 0`. That is the screen of before, which the
  15 Nov film shows.
- **No override.** No .ini or cartridge in HEAD sets the cvar.
- **Stills.** The H43 submission stills h43-02 and h43-07 show the panel.
- **What we build.** We build the block, as before. Nothing changes.

## The bark plate's height (K3's question)
The plate is 7 + line + 7 units at 1080: FMargin(14, 7, 14, 7), the lane has no tail (BarkWidget.cpp:147 and :360).
- **The line height.** Roboto Bold and Bold Condensed share their vertical metrics (hhea 1900 / -500 of 2048). At 18 pt
  (24 px) the line is 28.25 units, so the plate is **42.25**.
- **thirdjam's still.** hud/03-clay-1080-play-bark AFTER, measured edge to edge on its 2/3-scale sheet, gives **42.75**.
- **Ours.** Built from the same numbers: 42.25. Sheet: r5_bark_height.jpg.
- **Verdict.** The height is a port, not a guess. No change.
- **One observation, not changed.** In that still the bark's text is 520 units wide, which is Roboto Bold. Bold Condensed
  would give 457. The source says `FJamMenuLook::Font` takes the kit font F_Hokej_Display when it loads
  (MenuWidget.cpp:106-117), and the asset is in HEAD (Plugins/JamAssets/Content/UI/Fonts). Its Bold is Bold Condensed
  (MENU-3.md:141). So we keep Bold Condensed, as the source says. The editor run behind that still may not have loaded
  the kit font.

## Deviations (new this round)
- **D5-1: the pass target.** thirdjam's ring and teach ask `UJamSim::HumanPassTarget` (JamSim.cpp:3213-3222). That call
  finds the mate inside `pass.aim.cone_deg` 25 (JamPassStagedTests.cpp:349) of the stick, at the held power; the teach
  asks along the facing at the full power. The snapshot's `PassTarget` is `BestPass` (JamSim.h:903), which is the bots'
  pick with no cone.
  - **What it costs.** In the window probe, two of the three held passes named a mate behind the camera (f267, f405),
    so no ring showed. The ring is right only when the two picks agree.
  - **What we do now.** The HUD reads `PassTargetHeld` and `PassTargetFacing` first and falls back to `PassTarget`.
  - **The fix is K1's.** K1 should add these two Controls lines in rink_core.cpp, next to PassTarget (SNAPSHOT.md would
    note them as v1.3):
    ```
    const FJamSkaterState& Hs = S.GetSkaters()[Hi]; FVector2D AimH, AimF;
    C["PassTargetHeld"] = GV(S.HumanPassTarget(Hi, Hs.BladePos - Hs.Pos, FMath::Max(1, Hs.PassChargeFrames), AimH));   // HUDChargeLook.cpp:100
    C["PassTargetFacing"] = GV(S.HumanPassTarget(Hi, FVector2D(FMath::Cos(Hs.Yaw), FMath::Sin(Hs.Yaw)), S.GetConfig().Pass.PowerFullFrames, AimF));   // HUDTeach.cpp:67
    ```
  - **The tap's target.** thirdjam asks HumanPassTarget on the release frame. We keep the held read from the last frame he
    carried, because after the step the puck has already left.
- **The playerbot.** It never passes in 30,000 frames. The show-rule test therefore records a second match with thirdjam's
  regular playtester, which passes 16 times.

## Tests (tests/bot_hud_rules.gd)
- **Part A** adds Jam.Hud.Teach (HUDPossessionTests.cpp:150-191), case for case: 3 showings of 90 frames over 20,000 due
  frames; the pulse ends when he does it and never comes back; done before due means never shown; a restart keeps the
  session's count.
- **Part B** records two matches: the playerbot (30,002 frames), then the regular playtester (8,189 frames). The checks:
  - `ButtonsWithPuck` against the carrier.
  - The panel's half against the swap rule over ButtonsWithPuck (11,741 frames with the puck, 25,726 without).
  - The grace ring on every frame `CarrierInTakeGrace` says (12,091 frames). On the 8 first frames, left 30 and scale 1.5.
  - The pass ring only while held under PassTarget (18 frames) or in flight under his own pass (408 frames). Never under a
    boxed skater, and never missing while held.
  - The teach limits: 3 pass pulses and 2 check pulses. Each starts on its own frame, at least 900 frames after the last,
    never after done, at most 90 frames. Never counting, down or within 60 frames of a drop. The taught row lit (144 frames).
  - The test fails if any of these is found 0 times.
- **Result.** 474,995 checks, 0 failed.

## Looked at (the window probe, .tl/k5/probe_r5.gd; keys and the right mouse button through Godot's input, steering to the puck)
- r5_02_after_drop.jpg: f230, the panel WITHOUT THE PUCK, the mate's carrier ring.
- r5_06_grace_first.jpg: f255, he wins the puck; the grace's first frame stands at 1.5 x.
- r5_05_teach_1.jpg: f1438, an orange carrier within reach in front. RMB CHECK is lit yellow, and the carrier's grace ring
  is at 1.5 x.
- r5_03_pass_held_0.jpg: f267, the pass held 12 frames. PassTarget is mate 3, behind the camera, so there is no ring (D5-1).
- r5_07_play_1200.jpg: f1431.
- r5_sbs_sheet.jpg puts each still beside thirdjam's (panel/03, screen-tells/05, screen-tells/r3-08).
- r5_bark_height.jpg: the bark plates at 1080 units.
