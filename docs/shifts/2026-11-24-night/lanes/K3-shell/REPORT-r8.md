K3 SHELL, ROUND 8 REPORT (campaign night 23-24 Nov 2026; worktree .claude/worktrees/hk-shell, uncommitted, on hokej 2bede87)

OUTCOME
The pack's own hit-stop port (scripts/hit_stop.gd, deleted) and its puck rule are replaced by lane K2's show object
(ctx.cores.view_script("rink", "skater_show")): one owner of thirdjam's hit-stop picks and holds and of the carrier the
screen shows. The carried puck is drawn on the shown carrier's blade socket; shots, passes and pokes read as verbs on film.
The match hash did not move (ab881a00fb9af8ef; state 4685cd21e60096f0). Export check headless PASS.

1. THE SWAP: DONE (scripts/match_view.gd, scripts/main.gd).
   - One sim frame of the match, in thirdjam's order (HokejGameMode.cpp:1664-1707, as skater_show.gd's header and K2's
     verb_gym.gd drive it): the bus events to every figure (DeliverEvents: OnBusEvent for knockdown, check, lift, deke,
     as verb_gym delivers them), show.step_sim (HitStopRoute, then FJamPuckShow::StepSim), every pawn's apply_sim_frame,
     show.after_pawns (the wind-up takes, the puck's hold count), every pawn's apply_render and figure tick, then
     show.render: the puck where it is drawn. The figures get set_rivals (K2's [ChkScan]).
   - The presentation hold: show.presentation_held(frame) (cpp:1710): no camera step and no HUD on a held frame, as before.
   - The figures look at the puck where it was last drawn (thirdjam's figure reads the puck actor), no longer the sim's.
   - The stand-ins (data/view.json figures false) take the same show: the puck by its render, the stand-ins of the
     show's last pick hold while the frame is held.
   - A restart: the show resets itself when the frame goes back (skater_show.step_sim); the pack's own reset is gone.
   - The proof modes (gym, replay) draw one figure without the show (no hits, no puck), as before.
   - Not set: skater_show's pass_target_of (UJamSim::HumanPassTarget, not in the snapshot: K2's deviation), so no mate
     calls for the pass.
   - The stand-in puck's origin is its base, the show gives the puck's centre: drawn at centre - 0.04 m (AJamPuck
     HalfHeightM). Our puck is still the round-3 stand-in, 2.5 cm tall; thirdjam's is 8 cm tall (InitPuck, JamPawns.cpp:
     865-870): listed, not changed (the arena / look lanes').
2. THE MATCH HASH: unchanged. bot_match_hand 3:1 in 9,071 frames, core hash ab881a00fb9af8ef; invariants: idle
   ad03a2add6ce42c1 twice, the bot twice 4685cd21e60096f0 after 9,072 frames. Presentation only, as designed.
3. FILM, LOOKED AT: r8_sbs_film_20s.mp4 (thirdjam left, ours right, 20 s from the opening faceoff), r8_sbs_sheet_a.jpg,
   r8_sbs_sheet_b.jpg, r8_ours_every4s.jpg (our minute), r8_carry_strip.jpg (a pickup and carry, every 8 frames),
   r8_shot_strip.jpg (a shot, every 5 frames). With K7's felt the backs carry numbers (7, 21, 9, 15, 88).
   - The carry: the puck now comes to the blade at the pickup and rides on it (r8_carry_strip, row 2), where in round 7
     it lay a stick's length off. It sits a puck's width ahead of the blade's middle at times.
   - Verbs: the shot reads (r8_shot_strip: the stick drawn back across the body, the release, the follow-through, the
     puck to the net); the pickup turns the body to the puck; passes and pokes play their takes.
   - Still skating (K2's round 4, listed not fixed): contact: bodies overlap, nobody reacts to a check or falls.
   - The look: the figures are lit by the style's sun, not the hall rig (K7 said so until the arena): shadows under ours
     stay faint; thirdjam's are dark at the feet. The puck is small and flat beside thirdjam's (above).
   - The HUD now has commentary lines at the bottom ("Welcome to the rink...", "Blue lays the body.", "Check, and a
     turnover", "Swing and a miss.") where thirdjam shows its barks; the chevron now floats a few pixels over the helmet
     (round 7's "on the helmet" is gone).
   - The close boards view (32 s) stands as thirdjam's (your decision: a surpass item).
4. GATES AND COST.
   - hokej: lint PASS; bots match_hand, rule_restart, gym_hand, tj_replay (0.54 cm), rule_signals PASS.
   - invariants: PASS on a quieter machine (determinism, solo_budget p50 3.04 ms, stage p99 3.78 ms of 4, 3 runs needed).
     A first run, made while my film recorded (and another session's Unreal Editor holds 4.3 GB), FAILED the stage p99
     at 4.02 ms. The figure has grown since round 7 (p50 2.16 -> 3.04 ms, p99 3.44 -> 3.78): K2's round 3 driver, K7's
     felt and the show together. The stage p99 (4 ms) is not part of the solo class: hokej is now close to it on any
     loaded machine. Director: a solo p99 too, or K2's native pose blend first?
   - tl check --tier fast: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229 PASS; foreman NOT RUN (no node_modules).
   - Full tier not run (your instruction).
EXPORT
   export.sh build --no-warm PASS (tag 2bede87); export.sh check --no-window PASS: hokej 6e9c32c23eaf3d45 in the editor binary
   and the exe (600 frames); the world 0 script errors, 0 engine errors in the editor, the exe and the exe copied elsewhere.

CHANGED FILES
engine/packs/hokej: scripts/match_view.gd (the frame around the show), scripts/main.gd (the show's presentation hold, the
  hit_stop port out), README.md; deleted scripts/hit_stop.gd.
docs/shifts/2026-11-24-night/lanes/K3-shell: REPORT.txt, ROUND-8.md, STANDUP.md, r8_* images and film. No git writes.

DEVIATIONS (new or changed)
- The figures look at the puck where it was drawn the frame before (thirdjam: the puck actor at the figure's tick, the same
  frame's placement before the late puck tick); the difference is one frame.
- Bus events: only the four of K2's verb_gym (knockdown, check, lift, deke) are delivered; thirdjam's DeliverEvents gives
  the figure every event (the figure ignores the rest today).

IMAGES TO LOOK AT (docs/shifts/2026-11-24-night/lanes/K3-shell/)
r8_sbs_film_20s.mp4, r8_sbs_sheet_a.jpg, r8_sbs_sheet_b.jpg, r8_ours_every4s.jpg, r8_carry_strip.jpg, r8_shot_strip.jpg
