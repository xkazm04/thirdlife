# M6 lanes: common (P play, T tool, C LLM), day shift 27 Nov

## The owner (27 Nov, away 24 h)
"use this time to master the sandbox engine, deep research Minecraft/Roblox. Think about what is our engine unique and where can outshine those two, chase it during the day so we stay with balanced level of freedom what to buil combining with our graphics and LLM builder which are suprerior game design aspects"

## Read first (all lanes)
- `CLAUDE.md`; `docs/research/sandbox/THESIS.md` (why M6, the balance of freedom: free in the large, guided in the small; the hand can do everything the LLM can).
- `contracts/BUILD.md` "Milestone 6: rules and runs": the authority. A question about it goes in your report and to the Director; never change a wire name.
- `engine/kernel/world/build/LANES.md` (M6 section, written by the seam): your files, your neighbours' files, every hand-off signature. The hand-offs you depend on are quoted in your brief; ask for anything else through your lane's PATCHES file (`PATCHES-P6.md`, `PATCHES-T6.md`, `PATCHES-C6.md`) in your worktree and tell the Director in a standup line: the Director relays by quoting code, never by paraphrase.
- The seam's report: `docs/shifts/2026-11-27-day/lanes/S6-seam/REPORT.txt` in your worktree (from the seam commit).

## Shared facts
- Seam commit: 6690ad32 on branch d27-m6 (the integration branch; NOT on main yet). Your worktree is cut from it.
- Selftest ranges: P 779-781, T 782-784, C 785-787. 773 (seam) and 754-767 stay green.
- The machine is shared with LP (look polish) and DN (day/night) lanes and the other two M6 lanes: one heavy Godot step at a time; Godot exe via TL_GODOT or .tl/local.json.
- Gates before done: `node devx/bin/tl.mjs check --tier fast`; `bash engine/tools/selftest.sh home.` (or your blocks) and once at the end the uncapped `bash engine/tools/selftest.sh` (main: 712 passed, 3 failed: base.lines_undeclared, base.lines_own_6001, feel.pushbox_invariants many_budget; the seam adds its cases); `node devx/bin/tl.mjs check --tier full --only world` (9/9 hashes equal main's).
- Work in rounds; after a landable round write a standup line "landable" and touch only files that round did not.

## Lane rules (verbatim from .claude/skills/shift/lane-rules.md)
- Standups: keep `docs/shifts/2026-11-27-day/lanes/<lane>/STANDUP.md` in YOUR worktree; one line at each milestone and at least every 60 minutes: `HH:MM | state: working|blocked|done|cut | did: <one line> | next: <one line> | gates: <last PASS/FAIL line or ->`. `blocked` names the question; keep working on what it does not touch. When you finish write `REPORT.txt` beside it (agents cannot write files named REPORT.md), return the full report as your final message, last standup line `done`.
- Honesty: evidence or it is not done; a stopped run is never a pass; NOT RUN is not PASS; fewer tests than main is a stopped run; unmeasured is not zero; a behaviour change that moves a test expectation is named with why; never loosen a test; what the player sees or feels is judged as a person meets it (a window, the exported game).
- Laws: work only in your worktree; no git that writes (read-only diff/status fine); absolute paths, never `cd` inside a backgrounded command; never kill a process you did not start; prefer --headless; class cache once `"$G" --headless --path engine --import`; time is frames; determinism; unknown keys are errors; absent = omit the key; packs use only TL*; contracts are Director-only; selftest blocks only in your range; raw captures under .tl/, the lane folder gets JPG stills < 400 KB and mp4 ≤ 30 s; a kernel API addition updates engine/kernel/API.md; files ≤ 600 lines.
- Report: each acceptance line met / not met with evidence; gate lines with counts; changed files; behaviour changes; what the owner should look at and how; questions for the Director; the next three things; your measurement outranks the brief.
