K5 screen, round 6 (landable)

1. MATCH card level. Cause: the HUD read data/match.json's difficulty when it was made, not the level the shell applied from the
   record. Fix (scripts/hud/screen.gd): Screen.applied_level(ctx, fallback) reads the `hokej_level` meta start_level sets; used when
   the HUD is made and synced every drawn frame (cards.set_level). Test (bot_hud_rules part A): no level applied -> match.json's;
   rookie / pro / all_star applied -> the card's sub line ends ROOKIE / PRO / ALL-STAR.
2. End card GOALS. HEAD counts the human's own goals (HUDEndStats.cpp:49 Hu.Goals, with the first end frame counted, HUDWidget.h
   4e: the critic's "3:2, all three his, card said 2" fault). Not the team's. Ours was already a port of that; a 3:0 win with
   GOALS 2 is correct when the human scored 2 of the 3. Test added: the end card's GOALS equals the human skater's Goals in the
   final snapshot, in both recorded matches (a 3:1 match passed).
3. White bar under the ring. In HEAD's regular cut it is OFF. Every white / paper ground line is gated off: held shot's line
   jam.hud.ShotLine 0 (HUDChargeLook.cpp:26; the "white slab at his shoulder" fault of 04:30), pass power line jam.hud.PassMeter 0
   (HUDPassMeter.cpp:25, A219), stop line jam.hud.StopLine 0 (HUDMarks.cpp:35), stamina bar (chalk, 240 x 8 bottom centre)
   jam.hud.SprintOnIce 0 (HUDWidget.cpp:63; it is not under the ring anyway). Nothing ported; K3's film is of an older build
   (as with the controls strip in round 5).
4. PassTargetHeld / PassTargetFacing are not in SNAPSHOT.md yet; charge.gd already reads them first. No held-pass still made.

Gates: tl check --tier fast 5/5 PASS; selftest hokej 5/5 PASS (hud_rules, hud_layer, pause_own, pause_frame, level_record);
bot_hud_rules PASS 475,175 checks 0 failed; bot_level_record PASS. No full tier, no new stills (no visual change).
Files: engine/packs/hokej/scripts/hud/screen.gd, engine/packs/hokej/tests/bot_hud_rules.gd, this lane's STANDUP.md, REPORT.txt.
