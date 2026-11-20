SURFACES · ASTRA ARM (GPT 6.2 Astra designs and builds; Opus operator verifies) · night of 20 Nov 2026
Worktree .claude/worktrees/n20-surfaces-astra, branch diorama-surfaces-astra (on diorama-base 781d32b), uncommitted.
Status: DONE. Round 2 is the deliverable. Every gate is green, re-run by the operator on the final tree; the exe
exports and checks.

HOW THE NIGHT RAN
- Round 1 (23:31-02:05). Astra built from COMMON.md plus the surfaces section, both passed verbatim. I stopped it
  at 2 h 25 min while it was re-running the kernel suite itself (299 PASS, 0 FAIL at that point). Its tree had been
  stable since 00:41. I verified it: all gates PASS. The look gaps went back to Astra as numbers only: river opaque
  beige, bluff a pink smear (detail 6.75 -> 3.55), saturation low.
- Round 2 (02:40-03:19), resumed session 01a1f5ef with the measured failures and attached crops. This is the
  final tree.
- Round 3 (03:24-04:01) ran in a separate copy outside the worktree (scratchpad n20sa-r3), so the round-2 tree
  stayed fixed while I verified it. I stopped it at 04:01. It is NOT ported: there was no time left to re-verify a
  third tree under the shared window lock. Its only change is engine/style/shaders/handmade.gdshaderinc: felt tufts
  on the pines (Astra measured pine gradient 23.0, target 24.0) and a "dry" grit term on the road. Its v3 road still
  looked over-orange in its own still. That file waits in the copy if the Director wants it later.

WHAT WAS BUILT, AND WHY IT READS AS DIORAMA (round 2)
- One opt-in style key, detail.handmade = 1 in style_diorama.json. It turns on a handmade surface path in
  toon.gdshader (handmade.gdshaderinc, material_noise.gdshaderinc). Classic does not have the key, so classic takes
  the old path.
- New material classes: felt, painted_wood, earth (plus ground, wood). They are assigned to existing palette keys in
  the diorama mat section.
  - felt: grass is pressed felt/flock with tufts and lint; pine and leaf crowns are felt.
  - painted_wood: platforms, beams, signs and curbs show wood grain with uneven paint.
  - earth: the road and parkour ground are ochre earth with grit.
  All of it is evaluated in object or world coordinates, so it is anchored and does not swim.
- Relief comes from a lighting-only normal. The depth/normal prepass keeps the geometric normal, so fibres and pores
  get no ink lines. The diffuse is a soft wrap with a warm pigment fill, and a separate varnish lobe makes painted
  surfaces glossy while felt stays matte. Bodies (the figure) are excluded.
- Resin river: water_resin.gdshader is chosen only when handmade is on. It is a blue bed under a view-dependent sky
  reflection with broken amber glints.
- Display-only geometry. Every piece is gated on handmade and not headless, so none of it is a collider, none of it
  touches the simulation RNG, and the headless gates never build it.
  - village_parts.gd: felt pine tiers with a rolled hem (720 tris near the visitor, 260 far, against 80 for the
    original), and rolled clay mesa layers.
  - stone_scatter.gd: road grit chips, plus 19 half-submerged stones at the waterline.
  - PIC_VERSION 15 -> 17. The picture-cache key gains a pigment term only under handmade.
- The palette keeps all 100 columns in the same order (values changed in the diorama file only). No pack, seed or
  kit file changed.
Measured on my own stills (same boxes each time; targets read off board 4 at 1280x720):
  grass  saturation 0.83, gradient 18.0   (classic 0.79 / 2.7; target 0.85 / 19.3)
  pine   saturation 0.65, gradient 18.9   (classic 0.43 / 9.1; target 0.58 / 24.0)
  road   saturation 0.78, value 0.83, gradient 9.56   (target 0.75 / 0.92 / 9.2)
  bluff  gradient 7.00, terracotta (155,74,48)   (classic 6.75 purple; round 1 was 3.55)
  river  blue water (51,110,142) with stones and highlights   (round 1 was opaque beige)
  parkour ground shadow contrast, p90/p10 luminance: 2.20   (classic 1.54)

RULES, EACH WITH ITS EVIDENCE (final tree)
1. No pack file changes; API v1 holds.
   - git diff -- engine/packs engine/seeds engine/kits contracts: empty.
   - tl check --tier fast: arch PASS 12/12 (it includes api-v1).
   - The 100 palette keys keep their order; there are no new or renamed keys (checked by script).
