# Lane editor: report (night of 19 Nov 2026, done at about 01:25)

The Director saved this from the lane's final message, because the harness refused the agent's report-file write. The
Director re-ran `ui.sh selftest`: 116 passed, 0 failed.

## What to look at, in order
1. `clip.mp4` (27.3 s, 1280x720, recorded in a real window driven by input events; the workbench plays at 1.3x, the
   game sheet at 4x).
2. `stills/contact-sheet.jpg` (18 captures) and `stills/slice/`. Today's panel is in `stills/today/`, judged in DESIGN.md.
3. Astra's raw mockups in `mockups/`: 4 screens and 5 rejected tries, with their prompts and `NOTES.md`. Astra ran alone,
   for 7 min and 51,364 tokens, given the problem and the constraints but no layout.
4. `DESIGN.md`.
5. To try it: `TL_ENGINE_DIR=<repo>/engine bash engine/tools/ui.sh fake --out=<scratch>/fake`, then
   `bash engine/tools/ui.sh open --jobs=<empty dir> --flags=<scratch>/fake/flags.fake.json`, then click
   "New game in the workbench…".

## What was built
**E1, the workbench** (`engine/ui/editor/`). One model sits behind every view. Nothing is written or started before you
press "Build it".
- **Your idea:** you write one line. Example sentences sit under it, and your words are kept as you wrote them.
- **The recipe:** a chip names the card that matched and the words that matched it. "Other recipes" and "None of these"
  are one click away. An idea with no card (for example an arena RPG) gets an honest notice plus the questions every
  game has.
- **The questions:** grouped as "Who plays", "How it is won" and "Where and how it looks".
  - Each question is a row of option chips. The proposed option is marked, with its reason and, where it exists, a
    measured figure ("a newcomer's hand wins 18 of 20 against rookie").
  - Answers read from your sentence are marked "from your words".
  - "Take the proposals" fills in every open question at once.
- **The village map:** your game appears on the map as a ghost.
  - Its ring follows the world's own lot rule (half the diagonal + 4 m).
  - The footprint is drawn by kind of game: rink with stands, pitch, track, course, arena and so on.
  - You can drag it and turn it (wheel or Q/E). Its gate faces the road.
  - Problems are named in words, for example: overlaps the plot "car" by 17 m; stands on the road; no free place fits.
  - "Close up" shows you at true scale (2 m).
- **The scale strip:** a side view beside the 2 m walker, and the size in words ("about 19 s to run across").
- **The review bar:** shows the exact request that will be sent and an estimate labelled as a guess. When "Build it" is
  disabled, the reason is written under it. "Build it" writes `<jobs>/_editor/*.json` and starts the Foreman through
  the existing door.

**E2, the game sheet** opens for a game made in the workbench. It has four parts:
- **Open:** approve or discard, answer a builder, resume, or see the door's errors.
- **Decided:** every answer and who gave it, plus the lot and the brief.
- **On its lot:** one bay per package, coloured by the site's state words.
- **Now:** what the builders are doing.

The input-event drive goes from the idea to "Build it", then approval, building and done, and back to the list. It passes
in 60 s with the fake adapter on the real runner.

## Gates
- `tl check --tier fast`: PASS 5/5.
- Full gate, first run: arch failed because `drive.gd` reached 603 lines (the limit is 600; it was split, and is now 446),
  and devx.test failed with the same finding. Packs missed hockey's `many_budget` at 1.088 ms with the machine at 91 %;
  the lane changed nothing outside the UI.
- Re-runs: arch 12/12, devx.test 225/225, ui.selftest 116/116, packs 2/2 (33 verb runs).
- First run, untouched by the fix: kernel.selftest 219, kit 91, seeds 39, item 91, foreman 210 (0 fail), world 8/8.
- **perf: NOT RUN (machine busy). It was not measured.**
- One self-inflicted problem: a parse error left the lane's own Godot window hanging for about 35 min, until the lane
  killed it by pid. Drive runs now pass `TL_UI_QUIT_AFTER`.

