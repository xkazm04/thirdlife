K5 screen: REPORT, round 2 (landable), 23 Nov 21:15. Worktree .claude/worktrees/hk-hud at hokej 663f0c5 + this round.

OUTCOME
- Call site on the raw glue: MET. ui_of() reads the glue's own data:
  - the resolved verbs from last_in (rink.last_human_input()),
  - the keys from last_raw.Down,
  - BRACED from Controls.CrossHoldSteps.
  Possession for the buttons reads Controls.HasPuckForButtons. The glue computes it (rink_gamemode.cpp:175-190) but does not
  publish it, so I am ASKING K1 for that field (see QUESTIONS). The rule is not re-ported in the pack. main.gd's one line is
  unchanged.
- GOAL banner and goal pause: MET. It uses thirdjam's own banner art, at the same timing, band and tint. The panel and the
  net/puck badges stand down under it. On the match-ending goal it plays inside the end card's wait.
- End card with stats and the 1.9 s wait: MET. The wait is 114 frames. The card has the word, the score line, the five-row
  table and the key caps on device B's panel art.
- IN THE BOX n: MET. Built, and its text is tested. It never shows in the regular cartridge (penalties are off).
- Commentator's caption lines with their triggers: MET.
  - All 415 lines of thirdjam's three banks, generated from its .inl banks; the manifest is identical to commentary.json.
  - The booth's picker is ported: situations, cooldowns, no-repeat, the 150-frame gate, must-play and hit cuts, the second
    beat after a goal, and passes held until a mate receives them.
  - The caption strip is in the one look and docked bottom centre.
  - It draws from its own seeded stream (presentation only, never in the state hash).
- Pause card on Esc, R restart: NOT BUILT, by decision.
  - The kernel's frame owns Esc: the exe's dungeon frame pauses the tree with its own card, and tl play ends the run.
  - A pack never sees Esc and has no pause hook.
  - What the kernel would need is in ROUND-2.md: a pack-declared pause, HUD keys while paused, ctx.leave() for QUIT TO MENU.
  - R restart is the glue's; the HUD resets on it and opens the MATCH card again (tested).
- Fade from black: K3's, not duplicated.
- Side-by-side stills at the goal, the end card and a caption, LOOKED AT: r2_sbs_sheet.jpg. The reference is thirdjam's own
  one-look stills (docs/experiments/hud/ of lane A229: HEAD's look, the AFTER halves). Same banner, caption, end card and
  MATCH card. My eye's list is in ROUND-2.md.
- Head socket anchor (Director's item 3): built. It follows any figure with thirdjam's sockets standing at the human's place.
  K3's swap is not in this tree yet, so it falls back to the stand-in top.

GATES
PASS  hokej lint (assets/ for the pictures: a pack's scripts/ holds GDScript only)
PASS  hokej smoke
PASS  hokej invariants (state ad03a2add6ce42c1, bot 4685cd21e60096f0, the raw-glue base)
PASS  bots 10/10, each named:
        match_hand: 3:1 in 9071 frames
        gym_hand
        rule_w_away
        rule_s_lock
        rule_aim: 12 of 12
        rule_aim_anchor
        tj_replay: 9329 of 9465
        rule_restart
        rule_signals
        bot_hud_rules: 152,736 checks, 0 failed (banner 342 frames over 3 goals, booth 147 lines, end wait and card)
PASS  selftest 830 (hokej.hud_rules, hokej.hud_layer)
PASS  fast tier with a fresh index: arch [12/12], assets [4/4], cards [3/3], devx.test [229/229], foreman.typecheck
FAIL  fast tier as cut: arch and devx.test fail only because the index is stale for kernel 1.21 (yours to regenerate;
      I put docs/generated back exactly as it was)
(no full tier, as ordered)

CHANGED FILES
- kernel:
    engine/kernel/api/tl_hud_layer.gd: image_of, image, nine; draw ops 6 and 7.
    engine/kernel/API.md: section 25, three rows for 1.21.
    engine/kernel/runner/manifest.gd: 1.20 -> 1.21.
- pack:
    engine/packs/hokej/pack.json: kernelApi 1.21.
    engine/packs/hokej/assets/hud/T_UI_RingPlain.png, T_UI_Ring.png, T_UI_Banner_Goal.png, T_UI_Panel.png (new).
      These are thirdjam's own textures, exported. NOT in my claim: please extend hk-hud's scope to engine/packs/hokej/assets/hud/**.
    engine/packs/hokej/scripts/hud/flow.gd, captions.gd, commentary_lines.gd (generated) (new).
    engine/packs/hokej/scripts/hud/hud.gd, screen.gd (changed).
    engine/packs/hokej/tests/bot_hud_rules.gd (changed).
- lane:
    ROUND-2.md, REPORT.txt, STANDUP.md, HUD.md.
    tools/commentary_lines.py (the generator).
    r2_sbs_sheet.jpg, r2_ours_goal_1080.jpg, r2_ours_goal_720.jpg, r2_ours_end_card_1080.jpg, r2_ours_caption_1080.jpg.
- not landed (raw, under .tl/): the Unreal export script and its log (.tl/k5/export_ui.py, ue_out/), and the project copy
  (.tl/tj-ui, 786 MB; delete when you like).

BEHAVIOUR CHANGES
- In a window:
  - the rings under skaters and the faceoff dial are thirdjam's own textures;
  - a goal shows the GOAL banner;
  - the match ends on the end card after 1.9 s;
  - the commentator's lines appear bottom centre.
- No sim, input or state-hash change; headless the HUD still does nothing.

DEVIATIONS (new this round; round 1's stand in REPORT-r1.md)
1. The end card waits 114 frames instead of 1.9 s of wall clock.
2. The booth's random stream is a seeded RandomNumberGenerator. thirdjam's is clock-salted PCG32, never reproducible.
3. No barks and no bark lane, so the booth's bark yield never triggers.
4. Game-mode events the booth does not get:
   - period_end and clock (timer mode only);
   - season_take, directors_call and announce;
   - pickups and zones (not in the regular cartridge).
5. The caption moves off the dock only for the human's own figure, not for downed figures or the net, own-net and puck labels.
6. The pause card is not built (see OUTCOME).
7. Until K1 adds HasPuckForButtons, the panel's possession half shows WITHOUT THE PUCK.

QUESTIONS FOR THE DIRECTOR
1. K1: Controls.HasPuckForButtons (bool, JamControls::HasPuckForButtons at the snapshot's frame). This is the field the panel needs.
2. The kernel's frame: should thirdjam's pause card replace the frame's own for this game (ROUND-2.md: the three kernel pieces)?
3. Claims: extend hk-hud's scope to engine/packs/hokej/assets/hud/** (lint keeps pictures out of scripts/).
4. Kernel 1.21 (TLHudLayer pictures): renumber as needed and regenerate the index on hokej.

FOR THE OWNER TO LOOK AT
r2_sbs_sheet.jpg: thirdjam's one-look stills left, ours right, at the faceoff, the goal, the end card and play with a caption.
Then r2_ours_goal_1080.jpg and r2_ours_end_card_1080.jpg. To play it: node devx/bin/tl.mjs play hokej.

NEXT THREE
1. Round 3: the menu (landing, HOME, PLAY NOW with the level row) and the first 30 seconds beside thirdjam's.
2. When K1's fields land: the panel's possession, the pass-target ring and the teach pulse, and the take grace's first frame.
3. The bark lane and bubbles (BarkWidget.cpp), and a tighter end-card table measured against still 13.
