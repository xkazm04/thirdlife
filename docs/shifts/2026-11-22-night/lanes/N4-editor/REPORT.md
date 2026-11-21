N4 editor-knowhow: REPORT (shift 2026-11-22-night, worktree n22-editor, base e6bbb13, nothing committed)

The editor now designs from proven genre templates. A melee fight copies DUEL-PLAYBOOK: its state machine, its move
frames (checked number by number), the contact table that changes both bodies, and the Wall, Duelist and Dancer
archetypes. A team ball game copies HOCKEY-ARCADE. Any other genre has to name its own reference. The first phase is
now a tofu stage, and the job holds there unless the tofu bot's metrics pass. The critic always lists the [H] items it
cannot judge. `foreman quality retry` records the answer and prints the resume command; it no longer runs the job.
I made two real Opus room runs and one real Opus Planner run on "a fight in a colosseum". Neither design is a generic
brawler.

OUTCOME PER ACCEPTANCE ITEM

1. The foreman tests are green, with new tests for the template choice, the tofu-stage hold and the retry fix. MET.
   - Suite: 271 tests, 265 pass, 0 fail, 6 skipped. The base was 261 tests, 255 pass and 6 skipped; the 10 new
     tests are in src/test/n4.test.ts.
   - Template tests (4):
     - a fight must copy the duel, and its copies must name the state machine, the mutual reactions and the
       archetypes;
     - a copied move must carry the table's frames exactly; a duel needs 3 or more copied moves, including an attack
       and a defence;
     - the room sends an invented core and paraphrased frames back;
     - the design step and the review read DUEL-PLAYBOOK, never the hockey research;
     - the Planner gets the duel excerpt and the tofu block;
     - builders get only their genre's implementable spec.
   - Tofu tests (4):
     - the six checklist items as metrics; an absent metric fails;
     - the duel's contact rows are checked;
     - plan checks: the TOFU CHECK line must be in the root and name every metric, and the tofu phase must be
       exactly the blockout milestone;
     - required for a fresh plan of a template brief; an older brief plans as before;
     - fail, then pass in round 1: the job goes on;
     - fail through round 2: the job holds with reason "quality", and status names the hold;
     - a passing critic does not pass a failing tofu stage.
   - Retry test (1): the answer is recorded as one comment event; no builder runs; the output reads
     "recorded; the job is not started. continue with: foreman resume <job> --adapter claude-cli --model opus
     --engine "C:/tl engine"". Resuming then runs revise round 3.
   - Critic test (1): the checklist block lists the [C] items frames can show and the [H] items they cannot; every
     critic answer ends with "[H] items not judged: a person must play it (items 2, 4, 13, 21, 26, 28, 30)".

