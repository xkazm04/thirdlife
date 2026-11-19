Lane wings (evening 19 Nov 2026): wings summoned by magic, not worn
Worktree .claude/worktrees/e19-wings, branch e19-wings from main 2950f03. Uncommitted; the Director lands.
Route: Astra (gpt-6.2-astra, high) designed and built it in one round (session 01a1f501-6dfe-7db3-818b-03805e27fe48,
254 k tokens, 19:11-19:52). The Opus operator re-ran every gate, took the clip and stills, and wrote this report.
I passed nothing back: no gate I ran failed.
VERDICT: landable.

WHAT IT IS
- The visitor walks with nothing on his back: no wings and no backpack.
- F summons the wings. A cyan four-point star opens between the shoulders. Two strokes sweep outward, and a bright nib
  "writes" the harness, the spars and then the twelve plates, each from hinge to tip, with sparkles. It reads as an
  inscription, not as a pop or a fade.
- Landing folds the wings first (36 ticks), then the same spell runs backwards (36 ticks) and the back is bare again.
  F in the air starts the fall at once, and the fold and the dismiss run together for 36 ticks.
- A pack biped with walker feel that calls fly() gets the same summon and dismiss on its back socket.
- Built through the style layer: TLStyleFx._wing_sigil plus a WingSigil node in engine/style/tl_style_fx.gd, a new
  shader engine/style/shaders/wing_sigil.gdshader, and a TL_WING_CAST define block in toon.gdshader. The define is
  compiled only into the wing-cast variant, so the normal toon shader is unchanged.

TIMING (ticks at 60 Hz)
- Summon: 36 ticks (0.60 s). The joints reach full spread on tick 30 and the last glint goes on tick 36.
- Take-off delay: 0 ticks. Flight starts on the F tick as before, and the wings are written while he lifts. So no case
  expectation moved.
- Landing: fold 36 plus dismiss 36, so the back is bare 72 ticks after touchdown. Air release: 36 ticks.
- In my road clip, F is pressed on tick 102, the summon ends on tick 137, touchdown is about tick 349, and the back is
  bare by tick 421.

ACCEPTANCE
1. Windowed clip of 20 s or less: MET. The operator took it.
   lanes/wings/clip-summon.mp4: 8.5 s, 1280x720, 60 fps. He walks bare-backed, presses F, the summon plays, he flies,
   lands, folds, the dismiss plays, and he walks on. Recorded with world.sh visit-test, the day flight lane's
   wf_flight.json and Astra's .tl/wing-review/final.devices.json, with TL_WINDOW_ARGS=--write-movie. The raw avi is
   .tl/op/clip.avi.
2. Stills, close up and in the world: MET. The operator took them.
   - sheet_close.jpg: 12 close-ups (ticks 10-141) from .tl/wing-review/review.gd: bare back, the star, the strokes, the
     plates, full span, folding, folded, the reverse spell, last stroke, bare back again. I ran the windowed render
     twice and 20 of 20 frames were byte-identical.
   - sheet_road.jpg: 10 frames from the clip run, seen from the road (ticks 51-448), summon row and dismiss row.
3. Permanent case in 540-549: MET. engine/tools/selftest.d/540-wings-summon.sh, flight.wings_summon:
   PASS flight.wings_summon (frames=144 summon=36 land_fold=36 land_dismiss=36 air_dismiss=36 errors=[])
   It checks:
   - the visitor draws no wing mesh before F and wears no backpack;
   - a real TLBiped with walker feel: nothing drawn before fly(); all 17 parts drawn and k=1 at the end of the summon;
     the parts stay drawn through the landing fold; the dismiss phase per tick; nothing drawn after the dismiss and
     after an air release; an interrupted summon reverses its progress and does not jump;
   - two runs give identical transforms, visibility and shader parameters over all 144 frames (determinism).
   Astra reports that the case fails on 2950f03, as it should. I did not re-run it on main.
   Gap: the visitor's bare back after a dismiss is checked through the pack biped, which uses the same FlightWings
   code. The case does not check it on the visitor itself.
4. Gates: MET. The counts are not below main's.

GATES (my runs in this tree, 20:00-21:05)
- selftest flight.: 13 passed, 0 failed. Main has 12 (the day reports say "flight. 12/12"; the day verdict's
  "13/13" is a slip). The 13th is the new flight.wings_summon.
- selftest moves.: 14 passed, 0 failed, the same as main.
- (My first two selftest runs passed the filter as an env var, which selftest.sh ignores, so they ran the whole kernel
  selftest: 318 passed, 0 failed, twice.)
