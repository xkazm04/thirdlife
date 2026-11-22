# D2 e6: report (day shift of 22 Nov 2026)

Route: Opus director, building by hand. Both fixes were small, so Astra (GPT 6.2) was not called: 0 tokens.
Landed:
- round 1 (E6), merge 2fdfef2, commit 9ea8e9d
- round 2 (r2a), merge 59ada89, commit 7734770

## For the owner: E6 in one paragraph
A game in a world sometimes played differently from the same game alone. N3's hockey change "pass out of pressure"
hashed differently from frame 2050 on. The cause was in how a world gives each game its own physics space. Every body
is born in the viewport's default space and is then moved into the game's space (world/pack.gd `adopt()`). A small
probe (40 boxes, the same scene built both ways) showed what the move does in Jolt. A body that joins its first space
is filed in the broadphase where it stands. A body moved into a space is filed as if it already stood where it will be
at the next step. So the game's space listed the same 105 colliders in another order from the lone runner's. When a
skater touched several static shapes at once (the net frame and the boards), the contacts were solved in that other
order, and a coordinate rounded 0.001 m apart. The fix is two lines in `adopt()`: right after the move, the body's
transform is stated again, which files it the way a first join does. The world's space is now built exactly as the
lone runner's. No lone hash moved (129 of 129 pack verbs identical), the world gate is 8/8, and r2a now plays the same
in a world and alone for 20000 frames on three seeds.

## Acceptance

### 1. Selftest (block 760): MET
- Files:
  - `engine/tools/selftest.d/760-e6-world-alone.sh`
  - `engine/kernel/runner/e6_space_case.gd`
  - the probe hook `TL_BODY_ORDER=<file>` in `engine/kernel/runner/pack_life.gd`. Both drivers write the pack space's
    query order at frame 3; it is inert unless the variable is set.
- Cases:
  - `e6.space_order`: one scene built twice, once in the default space and once through a real pack holder's `adopt()`;
    the query order is compared at frame 3.
  - `e6.space_contact`: four CharacterBody3D movers (move_and_slide, as TLBiped) slide into a bin along walls, posts
    and floor at once; their transforms must be bit-equal at frame 360.
  - `e6.body_order`: hockey, `world.sh run` against `tl.sh bot`, both with TL_BODY_ORDER at frame 3.
- Results:
  - Fix: 3/3 PASS (`e6/selftest760_fix.txt`).
  - Main's pack.gd: 0/3 (`e6/selftest760_main_packgd.txt`). The order differs, slider00 is 0.000019 m off at frame
    360, and hockey differs in 38 lines.
  - The Director re-ran both on his side: 3/3 PASS on the fix; with main's pack.gd, space_order and space_contact FAIL.
- On bare 45f108d, `e6.body_order` fails with "no body order written" (the hook did not exist there). The two space
  cases fail on bare main as they are.

