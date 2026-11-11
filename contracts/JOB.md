# Job contract (tl.job/1): the Foreman's log

WP3 implements this. In Phase 3 the construction site renders **exactly this log**, so it is the seam between the
Foreman and the world. Nothing about a job's progress may exist only in memory.

## Files (one directory per job)

```
site/<job_id>/
  job.jsonl        append-only event log, one JSON object per line; the single source of truth
  state.json       derived (schema `tl.state/1`); rebuilt from job.jsonl by rebuildState(); safe to delete
  pack/            the game's pack as verified so far (merged package outputs only)
  ws/<package_id>/ a builder's scratch copy of the pack for one package
  reports/         tl.verify/1 files and builder transcripts, referenced from events by relative path
  captures/        milestone images
```

`site/` is at the repository root and is a build workspace: the engine's `res://packs/` holds promoted packs only.
`job_id` is `<slug>-<YYYYMMDD>-<n>`. Package ids are `^[a-z][a-z0-9_]*$`.

## Words

A **job** builds one pack (one game) from one approved brief. The Planner cuts it into **packages**: slices with
disjoint file scopes inside the pack, each with a wire-level contract and its own acceptance. A package is built in its
own `ws/<package_id>/`, verified there, and only then are the files in its scope merged into `pack/`.

Package states: `queued`, `running`, `blocked`, `verifying`, `promoted`, `failed`.
Milestones: `blockout`, `greybox`, `art_pass`, `tuned`.
Verifier levels: `V0` schema, `V1` lint, `V2` headless smoke, `V3` invariants, `V4` bot playtest, `V5` capture critique,
`V6` human.

## Events

Every event has `v` (always `1`), `seq` (integer, +1 per line, starts at 1), `ts` (ISO 8601 UTC), `job`, `type`.
Unknown `type` or unknown keys are errors when the log is read.

