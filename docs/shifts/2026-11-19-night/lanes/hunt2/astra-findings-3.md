# Third Life QA round 2, part 3

Headless checks against the hunt2 worktree on 19 November 2026. Run the commands from the repository root in Git Bash. Exit 1 and a final FAIL line reproduce a finding. Exit 2 or an incomplete run supplies no verdict.

## C1. Two seed bots reject wins at the configured target

**High · May predate 17 Nov? Yes, 10 Nov (`b9a1443`).** The win checks now at `engine/seeds/seed_paddle/tests/bot_win.gd:62` and `engine/seeds/seed_drive/tests/bot_laps.gd:62` originally required exactly five goals and three laps. Both seed guides explicitly invite changing the win target in the rules file (`engine/seeds/seed_paddle/README.md:50`, `engine/seeds/seed_drive/README.md:46`). `contracts/PACK.md:59` makes game state the basis for the bot verdict.

**Reach.** These are the first manifest bots and supply the real V4 verdict. The repro changes one number per lane-local copy, plays both games to completion on seed 1 and checks that every verifier check except `bot.ok` passed. Drive also satisfied its original pad, boost and cone requirements.

[Repro](repro/C1.py) · `python docs/shifts/2026-11-19-night/lanes/hunt2/repro/C1.py`

```text
REPRO C1: FAIL paddle target 1 met at frame 1016, verifier exit 1 / drive target 4 met at frame 4579, verifier exit 1
REPRO C1: FAIL paddle target 1 met at frame 1016, verifier exit 1 / drive target 4 met at frame 4579, verifier exit 1
```

**Suggested fix.** Read each target from the seed rules. Keep checks on the winning side, finish reason, HUD and gameplay. Apply the same target to Paddle’s non-perfect hand at line 66.

**Director’s fix, two fresh processes.** The director changed the public bot verdicts at `engine/seeds/seed_paddle/tests/bot_win.gd:62` and `engine/seeds/seed_drive/tests/bot_laps.gd:62` to use the configured target.

```text
REPRO C1: PASS
REPRO C1: PASS
```

## C2. A valid aim record can replay a different button strength

**High · May predate 17 Nov? Yes, 16 Nov (`1c917374`).** Before the guard now at `engine/kernel/api/tl_input.gd:57`, a pack could declare a plain action named `aim@x` beside an aim named `aim`. The recorder uses the same name for the x coordinate at line 442. Replay folds both samples into one dictionary slot at line 368. The contract promises exactly the latched input on replay, including the input covered by the state hash (`engine/kernel/API.md:337`, `engine/kernel/API.md:940`).

**Reach.** Hockey declares the shipped `aim` at `engine/packs/hockey/scripts/main.gd:124`. The fixture adds a then-accepted plain action to that declaration pattern. It compares the two latches and their serialized hash inputs after writing and reading a real `tl.input/1` file. Stock hockey does not declare the colliding name.

[Test](repro/C2.gd.txt) and [diagnostic wrapper](repro/C2.sh) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/C2.sh`

```text
REPRO C2: FAIL 1 frame, aim x 7.000 in both, plain action live 0.250 / replay 7.000, equal hash input 0
REPRO C2: FAIL 1 frame, aim x 7.000 in both, plain action live 0.250 / replay 7.000, equal hash input 0
```

**Suggested fix.** Give plain actions and aim components distinct encodings, or reject colliding declarations in either order and report the reserved name before recording.

**Director’s fix, two fresh processes.** The director reserved `@` at `engine/kernel/api/tl_input.gd:57` and line 119. The wrapper accepts only the specific declaration diagnostic and a completed scenario.

```text
REPRO C2: PASS
REPRO C2: PASS
```

## C7. Timber Run repeatedly respawns off the deck in a translated world

**High · May predate 17 Nov? No, 18 Nov (`946af5a2`).** `engine/packs/parkour/scripts/main.gd:58` passes a course-local point to `runner.place()`, which sets `global_position` at `engine/kernel/api/tl_biped.gd:203`. The fall handler repeats that placement at `engine/packs/parkour/scripts/main.gd:81`. The pack guide promises a return to the last checkpoint (`engine/packs/parkour/README.md:16`), and the API specifies pack coordinates at `engine/kernel/API.md:819`.

**Reach.** The world host exposes this placement through `--at` and passes the offset to the holder at `engine/kernel/world/world.gd:151`. The two holders ran the real course on the same seed with no inputs. Translation along x alone was enough for a recurring fall. The ordinary village tour simulates its plots at their own origins.

[Repro](repro/C7.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh C7`

