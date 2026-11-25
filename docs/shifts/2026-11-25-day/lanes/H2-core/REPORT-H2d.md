H2d (the base: the header's clock, the ability plate's name), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-b at main
af53022 (H2c landed as 3f3659e).

== 1. A game on a clock shows its clock ==
- Cause: hud.gd's header line was rules.gd format_goal_rule(score_to_win) only: "FIRST TO 5", or "" when the rules have no
  score_to_win (a timer game), under "PERIOD 1". rules.gd had thirdjam's format_timer (cpp:431-435) but nothing called it.
- Fix: cards.gd reads game.rules.mode ("timer" -> cards.timer); hud.gd's header line is format_timer(snapshot TimerLeft)
  on a clock, "FIRST TO n" otherwise (one line changed; hud.gd stays at 600).
- Test: tests/bot_header.gd (template; selftest 868 registers it in a copy on a 3-minute clock): two hud.gd fed the same
  recorded match: the clock game's line is the time left on every play frame and counts down; the same game on first-to says
  FIRST TO 5. On the HEAD base it FAILS ("clock header on 0 frames"); now PASS: "clock header on 6000 frames (3:00 down to
  1:22), FIRST TO 5 on 6000, the plate in the skin's words on 6000".
- Stills (window, LOOKED AT): h2d_clock_cannon.jpg (the template copy: "PERIOD 1 / 2:55" between the scores, "F: CANNON
  READY x3"); h2d_g1_clock_and_bubble.jpg (a copy of G1's current pack on its three-minute clock with the newest hud files
  and a skin naming its tricks: "PERIOD 1 / 2:53" during a GOAL, the base plate "F: BUBBLE READY x1" beside G1's own hint
  "F: BUBBLE x1": one name on one screen).

== 2. One trick, one name ==
- skin.gd: new optional key ability_names (TYPE_DICTIONARY, default {}): the game's word for each trick by the core's kind
  {"shotgun": "cannon", "shield": "bubble"}; keys must be the core's kinds (shotgun, hip_check, shield, slow_puck) and values
  words, else a skin problem. ability.gd: the plate says the skin's word upper-cased ("F: CANNON  READY"), the core's id for a
  kind left out. hud.gd passes it (ability.setup).
- The Foreman's design check knows it: skinFields() reads a TYPE_DICTIONARY field as "ability_names.*", so "SKIN:
  ability_names.shotgun = cannon" and "SKIN: ability_names = {...}" are fields of the base's skin; a misspelt field is still
  refused (foreman/src/test/h2d_skin.test.ts, fails on the old code: "ability_names" was unknown).
- bot_header checks the plate in the skin's words on every frame the human holds a trick.

== 3. Arrows on the boost pads: G1's pack, not the base ==
The arrows are drawn by G1's own scripts/harbour.gd (_arrows; its zones "arrow*"); the base's fast_ice mark is
direction-free streaks along the rink (rink_toys.gd). G1's later harbour.gd already draws "a head at each end: the pad
speeds up a crosser going either way". Nothing to fix in the base.

== THE BASE'S LINE BUDGET (found on the way) ==
The base sits at the lint budget of 6,000 lines of game GDScript: HEAD was at the limit, and my additions put template and
hokej at 6,024 ("lint.size ... at most 6000": both packs failed lint, and foreman's e3g test failed). I folded comment
blocks in rink_toys.gd and hud/hint.gd and compacted my own additions: the base is 5,999 lines; lint passes on both
(template and hokej). The next base change has ONE line of room: the base needs a decision (a larger budget for a declared
base, or the HUD's long comment blocks moved to a doc).

== GATES ==
- hokej bot hashes, all 14, before (HEAD copy) and final: IDENTICAL, all passed (bot_match_hand fd162294891897fc ...
  bot_skin 0b476bdc7f9d4518; .tl/hashes-h2d-{before,final}.txt). One intermediate run had bot_skin FAIL (same hash): its
  check wants every skin key set, so ability_names got a default ({}); fixed, then passed.
- rink.: 47 PASS, 0 FAIL (45 + rink.header, rink.header_window); rink.template "42 files equal hokej's".
- hokej.: 5 PASS. k.sh selftest: 120 passed, 0 failed. tl check --only world: PASS [9/9].
- create.: 22 PASS + create.iterate.path FAIL once: the Foreman's `change` died on "EPERM, Permission denied ...
  foreman.lock" at JobLog.close (Windows held the lock file); not my code; rerun below.
- create.iterate.path rerun alone: PASS (15 steps).
- foreman npm test (final): 419 tests, 412 pass, 0 fail, 7 skipped (the first run failed e3g on the 6,024 lines: trimmed).
- tl check --tier fast (final): PASS arch 12/12, assets, cards, devx.test 229/229, foreman.typecheck; EXIT 0 (the first run
  failed arch on coreroute.ts 601 > 600: trimmed to 600).
- After the trims: lint template and hokej pass, rink. 47/0, hokej. 5/0, hokej hashes 14/14 identical (all final runs).

== FILES ==
engine/templates/rink_game/scripts/hud/{hud.gd, cards.gd, ability.gd, skin.gd, hint.gd (comments folded)},
engine/templates/rink_game/scripts/rink_toys.gd (comments folded), engine/templates/rink_game/tests/bot_header.gd (new,
not registered) = engine/packs/hokej/scripts/** the same; engine/tools/selftest.d/868-rink-hint.sh (rink.header,
rink.header_window); foreman/src/coreroute.ts (skinFields, skinAlias), foreman/src/test/h2d_skin.test.ts.
