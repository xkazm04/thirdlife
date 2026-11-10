# WP3: the Foreman

You are the builder of **WP3** in Phase 0 of the Third Life feasibility spike. Third Life is a single-player sandbox in
which an LLM designer and builder agents construct whole mini-games (hockey, racing) as verified **packs** over a frozen
law kernel in Godot. You build the **Foreman**: the program that turns a player's sentence into a brief, a plan of
packages, builder runs, verification and promotion, and that can be killed at any moment and resume truthfully.

## Read first, in this order
1. `C:\Users\kazda\kiro\third-life\contracts\README.md` (ownership, global rules), then `JOB.md` (your log contract),
   `RUNNER.md` (the engine door you call), `PACK.md` and `pack.schema.json` (what builders produce).
2. `C:\Users\kazda\kiro\third-life\docs\FEASIBILITY.md` section 4, the paragraphs on L4 Foreman and the builder
   transport contract, and section 5 (verification stack).
3. `C:\Users\kazda\kiro\ai-registry\knowledge\software-engineering\llm-agent\runtime-and-io\agent-cli-transport\agent-cli-transport.md`
   (read-only; read that one document, never an `index.json`) and follow its golden path for `probe()` and `run()`.
4. `claude --help` and `claude -p --help` on this machine (Claude Code 2.1.322) for the real headless flags. Do not
   trust flags from memory.

