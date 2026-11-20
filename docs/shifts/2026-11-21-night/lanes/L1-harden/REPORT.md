L1 crisp-harden: REPORT (night of 21 Nov 2026)
Worktree .claude/worktrees/n21-harden, branch n21-harden, base main d5967cc (3a4580b + the shift plan). Nothing committed
(the Director lands). Owner's words: "hardening and bugfixing of ... Crisp cel for its physics, objects collisions handling".

SUMMARY
Crisp cel's road rails, the plots' gate signs, the construction sites' signs, bushes and five kit parts are now solid for
the visitor, every way through stays open, and the B2 site fence follows the footprint. A new selftest block (620,
9 cases, headless) guards it. Each case that guards a new collider fails on the base. One pack hash moves, seed.wall,
because a ball meets the kit sign's new shape. The world still hashes as alone, 8/8, under crisp and classic.

ACCEPTANCE
1. Full gate green on the branch; world,packs green under crisp and classic, counts >= base.
   MET, with the split run the Director accepted at 21:15. The single full run cannot finish on this busy machine:
   kernel.selftest is killed at its 1800 s cap on the base too.
   - Base (a clean export of d5967cc, crisp, full gate): arch 12/12, assets 4/4, cards 3/3, devx.test 228/229 (the
     manifest row: inherited, fixed on main as dd1064f), foreman.test 216 pass + 7 skip of 223, kit.selftest 95/95,
     packs 1/2 (hockey invariants.many_budget p50 1.216 ms > 1.0: wall clock on a busy machine), perf PASS, seeds
     39/39, item.selftest 91/91, ui.selftest 166/166, world 8/8.
     kernel.selftest: 317 of 318 found, then killed at 1800 s. blend.car_origin failed (dc9024b: inherited).
   - Base, TL_STYLE=classic world,packs: world 8/8; packs 1/2 (hockey many_budget p50 1.191 ms).
   - Branch, full gate run 1 (crisp; before the B2 code and dc9024b): arch 12/12, assets 4/4, cards 3/3, devx 229/229
     (with my re-scanned manifest, since restored to the base's), foreman 217 + 6 skip / 223, kit.selftest 95/95,
     seeds 39/39, item 91/91, ui 166/166, world 8/8, packs 1/2 (the same hockey many_budget, p50 1.205 ms; A/B with
     the base above: the same failure, wall clock). perf: NOT RUN (machine busy).
     kernel.selftest: 123 of 124, then killed at 1800 s, 0 failed.
   - Branch, kernel.selftest by blocks (final tree; .tl/blocks.sh = selftest.sh with a block filter; the blocks
     themselves are unchanged):
     A (010-269) 161/161; B (270-499) 116/116; C (500-699) 79/79. Total 356 of 356, 0 failed. The base's own full
     run was killed with 318 found, so it has no complete count. selftest.d differs from the base only by the new
     620-harden.sh (+9 cases) and dc9024b's edits of 513 and 580; no case was removed.
     blend.car_origin and surf.model are green with dc9024b applied.
   - Branch, TL_STYLE=classic world,packs: packs 2/2 (48/48 verb runs; hockey many_budget passed this time),
     world 8/8.
   - fast gate (final tree): arch 12/12, assets 4/4, cards 3/3, foreman.typecheck clean, devx.test 228/229. The one
     red is the committed-manifest row, known-red-inherited (the base fails it identically). The manifest is the
     base's, per the Director.
2. Rails, sign and fences block the visitor in a window (a 20 s clip), with headless tests for each. MET.
   - clip-harden.mp4 (19.2 s, 1280x720), with clip-harden-strip.jpg. It is two scripted visits in a window
     (clip.sh + rails_clip / sign_clip walk and devices files, world.sh visit-test, crisp, the compact village):
     - He walks into the north row of rails and is held.
     - He slides along it, goes through a one-in-nine gap, turns, and walks back into the rail from the other side.
     - Then he walks into a plot's gate sign and flag, and is held.
   - Headless (620-harden.sh, each in frames). On the base export with only a test hook added: rails_block,
     gate_sign, site_sign, site_fence, bush_block and kit_parts FAIL. The quoted lines:
     - rails_block: "walked through the drawn rails at 193 of 193 places"
     - gate_sign: "walked through 10 of 10 gate markers"
     - site_sign: "x 5.4: he passed ... x 14.6: he passed"
     - site_fence: "0 stretches of site fence ... from behind he got 20.3 m from the centre"
     - bush_block: "walked into the middle of 50 of 50 bushes"
     - kit_parts: "bush: he passed ...; scoreboard: he stopped ..., want through"
     rail_gaps and spawn_clear pass on the base: they guard what the new colliders must leave open. Their controls:
     - rail_gaps: with the wall left unbroken at the gaps (a one-off mutation, reverted) it FAILS ("could not walk
       through 19 of 19 open spans ... stopped by rail").
     - spawn_clear: carries its own control box at the spawn, which must be found.
     The walk feel is unchanged: 280-walk.sh (walk.* 14 cases) and the walker, flight and moves blocks PASS in chunks
     B and C.
3. Per-part colliders: the parts changed, each kit hash moved and why, the manifest re-scanned. MET, re-scan left to
   the Director, as he asked at 21:05.
   Changed parts (kits/KIT.md "Collision per part"):
   - bush: was none; now a cylinder 0.75 x size by 1.1 x size.
   - sign: two posts and the board.
   - scoreboard: two legs and the board; the way under it is open.
   - marshal_post: four posts, the deck, the back board and the roof.
   - watch_tower: the legs as a hull, the deck, the parapet, the roof posts and the roof hull.
   - unchanged: fence (its box already stopped a walker; the scout's premise was wrong there) and pond water (still
     no body).
   TLKit.hash by tools/assets/scan_kit.gd, both fresh caches, base export -> branch (the other 31 parts identical):
     kit.bush          4e517d6b35a5d39f4e8b4a593ac04b383d762b56 -> a5b52dfe7bdad0198954e975197b47fa0397899e
     kit.marshal_post  4c5efb325f09b4ff5f283f4bdc04feecaa77388a -> ea1c6f2b30fe9cbb43ba03629ed9540af11b3f26
     kit.scoreboard    371267ea59133260c22af31e07c6c39cafcc7dd2 -> 33e9131c627a1d8a39be8dcae7381db69cb2c2c0
     kit.sign          341e36c5b8c68c7856513d8affb8b8e754bb63d0 -> 8619c2617b4be5dde1ac106a461310a90366c1d2
     kit.watch_tower   46a8f950673060aedef4da6a3db4af82eabe5339 -> a9bfd63e18261c2cfb5b0780b3dee37025b51717
   The kit.bush doc row changed too ("A bush. Collision: a cylinder round its leaves ...").
   assets/manifest.json is the base's in the branch: the Director re-scans on the merged tree.
   Pack hashes:
   - seed.wall moves: d5aea03b46c33ee6 -> 636b30026a88c5ae @1220 (crisp and classic). world = alone holds.
     Cause, proven: with the sign back on auto_box, the branch gives d5aea03b again (tl.sh bot, 1220 frames). The yard's
     kit sign at (9.5, -13) is met by the game's flying things: a ball or debris now passes where the old box
     stood (between the posts, under the board) or meets the posts and board instead.
   - Every other world hash equals the base's: seed.drive a2940a17, seed.paddle dff1a390, example.walker f1c7b537,
     example.kit ca698e71, example.car 3a459d0f, hockey a29dcdf0. parkour: the gate line truncates it to "f7" in both base and branch.
   - Visitor-space colliders (rails, the gate marker, world bushes, site posts, site fence) are in no pack's space.
4. The B2 fence follows the footprint (a still from the air, before/after). MET, after a premise check:
   - The round fence was already gone on main: d61321e, editor round 2, 19 Nov. Its before still is
     docs/shifts/2026-11-19-day/lanes/editor/stills/round2/before_01_building_above.jpg. Since then the yard stood open.
   - The owner's pick ("follow the footprint") is now built: site/draw.gd `_hoarding`. While the game is being built,
     a timber rail fence (TLKitSite.add_fence, 1.2 m) stands on the square of the lot's pad, 1 m inside its edge.
     landscape.gd pads a site plot with its footprint: 2r x 2r, turned by the player's yaw.
   - The fence is open for 7 m where the line from the centre to the gate meets it. It is solid: one box per straight
     stretch. It comes down when the game arrives.
   - b2-site-fence-before-after.jpg: from straight above and from 40 m, before (left) and after (right), with
     site.json's real job of 18 Nov.
   - A steel mesh fence was tried first and dropped: 66 ms of worker time and 10,352 triangles per 32 m lot, against
     36 ms and 3,696 for the timber one. It also made site.no_ring flaky (1 of 4 runs): that fixture waits for worker
     meshes within --quit-after 1200 frames. With the timber fence: 3 of 3, then PASS in chunk C.
5. kits/KIT.md and kernel/world/WORLD.md (colliders) updated in the branch. MET.
   - KIT.md: the hand-written "Collision per part" section; its generated part table regenerated (tools/k.sh docs).
   - WORLD.md: "The visitor's body" lists the new colliders and limits; a B2 paragraph after S2.
   - STYLE.md: the rows of detail.sign_out and detail.road_rails no longer say "presentation only".

CHANGED FILES (engine/)
- kernel/world/terrain/road_rails.gd: optional `ws`; `_walls`, one wall per drawn stretch, tag rail, POST_H tall, broken
  at every k % PASS_EVERY span exactly as `_row` draws.
- kernel/world/landscape.gd (+5 lines):
  - passes ws to the rails;
  - Parts.marker_solid for every gate marker;
  - Parts.bush_solids for WorldBushes and WorldRoadBushes.
- kernel/world/terrain/village_parts.gd:
  - marker_solid: one 1.5 x 1.9 x 0.38 box, tag sign, where edge_geometry draws the marker;
  - bush_solids: a cylinder for every bush at least 0.6 m tall, tag bush;
  - Parts.multi keeps the instance transforms as meta tl_xs (a headless MultiMesh keeps none; the test reads them).
- kernel/world/site/draw.gd:
  - `_posts`: the sign's and plan board's posts are solid;
  - `_hoarding`, `_perim`, `_perim_s`, `_hoarding_mesh`, and `hoarding` (a count): the B2 site fence;
  - `_solid` takes the fence.
- kernel/world/terrain/harden_case.gd (new, plus its .uid) and tools/selftest.d/620-harden.sh (new): 9 cases.
- kits/tl_kit_parts.gd: bush, sign, scoreboard, marshal_post and watch_tower bodies (`_sign_body`, `_tower_body`).
  kits/tl_kit.gd: the bush doc.
- kernel/world/site/fixtures/no_ring.gd, editor_yaw.gd: body and box counts moved, named in the files (outside the
  lane's column, see PATCHES.md 2).
- tools/selftest.d/513-blend-car-origin.sh, 580-surf.sh: dc9024b's hunks from main, as the Director asked (not mine).
- docs: kits/KIT.md, kernel/world/WORLD.md, style/STYLE.md.
- Lane folder: REPORT.txt, STANDUP.md, PATCHES.md, clip-harden.mp4 (19.2 s), clip-harden-strip.jpg,
  b2-site-fence-before-after.jpg, clip.sh and the clip / site_air walk and devices files.

BEHAVIOUR CHANGES (named)
- Under crisp the visitor can no longer cross the road's rails except at their gaps:
  - one span in nine;
  - the spur mouths and 9 m round a plot's gate;
  - the bridge and the river;
  - wherever a plot or lot reaches the row.
  There is no road bank where a rail tops out under a step: every place along the rails stops him (rails_block 193 of
  193 in the exe village, rails_village 199 of 199 in the wf_feel village). See "Round 2" below.
- The gate marker (sign and flag) is solid in every look; classic stands it in the fence's line, off the opening.
- Bushes at least 0.6 m tall stop him, in every look, except a bush whose cylinder would reach onto a road (main road or
  spur): that one stays walk-through.
- A site's sign and plan board have solid posts. While a game is being built the site is fenced (a 7 m opening at its
  path).
- The walk probe road_verge_walk of walks/visitor_walk.json walks along the rail row under crisp. It is now stopped
  by "rail" (measured in a window). PATCHES.md 1 has the one-value fix; that file is not the lane's.
- seed.wall's state hash (above).

FOR THE OWNER'S EYE
- clip-harden.mp4: the rails stop him, he slides to a gap and through, and back into the rail from the north. Then
  the gate sign stops him.
- b2-site-fence-before-after.jpg: the site from above, open yard (base) against the fenced footprint (branch).
- To walk it yourself: `bash engine/tools/world.sh visit wf_feel` (crisp): walk into the rails along the road, find a
  gap, then walk to a gate sign or into a bush.

QUESTIONS FOR THE DIRECTOR
1. The committed assets/manifest.json had stale kit hashes for all 36 parts at base d5967cc (c4d920d for arch_rib;
   fresh caches scan 8e63f81). You said at 21:05 that this was fixed on main as dd1064f. Re-scan on the merged tree:
   five ids move by this lane (above).
   Answered 22:32: leave the manifest at base; the Director re-scans at landing.
2. Answered 22:32: the Director applies PATCHES.md 1 at landing; the fixture edits land with the branch.
3. Re-cutting onto main: the lane runs no git that writes. Please merge main into n21-harden at landing (the Director
   offered to). Expected overlaps:
   - dd1064f's manifest: this branch leaves assets/manifest.json at the base;
   - dc9024b's two selftest hunks: already applied here, identical.

NEXT THREE THINGS THIS LANE WOULD DO
1. The other road-edge objects. The scatter measures its clearance on a 3 m grid, so a tree, rock or tuft can also
   lean onto the verge. Check them with an exact road distance, as the bushes now are.
2. The remaining auto_box parts that are not blocks when turned or stacked (barricade legs, cabin step): check them
   against their meshes the same way, and a kit-wide "the collider's top is the mesh's top" selftest.
3. A spawn and gate check across every walk script, not only the exe village (spawn_clear over walks/*.json), and the
   site fence in the exe's construction lot seen in the exported game.

ROUND 2 (22:23-23:10, the Director's 22:32: "raise the bank rails ... if it is more than raising post heights, stop
and report")
- The premise was wrong, and it was mine (round 1's "rails on a road bank are stepped over"). There is no road bank.
- The one crossing was at (-215.2, -0.4) in the wf_feel village. A terrain profile there shows the road flat at 0.25 m.
  At 2.5-3.5 m from its centre stood a roadside bush's new cylinder: 1.45 m tall, leaning over the road's edge, because
  the scatter measures its road clearance on a 3 m grid.
- The test's start point (ground_at from above) put him on that bush's top. From there he walked over the rail.
- The 7 exe-village places counted as "banks" were land a little lower than the road. All 7 already stopped him.
- What changed instead:
  - The bank lift was written, did not change the result, and was reverted. road_rails.gd and world_space.gd are as in
    round 1.
  - kernel/world/terrain/village_parts.gd bush_solids: a bush whose cylinder would reach onto the main road or a spur
    (the exact distance to their 2 m samples) gets no collider. landscape.gd passes road_pts and half.
- New case harden.rails_village: the rails walk in the wf_feel village, with every start on the land. With the fix
  mutated out (road_pts not passed) it FAILS: "walked over the rails at 1 of 199 places: (-215.2, -0.4) 3.0 m beyond;
  started on top of something, not on the road, at (-215.2, -0.4) on bush". With it, 199 of 199 stop him.
- rails_block now also fails when a start is on anything but the land. bush_block leaves out bushes on a road, as the
  code does.
- Block 620: 9/9 PASS.
- No stills: there is no bank, and nothing drawn changed (colliders only).
- world,packs after round 2:
  - crisp: world 8/8 (hashes as round 1, seed.wall 636b3002); packs 1/2. The fail is hockey many_budget, p50 1.208 ms:
    the same wall-clock failure as the base's 1.216.
  - classic: world 8/8; packs 2/2 (48/48 verb runs).

ROUND 3 (23:35, the Director: apply L3's PATCHES P1)
- What changed: kernel/world/site/draw.gd, as L3's PATCHES.md P1 gives it. `_key` appends `v.get("phase_line", "")`.
  `_sign` has an `elif v.has("phase_line")` branch that shows "Phase n of m: <title>". It sits between the arrived and
  "N of M built" branches.
- A job without phases has no `phase_line` and keeps "N of M built". editor_yaw's check of the "0 of 3 built" label
  still passes, and neither fixture's counts moved.
- Block 501: site.editor_pad and site.no_ring PASS.
- Block 620: 9/9 PASS.
- Block 502 (site.editor_yaw): FAIL in the run with 501 and 620, then PASS 3 of 3 alone. The failing run printed no
  SCRIPT ERROR and no "SITE EDITOR YAW OK": the fixture's waits for worker meshes ran out of its --quit-after 12000
  frames on a busy machine, the same flake no_ring showed with the steel fence. P1 adds no worker mesh, so this is the
  fixture's frame-bounded wait, not the patch.

