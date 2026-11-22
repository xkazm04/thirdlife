# Engine needs from the reference games (night of 22 Nov, the loop to 09:00)

What the duel and hockey needed that the kernel lacks:
- Game lanes write rows in `lanes/<lane>/ENGINE-NEEDS.md`. The Director collects them here.
- N1 lands them as kernel API.
- A row is closed when its API is on main and the game dropped its shim.

| # | Need | Proposed API | Who needs it | Shim today | Status |
|---|---|---|---|---|---|
| E1 | Play a rig clip faster or slower (wind-ups sized to frame tables) | `TLBiped.set_clip_speed(who, s)` or similar (N1's call) | duel (the frame tables), hockey (stick handling); every fight game from the editor | duel `feel.gd` writes `rig.clip_t` every frame | API landed c1cca38 (1.14: `TLBiped.play_clip(clip, timing, blend)`, `set_clip_speed`, `clip_now`, `clip_frame`; block 716 4/4); duel shim to drop in its next round |
| E2 | Swings with weight: anticipation, follow-through and a heavy arc that reads as heavy | rig fight clips `strike` / `strike_heavy` re-authored with wind-up and recovery poses; `TLVfx.trail` weight by class | duel; every melee game | duel swing trails only | rig poses landed c1cca38 (heavy coils overhead, long low lunge; light compact); E2b kernel trail = `TLHit.swing_trail` in N1 round 2 |
| E6 | **World = alone breach (kernel):** a skater's contact with static net or boards geometry integrates ~1e-3 m differently in world.sh than in the lone runner. Frames up to 2015 are identical; skaters[4] pos.x differs at frame 2016. Landed hockey passes only by trajectory luck. | world runner and lone runner identical physics: space settings, solver, contact and static body order | every game in a world (the law) | none; hockey r2a (more passes, hits kept) held back | assigned to N1 at 04:05; repro n22-hockey/.tl/w_r2a + .tl/wcmp.sh 2015/2016 |
| H1 | Cap the speed a contact may add to the puck | `TLBall.set_max_gain(per_frame, floor_speed)`, `set_velocity` | hockey (puck pinch), every ball game | hockey `carry.gd _pinch` | N1 round 3 (API 1.16) |
| E7 | Pushbox against a wall: with the defender pinned, half the penetration lets the attacker walk into him (seen by the -4 critic) | `TLHit.pushbox` gives the whole push to the free body when the other cannot move | duel, every melee game | none | open (from N4 round 10) |
| E8 | Gear slots on the biped's head, back and shoulder sockets, oriented by the rig (today a pack hand-builds socket transforms: +X right, +Y back, +Z down) | rig API for gear slots (N1/rigs' call) | duel, every editor game with distinct rivals | duel gen/arms.gd | open (from N4 round 14) |