2. Today's look stays exact. Proof sheet: classic-proof-masks.jpg. Every capture below uses TL_STYLE=classic. "Base"
   is a pristine archive of diorama-base, plus the two site job folders the worktree resolves from main (without them
   the village is a different world).
   - Village, 16 tour shots, --load=block --cost=model (blend_views walk):
     - 9/16 are bit-identical.
     - The other 7 differ only in blobs on moving things (race cars, chimney smoke, game pieces): 0.001% to 0.96%
       of pixels. The 0.96% is the smoke plume in 09.
     - No differing pixel lies on terrain, trees, mesas, bluff, river, fences or far pictures.
     - Base vs base in the same world (unblocked loading): 7/16 bit-identical, up to 2.72% px. That is the noise
       floor.
   - Parkour capture f520 and f987 (orbit, HUD on, 1920x1080): 0/255, identical.
   - Hockey f1500: 0.011% px, the same as base vs base (0.011%).
   - Flight stills (wf_flight, warm cache):
     - f1 max 2/255 (3 px > 1); f2 max 1/255; f4 0/255.
     - f3 and f5: small blobs on moving things (0.010% / 0.030% px).
   - Caveat: the first unblocked classic re-take after the PIC_VERSION bump drew some packs late (cold picture cache
     on a busy machine). It was re-taken with blocked loading. That was timing, not a look change.
3. No game's state hash moves. tl check --tier full --only world,packs,kit.selftest: PASS world [8/8], packs [2/2]
   (48/48 verb runs), kit.selftest [95/95].
   - All 8 world rows (hash and frames) are identical to diorama-base. Example: example.walker f1c7b53757c34040@371,
     game.parkour f7abac006a45bd43@988, hockey a29dcdf02a16dd1c@4186.
   - All 46 hashed pack runs are identical to the diorama-base runs, compared run by run.
4. Cache keys: generators changed (felt crowns, mesa layers, scatter), so PIC_VERSION went 15 -> 17.
5. Performance: tl perf run --scenario tour6,walk30 --no-record. The machine was BUSY (92-98 % use), so nothing was
   recorded. It decides nothing.
   - tour6 GPU: 1.198 ms classic -> 1.297 ms diorama (+8 %).
   - walk30 GPU: 1.237 ms -> 1.384 ms (+12 %).
   - frame p50 tour6: 2.75 -> 3.06 ms.
   No doubling.
Detail anchoring (boil):
   - Slow fixed pan (look.sh clip rig:idle:0:0.83:behind --thin=1, 1920x1080, CRF 4):
     - horizon band: classic 3.065 / 2.625 % flips; diorama 3.166 / 2.503 %.
     - play band: 0.901 / 0.292 % vs 0.762 / 0.294 %.
     No added crawl.
   - Village walk (clip segment A, frames 40-400): horizon 13.52 / 17.9 % vs 13.96 / 18.8 %.
   - The ground band in the walk rises from 4.42 / 4.5 % to 16.36 / 23.6 %. The felt and grit now carry
     high-contrast detail that moves with the ground under a moving camera, so the walking ground changes far more
     per frame than classic's flat fill. The fixed pan and Astra's static swatch check (0-4/255 over 105 frames)
     say it is anchored, but whether it shimmers to the eye at walking speed is a question for a person. Watch
     clip.mp4 0-7 s.

GATES (operator runs, final tree)
- node devx/bin/tl.mjs check --tier fast: PASS 5/5. arch 12/12, assets 4/4, cards 3/3, devx.test 229/229,
  foreman.typecheck clean.
- node devx/bin/tl.mjs check --tier full --only world,packs,kit.selftest: PASS world [8/8], packs [2/2] (48/48),
  kit.selftest [95/95].
- bash engine/tools/selftest.sh style.: 3 passed, 0 failed (walker.ink, first_reject, switch).
- bash engine/tools/selftest.sh surfaces.: 1 passed, 0 failed. This is the arm's own block 580, surfaces.handmade:
  100 columns, classic/resin/classic reload, crown 80->720, far 260, 19 bank stones.
- bash engine/tools/selftest.sh blend.pigment: 1 passed (classic edge p99.9 7.42/255, limit 12).
- Exe:
  - export.sh --out C:/Users/kazda/kiro/third-life/dist/arms/surfaces-astra/ThirdLife: PASS export.build, tag
    "781d32b 2026-11-20 03:34". The commit text says uncommitted round 2.
  - export.sh check: PASS export.check (same hashes as the editor binary, the village shows, W and Esc obeyed,
    nothing left behind).
- Not run by me: the full tier as a whole (kernel suite, seeds, item, ui, perf gate). Not run is not a pass. Astra's
  round-1 run of the kernel suite reached 299 PASS, 0 FAIL before I stopped it; that was round 1, not this tree.

