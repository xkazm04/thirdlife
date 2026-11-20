L3 create-screen: REPORT (night of 21 Nov 2026; worked 20:09-23:15 by the machine clock of 20 Nov)
Worktree .claude/worktrees/n21-create, branch n21-create. Base d5967cc; the Director fast-forwarded it to main b28477c
(L2 + L4 landed) under my uncommitted work at 23:20. All of my work is uncommitted (I ran no git writes).

WHAT IS THERE
- res://ui/create/create.tscn: the Create page. Root has `func open() -> void` and `signal closed` (COMMON menu seam).
  Full screen, drawn on a 1280x720 stage scaled to the window. Split by inheritance for the size ratchet:
  create_kit.gd (inks, state, cel keycaps, CRAZY sticker) <- create_design.gd (idea, designing, pitch, cards, Tell me
  more) <- create_build.gd (phase strip, phase done, done, failed) <- create.gd (setup, job reading, polling, input).
  create_model.gd = pure rules (screens, tap cycle, pending reactions, strip, try/play dirs, word counts).
  icon.gd = the 15 contract icons + interface glyphs drawn with shapes (no picture files, nothing for the asset manifest).
- Readers of JOB.md 2026-11-20: kernel/world/site/event_schema.gd (strict: every new key, word limits, 3-7 aspects,
  2-3 alternatives, 2-5 phases as a partition with deps in the same or an earlier phase, hold needs a note; plus L2's
  three narrowings), ui/job_model.gd + new ui/job_v2.gd (creativity, run_through, pitch, aspects, reactions per latest
  brief, phases with states passed/done/held/building/next, phase_wait, pause_kind "phase").
- kernel/world/site.gd: `phase_of(events)`; `view_of` carries `phase_line` ("phase n of m: <title>") and the [site]
  report carries `phase`. The sign itself is drawn by L1's draw.gd: patch in PATCHES.md (P1, two small edits).
- ui/foreman_door.gd: new_game(..., {creativity, run_through}), redesign, approve_v2, react steps, phase.
  ui/foreman_run.mjs: a `phase` step ending 3 (stopped at the next phase) or 1 is the job's outcome, not a door error.
- Fixtures: ui/fixtures/create/c1..c12 (written by ui/fixtures/make_create_fixtures.mjs): one crazy-mode game (Penguin
  Push) from sentence to done in 3 phases with a hold, plus a failed build, a failed design and a run-through job.
- Tests: ui/create/create_checks.gd (27 checks) run by `ui.sh selftest` (section 8) and by selftest.d/630-create.sh;
  selftest.d/631-create-site.sh plays the village with two lots on c5/c8 in a real world.
- ui/create/stage.tscn: host for stills (--mode=stills), the clip (--mode=clip, input events + a drawn pointer, record
  with --write-movie), a live run against a real Foreman (--mode=live), and a phased job driven by the page's own
  buttons (--mode=phases, TL_FOREMAN_CLI names the Foreman).

CHOICES
- Interview vs aspects: I did NOT show a card's interview questions as aspects. A reaction must name an aspect of the
  brief (aspect_reacted), and interview answers can only be given at `foreman new` (--answers), so tapping them after
  the Designer has answered could write nothing. A brief without aspects (a job made before v2) shows its five parts
  as read-only cards ("The rules", "The place", ...), Build it works, no tap hint.
- Card hint (expert drawer, "Recipe"): `foreman new` has no card flag, so a picked recipe goes as that card's proposed
  answers through `--answers` (JOB.md 2026-11-19), the only card-shaped key `new` takes. "Designer picks" sends none.
- Taps are local until Redesign or Build it; then only the reactions the log lacks are written (one `react` per
  changed aspect, before `redesign` or `approve`).
- Try it on a WIP phase opens <job>/pack. Play on a done job opens the last promotion (<job>/promoted/<id>), and
  falls back to <job>/pack. Both go through L4's seam, kernel/dungeon/dungeons.gd: `launch(dir)` starts the process and
  `launch_args(dir)` gives the arguments that are recorded. This is wired in create_build.gd `launch()`, so the
  Director has nothing to wire at merge.
- Pass/Hold wait while a Foreman still holds the job (found live: the log said phase_done ~0.5 s before the process
  that wrote it ended, and `phase` is refused then). The page shows "building" until it lets go.

ACCEPTANCE
1. ui.sh selftest green with fixture cases for each state: MET. [selftest] 195 passed, 0 failed (base 166; +27 Create
   checks, +1 panel v2 case, +1 the complete marker). tl check --tier fast: see GATES (one inherited red).
