# WP3b: finish the Foreman and run it against the real engine

You are a **new builder taking over the Foreman** (`foreman/`, Node 24 / TypeScript) in Phase 0 of the Third Life
feasibility spike. Third Life is a single-player sandbox in which an LLM designer and builder agents construct whole
mini-games as verified **packs** over a law kernel in Godot. The first Foreman pass is done and verified against a
stand-in engine. You close its gaps, plug in the real engine, and then run **one small real job end to end**: a real
Claude builder writing a real pack that the real engine verifies. That run is the first true test of the product loop.

## Read first, in this order
1. `C:\Users\kazda\kiro\third-life\contracts\README.md`, then `JOB.md` and `RUNNER.md` (both have "Amendments of
   2026-11-10" sections that are **newer than the code**: they are your work list), then `PACK.md`.
2. `docs\reports\WP3-FOREMAN.md`: the first builder's report, then the Director verification section at its end
   (decisions 1 to 5).
3. `foreman\JOURNAL.md`, `foreman\package.json`, then the source you need (`src\foreman.ts`, `verifier.ts`,
   `designer.ts`, `builder\`). Grep before you read.
4. `site\_engine_snapshot\kernel\API.md` (what a pack author gets) and one example pack,
   `site\_engine_snapshot\kernel\examples\ex_slide\`.

## Your scope
`foreman/**`, and `site/**` for job directories. **Read-only:** `site/_engine_snapshot/` (a frozen copy of the engine
made at 20:00 CEST; another builder is changing the live `engine/` right now, so never run or read `engine/` itself).
Set `TL_ENGINE_DIR` to the snapshot. Do not touch `contracts/`, `briefs/`, `docs/`, `kitlab/`, `spike/`.

## Part 1: contract amendments (all with tests against the fake adapter and fake runner)
1. **Composed manifest.** `pack.json` is written by the Foreman from `packId`, `title`, version and the `registers`
   blocks of merged packages. No package scope may contain it; the Planner prompt and schema say so.
2. **Re-plan on failure.** After the round limit a package goes back to the Planner once (`replan` covering it and its
   dependants); at most three re-plans per job; then `job_state: failed`.
3. **Milestones.** When the last package of a milestone merges: `capture` for each declared camera (with
   `--test=<first bot>`), then the V5 critic, then a `milestone` event with the capture paths.
4. **V5 critic for real.** A `generate`-mode call that is given the capture images and a rubric (silhouette,
   readability, consistency with the style, does the frame show the game being played) and returns scores and notes as
   schema-checked JSON. Find out from `claude --help` how an image is handed to a headless run and record it in the
   capability matrix; if it cannot be done in `generate` mode, use `readonly-scan` with the capture directory as cwd.
5. **Environment.** Edit-mode runs do not inherit variables whose names contain `KEY`, `TOKEN`, `SECRET` or `PASSWORD`.
6. **Runner changes.** A bot that does not finish is exit 1 `failed` (the snapshot engine still returns exit 3
   `watchdog` for this: accept both, and say so in the report). Unknown `checks[].id` and unknown `metrics` keys are
   accepted; top-level keys are strict. `merge.removed[]`, `verify.after`, `billing.mode: none`, the rest of the list.
7. Fix what the first report lists under "Not built" where it is cheap: pack id mismatch caught at first merge.

## Part 2: the real engine
Point the Verifier at `site/_engine_snapshot` and the real Godot executable. Run every verb on the snapshot's good
example packs and on three of its bad ones through the Foreman's own Verifier (`foreman verify`), and add these as an
integration test that is skipped when `TL_GODOT` is missing. Report every place the real runner differed from the fake
one you inherited, and fix the fake to match.

## Part 3: one real job, end to end (the point of this pass)
Run this through the real CLI, on the owner's subscription (approved for the spike):

> **Sentence:** "A marble run: three marbles of different materials roll down a zig-zag wooden ramp onto an ice sheet,
> and the one that slides furthest wins."

1. `foreman new` with the real Designer, `plan` with the real Planner (first live Planner call), `run` with
   `--adapter claude-cli`. Builders work in `edit` mode in their `ws/<package>/`, with the Bash allowlist derived from
   their acceptance commands, and are given: the package contract, `PACK.md`, the path of the snapshot's `API.md` and
   of two example packs, and the last verify report on later rounds.
2. Limits, enforced by the Foreman and not by hope: at most **3 packages**, **3 rounds** each, **12 minutes** per
   builder run, **one** re-plan, model `sonnet` for builders, and a token budget policy of your choosing that you state
   up front. If the Planner returns more than three packages, send it back once with that limit.
3. Do not help the builders. You may fix the Foreman when the Foreman is at fault (a bad prompt assembly, a wrong
   allowlist, a parsing bug), journal each such fix, and rerun. You may **not** edit the pack, hand the builders code,
   or change the sentence. If the job fails honestly, that is a result: report why.
4. When it ends, in either state: `foreman status`, the `job.jsonl` path, per package the rounds, outcomes, seconds and
   tokens; the composability figures from lint; and look at the milestone captures yourself.

This is the first time a nested Claude session edits files under the Foreman's control. Watch for: the builder writing
outside its workspace; the builder running Godot itself (it should, through the allowlist, and only the runner
command); a builder waiting for a permission prompt (a hang until timeout: note it and fix the flags); the builder
claiming success that the verifier refuses.

## Acceptance (the Director will run these)
- `npm test` and `tsc --noEmit` pass; the new tests exist for Part 1 items 1 to 6.
- `foreman verify` on a snapshot example pack returns the real engine's reports for all verbs.
- The real job's directory exists under `site/` with a complete `job.jsonl` that `rebuildState` reads strictly, and the
  final state is truthfully `done` or `failed`.
- If `done`: the Director runs the five verbs on `site/<job>/pack/` against the snapshot and they pass.

## How to work
Small verified steps; journal after each in `foreman/JOURNAL.md` (append under a "WP3b" heading). Kill every process
you start, including stray `claude`, `node` and Godot children; never kill others. No git. Network: `npm install` and
the CLI runs above. Never read, use or print any `ANTHROPIC_KEY_*` variable.

## Final message (your report, as text)
Status; Part 1 item by item; Part 2 differences between the fake and the real runner; Part 3 as a plain account: what
the Designer and Planner produced, what each builder did per round, what the verifier said, how it ended, seconds and
tokens per package and in total, Foreman fixes you made along the way, and what you saw in the captures; what this
says about running hockey through the same loop (what will break first); questions; minutes spent from real timestamps.

## Time-box
Until the list is done or **22:45 CEST today**, whichever comes first (check with `date`). Order if time runs short:
Part 2, then Part 1 items 1, 5 and 6, then Part 3, then the rest of Part 1. A usage limit can cut you off without
warning: keep the journal current.
