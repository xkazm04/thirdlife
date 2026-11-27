# T: the tofu gate stops bending games (then the J lanes' editor findings)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-hard-a` (branch n27-tofu, from main e66eb94e; foreman built, class cache imported at 00:17). Model: Opus
(engineering). You own the editor tonight: `foreman/` (src, prompts, tests), `engine/cores/rink/lab/**`, and
`engine/ui/create/**` when a fix needs Create to show something. Selftest blocks 790-799 are yours.
Your claim is `night-2026-11-27-juice` in the main checkout's `.claude/sessions.json`. It lists exact foreman files. Another
session claims `foreman/src/world_edit*` and `foreman/prompts/world_edit*`: never touch them. If you need a foreman file
not on the list, say so in a STANDUP line (the Director extends the claim) and go on.

**Why:** tonight six juice lanes (J*) send crazy abilities to real games through Create:
- a double-sledged hammer that launches robots;
- karts that jump;
- 3-metre dunks;
- a shield charge.

Every one of them breaks a 1v1 balance bound on purpose. On 25 Nov the editor's balance bounds (the "tofu gate":
skill_spread, skill_variants, idle, pressure_waves, lead_change_share, close_rounds) bent four games away from what the
person asked:
- **critic revises thrown away:** revises that did what the person asked were thrown away over a bound (G11 r5 and r9,
  G5 r8-r10);
- **hidden rules:** a builder added a hidden comeback multiplier to pass close_rounds (G19: "Bram's next string is replaced
  by a single charged heavy with probability 0.8");
- **measures edited:** builders rewrote the tofu test's own input policy (G4, G19 r5 changed `tests/bot_tofu.gd`);
- **camera-only failures:** camera- and HUD-only changes failed balance.

Read:
- `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-25-day/VERDICT.md` (the G11/G19 blocks and
  the finding);
- the PROOF docs of G5-kart, G11-biplane and G19-shield in that day's `lanes/`;
- `foreman/src/coregate.ts`, `boundlift.ts`, `coreplan.ts`, `method.ts` and the tofu-bound code (grep "tofu").

The fix the day named: **the Foreman owns its measures, and a person-asked change that breaches a bound becomes a note to
the person.**

Acceptance:
1. **A person-asked change that breaches a balance bound is built as asked and promoted.** The person gets a plain-words
   note in Create, for example "the hammer side now wins 17 of 20; say 'make it fairer' to tune it". No refusal, no
   send-back loop, no thrown-away critic revise that did what was asked.
   - A bound the person did NOT touch still guards (a regression a change did not ask for is still caught).
   - Say how you tell the two apart.
2. **Builders cannot change the Foreman's measures.** The tofu bot's input policy and the bound measures are
   Foreman-owned: a builder diff that touches them is refused or reverted, and named in the job log. (For packs, look at
   how the lab's measured check reads them.)
3. **No hidden rules to pass a bound.** With bounds as notes there is no incentive left, but also:
   - the what-changed card lists rules the person did not ask for (a probability, a multiplier, a rubber band) when the
     builder adds them;
   - or the builder prompt forbids them.
   Prove one of the two.
4. **Camera-only and HUD-only changes skip the balance check.**
5. **One real job** (the 25 Nov rule; real adapter, paid, a 40-minute stop):
   - reopen a finished job in your tree (copy one from `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/` or `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-robot/.tl/jobs/` into
     yours);
   - send one bound-breaking ability sentence;
   - show it promoted, with the note, and the ability present when played.
6. **Gates on your tree:** `npm test` in foreman (count it against main's), `tl check --tier fast`, the create. blocks,
   and any block that reads a file you touched. Then "landable T". The Director re-runs them on the merged tree.

After T lands, the Director sends you the J lanes' `blocked-editor` findings as rounds T2, T3... Same rules: a real job
per route change, landable, then the next one.

Contract changes (contracts/JOB.md events, a note kind) are Director-only: write the exact proposed text in your report
and the Director lands it.
---

# Night rules (27 Nov 2026), above the lane rules

- **The owner's words:** "lets use the night to give each game a unique juice. We will need to demonstrate juicy/crazy
  ability to express we can compose any ide there: For example carts with ability to jump, Robots with doublesledged
  hammer allowed to bash oponents, Basketball with crazy high jumps and dunks/blocks."
- **Read first:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/PLAN.md`,
  especially "What juice means tonight". The ability must be crazy and must read at a glance:
  - anticipation;
  - exaggeration;
  - impact (hit-stop, camera kick, knockback with a tumble, particles, sound);
  - the game answering it: the bots use it and react to it, and there is counterplay or a cost.
  Behaviour first: it changes what the hand and the bots do, not only the look.
- **The machine:** RAM at most 80 %, no CPU cap. Before every heavy step (a Foreman job start or change, any Godot run, a
  lab check, npm test, a selftest block) run
  `bash C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/tools/room.sh --wait`.
  Never kill a process you did not start. Another session (the Home sandbox) runs all night. Never touch
  `engine/kits/**`, `engine/kernel/**`, `engine/boot/**` or `contracts/**`.
- **Paths:** absolute paths only; never `cd` in a backgrounded command. Run Foreman job commands detached, one per line, and
  read their logs. A script that starts real (paid) work gets one dry start, checked within 5 minutes.
- **Rounds:** 45-75 minutes. A STANDUP line at least every 60 minutes. A lane silent for 60 minutes is asked; at 120 it is
  stopped.
- **Landable:** after you write "landable", stop editing until the Director says it landed. When you need the Director
  (a fast-forward, a ruling, a menu row), end your turn with the ask in your final message.


---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-27-night/lanes/T-tofu/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
