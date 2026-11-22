N4 create: the editor cannot start a new idea (night of 22-23 Nov 2026)
Lane N4, Opus solo, worktree .claude/worktrees/n23-create (branch n23-create, from main 1fa3b56).
Round 1 (the fix) landable 19:44, LANDED as merge 88ae2cd. Round 2 (export.sh check step 3b) landable 20:09.

WHAT THE OWNER MET
In the exe (d22-int/dist, build 48c4f59), Menu > Create > type an idea > GO puts a red toast on the page and nothing starts:
  "The builders cannot start: Foreman not found (no foreman/dist/cli.js above the engine)"
Still: evidence/before-05-after-go.jpg (typed idea: evidence/before-04-typed.jpg). Reproduced in a copy of that build
(.tl/repro48) with the fake-adapter settings, so no real job could start. Typing, the chips and GO itself all work.
The owner's own run log (evidence/before-owner-run-1853.log, copied from d22-int/dist/ThirdLife/ThirdLife-last-run.log,
18:53-18:57: World, three dungeons, World, Create) ends on "[boot] menu: Create": the page logged nothing, and no
d22-int/site/_ui_logs exists, so no Foreman was ever started from that build.

CAUSE (file:line, as of main 1fa3b56)
1. engine/ui/foreman_door.gd:30  cli_path = find_cli(ProjectSettings.globalize_path("res://"))
   (and engine/ui/create/create.gd:66 for the jobs root). In an exported build res:// globalizes to "" (the files are in
   the .pck; boot/probe.gd:27 already says so), find_cli("") stops at once, and check() (foreman_door.gd:60) reports
   "Foreman not found"; create_design.gd:169 puts it on the toast. Every exe had this; only the editor binary worked.
2. Latent behind it, engine/ui/foreman_door.gd:25  runner_path = globalize_path("res://ui/foreman_run.mjs") is the relative
   "ui/foreman_run.mjs" in an exe, and the export (include_filter *.json) carries no .mjs: once the Foreman was found,
   node would have had no starter to run ("the Foreman wrote nothing").
