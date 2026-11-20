# dio-astra, round 1 (day of 20 Nov 2026): brief for Astra

You are the designer and builder of the **dio-astra** arm. I am your operator (Opus): I run you, measure, verify and
pass back measurements. The design is yours.

## Read first
- `docs/shifts/2026-11-20-day/COMMON.md` (the owner's words, rules, shot set, loop, gates, lane rules) and
  `docs/shifts/2026-11-20-day/TEAMS.md` (your scope: "Astra arm" and "Team dio" -> dio-astra, selftest block 620-629).
- The board: `docs/shifts/2026-11-20-night/target/4-toy-diorama.jpg`, and `target/NOTES.md` section 4.
- Last night's work this tree is built on (both yours): `docs/shifts/2026-11-20-night/lanes/frame-astra/` (REPORT.txt,
  ASTRA-NOTES.md: the sky, light, contact pass, grade and the tilt-shift lens) and
  `docs/shifts/2026-11-20-night/lanes/character-astra/` (the clay figure, `engine/rigs/biped/clay_*.gd`,
  `engine/style/shaders/body_clay.gdshader`).

## The owner's words, verbatim (20 Nov, 10:20)
"hard to decide. Diorama looks better on first sight, but graphics seems blurry and quality/fidelity far below the art
concept. The original game does not look very good now, but there is clear the potential is there to evolve to create
beuatiful and sustainable world. Lets use this day still to work in parallel. 2 builders on Evolving crisp cell, 2
builders on diorama to see if we can improve the graphics quality further. Again 1 Astra + 1 Fable in team. No need to
focus on full game, the focus should be the world (surface, sky, nature) and the character. I would like to see from
both glimpses of full potential which would help me decide. Lets use 10 hours of time, and loop to perfect both
variants to use the time fully"

Also (10:10): "for Character the Opus + Astra looked better" than Fable's.

## Measurements of this tree (round 0, before any change today)
Shots: `.tl/r0/dio/` (diorama, TL_STYLE unset) and `.tl/r0/classic/` (TL_STYLE=classic), 1920x1080, the tour of
COMMON.md with `--load=block`. Sharpness = variance of a 3x3 Laplacian of luma over fixed bands of the frame
(`python .tl/sharp.py <dirA> <dirB>`; bands: far y 36-50 %, mid y 50-70 %, near y 75-100 %, x 10-90 %).
Classic draws ink contours, which add edge energy, so the ratio to classic is an upper bound on what is "lost", not a
target. Before/after on the same tree is the figure that counts.

| band (geometric mean of 16 tour shots) | classic | diorama | ratio |
|---|---|---|---|
| far (horizon, mesas, far trees) | 445.2 | 134.9 | 0.30 |
| mid | 202.0 | 97.3 | 0.48 |
| near ground (bottom quarter) | 76.9 | 18.9 | 0.25 |
| whole frame | 258.6 | 74.6 | 0.29 |

Worst single shots, near band: 07_parkour_road 0.12 (the board's shot), 11_site_crates_road 0.13, 10_paddle_above
0.15, 06_wall_above 0.18, 01_walker_road 0.19. Far band: 01_walker_road 0.11, 11_site_crates_road 0.14,
07_parkour_road 0.15.

What I see in the stills, factually:
- `07_parkour_road` near crop (x 640-1280, y 720-1080, `.tl/r0/crop07_near.jpg`): the fence's cast shadow edge and
  the pebbles on the road are smeared over roughly 8-12 px; the grass reads as soft horizontal streaks.
- `01_walker_road` (also last night's `docs/shifts/2026-11-20-night/lanes/combined/stills/01_walker_road.jpg`): the
  bush cluster and the ground in the bottom half are soft; the mesas, far pines and the crane at the horizon are soft
  too.
- The board: everything from the figure's boots to the far mesas and the crane is in crisp focus; only the
  bottom-left rail eases a little. Pebbles, fence rails and pine tiers have clean edges at every distance.
- Sky: the brightest cloud pixels (top 2 % of luma in the top 30 % of the frame) are (252,228,169) on the board and
  (253,216,157) in 07; the top 10 % are (250,207,149) on the board and (248,188,120) in 07.
- GPU (windowed tour, machine shared with three other arms): render gpu p50 1.934 ms diorama, 1.312 ms classic.
- Project: `anti_aliasing/quality/msaa_3d=2`; no anisotropic filtering, FXAA/TAA or scaling keys set in
  `engine/project.godot`.

## This round
The owner's first complaint is blur and low fidelity. COMMON.md § Sharpness sets the bar: the subject, the near ground
and the middle read sharp at 1920x1080; any lens blur is a gentle accent at the far edge; clean edges; textures not
smeared. Sharpness first; then, if time remains in the round, the next biggest gap you see between the shots and the
board inside your scope (frame and figure). How you get there is your design.

Time box: about 75 minutes (finish by about 12:05). Integration is at 13:30.

## Rules (from COMMON.md and TEAMS.md; hard)
- Work only in this worktree. Read-only git is fine; **do not commit**, no git that writes.
- Your scope only (TEAMS.md "Astra arm"). Surfaces, terrain, nature, kit, material response, `toon.gdshader` and the
  `material()` part of `tl_style.gd` belong to your partner (dio-fable, another worktree). If you need something from
  them, write it in `docs/shifts/2026-11-20-day/lanes/dio-astra/PATCHES.md`.
- In `style_diorama.json` add or change keys only in the sections you own (sun, env, fog, sky, clouds, ink, grade,
  lights, miniature_lens, figure); never reorder or reformat the others.
- No file under `engine/packs/**`, `engine/seeds/**`, `contracts/**` changes. `TL_STYLE=classic` must render exactly as
  before (identical or within 1/255). No game's state hash moves. Kernel v1 signatures kept.
- `engine/project.godot` render settings are shared with your partner: if you change one, say so in your notes.
- New selftest cases only as `engine/tools/selftest.d/62N-*.sh` (620-629).
- Never kill a process you did not start (other arms run Godot and Codex on this machine). Prefer `--headless`.
- Windowed captures wait for one machine-wide window lock (four arms + Director); do headless work while you wait.
  Raw captures stay under `.tl/` (use `.tl/astra-r1/`).
- Godot: `C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe` (TL_GODOT). The class
  cache is built.

## Tools
- Shot set: `bash docs/shifts/2026-11-20-day/lanes/dio-astra/shotset.sh <diorama|classic> <out dir> [tour flight figure games]`
  (the tour alone is `... diorama .tl/astra-r1/x tour`).
- Sharpness: `python .tl/sharp.py <before dir> <after dir>`.
- Gates (COMMON.md § Gates): `node devx/bin/tl.mjs check --tier fast`; `bash engine/tools/selftest.sh style.`;
  `bash engine/tools/selftest.sh rig.`. I re-run every gate and every still myself.

## At the end of the round
Write `docs/shifts/2026-11-20-day/lanes/dio-astra/ASTRA-NOTES.md` (append a "Round 1" section): what you changed and
why it moves toward the board, the files, your own before/after measurements, costs, and anything unfinished. End
with a short summary in your final message.
