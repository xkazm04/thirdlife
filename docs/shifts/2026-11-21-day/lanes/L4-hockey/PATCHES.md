# L4 hockey-mechanics: requests for files outside L4's column (the Director lands or forwards them)

## P1 (10:55) to L2 fight-clips, `engine/rigs/**`: a blade distance beside `stick_yaw`

Why: thirdjam carries the puck on the blade at 1.2 m from the skater's centre (1.6 m sprinting): `JamSim.cpp:1492-1499`,
`JamCartridge.h:159,187`. L4 ports that (the owner: "puck sticking to the player"). Today the hockey figure (body scale
2.2) draws its blade 2.77 m ahead and 1.24 m right (`tuning.json` carry.offset, measured on the rig). With the puck at
1.2 m and only a yaw, the drawn blade lies 1.5 m beyond the puck: the puck sits under the shaft, not on the blade.

Ask: a rig param `stick_reach` (metres on the ice from the root to the blade's heel, at rig scale 1; the pack divides by
its body scale), next to `stick_yaw`, that brings the blade in by pitching the shaft up and bending the arms; absent =
today's pose. If that is not cheap today, `stick_yaw` alone is still wanted; say so and L4 keeps the puck where the
drawn blade can reach (the fallback is to carry at the drawn blade's distance and port the rest of the rule).

**Update 11:45:** in a window, thirdjam's literal 1.2 m put the puck under this 4.4 m figure's chest (hidden; clip
`.tl/clips/r1_skate.mp4`). L4 now scales thirdjam's rule to the figure (body 0.66 m, not 0.4: walking 1.98 m, sprinting
2.64 m; `.tl/clips/r1s_skate.mp4`), and there the puck sits at the drawn blade whenever the stick points along the
facing. So `stick_reach` is no longer needed; `stick_yaw` is still wanted (with an aim off the facing the drawn stick
points one way and the puck rides another).
