H2c (a Create game's budget class), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-b at main 5b17c0d (H2b landed as e342b88).
Also: create.pause.path's race (your "if there is time").

== THE RULING, AS BUILT ==
A game made in Create is a dungeon, judged by the solo budget unless a person places it in the village. The kernel's
budget_class called every pack outside the engine's tree "many" (p50 1.0 ms), and a Create job's pack always lives outside
it. Mechanism: the Foreman tells the runner where the job's game lives, with a new invariants option --home:
  - create  = a job made without a village lot (every Create job): "solo" (p50 8.0 ms, p99 8 ms);
  - village = a job whose job_created has a `lot` (a village site job, kernel/world/site.gd reads the same lot): "many";
  - absent  = as before: the engine's boot files decide; a pack outside the engine's tree stays "many" (now said in words);
  - any other value: not_run (exit 2), "--home must be create or village (got '...')".
The Foreman passes it only to a runner whose verbs.json lists the option (an older engine is never given it), the plan may
not set it (it is the Foreman's, like --pack), and the builders' own self-check commands carry it too, so a builder measures
against the budget the Foreman will apply.

== EXACT LINES (for RUNNER.md / JOB.md) ==
engine/kernel/runner/verbs.json, invariants.options:
  "home": {"type": "string", "default": "", "note": "H2c. Where the game lives, for its frame budget: create (made in Create: a dungeon played alone, the solo budget) | village (placed on a village plot: one of many). Absent: the engine's boot files decide (invariants.gd budget_class). The Foreman passes it for its jobs."}
engine/kernel/host/host.gd:
  OPTIONS "invariants": ["pack", "report", "seed", "frames", "bot-frames", "home"]
  if opts.has("home") and not (str(opts["home"]) in ["create", "village"]): return _not_run("engine", "--home must be create or village (got '%s')" % str(opts["home"]))
engine/kernel/host/invariants.gd:
  static func budget_class(pack_dir: String, boot_dir: String = "res://boot", home: String = "") -> Dictionary:
  	if home == "create":
  		return {"class": "solo", "why": "a game made in Create (--home=create): a dungeon played alone until a person places it in the village"}
  	if home == "village":
  		return {"class": "many", "why": "a game placed in the village (--home=village): one of many games in one world"}
  	... (outside the tree, no home:) {"class": "many", "why": "not a pack of the engine's tree, and the runner was not told its home (--home): held to the village's one-of-many budget"}
  and its caller: budget_class(str(h.get("pack_dir")), "res://boot", str((h.get("opts") as Dictionary).get("home", "")))
foreman/src/foreman.ts (run() and previewBuilderPrompts()):
  this.o.verifier.home = this.log.state.lot !== undefined ? "village" : "create";
foreman/src/verifier.ts: `home?: "create" | "village"`; argsFor(verb, args) appends `--home=<home>` to invariants when the
  runner's verbs.json knows it and no --home is given; run() and the builders' self-check commands (deriveBashAllowlist) use it.
foreman/src/verbs.ts: FOREMAN_OPTIONS = pack, report, home (a plan's acceptance cannot carry --home).
Proposed RUNNER.md line (beside "invariants takes --bot-frames", line 108) -- REQUIRED by the arch rule verbs-contract:
  - `invariants` takes `--home=create|village` (H2c): where the game lives, for its frame budget. `create`: a game made in
    Create, a dungeon played alone until a person places it in the village (the solo budgets, checks
    `invariants.solo_budget` / `invariants.solo_frame_budget`); `village`: placed on a village plot, one of many
    (`invariants.many_budget`). Absent: the engine's boot files decide, and a pack outside the engine's tree is one of many.
    Any other value is not_run. The checks' details say the reason in words.
Proposed JOB.md line: the Foreman runs `invariants` with `--home=village` for a job whose job_created has a `lot`, and with
  `--home=create` for every other job (a game made in Create), when the runner's verbs.json lists the option.

== EVIDENCE (both ways, G4's real pack) ==
- G4's crews_stakes workspace, copied from d25-court's job (read-only source; the version its Foreman refused at seq 253 with
  "frame p50 1.516 ms (budget 1.0 ms for one of many: not a pack of the engine's tree"):
    no --home      -> FAIL invariants.many_budget "frame p50 1.179 ms (budget 1.0 ms for one of many: not a pack of the
                      engine's tree, and the runner was not told its home (--home): held to the village's one-of-many budget)" (exit 1)
    --home=create  -> PASS invariants.solo_budget "frame p50 1.261 ms (budget 8.0 ms for a game alone in its world: a game made
                      in Create (--home=create): a dungeon played alone until a person places it in the village; the one-of-many
                      budget 1.0 ms does not apply)", solo_frame_budget p99 1.874 ms of 8 (exit 0)
  (G4's current pack/ measures p50 0.85 ms and passes both ways; the class differs: solo_budget against many_budget.)
- budget.class (845): 18 checks (13 + 5 new: create outside the tree -> solo, village outside -> many, home wins over the boot
  files both ways, the reasons in words); budget.home_create / _village / _none / _bad (869, kernel/examples/pack_min copied
  outside the tree, the real runner): all PASS. Before the change the new checks fail (home ignored; --home an unknown option).
- foreman/src/test/h2c_home.test.ts 3 of 3: the engine's verbs.json and host.gd list it and a plan cannot carry it; the
  Verifier passes it to invariants only, only when told, never doubled, never to an engine without it; the Foreman sets create
  for a job without a lot (previewBuilderPrompts and run) and village for a job on a lot.

== create.pause.path (the race) ==
engine/ui/create/stage_pauses.gd: the check read page.busy 6 frames after a quality press; a fake-adapter Foreman that takes
the verdict inside those frames clears it. "Sent" is now: the door started a `quality` process for this press, no message,
and the page waits OR the log has already moved past the hold. Runs: 3 of 3 PASS alone, and create. 23 of 23 (before: 2 of 3
clean runs failed in H2b).

== GATES ==
- k.sh selftest: 120 passed, 0 failed (before the final trims; rerun below).
- selftest budget: 6 PASS (bad.budget, budget.class 18 checks, budget.home x4); verbs.json_matches_host PASS; invariants.* 13
  PASS; min.* 11 PASS (after the trims: budget 6, verbs 1, invariants 13 again).
- create.: 23 PASS, 0 FAIL.
- foreman npm test: 412 tests, 405 pass, 0 fail, 7 skipped (main 409 + my 3).
- tl check --only world: PASS [9/9] (before the two cosmetic trims below; no --home in the world gate).
- tl check --tier fast: assets, cards, foreman.typecheck PASS; arch FAILS on ONE finding: verbs-contract "contracts/RUNNER.md
  verb 'invariants': option --home is not documented" (devx.test fails on the same real-tree run). Contracts are yours: with
  the RUNNER.md line above, arch is green (the size ratchets are back at 605 / 2005: I trimmed host.gd and foreman.ts).
- invariants.gd keeps its CRLF line ends (my first edit had turned them LF; fixed, the diff is 18 lines).

== FILES ==
engine/kernel/runner/verbs.json, engine/kernel/host/{host.gd, invariants.gd, budget_class_test.gd}, engine/kernel/API.md
(section 16), engine/tools/tl.sh (usage comment), engine/tools/selftest.d/869-rink-boost-glow.sh (budget.home cases added),
foreman/src/{verifier.ts, verbs.ts, foreman.ts, test/h2c_home.test.ts}, engine/ui/create/stage_pauses.gd.

== FOR THE DIRECTOR ==
- RUNNER.md needs the --home line before fast is green (arch verbs-contract). JOB.md: the Foreman's rule above.
- G4 can resume after this lands: its next invariants run gets --home=create (its job has no lot).
- A note on my process: I edited engine/tools/tl.sh's usage comment while a selftest chain was running (bash reads a script as
  it goes); nothing in that chain failed, but I name it.
