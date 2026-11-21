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
| `job_created` | `sentence` (the player's words), `packId`, `title`; `answers` (optional), `lot` (optional): see "Added 2026-11-19" |
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
  After that round the job continues whatever the verdict; the verdict stays in the `milestone` event. (Replaced on
  2026-11-21 by "the quality loop": up to 2 revise rounds, keep the better, then hold.)
- **Capture frames.** A milestone films at most two bots. First the manifest's first test, at 25 % and 75 % of the
  frame at which it finished in its last passing report (the same shot every milestone, which the no-visible-change
  rule compares). Then the milestone's packages, newest merge first: the first one with an own acceptance bot (a
  test its acceptance runs and its `registers.tests` lists, not the first test) is filmed at 25 % and 95 % of the
  frame at which THAT bot finished. 120 and 480 for a bot without such a report. The first bot's captures keep the
  name `captures/<milestone>-<cam>-f<frame>.png`; the second bot's are `captures/<milestone>-<cam>-<bot stem>-f<frame>.png`.
  No visible change compares the first bot's captures only. The critic is told, per capture, the camera, the frame
  and which bot of which package was playing; `reports/critic-<milestone>-s<seq>.json` carries `shots[]`
  (`{capture, label}`).
- `foreman critique <job> <milestone> --out DIR` (added 2026-11-21): the milestone's captures and one critic call
  again on `pack/` as it is, writing only into DIR (captures, runner reports, `critique.json` with `dry: true`);
  nothing is written to the job.
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

### Added after P10 (2026-11-11): the change path, the inbox, the engine's verdicts, the player's check

- **Pack tests at a merge.** For a package that was re-opened (a `reopened` event) or is merged again, the whole-pack
  check before the merge runs, after `lint` and `smoke`, every test of the candidate's manifest that no package
  depending on the merging one answers for (a dependant answers for a test it registers and for a test its acceptance
  runs; those run right after the merge, in the dependants' re-verification). They are `verify` events without
  `package`, with `after: <pkg>`, report `reports/<pkg>-r<round>-pack-bot-<test>-s<seq>.json`. When a test of another
  package fails there, the same test is run on `pack/` without the round's files
  (`reports/<pkg>-r<round>-control-bot-<test>-s<seq>.json`). Control passes: the merge is refused, the round fails as
  for any failed check, and a note `[foreman] PACK TEST FAILED after the merge of <pkg> was tried: <test>, a test of
  package <owner>, ...` names both packages. Control fails too: a note `[foreman] pack test fails without this merge
  too: ...` and the merge goes on. `--pack-tests after_change|always|never`; default `after_change`.
- **A failed final verification after a promotion does not end the job.** The failure goes to one package:
  `reopened {package, reason}` whose reason starts `FINAL VERIFICATION FAILED (<n> of <limit>) at <verb> ...
  [report: <path>]. Sent back to <pkg>: <evidence>`, then `queued` with the same text as detail. That package gets
  ONE round. Which package: for a bot, the one that merged last after the state that the test's last passing run in
  the log saw; when nothing merged since, or the log has no passing run, the package that registers the test; for
  `lint`, `smoke` and `invariants` the package that merged last since the last promotion. Limit: `--final-rounds`
  (default: the round limit), counted from the last `promoted` or `change_requested`. When it is spent the job ends
  `job_state {state: "done"}` with a reason that starts `the change was NOT made:` and names the earlier promotion;
  there is no new `promoted` event and `pack/` keeps the unpromoted files. A job without a promotion ends `failed`
  as before.
- **Present values.** The prompt of a package that carries change requests has, under the requests, a section
  "The values as they are now": every `params` entry with its current value and range; the small values (numbers,
  booleans, strings up to 40 characters, lists of up to four numbers) of every `data/*.json`; the numbers the
  package's own scripts give to named keys. No model is asked and no event is written.
- **Inbox.** `<job>/inbox.jsonl`: one JSON object per line, appended in one write.
  `{id, ts, kind: "answer", package, text, by, change?}` or `{id, ts, kind: "change", text, package?}`; unknown keys
  are errors; a last line without its newline is not read yet. `foreman answer` and `foreman change` write there
  (exit 0; nothing is run) while another Foreman holds the job's lock, and write the log themselves otherwise, after
  what the inbox still holds. The lock holder reads the inbox when it starts, every `--inbox-poll-ms` (default 1000)
  while builders run, before it decides to pause, fail or finish, and once more before it releases the lock. Each
  entry becomes the event it would have been, with the entry's id in `inbox` (`answer.inbox`,
  `change_requested.inbox`: optional strings). An entry is taken when an event with its id exists; one that cannot
  become an event (no open question, an unknown package, nothing merged yet) is appended to
  `<job>/inbox.rejected.jsonl` with the reason and not tried again. An answered package is started again at once,
  while the other packages go on building. A change request taken while builders run re-opens its package only
  when that package is `promoted` and no builder is working on it; until then the request stays `pending` in the
  log, and it is applied at the latest when no builder runs any more (as at the start of a run).
  This replaces "it refuses while another Foreman holds the job's lock" in the section added after N3. `run`,
  `resume` and `cancel` still refuse.
