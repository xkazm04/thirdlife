# Night shift of 19 Nov 2026: verdict

The first run of `/shift`. The lanes ran from 00:08 to 05:10 and the verdict was written at 05:45, two hours before the
08:00 land-by. All four lanes the owner picked landed, then took extra rounds from their own "next" lists, inside the
agreed scope. Main is pushed at `d6f3659`. The exe `d6f3659 2026-11-19 05:29` passed `export.sh check`.

**Final gate on main `d6f3659`:**

| Step | Result |
|---|---|
| arch | 12/12 |
| assets | 4/4 |
| cards | 3/3 |
| devx.test | 226/226 |
| foreman | typecheck and 210 tests pass |
| kernel.selftest | **277/277** (219 before the shift and bugfix-37 had 180) |
| kit.selftest | 91/91 |
| packs | 2/2, 35 of 35 verb runs |
| seeds | 39/39 |
| item.selftest | 91/91 |
| ui.selftest | 128/128 (77 before) |
| world | 8/8, every game hashes the same in the world as alone |
| perf | PASS on a quiet machine (`tl perf run --quiet-only`; in the full gate it reported NOT RUN, machine busy) |

Also run: the windowed tour (passed after the walker and hunt2 merges), and `export.sh check`.

Before the shift (18 Nov evening), **bugfix-37** landed `120208a`: 35 of the trial's 37 bug-hunt defects fixed. Q24 was
fixed in part, and Q31 was left for the owner.

## Lanes

### parkour: landed in 2 rounds (`9ea78b0`, `d6f3659`)
- **What:** course F now looks like D, the winner by the owner's eye, built by Astra alone. It has E's run-up at the bar,
  a new **C retry** at the beam, a 4th checkpoint, D's cabin between the decks and open hills.
- **Evidence:** D/F side-by-sides (`lanes/parkour/stills/`, `stills-r2/comparisons/`) and clips `clip.mp4` and
  `clip-r2.mp4`. Bots pass on seeds 1-3; the impossibility test fails as it should with a 12 m gap. `tl ladder` retry:
  regular hand 20/20, newcomer 19/20 (seed 12 lost).
- **For your eye:** `dist/PLAY-LATEST.cmd`, walk west to the parkour plot, run the course. Walk into the beam standing up
  and press C.
- **Asks:**
  1. Keep the C retry at the beam, or only E's run-up?
  2. The newcomer retry bot is a gate test on seed 1, like hockey's ladder bots. Keep it there, or move it to ladder only?

### walker: landed in 3 rounds (`58a80d1`, `7b8c2bf`, `9c40838`), Opus directing Astra
- **What:**
  - The camera stays out of tree crowns: frames inside or near them went from 4,197 / 15,930 to 0 / 0 with his head
    outside a crown.
  - He no longer wedges in narrow V channels, and he rises onto a floor that arrives under him.
  - The held-slide foot is above the floor, and the slide-entry dip went from 0.148 to 0.018 m.
  - Walker ink coverage: 45 to 95 % on banks, 9 to 96 % against walls.
  - Hill crests are inked, and the bluff crawl ends below its old level (2.217, then 1.987 %, against 2.010 before).
  - Hunt2's two highs are fixed: a warm site cache changed a game's hash, and a backslash `--input` lost the stage record.
    Seven smaller findings are fixed too.
  - A/D sidestep or turn, and the crown swing, are each behind a setting. The defaults are unchanged.
- **Evidence:** `lanes/walker/clip.mp4` (16.6 s), ink and slide stills, A/D clips, swing clips, and checks in blocks
  400-490.
- **For your eye:** walk toward the bluff and under the trees, then slide down the bluff. Watch the outlines and the
  camera.
- **Asks:**
  1. A/D: face (today), sidestep or turn? Clips `ad/ad_*.mp4`; to try live, `TL_AD_KEYS=sidestep|turn`.
  2. Near crowns: may the camera swing up to 90-120° sideways (the default), or stay behind (`TL_CROWN_SWING=behind`,
     which costs 116 frames inside leaves in the sweep)?
  3. Slope jumps (D14 / A11): two slope jumps clear a 56° bank. Keep, weaken the push, or allow one slope jump per touch
     of walkable ground?
  4. The slide's trailing hand, which is 0.31 m above the floor (Q31): touch the floor, which needs the torso to lean?
  5. The camera choices from bugfix-37: it ignores a crown while his head is inside it, it comes close when a wall is
     behind him, and it never drops below head height. Keep all three?

