# K6 arena and sound, round 2: thirdjam's sound plays in our engine (23 Nov 22:28 to 23:00, 24 Nov 20:50 to 21:55)

**No ear has heard any of this.** Everything below is files, tables, frames and levels. Two clips are in this folder for
the owner's ear: `r2_sound_tj_30s.mp4` (thirdjam's own match, its first 30 s, commentator muted) and
`r2_sound_ours_30s.mp4` (ours, its first 30 s; another hand, so another play).

## What stands

- **The export.** `engine/tools/arena/export_audio.py` (one commandlet run): all 579 audio assets of thirdjam: 519 waves
  as wav (81 effects 50.8 s, 22 crowd clips 78.1 s, the music loop 28.8 s, 415 commentator lines 796.7 s; 62 MB of
  wav, not in git), the 53 MetaSound sources' documents as Unreal's own struct text, 5 sound classes (every one at
  volume 1.0, no parent) and 2 mixes. `audio_digest.py` reads a document into a graph: inputs with their defaults,
  nodes with their literals, what feeds each pin.
- **What the graphs say.** 28 of the 53 event sounds are synthesised in their graph (oscillators, noise, envelopes,
  filters), most mix that with waves, and most change with the two floats the game sends (Strength, Variant): gates at
  a Strength, random draws from a list, delays up to 2.15 s. A sound of thirdjam is therefore not a file: it is what
  Unreal's audio engine renders from the graph. **No MetaSound carries attenuation settings**: thirdjam's sounds are not
  placed in the hall; every one is heard the same wherever the camera is.
- **The event sounds, rendered by Unreal itself.** `render_audio.py` plays each of the 47 one-shot MetaSounds as
  `UJamEffectsBinder::HandleEvent` does (spawn, then Strength and Variant) at every Variant its event can carry and at
  five Strengths (0, 0.25, 0.5, 0.75, 1), three takes where the graph draws at random, and records Unreal's output
  with its non-realtime renderer (nothing went to the sound card): 436 renders. `audio_bake.py` cuts each to its sound
  and keeps a file only where the step is not the top step times a constant: 316 files, 102 steps that are a gain on
  another file, 18 silent steps. `SOUNDS.md` section 1 lists every event: what it is made of, its law per Variant.
- **The held sounds, ported as rules** (`engine/cores/rink/audio/rink_audio.gd`, each with its thirdjam line): the
  music (Level 0.6 from the start, 0.35 while the puck is in play, reached over 0.5 s), the crowd bed (started with
  the music and never touched: thirdjam sets neither its Level nor its Excite; its low-pass at 3000 Hz is baked into
  the file with Unreal's own biquad), the skate loop on the human's skater (stride loop at 1.4 x Speed, pitched
  4 x Speed - 2 semitones; a band of pink noise at 0.75 x Speed whose centre runs 1200 to 3700 Hz; a carve on a turn
  over 3 rad/s, at most once in 15 frames). The crowd's reactions are inside the event sounds (the goal's cheers or
  groan, the knockdown's ooh or roar by Strength, the save's ooh, the win's cheer): they came with the renders.
- **The kernel's sound from files**: `TLSound` (`engine/kernel/api/tl_audio_sound.gd`, API.md section 28): a core's
  files, one-shots (also at a position), loops with volume and pitch reached over frames, a voice line that ducks the
  music, five channels. Frames, not the wall clock. Every call is recorded headless.
- **Wired**: `ctx.cores.part("rink", "audio")`, three lines in the pack's `main.gd`, the capability `audio` in
  `pack.json`. The sound part reads the core's snapshot once a simulated frame.
- **The hall's grade and ink** have their own style file, `engine/style/hall_post.json` (the Director's answer 4);
  `TLStyleArena.post(anchor, {})` reads it. The picture is the round-1 picture (looked at: frame 300 of the pack).

## The proofs

- **Event, frame, clip** (`SOUNDS.md` section 2; selftest `core.rink.audio.match`): a whole match of the bare core
  (seed 1, pro, an idle hand, 7,163 frames, 2:3): 235 events that sound in thirdjam, 235 rows, each at its event's
  frame with the Variant an independent copy of thirdjam's table gives; two runs give the same rows. Shown red once
  (told that `goal` is silent: "row 100 is goal at 3127, the event is post at 3144").
