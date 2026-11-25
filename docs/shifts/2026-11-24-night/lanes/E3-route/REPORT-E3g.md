E3g: room on the base for a game's own scripts, and the person's "no" heard (25 Nov 2026, after real job 3, PROOF-E5c.md)
Tree .claude/worktrees/hk-editor, fast-forwarded to hokej 4d6b5ad (the only git write). Nothing committed. No paid job was run.

GATES
- foreman npm test: 372 tests, 365 pass, 0 fail, 7 skipped. That is E3f's 365 plus 7 new tests in e3g_growth.test.ts.
- npm run build: clean.
- tl check --tier fast: PASS 5/5 (arch 12/12, assets, cards, devx.test 229/229, foreman.typecheck).
- bash engine/tools/k.sh selftest: 120 passed, 0 failed, RESULT PASS. Its import wrote engine/kernel/runner/lint_base.gd.uid.
- selftest.sh, the lint blocks:
  - "bad." (020-v0v1): 30/30;
  - "min.": 11/11;
  - the new 853-base-lines.sh: 6/6.
- The new lint on engine/packs/hokej, engine/packs/hockey and engine/templates/rink_game: all three pass.
- Before/after: a copy of the HEAD tree (git archive) ran e3g_growth.test.ts. 6 of the 7 tests failed there. The seventh tests
  designfix.ts's own functions, which do not exist at HEAD. Small stubs were added to that copy so the test file loads
  (refusals none, any twist word frees the concept, no base written).

1. THE BASE'S LINES ARE NOT THE GAME'S OWN (blocking growth)
The rule:
- A pack declares its base in pack.json: "base": "<name>", a directory of engine/templates/ that holds a pack.json.
- In a game script (any .gd outside tests/), a line is the base's when the base's file at the same path holds the same
  line. Line endings are ignored, and each base line can answer only one pack line.
- So a file byte-equal to the base's counts 0 lines. An edited base file counts its added or changed lines (a removed
  line costs nothing). A file the base does not have counts every line.
- The base's files are still linted (fence, the 600-line per-script cap, capabilities); they are only not counted.
- A pack without "base" counts exactly as before.
- An unknown base is a layout error: "declares the base 'x', but the engine has no templates/x/ ...".
- A base that is not a plain name is a schema error (pattern ^[a-z][a-z0-9_]*$, so "../kernel" is refused).

Exact engine changes (for the contract wording):
- engine/kernel/runner/manifest.gd, KEYS gains:
    "base": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$", "max": 64},
- engine/kernel/runner/lint.gd (still 600 lines, the arch budget):
    const LintBase: GDScript = preload("res://kernel/runner/lint_base.gd")   (after Manifest; one blank line removed there)
    var base: Dictionary = LintBase.resolve(m, lay)                           (before errors.append_array(lay))
    var total_lines: int = 0; var test_lines: int = 0; var own_lines: int = 0
    own_lines += 0 if top_dir == "tests" else LintBase.own_lines(src, base, rel, nlines)     (in the per-file loop)
    size_err.append_array(LintBase.size_errors(own_lines, total_lines - test_lines, test_lines, base, MAX_PACK_LINES))
        (replaces "if total_lines - test_lines > MAX_PACK_LINES or test_lines > 4000: size_err.append(...)")
    lint.size detail: "%d lines of GDScript%s, ..." % [total_lines, LintBase.detail(own_lines, base), data_bytes]
    _line_at: "return starts.bsearch(pos, false)" (one line shorter, same result)
- engine/kernel/runner/lint_base.gd (new, 63 lines, no class_name):
  - BASES_DIR "res://templates/";
  - resolve() returns {name, dir} or adds the layout error;
  - own_lines() does the line matching;
  - size_errors() builds the message;
  - detail() builds the detail text.
- Messages:
  - over the limit with a base: "6001 lines of game GDScript of its own (scripts/, gen/; at most 6000; 5943 more are the
    base templates/rink_game/ unchanged, not counted), 334 lines in tests/ (at most 4000)";
  - over the limit without a base: the same as before;
  - detail with a base: "N lines of GDScript (K game lines of its own over the base rink_game), B bytes of data".
