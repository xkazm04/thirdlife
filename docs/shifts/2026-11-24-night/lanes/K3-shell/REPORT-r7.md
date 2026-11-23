K3 SHELL, ROUND 7 REPORT (campaign night 23-24 Nov 2026; worktree .claude/worktrees/hk-shell, uncommitted, on hokej 1389d47)

OUTCOME
`tl invariants` on hokej passes honestly: a dungeon with no village plot is now held to a solo budget (p50 8.0 ms, check
`invariants.solo_budget`): hokej's p50 is 2.16 ms, with all ten figures ticking headless. The YOU chevron and tag now stand
at the height of the figure's head socket (thirdjam's HumanHeadWorld), passed to K5's layer without touching scripts/hud.
The minute is filmed again with the HUD beside thirdjam's film and looked at. Export check headless PASS at the new head.
The match hash is unchanged (ab881a00fb9af8ef).

1. BUDGET CLASS: DONE (engine/kernel/host/invariants.gd).
   - `budget_class(pack_dir, boot_dir = "res://boot")`: "many" when a plot of engine/boot/village.json names the pack's game
     (games.json `name` for its `from`); "solo" when engine/boot/dungeons.json lists the pack and no plot names it; "many"
     otherwise (a pack outside the engine's tree too). BUDGET_SOLO_MS_P50 = 8.0.
   - The p50 check: solo -> check id `invariants.solo_budget`, detail "frame p50 2.164 ms (budget 8.0 ms for a game alone in
     its world: a dungeon (packs/hokej) with no village plot; the one-of-many budget 1.0 ms does not apply)"; many -> the
     old id `invariants.many_budget`, its detail now names why ("placed in the village (plot 'hockey')" etc.). The stage p99
     (4 ms, `invariants.frame_budget`) is unchanged and applies to both: hokej 3.44 ms, close to it (worth knowing).
   - Test: engine/kernel/host/budget_class_test.gd (+uid), selftest block engine/tools/selftest.d/845-budget-class.sh
     (`budget.class`): 12 checks PASS: on the engine's boot files hokej solo; parkour and hockey (dungeons with village
     plots), ex_walker (plot only), bad_budget (neither), a folder outside the engine many; and a fixture boot dir with each
     case alone (dungeon only; dungeon not even in games.json; dungeon and plot; plot only; neither).
   - hokej `tl invariants`: PASS, every check: determinism ad03a2add6ce42c1, frame_budget p99 3.442 ms, solo_budget p50
     2.164 ms, entity 62 nodes, bot twice 4685cd21e60096f0 after 9,072 frames. Figures not hidden from the headless run.
   - The contract (contracts/RUNNER.md "Frame budget (V3)") still names only many_budget: yours to word. docs/PERF.md's
     table likewise.
2. THE YOU CHEVRON ON THE HEAD: DONE AS FAR AS K5'S LAYER LETS ME.
   - K5's layer had not done it: hud.gd `_you_marker` projects (Pos.x, head_m, Pos.y) with head_m = 1.64 (the stand-in).
   - What I passed: match_view.gd `head_world(i)` = thirdjam's HumanHeadWorld (HUDWidget.cpp:1089-1121): the figure's
     head_socket, come back along the head's axis (head bone -> socket) by jam.hud.MarkerLiftCm -18 (HUDWidget.h:322), in
     world space. main.gd sets `screen.view.head_m = head_world(human).y` before the existing Screen.frame_of call (one
     line; no file under scripts/hud touched). So the chevron rides the figure's real head height (it drops when he
     crouches at the faceoff, as thirdjam's does).
   - NOT done (K5's): the head's XY. K5 anchors over the skater's sim point; thirdjam over the socket itself (a lean, a
     fall). For K5: take a Vector3 (e.g. ui["head_world"] or a `head_world` var) in `_you_marker` in place of
     (Pos, head_m); match_view.head_world(i) gives it. Also hud.gd figure_box_m (the keep-clear box) is still the stand-in's
     0.42 x 1.64 x 0.25.
