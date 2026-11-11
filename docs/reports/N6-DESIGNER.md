# N6 the designer panel in the game: builder report and Director verification

Brief `briefs/BRIEF-N6-DESIGNER.md`. Builder work time 01:25 to 01:58 on 2026-11-11 and 09:06 to 09:09 (36 minutes of work;
harness: 382,498 subagent tokens, 122 tool uses), in the engine copy `site/_work/n6/engine/`. The session stood still
between the two, so the Director verified and merged the work from its files at 03:55, and the builder's report came
after. The report is the builder's final message, saved unchanged.

---

## Builder report (verbatim)

N6 DESIGNER PANEL: FINAL REPORT (builder; 2026-11-11, 01:25 to 01:58 and 09:06 to 09:09 CEST)

## Status

The panel is built and works end to end against the fake adapter and the real runner. It reads the real marble and hockey jobs correctly. No model was called, no git command was run, and nothing outside `ui/**` and `tools/ui.sh` in my engine copy was written.

- `bash tools/ui.sh selftest`: 69 passed, 0 failed, exit 0 (last run 09:07).
- Captures: 39 pictures plus `sheet.png`, each looked at.
- Live path: two scripted sessions passed, driven by input events.
- Processes: none of mine is left (checked by command line at 09:08).
- **Clock:** the session stood still from 01:58 to 09:06. No tool call ran in that gap, so the Director's 03:52 message reached me at 09:06.

One premise of the brief was wrong: the real marble pack declares no `params`, so its Tune section honestly says "nothing declared". Sliders are shown on a scratch copy with four params added, and on the live-built pack.

One known inconsistency is left in. On a stalled job the Change field and Send are enabled, and the section head says "1 in flight" while the row's chip says "no foreman" (capture 14).

