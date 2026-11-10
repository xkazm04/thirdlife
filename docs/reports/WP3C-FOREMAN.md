# WP3c Foreman close-out: builder report and Director verification

Brief `briefs/BRIEF-WP3C-FOREMAN.md`. Builder wall time 21:15 to 21:44 CEST on 2026-11-10 (29 min; harness: 313,075 subagent tokens, 77 tool uses). No model was called in this pass.

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

## WP3c Foreman: final report

### Status
All nine items are built and each has tests named by item number. No real job was run and no model was called; `foreman probe` ran once (0 tokens, CLI 2.1.322, subscription). Godot never ran in `engine/`; files there were only read.

Results from runs made after my last edit:
- `npx tsc --noEmit`: exit 0.
- `npm test` without `TL_GODOT`: 132 tests, 128 pass, 4 skipped (the engine tests).
- `npm test` with `TL_GODOT` (snapshot engine, `TL_ENGINE_DIR` unset): 132 tests, 132 pass, 0 skipped.
- `init-fixture` plus `run --adapter fake`: exit 0, 56 events, `done`, promoted to `C:\Users\kazda\kiro\third-life\site\wp3c-fixture-20261110-1\promoted\game.paddle_court\`.
- No process of mine is left. Nothing changed under `site/_engine_snapshot` or `site/marble-run-three-marbles-20261110-1` since 21:14.

Two slips of mine, neither with any effect:
- I ran one `git status` by mistake (read-only, output discarded).
- A badly quoted shell command made bash try to run `kill` with plain words as arguments. Every call was refused and nothing was signalled.

### Item by item
New tests are in `C:\Users\kazda\kiro\third-life\foreman\src\test\wp3c.test.ts` (18 tests).

1. **Reference copy.** New `foreman\src\reference.ts`. `ref/` now also gets `seeds/README.md`, every seed pack (not `seeds/captures`), `kits/KIT.md`, `kits/LAYOUT.md`, `rigs/RIGS.md` and `style/STYLE.md` when the engine has them.
   - The builder prompt names each file and gives the order: read `ref/seeds/README.md` first, copy the nearest seed, build the venue from the kit before making boxes.
   - Tests "1 reference" (3): an engine with seeds and kit, an engine without, and the repo's `engine/` and snapshot read as they are.
2. **Planner prompt.** `foreman\prompts\planner.md` and `designer.ts`. It lists what exists by name (36 kit parts, layout sections, rigs, style, seeds) plus the seeds' guide, read from `ref/`. It states the builder time limit as a number, the sizing rule (small playable root, later packages carry the rest), and the `art_pass` rule. The package limit stays a parameter.
   - `plan` now prepares `ref/` and takes `--builder-timeout-ms`.
   - Tests "2 planner" (2).
3. **`note` event.** The builder is asked for a `DEVIATIONS:` heading; `DEVIATIONS: none` gives no event. The text becomes `note {package, round, text}` straight after the `builder_run`. Every package that depends on it, directly or through another, gets it in its prompt.
   - Test "3 note".
4. **No visible change.** An `art_pass` milestone whose captures are all byte-identical to the previous milestone's logs `failed` with cause `no_visible_change`, then `queued` for the next round with that as feedback. No `milestone` event is written for that look.
   - At the round limit the package stays failed and its files leave `pack/` again (a `merge` event with `files: []` and `removed`).
   - A milestone that is not `art_pass` only gets a note in its summary.
   - Tests "4 no visible change" (3, one of them a kill between the two events) and "4+5 resume" (stop at every event, then resume).
5. **Critic.** "NOT ok" queues the milestone's packages for one extra round with the scores and notes as feedback. The second look writes the `milestone` event whatever the verdict. If the extra round itself fails, the package stays as merged and the job goes on.
   - Tests "5 critic" (2) and "4+5 resume".
6. **Capture frames.** 25 % and 75 % of `bot.frames` from the last passing report of the manifest's first bot; 120 and 480 without one. The first job's real report has that shape (`frames: 1207`, so 302 and 905).
   - Test "6 capture frames".
7. **Budget.** The CLI's result event carries cache reads in `usage.cache_read_input_tokens` (course_core in the first job: 2,137,798). This is recorded in `foreman\data\capabilities.json` under `tokenUsage`. The adapter reports it, `builder_run` logs it raw as `tokensCacheRead`, and the ledger counts it at 0.1.
   - The derived `budget.state` is `closed` once the job has ended.
   - Tests "7 budget" (2).
8. **Promotion.** The default is `<job>/promoted/<pack id>/`. `--promote-to engine` writes `<engine>/packs/<id>/` and falls back to the job directory when the engine is not writable. `--no-promote` still works.
   - Tests "8 promotion" (2).
9. **`foreman verify`.** The re-run rule did not hold there; it does now. A clock-based failure is run once more, both lines are printed, both reports are kept, and the second decides.
   - Test "9 verify".

Old tests I changed on purpose:
- `cli.test.ts` looks for the pack in `<job>/promoted`, and its `plan` calls pass `--no-reference`.
- `helpers.ts` keeps the older tests on `promoteTo: "engine"`.
- The event-type list has `note`.
- Two budget tests expect `closed` after the job ends.
- The WP3b milestone test no longer expects "NO VISIBLE CHANGE" on the fixture, because the fake runner's picture now depends on the pack's files.

### The two prompts
- **Printed copy:** `C:\Users\kazda\kiro\third-life\foreman\dry\wp3c-prompts-marble.txt` (1,727 lines). It holds the Planner prompt and the three builder prompts for the first job's sentence, brief and plan, against `C:\Users\kazda\kiro\third-life\engine`.
- **Command that prints them** (no model call), from `foreman/` in Git Bash:
  ```
  export TL_GODOT="C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"
  export TL_ENGINE_DIR="C:/Users/kazda/kiro/third-life/engine"
  node dist/cli.js prompts ../site/wp3c-dry-marble-20261110-1 --max-packages 3 --timeout-ms 720000 --round-limit 3
  ```
  The dry job `site\wp3c-dry-marble-20261110-1` holds only the first 10 events of the real log. The command writes `ref/` and `state.json` there and no event. `--planner-only`, `--builder-only` and `--package ID` narrow the output.

### Command lines for the second real job
From `C:\Users\kazda\kiro\third-life\foreman` in Git Bash. `dist/` is current.
```
export TL_GODOT="C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"
export TL_ENGINE_DIR="C:/Users/kazda/kiro/third-life/engine"

