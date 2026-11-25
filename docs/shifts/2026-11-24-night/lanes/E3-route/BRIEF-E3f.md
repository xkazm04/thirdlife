# E3f: a change keeps the person's game (the editor's change path, after the real proof E5b)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-editor` (branch hk-editor, at hokej 9a9126f). Opus. 75-90 min.
Absolute paths only; never `cd` in a backgrounded line. No git that writes. Campaign + lane rules:
`C:/Users/kazda/kiro/third-life/docs/shifts/2026-11-24-night/CAMPAIGN-RULES.md` (they bind; STANDUP.md lines in
`docs/shifts/2026-11-24-night/lanes/E3-route/STANDUP.md` of your tree, REPORT-E3f.txt at the end).

The owner (24 Nov ~23:20): "achieve game like this can be built by user from the editor ... user should have path even
through more iterations to get there". The real proof (read `docs/shifts/2026-11-24-night/lanes/E5-proof/PROOF-E5b.md`,
"Defects for the Director", and look at `e5b/b_j2_v010_vs_v011.jpg`) shows the iteration path broken: job 2's pirate
game (teal v gold, first to 1, 70x35) asked "make the goals bigger" and came back as plain HOKEJ. Real job folders for
evidence: `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-proof/.tl/proof-jobs-b/` (events 198, 201, 208 of job 2;
event 346 of job 1). Read them; do not run new real (paid) jobs: E5b re-runs after you land.

## Fix, in this order
1. **(blocking) A change never turns the game back into the base.**
   - On a core game, a change whose words map to cartridge keys (goal size, rink size, speeds, rules, teams) goes to the
     cartridge package, never the base. The owner question / Planner pick must not answer "base" for a cartridge key.
   - The base package's change round (if one is ever legitimate) never overwrites files another package owns (data/
     cartridge, rules, skin, match.json, the skin's banks); its note and its merge list must agree. Find why the note said
     "kept" while the merge listed them, and fix the cause.
   - Regression test from job 2's real shape: a promoted core game + "make the goals bigger" -> a cartridge diff on
     goal_width_m (or the core's goal key), skin and match.json byte-equal to v0.1.0.
2. **A cartridge diff lists only the files it changed** (job 1 event 346: match.json and the drill test byte-identical
   yet listed), so `fastchange.ts` takes the fast path. Compare bytes at the merge, or list from the diff. Test: job 1's
   "make it faster" shape stays on the fast path (runner calls as E4b's 7).
3. **The critic on a core game: base-owned reasons go to the person, not to revise rounds.** When the critic's NOT ok
   names the base / the core's behaviour / the base camera (things no package of the job can change), skip the revise
   rounds and raise the quality card at once, its text naming what the base does (job 1 lost ~89 of 140 min here).
   Reasons in the job's own scope still revise as today. Test both ways.
4. **The measured check fails a match that is over before a person plays.** Add goals a minute or match length to the
   judge (`rinkjudge.ts`), the band derived from thirdjam's modes the way `scripts/rink-goal-band.mjs` derives the goal
   band (cite the modes; sudden-death modes are legit short: the band comes from data, not your choice). Job 1 (first to 5
   in 1.2 min) and job 2 (first goal in 12 s) must fail or stop as the data says; hokej's own cartridge must pass.
5. If time remains: a change that cannot be seen (job 1 "the orange team is too strong" while the player's side wins 10/10)
   answers with the before figures instead of a silent no-op; and the promoted version carries a one-line "what changed"
   (foreman side only; say what Create would need to show it).

## Acceptance
- Each fix has a test failing before and passing after (name them); `npm test` in foreman 0 fail with the count vs 357;
  `node devx/bin/tl.mjs check --tier fast` PASS; `npm run build` clean.
- Replay of job 2's change decision against the fixed code (fake runner fed the real events' texts) shows the cartridge
  package picked and skin/match kept.
- "landable E3f" in STANDUP.md, then stop editing and return the report.
