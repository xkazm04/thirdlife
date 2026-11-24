K6 arena and sound, round 2 (the sound): REPORT (23 Nov 22:28 to 23:00, 24 Nov 20:50 to 21:55)
Worktree C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-arena, branch hk-arena, at be548e5 (older than hokej).
Nothing committed (the Director lands). LANDABLE ROUND 2.

NO EAR HAS HEARD ANY OF THIS. The proofs are files, tables, frames and levels. Two 30-second clips are in the lane
folder for the owner's ear.

OUTCOME
thirdjam's sound plays in our game: every event of the core's snapshot that sounds in thirdjam sounds here on its
frame, with the sound Unreal's own audio engine renders for that event at its Variant and Strength; the music with
its two levels, the crowd bed and the skate loop driven by the human's speed run under it. The kernel gained sound
from files (TLSound). Over 90 seconds our output's level sits on thirdjam's own recording: median second -28.2 dB
against -28.5 dB. Not in: the commentator, the barks' blip (the core does not emit bark events), the goal lamp, the
net shake and the rocking caps (round 3).

LOOK AT / LISTEN TO (docs/shifts/2026-11-24-night/lanes/K6-arena/)
  r2_sound_tj_30s.mp4      thirdjam's own match, first 30 s of its sound (commentator muted)
  r2_sound_ours_30s.mp4    ours, first 30 s (another hand, so another play)
  r2_loudness.jpg          loudness per second, thirdjam's recording against ours, 90 s (I looked at this chart)
  SOUNDS.md                1: every thirdjam event sound, what it is made of, its law per Variant; 2: a recorded
                           match's event / frame / clip table
  ROUND-2.md               what stands, the proofs, what is missing, deviations
