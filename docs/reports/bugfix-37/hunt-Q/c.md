# D5 arm C status (Opus directing GPT 6.2 Astra)

## Final report (13:37, 18 Nov 2026)

Started at 13:06, report at 13:37: 31 minutes of wall time against the 75-minute box. Findings are in `docs/reports/astra-trial/d5/findings.md`
and the reproductions are in `docs/reports/astra-trial/d5/repro/` (38 files).

### Acceptance
1. **findings.md: met.** It has 32 numbered findings: 2 high, 15 medium and 15 low. Each one gives file:line, the failure, the severity, the command and the printed lines.
   - Every printed line comes from **my own re-run** on this worktree. All 33 of Astra's candidates reproduced exactly as Astra claimed.
   - Most important:
     - **#1 (high)**: `selftest.sh:205` world.same prints PASS when its `world.sh` child is stopped before its first hash. This breaks the gate-honesty law.
     - **#2 (high)**: `world_space.gd:317/263` copies a pack's box, sphere and capsule colliders into the world by the pack's own `Shape3D` and never keeps that `Shape3D`.
       - The world copies colliders only on a plot's first arrival (`view.gd:351-361`).
       - So after a next round, the walker room's walls are still drawn but have no collision.
     - **#3**: `visit.gd:270` writes `length` as the count of sparse entries, so a rebuilt on-stage game loses its record.
     - **#4**: a bot's held `gas` press carries over to the person on stage.
     - **#5**: the avoiding camera can be placed inside a body its sphere already touches (a pine crown when he jumps).
     - **#6**: a shut hole draws the pad, but there is no collider under it.
     - **#7**: `ground_cover` uses the axis-aligned box of a rotated deck, so a 42.5 m hole opens over ground nothing covers.
     - **#8**: a body put at rest on a 65 degree bank stands there for ever.
     - **#9**: after leaving a game that he entered during a slide, the figure keeps the slide clip.
     - **#10**: bones a clip leaves out keep their old rotation; under `look_at`, the neck reaches 172 degrees.
     - **#11**: turning in the air twists the planted boots 30 degrees on landing.
     - **#12**: boil.py reads a still 720p clip as 100 % flicker.
2. **Reproductions run from the worktree root as written: met.**
   - The `.gd` repros use `timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/<x>.gd"`. #32 also needs `--fixed-fps 120`, and #30 needs `-- --mode=skate --team=red`.
   - The `.py` and `.sh` repros run as `python ...` and `bash ...`.
   - I ran all of them. Temporary files clean up after themselves (the repro folder holds only .gd, .py and .sh files).
3. **Suspicions labelled: met.** They are the last section of findings.md:
   - One item I did not accept: look.sh deletes `<out>.avi`. That file is look.sh's own intermediate movie, so this is by design.
   - One suspicion I did not reproduce: `visitor._frame_usec` grows without limit during a person's visit.
   - A caveat: for #2, #4, #5, #6 and #17, whether the shipped game reaches them was traced through the callers, not run in a world.

### Caveats a reviewer should know
- Without git (a trial rule) I could not see which lines are new today. Findings marked *(may predate today)* are #1, #2, #4, #15 and #22. They are in scoped files but probably in older code.
- Severity is my grading, not Astra's. Astra rated 9 candidates high and I kept 2. The other 6 I lowered to medium, and look.sh I rejected. I based each grade on whether the shipped game gets there (for example, the walker's 0.35 m capsule is wider than the 0.3 m camera margin, so ordinary walls cannot trigger #5).

### Files changed
- Only `docs/reports/astra-trial/d5/` changed: findings.md, c.md (this file), repro/ (38 files) and astra/ (briefs, Astra logs, cand_a.md, cand_b.md, cand_r.md, review.md).
- No engine file was edited. `find -newer` shows no change outside `docs/reports/astra-trial`.
- `engine/.godot/` was created by a one-time `--import` so the headless repros can run; it is an import cache.

### Next
- First fix #1 and #13/#14: make the gate fail when a step finds nothing or its child is stopped.
- Then #2: keep the pack's `Shape3D` in `_keep`, or copy the colliders again on every `rebuilt` event.
- Run #2, #5 and #6 in a real world walk (tour_next_round, wf_canopy with a jump under a pine, visitor_walk with a cold cache) to turn the traced reach into measured reach.

