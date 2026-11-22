N3 hockey-play: night of 22 Nov 2026. Lane report.
Opus director; Astra (gpt-6.2-astra) built rounds 1-3 of the main work. Worktree n22-hockey. Landed by the Director:
- the main work: 20a18bb (merge b024967);
- loop round 1: 4fcdf37 (merge b61300f);
- loop round 2: fc2961f (merge b2e4ce6).
Loop round 3: 69f27ca. Loop rounds 4 and 4b were tried and reverted. The tree equals landed round 3 plus a test-side
overlap measure.

THE OWNER'S ASK
"THe game is unplayable through inbalancing of puck stickiness, players speed, ability AI to decide what to do, when to
pass and shoot." Keep the body-check rate. The big puck goes through TLBall.set_radius. The spec is HOCKEY-ARCADE section 5.

WHAT WAS BUILT (main work, landed)
- The puck is a state: loose, carried, pass, shot. Every loss has a readable cause: poked, hit (check), intercept, lost
  (self), bobble, dump.
  Files: scripts/carry.gd, scripts/poke.gd, rink_api.gd.
- The carry is a critically damped spring to the drawn blade, with dangle on turns. The carrier loses the puck himself
  only on a sprint plus a hard turn.
- Pickup is by relative speed: clean under 15 m/s, a bobble from 15 to 20.
- Reception: the man a pass is meant for gets a wider window, a soft magnet in its last 18 frames, and is clean up to
  28 m/s relative.
- One-timer: shoot pressed 8 frames before arrival or 6 after; it fires 4 frames after the take at 28.8 m/s.
- Poke: a 24-frame action, live on frames 6-12, cooldown 40.
  - Odds: 65 % from in front, 45.5 % from the side, 26 % from behind; x0.6 on a carrier who just cut.
  - A whiff halves the poker's turn rate for 15 frames.
  - Anti ping-pong: a new owner cannot be poked for 24 frames; the old owner and nearby opponents cannot steal for 30.
- Speed table, by the research's ratios:
  - cruise 9.2 / sprint 10.58 m/s; the carrier x0.88 with 0.8 of the thrust;
  - turn rate 4.5 rad/s, x0.85 carrying, x0.67 sprinting;
  - pass 18 m/s (23 past 15 m); wrist shot 24, full charge 32; puck cap 34.
- Utility AI (scripts/ai/brain.gd, sense.gd, carrier.gd, roles.gd):
  - decisions at 4 Hz, staggered and event-interrupted, with a commitment bonus;
  - perception lag and aim and score noise by level;
  - SHOOT, PASS, CARRY, PROTECT, DUMP;
  - roles F1/F2/F3 and D1/D2/D3 by time to the puck; a support-spot grid;
  - a pass call: a ring under the open mate;
  - the goalie on the puck-to-net line, 1-2 m deep, under 4 m/s.
  - Body checks keep their per-frame trigger, and the hit rate was kept.
- Own-goal guards, each from an idle hand's measured win:
  - no AI pass, shot or dump that risks its own net;
  - the human's mates never carry the puck in themselves;
  - a goalie takes slow pucks and his own side's errant passes;
  - the pinch guard: a loose puck gains at most 4 m/s a frame without a release;
  - goals count only through the mouth.
- Big puck: TLBall.set_radius (kernel API 1.13), through boosts.gd resize.
- Measures:
  - tests/metrics.gd (in every ladder test), tests/bot_metrics_ai.gd;
  - lanes/N3-hockey/metrics.mjs runs cells x seeds;
  - named figures for the editor (N4): possession_median_f, passes_per_possession, pass_completion, shots_per_min_team,
    slot_or_one_timer_share, turnovers_per_min, turnover_share, oz_share_blue, entry_success, goals, idle_max_f,
    dead_puck_max_f, pressure_waves, lead_change_share, close_rounds, rounds, hand, plus raw.
- New tests: bot_poke, bot_dangle, bot_reception, bot_own_net, bot_ai_play, bot_metrics_ai.
- Selftest block 730: record = replay for 4 bots.
- README: an N3 section with the before/after table and the ladder.