All paths below are under `C:\Users\kazda\kiro\third-life\site\_work\n6\engine\`.

## What was built

| File | Purpose |
|---|---|
| `ui\job_model.gd` | Reads `job.jsonl` itself, tolerant of a torn tail; reads and writes `params` values |
| `ui\foreman_door.gd` | Starts Foreman command lines as detached `node` processes; says whether one is alive |
| `ui\foreman_run.mjs` | Runs the Foreman steps in a chain (approve, plan, run) and logs to `<jobs root>\_ui_logs\` |
| `ui\panel.gd` | The list and the sheet, built in code, colours from `style\style.json` |
| `ui\host.gd`, `ui\host.tscn` | Stand-alone host with a seed frame behind the panel |
| `ui\drive.gd` | The scripted live sessions |
| `ui\selftest.gd` | The headless checks |
| `ui\sheet.gd`, `ui\sheet.tscn` | Contact sheet of the captures |
| `ui\fixtures\make_fixtures.mjs` | Seven display states cut from the real marble log |
| `ui\fixtures\make_fake.mjs` | Fake-adapter scripts and flags (the kernel's `pack_min` in two packages) |
| `ui\flags\real.json` | The N3 report's claude-cli settings; these call a model and were never used |
| `tools\ui.sh` | Verbs `open`, `shot`, `selftest`, `fixtures`, `fake`, `live`, `sheet` |

The panel starts nothing unless it is given a flags file (`--flags=<json>`). Without one it shows the jobs and says it can start nothing.

## What the panel does, with the capture that shows each

Captures are in `ui\captures\`. The sheet of all of them is `ui\captures\sheet.png`.

### Games list (layer one)
- One 24 px row per job directory: title, state chip, packages done of total, thin bar, elapsed time. First row "New game…".
- Chips beyond the brief's six: `approve?` (brief waits), `question` (a builder asks), `budget`, `stalled` (no Foreman alive), `cancelled`, `unreadable`.
- Empty list: `01-empty-list.png`.
- Five real jobs from `site\`, read only: `03-marble-build.png`. The first marble job shows as `stalled`, which is a real dead Foreman.
- Seven states side by side: `10-paused-on-question.png`.

### Brief
- The sentence, the five brief parts held to two lines each (a click opens a line), the estimate, "so far", and who approved.
- Real marble job: `02-marble-brief.png`.
- Waiting for approval with Approve and Discard: `09-waiting-for-approval.png` (fixture) and `20-live-2-waiting-for-approval.png` (live).

### Build
- One row per package: state, round, time worked, tokens. The current activity is the one line under the title.
- Milestone pictures as thumbnails with the critic's verdict; a click enlarges one.
- Builder notes are folded away; each note is held to two lines.
- A question shows as a framed block with an answer field, a "let it change package X" choice and an Answer button.
- Real marble job (3 packages, question and answer, 6 pictures): `03-marble-build.png`.
- Notes open: `04-marble-build-notes.png`. Picture enlarged: `05-marble-picture-enlarged.png`.
- Real hockey job, done: `16-real-hockey-build.png` (4 packages, two questions, 10 pictures, 21 notes).
- Paused on a question: `10-paused-on-question.png` (fixture), `25-live2-1-paused-on-question.png` (live).
- The choice list open: `25-live2-2a-choice-open.png`.

### Change
- One field, "What should be different?", a Send button, and earlier requests with owner package and outcome chip.
- Real hockey job: `17-real-hockey-change.png`. It shows the first request `failed` and the second `made · 0.1.1`. I checked that against the log: `job_state failed` at event 279, `promoted 0.1.1` at event 330.
- Live, in flight: `20-live-7-change-in-flight.png`. Live, made: `20-live-8-second-promotion.png`.
- Real marble job, no requests: `06-marble-change.png`.

### Tune
- One slider per `params` entry, with label and current value from the named JSON file.
- Moving a slider rewrites the data file through a temporary file and a rename. Key order is kept and whole numbers stay whole.
- The sheet says "A change takes effect at the next start of the game". I found no clean live path (see PATCHES 4).
- Real marble pack, nothing declared: `07-marble-tune.png`.
- Scratch copy with four params: `08-tune-declared.png`.
- Live-built pack after a slider drag: `20-live-9-tuned.png`.

### Other states
- Paused on budget: `11-paused-on-budget.png`.
- Failed with its cause in one line: `12-failed.png`.
- Foreman dead (lock names a process that is gone), with a Resume button: `13-foreman-dead.png` (fixture), `25-live2-3-foreman-dead.png` (live).
- Change request whose Foreman died: `14-change-foreman-dead.png`.
- Foreman not found: `15-foreman-not-found.png`.
- Discarded: `25-live2-5-discarded.png`.
- 1280x720: `30-720p-marble-build-notes.png`, `31-720p-paused-on-question.png`, `32-720p-marble-all-open.png`, `33-720p-tune.png`. Text stays in its boxes; the sheet scrolls inside the window.

## Selftest

69 checks, all pass. They cover:
- **The real marble job:** 126 events, 3 packages each promoted in round 2, milestones blockout / art_pass / tuned with 6 pictures on disk, 6 notes, 1 question and its answer by the player, final state done, one promotion at 0.1.0.
- **Totals:** tokens in 2,009,179, out 85,150, cache read 1,689,227, equal to the Foreman's own `state.json`; elapsed 14:45.
- **Display states from prefixes of the log:** designing, approve, planning, running, question, budget, failed, change in flight, change made.
- **A half-written log:** a torn last line is reported and 60 whole events are read; nine cuts at arbitrary bytes all give a picture.
- **The Foreman:** missing Foreman, missing node, no settings, capture mode starts nothing, a dead lock pid is not alive.
- **Command lines:** what each button starts (new, approve then plan then run, answer with and without `--change`, change, cancel, resume).
- **Tune:** two writes to a copy of the marble `tuning.json`; the file stays valid JSON, nothing else changes, no temporary file is left.

The selftest prints one engine `ERROR: Could not create child process` line. That is the missing-node check and is announced on the line before it.

## Live-path proof

Both sessions used `--adapter fake`, the real runner, `TL_ENGINE_DIR=site/_engine_snapshot4`, and scratch jobs roots under `site\_work\n6\`. Every step is logged with its time and how it was done in `ui\captures\live_proof.txt` and `ui\captures\live2_proof.txt`.

**Session 1** (`ui.sh live`, 88 s, exit 0), in order:
1. Click "New game…", type the sentence (64 key events), Enter.
2. Click "Approve and build".
3. Click a milestone picture and click again to close it; click the notes fold open and shut.
4. Click the Change section head, click the field, type the request (39 key events), click Send.
5. Click the Tune section head and drag the "Number of balls" slider.

Seen in the log through the panel's own model: brief set, approved, plan, mid-build, done with pack 0.1.0, `change_requested`, owner `core` re-opened, second promotion at `promoted/game.balls_roll_down_wooden@0.1.1`, outcome made. The slider drag changed `balls` from 9 to 3 in that pack's `data/tuning.json`, and the file is valid JSON.

**Session 2** (`ui.sh live --drive=live2`, 134 s, exit 0), in order:
1. Describe and approve as above; the job pauses on a builder's question.
2. Click the answer field, type the answer, open the choice list and click "let it change core", click Answer. The answer became a change request for `core`, outcome made.
3. The session kills its own Foreman mid-run. The row turns `stalled` within about 2 s (3.6 s in the first run).
4. Click Resume; the job finishes done.
5. Describe a second game and click Discard; the job ends cancelled.

**Through real UI events** (`Input.parse_input_event`: mouse motion, buttons, keys with characters): every click, every typed character, Enter, and the slider drag.

**Through direct calls:** reads of the panel's model to wait for a state, the screenshots, and one `OS.kill` of the Foreman that session had started, to stage the dead Foreman. No panel or door method was called to make anything happen.

## Contents of `ui\PATCHES.md`

None is applied and none has been run. Each is written as exact text against my engine copy, except patch 4.

1. **Keys typed into a field must not reach the game.** `kernel/api/tl_input.gd` polls `Input.is_physical_key_pressed()` in `_sample()` every physics frame, so typing "wasd" into a field would steer the game. Patch: compute `var devices: bool = accept_devices and not keys_taken()` once in `_sample()`, and add `keys_taken()`, which is true while a `LineEdit` or `TextEdit` has focus. Injected (bot) input is untouched.
2. **Esc must not end the game while the panel is open.** `kernel/runner/worker.gd` line 247 ends a `play` run on Esc, again by polling. Patch: add `and not _designer_open()`, where that function checks a `TLDesigner` layer's visibility.
3. **Show the panel over a running pack.** In `worker.gd start()`, when `mode == "play"` and `--jobs` is given: add a `CanvasLayer` named `TLDesigner` (layer 50, hidden), create the door and the panel, and toggle the layer on Tab in `_unhandled_key_input`. `tools/tl.sh play` must pass `--jobs=` and `--foreman-flags=` through as paths. Two things to check when it is tried: the worker runs with `PROCESS_MODE_ALWAYS`, and `tl_orbit_cam.gd` reads the mouse in `_unhandled_input`, so clicks on the panel do not reach it.
4. **Tune takes effect at the next start.** Packs read their data once in `_pack_setup` and the kernel cannot load a pack twice in one process. Proposal only, not exact text: a `restart_pack()` in `worker.gd`, called 300 ms after the last slider movement.
5. **Which pack does the game play (a gap, not a patch).** The panel tunes `<job>/promoted/<pack id>[@version]/`. With `--promote-to engine` it shows "no promoted pack", because it does not know the engine directory the Foreman used.

## What a player still cannot do

- Open the panel inside a running game. It runs only in its own host (patches 1 to 3).
- See a tuned value act without restarting the game, or start the game from the panel at all.
- Answer a question while the Foreman still works on other packages. `foreman answer` refuses while the lock is held (the real hockey job showed this), so the field is disabled with the reason until the job pauses.
- Send a change request while a Foreman runs the job, for the same reason. There is no inbox.
- Comment on a milestone, cancel a running job, see a verify report or a builder transcript, see re-plans, or choose adapter and limits. These come only from the flags file.
- Tell the three jobs titled "A marble run" apart in the list.
- Use a double quote in a sentence: it is turned into a single quote to survive the Windows command line.

## What I did not verify

- No person has clicked it. Every interaction was synthetic input into a window at 0,1440.
- Readability at arm's length is judged from the pictures only (13 px type, 24 px rows).
- The real adapter path: `ui\flags\real.json` was never used, so no `new`, `plan` or `run` with claude-cli has gone through the door.
- Not exercised by events: the "Design" button (Enter was used), a click to open a brief line or a note, the Resume button on a budget pause, scrolling, the hover tooltip-free states.
- Many jobs in the list (more than fit) and a long sheet scrolled by wheel.
- The foreign-pid liveness check runs `tasklist` at most once per 4 s per pid. It was right for the real hockey Foreman and for dead pids, but its cost with many live jobs is unmeasured.
- A job whose `job.jsonl` is locked by its writer at the moment of reading was not staged; the code keeps the last good picture.

## Side effects to know

- I opened two panel windows by mistake at 01:56 (a failed `sed` left `ui.sh open` waiting for Esc). I closed them by pid after identifying them by command line: 48088/110804 and 106456/42964, all mine.
- Scratch directories left under `site\_work\n6\`: `fx`, `fake`, `jobs`, `jobs2`, `empty`, `live_shots`, `live2_shots`. Each jobs root has a `_ui_logs\` folder with the Foreman's output per button press.
- Nothing was written under `site\` beside the real jobs, in `foreman\`, in `contracts\`, or in the main tree's `engine\`.

## Questions

1. **Answering while running.** A question can be open while the job is still `running`. Should the Foreman take answers and change requests through an inbox file, so the panel need not wait for the pause?
2. **Chips.** Are `approve?`, `question`, `budget` and `stalled` acceptable beside the brief's six, or should the chip keep to the six and the extra word go in the figure column?
3. **Stalled jobs.** Should Change be disabled on a stalled job until Resume has run? Today it is enabled (capture 14).
4. **Tune writes.** The slider rewrites the whole data file with two-space indent. Is that acceptable, or must the original formatting be kept byte for byte around the changed number?
5. **Foreman settings.** Where should the flags file live for a player: beside the jobs root, or in the engine's user settings?
6. **Patch 3's key.** Is Tab the key you want for the panel?

## Minutes spent

By `date`: started 01:25:15, worked until 01:58 (33 minutes), stood still until 09:06, then worked 09:06 to 09:09 (3 minutes). That is about 36 minutes of work inside 7 h 44 min of wall clock. The step record is `ui\JOURNAL.md`.

---

## Director verification

Done 03:45 to 03:55 on 2026-11-11, from the files the builder had left, before any report existed. The builder's
report above arrived at 09:09: its session had stood still from 01:58 to 09:06, so the Director's message of 03:52
reached it seven hours late. At 09:09 the Director compared the builder's copy with the main tree again: every
script and `tools/ui.sh` are identical to what was merged at 03:52; only the journal and the captures are newer.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash tools/ui.sh selftest` in the copy | 69 passed, 0 failed |
| the same on the main tree after merging `ui/**` and `tools/ui.sh` | 69 passed, 0 failed |
| the builder's live-path record `site/_work/n6/live_shots/live_proof.txt` read | a scripted session against the Foreman's fake adapter: a click on "New game...", 64 key events typed into the field, Enter, the brief appears, a click on "Approve and build", mid-build, done, a milestone picture enlarged and closed, notes folded, a change request typed and sent. Steps are marked `UI event`, `read` or `direct` (screenshots) |
| the Director's own captures on the main tree: `ui.sh shot --jobs=site --select=ice-hockey-three-against-20261111-1 --section=build` and `--section=change`, read only | the panel shows tonight's real hockey job: `done`, 4 of 4 packages with rounds, minutes and tokens, both questions with the Director's answers, five milestones with their pictures, 2 change requests, 5 tunable values |

