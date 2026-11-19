# Lane parkour, round 4 (day of 19 Nov): Skyline newcomer losses and swing framing, done at 14:58

Worktree d19-parkour3 (Skyline landed on main in cdcf469; this round's edits continue on the same branch). Route as
before: Astra (codex gpt-6.2-astra, high, session 01a1f2bc-fc0c-7ad0-bfd1-9d7f5f86d10a) decided and built; the
operator traced the losses, passed back only facts, and re-ran every gate.

Codex rounds (machine clock). Tokens are the session's running total, so each round's share is the difference.
| Round | Wall time | Session total after | This round | What was passed in |
|---|---|---|---|---|
| 5 | 13:32:26-13:49:52 (17 min 26 s) | 1,322,996 | about 129,600 | Operator trace of the 5 newcomer losses, plus "frame the swing" |
| 6 | 14:02:04-14:14:39 (12 min 35 s) | 1,400,895 | about 77,900 | Camera only: the runner was hidden under the bar at the hangs |
| 7a | 14:25:29-14:26:10 (41 s) | 1,426,003 | about 25,100 | Camera only: the runner was out of frame at the take-off. Astra misread the 15:15 stop as a UTC-converted time and stopped at once without editing |
| 7b | 14:26:30-14:41:21 (14 min 51 s) | 1,510,263 | about 84,300 | The same item, with the machine clock stated |

## Item 1: newcomer losses on Skyline (game or bot?)
**Operator trace** (evidence/round4/skyline-trace.txt, newcomer-losses.txt). All 5 losses timed out at checkpoint 13,
the bars: course seeds 5 and 16, retry seeds 11, 12 and 18. There were two modes:
- **Mode A, mostly the game:** after a bar fall, the runway respawn walked the runner backward off the runway, down to
  the headwall approach. He stood there at the face for about 1,800 ticks: nothing returned him, and the bot never
  re-climbed. Course 16 and retry 11.
- **Mode B, the bot:** repeated mistimed releases. Course 5 had 20 attempts, 10 blue catches and 3 red catches.

**Astra's decision:** fix both, and keep the transfers and their catch windows.
- The game cause of mode A: the Back key, held for the pump on the bar, stayed down through the respawn. A person could
  meet this with ordinary controls; Astra reproduced it with the perfect hand (0.085 m drift on the shipped game).
- **Game fix:** the runway checkpoint ignores a Back press carried through the respawn until it is released. Landing on
  the lower approach now returns you to the earned runway. New test: tests/bot_runway_recovery.gd. Holding Back through
  placement gives 0.000 m drift and 2.31 m of advance with W; a fresh S walks off, the runner recovers and finishes.
- **Bot fix:** a shared release policy for all hands. The bot estimates the time to the next grip from its foot
  positions, and releases on a forward stroke at a predicted angle of 0.63 to 1.35 rad and more than 2.7 rad/s.
- **Kept:** the 2 remaining newcomer timeouts (course seed 4, retry seed 8). Both were still making real attempts at the
  clock limit, and Astra kept that timing difficulty on purpose.

**Ladder** (`tl ladder`, seeds 1-20). These are scripted hands, not a person. My runs match Astra's exactly:
| Level | Hand | Before (wins, mean frames) | After |
|---|---|---|---|
| Course | newcomer | 18/20, 2670 | 19/20, 2604 |
| Course | regular | 20/20, 1291 | 20/20, 1260 |
| Course | sharp | 20/20, 1081 | 20/20, 1079 |
| Forced C retry | newcomer | 17/20, 2467 | 19/20, 2403 |
| Forced C retry | regular | 20/20, 1378 | 20/20, 1432 |
| Forced C retry | sharp | 20/20, 1186 | 20/20, 1144 |
One input policy drives every hand; only the TLHand profile differs. As in round 3, the Skyline driver leads its
releases by its own measured input delay.

## Item 2: framing the swing (pack camera hint only)
- **Round 5 (Astra):** raised the sightline and widened the lens. This put the bars mid-frame, but the runner was hidden
  under the bar at the hangs (only the top of his head showed at frame 948).
- **Round 6 (Astra):** scripts/skyline_camera.gd, a node under the orbit camera. It turns the rendered view to the side
  and lower while the runner is on the bars. The walker still steers by the orbit's own yaw, and drag and wheel still
  work. The runner's visible pixels at the hangs went from about 3,000 to about 16,000.
- **My own play-camera stills** (stills/round4/) then found two gaps:
  - At frame 915, the jump to blue, the runner was not in the frame at all.
  - At frame 895 the view was already turned, so holding W ran him toward screen-right.
- **Round 7 (Astra):** the rear view is kept through the run-up and the take-off. The camera cuts to the low side view
  when the runner catches blue, holds it through the transfer and the red hang, and goes back to the rear view after
  the red release, for the ramp. Astra's measure at frame 915: 0 -> 14,439 visible pixels. Its continuous check over
  movie frames 868-990 found the runner visible in every frame (at least 7,647 px).
- **My check (stills/contact-sheet-round4.jpg, round 6 above and round 7 below; raw JPGs in stills/round4-final/):**
  the runner is visible at all six frames (870, 895, 915, 926, 948, 975). At 895 he runs straight up the screen toward
  blue.
- **Clip:** clip-round4.mp4, 17.40 s, 1280x720, 60 fps, native speed. One full perfect-hand run: 986 race frames,
  0 falls, splits 338/286/182/180. The Skyline part: clip-round4-skyline-strip.jpg.

## Gates (operator runs on the final tree)
- lint: PASS, 0 bypasses.
- Pack tests: 18 bots x seeds 1 and 2 = 36/36 pass. Every state hash is identical to the round-5 tree, so the camera
  changes are presentation only. I also ran round 5 on seeds 1, 2 and 3: 54/54.
- Impossibility: 12 mutations x (bot_geometry, bot_course) = 24/24 exit 1, with only bot.ok red (run on the round-5
  tree; rounds 6 and 7 changed no physics).
- Ladder: unchanged across rounds 5, 6 and 7 (table above).
- `tl check --tier full --only packs,world`: packs PASS 2/2 (48 of 48 verb runs), world PASS 8/8, on the first run.
- `tl check --tier fast`: PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck).
- Evidence: evidence/round4/operator/.

