H1g (round 7 of lane H1, editor hardening), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-a, from main fea8abb.
Opus. Covers your four answers to H1f (items 1-4) and your two later real-job findings (items 5-6).
Every item has a test that fails on main fea8abb and passes now. Real jobs were read in place, read only.

1. A bare yes grants the paths the builder's question named: MET.
   - scopegrant.ts: a yes to a scope question that names no paths grants the paths the question named. A yes that names
     paths still grants those.
   - widenedNote now says nothing when no answer granted anything. It used to write "may change ;" when another rule had
     put a file outside the plan scope; the H1g 5 test caught this.
   - Test: H1g 1, with G4's real events 221 and 224: "Can the Foreman either widen this package's scope to
     `scripts/core/**`, `scripts/main.gd` and `scripts/bodies/**` ...?" answered "Yes, let it change what it needs."
     It grants exactly those three. "Yes, go ahead" grants the same. "Yes, but only scripts/main.gd" grants that one
     path. "No, raise the budget instead" grants nothing.

2. When only some bots changed, the unchanged ones are named in words: MET.
   - playsame.ts: when some bots counted differently after the round and others did not, the note now reads "the look
     changed, part of the play did not: ... and after revise round N <bots in words> did not change (...); only <bots>
     changed".
   - How bots are named:
     - bot_hand_newcomer: "the newcomer's match"
     - bot_hand_<x>: "the <x> hand's match"
     - bot_ladder_<level>_<hand>: "the <hand> hand's match at <level>"
     - bot_tofu: "the tofu bot's figures"
     - bot_mash: "the button-masher's match"
     - any other bot: "the <name> bot (tests/<file>)"
   - The all-same note uses the same words.
   - Replayed read only on G2's real job, each of its six revise rounds now gets a line. For example, blockout round 2
     (the test fixture) reads "the player bot (tests/bot_player.gd), the newcomer's match and the perfect hand's match did
     not change ...; only the tofu bot's figures and the button-masher's match changed". G4's two rounds still get none.
   - Test: H1g 2, with G2's blockout round 2 as a fixture (foreman/fixtures/h1g/g2-blockout-r2: the bot reports, trimmed
     to their seed and bot result, plus the snapshot's seq and the critic's notes).
   - Moved expectation (named in the test): H1f 3. Its note said "tests/bot_rally.gd plays"; it now says "the rally bot
     (tests/bot_rally.gd) plays".