## Your scope
`foreman/**` only (Node 24, TypeScript, npm; `foreman/JOURNAL.md`). Keep dependencies few (a JSON-schema validator and
a test runner are enough; Node's built-in test runner is fine). No web server, no UI: a library plus a CLI.

## What to build, in priority order
1. **Job log** per `JOB.md`: typed events, an append-only writer (one line per event, flushed), a strict reader
   (unknown type or key is an error), `rebuildState(jobDir)` that derives `state.json` from the log alone, and the
   resume rules. Property to test: for any prefix of a finished log, `rebuildState` succeeds and continuing gives the
   same package outcomes.
2. **Builder transport**: one `Builder` interface with `probe()` and
   `run({prompt, mode, cwd, schema?, model?, timeoutMs}) -> {ok, outcome, text?, json?, raw, durationMs, tokensIn?, tokensOut?}`.
   Outcomes `ok`, `timeout`, `truncated`, `error`, `refused` are typed, never thrown. Three adapters:
   - `fake`: deterministic, scriptable from a fixture (writes given files into `cwd`, returns given text, can fail,
     time out or truncate on cue). Every test uses it.
   - `claude-cli`: Claude Code headless. Prompt over **stdin, never argv**; modes are separate seams: `generate`
     (no tools, neutral temp cwd), `readonly-scan` (read tools only), `edit` (file tools inside `cwd`, plus a bash
     allowlist **derived from the package's own acceptance commands**, not hand-written); our own timeout that kills
     the process tree; detection of a truncated answer; token counts from the CLI's JSON output when present.
   - `messages-api`: a thin stub that implements the interface and returns `refused` with a clear message unless an
     API key variable the user names is set. Do not call the API.
   A dated **capability matrix** as data (`foreman/data/capabilities.json`: per adapter and version: output formats,
   schema support, tool restriction flags, ceilings), filled from what you observed, with the date.
   **Billing**: the probe reports whether a run would bill a subscription login or an API key, from the real
   environment (for example whether `ANTHROPIC_API_KEY` is set), and the Foreman writes the `billing` event before
   the first run. Never print or log a key.
3. **Verifier**: runs the `RUNNER.md` verbs by spawning `TL_GODOT` directly (no shell), with a timeout, parses the last
   stdout line and the report file, cross-checks exit code against `outcome`, and writes `verify` events. A builder's
   claim of success is never consulted. V5 is a seam only: `critic(captures[], rubric) -> {ok, scores, notes}` backed
   by a `generate`-mode builder run; implement it against the fake and leave the image hand-off documented.
4. **Planner and package loop**: given a `plan_set` (hand-written fixture for now), run packages in dependency order,
   up to N in parallel, each in `ws/<package>/`: prompt assembled from the package contract, the pack contract and the
   last verify report; builder run; verification; on failure the report goes back as the next round (limit 4); on
   success merge only in-scope files into `pack/`, then verify the whole pack at V0 to V2. Out-of-scope files are
   dropped and recorded.
5. **Designer and Planner prompts** as `generate`-mode calls with JSON schemas for the brief and the plan
   (`foreman/prompts/`), validated before they are accepted. Unit-test with the fake; see the live check below.
6. **Budget policy** (`tokens_per_hour`, `only_while_playing`, `overnight`): pause and resume as `budget` events, with
   a simulated rate-limit test. **Promoter**: copy a fully verified `pack/` to `<TL_ENGINE_DIR>/packs/<id>/` and write
   `promoted`.
7. **CLI** `foreman`: `probe`, `new "<sentence>"`, `plan <job>`, `run <job> [--adapter fake|claude-cli] [--parallel n]`,
   `status <job>` (a dense table: one row per package with state, round, last cause), `resume <job>`, `verify <dir>`.

## The engine is not ready yet
WP1 is writing the kernel in parallel; `engine/` may be empty or broken while you work. Do not read or write it. Test
the Verifier against a **fake runner**: a small Node script standing in for `TL_GODOT` that obeys `RUNNER.md` (verbs,
exit codes, last-line JSON, report file) and can be told to pass, fail, hang or print garbage. The real engine is
plugged in later by pointing `TL_GODOT`/`TL_ENGINE_DIR` at it.

## Live checks against the real CLI (small, and say what they cost)
The owner has approved spending their Claude subscription on this spike. Do exactly these and no more:
- `probe()` on `claude-cli` in the real environment (installed, version, logged in, billing mode).
- One `generate` run with a one-line prompt and a tiny JSON schema, to prove stdin prompt, JSON output and token
  counts.
- One `edit` run in an empty temp directory asking for a single small file, to prove the tool restriction and the
  timeout path work (then run it once more with a 1 s timeout to prove `timeout` is typed).
- One Designer call on the sentence "a ball-and-paddle game in a walled court" to see a real brief validate.
You are yourself running inside a Claude Code session: a nested `claude` call may behave differently (environment
variables such as `CLAUDECODE` are set). If it refuses or misbehaves, record exactly what happened and stop the live
checks; do not unset variables you do not understand, and never use any `ANTHROPIC_KEY_*` variable from the environment.

## Acceptance (the Director will run these)
- `npm test` in `foreman/` passes; tests cover: strict log reading, `rebuildState` on every prefix, kill-and-resume
  mid-package (no `promoted` package is rebuilt), a builder that claims success while the verifier fails (package does
  not promote; round increments; `failed` after the limit with `cause: verify_failed`), out-of-scope files dropped,
  timeout and truncation as typed outcomes, exit code and `outcome` disagreement flagged, budget pause and resume.
- `node dist/cli.js run <fixture job> --adapter fake` builds a three-package fixture to `promoted` against the fake
  runner; killing it mid-run (the test does this) and `resume` finishes without redoing completed packages.
- `foreman probe` prints adapter, version, auth and billing mode without spending tokens where the CLI allows.
- `tsc --noEmit` is clean.

## How to work
Small verified steps; journal after each in `foreman/JOURNAL.md`. Kill every process you start; never kill others.
No git. Network: only `npm install` and the live CLI checks above.

## Final message (your report, as text)
Status; what exists and what does not, against the priority list; test output summary; the live-check results with
tokens and seconds; the capability matrix as observed; how billing mode is determined; what you could not verify
without the engine; what in `JOB.md` or `RUNNER.md` turned out wrong or missing (proposed wording); lines of code;
questions; minutes spent from real timestamps.

## Time-box
Until the list is done or **21:45 CEST today**, whichever comes first (check with `date`). Leave the last 20 minutes
for the full test run and the report. A usage limit can cut you off without warning: keep the journal current.