2. Kernel file changed, world must pass, a fixture log with every new key read by event_schema.gd: MET.
   - tl check --tier full --only world: PASS 8/8 games world = alone.
   - create.schema: all 12 fixtures (358 of 358 lines) pass the strict reader; c9-done + c12-run-through hold all 29 new
     keys; 25 broken copies are refused each for its own reason.
   - create_site.read/phase (631): a real world with lots on c5/c8 reads 22/22 and 52/52 events and reports
     "phase 1 of 3: Slide and bump" | "phase 2 of 3: Rivals and cracks". Before (base event_schema.gd): FAIL
     "lot 0: job.jsonl line 1: unknown key 'job_created.creativity'".
   - L2's real output: `foreman init-fixture --phases` run through 3 phases + a hold with L2's Foreman: 102/102 events
     read strictly, every screen right (phase_done x4, done).
3. Stills of states 1-6 and a 20-30 s clip: MET. lanes/L3-create/stills/ (28 JPG, 1280x720): 1-idea, 1b crazy,
   1c drawer, 2a/2 designing, 3 pitch, 3b tapped, 3c Tell me more, 3d redesigned, 4 building, 4b held, 4c phase 2,
   5 phase done, 5b hold note, 6 done, 7 failed, 7b design failed; 8-* a live v1 job with a real Foreman (fake
   adapter); 9-* L2's real phased job driven by the page's buttons; 10-* the exe main menu opening and closing Create. create-sheet.jpg (16 states, 391 KB).
   create-clickthrough.mp4: 27.0 s, 1.4 MB: type the idea, Crazy, Go, designing, pitch, tap tap, drop, Tell me more,
   Build it, building, phase done, Try it, Pass, phase 2, done, Play. Driven from fixtures with input events.
4. Every CLI call matches JOB.md: MET (create.door + create.page check the exact argument lists). The calls:
     foreman new "<sentence>" --site <jobs> <new flags> [--answers <json>] [--creativity crazy] [--run-through]
     foreman react <job> <aspect> keep|drop|<alternative id> [--note "<text>"]     (one per changed aspect)
     foreman redesign <job> <redesign flags, else new flags>
     foreman approve <job> ;; foreman plan <job> <plan flags> ;; foreman run <job> <run flags>
     foreman phase <job> pass <resume flags>
     foreman phase <job> hold --note "<text>" <resume flags>
   Positional parts are the contract's word for word; the trailing flags are the adapter settings of the flags file
   (as every Designer/run command of the panel already takes them). Standard writes no --creativity.
   Live proofs: (a) v1 Foreman of this tree, fake adapter: Go -> designing 0.6 s -> pitch 4.6 s -> Build it -> building
   -> done 89 s, Play -> --dungeon=<job>/promoted/game.marble_run_three_marbles; (b) L2's Foreman: the page's Try it
   (recorded), Pass, Hold + note, Pass, Pass -> done in 32 s, every step through foreman_door.
