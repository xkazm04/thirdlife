# Third Life: feasibility spike plan

Companion to `FEASIBILITY.md`. Thresholds marked *(proposal)* are the Director's, to be replaced by measured values after the first run.

## The claims the spike must confirm or kill

| Claim | Test | Phase |
|---|---|---|
| C1 A look that is good AND authorable by an LLM at game scale exists | art lane B on the look-test scene (lane C voxel deferred to a nightly spike) | A (running) |
| C2 A sentence becomes a playable, machine-verified game without human code | hockey end to end | 1 |
| C3 The kernel is composable: a second, different game needs no kernel change | racing on the frozen kernel | 2 |
| C4 Construction can be shown truthfully and steered by the player | site driven by the real job log, milestone comments re-plan | 3 |
| C5 Cost and time are tolerable and predictable | job log metrics across 1-3 | 1-3 |

## Phase A: art lane B (four passes done and verified on 2026-11-10; **accepted by the owner at Gate A**)

One builder at a time in `spike/lab/b` against the scene contract `spike/lab/SCENE.md`.
- **B** (inked low-poly + painterly atmosphere): the direction chased. Four builder passes on 2026-11-10, about 3 h 45 min of builder time, each
  re-run and checked by the Director. Reports: `spike/lab/b/REPORT.md`, `REPORT-PASS2.md`, `REPORT-PASS3.md`, `REPORT-PASS4.md`.
  Result: all rubric items at 4 of 5, consistency 5; 5,081 lines of GDScript that build the scene at load time, no Blender, no hand-made
  asset; 261 draw calls and under 2 ms of GPU time at 1440p on an RTX 4090; four layouts from one kit; a written layout contract
  (`spike/lab/b/LAYOUT.md`) and a validator (`tools/g.sh validate`).
- **C** (voxel): **deferred by the operator on 2026-11-10** after seeing its early state, probably to a later nightly spike. Its builder was stopped
  about 30 minutes in, at the planning/pipeline stage: no report, no measurements, so the Director's concerns about voxel are still **untested**, neither
  confirmed nor refuted. `spike/lab/c/` and `BRIEF-C.md` stay on disk as the resume point (`JOURNAL.md`, `LEDGER.md`).
- **Gate A** (operator + Director): accept lane B as the art direction, ask for a second pass, or fall back to another direction from the r1 gallery.
  Inputs: lane B's REPORT.md, captures, authoring ledger and perf table, verified by the Director running `tools/g.sh` itself.
  **Ruled 2026-11-10: "Keep lane B".** Lane B is the art direction.

### What Phase A changes in the phases below (**approved by the owner on 2026-11-10**)

Lane B tested, by accident and then on purpose, the thing Phases 1-3 depend on: whether a builder can describe a new place as data.

1. **Data first, kit code as the escape hatch.** A layout file written with the code frozen expressed what goes where and what is absent, and
   failed for every new quantity or new kind of thing (three houses, two rinks, a lake, a watch tower, a kart). Each gap cost 1 to 90 lines.
   A new kit part (the watch tower) took 36 lines and worked on the first run. So the pack contract should make data the default and let a
   builder add kit parts inside the fence, and the bypass count in C2 should count kit parts added per pack as its own figure.
2. **Lists, not singletons.** The first schema had one arena, one house, one wall length. WP1's pack manifest must take lists for every venue
   part from the start (`arenas[]`, `houses[]`, `circuits[]`).
3. **A validator is necessary and not sufficient.** It caught every planted schema fault with a readable message. It cannot see placement
   faults: a light mast in front of the camera, the subject outside the frame. WP3's verifier needs a look-at-the-capture step (V-level to be
   named in `docs/FEASIBILITY.md`) in addition to schema and play-test checks.
4. **Unknown keys are errors.** A silently ignored key was the commonest way a layout under-delivered without failing.
5. **Timing-based checks flake under GPU contention.** One timed capture and one play-test run misfired once each while another GPU job ran,
   and passed on repeat. WP1's headless runner should step on physics frames, not wall time, and the verifier should treat one retry as
   normal and record it.
6. **Builder mechanics.** A builder's second pass ran out of context; each pass after that went to a fresh builder given a reading order, and
   that worked. Builders cannot write report files; the Director saves the returned text. WP3's job log should assume both.

## Phase 0: kernel skeleton and harness (**go given by the owner on 2026-11-10**; WP1-3 dispatched 18:55 CEST)

Contracts written by the Director before the fan-out: `contracts/README.md` (ownership and global rules), `PACK.md` + `pack.schema.json`,
`RUNNER.md` (engine verbs and the `tl.verify/1` report), `JOB.md` (the `tl.job/1` log), `KIT-RIG-STYLE.md`. Briefs: `briefs/BRIEF-WP1-KERNEL.md`,
`BRIEF-WP2-KIT.md`, `BRIEF-WP3-FOREMAN.md`. One deviation from the table below: **WP2 builds in its own Godot project `kitlab/`** (same `res://kits`,
`res://rigs`, `res://style` paths) so two builders never share a `.godot` cache; WP4 moves those three directories into `engine/` as its first step.
The go covers Phase 0 only (WP1-4). Phases 1-3 (hockey, racing, live site) are not started without a further word from the owner.
Commits and the `kernel-v0.1` tag wait for the owner's explicit instruction (nothing is committed yet).

