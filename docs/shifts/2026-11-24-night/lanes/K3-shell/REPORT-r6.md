K3 SHELL, ROUND 6 REPORT (campaign night 23-24 Nov 2026; worktree .claude/worktrees/hk-shell, uncommitted, on hokej 75844e9)

OUTCOME
All ten skaters of the match (and the gym's one, and the replay's one) are thirdjam's own figure (lane K2's TLRigSkater)
driven by thirdjam's pawn (K2's skater_pawn.gd, AJamSkater::ApplySimFrame / ApplyRender), one pawn a skater fed its
snapshot entry every frame in StepOnce's order. The match hash is unchanged (ab881a00fb9af8ef, 3:1 in 9,071 frames).
The capsules stay behind data/view.json `figures: false`. Two findings: the figures cost about 2.2 ms a frame (headless) and
put hokej over the invariants' "pack in a world of many" budget (p50 2.70 ms against 1.0 ms), and the pawn could not be
reached from a pack at all, so kernel 1.20 adds the door `ctx.cores.view_script(id, name)`.

1. THE SWAP: DONE.
   - scripts/match_view.gd: one pawn and figure a skater, made as AHokejGameMode spawns them (TLRigSkater.setup({team}),
     set_human, pawn.init_skater(index, team, the cartridge's colour_hex in linear, jersey number)). Jersey numbers are
     AHokejGameMode::JerseyNumberFor (HokejGameMode.cpp:439-444) by slot in team in sim order: 7 13 42 then 4, 5 for
     blue; 9 21 88 then 14, 15 for orange (thirdjam's own fallback). Each frame: pawn.apply_sim_frame(skater, Frame), then
     apply_render(skater, 1.0) (the engine interpolates; the node's interpolation is reset on a jump the sim does not
     move through, as the stand-ins did), then fig.set_puck(the puck in the figure's frame) and fig.tick().
   - Hit-stop now goes where thirdjam sends it: hit_stop.route() returns the hold, and match_view.begin_hit_stop calls
     BeginHitStop on the victim's and the checker's pawns and holds the puck by AJamPuck's own count (BeginHitStop,
     StepSimFrame, Place: JamPawns.cpp:984-1017, ported: held where it was last drawn for the hold, then the catch-up lerp).
     The camera still holds the presentation frame (cpp:1708). With figures:false the round-3 stand-in hold is kept.
   - The puck: drawn where the sim has it (K2's shown carrier, FJamPuckShow, is not ported yet).
   - The proof modes: gym and replay show one figure (view.show_only); the others are hidden and not ticked. The replay's
     logged skater is a real snapshot entry with its place, velocity and turn rate set from thirdjam's log.
   - KERNEL 1.20 (a finding, then a fix): lint N4 lets a pack load only its own files, res://kits, rigs, style and
     kernel/api; the pawn lives in engine/cores/rink/view/ (K2's scope), so no pack could use it. Added
     `ctx.cores.view_script(id, name) -> GDScript` (engine/kernel/api/tl_cores.gd): loads
     engine/cores/<id>/view/<name>.gd, a plain name only; null and an error otherwise. manifest KERNEL_API 1.20, API.md
     section 24 row, docs/generated (tl arch --index). The pack's kernelApi is 1.20. Director: the alternative is to move
     the pawn under engine/rigs/skater (it references nothing outside itself); your call.
2. FILM, LOOKED AT: r6_sbs_film_20s.mp4 (thirdjam's 20 s film left, ours right, from the opening faceoff, the layout of
   r3), r6_sbs_sheet_a.jpg / r6_sbs_sheet_b.jpg (every 2.5 s), r6_ours_every4s.jpg (our whole minute, every 4 s),
   r6_boards_close.jpg, r6_capsule_vs_figure.jpg, r6_contact_strip.jpg. Not the same play (thirdjam's playtester against
   our scripted hand). What my eye rejects now that figures stand there:
   a. Scale: right. At the opening faceoff our human and the centre opponent stand the size thirdjam's do (about 150
      px of 480); the far wingers match too. Our figure is shorter than the 1.64 m capsule was (r6_capsule_vs_figure).
   b. The camera at the boards on a real figure (r6_boards_close.jpg, frames 1860-1990): the human stopped with his
      back at the side boards and thirdjam's boards view brought the eye to 0.6-0.9 m from him, 2.3 m high, pitch -35:
      his helmet fills the lower third for two seconds. The camera is thirdjam's (0.54 cm on its film); thirdjam's code
      fades only the HUD rings near the eye (HUDPossession.cpp:47 NearCamFadeM), never the figure. A capsule hid this.
      Not changed; worth a look against thirdjam doing the same (its film here never stops at the boards).
   c. Bodies through bodies at contact (r6_contact_strip.jpg, about 45 s): two figures overlap shoulder into chest.
      The sim's skater radius is 0.4 m and the figures' pads are wider; checks and hits play as skating (K2: not
      ported), so nothing pushes or reacts.
   d. Shadows: soft grey and faint under ours; thirdjam's are darker and sharper at the feet. The figures stand on the
      ice (no float seen); feet slide a little on the stops (the stop take is K2's; not judged further).
   e. Backs: a blank light patch where the number goes (K7's look lane); the far figures read as orange/blue dolls,
      not as thirdjam's numbered players. Ice whiter and flatter than thirdjam's lilac grey (known since round 3).
   f. The stick: the human's stick swings far behind him at times when the aim is behind (thirdjam's aim rule through
      the pawn; seen in r6_capsule_vs_figure lower right). The carried puck lies where the sim has it, often a stick's
      length from the blade drawn: the shown carrier (K2) is what puts it on the blade.
   g. Verbs that play as skating (as K2 said): shots, passes, pokes, checks, falls and get-ups, board hits. No pops or
      teleports seen in the minute; no slide-in at the faceoff resets.
   h. A cream light pool on the ice round the human when the eye is low (boards view): it is there with the capsules too
      (r6_capsule_vs_figure top row), so it is the hall light on the ice, not the figure.
3. FRAME COST, figures against capsules, the same match (bot_match_hand, seed 1):
   - Headless (tl smoke, 3,600 frames, the pack's tick): p50 2.21 / 3.16 ms (two runs) against 0.49 / 0.51 ms; p99 3.6 /
     4.2 ms against 0.9 ms. So ten figures cost about 2.2 ms a frame, as K2 measured (2.0).
   - In a window (1280x720, D3D12, RTX 4090, uncapped: --fixed-fps 60 --disable-vsync --max-fps 0, 5,400 frames, Godot's
     per-second fps): figures 280 fps median = 3.57 ms a frame (slowest second 4.83 ms); capsules 768 fps = 1.30 ms.
     Both far inside the 16.7 ms of a 60 Hz frame.
   - FINDING: `tl invariants` now FAILS its budget check: frame p50 2.70 ms over the 1.0 ms budget of "a pack in a world of
     many" (p99 3.59 ms, under the 4 ms stage budget). Determinism there passes. hokej is in games.json, so the world
     step will carry these ten figures too. Options (not mine to pick): K2's next cut (a native pose blend, their report),
     ticking only the figures the camera sees (a deviation: thirdjam takes WasRecentlyRendered as true, K2 deviation 9),
     or a budget class for a whole-game dungeon. I did not hide the figures from the headless run.
4. DETERMINISM AND EXPORT, HEADLESS:
   - The match hash is round 5's: bot_match_hand core hash ab881a00fb9af8ef, state 4685cd21e60096f0 after 9,072 frames
     (invariants twice; record -> replay the same); idle ad03a2add6ce42c1 (smoke four times, figures and capsules: the
     same). What is drawn does not reach the state.
   - Export: export.sh build --no-warm PASS (the pck carries cores/rink/view/skater_pawn and rigs/skater), export.sh check
     --no-window PASS: hokej 6e9c32c23eaf3d45 in the editor binary and the exe (600 frames), as round 5.
   - rawtrace (round 5's finding) is unchanged: first differing frame 1,506 (with K1).

GATES
hokej: lint PASS, smoke PASS, bots 9/9 PASS (match_hand 3:1 ab881a00fb9af8ef, rule_w_away, rule_s_lock, rule_aim,
  rule_aim_anchor, rule_signals, rule_restart, gym_hand, tj_replay 0.54 cm); invariants: determinism PASS, budget FAIL
  (above). tl check --tier fast: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229 PASS; foreman NOT RUN (no
  node_modules in this worktree). Full tier not run (your instruction).

DEVIATIONS (new)
- The figure ticks once a sim frame (DT 1/60), thirdjam's once a rendered frame (the law of physics frames; K2's own).
- Puck hold catch-up drawn at alpha 1 (thirdjam lerps with the render alpha; the engine interpolates between frames).
- Every figure is given the puck to look at (thirdjam's figure reads the puck actor itself; K2 deviation 12).
- The replay mode's figure is fed a real snapshot entry with the log's place and motion (thirdjam's log has no pose).

CHANGED FILES
engine/packs/hokej: scripts/match_view.gd (figures + stand-ins behind the flag, AJamPuck's hold), scripts/main.gd
  (view.json, view_script, hit-stop to the pawns, show_only, the replay's skater), scripts/hit_stop.gd (route returns the
  hold), data/view.json (new), pack.json (kernelApi 1.20), README.md.
engine/kernel: api/tl_cores.gd (view_script), runner/manifest.gd (1.20), API.md; docs/generated/API-INDEX.md,
  API-V1.json, REPORTS.md (tl arch --index).
docs/shifts/2026-11-24-night/lanes/K3-shell: REPORT.txt, ROUND-6.md, STANDUP.md, r6_* images and film.
Removed a stray engine/cores/rink/bin/~rink_core...dll (Godot's reload copy from my runs; untracked). No git writes.

QUESTIONS FOR THE DIRECTOR
1. The budget (finding 3): which of the three ways?
2. Kernel 1.20 `ctx.cores.view_script`, or the pawn moved under engine/rigs/skater?
3. The boards view on a real figure (2b): accept as thirdjam's, or have K2/K3 look at thirdjam doing the same?

IMAGES TO LOOK AT (docs/shifts/2026-11-24-night/lanes/K3-shell/)
r6_sbs_film_20s.mp4, r6_sbs_sheet_a.jpg, r6_sbs_sheet_b.jpg, r6_ours_every4s.jpg, r6_boards_close.jpg,
r6_capsule_vs_figure.jpg, r6_contact_strip.jpg
