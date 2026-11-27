# The juice pass (S2-juice, shared by both arms)

**What it is.** One block of builder text, `foreman/prompts/juice_pass.md`. It is byte for byte the same in arm A
(`d25-robot`, branch d27-sp-juice) and arm B (`d27-sp-juice-b`, branch d27-sp-juice-b). When the pass runs, the Foreman
gives this text to the package that owns the change. It goes in beside the person's change request, in that builder's
round prompt (`foreman.ts` feedback(), after the change request).

**Where it comes from.** It writes down the hand layers that beat the editor last night (27 Nov):
- robots: the red-hot hammer head and the reach ring; launches of 3.7-5.4 m with 40-64 frames in the air; BONK! /
  KA-BONK!!; the lens kick, and the camera following a launched captain; a miss buries the head in dust;
- shield wall: a lane of red rings; BOWLED! / BRACED! / SLAM!; hit-stop 4/9; a 0.22-0.45 shake; the lens following the
  slam;
- Arsenal: the stick on fire, a growing wind-up ring, METEOR!, a net bulge and glass rattle;
- J4b's basketball sentence: the court-wide slow beat at the rim, the camera push-in, mid-screen SLAM!/REJECTED!, the
  rim shake.

**It scales down.** The builder sizes the move first:
- **small** (a tap used many times a minute): a pose tell, 2-3 f hit-stop, a 0.05 shake, one burst, one sound; no word,
  no slow beat, no camera move;
- **big** (it floors, launches or steals): parts 2 to 7 below;
- **signature** (the move at its biggest): big, plus the slow beat.

