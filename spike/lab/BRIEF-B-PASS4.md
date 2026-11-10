# Lane B, pass 4: density, contrast, and the layout contract (fresh builder)

You are a **new builder taking over lane B** of the Third Life art-feasibility spike. Three passes are done and verified;
you continue. You have no memory of them, so read, in this order, before touching anything:

1. `spike/lab/BRIEF-COMMON.md` (rules for every builder) and `spike/lab/SCENE.md` (the scene contract).
2. `spike/lab/b/REPORT-PASS3.md`: read the **Director verification** section at the end first (it is your defect list),
   then the builder report above it. Skim `REPORT-PASS2.md` only if you need history.
3. `spike/lab/b/README.md`, `KIT.md`, `tools/g.sh`, the PASS 3 part of `JOURNAL.md`, then the source you need.
4. Images, as half-size sheets that already exist in `spike/lab/b/captures/director/`: `pass3_ref_vs_hero.png` (concept
   on the left, our hero on the right: **this is the gap you are closing**), `p3_main.png`, `p3_c.png`, `p3_avatar.png`,
   and `captures/b_avatar_faces.png`.

All rules of BRIEF-COMMON hold: work only in `spike/lab/b/`, **no git commands at all**, no network, never kill a process
you did not start (other sessions run Godot tests and a GPU benchmark on this machine), kill every process you start,
journal as you go. Do not open an interactive window.

**Context discipline:** look at images as half-size contact sheets except when judging fine detail; grep before you read;
do not dump whole source files. If your context is getting full, stop at a clean point with the journal current and
return what you have.

Before you change anything, copy the current frames to `captures/pass3_orig/` (`captures/builder_orig/` and
`captures/pass2_orig/` are read-only).

## Part 1: the layout contract (do this first; it is the product question)
Pass 3 showed that a layout file written with the code frozen could express where things are but not most quantities.
Seven edits widened it. Now make the contract explicit and test it properly.

1. Write `LAYOUT.md`: every key the three layout files may use, its type, default, range, and one line on what it does;
   then a plain list **"what a layout cannot express"** (stand side, road width and banking, car count, skating bots,
   and whatever else you find by reading `world.gd`, `sim.gd`, `look.gd`).
2. Write a validator, `tools/g.sh validate <layout>` (GDScript run headless is fine): unknown keys, wrong types, values
   out of range, props that name a kit part that does not exist, cameras missing. It must pass on `layout.json`,
   `layout_alt.json`, `layout_c.json` and fail with a readable message on a deliberately broken copy. Unknown keys must
   be an error, not ignored: a silent typo is the failure this exists to catch.
3. **Layout D, the honest test.** Freeze `src/` and `shaders/` (record a hash). Then write `data/layout_d.json` using
   **only `LAYOUT.md`** as your reference, not the source, for this brief: *a lakeside training camp: two small rinks side
   by side, one of them half-built with holograms, a short kart track looping around a hill, one house on the shore, a
   crane, a watch tower.* Run the validator, the hero/site/track captures and the play test. Report every place the
   brief could not be expressed, what the validator caught, and whether anything crashed. Do not edit code to rescue it:
   list the edits it would need, with a line estimate each. (You may fix code afterwards as a separate, clearly marked
   step if time allows, as pass 3 did.)

## Part 2: close the gap to the concept (see `pass3_ref_vs_hero.png`)
1. **Contrast and saturation.** Our frame sits under a violet haze; the concept is crisp and saturated with dark ink.
   Fix it in `data/style.json` (grade, fog, shade colours), not in code, unless a parameter is missing. Show before/after.
2. **Density in the hero**, all from layout data and existing kit parts where possible: a second crane, more scaffolds
   and material stacks, bots that read at hero distance (move the work closer to the camera side of the rink, or raise
   beacon size; do not just scale bots up again), a fence line and rocks along the track, cliff faces with drawn strata.
   Count triangles and draw calls before and after.
3. **Light pools** are hard-edged yellow discs (porch, avatar in the alt hero, mast). Make them read as light: soft or
   three-band falloff, tinted by the surface, no visible disc edge on grass.
4. **Face** (`b_avatar_faces.png`): eyes level and symmetric, a mouth that is a shape and not a row of blocks, even
   cheeks, a blink that closes fully. Keep the rig and bone names.
5. **Track frame**: it is the weakest capture. Give the road surface, verge and foreground something to look at
   (kerb detail, tyre marks that read, a marshal post or signage in frame), and remove the tree shadows that fall from
   nothing visible, or put the trees in frame.
6. Small: make `BUSY_EXE` in `tools/g.sh` default to empty and document it in `README.md`; in the layout-C hero the avatar
   hides the rink and one house sits below the ridge lip (fix in `layout_c.json` only).

## Outputs
- `tools/g.sh pass3` still passes with no ERROR / leaked / FAIL line; add a `pass4` target that also runs the validator on
  all layouts and the layout-D captures and play test.
- `captures/b_pass4_compare.png`: pass 3 against pass 4 for hero, site, track, avatar front. A second sheet
  `captures/b_pass4_ref.png`: `../ref/B_toon_ink.png` beside the new hero.
- Journal after every completed step; a separate pass-4 ledger (work, minutes from real timestamps, rounds).
- You cannot write report files (the harness blocks names like REPORT; `LAYOUT.md` is documentation and is allowed. If it
  is blocked, put the content in `README.md` under a "Layout contract" heading and say so). Return the pass-4 report as
  text in your final message: status; Part 1 findings (what the validator catches, what layout D could not express, the
  edit list with line estimates); capture paths; perf one-liner with draw calls and triangles before/after; the rubric
  re-scored with evidence, saying plainly where a score did not move; what is still weaker than the concept; ledger
  totals; questions.

## Time-box
Until this list is done or **19:40 CEST today**, whichever comes first. Stop building by about 19:15 and use the rest for
the acceptance run, stats and the report text. Order if time runs short: Part 1 (all three steps), then Part 2 items
1, 2, 3, 4, 5, 6. The usage limit can cut you off without warning: the journal is the resume point, so keep it current.