## Behaviour changes
- The games list's first row is now "New game in the workbench…". The old one-line "New game…" row is still there.
- The fake plan in `ui/fixtures/make_fake.mjs` had been out of date since P10 (no `PLAYER CHECK` line), so N6's live proof
  could not pass. One contract line was added, and `ui.sh live` passes again (87 s).
- The drive's `find` now returns the first visible control with a given name.
- `panel.gd` changed by one line (it is held by the size ratchet).

## Where the lane disagrees with Astra's mockups (it did not redraw them)
- 01 asks one question per screen, which would be six screens for hockey. The slice shows every question at once. It
  borrowed Astra's "Foreman suggests" idea, its "Draft · Nothing spent" footer and the cream, honey and ink look.
- 01 shows a rink with skaters before anything is built. The slice draws only what has been decided.
- 02 moves the rink inside a plot it was given, whereas in the village the player places the lot itself. 02's hatched
  overlap is better than the lane's red ring, and was not built.
- 03 is the strongest: crew signs at the bays, and the builder's question tied to the bay on hold. The game sheet takes
  bays-by-state in 2D only.
- 04 explains why no recipe fits ("enemies that fight back need new behaviour"), which is better than the lane's
  generic notice.

## Contract proposals (the Director's to decide)
1. CARDS.md: an optional `interview` key per card (questions, options, the proposal and its reason, match words, variants)
   and an optional `footprint`; `tl cards check` would verify that each proposal is one of its options. For now these
   live in `engine/ui/interview/*.json`.
2. JOB.md: optional `job_created.answers` and `job_created.lot` (`{at, yaw_deg, radius}`). Until then the village does
   not put a workbench game on the lot the player chose, and the game sheet says so.
3. A measured `footprint` in each seed's `pack.json`, to replace the size guesses.

## Next three
1. Put the lot into the world, so the construction rises where the player placed it.
2. Change a decision from the game sheet: the ring refits and the change is sent as a change request.
3. Make the village map the editor's home screen, with every game on its lot.

---

# Round 2 (01:31-02:13): change a decision, and Astra's look pass

The Director saved this from the lane's message and re-ran `ui.sh selftest`: 123 passed, 0 failed. The Director also
looked at the side-by-sides at 720p.

## A. Change a decision from the game sheet
- Click a line under Decided ("Click a line to change it."). The question's options appear as chips, with the current one
  marked "now".
- Pick another option and the lot refits at once:
  - the new ring is drawn and the current ring is dashed ("now: ring N m");
  - a line reads "With this change: 67 x 45 m … ring 45 m";
  - the exact request text is shown.
- "Send the change" goes through the existing Foreman change path. No contract changed.
- Sending is refused until a package is built, while the builders are busy, or when the new size outgrows the lot (the
  neighbour it would hit is named).
- The line follows the job's outcome: waiting, in flight, not made, made. Only a made change becomes the decided value,
  marked "changed by you". "Keep it as it is" cancels.
- The drive was run on input events alone: rink, then Standard 60 x 30 m (ring 54 -> 45 m before sending), then Send,
  then the change request appears in the log, then the change is made. It passes in about 92 s (fake adapter, real
  runner). Captures are in `stills/change/`.
- The selftest gained 7 cases: 123 in all, none failing.
- **Open: a lost click.** In 1 run of about 6, a click on the "Pro" chip did not register as an answer; 4 runs made to
  catch it did not reproduce it. The drive now reads every chip answer back and fails loudly if one is missing. A player
  would feel this; watch it.

## B. Look pass by Astra alone
- One Codex run: session `01a1f140-8552-7913-9cc6-7026c7570d86`, about 26 min, 231,058 tokens. Astra was given only the
  problem, the before captures, its own mockups as reference, and the rule that changes be visual only. Its notes are in
  `stills/look-pass/NOTES-astra.md`.