## Changed files this round
- engine/packs/parkour: README.md, pack.json (0.3.1, 18 tests), scripts/main.gd, tests/support/run_hand.gd.
- New: scripts/skyline_camera.gd, tests/bot_runway_recovery.gd.
- Lane: STANDUP.md, REPORT-round4.txt, clip-round4.mp4 and its strip, stills/round4*, stills/contact-sheet-round4.jpg,
  stills/astra-5..7/, evidence/round4/ (Astra's reports 5, 6 and 7).

**Size note for landing:** Astra's raw run videos (evidence/round4/astra-run-5.mp4, -6.mp4, -7.mp4, and
evidence/round3/astra-run-4.mp4) are about 21 MB each, and the lane folder is 142 MB. clip-round4.mp4 (11.6 MB) is the
operator's take.

## Behaviour changes (named)
1. Runway checkpoint: a Back key held through the respawn is ignored until released. Falling onto the lower approach
   returns you to the runway.
2. Play camera on Skyline: the rear view through the take-off, a cut to a low side view from the blue catch to the red
   release, and the rear view for the ramp. Your own orbit controls still apply.
3. The ladder bots' shared bar-release policy changed: newcomer 18 -> 19/20 on the course, 17 -> 19/20 on retry.
No test expectation was loosened.

## For the owner
`node devx/bin/tl.mjs play parkour`, or watch clip-round4.mp4. Nobody has played Skyline. A person should judge:
- the camera cut when you catch blue: does it disorient, given that W keeps steering by the rear orbit?
- the release timing on the bars.

## Questions for the Director
None new. Rounds 6 and 7 add a pack script that runs in _physics_process to compose the rendered camera pose. It is
presentation only and the state hashes are unchanged. Say if packs should do that only inside _pack_tick.

## Next
1. A person plays Skyline with the cut camera.
2. The two remaining newcomer timeouts (course seed 4, retry seed 8) are timing misses Astra chose to keep. Review them
   once a person has played.
