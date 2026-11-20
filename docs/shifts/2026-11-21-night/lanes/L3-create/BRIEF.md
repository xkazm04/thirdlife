# L3 create-screen: the Create page (sentence, aspects, phases)

Read `docs/shifts/2026-11-21-night/COMMON.md` first. It has the owner's words, the wire contract, the seams with L2 and L4,
your file column, and selftest block 630-639.
- Worktree: `C:/Users/kazda/kiro/third-life/.claude/worktrees/n21-create`, branch `n21-create`, base main `3a4580b`.
- Route: Opus solo.
- Time box: until 06:30.
- Standups: `lanes/L3-create/STANDUP.md`. Message the Director when you are landable.

## Owner's words
"Game design breakdown in the designer. Designer should be able to express on very high level key game aspects so player
can react on each of them, but without information/text overhaul. The UX should be feasible to operate for 10 yo player
with very vague needs, but also to be mastered for 30-50 yo guys." Also: "player can go in construction side and
check/try results of each phase so he can let it pass or stop/pause and provide more instructions to the builder".

The owner picked a full-screen page in a new main menu, not an overlay in the world. Aspects are LLM-chosen, 3-7 per game.
Phases are LLM-chosen, 2-5 per game.

## What exists (scout)
- `engine/ui/editor/workbench.gd`, `editor_model.gd`, `foreman_door.gd`, `panel.gd`, `job_model.gd` and `host.gd`. These
  are a standalone dev tool (`engine/tools/ui.sh`), not mounted in the exe.
- `foreman_door.new_game(...)` already runs `foreman new` as a detached node process (`foreman_door.gd:115`).
- `job_model.gd:365-385` derives a phase label from `job_state` only.
- `engine/kernel/world/site/event_schema.gd` is a strict mirror of the job events. An unknown key breaks the village site,
  so it must learn every 2026-11-20 key.
- Reuse the editor's interview pieces where they fit. The interview stays available: a card's questions can show as
  aspects when the Designer has not answered yet. That is your call; say which you chose.

## The page: `res://ui/create/create.tscn`
The root has `func open() -> void` and `signal closed`. L4's menu mounts it.

States, each drawn, including empty, error and failed:
1. **Idea.**
   - One big sentence box and a two-way switch: **Standard / Crazy**. For Crazy, write one line on what it does.
   - A "surprise me" idea chip row for the 10-year-old.
   - Go.
   - Expert drawer (collapsed by default): run-through on or off, and the card hint.
2. **Designing.** Something alive to look at while the Designer runs, with no fake progress. Show the sentence and
   "the designer is thinking", plus elapsed time.
3. **Pitch + aspect cards.**
   - The pitch line is large. Each aspect is a card: icon, title, line.
   - Crazy aspects are marked with a distinct badge.
   - One tap cycles keep, then each alternative, then drop.
   - "Tell me more" expands the `detail` and a free-text note field for the expert.
   - Buttons: **Redesign** (sends the reactions, then `foreman redesign`) and **Build it** (`foreman approve`).
   - Text budget: nothing on screen longer than the contract limits. No paragraphs.
4. **Building.**
   - A phase strip: one chip per phase, with title, state and the `try` line under the current one.
   - Package progress inside the current phase.
5. **Phase done.**
   - **Try it.** Starts a second process with `--dungeon=<job dir>/pack` (COMMON try-it seam). You may stub the target with
     a seed pack dir to test it.
   - **Pass.** Runs `foreman phase <job> pass`.
   - **Hold + note.** Opens a note box, then runs `foreman phase <job> hold --note`.
6. **Done.** "Your game is ready". Play it as a dungeon.

**Readers.** `job_model.gd` and `event_schema.gd` (plus `site.gd` if needed) read every key of JOB.md 2026-11-20. The
village site sign shows phases (`phase n of m: <title>`) where it showed packages.

**L2 dependency.** L2 builds the Foreman commands in parallel and is not merged into your tree. Build against the contract
text plus fixtures:
- Write fixture job logs for each state, in the `engine/ui/fixtures/` style.
- Drive the page from them in `ui.sh selftest` and your 63x blocks.
- Calls to `foreman react`, `redesign` and `phase` go through `foreman_door.gd`, with exactly the CLI shapes in JOB.md.

## Look
- Crisp cel is the house look. Use the existing UI theme and widgets (`engine/ui/flags`, the HUD workshop).
- Make it read at 720p: the 19 Nov HUD lesson measured glyph heights against a readability floor.
- The owner wants to escape mediocre styling on the first try. Big type, few words, icons, colour for state.
- Stills of every state at 1280x720 go into the lane folder as JPG.

## Acceptance
- [ ] `engine/tools/ui.sh selftest` green, with new fixture cases for each state, and `tl check --tier fast` green.
- [ ] Your kernel file changed, so the full gate's `world` step must also pass: the village site is not broken by new keys.
      Prove it with a fixture job log that has every new key, read by `event_schema.gd`.
- [ ] Stills of states 1-6 plus a 20-30 s clip of clicking through them, driven from fixtures.
- [ ] Every CLI call the page makes matches JOB.md word for word, as a list in REPORT.
- [ ] A 10-year-old path (idea, Go, tap tap, Build it) needs no reading beyond the titles. Count the words on each screen
      and report the counts.
