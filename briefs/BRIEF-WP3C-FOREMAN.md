# WP3c: Foreman close-out before the second real job

You are a **new builder taking over the Foreman** (`foreman/`, Node 24 / TypeScript) in Phase 0 of the Third Life
feasibility spike. Third Life is a single-player sandbox in which an LLM designer and builder agents construct whole
mini-games as verified **packs** over a law kernel in Godot. Two Foreman passes are done and verified; the second ran
one real job end to end (Claude CLI builders wrote a marble-run pack; every gate passed in round 1). That run showed
what the Foreman lets through. You close those gaps. **You do not run a real job**: the Director runs the second one
right after you finish, on a newer engine that now contains a kit, rigs, a style and three seed games.

## Read first, in this order
1. `C:\Users\kazda\kiro\third-life\contracts\README.md`, then the **last "Amendments of 2026-11-10, second round"
   section** of `contracts\JOB.md` and `contracts\RUNNER.md`: they are your work list.
2. `docs\reports\WP3B-FOREMAN.md`: the builder's report, then the "Director verification" section at its end
   ("What the job does and does not prove", decisions 1 to 10).
3. `foreman\JOURNAL.md` ("WP3b" section), then the source you need. Grep before you read.
4. The real job, as evidence: `site\marble-run-three-marbles-20261110-1\job.jsonl`, its `reports\` and `ref\`.

## Your scope
`foreman/**`, and new job directories under `site/` for fixture runs. **Read-only:** `site/_engine_snapshot/` (the engine
copy your engine tests use), `site/marble-run-three-marbles-20261110-1/`, and `engine/` (**read files only, never run
Godot there**: another builder is changing it right now). Do not touch `contracts/`, `briefs/`, `docs/`.

## The work, in this order (each with tests against the fake adapter and the fake runner)

1. **Reference copy.** `ref/` is built from `TL_ENGINE_DIR`: `kernel/API.md`, the law tables, two example packs, and,
   **when they exist in that engine**, `seeds/**` (the three seed packs and `seeds/README.md`), `kits/KIT.md`,
   `kits/LAYOUT.md`, `rigs/RIGS.md`, `style/STYLE.md`. The live `engine/` has them; the old snapshot does not; both must
   work. The builder prompt names what is in `ref/` and says: read `ref/seeds/README.md` first, copy the nearest seed,
   build the venue from the kit before making boxes.
2. **Planner prompt.** Tell it what exists (the kit, the rigs, the style, the seeds, by name, read from `ref/` when
   present), that a builder run has a hard time limit (pass the real number), and to size packages so the root is
   playable with few files and later packages carry the rest. An `art_pass` package must have an acceptance that a
   capture can show (it changes what the camera sees). Keep the limit of packages a parameter.
3. **`note` event.** After a builder run, the deviations it states go into a `note {package, round, text}` event (ask
   for them under a fixed heading in the builder's answer, for example `DEVIATIONS:`; none means no event). The notes of
   a package are part of the brief of every package that depends on it.
4. **No visible change.** When every capture of an `art_pass` milestone is byte-identical to the same capture of the
   previous milestone, its packages fail that round with cause `no_visible_change` and go to the next round with that
   as feedback.
5. **Critic.** "NOT ok" gives the milestone's packages one extra round with the critic's notes as feedback; after that
   round the job continues whatever the verdict. The verdict stays in the `milestone` event.
6. **Capture frames.** 25 % and 75 % of the frame at which the first bot finished in its last passing report; 120 and
   480 when there is none.
7. **Budget.** Cache-read tokens count at weight 0.1 against a token policy (raw figures logged unchanged; find out
   from the CLI's result JSON which field carries cache reads and record it in the capability matrix). `budget.state`
   closes when the job ends.
8. **Promotion.** When the engine directory is not writable or `--promote-to job` is given, promotion writes to
   `<job>/promoted/<pack id>/`, so a job can end `promoted` without touching the engine. Make that the default.
9. `foreman verify` on a pack whose only failure is clock-based: confirm the re-run rule holds there too.

## Acceptance (the Director will run these)
- `npx tsc --noEmit` clean; `npm test` passes with and without `TL_GODOT`; new tests exist for items 1 to 8, named by
  item number.
- `foreman init-fixture` plus `run` with the fake adapter still reaches the end state, now `promoted` under the job
  directory.
- A dry check the Director can read: a command or test output that prints the **assembled builder prompt and Planner
  prompt** for a job whose `TL_ENGINE_DIR` is `C:\Users\kazda\kiro\third-life\engine` (reading files there is allowed),
  without calling any model. Say how to run it.
- The exact command lines for `new`, `plan` and `run` that the Director should use for the second real job (same
  sentence, `--adapter claude-cli`, builders on `sonnet`, at most 3 packages, 3 rounds, 12 minutes per run, one
  re-plan), with the environment variables to set.

## How to work
Small verified steps; journal after each in `foreman/JOURNAL.md` (append under a "WP3c" heading). Kill every process
you start, including stray `claude`, `node` and Godot children; never kill others. No git. Network: `npm install` only.
**No model calls at all** in this pass, except `foreman probe` (which spends no tokens). Never read, use or print any
`ANTHROPIC_KEY_*` variable.

## Final message (your report, as text)
Status; item by item what was built and the test that proves it; the two prompts' paths or the command that prints
them; the command lines for the second real job; what is still fake-only; questions; minutes spent from real timestamps
(`date`).

## Time-box
Until the list is done or **22:10 CEST today**, whichever comes first (check with `date` at the start and often). Order
is the priority: items 1 to 4 and the command lines are worth more than the rest. Leave the last ten minutes for the
tests and the report. A usage limit can cut you off without warning: keep the journal current.
