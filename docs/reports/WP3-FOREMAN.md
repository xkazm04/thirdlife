# WP3 Foreman: builder report and Director verification

Brief `briefs/BRIEF-WP3-FOREMAN.md`. Builder wall time 18:53 to 19:45 CEST on 2026-11-10 (52 min; harness: 398,698 subagent tokens, 146 tool uses).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

# WP3 Foreman: final report

## Status
All seven items on the priority list are implemented and every acceptance check passes. Nothing was verified against the real engine, and three paths of the real `claude` CLI were never exercised (listed below). Finished at 19:45, two hours inside the time-box.

- `npm test`: 87 tests, 87 pass, about 20 s. The suite was at 77/77 on three consecutive full runs earlier; ten tests were added after that.
- `tsc --noEmit`: clean.
- No stray `node` or `claude` processes, no leftover temp directories, nothing written outside `foreman/`.

To re-run (from `C:\Users\kazda\kiro\third-life\foreman`):
```
npm install && npm test
node dist/cli.js init-fixture <tmp>/job
node dist/cli.js run <tmp>/job --adapter fake
node dist/cli.js status <tmp>/job
node dist/cli.js probe
```
`dist/` is git-ignored by the root `.gitignore`; `npm test` builds it. The fixture job carries a `foreman.config.json` that pins the bundled fake runner and promotes into `<job>/engine-out`, so the literal acceptance command needs no environment and never touches `engine/`. Running `fixtures/job-paddle` in place also works, but leaves run output there; `node fixtures/make-fixture.mjs` restores it.

## What exists, against the priority list
1. **Job log** (`src/events.ts`, `src/joblog.ts`)
   - Strict reader: unknown type, unknown key, missing key, null value, wrong `seq` or a changed job id are errors.
   - Append-only writer: one line per event, fsync, single-writer lock.
   - `rebuildState` derives `state.json` from the log alone and is tested on every prefix.
   - A torn last line (a kill mid-write) is tolerated, reported, and cut off when the writer opens.
2. **Builder transport** (`src/builder/`)
   - `fake`: scriptable from a fixture, used by every test.
   - `claude-cli`: three separate mode functions; prompt over stdin; flags read from `data/capabilities.json`; our timeout with a process-tree kill; typed outcomes.
   - `messages-api`: a stub that always returns `refused`, as specified.
   - The edit seam's Bash allowlist is derived from the package's acceptance commands and carried in a per-call settings file outside the workspace.
3. **Verifier** (`src/verifier.ts`)
   - Spawns `TL_GODOT` directly with no shell and a timeout.
   - Cross-checks exit code, last stdout line and report file; a stale report is never reused.
   - V5 is a seam only: `critic()` in `src/designer.ts`, tested against the fake. The image hand-off is described in a code comment and was not exercised.
4. **Package loop** (`src/foreman.ts`)
   - Dependency order, N in parallel, one `ws/<package>/` each, round limit 4.
   - Out-of-scope files are dropped before verification and recorded.
   - Resume from any log line.
5. **Designer and Planner** (`src/designer.ts`, `prompts/`): generate-mode calls with JSON schemas, validated before acceptance, one retry with the rejection reasons.
6. **Budget and Promoter** (`src/budget.ts`, `src/promoter.ts`): three policies, pause and resume as `budget` events, a simulated rate-limit test; promotion copies to `<TL_ENGINE_DIR>/packs/<id>/`.
7. **CLI**: `probe`, `new`, `plan`, `run`, `status`, `resume`, `verify`, plus four I added: `approve`, `answer`, `cancel`, `init-fixture`.

