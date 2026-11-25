K1 core: report for landable round 2 (rounds 1-3 of the brief done; round 4 partly)
Lane K1 "core", hockey campaign night 23-24 Nov 2026. Worktree .claude/worktrees/hk-core (branch hk-core). 16:51-18:10.

HEADLINE
thirdjam's actual C++ (JamCore: sim, rules, zones, effects, cartridge loader, AI core, difficulty, playtester, bot match,
sim adapter, tournament commandlet) compiles UNCHANGED into a Godot 4.7.2 GDExtension behind a thin Unreal shim. Through it,
thirdjam's own tournament prints the Unreal build's TRACE lines exactly: 611,543 of 611,543 lines, every frame, 10 seeds x
rookie/pro/all_star x {playerbot, playtester regular+sprint}, natively and inside Godot. No floating-point difference at all.

ACCEPTANCE (rounds 1-4 of the brief)
1. Extension builds from a clean tree by one command, loads headless and in an exported exe: MET (with one caveat).
   - `bash engine/tools/rink.sh build all`: fresh godot-cpp clone at pinned 7fd5c4bc, API dumped from the Godot tl doctor
     finds, HEAD debug + release + the t5 proof build: PASS x3 in 6 m 7 s (.tl/build-clean.log).
   - Headless: selftest rink.smoke PASS. Exported exe: a minimal exported project (release template + release DLL) runs
     3,600 bots-only frames and ends on hash e9e795069734352c, the same as the debug DLL in the editor project.
   - Caveat: the full ThirdLife export (engine/tools/export.sh) was NOT run.
2. Traces equal the Unreal build's for the t5 source: MET. Table in ROUND-2.md; the 60 closing JSON lines (with each
   match's final state hash) in ue-t5-reference.jsonl. HEAD baseline recorded (head-baseline.jsonl); HEAD departs from
   t5 at frames 101-133 (a game change between the trees, not floating point). HEAD has no Unreal build to check against.
3. SNAPSHOT.md names every field with its thirdjam source line; a GDScript smoke steps a regular 5 v 5 for 3,600 frames
   with bots only and prints the score: MET. SNAPSHOT draft v0 out at 17:02 (first hour of round 2), v1 (built) now:
   15 FJamInput, 154 FJamSkaterState, 19 FJamPuckState, 9 FJamSimEvent fields with HEAD JamSim.h lines.
   Smoke: score 1:1, 2 goal events, hash e9e795069734352c twice, 1.2-1.8 s for 3,600 frames incl. a full snapshot each frame.
4. Patch list against thirdjam's files is short and mechanical: MET, it is EMPTY (cmp against both source trees:
   0 of 40 / 0 of 42 differ). The shim's own deviations from Unreal: native/PATCHES.md (10 rows, none reaches the sim).
5. `tl check --tier fast` passes: MET, 5 of 5 PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229,
   foreman.typecheck clean; `npm ci` was run in the worktree's foreman/ so the last step could run). No rule-table edits.
Round 4 NOT done: the kernel entry for packs (and its API.md lines) and `_pack_state` fed from the snapshot through the
runner. The core's state_hash() and a same-seed-twice test exist (rink.smoke); the pack-side wiring waits for the entry.

