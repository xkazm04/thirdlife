# E4 iterate: standup lines

- 00:40 Foreman: a change may grow the game (foreman/src/grow.ts: owner question answers "new" -> Planner adds <= 2
  packages, plan_set + reopened + queued; `wire` re-opens a kept package after the new one merges; holds grow too).
  grow.test.ts 2/2 on the phases fixture (fake adapter + fake runner): growth -> 0.1.1, then a court change -> 0.1.2.
  npm test 327 (320 pass, 7 env skips, 0 fail).
- 00:55 Create: done screen = Play + Add to menu + change box (foreman change); Changing: <words> while it builds;
  Continue for a build whose Foreman is gone; My games (top bar) lists the jobs root newest first and reopens one.
  Menu: kernel/dungeon/dungeons.gd person's list user://dungeons.user.json (TL_USER_DUNGEONS), read_menu() = shipped
  + mine; boot/hub.gd reads read_menu(). create_case: 40 passed, 0 failed (6 new create.iterate.* checks).
- 01:50 proof: selftest block 781 create.iterate.path (headless, real Foreman via the door in the exe's layout, fake
  adapter + fake runner): 15/15 steps (Continue, Pass x3, v1, grow -> v2, change -> v3, Play @0.1.2, Add to menu, My
  games, reopen, menu rows). Windowed stills in lanes/E4-iterate/stills/ (13, looked at). Gates: tl check --tier fast
  PASS; npm test 327 (320 pass, 7 env skips, 0 fail; final code incl. hold growth); ui.sh selftest --repo=<main> 212
  passed, 0 failed (206 + 6 new); selftest.sh create. 10/10. Not run: export.sh build/check (no fresh exe).
- landable E4