3. A camera-steadiness figure in the runner, checked by the Foreman: MET.
   - New engine/kernel/runner/camyaw.gd (with its .uid). Each physics frame, the worker samples the active camera
     (ctx.cameras.active) before the tick. The figures are the camera's turn and travel over each one-second window
     (60 frames), counted as the sum of frame-to-frame changes, so a camera that swings or slides back and forth counts.
     A window that contains a cut to another camera is left out. Shake moves the camera's h/v offsets, not its transform,
     so it adds nothing.
   - The figures are read only. State hashes are unchanged: ex_car and ex_bounce hash the same with and without the
     sampling (3a459d0fe25e7853 and 6c586b7eda437ce0).
   - worker.gd merges the figures into metrics. host.gd passes them through in the smoke and bot reports. The keys are
     absent when no camera was active for a full second.
   - Why travel as well as yaw: G4's play camera keeps one heading and slides after the player (main.gd `_cameras`: a
     fixed offset, the position lerped toward the player). The hoop crossing the frame is the view sliding, not turning.
     On G4's real pack (a copy of its pack/, v0.1.0), tests/bot_play.gd, seed 1: yaw p90 0 deg/s (max 1); travel p90
     5.3 m/s (max 11). tests/bot_first_minute.gd: yaw 0 (max 1), travel 2.7 m/s (max 4.1).
   - Hokej (engine/packs/hockey), seed 1, tests/bot_hand_newcomer.gd and tests/bot_hockey.gd: yaw 0 / 0 and travel 0 / 0.
     The camera these bots run with is still. ex_car's chase camera: yaw p90 17.8 deg/s (max 32.3), travel 13.1 m/s
     (max 14). ex_bounce's fixed front view: 0 on both.
   - Foreman side: new foreman/src/camnote.ts.
     - It finds a person's note on a kept or chosen card that asks for a steady camera ("steady, still, fixed, no
       swinging, TV game, broadcast" with a camera word in the note or on the card).
     - It checks the note against the newest bot runs' figures. Steady means at most 15 deg/s of turning and 1.5 m/s of
       travel (p90).
     - A camera over either bound gives "person's note not kept: "<note>": measured, the game's camera travels 5.3 m a
       second (p90 over tests/bot_play.gd's run, ...)", which makes the look NOT ok through notesKept (H1f), whatever
       the critic scored.
   - The fake runner reports these figures for FAKE_CAMERA(<yaw>,<move>).
   - Tests:
     - H1g 3: G4's real figures as a fixture with G4's real note (missed), plus a Foreman loop. In the loop the critic
       says ok and the camera travels 9.2 m/s, so revise round 1 is told the person's words. At 0.4 m/s the new version
       is kept.
     - Selftest block 863 (runner.camera_chase, runner.camera_still): both FAIL with main's worker.gd and host.gd
       (no keys) and PASS now.
   - Lines for RUNNER.md: below, for you to word. I did not edit the contract.

4. The create.pause.path race: MET (the test's waits were fixed; the product was not changed). Reconciled with H2c into
   one approach (below).
   - Three causes were found, all in stage_pauses.gd:
     a) "Sent" was read 6 frames after the press. A Foreman that answers in the wall time of those frames clears the
        page's wait.
     b) While a revise round runs, the quality card stays up without buttons ("the builders are still at work on this
        game"). waits() took it for a new hold and pressed a button that was not there. This is H2c's remaining 1 in 23
        ("quality accept is sent ... frame 1743"): the same repeated FAIL lines appear in d25-hard-b's run in
        tl_selftest_47876.
     c) The card's buttons show while the Foreman that wrote the hold is still letting go of the job. A press then is
        refused with "the builders are still at work on this game", nothing is sent, and the check sees the same hold
        ("lost"). Run 2 of my first three showed this.
   - The single rule now, for the answer and for every quality move (H2c's door check included, so the merge keeps one
     approach):
     - waits() treats the quality card as a pause only when its buttons show and no Foreman holds the job.
     - Before the press, the stage notes how many processes of that kind (answer or quality) the door has started.
     - After the frames, a send holds when the door has started one more process, the page shows no message, and the
       page is either still waiting or past the pause it answered (by the question's seq, or by the hold's milestone,
       round and notes). It fails only when the job is still on that same pause.
   - A fourth cause, in the Foreman, not the stage (item 4b). Two of my six runs (and one at 17:02) failed with "phase
     did not work" / "quality did not work: Error: EPERM, Permission denied: ...foreman.lock" at JobLog.close. On
     Windows, the Create page reads the lock's pid every poll and opens the file without delete sharing, and the CLI's
     delete fails at that moment.
     - Fix: joblog.ts removeWaiting deletes the lock, waiting up to 3 s on EPERM or EBUSY. fs.rmSync's own maxRetries
       does not cover a plain file; I tried it and it still threw.
     - Test: H1g 4b, Windows only. A PowerShell child opens the lock as Godot's FileAccess does and holds it for 400 ms.
       On main, close() throws EPERM; now the lock is gone once the reader lets go.
   - Product question (c): the quality card shows Fix it / It's fine / Change it while the Foreman is still exiting,
     and a press is refused with a message. The page keeps the card, so a person can press again. Pass already waits
     for `settling` in the same case. Should the quality card do the same? That would be a small create.gd /
     create_pause.gd change; I did not make it.
   - The page sets `busy` synchronously on the press. The old check read it 6 frames later. A Foreman that answers in
     the wall time of those frames clears it (under load a frame is slow), and the page then rightly shows the next
     state.
   - stage_pauses.gd now reads "sent" at the press. After the frames, it passes when the page is still waiting
     ("waiting") or the log has moved past the pause it answered ("taken"). It fails only when the page dropped the send
     and the job is still held on that same pause ("lost"). This is checked for the answer and for every quality move.
   - The product shows no wrong state: in every run the page was either waiting or past the pause it answered.
   - Proof (outside the selftest, with a wait of 1500 frames x 10 ms after each send, as a loaded machine would give):
     - main's stage: 5 FAIL of its 5 send steps ("quality retry/accept/change is sent", "Answer sends ...").
     - the new stage: 10 of 10 PASS, each send "taken".
     - Logs: scratch h1g-pauses-before15s and h1g-pauses-after15s.
   - `--sent-frames` and `--sent-delay-ms` are stage arguments for that proof. The selftest's own run is unchanged:
     6 frames, no delay.

