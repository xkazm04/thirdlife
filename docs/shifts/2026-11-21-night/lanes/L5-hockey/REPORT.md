L5 hockey-fun: REPORT (night of 21 Nov 2026)
Worktree .claude/worktrees/n21-hockey, branch n21-hockey, base main 3a4580b. No git writes; the Director lands.

WHAT CHANGED (one line each; details in engine/packs/hockey/README.md, section "Fun")
- Play camera (scripts/fun/cam.gd). A broadcast follow camera is now the default play view: 50 degrees down from the
  near side, so W is still up the ice. It frames the puck or its carrier, leads 5 m in the attack direction plus 0.45 s
  of the play's speed, pulls toward you and widens 20 to 30 m when you are far from the puck, eases critically damped,
  and cuts to each face-off. V switches to the old fixed top view ("arena", which the selftest 572 still captures) and back.
- Hit-stop, shake, burst, punch, down ring (scripts/fun/fun.gd, look.gd). Below 5 m/s closing nothing happens. From
  5 m/s up: a freeze of 4 to 9 frames (skaters, figures, a loose puck and the clock), a camera shake of 0.12 to 0.4 m,
  blue snow and inked ice chips, a squash of the victim, and a 12 to 22 % zoom punch. An orange ring lies under a man
  while he is down. Counted in frames; it is in the hash; a record of it replays to the same hash.
- Goalies (scripts/keeper.gd). One per side, in every mode but pond. Each tracks the puck he saw reaction_frames ago on
  the line to his goal's centre. Saves: a glove reach 0.9 m (0.6 of that on the move); a poke check from 2.2 m on a
  carrier; his body gives rebounds. Outlet: a pass after 40 frames, only to a mate 8 m or more up ice. He covers a mate's
  puck at his own mouth, and a puck he holds is never a goal. Nobody checks him or pokes his puck. The level sets the red
  goalie's reaction, speed, glove and poke reach (rookie 26 f / 2.4 m/s / 0.75; pro 12 / 3.4 / 0.95; all-star 7 / 4.2 / 1.1).
- Shots fly at the cursor (rink_api.gd shot_dir). Before, they flew parallel to the stick from the blade, 1.24 m right
  of the cursor. The goalies made this visible: the perfect hand lost to rookie on seeds 15 and 16.
- Your mates set you up (ai/brain.gd feed). A blue AI mate shoots only within 240 frames of your own pass or shot;
  otherwise he passes to you. The AI shoots at the far corner from the goalie (corner_z 1.5).
- Goal moment. It holds the net for 24 frames, then replays the shot in slow motion (1.5 to 3x, interpolated) under a
  goal card ("GOAL!  LEO / BLUE 2 : 1 RED / REPLAY"), all inside the existing 2 s pause; then the face-off.
  Saves get a "SAVE!  VLAD" card, a small shake and a thump.
- Match-end card: "YOU WIN   3 : 0", the best moment (the hardest check, else the longest goal), "R: rematch | Esc: leave",
  with the winning goal's replay underneath.
- First minute (scripts/intro.gd). A person's session starts with a playable drill: the ring (W A S D), LEO's pass, Q
  back to him, his return pass, a click into the empty net. Then the match starts at the default level and mode. Enter
  skips the drill. Each step is one line with a key glyph.
- Names on the cards: YOU, LEO, MAX against BRUNO, IGOR, OTTO; KUBA and VLAD in goal.
- Budget work, all drawing-only, so the hash is unchanged. Headless runs skip the camera, the rings and the sprays. The
  goalies' own biped step is off, since they are placed every frame. The replay records every 3rd frame.
- Kernel issue found, worked around in the pack (PATCHES.md, item 1). TLVfx.burst one-shot effects came out at the
  pack's origin in a window: the node is placed after add_child, and physics interpolation draws its first frame at the
  origin. Every hockey shot spray had sat on the centre spot. The fix is one line in tl_vfx.gd, for the kernel's owner.

ACCEPTANCE
- [met] Packs and world gate steps are green, and the counts are at or above base.
  - packs: PASS, found 2, completed 2, verb runs 61 of 61 (base 48 of 48: 13 new hockey tests).
  - world: PASS, 8 of 8 games, world = alone, hockey 47e8cddbff2a5035 at 6752 frames.
  - Moved expectations are named below under "test expectations that moved".
- [met] Clips of 20 to 30 s from a window (d3d12, bots playing, 960x540 in lanes/L5-hockey/clips/):
  - follow camera in open play: camera_open_play.mp4 (25 s)
  - big check with hit-stop and shake: big_checks.mp4 (25 s)
  - goalie saves: goalie_saves.mp4 (23 s)
  - goals with the goal moment and the match-end card: goals_and_match_end.mp4 (23 s)
  - first-minute drill: first_minute.mp4 (25 s; the bot waits 50 frames per step, as a person reading the line would)
  - the drill starting by itself in a person's session (mode play), and Enter skipping it: play_session_skip.mp4 (6 s)
  - one still from each clip: lanes/L5-hockey/sheet.jpg
