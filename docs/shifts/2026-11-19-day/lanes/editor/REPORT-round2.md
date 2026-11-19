Lane editor, round 2 (day of 19 Nov 2026): report, done at about 12:55
Worktree .claude/worktrees/d19-editor2 (branch d19-editor2, from main a68ef16). Nothing is committed.
Route:
- Astra (codex gpt-6.2-astra, high) built tasks 1 and 2 and the map redraw, in one session,
  01a1f363-bcce-7412-a586-38dea87138fa.
- I built tasks 3 and 4 myself.
- I re-ran everything below myself.

WHERE TO LOOK
1. clip-village-round2.mp4 (13.0 s). The 3D village, the lot the player chose by the river:
   - the crane stands on open ground, with no round fence;
   - the game arrives;
   - the camera comes down to the gate: two short rails, the arch, the sign;
   - the pad sits on the land.
2. stills/round2/:
   - before_ and after_ pairs of the site, built and arrived, from above and from the road (main a68ef16 against
     this tree);
   - map_before_after.jpg: the workbench map, fenced circles against footprint pads like the village;
   - measured_no_model_call.jpg: Find a place with no model call;
   - words_small_ice_no_stands.jpg.

TASKS
1. The last circle: DONE (Astra, verified).
   - site/draw.gd draws no round fence any more. Two short rails stand either side of the entrance, as the plots
     have them (same offsets and lengths as landscape.gd), with 1.2 m colliders.
   - The gate path, the sign, and the arrival arch and masts stay.
   - Test changes: the site mesh `site_fence` became `site_rails`, and two entrance walls replaced the ring of
     colliders.
   - New case: site.no_ring (block 501) checks the worker-built mesh, both walls, their height and the path, before
     and after a refit.
2. Pad height at a moved lot: DONE (Astra, verified).
   - What changed: when a lot moves (from the job log or the draft), site.gd computes the land's height at the new
     centre from files only. `_base_terrain` mirrors landscape.gd's box rule with the same VillageTerrain.base_h;
     landscape.gd is not edited.
   - Who uses that height: the pad, the site node and the reserved game plot. The log line is
     `[site] lot k: pad h 2.0 -> 0.37 m (the land at the new centre)`, and the report gains `pad_h`.
   - Agreement: for the probe lot at (-207, 44), the site gives 0.369039661 m. In a window, the landscape's own
     automatic pad for the same lot without `h` is 0.369039661 m. The difference is under 1e-9 m.
   - Lots that do not move keep their h.
   - Hashes: all nine packs keep their state hashes and tick counts over a 1,100-tick headless walk.
   - New case: site.editor_pad (block 501). At (-225, 68) the land is 5.558897 m; the moved pad is 5.558897 m and
     the stationary pad stays at 1 m.
3. Place calls into the job: DONE (me).
   - `foreman new --place-calls <json>` takes a list of 1 to 20 calls, each {adapter, model, durationMs, tokensIn?,
     tokensOut?}. It is checked before anything is written; a bad value is a usage error and writes nothing.
   - Each call is logged as a job-level `builder_run` (no package, no round), mode generate, outcome ok, right after
     billing and before the Designer's run.
   - No contract change: JOB.md already allows job-level builder runs, and tl ledger sums builder_run tokens.
   - In the editor: each answered "Find a place" call's figures are kept (also in the draft as `place_calls`) and
     passed on Build it as a json64 argument. An answer that has no figures is not recorded.
   - Proof:
     - foreman/src/test/place_calls.test.ts: 3/3;
     - the ui selftest cases for record_call and the door's argument;
     - `ui.sh place` reads the new job and fails unless the call is logged: "place calls logged in the job: 1,
       tokens in 3200, out 260";
     - `tl ledger` on that job: 7,000 in / 1,460 out, the place call included.
4. The Designer only when the words matter: DONE (me), measured.
   - "Find a place" asks the Designer only when the idea names something about the place. The list is
     place_panel.gd PLACE_WORDS, 41 phrases (quiet, river, near, next to, beside, far from, hill, middle, north...),
     matched as whole words.
   - Otherwise the editor offers its scorer's top three measured places, each reason built from its facts (the walk,
     then the nearest neighbour). There is no model call and nothing is logged.
   - Why: on neutral requests the real Designer had picked exactly the scorer's top three in 9 of 9 runs (round 1,
     final weights).
   - Saved per neutral click: about 5.3k tokens in, 0.6k out and 8-10 s. One real-Designer place call cost 5,296 in
     and 581 to 678 out.
   - With place words, the real Designer through the UI ("ice hockey, three against three by the river") gave 2
     valid places, best 72.4 (5,296 in / 678 out / 9.3 s). Its reasons name the river.
   - Proof: a selftest case for the word detector (6 neutral and 5 placed sentences, all right), and one that the
     measured proposals equal the scorer's top three.
   - Drives:
     - `ui.sh place` (place words, the fake Designer, the call is logged): passes;
     - `ui.sh place --measured` (no place words: three valid places, no call, none logged): passes.
   - The drive's idea now reads "...three against three by the river", so it still asks the Designer.

