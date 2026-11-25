E2b cartridge (K1's agent): report for landable E2b
Worktree .claude/worktrees/hk-core at 4c24154 (hokej, your fast-forward), nothing committed by me. 00:22-00:40 (25 Nov).

THE RED TEST, AND WHY
`cartridge: the same verdict as the core's C++ ...` failed on the merged head because the corpus moved: K8's round 2
changed hockey.thirdlife.cartridge.json (game.contact) and its rules file, so case 11's text was no longer the one the
C++ verdict had been recorded on. The test stopped there, as it should.

But the corpus moving was not the whole story. Patch 0004's switches carry value RANGES:
TlSetRule refuses over_top_decel_mps2 outside 0..60 and sprint_restart_share outside 0..1. The TS reader knew only the
switch NAMES, so it would have accepted 61, -1 and 1.5 where the core refuses them. That is a real difference, and it is
fixed:
- foreman/src/cartridge.ts `ruleSwitches()` reads each `if (K == "<key>") { ... }` line of the patches together with its
  `if (Value < a || Value > b) return false;` range. It THROWS on a refusal it cannot read, so a future patch with another
  kind of check cannot silently make the two sides differ.
- validateRulesText refuses an out-of-range value ("rule "over_top_decel_mps2": 61 is outside 0..60
  (0004-over-top-decel.patch)").
- knownRules() stays as it was (the names).

DONE
- Corpus: +6 rules cases (every switch in range, decel 60 / 61 / -1, share 1.5, share as true). 112 cases: 26 shipped,
  68 edits, 18 rules files. The new switches are picked up from the patch files: carry_holds_body (0003),
  over_top_decel_mps2 0..60 and sprint_restart_share 0..1 (0004), plus net_carry_wall (0002).
- C++ verdicts re-recorded with tools/rink_validate.gd on the committed cores (thirdlife DLL from 9161bf7, patches
  0001-0004): 46 accepted, 66 refused. In foreman/src/test/fixtures/cartridge-cpp-verdicts.json.
- Parity: 112 of 112 equal. cartridge tests 6/6; the rules test now also checks the four switches and the 0..60 range.
- CARTRIDGE.md: the rules row lists the four switches and their ranges; the corpus counts are corrected to 112 cases,
  68 copies, 18 rules files. The first E2 text said "56 copies"; it was 68 then too.

FOR THE GLUE (not changed this round, it needs a DLL rebuild)
The core's message for an out-of-range value is misleading: native/glue/rink_rules.cpp turns every false from TlSetRule
into `unknown rule "over_top_decel_mps2" (not a switch of native/patches-thirdlife)`. The verdict is right, the words
are wrong. A one-line change ("unknown rule, or a value outside its range") plus `rink.sh build all` would fix it. The
TS side already names the range. Say if you want it.

GATES
- tl check --tier fast: 5/5 PASS.
- foreman npm test: 331 tests, 324 pass, 0 fail, 7 skipped (the suite's own: TL_GODOT and an old job directory).
- selftest rink.cartridge PASS, rink.variant PASS; catalog.py --check PASS.

FILES (uncommitted)
foreman/src/cartridge.ts, foreman/src/cartridge_corpus.ts, foreman/src/test/cartridge.test.ts,
foreman/src/test/fixtures/cartridge-cpp-verdicts.json, engine/cores/rink/CARTRIDGE.md, this REPORT.txt, a STANDUP line.

KERNEL LINES: none.
