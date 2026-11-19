Please continue the same game-QA test-writing task, in a narrower form.

1. Finish the write-up first. In `docs/shifts/2026-11-19-night/lanes/hunt2/astra-findings-3.md`, add a section for each unit test you
   already wrote and ran: C3 (TLLaws.material copy), C4 (hockey puck while the dial pause is open), C5 (Seed Drive HUD after the time
   limit), C6 (hockey goal trigger and the goal line), C7, C8 (unknown tuning keys in the seeds) and C9 (boot report output). Use the
   same format as C1 and C2: file:line, why, test path and command, the output you saw, severity, reach and the "may predate 17 Nov"
   flag. Do not re-run C9 or extend it. A short description of what it showed is enough.
2. Note that the director has since changed code for C1, C2, C3 and C5. Re-run those four tests and note PASS/FAIL in the write-up.
3. Then do task 1 of the earlier brief: review the TLHand (B10) and hockey PREDELETE (A14, B1) changes. Use small gameplay unit tests
   in the same style. Write "Fix review: held" and "Probed and sound" sections.
4. If time remains, write up to three more gameplay unit tests for `engine/packs/parkour` or `engine/seeds/seed_wall`, named C10 and
   up.

The same rules apply: edit only under `docs/shifts/2026-11-19-night/lanes/hunt2/`. Read-only git is fine; do not commit. Run headless
with `timeout 180`.