ALSO DONE (beyond the four tasks)
- The workbench map now draws the village the blend lane built (Astra, verified).
  - Board, workbench and game sheet: games on footprint-shaped pads with spurs and entrance rails; no fenced
    circles.
  - While placing, a faint dashed edge shows at r + 3.6 m. The fit rule is unchanged (2 m between lot edges).
  - No word says "fence": "its edge would cross paddle's by 2 m", "next to paddle (4 m between lots)", and the
    placer prompt says the same.
  - Eight expectations moved for these words only:
    - selftest_place.gd: the path through parkour, the 5.6 m and 9.2 m gaps, road, river and bounds;
    - selftest.gd: the hockey overlap;
    - drive_editor.gd: the refused drag.
  - 39 before/after capture pairs in the worktree's .tl/b-shots/.
- team_possession card 0.2.2: rink and dressing options gained `from_words` (small ice, big ice, no stands, just the
  boards, stands, scoreboard, crowd). "small ice, no stands" used to stay at Standard with stands; it now sets small
  and bare. `tl cards check` PASS.

GATES (this tree, 12:20-12:48)
- tl check --tier full, exit 1:
  - PASS: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck, foreman.test 222 (216 pass,
    0 fail, 6 skipped; 219 on main, +3 mine), kit.selftest 92/92, packs 2/2 (44/44 verb runs), seeds 39/39,
    item.selftest 91/91, ui.selftest 165/165 (main 160), world 8/8 (world = alone).
  - NOT RUN: perf (machine busy, use 100 %).
  - FAIL: kernel.selftest, 286 of 293. NOT this lane's: all 7 failures are flight.* cases from one run, and one
    measurement fails in it: `FLIGHT collide FAIL ... trunk=-inf` (the case finds no tree trunk). I ran
    kernel/runner/flight_case.gd on a git archive of HEAD a68ef16 without my changes: the same line. So it is on main
    since blend and flight both landed. Blend's slope test moves the trees, and flight's collide case looks for a
    trunk. The other flight cases print PASS but take the process's exit 1.
- site.: 16/16 (14 on main; + site.editor_pad, site.no_ring).
- world.: 16/16. blend.: 2/2.
- --only world,packs: world 8/8 and packs 2/2 inside the full run above.
- ui drives (fake): place, place --measured, editor, home all ok. Place with the REAL Designer (--any-places
  --no-build) ok.
- fast tier: PASS 5/5.

CHANGED FILES
- engine/kernel/world/site.gd (pad height: `_base_terrain`, `pad_h`).
- engine/kernel/world/site/draw.gd (entrance rails, no ring); new site/fixtures/no_ring.gd and its .uid.
- engine/tools/selftest.d/501-editor-site.sh (new).
- foreman/src/cli.ts and cli_args.ts (--place-calls); foreman/src/test/place_calls.test.ts (new).
- foreman/prompts/placer.md (words).
- engine/ui/foreman_door.gd (place_calls argument).
- engine/ui/selftest.gd.
- engine/ui/editor/: place_panel.gd, editor_model.gd, workbench.gd, drive_editor.gd, selftest_place.gd, lot_scorer.gd,
  village_map.gd, map_base.gd, map_overlay.gd, map_landscape.gd, village_board.gd, game_sheet.gd, scale_strip.gd,
  workshop_art.gd.
- engine/cards/team_possession.json.
- engine/ui/JOURNAL.md.
- Lane folder: STANDUP.md, REPORT-round2.txt, clip-village-round2.mp4, stills/round2/ (11 JPGs).

BEHAVIOUR CHANGES
- A moved lot's pad sits at the land's height at its new centre. Before, it kept the walk lot's h. This moves the
  arrived game's plot origin y for that lot only; no pack's own hash moved.
- The site has no ring of fence colliders: the visitor can walk onto a construction lot from any side, as onto the
  plots since blend.
- A neutral "Find a place" calls no model. The tooltip and a one-line note under the map say why and how to get the
  Designer: name where you want it.
- The place drive's idea gained "by the river".

PROPOSED FOR JOB.md (Director)
- Today a place call is a plain job-level builder_run, so tl ledger counts it, but nothing in the log says it was a
  placement. Proposal: an optional `role` key on job-level builder_run (designer, planner, critic, placer), so the
  ledger can split cost by role.
- Also name the command `foreman new --place-calls <json>` (the shape above) beside --answers and --lot.

QUESTIONS FOR THE DIRECTOR
1. flight.collide fails on main (above): a rerun alone does not help. Flight's collide case needs its trunk again, or
   a trunk that does not depend on the scenery scatter.
2. The 41 place words are a list, not a model. Some Swedish or Czech words a player types will not match. Keep the
   list, or ask a small model to classify the idea (it would cost a call)?

NEXT THREE THINGS
1. The yaw into the world: an arrived game turned as the player turned it, proved world = alone.
2. A role on job-level builder runs (with the contract), and `tl ledger --by-role`.
3. Walk the exported village as a person past a moved lot at visitor height: the pad, the shoulder, the rails.

CODEX (Astra) TOKENS (one session; codex prints the running total)
- Brief A (site rails, pad height, block 501, stills): 219,261.
- Brief B (the map after blend, the words, 39 before/after pairs): 158,095 (running total 377,356).
- Round 2 total: 377,356. Real Designer calls I made: 1 (5,296 in / 678 out).
