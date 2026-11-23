K5 screen: REPORT, round 4 (landable), 23 Nov 23:25. Worktree .claude/worktrees/hk-hud at hokej be548e5 + this round.

OUTCOME
- The level into the record: MET.
  - HOME's PLAY NOW taps a key-less action (level_rookie, level_pro or level_all_star) for frame 0, so the input record holds
    the choice.
  - The shell applies it on frame 0 before the core's first step (Screen.start_level: set_difficulty + reset on the same
    seed).
  - Selftest hokej.level_record: a session started at ROOKIE is recorded and replayed from the record alone with the same
    hash (c96735f7d67d4e58). With the level's row removed it hashes differently (6b1af815a72df8fb).
- Barks and the bark lane as HEAD ships them: MET, except the triggers that wait on unported systems (Director's Call,
  signal replies).
  - The bank is 1,340 lines.
  - Picker: the cooldowns, the tone rolls and no repeats.
  - Triggers: goal, check landed, knocked down, faceoff, the end, near miss, steal, stall.
  - The lane: one bubble a side, beside the team's score plate, yielding to figures, the puck, the human and the HUD's line.
  - The booth yields 150 frames to a bark at the human.
  - Tested on the whole recorded match (69 barks); seen in the window.
- K1's fields: not landed yet, nothing to build. The panel shows WITH THE PUCK as soon as Controls.HasPuckForButtons appears.
- The first 30 seconds again, in K6's hall with K2's figures, beside thirdjam's: LOOKED AT (r4_sbs_sheet.jpg). My eye's list
  is in ROUND-4.md: the panel's possession (K1) and a slightly taller bark plate.

THE LINE FOR main.gd (K3's file; you merge it; it is in my tree for the tests)
  In _pack_tick, after `_light_hold(frame)`:
    if frame == 0:
        Screen.start_level(ctx, rink)              # lane K5: the level HOME chose, from the input record (key-less action)

KERNEL LINES: none this round (no kernel file touched).

GATES
PASS  hokej lint
PASS  hokej smoke
PASS  bots 11/11, including bot_hud_rules (152,761 checks, 0 failed, 69 barks) and bot_level_record
PASS  invariants: frame, solo and entity budgets
PASS  selftest 830: 5/5 (hud_rules, hud_layer, pause_own, pause_frame, level_record)
PASS  fast tier: 5/5 (arch 12/12, assets, cards, devx.test 229/229, foreman.typecheck)

BEHAVIOUR CHANGES
- Every hokej run's state hash moves (idle 7fc0e6fcdda31448, bot 8fb15a96ecaf7b8d; were ad03a2add6ce42c1 /
  4685cd21e60096f0). The cause: the three declared level actions enter the input part of the hash. The core's own hash is
  unchanged (bot_match_hand ab881a00fb9af8ef as before). Expected hashes anywhere else (K3's notes) move with it.
- In a window:
  - barks appear in the lane;
  - the commentator says fewer lines (100 where it said 147 on the recorded match), because barks at the human hold it, as
    in thirdjam.

CHANGED FILES
- pack:
    engine/packs/hokej/scripts/hud/barks.gd (new).
    engine/packs/hokej/scripts/hud/hud.gd, captions.gd, screen.gd (changed).
    engine/packs/hokej/data/hud_barks.json (new, 164 KB: thirdjam's bark bank).
      This is under data/, outside my claim: please add engine/packs/hokej/data/hud_barks.json to hk-hud's scope.
    engine/packs/hokej/tests/bot_level_record.gd (new); pack.json lists it last.
    engine/packs/hokej/scripts/main.gd: the two lines above.
- selftest: engine/tools/selftest.d/830-hokej-hud.sh (+ hokej.level_record).
- lane: ROUND-4.md, REPORT.txt, STANDUP.md, HUD.md (section 7), r4_sbs_sheet.jpg, r4_03_home_rookie.jpg,
  r4_05_match_dial.jpg, r4_06_after_drop.jpg, r4_07_play_4.jpg, r4_07_play_9.jpg, r4_08_pause.jpg.

DEVIATIONS (new): see ROUND-4.md.
1. Some barks are not triggered: directors_call, the signal acknowledgements and the praise replies.
2. The lane does not yield to downed figures' bone boxes or to the nets.
3. No bark voice.
4. Records made before this round replay at match.json's level.

QUESTIONS
1. Please extend the claim to data/hud_barks.json.
2. K1's three fields: tell me when they land.

FOR THE OWNER TO LOOK AT
r4_sbs_sheet.jpg (thirdjam left, ours right: HOME, the first faceoff, play with a bark in the lane, the pause card), then
r4_07_play_4.jpg. In the exe: the Hokej dungeon.

NEXT THREE
1. K1's fields: the panel's possession, the pass-target ring and the teach pulse, the take grace's first frame.
2. The barks' remaining triggers with the signals' replies (K1's intent) and the Director's Call when they are ported.
3. HOME's remaining entries (CONTROLS first) and keeping the lit level for next time.