**The seven parts** (the brief's list) and the numbers the pass gives:

| Part | What the pass asks for |
|---|---|
| a wind-up tell that grows | a glow that heats in 3-4 steps; a ring or lane on the ground at the real reach, swelling and throbbing faster as the charge fills; a rising sound; the asked wind-up never shortened |
| exaggeration, in numbers | a launch of at least 2 body heights, at least 40 f in the air, 1.5-3 turns of spin, speed kept in the air, scaled by charge; the numbers written under DEVIATIONS |
| hit-stop and a camera kick or follow | `TLHit.impact` 5-9 f by force; `ctx.cameras.shake` 0.25-0.45 m plus a lens kick (fov -5..9 degrees, back over 12 f), full in the player's own fight, at least 40 % across the field; the camera follows a launched player |
| an impact word mid-screen | a comic word at the contact point (`hud.add_tag`) or centred, 30-45 f, bigger at full force; never in the score line or over the clock |
| particles and sound | a burst along the blow (sparks / dust / debris), a second at full force, a trail on a fast weapon; sounds for wind-up, release and impact, scaled by force; a miss gets its own small cue |
| a slow beat on the big moment | signature only: 18-30 f where the pack's own sim runs at half or a third rate (frame-counted, deterministic, never `Engine.time_scale`), the camera closing in; at most once every 5 s |
| the world answering | the victim tumbles and drops what he carries; a body that lands among others bowls them or bounces off a wall; nets, rims and walls bulge or shake; the crowd or HUD reacts |

**Guards written into the pass** (so it does not harm a game):
- Exaggerate the arc, not the rules. Time out of play (from the hit to standing again) stays within +25 % of the move
  without the pass. Damage and cooldowns stay as asked. A match gets at most 10 % longer.
- Camera, words, particles and sound are drawing only and never touch the state hash. Hit-stop and the slow beat are
  in the simulation and count frames.
- The pass's numbers go into the pack's tuning data.
- The builder does what is in its scope. Each part outside it gets a `JUICE: <part> not done: <whose files>` line.
- Every builder ends its DEVIATIONS with a checklist line:
  `JUICE: size .. | tell .. | exaggeration .. | hit-stop .. | camera .. | word .. | particles+sound .. | slow beat .. | world answers ..`

**Code shared by both arms** (`foreman/src/juicepass.ts`, one constant apart):
- `juiceRuns(text)` decides from the person's words whether the pass runs:
  - arm A (`JUICE_MODE = "auto"`): every change that adds a move (`addsMove`: a play change that names a move and a
    key, or "give every X a ..."), unless the words say "keep it plain" / "no juice";
  - arm B (`JUICE_MODE = "choice"`): only when the words say "make it juicy" (Create's card writes them).
- `foreman.ts`, two hooks (+5 lines, 2006 of the 2032 ratchet):
  - the pass text goes into the owner's round prompt;
  - a note is logged: "[foreman] juice pass: ..." when it ran. In arm B only, "[foreman] juice pass offered: ..."
    when a change adds a move and was built plain.
- `boundlift.ts askedChange` (+2 lines): a change the pass ran on also counts the pass's words ("wind-up tell, launch,
  tumble, hit-stop freeze") among the person's words. The balance rows that measure those (idle_max_f, tells) are then
  moved by the change, not refused as a regression. Both arms do the same.
- Tests: `foreman/src/test/juicepass.test.ts` (5), identical in both trees. They use the night's real sentences.

## The pass, verbatim (`foreman/prompts/juice_pass.md`)

```
JUICE PASS (the Foreman adds this to the change request; the person did not write it word for word, but it is part of
what they get). The change adds a move. Build the move exactly as asked first. Then make it read on screen the way a
person meets it: they see it coming, feel it land and see the world answer it. Last night's hand-made versions of a
robot hammer, a shield charge, a slapshot and a dunk beat the editor's on exactly these parts.

1. SIZE THE MOVE FIRST, then give it only its size of juice (juice on everything is slop; a small move gets a small pass):
   - SMALL: a quick move used many times a minute that floors nobody (a tap, a hop, a poke, a feint): a 4-8 frame pose
     or squash as its tell, 2-3 frames of hit-stop on contact, a 0.05 m shake, one small burst, one sound. No word, no
     slow beat, no camera move.
   - BIG: a move that floors, launches or steals, used a few times a minute (a charge, a slam, a hammer blow): all of
     2 to 7 below.
   - The SIGNATURE moment: the move at its biggest (a full charge, a dunk, a hit that scores or floors two): BIG plus 6.

2. A TELL THAT GROWS: the wind-up shows from its first frame and grows until the release, so a rival (bot or person)
   can read it from across the field: a glow on the weapon or body that heats in 3-4 steps, and a ring or lane on the
   ground that marks the real reach or landing spot, swelling or throbbing faster as the charge fills. A wind-up
   sound that rises. The tell never shortens the wind-up the person asked for.

3. EXAGGERATION, IN NUMBERS: say the numbers under DEVIATIONS. A launched or thrown body goes at least two body heights
   up with at least 40 frames in the air and 1.5-3 turns of spin, keeping its speed in the air; a jump or leap hangs at
   its top. Scale every number with the charge or force when the move has one. Exaggerate the arc, the spin and the
   hang, not the rules: the time a victim is out of play (hit to standing again) stays within +25 % of what the move
   gives without the pass, damage and cooldowns stay as asked, and a match must not get longer by more than 10 %.

4. IMPACT: on contact, hit-stop on both bodies (`TLHit.impact`, 5-9 frames by force for a BIG move), a camera kick
   (`ctx.cameras.shake`, 0.25-0.45 m by force) plus a lens kick (the active camera's fov narrowed 5-9 degrees and sprung
   back over about 12 frames), full when it is the player's own fight and at least 40 % across the field. When the
   player himself is the one launched, the camera follows him up so he never leaves the frame.

5. AN IMPACT WORD MID-SCREEN: a short comic word where the blow landed (`hud.add_tag` on the victim or a node at the
   contact point, or a large centred label), 30-45 frames, a bigger word at full force ("BONK!" / "KA-BONK!!",
   "BOWLED!", "SLAM!"). Never in the score line, never over the clock, at most one word at a time per fight.

6. PARTICLES AND SOUND, and THE SLOW BEAT:
   - a burst thrown along the blow (`TLVfx.burst`: sparks for metal, dust and debris for stone and wood), a second
     burst at full force, a trail on a fast weapon or body (`TLHit.swing_trail`, `TLVfx.trail`); a sound for the
     wind-up, the release and the impact (`TLAudio.play` or the pack's `TLSound`), the impact louder or lower by force;
     a miss gets its own small cue (dust where the head hits the ground), never the hit's;
   - the SIGNATURE moment only: a slow beat of 18-30 frames where the pack's own simulation advances at half or a third
     rate (the pack skips its own step on the other frames: frame-counted and deterministic, never `Engine.time_scale`,
     never a wall clock), with the camera closing in on it and snapping back on release. At most once every 5 seconds.

7. THE WORLD ANSWERS: a body that is hit tumbles and drops what it carries; a body that lands among others bowls them
   over or bounces off a wall with a spark; a net, rim, board or wall that is struck bulges or shakes; the crowd or
   HUD reacts to the biggest moment.

Rules for the pass:
- Use the TL* API only (no hand-made materials, lights or environments). Camera, words, particles and sound are drawing
  only: they never change the state hash. Hit-stop and the slow beat are in the simulation and count frames.
- Put the pass's numbers in the pack's tuning data beside the move's, so a person can change them.
- Do what is in your scope. For a part outside it, write `JUICE: <part> not done: <whose files>` under DEVIATIONS.
- End your DEVIATIONS with one checklist line, each part yes / no / small:
  `JUICE: size <small|big|signature> | tell <..> | exaggeration <..> | hit-stop <..> | camera <..> | word <..> |
  particles+sound <..> | slow beat <..> | world answers <..>`.
```
