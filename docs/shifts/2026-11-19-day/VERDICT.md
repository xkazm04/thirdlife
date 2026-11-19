# Day shift of 19 Nov 2026: verdict

Four lanes ran from 08:40 to 16:18. All four landed on main, in 14 landings and one revert; nothing is held. Every
figure below was re-run by the Director on main or on the merged tree. Difficulty figures come from scripted hands:
**nobody has played today's work yet**. Final gate, exe and push: see "Main at the verdict" at the end.

## flight: mechanical wings, 5 x the run speed, and two climbing moves (Opus directing Astra; wings by Opus in Blender)
- **Verdict:** landed in five commits:
  - `83c39b7`: wings, flight, KERNEL_API 1.9.
  - `ebeeb2b`: the exe ships the wings.
  - `a6937c3`: ledge grab, mantle and hang bar, API 1.10.
  - `75acca5`: a fixture fix plus dust on take-off and landing.
  - `ce0dd63`: ledge at 3.05 m, cameras ignore bars, a soft swing for the village walker.
  Round 3 was first merged as `011e8e2` and reverted (`aeb201e`) because it broke 11 Skyline bots. The redo leaves
  Skyline's hashes identical.
- **Evidence:**
  - Every rule below is a permanent selftest case. `flight.` 13/13 and `moves.` 14/14 pass on main.
  - **Cruise:** 45.000 m/s against a 9.000 m/s run, ratio 5.000.
  - **Acceleration:** 95 % of cruise at tick 60 (1 s). The largest change in one tick is 1.5 m/s.
  - **Ceiling:** 119.993 m above the ground.
  - **Sweep:** a scripted sweep of 20,800 ticks over the bluff, trees and buildings had 0 capsule overlaps and 0 frames
    of the camera inside a crown.
  - **Packs unchanged:** a biped that never calls fly, or never asks for moves, keeps the same 600-frame position hash.
  - Clips: `lanes/flight/clip.mp4` (21 s), `clip-moves.mp4`, `clip-cam-bar.mp4`. Sheets: `sheet_world.jpg`,
    `sheet_wings.jpg`, `sheet_moves.jpg`.
- **For your eye:**
  - **Flight:** in `dist/PLAY-LATEST.cmd`, walk to the road and press **F**. **Space** climbs, **C** descends, and
    **W** cruises. Bank round a tree, then descend onto grass to land. Fly down into a plot and you land at its gate.
  - **Moves:** jump at a wall about 2.5 m high to grab the ledge. **Space** or **W** mantles up; **C** drops.
- **Director decisions you may overturn:**
  - **Keys:** F toggles flight. Space climbs and C descends.
  - **Speeds:** 5 x is forward only; sideways and back stay at run speed.
  - **Limits:** the ceiling is 120 m, and you cannot fly into a game's plot: descending below 12 m over it lands you
    at its gate.
  - **Moves:** ledge and bar became walker moves (API 1.10) so the ninja course could use them.
  - **Swing:** the soft end of the swing applies only to the village walker; packs keep the plain swing.
- **Asks:**
  - **F1. Flight feel:** keep as is / faster, slower or a different key / lower ceiling.
  - **F2. Ledge and bar for the village walker:** keep / Skyline only.

## parkour: Timber Run grows into a four-stage ninja course (Astra alone; an Opus operator verified)
- **Verdict:** landed in four commits:
  - `9bb3986`: three stages and 12 checkpoints.
  - `91ff082`: respawn fix.
  - `cdcf469`: stage 4, Skyline (headwall ledge grab, two swing bars, catch ramp).
  - `a6f8941`: a respawn bug a person could hit, plus a side camera on the bars.
- **Evidence:**
  - `bot_course` (perfect hand) finishes in 986 frames with 0 falls on seeds 1-3.
  - Ladders over 20 seeds per hand are in the lane reports. On the latest run the newcomer finishes the course on 19
    of 20 seeds, and the retry also reaches 19 of 20.
  - Each new obstacle has an impossibility case: making it impossible turns `bot_geometry` and `bot_course` red.
  - packs 48/48 and world 8/8 pass on main.
  - Clips: `lanes/parkour/clip.mp4`, `clip-round3.mp4` (17.4 s, native speed), `clip-round4.mp4`. Contact sheets are
    in `stills/`.
- **For your eye:** run `tl play parkour`, or walk to the yard in the exe. Things to judge:
  - the bar release timing;
  - the camera cut to the side view when you catch the blue bar;
  - the hit cost on the swing beam, which sends you back about 5 m;
  - the height of the tower.
- **Director decisions you may overturn:** packs may compose the drawn camera in `_physics_process` (picture only, no
  hash moves).
- **Asks:**
  - **P3. Skyline camera:** keep the side cut / plain orbit.
  - **P4. Next obstacles:** more stages / harder timing on the existing ones / leave it and play it first.

## blend: no circles round constructions (Opus directing Astra; Astra designed the look)
- **Verdict:** landed in two commits:
  - `a68ef16`: pads follow the footprint and grade into the land over 20-66 m. The rings, kerbs and round fences are
    gone; only short rails stand either side of the entrance. On the way it fixed seed_drive's 7 m bowl.
  - `0503123`: the terrain's light and dark triangles are gone (a noise-hash bug); road and meadow wear are painted
    into the terrain.
- **Evidence:**
  - Before and after stills of 8 lots, from the road and from above: `lanes/blend/contact-before-after.jpg`.
  - Ten scripted visits, walking and flying, before and after: `round2/visits_*.jpg`.
  - Clips: `clip-blend.mp4`, `clip-blend2.mp4`.
  - Check 512: the largest tone jump in the grass (99.9th percentile) fell from 17.58 to 7.42 of 255, against a limit
    of 12.
  - world 8/8: no game's state hash moved.
