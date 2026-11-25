E4 iterate: report (night of 24-25 Nov 2026; worktree .claude/worktrees/hk-create, branch hk-create at hokej fdeb09f)

What the person can do now, in one paragraph
After a build (and after any change) Create's done screen has Play, Add to menu and a change box ("What should change?
Faster, bigger, a new power..." + Change it). A change goes out as `foreman change <job> "<words>"`; the page shows
"Changing: <words>" over the passed phase strip while it is made, then the done screen again with "version N". A change
that adds something no package holds now GROWS the game: the owner question may answer "new", the Planner adds up to two
packages (and may name a kept package to wire them in, re-opened after the new one merges). At a phase pause the Hold
note is the change box (a phase hold is a change round by JOB.md), and it may grow the game too. My games (top bar,
every screen) lists the jobs root newest first with their state in words and version; a row reopens the job where its
log stands (play/change a done game, pass/hold a waiting phase, Continue a build whose Foreman is gone). Add to menu
writes the person's own dungeon list (never engine/boot/dungeons.json); the main menu's Dungeons lists it as "made by you
in Create" and plays the newest version; "In the menu" takes it out again.

The five rounds, one by one
1. Change box on done + at the phase pause: MET. Done: ChangeBox / SendChange -> door.change (foreman_door.gd `change`,
   already there, now reached from the exe's Create). Phase pause: Hold + note (`foreman phase hold --note`), which JOB.md
   defines as a change round on that phase's packages; no third button was added beside Try it / Pass / Hold (one box per
   screen; say so if you want a separate "Change" there). Cartridge seam: not wired (E2's cartridge.ts had not landed
   here); the seam is the owner question in foreman/src/grow.ts `ownerOrNew`: its rules already say "a game whose rules
   come from a data file (a cartridge, a tuning file) changes in the package that owns that file, also for a new ability,
   pickup, zone or variant the file has a place for" - so a cartridge game's change goes to the package owning
   data/*.cartridge.json. When cartridge.ts lands, a change whose owner holds a cartridge can be sent through its diff
   before the builder round (a call in foreman.ts applyChangeRequests right after `owner` is known).
2. A change may add a package: MET (Foreman). foreman/src/grow.ts (new). JOB.md wording proposed below.
3. Reopen later (My games): MET. create_model.gd games()/state_word(); create_build.gd _games()/open_game(); Continue
   (door.resume) for a build with no live Foreman.
4. Add to menu: MET. kernel/dungeon/dungeons.gd: user_path(), read_user(), add_user(), remove_user(), user_row(),
   read_menu(). The file: user://dungeons.user.json (in the exe: the ThirdLife user dir), or TL_USER_DUNGEONS.
   Shape {"schema": "tl.dungeons.user/1", "dungeons": [{"pack": <absolute promoted folder>, "title", "job"?, "look"?}]};
   unknown keys / relative pack / title > 80 are errors (row left out). boot/hub.gd load_rows() now calls read_menu()
   (shipped list, then the person's rows marked mine); boot/menu.gd shows "made by you in Create" for them. Create moves a
   listed job's row to its newest promotion when it shows the done screen.
5. Proof on the FAKE adapter: MET for the Create panel path with the exe's door layout; NOT run in a freshly exported
   .exe (export.sh build/check were not run: time and machine load). Details under Proof.

Proof (all fake adapter, no model called)
- foreman/src/test/grow.test.ts (2 new tests): the phases fixture built to done, then "add rocket skates..." -> owner
  "new" -> plan_set (core, court, paddle_ai, fx, rocket; rocket joins the last phase) -> reopened rocket (reason starts
  "change request (event N); the Planner adds a package for it") -> rocket queued r1 -> `[foreman] wire in rocket ...`
  change request for core, applied only after rocket was promoted -> promoted 0.1.1 (main.gd carries the wire-in, rocket.gd
  present, the first promotion kept); then "the rallies are too slow..." -> court (old path, no plan_set) -> 0.1.2.
  Plus ownerOrNew refuses anything but a listed id or "new"; growProblems refuses a kept id and an unknown wire.
- engine/ui/create/create_iterate_checks.gd (6 checks, in ui.sh selftest and kernel selftest 630): model (version,
  changing, change note after a failed change, Foreman wire request not shown as the person's), change box -> exact
  `change` command line and "Changing:", Continue -> `resume`, Add to menu / read_menu / follow newest / remove, My games
  order and reopen, the list's rules.
- engine/tools/selftest.d/781-create-iterate.sh (new block): headless, real Foreman processes through the door with the
  exe's layout (res:// = "", exe at <repo>/dist/ThirdLife), ui/create/stage.gd --mode=iterate: Continue, Pass x3,
  version 1, grow -> version 2, change -> version 3, Play launches --dungeon=.../promoted/game.paddle_court_crazy@0.1.2,
  Add to menu, My games, reopen, read_menu lists it playable. 15 of 15 steps; a missing end line or fewer steps is FAIL.
- Stills (1280x720, windowed run of the same mode with the real main menu at the end; LOOKED at, listed below):
  docs/shifts/2026-11-24-night/lanes/E4-iterate/stills/
    it-01-continue        a reopened build with no Foreman: Continue
    it-02-phase-done      phase 1 ready: Try it / Pass / Hold
    it-03-done-v1         done: Play, Add to menu, the change box
    it-04-typed-grow      "add rocket skates: hold the boost key to fly forward" typed
    it-05-changing-grow   phases passed, "Changing: add rocket skates ..."
    it-06-done-v2         "Paddle Court . version 2"
    it-06-typed-change    "the rallies are too slow: make the court smaller"
    it-07-changing-change "Changing: the rallies are too slow ..."
    it-08-done-v3         version 3 ; it-08-in-menu: the button now reads "In the menu" (green)
    it-09-my-games        My games: "Paddle Court  Ready, version 3 . in the menu"
    it-10-reopened        the row reopens the done screen
    it-11-menu-dungeons   the exe's main menu, Dungeons: the shipped four + "Paddle Court / made by you in Create"
  What I saw and fixed on the way: the first run's change-round screen showed phase 1 as building again (the GDScript
  reader re-opens a phase whose package is re-opened) and no "Changing" line; now a change on a handed-over game keeps
  the strip passed and shows the line (it-07). The change clock counted from the job's first event (94 h); it now counts
  from the change. Still seen and left: a reopened job's build clock counts from the job's first event (it-01, "94:05").

Gates
- node devx/bin/tl.mjs check --tier fast: PASS (arch 12/12, assets, cards, devx.test 229/229, foreman.typecheck).
- npm test in foreman/: see the standup's last line (327 tests before the hold-growth edit: 320 pass, 7 environmental
  skips, 0 fail; main had 325, +2 new).
- bash engine/tools/ui.sh selftest --repo=C:/Users/kazda/kiro/third-life: "[selftest] 212 passed, 0 failed" (H3 had 206;
  +6 = the new create.iterate.* checks; nothing else moved).
- bash engine/tools/selftest.sh create. : 10 passed, 0 failed (630 create.*, 780 create.go.*, 781 create.iterate.path).
- One check bound changed: create_checks.gd "words on screen ... done" <= 15 became <= 30 (done now carries Add to menu
  and the change box: 26-29 words).

Files (all inside my scope, plus the two menu readers the task names)
- foreman/src/grow.ts (new), foreman/src/testing/grow-steps.ts (new), foreman/src/test/grow.test.ts (new)
- foreman/src/foreman.ts, lines touched (E3: none of these is the builder-run path):
    imports 21-22 (whoOwns dropped; grow.js imported), changeReady 169-170 (a wire request waits), the phase step
    call at 270 (phaseStep gets a `grow` hook), the new private rootId() + growHost getter 1211-1240 (just before
    packageLines()), and applyChangeRequests 1259-1286 (ownerOrNew instead of whoOwns; the "new" branch).
    foreman.ts is 1943 lines (ratchet 2005).
- foreman/src/phases.ts: PhaseHost.grow? (optional); applyHolds asks ownerOrNew (also for a one-package phase when grow
  is there) and grows on "new".
- engine/ui/create/{create.gd, create_build.gd, create_kit.gd, create_model.gd, create_checks.gd, stage.gd} +
  create_iterate_checks.gd(.uid) (new)
- engine/kernel/dungeon/dungeons.gd (the person's list), engine/boot/hub.gd (1 line: read_menu), engine/boot/menu.gd
  (1 line: "made by you in Create")
- engine/tools/selftest.d/781-create-iterate.sh (new)
Not touched: contracts/*, cli.ts (861 ratchet, 856 lines), promoter.ts, engine/boot/dungeons.json, designer.ts, prompts/.

Proposed JOB.md wording (Director-only; a new section)
### Added 2026-11-25: a change may grow the game; the person's dungeon list
- The owner question of a change request (and of a phase hold) may answer `"new"`: the request adds something none of
  the plan's packages' files can hold. The Planner is then asked for at most 2 new packages (the planner prompt plus a
  growth section; the kept packages are fixed: no id, no file of theirs). The Foreman writes `plan_set` (the kept
  packages + the new ones; `card` and `phases` stay; each new package joins the phase being built now, else the last
  phase), then per new package `reopened {package, reason}` whose reason starts `change request (event N); the Planner
  adds a package for it` (for a hold: `phase hold (event N) on phase P; the Planner adds a package for it`), then
  `package_state queued` round 1 with detail `CHANGE REQUEST: <text>`. The request is taken by that `reopened` (its text
  joins the new package's brief). Without a usable growth answer the root package (a hold: the phase's first) takes it.
- A growth answer may name up to 2 kept packages in `wire`: for each the Foreman writes `change_requested {package,
  text}` whose text starts `[foreman] wire in <new pkg> (added for change request event N; ...)`; such a request waits
  (is not applied) until <new pkg> is promoted. Readers that show the person's requests leave out `[foreman] ` ones.
- Not a contract of the job log, for the record of the exe: Create's "Add to menu" writes the person's dungeon list
  user://dungeons.user.json (`tl.dungeons.user/1`, kernel/dungeon/dungeons.gd), never engine/boot/dungeons.json; the
  main menu reads the shipped list, then this one.

Questions for the Director
1. Phase pause: keep Hold as the change box (as now), or add a fourth "Change" beside Try it / Pass / Hold that sends
   `foreman change` (any package, not only the phase's)?
2. The cartridge route (E2/E3): when cartridge.ts lands, should a change whose owner holds a cartridge first try a
   cartridge diff (no builder round) and only then fall back to the package round? The seam is named in round 1 above.
3. hub.gd/menu.gd are boot files (L4's); the two one-line edits there are the menu's reader of the person's list.
