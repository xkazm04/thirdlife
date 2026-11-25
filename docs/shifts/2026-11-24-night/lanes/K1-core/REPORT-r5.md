K1 core: report for landable round 5
Lane K1 "core". Worktree .claude/worktrees/hk-core (branch hk-core, at f9d2db9, nothing committed by me). 20:51-21:20.
Details: ROUND-5.md beside this file.

DONE (the Director's order)
1. D3D12 guard: engine/tools/export.sh need_tools() refuses an export when engine/project.godot no longer keeps
   rendering_device/driver.windows="d3d12" (one line + one comment). bash -n clean. A full export was NOT run.
2. Controls fields selftest: rink.controls PASS. A whole match (thirdjam's playtester, seed 1, 12,206 frames; seed 2 also
   16,903): ButtonsWithPuck equals thirdjam's rule (InputMapping.cpp:432-442) on every frame, ButtonsCarrying = carrier, in reach
   whenever the puck is within 1.5 m of his body, Pass/SaucerTarget always -1 or a teammate, TakeOwner = a settled carrier,
   no take grace without a carrier; each case seen (2,079 carrying, 1,617 our loose puck, 8,510 without). For K5: ButtonsInReach
   can be false while he carries (a puck on the blade beyond the body's reach is carried in thirdjam): don't treat it as "carrying".
3. Thirdlife variant by cartridge: TWO cores, one source. RinkCore stays thirdjam byte for byte; RinkCoreThirdlife
   (rink_core_thirdlife.dll) is built from a copy of thirdjam + native/patches-thirdlife. ctx.cores.open("rink",
   "<name>.cartridge.json") opens the variant when data/<name>.rules.json lies beside it and loads the rules (TlSetRule per
   key, unknown = error; "levels" through ApplyDifficultyTune at reset); no sidecar = RinkCore as before.
   K8's ask done: the patched tree with switches off prints 588,119 of 588,119 TRACE lines identical to the plain build over the
   60 tournament matches, and the 60 closing hashes equal head-baseline.jsonl. Inside Godot: 8,187 of 8,187 frames equal
   (switch off); switch on plays 3:2 and differs from frame 1 (the patch hashes its own state then: expected).
   K8's real files load (net_carry_wall=1, 7,025 frames, 3:2, afa526fbec2e1016).
   Why two cores and not K8's one: regular's hashes cannot move by construction; going to one core later is one line in
   TLCores.KNOWN. Director's call.
4. Jam.Controls extracted: native/tests/tl_controls_tests.cpp, 10 of thirdjam's JamGame button-rule tests re-typed against our
   glue, each citing its ControlsTests.cpp lines: 10/10 PASS (rink.sh tests TL.Controls). Mutating two glue rules fails 3 of
   them. What could not be kept is named at each test (Enhanced Input slots, cvar-off arms the port ships fixed, CursorAimFromRay,
   JamBaseline, rebinding).

GATES
- tl check --tier fast: 5 of 5 PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck).
- selftest rink.: 17 passed, 1 failed. All 11 of mine PASS (smoke e9e795069734352c unchanged, trace_head 51/51, trace_t5 21/21
  = Unreal's, entry_twice, entry_replay, window, rawhand, rawtrace 600/600, playtester_seat, controls, variant [plain-only here]).
  FAIL rink.view.hits (K2's hitread.core1800: got af496e74ecbfdcba, want 3ba801e4fee31b2b): NOT mine. Same result with HEAD's
  committed DLL swapped in (A/B run), so it is in the tree at f9d2db9 already.
- rink.sh build all: thirdjam debug + release, t5 debug PASS; thirdlife NOT BUILT here (no patches in this tree).
- rink.sh tests TL.Controls: 10 of 10.
- Not run: tl check --tier full; an export; selftests 801/802 (untouched this round).

FILES (all uncommitted in hk-core)
 modified: engine/tools/export.sh, engine/tools/rink.sh (build: thirdlife tree + .gdextension + extension_list; build all;
   new "tests" case), engine/tools/selftest.d/800-rink-core.sh (rink.controls, rink.variant), engine/kernel/api/tl_cores.gd,
   engine/kernel/API.md (section 24 bullet, "Addition in 1.29"), engine/cores/rink/SNAPSHOT.md (two cores section),
   engine/cores/rink/native/SConstruct, native/src/rink_core.cpp, native/glue/rink_gamemode.h, engine/cores/rink/bin/.gitignore,
   bin/rink_core.windows.template_{debug,release}.x86_64.dll (rebuilt: the binding gained load_rules / rules_applied)
 new: native/glue/rink_rules.{h,cpp}, native/tools/thirdlife_tree.py, native/tests/tl_controls_tests.cpp,
   engine/cores/rink/tools/rink_controls.gd(+.uid), rink_variant.gd(+.uid), lane ROUND-5.md, this REPORT.txt, a STANDUP line.

KERNEL LINES: 1.29 (TLCores.open picks the variant by a rules sidecar; load_rules / rules_applied). API.md has an appended
bullet only; version lines and docs/generated untouched (regenerate at the merge).

FOR THE DIRECTOR (landing)
- Clean point: yes, after this report. Fast-forwarding onto hokej 23bfe62: rink.sh overlaps K8's hunk at the gdtrace line
  (~line 95). K8's version turned the literal carriage return in `tr -d '<CR>'` into a line break (a Python rewrite with
  newline translation; I made the same mistake and put the base line back). Take the BASE line there (a literal CR inside the
  quotes), not K8's, or gdtrace prints nothing useful. My other rink.sh hunks (build, tests) do not touch K8's blocks.
- After the merge (native/patches-thirdlife present): run `bash engine/tools/rink.sh build all` (builds thirdlife debug +
  release, writes engine/cores/rink/rink_core_thirdlife.gdextension) and commit rink_core_thirdlife.*.dll + the .gdextension;
  then `selftest rink.variant` runs its full case (it FAILS if the patches are there and the library is not: on purpose).
- For K3 (to play hockey.thirdlife in the exe): copy hockey.thirdlife.cartridge.json AND hockey.thirdlife.rules.json into the
  pack's data/ and open "hockey.thirdlife.cartridge.json": nothing else changes in the pack. A replay of a thirdlife match must be
  checked against thirdlife hashes. The export of the variant's .gdextension was not tried (no export run this round).

QUESTIONS
1. One core or two (above)? I built two; one is a one-line switch once you want it.
2. Should the rules sidecar's schema (tl.rink.rules/1) get contract wording? Contracts are yours (K8 asks the same).

DEVIATIONS
1. glue gained three ports of thirdjam's own accessors for the tests (Step(bool), ActiveVerb, IsAnchored); play unchanged.
2. The sidecar reader requires "schema" (K8's lab reader did not); it drops the lab's -tl/-tune overrides.
3. TL.Controls tests skip what needs Unreal or a cvar arm the port ships fixed (listed at each test and in ROUND-5.md).
4. thirdjam's files: untouched (the patches apply to a copy under .tl/).
