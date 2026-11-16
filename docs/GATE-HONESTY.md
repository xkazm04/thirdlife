# Gate honesty: a gate that cannot pass by stopping

The jam's last day (HOKEJ, 15 Nov 2026) had two tool faults, both the Director's:

1. A landing was reported green on **214 of 373 tests**: a watcher stopped the test run when the disk fell under a floor, and the
   script counted what had passed.
2. A cleanup of 28 worktrees followed **directory junctions** inside them into the main checkout and emptied a 130 MB licensed
   plugin folder there.

This page is the audit of `tl check` against the first fault, and the rule for removing a worktree against the second.

## The law

- A step that has a count reports **found** (units its run found: tests, cases, rules, checks) and **completed** (units carried
  to a verdict). The engine (`devx/lib/gate/engine.mjs`) **fails** the step on `found == 0` or `completed != found`, whatever
  `ok` the step claims.
- A run **cut short** (our timeout, anyone's kill, a script without its own trailer line, a test run without its summary) is
  never a PASS. Our own timeout is a FAIL that says "timed out"; a kill from outside is **could not run**.
- **Could not run** (`notRun: true`: no Godot, no `foreman/node_modules`, no input, the machine too busy to judge, killed from
  outside) is never a pass. The gate exits **2** when nothing failed and something could not run; exit 1 when anything failed.
- Zero steps selected is a FAIL ("found 0 steps"), except under `--changed` when nothing changed that any step claims: then there
  is nothing to check and the note line says so.
- The disk floor **says, never stops**: `tl doctor` and the first line of `tl check` print free space on the repo's drive and
  `WARN` under the floor (20 GB, `TL_DISK_FLOOR_GB` overrides). Nothing is killed or skipped for it.

The JSON line of `tl check` carries, besides `steps`: `steps_found`, `steps_completed`, `units_found`, `units_completed`,
`not_run` (the ids; omitted when none), `disk_free_gb`, `disk_floor_gb`, `disk_low` (only when low). Each step in `steps` carries
`found` and `completed` when it counts, `not_run: true` when it could not run. The PASS/FAIL line shows `[completed/found]`.

## The step contract

```
run(ctx) -> { ok: boolean, detail?: string, clockOnly?: boolean, found?: int, completed?: int, notRun?: boolean }
```
A step that runs units MUST return `found` and `completed`. A step that cannot run here returns `{ ok: false, notRun: true,
detail: "<what is missing>" }`. A step never returns `ok: true` for something it did not judge.

## The audit: every step

| step | tier | how it counts (after the cure) | the false-pass path found (before) | the cure | test (devx/test/gate-honesty.test.mjs) |
|---|---|---|---|---|---|
| (the gate itself) | both | steps selected vs steps that returned | zero steps selected passed (exit 0); a step's `ok:true` stood whatever it ran | zero selected = FAIL (except `--changed` with nothing to check); engine judges found/completed | "a step that says ok but completed fewer...", "found zero units", "zero steps selected", "JSON line carries found and completed" |
| `arch` | both | rules evaluated (in process) | none: in-process, cannot stop part-way and still return | reports found/completed | (engine tests) |
| `assets` | both | checks evaluated (in process) | none | reports found/completed | (engine tests) |
| `cards` | both | checks evaluated (in process) | none (an empty check list read `steps[0].detail` and threw: a FAIL, not a pass) | reports found/completed; empty list says "no checks" and fails on found 0 | (engine tests) |
| `devx.test` | both | node --test summary: `tests` found, pass+fail+skipped+todo completed (cancelled is not completed) | **zero test files passed** ("no devx tests yet"); exit 0 without a summary passed; the timeout said only `NaN pass, NaN fail` | zero files = FAIL; no summary = cut short = FAIL; our timeout = FAIL "timed out"; an outside kill = could not run; whole output kept in `.tl/last/devx.test.log` on a failure | "devx.test: zero test files", "a run stopped before its summary", "our timeout ... a kill from outside" |
| `foreman.typecheck` | both | none (tsc has no units) | missing `foreman/node_modules` was a FAIL as if the code were wrong | missing deps = could not run (exit 2); timeout = FAIL; outside kill = could not run | "foreman steps without foreman/node_modules could not run" |
| `foreman.test` | full | node --test summary, as devx.test | exit 0 counted as pass with `? pass`; the one failure in six under load **named no test** (the old pattern took every ✖ line, parents and the "failing tests:" header included, and dropped the place) | counts as devx.test; names each failing test **with its file and line** from the spec reporter's "failing tests:" block; the **whole output is kept on every run** in `.tl/last/foreman.test.log`; a timeout says so | "foreman.test: a failure names the failing test with its file and line, and the whole output is kept" |
| `kernel.selftest` | full | `selftest.sh` own trailer `selftest: N passed, M failed` = found; PASS/FAIL case lines seen = completed | exit 0 passed **without the trailer**: a script stopped before its end that still exited 0 counted what it had printed | no trailer = cut short = FAIL; trailer N+M != lines seen = FAIL; a cut-short run is never clock-only (no retry turns it green) | "shell selftest: exit 0 with PASS lines but no trailer", "a trailer that counts more cases than the lines we saw" |
| `seeds` | full | `seeds.sh` trailer `seeds: N passed, M failed` (24 today) | as kernel.selftest | as kernel.selftest; proven on the real script: `PASS seeds [24/24]` | same two tests |
| `kit.selftest` | full | `selftest.gd` trailer `[selftest] N passed, M failed: RESULT ...` | it counted `\bPASS\b` anywhere, so **"RESULT PASS" on a run of zero cases passed** | counts `^PASS ` case lines against the trailer; found 0 = FAIL | "kit.selftest: 'RESULT PASS' on a run of zero cases is not a PASS" |
| `item.selftest` | full | `item.sh` trailer `item selftest: N passed, M failed` | **passed as "SKIPPED, not judged"** without the marble job (every worktree) | no input = could not run (exit 2); counts against the trailer | "item.selftest without its input ... could not run" |
| `ui.selftest` | full | `ui/selftest.gd` trailer `[selftest] N passed, M failed` | as item.selftest | as item.selftest | (same path as item.selftest) |
| `perf` | full | scenarios judged against a quiet baseline | **passed** with no quiet baseline and **passed** on a busy machine, judging nothing | both = could not run (exit 2); judged scenarios are found/completed | "perf with no quiet baseline judged nothing: could not run" |
| `packs` (lane H, new) | | must return found = packs found, completed = packs carried to a verdict | (not yet written) | must follow the contract above | (lane H's) |

Common to every step that spawns: `ctx.run` now names our own timeout (`timedOut: true`) and the signal (`signal`) on its result,
so a step can tell "timed out" from "killed" from "failed" (test: "ctx.run names our own timeout").

### What it costs

- In a worktree (no `foreman/node_modules`, no `site/`), `tl check --tier fast` exits **2**, not 1: `foreman.typecheck` could not
  run. That is the truth about such a run; read `not_run` in the JSON.
- `tl check --tier full` on a busy machine exits **2** for `perf` ("machine BUSY: not judged"). It used to pass. A merge gate
  that needs a 0 runs perf on a quiet machine or reads `not_run` and decides in words.
- The pre-push hook says "COULD NOT RUN" for exit 2 and stops the push, as it does for a FAIL.

### What this does not catch

- A shell script whose own trailer is printed and whose cases were skipped inside it (a case the script never ran is not counted
  by anyone). The scripts in `engine/tools/` have no case manifest; a count drop against the previous run is not judged yet.
- A Windows timeout kills `bash` / `cmd.exe`; a grandchild (Godot, node) can outlive it. The verdict is still FAIL "timed out".
- The gate process itself killed: no JSON line is printed. A reader that finds no JSON last line must treat the run as failed.

## Removing a worktree: `tl trees`

Measured on this machine (16 Nov, a temp repository, a junction made by `mklink /J` inside the temp folder):

| removal | target of a junction inside the tree |
|---|---|
| `git worktree remove --force <tree>` | **5 files -> 0: git follows the junction and empties its target** |
| node `fs.rmSync(tree, {recursive})` | 5 -> 5 |
| PowerShell 5.1 `Remove-Item -Recurse -Force` | 5 -> 5 |
| `cmd /c rmdir /s /q` | 5 -> 5 |
| Git Bash `rm -rf` | 5 -> 5 |

So a worktree holding a junction must never be handed to `git worktree remove` as it is. `tl trees remove <name> --apply`:

1. refuses when a process runs from the tree (its exe or command line names a path inside it), and when processes cannot be listed;
2. refuses when the tree's folder cannot be renamed aside and back (Windows: something holds it open);
3. unlinks **every** junction and symbolic link inside the tree first, each with a non-recursive call (`unlink`, else `rmdir`),
   and checks the link is gone and its target holds at least as many files as before; any miss stops everything;
4. scans again: no link may be left;
5. only then `git worktree remove --force`;
6. checks every link target and the main checkout's kept folders (`site`, `.tl`, `foreman/node_modules`, every `--keep`, every
   link target inside the main checkout) hold at least as many files as before.

Without `--apply` it is a dry run that prints the plan (the default, and it says so). `tl trees list` prints every worktree with
its size, branch, merged into main (asks git; `--no-git` leaves it out), the processes running from it, and every link inside it
with its target. Proof: `devx/test/trees.test.mjs` (temp repo, a worktree with a junction into the main checkout's gitignored
`site/plugin` and a nested one to a folder outside; after `--apply` the targets keep 6 of 6 and 1 of 1 files).