Ruled out: node not found (it answers: v24.14.0), no flags (res://ui/flags/real.json is in the pck), a button wired to
nothing, a field that takes no keys (typing and GO work: before-04-typed.jpg).

THE FIX (engine/ui only)
- foreman_door.gd: disk_dir() / disk_dir_of(res_dir, exe): res:// when it is a folder on disk (editor binary), else the
  executable's folder; find_cli walks up from there (dist/ThirdLife beside a checkout finds that checkout's Foreman).
  find_runner(dir, cli): the engine's own ui/foreman_run.mjs, else <repo of the found cli>/engine/ui/foreman_run.mjs.
  check() says when the starter is missing; "Foreman not found" now names the folder it looked from.
  setup() takes res_dir + exe (a selftest gives an exe's layout) and runner; from_dir is kept on the door.
- create/create.gd: the jobs root is found from Door.disk_dir(); setup takes door options ("door": {...}); the exe's log
  gets "[create] jobs ...; Foreman ...; starter ...; node ...; settings '...': ready|<problem>" when the page opens and
  "[create] the Foreman stopped: ..." when a start fails later.
- create/create_design.gd: GO logs "[create] GO: <toast>" or "[create] GO: foreman new '<sentence>' started".
The designer panel (ui/panel.gd, ui/host.gd) uses the same door and gets the same fix.

PROOF IN AN EXPORTED EXE
bash engine/tools/export.sh --commit "1fa3b56+N4" in my tree: "PASS export.build: tag 1fa3b56 2026-11-22 19:37"
(HEAD 1fa3b56 plus the uncommitted N4 diff). Started like PLAY-LATEST.cmd (working dir = the exe's folder) with
TL_CREATE_FLAGS=<flags.fake-designer.json> (fake adapter, the Designer's answer from Foreman's own test helpers; no model).
Menu > Create > "Penguin push" > GO: "The designer is thinking", then the pitch with three aspect cards, Redesign, Build it.
  evidence/after-03-create-page.jpg, after-04-chip.jpg, after-05-designing.jpg, after-06-pitch.jpg,
  evidence/after-create-go-to-pitch.mp4 (26 s, the window), evidence/after-run.log:
  [create] jobs .../n23-create/site; Foreman .../n23-create/foreman/dist/cli.js; starter .../n23-create/engine/ui/foreman_run.mjs; node v24.14.0; settings 'fake adapter (the Designer answers)': ready
  [create] GO: foreman new 'penguins pushing each other off an iceberg' started
The job site/penguins-pushing-each-other-20261122-1 was written by the Foreman (fake adapter; gitignored).
Note: in my first after-run the scripted arrow keys did not reach the menu (the window did not hold the focus for the
driver; menu.gd is unchanged and keys worked in the before run); the recorded run picks Create with the mouse.

TESTS
- ui.selftest (engine/ui/selftest.gd, section 4): 5 new checks of the exe layout (the walk up from '' finds nothing;
  the exe's folder; the door set up as an exe finds the checkout's Foreman, starter, node; the paths; an exe with no
  checkout above says where it looked). Gate: "PASS ui.selftest [206/206]" (main's selftest.gd: 201 passed, 0 failed).
- New kernel selftest block 780 (engine/tools/selftest.d/780-create-go.sh + engine/ui/create/create_go_case.gd +
  engine/ui/fixtures/make_designer_fake.mjs): the Create page with the exe's door layout, a chip and GO run
  `foreman new` for real with the fake adapter until the pitch is on the page. create.go.door, create.go.started,
  create.go.pitch: 3/3 PASS (about 40 s). With main's create.gd/create_design.gd/foreman_door.gd: create.go.door FAILS
  ("looked from <null>"). Honest limit: the headless editor binary globalizes res:// to the engine folder, so a headless
  test sees the exe only through the res_dir/exe seam; the exe proof above is the real one. Every earlier Create/door
  test ran the door dry, which is why none started a Foreman.
- bash engine/tools/selftest.sh create.  -> 9 passed, 0 failed (630 create.* 6 + 780 create.go.* 3).
- node devx/bin/tl.mjs check --tier fast -> PASS arch [12/12], assets [4/4], cards [3/3], devx.test [229/229],
  foreman.typecheck; exit 0. Full tier not run (no kernel, kits, rigs, style or seeds change); ui.selftest run alone.

CHANGED FILES
  M engine/ui/foreman_door.gd, engine/ui/create/create.gd, engine/ui/create/create_design.gd, engine/ui/selftest.gd
  A engine/tools/selftest.d/780-create-go.sh, engine/ui/create/create_go_case.gd (+ .uid),
    engine/ui/fixtures/make_designer_fake.mjs, docs/shifts/2026-11-23-night/lanes/N4-create/ (BRIEF, STANDUP, REPORT,
    evidence/: 6 JPG stills, one 26 s mp4, 3 logs)
No foreman/, export script, contract or claim outside the brief was touched (foreman/dist and node_modules were built in
my tree only, gitignored; site/ holds plain copies of the two marble jobs and the fake job, gitignored).

BEHAVIOUR CHANGES (owner and Director, read this)
- After a fresh export, GO in Create WORKS: with the build's own settings (res://ui/flags/real.json: claude-cli sonnet)
  it starts a REAL Foreman `new` (a model call) into <checkout>/site. Tonight's rule is no Foreman jobs: do not press GO
  in a fresh exe without TL_CREATE_FLAGS pointing at fake settings.
- An exe with no checkout above it (a copy elsewhere) still says "Foreman not found (no foreman/dist/cli.js in <folder>
  or a folder above it)": the exe needs a checkout with a built Foreman (npm --prefix foreman ci && npm --prefix foreman
  run build) and node on PATH.
- The 780 block needs foreman/dist built (as ui.selftest already does); without it it FAILS with that instruction.

ROUND 2: export.sh check step 3b, Create (the Director's answer to question 2)
- engine/tools/export.sh check, step 3b (with the window steps 2 and 3; --no-window skips it): writes the fake Designer
  settings into the check folder (engine/ui/fixtures/make_designer_fake.mjs), refuses to start when any adapter there
  is not "fake", then starts the exe with `-- --menu` and TL_EXE_CREATE_GO="penguins pushing each other off an
  iceberg", TL_CREATE_JOBS=<check>/create/jobs. PASS needs: exit 0, a create_go line with ok and screen pitch, the
  "[create] jobs ...; settings 'fake adapter ...': ready" line, and a job folder whose job.jsonl holds brief_set.
  The final PASS line now also says "starts a new idea in Create up to the pitch (fake adapter)".
- engine/boot/hub.gd: the TL_EXE_CREATE_GO instrument (with TL_EXE_CREATE_FRAMES, default 3600, and TL_EXE_CREATE_SHOT):
  the menu opens Create through _menu_create (the button's function), the sentence goes in, the page's own go() is
  pressed, and after the pitch or a toast (counted in frames) one "create_go" JSON line is printed and the process ends
  (exit 0 pitch, 1 otherwise).
- engine/ui/create/create.gd: "[create] screen: <name> (<job>)" on the log whenever the shown screen changes (not dry).
Evidence:
- My tree at 88ae2cd + round 2: export "PASS export.build: tag 88ae2cd 2026-11-22 19:52"; then export.sh check:
  "PASS export.check: build '88ae2cd 2026-11-22 19:52'; the exe runs the same games and 3 dungeons to the same hashes as
  the editor binary, shows the village, obeys W and Esc, starts a new idea in Create up to the pitch (fake adapter), and
  leaves nothing behind". 3b: "GO reached the pitch in 27 frames, job penguins-pushing-each-other-20261122-1 (fake
  adapter)". evidence/r2-export-check.log, r2-export-check-create.log, r2-export-check-create-pitch.jpg.
- The first check run FAILED 3b although the exe reached the pitch: my condition picked jobs/_ui_logs (the door's
  log folder) as the job. Fixed to the folder that holds a job.jsonl; the second run is the PASS above.
- Negative: the same exe copied to %TEMP% (no checkout above it) with the step's environment prints create_go ok:false,
  "The builders cannot start: Foreman not found (no foreman/dist/cli.js in .../Temp/tl-n4-noco/ThirdLife or a folder above
  it)", exit 1: 3b would FAIL on the 22 Nov condition (evidence/r2-no-checkout-negative.log). An exe from before round
  2 has no instrument: it prints no create_go line, and 3b FAILS after its 240 s limit.
- Gates for round 2: tl check --tier fast PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck);
  ui.selftest 206/206; selftest create. 9 passed, 0 failed.
- Round 2 changed files: M engine/tools/export.sh, engine/boot/hub.gd, engine/ui/create/create.gd; lane folder.

QUESTIONS FOR THE DIRECTOR (answered 19:47)
1. Prove Build it from the exe? No: no real job tonight.
2. A Create step in export.sh check? Yes: round 2 above.
3. Ship foreman_run.mjs beside the exe? Not tonight; the exe borrows the checkout's copy (next item 1 below).
Open: export.sh check step 3b, like selftest 780, needs foreman/dist built in the checkout (main has it); a fresh
worktree without it FAILS 3b with "build the Foreman first".

NEXT THREE THINGS THIS LANE WOULD DO
1. Ship the starter with the exe (export.sh copies engine/ui/foreman_run.mjs beside ThirdLife.exe; the door already
   looks in the exe's folder first), so an exe moved away from its checkout needs only a Foreman, not the engine files.
2. Build it -> phase 1 from the exe with the fake builder, when real jobs are allowed again (TL_GODOT / TL_ENGINE_DIR for
   the Foreman's verifier are not set by the exe today; untested).
3. A probe row (boot/probe.gd) for "Create's Foreman: ready | <problem>", so `ThirdLife.exe -- probe` tells it at once.
