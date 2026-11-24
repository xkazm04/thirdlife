# K6 arena and sound, round 3: the commentator's voice, the barks, the hall answering the game (24 Nov, 22:20 to 23:40)

**No ear has heard the voice.** Everything about sound below is files, frames, levels. The reactions were LOOKED at
(stills of ours from thirdjam's own camera beside thirdjam's game stills of the same moments, and close-ups).

## What stands

- **The voice is the caption's line.** The commentator's 415 lines (thirdjam's three banks; all mono 24 kHz, 796.7 s)
  are in the core as Ogg (`engine/cores/rink/audio/vo/`, 6.1 MB; `voice.json`, baked by `engine/tools/arena/vo_bake.py`
  from round 2's export). Nothing picks a line twice: lane K5's caption picker (its port of FJamCommentaryPicker in the
  pack's HUD) picks; once a drawn frame the pack hands the HUD's record to the core's sound part
  (`sound.booth(frame, screen.view.shown, captions.last_end, barks.said)`, one call site in `main.gd`), which says the
  line the caption started on that frame from that line's own file. thirdjam's rules (CommentarySystem.cpp:827-878,
  SC_VO's passive mix SCM_DuckMusic): through MS_commentary at Volume 1, at 0.345 of its wave (-9.24 dB: what thirdjam's
  own output gives a line, measured below);
  the music ducked to 0.45 (-6.94 dB) while a line plays, 12 frames each way (Unreal's default mix fade 0.2 s,
  SoundMix.cpp:27-28), a straight line in gain; a new line stops the one playing; a line the booth cuts without a new
  one (a bark at the human, 30 frames or more into it) fades out in 9 frames (FadeOut 0.15 s).
- **The barks sound.** thirdjam's UJamBarkSystem::Show broadcasts `bark` (Strength 0) and the binder plays MS_bark
  (BarkSystem.cpp:538-548, EffectsBinder.cpp:146-149): every bark K5's bark lane says plays the baked MS_bark on its
  frame.
- **The pause.** thirdjam's pause card calls SetGamePaused; Unreal then pauses every source whose class is not a UI
  sound and resumes it where it was (AudioDevice.cpp HandlePause; all five thirdjam classes have is_ui_sound false).
  Our dungeon pauses the tree with the pack under a pausable node; Godot pauses every AudioStreamPlayer under it the
  same way. No code was needed; it is proven through TLSound's own node (selftest `core.rink.booth.pause`).
- **The hall answers the game** (`engine/cores/rink/arena/rink_react.gd`, `arena.reactions(ctx.root, rink)`,
  `react.frame(snap)` every simulated frame, before the hit-stop's early return as thirdjam's bus frame is):
  thirdjam's ARinkActor reactions line for line (RinkActor.cpp:1363-1858, constants RinkActor.h:86-179):
  - a goal: the scorer's table's lamp and the lamp behind the scored net flash 108 frames (LampAt; MI_Trim_Lamp's
    Emissive 0.5 -> 9, on our lamp materials through the new `TLStyleArena.set_glow`); the scored net's cords shake
    54 frames (NetShakeAt: depth +-12 %, height -+6 %, about the goal line); the caps behind the scored goal line hop
    in a wave from the posts once a lamp pulse;
  - a skater's hard board hit (Strength 0.45 or more): the nearest of the 73 caps rocks 26 degrees away from the rink
    and hops 22 cm at Strength 1 (CapRockAt), its two neighbours each side answer 2 frames later per place at 0.55 and
    0.25, up to 4 ripples at once; a hit on a long side within 2 m of a bench, box or the scorer's table rocks it
    3.5 degrees (RattleAt);
  - the crowd of the scored end stands: BP_ArenaCrowd's scalar (up over 28 frames, held to 88, down by 108; status
    AR13's measured table), driving the cheering pose round 1's crowd shader already had.
- **thirdjam's own goals and nets** now stand in the hall (they were baked and hidden in favour of lane K3's goal):
  K3's goal is one merged mesh with the boards and markings and cannot shake. `main.gd` passes `arena_goals` and
  `tj_rink.gd` skips its own goal when it is set (one guarded line in K3's file: question 1 for the Director).

## The proofs (selftest blocks 842, 843; 18 of 18 with 840 and 841)

- `core.rink.booth.match`: a whole match of the bare core through the pack's own `hud.gd` (seed 1, pro, an idle hand,
  7,163 frames): 30 lines started by the caption, 30 said, each on its frame from its own file; 17 barks said,
  17 MS_bark; 4 cuts, exactly where the bark rule says; two runs agree. Shown red (barks withheld: "the bark at 90
  has no MS_bark"). Rates: 15.1 lines and 8.5 barks a minute here, 14.0 and 9.0 in thirdjam's own played match
  (another hand, another play). The table: `BOOTH-REACT.md` section 1.
- `core.rink.booth.duck`: TLSound's node ducks the music bus to x0.45 in a straight line of gain over 12 frames
  (checked every frame to 0.002), the line fades in 9 frames, the music back to 0 dB 12 frames later.
- `core.rink.booth.pause`: under the tree's pause the music loop and a line hold their place (300 ms of the mixer's
  wall clock: the same position to 0.1 ms) and go on at resume. Shown red (the pack's node left unpausable).
- `core.rink.react.tj`: thirdjam's own log of a played match (13,620 frames, its 57 goal and board events) through
  our reactions gives every one of the 45 reactions thirdjam's ARinkActor logged: the same cap of 73 each of 39 times,
  its tilt and hop within the log's print precision (worst 0.054 degrees, 0.050 cm), the same rattled piece and roll
  4 times, the same scored end twice. Shown red (26 degrees made 24: "frame 1163: cap 41 tilt 24.0 ...; thirdjam cap
  41 tilt 26.0"). The table: `BOOTH-REACT.md` section 2.
- **The voice in thirdjam's own output** (`engine/tools/arena/vo_gain.py`): thirdjam's match recorded with its
  commentator on (render_match.py, 90 s, 21 lines said): each line's wave found by cross-correlation; gain 0.338 to
  0.356 over 17 lines, median 0.345 (-9.24 dB), not the 0.5 a mono MetaSound like the skate loop comes out at: the
  port takes 0.345 (`voice.json` "out_gain"). The lines sit 0.22 to 0.28 s after their logged frames, and so does the
  faceoff drop's own sound at the same moments (+0.14 s at frame 90, +0.27 at 1517): thirdjam's hit-stops hold its sim
  frames while its ticks run; the voice starts on its frame. Ours: the opening line at frame 0, gain 0.345.
- **Loudness, 90 s each, both with the commentator** (`r3_loudness.jpg`; two plays): median second -27.6 / -27.1 dB
  (thirdjam / ours), loudest tenth -22.1 / -21.4, quietest tenth -30.7 / -31.1, whole -26.4 / -25.9, peak -3.3 / -3.8,
  bands under 300 Hz / 300 Hz-3 kHz / over 3 kHz -32.8 / -28.4 / -40.7 against -32.7 / -27.8 / -39.5. Round 2 without
  the voice: median -28.5 / -28.2; the voice lifts both by about 1 dB.
- `core.rink.react.caps`: Build's stanchion walk (ported) gives the 73 caps at the baked instances' places to 0.00000 m
  and yaws to 0.0004 degrees (the hash-made turn of each cap included).
- `core.rink.react.curves` and `.goal`: thirdjam's own RinkReactionTests expectations (LampAt, NetShakeAt, RattleAt,
  CapRockAt; on the goal's frame the lamps at 9 and the net off rest, deepest within 2 frames under 15 %, a cap of the
  scored end hopping on the goal's frame, all at rest by 120) and BP_ArenaCrowd's measured cheer at 15 frames.

## What I looked at (stills: ours from thirdjam's logged camera; thirdjam's game stills, the same deterministic hand)

- `r3_goal_full_sbs.jpg`, `r3_goal_sbs.jpg`: thirdjam's stills at the goal (frame 1307), +2, +18, and back at rest
  (+114) beside ours from the same camera. thirdjam's still named f<N> is the frame after N (its request frame), read
  off the puck in the net and the NS_goal ribbons on the still named f01306. The goal light behind the net: lit orange
  on the goal's frame in both, still lit at +18, back to the same dark red at +114. The end's crowd: up by +18 in
  both, seated again at +114.
- `r3_end_ours.jpg`: ours, close: the lamp's pulse and fade, the crowd rising and still up at +100 (0.4).
- `r3_cap_ours.jpg`: ours, a hard hit: the cap hops and tips away on the hit's frame, stands at +2 (the cosine's zero)
  while its neighbour rises on its 2-frame delay, swings toward the ice at +4.

## What my eye rejects

1. In thirdjam at +18 a hopping end cap turns purple-red under the goal wave's travelling red light; ours stay blue.
   The lights of the reactions are not ported (below).
2. thirdjam's goal has NS_goal (white ribbons and a puff of smoke over the net) and the GOAL banner; neither is this
   lane's (the effects and the HUD), but the goal reads far louder there than in my HUD-less stills.
3. The net's shake is not visible from the game camera in either game (54 frames of +-12 % depth at 20 m); only the
   close-up shows it, and there I have no thirdjam still to set beside it.
4. Carried from round 1: the boards' clay bump reads as a sandy, pitted surface in close views (thirdjam's is
   smoother), and our ice is a touch whiter than thirdjam's in the same pose.

## Deviations (new this round; rounds 1-2's stand)

1. **No reaction lights**: the two lamp lights (800 cd at the scored end, 100 at the table, 3.5 m, lighting channel 1),
   the hit flash (90 cd warm, only for a check into the boards) and the goal wave's two red lights are not ported: the
   hall's materials are lit by the rig's list in the shader (round 1), not by engine lights; a light that changes per
   frame needs that list to take extra lights (a style addition: next round).
2. **The penalty box** (its door, its clock hand, its light on a foul) is not ported: not in the brief's list.
3. The voice's level is thirdjam's own output measured (0.345 of the wave; `vo_gain.py`), not a rule read from a graph.
4. The duck's fade is Unreal's default 0.2 s (SCM_DuckMusic's own fade times were not in round 2's export; the
   defaults are SoundMix.cpp:27-28).
5. `tj_rink.gd` (lane K3's) has one guarded line: its goal is not drawn when the hall's goals stand.
6. The voice and the barks are only heard where the HUD runs (a window): headless runs record no voice, as before
   they showed no caption.

## Next

1. The reaction lights (lamp lights, hit flash, wave lights) through the rig's list; the penalty box.
2. A person's ear on the voice and the mix (no ear has heard either recording).
3. Round 1's carried look items (the boards' bump, the ice's white).