To hear it: node devx/bin/tl.mjs play hokej (after one `--import` of the tree: the .ogg files' import data is not in git).

ACCEPTANCE (round 2's share)
1. Every game event that makes a sound in thirdjam makes the same sound here at the same frame, tested headless from
   recorded snapshots: MET for what the core emits, with the limits named below.
   - selftest core.rink.audio.match: a whole match of the bare core (seed 1, pro, idle hand, 7,163 frames, 2:3):
     235 sounding events, 235 rows, each at its event's frame with the Variant an independent copy of thirdjam's
     table gives, every named file there; two runs give the same rows. Shown red once.
   - selftest core.rink.audio.tj: thirdjam's own log of a played match (546 events): 542 sound, 4 silent by
     thirdjam's rule (period, carry), none unknown; both goals get the Variant thirdjam's binder logged.
   - In the recording: the faceoff drops at frame 90 (1.500 s); our level jumps at 1.504 s.
   - "The same sound": the file is Unreal's render of that event's MetaSound, at the nearest of five Strengths and
     one of at most three takes. Limits: bark events are not in the core's snapshot (thirdjam: 14 in 90 s); the
     commentator is not in.
2. The sources exported, sizes said: MET. 579 assets: 519 waves (62 MB as wav, kept out of git under .tl), 53
   MetaSound documents as text. In git: engine/cores/rink/audio 6.9 MB (limit 60): 316 event files 5.4 MB, music
   0.65, crowd bed 0.16, skate 0.1. The commentator's 415 lines are 38 MB as wav and not in yet.
3. The event-to-sound table and the MetaSound rules: MET (SOUNDS.md; rink_audio.gd cites each rule's thirdjam line).
   Found: 28 of 53 sounds are synthesised in their graphs, and no MetaSound has attenuation: thirdjam's sounds are
   not placed in the hall.
4. Crowd bed and its reactions, the skate loop by speed, music levels: MET. The reactions (goal cheers and groan,
   knockdown ooh and roar, save ooh, win cheer) are inside the rendered event sounds.
5. The kernel audio additions: MET (TLSound; API.md section 28 appended, not numbered).
6. A minute beside a minute, by the numbers: MET (90 s each). Median second -28.5 / -28.2 dB (thirdjam / ours),
   loudest tenth -22.3 / -21.5, quietest tenth -30.6 / -30.9, whole -27.1 / -26.5, peak -3.2 / -4.7, three bands
   within 1.1 dB, the first 1.2 s (music and bed alone) -29.6 / -29.7.
Not in this round: the commentator's voice, the goal lamp, the net shake, the rocking caps, the crowd's cheering pose.

GATES (final tree, 24 Nov 21:25 to 21:55; the machine at 100 % CPU throughout)
  tl.sh lint --pack=engine/packs/hokej      PASS
  tl.sh smoke                               PASS (3600 frames, state hash ad03a2add6ce42c1)
  tl.sh bot, the pack's ten tests           10 of 10 PASS (bot_match_hand 9072 frames 4685cd21e60096f0, bot_gym_hand,
                                            bot_rule_w_away, _s_lock, _aim, _aim_anchor, _restart, _signals,
                                            bot_hud_rules, bot_tj_replay)
  tl.sh invariants                          3 runs: FAIL, FAIL, PASS, all on invariants.frame_budget alone
                                            (p99 4.306, then with the sound part switched off 4.127, then with it on
                                            3.978 ms against a 4 ms budget; p50 3.2 to 3.4 ms). The pack's frame sits at
                                            the budget on this loaded machine with or without the sound; the sound
                                            part itself costs 0.016 ms a frame at the median, 0.107 at p99. The state
                                            hash is the same with and without it (ad03a2add6ce42c1). A first smoke
                                            failed because I let the gate start while the bake was rewriting
                                            audio.json (one "does not read" error); rerun twice green.
  selftest blocks 840 + 841                 10 of 10 PASS (core.rink.arena.* 5, core.rink.audio.table, .kernel,
                                            .match, .tj, .loops). Shown red: TL_AUDIO_EXPECT_SILENT=period,carry,goal
                                            -> FAIL core.rink.audio.match "row 100 is goal at 3127, the event is post
                                            at 3144".
  style pin blocks (filter surf.)           14 of 14 PASS
  tl check --tier fast                      FAIL, exit 1: arch [12/12] red on api-v1 (additions: class TLSound,
                                            TLStyleArena.post_file and POST_FILE, the PARTS entry) and api-index-fresh;
                                            devx.test 226 of 229, the same causes; assets 4/4 and cards 3/3 PASS;
                                            foreman.typecheck NOT RUN (no node_modules in this tree). They go green
                                            with the Director's version number and index, as in round 1.
  The picture after the grade and ink moved into a file: frame 300 of the pack looked at; identical pixel for pixel
  to the capture before the last signature fix.

FOR THE MERGE (my tree is at be548e5; lines by their text)
1. engine/packs/hokej/scripts/main.gd, three call sites:
   a. after `var arena ...`:      var sound                # thirdjam's sound, the core's own part (ctx.cores.part; lane K6)
   b. in _pack_setup, straight after `rink.reset(ctx.seed)` / `snap = rink.snapshot()`:
        var sound_part = ctx.cores.part("rink", "audio")
        if sound_part != null:
            sound = sound_part.new()
            sound.begin(cart)
   c. in _pack_tick, straight after the `snap = rink.snapshot()` that follows the step, before `if _draw_figures():`:
        if sound != null:
            sound.frame(snap)
      (before the hit-stop's early return on purpose: a held picture still sounds, as thirdjam's bus does)
2. engine/packs/hokej/pack.json: "audio" added to capabilities.
3. Kernel, to be numbered by the Director (no version line, nothing under docs/generated touched):
   - engine/kernel/api/tl_audio_sound.gd, NEW: class TLSound (play, loop, set_loop, stop_loop, say, saying,
     channel_db, count; constants CHANNELS, PLAY_KEYS, LOOP_KEYS, SET_KEYS, SAY_KEYS, SILENT_DB, NODE_NAME,
     BUS_PREFIX) with the inner class TLSoundNode. It reads TLAudio.events / _loose_events / MAX_EVENTS.
   - engine/kernel/api/tl_cores.gd: ONE line, the PARTS row of "rink" gains
     "audio": "res://cores/rink/audio/rink_audio.gd". (hokej's file has moved round it: 1.29 variant lines.)
   - engine/kernel/API.md: a section appended at the end, "## 28. Sound from files: `TLSound` (capability `audio`,
     addition in 1.27)": the heading's section number and the 1.27 are mine to be corrected by you.
   - engine/style/tl_style_arena.gd: NEW `const POST_FILE`, `static func post_file() -> Dictionary`; `post(anchor,
     opt)` keeps its signature and now applies style/hall_post.json with `opt` on top.
4. engine/cores/rink/arena/rink_arena.gd, my hunks (K7's are elsewhere in the file: I did not touch build's rig
   lines, _texture or rig_lights):
   - the constants VIGNETTE_K and HALL_INK removed (after `const ICE_LIFT`);
   - in light(): `TLStyleArena.post(anchor, hall_post())` -> `TLStyleArena.post(anchor, {})`. K7 has put a
     "K7 begin / K7 end" block in light() on hokej: mine is the one post line, keep K7's block as it is;
   - the function hall_post() removed (between roof_light and set_cheer).
   engine/cores/rink/arena/review/arena_case.gd: in _light, `Arena.hall_post()` -> `TLStyleArena.post_file()`.
   engine/tools/arena/shots.gd: its post call takes `{}`.
5. New files: engine/style/hall_post.json; engine/cores/rink/audio/** (rink_audio.gd, audio.json, sfx/ 316 ogg,
   music/, crowd/, skate/, review/audio_case.gd, review/tj_events_regular_pro.json); engine/tools/selftest.d/
   841-rink-audio.sh; engine/tools/arena/: export_audio.py, audio_digest.py, audio_jobs.py, render_audio.py,
   render_match.py, audio_bake.py, audio_table.py, tj_events.py, loudness.py, wav_stats.py, record_ours.sh.
   engine/style/STYLE.md: the `post` bullet of my hall section reworded.
6. Not checked against hokej's head: K7's hall_ice.gdshader and rig_lights edits with my tree; the sound with the
   variant core (1.29); K5's pause card (the loops keep playing while the pack is paused: TLSound's node counts
   physics frames, the players are not paused).

BEHAVIOUR CHANGES
- `tl play hokej` has sound: music from the first frame, the crowd bed, the skate loop, every event's sound.
- The pack declares `audio`. Headless runs play nothing and record every call in TLAudio.events.
- No state changed (same state hash with and without the sound part); no test expectation moved.
- The hall's grade and ink values are the same numbers, now read from engine/style/hall_post.json.

DEVIATIONS (new; reasons in ROUND-2.md)
1. Event sounds are Unreal's renders at 5 Strengths x the Variants x up to 3 takes, not the graphs run live.
2. Two measured output factors on the held sounds (stereo 0.7071, mono 0.5).
3. Ogg Vorbis from Unreal's 16-bit 48 kHz output. 4. The crowd bed's low-pass baked at its resting cutoff.
5. The skate loop's noise layer is our noise through thirdjam's filters; level ramps are straight lines.
6. thirdjam's comparison recording has its voice class muted; HEAD's content on the 15 Nov binaries.
7. Sounds are not placed, as in thirdjam. 8. Round 1's deviations stand (TONE_GAIN 6.0 and the rest).

QUESTIONS FOR THE DIRECTOR
1. Barks: thirdjam's bark events come from its game mode, not its sim. Should lane K1 put them in the snapshot's
   events (then MS_bark plays with no further work), or does the HUD lane own the bark source?
2. Pause: should the loops fall silent under K5's pause card (thirdjam: what does its pause do to the music?), and
   who calls it: the pack (`sound.end()` / `begin`) or a kernel rule that pauses a pack's TLSound node with its tick?
3. The .ogg files' import data (`*.import`) is ignored by git like every other import: a fresh checkout plays no
   sound until `--import` has run once. Is that step part of `tl play`, or should the core's sounds be loaded
   without the importer?
4. Five Strength steps and three takes: enough for parity, or do you want the graphs run live (a synth in the
   engine: weeks, not hours)?

NEXT THREE (round 3)
1. The commentator: 415 lines as ogg (about 5 MB), commentary.json's triggers and the booth's rules through
   TLSound.say with the duck; a recorded match's line / frame table beside thirdjam's own JAMVO log.
2. The reactions: the crowd's cheering pose on a goal (the shader waits for it), the goal lamp (108 frames), the
   net shake (54), the rocking caps, each from the snapshot's events with its frame table.
3. The carried look items from round 1 once my tree is on hokej's head (the fans' far level, the darks).