- **Starved.** A runner result with exit 2, outcome `not_run` and an error of kind `engine` whose message begins
  `starved:` is the machine's, never the pack's: a note `[foreman] inconclusive: machine busy. the machine starved
  the run: ...`, the same pauses and retries as for a clock-based failure, then `blocked` with cause `machine_busy`
  and the job `paused`. Nothing is sent to a builder and the round is not spent. When the checks of a round report
  `metrics.starved_stalls`, the sum is in the `detail` of the `package_state` that ends the round (`promoted`,
  `failed`) or of the next `running`: `starved_stalls <n> (<ms> ms) in <k> check run(s) ...`.
- **Player check.** A plan in which a package registers the capability `input` must hold, in a contract, a line
  `PLAYER CHECK: tests/<bot>.gd fails when <what the human-controlled side can no longer do>`; the bot must be in a
  package's `registers.tests`. The plan check refuses a plan without it (first plan, re-plan, a hand-written plan).
- Files in a job directory added by this: `inbox.jsonl`, `inbox.rejected.jsonl`.

### Added 2026-11-17: recipe cards in a job; the construction site reads this log

- **`plan_set.card`** (optional string): the id of the `tl.card/1` card (`contracts/CARDS.md`) the Planner chose for the
  whole job, e.g. `"card.knock_down"`. Absent when no card fits (the key is omitted, never `null`). A `replan`'s fresh
  `plan_set` repeats it or omits it. The Planner sees every card under `ref/cards/` (each card's JSON and `INDEX.md`,
  the `tl cards list` table); a card id that is not in `ref/cards/` is refused by the plan check like an unknown key.
- **Builder briefs** of a job whose plan names a card carry the card's text exactly as `tl cards brief <id>` prints it.
- **Change not made.** When a change request ends without a promotion, `pack/` is put back to the last promoted pack
  (`promoted/<pack id>@<version>/`) before the job's state event. The put-back is logged as `merge` events (files back,
  `removed` the change's new files) before the job's state event; the unpromoted pack/ is kept in
  `reports/change-not-made-s<seq>/pack/`.
- **Kernel version.** A pack the Foreman writes declares the `KERNEL_API` of the engine it was built against
  (`engine/kernel/runner/manifest.gd`), read from that engine, never a constant in the Foreman.
- **The construction site** (`engine/kernel/world`, a lot with a `job`) reads `job.jsonl` and `promoted/` and nothing
  else of a job directory. It writes nothing there. A change to an event that the site draws is a change to this page.

### Added 2026-11-18: hand checks at final verification

