# K5 screen, round 4: the barks, the level in the record, the first 30 seconds in the hall

## What stands
- **The level is an input.** HOME's PLAY NOW taps a key-less action (`level_rookie`, `level_pro` or `level_all_star`, declared by
  screen.gd at setup) for frame 0, so the input record holds the choice (`[0, "level_rookie", 1]`).
  - On frame 0, before the core's first step, the shell applies it: `Screen.start_level(ctx, rink)` sets the difficulty and
    resets on the same seed.
  - main.gd gains one line for that (below). Without a level action, data/match.json's level stands.
  - Selftest `hokej.level_record`: a session started at ROOKIE (tests/bot_level_record.gd) is recorded. Replayed from the
    record alone it hashes the same (c96735f7d67d4e58). With the level's row taken out of the record it hashes differently
    (6b1af815a72df8fb), so the level comes from the record.
- **The barks as HEAD ships them** (barks.gd; the bank data/hud_barks.json, 1,340 lines, the same as BarkData.inl and
  Content/Barks/barks.json):
  - The triggers: a goal, the human's check landed, the human knocked down, a faceoff, the end, a near miss, a steal, a stall.
  - The picker: 240 frames between barks, 480 for one speaker, the tone roll at normal, no line from the last ten. Its stream
    is its own, seeded.
  - The lane: one bubble a side, beside the team's score plate, bottom at y 84, 262 from the centre. It shows only the newest
    bark of a team whose speaker is in the frame and within 24 m. It never stands over a figure, the puck or the human's box,
    and never while the caption or the faceoff hint stands. Held 150 frames, faded over 90; a pause clears it.
  - The look: the panel, the team's edge, Bold 18.
- **The booth yields to barks** (CommentarySystem.cpp:520-534): a bark at the human holds the commentator 150 frames and cuts a
  line older than 30 frames, except a priority-5 call. On the recorded match the booth now starts 100 lines where it started
  147.
- **Tests:** bot_hud_rules.gd adds the barks' rules on the whole recorded match: barks at least 240 frames apart, the lane
  never with a HUD line, no line inside a bark's hold but a priority-5 call. 69 barks; all checks pass (152,761 checks).
  The lane's own geometry is judged in the window probe: the test's top-down layer sets its eye 30 m up, so its speakers are
  beyond the 24 m rule.
- **The first 30 seconds again, in K6's hall with K2's figures**, through the exe's dungeon frame. The path: title, HOME,
  ROOKIE, PLAY NOW, the light hold, the MATCH card and the dial, the drop, the welcome line, play, then the barks
  "I called for it, but sure, ignore me" and "Why do the posts always side with the human?" in the orange lane, the pause
  card, leave confirm, resume, restart, leave.

## Stills (looked at): r4_sbs_sheet.jpg (thirdjam's one-look and front-end stills left, ours right)
- HOME: the same layout and words, including the ROOKIE line, which HEAD's MenuFlow.cpp:421 writes as ours. thirdjam's
  menu-3 still is older and says "rookies rarely hit." Ours still lacks the other entries.
- The first faceoff: the same MATCH card, dial, hint, panel and radar. The YOU tag stands on the figure's head socket.
- Play with a bark: the bubble in the scoreboard's row beside the team's plate, its edge in the team's colour, as in
  thirdjam's AFTER half.
- The pause card: as round 3.
- What my eye rejects:
  1. The panel still says WITHOUT THE PUCK while he carries (K1's field).
  2. The bark's plate reads a touch taller than thirdjam's, from our Bold 18 line height.
  3. No other defect seen.

## The line for main.gd (K3's file; the Director merges it)
In `_pack_tick`, after `_light_hold(frame)`:
    if frame == 0:
        Screen.start_level(ctx, rink)              # lane K5: the level HOME chose, from the input record (key-less action)
(In my tree for the tests: 2 lines, CRLF kept.)

## Deviations (new)
1. The barks' directors_call, signal acknowledgements and praise replies are not triggered: the Director's Call and the
   signals' replies are not ported. Their lines are in the bank.
2. The bark lane yields to the human's box, every figure's column and the puck. It does not yield to the downed figures'
   bone boxes or to the nets (thirdjam's GetKeepClear also has those).
3. The barks have no voice (thirdjam's is optional: `jam.BarkVoice` 0).
4. The level actions are recorded as presses (key-less actions): a record made before this round replays at
   data/match.json's level, as it did.

## Waiting on K1
`Controls.HasPuckForButtons` (the panel's half), the take-grace flag (TakeOwner / InTakeGrace) and the pass-target query (the
pass-target ring and the teach pulse's pass half).
