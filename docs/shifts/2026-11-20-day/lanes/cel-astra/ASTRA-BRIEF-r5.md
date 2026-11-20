# cel-astra, round 5 brief (20 Nov 2026, 16:40; for GPT 6.2 Astra, a fresh session; the last build round)

You are the designer and builder of arm **cel-astra** (team cel, "crisp cel"): the frame (sky, clouds, sun, light,
shadows and the shadow filter, grade, post, antialiasing, sharpness) and the figure. An Opus operator runs you,
re-runs every gate and looks at every still. This is a fresh session: your rounds 1-4 are in
`docs/shifts/2026-11-20-day/lanes/cel-astra/ASTRA-NOTES.md` (read Round 4 and Round 3 in full); also read
`ASTRA-BRIEF-r4.md`, your `PATCHES.md`, the partner's `docs/shifts/2026-11-20-day/lanes/cel-fable/PATCHES.md`,
`COMMON.md`, `TEAMS.md`, and look at board 2 (`docs/shifts/2026-11-20-night/target/2-crisp-cel.jpg`).

Worktree: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d20-cel-astra`. Read-only git is fine; **do not commit**.
Never kill a process you did not start. **Do not write into STANDUP.md or REPORT.txt** (the operator keeps them).
The ground's paints and bands (`toon` section, `toon_cel.gdshader`, palette) are cel-fable's: numbers in PATCHES.md,
never edits. `boot.gd` is at 600/600 lines; `tl_style.gd` near 600. Classic stays exact; game hashes stay.

## Where the tree stands
Integration 2 is merged: `d20-cel` 5e4b5c8 = your round 3-4 (c9d14ba) + cel-fable's rounds 4-6 (cd89476: road rails,
tree shade, olive meadow, cream strata, road rim, drifting cloud shadows `toon.cel_cloud`, and `toon.shade_k` 0.85,
so `character.cel.wardrobe` and `style.cel.exe_aa` should load clean now). The class cache is rebuilt.

## The operator's verification of round 4 (my runs on your r4 tree)
- fast PASS 5/5; full `world,packs,kit.selftest` PASS (world 8/8, packs 48/48, kit 95/95); 46 pack hashes = base.
- Classic proof: 18/18 reproducible shots 0/255 against `.tl/r0/classic`; the 9 noisy within noise.
- Selftests: rig. 14/0; cel. 2/2 (the two clamp failures, now fixed by the partner); `style.frame.pixels` could not
  run (window-lock timeout after 900 s; to be re-run).
- **Sharpness in stills went down in the middle distance with round 4** (my lane shot set, Laplacian variance,
  `.tl/op-r3v` = your r3 tree, `.tl/op-r4` = your r4 tree; classic in brackets):
  07_parkour_road centre 3500 -> 2349 (classic 2402), mid band 3711 -> 2568 (classic 2333);
  24_flight_bluff2 centre 853 -> 615 (classic 568); 51_road_visitor centre 616 (r3 capture of the joined tree)
  -> 531, near 122 (unchanged). The owner's first complaint about the other look was "blurry"; these stills are
  taken by the tour and the visit camera at rest. Please measure whether the distant history pass is what softens a
  still frame, and choose with both numbers (still sharpness and motion flicker) in view.

## The Director's words (16:35, verbatim)
"Round 5, in order:
(1) Fence shadows on the road have a sawtooth edge (cel-fable found it). Its cel cut at half the sun's shadow lands
on the filtered edge (`sun.shadow_blur` 0.72, filter_quality 2). It is testing blur 0.3 with a hard filter in a scratch
copy, and will put the result in its PATCHES. The shadow filter is yours: make cast edges on the road clean and cut,
as on board 2.
(2) Thin grass against the horizon still flickers.
(3) Then raise fidelity in the frame: the sky's gradient and cloud shapes beside the board.
Final integration is at 19:45. Be READY by 19:30 with your tree clean and REPORT.txt drafted."

## The round
Until **18:35** at the latest (then I verify for 50 minutes): a clean working tree, ASTRA-NOTES.md "Round 5" on top
(what changed, keys, measurements before/after, selftests with their lines), PATCHES.md current. Work the Director's
items in order; measure each before and after (the cast edge on the road: e.g. count of stair steps or edge width in
pixels along a fence cast at native 1080p, in a still and in the exe). Token budget: the day's Astra budget is spent;
please stay under about 350k tokens in this session and prefer headless captures (the window lock queue was 6-15
minutes per windowed run this afternoon).
