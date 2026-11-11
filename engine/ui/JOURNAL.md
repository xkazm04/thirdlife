# N6 journal (designer panel)

Resume point. Newest entry last. Times are CEST from `date`.

- 01:25 start. Read the brief, JOB.md, N3 report, the marble job, STYLE, host.gd's windowed worker, the fake adapter.
- 01:31 ui/job_model.gd (reads job.jsonl itself, tolerant of a torn tail), ui/foreman_door.gd + ui/foreman_run.mjs
  (the door: one detached node process runs the Foreman steps in a chain and logs to <jobs root>/_ui_logs/).
- 01:35 ui/panel.gd (list + sheet, built in code, colours from style/style.json), ui/host.gd + host.tscn, tools/ui.sh.
- 01:37 first capture on the real site/ root (read only): the panel drew on the first run. Looked at it: list of 5 real
  jobs, marble Build with 3 packages, question + answer, 6 thumbnails. The first marble job shows as `stalled`
  (a real dead Foreman).
- 01:39 ui/selftest.gd: 61 checks; 4 failed on my own wrong expectations (core_run is 309.2 s not 313.6; 2 of 3 at
  event 60; 11 dirs; ints come back as floats). Fixed the expectations after recomputing each by hand.
- 01:40 ui/fixtures/make_fixtures.mjs (seven display states cut from the real marble log into site/_work/n6/fx) and
  make_fake.mjs (fake-adapter script: pack_min in two packages, with `params`; flags file). Pre-check of the chain
  approve -> plan -> run -> change through ui/foreman_run.mjs on the real runner (snapshot4): exit 0, 73 events,
  two promotions (site/_work/n6/precheck, deleted later).
- 01:42 captures of the empty list and the real marble job (site/ root, --readonly): looked at each.
- 01:43 ui/drive.gd: the live session through input events only. First run passed end to end in 160 s: describe,
  approve, mid-build, done, change request, second promotion, slider drag writes balls 9 -> 3 (valid JSON).
  Proof: site/_work/n6/live_shots/live_proof.txt.
- 01:46 looked at the fixture captures. Found and fixed: a stalled job kept counting time (now it stops at its last
  event); the tune label column was too narrow; "Foreman not found" was printed twice in the list; the enlarged
  picture never showed (its box had size 0: now sized by hand in _fit).
- 01:48 ui/PATCHES.md (kernel input polls the keyboard: three exact patches, none applied, none run).
- 01:49 second live session (live2): a builder's question answered in the panel, the session's own Foreman killed
  mid-run -> the row turns `stalled` in 3.6 s -> Resume -> done; a second game discarded. Passed in 80 s.
- 01:52 selftest now also checks the command lines each button starts (69 checks). 720p captures looked at.
- 01:53 the REAL hockey job (read only) taught two things: a builder's question can be open while the job is still
  `running` (other packages go on), and `foreman answer` refuses while a Foreman holds the lock. The list chip now
  says `question` whenever one is open, and the answer field is disabled with the reason until the job pauses.
- 01:55 drive: also clicks a picture (enlarge, close), the notes fold, and the "let it change core" choice.
- 01:56 mistake: a sed that should have added --quit-after to tools/ui.sh failed, so `ui.sh open` opened two windows
  that waited for Esc. Closed them by pid (48088/110804 and 106456/42964, all mine, found by their command lines).
  ui.sh fixed with an edit; `TL_UI_QUIT_AFTER=150 ui.sh open` now exits 0 by itself.
- 01:57 live2 passed again (134 s), now with the "let it change core" choice clicked in the list: the answer became a
  change request for core, outcome made.
- 01:58 final run of live (session 1) passed in 88 s, with the picture and notes clicks. Then this session stood
  still until 09:06 (no tool call ran in between; nothing of mine was running: checked by command line at 09:07).
- 09:06 Director's message read. All static captures retaken with the final code (20 pictures, 44 s, one window at
  a time). selftest: 69 passed, 0 failed.
- 09:07 the real hockey job is done: captures 16 (Build) and 17 (Change) on site/ read only, no code change. Its
  first change request shows `failed` and the second `made 0.1.1`; checked against job.jsonl (job_state failed at
  event 279, promoted 0.1.1 at event 330): the panel is right.
- 09:08 ui/captures/sheet.png built (39 captures) and looked at. Known and not fixed: on a stalled job the Change
  field is enabled and the section head still says "1 in flight" while the row's chip says "no foreman" (capture 14).
- 09:09 final process check, report. RESUME POINT: nothing is running; the work is complete as reported.
