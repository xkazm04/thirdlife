# Lane S: the construction site (status)

## Final report (00:55, 18 Nov; lane end 04:30)

| # | acceptance | verdict | figure |
|---|---|---|---|
| 1 | selftest `site.` cases | met | 6 of 6 PASS (`selftest.sh site.`, 00:35): replay_same (the same at tick 300 on two runs: building, 2 of 3), failed, missing_log, live (log grows 6 -> 21 events at tick 100, read at 120, game arrives), arrival (game arrives at tick 380, hash 545cd7c35ab2a361 = alone = replay), unmade (Director's seam: built 1 of 2 after the restore). Before: 0 of 6 (the old world makes no site plot and prints no `[site]` line) |
| 2 | `tl check --tier full` green | met | run 3, 00:35 to 00:51: exit 0, 882 of 882 units, every step PASS incl. `world` 7/7 and `packs` 1/1; kernel.selftest 165 (last green 159: + 6 `site.`); other counts equal to the last green |
| 3 | world.gd <= 672, `tl arch` green | met | world.gd 669 lines; landscape.gd 596 (<= 600); `tl arch` ok after `tl arch --index` |
| 4 | one still per stage | met | stills/site_pad.png, site_bays.png, site_mid_build.png, site_all_merged.png, site_arrived.png, site_failed.png (+ site_on_stage.png: the arrived game on stage in the exe); sheet S-site-sheet.jpg (300 KB) |
| 5 | `world.sh tour tour --headless` PASS; frame figure | met | PASS (23:57, busy: an export ran). Window tour before (main) / after: frame p50 2.754 / 2.882 ms, p99 10.24 / 9.74 ms, max 137 / 70 ms (possibly busy: lane C); the tour has no site lot |
| 6 | export builds, `export.sh check` PASS with the site lot | met | final build 00:51 (`--commit ew-site-final2`): PASS export.build, PASS export.check; `site_0` (the arrived 11 Nov hockey game) 5f173401f3f0d58a in editor, exe and moved exe |

Gate runs: run 1 (00:03-00:26) every step PASS but perf NOT RUN (machine BUSY 66 %) -> exit 2; kernel.selftest 164.
Run 2 (00:30) stopped by me when site/log.gd changed under it (the Director's seam). Run 3 differs from run 1 by
perf (quiet now: PASS) and kernel.selftest 165 (+ `site.unmade`); world hashes identical.

Files changed: new `engine/kernel/world/site.gd`, `site/log.gd`, `site/draw.gd` (+ .uid), `site/fixtures/` (failed,
arrive with promoted/example.bounce@0.1.0 = a copy of ex_bounce, unmade, site_arrive.json), `walks/site.json`;
changed `world.gd` (+4 calls, world line folded: 672 -> 669), `landscape.gd` (lots only, 592 -> 596), `WORLD.md`
(section S), `engine/boot/boot.gd` (`_site_lots`), `engine/boot/village.json` (one site lot), `engine/tools/export.sh`
(copies sites/), `engine/tools/selftest.sh` (one closed `site.` block), `docs/EXE.md`, `engine/JOURNAL.md`;
generated `docs/generated/REPORTS.md` (S-PATCHES 1).
New public API: none (no class_name; site.gd is preloaded by path). Walk keys `landscape.lots[i].job`, `.replay`.
PATCHES: S-PATCHES.md (REPORTS.md regeneration; optional kit part; world collider removal).
Questions: (1) the hockey game is built 700+ ticks after its release in a window (queue mode) against ~2.7 s alone:
worth a look by whoever owns jobs.gd. (2) the village's site lot is LIVE on a copied log: the Director's 07:00 job
needs a re-export to show progress in the exe; the editor binary (`world.sh visit`) follows the real file.

## Log
- 23:11 started; read common.md, laws.md, lane-S.md, contracts/JOB.md, WORLD.md, TIERS.md (loading), landscape.gd,
  world.gd, jobs.gd, tiers.gd, boot.gd, village.json, games.json.
- 23:25 design chosen (see Design). Recorded log states, read from the fixture (331 events): package states seen are
  `queued`, `running`, `verifying`, `blocked`, `promoted`; `merge` events 11; `job_state` passes through `failed`
  (seq 279) and back to `running` (a change request) and ends `done`. So "building" in the brief is the log's
  `running`, and "merged" is the log's `promoted` package state (after a `merge` event). Nothing invented.

## Design
- A site lot (`landscape.lots[i].job`) becomes, at world start, a RESERVED plot appended to the walk's plots
  (radius = lot radius, origin = lot `at` and `h`). The plot is held: the scheduler sees it as unreachable and the
  world never asks the arrival queue for it until the site says the job's last `promoted` event has been reached.
  Then the queue (jobs.gd) builds it like any arrival (`built` event in the world log: replays do the same).
- The site's state (stage, packages, states) is presentation; it is not in any `state_hash`.
- 23:21 the 11 Nov hockey pack (`promoted/game.ice_hockey_three_against@0.1.1`) LOADS on today's kernel: `world.sh run`
  smoke 600 frames, exit 0, 0 script errors, 0 engine errors, load 2.7 s. So the arrival is proven with the real pack.
- 23:37 first headless tour of `kernel/world/site/fixtures/site_arrive.json` (a wall yard + 2 site lots): PASS
  world.tour; the promoted fixture game (a copy of ex_bounce under the job's `promoted/`) arrives at tick 380 and its
  hash = alone = replay (`site_0 | example.bounce | 241 | 545cd7c35ab2a361 x3 | same`). world.gd 669 lines (<= 672).
- 23:42 stills run 1 (window, walks/site.json): 6 of 6 pictures; arrived still too early (queue builds the hockey
  game ~290 ticks after the release). Run 2 (23:47, busy: selftest running alongside): the game built at tick 2535
  (703 ticks after release, busy), the second promotion reloads it at 2632 (`reload` event) and it is built again at
  2719. Looked at: bays, mid-build (3 of 4 built, one bay on hold), failed sign, the rink standing in the fence.
  Fixed after looking: the sign's two lines overlapped (now title grows up, status line grows down).
- 23:50 selftest `site.` 5 of 5 PASS (replay_same, failed, missing_log, live, arrival). Before: the main checkout's
  engine on the same fixture walk prints no `[site]` line and makes no site plot (1 pack, `wall` only): 0 of 5.
  `tl check --tier fast --changed`: FAIL arch: landscape.gd 618 > 600 (moved the site helpers into site/draw.gd:
  596) and reports-index-fresh (generated digest; S-PATCHES.md 1).
- 23:55 S3: village.json lot (240, -55) r 40 h 2 with `job` = site/ice-hockey-three-against-20261111-1 (one key);
  boot.gd `_site_lots` (exe: sites/<job folder> beside games/; not found: plain lot + `[boot]` line + left_out);
  export.sh copies job.jsonl + the last promoted game to dist/ThirdLife/sites/. Editor check of the village: exit 0;
  site live, 331 events, game arrives at tick 0, ticks 2124 frames; 67 looks at the file, 23.9 ms in all.
- 23:57 `export.sh --commit ew-site-S3`: PASS export.build (tag 0ca9f8f 2026-11-17 23:55), BUILD.txt lists the site.
- 23:57 `world.sh tour tour --headless`: PASS world.tour (busy: export running); tick p50 1.64 ms, p99 21.6 ms.
- 23:59 `export.sh check`: PASS (step 1: 8 games, `site_0 | game.ice_hockey_three_against | 2123 | 5f173401f3f0d58a`
  the same in the editor binary, the exe, the exe moved; steps 2, 3, 4 PASS).
- 00:01 the exe, keys by script (TL_EXE_KEYS, no person): Shift+W 300 m east along the road, mouse -600 px (north),
  Shift+W in through the site's gate; blocked by the rink's boards at (240, -26.9), inside the plot; E at frame 2300:
  stage 7 (`site_0`) from frame 2310; Q at 2700: walking again at 2760; Esc ends, exit 0. Picture on stage:
  stills/site_on_stage.png (the 11 Nov hockey game, HUD "BLUE 1 / RED 1", "Q or Esc leave the game").
- 00:02 stills run 3 (fixed sign): stills/site_pad.png, site_bays.png, site_mid_build.png, site_all_merged.png,
  site_arrived.png, site_failed.png; sheet docs/reports/engine-world-next/S-site-sheet.jpg (300 KB).
  Release to built in a window (queue mode): 737 ticks (run 3), 703 (run 2, busy), ~287 (run 1).
- 00:03 window tour (`world.sh tour tour --pictures-only`), before = main checkout, after = this worktree, run back to
  back (lane C may be running: possibly busy): frame p50 2.754 -> 2.882 ms, p99 10.24 -> 9.74 ms, max 137 -> 70 ms;
  10 of 10 pictures both. The tour has no site lot: the difference is noise.
- 00:26 `tl check --tier full` (run 1, 00:03 to 00:26): every step PASS (arch 12/12, devx.test 216/216, foreman.test
  196/196, kernel.selftest 164/164 (last green 159: + the 5 `site.` cases), kit 86/86, packs 1/1, seeds 30/30,
  item 91/91, ui 69/69, world 7/7) except perf NOT RUN (machine BUSY, use 66 %): exit 2. `tl arch --index` was run
  first (docs/generated/REPORTS.md regenerated; S-PATCHES.md 1). perf again at 00:27: BUSY (92 %); at 00:30: PASS
  (mix30, pile600 within tolerance; machine quiet, use 35 %).
- 00:27 site.gd: the reserved plot no longer carries `"pack": ""` (absent value = omit the key). Re-export
  `--commit ew-site-final`: PASS export.build (tag 0ca9f8f 2026-11-18 00:27); `export.sh check` PASS, `site_0`
  5f173401f3f0d58a the same in all three runs.
- 00:30 `tl check --tier full` run 2 started (one clean run after the last code change).
- 00:32 Director's message (lane C seam): after a change that is not made the Foreman restores pack/ to the last
  promotion and appends `merge` events with `files: []` and `removed` (foreman/src/unmade.ts on ew-cards, read
  only). Before: site/log.gd set `merged = true` on EVERY merge, so a package whose files all go (added by the
  change) would show a finished house and count in "N of M built" (by the code; not run). Now a package's merged
  files are a set (`files` add, `removed` take away) and it stands finished while the set is not empty.
  Hand-written fixture kernel/world/site/fixtures/unmade (33 events: promotion, change, replan adds `cups`, merges,
  final verification fails, the two restore merges, `job_state done` "the change was NOT made"). Selftest
  `site.unmade` PASS: 33 of 33 events read, no log error, built 1 of 2 (`core:promoted+merged`, `cups:failed`),
  stage promoted (the earlier game stays). `selftest.sh site.`: 6 of 6.
- 00:33 gate run 2 stopped by me (task stopped, its own Godot/selftest processes ended: only processes under this
  worktree's paths) because log.gd changed under it; run 3 follows.
