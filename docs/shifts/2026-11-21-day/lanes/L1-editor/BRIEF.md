# L1 editor-quality: the editor designs every game like a standalone game it must sell

Read `docs/shifts/2026-11-21-day/COMMON.md` first. It has the owner's words, the notes he gave before (which the
pipeline dropped), the laws, and your file column.

Then read the whole spark note in the main checkout: `.spark/Spark/ideas/game-quality-bar.md`. Scout digest A is your
gap map, B is the research, and the brief's L1 package and Data & API are your spec.

- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n21d-editor`, branch `n21d-editor`, base main
  `df58f0b`.
- **Route:** Opus solo. Time box: until 18:30, but land EARLY: the proof jobs wait for you. Aim to be landable by 15:00
  with the core, and polish after.
- **Standups:** in `lanes/L1-editor/STANDUP.md`. When you are landable, also send the Director a message.

## Why (the scout, verified file:line; re-check each)
- The builder never sees fun:
  - `foreman/prompts/builder.md` has no fun, feel, animation or juice, and its priority is "the smallest thing that
    passes the acceptance" (:52).
  - `briefText()` (`foreman/src/designer.ts:139-147`) passes only the five fields, the pitch and the aspects.
  - `cardBrief` (`devx/lib/cards/brief.mjs`) never prints `card.fun`.
- The Designer prompt caps feel:
  - "Difficulty is their speed, reaction and aggression" (`designer.md:32-33`), against the owner's R-0045 (skill in
    movement, not speed stats).
  - "no ragdoll: a knock-down is TLBiped.down" (:80).
  - "one main verb" (:18).
  - No slot for animation, playstyles or progression.
- The Planner pulls small: "the smallest thing that plays", "FEW files" (`planner.md:47-51`).
- The critic judges 4 stills and its NOT ok never stops anything (`contracts/JOB.md` "Critic", `foreman.ts:1560-1578`).
  - It said NOT ok at every milestone of both colosseum jobs, and both were promoted anyway.
  - Its notes were right: "no shield, no bash, no roll, no hit effect"; "the same body ... with only the colours
    swapped"; "bodies overlap into a single blob".
- The games (`site/fight-colosseum-20261120-{1,2}/promoted/game.fight_colosseum`):
  - one attack button, no block or loadout;
  - a 120-degree arc with auto-face;
  - hits are a shove and a squash, or every hit is a knock-down;
  - borrowed clips (`shoot` as a strike, `slide` as a roll, `cheer` as a tell, `fly` as a lion pounce);
  - rivals are the player's body recoloured;
  - the camera is lost behind the wall.

## Work
1. **`docs/GAME-QUALITY.md`, the handbook the prompts cite.**
   - The design practice: pillars that rule something out, the 3 s / 30 s / 3 min loops, verbs with frame data, skill
     floor and ceiling, playstyles, the first minute, a one-page doc.
   - The feel numbers at 60 Hz:
     - hit-stop on attacker AND victim, 3-8 frames scaled by force, capped at about 20; the victim vibrates;
     - knockback = base + growth x damage taken, minus mass;
     - dodge i-frames from frame 1 for 14-26 frames, with a tell;
     - telegraphs of at least 20 frames; hitbox 2-4 frames;
     - player anticipation 2-5 frames light, 8-10 heavy; input to response at most 6 frames;
     - the camera fades occluders and never sits behind scenery.
   - Marketability: hook plus anchor, the GIF test, three clip moments.
   - Arcade sports and brawler lessons; the LLM failure modes (Spec2Game, GameCraft-Bench, GlitchBench, mode
     collapse) and what fixes them.
   - **The SLOP LIST:** defaults to avoid, each with why. Include:
     - one attack button;
     - recoloured rival bodies;
     - borrowed clips that do not match the verb;
     - a hit without a victim reaction;
     - a camera behind scenery;
     - a twist that is only HUD text;
     - auto-aim that removes skill;
     - every hit floors the victim (no exchange);
     - fighters overlapping;
     - placeholder shapes in a clip moment.
   - Sources: digest B in the spark note. Cite the sources, keep it tight, and make each rule checkable.
2. **The design room** (JOB.md "Added 2026-11-21"):
   - New prompts `foreman/prompts/concept.md` (5 candidates with likelihoods, pick a bold one that fits, references
     with what to borrow, hook and anchor) and `design-review.md` (a producer/marketer: hook, gif, depth, feel, fit,
     each 0-1, the slop list, verdict ok or revise, at most 80 words of notes).
   - Rewrite `designer.md` to write `brief.design` with the v2 fields.
   - Remove the speed-stats difficulty line. Difficulty comes from the design (aggression, reading, patterns).
   - Remove the "no ragdoll" steer. It says: use `TLHit.react` / `TLHit.down` for hits and the rig's fight clips
     (L2: strike, strike_heavy, block, roll, dodge, body_check, cross_check, taunt).
   - Allow more than one verb when the design needs it; keep a defensive verb required.
   - Code: `foreman/src/designer.ts` and the call chain; the events `design_reviewed`, `brief.concept`, `brief.design`.
3. **Builders read the design.** Every package prompt carries `brief.design.verbs`, `feel` and `clips`, plus the
   card's `fun` block. Fix `brief.mjs` and `cards.ts` so `fun` prints for builders and the Planner.
   - `builder.md` gets a "Feel" section citing GAME-QUALITY.md.
   - Its priority line becomes: make the acceptance pass AND land the feel sheet for the verbs your package owns.
4. **The Planner.**
   - The first package is the core verb exchange with its whole feel sheet on greybox.
   - Every package's `serves` names clip ids.
   - "FEW files" stays only as "no file the package does not need".
   - It never cuts the feel sheet to fit.
   - Raise the default package cap if one is hard-coded below what a real design needs. Say the number.
5. **The critic and the quality loop.**
   - Motion strips: a 4x3 tile of 12 frames, 5 frames apart, per filmed point.
   - Find the cheapest way to film 12 frames in one run: the runner's capture path in `engine/kernel/runner/**`, only
     the capture code, or `tl.sh capture`. Propose the RUNNER.md text if the capture verb changes.
   - Rubric adds `feel` (anticipation, impact and victim reaction visible in a strip) and `slop` (any slop-list item
     seen: fail).
   - The loop: up to 2 revise rounds, a pack snapshot before each, and a pairwise compare that keeps new or previous
     (`milestone.round`, `kept`, `strips`). Then `job_state paused reason "quality"`, and
     `foreman quality <job> accept|retry [--note]`.
   - `foreman status` names the hold and the command.
6. **Readers.** `foreman/data/job-events.schema.json`, `engine/ui/job_model.gd`, `engine/ui/job_v2.gd` (Create shows a
   quality hold with the critic's notes; keep it small) and `engine/kernel/world/site/event_schema.gd` (concept and
   design opaque; `design_reviewed` and reason `"quality"` accepted).
   - Run `bash engine/tools/ui.sh selftest`. The village site must not break on a v3 job.

## Acceptance
- Foreman tests are green, with new tests for the room (3 steps, revise once), the loop (2 rounds, keep previous restores
  the snapshot, hold, accept, retry) and the strips. The fast gate is green.
- A fake-adapter job walks concept -> design -> review(revise) -> design -> review(ok) -> brief -> phases -> a NOT ok
  milestone -> 2 rounds -> hold -> `quality accept` -> done. Paste its `foreman status` at each stop.
- **One REAL Designer run** (claude-cli, opus; this is design only, so it is cheap) on "a fight in a colosseum",
  standard AND crazy. Put `brief.concept`, `brief.design` and `design_reviewed` in your lane folder as JSON.
  - Judge it yourself against the slop list and the owner's three arena complaints: skill/playstyle design, reactivity on
    hits, a movement roll. If it reads like last night's brief, the prompts are not done.
- `foreman critique` on last night's crazy job with strips. Its report is in your lane folder.
- `ui.sh selftest` and the site reader pass on a v3 job fixture.

## Out of scope
- The rig clips (L2).
- TLHit bodies (L3).
- Hockey (L4, L5).
- Running the proof jobs (the Director does that after you land).
