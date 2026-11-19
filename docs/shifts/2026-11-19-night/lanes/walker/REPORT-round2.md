Lane walker, round 2 (n19-walker2 from 58a80d1), 03:06-03:55 by the worktree clock. Nothing committed.

All nine requested hunt2 findings are fixed. Not A11 (the owner's D14). Each has a repro before -> after and a permanent check.
I re-ran every check myself: red on the HEAD file(s), green now.

B2 (high), warm site cache changed ticks and hash. Built by D.
  Cause: site.gd restored the scheduler footprint from the cached display radius.
  Fix: s["sched_r"] = fr (from the files) is saved at setup and restored on arrival.
  Repro: B2.py FAIL (cold/warm pack ticks 220/123, different hashes) -> PASS.
  Check world.site_warm_cache (block 440): HEAD gives cold 220 vs warm 123; now cold = warm = 220, hash 51b227f5.
B4 (high), backslash --input lost the stage recording. Built by D.
  Fix: visit.gd normalizes the input path once.
  Check runner.input_backslash (440, engine/kernel/runner/walker_replay_case.gd): HEAD backslash feeds 0, gas 0;
  now feeds 1, gas 71, the same as forward slashes.
  Separate finding (not fixed, outside B4): in the hunt2 B4 harness a 3rd in-process load of seed_drive hashes
  differently (afa14fea vs 56025ee7) even with a forward-slash path. A 4th load matches again. The record files are
  byte-identical between loads (md5 checked). That is why my check compares feeds and gas ticks, not hashes.
B7 (medium), concave floor faces dropped by their centroid. Built by Astra r5.
  Fix: world_space.gd and draw_pictures.gd share a triangle-meets-disc test in draw_base.gd.
  Repro: visitor at -26.60 m -> held at 0.00.
  Cost: village concave faces 9,838 -> 10,118 (+2.85 %).
  Check: ground.concave_cover (block 460).
B3 (medium), site job-log reader accepted malformed events. Built by Astra r5.
  Fix: new site/event_schema.gd validates each event before the fold.
  Repro: 6/6 invalid events accepted -> refused. All shipped fixtures and both site/ jobs still read whole (255/255).
  Check: site.log_schema.
B9 (low), late promoted files never re-checked. Built by Astra r5.
  Fix: a live site retries a missing manifest on its 60-tick poll.
  Check: site.late_files. Red on HEAD+B2 site.gd (arrival -1), now arrival at tick 120.
A13 (low), coyote jump accepted on tick 7. Built by Astra r4.
  Fix: air_ticks < COYOTE.
  Check: walk.coyote_limit (block 450).
H1 (low), 2.8 cm wall shiver. Built by Astra r4.
  Fix: 1 mm sweep margin on the ground horizontal move (walker_space._test takes a margin).
  Before: x span 0.0283 m, peak 1.13 m/s. Now 0.0000 m, and he still slides 2.1 m along the wall.
  Check: walk.wall_still.
A5 (low), downed walker-feel biped sped up. Built by Astra r4.
  Fix: TLBiped passes the brake to drive().
  Note: this touches engine/kernel/api/tl_biped.gd, outside the claimed scope. No public member was added; drive()
  gained an optional brake argument.
  Before 1.70 -> 5.10 m/s, now 1.70 -> 0.00.
  Check: walk.down_brake.
B12 (low), rejected first style load left an empty palette. Built by D.
  Fix: tl_style.gd marks a failed load as loaded only for the default.
  Check style.first_reject (block 470; the case lives in kernel/world/walks, because arch counted it as API under
  engine/style): HEAD 0 keys, now 100.

FULL GATE (one run, final tree): every step PASS.
  arch 12/12, assets 4/4, cards 3/3, devx.test 225/225, foreman.typecheck, foreman.test 210/210
  kernel.selftest 259/259 (main 250 + 9 new)
  kit 91/91, seeds 39/39, item 91/91, ui 123/123
  packs 2/2, 34/34 verbs; the hockey budget held this time
  perf 2/2 (mix30, pile600; machine quiet, use 40 %)
  world 8/8, world = alone; hashes match r5's before/after.
  The seed.drive/seed.wall hash change against my round-1 gate comes from hunt2's merge (seed scoring), not from round 2.
  Parkour hashes were the same before and after r4.

QUESTIONS FOR THE DIRECTOR
1. Is tl_biped.gd (engine/kernel/api) acceptable for A5? Otherwise drop A5.
2. JOB.md: should package_state.detail, builder_run.transcript and job_state.reason be marked optional? The reader
   follows the Foreman writer: 63 package_state events omit detail.
3. The seed_drive in-process 3rd-load hash difference (above) may deserve a hunt.

CODEX: r4 105,489 tokens (session 01a1f192-b1c8-79f3-a6c4-b82435a79b6d), r5 140,435 (01a1f192-b1ca-72a2-b940-a7c7f47c1885).
