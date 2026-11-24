# K1 core: round 5 (24 Nov 20:51-21:20; paused by the owner at 23:10 on 23 Nov, resumed 20:51)

## 1. The D3D12 export guard
`engine/tools/export.sh` `need_tools()`: one line refuses an export (exit 1) when `engine/project.godot` no longer keeps
`rendering_device/driver.windows="d3d12"`, with the reason (round 4: a windowed quit crashed 5 of 10 times on Vulkan, 0 of 10 on
D3D12). `bash -n` clean; project.godot line 37 matches. A full export was not run this round.

## 2. The snapshot's Controls fields (for K5)
`engine/cores/rink/tools/rink_controls.gd`, selftest `rink.controls`. A whole match played by thirdjam's playtester (pro,
regular + sprint) and, on every frame, the fields against their rules recomputed from the snapshot:
- `ButtonsWithPuck` = thirdjam's rule (InputMapping.cpp:432-442: he carries, or the puck is loose and last touched by his team);
- `ButtonsCarrying` = (Carrier == the human);
- `ButtonsInReach` true whenever the puck is within 1.5 m of his body (CarrierReachM is at least 1.65 m). It is NOT true on every
  carried frame: a puck held on the blade beyond the body's reach is carried (CarrierIndex's second clause), my first draft of
  the check assumed otherwise and failed on it; thirdjam's rule is the one kept;
- `PassTarget` / `SaucerTarget`: -1 or a teammate, never himself or an opponent;
- `TakeOwner` in range and equal to a carrier who has held the puck 30 frames on at least 95 % of those frames (seed 1: 3,619 of 3,619; seed 2: 6,069 of 6,081);
- `CarrierInTakeGrace` never true with no carrier;
- every interesting case must occur (a stuck field fails): seed 1, 12,206 frames: 2,079 carrying, 1,617 our puck loose,
  8,510 without, pass target on 6,938, in reach 2,939. Seed 2 also PASS (16,903 frames).

## 3. The thirdlife variant, selected by cartridge
Design: two cores, one source. `RinkCore` (rink_core.dll) stays thirdjam byte for byte; `RinkCoreThirdlife`
(rink_core_thirdlife.dll) is the same binding compiled from a COPY of thirdjam with `native/patches-thirdlife/*.patch` applied.
Why two and not one patched core: the regular cartridge's hashes are then unchanged by construction (its library has no patched
line in it), and a future patch can never reach hockey.regular; the price is a second 1.5 MB library. K8 proposed one core; the
round's brief allowed either; K8's ask (re-run the trace compare on the patched tree, switches off) is done below and passes, so
going to one core later is a one-line change in TLCores.KNOWN if the Director prefers it.
- `native/tools/thirdlife_tree.py`: copies native/thirdjam to `.tl/rink-thirdlife-core/thirdjam`, applies every patch in name
  order with `patch -p1`; a patch that does not apply fails the build (nothing half-patched is built); a stamp of the hashes
  keeps the copy until thirdjam or a patch changes.
- `native/SConstruct` `tree=thirdlife` (option `patches=<dir>`): builds from that copy with `RINK_THIRDLIFE`.
- `native/src/rink_core.cpp`: one source; under `RINK_THIRDLIFE` the class registers as `RinkCoreThirdlife` with entry
  `rink_core_thirdlife_init` (GDCLASS stringifies its argument, so one macro level expands the name first: without it both
  libraries registered "RinkCore" and the second was refused). New methods in both: `load_rules(json)`, `rules_applied()`.
  The plain core refuses any rule. `reset` applies the sidecar's level tune (thirdjam's ApplyDifficultyTune) on top of the
  resolved profile.
- `native/glue/rink_rules.{h,cpp}`: the sidecar reader, K8's lab reader (lab/lab_rules.cpp) key for key, minus the lab's
  command-line overrides; also requires "schema".
- `engine/kernel/api/tl_cores.gd` (1.29): `open(id, cartridge)` opens the variant when `data/<name>.rules.json` lies beside
  `data/<name>.cartridge.json`, hands it the rules after the cartridge; errors name the class and the build command.