- When the job's card has `hands` (`contracts/CARDS.md`), final verification runs every check on seeds 1..N as `verify`
  events (level V4, verb `bot`, report stem `final-hand-<hand>-seed<k>`). A failed bound means nothing is promoted and the
  job ends `failed` with the rows in its reason; after a change request, `pack/` goes back to the last promotion.
- (Added later the same night.) A plan whose card has `hands` must register each `tests/bot_hand_<hand>.gd` the card
  checks; the plan check refuses it otherwise. A failed hand check first sends every package that registers a failing
  test back for ONE round (`reopened` reason and `queued` detail starting `hand check failed`, with the rows); then
  final verification and the hand checks run again. Only a second failure since the last promotion or change request,
  or a failing test no package registers, ends the job unpromoted.
- Each hand check also leaves `reports/hand-checks-s<seq>.json` (`tl.hand-checks/1`: card, version, title, seeds, rows with
  their bounds); `foreman status`, `foreman explain` and the designer panel read it. The verify events stay the record.

### Added 2026-11-19: answers, lot and decision (the minigame editor)

Approved by the owner on 19 Nov (E2). All three keys are optional; absent means the job was not made in the editor, and
the reader behaves as before (absent = omit the key, never `null`).

- `job_created.answers`: object `{<question key>: <option id>}` from the card's `interview` (CARDS.md), one entry per
  question the player or a proposal answered. Every key is a question of the card the job was made from, every value one
  of its option ids.