DELIVERABLES (lane folder docs/shifts/2026-11-20-night/lanes/surfaces-astra/)
- contact-sheet.jpg: target 4 beside the best diorama village frame (parkour road), then 12 classic|diorama pairs:
  village road and above x6, flight bluff and cruise, parkour f520, hockey f1500, rig close-ups three and vclose.
- stills/*.jpg: 7 diorama frames. classic-proof-masks.jpg: the classic proof. contact-sheet-r1.jpg: round 1, for
  history.
- clip.mp4: 23.0 s, 1280x720, windowed, diorama.
  - 0-7 s: the road west into the parkour yard (blend village, scripted).
  - 7-23 s: take-off and flight over the village and the bluff (wf_flight, the flight lane's devices).
  There is one cut between the two worlds.
- Exe: C:/Users/kazda/kiro/third-life/dist/arms/surfaces-astra/ThirdLife/ThirdLife.exe
- NOTES-astra.md (Astra's own measurements), PATCHES.md (Astra's frame note plus operator merge notes), STANDUP.md.
- Raw captures and every log are under .tl/ in the worktree: shots/, clip/, boil/, codex-r1/r2/r3.log,
  r2-*.log, base-gate/.

CHANGED FILES (all uncommitted)
  M engine/style/style_diorama.json            (detail.handmade, palette values, mat classes, water)
  M engine/style/tl_style.gd                   (CLASSES + felt/painted_wood/earth, detail.handmade range, resin
                                                water choice, g_mottle.y = handmade)
  M engine/style/shaders/toon.gdshader         (handmade branch in fragment and light)
  A engine/style/shaders/handmade.gdshaderinc (+ .uid)
  A engine/style/shaders/material_noise.gdshaderinc (+ .uid)
  A engine/style/shaders/water_resin.gdshader (+ .uid)
  M engine/kernel/world/terrain/village_parts.gd (felt crowns, clay mesa layers, grit and bank stones; display only)
  A engine/kernel/world/draw/stone_scatter.gd (+ .uid)
  M engine/kernel/world/draw/draw_base.gd      (PIC_VERSION 17)
  M engine/kernel/world/draw/draw_pictures.gd  (pigment term in the cache key under handmade only)
  A engine/tools/selftest.d/580-surfaces-astra.sh
  A docs/shifts/2026-11-20-night/lanes/surfaces-astra/*
  Note for the Director: stone_scatter.gd sits under engine/kernel/world/draw/**, which is in the surfaces file list.

PATCHES.md (summary)
- Frame: the ink contour on pine tiers and on the clouds still reads as ink at play distance, so compare it with
  the frame arm's contour treatment. The handmade light() replaces the directional diffuse; merge by hand if frame
  edits toon light() too.
- Character: under diorama, the review-scene floor loses its tile grid. The figure itself is untouched.
- PIC_VERSION: when combining, take max + 1.

WHAT STILL DOES NOT READ AS DIORAMA (honest)
- The frame is not ours, and it decides much of the read. The billboard clouds with their seam, the ink outlines and
  the purple sky still say "storybook", not "miniature". There is no tilt-shift and no warm raking light, so the felt
  and grain read as texture rather than as tiny handmade objects.
- Pines are felt-coloured but smoother than board 4's (gradient 18.9 vs 24.0). Round 3 had the fix but is not ported.
- The road and parkour ground are a hot, saturated orange-red (parkour-f520). That is close to board 4's road
  colour but glowier than clay, and it competes with the HUD and the runner more than classic did.
- No fingerprints or tool marks show at play distance; they need a close surface under raking light. Chipped paint
  at edges is not visible in the shot set.
- The walking ground changes a lot per frame (see the boil). This needs a person's eye in the clip or the exe.
- The hockey rink is essentially unchanged (ice); the diorama read there comes only from the boards.

COST PER NEW GAME
- Zero added. Games keep naming the same palette keys. There are no new textures, assets, kit calls, pack fields or
  export steps. The diorama is chosen by style keys only.

QUESTIONS FOR THE DIRECTOR
- Port round 3's handmade.gdshaderinc (pine felt tufts, road grit)? It needs a gate and shot re-run first.
- Should the review floor get its own class so its grid survives the diorama?

NEXT THREE THINGS
1. Port round 3's pine tufts without the road "dry" multiplier, then re-verify.
2. Tone the earth ochre toward clay (lower value/saturation near the HUD) and add sparse chipped paint on beam edges
   at play distance.
3. A walking-speed shimmer measure on the felt ground (motion-compensated boil) and a mip/filter pass if it shows.
