K3 SHELL, ROUND 9 REPORT (campaign night 23-24 Nov 2026; worktree .claude/worktrees/hk-shell, uncommitted, on hokej be548e5)

OUTCOME
K2's contact is wired as verb_gym.gd wires it, the rink draws only the marks thirdjam's hall ice does not paint (in
thirdjam's colours), and the whole picture (match, felt figures, contact, HUD, the hall and its light) is filmed beside
thirdjam's film. The match hash (the core's) did not move: ab881a00fb9af8ef. The run's state hash did move, for one proven
reason (the pack's kit ice, a physics body, is no longer built inside the hall; see 2). The solo class has its own p99
budget. Export check headless PASS. Nothing outside the pack was fixed (the budget line was yours to ask for).

1. CONTACT, AS VERB_GYM.GD DOES IT (scripts/match_view.gd, main.gd).
   - hits = ctx.cores.view_script("rink", "hit_read").new(); hits.skater_speed = game.skater.speed; each frame
     hits.step_sim(snap, pawns, core.last_human_input()) right after show.after_pawns (HokejGameMode.cpp:1706).
   - All four bus events (knockdown, check, lift, deke) to every figure (DeliverEvents, before the show).
   - fig.set_rink(half length, half width, corner radius in cm) once at spawn; set_rivals as before.
   - The order after the pawns is verb_gym's: every pawn's apply_render, show.render (the puck's place), then each
     figure's set_puck from where its pawn stands drawn and tick, then a carried puck takes its socket's place again
     after the tick (AJamPuck::Tick, JamPawns.cpp:959-977). Round 8 had the look one frame late; this is K2's order.
   - bot_match_hand: 3:1 in 9,071 frames, core hash ab881a00fb9af8ef (unchanged); restart, gym, tj_replay (0.54 cm),
     aim PASS.
2. THE ICE MARKINGS (gen/tj_rink.gd, main.gd).
   - With the arena (ctx.cores.part("rink", "arena") present): tj_rink no longer builds the kit ice, the boards and the
     kick plate (the arena's rink surfaces draw them) nor RinkActor's markings sections 0 and 1 (centre line, goal lines,
     blue lines, 9 m centre circle: hall_ice.gdshader paints them). It draws only sections 2 and 3, "the marks B's
     painted ice does not carry" (RinkActor.cpp:614-659): the faceoff circles with their hash marks, the eight dots, the
     crease outlines and the trapezoids in section 2's red, the crease fills and the centre dot in section 3's pale blue,
     each thirdjam's colour read from arena.json (rink_surfaces.Markings materials [2] and [3]: MID_BasicShapeMaterial_0
     (0.6, 0.02, 0.02) and _2 (0.35, 0.55, 0.85), linear) on the palette's white. The goals stay ours (the arena leaves
     them to the pack). Without the arena: today's drawing, unchanged.
   - THE RUN'S STATE HASH: idle ad03a2add6ce42c1 -> d0134cd230d9a332; bot d4188b88cacbecf9 (was 4685cd21e60096f0); the
     dungeon's 600 frames bf0f453fe32b7bb2 (was 6e9c32c23eaf3d45). Cause, proven: the kit's `rink` part carries a static
     body, and the runner's hash covers physics bodies (bodies 1 -> 0). With the kit ice built again inside the hall
     (a one-line toggle, run and reverted) the idle hash is ad03a2add6ce42c1 again. The core's hash is the same in every
     run. Say if you want the hash kept instead: then the kit ice stays under the arena's (hidden, 2 mm lower).
3. THE WHOLE PICTURE, LOOKED AT (r9_sbs_film_20s.mp4, r9_sbs_sheet_a.jpg, r9_sbs_sheet_b.jpg, r9_ours_every4s.jpg,
   r9_still_faceoff.jpg, r9_still_knockdown.jpg, r9_knockdown_strip.jpg). With the hall it reads as thirdjam's game:
   the opening faceoff (r9_still_faceoff) is close to a copy. What the owner's eye will see, most visible first:
   a. SHADOWS. thirdjam's figures cast dark, sharp shadows long across the ice (a knocked man's shadow is as big as he
      is: r9_still_knockdown); ours cast faint grey ones close to the feet. The first difference anyone sees in motion.
      (K7 said the figures are lit by the style's sun until the arena: the arena is here now; the figures' shadow under
      the hall's rig is K6's / K7's, not changed by me.)
   b. THE CONTROLS PANEL. Ours is a six-row block bottom left for the whole match; thirdjam's film shows one line of keys
      at the faceoff and a two-word strip after (its h45 stills do show the block: thirdjam has both; K5 to say which
      the regular cut shows when).
   c. THE KNOCKDOWN. Ours falls and lies on the ice and gets up (r9_knockdown_strip: the check at frame 692, the man
      flat by 704); thirdjam's victim is thrown through the air first (its h45 still "hit, man in the air"). Not the same
      moment, so not a fair pair; worth K2's look at a matched hit.
   d. THE PUCK. At the faceoff thirdjam's puck on the dot glows under the human; ours is a small flat black disc (2.5
      cm, thirdjam's 8 cm) with no glow, and reads small everywhere.
   e. THE ICE. Ours a shade brighter and flatter than thirdjam's lilac grey, with less fall-off to the far end; the
      painted lines match (the centre line's wide salmon band, the blue lines, the circle).
   f. BODIES AT CONTACT still overlap in the scrums by the boards (r9_knockdown_strip row 1), less than in round 8.
   g. THE CLOSE BOARDS VIEW (32 s) stands as thirdjam's (your decision).
   h. Same as thirdjam: the crowd and the hall's wood, the lamps, the score plates, MATCH card, dial, rings, markers,
      radar, the commentary lines, numbers on the backs.
4. EXPORT AND COST.
   - export.sh build --no-warm PASS (tag be548e5); export.sh check --no-window PASS: hokej bf0f453fe32b7bb2 in the editor
     binary and the exe (600 frames); the world 0 script errors, 0 engine errors (editor, exe, exe copied elsewhere).
   - Window cost, the whole picture (1280x720, D3D12, uncapped, 5,400 frames, Godot's per-second fps; another session's
     Unreal Editor was running): 170 fps median = 5.88 ms a frame (slowest second 6.76 ms); with figures false (capsules,
     same hall and HUD) 311 fps = 3.21 ms. Round 7 (no hall): 6.13 and 3.70 ms.
   - Headless (invariants): solo p50 3.19 ms, p99 3.89 ms.
5. THE SOLO P99 (engine/kernel/host/invariants.gd, your decision): a solo pack's p99 is judged against
   BUDGET_SOLO_FRAME_MS_P99 = 8 ms under its own check id `invariants.solo_frame_budget`; every other pack keeps the
   stage's 4 ms under `invariants.frame_budget`. Test: one line in budget_class_test.gd (the two constants) and a grep in
   selftest 845 (`budget.class` 13 checks PASS). hokej invariants PASS: solo_frame_budget p99 3.887 ms of 8, solo_budget
   p50 3.194 ms of 8, determinism, the bot twice. host.gd still takes its extra idle runs while p99 > 4 ms (it may not
   grow; harmless: more runs, a steadier figure). RUNNER.md / PERF.md wording: yours.

GATES
hokej: lint PASS; bots match_hand, rule_restart, gym_hand, tj_replay, rule_aim PASS; invariants PASS (above). selftest
budget.class PASS. tl check --tier fast: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229 PASS (a first run under load
failed devx's wall-clock "real tree under 5 s" at 5.2 s; re-run quiet: PASS); foreman NOT RUN (no node_modules). Full tier
not run (your instruction).

CHANGED FILES
engine/packs/hokej: scripts/match_view.gd (the hit read, set_rink, verb_gym's render order, the late carried puck),
  scripts/main.gd (hit_read, the human input to the view, the arena's marking colours to the rink), gen/tj_rink.gd (inside
  the hall: no ice, boards or kick plate; sections 2 and 3 only, thirdjam's colours), README.md.
engine/kernel/host/invariants.gd (solo p99), engine/kernel/host/budget_class_test.gd, engine/tools/selftest.d/845-budget-class.sh.
docs/shifts/2026-11-24-night/lanes/K3-shell: REPORT.txt, ROUND-9.md, STANDUP.md, r9_* images and film. No git writes.

QUESTIONS FOR THE DIRECTOR
1. The run's state hash moved with the kit ice's body (2): accept the new hashes, or keep the hidden kit ice?
2. Shadows (3a) are the most visible difference: whose lane (K6's rig on the figures, or K7's felt)?

IMAGES TO LOOK AT (docs/shifts/2026-11-24-night/lanes/K3-shell/)
r9_still_faceoff.jpg, r9_still_knockdown.jpg, r9_sbs_film_20s.mp4, r9_sbs_sheet_a.jpg, r9_sbs_sheet_b.jpg,
r9_ours_every4s.jpg, r9_knockdown_strip.jpg