OUTCOME AGAINST THE ACCEPTANCE
1. The 5 metrics inside their bands, with a before/after table: PARTLY MET. The table is in the README N3 section.
   Measured: 20 seeds a cell, 16 cells, 320/320 runs completed. "Before" is c7dad86.
   - Inside the band:
     - bobble share 7-11 % and self-loss 0 % (before: no such causes; 54-77 % of turnovers were pokes);
     - the bots' slot or one-timer share 55-68 % (before 10-27 %);
     - entries kept 54-69 %;
     - shots 2.2-3.0 per team a minute (before 2.3-6.0);
     - goals 2.6-3.4 a match.
   - Completion, under the definition fixed in loop round 2 (taken by the passer's side, whistles out): 83-91 %. That is
     ABOVE the 70-85 band: the bots pass only when safe.
   - Outside the band:
     - possession median 3.0-4.1 s, against 4-10 (before 0.4-0.8);
     - passes per possession 1.2-1.8, against 1.5-3;
     - checks 43-57 % of turnovers, against at most 45.
   - The trade: possession and the check share pull against the owner's "keep the body-check rate". Holding the bots'
     body checks back on a fresh carrier gave 3.5-4.4 s and 37-44 %, but a third fewer hits. I kept the hits: red on a
     person's hand at rookie / pro / all-star is 2.7 / 4.2 / 3.7 a minute (21 Nov: 2.5 / 4.3 / 4.9).
2. packs green and world 8/8 = alone: MET for world; packs NOT MET on the frame budget.
   - world 8/8 PASS at landing (hockey 800de8f1ccef03f0@1743).
   - packs: every hockey verb passes except invariants.many_budget. Busy A/Bs:
     - CPU 15-33 %: base 0.93-0.99 ms, N3 1.02-1.06 ms;
     - CPU 100 %: main 1.24-1.37 ms, N3 1.40-1.42 ms.
   - The Director re-reads it quietly.
   - All hockey hashes moved, by design: new carry rules, AI, speeds, goal entry.
3. Invariants p50 <= 1.0 ms: NOT MET on this busy machine. About +0.05-0.1 ms against base. The cost is the bots' brain,
   95-140 us a frame. Two cuts are kept and do not change the hash: the perception ring reused in place, and goal
   positions computed once a frame.
4. The ladder re-run with hands: MET. Wins of 20, newcomer / regular / sharp / perfect / idle:
   - rookie 15 / 19 / 19 / 20 / 0
   - pro 6 / 14 / 14 / 19 / 0
   - all-star 0 / 3 / 7 / 17 / 0
   The idle hand wins nothing (0/60).
5. Clips judged by me in a window, 20 s or less, in lanes/N3-hockey/clips/: MET (for the bots' play).
   - n3_one_timer_play: a red passing play, ONE-TIMER, goal.
   - n3_poke_frees_puck: a blue poke frees the puck from the red carrier; x0.33 replay.
   - n3_sprint_turn_loss: bot_dangle; the cruise turn keeps it, the sprint cut loses it; x0.25 replay.
   - n3_match_defence: 16 s of match play.
   - n3_r1_regular_before / after: loop round 1.
   - n3_r2_red_pass_out_of_pressure.
   - What a person meets in them:
     - the bots still bunch round the puck in 4-5 figure scrums;
     - bodies overlap in contact (TLHit.pushbox is not used);
     - the drawn stick can point away from the puck in a hard turn;
     - a self-loss is visible only briefly.
6. "Playable": NOT A LANE CLAIM. Nobody has played this with his own hands. Every figure is a scripted hand (TLHand).
   I judged clips, not the feel of the keys.

LOOP ROUNDS (after the extension to 09:00)
- Round 1, bunching. The scrums hold the support man and the lane man.
  - Keeping every bot without a job 5 m off the puck spread the play: scrums 16-22 % down to 13 % of live frames, and
    possession 3.6-4.1 s. But it cut red's hits about 25 %.
  - Keeping only the attackers off kept the hits but barely spread the play, and failed bot_ai_play seed 1.
  - Reverted. The measures landed. The owner's choice between spacing and hits is on the morning page.
- Round 2, passing. The low completion was my measure (whistles counted as misses; the scripted hand and the goalies
  mixed in).
  - Fixed definition: 83-91 %.
  - Two tries, both reverted:
    - the carrier re-decides on pressure: world differed from alone;
    - pass_min_lane 0.4: bot_modes seed 1 tied at the cap.
  - Measures landed.
- The world difference, traced: the runs are identical through frame 2015. At 2016 one skater beside red's net is 0.001 m
  off in the world: contact with static geometry integrates differently. This is a kernel issue: ENGINE-NEEDS row plus the
  wcmp.sh repro.
- Round 3, the carrier passes before the hit: the carrier re-decides every 7-8 frames instead of 15. It is a second slot
  in the same stagger (scripts/ai/brain.gd, two lines).
  - 20 seeds a cell, against the landed code:
    - red passes per possession: pro 1.5 to 1.9, rookie 1.2 to 1.4, AI-only 1.2 to 1.5, all-star 1.9 to 2.1 (band 1.5-3);
    - red AI completion 85-92 %.
  - Costs:
    - red's hits on a person's hand: pro 4.2 to 3.9, rookie 2.7 to 2.3, all-star 3.7 to 3.2;
    - possession median 2.8-3.7 s, mixed;
    - all-star sharp wins 3 of 20 (was 7): a sharper red.
  - Gates: world.alone same (ecd7591b103f6205); 56/56 seed 1; selftest hockeyplay 12/12; fast tier 4 PASS + foreman NOT RUN.
  - Clip: clips/n3_r3_red_pass_out_of_pressure.mp4 (regular hand, pro, seed 1, window). Red players pressed by blue at
    centre ice pass between them, carry in, ONE-TIMER. Sheet: sheet_r3_red_pass_out_of_pressure.jpg.
  - Landed: 69f27ca.
- Round 4, scrums round loose pucks: jobless bots keep 6 m off ONLY while the puck is loose. With a carrier, the defence
  still closes and hits.
  - world.alone: same.
  - Scrums 15-18 % down to 14-17 % of live frames.
  - Possession: pro 2.8 to 3.5 s, rookie 3.4 to 3.8 s.
  - Red's hits on a person's hand about level (pro -10 %, rookie +9 %, all-star +24 %).
  - Rookie newcomer wins 13 to 15.
  - In the window (regular hand, seed 1) there is no visible difference.
  - It failed bot_modes seed 1: outnumbered tied 1:1 at the test's 9000-frame cap, as pass_min_lane 0.4 also did.
  - Reverted. Sheet: sheet_r4_loose_keepoff_before_after.jpg.
- Round 4b (the Director's ask, what a person sees):
  - Bodies overlapping: measured, upright field skaters never overlap more than 0.087 m (new test-side measure
    overlap_frames / overlap_max in tests/metrics.gd). The overlap in the clips is drawing: 4.4 m figures under a
    50-degree camera, sticks and arms, men lying on the ice. TLHit.pushbox would change nothing physical, so it is not
    taken; ENGINE-NEEDS row for readable close figures.
  - The stick pointing away from the puck: steering stick_yaw in the rig's own frame at the drawn puck changed nothing
    visible. The hash was unchanged, as expected for drawing only (bot_dangle 1a633935c04f46a6). Compare the before and
    after rows of sheet_r4b_stick_before_after.jpg (window, bot_dangle seed 1).
    - Cause: the blade rests about 2 m out at 2.2x, while a bot carries the puck 1.0-1.3 m out, and stick_yaw is clamped.
    - Reverted. ENGINE-NEEDS row: a stick reach or blade IK rig parameter.
    - The game-side alternative, carrying at the blade, moves hashes and play: not at night.
  - Landable from 4b: only the overlap measure (test side).
- What blocks further AI rounds: two seed-1 accidents trip any change of the bots' play.
  - bot_modes' outnumbered match runs to a tie at the 9000-frame cap.
  - world = alone fails through the physics float difference at a static contact.
  Neither is a rule of the game. The fixes are N1's physics row, and a bot_modes cap tied to the mode's own time limit
  (the Director's call: it is a test expectation I will not loosen myself).

ASTRA TOKENS
- round 1: 225,334
- round 2: 205,423
- round 3: 201,997
- total: 632,754 of the 0.8 M budget

ENGINE NEEDS (lanes/N3-hockey/ENGINE-NEEDS.md)
- a ball speed-gain cap;
- goals that count only through the mouth;
- the pushbox, measured against hits;
- a kernel perception history;
- ctx.own_tick;
- a lone-runner trace;
- world and lone physics bit-identical against static geometry (repro included).

QUESTIONS FOR THE DIRECTOR
1. Spacing (r1e, keep_off_m) against the owner's hit rate: the owner decides.
2. many_budget: a quiet A/B, or accept +0.05-0.1 ms for the utility AI.
3. Whether r2a (pass out of pressure) lands once N1 makes world and lone physics bit-identical.

NEXT THREE
1. The world/lone physics fix, then re-try r2a (it raised red's passes and kept the hits).
2. Spacing with the hits kept: a defence that closes on the carrier but not on loose pucks.
3. A person plays it: the owner's hand on rookie and pro, newcomer and regular.

HONESTY NOTES
- I ran one git command that writes to the working tree: `git checkout -- data/levels` in round 1, at 02:4x. It reverted
  my own uncommitted level thresholds to the landed state. No commit, stash or reset.
- One gate run was stopped by my own wrapper timeout (a world check at 01:1x). It was re-run in full; I did not count
  the stopped run.
- The many_budget figures are all busy-machine A/Bs.
