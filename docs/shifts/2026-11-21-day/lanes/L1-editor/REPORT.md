L1 editor-quality: REPORT (shift 2026-11-21-day, worktree n21d-editor, base main 0553153/df58f0b, nothing committed)

OUTCOME PER ACCEPTANCE ITEM

1. Foreman tests green, with new tests for the room, the loop and the strips; the fast gate green.
   MET for the tests; the fast gate is MET except one contract text the Director owns.
   - foreman suite: 258 tests, 252 pass, 0 fail, 6 skipped (base: 250 tests; +8 in src/test/quality.test.ts).
     New tests: room 3 steps + revise once + verdict recomputed from scores/slop; round 2 final; word limits and a
     missing defensive verb sent back; handbook sections and slop ids; wire (concept/design/design_reviewed/serves/
     milestone round-kept-strips, strict); builders and the Planner read the design; loop keep-PREVIOUS restores the
     snapshot; hold (also with run_through), status names it, retry with a note, accept ends it; strips filmed and
     labelled, feel+slop in the rubric; stills only on an engine without --strip.
   - fast gate: foreman.typecheck PASS, assets PASS [4/4], cards PASS [3/3]; arch FAIL and devx.test 227/229 FAIL,
     both ONLY on verbs-contract "contracts/RUNNER.md verb 'capture': option --strip is not documented". RUNNER.md is a
     contract: the text is in PATCHES.md item 1. Every other arch rule passes (size-ratchet ok, context-map-cover ok).
   - full tier: see GATES below.

2. A fake-adapter job walks concept -> design -> review(revise) -> design -> review(ok) -> brief -> phases -> a NOT ok
   milestone -> 2 rounds -> hold -> quality accept -> done. MET.
   `foreman status` at each of the four stops: walkthrough-status.txt (this folder). The job log: v3-walkthrough-job.jsonl
   (104 events). Key events: 8 design_reviewed r1 revise ("...HUD number... Slop: hud_only_twist"), 9 design_reviewed
   r2 ok, 10 brief_set, 39-40 revise round 1 of 2 to court, 55 milestone round 1 kept new NOT ok, 56-57 round 2,
   72 milestone round 2 NOT ok, 73 job_state paused "quality", 74 comment "quality accept: ...", 75 running,
   96 greybox milestone ok, 103 promoted, 104 done. Stop 3 prints:
     HELD     quality: milestone blockout is still NOT ok after revise round 2
     critic   silhouette 0.8, readability 0.45, ... ; the court is a grey slab; the ball is hard to find
     answer   foreman quality <job> accept [--note "..."]   or   foreman quality <job> retry --note "<what to change>"

3. One REAL Designer run (claude-cli, opus) on "a fight in a colosseum", standard AND crazy. MET.
   room-standard.json and room-crazy.json (concept, design, design_reviewed, the brief, the runs). My judgement against
   the slop list and the owner's three arena complaints:
   - skill/playstyle design: YES. Standard: 5 verbs with frames (light 4/3/14, heavy 10/4/26 charge, guard with a 6 f
     parry, roll 22 f with i-frames 1-20, shoulder 14/6/22 that breaks guard), 3 weapons as playstyles (gladius and
     shield, maul, twin blades), skill ceiling parry / bank slam / shadow pin. Crazy: jab/heavy/shove/guard/roll with a
     strike>shove>guard>strike triangle, playstyles Wrecker / Duelist / Architect.
   - reactivity on hits: YES. TLHit.react on every hit by strength (0.3/0.7/1.2), TLHit.down only for stone slams and
     big hits, hit-stop on both 4-16 f (crazy 4-18), Smash-style knockback base + growth x percent over mass, whiff with
     no burst, shake scaled by force.
   - a movement roll: YES, defensive with i-frames (20 f standard, 18 f crazy), punishable recovery.
   - slop: none of the ten in either. Rivals have their own bodies, weapons and tells (Pip 0.9 scale 24 f wind-up,
     Brutus 1.35 maul 36 f charge, Livia reads repetition, Castor parries long charges); side-on orbit camera that
     avoids columns; no auto-face (aim with your feet); the twist changes the world (columns/walls collapse).
   - It does not read like last night's brief. Weak points I see: both runs chose the same concept family (smash
     rivals into stone that collapses: candidate likelihood 0.2 and 0.12), so the concept step escaped the duel but
     the two modes converged; crazy gives Sabine `cross_check` (a hockey clip) and the producer flagged it; the
     producer said ok at round 1 both times, so the revise path ran only in the fake tests. Cost: standard 3 calls,
     crazy 3 calls (the first crazy attempt failed: the review's notes were 84 words twice; fixed by a counted-words
     hint and 3 attempts for concept, design and review).