| `type` | Extra keys |
|---|---|
| `job_created` | `sentence` (the player's words), `packId`, `title` |
| `brief_set` | `brief` (object: `rules`, `arena`, `ai`, `controls`, `mood`, each a string), `estimate` (`{packages, wallMinutes, tokens}`) |
| `brief_approved` | `by` (`player` or `auto`) |
| `plan_set` | `packages[]`: `{id, title, milestone, deps[], scope[] (globs inside the pack), contract (string), acceptance[] ({level, verb, args}), registers ({capabilities[], assets[], tests[], cameras[]}, each optional)}` |
| `package_state` | `package`, `state`, `round` (integer, starts at 1); `cause` (required when `failed` or `blocked`: one of `verify_failed`, `builder_error`, `builder_timeout`, `builder_truncated`, `budget`, `dependency`, `question`, `cancelled`), `detail` (string) |
| `builder_run` | `package`, `round` (omit both for job-level runs: Designer, Planner, critic), `adapter` (`claude-cli`, `messages-api`, `fake`), `mode` (`generate`, `readonly-scan`, `edit`), `model`, `outcome` (`ok`, `timeout`, `truncated`, `error`, `refused`), `durationMs`; `tokensIn`, `tokensOut` (when the adapter reports them), `transcript` (relative path) |
| `verify` | `package` (or omit for the whole pack), `round`, `level`, `verb`, `ok`, `report` (relative path), `exitCode` (omit when the runner did not exit by itself: spawn failure or killed on timeout), `after` (optional: the package whose merge this whole-pack check gates) |
| `merge` | `package`, `files[]` (relative to `pack/`), `removed[]` (optional: in-scope files the package deleted) |
| `question` | `package`, `text`; answered by an `answer` event: `package`, `text`, `by` |
| `milestone` | `milestone`, `captures[]` (relative paths), `summary` |
| `comment` | `milestone`, `text`, `by` (`player`) |
| `replan` | `reason`, `added[]`, `removed[]`, `changed[]` (package ids), then a fresh `plan_set` follows |
| `budget` | `policy` (`{kind: "tokens_per_hour" or "only_while_playing" or "overnight", limit}`), `state` (`running` or `paused`), `reason` |
| `billing` | `adapter`, `mode` (`subscription`, `api_key` or `none` for an adapter that bills nothing), `evidence` (which environment variable or login decided it; never the key itself) |
| `promoted` | `packId`, `version`, `dest` (`packs/<id>`, relative to the engine directory) |
| `job_state` | `state` (`running`, `paused`, `done`, `failed`, `cancelled`), `reason` |

## Rules

- **Resume.** A Foreman started on an existing `site/<job_id>/` reads `job.jsonl`, rebuilds state and continues. A
  package whose last state is `promoted` is never rebuilt. A package left `running` or `verifying` by a kill restarts
  that round from its `ws/` (or from a clean copy), and the log shows it as a new `package_state` with the same `round`
  plus `detail: "resumed"`.
- **Done is decided by the verifier**, never by the builder's words. A `builder_run` with `outcome: ok` moves a package
  to `verifying`, not to `promoted`.
- **Rounds.** A failed verification returns the `tl.verify/1` report to the same builder as the next prompt and
  increments `round`. Default limit 4 rounds per package, then `failed` with `cause: verify_failed`.
- **Scope.** Only files matching the package's `scope` are merged. A builder writing outside it is recorded
  (`detail`) and those files are dropped.
- **Idempotent.** Replaying any prefix of the log and continuing gives the same final `pack/` as an uninterrupted run,
  apart from what the builder itself generated differently.
- `billing` is written before the first `builder_run` of a job, from the probe, and shown to the player.

## Amendments of 2026-11-10 (after WP3)

- **The manifest is composed, not built.** `pack.json` is written by the Foreman from the job's `packId`, `title`,
  version and the `registers` blocks of the packages merged so far. No package's `scope` may include `pack.json`.
- **Merge gate.** Before a package's files are merged, the whole pack as it would be after the merge is verified at
  V0 to V2. Only then are `merge` and, for the last package, `promoted` written. `pack/` never holds unverified files.
- **Rounds and outcomes.** A builder run whose outcome is not `ok` consumes a round, except a rate-limit pause, which
  does not. `refused` fails the package at once. Dependants of a failed package become `blocked` with cause
  `dependency`. On resume, a round whose `builder_run` with outcome `ok` is already logged is not run again; only its
  verification is redone.
- **Re-plan on failure.** A package that fails after the round limit goes back to the Planner once (a `replan` event
  covering it and its dependants). At most three re-plans per job; then `job_state: failed`.
- **Milestones.** When the last package of a milestone is merged, the Foreman runs the `capture` verb for the pack's
  declared cameras, then the V5 critic, and writes `milestone` with the capture paths.
- **`budget.policy.limit`**: integer tokens for `tokens_per_hour`; `"HH:MM-HH:MM"` local time for `overnight`; omitted
  for `only_while_playing`. A rate-limit pause is written with `kind: "tokens_per_hour"` and no limit.
- **Environment.** Edit-mode builder runs do not inherit variables whose names contain `KEY`, `TOKEN`, `SECRET` or
  `PASSWORD`, apart from what the adapter's own authentication needs.
- **Other files a job directory may hold:** `foreman.lock`, `children.jsonl`, `foreman.config.json`,
  `ws/<package>.baseline.json`, transient `ws/_candidate_<package>/`, `reports/*.verdict.json`. A torn last line in
  `job.jsonl` (a kill mid-write) is tolerated on read, reported, and cut off when the writer opens.
- `job_created` carries a `packId` and `title` derived from the sentence; `brief_set` may refine the title.

## Amendments of 2026-11-10, second round (after WP3b)

- **`ref/`** is an allowed job-directory entry: read-only reference copies for builders (kernel `API.md`, law tables,
  example packs, the seed packs, `KIT.md`, `LAYOUT.md`, `RIGS.md`, `STYLE.md`).
- **`note` event** `{package, round, text}`: the deviations a builder states in its answer. The notes of a package are
  part of the brief of every package that depends on it.
- **Clock-based verdicts.** A verification whose only failure is clock-based (`budget`, `tick_timeout`) is run once
  more; both runs are logged and the second decides.
- **No visible change.** When every capture of a milestone is byte-identical to the same capture of the previous
  milestone, and the milestone is `art_pass`, its packages fail that round with the cause `no_visible_change`.
- **Critic.** A "NOT ok" verdict gives the milestone's packages one extra round with the critic's notes as feedback.
  After that round the job continues whatever the verdict; the verdict stays in the `milestone` event.
- **Capture frames.** 25 % and 75 % of the frame at which the first bot finished in its last passing report; 120 and
  480 when there is none.
- **Milestones are labels**, not ordered stages: one fires when its packages are merged.
- **Budget weights.** Cache-read tokens count at 0.1 against a token policy; raw figures are logged unchanged.
- **Manifest.** Version `0.1.0` at the first build; entry `scripts/main.gd`.
- **Promotion** writes to `<job>/promoted/<pack id>/` when the engine directory is not writable, so a job can always
  end `promoted`.

### Added after WP3c (2026-11-10)

- `builder_run.tokensCacheRead` (optional): the part of `tokensIn` read from the prompt cache, when the adapter
  reports it.
- `promoted.dest` is `promoted/<pack id>` relative to the job directory when promotion goes to the job directory, and
  `packs/<pack id>` relative to the engine otherwise.
- A send-back that is not a failure (the critic's extra round) is a `queued` event whose `detail` starts with
  `critic (V5) NOT ok, one extra round`. `no_visible_change` is `failed` with that cause, then `queued`.
- Known gaps, accepted for the spike: captures are compared only for the same camera and frame; a package already
  building when its dependency is sent back keeps the older files until the merge gate; a second look at a milestone
  overwrites the first look's capture files.

### Added after N3 (2026-11-11): change requests

- Command: `foreman change <job> "<text>" [--package <id>]`. Works on a job in any state after its first promoted
  package, including `done`; it refuses while another Foreman holds the job's lock.
- Events: `change_requested {text, package?}`; `reopened {package, reason}`. A `reopened.reason` that comes from a
  change request starts with `change request (event N)`, where N is the `seq` of the request. The reopened package is
  then `queued` with a detail starting `CHANGE REQUEST: `.
- After the owner merges again, every promoted dependant's acceptance runs on the merged pack (`verify` events whose
  report names contain `-reverify-`); only a dependant that fails is re-opened.
- A `done` job returns to `running` and ends `done` again. Each later promotion bumps the pack version to `0.1.<n>` and
  goes to `promoted/<pack id>@<version>/`; earlier promotions are kept. The last `promoted` event names the current one.
- A change that no round could make leaves the earlier verified files in place; the package is `promoted` again with a
  detail that says the change was not made.
- The critic's verdict may carry `package`: the package it holds responsible. Its extra round goes there through the
  same re-open path; an unknown or missing name falls back to the milestone's own packages and writes a `note`.
- Failure cause `kit_regression`: a round raised the bypass count or lowered kit use against the pack before the
  round. A `KIT:` line under the builder's `DEVIATIONS:` lets the round pass and is recorded as a `note`.
- `foreman follow <job> [--from <seq>]` prints each event as one JSON line as it is appended and exits 0 at a terminal
  state. It holds no lock.
- Notes the Foreman writes itself start with `[foreman] `.
- Files in a job directory added by this: `ws/<pkg>.carried.json`, `ws/<pkg>.kit.json`, `captures/promotion<n>-*`.
- Runner verbs and options come from `<engine>/kernel/runner/verbs.json`; a missing file is an error at start.
- Added after N3b: failure cause `machine_busy`. A clock-based failure (frame budget, watchdog time limits) is run
  twice; if both fail and the median frame is not itself over half the budget, the Foreman measures the machine with
  `smoke` on the engine's reference pack (`kernel/examples/pack_min`), waits and retries (`--clock-retries`,
  `--clock-pause-ms`), and only then blocks the package with `machine_busy` and pauses the job; `resume` verifies the
  same files again without a builder run. A busy-machine failure is never sent to a builder as feedback.
- `ws/<pkg>.members.json` lists the packages whose merged files a workspace holds; the workspace manifest is composed
  from the dependency closure plus those.
