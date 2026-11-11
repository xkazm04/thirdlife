# N3 Foreman change request: builder report and Director verification

Brief `briefs/BRIEF-N3-FOREMAN.md`. Builder wall time 00:04 to 00:59 CEST on 2026-11-11 (55 min; harness: 457,994 subagent tokens, 149 tool uses). No model was called.

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

N3 FOREMAN: FINAL REPORT (builder; 2026-11-11, 00:03 to 00:58 CEST)

## Status

All six items are built and green against the fake adapter and fake runner. Parts of items 1, 4 and 6 also ran on the real runner against `site/_engine_snapshot3`. No model was called; `foreman probe` only.

- `npx tsc --noEmit`: exit 0.
- `npm test` with `TL_GODOT` and `TL_ENGINE_DIR=site/_engine_snapshot3`: 156 tests, 156 pass, 0 skipped, 157 s.
- `npm test` without `TL_GODOT`: 156 tests, 151 pass, 5 skipped, all five with the reason "TL_GODOT is not set".
- `foreman probe --adapter claude-cli`: version 2.1.322, subscription (max), 0 tokens.
- No git command was run; `npm install` was not needed.

Two premises in the brief were wrong; both are handled and described under items 3 and 6. One older race in kill-and-resume surfaced under load and is fixed (see "Also fixed").

## Item by item

New tests are in `foreman/src/test/n3.test.ts` (23 tests) plus one in `foreman/src/test/engine.test.ts`.

### 1. Change request
- **Command:** `foreman change <job> "<text>" [--package ID] [--no-run] [run options]`. It records `change_requested {text, package?}` and then continues the job exactly as `resume` does.
- **Owner:** with `--package` that package is the owner. Without it the Planner is asked once (`prompts/owner.md`, logged as a job-level `builder_run`). If it gives no usable answer, the root takes it and the reason says so.
- **Re-open:** `reopened {package, reason}`, then `queued` at the next round with detail `CHANGE REQUEST: <text>`. The text stays in the package's brief for every later round. The round limit counts from the re-opening.
- **Dependants:** after the owner merges again, each promoted dependant's acceptance is run on the merged pack (`verify` events, report names `*-reverify-*`). Only one that fails is re-opened and rebuilt.
- **Second promotion:** a `done` job goes back to `running` and ends `done` again. The pack version becomes `0.1.<n>` and the new pack goes to `promoted/<pack id>@<version>/`; the first promotion is untouched.
- **Failed change:** if no round passes, the earlier verified files stay, the package is `promoted` again with a detail saying the change was not made, and the job ends `done`.
- **Answer:** `foreman answer <job> <pkg> "<text>" --change <package>` writes the `answer` and a `change_requested` for that package.
- **Pictures:** a pack that is promoted again is captured first (`captures/promotion<n>-<cam>-f<frame>.png`, no critic), with the paths in a note. This was not in the brief; I added it so you can see what a change did.
- **Tests:** seven tests named "1 change: ...". They cover the done job, the Planner as owner and its fallback, a failing dependant, a failed change, a kill between `reopened` and `queued`, `answer --change`, and the command line run twice with `status --json`.
- **Real runner:** "real engine, N3: ..." runs a one-package job, a change request and a second promotion on snapshot3.

### 2. The critic names the package
- The critic prompt now lists each package with the files it owns, and its answer has an optional `package`.
- A NOT ok verdict re-opens the named package through the same path; the milestone is written after that round and the second look.
- An unknown or missing name falls back to the milestone's own packages and writes a `note`.
- **Tests:** "2 critic: it names the ROOT package while an art package has just merged ..." and "2 critic: an unknown or missing package falls back ...".

### 3. Kit use cannot fall silently
- **Premise wrong.** The lint report has no `metrics`. The figures are under `composability` (`gdscript_lines`, `kit_parts_added`, `bypasses[]`), and there is no "kit parts used" figure at all. Evidence: `site/marble-run-three-marbles-20261110-2/reports/final-lint-s121.json` and `lint.gd` in snapshot3.
- **Built instead:** bypasses are `composability.bypasses.length` from the whole-pack lint. Kit use is counted by the Foreman: `"kind"` entries in `data/*.json` plus `TLKit.` and `TLRigs.` calls in scripts.
- A round that raises bypasses or lowers kit use is not merged: `failed` with cause `kit_regression`, then `queued` with the figures as feedback.
- A `KIT:` line under `DEVIATIONS:` (or plain words naming the kit, the bypass or the pattern) lets the round pass, and the reason is recorded as a note.
- Inside the critic's extra round a kit regression gets exactly one more round; after that the earlier files stay.
- `--no-kit-gate` switches the comparison off.
- **Tests:** four tests named "3 kit: ...".