- [met] The ladder table covers rookie, pro and all-star against the newcomer, regular, sharp, perfect and idle hands,
  20 seeds a cell (below and in the README).
- [met] The README has a new "Fun" section: each ingredient, where it lives, and the key or value that turns it off for
  comparison.
- [met, with a caveat] The report names the three things that would make it more fun next (at the end). I judged them
  from the clips in a window, not by my own hands on a keyboard.
- Brief items:
  - camera (V = the old top view): done; 3+ iterations, clips cam_v1, v2, v3 and final in .tl/l5/clips.
  - juice on checks: done; deterministic in frames (record = replay hash).
  - goalies (track, save, beatable from an angle or after a pass across, beaten by a perfect hand, level changes the
    reaction): done; bot_goalie holds them.
  - goal moment: done.
  - match-end card: done.
  - first minute with a skip key: done.
  - hash changes: said below.
  - idle hand wins 0: done (it won 17 of 20 at rookie before the fix).

GATES
- tl check --tier full --only packs,world, 23:00 (final code):
    PASS packs  [2/2] found 2, completed 2; verb runs 61 of 61
    PASS world  [8/8] 8 games: world = alone (hockey 47e8cddbff2a5035@6752)
    hockey invariants: determinism two runs 119534d45f97f1fe; frame p99 1.348 ms (budget 4); frame p50 0.947 ms
    (budget 1.0 one of many). The machine was busy; side by side, base main measured 0.88 to 0.90 ms.
  An earlier run, before the budget cuts, failed: invariants.many_budget, frame p50 1.115 ms, measured while my clips
  and a ladder ran.
