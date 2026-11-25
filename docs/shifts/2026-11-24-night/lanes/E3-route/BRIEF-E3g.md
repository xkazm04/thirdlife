# E3g: room to grow on the base, and the person's "no" heard (after real job 3, E5c)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-editor` (fast-forward it to hokej 4d6b5ad first:
`git -C <tree> merge --ff-only hokej` is the ONE git write you may do). Opus. 90 min. Absolute paths only; never `cd` in a
backgrounded line. Campaign + lane rules: `C:/Users/kazda/kiro/third-life/docs/shifts/2026-11-24-night/CAMPAIGN-RULES.md`.
STANDUP lines in your tree's `docs/shifts/2026-11-24-night/lanes/E3-route/STANDUP.md`; REPORT-E3g.txt at the end.

Owner (24 Nov ~23:20): "... game like this can be built by user from the editor ... user should have path even through
more iterations to get there". Read `docs/shifts/2026-11-24-night/lanes/E5-proof/PROOF-E5c.md` (real job 3) and
`REPORT-E3f.md`. Do not start real (paid) jobs.

## Fix, in this order
1. **(blocking growth) The base leaves no room for a game's own scripts.** The base is 5943 of lint's 6000 game-script
   lines (`engine/kernel/runner/lint.gd:9` MAX_PACK_LINES; mirrored in `foreman/src/testing/fake-runner-core.ts:271`),
   so any script package overflows and its builder asks the person a question he cannot judge (job 3's `banks`). A
   pack that declares its base (pack.json / the core route) counts only the lines it adds or changes against the
   limit: files byte-equal to `engine/templates/<base>/` are engine-owned, still linted, not counted. Exact rule in
   lint.gd + the fake runner identical; tests both ways (a base copy + 500 own lines passes; 6001 own lines fails; a
   base file edited counts). lint.gd is kernel: run `bash engine/tools/k.sh selftest` and the lint selftest blocks; say
   the exact lines in your report (the Director words the contract).
2. **A "no" the person gives on a builder's question reaches the critic as a drop** (job 3: "skip the bank-shot extras",
   yet the critic judged the stars and DOUBLE banners). Same path as dropped aspects (`phases.ts criticRubric`). Test.
3. **The Designer's retries fix all failing checks at once.** Job 3's first two starts failed after 3 attempts each, a
   different small check each time (playstyle 14 words, "widths", SKIN keys). Feed every failing check of an attempt to
   the next, and fix mechanical ones without the model where the fix is exact (trim, known key). Test with the real
   failure texts from `.claude/worktrees/hk-proof/.tl/proof-jobs-c/` (read-only).
4. **A sentence that names its own twist gets no other twist added** (job 3: "slow and fast patches and bumpers"; the
   concept added "banked goals count double"). `concepts.ts faithfulProblems`. Test.
5. If time remains: why the first lint of a fresh job workspace takes 3-3.5 min (all five real jobs); find the cause
   (class-cache import?) with a measurement, fix if cheap (e.g. the base's cache prepared once), else report.

## Acceptance
- Each fix a test failing before / passing after; foreman `npm test` 0 fail (count vs 366); `npm run build` clean;
  `tl check --tier fast` PASS; for item 1 also `k.sh selftest` and `selftest.sh lint` (or the block that holds lint).
- "landable E3g" in STANDUP.md, stop editing, return the report.