### 4. Runner options from the engine
- `ACCEPTANCE_OPTIONS` and the fake runner's option table are deleted. `src/verbs.ts` reads `<engine>/kernel/runner/verbs.json`; the Planner prompt prints its option list from that file.
- A missing or broken file is a `VerbsError` at the start of `plan`, `run`, `resume`, `change` and `prompts` (exit 2, nothing written).
- The bundled fake runner uses its own engine file, `foreman/fixtures/engine/kernel/runner/verbs.json`. A test asserts it equals snapshot3's.
- **Tests:** three tests named "4 verbs: ...". One feeds the second real job's first Planner output (`reports/planner-a1-s6.json`, with `--bot-frames=4000`) to the plan check: accepted.
- **Real runner:** the engine test's plan uses `invariants --bot-frames=3000` and the real runner accepts it.

### 5. Follow
- `foreman follow <job> [--from SEQ] [--poll-ms N] [--idle-ms N]` prints each event as one JSON line and exits 0 at `done`, `failed` or `cancelled` in an event after SEQ.
- It holds no lock and reads only complete lines, so a torn last line is waited for and never printed. `paused` is not terminal.
- With `--from <last seq>` on a finished job it waits for what a change request appends.
- **Tests:** two tests named "5 follow: ...". By hand: `follow --from 56` printed events 57 to 83 of a `change`, once each, and exited 0.

### 6. Builders declare what a player may tune
- **Premise wrong.** `contracts/PACK.md` says the runner validates `footprint`, `params`, `on_leave`, `subject` and `moments`. But `kernel/runner/manifest.gd` in snapshot3 and in `engine/` (both dated 2026-11-10 18:59) knows none of them and treats unknown keys as errors. A `pack.json` with `params` fails lint on both.
- **Built instead:** the Foreman checks which of the five names the engine's `manifest.gd` contains. Only accepted fields are asked for and carried through; one a builder writes anyway is removed and recorded in the round's detail.
- **On tonight's engines** (none accepted) the prompt says: keep tunable values in `data/*.json`, do not add those keys, and end the answer with `TUNABLE: <file> <path> <min> <max> <step> <label>` lines. The Foreman does not parse those lines yet.
- **On an engine that accepts them** the prompt asks for `params` entries, and the fields survive merges, other packages' workspaces and promotion. Any other edit of `pack.json` is still undone.
- **Tests:** four tests named "6 ...". The real-engine test confirms `params` is kept out on snapshot3 and lint passes.

## Also fixed
- **Kill and resume race (older than N3).** When the Foreman's process tree is killed, the runner child dies a few milliseconds first. The Foreman then logged a failed verification (exit 1, empty stdout) and started the next round before dying. Under CPU load 2 of 12 kill-and-resume runs burned a round this way. A runner that ends with no output is now verified once more; 12 of 12 are clean afterwards.
- **Fake runner parity.** The fake now reports `invariants.bot_deterministic`, as the engine has since WP5.
- **Foreman notes.** Notes the Foreman writes itself start with `[foreman] ` and are not passed to dependent builders as deviations.

## Dry prompt
`C:\Users\kazda\kiro\third-life\foreman\dry\n3-prompts-hockey.txt` (159 KB), in five parts:
1. the Planner prompt;
2. three builder prompts, round 1;
3. the root's prompt after a change request;
4. the critic prompt and the owner prompt;
5. the manifest section as it reads on an engine that accepts the optional fields.

The job behind it, `foreman\dry\ice-hockey-three-against-20261111-0\job.jsonl`, has a hand-written brief and three-package plan, because the Designer and Planner are model calls. The real job's brief and plan will differ.

## Command lines for the real hockey job

Run from `C:\Users\kazda\kiro\third-life\foreman` in Git Bash; `dist/` is current. The engine must have `kernel/runner/verbs.json`; snapshot3 does.

