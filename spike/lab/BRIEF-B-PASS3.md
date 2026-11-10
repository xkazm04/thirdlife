# Lane B, pass 3: fix what is hidden, then finish the look (fresh builder)

You are a **new builder taking over lane B** of the Third Life art-feasibility spike. The previous builder ran two passes and
stopped because its context filled up. Nothing is wrong with the work; you continue it. You have no memory of it, so read,
in this order, before touching anything:

1. `spike/lab/BRIEF-COMMON.md` (rules for every builder), `spike/lab/SCENE.md` (the scene contract), `spike/lab/BRIEF-B.md`
   (the direction), `spike/lab/BRIEF-B-PASS2.md` (what pass 2 was asked, including contract amendments).
2. `spike/lab/b/REPORT.md` and `spike/lab/b/REPORT-PASS2.md`: the builder's reports, each ending with a **Director
   verification** section that lists what the Director saw in the frames. That section is your defect list.
3. `spike/lab/b/JOURNAL.md`, `KIT.md`, `README.md`, `tools/g.sh`, then the source in `src/`, `shaders/`, `data/`.
4. The references in `spike/lab/ref/` (`B_toon_ink.png`, `E_painterly_gouache.png`, `A_lowpoly.png`) and the current
   `captures/b_hero.png`, `b_site.png`, `b_crumble.png`, `b_avatar.png`, `b_alt_hero.png` (use the Read tool).

All rules of BRIEF-COMMON hold: work only in `spike/lab/b/`, no git, no network, never kill a process you did not start
(another session runs Godot tests for a different project on this machine), kill every process you start, journal as you go.

**Context discipline (the last builder ran out):** look at images as half-size contact sheets (ffmpeg `scale` + `hstack`)
except when judging fine detail; do not dump whole source files you do not need; grep before you read. If you notice your
context getting full, stop at a clean point, make sure the journal is current, and return what you have.

## Part A: engineering honesty (do these first; they are cheap and they are hiding information)
1. **Exit-time leaks.** `tools/g.sh` filters Godot's exit errors through a `NOISE` pattern. Raw, they are: 8 meshes, 23
   materials, 2 shaders, 8 scene instances and 41 ObjectDB instances leaked, "2 resources still in use at exit". They
   appeared in pass 2. Find the cause (likely static/cached resources or nodes freed after the renderer, e.g. the merge,
   the style autoload or cached materials), fix it, and **remove the filter**. If a remainder is a Godot quirk, say which
   lines and why, and filter only those exact lines.
2. **Movie slowdown.** `g.sh movie` went from about 36% of real time in pass 1 to about 8% in pass 2 (4 min 26 s for 20 s).
   Find what changed (bisect with the pass-2 features: paper grain, hatch, part-local channel, lights, translucent dust,
   merge) and fix or explain it. Target: `g.sh all` back under about 3.5 minutes. Check whether the same cause costs
   frame time in normal play (`gpu_ms` rose from 1.43 to 1.60).
3. **Run the play test and all five cameras on the alt layout** (`--layout=alt`), which was never done. Fix what breaks.
4. Regenerate `b_map.png` (it still shows pass 1) and view the overcast frame, which nobody has looked at since the clamp
   ranges changed it (`fog.density` and `fog.height_density` are now clamped).

## Part B: visible defects (from the Director's verification)
1. The "waterfall" is a pale pixelated rectangle on the mesa. Make a real one that reads as falling water in this ink
   style, or remove it. Better: bring the **river, a bridge and the ridge's cliff edge into the hero frame**.
2. Crumble dust is a bright white cloud hiding the break. It must read as dust (thin, warm, fading within about a
   second) and the broken slabs, core faces and rebar must stay visible at t=1.5 s.
3. Hero framing: the timber-frame extension is cut by the right edge; only one car is visible; bots are still small.
   Adjust layout data and camera, not the kit.
4. In `b_avatar.png` the moved house's roof pokes up through the ridge grass behind the avatar. Fix the terrace or the camera.
5. Ground hatching shows as dark dashes on foreground grass. Hatching should read as drawn shadow in shade only.

## Part C: the remaining look gaps
1. **Lighting.** Shade is one flat colour per band. Add, as style data: a sky/ground ambient gradient by surface normal,
   a cheap warm bounce on surfaces facing lit ground, and visible warm spill from the house windows and site lights onto
   nearby ground. Goal: atmosphere/lighting from 4 to 5 without losing the flat-band toon identity.
2. **Avatar.** Truly rounded forms where a toy would be rounded (rounded-box and capsule generators in MeshKit, reused by
   bots and cars), a face with at least blink and two expressions driven by a parameter, visible fabric class on the
   jacket. Keep the rig and bone names. Capture front, 3/4 and back.
3. **Material richness at distance.** The surface language is subtle beyond about 30 m. Make it carry at hero distance
   where it matters (roof, road, arena concrete, wood) without turning into noise; show a crop comparison.

## Part D: the product question (do not skip; it matters more than polish)
1. **One material for the whole palette** (colour/material class through a vertex channel or a small lookup), so the
   static world is a handful of draw calls per shadow cascade. Report draw calls and `gpu_ms` before and after, and what
   it cost in flexibility.
2. **A third layout written after the code is frozen.** When Parts A-C are done, commit to not editing `src/` or
   `shaders/`, then write `data/layout_c.json` for a deliberately different brief: *an outdoor pond-hockey rink without a
   roof beside an oval speedway with a long barrier wall, a village of three houses, no cranes, a dense forest edge*.
   Run `--layout=c` hero/site/track captures and the play test. Report honestly every place the layout file could not
   express the brief and what code change it would have needed. **If you had to edit code, say so and list the edits**:
   that list is the finding, not a failure.

## Outputs
- `tools/g.sh all` passes (and `g.sh alt`, `play_test` on main and alt, the layout-c captures), with the noise filter gone.
- `captures/b_pass3_compare.png`: pass 2 against pass 3 for hero, site, avatar, crumble. Copy the current pass-2 frames to
  `captures/pass2_orig/` **before you change anything** (`captures/builder_orig/` holds pass 1: read-only).
- Journal after every completed step; a separate pass-3 ledger (work, minutes, rounds).
- You cannot write report files (the harness blocks it; do not try other names). Return the pass-3 report as text in your
  final message: status; what Part A found (causes, not symptoms); capture paths; perf one-liner and the before/after
  table; the rubric re-scored with evidence, saying plainly where a score did not move; what layout C proved and the list
  of code edits it needed, if any; what is still weaker than the references; pass-3 ledger totals; questions.

## Time-box
Until this list is done or **19:45 CEST today**, whichever comes first. Stop building by about 19:15 and use the rest for
captures, stats, play tests and the report text. Order if time runs short: Part A, Part B, Part D, then Part C.
The usage limit can cut you off without warning: the journal is the resume point, so keep it current.
