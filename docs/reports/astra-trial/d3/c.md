# D3 arm C: final report (Opus directing GPT 6.2 Astra)

Start 14:26:48, report Wed Nov 18 15:56:42 CEST 2026 (wall time about 91 min of 120). Astra runs: **1** (no resumes). Astra tokens: **637,049**.
My own tokens are not visible to me.

## Acceptance
| # | Verdict | Evidence |
|---|---|---|
| 1 | **met** | `node devx/bin/tl.mjs check --tier fast --changed`: exit 0, PASS arch [12/12], PASS cards [3/3] (39 changed paths). `node devx/bin/tl.mjs check --tier full` (run by me in this worktree, 15:35 to 15:55): exit 0, steps 14/14, **units 945/945** (floor 942), packs [2/2] 33 of 33 verb runs (parkour lint, smoke, bots, invariants), kernel.selftest 181/181 (with the new `walk.biped_parity`), **world [8/8]: game.parkour 5b103a8c... hashes in the world as alone**. Log: `docs/reports/astra-trial/d3/astra/gate-full.log`. |
| 2 | **met** | `docs/reports/astra-trial/d3/stills/`: `parkour-overview.png` (course from high above, oblique), `parkour-jump.png` (frame 73, mid-air over gap 1), `parkour-under_bar.png` (frame 198, run slide under the bar), `parkour-chute.png` (frame 288, slope slide down the 65 deg chute), `parkour-village-road.png` (the plot from the road). I looked at every one: each shows what it claims. |
| 3 | **met** | Course is **seedless** (layout does not read the seed). Bot `tests/bot_course.gd` (perfect hand, through the input layer) on seeds 1..20: **338 race frames = 5.633 s on every seed**, 0 falls. Impossible variant (`chain_gap_m` 12.0, a scratch copy): `bot_geometry` FAIL exit 1 "gap 2 is 12.00 m (running jump reach 4.95 m)"; `bot_course` FAIL exit 1 "gaps [true, false] ... falls 1". Also `bot_obstacles`: missing each gap respawns at the checkpoint; run+jump without slide stops at 27.09 m against the bar face at 27.30 m. |
| 4 | **met** | See "Reuse decision" below. |