4. `foreman critique` on last night's crazy job with strips. MET. critique-crazy/critique.json (+ 3 strip JPGs).
   fight-colosseum-20261120-2, milestone tuned, 8 stills + 8 strips (all captured): NOT ok, silhouette 0.55,
   readability 0.4, style 0.7, shows_play 0.6, fun_promise 0.35, feel 0.1, slop 0. It names fighters_overlap (strip 9
   frames 86-101), camera_behind_scenery (strip 14 frames 2438-2458), hit_without_reaction (strip 10 frames 364-374:
   "no wind-up, no hit-stop hold and no flinch"): the owner's complaints, seen in motion.

5. `ui.sh selftest` and the site reader pass on a v3 job fixture. MET.
   ui.sh selftest: 195 passed, 0 failed. The strict site reader (kernel/world/site/event_schema.gd) and the panel model
   (ui/job_model.gd + job_v2.gd) on the walkthrough log: 0 of 73 (held prefix) and 0 of 104 lines rejected, no unknown
   types; held prefix reads phase paused, pause_kind "quality", job_reason "the critic still finds blockout weak: ...",
   design_reviews ["1 revise", "2 ok"], concept_pitch set; a log with strips passes; an unknown key in
   design_reviewed.scores is rejected. (Checked with a one-off Godot script; not a committed case: create_checks.gd
   is outside my column and counts exactly 12 fixtures. Proposed: add the walkthrough log as a fixture there.)

GATES
- foreman (npm test): tests 258, pass 252, fail 0, skipped 6.
- tl check --tier fast: FAIL arch [12/12] verbs-contract (RUNNER.md text, PATCHES.md 1); PASS assets [4/4]; PASS cards
  [3/3]; FAIL devx.test [229/229] 227 pass, 2 fail (the same rule); PASS foreman.typecheck.
