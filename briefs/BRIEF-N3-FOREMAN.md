# N3: the Foreman learns to change a finished package

You are the builder for the **Foreman** of Third Life: the Node/TypeScript job runner in `foreman/` that turns a
player's sentence into a verified game pack by planning packages, running CLI builder agents, verifying each round with
the engine and promoting the result. Two real jobs have run to `done`. The second showed what is missing, and tonight
you build it. Right after you finish, the Director runs a real hockey job with your build, including at least one
change request, so leave it green.

## Read first
1. `C:\Users\kazda\kiro\third-life\docs\reports\JOB2-MARBLE.md` (findings 2, 3, 4 and 5 are your work list).
2. `foreman\README.md`, `foreman\JOURNAL.md` (WP3c section), `contracts\JOB.md`, the last section of
   `contracts\PACK.md`, `docs\reports\WP3C-FOREMAN.md` (its "Director verification" and the command lines).
3. The real job's log, as test input: `site\marble-run-three-marbles-20261110-2\job.jsonl` (read only).

## Scope
`foreman/**` only. Read-only: `site/**`, `engine/**`, `contracts/**`. The engine your tests use is the frozen copy
`C:\Users\kazda\kiro\third-life\site\_engine_snapshot3\` (`TL_ENGINE_DIR`), with
`TL_GODOT=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe`. Other builders are
changing `engine/` tonight; do not run anything there.

## The work, in this order
1. **Change request.** `foreman change <job> "<text>" [--package=<id>]` works on a job in any state after its first
   promoted package, including `done`. Without `--package` the Planner is asked which package owns the problem
   (one short call; with the fake adapter in tests). The owner package is re-opened with the text as its brief
   addition, runs its normal rounds, and every package that depends on it is verified again (and rebuilt only if its
   verification now fails). New events: `change_requested {text, package?}` and `reopened {package, reason}`. A `done`
   job goes back to running and ends `done` again with a new promotion; the earlier promotion is kept beside it, not
   overwritten. A builder's question "may package X be changed?" can now be answered yes: `foreman answer` accepts
   `--change=<package>` and turns the answer into a change request.
2. **The critic names the package.** The picture critic's verdict gets a `package` field: the package whose files
   most likely cause what it sees (it is given the plan's package list with one line each and the files each owns).
   Its extra round goes to that package through the change-request path, not to whichever package just merged.
   An unknown or missing `package` falls back to today's behaviour and is logged as a `note`.
3. **Kit use cannot fall silently.** After each round compare the lint figures of the merged pack with the figures
   before the round: bypass count and kit parts used. A round that raises bypasses or lowers kit use fails with cause
   `kit_regression` and one more round, unless the builder's `DEVIATIONS:` section names the reason; then it passes
   and the reason is recorded as a `note`. Check what the lint report really offers before you design this
   (`metrics` of the `lint` verb in a real report under `site\marble-run-three-marbles-20261110-2\reports\`).
4. **Runner options from the engine.** Delete the copy of the runner's option list (`ACCEPTANCE_OPTIONS` in
   `src/designer.ts`, and any other copy) and read `<engine>/kernel/runner/verbs.json` (`tl.verbs/1`: verbs, options,
   types, defaults). A plan that uses `--bot-frames` with `invariants` must now pass. A missing or unreadable file is a
   clear error at start, not a silent fallback.
5. **Follow.** `foreman follow <job> [--from=<seq>]` prints each event of `job.jsonl` as one JSON line as it is
   appended, starting after `--from`, and exits 0 when the job reaches a terminal state. It holds no lock and
   tolerates a torn last line. A game window will read this to show a build live.
6. **Builders declare what a player may tune.** The builder prompt tells a builder to list the values a player might
   want to change in `pack.json` `params` (`[{name, file, path, min, max, step, label}]`, see `contracts\PACK.md`,
   last section), and to keep such values in a JSON file under `data/` instead of in script constants. The manifest
   composition and the manifest type carry `params`, `footprint`, `on_leave`, `subject` and `moments` through
   unchanged when a builder writes them.

## Acceptance (the Director will run these)
- `npx tsc --noEmit` clean; `npm test` passes with the new tests, none skipped without a stated reason.
- A fixture job that ends `done`, then `foreman change` on it: the log shows `change_requested`, `reopened`, a round
  of the owner, re-verification of a dependant, and a second promotion; `foreman status --json` agrees.
- A fixture in which the critic names the root package while an art package just merged: the extra round runs on the
  root.
- A fixture round that drops kit use fails with `kit_regression`; the same round with a stated deviation passes.
- The second real job's first Planner output (it used `--bot-frames=4000`) is accepted by the plan check.
- `foreman follow` on a job that is being written by another process prints every event exactly once.
- `foreman prompts` shows the new builder text; put a dry copy in `foreman/dry/n3-prompts-hockey.txt` for the sentence
  "Ice hockey, three against three: skaters, a puck, two goals, first to three goals wins. I play one skater with WASD
  and shoot with space."
- **Command lines for the Director's real hockey job** (new, plan, run, change, follow), with the environment to set,
  the limits you recommend, and what to expect in the log.

## How to work
Small verified steps; journal each in `foreman/JOURNAL.md` under an "N3" heading. Kill every process you start,
including stray `claude`, `node` and Godot children; never kill others. No git. Network: `npm install` only.
**No model calls at all** in this pass except `foreman probe` (which spends no tokens): everything runs against the
fake adapter and fixtures. Never read, use or print any `ANTHROPIC_KEY_*` variable. Where a step's premise is wrong,
say so with the evidence and propose the alternative.

## Final message (your report, as text)
Status; item by item what was built and the test that proves it; the test count; the dry prompt path; the command
lines for the hockey job; what is still fake-only and has never run live; questions; minutes spent from real
timestamps (`date`).

## Time-box
Until the list is done or **80 minutes after your start** (run `date` first and often). Items 1, 2 and 4 and the
command lines are worth more than the rest. Leave the last ten minutes for the tests and the report. A usage limit can
cut you off without warning: keep the journal current.
