N6 world-directions | Opus director of three GPT 6.2 Astra-solo arms | night 2026-11-22 | report written 21 Nov 20:50

WHAT HAPPENED
- 19:14 rubric first (RUBRIC.md: 7 items 0-4, 6 hard gates, 6 fixed stills with S1 and S6 the same coordinates in every
  arm), then ARM-COMMON.md (process, files, proofs; no art direction) and briefs/ARM-a/b/c.md (one direction each).
- 19:16 three codex runs in parallel (`codex exec -m gpt-6.2-astra ... < /dev/null`, "read-only git is fine; do not
  commit"). Each ran 6-7 rounds unprompted in about 35-45 minutes.
- 19:58-20:03 each session resumed by id (phase 2, briefs/PHASE2-COMMON.txt): the Director's independent scores as
  evidence, plus four evidence fixes (haze-off map, venue camera on its road, an 18 s village-out flight, a frame pass
  with no readback). Each ran 5-6 more rounds. All three finished by 20:31 with 12 rounds each.
- 20:30-20:46 the Director re-ran every proof himself in each arm tree (own window run "round 90", selftests, world
  gate, fast tier) and built the side-by-side sheet and COMPARE.md.

ACCEPTANCE (per arm)
- Flyover clip of 20 s or less: met. 18.0 s, 540 frames, 1280x720 H.264 in each arm's round-8..12 folder; round 1-7
  clips of 5-12 s. Director copies at 27 CRF: arms/<x>/flyover-round-12.mp4 (4.6-5.7 MB), arms/<x>/flyover-round-1.mp4.
- A 6-still sheet per round: met. 12 sheets per arm (arms/<x>/rounds/round-N/sheet.jpg; full-size stills stay in the
  arm trees) and arms/<x>/evolution.jpg (every round, the 6 views).
- Rubric scores per round: met. Arm self-scores in arms/<x>/rounds/round-N/SCORES.md; the Director's independent
  scores for every round in DIRECTOR-SCORES.md. Director totals of 28, round 1 to 12: A 12 to 21, B 16 to 21, C 9 to 21.
  The arms' phase-1 self-scores ran 4 to 8 points above the Director's. After the feedback they came within 0 to 2.
- World 8/8 = alone: met, measured two ways by the Director in each arm tree:
    Home window (growth built around the 8 games of engine/boot/village.json, crisp, 1920x1080): every game's full
    state hash = a fresh standalone worker at the same seed and own-tick count. PASS home.a.alone 8/8,
    PASS home.b.world_alone 8/8, PASS home.c.window.alone 8/8 (arms/<x>/director-verify/proof.txt).
    `tl check --tier full --only world`: A PASS [8/8] 120524 ms, B PASS [8/8] 344584 ms, C PASS [8/8] 164740 ms
    (Director base tree before the arms: PASS [8/8] 148452 ms).
- Load time and frame cost: met (busy machine, 20-25 other Godot processes; same-session A/B only).
    Growth build: A 1.21 s, B 0.94 s, C 0.85 s.
    Flight with no readback, p50/p99 ms: A 4.68/10.40 (village alone on the same flight 4.66/9.23), B 5.27/10.99 (no
    village flight in B's runner), C 3.84/7.65 (village alone 4.40/10.37).
    First draw village -> Home in one session came out lower for the Home in all three Director runs (cache warmth):
    load deltas are order-sensitive and are not evidence. The build time is the added cost.
- One side-by-side sheet and COMPARE.md: met (SIDE-BY-SIDE.jpg final rounds, SIDE-BY-SIDE-round1.jpg, COMPARE.md).
- No arm lands: met. The Director made no git writes. Each arm tree has an empty tracked diff and only new files:
  engine/kernel/world/home/** (11-16 files, largest 263 lines, no class_name), engine/tools/selftest.d/750-home-a.sh /
  753-home-b.sh / 756-home-c.sh, docs/shifts/2026-11-22-night/lanes/N6-world/arm-<x>/**. Raw frames are under each
  tree's .tl/ (A 0.7 GB, B and C about 0.2 GB).

GATES (Director's runs, 20:30-20:46)
- A: selftest home.a 5/5 PASS (determinism, extent [-3264..3264], reach 5 venues + 2 portals, chunk 66 shared samples,
  village delta 4e-8 m); fast: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229 PASS, foreman.typecheck NOT RUN ->
  exit 2; world PASS [8/8].
- B: selftest home.b 8/8 PASS (determinism, extent [-1392,-1056,1428,1032], reachable 14/14, chunk, village 0 m,
  ferry 127 soundings, saltern, summary); fast as A (exit 2, foreman NOT RUN only); world PASS [8/8].
- C: selftest home.c 5/5 PASS (determinism, extent [-1728,-1344,1824,1248], seam, destinations, chunk); fast as A
  (exit 2, foreman NOT RUN only); world PASS [8/8].
- foreman.typecheck is NOT RUN in every worktree (no foreman/node_modules; the same in the Director's base tree, which
  the arms never touch). It is not a PASS. Arms A and C first worked around it by copying the tree under .tl with npm ci.
  Phase 2 told them to stop.

ASTRA TOKENS (session totals printed by codex)
A 676,246 | B 551,376 | C 594,640 | total 1.82 M, under the 3 x 0.8 M budget.

WHAT THE OWNER SHOULD LOOK AT, AND HOW
1. SIDE-BY-SIDE.jpg (3 arms x 6 views, final round).
2. arms/a|b|c/flyover-round-12.mp4 (18 s each).
3. arms/<x>/evolution.jpg to see the 12 rounds.
4. To fly one yourself (window): `bash <arm tree>/engine/kernel/world/home/home.sh <new round>` (A) or
   `home.sh capture <round>` (B, C). Arm C also has `home.sh visit <round>`, a window to walk its Home by hand (its
   growth has visitor collision; A and B do not). These write a new round folder in the arm tree.
The Director's lean, in COMPARE.md: B islands answers the question most clearly (shape, a place per island, simpler
streaming and sharing). A is the best to walk out into and the only one at 6.5 km. C has the best single destination.
A hybrid (islands, with A's grain and C's height) is the natural next step. All three end level at 21/28. The owner's
eye decides.

BEHAVIOUR CHANGES
None on any tracked path. Nothing reaches main. The growth runs only from each arm's own home/tour.tscn.

QUESTIONS FOR THE DIRECTOR
1. tl.land/1: the three arms export 96 m chunks (33x33 u16 heights, 32x32 material ids, water levels) with three
   different quantisations (A offset -128 m, step 0.01 m; B -64 m, 1/128 m; C its own). The contract needs one,
   agreed with N5, before any of them is adopted.
2. Integration hook (each arm's PATCHES.md): after Landscape.build returns the village terrain and before the first
   draw. The landscape should then skip the flat far plain and its mesas. This is a landscape.gd change (N5's file
   tonight), so it waits for the owner's pick.
3. Commit each arm to its branch (n22-world-a/-b/-c) as the brief says. Stage per path: engine/kernel/world/home/,
   the selftest file, docs/shifts/2026-11-22-night/lanes/N6-world/arm-<x>/. Leave .tl/ and .import.log out.

NEXT THREE THINGS
1. The owner walks the picked Home by hand (C has `visit` today; A and B need near colliders), then one more grind loop
   against what he says.
2. Land the picked direction behind the boot hook with the far plain removed, and chunk it through N5's land/ format.
3. If he picks a hybrid: B's archipelago as the frame, A's lanes, fields and mill on the home island, C's crater and
   tower on one outer island. Same rubric, same fixed stills, so the result compares with tonight's.
