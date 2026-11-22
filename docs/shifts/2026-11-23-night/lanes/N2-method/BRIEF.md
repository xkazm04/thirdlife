# N2 method: how games are designed for fun, and the editor rewritten to it (night of 22-23 Nov 2026)

**The owner, ~18:35, after playing the day's exe (verbatim):** "Editor cannot start new idea to build, World itslef is
very nice with downsides in blinking objects below/above the ground, and blinking objects aggressively with distance
levels. In far there are seen incomplete structures, on closer distance green ground. Hockey is unplayable garbage,
analyze in deep thirdjam - it is a mediocre hockey game we delivered but at least it has set basic gameplay mechanics,
AI, bugless graphics and balanced speed (https://github.com/xkazm04/thirdjam). Our hockey is a proof we should not start
any new minigame development as there is a lack of understanding how games should be done - we need research to change
mindset of what we are doing. The fact players can skate and shoot puck does not mean we delivered entertaining hockey
experience, the fact players can punch in arena and take damage does not mean we delivered fun fighting game. Both are
slop nobody would touch for fun and we should prepare processes and prompts to go much deeper in game design"

Worktree: `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-method` (branch n23-method, from main).

Route: Opus solo. Web research is allowed (WebSearch, WebFetch); cite every source.

The owner chose that everything lands tonight, the prompts included.

## Goal
Change the mindset. Today's test is "the mechanics exist and the bot metrics are green". The new test is "a person wants
to play it again".

Research how real games are designed for fun, write it down as OUR method, and rewrite the editor's prompts to it:
Foreman's design room, the builder briefs and the critic. Every future game is then designed that way.

## What to research (cite every source)
- **The craft of fun:**
  - core loop and moment-to-moment play;
  - game feel: Swink's "Game Feel", juice, input response;
  - MDA (mechanics, dynamics, aesthetics);
  - player fantasy and the first 30 seconds;
  - difficulty and flow;
  - readability, and feedback for every action.
- **How studios get to fun:**
  - paper and greybox prototypes;
  - the "find the fun" vertical slice;
  - playtest loops with real players;
  - kill criteria, design pillars and one-page designs;
  - what a design doc for a small arcade game contains.
- **Two worked cases from real games.** For each, state as concrete rules, numbers and moments what makes it fun:
  - an arcade hockey game (NHL 94, NHL Hitz or similar);
  - a duel game (For Honor duels, Souls 1v1 or a fighting game).
- **What LLM-built games tend to miss.** Use our own evidence:
  - `docs/GAME-QUALITY.md`;
  - the night and day verdicts of 21 and 22 Nov;
  - `docs/shifts/2026-11-22-day/lanes/D3-editor/REPORT.md`;
  - N1's teardown interim, from about 01:00:
    `.claude/worktrees/n23-teardown/docs/shifts/2026-11-23-night/lanes/N1-teardown/INTERIM.md`.

## What to write
1. **`docs/design/METHOD.md`, our game-design method.** It sets out:
   - **The stages** a game goes through before any build:
     - fantasy;
     - pillars;
     - core loop;
     - the 30-second test;
     - the feel spec, with numbers;
     - the reference-game teardown;
     - a paper or greybox prototype;
     - kill criteria.
   - **What a person checks** at each stage.
   - **What evidence counts:** a person's hand, never a bot figure alone.
2. **`docs/design/CASES.md`:** the two worked cases (hockey and duel), as they would go through the method. For hockey,
   cite N1.
3. **The editor rewritten to the method (`foreman/**`):** the design room's prompts and steps, the builder brief and the
   critic's questions.
   - Read `contracts/JOB.md` (design room, quality loop) and `foreman/src/` first.
   - Keep the job contract's events valid. A contract change goes in your report as a proposal; contracts are
     Director-only.
   - Keep the Foreman tests green and state the count. Add tests for new prompt content where it can be checked.
4. **`docs/GAME-QUALITY.md`:** point it at METHOD.md, and drop what METHOD.md replaces.

## Acceptance
- METHOD.md and CASES.md, with sources.
- The prompt rewrite, with a before/after excerpt in your report.
- `npm test` all green, with the count stated (main: 310 tests, 304-305 pass, 0 fail). Fast tier green.
- No Foreman build job is started tonight (no minigames). A dry `foreman new` design-room run on a FAKE adapter, to show
  the new prompts flowing through, is fine.

## Scope (your claim)
- **Yours:**
  - `docs/design/**`
  - `docs/GAME-QUALITY.md`
  - `foreman/**`
  - `engine/cards/**`
  - `devx/lib/cards/**`
  - your lane folder
- **Shared:** N4 (the Create fix) may need a foreman change. If it does, the Director tells you before it lands.

## Time and rounds
Time box: until 06:45. Rounds:
1. METHOD.md first draft, by about 23:30;
2. CASES.md, after N1's interim;
3. the prompts, last.

## Shift-wide rules for this night
- Absolute paths only; never `cd` inside a backgrounded command line.
- After you send "landable round k" (SendMessage to the Director), make NO edits in your tree until the Director answers
  "landed" (or "rejected").
- Stamp STANDUP lines from `date`, never from memory. Write a STANDUP line at least every 60 minutes. No line for 60
  minutes gets a status ask, and a second miss gets a stop.
- Lanes stop at 06:45 (CEST): report written, last STANDUP line `done` or `cut`.
- The owner's rule for tonight: no new minigame and no game-feature work on duel or hockey. No Foreman build jobs.
- Other sessions load this machine, so wall-clock checks (hockey many_budget, perf, the kernel suite's cap) are not
  evidence on a busy machine; say so instead of tuning to them. Mind RAM: the system killed a run at 1.7 GB free today.
- The full tier in a worktree needs `npm ci` in its `foreman/`, plus plain copies (no links) of
  `site/marble-run-three-marbles-20261110-1` and `-2` from the main checkout into its `site/`.

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-23-night/lanes/<lane>/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
  when the lane lands).
- Append one line at each milestone and at least every 60 minutes of work:
  `HH:MM | state: working|blocked|done|cut | did: <one line> | next: <one line> | gates: <last PASS/FAIL line or ->`
- `blocked` names the question in the same line. Then keep working on whatever the block does not touch.
- When you finish, write `REPORT.txt` beside it (the harness refuses agent writes to files named REPORT.md), return the
  full report as your final message too, and set the last standup line to `done`.

## Honesty
- Evidence or it is not done: a gate line, a test count, a still, a video, a repro before and after.
- A stopped run is never a pass. NOT RUN is not PASS. Fewer tests completed than on main is a stopped run.
- Unmeasured is not zero. Never fake a frame, a figure or a hash.
- A behaviour change that moves a test expectation is named, with why. Never loosen a test to make it pass.
- What the player sees or feels is judged as a person meets it (a window, the exported game), not only headless.

## Laws (CLAUDE.md)
- Work only in your worktree. No git that writes (read-only `git diff`/`git status` are fine). The Director lands.
- Never kill a process you did not start. Prefer `--headless`. Build the class cache once: `"$G" --headless --path engine --import`.
- Time is physics frames; determinism (same pack + seed + frames = same state_hash); unknown keys are errors; packs use only
  the TL* API and never declare class_name; kit, rigs, style reference nothing outside themselves.
- Contracts (`contracts/*`) are Director-only: put the question in your report.
- New selftest cases go in your own `engine/tools/selftest.d/NNN-<name>.sh` files, numbered inside the block range your brief
  assigns (two lanes once collided on 360).
- Raw captures (frame folders, long or uncompressed clips, mkv/avi) stay under `.tl/` in your worktree. The lane folder
  gets only sheets, notes, JPG stills and mp4 clips of 30 s or less.
- A kernel API addition updates `engine/kernel/API.md`; the Director regenerates docs on main (`tl arch --index`).
- Gates before `done`: `node devx/bin/tl.mjs check --tier fast`; when kernel, kits, rigs, style or seeds changed, also
  `node devx/bin/tl.mjs check --tier full` (perf alone if it says NOT RUN).

## REPORT.md
- Outcome against each acceptance criterion: met / not met, with its evidence.
- Gates with PASS/FAIL lines and counts.
- Changed files; behaviour changes; anything the owner should look at, and how.
- Questions for the Director; the next three things this lane would do.
