H1 hand: REPORT, build 1 (the behaviour sheet built into the house hockey). Full write-up: BUILD.md in this folder.

Built (engine/packs/hockey only; no kernel change; scripts/ai, data/ai.json, data/levels untouched):
- Sheet 4.1 rows S1-S17 (S19: no change by design): wind-ups 8/8 (clips timed), check recovery 0 / 12 after a whiff, cross
  recovery 30, the cross lands at the meeting and strips a carrier at the press, unpressed contact exchanges speed
  (restitution 0.2, braces as effective mass), down 36-126 so the 24-frame rise fits thirdjam's total, fun.stop off, the poke
  certain in reach (front/side; never from behind; no chance after a cut), live frames 0-7, again after 14, a miss locks 20,
  the puck to the poker; carrier 0.92, sprint 0.08/0.97; turn 5.0.
- Route A rows A2-A4: skate_accel 8.73, reverse_decel 13 (measured; the sheet's 18.9 gave 23 frames), hit-law speeds x0.727.
- Not built: route B (owner), S18 (withdrawn: thirdjam's "puck comes back 24.8/min" was a trace artifact, the puck at its
  1.65 m reach edge; corrected in BEHAVIOUR-HAND.md 0 and 3.2), A5 (data/ai.json: "For H2" in BUILD.md).
- Found and fixed: the check's pull ran the attacker into his man; the cross had no man when pressed from > 0.88 m; the pass
  magnet could orbit a pass round its receiver for ever. Open: a drill re-placed after a hit puts r0 0.2-0.35 m off his mark.

Proof (before -> after, thirdjam), our own instruments: build-up 19 -> 34 frames (34); stop 19 -> 29 frames (29-30); turn
heading 53 -> 49 frames (50), turn overshoot +27 % -> +14 % (+14 %); carrier 0.88 -> 0.80 of free (0.80); check again after a hit
42 -> 2 frames (at once); timed cross 12 stumble -> 9 knockdown; unpressed contact front 0/0 -> 4.32/2.52 (4.32/2.52), side
1.80/0, back 5.40/3.60 (exact); your keys back after a front hit 104 -> 88 frames (87 at our scale); freezes 8 frames -> 0;
poke 14/20 and 7/20 at frame 7, loose -> 20/20 and 20/20 at frame 1, to the poker. Pick-up, ring and pass scenes: identical.
In 24 ladder matches (TLHand regular, pro): freezes 3.97 -> 0 a minute; he is poked off 10.0 -> 27.3 and hit off 13.9 -> 7.2
(thirdjam 7.2) a minute of carrying; wins 12 -> 9 of 24. Not reached: back to 90 % the other way 65 frames (61); carrier
build-up 35 (34); build-up metres 0.046 of the rink (0.042). Body widths unchanged (route A): 5.2 a second (15.8).
Window: build1_window.mp4 (18 s) and build1_window_sheet.jpg; window rows byte-identical to headless for stop, turn, check, cross.

Tests changed (each with its row in BUILD.md): bot_sprint (S15/S16), bot_reverse_stop (A2/A3), crazy_pickups (A2), bot_fun
(S10), bot_check (A4/S9), bot_contact (A4/S4/S9), bot_poke (S11-S14/A2, drills poke_lock and poke_cut moved), bot_reach
(S12/S13), bot_windup (row 1 from a fresh match: the open drift), bot_hockey_ai (seed 1 now a 2:2 draw at the time limit;
accepted as played out: a judgement call for the Director). Pack tests 56/56 before and after (seed 1). Ladder seed-1 figures
moved (BUILD.md), not tuned back.

Gates:
- tl check --tier fast: PASS arch [12/12], assets [4/4], cards [3/3], devx.test [229/229], foreman.typecheck (12:47).
- tl check --tier full --only packs: FAIL twice, only `hockey invariants: invariants.many_budget` (frame p50 1.382 then 1.101 ms,
  budget 1.0); 128 of 129 verb runs passed. Main's own hockey pack fails the same check back to back under the same load
  (1.05-1.35 ms; the build 1.08-1.36). Not a pass: it needs a quiet machine or the Director's call.

Changed files: engine/packs/hockey/{data/tuning.json, data/drills.json, scripts/hits.gd, scripts/contact.gd (new), scripts/main.gd,
scripts/state.gd, scripts/poke.gd, scripts/carry.gd, README.md, tests/(10 above)}; docs/research/hockey-teardown/BEHAVIOUR-HAND.md
(correction), probes/hand_step.gd (keep flag, hit columns), probes/hand_blip.mjs (new); this folder: BUILD.md, REPORT.txt,
STANDUP.md, build1_window.mp4, build1_window_sheet.jpg. Scope note: .claude/sessions.json holds only the docs claim for this
lane (d23-hand); the engine/packs/hockey claim is the Director's to record.

Questions for the Director: the packs gate's frame budget under load; bot_hockey_ai's draw; the open placement drift; whether
the bots' 27 pokes a carry-minute is the ladder's aggression (H2).
Next three: a quiet-machine hockey invariants run; chase the r0 placement drift; route B on the owner's word.