- ui.sh selftest: 195 passed, 0 failed.
- runner strips (the sub-agent's run, re-graded by me on its numbers and the png): stills byte-identical before/after
  (pack_min 6fb5d0d5..., ex_down 6a9e0b53...); worker-level state hash with and without strip grabs identical
  (ex_down 93ecbbb8d520ba41 at 12x5, 2x5, 16x1; hockey 890bb53cc8942448); --strip=abc etc. exit 2 not run;
  selftest verbs.json_matches_host PASS; hockey 12x5 strip 2560x1080 in 6.6 s. NOTE: hockey stills were NOT
  byte-stable run to run even before the change (659dc6d0 vs 6b79e953): unrelated to this lane, worth a look.
- tl check --tier full: NOT PASSED, and not judgeable on this machine today (gate load 7.19).
  First run: stopped by MY OWN 58-min wrapper timeout during kit.selftest (exit 124): a stopped run, discarded.
  Second run (--only the Godot steps, no wrapper, 12:36-14:13):
    PASS kit.selftest [95/95]; PASS seeds [39/39]; PASS ui.selftest [195/195]; PASS world [8/8] (every game = alone);
    FAIL kernel.selftest [78/79]: 0 failed, 78 passed, then the 1800 s cap killed it (a stopped run, NOT a pass);
    FAIL item.selftest [36/37]: 0 failed, 36 passed, then the 600 s cap (stopped run, NOT a pass);
    FAIL packs [1/2]: hockey invariants.many_budget p50 1.027 ms vs the 1.0 ms budget (wall clock under load 7.19:
      BUSY, not evidence either way; last night quiet was 0.921). My only per-frame runner change is one integer test
      (strip_count > 0, false without --strip); not A/B-ed against the base on a quiet machine;
    NOT RUN perf (machine BUSY, use 74%).
  The Director's quiet full-tier run at landing is the real verdict for kernel, item, packs and perf.
- foreman.test inside the gate: PASS (also run alone: 258 / 252 pass / 0 fail / 6 skipped).

CHANGED FILES
New: docs/GAME-QUALITY.md (227 lines: design practice, feel numbers at 60 Hz, marketability, arcade lessons, LLM
failure modes, the slop list of 14 ids, 24 rules by role, 23 sources; written by a sub-agent from digest B with web
checks, re-read by me); foreman/prompts/concept.md, design-review.md, critic-compare.md; foreman/src/room_wire.ts (shapes
and checks), room.ts (the three steps), roomtext.ts (handbook sections, design text for Planner/builders),
quality_state.ts (the loop read from the log), quality.ts (film, judge, snapshot, compare, restore, send back),
cli_quality.ts (`foreman quality`, status lines), playercheck.ts (moved out of designer.ts for its line budget),
src/test/quality.test.ts.
Changed: foreman/prompts/designer.md (rewritten), planner.md, builder.md, critic.md, plan.schema.json (serves);
foreman/src/designer.ts, events.ts, foreman.ts (1976 -> 1898 lines: runMilestone delegates), cli.ts, cli_design.ts,
cli_critique.ts (strips), cards.ts (fun for the Planner), design_state.ts, joblog.ts, options.ts (strips), phases.ts,
rounds.ts, shots.ts, status.ts; foreman/data/job-events.schema.json (regenerated); tests cli, designer_v2,
editor_flags, place_calls, joblog, n3, wp3c, helpers; devx/lib/cards/brief.mjs (card fun prints for builders);
engine/kernel/runner/worker.gd, verbs.json (strip); engine/kernel/host/host.gd (line-neutral, OUTSIDE my column,
PATCHES.md 2); engine/tools/tl.sh (usage header, needed by the arch rule); engine/kernel/world/site/event_schema.gd;
engine/ui/job_model.gd (one line, still 600), job_v2.gd.

BEHAVIOUR CHANGES (each moved a test expectation; named)
- `foreman new` / `redesign` run the design room: 3 to 5 generate calls (roles concept, designer, design_review)
  before brief_set; design_reviewed events precede it. The Designer's answer must carry `design`. (cli, place_calls,
  editor_flags, designer_v2 tests: fake scripts gained the concept/review steps; event order and run counts updated.)
- The critic's "one extra round, then continue whatever" is gone (JOB.md 2026-11-21): up to 2 revise rounds, each
  looked at again with round/kept on the milestone event; still NOT ok -> job paused "quality", nothing promoted, no
  new package started. Detail/reason text is now "critic (V5) NOT ok, revise round <k> of <n> (milestone <m>)"; the
  old "one extra round" text is still read in old logs. (n3 "2 critic" x2, wp3c "5 critic" x2 and "4+5 resume":
  expectations rewritten to the new contract; the resume test now accepts the hold and kills at every event of both
  runs.)
- Builders: the priority line is now "make the acceptance pass AND land the feel sheet"; a Feel section (rules +
  handbook sections 2, 6 and the builder rules) appears only when the brief has a design doc.
- Planner: the root is "the core verb exchange with its whole feel sheet, on greybox"; "FEW files" became "no file the
  package does not need"; never cut the feel sheet; packages name `serves` (checked against the design's clip ids);
  default size "Four to ten packages" (was "Three to eight"; there is no hard-coded cap: --max-packages stays the only
  hard limit). (wp3c planner prompt test updated.)
