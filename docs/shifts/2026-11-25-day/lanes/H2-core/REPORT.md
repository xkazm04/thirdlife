H2 (core and base), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-b (branch d25-hard-b, base 39d3f7b). Opus.
Items 1 and 2 done; item 3 probed (both faults are not base drawing bugs; nothing to fix in the base).

== 1. PICKUPS AND EFFECT EVENTS IN THE CORE'S SNAPSHOT (unblocks G1 Arsenal hockey) ==
What changed
- engine/cores/rink/native/src/rink_core.cpp snapshot(): three read-outs from thirdjam's effect system (UJamEffectSystem,
  which the sim's Events never carried):
    Pickups       [{Id, PickupIndex, Kind, Pos, SpawnFrame}]  GetPickups (FJamPickupOnIce), on the ice now
    EffectEvents  [{Name, Who, Where, Strength, Kind, Frame, Text, Dir, Outcome}]  GetFrameEvents: pickup_spawn / pickup_take /
                  effect_start / effect_end this frame
    Boosts        [String per skater]  GetBoostKindFor (the boost glow's kind; "" none)
  Read-outs only: nothing stepped, nothing hashed. The sim's Events are NOT appended to (a pack listening to Events hears what
  it heard). SNAPSHOT.md v1.4: additions only (status line, shape, a new section "The effect system's read-outs").
- Rebuilt all cores with `rink.sh build all` (thirdjam debug+release, t5 debug, thirdlife debug+release; -j6 to stay under
  the CPU ceiling): EXIT 0. Changed binaries: rink_core.{debug,release}.dll, rink_core_thirdlife.{debug,release}.dll.
  rinkcli-thirdjam-t5.exe was relinked from unchanged sources: I put the original back (no binary diff for it).
- Base (engine/templates/rink_game, hokej's copy byte-equal): scripts/rink_toys.gd now reads the snapshot's Pickups (it
  already drew a list when present); counts() gains core_on_ice; the pre-1.4 fallback also listens to EffectEvents.
  tests/bot_toys.gd (template only): a cartridge with pickups FAILS when the core reports none, when none lands in 2,400
  frames, or when the beacons standing are not the core's count. README: pickups no longer a known limit.
- New: engine/cores/rink/tools/rink_pickups.gd + selftest block 865 (rink.snapshot_pickups, rink.pickups_drawn).

Evidence
- hokej bot hashes, all 14 bots, before (copied DLLs) and after (rebuilt DLLs + new rink_toys.gd): IDENTICAL, all passed.
    bot_match_hand fd162294891897fc   bot_gym_hand 83e7ddd8360faed6   bot_rule_w_away c69a8362eda1d6b1
    bot_rule_s_lock ed4ae31c4537d66a  bot_rule_aim 85e156b868c93dd0   bot_rule_aim_anchor 51848c0a83b7c4d9
    bot_tj_replay 4341753bf4227a11    bot_rule_restart a81ec62c09aca9f5  bot_rule_signals db66e2a271264059
    bot_hud_rules 3905d475ae359ba0    bot_level_record b80f28fdb0a38050  bot_first_match fe4dd45844ce33de
    bot_cut_cores b7240b3b2e392418    bot_skin 0b476bdc7f9d4518  (full 64-hex in .tl/hashes-{before,after}.txt; diff empty)
  (bot_first_match, bot_match_hand, bot_skin, bot_tj_replay, bot_cut_cores equal E1's listed baseline too.)
- rink.snapshot_pickups: thirdjam's Arsenal cartridge, 3,600 frames: 36 pickups put down (16 speed, 20 precision), 28 taken,
  8 standing, 22 effect_start, a boost on some skater in 2,844 frames; every spawn and take in EffectEvents on its frame at
  its Pos; a second core never asked for a snapshot hashes equal on 3,600 of 3,600 frames; the regular cartridge reports none.
- rink.pickups_drawn: a template copy with all five built-in kinds: "pickups put down 12, taken 5, standing 7 (core 7)".
- Stills (window, 1280x720, HUD on), LOOKED AT, in this folder:
    h2_pickups_top.jpg     six beacons in their kinds' colours (cyan speed, magenta precision, violet heavy puck, yellow
                           big puck) on the ice from the top camera
    h2_pickups_follow.jpg  a speed beacon (cyan spike on its pedestal, ground ring) ahead of the player: reads at once
  Seen, not mine: the top view still draws the human's follow-camera ring as a large ellipse (E1's known HUD item).

