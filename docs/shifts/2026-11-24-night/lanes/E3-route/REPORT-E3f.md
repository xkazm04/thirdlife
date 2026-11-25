E3f REPORT: a change keeps the person's game (tree .claude/worktrees/hk-editor, branch hk-editor at hokej 9a9126f; nothing committed)

CAUSE OF THE BLOCKING DEFECT (job 2, events 198/201/208)
- The Planner was offered the base with every file it ever merged (data/match.json, data/skin.json, the cartridge) and
  its rules say sizes "belong to the package that builds the play space (often the root)": it answered "base".
- The base's change round re-ran startFromBase. It "kept" the files later packages own by NOT copying them, but the base's
  workspace still held its own round-1 copies of data/skin.json and data/match.json (refreshWs never refreshes files inside
  the base's scope, which is everything), and the baseline of a round-1 workspace (cut from an empty pack/) knew none of
  them, so mergeSet listed all 40 files and the base's skin/match went over the pirate ones. Note and merge disagreed
  because "kept" meant "not copied", not "the workspace holds pack/'s file".

FIXES (foreman/ only)
1. Route: new foreman/src/coreowner.ts. On a core game the Planner's owner question lists the job's own packages, not the
   base (changeCandidates); whatever still lands on the base (the root fallback, grow's fallback, a phase hold's first
   package) is moved by coreChangeOwner: cartridge words (goals, rink, speed, rules, teams and team colours, bots) -> the
   package owning the cartridge (the one that also owns data/match.json first); skin-only words (title, names, commentary,
   barks) -> the skin's owner. The reopened reason says why. Wired in foreman.ts applyChangeRequests and phases.ts
   applyHolds. A change naming --package base by hand still runs the base (now harmless, below).
   Base round: coreroute.ts startFromBase copies pack/'s file into the workspace for every kept file; foreman.ts mergeSet
   never lets the base merge a file another package's scope owns that pack/ holds.
2. mergeSet lists only files that differ from pack/ for files the package merged before (a re-opened package); when
   nothing differs (a merge redone after a kill) it falls back to the old list. Job 1's shape now merges only the cartridge
   and stays on the fast path.
3. quality.ts sendBack: on a core game, a critic NOT ok whose package is the base (or names the core/engine/camera/base by
   word) writes a `milestone` at the hold's round (2) at once: no snapshot, no revise round. The card text starts
   "critic (V5) NOT ok: this is how the base plays (base: engine/templates/rink_game/ on the rink core: the skating, the
   contact, the bots, the base's camera); no package of this game can change it, so no revise round was spent. Play it and
   keep it, or say what to change. The critic saw: ..." (Create's job_v2.on_look reads it unchanged). A Foreman note names
   it. Retry with a note still sends one round; a named job package still revises as before.
   Also: lookOk and cli_quality's reason regex now count "core check NOT ok" ("critic (V5) and core check NOT ok" was
   read as ok, so a look the measured check failed at round >= 1 closed the milestone).
4. rinkjudge.ts: goals a MINUTE per level against thirdjam's modes, and a match longer than any of them. Band from data:
   foreman/scripts/rink-goal-band.mjs now records each level's minutes (regular cut + 12 modes of MODES.md, thirdjam's
   regular playtester, 5 seeds a level): 1.29 (glass-house pro) to 4.80 (bruisers pro) goals a minute, sudden death
   1.67-2.5; minutes 0.4 (sudden-death rookie) to 6.8 (marathon). Same quarter-span rule as E3d's goal band: 0.4..5.7
   goals a minute is a pass, above 8.4 min is a defect. Goals-a-match band unchanged (1 to 17.6, byte-equal `from`).
   Results on the real lines (recorded with --defects, fixtures src/test/fixtures/e3f-lines/):
   - job 1 v0.1.0 (first to 5): 6.67 / 6.33 / 6.09 goals a minute -> GROSS DEFECTS, exit code 1.
   - job 2 (first goal wins): 1 goal in 0.3/0.2/0.2 min = 3.3/5.0/5.0 a minute: INSIDE the band (bruisers plays 4.8);
     the data does not call it a defect. It is said in words: "matches shorter than any of thirdjam's modes (...; the
     shortest, sudden death, lasts 0.4 min or more), at a goal rate thirdjam's modes play: words, not a defect".
     The minutes figure is rounded to 0.1 by check_cartridge, so at 0.2 min the rate is +-25 %.
   - hokej's hockey.thirdlife.cartridge.json: 1.54-2.07 a minute, "measured, no warning".