### 2. r2a hashes the same in a world and alone: MET
Tree: `.tl/w_r2a` (N3's engine copy with r2a). The all-AI match bot is a scratch copy of bot_match with LIMIT 20000
(not landed).

| Run | Seed 1 | Seed 2 | Seed 3 |
|---|---|---|---|
| Fix, all-AI match bot, 20000 frames: world = alone | 85c0a58e | a4fabbbd | 62c46196 |
| Control on main's pack.gd, same bot | same | DIFFERENT: e702acb7 vs a4fabbbd | DIFFERENT: dbbdcd64 vs 62c46196 |
| Fix, bot_hockey (the bot ends the run) | same, 6750 frames | same, 3177 frames | same, 2688 frames |
| Main's pack.gd, bot_hockey | DIFFERENT: world ends at 6743 frames, alone at 6750 | | |

- Lone hashes are identical on main and with the fix.
- Cause check (before the fix was built):
  - With the lone runner moving bodies into its own space as adopt() does, alone = world at 2050 and 3000.
  - World `--space=shared` (no move) = alone.
- Evidence: `e6/r2a_world_alone_20000.txt`.

### 3. Hash A/B of every pack verb against main: MET (none moved)
- `tl check --tier full --only packs,world`, my tree against a copy carrying main's pack.gd.
- packs: 129/129 verb hashes and frame counts identical (`e6/ab_packs.txt`).
- world: 8/8 same in both runs; the rows are identical (`e6/ab_world_*.txt`). No world-side hash moved.

### 4. Round 2, r2a on the landed hockey: MET (effect within noise; see the reading)
- Code: `data/ai.json` pressure_m 3.5; `scripts/ai/brain.gd` (pressure_m in KEYS, and the carrier re-decides the moment
  an opponent he saw comes inside pressure_m); a README line. keep_off_m and spacing are untouched.
- Clip: `r2a/clip_red_pass_out_of_pressure_s1.mp4`.
  - 19.5 s, recorded in a window (d3d12, movie writer, 60 fps).
  - tests/bot_hockey_regular.gd (regular hand), seed 1, frames 1470-2640.
  - Three red passes made under pressure, at frames 1530, 2132 and 2530 (from the metrics moments of the headless run
    of the same seed).
  - Stills: `r2a/sheet_red_pass_out_of_pressure_s1.jpg`. The Director read three passes under pressure by eye.
  - Godot segfaulted on exit after --quit-after; the movie was complete.
- Metrics: `r2a/metrics_{before,after}_20seeds.txt` and `r2a/red_passes_under_pressure_20seeds.txt`. Four cells x 20
  seeds; 160/160 runs completed. Cells are rookie_newcomer, pro_regular, allstar_sharp and ai_pro, in that order:

  | Metric | rookie_newcomer | pro_regular | allstar_sharp | ai_pro |
  |---|---|---|---|---|
  | Red passes per possession | 1.4 -> 1.6 | 1.9 -> 1.8 | 2.1 -> 2.3 | 1.5 -> 1.3 |
  | Completion, all passes | 86 -> 89 % | 85 -> 87 % | 89 -> 88 % | 90 -> 89 % |
  | Completion, red AI | 85 -> 84 % | 92 -> 90 % | 92 -> 93 % | 91 -> 89 % |
  | Red hits kept (stumble + down per min) | 2.3 -> 2.6 | 3.9 -> 4.0 | 3.2 -> 3.9 | 5.3 -> 4.8 |
  | Red passes made with a blue inside 3.5 m, per live min | 5.4 -> 5.8 | 7.6 -> 6.2 | 8.8 -> 8.1 | 5.5 -> 5.4 |
  | Possession median | 3.4 -> 4.0 s | 2.8 -> 3.4 s | 3.0 -> 3.2 s | 3.7 -> 3.3 s |

- Honest reading: on 20 seeds the effect is inside the noise. N3 measured r2a before round 3 landed, and round 3
  already makes the carrier look again every 7-8 frames, so the pressure event adds little now. It landed because the
  owner asked for it once E6 was fixed. It was not tuned further (Director, 15:2x).
- 56/56 hockey bot tests PASS, plus lint and smoke.
- world.alone: 8/8 same; hockey is bcc1f5dc@5256 in both runs.
- style.frame.rink: PASS (`r2a/style_frame_rink_572.jpg`).

### 5. Gates
- Fast tier (my tree, before and after r2a): 5/5 PASS. arch 12/12, assets 4/4, cards 3/3, devx.test 229/229,
  foreman.typecheck clean.
- packs:
  - Round 1: 128/129, both on my tree and on main's.
  - Round 2: 128/129.
  - The one failure each time is hockey invariants.many_budget, a wall-clock p50 against a 1.0 ms budget:

    | Run | p50 |
    |---|---|
    | Round 1, fix | 1.107 ms |
    | Round 1, main | 1.218 ms |
    | Round 1 re-run | 1.088 ms |
    | Round 2 | 1.119 ms |
    | Director, d22-int | 1.166 ms |

    The machine was loaded (two gates at once, plus other sessions), and main fails it equally, so it is not evidence.
    The other invariants pass.
- world: 8/8 PASS (round 1 and round 2).
- selftest e6.: 3/3. style.frame.rink: 1/1.
- Rest of the full tier (kernel.selftest, kit.selftest, seeds, perf), on the round-2 tree, run read-only:
  - kit.selftest: PASS, 120/120.
  - seeds: PASS, 39/39.
  - perf: NOT RUN (machine BUSY, 94 % use).
  - kernel.selftest through the gate: STOPPED at the gate's 1800 s cap on the loaded machine after 117 cases passed
    and 0 failed. That is a stopped run, not a pass.
  - kernel suite straight through `bash engine/tools/selftest.sh` (no cap; r2a/kernel_selftest_uncapped.txt), 16:03-16:44:35: COMPLETED with its
    trailer line, "selftest: 491 passed, 0 failed".
    - It includes e6.space_order, e6.space_contact and e6.body_order; style.frame.rink; every hockeyfun, hockeymech and
      hockeyplay case; and D1's home.* and land.* cases.
    - It ended before the Director's 16:44 stop request; the processes were then stopped, and none was left running.
    - This is not the gate's own step; the verdict re-runs the suite on main 59ada89+.

## Changed files
- Round 1:
  - `engine/kernel/world/pack.gd`: adopt() states the transform after body_set_space / area_set_space.
  - `engine/kernel/runner/pack_life.gd`: write_body_order(), TL_BODY_ORDER at frame 3.
  - `engine/kernel/runner/e6_space_case.gd` (+ .uid), new.
  - `engine/tools/selftest.d/760-e6-world-alone.sh`, new.
- Round 2: `engine/packs/hockey/data/ai.json`, `scripts/ai/brain.gd`, `README.md`.
- No change to API.md (nothing pack-facing) or to any contract.

## Behaviour changes
- In a world, a pack's own space is now built as the lone worker's default space is. No lone hash moved, and no world
  hash of the 8 games moved.
- Hockey: the AI carrier re-decides on pressure. 34 hockey verb hashes moved; duel and parkour moved 0.

## For the owner to look at
- Play hockey. The red carrier should pass away from a man closing on him. The clip shows what to look for.

## The three hockey rows N1 flagged (N3's ENGINE-NEEDS), as next items, with my view
1. TLTrigger `entry_side`: goals count only through the mouth.
   - Worth building: a small, general kernel option (a plane normal; `entered` fires only for a body that crossed that
     face). Every goal game needs it, and hockey's shim (`goal_by_position` remembering a puck from behind the line)
     is game logic in the wrong place.
   - It moves no hash for a puck that enters from the front.
   - Build it with a selftest that shoots a body through each face.
2. `TLContext.history(frames)`: perception lag for bots.
   - Worth building, but after one more consumer. The duel's rivals are the second; then the API is shaped by two
     games, not one.
   - Hockey's `sense.gd` ring (24 frames, about 20 us a frame) works; a kernel ring saves the cost and gives every
     editor game with bots the same "what he could see N frames ago".
   - It must record in the pack's own tick order, so a world and alone see the same history.
3. `ctx.own_tick`: a deterministic sub-rate equal in a world and alone.
   - My view: test E6 first. N3 saw `frame % 2` steering, and a count of think() calls, hash differently in a world, and
     did not establish the cause. The kernel already passes the pack its own tick (pack.gd `frames_done`, the same as
     the lone frame). Any AI change re-rolls the play and can produce a new multi-shape contact, which is exactly
     E6's divergence.
   - So re-run N3's every-other-frame steer on the fixed kernel before adding an API. If it hashes the same now,
     own_tick is not needed and the row closes. If not, the trace tool in the next row (`world.sh alone --trace` on
     both runners, first differing frame) is the right tool, not a new counter.

## Questions for the Director
- RUNNER.md (a contract) could name `TL_BODY_ORDER` as a diagnostic, and the rule that a world builds a pack's space
  as a first join builds it. Left to you.
- The all-AI 20000-frame bot (bot_match with LIMIT 20000) found divergences that bot_hockey's short games did not:
  seeds 2 and 3 on main.
  - The world gate runs the manifest's first test, which for hockey ends at its result (about 2700-6700 frames).
  - A long all-AI test, or a `--test` option for `world.sh`, would make the world gate bite harder.

## Next three things this lane would do
1. Re-run N3's `frame % 2` steer on the fixed kernel to settle the own_tick row (item 3 above).
2. `world.sh --test=<t>`, plus a long all-AI hockey test in the world gate, so world = alone is checked over 20000
   live frames, not only until the first bot's result.
3. TLTrigger `entry_side` with its selftest, then retire hockey's goal shim.
