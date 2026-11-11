# WP1 journal (law kernel, host, runner)

Resume point. Newest entry last. Times are CEST from `date` or from file times (entries before 19:29 were first
written with estimated times that ran ahead of the clock; corrected at 19:29).

- 18:53 start. Read brief, contracts, FEASIBILITY 4-6, spike patterns (sim.gd, player.gd, g.sh).
- 18:56 created engine/ skeleton: project.godot (Jolt, 60 Hz, Forward+), packs/.gitkeep.
- 18:59 probed: Logger subclass + OS.add_logger works in 4.7.2 (file, line, error type, script backtraces), load()
  of an absolute-path .gd works, --log-file works, headless start about 0.4 s.
- 19:03 law tables written (kernel/data/materials.json, surfaces.json).
- 19:09 spine up: host.gd (supervisor) + runner/{manifest,lint,logger,worker}.gd, api/{tl_context,tl_input,tl_laws,
  tl_cameras,tl_chase_cam,tl_orbit_cam,tl_bodies,tl_trigger,tl_contact,tl_damage}.gd, standin/, tools/tl.sh,
  examples/pack_min. lint and smoke passed on pack_min on the first run.
- 19:11 all five verbs pass on pack_min (lint, smoke 3600 x2 same hash, seed 2 differs, invariants, bot, capture).
  invariants caught a real defect in my own pack_min (balls rolled off the floor, below y = -50): kerbs added.
- 19:13 11 bad packs written under kernel/examples/bad_*; tools/selftest.sh written.
- 19:17 capture workers crashed at engine start about 70 % of the time (access violation inside amdxc64.dll while the
  Vulkan window opens; another Godot process was running). Not our code: the worker had not printed its first line.
  Fix: supervisor restarts a worker that died before "[tl] worker start"; windowed order default, d3d12, d3d12,
  default (TL_RENDER_DRIVERS overrides). d3d12 was 12 of 12.
- 19:20 law example ex_slide passes: measured friction within 6 % of the table (rubber on ice 4.57 m against 4.59 m
  expected, rubber on asphalt 0.43 m, wood on ice 15.28 m, wood on asphalt 0.89 m from 3 m/s). Needed
  physics/3d/default_linear_damp=0 in project.godot (the engine default 0.1 added a drag the table does not know).
- 19:23 wrote api/{tl_ball,tl_rules,tl_spawner,tl_fracture,tl_biped,tl_vehicle}.gd. ex_wall (ball + damage +
  fracture) passed its bot on the first run.
- 19:26 ex_walker (biped walk/run/skate, crate push, triggers, rules lap, orbit cam) and ex_car (vehicle slalom by
  input actions, nitro, brake test: asphalt 10.1 m against ice 96.0 m from 14 m/s = grip 0.99 and 0.104; law 1.0
  and 0.1) pass. Captures of car, walker and wall looked at; walker room enlarged (camera was behind a wall).
- 19:29 ex_bounce (restitution by pair law incl. overrides at the first touch, spawner, trigger, score): measured
  0.65 / 0.60 / 0.30 / 0.55 against law 0.65 / 0.60 / 0.30 / 0.55. selftest: 43 passed, 0 failed (47 s).
  Next: priority 7 (TLSteer, TLHud, TLVfx, TLAudio stand-ins), tl.sh play, hardening pass, API.md, final selftest,
  report.
- 19:34 priority 7 done as stand-ins: api/{tl_steer,tl_hud,tl_vfx,tl_vfx_node,tl_audio}.gd; ex_car now also runs an AI
  pace car (TLSteer.keep_lane: 143 of 147 m, at most 1.27 m off the line), a HUD, a nitro flame, a finish horn.
  ctx.pack_state() added (bots read game state through ctx, not through the tree). capture accepts --test=<bot>
  (kernel extension: a bot plays up to the captured frame). tl.sh play added (interactive, not a verify verb).
- 19:37 more bad packs: bad_error_storm (exit 3, script_errors), bad_setup_loop (exit 3 after 10 s), bad_size,
  bad_bypass/gen/part.gd (kit_parts_added 1). Watchdog errors now name the script; the engine's "Failed to load
  script" echo of a parse error is dropped. Worker ends itself when its supervisor is gone (--parent).
  NOTE: the Bash tool halves doubled backslashes in commands; edit regex strings with the Edit tool only.
  Next: API.md, final selftest, line counts, report.
- 19:40 kernel/API.md written (17 sections + runner notes). TLBall.hold/release (possession), TLRules.standings,
  capability check in TLSteer.
- 19:43 ex_shuffle (puck at 30 m/s against a 0.2 m rail and through a 0.3 m trigger; hold/release; slide 4.66 m =
  friction 0.099 against law 0.10). It found a real defect: the thin trigger missed the fast puck once. Fixed in
  TLTrigger with a swept test of every TLBall's last step.
- 19:46 full selftest found my own regression: OS.is_process_running() only knows child processes, so the new
  "supervisor gone" check ended every worker that ran longer than a second. Replaced with an alive file the
  supervisor rewrites (worker gives up after 60 s of silence). Temp file removal now retries (logs were left
  behind after a killed worker).
- 19:48 extra checks, all pass: pack outside the project in a path with spaces (lint, smoke, invariants, bot,
  capture), direct invocation as in RUNNER.md, cold start with no .godot (supervisor imports, 3.9 s), four
  invariants runs at once (8 workers, one hash).
  Next: final full selftest, line counts, report.
- 19:50 full selftest: 52 passed, 0 failed (67 s). (Times of the four entries above corrected from the clock.)
- 19:52 Director's amendments folded in: TLBall.create({part = ...}) and TLBodies.from_part() accept kit parts in
  the dynamic-prop convention (tl_dynamic, tl_shape, tl_shape_offset, tl_material, tl_mass_hint); TLStandin.dynamic_part
  makes one for tests; ex_shuffle uses both (puck 0.17 kg and paddle 1.5 kg from the mass hint). TLBiped sends the
  rig its mode in _ready, not before it is in the tree. lint level was already "V1"; unknown sockets already
  tolerated (TLVfx.attach(null) returns null). Next: API.md update, final selftest, line counts, report.
- 19:54 final selftest after the amendments: 52 passed, 0 failed (76 s). No Godot process of mine left running.
  Work complete against the brief's list; report returned to the Director as the final message.

# WP4: kit into the engine, then three seed packs (builder journal)

- 19:59 start (clock from `date`). Read the brief, the four contracts, API.md, ex_car, tl.sh, selftest.sh, KIT.md,
  LAYOUT.md, RIGS.md, STYLE.md, k.sh and the Director sections of the WP1 and WP2 reports.
