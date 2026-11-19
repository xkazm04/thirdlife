# hunt2 findings: bug hunt round 2 on the fixed tree (night of 19 Nov 2026)

(This was saved as findings.txt because this agent may not write report files ending in .md.)

The tree is worktree `n19-hunt2`, cut from main `9ea78b0`. The route was Opus directing Astra (`gpt-6.2-astra`, high effort), in three
Codex sessions. Astra wrote every repro. The director (Opus) re-ran every repro on this worktree and graded it. Grades:
- **verified**: the repro printed `REPRO <id>: FAIL` for the director on the unfixed code.
- **not a defect**: it reproduces, but the behaviour is intended.

Astra's own write-ups are in `astra-findings.md` (A1-A15), `astra-findings-2.md` (B1-B12) and `astra-findings-3.md` (C1-C12).
They hold the pasted output, the blame and the suggested fixes. The repros are in `repro/`. Run each from the worktree root:
- a `.gd.txt` repro: `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh <ID>`
- a `.sh` repro: `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/<ID>.sh`
- a `.py` repro: `python docs/shifts/2026-11-19-night/lanes/hunt2/repro/<ID>.py`

Scope (who can fix it):
- **hunt2**: fixed in this lane.
- **walker**: `engine/kernel/world/**`, `runner/**`, `style/**`, `rigs/**`, owned by the live walker lane.
- **Director**: code no live lane claims (devx, `engine/tools/*.sh`, the bugfix-37 selftest blocks).

The "may predate" column comes from `git blame`: "yes" means the line is older than 17 Nov.

In total, 36 defects were verified out of 37 reported (A3 is not a defect). This lane fixed 18 of them. The other 18 are listed for the
Director: 3 high, 9 medium, 6 low. One more low (H1) is the director's own.

## Fixed in this lane (each has a permanent case in `engine/tools/selftest.d/360-hunt2-fixes.sh`)

How the fixes were proven: the Godot cases were run against a copy of the engine that holds the HEAD (9ea78b0) versions of every
changed file. 18 of 19 printed FAIL there. `goal_in_net` is a control and passes on both versions. The C1 case also fails on that
copy: the paddle bot exits 1 at target 1. On the fixed tree all 21 cases pass.