- What it changed:
  - the Archivo typeface (SIL Open Font License, `engine/ui/editor/fonts/OFL.txt`, 644 KB);
  - cream paper panels ruled in ink, ink header and review bars, the red workshop flag, honey chips;
  - an illustrated village map: fenced plots, a landmark per neighbour, wheel tracks, trees, terracotta hatching where a
    game overlaps;
  - jerseys on the rink, a scale drawing on graph paper beside the 2 m walker, and boarded bays with signs in the game
    sheet.
- Clarity: the lane read every screen at 1280x720 and 1920x1080. Everything is readable and every control can still be
  found by name. Astra was not sent back.
- The only change the lane made itself: `village_map.gd` reached 659 lines, over the 600 ratchet, so its state and small
  helpers moved into `map_base.gd`. Drawing did not change, and every screen was re-captured and looked at.
- Pictures: `stills/look-pass/side-by-side/` (25 before/after pairs), `after/`, and `after-astra-raw/`. The separate
  before set was dropped because the side-by-sides hold it. Clip: `clip-look.mp4`, 20.1 s at 1.4x.

## Gates
- `ui.sh selftest`: 123 passed, 0 failed.
- `ui.sh editor`: the whole session passes after the look pass, through to the change being made.
- `tl check --tier fast`: 5/5.
- Packs were not run, because nothing outside `engine/ui` changed.

## For the Director
- JOB.md could take an optional `change_requested.decision {key, to}`. Today the change is matched to its decision by text.
- The village still does not put a workbench game on the lot the player chose (round 1, proposal 2).

---

# Round 3 (02:16-03:29): the lost click, and the village board as home

The Director saved this from the lane's message and re-ran `ui.sh selftest`: 125 passed, 0 failed.

## 1. The lost "Pro" click came from the drive, not the editor
- Reproduced with a targeted session, `ui.sh chips`: 7 of 1,740 clicks were lost (0.4 %).
- Cause: a press sent from script makes the window receive one mouse motion at the real Windows cursor's position. That
  motion lands outside the chip, so Godot's button cancels the press and fires "button up" but not "pressed". In the
  logs, the stray motion sits exactly at the OS cursor minus the window position.
- The chip rebuilds were ruled out: the logged positions were identical before and after.
- A person's mouse is where it presses, so a player is not affected. The editor was not changed.
- Fix in `drive.gd` `click_at`: wait until the press has been processed, then send the drive's own position again just
  before the release. Result: 0 of 900 clicks lost, with other drives running in parallel for load.
- No selftest case is possible, because this needs a real window and the OS cursor. `ui.sh chips` is the check.
- The N6 live drive uses the same `click_at`, so older lost-click flakes are explained by this too.

## 2. The village board is the editor's home screen (E5)
- The board shows the workbench's map with every plot and every workbench game on its lot. Labels are in honey, with
  the site's words (being designed, waits for you, building 1 of 2, ready to play, ...): a crane while it builds, its
  recipe's symbol when done.
- "Your games" lists the same games. A game made with the one-line box has no lot; its row says so.
- Click a lot or a row to open its game sheet; "< Games" comes back to the board. "+ New game" opens the workbench.
  "Jobs list" opens the designer panel, and its "Village" button returns.
- No new art: Astra's map and symbols are reused.
- `ui.sh open` starts on the board; `--panel` starts on the old panel.
- Drive `ui.sh home` (input events only): empty board, new game, build, approve, back to the board ("building 0 of 2"),
  then "ready to play", then a click on its lot opens the sheet, then the jobs list, then the village board again. It
  passes in 56 s.
- Captures in `stills/home/`; clip `clip-home.mp4`, 19.2 s.

## Gates
- `ui.sh selftest` 125/0 (2 new cases).
- Drives pass: `ui.sh editor`, `ui.sh home` and `ui.sh live`.
- `ui.sh chips`: 0 of 60 lost.
- `tl check --tier fast`: 5/5.

## Still open
- The 3D village does not yet place a workbench game on the lot the player chose (proposal `job_created.lot`).
