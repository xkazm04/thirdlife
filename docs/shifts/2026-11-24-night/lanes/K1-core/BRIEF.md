# K1 core: thirdjam's own simulation and bots, compiled into our engine

Campaign night of 23-24 Nov 2026. Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-core` (branch `hk-core`).
Route: Opus solo. Rounds of 60-90 minutes; first landable round as soon as the skater law runs and matches.

## Goal
Direction 1 and 8 of `docs/design/DIRECTIONS.md`: the game owns its simulation, and it is thirdjam's, copied whole. Not a
re-typing into GDScript: **compile thirdjam's actual C++** into a native library our engine loads (a Godot GDExtension),
behind a thin shim for the Unreal types it uses, so that the same source gives the same game. Then prove it: the same
seeds give the same trace as the Unreal build.

## What is known (scouted; verify as you go)
- Sizes (HEAD, `S` = `Game/Source`): sim `S/JamCore/.../JamSim.cpp` 4,717 lines (+ `.h` 1,177), `JamPawns.cpp` 1,033,
  `JamCartridge.cpp` 1,522 (+ `.h` 725), rules and zones about 500, effects about 1,700; AI `JamAICore.cpp` 2,728 (+ `.h`
  997), `DifficultyProfile.cpp` 423, `JamPlaytester.cpp` 1,384 (the human-like hands: novice, regular, good),
  `JamBotMatch.cpp` 411, `JamSimAdapter.cpp` 423, `JamHitHand.h` 409; the tournament commandlet
  `S/JamCore/AI/JamTournamentCommandlet.cpp`.
- Portability: `JamAICore`, `JamBotMatch`, `DifficultyProfile` are pure C++ (`<cmath>`, `<cstdint>` only). `JamSim` and
  `JamCartridge` use Unreal core types only (`UObject`, `TArray`, `FVector2D`, `FMath`, JSON reading): a type swap, not a
  rewrite. Everything under `JamGame` (rendering, UMG, input) is NOT yours (lane K3 ports the camera, input and pawns).
- Cartridges: `Game/Content/Cartridges/*.json` (11 cuts, `ladder/`, `modes/`); the regular game is
  `hockey.regular.cartridge.json` (5 v 5, 90 x 45 m, first to 3).
- The trace: `-run=JamTournament -cartridge=hockey.regular -seeds=a-b -mode=playerbot|playerbot_ai|brain|idle
  -difficulty=rookie|pro|all_star -player=novice|regular|good -playersprint -trace=N -maxframes=`; line format
  `TRACE f=<frame>[ frozen] stall=<0|1> puck(x,y v<speed>)` then per skater ` <team><H|P|C|S|B>(x,y)>yaw[mx,my SHOOT]`
  then ` since= ht= car= lt= fo= pk=`; each match ends with one `thirdjam.playtest/1` JSON line
  (`JamBotMatch.cpp:229-241`).
- The runnable Unreal build was made from the 15 Nov tree `C:/t/t5` (78 files differ from HEAD; `JamSim.cpp` by 149
  lines, `JamAICore.cpp` by 118). So: prove the shim by compiling **t5's** source and matching the t5 build's traces
  exactly; then switch the same shim to **HEAD's** source, which is what ships in our game.
- This machine has Visual Studio 2022, Python 3.12 and SCons; no CMake. Godot: `node devx/bin/tl.mjs doctor` prints the
  console exe (4.7.2). `godot --dump-extension-api` gives the API json godot-cpp builds against; godot-cpp must be
  fetched (network) at the branch that matches.

## Rounds
1. **Spike (time box 90 minutes): can it be built here?** godot-cpp built for this Godot; a hello-world extension loads
   headless. If this is blocked for a reason you cannot remove in the time box, STOP and report exactly what blocks it
   (the fallback is a hand port to GDScript, which the Director must decide; do not start it on your own).
2. **The shim and the law.** `engine/cores/rink/native/`: thirdjam's sources copied verbatim into `native/thirdjam/`
   (unchanged files; every edit you must make to a copied file is a marked patch and is listed), a shim header set for
   the Unreal types, a `RinkCore` class exposed to GDScript: load a cartridge (JSON text), set difficulty and seed, set
   the human's input for a frame (move x/y, aim x/y, buttons as thirdjam's input struct has them), `step()`, and read a
   snapshot (every skater: team, slot, position, velocity, facing, the stick aim, every state and timer the screen
   needs to pose him, e.g. down, stumble, wind-ups, braking, sprint, stamina; the puck: position, velocity, height,
   owner; score, clock, period, the frame's events). Mirror thirdjam's field names; write `engine/cores/rink/SNAPSHOT.md`
   as the interface (lanes K2 and K3 build on it: get this file out EARLY, in the first hour of round 2, even if
   incomplete, and say so in STANDUP.md).
3. **Proof of sameness.** A headless runner (`engine/tools/rink.sh trace ...` or a `tl` command) that runs thirdjam's own
   bot match / tournament through the extension and prints the same TRACE lines. Compare against the Unreal build's
   output for the same flags on at least 10 seeds x 3 difficulties (t5 source): the target is identical lines; where
   floating point differs, say where the first difference appears and how large it grows. Then build HEAD's source and
   record its traces as our baseline.
4. **In the engine properly.** The built library's home, how `tl doctor` / the gate / the export find or build it
   (`engine/tools/core.sh build`), what is committed (source and build script; say whether the binary should be
   committed and why), state hash: the snapshot feeds `_pack_state` so the determinism law holds; a test that the same
   seed and inputs give the same hash twice.
5. **Then** (later rounds, on the Director's word): thirdjam's own `Jam.Core.*` and `Jam.Bot.*` automation tests
   compiled against the extension; a hand ladder and mechanic ablation harness (lane K4) on top.

## Acceptance (rounds 1-4)
- The extension builds from a clean tree by one command and loads in Godot headless and in an exported exe.
- Traces from the extension equal the Unreal build's for the t5 source on the seeds above (or the difference is
  measured and explained at its first frame).
- `SNAPSHOT.md` names every field with its thirdjam source line; a GDScript smoke test steps a regular 5 v 5 match for
  3,600 frames with bots only and prints the score.
- The patch list against thirdjam's files is short and every patch is mechanical (a type, an include, a macro).
- `node devx/bin/tl.mjs check --tier fast` passes (rule-table edits listed).

## Scope
Write: `engine/cores/rink/**` (native sources, shim, build script, SNAPSHOT.md), `engine/tools/core.sh` or `rink.sh`,
the kernel entry a pack uses to reach the core (smallest possible; say what you added to `engine/kernel/API.md`),
rule-table edits per campaign rule 6, `docs/shifts/2026-11-24-night/lanes/K1-core/`. Selftest block range 800-809.
Not yours: camera, input mapping, figure, HUD, the pack (K2, K3).

---

# Campaign rules (the hockey port; pasted into every lane brief, above the lane rules)

Read `docs/design/DIRECTIONS.md` first: the owner's words, what went wrong three times, the ten directions, the stair.

1. **Port, do not reinterpret.** thirdjam is the reference and we own its source. Every number and every rule you write
   cites its thirdjam file:line. You do not tune, simplify, "improve" or re-derive anything. Where our engine cannot carry
   a thing as thirdjam has it, the engine gains the missing piece (say which); the game is not bent. Every deviation from
   thirdjam, however small, goes in a `DEVIATIONS` list in your report with its reason.
2. **Sources.** thirdjam's final submitted source (HEAD 8dc713c6, the game the owner knows):
   `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown/.tl/thirdjam` (read-only; `Game/Source` is "S" below).
   The older 15 Nov source tree that the runnable editor build was made from: `C:/t/t5` (read-only). The runnable build
   (UE 5.9 editor binaries + content, 4.5 GB): `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown/.tl/tj-run/Game`
   (read-only: run it in place with `-Multiprocess` and your own `-abslog=` and output folders, or copy it into your
   tree's `.tl/` if you must change it). UE 5.9 is at `C:/Program Files/Epic Games/UE_5.9`. How earlier lanes ran it:
   `docs/research/hockey-teardown/TEARDOWN.md` section 1 and `BEHAVIOUR-HAND.md` "How it was measured".
3. **Look, every round.** Before each standup line, put your own rendered frames beside the reference's frames of the
   same moment (same camera, same scene), LOOK at them yourself (read the image files), and write what your eye rejects.
   A defect you can see is not landable. Film is not the judge of play (the owner: "the pictures will not uncover core
   problem which is the gameplay itself in speed and balancing of skill mechanisms"); it is the judge of defects.
4. **Play is judged by play.** Where your lane touches how the game answers a hand, the proof is the same scripted hand
   through the same inputs in both games, compared frame by frame, never a number chosen by you.
5. **The machine is shared and tight** (about 15 GB of RAM free, other sessions run Godot). One Unreal process at a time
   per lane, closed as soon as it has done its job; never kill a process you did not start; Godot `--headless` unless you
   need a picture. Raw captures stay under your tree's `.tl/` and are deleted when their sheets exist.
6. **Module homes** (Director's ruling for this campaign; contracts follow at landing): the game core lives in
   `engine/cores/rink/` (a new engine module: a core may use the kernel API, kits, rigs and style; packs reach it through
   one kernel entry); the skater figure lives in `engine/rigs/skater/` with its imported mesh and clips beside it; the
   new game's pack is `engine/packs/hokej/` (thin: a cartridge and glue). The old `engine/packs/hockey` is not touched.
   If `tl arch`, the lint or the asset rules reject these homes, change the rule tables under `devx/` or
   `engine/kernel/runner/lint.gd` minimally, and list every such edit in your report (the Director words the contracts).
7. **Rounds.** Work in rounds of 60-90 minutes. At the end of each: standup line, your frames looked at, a short
   `ROUND-<n>.md` in your lane folder (what stands, what your eye rejects, deviations, next). When a round is worth
   landing, write "landable round n" in STANDUP.md, stop editing, and return your report as your final message; the
   Director lands it on the campaign branch `hokej` and sends you on.

---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-24-night/lanes/K1-core/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
  when the lane lands).
- Append one line at each milestone and at least every 60 minutes of work:
  `HH:MM | state: working|blocked|done|cut | did: <one line> | next: <one line> | gates: <last PASS/FAIL line or ->`
- `blocked` names the question in the same line. Then keep working on whatever the block does not touch.
- When you finish, write `REPORT.txt` beside it (the harness refuses agent writes to files named REPORT.md), return the
  full report as your final message too, and set the last standup line to `done`.

## Honesty
- Evidence or it is not done: a gate line, a test count, a still, a video, a repro before and after.
- A stopped run is never a pass. NOT RUN is not PASS. Fewer tests completed than on main is a stopped run.
- Unmeasured is not zero. Never fake a frame, a figure or a hash.
- A behaviour change that moves a test expectation is named, with why. Never loosen a test to make it pass.
- What the player sees or feels is judged as a person meets it (a window, the exported game), not only headless.

## Laws (CLAUDE.md)
- Work only in your worktree. No git that writes (read-only `git diff`/`git status` are fine). The Director lands.
- Never kill a process you did not start. Prefer `--headless`. Build the class cache once: `"$G" --headless --path engine --import`.
- Time is physics frames; determinism (same pack + seed + frames = same state_hash); unknown keys are errors; packs use only
  the TL* API and never declare class_name; kit, rigs, style reference nothing outside themselves.
- Contracts (`contracts/*`) are Director-only: put the question in your report.
- New selftest cases go in your own `engine/tools/selftest.d/NNN-<name>.sh` files, numbered inside the block range your brief
  assigns (two lanes once collided on 360).
- Raw captures (frame folders, long or uncompressed clips, mkv/avi) stay under `.tl/` in your worktree. The lane folder
  gets only sheets, notes, JPG stills and mp4 clips of 30 s or less.
- A kernel API addition updates `engine/kernel/API.md`; the Director regenerates docs on main (`tl arch --index`).
- Gates before `done`: `node devx/bin/tl.mjs check --tier fast`; when kernel, kits, rigs, style or seeds changed, also
  `node devx/bin/tl.mjs check --tier full` (perf alone if it says NOT RUN).

## REPORT.md
- Outcome against each acceptance criterion: met / not met, with its evidence.
- Gates with PASS/FAIL lines and counts.
- Changed files; behaviour changes; anything the owner should look at, and how.
- Questions for the Director; the next three things this lane would do.
