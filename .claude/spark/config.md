---
product: "Third Life"
stack: "Godot 4.7.2 (GDScript) engine + Node 24/TypeScript Foreman + Node ESM devx tool; Windows 11 + Git Bash"
vault: ["C:/Users/kazda/kiro/third-life/.spark"]
vault_subdir: Spark
context_map: context-map.json
base_branch: main
active_runs_ledger: ".claude/sessions.json"
locale_count: 1
---

## Gates
- always: `node devx/bin/tl.mjs check --tier fast`
- when engine/kernel, kits, rigs, style or seeds changed: `node devx/bin/tl.mjs check --tier full`
- builder: `node devx/bin/tl.mjs check --tier fast --changed`
- before a merge to `main`, on the merged tree: the full gate, `bash engine/tools/world.sh tour tour --headless`,
  the same tour in a window, `bash engine/tools/world.sh alone --packs=<the exe's games> --mode=bot --frames=20000`
  (a game in the world hashes as it does alone), `bash engine/tools/export.sh --commit <sha>` and
  `bash engine/tools/export.sh check`. In the main checkout only: `node devx/bin/tl.mjs check --tier full --only
  item.selftest,ui.selftest` (they need last night's job under `site/` and are skipped in a worktree).
- a performance figure counts only from `node devx/bin/tl.mjs perf run --quiet-only --wait <s>`; a figure taken
  while builders run is labelled busy and decides nothing.

- the pre-merge list, as it runs since 2026-11-16: the full gate now holds `world` (every game of `engine/boot/games.json` in one
  world = alone; it replaced the hand-run `world.sh alone`); the tour in a window is `bash engine/tools/world.sh tour tour
  --out-dir=<abs dir>` (without `--out-dir` it exits 2). Run the WHOLE list on the first merged tree of a night, not at the end:
  a kernel fault of 03:31 was found by it at 05:39.
- a worktree runs the whole full gate after `npm ci` in its `foreman/` and plain copies (no links) of
  `site/marble-run-three-marbles-20261110-1` and `-2` into its `site/`; with only one of the two, a devx ledger test fails.
- a win-or-lose test enters the gate only after its verdict held on 20 of 20 seeds (two of tonight's were coins: 10 and 19 of 20);
  a difficulty figure comes from `tl ladder` and is quoted with the hand profile and the seed count.

- before committing a builder's new directory: `git check-ignore -v <dir>/<a file>`; an ignore pattern for job output
  (`/site/`) once hid `engine/kernel/world/site/` and the commit would have dropped the site's code silently.

## Rituals
- Phase 0: read `.claude/sessions.json`; add an entry for this spark's scope. Phase 6: remove it.
- Phase 5: after every package, `tl arch --index` if engine API changed (docs/generated/API-INDEX.md).

## Repo law
Read CLAUDE.md "Laws that bite" and paste it verbatim into every builder brief. Walls: contracts/* are Director-only;
other sessions' uncommitted files are never touched; worktree for multi-file work; stage per file.
Builders run no git command of any kind (the Director stages and commits); a test may run git only against a temporary
repository with `GIT_DIR` unset. Scripts and briefs with quoted passages are written to a file with the Write tool and
run from there, never as a bash heredoc (the trap was hit three times on 2026-11-11).
Dispatch by tier (owner's rule, 2026-11-11): development packages to `model: "opus"` builders, re-runs of checks to
`model: "sonnet"` verifiers given a fixed, numbered command list with expected values and the instruction to report
what was printed; the Director writes briefs, reads results, looks at the pictures and decides. A verifier is told:
one step at a time, one repeat on failure, never explain a failure away.
Parallel builders get disjoint FILES, named in each brief with who owns the neighbours; what sits between them goes
to a patches file, and a last single-builder package owns the seam (P14 of the core run closed what three parallel
builders each had to leave). Each builder picks an unused number for `engine/tools/selftest.d/NNN-<lane-or-topic>.sh`
and puts its cases there. Close every shell construct in that file. The selftest runner discovers blocks in sort order.
The kernel API is versioned (`tl arch` rule `api-v1`): a builder that adds a public member says so; the Director
settles the version on the merged tree. `tl.sh` takes the pack as `--pack=<dir>`.

A lane's state lives on disk, never only in the agent: every lane writes `status/<lane>.md` as it goes, so a Director restart (13:23 on 2026-11-13 lost three
running lanes; 02:00 the same night lost the dispatch for seven hours) resumes a lane from its worktree and its status file with a new agent, and the Director's
chain scripts live in files (`land.sh`, `export.sh`), not in a shell's memory.

Since 2026-11-16 a lane's status file is `docs/reports/<slug>/<lane>.md` in its worktree (not a top-level `status/`); stills
stay out of git (a table in a README and one sheet under 1 MB are committed; the rest is copied to the vault). A number in a
brief is a thing to measure, and the brief says so: builders corrected three of the Director's premises that night (a hash that
could not stay, a blade at 3.0 m not 1.9, a tolerance needing 100 seeds). A second builder on a pack another builder is in gets
its own worktree and a list of files it stays out of: five such merges were clean. A kernel helper that asks the physics
world asks the pack's own space (`TLContext.space_state_of`), and anything new in the kernel is proven in a world, not only alone.

## Wave defaults
One AskUserQuestion call of up to 4 questions.

## Question taste
- Operator wants tooling-scope questions asked as multi-select pillars, and answers extra wishes via "Other" (devx spark 2026-11-11 added a doctrine: player-facing content tooling ideas).
- Isolation and push policy: worktree + branch + push branch is the accepted default; do not re-ask.
- 2026-11-17 engine-world-next: offered "replay recorded jobs (no spend)" vs "one real job", the operator chose the real job: when a path can be proven against a real model at bounded cost, offer it and expect a yes.

## Skill improvement log
- 2026-11-11 devx-foundation: a bash heredoc with many quoted passages failed to parse as one command; write brief files with the Write tool, not heredocs.
- 2026-11-11 devx-foundation: a gate step that reports only the tail of a failing run loses the one fact needed (which test); every step must name the failing unit and keep the full output. `foreman.test` failed once in six full runs under load and passed five times; the test is still unidentified.
- 2026-11-11 devx-foundation: parallel builders on one branch worked with auto-discovered files (commands, gate steps) and no shared registry; keep that shape for any future fan-out.
- 2026-11-11 third-life night plan: the Director verifying, a real Foreman job and three builders on one machine made every
  wall-clock limit useless for an hour and cost the job two questions and four rounds. Do not run a real job while builders
  use the engine; a time-limit failure is re-run alone before it is believed.
- 2026-11-11 third-life night plan: a builder finished at 01:55 and its session stood still for seven hours without a report.
  Check a builder on disk when it is 15 minutes past its time-box.
- 2026-11-11 third-life night plan: five brief premises were wrong and each builder said so with evidence because the brief
  said its measurement outranks the brief; keep that line in every brief. Contract fields written before the code that
  validates them existed were met by nobody: name the validator with the field.
- 2026-11-11 core-perfection: the base moved under the spark between Phase 0 and the waves (another session's branch was
  merged, bringing this overlay). Fetch again and re-read the overlay right before the go-gate.
- 2026-11-11 core-perfection: per-package verification by Sonnet subagents with a fixed command list found four things
  no builder reported (windows of parallel runs throttling each other to 270 ms a frame, a proof failed by a sound-device
  error, a queue that left a game unbuilt, a drawing check that fails once in a while). Keep the second run; it costs
  50 to 100 thousand tokens a package.
- 2026-11-11 core-perfection: the builders' reports named a miss with its figure every time the brief asked for
  "met / not met / not done" per acceptance line. Round 2's loading package missed its target and said so; that
  sentence is what made rounds 3 and 4 possible. Keep the three-way acceptance form.
- 2026-11-11 core-perfection: the Director's reading of a failure went into the next brief as a reading "yours to
  prove or refute", with the case to reproduce. It was proven once (frame-rate-bound preparation) and refuted once
  (the remaining hitch was not the view's). Write causes that way, never as facts.
- 2026-11-11 core-perfection: looking at the pictures is the Director's and found what no check did (empty pads at
  the start, the road cut into patches, marks as boxes at 50 m). A builder's own guess at a visual cause was wrong
  (soft patches) and a 35-minute fix brief that said "switch candidates off one at a time" found the real one in 8.
- 2026-11-11 core-perfection: a worktree linked to the main checkout's `foreman/node_modules` by a junction must lose
  the junction (`cmd //c rmdir <link>`) BEFORE `git worktree remove`, and the main folder is counted before and after.
- 2026-11-11 core-perfection: the Director once typed `git commit --no-verify -m wip` while only meaning to stage, and
  amended it at once. Stage and commit are two commands; no flag that skips a hook is ever typed.
- 2026-11-11 megajam-unreal: `node --test <dir>` is not valid on Node 24 (two builders hit it); briefs say `node --test` bare or quoted globs.
- 2026-11-11 megajam-unreal: a builder's disk floor on the shared C: stopped it for another process's 5 GB; make floors per-step with an env override and tell the operator the number, do not hard-stop.
- 2026-11-11 megajam-unreal: four builders on disjoint folders of a fresh repo needed no merge; the one cross-cutting change (a size budget) was two mid-flight messages. Opus for the package with an unknown toolchain (Unreal MCP) paid for itself: six failure modes diagnosed and scripted around.
- 2026-11-12 megajam-unreal (prep, second phase): three PowerShell 5.1 traps in one script, each a false "failure" of a working step: Start-Process -PassThru returns a null ExitCode unless $p.Handle is read first; a function returns every line it emitted, so `return $code` after a logging pipe yields an array (pipe the log to Out-Null); cmd.exe in this environment does not resolve a bare .bat from the cwd (exit 9009), so stage files call batch files by absolute path. Check the log of the real tool before believing a script's verdict.
- 2026-11-12 megajam-unreal (experiment night): a research lane's vendor claims (Meshy rig free, no retarget) were reversed by a 35-minute API run; brief research lanes to run the cheapest real call before writing a capability table, and mark every unrun row [vendor].
- 2026-11-12 megajam-unreal: two art waves offered variants of one style; the operator wanted different styles. When the operator says "I love X but it is risky", the next set is alternative paths at X's tier, not X at several tiers.
- 2026-11-13 night-capacity: the Director's session stood still for seven hours (a login interruption) and eight of eleven fillers never started; a lane finished at
  01:52 and waited. Rule for a night: hand the queue to a scheduled chain or a second dispatching session; leave the operator a one-line liveness check.
- 2026-11-13 night-capacity: `git apply --3way` on a file with unstaged edits applies nothing and the chain reported success; a cleanup lane removed a variable a
  feature lane began reading the same hour; the cook ran on a stale editor after a gate in another worktree. All three are now checks in the Director's landing
  script, which replaced the retyped chain.
- 2026-11-16 jam-lessons-home: the overlay's pre-merge list was first run 2 h after the fault it catches was merged; every check
  on that list that can be a gate step now is one (`world`), and the list is run on the first merged tree.
- 2026-11-16 jam-lessons-home: one long-lived builder per lane (13 packages through one agent by SendMessage, each with a hard
  clock time and "what is not proven by then is listed as not done") kept its context and finished every package early; briefs
  written while the lane worked, so no lane waited for the Director more than two minutes.
- 2026-11-16 jam-lessons-home: the Director merged a kernel package (3374cdd) without running the consumer's tests on the merge:
  the branch was red on one step for 20 minutes. Run the consumer's gate step on every merge before the next dispatch.
- 2026-11-16 jam-lessons-home: looking at one still per package by the Director found what no bot said (no puck, dial text on
  the ice, developer wording); a separate look builder (Fable) with before/after pairs then cured it without touching a rule.
- 2026-11-18 engine-world-next: packages timed at 1-2 h each were done in 30-60 min by long-lived Opus lanes; the night ran as five
  rounds per lane, each brief written while the previous round gated. Plan a night as rounds with the next brief ready, not
  one long package list; the real job moved from 05:30 to 01:14 because the lanes landed early.
- 2026-11-18 engine-world-next: a builder made a gate selftest pace its writer by wall clock under load (a law breach the
  pasted laws already forbid); the Director's next brief made it frames-only. Read every new selftest for clock use at review.
- 2026-11-18 engine-world-next: the Director re-ran one hand check (`tl cards hands seed_paddle`) and got the builder's figures
  exactly; one cheap re-run per round is the check that a lane's tables are real.
- 2026-11-18 astra-trial: `tl arch --index` run inside a worktree counts that worktree's uncommitted report notes, so the
  committed REPORTS.md was stale on main twice (a refused push). Regenerate generated docs on main after the merge, never in a
  worktree that holds notes you will not commit.
- 2026-11-18 astra-trial: arms branched before a structural change landed on main (the selftest.d split) each needed a hand
  port at merge, and a builder's CRLF file made a whole-file conflict. Land structural changes before a wave branches, and check
  `file <changed .md>` for CRLF at review.
- 2026-11-18 astra-trial: for model comparisons, blind judge agents on anonymised copies worked; the copies must keep generated
  files (a judge read a missing API index as every arm's failure) and strip arm words from report text.
