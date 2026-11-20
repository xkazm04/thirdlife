# L2 designer-foreman: a fun-first Designer with aspects, crazy mode and phases

Read `docs/shifts/2026-11-21-night/COMMON.md` first: the owner's words, the wire contract, the laws and your file column.
- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n21-designer`, branch `n21-designer`, base main `3a4580b`.
- **Route:** Opus solo.
- **Time box:** land-ready by 02:30, so the Director can run the two proof jobs on it. Then polish until 06:30.
- **Standups:** `lanes/L2-designer/STANDUP.md`. Send the Director a message when landable.

## Owner's words
"our prompts and thought processes for content designs stick to principles like Minecraft or Roblox ... Designer's LLM
always tries to create the most fun output to entertain the player via a) Wow effect b) Levels of creativity ('crazy')
c) Multi-phases construction d) Game design breakdown ... feasible for a 10 yo ... masterable by 30-50 yo".

## What the scout found
- **Designer.** `foreman/prompts/designer.md` is 26 lines. It says: "Be concrete and small... Do not invent features the
  sentence does not ask for." It makes one call and outputs `brief{rules,arena,ai,controls,mood}`
  (`foreman/prompts/brief.schema.json`).
- **Planner.** `planner.md` plus `plan.schema.json`, checked by `planProblems`, `planCardProblems` and
  `planHandProblems` (`foreman/src/designer.ts:275-330`).
- **Critic.** `designer.ts:391`, rubric `silhouette/readability/style_consistency/shows_play`. Its prompt says "You judge
  legibility and consistency, not fun."
- **Approval and the run.** The only approval gate is `brief_approved`. After it the whole plan runs unattended; the
  scheduler lives in `foreman.ts` and `machine.ts`.
- **Cards.** `engine/cards/*.json`: 4 cards. None encodes camera-serves-verb, juice, rival character, first minute or stakes.
- **The yardstick.** The gap list for hockey is the measuring stick for "fun":
  - camera fixed 100 m up;
  - no hit-stop or shake;
  - no goalie;
  - a bare WIN/LOSE screen;
  - no onboarding.
- **Schema readers to keep in step:**
  - `foreman/src/events.ts` and `foreman/data/job-events.schema.json`;
  - `designer.ts`, `cli.ts`, `status.ts` and `explain`;
  - tests in `foreman/src/test/*` and fixtures `foreman/fixtures/make-*.mjs`;
  - the Godot readers, which belong to L3 and are not yours.

## Work
1. **Rewrite `designer.md` fun-first.**
   - The goal is the most fun game the sentence can become, built in phases. The rule "do not invent" is gone. Creativity
     standard: serve the player's goal, filling every gap with the most fun choice.
   - **The fun-ingredients checklist** the Designer works through, and the brief makes concrete:
     - a camera that serves the main verb;
     - juice on the verbs that matter;
     - rivals with character;
     - a first minute that teaches by playing;
     - stakes that make the next round matter;
     - an intensity curve;
     - one twist.
   - **Pitch and aspects.** Output `pitch`, plus 3-7 `aspects` chosen for this game (JOB.md 2026-11-20 limits, icon enum),
     each with 2-3 alternatives that are genuinely different games, not tweaks.
   - **Wow.** Show in the prompt, with one compact worked example, how a vague sentence becomes a design deeper than the
     player said.
   - **Crazy.** Keep the player's words and add 1-2 unexpected mechanics on top, each its own aspect with `crazy: true`.
     They must still be buildable with the TL* API.
   - **Feasibility guard.** Every aspect must be something the kernel and kit can do: the Designer gets
     `engine/kernel/API.md` or the generated index, and the cards.
2. **Schema and commands.** Change the brief schema, the plan schema (`phases`), events.ts, the event JSON schema and the
   readers. Add the commands `new --creativity crazy --run-through`, `react`, `redesign` and `phase pass|hold [--note]`,
   exactly as JOB.md says.
   - `redesign` passes the reactions to the Designer.
   - Approval hands the reactions to the Planner.
3. **Planner phases.** The Planner emits 2-5 phases with a `try` line each. The first phase is the smallest thing that
   plays, and the camera serves the verb from phase 1. Validate the partition and deps in `planProblems`.
4. **Scheduler.**
   - After each phase: `phase_done`, then `job_state paused reason "phase"` unless `run_through` is set. With
     `run_through`, write the auto `phase_reviewed`.
   - `hold` with a note runs a change round scoped to that phase's packages.
   - A waiting job is never a hang: `foreman status` names the phase and the command.
   - A stuck or failing phase fails loudly.
5. **Critic.** Drop the "not fun" sentence. Add a `fun_promise` dimension: does the capture show the phase's `try` line
   happening?
6. **Cards.** Add a `fun` block to all four cards (CARDS.md 2026-11-20), drawn from what each example really does or
   should do. Teach `tl cards check` the block in `devx/lib`; touch only that part.
7. **Proof fixtures.** Add a replayed fixture job (the `fake` adapter) that goes through 3 phases with one `hold` + note
   and one `pass`, plus one crazy brief with a crazy aspect. Two real-model Designer calls are allowed for prompt tuning;
   each must be cheap (Designer only, no build).
   - Sentence: "a fight in a colosseum".
   - Run it standard and crazy, and save both briefs to your lane folder.
   - Judge them against the checklist yourself, and iterate the prompt at most 3 times.

## Acceptance
- [ ] `tl check --tier fast` green; foreman typecheck and tests green, with the count >= base plus a test per new event and
      command.
- [ ] The fixture job goes through 3 phases (pause, hold+note change round, pass, run-through), shown by `foreman status`
      output at each stop.
- [ ] The two real Designer briefs ("a fight in a colosseum", standard and crazy) are in the lane folder, with your
      checklist judgement. Crazy has 1-2 `crazy: true` aspects; every aspect is within its limits.
- [ ] Every card has a `fun` block; `tl cards check` is green.
- [ ] Prompt diffs are summarised in REPORT for the owner: what the Designer now says that it did not before.
