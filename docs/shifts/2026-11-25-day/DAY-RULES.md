# Day rules (25 Nov 2026), above the lane rules

- **The machine is shared and has a ceiling: RAM 70 %, CPU 70 %.** Before every heavy step (starting or resuming a
  Foreman job, any Godot run, a C++ build, a lab check, npm test, a selftest block), run
  `bash C:/Users/kazda/kiro/third-life/docs/shifts/2026-11-25-day/tools/room.sh --wait`. If it gives up after 45 min,
  write that in STANDUP.md and do light work. Never kill a process you did not start.
- Absolute paths only; never `cd` in a backgrounded command. Run Foreman job commands detached, one per line, and read
  their logs; a script that starts real (paid) work gets one dry start checked within 5 minutes.
- After you write "landable", stop editing until the Director says it landed.
- Rounds of 60-90 minutes; a STANDUP line at least every 60 minutes; a lane silent for 60 minutes is asked, at 120 stopped.
- Owner's standing rules: behaviour is the core of game design (movement, contact, bots, the object's physics); the
  owner's hand and eye are the bar; never call a thing fixed before it was seen as a person meets it.

## For game lanes (G*): you are the person
- Use the editor exactly as a person does: Create's command order through `foreman` with the flags of
  `engine/ui/flags/real.json` (real adapter: Sonnet via claude-cli, paid), your own jobs root under your tree's
  `.tl/jobs/`. Answer every card as a person would (keep, drop, a short note; "It's fine, go on" only when a person
  would). Iterate with the change box in words, at least four rounds, aiming at the target images of your game in
  `docs/shifts/2026-11-24-night/concepts/<slug>_concept.jpg` and `<slug>_screenshot.jpg`.
- Never edit foreman/, engine/ or contracts/. When the editor blocks you, write it in STANDUP.md as
  `blocked-editor: <what a person met> | evidence: <job event / still>` and keep going on what you can.
- Judge by play and eye: film each version (follow camera and a wide view), LOOK at your stills beside the target and
  hokej (`dist/PLAY-LATEST.cmd`'s hokej), and say per version what a person would feel, in plain words. Behaviour
  first: does it move, hit, react and play like a game worth replaying?
- At each version also record: time, tokens, path (fast/full), what changed, measured figures where the editor gives
  them, and the gap to the target in three lines.
- Promote good versions and add the best to the menu as Create does (Add to menu); the Director copies them out.
