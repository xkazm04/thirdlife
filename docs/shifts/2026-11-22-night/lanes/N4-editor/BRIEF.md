# N4 editor-knowhow: the editor designs from proven genre templates, and kills a core that is not fun

Read `docs/shifts/2026-11-22-night/COMMON.md` first. Then read all three files in `docs/research/` and the current
`docs/GAME-QUALITY.md`, `foreman/prompts/{concept,designer,design-review,planner,builder,critic}.md` and `contracts/JOB.md`
"Added 2026-11-21".
- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n22-editor`.
- **Route:** Opus solo.
- **Land:** by 03:30. The Director re-runs the colosseum proof after you, N1 and N2 land.
- **Tests:** foreman tests.

## The owner, 21 Nov
"The games are still mediocre slop ... we don't need to reinvent wheel, there are hundreds of duel games (souls like, for
honor duels) with well known game design paths we can mimic." Before the next colosseum attempt: "research know how first
as we lack understanding what's making games popular in videogame history". The research is done; it is in
`docs/research/`.

## Work
1. **`docs/GAME-QUALITY.md` v2.** Fold in R1-R14, the anti-patterns ("10,000 bowls of oatmeal" is the main risk for us) and
   the 30-item plays-twice checklist, each item marked [B]/[C]/[H].
2. **Genre templates.**
   - The concept step must name ONE proven reference design per core loop and say what is copied from it:
     - a melee duel copies DUEL-PLAYBOOK (state machine, mutual reactions, three archetypes);
     - an arcade sport copies HOCKEY-ARCADE (possession as a state, utility AI, roles);
     - other genres name their own proven reference and its mechanics.
   - The design doc carries the template's rules and frame tables, not paraphrases.
   - Add `docs/research` excerpts to the design and builder context: the relevant one by genre, not all of them.
   - When N2's `engine/cards/duel.json` exists, the duel card is the default for a fight, alongside the other cards.
3. **The tofu stage.**
   - The Planner's first phase is the core verb exchange on flat shapes, with the feel sheet.
   - The phase passes only if its bots show checklist items 1, 3, 9, 11, 12 and 15: feedback within 3 f, an analogue skill
     dimension, no idle opponent, tells of 12 f or more, pressure waves, lead changes.
   - The critic and the job hold if it fails, exactly like the quality loop.
   - Define the bot metrics the Planner must ask each package's bot to report. They are names in a `metrics` object of the
     bot's report; check what the runner already lets a bot report.
   - Propose the JOB.md wording to the Director (PATCHES.md); contracts are Director-only.
4. **The critic** checks the [B]/[C] items it can see. It must always add the line "[H] items not judged: a person must
   play it".
5. **Fixes from the 21 Nov day,** small:
   - `foreman quality <job> retry --adapter ...` must record the retry and print the resume command, NOT run the job in
     the foreground;
   - the producer's review notes reach the re-plan path (check L1b did this).

## Acceptance
- foreman tests green, with new tests for the template choice, the tofu-stage hold and the retry fix.
- **Two real Opus room runs on "a fight in a colosseum"** (standard and crazy), JSON in your lane folder. Each names its
  template and copies its rules: frame tables, mutual reactions, archetypes.
  - Judge them against the owner's words. If either is a generic brawler again, the prompts are not done.
- Your proposed JOB.md text is in PATCHES.md.