| id | severity | defect (file:line at 9ea78b0) | may predate | fix | case: HEAD copy -> fixed |
|---|---|---|---|---|---|
| A2 | medium | The editor binary without `--games` drops the hockey plot. The export name `ice_hockey_three_against` is not the name of its folder, `engine/packs/hockey` (`engine/boot/boot.gd:181`) | yes (16 Nov rename) | `_pack_dir` falls back to the `from` field of `boot/games.json`. Comments were reflowed to keep boot.gd at its 600-line budget | `boot_editor_games`: 7/8 -> 8/8 plots |
| A4 | low | A `use_velocity` chase camera swings to the target's facing below 1.2 m/s (`kernel/api/tl_chase_cam.gd:251`) | yes | Travel is measured over as many ticks as 2 cm takes, and the travel heading is kept at rest. `snap()` still takes the facing (Q19) | `chase_slow_travel`: 0.00 -> 7.00 m behind |
| A6 | medium | A held ball whose holder is freed stays frozen in the air. A freed node compares equal to null (`tl_ball.gd:213`, `:173`) | yes | A `_held` flag kept apart from the node | `ball_holder_freed`: frozen -> falls 1.27 m |
| A7 | medium | The hockey position fallback scores a puck flying over the net. It also reads world x/z, so it never fires in a pack placed away from the origin (`packs/hockey/scripts/rink_api.gd:440`) | yes | `p.y <= GOAL_TOP` (1.55 m) and pack-local `puck.position` | `goal_over_net` 1 -> 0; `goal_offset_pack` 0 -> 1; control `goal_in_net` 1/1 |
| A8 | medium | Hockey's api and hits helpers form a RefCounted cycle that survives every unload (`main.gd:273`, `hits.gd:35`) | yes | `rink_api.hits` is held weakly | `hockey_helpers_freed`: 4/4 -> 0 alive |
| A9 | medium | Seed Drive with an empty tank: tapping Shift boosts on alternate ticks, because one released tick recharges 0.000001. A full tank also burned 71 ticks, not 70 (`kernel/api/tl_vehicle.gd:189`) | yes | A tick burns only on at least half a tick of charge | `nitro_crumb` 30 -> 0; `nitro_full_tank` 71 -> 70 |
| A10 | low | `avoid_pull` is in parent units under a scaled parent (`tl_chase_cam.gd:156`) | no | It is measured through the parent's basis | `chase_pull_scaled`: 2.30/4.60 -> 4.60/4.60 |
| A14 | medium | The hockey rink kept out of the tree for a switch back outlives the pack (`main.gd:203`) | yes | A PREDELETE handler frees the venues, dress and pool kept out of the tree | `hockey_venue_freed`: alive -> freed |
| A15 | medium | Parkour C retry: a runner holding forward against the beam bounces about 3 cm in a 3-tick cycle (speed 0 / 0.57 / 1.13 m/s). `speed() < 0.5` blinks, so the cue blinks and most C taps are lost (`packs/parkour/scripts/main.gd:109`) | no (19 Nov) | Blocked means under 10 cm of travel across the last 8 ticks | `parkour_retry_pressing`: C moved him 0.02 m -> 4.16 m back |
| B1 | medium | Hockey's benched skaters, left out by the big-ice roster, outlive the pack (`main.gd:228`) | yes | The same PREDELETE handler | `hockey_bench_freed`: 2/2 -> 0 alive |
| B10 | medium | TLHand: a release lengthened to the minimum tap lands on the next queued press's frame, so the game sees one press. 64 taps gave 45 edges, and `taps_lost` stayed 0 (`kernel/api/tl_hand.gd:363`) | yes | A postponed release pushes what follows by at least one frame | `hand_double_tap`: 45 -> 64 edges |
| C1 | medium (Astra: high) | The Seed Paddle and Seed Drive bots reject wins at any target but 5 goals or 3 laps, though the seed guides invite changing it (`seed_paddle/tests/bot_win.gd:60`, `seed_drive/tests/bot_laps.gd:60`) | yes | The bots read `score_to_win` and `laps_to_win` from `rules.json` | `seed_target_paddle` / `_drive` (copies at 1 goal and 4 laps): exit 1 -> 0 |
| C2 | low (Astra: high) | A plain action named `aim@x` collides with the recorded x of an aim `aim`, so a replay folds them (`kernel/api/tl_input.gd:56`, `:436`) | yes | `@` in a declared action or aim name is an error (API.md says so) | `input_at_reserved`: declared -> refused |
| C3 | medium | `TLLaws.material()` returns the shared row, so editing it changes every context's physics: one pack's edit reaches another pack in a world (`kernel/api/tl_laws.gd:92`) | yes | It returns a copy. Internal reads use `_row()` | `laws_material_copy`: 0.03125 -> 1.00000 |
| C5 | medium | An idle Seed Drive player sees "THREE LAPS DONE" on time-out. The rules name the only side the winner on time (`seed_drive/scripts/main.gd:89`) | yes | Text depends on `reason == "laps"` | `drive_time_hud`: THREE LAPS DONE -> OUT OF TIME (time) |
| C7 | medium (Astra: high) | Timber Run placed away from the origin by a world (`--at`) puts the runner off the course. He falls 5 times in 120 idle ticks: `place()` takes world coordinates and was given course ones (`parkour/scripts/main.gd:58`, `:81`) | no (18 Nov) | `runner.place(ctx.root.to_global(spawn_at))` | `parkour_offset_pack`: station -100 m, 5 falls -> 0 m, 0 |
| C10 | medium | Seed Wall stores each piece's origin when the queued break is handled, after a physics step has moved it. Score and pieces disagreed on 26 ticks (`seed_wall/scripts/main.gd:134`) | yes | The origins are stored in the `broke` signal handler | `wall_origin_at_break`: 26 -> 0 disagreeing ticks |