**Looked at:** `ui/captures/03-marble-build.png`, `07-marble-tune.png` (builder's, in the copy) and the Director's two
hockey captures (`docs/reports/img/n6_panel_hockey.jpg`).

### What the Director saw

- It follows the owner's taste as briefed: a list of short rows (name, state chip, packages done, a thin bar, time) and
  a sheet for the selected game with folding sections. Small type, tight rows, ink-dark panels in the style's palette
  over the game picture. Nothing reads as a chat log.
- A stalled job (a Foreman that died) shows as `stalled` in red and stops counting time, as the brief asked.
- The second marble job's question and the Director's answer appear as two one-line rows.
- The hockey pack declares 5 tunable values, so the builder prompt added in N3 reached a real builder and the Tune
  section has real content.

### What is not verified

- The second live session (a question answered in the panel, a killed Foreman, Resume): its record was not read.
- A slider's write to a pack's data file: covered by the selftest, not looked at by the Director.
- The 1280x720 captures and every capture not named above.
- No person has clicked it. Nothing here ran with a real model.
- The panel inside a running game: tonight it runs in its own host scene with a still picture behind it.

### What a player still cannot do (Director's reading at 03:55; the builder's own, fuller list is in its report)

- Open the panel while playing: the kernel polls the keyboard, so typing in a field would steer the game behind it.
  The builder's three exact patches for that are in `engine/ui/PATCHES.md`; none is applied and none has run.
- See a tuned value take effect without starting the game again.
- Point at something in the world and ask for a change to it.

### Merged

`engine/ui/**` (without the 42 MB of captures, which stay in the builder's copy) and `engine/tools/ui.sh`, both new.
Nothing else was touched.

### Director's decisions on the builder's questions (09:15)

1. Answers and change requests while a Foreman runs: yes, the Foreman should take them through an inbox; today both
   wait for a pause. Carried to the next Foreman pass.
2. The extra chips (`approve?`, `question`, `budget`, `stalled`) stay: each names something the player must act on.
3. Change is to be disabled on a stalled job until Resume has run. Not changed yet.
4. A slider may rewrite the whole data file with two-space indent.
5. Where the Foreman's settings live for a player, and the key that opens the panel: for the owner, with the panel's
   move into the world.