Plot: `parkour` at origin **(-186, 1.0, -32)**, radius 28, south of the road at its west part (road point (-190, 3)), west of the walker plot; clears the road edge by 3.85 m (square footprint 2.93 m), the nearest plot by 14.57 m, the lots by 358 m (Astra's figures; consistent with village.json). `tl play parkour` launches it alone.

## Reuse decision (kernel API vs pack copy)
Kernel API addition, **1.6 -> 1.7** (opt-in): `TLBiped.create({"feel": &"walker"})` plus `slide()`, a `slide` action in `drive_from_input`, `walker_motion()`, `WALKER_HEIGHT`/`WALKER_SLIDE_HEIGHT`. Not a copy of the numbers: the pack biped calls the **same** `world_body.gd drive()` the village walker uses; the capsule queries it needs moved from `world_space.gd` into a new base `kernel/world/terrain/walker_space.gd` that both extend/use. Why: the walker's body was reachable only through the world's space, and TLBiped (jump 4.5 m/s, run 6.0, no slide, no slope slide) did not match; one code path means the feel cannot drift. Evidence (`walk.biped_parity`, same geometry, 60 Hz), walker vs pack: jump apex 0.943499 / 0.943499 m; air 33 / 33 frames; rest to full run 16 / 16; run slide 5.255554 / 5.255554 m, 54 / 54 frames; slope slide on 65 deg 54 / 54 frames, peak 14.0 / 14.0 m/s. Default TLBiped untouched: 56/56 legacy bot hashes and frame counts matched before/after, and the full gate's world step matches.

## Files changed (all by Astra except the one journal line)
engine/kernel: `api/tl_biped.gd`, `API.md`, `runner/manifest.gd` (1.7), `runner/visit.gd`, `world/terrain/walker_space.gd` (+.uid, new), `world/terrain/world_body.gd`, `world/terrain/world_space.gd`, `world/walks/walk_case.gd`; `engine/tools/selftest.sh`; `engine/packs/README.md`; `engine/packs/parkour/` (README.md, pack.json, data/course.json, scripts/course.gd, scripts/main.gd, tests/bot_course.gd, bot_geometry.gd, bot_obstacles.gd); `engine/boot/games.json`, `engine/boot/village.json`; `engine/JOURNAL.md`; `docs/generated/API-INDEX.md`, `API-V1.json`, `REPORTS.md`. Stills (not committed). `.tl/run/` holds 133 MB of Astra's verification copies (gitignored).
Share: Astra wrote everything in the pack and kernel (about 900 lines of code and docs); my own edit is one line in `engine/JOURNAL.md` (the full-gate verdict): under 1 %.

## Merge notes for the Director
- Main's `engine/tools/selftest.sh` was split into `selftest.d/` at 14:37 by another session (after this worktree branched). Astra's edit adds `walk.biped_parity` to the walk case list in the old monolith: at merge it must go into the matching `selftest.d` block instead.
- `kernelApi` 1.7 is a minor (additions only); `docs/generated` regenerated.

## Where Astra was strong, where it needed me
- Strong on architecture: it picked a better reuse than my brief (share `world_body.gd drive()` through an extracted capsule base, not re-read constants) and proved it with a two-body parity test that measures both bodies to six decimals.
- Strong, unasked, on regression proof: it replayed 56 legacy bot scenarios against a pristine engine copy to show the kernel change is hash-neutral, and found its own missing `super()` call that way.
- Strong on honesty: it reported requirement 7 as partial instead of calling separate step runs a full pass.
- Needed me on rule interpretation: it read "no git" as forbidding the stock gate (which reads a diff and builds a fixture repo in the system temp folder) and built git-free copies of the tree instead (133 MB in `.tl/run`, many minutes of tokens). I ruled the gate's internal git use is not a builder's git and ran the stock gate myself: 945 units, all green.
- Needed me for the end-to-end verdict and the merge risk (selftest.sh moved under it on main); taste-wise the course is short (5.6 s) and the overview is oblique rather than plan view, which I accepted for the time box.

## What I would do next
A longer course (a second chain, a chute that ends in a jump), a straight-down plan-view still, ladder figures through `sharp`/`regular`/`newcomer` hands (`tl ladder`) so the 5.6 s time is not only a perfect hand's, and the selftest.d rebase.

---

# D3 arm C: status (Opus directing GPT 6.2 Astra)

Start: Wed Nov 18 14:26:48 CEST 2026. Time box ends 16:26.

## Log
- 14:26 start; read common.md, laws.md, d3.md, arm-c.md.
- 14:30 surveyed: walker body = engine/kernel/world/terrain/world_body.gd (world-space kinematic capsule, not reachable from a pack);
  pack-facing TLBiped (API 1.6) has jump_speed 4.5, run_speed 6.0, no slide/slope-slide: feel differs. Steering Astra toward a
  kernel API 1.7 addition that reads world_body.gd's constants (one source of the numbers).
- 14:28 Astra run 1 launched (brief docs/reports/astra-trial/d3/astra/brief-1.md, log run1.log).
- 14:38 mid-run review: Astra chose to SHARE world_body.gd's drive() (new kernel/world/terrain/walker_space.gd adapter holding the capsule motion queries; TLBiped option feel=&"walker" + slide(); KERNEL_API 1.7). Better than my const-reading suggestion. Watch item: world_space.gd/visit.gd touched -> village walker hashes must not move.
- 14:51 looked at Astra's 5 stills (overview, jump, under_bar, chute, village-road): all show what they claim; overview is oblique-high rather than straight down; course is short (4 decks).
- 15:24 Astra still in run 1: per-step gates, 20 seeds, impossible-course variant, legacy-bot hash comparison before/after kernel change.
- 15:35 Astra run 1 done (637,049 tokens). Claims 1-6 done; 7 partial: it refused the stock full gate because the gate runs git (devx tree test makes a temp repo in os.tmpdir; --changed reads git diff) and it read my "no git" rule literally; it ran every step on git-free copies instead.
- 15:36 Director decision: the gate's own internal git use (read-only diff, a temp fixture repo outside the worktree) is not me or Astra running git; the acceptance line demands the stock command, so I run it myself. tl check --tier fast --changed: exit 0, PASS arch [12/12], PASS cards [3/3] (39 changed paths). Full gate started.
- 15:36 reviewed kernel diff (read-only against the main checkout): visit.gd reads WALK/RUN from world_body.gd; world_space.gd now extends walker_space.gd (capsule queries moved, not changed); world_body.gd: WALK_MPS/RUN_MPS consts, ray excludes own body, can_start_slide(), place() moved to the caller. selftest.sh in main was split into selftest.d at 14:37 by another session, so the worktree's monolith + Astra's one-word edit (walk.biped_parity) will need a rebase onto selftest.d at merge.
- 15:56 full gate exit 0 (945/945 units, world 8/8); report written; done.