== 2. A FINISHED GAME MOVES TO THE NEWEST BASE (My games) ==
What changed
- foreman/src/rebase.ts + cli_rebase.ts: `foreman rebase <job>` and `foreman rebase --pack <dir> --out <dir>` (no model).
  Kept byte for byte: data/skin.json, data/match.json, data/*.rules.json, the game's cartridge (match.json's), every file the
  base lacks, and every data/ file the game changed. A file that is SOME version of the base (the job's ref/base copy, or any
  version of engine/templates/rink_game in git history, by blob id) is replaced by the newest; new base files are added;
  files an older base had and the newest dropped are removed. A script/test/gen/asset the game changed = conflict: refused,
  named (the move would lose it). pack.json: the game's own + the base's tests first, union of capabilities/assets/cameras,
  newer kernelApi, next version. Then lint, smoke, every bot of the manifest; a bot that fails is run on the game as it was:
  failing there too = the game's own failure, kept and named; only a check the move broke stops it (game untouched).
  Job mode: verify events in job.jsonl, then pack/ and ref/base follow, a merge + "[foreman] what changed in v0.1.n ..." note,
  promoted/<id>@<version> beside the earlier versions, job done. Refused while a Foreman runs (job log lock), or when the job
  is not done / not on a core.
- Create: My games draws one control, "Newest base", on a finished game whose pack lacks or holds older base files
  (create_model.gd base_behind: scripts/, gen/, tests/ of engine/templates/rink_game against <job>/pack); it sends
  `foreman rebase <job>` (foreman_door.gd rebase) and toasts what happens; the row reads "Moving to the newest base" while
  the Foreman verifies. cli.ts kept at its 861-line ratchet.
- New tests: foreman/src/test/h2_rebase.test.ts (4), engine/ui/create/create_rebase_case.gd + selftest block 866 (4).

Evidence: the proof on a copy of .tl/proof-games/pond_v014 (.tl/proof-pond/, `foreman rebase --pack`):
- plan: 5 base files brought up to date (captions, hud, skin.gd, main.gd, bot_skin), 3 added (ability.gd, rink_toys.gd,
  bot_toys.gd), 32 current; kept 13 (black_ice cartridge, its commentary, the pond's own hud_barks.json banter - a base file
  the game rewrote - match, skin, five trial cartridges, its three own bots); version 0.1.4 -> 0.1.5.
- verified: lint, smoke, 7 bots ok; bot_crease_policy FAILS, and fails word for word the same on the untouched v014
  ("2 cross passes of 3 ... score 0:5"): kept as the game's own. "PASS rebase: verified (9 checks; 1 failed as on the game
  before the move)". The cartridge, skin, match, barks, commentary and the pond's bots are byte-equal to v014 (cmp).
- h2_pond_top_v014_vs_v015.jpg (LOOKED AT): v014's top view is cut by black roof trusses across the rink; v015's is the
  whole rink, clean, nets and players visible. The roof trusses are gone.

== 3. TWO DRAWING FAULTS (two-way probe; no base fix needed) ==
Probe: engine/cores/rink/tools/rink_cage_probe.gd on E5e's cartridge (proof-games/patches_v011 slush, 70 x 35, corner 3),
seeds 1-3 at pro, the human played by thirdjam's playerbot, 29,750 frames.
- Net: the core's net hull (CollideSkaterStatic: GoalLineX..+NetDepth 1.5, GoalWidthM) keeps bodies out: 6 of 29,750
  frames had a body more than 2 cm in, deepest 7.9 cm. The base draws the net at the same box (tj_rink.gd _goal: L/2-4,
  depth 1.5, the cartridge's goal width). So #7 "climbing over a net" in E5e's strip is a skater pressed against the net's
  front seen from the raised follow camera (a 1.8 m figure in front of a 1.2 m net), not a body inside the cage.
- Bumpers: the core's contact disc is the drawn disc (JamSim.cpp:2265-2276 radius Size/2 + 0.4; rink_toys.gd draws
  diameter = size at the cartridge's x, z); measured closest skater centres 3.83-3.90 m for radius 3.5 (+0.4). E5e v011's
  bumpers sit 1.24 m off the boards. E5c's (60 x 30, corner 3, d 5 at +-27.3, +-12.3) sit 0.08 m from the rounded corner
  (computed): the drums touch the boards, and the top camera's perspective puts the 1.2 m drum over the corner. Cause: the
  cartridge's placement (the Designer packed them into the corner), which the core accepts. Not a base bug.

== GATES ==
- k.sh selftest: [selftest] 120 passed, 0 failed: RESULT PASS
- selftest rink.: 40 PASS, 0 FAIL (38 before + rink.snapshot_pickups, rink.pickups_drawn; rink.template "41 files equal
  hokej's", rink.trace_head 51/51, rink.trace_t5 21/21, rink.variant, rink.advice 12,206/12,206, rink.playtester_seat)
- selftest hokej.: 5 PASS, 0 FAIL (hud_rules, hud_layer, pause_own, pause_frame, level_record b80f28fdb0a38050 replayed equal)
- selftest create.rebase: 4 PASS, 0 FAIL (block 866)
- tl check --only world: PASS world [9/9] 9 games: world = alone (201 s)
- foreman h2_rebase.test: 4 pass, 0 fail
- tl check --tier fast (after `godot --import` made the 3 .uid files and cli.ts was cut back to its 861-line ratchet; the first
  run FAILED on exactly those): PASS arch [12/12], PASS assets [4/4], PASS cards [3/3], PASS devx.test [229/229] 229 pass
  0 fail, PASS foreman.typecheck. EXIT 0.
- foreman npm test: tests 376, pass 369, fail 0, skipped 7 (EXIT 0). The 4 new tests are among them.
- selftest create.: 15 PASS + 1 FAIL in the run at 100 % machine CPU: create.pause.path "quality retry is sent (the page waits
  for the Foreman) (frame 755)" (a frame-counted wait on a real fake-adapter Foreman); run again alone right after: PASS
  (10 steps). My edits do not touch the pause cards; I call it load-timing flake, but name it: if it recurs on main, look there.

== CHANGED FILES ==
engine/cores/rink/native/src/rink_core.cpp, engine/cores/rink/SNAPSHOT.md, engine/cores/rink/bin/rink_core{,_thirdlife}.
windows.template_{debug,release}.x86_64.dll, engine/cores/rink/tools/{rink_pickups,rink_cage_probe}.gd (+ .uid),
engine/templates/rink_game/{scripts/rink_toys.gd, tests/bot_toys.gd, README.md}, engine/packs/hokej/scripts/rink_toys.gd,
engine/tools/selftest.d/{865-rink-pickups,866-create-rebase}.sh, engine/ui/{foreman_door.gd, create/create_model.gd,
create/create_build.gd, create/create_rebase_case.gd (+ .uid)}, foreman/src/{rebase.ts, cli_rebase.ts, cli.ts, cli_args.ts,
test/h2_rebase.test.ts}, this folder (STANDUP.md, REPORT.txt, 3 JPG stills).
Behaviour changes: bot_toys now fails a pickup cartridge whose pickups the core does not report or that never land (it only
said so before). No sim number moved.

== FOR THE DIRECTOR ==
- Owner, to look: My games -> a finished rink game -> "Newest base" (Create in the editor), then Play the new version and
  press the top camera. Stills here: h2_pond_top_v014_vs_v015.jpg, h2_pickups_follow.jpg.
- Contracts: contracts/JOB.md has no `rebase` command yet (Director's): the events it writes are existing ones (job_state,
  verify, merge, note, promoted).
- Known limit: a later change on a moved job recomposes pack.json from the plan, which does not list bot_toys.gd; the file
  stays, the bot is then not run. The plan's base package registers could follow the base (a replan event).
- E5c follow-up (not base): a cartridge check could warn when an obstacle lies within ~1 m of the boards.
- Next three: draw the Boosts read-out (thirdjam's boost glow on the skater, boost_look.gd NOT PORTED); let the top view hide
  the follow-camera ring; carry the plan's base registers on a rebase.
