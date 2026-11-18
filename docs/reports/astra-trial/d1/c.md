# D1 arm C: Opus directing GPT 6.2 Astra (final report)

Start 13:05:48, report 13:59 (about 53 min of the 75-minute time box). All four acceptance lines are met.

## Acceptance
1. **Met.** Same case names and pass count. Baseline (frozen copy of the old script, 13:06-13:16) gave `selftest: 180 passed, 0 failed`. After the split (13:26-13:38) it gave `selftest: 180 passed, 0 failed`. The sorted `PASS|FAIL <name>` lists diff empty (180 lines), and the run order is identical too. Separately, I diffed the old lines 56-959 against the 30 block files in sort order, with only each file's new header removed: 868 non-blank lines, identical. Astra ran its own byte-level check: 84,577 bytes, equal.
2. **Met.** Filtered runs give the same verdicts before and after:

   | Filter | Before | After |
   |---|---|---|
   | `walk.` | 8 passed, 0 failed | 8 passed, 0 failed |
   | `site.` | 10 passed, 0 failed | 10 passed, 0 failed |
   | `ground.` | 1 passed, 0 failed | 1 passed, 0 failed |
   | `rig.` | 2 passed, 2 failed | 2 passed, 2 failed |

   The 2 `rig.` FAILs were already there before the change and are kept unchanged. `rig.biped_walks_and_skates` and `rig.vehicle_drives` are `kit_claim` cases. They read the `kit.bot` report, and the `rig.` filter does not run `kit.bot`. This is a bug in the old script, not one this change introduced; see Next.
3. **Met.** Two new blocks were added independently and touched no shared file. I added `selftest.d/995-lane-a.sh` and `996-lane-b.sh` (2 and 4 lines). `bash engine/tools/selftest.sh demo.` printed `PASS demo.lane_a`, `PASS demo.lane_b`, `selftest: 2 passed, 0 failed`, exit 0. I then removed both files. Astra's own run of the same proof, with the file listing and both files' contents, is in `docs/reports/astra-trial/d1/c-demo-proof.txt`. Two more checks passed:
   - A block that does not parse prints `FAIL selftest.d.<file>: does not parse`, and the run goes on (Astra tested this with a fixture).
   - Files whose names start with `_` are skipped.
4. **Met.** `node devx/bin/tl.mjs check --tier full` exited 0 (13:38-13:57). It found 942 units and completed all 942. All 14 steps passed; `kernel.selftest` was [180/180]. `tl check --tier fast` is green as well.

## Files changed
All of these were written by Astra except `docs/generated/REPORTS.md` and this status file.
- `engine/tools/selftest.sh` (961 to 73 lines) now holds only:
  - the header, which documents the convention;
  - the setup and the helpers (`report_of`, `check`, `verdict`, `field`, `number`);
  - a discovery loop that sorts `selftest.d/*.sh` in the C locale, skips `_*`, runs `bash -n` on each file and sources it in the main shell;
  - the old final two lines, unchanged.
- `engine/tools/selftest.d/010-min.sh` … `300-rig.sh`: 30 block files, numbered in steps of 10.
  - Each file starts with a short header comment.
  - Where a file depends on an earlier one, it has a `# needs:` line. For example, K2d and six other blocks use `p7_play` / `$OUTW` from `110-p7.sh`.
- `engine/tools/selftest.d/README.md`: the convention, the helpers table, the filter guard, the no-wall-clock rule and an example.
- `engine/tools/selftest.d/160-p14c.sh`: `world.tools_tr_filter` now scans `selftest.d/*.sh` as well. Otherwise the moved blocks would have dropped out of that check. A probe file proved it: FAIL naming the file, then PASS once it was removed.
- `devx/lib/gate/steps/kernel.mjs`: `paths` now includes `engine/tools/selftest.d/**`, so `--changed` still selects `kernel.selftest` when only a block file changes. Nothing else in `devx/` parses `selftest.sh`'s text; `counts.mjs` reads stdout.
- `.claude/spark/config.md` (lines 52-53): builders now get a `selftest.d/NNN-*.sh` file instead of appending to the tail of `selftest.sh`.
- `docs/generated/REPORTS.md`: I regenerated it with `tl arch --index`.
  - Before that, the fast gate failed `reports-index-fresh` and 3 devx tests.
  - The only cause was the untracked trial docs under `docs/reports/astra-trial/`.
  - If those trial docs are not committed, drop or regenerate this file.

## Next
- Fix the `rig.` filter bug carried over from the old script: `kit_claim` should also run when the filter matches the claim's own name, which means running `kit.bot` first.
- Consider giving `p7_play` / `$OUTW` a shared `_lib` file so that a filtered run of `k2.` or `k4.` does not depend on the P7 block.
- Have `tl arch` check that no two `selftest.d` files share a number.

## Astra (arm C)
- **Runs:** 3 launched, 2 productive.
  - Launch 1 hung on stdin: `codex exec` printed "Reading additional input from stdin" and created no session for 12 minutes. I killed my own process and relaunched with `< /dev/null`.
  - Run 1 did the whole implementation in 5.5 minutes.
  - Run 2 was a resume by session id for two corrections and took 1 minute.
