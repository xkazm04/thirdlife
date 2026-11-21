# L1 editor-quality: what the Director lands in files outside the lane's column

## 1. contracts/RUNNER.md: the capture verb's `--strip` (REQUIRED: `tl arch` fails without it)

The runner change is in this tree (`engine/kernel/runner/worker.gd`, `verbs.json`, a line-neutral `host.gd` edit, the
`engine/tools/tl.sh` usage header). The arch rule `verbs-contract` wants the option documented in RUNNER.md, which is a
contract, so the fast gate's `arch` and `devx.test` (arch.test.mjs:303, :313) fail on this tree until this text lands.

**The `capture` row, options column**, becomes:

`--cam=<name>`, `--frame=<int>` (default 120), `--out=<file.png>`, `--res=1920x1080`, `--hud=off|on` (default off: the
world alone; on: the pack's HUD is in the still), `--strip=<count>x<step>` (count 2..16, step 1..60; one png of count
frames step apart from `--frame`)

**After the "`capture` adds" line in the report section:**

- `capture --strip=<count>x<step>` (2026-11-21) films count views in one run, at frames F, F+step, ... F+step*(count-1),
  where F is `--frame`. Each view is taken before that frame is ticked, with the sim paused, so the sim and its frame
  counter advance exactly as in a run with no captures. The png is the views at half size, row-major in 4 columns
  (fewer when count < 4), rows = ceil(count/4): `--res=1280x720` with 12x5 gives 2560x1080. The `capture` object keeps
  its keys: `frame` is F, `width`/`height` are the tiled png's. The run ticks F+step*(count-1) frames. A malformed
  value is not run (exit 2).

## 2. engine/kernel/host/host.gd (no lane owns it)

Line-neutral (605 lines before and after, held by `devx/arch.baseline.json`): `"strip"` on the capture OPTIONS line, the
`--test` line became a loop over `["test", "strip"]`, one validation line, and the two-line `--out` removal became one
line. Landed in this tree because the strip cannot be filmed without it; named here because it is outside the column.

## 3. contracts/JOB.md: proposed wording (questions in REPORT.txt)

- `milestone.round`: the contract says "1 or 2". `foreman quality <job> retry` runs a third (and later) round, so the
  writer and both readers accept any positive round. Proposed: "`round` (1, 2, and 3 and up after a `retry`)".
- The answer to a hold is written as a `comment` event on the held milestone, `text` "quality accept" or
  "quality retry" (each optionally ": <note>"), `by: player`: no new event type. Proposed sentence under "The quality
  loop": "The answer is a `comment` on the held milestone whose text starts `quality accept` or `quality retry`."
- A first look that is NOT ok writes no `milestone` event (the milestone is not reached, as before); the version it
  judged is kept in `reports/quality-<milestone>-r1/` (pack/, the look's images, look.json). Each revise round k
  snapshots to `reports/quality-<milestone>-r<k>/` before it starts.
- A critic that gives no usable answer (or does not run) does not gate: the milestone is written, as before. Proposed
  sentence: "A look without a verdict (no critic, no usable answer) closes the milestone; quality is never auto-passed
  on a verdict the critic did give."
- A new version the critic scores ok is kept without a compare call (an ok version beats one it sent back).
- `job_created`/`builder_run` unchanged; job-level runs now also come from the roles `concept`, `design_review` and
  `critic_compare` (transcripts `reports/<role>-a<n>-s<seq>.json`).

## 4. L1b: engine/ui/create/create_checks.gd: run the v3 reader checks (ui/quality_checks.gd) with the Create checks

`engine/ui/quality_checks.gd` (new, L1b) checks the two new fixtures `ui/fixtures/create/c13-quality-hold` and
`c14-quality-done` (a real Foreman run with the fake adapter: room with a revise, plan with `serves`, two revise rounds,
the quality hold, `quality accept`, strips): every line through the strict site reader, all 13 new keys present, 5
broken copies refused, the panel model shows the hold with the critic's words, Create shows c13 building and c14 done.
Run alone it gives 6 PASS (`.tl/walk/qc.gd` in the L1 tree). To gate it in `tools/ui.sh selftest` and kernel selftest
block 630, three lines in create_checks.gd (SCREENS and its count of 12 stay as they are):

```diff
 const Dungeons = preload("res://kernel/dungeon/dungeons.gd")
+const QualityChecks = preload("res://ui/quality_checks.gd")   # L1b: the 2026-11-21 readers (fixtures c13, c14)
@@
-const CHECKS: int = 27
+const CHECKS: int = 27 + QualityChecks.CHECKS
@@ static func run(tree: SceneTree, check: Callable, tmp: String) -> bool:
 	_site(counted)
+	QualityChecks.run(counted)
 	check.call("create.complete: all %d checks ran" % CHECKS, count[0] == CHECKS, "%d ran" % count[0])
```
