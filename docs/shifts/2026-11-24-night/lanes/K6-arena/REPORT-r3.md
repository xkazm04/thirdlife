K6 arena and sound, round 3 (the voice, the barks, the hall answering the game): REPORT (24 Nov 22:20 to 23:45)
Worktree C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-arena, branch hk-arena, at hokej b1ea774.
Nothing committed (the Director lands). LANDABLE ROUND 3.

NO EAR HAS HEARD THE VOICE. Its proofs are files, frames and levels; the reactions were LOOKED at in stills.

OUTCOME
thirdjam's commentator speaks in our match: the line lane K5's caption picker starts is said on the same frame from
that line's own file (one picker: the HUD hands its record to the core's sound part), at the level thirdjam's own
output gives it (measured: 0.345 of the wave), the music ducked to 0.45 under it, a cut line fading in 9 frames.
Every bark said plays MS_bark. Under K5's pause card every loop and the line stop where they are and go on at resume
(as Unreal's SetGamePaused does; proven through TLSound's own node). The hall answers the game as thirdjam's
ARinkActor does: the goal lamps flash 108 frames, the scored net shakes 54, the board caps rock 26 degrees with their
ripple and the goal's wave, a bench, box or table rocks 3.5 degrees, the scored end's crowd stands (BP_ArenaCrowd's
curve). thirdjam's own played match, fed through our reactions, gives every one of the 45 reactions its log wrote.

LOOK AT / LISTEN TO (docs/shifts/2026-11-24-night/lanes/K6-arena/)
  r3_goal_full_sbs.jpg   thirdjam's game stills at goal +1 and +17 (left) beside ours from its logged camera (right)
  r3_goal_sbs.jpg        the same, cropped on the net and its lamp: goal frame, +2, +18, back at rest +114
  r3_end_ours.jpg        ours close: the lamp's pulse and fade, the end's crowd up and sinking (rest, 0, 3, 9, 27, 100)
  r3_cap_ours.jpg        ours close: a hard hit's cap (rest, 0, 2, 4, 6, 10 frames): hop and tip, the neighbour's delay
  r3_sound_tj_30s.mp4    thirdjam's own match with its commentator ON, the first 30 s
  r3_sound_ours_30s.mp4  ours with the commentator, the first 30 s (another hand, another play)
  r3_loudness.jpg        loudness per second, 90 s each, both with the commentator
  BOOTH-REACT.md         1: a recorded match's frame / line / caption text / clip, the barks and the cuts;
                         2: thirdjam's 45 logged reactions beside ours, row by row
  ROUND-3.md             what stands, the proofs, what my eye rejects, deviations
To hear it: node devx/bin/tl.mjs play hokej (after one `--import`: the .ogg import data is not in git).

ACCEPTANCE (round 3's share of the brief)
1. The commentator's lines with their triggers, the voice saying the caption's line: MET.
   - 415 lines as ogg (6.1 MB), every id of K5's bank has its file (core.rink.booth.voices).
   - core.rink.booth.match: a whole bare-core match through the pack's own hud.gd (seed 1, pro, idle hand, 7,163 frames):
     30 lines started by the caption picker, 30 said, each on its frame from its own file; 17 barks, 17 MS_bark; 4 cuts
     exactly where a bark at the human came 30+ frames into a line; two runs agree; shown red once (barks withheld).
   - In a recording of the pack (movie writer, 90 s): the opening line found at frame 0 by cross-correlation.
   - Rates beside thirdjam's own played match: 15.1 lines and 8.5 barks a minute here, 14.0 and 9.0 there.
2. The goal lamp (108), the net shake (54), the rocking caps (26 degrees): MET, and the crowd's cheer, the rattle.
   - core.rink.react.tj: thirdjam's own log (13,620 frames, 57 goal/board events) through our reactions: 45 of 45
     reactions, the same cap 39 of 39 times, tilt and hop within the log's print precision (worst 0.054 deg, 0.050 cm),
     the same piece and roll 4 times, the same end twice; shown red once (24 degrees).
   - core.rink.react.caps: Build's stanchion walk = the baked caps (0.00000 m, 0.0004 degrees).
   - core.rink.react.curves / .goal: thirdjam's RinkReactionTests expectations; BP_ArenaCrowd's measured curve.
   - Looked at: thirdjam's stills of the same deterministic match beside ours (lamp, crowd); close-ups of ours (net,
     caps). What my eye rejects: ROUND-3.md (the wave's red light on the caps is missing; no NS_goal, not this lane's).
