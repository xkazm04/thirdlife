# Rink core: what was changed to compile thirdjam outside Unreal

## Patches to thirdjam's files: none

Both copies are byte-for-byte thirdjam's own files (`diff -r` against the source trees is empty):

| Copy | Source | Files |
|---|---|---|
| `thirdjam/` | thirdjam HEAD 8dc713c6, `Game/Source/JamCore` (the game the owner knows; what ships here) | 40 (no JamPassFate: not in HEAD) |
| `thirdjam-t5/` | `C:/t/t5/Game/Source/JamCore` (15 Nov; the tree the runnable Unreal build was made from) | 42 |
| `content/Cartridges`, `content-t5/Cartridges` | each tree's `Game/Content/Cartridges` | 39 each |

The closure is JamCore's simulation, rules, zones, effects, cartridge loader, JSON reader, AI core, difficulty,
playtester, bot match, sim adapter and the tournament commandlet. Nothing under `JamGame` (rendering, pawns, UMG, input).

## Build settings that are Unreal's

- `/std:c++20` (UBT builds JamCore as C++20), `/fp:precise` (UE 5.9 VCToolChain.cs: Editor targets use FPSemantics Precise),
  MSVC 2022 x64, no FMA contraction (MSVC does not contract under /fp:precise).
- Defines: `JAMCORE_API=` (UBT's module export macro), `WITH_DEV_AUTOMATION_TESTS=0` (JamPlaytester.cpp's three tests are
  compiled out), `WITH_EDITOR=0`.

## The shim (`shim/`): Unreal types, with Unreal's semantics where they reach a number

Taken from UE 5.9's own headers: `FMath` Min/Max/Clamp/Abs/Lerp/Square, `UnwindRadians`/`UnwindDegrees` (with UE's float
constants `UE_PI`, `UE_TWO_PI`), `RoundToInt32`/`FloorToInt`/`CeilToInt` (the SSE times-two forms), `RoundToDouble`
(floor(x + 0.5)), `InvSqrt` (SSE `1/sqrt`), `Atan2(double)` (atan2 with UE's 0,0 guard), `Atan2(float)` (UE's minimax);
`FVector2D` as `TVector2<double>` (`operator/` multiplies by `1/s`, `GetSafeNormal` default tolerance `UE_SMALL_NUMBER`
as a float, `IsNearlyZero` `UE_KINDA_SMALL_NUMBER`); `FString`/`FName` equality ignoring case.

Evidence that this is enough: the t5 tree through this shim prints the Unreal build's TRACE lines exactly (611,543 of
611,543 lines, every frame, 10 seeds x 3 difficulties x 2 modes, including each match's final state hash), natively and
inside Godot (lane K1 ROUND-2.md).

### Shim deviations (not Unreal's behaviour; none reaches the simulation)

| # | What | Where it could matter | Why it does not here |
|---|---|---|---|
| 1 | `TArray::Sort` is `std::sort`, not UE's introsort | equal keys could land in another order | JamCore's two sorts use total orders (ties broken by index); the trace proof covers them |
| 2 | `TMap`/`TSet` find by linear search; iteration keeps UE's sparse-array order (holes refilled last-freed first) | speed only | only JamCartridge's schema table uses TMap |
| 3 | `GetTypeHash` is `std::hash`, not UE's CRC | hashing containers | nothing in JamCore hashes with it (StateHash is thirdjam's own FNV) |
| 4 | `FRegexPattern` is `std::wregex` (ECMAScript), not ICU | cartridge key/pattern validation messages | the patterns used are plain ECMAScript-compatible ones |
| 5 | `FName` keeps the casing it was made with; `operator<` compares strings | display, sorting by name | no JamCore code sorts FNames |
| 6 | `FString::Printf` is `_snwprintf_s` | log/text formatting | the TRACE and JSON lines are written by thirdjam's own `std::snprintf` |
| 7 | `NewObject` is a plain `new`; no garbage collector | lifetime | `TStrongObjectPtr` deletes; a cartridge lives as long as its RinkCore |
| 8 | `UE_LOG` goes to a host sink (stdout, or the lines `run_tournament` returns); `check` aborts | logging | - |
| 9 | `FColor` -> `FLinearColor` by the sRGB formula, not UE's table | cartridge look colours | presentation only, never read by the sim |
| 10 | `FPaths::ProjectContentDir` is set by the host (`set_content_dir`) | where `-cartridge=name` resolves | - |
| 11 | `TAutoConsoleVariable` holds its shipped default (no console) | jam.* switches read by the pawn helpers and tests | the defaults are the shipped game |
| 12 | `AJamSkater::CallFigure` dispatches by name without reflection, for `UJamFigureCallProbe` only (shim/pawn/pawn_helpers.cpp) | Jam.Core.Contact.FigureCalls | the probe's three reflected signatures are written out; the test's seven checks pass |
| 13 | `FString::ReplaceInline` returned 0 (round 3) / `TestEqual` on arrays recursed (round 3): fixed | tests only | the simulation calls neither |

## The pawn shim (round 4, thirdjam's own tests only)

thirdjam's contact and stick tests call five pure helpers of the pawn (`AJamSkater::HitStopFrames`, `HitStopFramesFor`,
`HitStopPick`, `StumbleFramesFor`, `BrakeDecelFor`, `SmoothAimDeg`) and its console variable `jam.hitstop`. The pawn itself is an
Unreal actor. `native/thirdjam/Private/JamPawns.cpp` and `Public/JamPawns.h` are copied verbatim (not compiled);
`native/tools/extract_pawn_helpers.py` copies those helpers' bodies out of it at build time, unchanged, with their line numbers,
into the test build; `shim/pawn/JamPawns.h` declares them (declarations copied from JamPawns.h with line numbers) with no actor
in it. Result: 36 of 36 contact tests and 2 of 2 stick tests PASS. The game build does not compile any of it.
