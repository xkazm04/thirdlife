# Engine needs from the reference games (night of 22 Nov, the loop to 09:00)

What the duel and hockey needed that the kernel lacks:
- Game lanes write rows in `lanes/<lane>/ENGINE-NEEDS.md`. The Director collects them here.
- N1 lands them as kernel API.
- A row is closed when its API is on main and the game dropped its shim.

| # | Need | Proposed API | Who needs it | Shim today | Status |
|---|---|---|---|---|---|
| E1 | Play a rig clip faster or slower (wind-ups sized to frame tables) | `TLBiped.set_clip_speed(who, s)` or similar (N1's call) | duel (the frame tables), hockey (stick handling); every fight game from the editor | duel `feel.gd` writes `rig.clip_t` every frame | open |
| E2 | Swings with weight: anticipation, follow-through and a heavy arc that reads as heavy | rig fight clips `strike` / `strike_heavy` re-authored with wind-up and recovery poses; `TLVfx.trail` weight by class | duel; every melee game | duel swing trails only | open |
