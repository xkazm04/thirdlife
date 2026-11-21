# N6: three Homes grown from one village (the owner picks)

TWO-WORLDS open question 1: "One continuous land, or islands joined by roads, boats or flight?" Three GPT 6.2 Astra
arms, each working alone on the look, grew today's village (engine/boot/village.json, its 8 games, unchanged) in three
directions. Each ran 12 rounds of the same loop: build, capture in a crisp window, score against RUBRIC.md, refine. Rounds
1-5/7 ran on the first brief, rounds 6/8-12 after the Director fed back his own scores and fixed the evidence (a
haze-off map, the venue camera on its road, an 18 s village-out flight, a frame pass without capture).

**Look first:** `SIDE-BY-SIDE.jpg` (final rounds, the same 6 views per arm), then each `arms/<x>/flyover-round-12.mp4`
(18 s, starts among the village's games and goes out to two venues), then `arms/<x>/evolution.jpg` (every round, top
to bottom). `SIDE-BY-SIDE-round1.jpg` shows where they started.

## The three answers

| | A: one continuous land (Wren Valley) | B: islands (archipelago) | C: highlands |
|---|---|---|---|
| What it is | the village's river valley runs out into furlong fields, hedges, orchards and woods; cream chalk downs and a ridge with peaks close the horizon; a mill on the river at the bridge | the village is the home island; five other islands (twin-peaked west island with a lighthouse, a crater island, sand and dune island with kilns and a salt works, a crescent), joined by a trestle bridge, a causeway and a dashed ferry line | the village on a shelf; snow peaks, a crater tarn with a waterfall spilling down a basalt gorge, a bell tower on the crater rim, switchbacks, Lantern Quay with a moored boat, Pear Fair orchard |
| Grown extent (selftest) | 6.53 x 6.53 km (the TWO-WORLDS 6.5 km) | 2.82 x 2.09 km, mostly sea between the islands | 3.55 x 2.59 km |
| Venues | 5 graded plots, 2 portals | 5 flat pads, 2 portals | 5 plots, 2 portals (plus named stops) |
| Best still | `village_edge_out`: a fenced lane out of the village toward the chalk downs | `overview_sw` and `map`: reads as an archipelago in one glance | `venue_approach`: a road climbing to the bell tower |
| Weakest still | `overview_sw`: from high it is still a green carpet; venues are small from afar | `far_look_back`: a flat sand plain; cliffs smooth and plain | `map`: rough purple smears; slopes carry broad flat colour patches |
| Visitor can walk the growth | no (visual; colliders are its "next") | no (routes not walked live yet) | yes (relief collision; 186 route probes hit within 1.1 mm) |
| Director's score, round 1 -> 12 (of 28) | 12 -> 21 (S3 V3 R3 P2 C3 L3 F4) | 16 -> 21 (S3 V3 R3 P3 C3 L2 F4) | 9 -> 21 (S3 V3 R3 P3 C3 L2 F4) |
| Arm's own score, round 12 | 20 | 21 | 21 |
| Astra tokens (session total) | 676 k | 551 k | 595 k |

All three end level on the rubric. They differ in kind, and the rubric does not settle the owner's question; his eye does.

## What the Director re-measured himself (21 Nov 20:30-20:46, own window runs "round 90", machine busy with other lanes)

| | A | B | C |
|---|---|---|---|
| Home window: each of the 8 games' full hash = the same pack alone for its own ticks | **PASS 8/8** | **PASS 8/8** | **PASS 8/8** |
| `tl check --tier full --only world` in the arm tree | PASS [8/8] 121 s | PASS [8/8] 345 s | PASS [8/8] 165 s |
| arm selftest block (headless) | home.a 5/5 PASS | home.b 8/8 PASS | home.c 5/5 PASS |
| fast tier | arch 12/12, assets 4/4, cards 3/3, devx.test 229/229 PASS; foreman.typecheck NOT RUN (no foreman/node_modules in worktrees, the same in the Director's base tree): exit 2 | same | same |
| growth build (measured in the window) | 1.21 s | 0.94 s | 0.85 s |
| flight frame, no capture, 1920x1080: p50 / p99 ms | 4.68 / 10.40 (village alone on the same flight: 4.66 / 9.23) | 5.27 / 10.99 (no village flight in B's runner) | 3.84 / 7.65 (village alone: 4.40 / 10.37) |
| draw calls in the flight p50 / max | 77 / 145 (village 64 / 119) | 39 / 103 | 138 / 503 (village 97 / 451) |
| first draw, village then Home in one session | 7483 -> 6758 ms | 6338 -> 5223 ms | 5963 -> 4879 ms |

Load time: the second load in a session is warmer, so "Home minus village" came out negative in all three Director
runs; the arms saw anything from +21 ms to +1.9 s. The growth build (0.85-1.21 s) is the honest added cost. Frame cost:
the grown land costs nothing measurable over the village on the same flight (p50 within 0.1 ms; C's p50 is lower because
its flight sees more mountain and less village). Busy machine (20-25 other Godot processes): A/B in one session only.

The growth touches no tracked file in any arm (`git diff` empty), declares no `class_name`, and the largest new file is
263 lines. The village heightfield inside its box is unchanged in all three (selftests: max difference 4e-8 m, 0, 1.6e-5 m).

## The Director's lean (for the owner to overrule)

- **B islands** answers the question most clearly: it reads as a shape at any distance, each island is a place of its
  own, and TWO-WORLDS' own argument holds (streaming and sharing are simpler; a region is one item). Its eye level is
  the plainest of the three (sand flats, smooth cliffs).
- **A continuous land** is the best place to walk out into at eye level (the lane, the mill bridge, the downs) and is
  the only one at the full 6.5 km. From above it is still a carpet.
- **C highlands** has the best single destination (the bell tower on its road, the waterfall) and the only walkable
  growth, and the roughest surfaces.
- A hybrid is natural: islands as the Home's structure, with A's eye-level grain (lanes, fields, a mill) on the home
  island and C's height (a crater, a tower) on one of the others.

## Not done, not verified
- Nobody has walked any of the three Homes by hand; the flights are scripted cameras. The owner's hand is the bar.
- B's runner measures no village-alone flight, so B's frame cost has no same-flight baseline (stills: 123 vs 108 calls).
- The three chunk exports use three different quantisations (A: -128 m offset, 0.01 m step; B: -64 m, 1/128 m; C: its
  own): `tl.land/1` is not a contract yet (a Director/N5 question).
- Integration: each arm runs from its own `home/tour.tscn`; the hook into the boot village is described in each arm's
  `PATCHES.md` (after `Landscape.build`, before the first draw; the far plain should then not be built).