- MAX_PACK_LINES (6000) and the tests/ cap (4000) are unchanged.
- KERNEL_API was not bumped (1.30). A pack that writes "base" fails on an older kernel ("unknown key"). The Foreman
  therefore writes the key only when the engine's manifest.gd names it. Director: decide whether this needs a minor bump.

Foreman, in step:
- foreman/src/testing/fake-runner-core.ts uses the same rule:
  - "base" is in OPTIONAL_MANIFEST_FIELDS with the same pattern;
  - the base is <--path engine>/templates/<base>;
  - baseOf() and ownLines() mirror lint_base.gd, with the same messages.
- foreman/src/manifest.ts:
  - composeManifest(job.base) writes "base" when a package of kind "base" is among the packages;
  - engineKnowsBase(engineDir) reads the engine's manifest.gd.
- foreman/src/foreman.ts jobIdentity(): base = coreRouteOf(template).base when the engine knows the key (always on the fake
  runner).
- Job 3's shape now: the base is 0 own lines and a script package has the full 6000 to itself. banks' 285 lines over
  (6228 - 5943) are 285 own lines.

Contracts the Director words (I did not edit contracts/):
- PACK.md, manifest table: optional "base".
- PACK.md "Size limits": the own-lines rule above.
- pack.schema.json: "base" (the fake runner skips the schema for it, as it does for the other optional fields).
- JOB.md: the Foreman writes "base" for a core game.

Tests:
- 853-base-lines.sh, on one copy of the base:
  - base.lines_own_500: the base plus 500 own lines passes;
  - base.lines_undeclared: 6443 fails, the old rule;
  - base.lines_own_6001: fails with the message above;
  - base.lines_edited_before / base.lines_edited: 5995 own lines pass, then 10 edited lines of main.gd make 6005 and fail;
  - base.lines_unknown: an unknown base is a layout error.
- e3g_growth.test.ts "E3g 1" (x2): the same cases on the fake runner, plus composeManifest and engineKnowsBase.