## Deviations from the brief or JOB.md
- **Merge order.** The brief says merge, then verify the whole pack. I verify a candidate (pack/ plus the package's in-scope files) at V0 to V2 first and only then copy into `pack/` and write `merge`. JOB.md has no event to undo a merge, and this way `pack/` never holds unverified files.
- **`builder_run` without `package` and `round`** for Designer and Planner calls.
- **`verify.exitCode` is omitted** when the runner was killed or never started.
- **`billing.mode` for the fake adapter** is written as `subscription` with evidence "nothing is billed", because the contract has no `none`.
- **A `budget` event is written at the start of a run** to record the policy, so a resume without the flag still enforces it.
- **A non-ok builder run consumes a round.** `refused` fails the package at once; a rate limit does not consume a round.
- **Extra files in the job directory**: `foreman.lock`, `children.jsonl`, optional `foreman.config.json`, `ws/<pkg>.baseline.json`, transient `ws/_candidate_<pkg>/`, `reports/*.verdict.json`.
- **`run` defaults to the fake adapter**, while `new` and `plan` default to `claude-cli` and spend tokens.

## Not built
- **No re-planning on failure.** A failed verification goes back to the same builder; the Planner is never re-invoked. FEASIBILITY section 4 says failures return to the planner. A `replan` event is written only when `plan` is run again by hand.
- **Milestone captures.** `milestone` events are written with `captures: []`; the `capture` verb is never called by the loop.
- **In-scope deletions are not merged**; the `merge` event has no field for them.
- **`comment` events** are read but never written.
- **`only_while_playing`** reads a file named by `TL_PLAYING_FILE`; that is a seam, not a real signal.
- **Pack id mismatch** between the job and `pack.json` is caught only at promotion, not at the first merge.

## Live checks
Exactly the four in the brief plus the probe; no retries were needed. Model alias `sonnet` resolved to `claude-sonnet-5-5`. Cost is the CLI's own notional figure on a subscription login.

| Check | Outcome | Seconds | Tokens in | Tokens out | Notional cost |
|---|---|---|---|---|---|
| `probe` | available, logged in, subscription | 0.4 | 0 | 0 | 0 |
| generate + tiny schema | `ok`, `{"capital":"Paris"}` | 2.6 | 2,715 | 54 | $0.0114 |
| edit, one file in an empty temp dir | `ok`, `hello.txt` exact, nothing else written | 4.2 | 11,240 | 206 | $0.0106 |
| edit with `timeoutMs` 1000 | `timeout` (typed) | 1.2 | none reported | none reported | not reported |
| Designer on the sentence | `ok`, brief validated on the first attempt | 10.6 | 3,893 | 987 | $0.0254 |

Total reported: 17,848 in, 1,247 out. In the timeout run only the init event had arrived before the kill, so whether a request was in flight is unknown.

The nested session did not misbehave. `CLAUDECODE` and `CLAUDE_CODE_*` were inherited untouched; the child reported one `plugin_errors` entry (a path from `CLAUDE_CODE_PLUGIN_DIRS` not found) and a `messaging_socket_path`, and neither affected a run.

## Capability matrix as observed (`data/capabilities.json`, dated 2026-11-10, version 2.1.322)
- **Prompt channel**: stdin with `-p --input-format text`.
- **Output**: `stream-json` with `--verbose`; no non-JSON lines on stdout in four runs, stderr empty.
- **Schema**: `--json-schema` works with `--tools ""`. The CLI adds one tool named `StructuredOutput`, the run takes two turns, the answer is in `structured_output`, and `stop_reason` is `tool_use`, not `end_turn`.
- **Tool restriction (edit)**: the init event listed exactly `Edit, Glob, Grep, Read, Write`, `permissionMode` was `acceptEdits`, the model reported no shell, and `permission_denials` was empty.
- **Customizations**: with `--safe-mode`, `mcp_servers` was 0 and the generate context was about 2.7k tokens. Init still listed built-in agents, skills and plugins.
- **Ceilings**: the CLI offers no wall clock and `--help` has no `--max-turns`; our timeout is the only one.
- **Tokens**: `usage` in the result event; a killed run reports none.
- **Rate limit**: every run carries a `rate_limit_event` with `status` and `resetsAt`.

Never exercised live:
- a Bash allow rule being honoured, or a deny rule winning;
- a write outside cwd being refused by `--restricted`;
- `readonly-scan` mode;
- the Planner;
- a real truncation, rate-limit rejection or auth failure. Those patterns come from `--help` and synthetic envelopes only.

The adapter is also tested end to end against a stand-in `claude` executable (`src/testing/fake-claude.ts`) through the real spawn door, including Windows quoting of the empty `--tools` value and the schema.

## How billing mode is determined
The probe builds the child environment at one function (`childEnv`) and uses it for the probe and for every run:
1. `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN` set → `api_key`.
2. `CLAUDE_CODE_USE_BEDROCK`, `_VERTEX` or `_FOUNDRY` set → `api_key`.
3. Otherwise `claude auth status --json` (zero tokens): `authMethod=claude.ai` → `subscription`; any other logged-in method → `api_key`.

The evidence string names the variable or login, never a value. The Foreman writes `billing` before the first `builder_run`. If a run's own init event reports an `apiKeySource` that contradicts the probe, a second `billing` event is appended at once.

Only the subscription path was observed; the flip to key billing is unit-tested with a dummy value, not seen live. `--force-subscription` removes the metering variables at the spawn door.

## What could not be verified without the engine
- Whether Godot accepts the argument vector as written in RUNNER.md.
- The real report shape, `level` strings and exit codes.
- Whether the report is really the last stdout line under Godot's own output.
- Real timing against the Verifier's 10-minute default per verb.
- The capture window. I pass `--position 0,1440` for `capture` per `contracts/README.md`; RUNNER.md does not mention it.
- That a promoted pack loads.

The fake runner's pass and fail rules are mine, not the kernel's.

## Contract problems and proposed wording
**JOB.md**
1. `builder_run`: "`package`, `round` (omit both for job-level runs: Designer, Planner, critic)".
2. `verify`: "`exitCode` (omit when the runner did not exit by itself: spawn failure or killed on timeout)".
3. Whole-pack `verify` events do not say which merge they belong to; I encode it in the report file name. Proposed: an optional `after` key holding the package id, and "`round` is the round of the package being merged; 1 for the final gate".
4. Merge gate rule: "Before a package's files are merged, the whole pack as it would be after the merge is verified at V0 to V2. Only then are `merge` and `promoted` written."
5. `billing.mode`: add `none` for adapters that bill nothing.
6. `budget.policy.limit` has no type. Proposed: integer tokens for `tokens_per_hour`, `"HH:MM-HH:MM"` local time for `overnight`, omitted for `only_while_playing`. A rate-limit pause has no policy to name; I write `{kind: "tokens_per_hour"}` without a limit.
7. Resume: "A round whose `builder_run` with outcome `ok` is already logged is not run again; only its verification is redone."
8. State what a non-ok builder outcome does to the round counter, and that dependants of a failed package become `blocked` with cause `dependency`.
9. `merge`: add `removed[]` for in-scope deletions.
10. `promoted.dest`: I write `packs/<id>` relative to the engine directory; say whether that or `res://packs/<id>` is wanted.
11. `job_created` needs `packId` and `title` before the Designer runs, so I derive both from the sentence.
12. List the extra files a job directory may hold, and state the torn-last-line rule.

**RUNNER.md**
1. `lint` covers V0 and V1 in one report: say which `level` string it carries (I accept the report's, falling back to V1).
2. The default for `TL_ENGINE_DIR` is not written down; I assume `<repo>/engine`.
3. Say whether the caller passes `--position` for `capture`.
4. Say that the stdout line and the file agree in content, not byte for byte; I compare parsed values.

## Lines of code
| Part | Lines |
|---|---|
| `src/` without tests | 4,524 |
| Tests (`src/test/`) | 2,011 |
| Prompts and schemas | 188 |
| Scripts and the fixture generator | 307 |
| Data (capability matrix plus the generated event schema) | 1,144 |

## Findings worth knowing
- On Windows, hard-killing the Foreman takes its children with it, because Node starts non-detached children in a kill-on-close job object. A test pins this. `src/orphans.ts` keeps a pid ledger and an identity-checked reaper as a second line; the identity check is Windows-only.
- An edit-mode builder inherits the whole environment, including the unrelated `ANTHROPIC_KEY_LANE_*` variables, and with a shell grant it could read them. I added `--hide-env NAME,PREFIX_*` (also `TL_HIDE_ENV`); it hides nothing by default.
- The `tokens_per_hour` ledger counts cache-read tokens at full weight.

## Questions
1. **Manifest ownership.** `pack.json` belongs to one package, scopes are disjoint, and the whole pack must pass lint after every merge. A manifest that lists a later package's bot or generator therefore fails layout until that package lands, and no later package may register its own bot. The Planner prompt currently tells the first package to list only its own files. Do you want a shared-file exception for `pack.json`, a final assembly package, or lenient intermediate lint?
2. Should a failed package go back to the Planner, as FEASIBILITY says, and after how many rounds?
3. Is the candidate-first merge order acceptable, or do you want the literal merge-then-verify with an undo event?
4. Should `--hide-env` hide key-like variables by default for edit-mode runs?
5. Who triggers captures and the V5 critic at a milestone: the Foreman loop or a separate step?

## Minutes spent
18:53 to 19:45 by `date`: 52 minutes.

`C:\Users\kazda\kiro\third-life\foreman\JOURNAL.md` has the step-by-step record and is the resume point.

---

## Director verification

Done 19:46 to 19:52 CEST on 2026-11-10, after the builder had stopped.

### What was re-run, and the result

| Check | Result |
|---|---|
| `npx tsc --noEmit` in `foreman/` | exit 0, no output |
| `npm test` | 87 tests, 87 pass, 0 fail, 21 s |
| `node dist/cli.js init-fixture <tmp>` then `run <tmp> --adapter fake` | exit 0; three packages `promoted` (one of them in round 2 after a planted verify failure); pack promoted to `<tmp>/engine-out/packs/game.paddle_court`; 50 log events of 12 types |
| `status <tmp>` | the dense table: one row per package with state, round, runs, last verify |
| Kill and resume (Director's own: hard kill 1.6 s into a fresh run, then `resume`) | killed at 40 events with one package `verifying`; resume exit 0; 56 events; each package `promoted` exactly once; 4 builder runs in total, the same as an uninterrupted run; one `detail: "resumed"` event |
| `node dist/cli.js probe` | `claude-cli`: installed, logged in, **subscription** (`authMethod=claude.ai`), no API-key variable set, 0 tokens; `messages-api`: stub, not available |

So the acceptance list in the brief holds as far as it can be checked without the engine.

### What is not verified

- **Nothing has touched the real engine.** The runner the Foreman was tested against is the builder's own stand-in, with
  pass and fail rules the builder wrote. Whether Godot accepts the argument vector, whether the report really is the
  last stdout line, and real timings are open until WP1 is plugged in (first job of WP4).
- **The live CLI checks were not repeated** by the Director (they spend tokens and the builder's table is specific:
  17,848 tokens in, 1,247 out, four calls). Three seams were never exercised live at all, as the builder says: a Bash
  allow rule being honoured, `readonly-scan`, and the Planner. A real truncation or rate-limit response has not been seen.
- **No re-planning on failure, no milestone captures, no V5 critic run.** These are the gaps between this Foreman and the
  one Phase 1 needs.

### Director's decisions on the builder's questions (contracts amended on 2026-11-10)

1. **Manifest ownership.** `pack.json` is **composed by the Foreman**, not written by any builder. Each package declares
   in the plan what it registers (`registers: {capabilities[], assets[], tests[], cameras[]}`), and the Foreman writes
   the manifest from the packages merged so far plus the job's `packId`, `title` and version. No package owns it, so
   scopes stay disjoint and lint passes after every merge. (`JOB.md` amended.)
2. **Failed packages go back to the Planner** after the round limit: one re-plan of that package and its dependants,
   at most three re-plans per job, then the job fails. That matches the kill criterion in the spike plan. To build.
3. **Candidate-first merge is accepted** and is now the contract: verify the pack as it would be after the merge, then
   merge. (`JOB.md` amended.)
4. **Hide key-like environment variables from edit-mode runs by default**: names containing `KEY`, `TOKEN`, `SECRET`
   or `PASSWORD`, except what the adapter's own auth needs. The subscription login does not live in the environment, so
   this costs nothing. To build.
5. **The Foreman loop triggers captures and the V5 critic** when the last package of a milestone is merged. To build.

The other proposed wordings (job-level `builder_run`, optional `exitCode`, `billing.mode: none`, `budget.policy.limit`
types, resume rule, `merge.removed[]`, `promoted.dest`, extra job-directory files, the torn-last-line rule, the `lint`
level string, `TL_ENGINE_DIR` default, `--position` for `capture`) are accepted and written into `JOB.md` and
`RUNNER.md`.

### Size

4,524 lines of source, 2,011 lines of tests, 52 minutes of builder time, 398,698 tokens.