5. A change with two asks, half made, goes on: MET.
   - New foreman/src/halfmade.ts, called at the merge (foreman.ts, on the same line as the H1f widened note).
   - In a change round, the builder's lines that say part was not made ("NOT DONE", "not made", "belongs to another
     package") are read. When another package's plan scope holds a path those lines name, the Foreman writes a note,
     "part of your change was NOT made by <id>; it goes on to <owner>, whose files <id> names: <lines>", and a change
     request of its own for the owner, carrying the person's words.
   - When nobody owns the rest, the note says it plainly: "part of your change was NOT made: <id> made what it could
     and says: ... say it again as a change of its own if you still want it".
   - The what-changed line no longer counts the NOT DONE lines as "what you will see". It adds the not-made line on its
     own line ("... it went on to court, which made it ..." once the owner merged). The person's words appear once.
   - On G2's real case, core's line names `scripts/ai/**` and `data/ai.json`, which are brain's files, so the rest would
     have gone to brain.
   - Test: H1g 5. "Make the rival twice as fast, and make the court walls twice as high." goes to paddle_ai. Its builder
     doubles the speed and says NOT DONE for `data/court.json`. The rest goes to court, which merges the 2.4 m walls. The
     what-changed line carries both builders' words and the not-made line. A unit case covers the no-owner words.

6. Body rows only for games with bodies: MET.
   - gamewords.ts hasBodies(brief) is yes when the design says a body stumbles, tumbles, staggers, falls, gets up,
     clambers or flinches. It is no for a game of vehicles that says none of that. It is yes otherwise, as before.
   - The body words (body, stability, stand, brace, stumble, down, downed, lying, loose, unseen) left the generic list.
     They are the game's own words only when it has bodies.
   - The house_game rubric for a game without bodies drops "the bodies" from what the games share and says "This game
     has no bodies that stumble or fall: judge its own contact, the bumps, the pushes and the ball, never a body's
     stand, brace or stumble".
   - G5 (bumper karts): no bodies. G4 and G2: bodies, so they are unchanged.
   - Test: H1g 6, with G5's real brief and tuning as fixtures. None of hits.body_window, bot_body_window, stand_brace,
     side_brace, sprint_stability, stumble_ratio, stability_speed or unseen_stability is asked of the karts any more, and
     fewer than G5's 49 rows are asked. The basketball is still asked hits.stumble_ratio.

LINES FOR contracts/RUNNER.md (yours to word; I did not edit the contract)
- In "Amendments of 2026-11-10 (after WP1)", the "In use:" list of additive metrics: add camera_yaw_p90_dps,
  camera_yaw_max_dps, camera_move_p90_mps, camera_move_max_mps.
- A new paragraph:
  "### Added 2026-11-25 (H1g): how much the game camera moves
  `smoke` and `bot` reports carry four metrics read from the active camera (`ctx.cameras.active`), sampled once per
  physics frame:
  - `camera_yaw_p90_dps` and `camera_yaw_max_dps`: degrees its heading turns in one second, as the sum of the
    frame-to-frame turns over each 60-frame window; the 90th percentile and the largest over the run.
  - `camera_move_p90_mps` and `camera_move_max_mps`: metres it travels in one second, over the same windows.
  A window that holds a cut to another camera is left out. Shake (h/v offset) adds nothing. All four are absent when no
  camera was active for 60 frames in a row. They are read only: they change no state and no hash."

MERGE NOTE: MY TREE IS BEHIND MAIN
- This tree is main fea8abb plus H1g. Main is now at 223f98c and holds H2c.
- engine/ui/create/stage_pauses.gd will conflict: H2c's quality_sent block against my rewrite. My version contains H2c's
  rule (a door process started for the press, no message, waiting or moved on) for both kinds. Take mine for that file
  whole, and drop `quality_sent` and its say() block. Nothing else of H2c's is in this file.