```
export TL_GODOT="C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"
export TL_ENGINE_DIR="C:/Users/kazda/kiro/third-life/site/_engine_snapshot3"

node dist/cli.js probe --adapter claude-cli

node dist/cli.js new "Ice hockey, three against three: skaters, a puck, two goals, first to three goals wins. I play one skater with WASD and shoot with space." --adapter claude-cli --model sonnet --auto-approve

node dist/cli.js plan ice-hockey-three-against-20261111-1 --adapter claude-cli --model sonnet --max-packages 4 --builder-timeout-ms 900000

node dist/cli.js run ice-hockey-three-against-20261111-1 --adapter claude-cli --allow-edit --model sonnet --round-limit 4 --timeout-ms 900000 --max-replans 1 --max-packages 4 --parallel 2 --budget tokens_per_hour:4000000

# second terminal, any time after `new`:
node dist/cli.js follow ice-hockey-three-against-20261111-1

# after `done` (or with --package <id> to skip the Planner's owner call):
node dist/cli.js change ice-hockey-three-against-20261111-1 "<what to change>" --adapter claude-cli --allow-edit --model sonnet --round-limit 4 --timeout-ms 900000 --max-replans 1 --max-packages 4 --parallel 2 --budget tokens_per_hour:4000000

# to watch only the change (N = events before it, from status):
node dist/cli.js follow ice-hockey-three-against-20261111-1 --from N

node dist/cli.js status ice-hockey-three-against-20261111-1
node dist/cli.js status ice-hockey-three-against-20261111-1 --json

# a builder's question (run exits 3, job paused):
node dist/cli.js answer ice-hockey-three-against-20261111-1 <asking package> "<answer>" --change <package to change>
node dist/cli.js resume ice-hockey-three-against-20261111-1 <same flags as run>
```

- **Job id:** `new` prints it; it is `ice-hockey-three-against-20261111-1` if no such directory exists under `site/`. The pack id is `game.ice_hockey_three_against`.
- **Limits I recommend:**
  - 4 packages.
  - 15 minutes per builder run, with the same number given to `plan`.
  - 4 rounds, because the kit gate can cost one.
  - 1 re-plan and 2 in parallel.
  - 4,000,000 weighted tokens per hour as a runaway guard (job 2 used about 574,000 in 15 minutes).
- **Detached:** start `run` and `change` detached, not under a tool timeout. If interrupted, `resume` with the same flags.
- **Engine:** `change` refuses while another Foreman holds the job's lock. Use the same `TL_ENGINE_DIR` for `plan`, `run` and `change`.
- **Flags:** the `change` flags were accepted with `--adapter fake` on a scratch fixture.

What to expect in the log beyond job 2:
- A plan that uses `invariants --bot-frames=...` is accepted.
- A round may end `failed` with cause `kit_regression`, then `queued` with "KIT REGRESSION: ...". A stated reason shows as a note starting "[foreman] kit figures got worse".
- A builder that writes `params` on this engine gets "the builder wrote params; this engine's manifest check does not accept that field yet" in the `verifying` detail.
- After a NOT ok critic: `reopened` with reason "critic (V5) NOT ok, one extra round (milestone X): the critic names this package", then that package's round, then `*-reverify-*` verifies of its promoted dependants, then the milestone. Or a "[foreman] the critic named no package" note and the old behaviour.
- A change request produces these events in order:
  1. `change_requested`;
  2. `job_state running: reopened by a change request (was done)`;
  3. one generate `builder_run`, unless `--package` was given;
  4. `reopened`, then `queued` with "CHANGE REQUEST: ...", then the owner's rounds;
  5. `merge` and `promoted`, then the reverify events;
  6. the final lint, smoke, invariants and bot;
  7. two `promotion2-...` captures and a "[foreman] pictures ..." note;
  8. `promoted` at version 0.1.1 with dest `promoted/game.ice_hockey_three_against@0.1.1`;
  9. `job_state done ... (promotion 2 of this job; the earlier one is kept)`.
- Exit codes: `run` and `change` give 0 for done, 3 for paused, 1 for failed.

## Still fake-only, never run live
- No model has seen the owner prompt, the critic's `package` field, or the new builder text (`KIT:`, `TUNABLE:`, the change-request sections).
- Re-verification and rebuild of dependants ran only on the fake runner; the real-engine job has one package.
- Kit figures were counted on real files only for `pack_min` and the marble pack. No real round has failed with `kit_regression`.
- Carrying optional manifest fields has only run on the fake runner, because no engine accepts them yet.
- `follow` has only followed fake-adapter jobs.