### editor: landed in 4 rounds (`eac9e92`, `c9fe14f`, `d47f14b`, `16534db`), Opus with Astra-drawn mockups and look
- **What:** the minigame editor, rebuilt as the start of the tool the owner described.
  - **Workbench:** idea, then recipe, then grouped questions with proposals and their reasons, then placing and sizing
    the game on the village map (problems named in words, scale beside the 2 m walker), then a review, then "Build it".
  - **Game sheet:** Decided / Open / On its lot / Now, and a decision can be changed with a refit preview.
  - **Look:** a pass by Astra alone (illustrated map, inked panels).
  - **Home:** the village board, with every game on its lot.
  - **In the world:** a workbench game rises on the lot the player chose, and the workbench now knows the river.
  - **Lost click:** found in the test drive (a scripted press lets Windows send one motion at the real cursor) and fixed.
    A player was never affected.
- **Evidence:** `lanes/editor/DESIGN.md`, Astra's raw mockups, look-pass side-by-sides, and clips `clip.mp4`,
  `clip-look.mp4`, `clip-home.mp4`, `clip-lot.mp4`. ui.selftest 128, and drives `editor`, `home`, `live` and `chips`
  (0 of 900 clicks lost).
- **For your eye:** `bash engine/tools/ui.sh fake --out=<scratch>/fake` (with `TL_ENGINE_DIR=<repo>/engine`), then
  `bash engine/tools/ui.sh open --jobs=<empty dir> --flags=<scratch>/fake/flags.fake.json`. It opens on the village
  board.
- **Asks:**
  1. Is this the direction for the editor (the workbench, the sheet and the board)?
  2. Contract proposals: CARDS.md `interview` and `footprint` per card; JOB.md `job_created.answers` and
     `job_created.lot`, and `change_requested.decision`.
  3. With the river checked, the village has no room by the road for a 45 m venue. Grow the village, or keep venues
     small?

### hunt2: landed in 2 rounds (`30cfbed`, `376dc23`), Opus directing Astra
- **What:** 37 findings graded (36 verified). 23 were fixed in its own scope, among them the held-ball freeze, the nitro
  crumb, a shared laws material, the regular hand's lost double taps, hockey leaks, parkour retry and respawn, seed
  scoring, `tl ladder` counting rejected runs, bugfix blocks passing a stopped run, boot's exit code, and unknown
  tuning keys. The two highs in walker files went to the walker lane, which fixed them.
- **Evidence:** `lanes/hunt2/findings.md`, `findings-round2.md`, the repros, and blocks 360 (36 cases).
- **Asks:**
  1. Hockey C4 (the puck slides while the clock is paused) and C6 (a puck touching the goal line from the field side
     scores) wait for the owner, because hockey is deferred.
  2. Should `place()` take pack coordinates? Today it takes world coordinates, against API.md.
  3. The hockey frame-time budget (`many_budget`) fails `packs` whenever lanes load the machine (1.02-1.09 ms against
     1.0). An A/B run showed load, not regressions. Should the gate retry under load, or the budget change?

## Route scoreboard (feeds the skill's route table)

| Route | Lanes / rounds | Held? |
|---|---|---|
| Astra alone (look) | parkour r1 and r2; editor look pass and mockups | Yes. The parkour look closed the gap to D; the editor look pass was a clear step up and stayed readable. Fast: 16-26 min per run |
| Opus directing Astra (code) | walker r1-r3, hunt2 r1 | Yes. The Opus directors caught Astra's look regression (the thin grey crest, sent back twice) and its scope noise (claims written into the worktree, CRLF churn). The cybersecurity filter stopped one hunt run; it was resumed by id |
| Opus alone | editor slices, hunt2 r2, the small walker items | Yes. Hunt2 r2 judged its five items too small for Codex |

**Cost:** about 4.1 M Astra tokens:
- walker 2.46 M
- hunt2 0.92 M
- parkour 0.40 M
- editor 0.28 M

4 Opus lane agents ran all night (plus 1 for bugfix-37 before the shift), and about 12 landings went through the gate on
main.

## Lessons for the skill
- Agents cannot write files named `REPORT.md` (a harness refusal). The Director saved each report from the final message.
  Ask lanes for `REPORT.txt` and the final message.
- Lanes picked selftest block numbers that collided (two 360s); the Director renumbered them. Assign a block range per
  lane in the brief.
- Measuring clips and frames grew to 775 MB in one lane. Keep them under `.tl/` or the vault, and commit only sheets,
  notes and short clips.
- Hockey's `many_budget` flakes under load. Re-run `packs` alone and A/B against the pre-merge tree before calling it a
  regression.
- Re-dispatching landed lanes from their own "next" lists kept the machine busy all night, within scope.

## Next shift
- The owner plays exe `d6f3659` and answers the asks above.
- Then: the editor's next steps (the village reads `_editor/` itself; the contract proposals once approved), the parkour
  fun pass after the owner plays it, and a hunt on the third-load hash difference of seed_drive (walker r2 finding).
