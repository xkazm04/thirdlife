# N3c Foreman: a stall at different frames is the machine: builder report and Director verification

Sent by the Director at 02:25 on 2026-11-11 after the N3b gauge misjudged four load stalls on the real hockey job. Builder wall time 8 min. No model was called.

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

N3c: FOREMAN FOLLOW-UP REPORT (builder; 2026-11-11, 02:25 to 02:33 CEST)

## Status

The different-frame rule is built, and the four real reports classify as machine load for both rounds. `npx tsc --noEmit` exits 0. `npm test`, run once at the end with `TL_GODOT` and `TL_ENGINE_DIR=site/_engine_snapshot3`, gave 165 tests, 165 pass, 0 skipped: the 161 from before plus 4 in `foreman/src/test/n3c.test.ts`. No model call, no git command, nothing of mine left running. The hockey job directory was only read (0 files changed, no lock file).

My N3b gauge was the fault. A 1.3-second reference run seldom meets a 250 ms scheduler stall, and I had it say "The time is this pack's own" on that evidence.

## What I built

1. **Different frames mean the machine.**
   - The frame and the callback are read from the watchdog error as the runner writes it ("... (frame N)").
   - When every run of the same check stalled at a different frame or in a different callback, the verdict is machine load. The gauge is not run at all.
   - It takes the same path as "busy": a note, wait 20 s, 40 s, 80 s, the check again. Each retry joins the comparison. After the tries the package is `blocked` with cause `machine_busy` and the job is paused.
2. **Same frame means the pack.**
   - When all runs stalled at the same frame in the same callback, the round fails without waiting.
   - A note "[foreman] the same stall twice: ..." is written, and the builder's next prompt carries the frame and the callback.
3. **No frame, or a mixed picture, falls back to the gauge.** If any report has no frame, or some frames repeat and some do not, the gauge decides as before.
4. **Figures in the note.** The median and p99 that a failing run still reported are in the note. For round 3 it reads "median 0.715 ms, p99 1.278 ms, so single ticks blew the watchdog's limit while the frames around them stayed far under the 8 ms budget".
5. **Honest gauge wording.** The gauge's note now starts "machine not shown busy". It says a passing reference run is evidence about the moment after the failure, not proof about the moment of it, and that the failure is reported as measured.
6. **Feedback re-reads the reports (not in your list).** When the next round's prompt is built, the failed check's runs are read again from their report files. Stalls at different frames are told to the builder as machine load, with "if an earlier message of the Foreman called this the pack's own time, that was wrong", and the report is not handed over as its pack's failure.
   - This matters for your resume, because the hockey log was written before the rule.
   - On a scratch copy of the real log, `hockey_ai`'s round 4 prompt now reads "Round 3 did not pass invariants (V3), but NOT because of your pack: ... frame 3522 in _pack_tick ...; frame 1307 in _bot_tick ...".

Test support added:
- Fake runner marker `FAKE_STALL_AT(n)` stalls at the same frame every run.
- `FAKE_RUNNER_LOAD_FRAMES` makes load trips land at different frames.
- The four real reports are copied to `foreman/fixtures/hockey-stalls/`.

## Tests (4 new)

- Two stalls at different frames with a reference pack that would pass: retried, no round spent, the builder hears nothing, no reference run made. A second case where the stalls keep coming ends `machine_busy` and paused.
- Two stalls at the same frame: straight to the builder with "frame 4885 in _pack_tick".
- The four real hockey reports through the classifier: machine load for round 2 (frames 4885 and 6483) and round 3 (frames 3522 and 1307), with the round 3 figures in the text.
- A log written before the rule: the next round's prompt says machine load and does not contain the old verdict.

## The resume command line

The `resume` line you used before works unchanged. I suggest one change: add `--round-limit 6` in place of `--round-limit 4`.

`hockey_ai` is at round 4 of 4, and rounds 2 and 3 were lost to the machine. With the limit at 4, one more failed round sends the package to a re-plan. The limit is a run option and is not stored in the log, so raising it on `resume` is enough.

## What I could not decide or verify

- **Mixed stalls.** If some runs repeat a frame and others do not, the Foreman falls back to the gauge, which is the weak instrument. I did not find a better rule in the time.
- **Frame-budget failures.** A p99 over 8 ms with no watchdog stop has no frame to compare. It still depends on the gauge and the median rule. That is the `hockey_ai` round 1 case, which the 2 ms tick and p99 limits may or may not catch under tonight's load.
- **The bot's "0 shots" failure.** That is a real failure of the pack and goes to the builder as an ordinary bot failure. I did not look into it.
- **Live use.** Nothing here has run with a real model or on the real job. The prompt check was on a scratch copy of the log.
- **Contract.** `contracts/JOB.md` is read-only for me. The note prefixes "the same stall twice" and "machine not shown busy" are new.

## Minutes spent

02:25:30 to 02:32:56 CEST by `date`: 8 of the 20 minutes. The record is in `C:\Users\kazda\kiro\third-life\foreman\JOURNAL.md`, section "N3c".

---

## Director verification

Done 02:34 to 02:45 on 2026-11-11.

| Check | Result |
|---|---|
| `npx tsc --noEmit` in `foreman/` | exit 0 |
| `npm test` with `TL_GODOT` and `TL_ENGINE_DIR=site/_engine_snapshot3` | 165 tests, 165 pass, 0 skipped |
| first live use, the hockey job's `resume` at 02:37 | `hockey_ai` round 4: five runs of `bot` stalled at five different frames (9432, 274, 4195, 2590, 17076); the Foreman wrote "inconclusive: machine busy" each time, waited 20, 40 and 80 s, then blocked the package with cause `machine_busy` and paused the job. No builder round was spent and the builder was told nothing false. |

The rule works as designed. What it also shows: with three builders, another session and a real job on one machine, five
runs in a row met a 250 ms stall. Real jobs need a quiet machine or a watchdog that counts processor time, not wall
time; the second is a kernel change for a later pass.