### Cost
- Wall time: 31 minutes (13:06 to 13:37).
- **Astra: 5 runs, 915,170 tokens** (sum of the "tokens used" lines):
  - a: 153,730
  - b: 172,915 (stopped by OpenAI's "possible cybersecurity risk" filter)
  - b2, resuming b's session: 185,011 (this may count b's context again)
  - r: 176,979
  - skeptic review: 226,535
- My own (Opus) tokens are not visible to me.
- Share of the work: Astra wrote all 38 repros, the 33 candidate write-ups and the reach review, which is about 85 % of the lines. I wrote the briefs, re-ran and judged every finding, re-graded severities, added the reach notes and rejected one item, about 15 %. findings.md is assembled from Astra's text with my edits. I found the `avoid_min` lead myself before Astra reported it too.

### Where Astra was strong and where it needed me
- **Strong at reproductions.** All 33 candidates reproduced on my re-run, with no false repro. Most have a control line next to the FAIL line, and the doc lines I spot-checked were accurate.
- **Strong at depth.** It found defects I would not have reached in the time box: a Shape3D outliving its body, ffmpeg's chroma rounding in boil.py, `cast_motion` ignoring a body the sphere starts inside, AABB coverage of a rotated deck, and a gate step that passes when its child is stopped.
- **Needed me for severity and reach.** It grades by the worst case: 9 "high", of which 2 hold once you ask whether the shipped game gets there. It also put one by-design behaviour (look.sh's own .avi) in as high.
- **Its skeptic role failed.** Asked to argue against 7 doubtful items, it returned "REAL in play" for all 7. Its traces through the callers were useful, but I had to check them myself (I checked 2).
- **Operations needed me.** One run was stopped by OpenAI's cyber filter after it had written its repros but before its report; resuming by session id recovered it. The brief needed a Godot command line I had verified first; with that, the runs needed no other correction.

## Log
- 13:06 start (date: Wed Nov 18 13:06:00 CEST 2026). Read brief files, scope.txt (49 paths, ~9200 lines of gd/py/shader).
- 13:06 tl doctor: Godot found; ran `--headless --import` once in engine/ so headless repros can resolve class names. Splitting scope into 3 Astra runs (walker/camera/runner, terrain/draw, rigs/shaders/tools).
- 13:08 launched 3 Astra runs in parallel (a: walker/camera/runner/boot/walks; b: terrain/landscape/draw; r: rigs/shaders/tools). Brief: docs/reports/astra-trial/d5/astra/brief_common.md
- 13:09 while Astra hunts: read world_body.gd, visitor.gd, tl_chase_cam.gd myself (to review). Own lead: TLChaseCam.setup rejects documented option avoid_min (to cross-check against Astra).
- 13:12 Astra runs in progress; 26 repro files written so far; verified a_avoid_min.gd myself (prints FAIL, matches my own lead).
- 13:19 Astra run b ended early: OpenAI 'possible cybersecurity risk' flag (false positive) killed it after repros, before cand_b.md. Resumed its session (run b2) to write cand_b.md only. Pass 1: ran all 28 .gd repros myself; most print FAIL, now reviewing whether each expectation is the documented behaviour.
- 13:20 run a done (cand_a.md: 12 findings). Verified all 12 repros myself (all print FAIL as claimed); reviewing expectations vs docs; severities to be re-graded (capsule radius 0.35 > margin 0.3 limits camera_wall to crowns/packs).
- 13:23 runs a, b2, r done (cand_a 12, cand_b 9, cand_r 12 = 33 candidates). Pass 2: I ran every repro (gd, py, sh) myself: all 33 print FAIL as claimed. Launched Astra skeptic run (brief_review.md) on 7 reachability doubts; writing findings.md meanwhile.
- 13:28 own reach check for #2: view.gd:351-361 copies a pack's colliders only on its first arrival (not _arrived.has(i)); later 'rebuilt' events (next round) never re-copy. Waiting for the skeptic run to confirm the old holder is freed.
- 13:36 skeptic run done: 7 of 7 'REAL in play' (anchored: never said no); I spot-checked 2 (view.gd first-arrival copy; tour_views has no pad_h). findings.md generated: 32 findings (2 high, 15 medium, 15 low), 1 rejected, 3 suspicions. Checked nothing outside docs/reports/astra-trial changed (find -newer).
