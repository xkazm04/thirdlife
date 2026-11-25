E5 proof: real Foreman jobs through Create's path (night of 24-25 Nov 2026)
Tree .claude/worktrees/hk-proof, branch hk-proof at hokej 585d130; nothing committed (the Director lands).
Full write-up: PROOF.md beside this file. The stills are the JPGs beside it.

RESULT
- The path works with the real model (claude-cli sonnet, the flags of engine/ui/flags/real.json, every step through
  ui/foreman_run.mjs in foreman_door.gd's order).
- Job 1, "3 against 3 hockey on a small pond rink": DONE, v0.1.2.
  - Core route: the base was copied in 71 s with no builder; the cartridge, a goal-beat script and the skin came from
    3 builders of 4 to 5 min; Build to v0.1.0 took 41 min.
  - Change "make it faster": a cartridge diff, one 6 s call (11k tokens), no builder: speed 9 -> 12, accel 12 -> 16,
    turn 5 -> 6.5, shot 18 -> 22, puck 30 -> 36. Measured pro speed 7.6 -> 9.2 m/s. v0.1.1 in 14.5 min.
  - Change "the orange team is too strong": diff ai_red_skill -> 0.6. There is no orange team and the player already
    won 10/10. v0.1.2 in 14.8 min.
  - Plays like hokej (it is hokej's match on a 50 x 26 rink), but it is a goal flood: 33 a match, against hokej's 2
    to 5.
- Job 2, slow and fast patches + bumpers: STOPPED at phase 1. The core plays the zones and bumpers (measured), but the
  base draws none of them, so the ice is plain.
- Job 3, pirate Sharks/Gulls, teal and gold, first goal wins: STOPPED at phase 1. The cartridge was exactly right, but
  the base's hand check needed a shot; the match ended 1:0 on a carried-in goal.
- Cost: 11.8M tokens in (7.9M cache reads), 546k out, weighted 5.27M; 181 min wall over 5 job starts (2 of them job 1's
  starts lost to route defects, fixed).

EDITS (npm test 349: 342 pass, 0 fail, 7 skipped; tl check --tier fast PASS 5/5)
- foreman/src/coreroute.ts: schemaPaths follows "$ref": "game.schema.json" (the Designer was refused for real keys);
  normalizeCorePlan drops invariants (the base itself fails it).
- foreman/src/foreman.ts: the final verification of a core job skips invariants (3 lines).
- foreman/src/quality.ts: a critic revise round never goes to the base package.
- tests: core_route.test.ts (2 assertions), revisepair.test.ts (1 new test).
- engine/templates/rink_game/tests/bot_match_hand.gd: the net from the cartridge (was x 41); ok = carried AND (shot
  OR his side scored). Regular hash unchanged.
- engine/templates/rink_game/scripts/main.gd: the hall goals only on 90 x 45 (else the rink's own goals at the goal
  lines; before, the nets stood outside the boards); the top camera's near plane at 50 m (it was black above the roof).

NOT FIXED (larger; details and log lines in PROOF.md)
1. The base draws no zones, obstacles or pickups (job 2's whole game is invisible).
2. Create cannot answer a builder's question or a quality hold: a person is stuck.
3. The concept step picks a 0.08-0.18 likelihood twist on plain sentences (direction question).
4. The critic judges aspects the person dropped.
5. No measured check at a phase pause while the milestone is open.
6. The core check's warnings (goal flood, trivial at all_star) never act.
7. A change naming a team the game does not have goes through.
8. The commentary names teams by index.
9. The builders cannot run check-cartridge.
10. A no-builder change round still takes about 15 min (re-verification and captures).
11. A stale class cache in a fresh tree breaks hokej until tl.sh import.

EXE AND MENU
- dist/ThirdLife built (export.sh, 103 s); export.sh check PASS.
- Job 1 v0.1.2 is in %APPDATA%\ThirdLife\dungeons.user.json, added by Create's add_to_menu calls.
- To play: run dist\PLAY-LATEST.cmd, then Dungeons, "3 against 3 hockey on a small pond rink" (made by you in
  Create).
- To see the jobs in My games: start the exe with TL_CREATE_JOBS=<tree>/.tl/proof-jobs.

STILLS TO LOOK AT: compare_hokej_j1.jpg, hokej_strip.jpg, j1_phase1_strip.jpg, j1_v011_strip.jpg, j1_v012_strip.jpg,
j2_phase1_strip.jpg, j3_cartridge_ws_strip.jpg, netfix_pond.jpg, topcam_fix_pond.jpg
