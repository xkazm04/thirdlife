K5 screen, round 7 (landable), on hokej dd2ca15

Cause of the 12 failures: tests/bot_hud_rules.gd still compared the ring with Controls.PassTarget (BestPass, the bots' pick),
while charge.gd reads PassTargetHeld (K1's v1.3, thirdjam's UJamSim::HumanPassTarget along the stick at the hold,
HUDChargeLook.cpp:97-112). The test now expects: while he carries and holds the pass, the ring under PassTargetHeld; in flight
(Puck.PassFrames > 0, PassBy = him, 45 frames at most) the release target. No change to the HUD code.
bot_hud_rules: 474,784 checks, 0 failed.
Held-pass still: docs/shifts/2026-11-24-night/lanes/K5-hud/r7_pass_held_ring.png (looked at): he carries in his own zone with the
take grace's 1.5 x ring, RMB held (panel row RMB PASS lit), a small team-blue ring stands under the mate (skater 2) by the net.
Probe: .tl/k5/probe_r7.gd (window, the scripted bot gets him the puck, then raw input holds RMB). The flight still showed the
opponent ring after the loss of the puck, not a flight ring; not used. PassTargetFacing (the teach) has no still this round.
Gates: tl check --tier fast 5/5 PASS; selftest hokej 5/5 PASS; bot_hud_rules PASS.
Files: engine/packs/hokej/tests/bot_hud_rules.gd, this lane's STANDUP.md, REPORT.txt, r7_pass_held_ring.png.