- **thirdjam's own event log through our rules** (`core.rink.audio.tj`): the 546 events thirdjam broadcast in its own
  played match: 542 sound, 4 are silent by thirdjam's rule, none is unknown; both goals get the Variant thirdjam's own
  binder logged.
- **On the frame, in the recording**: the opening faceoff drops at frame 90 (1.500 s): our recording's level jumps at
  1.504 s; thirdjam's at 1.542 s (its recording starts a few ticks before its frame 0).
- **Loudness against thirdjam's own recording** (`r2_loudness.jpg`; `loudness.py`): 90 s of thirdjam's match recorded
  from its own output (its measured hand, commentator's class muted because ours has no voice yet) against 90 s of
  ours (the pack through the movie writer, its scripted hand):

  | | thirdjam | ours |
  |---|---|---|
  | median second (the bed: music, crowd, skates) | -28.5 dB | -28.2 dB |
  | loudest tenth of the seconds (events) | -22.3 dB | -21.5 dB |
  | quietest tenth | -30.6 dB | -30.9 dB |
  | whole 90 s | -27.1 dB | -26.5 dB |
  | peak | -3.2 dB | -4.7 dB |
  | under 300 Hz / 300 Hz to 3 kHz / over 3 kHz | -31.8 / -30.0 / -41.0 | -31.9 / -29.2 / -39.9 |
  | the first 1.2 s (music and crowd bed alone) | -29.6 dB | -29.7 dB |

  The two matches are different plays (two hands): the levels are compared, not the moments.
- **What Unreal's output does to a 2D sound, measured**: a stereo source comes out at 0.71 of its wave (the music
  0.706, the crowd bed 0.721 with 5.8 % residual against our low-passed file), a mono one at about 0.5 (the skate loop
  0.52 and 0.51 of this port's model). The held sounds carry these two factors (`audio.json` "out_gain"); before them
  our bed was 4.5 dB too loud. The event files are Unreal's output already.

## Size and cost

- `engine/cores/rink/audio/`: 6.9 MB (limit 60): 316 event files 5.4 MB, music 0.65, crowd bed 0.16, skate 0.1,
  the table 0.09. The commentator's 415 lines (38 MB as wav) are not in yet.
- The sound part costs 16 microseconds a frame at the median, 107 at the 99th percentile (headless, the machine at
  100 % CPU).

## What is missing or differs (no ear: these are from the tables and the levels)

1. **The barks have no sound**: thirdjam broadcasts `bark` from its game mode (14 in the 90 s recorded), the core's
   snapshot does not carry them. `MS_bark` is baked and would play the moment the event arrives.
2. **No commentator** (round 3), and with him the music's duck.
3. **Strength has five steps.** Between two steps a sound that only scales follows a straight line; a sound that
   changes takes the step below.
4. **A random draw has three fixed takes** (thirdjam draws anew each time, and its noise is new each time); the take is
   chosen from the frame and the event, not by thirdjam's no-repeat rule.
5. **The skate loop's noise layer** is our own noise through thirdjam's filters; its level against Unreal's is inside
   the 0.52 measured for the whole loop, not measured alone.
6. The skate loop's and the music's level changes are straight ramps where the MetaSound interpolates on its own
   curve; the bed's Excite input is not ported (thirdjam never sets it).
7. `period_end`, `clock`, `win`, the ability, pickup, zone and cannon sounds are baked and in the table; the regular
   cut never raises most of them, so no match here has sounded them.

## Deviations (new this round; round 1's stand)

1. Event sounds are renders at 5 Strengths x the Variants x up to 3 takes, not the graphs run live.
2. `out_gain` 0.7071 / 0.5: measured factors on the held sounds.
3. Ogg Vorbis (quality 5, music 6) from Unreal's 16-bit 48 kHz output.
4. The crowd bed's low-pass is baked at its resting cutoff.
5. thirdjam's comparison recording has its voice class muted, and was made on HEAD's content over the 15 Nov binaries.
6. Sounds are not placed (as in thirdjam): `TLSound.play`'s position is there and unused by this part.
7. The pack declares the capability `audio`.

## Next (round 3)

1. The commentator: the 415 lines as ogg, `commentary.json`'s triggers, the booth's rules, the duck (the text is K5's).
2. The reactions: the crowd's cheer on a goal (the shader is waiting for it), the goal lamp, the net shake, the caps.
3. Barks, if lane K1 or K5 can hand the bark events to the sound part.