2. Two real Opus room runs on "a fight in a colosseum", standard and crazy. MET.
   Files: room-standard.json and room-crazy.json in this folder. Both ran on claude-cli, opus, subscription.
   - STANDARD (job fight-colosseum-20261121-1; 3 calls; about 110k tokens in, 23k out; 226 s).
     - Template: duel, copied from "Dark Souls, Sekiro and For Honor duels, as docs/research/DUEL-PLAYBOOK.md". Its
       copies name the 6.4 state machine with the 8-frame buffer, the 2/6.3 mutual reactions, the 6.7 archetypes,
       and both move tables.
     - Verbs, each copying its move with exact frames: light 18/4/16, heavy 32/5/28, bash 14/6/24, parry 1/12/20,
       roll 3/18/15. Parry and roll are defensive.
     - The rules text carries the whole contact table with hit-stop on both fighters:
       - blocked heavy: the attacker bounces for 40 f, -22, and a light is guaranteed;
       - parried light: the attacker is PARRIED for 52 f, +44;
       - bash: GUARDBROKEN 30, or WALLSPLAT 60 with a wall within 1.2 m;
       - clash: both rebound for 20 f;
       - counter-hits.
       It also carries the stamina, posture, poise tiers and the EXHAUSTED state of 6.1.
     - Rivals: ORSO THE WALL, LIVIA FERRO THE DUELIST and KASS THE DANCER, each at its AI tier from 6.6, with the
       playbook's tells, plus a Title Defense at Champion tier.
     - Hook: "parries hurl rivals through stone walls that shatter and stay broken" (the arena changes for later
       rounds).
     - The producer passed it in round 1 (hook 0.8, gif 0.85, depth 0.85, feel 0.8, fit 0.85), with notes to fix
       Orso's shield clip and the breach-damage wording.
   - CRAZY (job fight-colosseum-20261121-2; 4 calls; about 121k tokens in, 30k out; 318 s). It read the standard
     design as taken.
     - Same template: duel. Its copies add Sekiro's posture deathblow.
     - Same five copied moves with exact frames, and the same contact table.
     - Hook: "every deathblow swaps you into the body you just beat". The leader always fights wounded, which is the
       visible comeback rule.
     - The bodies are the Wall, the Duelist and the Dancer. The rival souls (Old Varro, Sabina Quickhand, Little Ixi,
       and the Red Lion as champion) keep their habits in whatever body they take.
     - The concept's `why` says it left the standard's families (wall breaches, crowd weapons, chains, disarms).
     - The producer passed it in round 1 (0.85 / 0.75 / 0.8 / 0.8 / 0.85), with notes asking for a persistent marker
       on the player's soul and an orbit clamp.
   - My judgement against the owner's words. Neither design is a generic brawler. Both copy the core instead of
     inventing it. "Mutual reaction on attacks and collision" is written into each design, contact by contact, from
     the playbook's table. Each rival differs in its defence. Difficulty comes from the playbook's tiers, never from
     speed stats.
     - Weak point 1: the standard design's hook is again in the stone-wall family (L1 of 21 Nov also chose
       "slam into stone"). It now sits on a copied duel core, so it is a hook, not the game.
     - Weak point 2: neither run used the revise path for real; the producer said ok in round 1 both times.
   - Extra evidence, which the brief did not ask for: one real Opus Planner run on the standard job (plan-standard.json).
     - A single 571 s call (85k in, 59k out); its first answer was accepted.
     - It wrote the TOFU CHECK line on duel_core with the duel rows (contact_types, one_sided_contacts).
     - The tofu phase is duel_core plus rival_ai, both milestone blockout.
     - It pasted the metric rows and the contact table (PARRIED, BLOCKSTUN, WALLSPLAT, the attacker's recoil) into
       the root contract.
     - So a real Planner can satisfy the new plan rules. The Director's proof re-run will not stop at the plan step
       because of them.

3. The proposed JOB.md text is in PATCHES.md. MET. It is item 1: "Added 2026-11-22: genre templates and the tofu stage".

GATES
- foreman (npm test): 271 tests, 265 pass, 0 fail, 6 skipped.
- tl check --tier fast: all PASS.
  - arch [12/12]
  - assets [4/4]
  - cards [3/3]
  - devx.test [229/229]
  - foreman.typecheck
- The full tier was not run. Nothing in kernel, kits, rigs, style or seeds changed.

WORK ITEMS
1. docs/GAME-QUALITY.md v2.
   - The header says "Copy the proven core; be new only in the hook".
   - Feel numbers: visible feedback within 3 f and the full pose by 6 f (was "at most 6 f").
   - Section 5 adds "invented cores", and mode collapse now applies to the hook only.
   - Slop list: four new ids, appended after the old 14:
     - generic_brawler
     - one_sided_contact
     - oatmeal_variety
     - passive_ai
   - Rules by role, now 30:
     - Designer: the template rule;
     - Planner: the tofu rules;
     - Builder: contacts change both bodies, feedback within 3 f, the tofu bot measures;
     - Critic: judge the [C] items by number; end with the [H] line.
   - New sections:
     - 8: R1-R14, each saying where the pipeline checks it;
     - 9: the anti-patterns, with "10,000 bowls of oatmeal" in bold as our main risk;
     - 10: the 30-item checklist with [B]/[C]/[H] and a column naming who judges each item;
     - 11: the genre templates, with the duel move table the code checks;
     - 12: the tofu stage, with its metric table.
2. Genre templates (foreman/src/templates.ts).
   - The concept must carry `template` {id, reference, copies}.
   - The sentence picks the template: a fight is a duel, hockey/football/basketball and similar are an arcade sport.
   - `copies` must name what the template requires.
   - A design verb's `move` must carry the table's frames exactly.
   - The design step, the review and the Planner get that template's research excerpt; builders get the
     implementable spec. `own` gets no excerpt.
   - The duel template names `card.duel` as the default card, and planner.md says to take it when it is listed. N2's
     card is not on this tree yet, so this path is untested against the real card.
3. The tofu stage (foreman/src/tofu.ts, quality.ts).
   - The TOFU CHECK line and its metrics: feedback_f, skill_spread, skill_variants, idle_max_f, tell_min_f, tells,
     pressure_waves, lead_change_share and close_rounds. A duel adds contact_types and one_sided_contacts; an arcade
     sport adds possession_median_f.
   - The metrics are read from `bot.result.metrics` of the bot's newest finished report. The hand is read from
     metrics.hand or result.hand.
   - The tofu rows are judged with the critic's look into one verdict, and the existing loop does the rest: revise
     rounds, keep the better version, then the hold.
   - The report is reports/tofu-<m>-s<seq>.json.
4. The critic. The prompt now carries a checklist block, and the code appends the [H] line when the model leaves it
   out (roomtext.ts withHLine, designer.ts critic).
5. The 21 Nov fixes.
   - `foreman quality` records the answer and prints the resume command, with paths in forward slashes and quoted
     values. It never runs the job; `--no-run` is still accepted and changes nothing.
   - The producer's notes do reach the re-plan path: checked. L1b did it in foreman.ts line 355, and the
     quality.test L1b test asserts it.

CHANGED FILES
- New:
  - foreman/src/templates.ts
  - foreman/src/tofu.ts
  - foreman/src/test/n4.test.ts
  - in this lane folder: PATCHES.md, STANDUP.md, REPORT.txt, room-standard.json, room-crazy.json,
    plan-standard.json
- Changed docs and data:
  - docs/GAME-QUALITY.md
  - foreman/data/job-events.schema.json (regenerated)
- Changed prompts: concept.md, designer.md, design-review.md, planner.md, builder.md, critic.md.
- Changed foreman/src: room_wire.ts, roomtext.ts, room.ts, designer.ts (591 lines; the budget is 600), quality.ts,
  quality_state.ts, cli_quality.ts, cli.ts, concepts.ts, repair.ts, foreman.ts, testing/fake-runner-core.ts.
- Changed tests and fixtures:
  - helpers.ts
  - cli.test.ts
  - designer.test.ts
  - quality.test.ts
  - wp3c.test.ts
  - foreman/fixtures/job-paddle/fake-builder.json (edited as text: one line)
- Nothing outside my column. The site reader treats concept and design as opaque, so it needs no change.

BEHAVIOUR CHANGES (each test expectation that moved is named here)
- The concept answer must carry `template`, and a design verb may carry `move`. The fixture sampleConcept now carries
  an `own` template, and the roomSteps hockey concept carries arcade_sport.
- quality.test "crazy concept" now designs on "a paddle match in a walled court", because a fight must copy the duel.
  The handbook test's Builder rules now start at rule 13 because v2 added rules.
- A fresh plan of a brief whose concept has a template needs the tofu stage. cli.test's planner fixture now uses
  fixturePlanTofu.
  - The fixture's rally bot now reports passing FAKE_METRICS (a new fake-runner marker), so tofu stages built on it
    pass.
  - Older briefs, with no template, plan exactly as before.
- The Planner prompt says the root is "on flat shapes (milestone blockout)", not "on greybox" (wp3c regex updated).
- Critic answers gain a last note, the [H] line (designer.test "critic (V5 seam)" deep-equal updated).
- `foreman quality` no longer runs the job.
- A milestone summary can read "tofu stage NOT ok" or "critic (V5) and tofu stage NOT ok". lookOk,
  verdictOfLook and the status line read all three forms.

FOR THE OWNER TO LOOK AT
- Read room-standard.json and room-crazy.json, in the brief's rules and ai fields: they are the designs the next
  colosseum attempt starts from.
- The real proof is a person playing the tofu phase: "Parry, block, roll and punish Orso in a walled ring" (the
  real Planner's first phase).

QUESTIONS FOR THE DIRECTOR (also in PATCHES.md item 2)
1. Land the JOB.md text in PATCHES.md item 1.
2. PACK.md says a bot returns "plus any numbers". Should it name `metrics` as the object that holds named bot figures?
3. The real Planner call took 571 s on Opus (the prompt is bigger with the duel excerpt). Check the generate timeout
   the Director's proof run uses for the planner role.
4. When N2's card.duel lands, check that its `applies_when` lines match a fight. The Planner is told to take it as the
   default, but no code enforces that.

NEXT THREE THINGS
1. Run the Director's colosseum proof through the tofu phase, then play it by hand: do the metrics a builder's bot
   reports match what a person feels?
2. Add a [B] check to the tofu bot for DUEL-PLAYBOOK's own acceptance, per contact type: both fighters' states change
   on each 6.3 row. Today it is one count, one_sided_contacts.
3. Stop the stone-wall hook from recurring: record each sentence's chosen hook families site-wide, for standard
   too, not only crazy.