3. FILM WITH THE HUD, LOOKED AT: r7_sbs_film_20s.mp4 (thirdjam left, ours right, 20 s from the opening faceoff),
   r7_sbs_sheet_a.jpg, r7_sbs_sheet_b.jpg (every 2.5 s), r7_ours_every4s.jpg (our whole minute), r7_chevron_on_head.jpg
   (crops: the chevron over our human above, thirdjam's below). What my eye rejects:
   a. The chevron sits ON the helmet (its tip touches or enters the helmet's top); thirdjam's floats a few pixels above it
      (r7_chevron_on_head.jpg). Same rule, same -18 cm: so our head_socket is lower over the helmet than thirdjam's mesh
      socket (K2 exported head_socket as a bone; thirdjam reads a mesh socket). For K2 to check the socket against
      thirdjam's mesh; I did not tune the lift.
   b. The bottom-left controls panel (six rows, WITHOUT THE PUCK) is a block where thirdjam's film shows a one-line strip
      ("LMB CROSS-CHECK  RMB CHECK"; the full key line at the faceoff). K5's (panel.gd); listed only.
   c. thirdjam's barks and calls ("HE JUST GOT IT", "Blue shoots!", the coach's lines under the score) are absent; the
      scoreboard plates are smaller than thirdjam's relative to the frame. K5's / K6's.
   d. Ours shows "PRESS SHOOT AT THE DROP, NOT BEFORE" under the faceoff dial; thirdjam's film at that moment does not
      (it is thirdjam's first-faceoffs hint; its film may be past them). Not judged.
   e. Same as round 6, for K2's next round, listed not fixed: the carried puck lies off the blade (the shown carrier);
      bodies overlap at contact (contact clips); blank number patches (K7). The boards view's close eye (round 6, kept as
      thirdjam's: a "surpass" item) now also puts the chevron and panel over the helmet (r7_ours_every4s, 32 s).
   f. What reads right: the MATCH card, the score plates, the faceoff dial with HOLD, the rings (yours, the carrier's,
      doubled while you carry), the far-net and own-net distance markers, the radar, the YOU tag at the faceoff over the
      figure's head, as thirdjam's.
4. EXPORT AND COST.
   - export.sh build --no-warm PASS (tag 1389d47), export.sh check --no-window PASS: hokej 6e9c32c23eaf3d45 in the editor
     binary and the exe (600 frames); the world 0 script errors, 0 engine errors.
   - Window cost, HUD + figures against HUD + capsules (1280x720, D3D12, uncapped, 5,400 frames, Godot's per-second fps):
     163 fps median = 6.13 ms a frame (slowest second 7.14 ms) against 270 fps = 3.70 ms. Round 6 without the HUD: 3.57
     against 1.30 ms. So the HUD costs about 2.5 ms a frame and the figures about 2.4 ms; together inside the 16.7 ms frame.
     (Both windowed runs ended in a segfault at quit: the known quit crash, with K1.)
   - Headless the HUD draws nothing (K5's screen.gd), so the headless pack tick is round 6's (p50 2.16 ms).

GATES
hokej: lint PASS; bots match_hand (3:1, ab881a00fb9af8ef), rule_restart, tj_replay (0.54 cm), gym_hand PASS; invariants PASS
(solo_budget). selftest budget.class PASS (12 checks). tl check --tier fast: arch 12/12, assets 4/4, cards 3/3, devx.test
229/229 PASS; foreman NOT RUN (no node_modules in this worktree). Full tier not run (your instruction). The other rule bots
were not re-run: nothing they read changed (the head height only moves the HUD, which draws nothing headless).

CHANGED FILES
engine/kernel/host/invariants.gd (budget class, solo_budget), engine/kernel/host/budget_class_test.gd (+.uid, new),
engine/tools/selftest.d/845-budget-class.sh (new); engine/packs/hokej/scripts/match_view.gd (head_world),
engine/packs/hokej/scripts/main.gd (head_m to K5's layer before frame_of);
docs/shifts/2026-11-24-night/lanes/K3-shell: REPORT.txt, ROUND-7.md, STANDUP.md, r7_* images and film. No git writes.

QUESTIONS FOR THE DIRECTOR
1. K5 to take the head as a point (XY too), or is the height enough until the figure leans and falls (K2's falls)?
2. K2 to check head_socket against thirdjam's mesh socket (the chevron on the helmet, 3a)?

IMAGES TO LOOK AT (docs/shifts/2026-11-24-night/lanes/K3-shell/)
r7_sbs_film_20s.mp4, r7_sbs_sheet_a.jpg, r7_sbs_sheet_b.jpg, r7_ours_every4s.jpg, r7_chevron_on_head.jpg