- Milestones film one motion strip per filmed point when the engine's verbs.json has `--strip` (main will, after this
  lands): about 2x capture time per milestone (one 7-8 s run per point); critic calls carry up to 16 images.
- `foreman status` shows concept, reviews, rounds/kept per milestone, and the hold with its command.

QUESTIONS FOR THE DIRECTOR (also PATCHES.md item 3)
1. Land the RUNNER.md text (PATCHES.md 1): the fast gate's arch is red without it.
2. JOB.md says milestone `round` is 1 or 2; `retry` makes 3+. I accept any positive round. OK to amend?
3. The owner's answer to a hold is a `comment` event ("quality accept|retry[: note]"), no new event type. OK, or do you
   want a `quality_answered` event?
4. A critic that gives no usable answer (or is off) closes the milestone as before (it does not gate). The contract
   says quality is never auto-passed; I read that as "never on a verdict the critic gave". Confirm.
5. A first look that is NOT ok writes no milestone event (as before: not reached); its version is kept in
   reports/quality-<m>-r1/. OK?
6. host.gd is nobody's column; I changed it line-neutrally because a strip cannot be filmed without it.

NEXT THREE THINGS
1. The concept step converged on the same "slam into collapsing stone" idea in standard and crazy: feed the standard
   concept (or last night's pick) to the crazy concept step as "taken", and record the candidate pool per job so a
   re-run cannot pick the same family twice.
2. Commit the walkthrough log as a create_checks fixture (UI lane) and a site-reader case, so v3 keys are gated.
3. Give the critic the strip of each named clip moment first (aim the second filmed bot at the package that `serves`
   a clip), and have the Planner put the producer's last warnings into the root contract (done for `plan`; the
   re-plan path does not pass them yet).

==================================================================================================================
ROUND L1b (14:19-, same tree, base main 15d6ed5)

P0. A word limit must never kill a good design (the crazy proof fight-colosseum-20261121-2 died on
    "design playstyle 'murmillo' line has 17 words; at most 12"). MET.
   - foreman/src/repair.ts: when an answer's ONLY problems are length limits (proved by cutting each offending field to
     its limit: then the schema and every check pass), ONE repair call (role <role>_repair) lists each field with its
     path, text, count and limit and asks for those fields alone ({"fixes":[{path,text}]}); the Foreman merges them
     back and keeps everything else verbatim. A field still over after the repair is cut at its limit and the call's
     problems say so. Content errors (a missing defensive verb, a wrong id) make no repair: the 3 attempts as before.
   - Wired for the design step (BRIEF_LIMITS: pitch, aspects, every design text field, playstyle title 4 / line 12),
     the concept step, the review's notes and the Planner's phase `try` lines.
   - Fake test (quality.test.ts "repair:"): a design with two 20-word playstyle lines -> calls concept, designer,
     designer_repair, design_review (no second design attempt); only the two fields in the repair prompt; the rest
     verbatim; a stubborn repair answer is cut at 12 words; a content error beside the length problem goes to attempt 2.
   - REAL opus crazy room (room-crazy-l1b.json): the design step overshot once ("thraex" line 13 > 12); the repair call
     fixed it in 8.2 s (3081 tokens in, 230 out): "Small buckler: parry 10 f, roll 24 i-frames, guard 60 degrees".
     4 model calls in all; review ok (hook 0.8, gif 0.74, depth 0.78, feel 0.76, fit 0.85).

