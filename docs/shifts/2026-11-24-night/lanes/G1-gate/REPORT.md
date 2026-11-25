G1 gate: report (night of 24-25 Nov 2026). Tree .claude/worktrees/hk-gate (branch hk-gate at hokej 7750a94). Nothing committed.

1. world: hokej trips the world's watchdog at frame 9071
--------------------------------------------------------
What runs at frame 9071: hokej's hand bot (tests/bot_match_hand.gd, pack.json's first test) sees the match over (3:1,
first to 3) and says it is done. The world (kernel/world/pack.gd tick) then called finish() INSIDE the same guarded tick:
the bot's verdict, census, hash, _pack_state, teardown. The lone worker guards _bot_result and teardown under
SETUP_LIMIT_MS (10 s; runner/worker.gd) and plain() of the result is not guarded at all; the world held them to the
frame's 250 ms. So the world failed a run that passes alone: a breach of "a game in a world plays as it does alone".

Cost by part (measured, world tick 9071; probes were temporary and are removed):
  the pack's tick (game + bot tick) ....... 3.8 ms   (alone: tick_ms_max 6.7 ms over all 9072 frames)
  finish: saved_data 0.4 ms, the bot's _bot_result call 0.06 ms,
          plain() of the result ............ 450-480 ms  (the bot's metrics.raw: inputs, hashes, devices for 9071
                                                         frames, ~27,000 dictionaries; the report is 4.3 MB)
  census/hash/pack_state/teardown never reached before the kill.
It is not a hitch a player meets: a person's session has no bot and no bot verdict; the game frame is 3.8 ms.

When it came in (world.sh run --packs=hokej --mode=bot --frames=20000 at each commit, read-only checkouts, removed):
  39c6a39 (round 4, 23 Nov 20:09) ... no trip: the match ends at 5459 frames, raw dump {inputs, hashes}
  89d3b85 (round 5, 23 Nov) ......... TRIP at 9071 (raw glue: the match now 9071 frames; the dump gains "devices")
  9161bf7, 2e64f47, 585d130, 90ca5ed (K8 3a), 8272069 (E5), 67b1349 (before E1b), 7750a94: TRIP at 9071, same
  match (score 3:1, 1810 carried, 27 shots) and alone hash fd162294891897fc. None of tonight's merges brought it.
Two-way: at 89d3b85 with "devices" removed from the bot's result: no trip, iter_ms_max 221.5 ms (just under 250),
  hash = alone (4685cd21e60096f0). At 67b1349 with the whole raw dump removed: no trip, iter_ms_max 15.8 ms, hash
  fd162294891897fc unchanged.

Fix (kernel, at the cause: the world guarded the end of a run as a frame):
  engine/kernel/host/guard.gd   tick(): the pack's tick under the 250 ms limit as before; when its bot said done on
                                that tick, p.finish() is the guard's next call under FINISH_LIMIT_MS 10000 (the worker's
                                SETUP_LIMIT_MS); begin(info, limit_ms) takes a per-call limit; a trip in it says
                                "phase":"finish". The 250 ms of every other call is unchanged.
  engine/kernel/world/pack.gd   defer_finish (the guard sets it) / finish_due: tick() marks the finish due instead of
                                calling it; a direct caller (walker_replay_case.gd) still finishes inside tick as before.
  Order of calls is unchanged (finish ran last in tick; now right after it). No pack or template file changed, so
  rink.template (851) is untouched and every bot hash stays.
After: world.sh run --packs=engine/packs/hokej --mode=bot --frames=20000: no trip, 9072 frames, state_hash
  fd162294891897fc7d97d7ef5a85d3e874643159924991216a0394bd8bfba62e = alone; tick 9071 = 3.8 ms; the finish call
  452 ms under its 10 s limit (iter_ms_max 477 ms in the world line is that call; iter_ms_p99 6.5 ms).
Open (Director's choice, not done): the bot's 4.3 MB raw dump (K3's proof feed: docs/.../K3-shell/proof/
  core_replay.gd, rawtrace_compare.py) still costs ~450 ms of plain() at every hokej/base bot end, alone and in a
  world. Making it opt-in or cheaper is a pack+template change (and K3's tools' format); without the dump the end is 16 ms.

2. kit.selftest refs: look_gym in rigs/
---------------------------------------
Moved (working tree; the Director stages: 4 deletions under rigs/, 4 new files):
  engine/rigs/skater/look/{look_gym.gd, look_gym.gd.uid, look_gym.tscn, gym_rig.json} -> engine/tools/skater/look/
  (gym_rig.json is read only by the gym). The look stays: tl_rig_skater_look.gd, look_case.gd, the three textures.
Callers updated: look_gym.tscn (its script path), look_gym.gd (header command line, gym_rig.json path),
  engine/tools/selftest.d/850-skater-look.sh (look.skater.render), engine/rigs/RIGS.md:296,
  K7's tools docstrings (docs/shifts/2026-11-24-night/lanes/K7-look/tools/look_pairs.py, look_reference.py).
The refs rule is not touched.

Gates (this tree, after the fix; one Godot at a time)
  bash engine/tools/k.sh selftest ............. 120 passed, 0 failed (PASS refs)
  selftest look.skater ........................ 8 passed (render through the moved gym, in a window)
  selftest rink. .............................. 37 passed, 1 failed: rink.playtester_seat "the core or its CLI is not
                                                built": rinkcli-thirdjam.exe is gitignored and absent from this
                                                worktree (and the main checkout); environment, nothing G1 touched
  selftest hokej. ............................. 5 passed
  selftest p1. (the guard) .................... 2 passed (runaway_cpu, world_runaway: a runaway still trips at tick 20)
  world.sh run hokej bot 20000 ................ no trip, hash = alone
  tl check --only world ....................... PASS [9/9] world = alone
  tl check --tier fast ........................ PASS (arch 12/12, assets, cards, devx.test 229/229, foreman.typecheck)
Not run: selftest dungeon. (windowed, long); its trip case reads a "_pack_tick" record that this change does not alter.

Files changed (stage per file):
  M engine/kernel/host/guard.gd (CRLF kept)    M engine/kernel/world/pack.gd (LF kept)
  D engine/rigs/skater/look/look_gym.gd, look_gym.gd.uid, look_gym.tscn, gym_rig.json
  A engine/tools/skater/look/look_gym.gd, look_gym.gd.uid, look_gym.tscn, gym_rig.json
  M engine/tools/selftest.d/850-skater-look.sh  M engine/rigs/RIGS.md
  M docs/shifts/2026-11-24-night/lanes/K7-look/tools/look_pairs.py, look_reference.py
  A docs/shifts/2026-11-24-night/lanes/G1-gate/STANDUP.md, REPORT.txt
Disk: all .tl/old-<sha> checkouts removed (no junctions); my selftest report folders and scratch logs deleted.