5. (time remained) rinkjudge.unseenChange + coregate.cartridgeChange: "too strong/hard/can't win/easier" while the
   playtester on the person's seat wins >= 9 in 10 at every level (or "too easy/harder" at <= 1 in 10) is asked back as a
   question with the before figures, through the existing asked-back path (answer -> diff). Job 1's 10/10/9 case asks.
   fastchange.whatChangedNote: before a 2nd or later promotion a Foreman note "[foreman] what changed in v0.1.1 (since
   v0.1.0): asked "make the goals bigger"; game.rink.goal_width_m: 4 -> 4.4; files: data/sharks_gulls.cartridge.json"
   ("nothing was merged: the change was NOT made" when so). For Create to show it: read the last note starting
   "[foreman] what changed" before each `promoted` event and print it on the version line (engine/ui job_model/job_v2
   fold, the Create version card); no event schema change was made.

TESTS (foreman/src/test/e3f_change_path.test.ts; run against 9a9126f's sources by swapping them in place: 6 of 8 failed
there (the 2 pure new-function tests aside), all 8 pass now)
- E3f 1  replay of job 2's change decision (fake runner, the Planner's real answer "base" word for word): reopened =
         cartridge, diff game.rink.goal_width_m 4 -> 4.4, no base merge, skin.json and match.json of v0.1.1 byte-equal to
         v0.1.0, title still PIRATES; plus the "what changed" line.            [failed before]
- E3f 1b `--package base` change: note keeps data/match.json, data/skin.json; the base's merge lists neither nor the
         cartridge; skin/match/cartridge byte-equal.                           [failed before]
- E3f 2  job 1's shape (cartridge package owns cartridge + match.json + tests/bot_pond_drill.gd): "make it faster" merges
         only the cartridge; runner calls lint 3, bot 1, smoke 2, capture 1 (E4b's 7).   [failed before]
- E3f 3  base-named critic -> milestone round 2 + qualityHeld, no reopen/queued; job-scope named -> reopen; retry with a
         note -> a round; off a core -> E5 rule as before.                     [failed before]
- E3f 3b lookOk counts "core check NOT ok".                                    [failed before]
- E3f 4  real lines: job 1 fails, job 2 words only, hokej passes.              [failed before]
- E3f    coreChangeOwner / changeCandidates (pure).
- E3f 5  unseenChange both ways.

GATES
- foreman npm test: 365 tests: 358 pass, 0 fail, 7 skipped (was 357: 350 pass, 7 skipped; +8 = the E3f file).
- npm run build: clean. node devx/bin/tl.mjs check --tier fast: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3,
  devx.test 229/229, foreman.typecheck). foreman.ts 1986 lines (ratchet 2005), coreroute.ts 586, quality.ts 466.

FILES
foreman/src/coreowner.ts (new), foreman/src/foreman.ts, coreroute.ts, phases.ts, quality.ts, quality_state.ts,
cli_quality.ts, rinkjudge.ts, coregate.ts, fastchange.ts, foreman/scripts/rink-goal-band.mjs,
foreman/data/rink-goal-band.json (rate, minutes, minutes_from added), foreman/src/test/e3f_change_path.test.ts (new),
foreman/src/test/fixtures/e3f-lines/{job1,job2,hokej}.json (new; real tl.rink.check/1 lines).

DEVIATIONS / OPEN
- Rule 3 (frames every round) does not apply: no picture changes in this lane (Foreman TypeScript only).
- Job 2 does not fail the measured check: the data (bruisers pro 4.8 goals a minute, sudden death 0.4-0.6 min) does not
  make a 12-second golden goal a gross defect under the E3d quarter-span rule; it is words. If the Director wants it
  failed, that is a choice of rule (e.g. minutes below the shortest mode), not data.
- The base-owned test is "the critic's package field names the base" (or core/engine/camera/base by word); a critic that
  names a job package for a base-owned reason still revises.
- Create (engine/ui/job_v2.gd on_look) matches only "critic (V5) NOT ok: "; a held look whose verdict is
  "critic (V5) and core check NOT ok" would not show its reasons on the card (UI side, not touched).
- No real Foreman job was run; E5b re-runs after landing.
