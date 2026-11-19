# Walker R4 verification

All runs used the lane worktree and Godot 4.7.2. Commands below run from the worktree root.

| Check | Command or procedure | Captured output |
|---|---|---|
| Hunt2 repros | `bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh <ID>` for `A13`, `H1-beam-trace` and `A5` | [Before](repro-before.txt) · [After](repro-after.txt) |
| Three new assertions | `"$TL_GODOT" --headless --path engine --script res://kernel/world/walks/walk_case_d.gd` | [Original body and caller](red-on-old.txt) · [Fixed](green.txt) |
| Case selection | Same command with `-- walk.coyote_limit` and `-- walk.unmatched` | [One match and zero matches](selection.txt) |
| Missing case line | Supplied the fixed run's output to block 450 with only the wall verdict removed. The completion line was still present. | [Block verdicts](missing-line-control.txt) |
| Walker suite | `bash engine/tools/selftest.sh walk.` | [Before](walk-before.txt) · [After](walk-after.txt) |
| Parkour | `bash engine/tools/tl.sh <verb> --pack=engine/packs/parkour`, adding `--test=tests/<bot>.gd` for each bot. Ran the reference script's verbs and the manifest's retry bot. Checked each process exit and the final verify report. | [Before](parkour-verbs-before.txt) · [After](parkour-verbs-after.txt) |
| Packs gate | `node devx/bin/tl.mjs check --tier full --only packs` | [Gate output](packs.txt) |
| Fast gate | `node devx/bin/tl.mjs check --tier fast` | [Gate output](fast.txt) |

The H1 repro prints PASS when the trace completes. Compare lateral position, displacement and speed on ticks 40–69. The independent wall test measures the settled range and peak speed across 45 ticks, then checks tangential travel under diagonal input.

For the red run, the saved original `world_body.gd` and `tl_biped.gd` were copied back and compared byte-for-byte with HEAD. The original biped uses the corresponding four-argument drive call. The same three assertions then ran after restoring the fixed files.

The historical [parkour helper's baseline output](parkour-before.txt) contains six successful verify reports. Its final shell status is 1 because its last empty-report check is false. The before/after comparison uses fresh per-verb runs and checks the actual process status, including the fourth bot.