## Not built
- `foreman change` on a job another Foreman is running: it refuses on the lock; there is no inbox.
- A kill during the re-verification of dependants is not resumed as such; the final verification still runs every check on the whole pack.
- A change request does not re-run the milestone critic; it only takes pictures.
- `moments` are carried but capture frames still come from the bot's finish frame (finding 8 was not in this brief).

## Side effects to know
- Godot created `site/_engine_snapshot3/.godot/` (6 cache files, 00:32) on its first run with `--path` there. No source file of the snapshot changed.
- Nothing changed under `contracts/` or the marble job; `engine/` was only read.
- No node or Godot process of mine is left.
- `foreman\README.md`, which the brief names, does not exist; I did not create it.

## Questions
1. **Contract wording.** `contracts/JOB.md` is read-only for me. Proposed additions:
   - events `change_requested {text, package?}` and `reopened {package, reason}`;
   - cause `kit_regression`;
   - `promoted.dest` is `promoted/<pack id>@<version>` for a later promotion, with version `0.1.<n>`;
   - job-directory files `ws/<pkg>.carried.json`, `ws/<pkg>.kit.json`, `captures/promotion<n>-*`;
   - notes starting `[foreman] ` are the Foreman's own.
2. **Linking a re-open to its request.** The `reopened.reason` starts with `change request (event N)` and the reducer reads N. Is a fixed prefix acceptable, or do you want a key?
3. **Optional manifest fields.** Is reading `manifest.gd` for the key names acceptable as the test of what the engine accepts? A data file like `verbs.json` would be cleaner. `contracts/pack.schema.json` also lacks the five fields.
4. **Kit figure.** Should lint report a kit-parts-used figure in `composability`? The Foreman would then use it instead of its own count.
5. **Kit gate strictness.** A new package that adds any bypass must say why or loses a round. Is that what you want for hockey, or should the first merge of a package be exempt? `--no-kit-gate` exists for tonight.
6. **Promotion directory.** A later promotion goes beside the first as `<id>@<version>`, and the last `promoted` event names the current one. With `--promote-to engine` the newer pack replaces the older. Acceptable?
7. **Critic after a change.** Do you want the critic to look at the pictures taken after a change, at the cost of one call and possibly one round?

## Minutes spent
00:03:40 to 00:58:31 CEST by `date`: 55 minutes of the 80. The step record is in `C:\Users\kazda\kiro\third-life\foreman\JOURNAL.md`, section "N3".

---

## Director verification

Done 01:00 to 01:22 CEST on 2026-11-11, after the builder had stopped.

### What was re-run, and the result

| Check | Result |
|---|---|
| `npx tsc --noEmit` in `foreman/` | exit 0 |
| `npm test` with `TL_GODOT` and `TL_ENGINE_DIR=site/_engine_snapshot3` | 156 tests, 156 pass, 0 skipped, 129 s |
| `foreman/prompts/owner.md` and the kit lines of `foreman/prompts/builder.md` read | as described: the owner prompt asks for one package and a one-sentence reason; the builder is told a round that adds hand-built parts or drops kit parts is not merged unless a `KIT:` line says why |

### What is not verified

Everything here has run only against the fake adapter, apart from the one-package real-engine test. The hockey job is
the first live use of: the change request, the owner call, the critic's `package` field, the kit gate, re-verification
of dependants, `follow`, and the reading of `verbs.json`. The Director did not read the 1,400 changed lines.

### Director's decisions on the builder's questions

1. The contract wording: added to `contracts/JOB.md` ("Added after N3").
2. A fixed prefix on `reopened.reason` is accepted for the spike.
3. Reading `manifest.gd` for the names of accepted fields is accepted for now; a data file like `verbs.json` is the
   later fix.
4. Lint should report kit parts used; the next kernel pass adds it and the Foreman then drops its own count.
5. The kit gate stays strict for hockey, first merge included: what it costs is one of the things to measure.
6. Later promotions beside the first as `<id>@<version>`: accepted.
7. The critic does not look again after a change tonight.

The builder was right that two premises of the brief were wrong: lint has no kit-use figure, and no engine accepted the
optional manifest fields when the brief was written (the N4 merge adds them).