- tl check --tier fast, 23:12: PASS arch 12/12, PASS assets 4/4, PASS cards 3/3, PASS foreman.typecheck. FAIL
  devx.test 228 of 229: the assets-manifest test, inherited (Director's note; fixed on main dd1064f; assets/ untouched).
- selftest: hockeyfun.* 6 of 6 PASS (new block 650). style.frame.rink PASS (the arena still captures the whole rink).
  hunt2.* 36 of 36 PASS. k8.stage_keys PASS.
- Every hockey test on seeds 1 to 20 (37 tests). Each was green on 20 of 20 after the last sim change, except two
  worker launches of about 700 that ended without a result: bot_goals seed 12 (empty log) and bot_intro seed 18
  (exit -1066598273 at 3.4 s, "the bot did not run"). Both reran green. The machine was shared with four lanes.

LADDER (tl ladder --pack engine/packs/hockey --seeds 20, final code; the human side is one bot's policy pressed through
TLHand of the named profile, with the cursor through the hand; idle presses nothing; 95 % intervals by the normal
approximation; 20 seeds a cell)
| level    | newcomer        | regular         | sharp           | perfect      | idle                     |
|----------|-----------------|-----------------|-----------------|--------------|--------------------------|
| rookie   | 20/20 100       | 20/20 100       | 20/20 100       | 20/20 100    | 0/20 (12 drawn, 8 lost)  |
| pro      | 11/20 55 (33..77)| 11/20 55 (33..77)| 14/20 70 (50..90)| 20/20 100   | 0/20                     |
| all-star | 5/20 25 (6..44) | 15/20 75 (56..94)| 14/20 70 (50..90)| 16/20 80 (62..98)| 0/20                |
Goals for : against: rookie perfect 3.00 : 0.05; pro regular 1.55 : 1.25; all-star sharp 2.05 : 1.20; all-star
newcomer 0.95 : 1.80. On 16 Nov (no goalies) pro regular was 8/20 and all-star sharp 5/20. The human side now scores
more because shots go where the cursor is; the AI mates no longer score without you.

TEST EXPECTATIONS THAT MOVED (each named, with why)
- bot_hockey_ai: "everybody moved 3 m" now counts skaters only. Goalies keep to their crease; bot_goalie checks that.
  It also waits for the result line at full time (H9a's rule); with goalies, full-time ends became common.
- bot_match: it now runs until both sides have scored, at least 6,000 and at most 18,000 frames (it was a fixed 6,000).
  With goalies, one side went 6,000 frames without a goal on 5 of 20 seeds, and red's first goal on seed 1 came at
  12,267. Both sides scored on 20 of 20 seeds.
- bot_aim: the shot's error is measured from the puck to the aim point, because the shot now flies at it. Errors are
  0.00 to 0.01 degrees on seed 1, against the same 3-degree bound.
- bot_hockey (ladder base): the bot aims at the mouth's side away from the goalie at z 1.5. It was 1.2, chosen when
  there was no goalie.
- The hash of every hockey test changed (goalies, feed, hit-stop, shots at the cursor). World = alone holds (world PASS).

NEW TESTS (all 20 of 20 seeds, 1..20)
- bot_goalie: four goalie drills (save straight, goal from an angle, goal on a one-timer after a pass across, poke check),
  and the crease kept.
- bot_fun: a hard check holds 8 frames still with the clock held; a 2 m/s bump has no stop; a goal is replayed.
- bot_intro, bot_intro_skip: the first-minute drill played through to its goal, then the match from 0 : 0; Enter skips it.
- 9 ladder cells: rookie, pro and all-star with the regular, sharp, newcomer and idle hands, completing the 15-cell table.
- selftest block engine/tools/selftest.d/650-hockey-fun.sh (6 cases): the records of bot_fun and bot_goalie replay to
  their bots' hashes.

CLIPS (window, d3d12, 1280x720 recorded, 960x540 in the lane folder; bots playing; lanes/L5-hockey/clips/)
- camera_open_play.mp4 (25 s, all-star, seed 2): the follow camera, a save, two goals with replays.
- big_checks.mp4 (25 s, rookie, seed 1): two 14 m/s knockdowns: hit-stop, shake, chips, punch, down ring.
- goalie_saves.mp4 (23 s, all-star, seed 3): four saves with SAVE cards, rebounds.
- goals_and_match_end.mp4 (23 s, all-star, seed 2): three goals with cards and replays, then the match-end card.
- first_minute.mp4 (25 s): the drill paced like a person (each step's line read for 50 frames), then the match.
- play_session_skip.mp4 (6 s, a person's session, mode play): the drill starts by itself; Enter at frame 200 goes to the match.

FILES (all inside engine/packs/hockey/ except the selftest block and the lane folder)
new:     scripts/fun/cam.gd, scripts/fun/fun.gd, scripts/keeper.gd, scripts/intro.gd, scripts/state.gd (_pack_state moved
         out of main.gd for its 600-line limit), tests/bot_goalie.gd, bot_fun.gd, bot_intro.gd, bot_intro_skip.gd,
         9 tests/bot_ladder_*.gd, engine/tools/selftest.d/650-hockey-fun.sh
changed: scripts/main.gd, rink_api.gd, hits.gd, look.gd, drills.gd, modes.gd, ai/brain.gd, fx/fx.gd; data/tuning.json
         (follow, fun, goalie, intro, look.names / down_ring, again), ai.json (corner_z, assist_frames, feed_frames),
         levels/*.json (goalie), modes/pond.json (goalies false), drills.json (bench, intro, four goalie drills);
         pack.json (tests); README.md (Fun, keys, tests, limits, ladder); tests bot_hockey.gd, bot_hockey_ai.gd,
         bot_aim.gd, bot_match.gd
lane:    docs/shifts/2026-11-21-night/lanes/L5-hockey/{STANDUP.md, PATCHES.md, REPORT.txt, clips/}

QUESTIONS FOR THE DIRECTOR
1. Kernel: TLVfx.burst one-shot at the origin (PATCHES.md item 1). It affects every pack's bursts in a window.
2. HUD: the goal card and the match-end card are the HUD's one font size (36). A large title widget, such as
   TLHud.set_title(text, frames), would let "GOAL!" be big. That is a kernel API addition.
3. The frame p50 budget (1.0 ms "one of many") is tight. Side by side on a busy machine, the base measured 0.88 to 0.90
   ms and this tree 0.96. The gate's figure decides; the quiet-machine figure should come from the Director's merged tree.
4. tests/probe_moments.gd was a scratch bot for finding clip moments. Its file and manifest line are removed; a copy
   stays in .tl/l5 (not tracked).

WHAT WOULD MAKE IT MORE FUN NEXT (judged from the clips in a window and the scripted person's session; I have not played
it with my own hands, so take these as a viewer's, not a player's)
1. Saves need a body. The goalie stands upright and the puck just stops at him. A visible stab, kick or slide toward
   the puck on a save, plus a few frames of hit-stop on a big one, would make saves as exciting as goals. The SAVE card
   and thump are a start. Without a body, the goalie reads as a post.
2. The scrum. Five or six figures gather on the puck along the boards (big_checks.mp4, goalie_saves.mp4). The play
   reads as a pile, and your own figure gets lost in it. The AI needs spacing: one chaser a side, the others holding
   lanes. That would also make passing, which the mates now do for you, read as hockey.
3. A shot you can feel. Every shot is the same 18 m/s. A one-timer bonus off a pass, or hold-to-charge with a visible
   wind-up, would reward timing. The pass-across already beats a goalie on the move (bot_goalie), but nothing on the
   screen says "that was a one-timer". A large GOAL title would help too; it needs a HUD widget (question 2).

NEXT THREE THINGS THIS LANE WOULD DO (L5b, if the Director agrees)
1. The goalie's save made visible (a stab or slide and a squash; drawing only, no hash change).
2. AI spacing against the scrum: one chaser a side. This changes the sim, so the ladder and the gates run again.
3. A one-timer bonus with an on-screen mark.

======================================================================================================================
L5b (22 Nov, 00:00-00:15), on top of the Director's commit 30c1372. Small changes, each gated.
1. The goalie's figure is ticked by the fun layer: a stance, and on a caught shot a stab (pass clip) and a squash. His
   biped step stays off. Drawing only: bot_goalie's hash was unchanged (667641179215f829) after this step alone.
2. Nobody swarms a goalie. While a goalie holds the puck, the other side's skaters wait 10 m out in their lanes
   (ai.json goalie_gap). The clip save_v3 (.tl) shows red backing off where five figures had crowded the goalie.
   This changes the simulation.
3. One-timer. A shot within 14 frames of taking your own side's pass flies 1.35x (18 -> 24.3 m/s), with a
   "ONE-TIMER!" card, a crack and a kick of the camera. The shot frames and the factor are tuning values
   (shoot.one_timer_frames, shoot.one_timer_scale). bot_fun gets 2 rows: a shot straight off the pass is a one-timer
   at 24.3 m/s; a shot held 16 frames first is not, at 18.0 m/s.
   bot_match also reports the crowd near the puck as a number, not a verdict: 1.2 to 1.6 skaters within 4 m, 4 or more
   in 0 to 4 % of live frames, on seeds 1 to 10.

Gates (L5b final code, 00:00 to 00:10):
- PASS packs [2/2]: found 2, completed 2; verb runs 61 of 61.
- PASS world [8/8]: world = alone.
- hockey invariants: frame p50 0.974 ms (budget 1.0; busy machine, as before).
- selftest hockeyfun.*: 6 of 6 PASS (bot_fun 5 rows, record = replay).
- 20 tests on seeds 1 to 20: all 20 of 20.

Ladder (tl ladder --pack engine/packs/hockey --seeds 20, L5b; hands as in L5):
| level    | newcomer        | regular          | sharp            | perfect          | idle |
| rookie   | 18/20 90        | 20/20 100        | 20/20 100        | 20/20 100        | 0/20 |
| pro      | 5/20 25 (6..44) | 12/20 60 (39..81)| 12/20 60 (39..81)| 19/20 95 (85..100)| 0/20 |
| all-star | 3/20 15 (0..31) | 10/20 50 (28..72)| 12/20 60 (39..81)| 14/20 70 (50..90)| 0/20 |
The idle hand still wins nothing, and the perfect hand still wins every rookie match.

Clip (20 s or less, in the lane folder): clips/l5b_fun_rows.mp4 (10 s, bot_fun). It shows the hit-stop, the bump, the
goal replay, the one-timer card and the ordinary shot.
Files: scripts/fun/fun.gd, scripts/ai/brain.gd, scripts/rink_api.gd, scripts/main.gd (one line: the shot event
carries the one-timer), scripts/fx/fx.gd, data/tuning.json, data/ai.json, tests/bot_fun.gd, tests/bot_match.gd (crowd
figure only), README.md.

======================================================================================================================
L5c (22 Nov, 00:25-00:55), on top of 981cf41. The camera at the moments a person meets first; drawing only.
- Establishing shot: each match opens on the whole rink from 46 m and swoops in to the play over 100 frames. The
  opening face-off's cut no longer kills it; the first try did (clip l5c_cam2, .tl), the second keeps it (l5c_cam3).
- Goal: while the horn goes (hold_frames) the camera moves in close on the net at 12 m, then follows the replay at
  15 m as before.
- Cost: none headless. The camera's work is skipped headless, and no loop over skaters was added.
- The simulation is unchanged: the gate's bot_hockey hash 3b372f91ecfe4c79@6751 equals L5b's, so the L5b ladder stands.
Gates (00:40-00:52):
- PASS packs [2/2]: verb runs 61 of 61.
- PASS world [8/8]: world = alone.
- hockey invariants: frame p50 0.971 ms (L5b 0.974; busy machine).
- selftest hockeyfun.*: 6 of 6 PASS.
Files: scripts/fun/cam.gd, scripts/fun/fun.gd (one argument), data/tuning.json (follow.goal_distance,
establish_distance, establish_frames, establish_ease), README.md.
Clip: clips/l5c_establish_and_goals.mp4 (19.6 s, rookie, perfect hand, seed 6): the opening swoop, two goals each in
close on the net, then the replay.