```text
REPRO C7: FAIL 120 idle ticks, translation 0/100 m, start stations 0.00/-100.00 m, falls 0/5
REPRO C7: FAIL 120 idle ticks, translation 0/100 m, start stations 0.00/-100.00 m, falls 0/5
```

**Suggested fix.** Keep the stored checkpoint in course coordinates. Convert it with `ctx.root.to_global(spawn_at)` at each world-space placement, including restart and recovery.

## C3. Editing a returned material row changed another pack’s physics

**Medium · May predate 17 Nov? Yes, 10 Nov (`b9a1443`).** The old `TLLaws.material()` returned the table row itself. The shared row is now at `engine/kernel/api/tl_laws.gd:99`, behind a public copy at line 93. The material and surface tables are read-only for packs under `engine/kernel/API.md:130`.

**Reach.** Seed Paddle builds its ball at `engine/seeds/seed_paddle/scripts/main.gd:44`. The fixture edits the returned friction in a second context, then applies the ball’s own material again in the game context. The first two runs changed the real rigid body’s friction. The second context is a test client.

[Repro](repro/C3.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh C3`

```text
REPRO C3: FAIL 2 contexts, 1 edited return value, Seed Paddle ball friction 1.00000 -> 0.03125
REPRO C3: FAIL 2 contexts, 1 edited return value, Seed Paddle ball friction 1.00000 -> 0.03125
```

**Suggested fix.** Return a copy at the public boundary and keep the shared row private to the kernel, as in the director’s change.

**Director’s fix, two fresh processes.** A fresh application of the unedited ball material provided the control. The director’s public copy now isolates the contexts.

```text
REPRO C3: PASS
REPRO C3: PASS
```

## C4. The puck keeps travelling while the rule dial is open

**Medium · May predate 17 Nov? Yes, 16 Nov (`3df10a27`).** `engine/packs/hockey/scripts/dial.gd:16` pauses the rules, then `engine/packs/hockey/scripts/main.gd:405` brakes the skaters. The loose puck continues its physics steps. The pack promises a paused match while the dial is open at `engine/packs/hockey/README.md:103`.

**Reach.** The fixture starts the shipped moving-puck drill and presses the same dial action bound to T. Both public state and the rules clock stayed paused throughout the measurement.

[Repro](repro/C4.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh C4`

```text
REPRO C4: FAIL 30 paused frames, clock advanced 0, loose puck travelled 1.367 m along x
REPRO C4: FAIL 30 paused frames, clock advanced 0, loose puck travelled 1.367 m along x
```

**Suggested fix.** Suspend puck and skater motion for the dial and restore their velocities on close. Include a moving puck in the dial bot’s pause assertion.

## C5. An idle Seed Drive player saw a three-lap victory on timeout

**Medium · May predate 17 Nov? Yes, 10 Nov (`b9a1443`).** When time expires, TLRules finishes with the score leader. The car is the only side. The HUD handler at `engine/seeds/seed_drive/scripts/main.gd:89` originally tested the winner alone. The seed requires the laps before the deadline (`engine/seeds/seed_drive/README.md:3`), and calls a time finish a failure at line 40.

**Reach.** The unmodified game idled through all 5,400 physics ticks with no input. The fixture reads the hint via the same public state that the bots receive.

[Repro](repro/C5.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh C5`

```text
REPRO C5: FAIL 5400 frames, 0/3 laps, reason time, HUD 'THREE LAPS DONE'
REPRO C5: FAIL 5400 frames, 0/3 laps, reason time, HUD 'THREE LAPS DONE'
```

**Suggested fix.** Use the finish reason to distinguish a lap victory from a timeout. The director has added this check to the HUD handler.

**Director’s fix, two fresh processes.** The director’s finish-reason check cleared the false victory after the same 5,400 idle ticks.

```text
REPRO C5: PASS
REPRO C5: PASS
```

## C6. Touching the goal line from the field side scores

**Medium · May predate 17 Nov? Yes, 16 Nov (`3249be79`, `3df10a27`).** The overlap callback at `engine/packs/hockey/scripts/main.gd:355` awards the goal on first contact with the box. The documented position rule at `engine/packs/hockey/scripts/rink_api.gd:442` requires the puck’s centre inside the goal. On the same coordinates the position rule returned no scorer. This is the entry plane at ice level, distinct from A7’s height test.

**Reach.** Both paths feed the shipped scoreboard. The fixture freezes a loose puck with half its radius across the line, waits for the real physics overlap and checks that its centre never crossed.

[Repro](repro/C6.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh C6`

```text
REPRO C6: FAIL 1 stationary puck, centre 0.060 m short of line for 6 ticks, blue gained 1
REPRO C6: FAIL 1 stationary puck, centre 0.060 m short of line for 6 ticks, blue gained 1
```

**Suggested fix.** Use one crossing criterion for overlaps and position checks. For fast shots, test the swept centre against the scoring plane so a shot that clears the volume within one frame still counts.

## C8. All three seeds accept misspelled tuning fields

**Medium · May predate 17 Nov? Yes, 10 Nov (`b9a1443`, all three loads).** `engine/seeds/seed_drive/scripts/main.gd:33`, `engine/seeds/seed_paddle/scripts/main.gd:33` and `engine/seeds/seed_wall/scripts/main.gd:34` read the tuning object, then pick the known game-specific fields without checking their siblings. `contracts/README.md:40` requires unknown schema keys to raise an error.

**Reach.** Each test copy adds one misspelled sibling to a real tuning section and retains the valid field. Every smoke check passes for 20 frames, so a builder receives no indication that the extra value has no effect.

[Repro](repro/C8.py) · `python docs/shifts/2026-11-19-night/lanes/hunt2/repro/C8.py`

```text
REPRO C8: FAIL 3/3 unknown tuning keys passed 20-frame smoke: drive.cones.mass_typo, paddle.rival.speed_typo, wall.wall.hp_typo
REPRO C8: FAIL 3/3 unknown tuning keys passed 20-frame smoke: drive.cones.mass_typo, paddle.rival.speed_typo, wall.wall.hp_typo
```

**Suggested fix.** Validate each seed’s tuning sections on load, preserving its documented annotation keys. Name the complete field path in the error.

## C9. Boot does not propagate failures to write its reports

**Medium · May predate 17 Nov? Yes for probe, 11 Nov (`52624f4c`). The check-side write dates to 18 Nov (`0b6304dc`).** `engine/boot/probe.gd:126` calls a writer which silently returns on an open failure at line 132, then exits 0 at line 127. `engine/boot/boot.gd:593` similarly lets the check tour start when the identity sidecar cannot be opened. The promised outputs are documented at `docs/EXE.md:103` and `engine/boot/boot.gd:582`.

**Reach and evidence.** The existing test exercises the editor boot scene, with writable controls and a directory occupying each requested report path. It checks the probe JSON and the check tour’s identity sidecar separately. The earlier run’s final console output was unavailable when this write-up resumed. C9 is recorded as a source-confirmed write-error path without a verified runtime count.

[Repro](repro/C9.py) · `python docs/shifts/2026-11-19-night/lanes/hunt2/repro/C9.py`

**Suggested fix.** Check the open and write results and return an error naming the requested path when either report cannot be saved.

## C10. Seed Wall measures displacement after the rubble has started moving

**Medium · May predate 17 Nov? Yes, 10 Nov (`b9a1443`).** `engine/seeds/seed_wall/scripts/main.gd:134` saves each piece’s origin when the queued break is handled. The first physics step can already have moved the pieces. Line 155 then measures travel from the late position. The scoring rule at `engine/seeds/seed_wall/README.md:4` gives a point once a piece is more than 0.6 m from its place in the wall.

**Reach.** The shipped `bot_knock.gd` plays seed 1 through its input actions. A passive observer saves each piece’s position at the actual fracture signal, then independently counts each first threshold crossing at the same instant the pack samples its score. At frame 209, three pieces qualified and none had been credited. The round still ended by score.

[Repro](repro/C10.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh C10`

```text
REPRO C10: FAIL 24 scoring ticks disagree; first frame 209, pieces beyond threshold from wall 3, credited 0
REPRO C10: FAIL 24 scoring ticks disagree; first frame 209, pieces beyond threshold from wall 3, credited 0
```

**Suggested fix.** Capture the piece positions in the break callback while they still match the wall. Pass those positions in the queued event so score, sound and visual updates can keep running in the pack tick.

## Fix review: held

**B10 — postponed releases and queued presses.** The original 64-tap regression passed twice. The new test combines consecutive shoot taps, a held sprint, alternating left/right and a release-all drain. It repeats each seed and lapse setting and compares every sampled key mask and the full stats dictionary. Every internal press and release produced a matching game-visible edge. The two seeds produced different traces. [Original](repro/B10.gd.txt) · [Controls](repro/B10-controls.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh B10-controls`

| Seed | Lapses/min | Visible down/up edges | Shoot edges + lost (48 requested) | Lengthened | Sticks | Overshoots | Frames holding both directions |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0 | 120 / 120 | 48 + 0 | 25 | 3 | 24 | 0 |
| 2 | 0 | 120 / 120 | 48 + 0 | 24 | 3 | 24 | 0 |
| 1 | 72 | 108 / 108 | 36 + 12 | 13 | 1 | 24 | 0 |
| 2 | 72 | 111 / 111 | 39 + 9 | 19 | 1 | 24 | 0 |

Both no-lapse runs kept sprint down on all 648 sampled hold frames. The 72/min setting deliberately exercises lost taps. Every run ended with all keys up.

**A14 and B1 — hockey PREDELETE.** The original rink and bench regressions passed twice. The new test cycles base → big ice → base → pond → big ice in each of three holders. Big ice detached the dress and benched two skaters. Base reinstated the original dress, rink and skaters. With the entry deleted separately, the active rink and four in-tree skaters survived for their owner. A bench node freed in advance caused no second-free error. Unloading normally, deleting the entry first, or detaching the whole holder before freeing it each left zero of nine tracked objects alive. [Rink](repro/A14.gd.txt) · [Bench](repro/B1.gd.txt) · [Ownership controls](repro/B1-controls.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh B1-controls`

```text
REPRO B10-controls: PASS
REPRO B10-controls: PASS
REPRO B1-controls: PASS
REPRO B1-controls: PASS
```

## Probed and sound

- **C11 · Timber Run restart and camera.** One run restarted during a real slide at frame 180. Scaling the body to 1.25 retained the short capsule and R restored the full-height capsule, zero speed, elapsed time and checkpoint. A second run crossed gates 0–3 in order. The orbit rose from 33° to 60° and returned to 33°. The finish HUD appeared and R retained the 338-frame session best. The five registered capture/play views matched the manifest. Both processes printed `REPRO C11: PASS`. [Test](repro/C11.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh C11`
- **C12 · Seed Wall reload and timeout.** Holding throw across a reload produced one throw. Five distinct presses cycled the five-ball pool back to ball 0. Handouts occurred at frames 0, 37, 86, 124, 162 and 200. The 3,600-tick timeout produced one horn, one opening whistle and the HUD text `TIME IS UP`. Both processes printed `REPRO C12: PASS`. [Test](repro/C12.gd.txt) · `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh C12`
- **Seed targets and rules.** C1 exercised real configured wins at one goal and four laps after the director’s changes. C5 exercised the unmodified 90-second Drive timeout with zero laps. C4 measured a stationary rules clock throughout 30 dial frames.

All gameplay evidence is headless. View registration, camera angles and HUD strings were read from the running game. No full gate or graphical capture was run for this report.