2. A "NO" TO A BUILDER'S QUESTION REACHES THE CRITIC AS A DROP
- joblog.ts: a PackageView keeps answered: [{question, answer}] (the open question paired with its answer).
- phases.ts criticRubric():
  - the fun_promise item carries refusalsText() beside personDecisionsText() (E3c's drops);
  - text: "THE PERSON REFUSED, answering a builder during the build (...): to package "banks"'s question "..." the person
    answered "No. ...". What the person refused or said to skip is DROPPED: it is not in this game, do not look for it,
    never score any item down or call the look NOT ok because it is missing, and treat a pitch, contract, clip moment or
    kill line about it as void."
- isRefusal(): an answer that starts with no, nope, nah, never, not, don't, do not, skip or drop, or that contains skip,
  drop, "leave ... out" or "don't add". A yes adds nothing.
- Test "E3g 2": job 3's own question and answer events.

3. THE DESIGNER'S RETRIES FIX EVERY CHECK AT ONCE
- generate() moved from designer.ts to foreman/src/generate.ts. designer.ts re-exports it (600 -> 525 lines). Changes:
  - (a) Every problem of an attempt is found: the content checks run even when the schema check fails, including the
    adapter's own schema refusal.
  - (b) Exact fixes are made without the model, before any repair call or retry:
    - a word overflow of at most 3 words (TRIM_MAX) is trimmed by trimWords() in repair.ts: articles first, never
      ending on a joining word;
    - then the role's exactFix. For the Designer this is foreman/src/designfix.ts:
      - WORLD bare units: "75 widths" -> "75 body widths";
      - "75 by 37 widths" -> "37 body widths";
      - a SKIN field written with another spelling of exactly one base skin field ("Team_Name" -> team_names).
    - An overflow of more than 3 words still gets L1b's one repair call.
  - (c) A retry hears every problem of the attempt, AND every problem an earlier attempt was refused for ("# Earlier
    answers were refused for these too ..."), plus "Fix EVERY problem above in this one answer ...".
- Real failure texts: foreman/fixtures/e5c/ holds job 1's and job 2's six real designer answers and their concepts (from
  hk-proof .tl/proof-jobs-c, read-only).
  - Job 1 attempt 1 (three 14-word playstyle lines) now passes with 1 model call. At HEAD it took 2 (designer +
    designer_repair).
  - Job 1 attempt 2 ("75 widths long") passes at once. At HEAD it was refused.
  - Job 2 attempt 2 ("75 by 37 widths") is fixed exactly.
- With E5c's SKIN fix and these changes, all six real attempts would have passed on the first call.
- Two older tests changed with the behaviour:
  - quality.test.ts "room": the hook over its limit is now 17 words, so it still exercises the repair call; 14 words is
    trimmed now.
  - e3c_room.test.ts: an open twist is now "pond hockey with a crazy twist"; see item 4.

4. A SENTENCE THAT NAMES ITS OWN TWIST GETS NO OTHER TWIST
- concepts.ts:
  - faithfulProblems() frees the concept only when the words leave the twist open (OPEN_TWIST_WORDS: twist, crazy,
    weird, wild, strange, surprise, unexpected, unusual, random, chaos, creative);
  - a sentence with "where the ..." / "but" / "lava" names its own twist: candidate 1 = that game with exactly that twist,
    chosen 0, highest likelihood.
- prompts/concept.md says the same in one new bullet.
- Real data: job 1's concept ("... and score goals worth double", candidate 2 of 5, likelihood 0.3 vs 0.85) is now
  refused with "name their own twist, so they ask for no other: choose the faithful reading, "chosen": 0, not candidate 2".
- Test "E3g 4".

5. WHY THE FIRST LINT OF A FRESH JOB TAKES 3-3.5 MIN (measured; not fixed)
- Lint itself takes 0.4 s on a fresh base copy (first and second run alike). Godot's first start, import and scan are
  ruled out.
- The time is the core's MEASURED CHECK (coregate.ts measuredGate). It runs before the round's lint and is logged under
  the lint event. Job 3's base round:
  - cartridge validator 08:58:05;
  - house check core-house-hokej.json 08:59:44 (99 s);
  - game check base-r1-measured 09:01:29 (105 s);
  - lint 0.38 s.
- The house check and the game check run in sequence, on different cartridges (hokej's thirdlife cartridge vs the base's
  hockey.regular).
- Inside each check (engine/cores/rink/lab/check_cartridge.mjs, `--defects`), the skate_only defect cell plays 16
  planning-hand matches in a row (73 s of a 76 s check). The other 7 cells wait for it.
- Cheap fixes, NOT made (another lane's module, and machine load), in order of value:
  - (a) split the defect cells by seed range in check_cartridge.mjs: 4 x 4 seeds gives identical per-match lines, about
    76 s -> about 26 s per check;
  - (b) cache measurements across jobs, keyed by (cartridge sha1, rinklab.exe sha1). The house check and the base's
    untouched cartridge are the same in every job;
  - (c) run the house and game checks with Promise.all (halves the wall time, doubles the load).
  - (a)+(b) would take the base round from about 204 s to about 30 s.
- Side finding: a host script that fails to parse ("Could not preload resource script res://kernel/runner/lint.gd", caught
  mid-edit) made the headless Godot hang instead of quitting. A verb would then stall until the Verifier's 10-minute
  timeout.

DEVIATIONS / NOTES
- Campaign rules 3-4 (frames, play) do not apply: no game or look changed.
- lint.gd is exactly at the 600-line arch budget. The rule lives in lint_base.gd so lint.gd does not grow (one blank line
  dropped, _line_at one line shorter).
- joblog.ts is at 600, foreman.ts at 1990 of its 2005 baseline.

FILES
- New:
  - engine/kernel/runner/lint_base.gd (+.uid);
  - engine/tools/selftest.d/853-base-lines.sh;
  - foreman/src/generate.ts;
  - foreman/src/designfix.ts;
  - foreman/src/test/e3g_growth.test.ts;
  - foreman/fixtures/e5c/ (8 JSON files).
- Changed:
  - engine/kernel/runner/lint.gd, manifest.gd;
  - foreman/src/designer.ts, foreman.ts, manifest.ts, joblog.ts, phases.ts, concepts.ts, repair.ts,
    testing/fake-runner-core.ts;
  - foreman/prompts/concept.md;
  - foreman/src/test/e3c_room.test.ts, quality.test.ts;
  - STANDUP.md.