**Phase 0 finished on 2026-11-10 22:15 CEST.** WP1 to WP5 and three Foreman passes are built and verified by the Director; reports
in `docs/reports/`. Two real jobs (a marble run from one sentence, Claude CLI builders, no human code) ended `done` in about 15 minutes
each. Job 1 ran on an engine copy without kit, style or seeds and gave a grey-box whose art package changed no pixel. Job 2 ran on the
full engine with the seeds and kit documents as reference: a third of the root package's time, 1 kernel bypass against 7, the shared
look, and the critic's extra round, deviation notes and a builder question all running live (`docs/reports/JOB2-MARBLE.md`).
Against the acceptance column below: every item holds except the `kernel-v0.1` tag, which waits for the owner (nothing is committed).
Never seen live: a verifier failure, a re-plan, a builder timeout. Never done: real keys, the HUD by eye, sound by ear.

**Carried into Phase 1 as its first work** (each is a finding of job 2, not a wish): a change request that re-opens the package that
owns a problem; a critic that names the package at fault; a kit-use figure that cannot fall silently in a later round; capture moments
declared by the pack; the Foreman reading the runner's options from the engine; a rule for wall-clock gates on a loaded machine.

Project `third-life/engine/` (Godot) + `third-life/foreman/` (Node/TypeScript). Work packages, each one builder session, contracts first:

| WP | Owns | Acceptance (checkable) |
|---|---|---|
| WP1 Kernel + host | `engine/kernel/**`: material/law tables, surface rules, contact/damage/fracture, controllers (biped, vehicle, puck/ball), rules state machines, camera rigs, VFX/audio presets, the typed API, pack loader, watchdog, headless runner with structured logs | loads a pack from a manifest; runs 60 s headless deterministic (same seed, same state hash); API lint rejects OS/network/world-write calls; Jolt material properties come from the tables |
| WP2 Rigs + kit + style | `engine/kits/**`, `engine/rigs/**`, `engine/style/**`: biped and vehicle and bot rigs with a clip library and IK layers; kit parts and generators from the winning art lane; `style.json` | biped plays idle/walk/run/skate/shoot clips; vehicle rig steers and suspends; a kit part regenerates from script identically; style swap changes whole look |
| WP3 Foreman | `foreman/**`: Designer/Planner/Builder-adapter/Verifier/Promoter, job DAG, resumable job log (JSONL), budget policy, CLI adapter first and API adapter second | a job killed mid-run resumes without redoing completed packages; the verifier rejects a package that claims done but fails V2; per-job wall time, tokens, rounds and failure cause recorded; adapters implement `probe()`/`run()` with separate `generate`/`readonly-scan`/`edit` modes, explicit `timeoutMs` (a truncated answer is typed, not "failed"), a dated capability matrix, and the billing in force (subscription vs API key in the environment) is shown before a job starts |
| WP4 Seed packs | `engine/seeds/**`: 3 disjoint seed games (ball-and-paddle, drive-around vehicle sandbox, destructible wall) as examples + their bots | each runs headless, passes its own bot; tagged `kernel-v0.1` with the seeds |

WP1 and WP2 share no files; WP3 depends only on the **pack contract** (manifest, job and verifier report schemas), which the Director commits as stubs before the fan-out.
WP4 depends on WP1+WP2.

## Phase 1: hockey (S1)

Player sentence -> Designer produces a brief and an estimate -> player approves -> Planner cuts a DAG (arena kit assembly, rink laws, skaters + AI, puck, rules, controls, HUD, audio cues,
art pass, tuning) -> builders -> Verifier -> Promoter. Acceptance: V0-V4 green: a headless bot match runs to full time with consistent scoring and determinism; V5 captures pass the rubric; a human can play
it with keyboard (`WASD` + shoot). **No human wrote game code.** Record: wall time, tokens, rounds, failure causes per package, lines of pack GDScript, bypassed kernel primitives.
Kernel-gap tickets may be raised and fixed here; after hockey the kernel is tagged `kernel-v0.2`.

## Phase 2: racing (S2)

Same flow, new sentence ("a night street circuit with nitro and destructible walls"). **Acceptance: `git diff kernel-v0.2 -- engine/kernel` is empty.** Because script freedom is wide, the report must also give
bypass count and pack GDScript size; a clean diff with a large bypass count is a *partial* result. If racing needs a kernel change, the report lists each gap as data: that is a valid, valuable outcome and sizes the kernel.

## Phase 3: live construction site (S4)

The world renders the Foreman's job log: builder bots at stations per package, blueprint holograms for unbuilt parts transitioning to built on real package completion, milestone boards with captures.
Player comment on a milestone re-plans only affected packages (the planner emits a diff of the DAG). Acceptance: kill and restart the Foreman mid-build: the site resumes truthfully; a comment on the hockey
"art pass" milestone changes only the dependent packages and the change is visible on the site. Budget policy pause/resume (simulated rate limit) is visible.

## Success and kill criteria *(proposal)*

| Outcome | Evidence |
|---|---|
| GO to production | C2 achieved with >= 70 % of packages passing the verifier without human intervention and hockey playable in <= 6 h wall; C3 with zero kernel diff and bypass count low; art lane averages >= 4/5 on its rubric from the report |
| PIVOT | C2 true but cost/time >> estimates, or C3 fails on a small, nameable set of kernel gaps (fix the kernel, rerun racing), or art authorable only at large cost (pick the cheaper lane) |
| KILL / reshape | builders cannot reach a verifier-green hockey without human code after three DAG re-plans, or look quality unreachable within the cost bound, or a service blocked by terms (the single-player product can still continue) |

## Out of scope for the spike
Multiplayer and sharing; marketplace; a real security sandbox (the fence is a guardrail); new rig families; generative 3D models; mobile; the player-facing designer UI polish (a minimal chat panel is enough); economy; saves beyond promoted packs.

## Cost transparency
Phase A (two builders for about 5 h each) and Phases 1-2 (many CLI agent sessions) consume the operator's Claude subscription. The job log records usage per package; no separate analysis package is planned (the operator did not select the cost ledger as scope).
