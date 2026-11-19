# Timber Run · Round 3 · 19 November 2026

**Design decision. Keep the course and fix recovery and steering.** Timing the pendulum and landing on a narrow beam are fair demands. Falling off the same checkpoint for another 2,000 frames, sometimes because the previous fall’s side key immediately drove the next attempt, inflated the newcomer difficulty figure. On the same twenty seeds, the newcomer now finishes 20/20 on both levels. Its mean course time is 29.43 s and it still falls a median of 8.5 times. [Per-seed results](r3/newcomer-runs.tsv)

## Where the losses came from

- **A player could reproduce the sideways step.** With the original checkpoint, a perfect hand deliberately ran off the side and released the key on the first observable respawn frame. The camera held its 90° yaw. The walker appeared near the centre at 0.567 m/s, accelerated briefly after release and stopped 0.693 m from centre. The beam’s half-width is 0.525 m. Placement clears velocity, but the pack immediately reapplied the held side key. The stock walker carries a new step from rest for nine ticks. Holding the key for 18 frames after placement moved the runner 1.649 m sideways. [Release trace](r3/release-on-respawn.tsv) · [Original regression failure](r3/beam-before.json)
- **The controller compounded it.** It could request a nine-frame correction every 16 frames, while the newcomer hand takes 14–23 frames to start a tap. It also estimated sideways speed across a teleport. On seed 8 the original controller delivered left and right inputs on successive beam respawns while the camera kept the same yaw. Isolating just the steering-policy change recovered course seeds 8, 14 and 16. Isolating just the checkpoint change also recovered all three, with 12, 22 and 25 falls respectively. [Delivered inputs](r3/seed8-beam-input.tsv) · [Isolated changes](r3/isolated-changes.tsv) · [Operator’s original trace](newcomer-fall-trace.txt)
- **Retry seed 12 lost on a different criterion.** Its original run reached the summit in 1,630 frames. The slide had already ended at station 30.069 m, before the bar began at 30.360 m. Moving only the retry slide cue from 3.6 m to 3.0 m before the bar gave the runner more run-up and produced an active slide at station 30.404 m. The original ladder verdict was correct. [Matched bar samples](r3/retry12-bar.tsv)

## What changed

At the near beam checkpoint the walker now faces down the beam. A strafe held through placement must go neutral or reverse before it can steer in that direction again. Forward and back remain available immediately, including while the old side key is still down. The HUD gives the release cue. The race clock and pendulum keep advancing. [Windowed checkpoint view](r3/beam-recovery.jpg)

On both levels, every hand waits for a lateral tap to appear and release on the public input before requesting another. A tap that never arrives can be retried after 45 frames. The controller measures lateral travel from the new position after a fall. Each hand uses the same 3.0 m retry-slide cue. All inputs still go through TLHand with its normal delay, missed taps and releases. The ladder still requires an active slide inside the bar and a summit finish. The forced-retry level also requires a witnessed block and C recovery. [Controller](../../../../../../../engine/packs/parkour/tests/support/run_hand.gd) · [Retry and win conditions](../../../../../../../engine/packs/parkour/tests/bot_ladder_retry_regular.gd)

The new beam regression deliberately falls off each side, holds that side for 18 frames after placement, then adds forward and run for 18 frames. It measured **0.000 m sideways and 1.583 m forward**. Releasing and pressing the same side key again moved the walker 0.314 m in that direction. Every existing test retained its assertions. The measured extra time for charging through a strike moved from 11–24 to **5–18 frames** because recovery is quicker. All six dangerous delays still produce a hit, and all six open delays still have identical finish times. The clean perfect-hand run remains **806 race frames (13.433 s)**, with splits of 338, 286 and 182. [Recovery test](r3/verify/bot_beam_recovery-1.json) · [Twelve phase pairs](r3/verify/bot_swing_phases-1.json) · [Perfect run](r3/verify/bot_course-1.json)

## Difficulty through each hand

Same seeds 1–20 before and after. Means include all twenty race clocks, including timeouts. The baseline used the landed pack at `ebeeb2b` on API 1.9 with a scratch registration for retry sharp. That registration uses the same retry controller with the sharp TLHand profile. It ships with this revision so all six cells can be reproduced. [Before ladder](r3/ladder-before.txt) · [After ladder](r3/ladder-after.txt)

| Level | Hand | Wins before | Wins after | Mean frames before | Mean frames after |
|---|---|---:|---:|---:|---:|
| Course | Newcomer | 17/20 | 20/20 | 2,316 | 1,766 |
| Course | Regular | 20/20 | 20/20 | 971 | 970 |
| Course | Sharp | 20/20 | 20/20 | 845 | 841 |
| Forced C retry | Newcomer | 17/20 | 20/20 | 2,042 | 1,698 |
| Forced C retry | Regular | 20/20 | 20/20 | 1,041 | 1,062 |
| Forced C retry | Sharp | 20/20 | 20/20 | 908 | 898 |

On the reported course losses, seed 8 went from 68 falls to 14, seed 14 from 51 to 6 and seed 16 from 57 to 8. Seed 1 improved from 16 falls to 7. On the forced-retry losses, seeds 4, 12 and 14 finished in 1,963, 1,267 and 1,637 frames with 13, 4 and 8 falls respectively. The regular hand’s forced-retry mean rose by 21 frames (0.35 s). On a separate check of seeds 21–30, the newcomer finished 10/10 on each level. These are scripted-hand measurements. Human completion rates remain unmeasured. [Per-seed runs](r3/newcomer-runs.tsv) · [Paired changes](r3/isolated-changes.tsv)

## Flight and scope

Parkour remains a walking course on kernel API 1.9. The operator pressed F at stage ticks 160 and 260 alongside Space, Shift and W. The 449 stage input samples recorded only jump, forward and run. After leaving the plot, the visitor reached 11.077 m above its previous height in flight. Parkour’s action map has no `fly` entry. The pack and tests use the existing walker, beam and HUD without kit or kernel changes. A stage using mantle or hanging remains deferred until the operator brings in the new API. [Windowed flight check](fly-probe-visit.txt)

## Gates

| Gate | Result |
|---|---|
| Pack lint | PASS schema, layout, fence, capabilities and size. Zero reported bypasses. [Lint output](r3/lint.json) |
| Every registered test, seeds 1 and 2 | PASS 28/28. Fourteen bots on each seed, including the new beam regression and forced-retry sharp cell. [All PASS lines](r3/verify/results.txt) |
| Full tier | PASS packs 2/2, 44/44 verb runs. PASS world 8/8. Parkour matched `d252059296969eef` after 808 frames. Hockey passed in the same run. [Full gate](r3/full.txt) · [World hash pairs](r3/world.txt) |
| Recovery in a world | PASS with parkour and paddle together. At tick 601, while the old strafe was still held, the parkour hash matched `e287ab6a7637f6ec` alone and in-world. After both deliberate falls it matched `be14e9b43e346659` at tick 1,276. [While held](r3/world-at-respawn.txt) · [Both recoveries](r3/world-recovery.txt) |
| Pack invariants | PASS repeated idle and bot hashes, frame budgets and entity count. [Invariants](r3/invariants.json) |
| Fast tier | PASS arch 12/12, assets 4/4, cards 3/3, devx tests 226/226 and Foreman typecheck. [Fast gate](r3/fast.txt) |
| Negative controls | PASS 20/20 expected failures. Nine impossible data changes each failed geometry and traversal. Removing the hit response failed the swing-phase test. The original beam response failed the new recovery test. Each bot completed with exit 1 and only `bot.ok` failed. [Failure lines](r3/negative-results.txt) |