1. Crazy must not collapse onto the standard's idea family. MET.
   - foreman/src/concepts.ts: a crazy `new`/`redesign` reads the STANDARD jobs of the same sentence in the same site;
     their concepts go into the concept prompt ("Already designed: the STANDARD version ..."): a different idea family,
     not a variation, not one of its candidates; `why` names the family left. Without one, the crazy prompt forbids the
     most typical crazy move (for an arena: the arena breaking, falling stone, animals let loose) and asks for a rule
     bent (what scores, who you control, what a hit does, the audience, time), 4+ idea families among the 5. A crude
     guard sends back a chosen pitch+hook that shares most content words with a standard one (Jaccard > 0.4).
   - Proof, the same real run: the site held the standard job (room-standard.json: "slam rivals into columns that
     collapse"); the crazy concept prompt carried it; it chose candidate 1 (likelihood 0.12): "every clean hit rips the
     weapon from your rival's hands" (one golden gladius; possession, not health; references For Honor, Nidhogg disarm,
     NBA Jam on fire); `why`: "Left the standard's column-destruction and crowd-weapon families". Verbs: strike 4/3/14,
     strike_heavy 10/4/28, guard (8 f parry, defensive), roll (i-frames 1-20, defensive), taunt; playstyles Murmillo
     Wall / Thraex Dancer; crazy aspect "The Oiled Finale". The producer's notes name three frame contradictions
     (feint cancel window, parry vs guard arc, a missing clip name) for the builders.

2. The walkthrough log as a Create fixture with a site-reader check. MET in my files; the gate hook is PATCHES.md 4.
   - engine/ui/fixtures/create/c13-quality-hold (79 events) and c14-quality-done (112), from a re-run of the fake
     walkthrough on a fake engine that films strips (so `milestone.strips` is in them).
   - engine/ui/quality_checks.gd (new): 6 checks, all PASS headless: 191 of 191 lines through the strict site reader;
     all 13 new keys present; 5 broken copies refused (unknown scores key, verdict, score 1.5, kept "both", an absolute
     strip path); the panel model shows c13 paused, pause_kind quality, the critic's words, reviews ["1 revise","2 ok"];
     c14 done with no hold; Create's screen_of: c13 "building", c14 "done". create_checks.gd is not mine: the
     three-line hunk that runs it inside ui.sh selftest and kernel block 630 is PATCHES.md 4.

3. Clip moments first, and the producer's warnings on the re-plan path. MET.
   - shots.ts: a milestone package that `serves` a clip is filmed before a newer one that serves none; a shot carries
     its clip ids; its strips are labelled "CLIP MOMENT <ids> (its package serves it): MOTION STRIP ...", and the
     critic gets them FIRST (then the stills, then the other strips).
   - foreman.ts tryReplan passes the last design_reviewed notes; the Planner prompt carries "The producer's last review
     of this design (its warnings: make each one true in a contract)". Test: quality.test.ts "L1b: ...".

L1b GATES
- quality.test.ts: 11 tests (L1 8 + L1b 3: repair, crazy concept, clip-first with re-plan warnings).
- fast: PASS arch [12/12] (RUNNER.md --strip is landed), assets [4/4], cards [3/3], devx.test [229/229],
  foreman.typecheck.
- foreman suite: tests 261, pass 255, fail 0, skipped 6 (L1 landed with 258).

L1b CHANGED FILES
New: foreman/src/repair.ts, foreman/src/concepts.ts, engine/ui/quality_checks.gd (+ .uid),
engine/ui/fixtures/create/c13-quality-hold/job.jsonl, c14-quality-done/job.jsonl, lane room-crazy-l1b.json.
Changed: foreman/src/designer.ts (generate: the repair hook; Planner `try` limits; review into the re-plan prompt),
room.ts (limits per step; taken concepts), cli.ts and cli_design.ts (takenFor), foreman.ts (re-plan review),
shots.ts and quality.ts (clip strips first), prompts/concept.md ({{taken}}), src/test/quality.test.ts; lane
walkthrough log and status re-run with strips.

L1b BEHAVIOUR CHANGES
- A length-only overshoot now costs one small repair call (role <role>_repair, logged as a job-level builder_run
  with its transcript) instead of a whole new attempt or a failed job; a field still over is cut at its limit.
- A crazy job in a site that holds a standard job of the same sentence reads its concept (a new input to the prompt).
- The critic's images start with the clip-moment strips when a package serves a clip.