- 20:01 moved the kit lab project's kits/, rigs/ and style/ -> engine/ (same res:// paths); its lab/ -> engine/kits_lab/;
  its tools/{selftest,validate,gen_docs}.gd + convert_laneb.py -> engine/kits_lab/tools/; k.sh -> engine/tools/k.sh
  (paths fixed: res://lab -> res://kits_lab, captures -> kits_lab/captures). MOVED.md written in the old directory.
  project.godot: added the kit lab's rendering block (d3d12 driver, msaa, shadow size, clear colour).
  `bash engine/tools/k.sh selftest`: 86 passed, 0 failed (26 s). `k.sh validate`: 7 files, 0 failed.
- 20:04 `bash engine/tools/tl.sh selftest` with the kit installed, before any kernel change: 52 passed, 0 failed (62 s).
  The examples now get real rigs through TLStandin.rig (ex_car braking on ice 96.2 m, was 96.0 with the stand-in).
  Next: kernel fixes (bot budget -> exit 1; d3d12 default; vehicle steer sign: kernel +1 = right, rig +1 = left),
  then example pack ex_kit with the four new selftest cases, then captures.
- 20:08 Step 1 kernel changes (the list for the report):
  1. kernel/runner/worker.gd (~l.227): a bot not done within --frames no longer trips the watchdog; it collects the
     bot result and ends the run. kernel/host/host.gd (~l.148): `bot.completed` false + error kind `bot`
     "frame_budget: ..." -> outcome failed, exit 1 (Director's decision 1). tools/selftest.sh bad.bot_never_done: 3 -> 1.
  2. kernel/host/host.gd (~l.320): windowed worker driver order is d3d12 x3 (was default, d3d12, d3d12, default);
     project.godot also sets rendering_device/driver.windows=d3d12 (Director's decision 5).
  3. kernel/api/tl_vehicle.gd (~l.266): sends -steer to the rig (controller + = right, RIGS.md + = left);
     kernel/standin/tl_standin_rig.gd (~l.111): stand-in wheel yaw follows the rig's sign. Found by reading
     RIGS.md; ex_kit now measures it (steering right gives a negative wheel yaw and a right turn).
  4. kernel/standin/tl_standin.gd: new `standin_rig(family, params)` so the fallback stays testable now that
     TLRigs is installed.
  5. New example kernel/examples/ex_kit (pack + bot) and 9 selftest cases: kit.lint, kit.bot,
     kit.ball_on_ice_slides_by_law (friction 0.1005 against law 0.1), kit.wall_and_crate_break (16 and 6 pieces),
     rig.biped_walks_and_skates (29 bones, 2.30 m/s, leg swing 0.57, skate 9.5 m/s), rig.vehicle_drives,
     standin.fallback_still_works, kit.invariants. `tl.sh selftest kit`: 9 of 9.
  6. kernel/API.md: section 14 (kit installed: what happens by default), 15/16 (bot budget exit 1), 18 (d3d12), table.
  Nothing else needed changing: laws on kit bodies, TLBall/from_part on kit dynamic props, TLFracture on kit
  Intact/Pieces and the rig seam (metrics, set_locomotion, play, set_param, tick) worked as written.
- 20:07 looked at five windowed frames of ex_kit (ice, wall, walker, skater, car; d3d12): lane-B look installed
  (painted sky, ink lines, toon bands), real biped mid-stride on kit concrete, skater on the ice lane, kit wall
  cracked into pieces with the steel ball in it, coupe on tarmac with shadow. Kernel-made balls are plain black.
  Next: full selftest, then seeds (paddle, drive, wall).
- 20:10 full `tl.sh selftest` after the kernel changes: 60 passed, 0 failed (52 old + 8 new: kit.lint, kit.bot, five
  claims, kit.invariants). STEP 1 PROVEN: both selftests pass in one project, frames looked at.
- 20:12 kernel gap found while designing seed.paddle: the kit `paddle` is "a part the game moves", TLBodies.from_part
  makes a free rigid body for it, and the kernel has no door to move a body under control or keep it on a rail.
  Added (kernel change 7): option `lock` (world axes x y z rx ry rz) on TLBodies.make and from_part, and
  `TLBodies.drive(body, velocity, max_accel)`. tl_bodies.gd +30 lines; API.md section 4. For the Director to bless.
  Next: seeds/seed_paddle.
- 20:16 seed.paddle (engine/seeds/seed_paddle) done: lint 0 bypasses (128 script + 33 test lines, kit_parts_added 0),
  smoke, invariants (hash bc93a9a4c892f2ab twice at seed 1; seed 2 gives 000eda488e72f0fe), bot wins 5:0 at seeds
  1, 2, 3 (6,775 frames at seed 1). Venue is one tl.layout/1 file with terrain. Captures paddle_court_f400/f2400,
  paddle_baseline_f520/f2000 looked at: lane-B look holds (forest, mountains, cabin, stands, ink lines).
  Kernel change 8: lint allows README.md at the pack root (the brief wants one per seed; PACK.md does not list it).
  Mistakes so far: a bot variable named `scores` counted as a bypass; a rolling ball loses speed when re-shot, so the
  court is ice and the ball `planar`; the rival was unbeatable at 3.6 m/s. README files still to write.
  Next: seed.drive.
- 20:22 seed.drive (engine/seeds/seed_drive) done: lint 0 bypasses (130 script + 46 test lines), smoke, invariants
  (b9adbb1967e36108 twice at seed 1; seed 2 e6662471f07f7d94: cone jitter comes from ctx.rng), bot: 3 laps in 58.6 s of
  90, pad 3 times, 3 nitro bursts, at most 1.2 m off the line. Captures drive_chase_f300/f1560, drive_overview_f420/
  f1500 looked at (coupe on the kerbed loop, forest, cabin, tyre stacks). Mistakes: bot variable `laps` = bypass;
  9 m look-ahead was too short to brake for a bend (ran wide, left the road), fixed with a second, speed-scaled
  point `far`; nitro toggled 254 times without hysteresis. Kit gap: `cone` is static only; the seed re-tags it
  as a dynamic prop by hand (_loose_cone). Next: seed.wall.
- 20:29 seed.wall (engine/seeds/seed_wall) done: lint 0 bypasses (131 script + 51 test lines), smoke, invariants
  (da4bdc3f65cc07ae twice at seed 1; seed 2 4b2de68d7beff849: block toughness is drawn from ctx.rng), bot wins by
  score at seeds 1-4 (40-45 pieces down in 18.5-21.2 s of 60, 15-17 throws). Captures looked at (walker carrying a
  ball, rubble, crane, cabin, mesa). Mistakes: the bot saw "over" one frame before the pack had handled its queued
  `finished` event (events are now handled at the end of _pack_tick); every bounce puffed white stand-in dust
  (now only wall hits, tinted); score target 44 of 48 was too tight for some seeds (now 40).
  TLVfx stand-in particles are unlit white squares: they do not match the lane-B look (kernel gap, not fixed).
  New tool engine/tools/seeds.sh (all verbs on all seeds; `seeds.sh sheet` rebuilds the contact sheet).
  Next: seeds.sh run, sheet, README files, final selftests, report.
- 20:33 README.md written for each seed and engine/seeds/README.md (how to write a pack; ten mistakes).
  engine/seeds/captures/seeds_sheet.png built by `seeds.sh sheet` (12 frames: 3 seeds x 2 cameras x 2 frames) and
  looked at. `seeds.sh`: 24 passed, 0 failed.
- 20:36 FOUND: seed.wall's bot run was not repeatable (seed 1 gave 19.8 s / 15 throws in 8 runs and 20.3 s / 16
  throws in 3). Cause: TLContact took the pair law from the FIRST colliding body the physics engine reported; with a
  ball against rubble and ground at once that order differs between runs. Kernel change 9 (tl_contact.gd ~l.37):
  choose the pair with the lowest friction, alphabetical on a tie. After the fix 10 of 10 runs gave the same hash
  (6366b88f838e, 20.3 s). `invariants` did not catch it because smoke presses nothing, so nothing breaks.
  Also: no literal mention of the old kit lab directory is left under engine/ (journal reworded, three comments).
  Next: final tl.sh selftest, k.sh selftest, seeds.sh, 5 repeated bot runs per seed, re-capture the sheet, report.
- 20:41 final checks after the last kernel edit (tl_contact.gd): `tl.sh selftest` 60 passed, 0 failed;
  `k.sh selftest` 86 passed, 0 failed; `k.sh validate` 7 files, 0 failed; `seeds.sh` 24 passed, 0 failed;
  5 repeated bot runs per seed at seed 2 gave one state_hash each (paddle 944b605a62d5, drive f443d2e59a7f,
  wall 0dd2cd09aec1).
- 20:54 seed.wall: a ball taken back into the hands no longer queues a "hit" (cosmetic); wall verbs re-run (8 of 8),
  bot at seeds 1-5 wins by score (40-45 pieces, 18.5-21.2 s). Sheet rebuilt with the final code and looked at:
  engine/seeds/captures/seeds_sheet.png (the stray squares near the walker are particles of the kernel's stand-in
  dust burst flying wide). `k.sh cap main hero` run once in the engine project: the moved lab scene captures
  (kits_lab/captures/wp4_check_main_hero.png).
  Not done: `tl.sh play` was not run on any seed (no interactive window allowed); the HUD was never seen (captures
  hide it; bots check its text); sound was checked by the event log only.
  No Godot process of mine is left (the three running belong to the other builder's engine snapshot).
- 20:56 WP4 complete against the brief; report returned as the final message. 57 minutes from 19:59.

# WP5: close-out fixes before the second real job (builder journal)

- 21:14 start (clock from `date`). Read the brief, contracts (second-round amendments), WP4 Director verification,
  this journal, API.md, tl.sh. Time-box ends 22:10.
- 21:15 item 1 reproduced: `tl.sh capture` of the marble pack (course, bot_race, f1000) ->
  engine/seeds/captures/wp5/marble_before_f1000.png, looked at: near-black course and marbles on the painted sky, no
  ground. Cause found by reading style/tl_style.gd + toon.gdshader: the style's environment has BLACK ambient (the toon
  shader is `ambient_light_disabled` and adds its own hemisphere ambient), and its sun sits 11.5 degrees above the
  horizon, so a plain StandardMaterial3D (TLStandin.material, used by TLBodies.make / TLBall) gets no ambient and a
  grazing sun. The sun IS installed (shadows show). Also: the pack's own gen/look.gd never ran (item 5), so its own
  sun/environment were never added. Plan: TLStyle.flat_material (toon, any colour), TLStandin.material uses it,
  style ambient for foreign materials, a style-owned default ground when the pack built no kit ground.
- 21:19 item 1 fix in, first after-capture looked at (engine/seeds/captures/wp5/marble_after_f1000.png): course is
  orange wood with ink lines and toon bands, ice plate pale lavender, red and steel marbles readable, long sun
  shadows on a grass ground to the horizon. Changes: style/tl_style.gd `flat_material(color, metal)` (toon shader
  with a private 1-column lookup texture), `ground(y, key, half)` (visual only), `_apply_world` ambient = mean of
  toon amb_sky/amb_ground (only reaches non-style materials: every style shader is ambient_light_disabled or
  unshaded); kernel/standin/tl_standin.gd `material(color, material_id)` asks TLStyle.flat_material,
  `install_default_ground(host, world)`; kernel/api/tl_bodies.gd + tl_ball.gd pass the material id;
  kernel/runner/worker.gd calls install_default_ground after _pack_setup (windowed only).
  Still to prove: a pack's own StandardMaterial3D (scratch pack), seed hashes unchanged.
- 21:21 item 2 built: kernel/host/host.gd `invariants` replays the manifest's first bot twice (option --bot-frames,
  default 36000), check `invariants.bot_deterministic`, metrics bot_state_hash / bot_frames (/ bot_state_hash_b).
  New bad pack kernel/examples/bad_bot_nondeterminism (idle hash equal twice, bot hashes differ: exit 1) and selftest
  case bad.bot_nondeterminism; min.invariants now also requires bot_deterministic ok. Hand runs: pack_min exit 0
  (bot hash 7dd11b8e after 228 frames twice), bad_bot_nondeterminism exit 1 with determinism ok + bot_deterministic
  false, bad_nondeterminism exit 1. Next: StandardMaterial3D proof, item 3 (TLVfx through style fx).
- 21:23 item 1, own StandardMaterial3D proven: scratch copy of pack_min + four meshes with the pack's own
  StandardMaterial3D -> engine/seeds/captures/wp5/plain_standardmaterial_after.png, looked at: orange, pale blue and
  red cubes lit with a clear light and shade side, the metallic sphere mirrors the sky; kernel floor/ramp in toon.
  (Kernel rubber balls are near-black: that is rubber's stand-in colour 0.14, not a lighting fault.)
- 21:25 item 3 built: style/tl_style_fx.gd `TLStyleFx.preset(name, opts)` + `preset_names()` (soft discs in palette
  colours, additive discs, inked toon chips for debris), kernel/api/tl_vfx.gd `_style_particles` uses it when
  TLStyle + TLStyleFx are installed (lifetime in frames stays the kernel's, headless unchanged: no particles).
  Captures engine/seeds/captures/wp5/wall_{yard_f330,player_f200}_{before,after}.png looked at: before = white unlit
  squares on the wall and beside the walker; after = small soft round dust puffs in the pack's tint and one small
  inked grey chip, no squares. (My first apply appended the fx block twice -> 23 parse errors, capture exit 3;
  duplicate removed, both captures then exit 0 with 0 errors.)
- 21:28 item 5 found and built (small): the marble pack's gen/look.gd does add_child(dress) then dress.set_script(s);
  the engine switches _physics_process on only when a node becomes ready, so a script attached afterwards never
  runs and prints nothing. kernel/runner/worker.gd `_find_idle_scripts` (after _pack_setup) lists pack scripts that
  define _process/_physics_process on a node that is not processing; result key `warnings`; kernel/host/host.gd puts
  them in the `smoke.loads` detail ("pack loaded; WARNING: scripts/look_dress.gd on node 'World/LookDress' never
  runs (_physics_process is off) ..."). Fails nothing. Marble smoke: warning shown, exit 0; seed_wall: no warning.
  Limit: a script with only _ready cannot be detected; a pack that switches its own processing off gets the warning.
- 21:29 item 4 docs: kernel/API.md new section "0. Start here" (7 points), look note under TLBodies, TLVfx text,
  section 14 (toon material for kernel visuals, default ground is a picture), section 16 (invariants = 4 runs,
  --bot-frames, warnings), section 17, generator note in section 1; seeds/README.md ("Kit first, boxes second,
  materials never", mistakes 11-13, invariants line); kits/KIT.md ("In a pack" paragraph above the generated
  tables); style/STYLE.md (flat_material, ground, plain ambient, TLStyleFx.preset).
  Preliminary `tl.sh selftest` started 21:28 in the background. Next: final battery (tl.sh selftest, k.sh selftest,
  seeds, seeds x3 hashes, marble lint/smoke/invariants/bot, final marble capture), then the report.
- 21:30 two small robustness edits (the last code edits): TLStandin.script_has caches its answer; worker
  _find_idle_scripts only looks at GDScript. Preliminary selftest before them: 61 passed, 0 failed.
- 21:38 FINAL BATTERY, all run after the last code edit (21:30:11):
  `bash engine/tools/tl.sh selftest`: 61 passed, 0 failed (60 old + bad.bot_nondeterminism), 101 s.
  `bash engine/tools/k.sh selftest`: 86 passed, 0 failed. `k.sh validate`: 7 files, 0 failed.
  `bash engine/tools/tl.sh seeds`: 24 passed, 0 failed.
  Seeds, seed 1: smoke hash paddle bc93a9a4c892f2ab, drive b9adbb1967e36108, wall da4bdc3f65cc07ae (= the WP4
  table: unchanged); bot three times each gave one hash: paddle cadd1cd9fffac7b1 (5:0, 6775 frames), drive
  36635c049bc6acd8 (3 laps, 58.6 s), wall 6366b88f838e3e78 (40 pieces, 20.3 s; = WP4). Bot at seed 2: paddle
  944b605a62d5, drive f443d2e59a7f, wall 0dd2cd09aec1 (= WP4 20:41 entry). NO SEED HASH CHANGED.
  Marble pack (site/marble-run-three-marbles-20261110-1/pack, read only): lint exit 0 (bypasses []), smoke exit 0
  (0f952b383d4a1e63), invariants exit 0 (bot_deterministic ok, bot hash dda2bb9e488d2ac3 = the Director's hash on
  the live engine), bot_race exit 0 (ranking steel, wood, rubber), bot_audio exit 0; every report carries the
  look_dress.gd WARNING.
  Captures re-made with the final code and looked at (engine/seeds/captures/wp5/): marble_after_f1000.png and
  marble_after_f300.png (lit orange chute, pale ice plate, three marbles readable, shadows on the grass ground),
  excar_nitro_f60_after.png (car on the kernel floor, small additive violet-white streak at the left exhaust
  beside the rig's own two flame cones; default ground to the horizon), wall_yard_f330_after.png (soft puffs).
  engine/seeds/captures/seeds_sheet.png rebuilt by `tl.sh seeds sheet` and looked at: no white squares left.
  Not verified: the kernel without TLStyle/TLStyleFx installed (stand-in fallbacks of material / VFX / ground);
  style_overcast.json in a capture; `tl.sh play`; a "broke" burst at its peak frame (debris chips seen only as one
  small chip in a seed; all nine presets were then drawn in a scratch pack, see the next entry).
- 21:39 all nine TLVfx presets fired at once in a scratch copy of pack_min (plus attached nitro_flame and smoke):
  smoke verb passed, captures at f112 and f135 had 0 script and 0 engine errors, looked at
  (engine/seeds/captures/wp5/fx_presets_f112.png, fx_presets_f135.png): round soft puffs, small round dots, inked
  debris chips, pastel confetti, a bright additive flame; no squares. Additive sparks wash out on the bright floor.
  `--bot-frames=100` on pack_min: bot_deterministic ok after 100 frames; `--bot-frames=abc`: not_run with a message.
- 21:39 WP5 complete against the brief; report returned as the final message. No code edit after 21:30:11.
- 21:47 WP5b (Director's follow-up on question 1, time-box 12 minutes): lint counts look and geometry made by hand.
  kernel/runner/lint.gd: BYPASS_STYLE (StandardMaterial3D / ShaderMaterial / ORMMaterial3D / DirectionalLight3D /
  OmniLight3D / SpotLight3D / WorldEnvironment / Environment `.new()` -> primitive `style`, in scripts/, gen/, tests/)
  and BYPASS_GEOMETRY (Box/Sphere/Cylinder/Capsule/Plane/Prism/Quad/Torus/Text/Point/Array/Immediate `Mesh.new()` and
  `MeshInstance3D.new()` -> primitive `kit`, in scripts/ and tests/ only; gen/ stays in kit_parts_added). The pattern
  label is the matched text. Same blanked-comments-and-strings text as the other patterns. Never a pass/fail.
  kernel/examples/bad_bypass: scripts/main.gd `_dress()` (lines 28-35: one material, one light, one mesh, one
  MeshInstance3D), gen/part.gd line 9 (a ShaderMaterial in a generator). tools/selftest.sh: bad.bypass_look and
  bad.bypass_gen_not_double_counted. kernel/API.md: bypass list in section 16, one line in "Start here" point 4.
  (My first try wrote the regex through a shell heredoc, which halves doubled backslashes: it failed before
  writing anything; redone with the Edit tool.)
- 21:53 after the last edit: `tl.sh selftest` 63 passed, 0 failed; `tl.sh seeds` 24 passed, 0 failed. Lint by hand:
  seed_paddle, seed_drive, seed_wall, pack_min, ex_slide, ex_bounce, ex_shuffle, ex_wall, ex_walker, ex_car, ex_kit
  all exit 0 with bypasses [] ; bad_bypass 10 bypasses, kit_parts_added 1; marble pack exit 0 with 7 bypasses
  (course_build.gd lines 14, 11, 9; look_dress.gd lines 38, 57, 64, 70), kit_parts_added 0.
  Not re-run after this edit: k.sh selftest (kits/rigs/style untouched), captures, the seeds' three-run hashes
  (lint is text only and runs in the supervisor; no worker code changed).

## N2: many games alive in one process (builder copy site/_work/n2/engine, started 2026-11-11 00:03)

- 00:08 baseline in this copy before any change: smoke hashes bc93a9a4 (paddle), b9adbb19 (drive), da4bdc3f (wall).
- 00:12 item 1, the pack instance. `TLContext` now owns what was static: `audio_events` (was `TLAudio.events`),
  `huds` (was `TLHud._all`), `ball_group` (was the tree-wide group `tl_ball`), `_warned` (was `TLAudio._warned`,
  `TLVfx._warned`, `TLLaws._warned`), plus `instance`, `holder`, `origin`, `space`. `TLContext.current` is now "the
  pack the kernel is calling"; `TLContext.of(node)` finds a node's pack through its holder (meta `tl_ctx`).
  Kernel nodes that are called by the engine, not by the kernel (TLContact.body_entered, TLTrigger overlaps), name
  their pack with `TLContext.enter/leave` before pack code hears the signal. TLFracture and TLSpawner take the
  seeded generator of their own pack (before: of `current`, which in a world would have been nobody's inside a
  physics callback: an unseeded generator). Ray queries of TLContact, TLVehicle, TLLaws.surface_under go to the
  pack's own space (`TLContext.space_state_of`).
- 00:17 items 3 and 4, first proof. `kernel/world/pack.gd` (the holder of one pack) and `kernel/world/world.gd`
  (the host), `tools/world.sh run|same|bench`, host.gd routes the modes `world` and `world-bench`. Each seed alone
  through the world host, in its OWN physics space, gives the single-pack worker's hash exactly: bc93a9a4,
  b9adbb19, da4bdc3f. `world.sh same --packs=seed_paddle,seed_drive,seed_wall` and `--packs=seed_wall,seed_wall`:
  PASS, three runs each (idle runs).
- 00:20 bot runs (the wall really breaks, the car really laps): each seed alone through the world host ends in the
  worker's bot hash and frame count (paddle cadd1cd9 at 6776, drive 36635c04 at 3516, wall 6366b88f at 1221);
  `world.sh same --packs=seed_paddle,seed_drive,seed_wall,seed_wall --mode=bot --frames=36000`: PASS, three runs.
- 00:22 item 2, the proof. The mechanism: the holder's `process_mode` (DISABLED when the pack does not get the world
  tick) together with `space_set_active(false)`; every collision object of the pack is set to
  DISABLE_MODE_KEEP_ACTIVE when it enters the tree, so disabling the holder does not take bodies out of the space.
  Paused mid-play (`--pause=0:600:60;1:1000:3600;2:5:1`) and sliced (`--every=2,8,30`), every seed's bot run ends
  in the same hash and frame count as the continuous run; the probe node in each pack counted 0 calls on a tick the
  pack did not get.
- 00:23 item 3, way (a) measured: a holder at 64 m, 1000 m or (2000, 0, 3000) changes the hash of all three seeds,
  and seed_drive's and seed_paddle's bots no longer finish. Cause: pack code reads world coordinates
  (`global_position` in `_pack_state`), not rounding: `ex_bounce`, which does not, keeps its hash at 1000 m.
  Way (b), bodies at the pack-local origin, is what every other run here is: all packs of a world stand at the
  origin of their own space, on top of each other, and never meet.
- 00:26 item 6: `verbs.json` has a `modes` block (`world`, `world-bench`), host.gd a `MODE_OPTIONS` table, and
  `tl.sh selftest` three new cases: `verbs.json_matches_host` (text comparison of both tables with the file, both
  ways), `world.same`, `world.sliced_and_paused`.
- 00:28 a bench pack, `kernel/world/packs/w_pile` (the seed is the body count). First figures: 600 awake boxes cost
  7.1 ms per tick; 300 boxes ASLEEP still cost 2.4 ms per tick. Sleeping is not cheap in this kernel: every dynamic
  body carries a TLContact whose `_physics_process` runs a ray query every tick, asleep or not.
- 00:31 `kernel/world/bench.gd` (`world.sh bench`), `kernel/world/PATCHES.md`, API.md section 19.
- 00:31 to 00:54 item 5: `bash tools/world.sh bench`, 73 world processes, 1393 s (most of it loading: 20 seed packs
  take about 65 s to load, about 3 s each). `kernel/world/BENCH.md` and `bench.json`. Timed tests ran on a machine
  shared with other sessions; from 00:46 the gates below ran beside the bench's hash tests (no timing in those).
  What it says: a seed pack costs 0.19 to 0.82 ms per tick (20 mixed: 0.5 ms each); 600 awake bodies 7.5 ms;
  a pack ASLEEP still 0.2 ms (35 bodies), so 60 asleep packs cost 13.8 ms, not the report's 0.2 ms; a pack switched
  off 0.001 ms; hashes identical against neighbours in other spaces (3 orders, 3 runs), after a pause of 1, 60 and
  3600 ticks mid-play, and at one world tick in 2, 8 and 30; 0 probe calls on a tick a pack did not get in 588,018
  pack ticks; 0 engine warnings. In ONE shared space a neighbour 300 m away changed ex_bounce's hash.
- 00:56 item 3 settled with a pack that has no world coordinate in its code (`w_pile`): standing 64 m from the
  origin its hash differs within 60 ticks (300 awake boxes, and 100 boxes settling); at 1000 m and beyond the
  starting positions already round to another millimetre. Way (a) is not hash-stable at any distance tried.
- 00:57 an experiment, NOT kept: `TLContact._physics_process` returning at once while its body sleeps
  (`if body.sleeping: _prev_velocity = body.linear_velocity; return`). 300 asleep boxes: 2.21 ms -> 0.16 ms per
  tick. Hashes unchanged in the 11 runs compared (three seeds idle and by bot, ex_bounce idle and by bot, ex_wall by
  bot, w_pile). tl_contact.gd was restored byte for byte (copy kept during the test); the change is a
  recommendation for the Director, because it touches every pack's physics path and the full gates were not run on it.
- 00:46 gates in this copy: `tl.sh selftest` 66 passed, 0 failed; `k.sh selftest` 86 passed, 0 failed;
  `tl.sh seeds` 23 passed, 1 failed (seed.drive.invariants: "frame p99 11.20 ms is over the 8 ms budget", the
  wall-clock budget, while my own bench was running 8 packs beside it); `tl.sh seeds drive.invariants` alone at
  00:55: PASS.
- 01:00 test 5 of the bench measured again with the two `w_pile` columns (`world.sh bench --only=offset`, 7
  processes, 146 s) and merged into BENCH.md and bench.json; BENCH.md got two hand-written sections at the end
  ("What the numbers mean", "Measured by hand"), which a re-run of the bench overwrites. Loading measured:
  about 3 s per seed pack, 65 s for 20, in one blocking call.
- 01:01 to 01:06 final gates on a quiet machine: `tl.sh seeds` 24 passed, 0 failed (smoke hashes bc93a9a4,
  b9adbb19, da4bdc3f: unchanged); `tl.sh selftest verbs.json` and `tl.sh selftest world.` 3 passed;
  `world.sh same --packs=seed_paddle,seed_drive,seed_wall` and `--packs=seed_wall,seed_wall`: PASS.
- Not done, for whoever continues: the watchdog in the world host; windowed worlds (camera and HUD ownership:
  kernel/world/PATCHES.md 1 and 2); drawing a pack away from its simulation origin (way b's picture half: no
  built-in mechanism found, see the report); worker.gd still carries its own copy of the load and hash code that
  pack.gd now also has (the two agree: the hashes are equal); tests 10 to 18 of the layering report.
- 01:06 to 01:09 the full selftests once more on the final files, quiet machine: `tl.sh selftest` 66 passed,
  0 failed; `k.sh selftest` 86 passed, 0 failed. N2 ends here (66 minutes of the 90).

## N5a: the world's clock (tiers, the scheduler, the world file)

Brief `briefs/BRIEF-N5A-TIERS.md`. Started 01:55 CEST on 2026-11-11 in `site/_work/n5a/engine/`. The machine is shared
(13 Godot processes at 02:07, mine among them).

- 01:56 item 1. `TLContact._physics_process` returns at once for a sleeping body (`if body.sleeping and _pm != null`:
  the extra condition lets a body that starts asleep get its law once). First check: three seeds idle
  bc93a9a4 / b9adbb19 / da4bdc3f, by bot cadd1cd9 at 6776 / 36635c04 at 3516 / 6366b88f at 1221: unchanged.
  One world process of mine hung at start (two world runs started in the same second, one of them refreshing the
  class cache); I killed it (PID 33660, mine) and the same command then ran in 16 s. Do not start two engine runs at
  once right after editing a kernel script.
- 02:02 item 2. `kernel/world/tiers.json` (every threshold) and `kernel/world/tiers.gd` (the scheduler: `decide`,
  `apply`, `due`; no node, no clock). Every decision is an event; `due` is a pure function of the events applied, so
  a log replays.
- 02:07 `kernel/world/pack.gd`: plot id and origin, `summary()` (TLRules: phase, score, clock), `saved_data()` /
  `restore()` (`_pack_save` / `_pack_load`), `plot_record()`, `unload()`, the time the tree spends in the pack's nodes.
  `kernel/world/world.gd`: `--walk`, `--replay`, `--log`, `--world`, `--save`; host.gd MODE_OPTIONS and verbs.json
  follow. `tools/world.sh walk|replay|proof|save|load`.
- 02:11 first walks: `world.sh walk boundary` (a and b 0 tier changes in 2400 ticks of zigzag along their common
  line, c one change) and `world.sh walk heavy` (valve: 4 demotions farthest first, slice 4, speed 800 per mille;
  every pack keeps ticking, longest wait 6 world ticks).
- 02:12 item 3, the proof: `world.sh proof proof --tiers-all` PASS. Three seeds 300 m apart, the player walks
  a -> b -> c and back (2700 world ticks, bots play): paddle 1880 own ticks 59c7f07b, drive 1814 ticks 2962e912,
  wall 1221 ticks 6366b88f (its bot won: the known bot hash). Each equals the same pack alone for the same ticks,
  and the replay of the world log.
- 02:13 item 5: `world.sh save` / `load` work; rename over the old file works on Windows; a file cut to 700 bytes is
  refused with exit 2 and left as it is, `<file>.prev` loads. `_pack_save` / `_pack_load` example in
  `kernel/examples/ex_bounce` (a seed is outside my scope: the seed patch is in PATCHES-N5A.md).
  Found: `--spacing` moves the SIMULATION (N2's way a) and pack_min's bot then ends at tick 1; the world file needs
  plot origins that do not move the simulation: new option `--plot-spacing`.
- 02:14 ledger: `world.sh proof ledger`: two packs unloaded for distance and rebuilt from their seed on the way back;
  ex_wall hashes as a fresh run of its new ticks, ex_bounce gets its score back (so it is not comparable, and the
  proof says so instead of failing... after the next edit).
- 02:16 item 4, loading: per pack `load_ms` {assets, script, enter_tree, setup, laws, bot}. ALL of it is the pack's own
  `_pack_setup`: paddle 2.4 to 2.5 s, drive 3.6 to 4.3 s, wall 2.1 s; the second copy of the same seed is as slow as
  the first (nothing is shared); scripts cost 0.4 s once per process, then 0.3 ms; laws 0.3 ms; the bot 4 ms;
  w_pile (305 bodies, no kit) loads in 21 ms; the first world iteration of 8 packs 25 ms.
- 02:19 selftest cases `world.walk_proof`, `world.walk_valve`, `world.walk_boundary`, `world.file`; the last three
  PASS alone. First gates on item 1 (while I was editing and testing beside them): `tl.sh selftest` 73 passed, 0
  failed; `k.sh selftest` 86 passed; `tl.sh seeds` 23 passed, 1 failed (`seed.drive.smoke_seed2`: the 250 ms
  wall-clock watchdog at frame 499, under load): to be run again alone.
- 02:21 the watchdog failure looked at: `tl.sh seeds drive.smoke` (three cases) twice with the sleeping-body return
  in: 5 of 6 cases stopped by the 250 ms watchdog, at frames 2864, 534, 759, 3418, 2477 (never the same frame);
  twice with the return switched off (`if false and ...`): 1 of 6 stopped. The watchdog guards the call into
  `_pack_tick` only, which the return is not part of, and the hashes are equal, so the cause is the machine (13
  Godot processes, CPU at 100 %), not the change; the sample is too small to say more. To be run again at the end.
- 02:23 item 6: lint `composability` has `kit_parts_used`, `kit_kinds_used`, `kit_build_calls`, `world_coordinates`,
  `world_coordinates_by` (seed_drive 19 parts / 6 world-coordinate reads, seed_paddle 14 / 12, seed_wall 23 / 7,
  pack_min 0 / 2); `TLVfx.squash` and `TLVfx.trail` (seams onto `TLStyleFx`); the worker already refuses
  `--mode=play` for a pack that fails lint (the Director applied N4's patch 4).
- 02:25 loading, inside `_pack_setup` (an instrumented scratch copy of the engine, deleted afterwards): paddle
  2140 ms = nature 1076 + terrain 783 + walls 188 + props 42; drive 3550 ms = nature 2286 + terrain 1099 + road 42 +
  props 50; wall 2064 ms = terrain 1011 + nature 819 + props 91 + actors 15. Building the ArrayMeshes is 53 to 71 ms,
  the content hashes 27 to 40 ms of that.
- 02:27 the experiment: scratch copies of the three seeds with `forest.scatter` false: setup 921 / 1158 / 1077 ms;
  also `terrain.far` false: 688 / 392 / 392 ms; the bot hashes stay cadd1cd9 / 36635c04 / 6366b88f. Built in scope:
  `ctx.scenery` and the world option `--scenery=plot` (`ctx.read_json` hands a `tl.layout/1` file out with both
  switches off): three seeds by bot load in 2.1 s instead of 9.7 s, same hashes.
- 02:28 first bench (full scenery, w_pile awake): 12 packs all ticking p50 4.7 ms, 30 packs 11.9 ms, 60 packs
  31.6 ms (load 122 s). In `bench_mix_30` the valve engaged for real (4 demotions, speed 600 per mille): measured
  cost under a machine at 100 % CPU. One stalled iteration moved every estimate; `_measure` now lets a sample count
  for at most four times the estimate. Bench stopped (my processes only) and started again with plot scenery.
- 02:30 to 02:33 second bench with `"scenery": "plot"` (12 packs load in 6 s, 60 in 26 s): all at sideline, world
  tick p50 5.1 / 11.9 / 30.5 ms for 12 / 30 / 60 packs; the mix (1 stage, 4 sideline, the rest backdrop, measured
  cost) 4.6 / 3.7 / 3.8 ms, slowest pack 0.28 / 0.14 / 0.057 of the world's ticks. All under load (CPU 100 %).
- 02:32 `world.sh proof leave`: `pause` (430 ticks = 145 + 285, none in between), `end` (ended at 545, built again at
  1060, 440 fresh ticks), `bot`: all three equal their solo runs and the replay. PASS.
- 02:33 item 1, the asleep figure: 10 / 30 / 60 packs of 30 sleeping boxes, every space active: 0.17 to 0.26 / 0.62
  to 0.78 / 1.57 to 1.60 ms per world tick (N2: 2.0 / 6.1 / 13.8): about 0.027 ms per asleep pack instead of 0.2.
  One pack of 300 sleeping boxes: 0.11 ms (N2: 2.21).
- 02:34 the cost estimate: the first 16 samples of a pack are a plain mean (the model's figure for a pile, 4 ms, had
  kept the slice of a 60-pack world at 29 for hundreds of ticks). Mix again: 4.0 / 4.2 / 4.1 ms, slowest 0.47 /
  0.11 / 0.064.
- 02:36 a sliced tick costs more than a continuous one (the two switches around it): 12 seed packs, per round of 12
  pack ticks, 4.7 to 5.3 ms at every tick, 6.4 ms at one in 2, 5.5 ms at one in 8.
- 02:37 `kernel/world/TIERS.md`, `PATCHES-N5A.md`, API.md section 20; the final gates started (no kernel file is
  edited after this line).
- 02:37 to 02:45 final gates in this copy, on the final kernel files, machine at 64 to 100 % CPU from other sessions:
  `tl.sh selftest` 76 passed, 1 failed (`ex.slide.bot`: exit 3, the wall-clock watchdog); the four new cases pass
  (`world.walk_proof`, `world.walk_valve`, `world.walk_boundary`, `world.file`), `verbs.json_matches_host` passes;
  `k.sh selftest` 86 passed, 0 failed; `item.sh selftest` 91 passed, 0 failed; `tl.sh seeds` 19 passed, 5 failed:
  `seed.paddle.bot`, `seed.drive.smoke`, `.hash` (no hash, because smoke was stopped), `.invariants`, `.bot`, every
  one the 250 ms watchdog ("_pack_tick took 264 ms", "did not return within 250 ms"), at frames 3004, 1461, 1349, 798.
  Seed hashes where a run finished: bc93a9a4, b9adbb19, da4bdc3f: unchanged.
- 02:45 to 02:48 is it the sleeping-body return? Two scratch copies of this engine, A as it is, B with the return
  switched off, `tl.sh seeds drive.smoke` (three cases) in turn, four rounds: A 2 of 12 cases stopped by the
  watchdog, B 7 of 12. The stalls are the machine's, and they are there without the change. (Scratch copies deleted.)
- 02:48 the failed cases again, alone: `ex.slide.bot` PASS twice; `seed.paddle.bot` PASS twice (`bot_seed2` once
  PASS, once the watchdog); `tl.sh seeds drive.` 8 passed, 0 failed, twice (hash b9adbb19 twice, seed 2 e6662471).
- 02:51 to 02:53 `tl.sh seeds` once more, whole, on the final files: 24 passed, 0 failed. Hashes bc93a9a4 / b9adbb19 /
  da4bdc3f (seed 2: 000eda48 / e6662471 / 4b2de68d), each twice: unchanged.
- 02:53 `world.sh proof bench_mix_12`: a walk scheduled from the measured clock, 12 packs loaded with plot scenery:
  all 12 hash as they do alone (loaded with FULL scenery) for the same ticks, and as in the replay. PASS.
- 02:57 tickets had not been run by any walk: `walks/tickets.json`, `world.sh proof tickets`: b pinned at sideline
  for 300 ticks, c pinned at backdrop for 200, d sent to ledger for 250 and rebuilt; own ticks 900 / 600 / 800 / 175,
  all four equal their solo runs and the replay. PASS.
- 02:56 to 02:59 `tl.sh selftest` once more, whole, on the final files: 77 passed, 0 failed. So the last full run of
  each gate in this copy: `tl.sh selftest` 77 / 0, `k.sh selftest` 86 / 0, `tl.sh seeds` 24 / 0, `item.sh selftest`
  91 / 0. The 02:37 round had 1 + 5 wall-clock watchdog failures under load (see above).
- Not done, for whoever continues: the watchdog in the world host; the player's real input routed to the stage pack;
  the next round of a game that ended by itself; ledger promotion without blocking the world; tickets asked for by
  a pack or the player; anything with a window (the distances in tiers.json are first values); `world.sh bench`
  (N2's) was not run again; the kit-side loading fixes (PATCHES-N5A.md entry 3). N5a ends here.

## N7: one world you can walk through (builder, main tree)

- 03:23 start (`date`). Brief `briefs/BRIEF-N7-WORLD.md`. A real job is verified on this machine until about 03:40:
  reading only until then. Read: both reports with the Director's decisions, PATCHES (N5b 1 to 4, N5a 6), world.gd,
  pack.gd, tiers.gd, draw.gd, view.gd, host.gd, both shell tools, the concept and tonight's overview.
- 03:27 plan. (1) tiers.gd gets a VISITOR mode: the stage no longer follows the player, `enter` / `leave` requests do
  (walk script `events`, or a live key); a game that is over and not on stage gets a `restart` event after
  `restart_pause_ticks`. All of it is events, so a log replays. (2) world.gd: patches 1 and 3, signals for whoever
  draws (`plot_event`, `ended`), scenery "plot" by default. (3) draw.gd: stage -1 (nobody on stage: every pack at its
  plot), a tier decides full or stand-in, a rebuilt pack is re-adopted. (4) view.gd becomes the host mode
  `world-view` (shot as before; with `--walk` the tour), landscape.gd and visitor.gd are new. (5) `world.sh tour`.
- 03:38 everything of items 1 and 2 written (tiers.gd visitor mode, world.gd signals and patches 1 and 3, pack.gd,
  tl_hud.gd patch 2, host.gd + verbs.json `world-view`, draw.gd stage -1 / set_tier / replace_holder, view.gd as a host
  mode with the tour, landscape.gd, visitor.gd, walks/tour.json, world.sh tour / visit). First headless run of the
  tour walk (400 ticks): loads, 0 errors.
- 03:39 `world.sh tour tour --headless`: FAIL. drive, paddle, car same; wall, walker, kit DIFFERENT alone: exactly
  the three packs that had been built again for a next round. Cause: `_rebuild` runs inside the world's
  `_physics_process`; the new pack's nodes enter the tree inside that physics frame, the scene tree does not tick
  them in it, but the kernel's calls (`_pack_tick`) and the physics step run: the pack's first tick is half a tick.
  N5a's ledger return and `on_leave: end` return go through the same `_rebuild` (its proofs used packs whose nodes
  do not tick themselves). Fix in tiers.gd: a `restart` (and a tier change from `ledger`) sets `rest_until = t + 1`;
  `due` skips the plot on that tick. It is state of the schedule, so the replay does the same.
- 03:40 `world.sh tour tour --headless`: PASS. Six packs, 2900 world ticks, 44 events, two games entered and left,
  walker / kit / wall restarted for next rounds; in the walk = alone = replay for all six.
- 03:41 `world.sh tour tour --out-dir=kernel/world/captures/tour`: first windowed run. PASS, the same six hashes
  as headless, 10 of 10 pictures, 4 stage changes, 0 gate leaks, 0 script errors, 0 engine errors. Looked at all ten:
  the visitor on the dirt road between fenced plots with the track's stand-in beyond; the track from its rim; ON
  STAGE the drive's own chase camera and HUD with the world's fence, trees and mesas behind its rim; the wall yard
  with its `player` view and HUD; both crane overviews. From the crane the village reads as a village, the picture
  is hazy at the top and `ex_car`'s own floor is a plain beige disc.
- 03:44 landscape, second pass: grass patches and tufts, road half width 3.0, mesas in three strata. New walk
  `tour_views` (three crane views) and `world.sh tour --pictures-only`. `captures/views/02_overview_hill.png` is the
  picture to put beside the concept: paddle court in front, the road, the track, the crane, mesas, the low sun.
- 03:46 selftest case `world.tour` (headless form); the world line of `world.sh walk` now also prints wrong-pack
  calls and kernel-call time (the `world.walk_valve` case's pattern follows). All gates started in one chain
  (selftest, seeds, k, item, view.sh check); WORLD.md, API.md 19 / 20 / 21, notes in TIERS.md, DRAW.md, PATCHES.md.
- 03:50 `tl.sh selftest` on these files: 78 passed, 0 failed (77 before + `world.tour`).
- 03:51 while the other gates run (no second engine process): the next landscape pass is written as a script and
  not applied yet (mesas with uneven outlines, flags and a sign at every gate, one fenced building lot with a crane).
- 03:57 all gates on the files of 03:46 (one chain, 03:46 to 03:57, under load): `tl.sh selftest` 78 / 0;
  `tl.sh seeds` 24 / 0 with hashes bc93a9a4 / b9adbb19 / da4bdc3f (seed 2: 000eda48 / e6662471 / 4b2de68d):
  unchanged; `k.sh selftest` 86 / 0; `item.sh selftest` 91 / 0; `view.sh check` (five packs, stage paddle, through the
  host mode `world-view`, scenery "plot"): PASS, 36635c04 at 3516, cadd1cd9 at 6776, 6366b88f at 1221, 16db2bf1 at
  332, 8d1831dc at 371: the hashes of DRAW.md section 6; 0 gate leaks, 0 wrong-pack calls, 0 errors.
- 03:57 landscape, third pass applied: mesas with uneven outlines in three strata, a flag on each side of every gate
  and a sign, building lots (`landscape.lots`: a fenced lot with a crane, a scaffold, timber, pallets, barricades).
  Looked at `views/` after each change; the hill view was moved twice.
- 03:58 N5a's proofs again, because `rest_until` changes who ticks when: `world.sh proof ledger`, `leave`,
  `tickets`: PASS, PASS, PASS (own ticks differ by one from N5a's figures where a pack was rebuilt, as intended).
- 03:59 ledger in a window: a tiers file with `backdrop_m` 70, `world.sh tour tour --tiers=<it> --out-dir=<scratch>`:
  wall, kit, car unloaded on tick 0 and built again when the visitor came near, walker and paddle unloaded later;
  PASS (drive, wall, kit, car same; walker and paddle in the ledger at the end: nothing to hash); 10 pictures, looked
  at four: the unloaded plots are drawn as their stand-ins.
- 04:00 the live path (`--live`: WASD, E, Q) run for 200 ticks in the hidden window with no key pressed: no script
  error. That is all the evidence for it; nobody has walked.
- 04:01 the final tour once printed an engine warning with the trace `CreateJob (jolt_job_system.cpp:123)`; the text
  was not kept (the tools filtered WARNING lines; they print them now). Engine errors 0, hashes equal. A headless run
  right after: 0 warnings. Two more windowed runs: it did not come back.
- 04:03 a second, small lot between the walker room and the track; final `world.sh tour tour
  --out-dir=kernel/world/captures/tour`: PASS, 10 of 10 pictures, all ten looked at again. Hash table: drive 2750
  ticks f3407ff7, wall 789 b292d651, walker 371 8d1831dc, paddle 2361 2ae96170, kit 8 0b8e9424, car 1864 bf2f98da:
  tour = alone = replay. Owner pictures: `captures/world_overview.png`, `world_vs_concept.png`, `far_and_near.png`,
  `world_from_above.jpg`; the tour frames kept as JPEG (21 MB in all instead of 48).
- 04:08 on the final files: `tl.sh selftest world.` 7 / 0 (`world.walk_proof` with N5a's hashes 59c7f07b / 2962e912 /
  6366b88f; `world.tour` with the table above), `tl.sh selftest verbs` 1 / 0 (5 verbs, 3 world modes), `view.sh check`
  PASS with the same five hashes. The full `tl.sh selftest` (78 / 0), `tl.sh seeds` (24 / 0), `k.sh selftest` (86 / 0)
  and `item.sh selftest` (91 / 0) are of 03:46 to 03:57; after them only landscape.gd, the two walk scripts,
  world.sh (WARNING lines, a verdict's wording, `--pictures-only`), selftest.sh (the text of one verdict) and
  documents changed.
- 04:09 requests that cannot be met (a scratch walk): `enter` on the road, `leave` with nobody on stage, `enter` of a
  named plot he is not in, `enter` while a game is on stage: four `refused` events with their reason.
- 04:10 no engine process of mine is left (the six Godot processes running belong to other projects); no window.
  Not done: a person walking it (`world.sh visit`); a body for the visitor; relief; `footprint` in the packs;
  the foreman's copy of verbs.json; the text of the one Jolt warning. N7 ends here.

## P4: land with relief, and a visitor with a body (core-p4-relief; clock from `date`, started 10:25)

- 10:25 start. Read the brief, WORLD.md, DRAW.md, landscape.gd, visitor.gd, draw.gd, view.gd, the kit's terrain.
  Premises checked: (a) the plot's height is already free: the walk's plot `origin` y goes through view.gd's lift
  (`origin.y += -rim`), so a pad height is just the plot's y; no draw.gd / view.gd edit was needed. (b) the black rim
  line of last night's pictures 04 / 06 is a step: the world's ground lay 6 cm under the pack's rim
  (GROUND_Y -0.06) and the dirt ring 3.6 cm over it; ink draws a heavy line on a 6 cm step at a grazing angle.
- 10:36 first baseline run (`world.sh tour tour --headless` in the worktree, cold cache) was still running after 30
  minutes at 600 CPU seconds: stopped by me (my own process). Everything after it ran in 5 to 15 s: the first run in a
  fresh worktree is not a measurement. Baseline taken from the main checkout's engine instead (read-only use,
  `TL_ENGINE_DIR`), see the figures below.
- 10:50 `terrain/village_terrain.gd` (heightfield 3 m cell, indexed mesh, 47,765 vertices, one surface of the palette
  key "terrain": the style's ground class with tufts and the strata on steep faces) + `landscape.gd` rewritten around it.
  Roads and the river are stamped into the grid (every sample marks the vertices round it) because a path query per
  vertex (the kit's way) would have cost 18 s here. Built in 0.27 to 0.5 s. First windowed picture looked at: pads read
  as terraces, the river was purple (grazing water), camouflage patches too strong (reduced), relief too weak
  (pad heights raised to -2.5 / 4.5 / 7 / 6 / 3 / 0.5, land noise up).
- 10:55 GROUND_Y 0.06 -> 0.0 (a pack's ground and the terrain at the same height under the dirt ring, ring +1.4 cm):
  the black rim line is gone in picture 04; what remains is a real crest at the lip of a dipped plot.
- 10:58 visitor body: `terrain/world_space.gd` (a PhysicsServer3D space of the world; kinematic capsule; test_motion
  slide, 0.55 m step, slope limit 55 degrees) built by the landscape, found by the visitor through the landscape
  node's meta `tl_space`. First run: he stuck on the steep bent rim of the drive's hollow (the 9 m band over a 7.6 m
  drop is 40 to 60 degrees): the walk stops at the rim now (0, -26). Second: the wall plot's fence stopped him at
  x 118 (the gate is at x 126): the walk was adjusted, as the brief allows. `visitor_probe` in a walk script runs
  teleport-and-walk probes against fence (outside and inside), gate, tree, rock, bridge rail, the bluff:
  8 of 8 as expected (a rock lower than a knee is walk-over by design; the first rock probe passed over a 0.3 m stone
  and a sphere collider turned into a hill he could climb: rocks now have cylinder colliders).
- 11:08 `tour`, `visitor_walk` and `p4_views` walks. Pictures looked at: bridge, river, bluff strata, rim.
- 11:19 `world.sh tour tour --out-dir=captures/p4/tour` (window + proof): PASS; hash table (drive 2419 ticks 59366015,
  wall 439 bb9ec8af, walker 371 8d1831dc, paddle 1894 c3b7779c, kit 332 16db2bf1, car 1573 9a0c139b): tour = alone =
  replay. The visitor line: 0 blocked ticks, ends exactly where the script says (end_dev 0.0), at most 10 m behind the
  script on the one fast stretch (raised the catch-up to 0.5 m a tick afterwards). The first run of that walk had the
  wall yard's gate at the wrong x (118 for 126): he was stopped by the fence at z -21.2, `blocked_ticks` 475: the script
  was adjusted, not the body.
- 11:20 arch gate: a schema name of its own for the visitor's lines is a schema no contract declares (arch: schema-versions): the lines are `tl.view/1`
  with kinds `visitor`, `visitor_probe`, `visitor_blocked` instead (proposed contract text in the report);
  landscape.gd was 721 lines (budget 600): the far plain, the road strip, the bridge, the mesas and the scatter's
  helpers moved to `terrain/village_parts.gd`; new .gd files need their .uid: `godot --headless --import` made them
  (and a `.import` per capture picture, deleted again).
- 11:25 cost, before (main's engine, this morning's tour) and after: WORLD.md "P4: what relief and a body cost".
  `view.sh check` (five seeds, stage paddle): PASS, the five hashes of DRAW.md section 6 again.
- 11:32 `tour_views` (another walk without pads or river) still builds and draws; `visitor_walk`: 8 of 8 probes.
## P2: the kernel's physics hot path (builder, worktree core-p2, started 2026-11-11 10:25)

- 10:25 start. Brief: `briefs/BRIEF-P2-HOTPATH.md`. First engine run in the worktree builds the class cache; the machine
  was at 100 % CPU (three other builders and a gate), so every figure of the morning is taken at least twice and
  A/B pairs are run in one sitting by swapping the file (old `tl_contact.gd` kept in the scratch directory).
- 10:30 a note on measuring: with other processes on all cores Jolt's worker threads are descheduled and a 300-body pile
  that costs 3.8 ms quiet read 59 to 268 ms in the same minute. Figures from such a minute are thrown away; the
  ones below are the quiet ones (`iter_ms_p50_all_ticked` of `world.sh run`, the lower of at least two).
- 10:45 profile of 600 awake bodies (`w_pile`, seed 600, 400 frames; quiet machine, 554 awake of 600 at the end):
  see the table in the report. In short: floor without trackers (bodies made with `track = false`) 0.87 ms; bodies
  with a `TLContact` whose script work is switched off 1.75 ms (contact monitoring and the physics material, 0.9 ms);
  the contact scripts themselves 2.4 to 3.4 ms (7.5 us per awake body per tick: 3.5 us the contact scan, 3.3 us the ray;
  226,117 of 240,000 body ticks cast a ray, because a box resting on boxes has no tagged surface and so asks again).
  Added bench pack `kernel/world/packs/w_pile_x` (the seed's hundred-thousands digit picks a profiling mode).
- 10:55 first version: one `Tracker` node per pack (inner class of `tl_contact.gd`, a child of `TLPack`, process priority
  100 as the contact nodes had) walks every tracked body in one loop; shared ray query object, space and `pair`
  answers. `w_pile` 600: 5.06 -> 4.0 ms; hash 6a234137ab9c88b5 unchanged.
- 11:00 second step: the surface comes from the engine's `body_entered` / `body_exited` signals (a set per body) instead
  of `get_colliding_bodies()` every tick; a body casts its ray again only after it has moved 15 % of its reach (estimated
  from its speed), so a puck at 30 m/s still casts every tick. `w_pile` 600: 2.4 ms, 300: 1.16 ms.
  All 13 packs x (smoke, bot): old and new hashes identical (table in the report).
- 11:20 hashes with the second step in: all 13 packs (3 seeds, 8 examples, hockey with both bots) x (smoke, bot): old and new
  equal, 3 runs (a `watchdog` row is a time limit under load; re-run alone it passes).
- 11:28 third step: a body whose contacts did not change and which has moved less than 15 % of its reach since its
  last cast returns after two engine reads (`_step` fast path). `w_pile` 600 in one sitting, orig / second step / third:
  6.3-7.2 / 3.7-4.7 / 3.1-3.6 ms (machine at 100 % CPU).
- 11:40 WITHDRAWN: skipping the whole pass while every body of the pack is asleep (a count kept from
  `sleeping_state_changed`). It made 60 asleep packs cost 0.5 ms instead of 1.5 ms, but the signal arrives after the
  physics step, so a body woken by code in `_pack_tick` (`apply_impulse`, `sleeping = false`) was not stepped on its
  first frame and its `_prev_velocity` was stale: the hockey hashes moved (smoke b0ddd31f0f70beeb -> 6e86f1425f8a6c6e,
  bot 5af10fbc -> 821b6e7d). Without the skip they are the old ones again. The sleeping body costs two engine reads.
- 11:45 pack author facts: nothing changed in `TLBodies.make`, `TLBodies.contact`, `TLBall`, `TLVehicle`, signals; a
  `TLTracker` node appears under `TLPack`. `TLLaws.pair_cached` is new (kernel side).
- 11:58 final code (`tl_contact.gd` without the withdrawn skip): 13 packs x (smoke, bot), old engine copy vs new, three
  runs of the new one: every hash equal to the old one and to each other, hockey (both bots) included; `invariants` of
  11 packs on the second-step code: determinism and bot_deterministic ok (ex_car and ex_wall fail `below_ground` at the
  default 3600 frames on the OLD engine too: unrelated, the selftest runs them at 900 / 1200).
- 12:02 `tl check --tier full` started at 11:50 on the final files (it runs `selftest.sh`, `seeds.sh`, `k.sh selftest`);
  under load `kernel.selftest` alone takes more than ten minutes. Its result is in the report, not here.
- Not done: a native extension (see the report: scons, MSVC 2022 and cargo are on the machine, no godot-cpp sources and
  no network); the sleeping pack path (2 reads per sleeping body per tick, 10 to 20 % dearer than the old per-node early
  return in the asleep bench); the tour's world tick before and after (not measured).

## P7: the simulation contract (builder, worktree core-p7, started 2026-11-11 13:22)

- 13:22 start. Brief: `briefs/BRIEF-P7-CONTRACT.md`. Read API.md, the index, PACK.md, RUNNER.md, lint.gd, manifest.gd,
  tl_input.gd, tl_context.gd, tl_orbit_cam.gd, worker.gd, statehash.gd, ui/PATCHES.md, devx/lib/arch.
- 13:26 old hashes taken before any engine file was touched: 12 packs (3 seeds, 8 examples, hockey) x (smoke, every bot),
  25 runs, all exit 0 (table in the report).
- 13:30 found: `world/pack.gd` (not mine) has its own copy of the hash; `host.gd` and `worker.gd` are held by the size
  ratchet (610 lines each), so the record, the replay verb and the device script live in a new file,
  `kernel/runner/session.gd`; `_canon` / `_plain` moved into `host/statehash.gd` (worker keeps one-line delegates,
  `world/pack.gd` calls them). worker.gd 610 -> 570 lines, host.gd 610 -> 601.
- 13:33 `TLInput`: the latch is the record. `_sample()` writes every value that is not zero as [frame, action, value];
  `_feed()` replaces devices and injection by a record; the pointer is three kernel actions (`tl.look_x`, `tl.look_y`,
  `tl.zoom`) filled from `_unhandled_input` and read by `TLOrbitCam` in its physics frame (its own mouse handler is gone).
- 13:34 first record of the paddle bot did not read back: a float written as decimal text is not the same double after
  Godot's JSON reader. Decision: a sample is a multiple of 0.001, rounded at the latch (`TLInput.STEP`), so a record
  holds exactly what the game read. Cost: bots that steer with analogue values play a slightly different game (paddle
  bot: won 5:0 in 6776 frames before, 4486 after). All bots are run again below.
- 13:36 paddle: `bot --record` -> `replay` -> the same hash (a6e8ba23c43f088c), and `replay --record` writes the same
  file byte for byte. `kernelApi` is 1.0; "0.1" is read as 1.0 (manifest.gd LEGACY_API), 2.0 and 1.1 are refused.
- 13:37 wall seed, a scripted interactive session without a window (`play --headless --frames=600 --devices=<file>`):
  30 frames of right-button drag, two wheel notches, W, Space, D. Hash c37d26423744c653; its record replayed:
  c37d26423744c653. The same keys without the mouse: ba1fabb0de04d5a1 (the mouse changes the game, through the record).
- 13:38 ui/PATCHES.md 1 and 2: a text field with focus takes the keys (pack_min, Space held 10..79, field 30..59: the
  record has `nudge` in 10..29 and 60..79 only); Esc with the panel open at frame 20 does not end, Esc at 50 with the
  panel closed ends the run (51 frames).
- 13:40 item 1: `devx/lib/arch/apicontract.mjs`, rule `api-v1`, `docs/generated/API-V1.json` (41 classes, 581 members,
  version 1.0; two runs of `tl arch --index`: unchanged). `tl arch --broken-demo <dir>` builds a tree in which
  `TLBall.shoot` lost its parameter and judges it: FAIL, `method TLBall.shoot changed: it was func shoot(impulse:
  Vector3) -> void, it is func shoot() -> void`. The index also lists signals and properties now. 22 arch tests pass.
- 13:43 FOUND BY THE THREE-FOLD PROOF: the first new hashes were stable for 24 of 25 rows; hockey smoke gave another
  hash in 1 run of 3. 30 more runs with `hash_parts` in the result: 29 alike, 1 other, and in that one the bodies-and-state
  part (b0ddd31f0f70beeb, the old hash) and the generator's state were the same. Cause: MINE. `_hash_into` sorted the
  action names as StringNames, and StringNames sort by their address in memory. Now sorted as text. All 25 rows three
  times again and 30 hockey smoke runs: one hash each (table in the report). The first set of new hashes is void.
- 13:45 item 4, the fence: 16 new rows in lint.gd (device reads past ctx.input, clocks that are not the tick,
  another pack's nodes and the kernel's side of ctx); no seed, example or promoted pack (hockey, marble run, paddle
  court) uses any. `func _input` stays a bypass (PACK.md; `bad_bypass` passes lint with it), so the worker switches a
  pack script's event handlers off when the node is ready. Control: without that line the case
  `p7.fence_handler_switched_off` fails (the handler ran 3 times), with it it passes. lint.gd is 600 lines (budget 600).
- 13:48 selftest: 19 new cases `p7.*` pass. `devx/arch.baseline.json`: four findings held until the contract text is in
  (`tl.input/1`, `replay`, `--input`, `--record` are not in contracts/ yet); host.gd 610 -> 601, worker.gd leaves the list.
- 13:52 the same device script in a real window (`tl.sh play` without `--headless`, events through
  `Input.parse_input_event`): the same record byte for byte and the same hash as headless and as the replay
  (a9e62096879b5a5a).
- 13:53 `tl check --tier fast`: 5 steps green (arch 9 rules, devx.test 126 pass). Patches for files of other owners:
  `kernel/api/PATCHES-P7.md` (the world's own hash in pack.gd, handlers in a world, the visitor's keys, foreman's
  KERNEL_API, bad_bypass).
- 13:55 the handler switch-off narrowed to scripts of the pack (by path, a pack inside or outside the engine directory:
  both checked) and connected once per node. A session that ends because the window is closed writes its record too
  (`worker._notification`, device kind `close`, case `p7.keys_window_closed_keeps_record`; not tried with a real click).
- 13:57 hockey: lint 0, invariants 0 (eed5cf0dec85f89e), capture 0 (picture looked at: the rink, six skaters), both bots
  recorded and replayed to their own hashes (7326d67aeb26ad7a, de74f3a77315f9a5); seed_drive and seed_wall bots too
  (b912bc471e4967a9, cb75fb26a1e80254). World proofs on the final hash code: `world.same`, `world.proof`, `world.tour` PASS.
- 14:10 lint with the new rows on every pack there is: 3 seeds, 8 examples, hockey (both copies), marble run, paddle
  court, w_pile: fence ok. `w_pile_x` fails lint on `get_parent(` (an N4 rule, not a P7 one; it is a world bench pack
  and the world does not lint).
- 14:12 the first full gate was started at 13:53 and I changed worker.gd, session.gd and selftest.sh while its
  `kernel.selftest` ran: stopped (my own processes only, none left) and started again on the final files.
- Not done: item 6 (the visitor's keys through the record). The keys are read in `world/draw/view.gd`, another
  builder's file; `visitor.gd` reads none. Proposal in `kernel/api/PATCHES-P7.md` section 3.
- 14:14 measured what the pointer costs a pack nobody points at (`_sample()` 100,000 times, best of 5, machine busy):
  with the three pointer actions in the same loop as the declared ones 4.2 us per frame for a pack with no action, 10.7 us
  with six: for 30 packs that is 0.1 to 0.3 ms of a world tick. Changed: the pointer's three are sampled only while one of
  them is alive (a drag, an injected value, a replay, a value on its way back to zero), declared actions are walked in a
  kept list, the replay's table is made only in a replay. After: 0.49 us with no action, 2.9 us with six. The second
  full gate (3 minutes old) was stopped for it and the gate started a third time; all 25 runs taken once more against
  the table.
- 14:18 after the fast path: all 25 runs once more, every hash equal to the table; the windowed session and its replay
  again a9e62096879b5a5a with the same record file.
- 14:38 third full gate (22 minutes): 11 steps green, `kernel.selftest` red with 1 of 101 cases:
  `p1.world_runaway: the world line has no trip record`. MINE: I had moved `host._intify` into session.gd and
  `host/world_supervisor.gd` (not my file) calls `h._intify`. Put back as a one-line delegate (host.gd 605 lines, the
  baseline held it at 610 before P7); the case passes. `item.selftest` and `ui.selftest` are skipped in a worktree
  (they need site/ of the main checkout): their fence cases that my lint rows could touch were run by hand
  (each fenced line of the five bad_reach packs reported once; `play` refuses a pack that fails lint; marble and
  paddle court pass lint).
- 14:31 `devx/lib/gate/godot-step.mjs`: the wall-clock limit of a script step 15 -> 30 minutes (kernel.selftest took
  13.3 minutes tonight with 20 more cases and four other builders on the machine).
- 14:40 fourth full gate started on the final files.
- 14:40 one `_sample()` before P7 against now, one process, alternating, best of 7 x 100,000 (machine busy): no action
  0.37 -> 0.55 us, two 1.45 -> 1.49 us, six 4.30 -> 4.81 us. For 30 packs that is 5 to 15 us of a world tick.
- 15:01 fourth full gate, final files: exit 0. arch 9 rules, devx.test 126, foreman.test 158, kernel.selftest 101 cases
  (12.2 minutes), kit.selftest 87, seeds 24; perf measured but not judged (machine BUSY, use 100 %); item.selftest and
  ui.selftest skipped in a worktree. End of the package; the report is the final message.
## P5: a world that loads without a hitch (builder, worktree core-p5, clock from `date`, started 2026-11-11 13:22)

- 13:24 MEASURED before any change (headless, `world.sh run`, 8 packs, scenery plot): a seed's load is its `_pack_setup`
  (drive 358 ms, wall 371, paddle 413, hockey 771 ms; `ex_bounce` 1.5 ms); the entry script costs 14 to 342 ms the first
  time in a process and 0.2 ms the second; laws, tree entry and asset generators are under 2.5 ms together.
- 13:26 experiment (scratch script, `-s`): `TLKit.build_layout` is 95 to 99 % of a seed's `_pack_setup` (drive 354 of
  358 ms, wall 274 of 371, paddle 398 of 413; hockey 18 + 155 of 771). It builds the venue OFF the scene tree and attaches
  it last, and the kit references nothing outside itself: the same build on a worker thread gave the same node, body and
  mesh counts and the same `Static` mesh hash, no error, 5 to 35 % slower, while the main thread went on (65,000 to
  111,000 idle frames). Attaching the built venue to the tree: 13 to 23 ms on the main thread (seeds with terrain), 0.1 ms
  (hockey venue). First physics step after it: 0.1 ms.
- 13:30 kit: `TLKit.build_layout_ahead(layout)` / `TLKitLayout.build_ahead` build a layout ahead and keep it by the hash
  of its JSON text; the next `build_layout` of an equal layout only attaches it (one result serves one call).
- 13:36 `kernel/world/jobs.gd`, the build queue: PREPARE on one worker thread (scripts loaded, layouts built ahead),
  ATTACH on the main thread at a tick boundary (`_pack_setup`), event `built` in the world log, one-tick rest kept.
  `tiers.gd`: a plot is `unbuilt` until its `built` event; `due` leaves it out; `restart`, `reload` and a return from the
  ledger make it unbuilt again. `tiers.json` `load: {mode: auto, budget_ms: 4}`. `pack.gd`: `stub()`. `plotfile.gd`: the
  world file writer and the directory hash moved out of `world.gd` / `pack.gd` (neither may grow: arch rule).
- 13:39 FOUND: a main thread that sleeps while it waits for the worker waits for ever: the worker's calls into the
  rendering and physics servers that return a value are run by the main thread (the servers' command queues). The wait
  loop now calls `RenderingServer.force_sync()` and one physics server call each round.
- 13:41 step mode (headless default: one pack per world tick, waited for, so arrival ticks are a pure function of the
  walk): `world.sh proof proof --tiers-all`, `tour tour --headless`, `tour tour_next_round --headless`, `proof ledger`
  all PASS (walk = alone = replay).
- 13:46 window, queue mode: the tour runs, packs arrive at ticks 73 to 145. Main-thread attach 17 to 195 ms
  (layout seeds 17 to 37 ms when the machine is free; `ex_walker` 165 and `ex_kit` 190 ms have no layout: all of their
  setup is still on the main thread). FOUND: the tour's 700 to 850 ms frames are the ticks of its `shot` events (the PNG
  of a 1920x1080 picture is encoded inside the frame), not only the rebuild. FOUND: in a window the worker's prepare took
  1.1 s instead of 0.4 s: each of its server calls that returns a value waits for the main thread's next frame.
- 13:50 `view.gd`: the tour's pictures are encoded on worker threads (the frames of the `shot` ticks are no longer slow);
  the tour line carries `frame_ms_p99_all`, `frame_ms_max_all` (PATCHES-P1 entry 1; the first two frames, which are the
  start itself, are left out and reported apart), `frames_over_16_7_ms`, `slow_frames` ([world tick, ms]) and the time
  to the first frame; PATCHES-P4 entry 1 applied (a walk's `landscape.pad_h` is the plot's height; `rim_band`).
  `world.sh` `window_mode` is supervised (PATCHES-P1 entry 2): trip record, start again with the pack left out.
  FOUND: `host.gd` refuses options it does not list (`--trip`, `--dead`, `--load` for `world-view`): they go through the
  environment (`TL_WORLD_TRIP`, `TL_WORLD_DEAD`, `TL_WORLD_LOAD`) until PATCHES-P5 entry 1 is applied.
- 13:52 selftest `world.reload` PASS: `ex_slide` copied, its `start_speed` changed at tick 299 (the walk's `edits`),
  `reload` at tick 300: 299 ticks, 838ccf3eb20d3d6b = the changed pack alone, not 53e7691203ce75fe; `pack_min` and
  `ex_wall` hash as in the undisturbed run; the log replays.
- 13:54 the tour in a window WITH the proof, queue mode, real arrivals: PASS, six packs tour = alone = replay.
  FOUND: the visitor ended at y = -432 m: a pack that arrives after the landscape was built had no collider copies in
  the visitor's space. `view.gd` now calls `world_space.add_pack` at a plot's first arrival; next run he ends at 6.49 m.
- 13:55 `walks/walk30.json` (30 games, two rows along 1.5 km of road, games beyond 200 m in the ledger) ran in a window:
  32 arrivals (30 and two returns), 184 of 12,000 frames over 16.7 ms. Arrival frames: 17 to 36 ms (seed_paddle, small
  examples 3 to 7 ms on their second copy), 90 to 120 ms (seed_wall), 165 to 310 ms (ex_walker, ex_kit: no layout). The
  machine stalled once for seconds (ticks 9791 to 9809, frames of 0.27 to 4.9 s, in step with another builder's window).
- 13:57 PATCHES-P2 entry 1 in `pack.gd`: the holder calls the tracker's pass itself (`contact_pass`, from the closing
  mark: after every node of the pack, before the physics step; a tracker made during a tick has its first pass on the
  next, as the scene tree had it). A/B with an environment switch (removed again): 13 packs (3 seeds, 8 examples,
  hockey, w_pile) x (smoke, bot) x 1500 frames, old order = new order, every hash.
- 14:01 the hockey game with its two layouts built ahead: `_pack_setup` still about 600 ms on the main thread when the
  machine is free (1.19 s measured under load): six skaters' rigs and its own parts. The layout was 173 of its 771 ms.
- 14:04 docs: TIERS.md "P5: loading is not simulation", WORLD.md "Loading (P5)", PATCHES-P5.md (8 entries);
  `docs/generated/API-INDEX.md` regenerated (`tl arch --index`: two new `TLKit` functions). Fast gate green.
- 14:09 TWO BUGS OF MINE, found by a tour cut short with `--ticks=300` and fixed: (1) `jobs.gd` `stop()` joined the
  worker while it was in the middle of a build, and the worker waited for the main thread to run its server calls: a
  deadlock at the end of a world. It now flushes the servers until the worker is done. (2) `view.gd` handed
  `img.save_png` to a worker without keeping the image: a Callable holds no reference, the image was freed when `_take`
  returned, one run ended with exit code 139. The images are kept until the tasks are waited for.
- 14:15 time from the world's start to the first drawn frame, `TL_WORLD_LOAD=block` against the queue, one run each,
  the gate and four other builders on the machine: six games 5.83 s -> 2.28 s (landscape 2.08 s of it); thirty games
  15.69 s -> 6.43 s (landscape 6.1 s of it). The tour line has `world_to_first_frame_ms` (the engine's own start, 4 to
  14 s under this load, is before it and is not counted).
- 14:17 `tl perf run --scenario tour6,walk30` recorded as line 7 of `perf/ledger.jsonl`, machine BUSY (use 99 %, probe
  0.729), not quiet: tour6 worst frame 286 ms (quiet baseline 762 to 838), frame p99 10.4 ms, load 18 ms (1675 to 1937),
  first frame 1.85 s after the world's start, six games built 4.1 s after it; walk30 worst frame 359 ms, frame p99
  7.6 ms, tick p50 2.9 ms, first frame 6.0 s, six games built 8.0 s.
- 14:18 FOUND before the gate could: in step mode the wait for a pack sat inside a world tick, so `mix30`'s worst tick
  would have been a build (hundreds of ms against a baseline of 19 ms) and its `load_ms` 40 ms: the perf gate would
  fail on a quiet machine for a cost that only moved. Now what a step, wait or replayed tick spends on a build is taken
  out of the tick's time and added to `load_ms` (`jobs.gd` `take_spent`, world line `load.in_ticks_ms`).
- 14:21 step mode no longer uses the worker (it was only waited for, 5 to 35 % slower than the main thread): it builds
  one pack per tick, whole, on the main thread. `mix30` under load: `load_ms` 16.2 s (the ledger's busy rows before P5:
  9.8 to 15.8 s), worst tick 90 ms, p99 13.7 ms. New mode `wait` (step order, prepared on the worker, waited for) for the
  new selftest case `world.queue` (`walks/queue.json`): three seeds built ahead by the worker, arrived at ticks 0, 1, 2,
  walk = alone = replay. A window-less run in `queue` mode is over before a worker is done (900 empty ticks in 35 ms).
- 14:24 the supervised window, run once: a tour of `pack_min`, `bad_watchdog`, `ex_wall`: the guard tripped at world tick
  21 (263 ms of processor time), `world.sh` started the window again without pack 1, the tour ran its 240 ticks, wrote
  its picture, the two healthy packs have hashes, exit code 1 (a pack failed), no window left.
- 14:25 two pictures looked at (walk30 half way, the tour's `far_and_near` from the windowed proof run): the visitor on
  the road, the venues at their plots.
- 14:24 full gate started on the final files (third start; the first two were stopped for the fixes above).
- 14:28 `view.sh check` (seed_drive, seed_paddle, seed_wall, ex_kit, ex_walker; stage paddle): PASS, drawn = headless:
  36635c049bc6acd8 at 3516, cadd1cd9fffac7b1 at 6776, 6366b88f838e3e78 at 1221, 34b19960cc4c5308 at 332,
  8d1831dc62dfe91a at 371 (the three seeds' bot hashes are N5a's).
- 14:32 hockey: `tl.sh smoke` b0ddd31f0f70beeb (3600 frames), `tl.sh bot` 5af10fbc23df0d76 (4888 frames): P2's figures.
  The same pack in a world (`world.sh run`, the contact pass called by name) for 3600 smoke frames: b0ddd31f0f70beeb.
  The same pack in a walk in `wait` mode (both its layouts built ahead on the worker, attached at tick 0), 3600 frames:
  b0ddd31f0f70beeb.
- `kernel/world/WORLD.md` was edited at 14:04 and put back at 14:26 (it is not in P5's scope): its text is PATCHES-P5
  entry 9.
- 14:42 `tl check --tier full` on the final code: GREEN. arch, assets, cards, devx.test (123), foreman.typecheck,
  foreman.test (158), kernel.selftest (83 cases, 613 s; `world.reload` and `world.queue` are new), kit.selftest (87),
  seeds (24), perf (machine BUSY: measured, not judged); item.selftest and ui.selftest SKIPPED (they need the main
  checkout's `site/`). Only `.md` files were edited after its start.
- 14:44 `tl perf run --scenario mix30,tour6,walk30 --quiet-only --wait 60`: the machine was not quiet, nothing recorded.
- 14:46 `mix30` A/B in the same minutes (busy), two runs each: block (as before P5) `load_ms` 13.0 / 13.4 s, tick p50
  3.8 / 3.9 ms, p99 11.4 / 12.2, worst 25.5 / 26.9 (the first iteration); step `load_ms` 13.5 / 14.0 s, p50 4.0 / 4.1,
  p99 9.4 / 9.4, worst 15.6 / 36.5.
- NOT DONE: the asleep-pack follow-up (kernel wake paths tell the tracker; `tl_bodies.gd`, `tl_contact.gd` untouched);
  the 60-asleep-packs figure was not measured; warm-up of pipelines (nothing was built: the first drawn frame of a world
  is 52 to 78 ms and is the start, and no first-use cost stood out above an arrival's own attach, but no run was quiet
  enough to say "under a millisecond"); a stand-in cache on disk; the whole of `_pack_setup` off the main thread.

## P13: the far picture in motion, and what the land costs (2026-11-11, builder core-p13)
- 16:39 start. Class cache imported. `far_study.mjs motion`: the draw layer's own camera on keys (TL_DRAW_CAMERA),
  Godot's movie writer, ffmpeg sheet + mp4. Before: the far -> middle change popped (tone, shadow, mark size); marks
  stepped every 2nd frame at 260 m; marks read as doors.
- Marks: drawn every frame between the last two ticks; rigs get a slim figure mesh; size grows smoothly with
  distance; shadow only nearer than 120 m. Far picture: far_flat 0, shadow on. After: the change shows only the
  lattice masts; the rink moves every frame.
- Pictures merged on a worker (surface arrays read there too) and cached under user://tl_cache/pictures by the pack
  directory's hash (hashed on workers). First-far frame 108 ms -> 7.6 to 9.5 ms (+4 to 20 ms when the meshes are made);
  from the cache 11.8 ms.
- Land: laps per section. Before: tour 1.76 s to the first frame (edges 752, terrain 363, colliders 329 ms), walk30
  4.54 s (edges 2018, grid 686, collision faces 808). Edges on a worker, land rows on a group task, collision faces
  without per-cell arrays: tour 0.63 to 0.66 s, walk30 1.05 s.
- Soft ground patches, trees give way to crane cameras, walks/compact_village.json (+ hockey via far_study compact).
- Kit: TLKitSite.bind_scoreboard. API bump to 1.1 tried and taken back (four P7 cases hold "1.0" as text): arch api-v1 shows this one finding, PATCHES-P13 entry 2. Selftest block P13: kit.score_bound, world.compact (both PASS).