- `engine/tools/rink.sh build thirdlife [target]` (env `TL_RINK_PATCHES` = another patch folder): writes
  `engine/cores/rink/rink_core_thirdlife.gdextension` after its library (a .gdextension without its library errors on every
  start) and seeds `.godot/extension_list.cfg`; `build all` builds it (debug + release) when the patches are there, else prints
  NOT BUILT and goes on.
- Proof, switches off = thirdjam (built with K8's two patches, byte-identical to the ones landed in hokej 23bfe62):
  thirdjam's tournament, 10 seeds x rookie/pro/all_star x playerbot/playtester regular+sprint, a TRACE line every frame:
  588,119 of 588,119 lines identical between the plain and the patched CLI (pb rookie 89,081, pt rookie 61,252, pb pro 131,391,
  pt pro 105,364, pb all_star 104,935, pt all_star 96,096), and the 60 closing hashes equal head-baseline.jsonl (round 2).
  No first differing frame. (HEAD has no Unreal build: its Unreal sameness rests on t5's 611,543-line proof through the same
  shim; the patched tree equals HEAD to the line.)
- Inside Godot (`tools/rink_variant.gd`, selftest `rink.variant`): seed 1 pro, the regular playtester: RinkCore and
  RinkCoreThirdlife with `net_carry_wall` false hash the same on all 8,187 frames (last 5707a1b65346fc6d, 3:1); with it on the
  match ends 3:2 at frame 7,025 and differs from frame 1 (the patch hashes `TlHeldBy` while its switch is on: expected).
  K8's own files loaded as they are (hockey.thirdlife.cartridge.json + .rules.json): loads, `net_carry_wall=1`, 7,025 frames,
  3:2, hash afa526fbec2e1016. Refusals: the plain core refuses a rule; an unknown rule and an unknown key are errors.
  TLCores.open: no sidecar -> RinkCore; sidecar -> RinkCoreThirdlife with the rule set.
- In THIS tree native/patches-thirdlife does not exist (it is K8's, landed in hokej after f9d2db9), so the variant's library and
  .gdextension are NOT in the tree: `rink.variant` checks the plain-only case here (the plain core refuses a rule, nothing
  registers the variant) and the full case once the patches are present. The test build is kept under .tl/thirdlife-build.

## 4. Jam.Controls extracted (our test file, the game unchanged)
`native/tests/tl_controls_tests.cpp`: ten of thirdjam's JamGame button-rule tests re-typed against our port
(native/glue/rink_gamemode.*), each citing its ControlsTests.cpp lines, compiled into rinktest (`rink.sh tests TL.Controls`):
Defaults (57-81), ByPossession (83-134), PressOutlivesPossession (136-226), RecordedStreamUnchanged (228-263), AimAnchor
(491-540), HeldCrossCheck (542-587), HeldAcrossChange (756-822, both rules), HeldAcrossChangeInTheSim (824-874), TapAgainstHold
(876-951), ChargeDiesOnLoss (1220-1313). 10 of 10 PASS. The in-sim tests go through the port's real input path
(FHumanControls::Read, keeping only the button fields as ApplyButtons does).
Not here (named at each test): the Enhanced Input slots and IsKeyMapped; OurPuckShoots 0; main's rule arm in the sim
(HeldAcrossChange 0) and BraceHoldFrames 0 (the port ships the cvars' values fixed); CursorAimFromRay/Hit; JamBaseline;
the rebinding (the stream test replays the same verbs twice).
Mutation check: with two glue rules broken (a dead shot/pass never dies; the saucer delay ignores the 13-frame hold) three tests
fail (PressOutlivesPossession, HeldAcrossChange 8 errors, HeldAcrossChangeInTheSim 1 vs 0). The saucer-delay mutation alone is
not seen: hockey.regular has game.pass.power on, so the saucer delay is 0 in thirdjam and in the port alike (the added
ButtonContext assertions confirm the port's delays equal thirdjam's formula for this cartridge).
Glue additions for the tests (ports of thirdjam's own): FButtonResolver::Step(bool) (InputMapping.cpp:341-346), ActiveVerb
(335-339), FAimAnchor::IsAnchored (InputMapping.h:161). Play is unchanged (the selftests below hash as before).
New: `engine/tools/rink.sh tests [filters]` builds rinktest (VisualSwapTests skipped: Unreal classes) and runs it.
