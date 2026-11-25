E4c: the phase pause's figures, a scope "yes", the run clock (night of 24-25 Nov 2026)
Tree .claude/worktrees/hk-create at hokej 991d73e; nothing committed (the Director lands). Files: engine/ui/create/** only.

1. Measured figures at a phase pause: MET.
   On a game on a core, the phase card narrows and a "Measured" card stands beside Try it / Pass / Hold: "Goals a match:
   33.6 / hokej: 3.4", "Match lasts: 6.2 min / hokej: 7.5 min", and each gross defect in red words (the defect's own
   first clause: "33.6 goals a match at pro"); the card's border is red with a defect, green without. Read from the
   newest note "[foreman] measured at the phase pause <phase>:" (E3d's phaseCheck) and its report (tl.foreman.measured/1:
   run.figures, run.defects, house.figures); without the report on disk, from the note's own figures. A check that
   could not run says "It could not be measured this time." create_model.gd measured_view, create_pause.gd _measured_card.
2. A scope question: MET.
   A question that asks for a package's scope ("scope", "be changed", "be added to", "a package that owns", ...) gets
   one chip "Yes, let it": it fills "Yes, let it change what it needs." and Answer sends `foreman answer <job> <asker>
   "<words>" --change <package>` then resume; <package> is a package of the plan the question names ("May ice_arena be
   changed ..."), else the asker (E5's "... added to this package's scope?"). The ", or" halves of such a question are not
   offered (they are the two sides of the same yes). Checked against the Foreman: on the pauses fixture
   `foreman answer <job> paddle_ai "Yes, let it change what it needs." --change court` writes the answer and
   change_requested {package: court}. create_model.gd scope_package.
   E3d's asked-back change reads whole in the card ("There is no orange team in this game: your side is red (Red
   Toques), the bots are blue (Blue Scarves). Did you mean the blue team, the bots? Say it again ...", the exact text
   rinkjudge.ts absentInChange gives for foreman/fixtures/e5-job1's skin and cartridge) with one chip "Yes, the blue team,
   the bots" (question_options reads "Did you mean ...?").
3. The build clock: MET. It counts from the job's last `job_state running` (the current run), and a stopped run's clock
   stands at its last event; the designing screen still counts from the job's first event. A reopened job showed 98 h.

Proof
- Dry checks (ui.sh selftest and selftest 630), 4 new: create.e4c.measured (the card beside the three buttons, figures
  beside hokej's, the defect red; the note-only fallback), create.e4c.scope (the chip and the exact answer --change +
  resume line; a named package; none on a plain question), create.e4c.orange (E3d's text whole, its one chip),
  create.e4c.clock (5:00 for a run that started 5 minutes before the page's clock).
- Headless live (782's way, real Foreman processes, the exe's door layout): create.pause.path now has 10 steps; the new
  one reads the build clock at the first hold of a job whose first event is days old: minutes, not hours.
- Stills (1280x720, looked at): lanes/E4-iterate/stills-e4c/ e4c-1-phase-measured, e4c-2-scope-question,
  e4c-3-scope-let-it, e4c-4-orange-question, e4c-5-run-clock (stage.gd --mode=e4c over create_iterate_checks.gd
  e4c_jobs). Seen and fixed on the way: the two ", or" chips of the scope question overlapped (a chip's size set before
  clip_text was held to its text's width); a scope question now shows only "Yes, let it".

Gates: npm test 356 (349 pass, 7 environmental skips, 0 fail); tl check --tier fast PASS 5/5; ui.sh selftest
--repo=C:/Users/kazda/kiro/third-life 219 passed, 0 failed; selftest.sh create. 11/11.
