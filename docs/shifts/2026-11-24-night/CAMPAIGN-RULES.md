# Campaign rules (the hockey port; pasted into every lane brief, above the lane rules)

Read `docs/design/DIRECTIONS.md` first: the owner's words, what went wrong three times, the ten directions, the stair.

1. **Port, do not reinterpret.** thirdjam is the reference and we own its source. Every number and every rule you write
   cites its thirdjam file:line. You do not tune, simplify, "improve" or re-derive anything. Where our engine cannot carry
   a thing as thirdjam has it, the engine gains the missing piece (say which); the game is not bent. Every deviation from
   thirdjam, however small, goes in a `DEVIATIONS` list in your report with its reason.
2. **Sources.** thirdjam's final submitted source (HEAD 8dc713c6, the game the owner knows):
   `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown/.tl/thirdjam` (read-only; `Game/Source` is "S" below).
   The older 15 Nov source tree that the runnable editor build was made from: `C:/t/t5` (read-only). The runnable build
   (UE 5.9 editor binaries + content, 4.5 GB): `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown/.tl/tj-run/Game`
   (read-only: run it in place with `-Multiprocess` and your own `-abslog=` and output folders, or copy it into your
   tree's `.tl/` if you must change it). UE 5.9 is at `C:/Program Files/Epic Games/UE_5.9`. How earlier lanes ran it:
   `docs/research/hockey-teardown/TEARDOWN.md` section 1 and `BEHAVIOUR-HAND.md` "How it was measured".
3. **Look, every round.** Before each standup line, put your own rendered frames beside the reference's frames of the
   same moment (same camera, same scene), LOOK at them yourself (read the image files), and write what your eye rejects.
   A defect you can see is not landable. Film is not the judge of play (the owner: "the pictures will not uncover core
   problem which is the gameplay itself in speed and balancing of skill mechanisms"); it is the judge of defects.
4. **Play is judged by play.** Where your lane touches how the game answers a hand, the proof is the same scripted hand
   through the same inputs in both games, compared frame by frame, never a number chosen by you.
5. **The machine is shared and tight** (about 15 GB of RAM free, other sessions run Godot). One Unreal process at a time
   per lane, closed as soon as it has done its job; never kill a process you did not start; Godot `--headless` unless you
   need a picture. Raw captures stay under your tree's `.tl/` and are deleted when their sheets exist.
6. **Module homes** (Director's ruling for this campaign; contracts follow at landing): the game core lives in
   `engine/cores/rink/` (a new engine module: a core may use the kernel API, kits, rigs and style; packs reach it through
   one kernel entry); the skater figure lives in `engine/rigs/skater/` with its imported mesh and clips beside it; the
   new game's pack is `engine/packs/hokej/` (thin: a cartridge and glue). The old `engine/packs/hockey` is not touched.
   If `tl arch`, the lint or the asset rules reject these homes, change the rule tables under `devx/` or
   `engine/kernel/runner/lint.gd` minimally, and list every such edit in your report (the Director words the contracts).
7. **Rounds.** Work in rounds of 60-90 minutes. At the end of each: standup line, your frames looked at, a short
   `ROUND-<n>.md` in your lane folder (what stands, what your eye rejects, deviations, next). When a round is worth
   landing, write "landable round n" in STANDUP.md, stop editing, and return your report as your final message; the
   Director lands it on the campaign branch `hokej` and sends you on.
