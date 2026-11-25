E3 route, round E3b report (the E3 report went to the Director with the E3 landing; this file holds E3b).
==================================================================================================================
E3b (25 Nov, on hokej 812bc04 with E1, E2, E4 merged): the route integrated for real
==================================================================================================================
1. E2's validator, called by name. coreroute.ts imports validateCartridgeText and validateRulesText from
   foreman/src/cartridge.ts (no dynamic loader, no name guessing; the Foreman's own envelope check is gone). A refused
   edit's note carries E2's pointer-prefixed sentences one per line, e.g.
     - data/hockey.regular.cartridge.json at /kick: unknown key "kick" is not allowed here; remove it. Allowed keys: ...
   and the next round's builder prompt carries that note (the fake proof's round 2 matches on that exact text).
2. E1's base as it is. The base package copies engine/templates/rink_game minus pack.json, README.md, *.uid,
   .godot/, *.import: scope assets/** data/** gen/** scripts/** tests/**; registers from its pack.json (tests
   bot_match_hand, bot_first_match, bot_skin; cameras follow, top); acceptance lint, smoke, bot_first_match. The game's
   cartridge = data/match.json "cartridge" (hockey.regular.cartridge.json). No E1 file edited: the base's
   bot_match_hand has no PLAYER CHECK comment, and the Foreman's fallback line is true for it (its ok needs
   carried_frames > 0 and shots > 0). SKIN lines are now checked against E1's skin (title, tagline, about, team_names,
   levels, commentary, barks). card.rink_core 0.2.0 has "base": "rink_game" (tl cards check now requires the base).
   The real base passes the fake runner's lint (only README.md at the root would not; it is not copied).
3. E2's real check. runRinkCheck runs `bash engine/tools/rink.sh check-cartridge <file> [--rules <sidecar>]
   --json-only` and reads the last {"tool":"tl.rink.check/1"} line: exit 0 + ok = measured, 1 = refused or a match
   did not end, 2 / ran:false / no line = could not run (never a pass). Figures shown: wins per level and the pro
   playtester's goals, minutes, carry, loose share, shots, passes, speed, possession changes, touches, knockdowns;
   warnings and problems in words. The fake runner's stand-in now validates with E2 and emits a tl.rink.check/1 line
   judged by the same reader.
   Measured for real once on this machine (thirdjam's regular playtester, 10 seeds a level; 20 s each):
     base hockey.regular:   pro wins 7/10, 4.3 goals a match, 2.9 min, mean speed 9.4 m/s, 15.8 knockdowns
     "make it faster" diff (game.skater.speed 11 -> 14, game.skater.accel 12 -> 30, validated by applyChanges):
                            pro wins 8/10, 4.2 goals, 1.5 min, mean speed 13.9 m/s, 4.1 knockdowns; WARN the mean speed
                            13.9 is above anything thirdjam ships (6.2..10.3) at every level.
4. E4's asks. cli.ts:561: `foreman plan --from` normalises a hand-written core plan (normalizeCorePlan(..., planCore(known)))
   before the plan check (test added). Create's recipe: card.rink_core now has its own `interview` (players 5/4/3 a side,
   opponents rookie/pro/all_star, win first to 3 / sudden death / three minutes, rink regular 90 x 45 / pond 60 x 30 /
   marathon 140 x 70, each proposal with its MODES.md or README reason) and a footprint (90 x 45, from the base's
   cartridge). Create's Recipe dropdown sends its proposals as --answers. Its match words (pond hockey, hokej, shinny,
   bandy, rink core, thirdjam, a side) take "pond hockey, three a side, sudden death" in the old workbench; a plain
   "ice hockey, three against three" still matches team_possession there, because the old workbench's scripted drives
   and village stamps (ui/editor/drive_editor.gd, selftest_place.gd, village_board.gd) are built on it: moving plain
   "hockey" is E4's/the Director's call. engine/ui/selftest.gd (E4's file): the interview list and question counts
   gain rink_core, plus one new check; the workbench block run headless: 59 of 59 PASS (the whole ui selftest did
   not finish inside 10 minutes here, so only the workbench block was run).
5. A change round on a core game is a cartridge diff first (E4's seam, foreman.ts:1292, after reopen):
   coregate.ts cartridgeChange: the owner holds the game's cartridge -> one generate call (role "cartridge",
   prompts/cartridge-change.md: the change in the person's words, the cartridge, CARTRIDGE.md sections 3 and 5)
   answers {changes: {key path: value}, why} -> E2's applyChanges applies and validates it (refused: asked once more
   with E2's errors) -> the measured check on the cartridge before and after -> the note "cartridge diff: <path: a -> b;
   ...> (why); measured before: ok (...); after: ok (...)" and reports/<pkg>-r<n>-diff-s<seq>.json (tl.foreman.diff/1).
   The round then runs with no builder (foreman.ts:829 diffRound puts the diffed cartridge into the workspace), is
   validated, verified and merged as any round, and the job promotes a new version. Falls back to a builder round
   (with the reason in a note) when: no key says it (empty diff), the diff changes nothing, refused twice, the
   generate call fails, or the after-check fails the cartridge.
   The fake proof (core_route.test.ts, driven as foreman_door.gd drives Create: new --site <jobs> + flags.new;
   approve; plan + flags.plan; run + flags.run; phase pass x2 + flags.resume; change + flags.change):
     v1 promoted -> change "make it faster" -> note "cartridge diff: game.skater.speed: 11 -> 14; game.skater.accel:
     12 -> 30 ...; measured before: ok (... pro_speed_mean 6.82 ...); after: ok (... pro_speed_mean 8.68 ...)", no
     builder_run for that round, version 2 promoted with speed 14, version 1 kept with 11 -> change "make the puck
     bounce like a ball" -> "cartridge diff not made: no key says it" -> exactly one builder round -> version 3.

FOREMAN.TS / CLI.TS lines of E3b (E4's files): foreman.ts:28 (import), :829 (diffRound before callBuilder),
:1292 (cartridgeChange after reopen); cli.ts:16-17 (import), :561 (normalise a --from core plan).

GATES (E3b): npm test (foreman): 348 tests, 341 pass, 0 fail, 7 skipped (the 7 earlier skips; none of E3s). tl check --tier fast PASS 5/5 (arch 12/12, assets 4/4, cards 3/3,
devx.test 229/229, foreman.typecheck). core_route.test.ts: 15 tests, 15 pass, 0 skipped (was 15 with 3 skips).

OPEN
- The fake stand-in's figures are made from the cartridge, not played: only the two real runs above are measurements.
- The measured check takes about 20 s a cartridge on this machine; a change round runs it twice (before, after).
- Plain "hockey" in the old workbench (not the exe's Create) still proposes team_possession's interview (see 4).