node dist/cli.js new "A marble run: three marbles of different materials roll down a zig-zag wooden ramp onto an ice sheet, and the one that slides furthest wins." --adapter claude-cli --model sonnet --auto-approve

node dist/cli.js plan marble-run-three-marbles-20261110-2 --adapter claude-cli --model sonnet --max-packages 3 --builder-timeout-ms 720000

node dist/cli.js run marble-run-three-marbles-20261110-2 --adapter claude-cli --allow-edit --model sonnet --round-limit 3 --timeout-ms 720000 --max-replans 1 --max-packages 3 --parallel 2 --budget tokens_per_hour:3000000
```
- `new` prints the job id; it is `...-20261110-2` if run today.
- Start `run` detached, not under a tool timeout. If it is interrupted, use `resume` with the same flags.
- The budget is in weighted tokens: the first job would have counted about 570,000. 3,000,000 is my suggestion for a runaway guard, not a measured need.
- The pack ends in `site\<job>\promoted\game.marble_run_three_marbles\`; the engine is not written.
- I checked that these `run` flags are accepted by running them with `--adapter fake` on a scratch fixture.

### What is still fake-only
Everything in items 1 to 8 has run only against the fake adapter and the fake runner. Specifically:
- No model has seen the new Planner or builder prompt, so whether a real builder writes the `DEVIATIONS:` heading is unknown.
- The byte comparison, the critic's extra round and the bot-derived capture frames have not run on real captures or with the live engine.
- The cache-read weighting is tested with scripted figures; the field name comes from recorded envelopes.
- Item 9 is tested with the fake runner's simulated load trip.
- The live `engine/` was only read (reference copy and prompts).

### Questions
1. **`tokensCacheRead`.** I added it as an optional key on `builder_run`, because the weighting needs the figure in the log. JOB.md does not list it. Proposed wording: "`tokensCacheRead` (the part of `tokensIn` read from the prompt cache, when the adapter reports it)".
2. **`budget.state`.** The event enum has no closed value, so I closed it only in the derived state (`state.json`, `status`); the last `budget` event still says `running`. Do you want a `closed` value in the event instead?
3. **`promoted.dest`.** In the job case it is `promoted/<id>` relative to the job directory, while the events table says `packs/<id>` relative to the engine. Is that acceptable?
4. **Send-back logging.** `cause` is only allowed on `failed` and `blocked`, so no visible change is `failed` then `queued`, and the critic's round is `queued` with a `detail` starting "critic (V5) NOT ok, one extra round". Is a fixed `detail` prefix acceptable as the marker?
5. **Cost of the critic's round.** In the first job the critic said NOT ok three times. With this rule that is up to one extra builder run per package, each up to 12 minutes. `--no-critic` switches the critic off entirely; there is no flag for a critic without the extra round. Do you want one before the run?
6. **Comparison gap.** Captures are compared only for the same camera and frame. If a package changes the frame at which the bot finishes, the frames differ and an art pass cannot fail for no visible change. Should the Foreman re-capture the previous milestone's frames in that case?
7. **Stale dependants.** A package already building when its dependency is sent back keeps working on the older files; the merge gate (lint and smoke on the whole pack) is the only check. Acceptable for the spike?
8. **First look's images.** A second look at a milestone overwrites the first look's capture files; only the first critique report is kept. Keep both sets?

### Minutes spent
21:15 to 21:44 CEST by `date`: 29 minutes. The step-by-step record is in `C:\Users\kazda\kiro\third-life\foreman\JOURNAL.md`, section "WP3c".

---

## Director verification

Done 21:47 to 21:55 CEST on 2026-11-10, after the builder had stopped.

### What was re-run, and the result

| Check | Result |
|---|---|
| `npx tsc --noEmit` in `foreman/` | exit 0 |
| `npm test` with `TL_GODOT` set (snapshot engine) | 132 tests, 132 pass, 0 skipped, 82 s |
| `site/wp3c-fixture-20261110-1/promoted/game.paddle_court/` | exists: the fixture job ends promoted inside its job directory |
| `foreman/dry/wp3c-prompts-marble.txt` read: the Planner prompt's opening and sizing sections, and the whole builder prompt for the root package | as the brief asked: the kit's 36 parts, the layout contract, rigs, style and the three seeds are named; the 12-minute limit is stated with the first job's 10.8 minutes as the scale; the root is told to be the smallest thing that plays; an art package is told that an unchanged picture fails it; the builder is told to read `ref/seeds/README.md` first, copy the nearest seed, build the venue from the kit before boxes, and to end with `DEVIATIONS:` |

### What is not verified

Everything new here has run only against the fake adapter and the fake runner, as the builder says. The second real job
is the first live use of: the new prompts, the `DEVIATIONS:` heading, the byte comparison, the critic's extra round, the
bot-derived capture frames and the cache-read weighting. The Director did not read the Planner prompt's middle
(the embedded seeds guide, pack contract and API are copies of files verified elsewhere).

### Director's decisions on the builder's questions

1. `tokensCacheRead` on `builder_run`: accepted; `JOB.md` amended.
2. `budget.state` is closed in the derived state only; the event enum stays as it is.
3. `promoted.dest` relative to the job directory in the job case: accepted; `JOB.md` amended.
4. A fixed `detail` prefix as the marker of a send-back: accepted for the spike.
5. The critic's extra round stays on for the second real job: a recovery round has never run live, and this is the
   cheapest way to see one. Cost is bounded by the round limit and the 12-minute limit.
6. to 8. The comparison gap when the bot's finishing frame moves, stale dependants, and the overwritten first-look
   captures are accepted for the spike and recorded as known gaps.