- **Tokens:** "tokens used" printed 65,691 for run 1 and 74,310 for run 2. That second figure is most likely the cumulative session total; if not, the sum is 140,001. My own tokens are not visible to me.
- **Share of the work:** Astra wrote 100% of the code and docs in the deliverable (selftest.sh, the 30 blocks, README, gate paths, spark config). I wrote no lines in it. I made the briefs, the baseline and after runs, the independent equivalence and demo checks, the gate runs, the REPORTS.md regeneration and this report.
- **Where Astra was strong:**
  - The mechanical, high-volume split: 180 cases, byte-exact, order kept, with cross-block dependencies found and annotated without prompting.
  - It proved its own work with targeted checks: a byte-level equivalence check, a broken-block fixture, a probe for the tr scan.
  - It wrote a clean, idiomatic runner (C-locale sort through `mapfile`, `bash -n` guard).
- **Where it needed me:**
  - Coverage it could see but did not act on: it reported that `world.tools_tr_filter` would no longer scan the moved blocks, but did not fix it until I sent it back.
  - It dropped two header facts (the exit-code rule and the no-wall-clock law) while rewriting the header.
  - It left reports under `.tl/` in the worktree.
- **Where the harness needed me:**
  - The scratchpad is shared between arms: arm d4-c overwrote my first `astra1.log`, so I moved my files to a private folder.
  - `codex exec resume --last` is unsafe when several arms run at once, because another arm's session can be the "last" one. I resumed by session id instead.
  - The stdin hang above cost 12 minutes.
- **Overall:** with a precise design brief, Astra is a fast, reliable builder for refactors like this one. The Director's value was in the brief, in independent before/after measurement, and in catching the quiet coverage loss and the lost repo-law text.

## Log
- 13:05 start. Read brief; surveyed selftest.sh (961 lines), gate step devx/lib/gate/steps/kernel.mjs (paths list only names selftest.sh).
- 13:09 baseline: frozen copy engine/tools/selftest_baseline_tmp.sh (removed at the end) running full selftest in background -> scratchpad baseline.txt.
- 13:07 Astra run 1 started (brief: scratchpad brief1.txt: selftest.d/NNN-*.sh blocks sourced in C-sorted order, bash -n guard, verbatim move, header + README, gate paths, demo proof, text-equivalence check).
- 13:16 baseline: 180 passed, 0 failed (13:06-13:16); sorted names in scratchpad base_names.txt.
- 13:19 run 1 never started: codex exec waited on stdin ('Reading additional input from stdin') for 12 min, no session file; killed my own pid 43084 + child 45812. Also found the scratchpad is shared with other arms (my astra1.log was overwritten by arm d4-c): moved my files to scratchpad/d1c-private. Never using 'resume --last' (another arm's session can be the last); will resume by session id. Baseline filtered (frozen copy): walk. 8/0, site. 10/0, ground. 1/0, rig. 2 passed 2 failed (rig.biped_walks_and_skates, rig.vehicle_drives fail under the rig. filter BEFORE any change: they read the ex_kit bot report that only an earlier unfiltered case writes).
- 13:19 Astra run 1 started, session 01a1ee98-e473-7951-acf3-9a417c11a825. Confirmed rig. pre-existing filter FAILs: kit_claim reads report_of kit.bot, which the rig. filter does not run (old behaviour; to be kept identical, noted as a finding).
- 13:25 Astra run 1 done (13:19-13:25, 65,691 tokens): 30 blocks 010..300, 180 cases, text-equivalence byte-exact (Astra's check), bash -n guard tested with a broken fixture, gate paths + README + spark config + demo proof. Review: good; two follow-ups sent (tr-filter scan must cover selftest.d; restore two header facts lost).
- 13:26 Astra run 2 done (resume by id, 1 min, 74,310 tokens cumulative for the session as printed): tr scan covers selftest.d (probe FAIL then PASS), header facts restored, .tl/d1-c removed. My own equivalence check (strip only the new header per file): 868 non-blank lines identical to old lines 56-959 (before the intended 160-p14c change). Starting after-run full selftest.
- 13:27 removed the frozen copy. tl check --tier fast first FAILED arch reports-index-fresh + 3 devx tests: caused only by the untracked trial docs (docs/reports/astra-trial/*) entering the report digest (diff: 63 -> 68 reports, 5 astra-trial rows). Ran tl arch --index to regenerate docs/generated/REPORTS.md (Director: drop it if the trial docs are not committed).
- 13:38 after-run (13:26-13:38): 180 passed, 0 failed; sorted PASS/FAIL name list identical to baseline (180), run order identical; filtered walk./site./ground./rig. identical verdicts to baseline. Own demo: two new files 995/996 ran (2 passed) with no other file touched, then removed. Starting tl check --tier full.
- 13:58 full gate green 942/942 (13:38-13:57). Final report written.