GATES
- tl check --tier fast: PASS arch [12/12], assets [4/4], cards [3/3], devx.test [229/229], foreman.typecheck.
- selftest rink.: 3 passed, 0 failed (rink.smoke, rink.trace_head 51/51, rink.trace_t5 21/21 = Unreal's).
- tl check --tier full --only packs (the extension loads in every engine run now): FAIL [2/3], 128 of 129 verb runs;
  duel and parkour green; hockey invariants.many_budget: frame p50 1.120 ms vs budget 1.0 ms (wall clock). NOT this lane's:
  A/B on the same tree, hockey invariants alone, alternating: with the extension 1.091 / 1.122 ms, without it (.gdextension
  renamed, extension list emptied) 1.106 / 1.132 ms: the same failure either way. The machine was loaded (another
  session's gtai gate ran look_golden at the time). Worth re-running on main when the machine is quiet.
- Full tier not run: no kernel, kits, rigs, style or seeds changed.

CHANGED FILES (all new; nothing existing edited)
- engine/cores/rink/: rink_core.gdextension, SNAPSHOT.md, proof/ (two small trace baselines), tools/rink_smoke.gd,
  tools/rink_trace.gd, bin/ (.gitignore + rink_core debug/release DLL + rinkcli-thirdjam-t5.exe, see question 1).
- engine/cores/rink/native/: SConstruct, PATCHES.md, shim/ (the Unreal shim), src/rink_core.cpp (the Godot class),
  cli/rinkcli.cpp (the commandlet outside Unreal), tools/gen_fields.py (+ fields.gen.md), .gdignore, .gitignore,
  thirdjam/ + thirdjam-t5/ (verbatim copies), content/ + content-t5/ (verbatim Cartridges).
- engine/tools/rink.sh (build | trace | gdtrace | ue | compare), engine/tools/selftest.d/800-rink-core.sh.
- docs/shifts/2026-11-24-night/lanes/K1-core/: STANDUP.md, ROUND-1.md, ROUND-2.md, REPORT.txt, head-baseline.jsonl,
  ue-t5-reference.jsonl.
- Local only (.tl/, gitignored): godot-cpp clone, objects, raw traces (ue/ native/ gd/ head/, about 600 MB; deletable).

BEHAVIOUR / ENGINE FINDINGS
- Godot 4.7.2 segfaults at exit (139) when a filesystem scan discovers a GDExtension for the first time, after the import
  completed. Any extension (a hello world, godot-cpp master or 4.5-stable). Avoided by listing it in
  .godot/extension_list.cfg before the first import; rink.sh build writes the line. LANDING NOTE: every checkout that
  gets this branch should run `bash engine/tools/rink.sh build` once, or append `res://cores/rink/rink_core.gdextension`
  to engine/.godot/extension_list.cfg; otherwise its first `--import` exits 139 (the second is clean).
- With the .gdextension in engine/, every Godot run of the engine project loads the DLL (1.5 MB, registers one class).
- Nothing for the owner to look at yet: the core draws nothing.

DEVIATIONS from thirdjam
1. Snapshot vectors are Godot single-precision Vector2 (the sim and its hash stay double).
2. The human's edge buttons are cleared after the step that used them (the game mode re-reads keys every frame).
3. AHokejGameMode's presentation extras (goalie-stance sends, hit-stop, HUD intents, JAM* log lines) are not in the core
   (JamGame: lane K3).

QUESTIONS FOR THE DIRECTOR
1. Binaries: commit rink_core.windows.template_debug/_release.x86_64.dll (1.5 MB each) and rinkcli-thirdjam-t5.exe
   (1.3 MB)? My advice: yes, so a clean checkout plays, exports and passes selftest 800 without a 6-minute toolchain
   build (MSVC + SCons + network); the source and the one command reproduce them. If not, selftest 800 FAILs on a
   checkout that has not built (it names the command; it never passes silently).
2. The thirdjam copies: keep both (HEAD = the game, t5 = the proof against the only Unreal build we have), or drop t5
   after landing and keep only the proof files? Its value: any later shim change is re-proved against Unreal.
3. Contracts: a new engine module home engine/cores/ (campaign rule 6) passed tl arch with no rule edit; the contract
   wording for cores, the kernel entry name, and whether a pack's _pack_state carries the core's hash are yours.
4. HEAD's sameness is inferred (zero edits + t5 bit-exact). A direct proof needs an Unreal build of HEAD's JamCore
   (UE 5.9 is installed; one editor-module build, Unreal-heavy). Worth a lane slot?

NEXT THREE
1. The kernel entry (smallest: one static that returns a RinkCore and reports a missing build), its API.md lines, and
   `_pack_state` = the core's hash, with a two-runs-same-hash test through the runner (round 4).
2. thirdjam's own Jam.Core.* and Jam.Bot.* automation tests compiled against the shim (a tiny FAutomationTestBase), so
   the reference's own tests run in our gate.
3. A scripted-hand input test: the same FJamInput sequence through RinkCore and through the Unreal playtester path,
   compared frame by frame (direction 4: play judged by play), for K3's input mapping to build on.
