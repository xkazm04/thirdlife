# K1 rounds 2 and 3: the shim, the law, the proof (17:00-18:10)

## What stands

- **thirdjam's JamCore compiles unchanged.** `engine/cores/rink/native/thirdjam/` (HEAD 8dc713c6, 40 files) and
  `native/thirdjam-t5/` (15 Nov t5, 42 files) are byte-for-byte copies (checked with `cmp` against the source trees:
  0 differ). Patch list against thirdjam's files: **empty**. Everything Unreal lives in `native/shim/` (CoreMinimal.h,
  ShimString.h, ShimMath.h, ShimObject.h, shim.cpp, forwarding headers, empty `*.generated.h`); build defines
  `JAMCORE_API=`, `WITH_DEV_AUTOMATION_TESTS=0`; `/std:c++20 /fp:precise` as UBT builds an Editor target.
  `native/PATCHES.md` lists the shim's ten deviations from Unreal and why none reaches the simulation.
- **Proof of sameness (t5 source vs the Unreal build of t5).** thirdjam's own `UJamTournamentCommandlet::Main` runs
  outside Unreal. Flags `-cartridge=hockey.regular -seeds=1-10 -trace=1` (a TRACE line every frame) for each of
  rookie / pro / all_star, in two modes (`-mode=playerbot`, and the playtester `-player=regular -playersprint`):

  | run | Unreal lines | native (rinkcli) | inside Godot (RinkCore.run_tournament) |
  |---|---|---|---|
  | playerbot rookie | 131,831 | identical | identical |
  | playerbot pro | 117,753 | identical | identical |
  | playerbot all_star | 121,527 | identical | identical |
  | playtester rookie | 60,484 | identical | identical |
  | playtester pro | 104,857 | identical | identical |
  | playtester all_star | 75,091 | identical | identical |

  611,543 of 611,543 lines equal, both ways, including each match's closing JSON line with its final state hash. Not a
  single floating-point difference; there is no first differing frame to report. The 60 closing lines are in
  `ue-t5-reference.jsonl`.
- **HEAD baseline.** The same 60 matches on HEAD's source: `head-baseline.jsonl` (588,119 trace lines, raw under
  `.tl/head/`). HEAD departs from t5 at frame 101-133 in every run (right after the opening draw): the 78 files that
  differ between the trees change the game, as expected. HEAD has no Unreal build here to compare against; its
  sameness rests on t5's bit-exact proof through the same shim and on HEAD compiling with zero edits.
- **RinkCore** (GDExtension, `engine/cores/rink/rink_core.gdextension`, class `RinkCore : RefCounted`):
  load_cartridge / load_cartridge_file / set_difficulty / set_human_mode / reset / set_human_input / step / snapshot /
  state_hash / run_tournament. One step is JamBotMatch RunMatch's frame (FJamSimAdapter with the game mode's systems,
  FJamBrain with the resolved difficulty); the human's slot takes `set_human_input` (FJamInput by thirdjam's names).
  `SNAPSHOT.md` v1 (draft v0 out at 17:02, built at 17:41) lists every field with its JamSim.h line; the snapshot code
  is generated from the same list.
- **Smoke** (`selftest.d/800-rink-core.sh`, 3 of 3 PASS): bots-only regular 5 v 5 (HEAD), 3,600 frames with a full
  snapshot every frame in 1.2-1.8 s, score 1:1, the same hash `e9e795069734352c` twice; HEAD trace inside Godot equals
  `proof/head.*.txt`; t5 CLI equals the Unreal build's own lines (`proof/ue-t5.*.txt`).
- **Exported exe**: a minimal exported project (release template, release DLL) runs the same 3,600 frames and ends on
  the same hash `e9e795069734352c` (debug in the editor = release in the export). The full ThirdLife export was not run.
- **One command**: `bash engine/tools/rink.sh build all` fetches godot-cpp at the pinned commit 7fd5c4bc, dumps the
  API from the Godot `tl doctor` finds, builds HEAD debug + release and the t5 proof, and seeds the extension list.

## What my eye rejects

Nothing to look at: this lane has no picture (the core draws nothing; K2/K3 draw). Rule 3 frames start when K3's shell
renders the snapshot.

## Found on the way (engine)

- **Godot 4.7.2 segfaults at exit (exit 139) when a filesystem scan discovers a GDExtension for the first time**, after
  the import completed and saved. Any extension does it (a hello world built against godot-cpp master or 4.5-stable).
  Listing the extension in `.godot/extension_list.cfg` before the first import avoids it; `rink.sh build` writes that
  line. A checkout that has never built will see one crashing `--import` (the second is clean).

## Deviations from thirdjam

1. Godot single-precision `Vector2` in the snapshot (the sim stays double; the hash is taken from the doubles).
2. The human's edge buttons are cleared after the step that consumed them (thirdjam's game mode re-reads keys every
   frame; same effect).
3. The core does not port AHokejGameMode's presentation-side extras (goalie stance sends, hit-stop, JAMSHOT logs,
   signals/intents from the HUD): they are JamGame, lane K3's.

## Next

Round 4: the kernel entry a pack uses to reach the core (and its API.md lines), `_pack_state` fed from the snapshot
with a two-runs-same-hash test through the runner, the binary policy decided by the Director, then thirdjam's own
`Jam.Core.*` / `Jam.Bot.*` automation tests compiled against the shim.