- My other edits touch files H2c may also have changed: foreman.ts (one line), quality.ts, fastchange.ts, gamewords.ts,
  worker.gd, host.gd. Please merge with care.

GATES (each after room.sh; logs in .tl/h1g/)
- foreman npm test: 421 tests, 414 pass, 0 fail, 0 cancelled, 7 skipped (the same 7). 421 = the merged tree's 415 + the 6
  H1g tests. A rerun after the last move (removeWaiting into removewait.ts) is in the STANDUP line.
- node devx/bin/tl.mjs check --tier fast: PASS. arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, typecheck clean.
  - One run failed the size ratchet: joblog.ts was 620 lines against its 600 budget. removeWaiting then moved to
    removewait.ts, and joblog.ts is back at 600.
- bash engine/tools/k.sh selftest: 120 passed, 0 failed.
- bash engine/tools/selftest.sh create.: 22 of 23 in the full run. The one FAIL was create.pause.path, from the EPERM on
  the lock (item 4b). Then create.pause.path alone, with every fix: 10 of 10 PASS over two loops of 5.
- Earlier runs of create.pause.path, kept for the record:
  - the full run above: FAIL, EPERM
  - before the waits() fix: FAIL ("lost")
  - before the foreman_alive wait: PASS, FAIL (c), FAIL (EPERM)
- bash engine/tools/selftest.sh runner.camera (block 863): 2 PASS (both FAIL with main's worker.gd and host.gd).
- node devx/bin/tl.mjs check --tier full --only world: PASS [9/9], world = alone. The hashes are those of main:
  example.car 3a459d0fe25e7853, hockey bcc1f5dc0fa482d9, and so on.
- Before-runs:
  - all six H1g Foreman tests FAIL on main fea8abb (a scratch copy with the new tests, the fixtures, the new modules
    camnote.ts and halfmade.ts, and shims for botWords and hasBodies);
  - block 863 FAILs with main's runner files;
  - main's pause stage FAILs 5 of its 5 sends under a 15 s wall wait, against 10 of 10 PASS for the new stage.

CHANGED FILES (round 7)
- New:
  - engine/kernel/runner/camyaw.gd (+ .uid)
  - engine/tools/selftest.d/863-runner-camera.sh
  - foreman/src/camnote.ts
  - foreman/src/halfmade.ts
  - foreman/src/test/h1g_hardening.test.ts (6 tests: H1g 1, 2, 3, 4b, 5, 6)
  - foreman/fixtures/h1g/: G2's blockout round 2 bot results, G4's camera report, G5's brief and tuning
- Changed:
  - engine/kernel/runner/worker.gd and engine/kernel/host/host.gd (the camera figures)
  - engine/ui/create/stage_pauses.gd (the test's wait)
  - foreman/src/:
    - scopegrant.ts
    - playsame.ts
    - quality.ts (the camera check, the rubric for a game without bodies)
    - gamewords.ts
    - fastchange.ts
    - foreman.ts (one line; 2004 of 2005)
    - joblog.ts (the lock delete waits; still 600 lines)
    - removewait.ts (new: removeWaiting)
    - testing/fake-runner-core.ts (FAKE_CAMERA)
- Moved test (named in it): foreman/src/test/h1f_hardening.test.ts (H1f 3's bot words).
- lanes/H1-critic: STANDUP.md, REPORT.txt

QUESTIONS FOR THE DIRECTOR
- Are the steady bounds right: 15 deg/s and 1.5 m/s at p90? Hokej's cameras and a fixed view read 0, G4's sliding view
  5.3 m/s and ex_car's chase 13.1 m/s. A broadcast camera that pans to follow play would sit between those.
- The bots in a run decide which camera is active. Hokej's two bots run with a still camera, so 0 is the figure of that
  view, not of hokej's chase camera. Should the runner also measure the view a person starts on in the exe?
- foreman/src/templates.ts on main holds a backspace character (one line). It is not mine; I left it.

NEXT THREE
1. The camera figure on the exe's starting view (if you want it).
2. A "rest of the change" that goes on to a package whose builder also says NOT DONE: today it would go on again. One
   hop may be enough.
3. Body rows for creature games that say "flops" or "rolls" (more words for REACTS) as real jobs show them.