- `job_created.lot`: `{at: [x, z], yaw_deg, radius}` in village metres: the lot the player placed. `radius` is the lot
  ring (half the footprint's diagonal + 4 m, at least 12). A village site that shows the job builds on this lot.
- `change_requested.decision` (optional): `{key, to}` when a change request was made by changing one decided answer in
  the editor: `key` is the question key, `to` the new option id. The `text` is still the request the builders read.
- Command: `foreman new` takes `--answers <json>` and `--lot <json>`; `foreman change` takes `--decision <json>`.
  Each is checked against the shapes above before anything is written; an invalid value is an error, not a dropped key.
- `foreman new --place-calls <json>` (added later on 19 Nov): the editor's "Find a place" model calls, written as job-level
  `builder_run` events (no `package`/`round`) right after the job is created, so `tl ledger` counts them. Proposed, not yet
  in the contract: an optional `role` on job-level `builder_run` (designer, planner, critic, placer).

### Added 2026-11-20: the designer v2 (pitch, aspects, creativity, phases)

Approved by the owner on 20 Nov (spark `designer-and-two-worlds`): the Designer aims at fun, shows a design as a few
aspects the player reacts to, has a creativity switch, and the build runs in phases the player tries and passes. Every new
key is optional; a job made before this reads as before (absent = omit the key, never `null`).

- `job_created.creativity` (optional): `"crazy"`. Absent = standard: serve the player's words. Crazy keeps the player's
  words and adds one or two unexpected mechanics on top; each is its own aspect with `crazy: true`.
- `job_created.run_through` (optional): `true`. Absent = the Foreman stops after every phase and waits for the player.
- `brief_set.brief.pitch` (optional on read, written by every v2 Designer): one sentence, at most 20 words, the game as a
  player would tell a friend.
- `brief_set.brief.aspects` (optional on read, written by every v2 Designer): 3 to 7 objects, chosen by the Designer for
  this game: `{id, icon, title, line, detail, alternatives, crazy?}`.
  - `id`: snake_case, unique in the brief.
  - `icon`: one of `player`, `rival`, `arena`, `goal`, `twist`, `camera`, `power`, `time`, `crowd`, `ball`, `vehicle`,
    `weapon`, `build`, `music`, `story`.
  - `title` at most 4 words; `line` at most 12 words; `detail` at most 60 words (the expert's expand).
  - `alternatives`: 2 or 3 `{id, title, line}` with the same limits; ids unique within the aspect.
  - `crazy`: `true` only on an aspect crazy mode added. Absent otherwise.
  `rules`, `arena`, `ai`, `controls`, `mood` stay and stay required: the Planner reads them.
- `aspect_reacted` (new event, before approval): `aspect` (an aspect id of the latest `brief_set`), `choice` (`"keep"`,
  `"drop"` or one of that aspect's alternative ids), `note` (optional string, the player's words). The latest reaction
  per aspect counts. A redesign (`foreman redesign <job>`) runs the Designer again with the sentence, the latest brief and
  the reactions, and writes a new `brief_set`; reactions to the old brief no longer count. `brief_approved` approves the
  latest `brief_set` together with the reactions that stand on it; the Planner sees both.
- `plan_set.phases` (optional on read, written by every v2 Planner): 2 to 5 `{id, title, try, packages}`, in build order.
  `try` (at most 12 words) says what the player can do when this phase is done. `packages` lists package ids; every
  package of the plan is in exactly one phase, and a package's deps are in its own phase or an earlier one. The first
  phase is the smallest thing that plays. A `plan_set` without `phases` runs as one phase, as before.
- `phase_done` (new event): `phase` (id). Written when every package of the phase is merged and the whole-pack checks after
  its last merge passed. Unless `run_through` is set, the job then waits: `job_state {state: "paused", reason: "phase"}`.
- `phase_reviewed` (new event): `phase` (id), `verdict` (`"pass"` or `"hold"`), `note` (optional string; required with
  `"hold"`), `by` (`player` or `auto`). `pass` starts the next phase (`job_state running`); after the last phase it lets
  the job go to final verification and promotion. `hold` with a note runs a change round on that phase's packages (the
  note is the request), then writes `phase_done` again. With `run_through` the Foreman writes `phase_reviewed {verdict:
  "pass", by: "auto"}` itself, right after `phase_done`.
- A job waiting on a phase is never a hang: `foreman status` names the phase and the command that answers it.
- Commands: `foreman new` takes `--creativity crazy` and `--run-through`; `foreman react <job> <aspect> <choice> [--note "..."]`;
  `foreman redesign <job>`; `foreman phase <job> pass|hold [--note "..."]`. Each checks its value against the shapes
  above before writing.
- Readers that mirror this table keep up: `foreman/data/job-events.schema.json`, `engine/ui/job_model.gd`,
  `engine/kernel/world/site/event_schema.gd` (strict: an unknown key there breaks the village site).
- Narrowings (21 Nov, from L2 and L3; the writer and every reader enforce them):
  - Alternative ids and phase ids are snake_case, like aspect ids.
  - No alternative id is `keep` or `drop`, so a `choice` always means one thing.
  - A `note`, where present (`aspect_reacted`, `phase_reviewed`), is a non-empty string; an empty note is an absent key.
  - The pause written after `phase_done` without `run_through` is `job_state {state: "paused", reason: "phase"}`.
  - The word limits stay strict in the site reader: the Foreman refuses to write an over-long line, so the reader never
    meets one from a v2 Foreman.

### Added 2026-11-21: the design room and the quality loop

Approved by the owner on 21 Nov (spark `game-quality-bar`). Every game is designed like a standalone game a small studio
must sell, and a milestone the critic finds weak is revised or held instead of shipped. Every new key is optional on
read; a job made before this reads as before (absent = omit the key, never `null`). Ids are snake_case.

- **The design room.** Before the first `brief_set` the Designer runs three steps:
  1. concept, which writes `brief.concept`;
  2. design, which writes `brief.design` together with the v2 fields (pitch, aspects, rules, arena, ai, controls, mood);
  3. review, which writes `design_reviewed`.
  A `"revise"` review runs the design step once more with the review's notes, then reviews again. Round 2 is final:
  whatever its verdict, the brief is set. A redesign (`foreman redesign`) runs all three steps again.
- **`brief_set.brief.concept`**:
  - `{candidates, chosen, why, hook, anchor, references}`.
  - `candidates` holds exactly 5 `{pitch, likelihood}`. `pitch` is at most 20 words; `likelihood` is a number in 0..1,
    the Designer's estimate of how typical the pitch is.
  - `chosen` is an index 0..4. `why` (at most 40 words) says why that one was chosen and the obvious one was not.
  - `hook` is at most 12 words, the novel thing. `anchor` is at most 6 words, the familiar genre.
  - `references` holds 2 or 3 `{game, borrow}`: a real game's name, and what to borrow from it in at most 20 words.
- **`brief_set.brief.design`** (the game design doc; text fields at most 30 words unless named):
  - `pillars`: exactly 3 `{line, rules_out}`.
  - `verbs`: 2 to 5 `{id, input, anticipation_f, active_f, recovery_f, cancel, defensive?}`. Frames are integers at
    60 Hz; at least one verb has `defensive: true`.
  - `playstyles`: 2 or 3 `{id, title, line}`. `title` is at most 4 words, `line` at most 12.
  - `loops`: `{s3, s30, m3}`.
  - `context`: at least 3 strings, the things that change the context within a match.
  - `skill`: `{floor, ceiling}`. `ceiling` is exactly 3 strings.
  - `feel`: `{hitstop_f, knockback, reaction, whiff, iframes_f, telegraph_f, shake, camera}`. `hitstop_f` is
    `[min, max]` frames, `iframes_f` and `telegraph_f` are integers, the rest are text.
  - `clips`: exactly 3 `{id, moment}`. `moment` is what a viewer would clip.
  - `first_minute`, `fail_state`, and `out_of_scope` (a list of strings).
- **`design_reviewed`** (new event, written by the review step before the `brief_set` it judged):
  - `{round, verdict, scores, notes}`.
  - `round` is 1 or 2. `verdict` is `"ok"` or `"revise"`.
  - `scores` is `{hook, gif, depth, feel, fit}`, each a number in 0..1. `notes` is at most 80 words.
- **`plan_set.packages[].serves`** (optional): a list of clip ids of `brief.design.clips` that the package brings closer.
  The Planner's first package is the core verb exchange with its whole `feel` sheet on greybox.
- **Builders read the design.** Every package prompt carries `brief.design.verbs`, `brief.design.feel`,
  `brief.design.clips` and the card's `fun` block.
- **The quality loop.** This replaces the 2026-11-10 "Critic" paragraph.
  - A `"NOT ok"` verdict gives the milestone's packages a revise round with the critic's notes; at most 2 rounds.
  - Before each round the Foreman snapshots the pack. After the round the critic compares the new captures with the
    previous ones.
  - The `milestone` event of a round carries `round` (1 or 2) and `kept` (`"new"` or `"previous"`). On `"previous"`
    the Foreman restores the snapshot.
  - Still `"NOT ok"` after round 2: the job writes `job_state {state: "paused", reason: "quality"}` and waits, also with
    `run_through`. Quality is never auto-passed.
  - `foreman quality <job> accept|retry [--note "..."]` answers it. `accept` continues as if ok. `retry` runs one more
    round with the note.
  - `milestone` without `round` is round 0, as before.
- **Motion strips.**
  - Each filmed point also writes `captures/<milestone>-<cam>-<bot stem>-strip-f<from>.png`: a 4x3 tile of 12 frames,
    5 frames apart, from frame `<from>`.
  - The `milestone` event carries `strips` (`[{capture, label}]`), and the critic sees strips and stills.
  - The "no visible change" rule compares stills only.
- **Readers keep up**: `foreman/data/job-events.schema.json`, `engine/ui/job_model.gd`, `engine/ui/job_v2.gd` and
  `engine/kernel/world/site/event_schema.gd`. The site reader takes `concept` and `design` as opaque objects, and
  accepts `design_reviewed` and the pause reason `"quality"`.
