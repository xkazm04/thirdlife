# Lane B, pass 2: close the gap to the references

Pass 1 is accepted: the Director re-ran `tools/g.sh all` (151 s, clean), looked at the frames and saved your report at
`spike/lab/b/REPORT.md` with a verification section at the end. Read that section first: it lists what the Director saw.
`BRIEF-COMMON.md`, `SCENE.md` and `BRIEF-B.md` stay binding except where this file amends them.

Pass 1 proved the look is **cheap and coherent**. Pass 2 answers the harder question: **how close to the concept art can
this pipeline get, and what does each step of closeness cost?** Your own rubric is the work list: material richness 2,
character appeal 3, destruction 3, "shipped indie game" 3. Raise those; do not spend time on what already scores 4-5.

## Answers to your six questions
1. **Report:** the harness blocks you from writing report files. Keep journaling in `JOURNAL.md` (that works) and return the
   pass-2 report as text in your final message; the Director saves it. Do not try other filenames to get around the block.
2. **Hero composition: amend the contract.** You may move the **house** (and its yard) and re-place the hero camera so the
   avatar is about 35-45% of frame height with arena, circuit and house all in frame, as in `ref/B_toon_ink.png`. Arena,
   circuit and wall positions stay. Record the new house coordinates in the journal and the report.
3. **Bots:** yes. Scale up to about 1.1-1.2 m, add a hard hat or beacon light that reads at 90 m, and make the work flash
   and sparks visible in the hero. The construction site is the game's signature; bots must read from the ridge.
4. **GDScript-only, rigid-part biped:** accepted for this look test, and the finding (no Blender round trip needed for kit
   parts) is valuable. Add the missing Shoulder and Toes bones only if it is cheap; the production rig is a later decision.
5. **Extra `--stats` keys:** fine, keep them.
6. **Hand-driven check:** the owner will play it. Your part: an automated input-driven test (`tools/g.sh play_test`) that
   injects the real input actions (walk off the ridge into the valley, orbit the camera to both pitch limits, fire
   `site_advance`, `nitro_pass`, `crumble`, then `reset`) and asserts by state, not by eye: avatar moved and is on the
   ground, pitch clamped to 30-60 degrees, rib state advanced, wall chunks awake then baked, and after `reset` every one of
   those is back to its initial value. Print one PASS/FAIL line per assertion. Also give the avatar collision with props.

## Work list, in priority order
1. **Material richness (the biggest gap).** A drawn surface language without hand-painted textures: procedural, per
   material class, driven by `style.json`. For example wood grain and plank lines, concrete panel seams and speckle,
   steel plate seams and rivet dots, tarmac wear and skid marks, grass stroke clumps, ice scratches; ink with **two line
   weights** (heavier silhouette, lighter creases); hatching that reads as drawn shadow, not as noise; a gouache/paper
   grain in the grade. Use triplanar or object-space mapping so parts need no UV work. Each material class is data: a new
   material must be a few lines of JSON, not a new shader. Show before/after on `site` and `avatar`.
2. **Characters.** Avatar: better proportions, hands with a thumb shape, a face that reads from the front, hair as larger
   calmer shapes (the spiky cone cluster reads harsh), bevelled/rounded parts where a real toy would be rounded, a little
   secondary motion (backpack, hair, tablet glow), feet in frame in the `avatar` capture. Bots: per answer 3, plus a second
   colourway so a crew reads as individuals.
3. **Hero frame as key art.** Per answer 2, plus terrain interest in frame (a cliff edge, the river and a bridge or
   waterfall, mesa silhouettes behind), clouds with shape instead of streaks, warm window light spilling onto the ground,
   a bounce/gradient term so shade is not one flat violet. The chimney smoke currently reads as floating stones: fix it.
4. **Site density from the kit.** Signage, flags, light masts, material stacks, fencing, a site cabin, stadium detail
   (scoreboard, entrances, lights), tyre stacks and marshal posts on the circuit: all as kit parts with parameters, placed
   by layout data. Keep counting triangles and draw calls.
5. **Destruction.** Replace the lattice fracture with irregular slabs (a seeded Voronoi-like or plane-cut pre-fracture made
   at build time), exposed rebar or a darker core material, dust that reads as dust (lighter, translucent, fading) and
   not as boulders. Still pre-fractured, still baked after sleep.
6. **Reusability proof (the product question).** Build a **second layout from the same kit with data only**:
   `--layout=alt` loads a different layout file with a smaller rink of a different shape or orientation, a different
   circuit and other positions. No new kit code for it. Capture `hero` and `site` for the alt layout and report exactly
   what the layout file could and could not express. This is the closest thing in this spike to "a builder agent
   assembles a new game from parts".
7. **Scaling debts, only as far as they are cheap:** merge static meshes per site, reduce shadow draw calls (report the
   before/after from `--stats`), clamp style ranges so a bad style file cannot break the look.

## Outputs
- The same acceptance set as pass 1 must still pass (`tools/g.sh all`), plus `play_test`, the alt-layout captures
  (`b_alt_hero.png`, `b_alt_site.png`) and a `captures/b_pass2_compare.png` sheet placing pass-1 and pass-2 `hero`, `site`,
  `avatar` and `crumble` side by side (pass-1 originals are in `captures/builder_orig/`: read-only, do not overwrite).
- Journal after every completed step; ledger rows for pass 2 kept separate from pass 1.
- Final message: status, capture paths, the perf one-liner, pass-2 ledger totals, the **rubric re-scored with evidence**
  (and say plainly where a score did not move), what the alt layout proved, the list of what is still weaker than the
  references and why, and the pass-2 report text for the Director to save.

## Time-box and safety
Until acceptance of this list or **19:45 CEST today**, whichever comes first; stop building by about 19:15 and use the rest
for captures, stats, `play_test` and the report text. If you are cut off by the usage limit again you will be resumed:
the journal is the resume point, so keep it current. Work only in `spike/lab/b/`; no git; never kill processes you did not
start (another session runs Godot tests for a different project on this machine: leave them alone, and treat fps numbers
taken while they run as indicative; `gpu_ms` is the steadier figure).
