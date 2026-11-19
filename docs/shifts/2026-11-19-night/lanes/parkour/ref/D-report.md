# D3 arm B | Roofline Relay

All four acceptance lines are met. Play with `node devx/bin/tl.mjs play parkour`, or enter the blue-flagged plot south of the village road, west of the walker yard, centred at **(-192, 3, -48)**. Scripted keyboard play finished in **5.92 s** both alone and after walking in from the road.

1. **Gates — met.** `check --tier fast --changed` exited 0 with 15/15 selected units. `check --tier full` exited 0 with **944/944 units, 14/14 steps** on the third run. Parkour passed lint with zero bypasses, 3,600-frame smoke, all three bots and invariants. All eight games matched in the world. Parkour’s world and standalone hashes were both `8313175e5eedce9d` at frame 357.
2. **Stills — met.** Five 1920 × 1080 captures show the [course from above](stills/b-course.jpg), [jump at frame 69](stills/b-jump.jpg), [slide under the bar at frame 197](stills/b-bar.jpg), [chute descent at frame 295](stills/b-chute.jpg) and [plot from the village road](stills/b-village-road.jpg).
3. **Completion and impossibility — met.** The perfect-hand bot finished **20/20 seeds in 355 timed ticks (5.917 s)** with zero falls. Widening only the first gap from 3.2 m to 12 m made the same bot exit 1 after two falls before the first checkpoint. A recovery run finished in 436 ticks and kept its best time across R. An upright runner holding forward and run stopped 0.60 m before the bar’s centre for 30 ticks.
4. **Walker reuse — met.** Kernel API **1.7** exposes the village mover through `TLWalker`. It queries the pack’s physics space and lowers the capsule to 0.85 m during a run slide. On a flat test deck, pack and village both jumped **0.943 m in 33 airborne ticks**, reached walk and run speed in eight ticks each, and slid for 54 ticks over 5.31 m. A live-entry test also exposed held bot inputs carrying into player control. The handoff now releases them.

**Files changed.** Added `engine/packs/parkour/` and its three bots. Updated the house-game README, both boot manifests, the kernel API reference, walker collision and movement code, and runner manifest, lint and visit code. Regenerated `API-INDEX.md`, `API-V1.json` and `REPORTS.md`. The report and five PNGs are under `docs/reports/astra-trial/d3/`.

**Next.** Playtest the second landing with a regular hand to measure how often players reach the slide in time.

**Cost.** 82 min 54 s wall time, from 14:26:28 to 15:49:22 CET. Token usage was unavailable. The first full run had two failing checks and a busy-machine performance result. The second passed 942 counted units but could not judge performance. The third passed both performance scenarios at 33% machine use.

## Work log

- 2026-11-18T14:26:28+01:00 Trial started. Read the briefs in order and the root instructions.
- 2026-11-18T14:29:27+01:00 Read pack, seed, API, kit and card references. Confirmed trial fixtures and dependencies are local. Chose shared walker physics and a plot west of the walker yard.
- 2026-11-18T14:34:39+01:00 Built the shared API 1.7 walker, the Roofline Relay kit course, timer, HUD, two input-only bots and the village plot at (-192, 3, -48). Starting runtime checks.
- 2026-11-18T14:36:08+01:00 Raised bar clearance to 1.49 m after a trace showed the ground mover lifting its sliding capsule into the bar. Clean bot passed in 355 race ticks, checkpoint bot passed in 436. Fast gate 244/244, full launched.
- 2026-11-18T14:39:29+01:00 All 20 seeds finished in 355 timed ticks. Widening only gap one from 3.2 to 12 m produced bot.ok=false after two falls, with a clean load. Reviewed four captures and the road tour; replacing the flags that hid the low bar and adding an upright clearance test.
- 2026-11-18T14:43:20+01:00 Verified the world-host hash matched the runner at 357 ticks. Upright control stopped 0.60 m before the bar for 30 ticks. Scripted standalone keyboard play won in 355 ticks. A live village entry exposed the prior bot's latched W/Shift; clearing injected input on stage handoff and rerunning.
- 2026-11-18T14:44:46+01:00 Replayed a live visit from the road through the gate. At tick 221 stage 7 had control; recorded W/Shift now match their device frames. The village HUD read Finish 5.92 s and Best 5.92 s. Saved the road still from the visitor camera. Final fast gate 244/244.
- 2026-11-18T14:48:52+01:00 Pack lint, smoke (3600 frames) and invariants passed; bot deterministic at 357 runner frames. Opened the real tl play parkour window and closed it normally after 516 physics frames (exit 0). Rechecked the final course on 20/20 seeds and the widened copy (exit 1).
- 2026-11-18T14:51:19+01:00 Measured the pack controller on a longer flat test deck against the village walk selftest. Both reached walk/run pace in 8/8 ticks, jumped 0.943 m with 33 air ticks, and stayed low for 54 ticks (5.315 m pack, 5.31 m village). All eight village walker cases passed.
- 2026-11-18T14:54:56+01:00 Full gate has finished the kernel, kit and house-pack runs and reached perf. All six Roofline Relay pack logs are green. Released the worktree scope claim for handoff.
- 2026-11-18T14:59:54+01:00 Full gate advanced through perf and seeds into item.selftest. Waiting for its completed-unit totals and eight-game world comparison.
- 2026-11-18T15:01:36+01:00 First full gate returned exit 1, 941/942 completed. World 8/8, parkour hash 8313175e5eedce9d at 357 frames. k2.down_invariants and hockey many_budget (1.021 ms vs 1.0 ms) failed; perf marked machine busy (71%). Diagnosing in isolation before a fresh full run.
- 2026-11-18T15:02:44+01:00 Isolated repeat passed k2.down_lint/smoke/bot/invariants (4/4). Hockey invariants also passed, p50 0.912 ms. Started a second unmodified full gate with no other verification runs in this arm.
- 2026-11-18T15:18:09+01:00 Second full gate completed the kernel and kit suites and entered the house-pack suite. Final totals will come from the gate trailer.
- 2026-11-18T15:26:29+01:00 Second full gate exit 2, 942/942 counted units completed, 180/180 kernel cases and all eight world hashes green. Only perf could not run (56% CPU, probe 0.948; limits 45%, 0.95). Continuing within the 120-minute box.
- 2026-11-18T15:27:42+01:00 Isolated perf passed both mix30 and pile600 within baseline tolerance at 44% use, probe 1.0. Started the third complete gate to establish one green command.
- 2026-11-18T15:41:07+01:00 Third full gate advanced from the kernel and kit suites to the house packs. No game or gate edits since the preceding full run.
- 2026-11-18T15:49:22+01:00 Final gate 944/944, world 8/8, fast changed 15/15. Verified all five PNGs, then wrote the final report.