- **For your eye:** walk off the road into any lot and along its edge, then fly over at 20-25 m. Look for any seam or
  circle.
- **Director decisions you may overturn:** plots are open on every side for the visitor: no fence wall, drawn or
  hidden.
- **Asks:**
  - **B1. Open plots:** keep them open / invisible walls.
  - **B2. The construction site's round fence**, the last circle seen from the air: follow the footprint next shift /
    leave it.
  - **B3. The car's course floor in the village:** draw it with its own look / keep it hidden.

## editor: E2 in code, then placement the LLM takes care over (Opus directing Astra)
- **Verdict:** landed in four rounds:
  - `5f50416`: E2 in code, and placement grounded in measured candidates.
  - `0a18c59`: no site circle, pads at land height, place-call tokens in the ledger.
  - `cac37c8` (merged in `a6f8941`): the construction follows the player's turn, a pad for a lot with no height, and
    the job titles.
  - `e66ca0b`: the arrived game stands turned too. Its gate, rails and sign still face the road.
- **Evidence:**
  - **E2:** the interviews now live in their cards. `tl cards check` passes and fails on a bad `propose`, and
    devx.test passes 229/229. The foreman tests cover `--answers`, `--lot`, `--decision` and `--place-calls`
    (foreman 223).
  - **E1 placement:**
    - Each answer redraws the map: the footprint, the stands, the path and the clearance.
    - "Find a place" returns 2-3 ranked places, each with a reason in the player's terms.
    - A deterministic scorer judges every place, and the fake adapter gives fixed proposals in tests.
  - **The turn:** world 8/8 with all 8 hashes identical before and after the turn work. `site.` 23/23,
    ui.selftest 166/166.
  - Clips: `lanes/editor/clip-place.mp4` (26.7 s), `clip-village.mp4`, `clip-village-round2.mp4` and
    `clip-visit.mp4` (28.5 s: walk, E, Q, F, fly to a fresh game). Stills are in `stills/` and `stills/round4/`.
- **For your eye:**
  1. Run `ui.sh open`, then "+ New game".
  2. Answer the questions and watch the map change.
  3. Press "Find a place", pick one, turn it, then "Build it".
  4. In the village, the crane stands on your lot, and the game arrives turned the way you set it.
- **Director decisions you may overturn:**
  - The Designer is asked for place words only. The fence-based fit rule decides the overlap.
  - The yaw is the editor's sign convention (world yaw = minus editor yaw), recorded on the reserved plot.
- **Asks:**
  - **E4. The Designer call per "Find a place"** (about 5.3k tokens in): keep / use the scorer's top three, with the
    Designer only when the request's words matter ("by the river", "quiet").
  - **E3 (still open from the morning):** see STATE.md.

## Findings for the next hunt (not owner decisions)
- `world.sh alone --at=<off-origin>` changes the hash of every game: seed.paddle, hockey and parkour reproduced. The
  world gate's village placement passes 8/8, so this is a float effect of a translated physics root.
- Not measured: whether a turned game reuses its picture cache.

## Route scoreboard
| Lane | Route | Held? |
|---|---|---|
| flight | Opus directing Astra for the mechanics; Opus alone in Blender and for rounds 3-4 | Yes. A cut-before-Skyline tree caused the one revert. |
| parkour | Astra alone for design and code; Opus operator | Yes. It won by eye again, and Astra found the bug a person could hit. |
| blend | Opus directing Astra; Astra designed the look | Yes. Astra traced the triangles to a D3D12 hash rounding. |
| editor | Opus directing Astra | Yes. Four rounds in one session each; it kept to scope. |

## Cost
- **Astra tokens, as codex printed them per lane:**

  | Lane | Tokens |
  |---|---|
  | editor | 1,559,055 |
  | parkour | 1,510,263 |
  | blend | 1,990,857 (resumed runs count their context again) |
  | flight | 941,684 |
  | **Total** | **about 6.0 M** |

  The plan's estimate was 2-3 M. Resumes recount context, so the real new work is lower; even so, the spend was
  above plan.
- **Designer calls:** about 17 real Sonnet calls (placement).
- **Agents:** 4 Opus lane agents, re-dispatched in place.

## Next shift
1. **You play it:** flight, Skyline and a workbench game turned on its lot (the asks above).
2. **Hunt:** the `--at` off-origin hash, and the picture-cache proof for turned games.
3. **Blend with the editor:** the construction site fence follows the footprint (B2).

## Main at the verdict (17:33)
- **Full gate on `d59f072`:** PASS on every step:

  | Step | Result |
  |---|---|
  | arch | 12/12 |
  | assets | 4/4 |
  | cards | 3/3 |
  | devx.test | 229/229 |
  | foreman.typecheck | clean |
  | foreman.test | 223 (218 pass, 5 skipped) |
  | kernel.selftest | 317/317 (+7) |
  | kit | 95/95 |
  | packs | 2/2, 48 of 48 runs |
  | perf | 2/2, quiet (it ran this time) |
  | seeds | 39/39 |
  | item | 91/91 |
  | ui | 166/166 |
  | world | 8/8 |

- **`tl arch --index`:** unchanged.
- **Exe:** `export.sh --commit d59f072` built `dist/ThirdLife/ThirdLife.exe`. `export.sh check` passes: the same hashes
  as the editor binary, it shows the village, and it obeys W and Esc.
- **To play it:** `dist/PLAY-LATEST.cmd`.