- tl check --tier fast: PASS 5/5: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck clean.
- tl check --tier full: PASS 14/14 steps, 1192/1192 units, flaky_retries 0, exit 0.
    arch 12/12 | assets 4/4 | cards 3/3 | devx.test 229/229 | foreman.typecheck clean
    foreman.test 223/223 (217 pass, 6 skipped) | kernel.selftest 318/318 (main 317) | kit 95/95
    packs 2/2, verb runs 48/48 | perf 2/2 (it ran: quiet machine, use 16 %) | seeds 39/39 | item 91/91 | ui 166/166
    world 8/8 (world = alone)
  --only world,packs is inside the full run: world 8/8, packs 2/2 (48/48).
- foreman.test skipped 6 where main skipped 5. This is the environment, not the change. The extra skip is n3.test.ts
  "4 verbs: the second real job's FIRST Planner output ...", which skips when site/_engine_snapshot3 is missing. That
  folder is gitignored job output: it exists in the main checkout and not in this worktree. The lane does not touch
  foreman/, devx/ or contracts/. Astra ran that one test on its own against the archived snapshot: tests 1, pass 1
  (.tl/foreman-historical-case.log). After landing, the main checkout runs it as before.
- State hashes: no gate moved a hash. Astra also compared against 2950f03: 46 of 46 pack hashes, 48 verb rows and 8
  world rows matched (.tl/wings-compare.log). I did not redo that comparison by hand. The gate's own checks (packs bot
  hashes, world = alone) passed.

CHANGED FILES (all inside the brief's scope)
- engine/kernel/world/flight_wings.gd: hidden until summoned; a 36-tick reversible cast clock; fold before dismiss;
  an air release.
- engine/kernel/world/visitor.gd: the rig is built with backpack=false; it passes fly_end to the wings.
- engine/kernel/api/tl_biped.gd (wings part): attaches FlightWings on the first fly_start and ticks it. Also see
  behaviour change 2. Three blank-line deletions and one comment rewording came with it, harmless.
- engine/style/tl_style_fx.gd: _wing_sigil() and class WingSigil.
- engine/style/shaders/wing_sigil.gdshader (+ .uid): new. engine/style/shaders/toon.gdshader: a TL_WING_CAST block.
- engine/tools/selftest.d/540-wings-summon.sh: new.
- docs/shifts/2026-11-19-evening/lanes/wings/: STANDUP.md, REPORT.txt, REPORT-astra-r1.txt (Astra's own report),
  clip-summon.mp4, sheet_close.jpg, sheet_road.jpg.

BEHAVIOUR CHANGES (named)
1. The visitor no longer wears the lane-B backpack or the folded wings while walking. This is the brief: "nothing on
   its back".
2. Every TLBiped with walker feel is now built with backpack=false, unless the pack sets rig_params.backpack itself.
   This applies even to a pack that never flies. Among tracked packs only parkour uses walker feel, and it already sets
   backpack:false, so no tracked game's look changes. A Foreman or site pack with walker feel and no backpack setting
   would lose its backpack. This goes a little beyond "a pack biped that flies". Director: keep it, or limit it to
   flying bipeds.
3. A walker-feel pack biped that flies now shows the wings. Before this lane, TLBiped drew none. It is presentation
   only, and the hashes are unchanged.

FOR THE OWNER TO LOOK AT
- Watch clip-summon.mp4, then sheet_close.jpg. In a window: bash engine/tools/world.sh visit compact_village, then F,
  Space to climb, F in the air, or land.
- Judge two calls: he lifts while the wings are still being written (no wait), and on touchdown the fold runs before
  the dismiss (1.2 s in all).

QUESTIONS FOR THE DIRECTOR
- API.md belongs to the hud lane. Astra's suggested line for the Flight paragraph: "Walker-feel bipeds with a back
  socket summon the visitor's wings on take-off. Landing folds and dismisses them. Ending flight in the air dismisses
  them during the fall." Also name the backpack default (change 2) there if you keep it.
- Behaviour change 2: keep it, or limit it to flying bipeds?

NEXT THREE THINGS THIS LANE WOULD DO
1. Add the visitor-after-dismiss check to case 540 (the gap in acceptance 3).
2. Check the exported exe: summon and dismiss in dist/ (export.sh check plus a windowed run).
3. If the owner wants it: a short take-off hold (about 12 ticks) so the first strokes are seen before he lifts. The
   ticks would be named and the flight cases re-checked.