The block refuses a stopped run (finding A1, applied to this lane's own block). The director tried both failures:
- A fake child prints a passing case line and kills itself: `FAIL ... the case run stopped (Godot exit 143)`.
- A child exits 0 without the `HUNT2END` trailer: `FAIL ... trailer HUNT2END missing`.

## Verified, not in this lane's scope or not fixed (for the Director and the owning lane)

| id | severity | defect | file:line | scope | may predate | repro |
|---|---|---|---|---|---|---|
| B2 | **high** | A warm construction-site cache changes a game's tick count and state hash. The scheduler footprint is restored from the cached display radius: 220 vs 123 pack ticks over the same 240-tick walk | `engine/kernel/world/site.gd:361` (setup `:76`) | walker | no (18 Nov) | `python repro/B2.py` |
| B4 | **high** | A native Windows `--input` path (backslashes) replays without the game's stage recording: gas ticks 71 vs 0, and a different hash | `engine/kernel/runner/visit.gd:69-70` | walker | yes (11 Nov) | `run.sh B4` |
| B8 | **high** | `tl ladder` counts a bot run the verifier rejected (exit 1, `smoke.no_script_errors=false`) as a completed sample, and exits 0 | `devx/lib/commands/ladder.mjs:85`, `:46`, `:103` | Director | yes (16 Nov) | `python repro/B8.py` |
| A1 | medium (Astra: high) | Block `310-bugfix-cam` accepts a case line from a Godot child that was then killed. It never reads the exit status or asks for a trailer, so selftest exits 0. By inspection, not repro, the other bugfix-37 blocks (`320`, `330`, `340`) never check the child's exit status or a trailer either | `engine/tools/selftest.d/310-bugfix-cam.sh:14`, `:22` | Director | no (18 Nov) | `bash repro/A1.sh` |
| A11 | medium | Two slope jumps clear a 2.8 m bank at 56°, above the 55° walk limit. This contradicts D14's "not hop up a steep bank" and belongs with the owner's open D14 question | `engine/kernel/world/terrain/world_body.gd:302-305` | walker | no (18 Nov) | `run.sh A11` |
| B3 | medium | The site's job-log reader accepts events with required fields missing, and unknown keys inside packages | `engine/kernel/world/site/log.gd:80-83` | walker | no (18 Nov) | `run.sh B3` |
| B5 | medium (Astra: high) | `tl.sh seeds <filter>` exits 0 when the filter selects no case. The devx gate has its own zero check | `engine/tools/seeds.sh:94` | Director | yes | `bash repro/B5.sh` |
| B6 | medium (Astra: high) | `tl.sh import` exits 0 when Godot cannot start | `engine/tools/tl.sh:84` | Director | yes | `bash repro/B6.sh` |
| B7 | medium | Concave floor faces are dropped from the world's collision copy by their centroid. A visible floor whose triangle centres lie outside the plot disc loses all collision, and the visitor falls to -26.6 m (fixture geometry) | `engine/kernel/world/terrain/world_space.gd:271`, `:330` | walker | no (18 Nov) | `run.sh B7` |
| C4 | medium | Hockey: while the rule dial is open the rules clock stops, but a loose puck keeps sliding (1.37 m in 30 paused frames). **Not fixed**: it changes hockey play, and the owner's 18 Nov rule defers hockey decisions | `engine/packs/hockey/scripts/main.gd` (dial pause) | hunt2 scope, owner | yes | `run.sh C4` |
| C6 | medium | Hockey: the goal trigger scores a puck that touches the goal line from the field side (centre 0.06 m short). The comment at `main.gd:260` says the trigger decides "the whole puck crossed". **Not fixed**: it moves goal timing (hockey hashes), so it waits on the owner | `engine/packs/hockey/scripts/main.gd:263`, `:355` | hunt2 scope, owner | yes | `run.sh C6` |
| C7-kernel | medium (question) | `TLBiped/TLBall/TLVehicle.place()` set `global_position`. API.md:819-821 says: stay in pack coordinates; a literal position passed to a call that wants a world position works only while the pack sits at the origin. Parkour is fixed locally (C7). Should `place()` take pack coordinates, so that every pack placed with `--at` is safe? | `engine/kernel/api/tl_biped.gd:202`, `tl_ball.gd:147`, `tl_vehicle.gd:167` | Director (API) | yes | `run.sh C7` on another pack |
| A12 | low | The `world` gate's games.json reader accepts unknown keys and explicit null | `devx/lib/gate/steps/world.mjs:23` | Director | yes | `bash repro/A12.sh` |
| A5 | low | A downed walker-feel biped speeds up from 0.57 to 3.97 m/s, because the cached step wish overrides the forced brake. No shipped caller combines walker feel and `down()` | `engine/kernel/world/terrain/world_body.gd:156` | walker | no (18 Nov) | `run.sh A5` |
| A13 | low | The coyote jump is accepted on the 7th airborne tick (limit 6) | `engine/kernel/world/terrain/world_body.gd:161` | walker | no (18 Nov) | `run.sh A13` |
| B9 | low | A live site never re-checks a promotion whose files arrived after its log line | `engine/kernel/world/site.gd:344-347` | walker | no (18 Nov) | `run.sh B9` |
| B12 | low | A rejected first style load (missing `--style` file) leaves the palette empty | `engine/style/tl_style.gd:78` | walker | yes | `run.sh B12` |
| H1 | low (director) | A walker pushing into a wall bounces 2.8 cm in a 3-tick cycle (x -0.323 / -0.351 / -0.342 m; speed 1.13 / 0.00 / 0.57 m/s). This caused A15, and may show as a shiver against walls | `engine/kernel/world/terrain/world_body.gd` (`_slide_move`) | walker | ? | `run.sh H1-beam-trace` |

## Backlog (low, in scope, not fixed)

| id | defect | file:line | repro |
|---|---|---|---|
| B11 | `avoid_margin` and `avoid_min` are used in the parent's units. Under a parent scaled 0.5 / 1 / 2, a 0.30 m wall clearance becomes 0.15 / 0.30 / 0.60 m. No shipped parent is scaled | `engine/kernel/api/tl_chase_cam.gd:207` | `run.sh B11` |
| C8 | All three seeds accept misspelled tuning keys. These are pack data with no schema, but the seeds are the models builders copy | `engine/seeds/*/scripts/main.gd` (tuning reads) | `python repro/C8.py` |
| C9 | `boot.gd check/probe` exit 0 when their report files cannot be written. `export.sh check` then fails on the missing file | `engine/boot/boot.gd:593` (and `boot/probe.gd`) | `python repro/C9.py` |

## Not a defect

| id | why |
|---|---|
| A3 | At rest 0.2 m short of the beam, C sends him back. A slide cannot start at rest (`world_body.gd:134`, speed >= SLIDE_MIN), so C has no other meaning there, and the HUD shows "C  Retry from checkpoint" in that band. Since the A15 fix he must stand there 8 ticks (under 10 cm of travel) first |
