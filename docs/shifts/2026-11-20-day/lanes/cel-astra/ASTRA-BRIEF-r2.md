# cel-astra, round 2 (12:15-12:55; integration 13:30)

## What the operator verified on your round-1 tree (my own runs)
- `check --tier fast` PASS 5/5. `check --tier full --only world,packs,kit.selftest` PASS: world 8/8, every hash equal to
  the base (drive a2940a17@3441, wall d5aea03b@1220, paddle dff1a390@4486, walker f1c7b537@371, kit ca698e71@332,
  car 3a459d0f@1872, hockey a29dcdf0@4186, parkour f7abac00@988), packs 48/48, kit 95/95.
- selftest `style.` 9/0, `rig.` 14/0, `cel.` 3/0.
- Classic proof against my base copy with the e191d8f rename and the assets (`.tl/r0/classic`): all 18 shots that are
  bit-exact between two base runs are 0/255; the other 9 stay within their run-to-run noise. Your crisp set reproduces
  in my run (`.tl/op-r1/crisp`): the same 18 shots equal.
- Sharpness (`.tl/op-r1/sharp.txt`, classic -> crisp, Laplacian variance): centre crop x1.07 to x2.14 on every shot;
  top and mid up on all but 26 top (x0.95) and 42 top (x0.70). The near crop fell in six shots: 01 walker road
  72 -> 59 (x0.82), 03 drive road 72 -> 60 (x0.84), 05 wall road 24 -> 17 (x0.70), 21 flight climb 124 -> 100 (x0.81),
  23 flight bluff 110 -> 91 (x0.82), 24 flight bluff2 109 -> 45 (x0.42).

## The Director's decision at 11:35 (verbatim in substance)
dio-astra found that the exported game window forces `msaa=2,taa=1` (`engine/boot/boot.gd` `EXE_AA`, overridable with
env `TL_EXE_AA`), while the tour captures use 4x MSAA + SMAA. Through the boot scene, mid-distance edge energy was 23
against 109: the owner plays a softer picture than the stills show. **On this branch you own boot.gd's `EXE_AA`.** Make
it come from `style_crisp.json` (a key such as `exe_aa`), with an absent key meaning today's value so classic stays
exact, and the env override first. **Measure the exe window, not only tours** (the owner judges the exported game;
the Director exports `dist/day/cel/ThirdLife` at 13:30). Also: cel-fable's helper is `engine/style/cel/cel_surfaces.gd`
(selftest prefix `celsurf.`); yours is `style_cel.gd`. Do not create files with those names of theirs.

## What differs from the board in the round-1 stills (described, measured where I could)
- 21_flight_climb: the five upper clouds share one silhouette and one set of lavender inner cuts (x 150-550, 790-1130,
  1290-1600 are the same shape at different scales). Board 2's clouds each have their own outline.
- I see no sun disc or sun glow in the crisp frames I looked at (01, 07, 21, 41, 51), and no patch brighter than 235
  on all three channels lies in the upper 500 rows of any of the 27; board 2 has a pale sun with a warm glow at the
  upper left over the mesas.
- Colour samples, board 2 vs 51_road_visitor crisp (median of a patch): lit road near the feet #de8542 vs #cd9b49;
  sky just above the far hills #fdb18a vs #ec999d; sky at the top #b275c7 vs #b87bb0.
- 51_road_visitor: the large tree at the left and the mid-ground grass still carry the fine diagonal hatch in
  shade; the long cast shadow across the road is grey-brown on the road and dark olive on the grass. (Surface hatch
  and material bands are the partner's; your PATCHES.md already proposes them.)

## This round
About 40 minutes: be done by **12:55** with a clean working tree. The exe antialiasing comes first; then any gap you
judge biggest. Keep classic exact and the gates green; I re-run everything 12:55-13:25. Update ASTRA-NOTES.md (a short
"Round 2" section at the top: what changed, keys, your measurements including the exe-window figure, the selftests you
ran) and PATCHES.md if needed. Read-only git is fine; do not commit. Never kill a process you did not start.