5. 10-year-old path and word counts: MET. Words on each screen (all visible labels, buttons, placeholders):
   idea 37 (heading 6, placeholder 3, GO, 6 chips 12, Standard/Crazy 2, its line 8-9, Menu, CREATE, More),
   designing 17, pitch 98 (6 cards: titles 15 words, lines 56; pitch 14; buttons and hint 9), building 52,
   phase done 36, hold note 36, done 11, failed 19.
   The path idea -> Go -> tap tap -> Build it needs: the heading, a chip or a typed idea, GO, card titles and the
   colours/dots, Build it. Nothing longer than the contract limits is on screen (the pitch <= 20, lines <= 12, titles
   <= 4 come from the log; the v1 fallback cuts each part at 80 characters).
   Readability: smallest type on the stage is 17 px = 12 px cap height at 720p (Archivo's H measured with PIL), the
   floor the 19 Nov HUD lane accepted for captions; most text is 22-62 px.

GATES (this tree after the fast-forward to b28477c, at 23:10-23:14 unless noted)
- tl check --tier fast: PASS 5/5: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck.
  Before the fast-forward, devx.test was 228/229: the assets manifest scan failed in every n21 worktree. That fail was
  inherited and is fixed on main (dd1064f).
- tl check --tier full --only world: PASS 8/8 (world = alone, every game of games.json).
- engine/tools/ui.sh selftest: [selftest] 195 passed, 0 failed.
- bash engine/tools/selftest.sh create (blocks 630 + 631): 8 passed, 0 failed.
- Earlier full gate (22:08, before the fast-forward, 5 lanes loading the machine): 12 of 14 steps PASS.
  - PASS: arch, assets, cards, foreman.typecheck, foreman.test 217/223 (6 skipped), kit.selftest 95/95, packs 2/2,
    perf, seeds 39/39, item.selftest 91/91, ui.selftest 195/195, world 8/8.
  - FAIL: devx.test (the inherited assets red above).
  - FAIL: kernel.selftest. It was killed at the gate's 1800 s cap after 212 of 213 units, 0 failed. A killed run is
    a stopped run, not a pass.
- bash engine/tools/selftest.sh run alone, without the cap (22:10-22:56, before the fast-forward): 353 passed,
  3 failed, 356 run, 46 min.
  - surf.model and blend.car_origin: inherited, fixed on main dc9024b.
  - k2.down_invariants: passes alone (`selftest.sh k2.down` 4/4). The Director accepted it as load.
  - All 8 of my cases passed.
- The menu (L4's exe hub, boot.tscn --menu, real mouse clicks; ui/create/stage.tscn --mode=menu):
  "Create button found" -> "after Create the page is open" -> "after the page's Menu button the page is gone and the
  menu is back", exit 0. Stills: 10a-exe-menu, 10b-exe-menu-create, 10c-exe-menu-back.
- L2 integration on the merged tree (this tree's own foreman, rebuilt). `foreman init-fixture --phases`, then
  `run --adapter fake` (exit 3). The page's own buttons then gave Try it (recorded), Pass, Hold + note, Pass, Pass.
  The job ended done in 12.5 s with 102 events. Play -> <job>/promoted/game.paddle_court_crazy.
- `foreman status` reads all 12 of my fixture logs (created, paused (phase), running, failed, done).

CHANGED FILES
  M engine/kernel/world/site.gd, engine/kernel/world/site/event_schema.gd (kernel, L3 column)
  M engine/ui/foreman_door.gd, foreman_run.mjs, job_model.gd (+5/-2 lines, at the 600-line budget), selftest.gd
    (create_build.gd preloads res://kernel/dungeon/dungeons.gd, L4's file now on main: it needs main's b28477c or later)
  A engine/ui/job_v2.gd (+.uid), engine/ui/create/* (create.tscn, create.gd, create_kit.gd, create_design.gd,
    create_build.gd, create_model.gd, icon.gd, create_checks.gd, create_case.gd, stage.tscn, stage.gd, .uid files)
  A engine/ui/fixtures/make_create_fixtures.mjs, engine/ui/fixtures/create/c1..c12/job.jsonl
  A engine/tools/selftest.d/630-create.sh, 631-create-site.sh
  A docs/shifts/2026-11-21-night/lanes/L3-create/{STANDUP.md, PATCHES.md, REPORT.txt, stills/, create-sheet.jpg,
    create-clickthrough.mp4}
  No kernel API member was added (site.gd/event_schema.gd are not in API.md; no class_name anywhere).

BEHAVIOUR CHANGES
- The village site's strict reader now accepts the 2026-11-20 keys (before: a v2 log stopped at line 1).
- A v1 job reads exactly as before (job_model: v2 keys at their absent defaults; one implicit phase).
- foreman_run.mjs: a `phase` step ending 1 or 3 is the job's outcome (was: a door error).
- L2's PATCHES are matched. event_schema refuses an alternative id keep/drop and an empty note. `phase` is one step
  that carries resume's run flags (L2's `phase` builds on itself). The page never sends a verdict while a Foreman
  holds the job.

FOR L4 (seen in 10c-exe-menu-back.jpg): the key hint line "arrows or W S choose / Enter open / Esc back" overlaps the
Quit button at 1280x720.

FOR THE OWNER TO LOOK AT
- The clip and the sheet. To use it for real: the exe's main menu -> Create (it calls a real model: ui/flags/real.json,
  claude-cli sonnet, unless TL_CREATE_FLAGS names other settings); or
  <godot> --path engine res://ui/create/stage.tscn -- --mode=open  (fixture door: nothing starts).
- A phased job end to end: foreman init-fixture <dir> --phases; foreman run <dir> --adapter fake; then
  <godot> --path engine res://ui/create/stage.tscn -- --mode=phases
  --job=<dir> --flags=<json with {"flags":{"resume":["--adapter","fake"]}}>

QUESTIONS FOR THE DIRECTOR
1. Word limits (title 4, line 12, detail 60, pitch 20, try 12) are enforced by the site's strict reader. Right for a
   mirror, but one over-long Designer line would stop a village site. L2 says its Foreman checks the same limits
   before writing; if not, loosen the mirror to a warning?
2. L2's three narrowings (alt/phase ids snake_case, alt id never keep/drop, notes non-empty) are in event_schema.gd;
   they belong in JOB.md.
3. `foreman new` has no card flag; the recipe hint uses --answers (proposed answers). A `--card <id>` on `new` would
   say it plainly.
4. JOB.md's react shape reads `[--note]` without a value; I (and L2) took it as `--note "<text>"`.
5. The every-n21-worktree assets scan red in devx.test (known-red-inherited, fixed on main dd1064f per the Director).
6. Proposal: make next-three item 2 a gate case (it needs foreman/dist built).

NEXT THREE THINGS
1. Land P1 (draw.gd, L1's file) and take a world still of the sign reading "Phase 2 of 3: Rivals and cracks".
2. A selftest block driving `init-fixture --phases` through the page (stage --mode=phases, 12.5 s headless).
3. A player test at 720p in the exe: real Designer (crazy) through Create, owner's hand; watch the tap cycle with a
   real 7-aspect brief (4 columns) and the hold-note round trip.