3. Barks: MET (MS_bark per bark said by K5's lane; BarkSystem.cpp:538-548 -> EffectsBinder).
4. Loudness against thirdjam's own recording with the commentator on: see LOUDNESS below.
5. Pause: MET (core.rink.booth.pause; shown red once with the node unpausable).
6. Frame cost: the reactions 2.9 microseconds a frame headless (13,620 frames of thirdjam's match); writes only while
   a reaction is live. Audio total 12.1 MB of 60.

LOUDNESS (90 s each, both with the commentator; two different plays, the levels compared, not the moments)
                                     thirdjam   ours
  median second                       -27.6    -27.1 dB   (round 2 without the voice: -28.5 / -28.2)
  loudest tenth / quietest tenth      -22.1 / -30.7   -21.4 / -31.1
  whole 90 s / peak                   -26.4 / -3.3    -25.9 / -3.8
  under 300 Hz / 300 Hz-3 kHz / over  -32.8 / -28.4 / -40.7   -32.7 / -27.8 / -39.5
  The voice's level in thirdjam's own output, line by line (vo_gain.py, 17 lines): 0.338 to 0.356 of the wave, median
  0.345 (-9.24 dB): the port takes 0.345 (I had first taken round 2's mono 0.5; corrected before landing). Ours: the
  opening line found at frame 0, gain 0.345. The lines sit +0.22 to +0.28 s after their logged frames in thirdjam's
  recording, and so does the faceoff drop's own sound at the same moments: thirdjam's hit-stops, not a voice latency.

GATES (final tree, 24 Nov 23:00 to 23:40)
  selftest core.rink. (840, 841, 842, 843)  18 of 18 PASS (842 and 843 new: booth voices, match, duck, pause; react
                                            curves, caps, goal, tj). Shown red: TL_BOOTH_SKIP_BARKS=1 -> match FAIL "the
                                            bark at 90 has no MS_bark"; TL_BOOTH_PAUSE_ALWAYS=1 -> pause FAIL "a player on
                                            TL_music is not paused"; TL_REACT_CAP_DEG=24 -> tj FAIL "frame 1163: cap 41
                                            tilt 24.0 ...; thirdjam cap 41 tilt 26.0"
  style pin blocks (filter surf.)           14 of 14 PASS; no file under engine/style/shaders changed
  tl.sh lint --pack=engine/packs/hokej      PASS
  tl.sh smoke                               PASS, state hash 3b762bc25ee35dbc..., the same as a copy of the pack with
                                            HEAD's main.gd and tj_rink.gd
  tl.sh invariants                          PASS (determinism 3b762bc25ee35dbc, solo frame p99 4.165 ms / p50 3.488 ms
                                            against 8, bot determinism fd162294891897fc)
  tl.sh bot, the pack's 13 tests            12 of 13 PASS; bot_hud_rules FAIL, 12 of 474,792 checks (lane K5's pass
                                            ring), the SAME failures on the baseline copy without my changes (question 2)
  tl check --tier fast                      FAIL, exit 1: arch [12/12] red on api-v1 (TLSound.stop_voice,
                                            TLStyleArena.set_glow: "set KERNEL_API to 1.30") and api-index-fresh;
                                            devx.test 226 of 229, the same causes; assets 4/4, cards 3/3 PASS;
                                            foreman.typecheck NOT RUN (no node_modules in this tree). They go green with
                                            the Director's number and index, as in rounds 1 and 2. uid-orphans green.

FOR THE MERGE (lines by their text)
1. engine/packs/hokej/scripts/main.gd (lane K3's), call sites:
   a. after `var arena ...`:       var react                # the hall answering the game ... (lane K6 round 3)
   b. in _pack_setup, round `rink_gen.build(...)`: `var marks: Dictionary = _arena_marks()`, `marks["arena_goals"] = true`
      when not empty, `rink_gen.build(..., marks)`, `arena.build(ctx.root, {"rink": rk, "goals": not marks.is_empty()})`,
      `react = arena.reactions(ctx.root, rk)`
   c. in _pack_tick, after `sound.frame(snap)`: `if react != null: react.frame(snap)` (before the hit-stop return)
   d. in _present, after `screen = Screen.frame_of(...)`: `if sound != null and screen != null:
      sound.booth(int(snap["Frame"]), screen.view.shown, int(screen.view.captions.last_end), screen.view.barks.said)`
2. engine/packs/hokej/gen/tj_rink.gd (lane K3's): ONE guard: `if not bool(arena_marks.get("arena_goals", false)):`
   round the two `_goal(...)` calls (question 1).
3. Kernel, to be numbered by the Director (no version line, nothing under docs/generated touched):
   - engine/kernel/api/tl_audio_sound.gd: NEW `static func stop_voice(fade_frames: int = 0) -> void`; TLSoundNode gains
     stop_voice and a line's fade; the duck under a line now ramps in a straight line of GAIN (was dB), as an Unreal
     sound mix fades (only lane K6 calls say).
   - engine/kernel/API.md section 28: the stop_voice row, the say row's duck words, a pause bullet.
   - engine/style/tl_style_arena.gd: NEW `static func set_glow(m: Material, emit: Color) -> void` (STYLE.md: one bullet).
   tl arch api-v1 asks for 1.30 for these two.
4. New files: engine/cores/rink/arena/rink_react.gd (+ .uid), review/react_case.gd, review/tj_react_regular_pro.json;
   engine/cores/rink/audio/voice.json, vo/ (415 ogg), review/booth_case.gd, review/tj_booth_regular_pro.json;
   engine/tools/arena/vo_bake.py, vo_gain.py, tj_react_log.py, react_shots.gd; engine/tools/selftest.d/842-rink-booth.sh,
   843-rink-react.sh. rink_arena.gd: `reactions()` and one doc line. rink_audio.gd: booth(), say(), voice.json.

BEHAVIOUR CHANGES
- `tl play hokej`: the commentator speaks, barks blip, the hall answers goals and hard board hits; thirdjam's own goals
  and nets stand in place of lane K3's (the same shapes from the same arena.py; K3's goal is drawn when there is no hall).
- No state changed: smoke's state hash 3b762bc25ee35dbc... equals the same tree without my changes; no test
  expectation moved.

DEVIATIONS (reasons in ROUND-3.md)
1. The reactions' lights are not ported (lamp lights, hit flash, the goal wave's red lights); the penalty box neither.
2. The voice's level is thirdjam's measured output (0.345), not a rule read from a graph.
3. The duck's fade is Unreal's default mix fade (0.2 s); SCM_DuckMusic's own fade times were not exported.
4. tj_rink.gd has one guarded line (lane K3's file).
5. The voice and the barks sound only where the HUD runs (a window), as the captions show only there.
6. Rounds 1-2's deviations stand.

QUESTIONS FOR THE DIRECTOR
1. tj_rink.gd: I guarded K3's goal with one line so thirdjam's own goals (whose nets can shake) stand in the hall. Keep,
   or should K3 own that switch?
2. bot_hud_rules fails on hokej b1ea774 before my changes too (12 of 474,792 checks: "a pass ring under 2" at frames
   2596-2604 and 4533-4536; the same failures on a copy of the pack with HEAD's main.gd and tj_rink.gd): lane K5's.
3. The reaction lights need the hall's rig to take lights that change per frame (a style addition): next round?

NEXT THREE
1. The reaction lights through the rig's list (the lamp lights, the hit flash, the wave lights); the penalty box.
2. A minute of the owner's own hand with sound (a person's ear is still the only judge of the voice and the mix).
3. Round 1's carried look items (the boards' bump in close views, the ice's white).
