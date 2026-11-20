# dio-astra, round 3 (about 13:20 to 15:00): brief for Astra (a fresh session)

You are the designer and builder of the **dio-astra** arm (the frame and the figure of the toy diorama). I am your
operator (Opus): I run you, measure, verify and pass back measurements. The design is yours.

## Read first
- `docs/shifts/2026-11-20-day/COMMON.md`, `docs/shifts/2026-11-20-day/TEAMS.md` (your scope: "Astra arm" and
  "Team dio" -> dio-astra; selftest block 620-629).
- The board `docs/shifts/2026-11-20-night/target/4-toy-diorama.jpg` and `target/NOTES.md` section 4.
- Your own work so far, in this lane folder: `ASTRA-BRIEF-r1.md`, `ASTRA-BRIEF-r2.md`, **`ASTRA-NOTES.md`** (rounds 1
  and 2: the far-only lens, the exe AA key `env.exe_aa`, the sun turned to azim -67, the cloud and clay changes, how
  you proved classic exact with the seeded harness `.tl/astra-r1/seeded-view.gd` and `classic-seeded.ps1`), `PATCHES.md`.
- Your partner's handoff to you: `docs/shifts/2026-11-20-day/lanes/dio-fable/PATCHES.md` § "dio-astra (frame)".

## What changed since round 2
Rounds 1-2 are committed (8cae07a). The Director merged both dio arms into `d20-dio` (1070eea) and this worktree is
on it: dio-fable's fibre textures (`engine/style/dio/tex/*.res`), felt pines and bushes with real form, clay mesas,
turned fence posts, clay kit boxes and a style-keyed picture cache are now in the tree. The class cache is rebuilt.

**Classic proofs need a cache of their own** (dio-fable PATCHES, Director item 3): a cache filled by diorama runs of
this tree can hold felt pictures under a classic key. Use a fresh `TL_CACHE_DIR` (e.g. `.tl/cache-classic-r3`) for
every classic capture, and the same one for its base twin. My classic baseline is the fixed base archive
`.tl/opbase` (d20-base + the `_face` fix), as before.

## Measurements of the joined tree (my shots, `.tl/j1/dio/`, 1920x1080, same shot set as before)
Sharpness (variance of a 3x3 Laplacian of luma, geometric mean, bands as before; `python .tl/sharp.py <A> <B>`):

| band | your r2 (old surfaces) `.tl/v2/dio` | joined tree `.tl/j1/dio` | ratio |
|---|---:|---:|---:|
| tour far | 167.7 | 232.8 | 1.39 |
| tour mid | 110.5 | 224.7 | 2.03 |
| tour near ground | 50.5 | 204.3 | 4.05 |
| flight far / mid / near | 205.9 / 141.6 / 51.0 | 252.5 / 221.3 / 225.4 | 1.23 / 1.56 / 4.42 |

Tour GPU p50 (windowed picture run, machine shared): 2.339 ms joined, 1.518 ms on your r2 tree.

Colour, measured factually (frames scaled to 1280x720, rows 300-720, olive/green pixels; "lit" = brightest 40 % of
them, "shade" = darkest 15 %; the board filter also catches some of the golden road, so treat it as approximate):

| | lit grass | grass in shade | top sky band (rows 0-120) |
|---|---|---|---|
| board | (206,162,56) #cea238 | (67,62,18) #433e12 | (189,128,127) |
| joined 07_parkour_road | (144,150,35) #909623 | (92,101,26) #5c651a | (172,118,121) |
| joined 01_walker_road | (150,155,34) #969b22 | (97,110,29) #616e1d | (163,117,126) |
| joined 13_lot_river_road | (132,136,26) #84881a | (73,79,18) #494f12 | (169,114,121) |

On the board red exceeds green in lit grass; in ours green exceeds red. Board shade is deeper.

## This round: the Director's list, in this order (13:20)
1. **16x anisotropic filtering on a diorama-only route, not `project.godot`.** dio-fable: "the ground is now a fibre
   texture seen at a grazing angle: at 4x it goes soft from about 25 m, at 16x it holds to the middle distance. This is
   the single setting that most decides whether the meadow reads sharp." Classic must stay exact.
2. **Reconcile the sun and the palette on the joined tree.** dio-fable moved its palette (`grass #7e9a3e`,
   `grass_dark #4a7836`, `pine #385c34`, `pine_light #517c40`) for the old sun (`#ffcb98`, 1.24); you turned the sun
   to azim -67 and `#ffcf9c`. The river mirrors three sky colours that sit in dio-fable's `water` section
   (`water.sky` #ffc59a, `water.sky_top` #8a78c8, `water.cloud` #ffe2b4). **Do not edit the palette, `water`, `toon`,
   `mat` or `detail` sections.** Change your own light if that is your call, and write the numbers dio-fable should set
   (palette and the three water colours, with your measurements) in `PATCHES.md` under "For dio-fable"; the
   Director passes them on.
3. **Shimmer.** 4x MSAA without TAA doubled the horizon motion in the exe (your r2 figure 0.61 -> 1.23). Measure it on
   moving footage in the exe window (the boot scene), and bring it down without giving the sharpness back.
4. **Cream clouds** (the broad highlight is still less cream than the board).

The owner's words from the integration will follow when the Director sends them; I will pass them on.

## Hard stop for this round
About **15:00**, with a clean, working tree, gates green, classic exact, and a "Round 3" section appended to
`ASTRA-NOTES.md`. The next integration is 16:30. Do not start an unfiltered `tl check --tier full`.

## Rules (unchanged; hard)
- Work only in this worktree. Read-only git is fine; **do not commit**, no git that writes.
- Your scope only (TEAMS.md "Astra arm", plus `engine/boot/boot.gd` EXE_AA on this branch). In
  `style_diorama.json` add or change keys only in your sections (sun, env, fog, sky, clouds, ink, grade, lights,
  miniature_lens, figure); never reorder or reformat the others.
- No file under `engine/packs/**`, `engine/seeds/**`, `contracts/**` changes; `TL_STYLE=classic` exact; no state hash
  moves; kernel v1 signatures kept. New selftests only as `engine/tools/selftest.d/62N-*.sh` (622-629 are free).
- Never kill a process you did not start (four arms and the Director share this machine and one window lock).
  Raw captures under `.tl/astra-r3/`.
- Godot: `C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe` (TL_GODOT).

## Tools
- Shot set: `bash docs/shifts/2026-11-20-day/lanes/dio-astra/shotset.sh <diorama|classic> <out dir> [tour flight figure games]`
  (set `TL_CACHE_DIR` for classic, see above).
- Sharpness `python .tl/sharp.py <A> <B>` (tour shots by default; `SHARP_ONLY="^2"` for flight); classic pixel diff
  `python .tl/pxdiff.py <before> <after>`.
- Gates: `node devx/bin/tl.mjs check --tier fast`; `node devx/bin/tl.mjs check --tier full --only world,packs,kit.selftest`;
  `bash engine/tools/selftest.sh style.` (and `rig.`, `moves.`, `flight.`, `wings`, `character.`). I re-run all of them.
