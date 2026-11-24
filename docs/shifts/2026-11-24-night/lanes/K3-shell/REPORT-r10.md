K3 SHELL, ROUND 10 REPORT (resumed 24 Nov 20:50; worktree .claude/worktrees/hk-shell, uncommitted, on hokej f9d2db9)

OUTCOME
(1) thirdjam's puck is in: 8 cm tall, its kit's glowing disc on the ice under it, from its source and K6's export. (2) The
player's first match at ROOKIE is filmed to the end card and cut to 58.6 s beside thirdjam's film, and looked at. It is
NOT played by thirdjam's playtester and NOT filmed from the exe: both are blocked outside the pack, measured below, and I
ask before touching either. The hand is the pack's scripted one, through the same keys and mouse a person uses.
(3) The exe is exported at hokej's head and checked headless; the command for the owner is below. The core's match hash
did not move (ab881a00fb9af8ef).

1. THE PUCK (gen/tj_rink.gd standin_puck, scripts/match_view.gd).
   - AJamPuck::InitPuck (S/JamCore/Private/JamPawns.cpp:865-916): the engine's unit cylinder scaled 2r x 2r x 0.08 m
     (r = game.puck.radius_m 0.12; colour #111111: the palette's black). It was 2.5 cm tall; now 8 cm.
   - Its kit (R-0016): SM_PuckDisc, which AJamPuck::PlaceDiscOnIce keeps 0.4 cm over the ice under the puck at any height
     (:1019-1025). The mesh is K6's export (hk-arena .tl/arena-export/meshes/SM_PuckDisc.glb, untracked); I read its
     section 0 profile from it (a dome 42 cm across, 2.7 cm high: radius 0.21 m at 0.2 cm, 0.18 at 1.1, 0.15 at 1.8, 0.12
     at 2.3, 0.06 at 2.6) and draw it with TLMesh in the palette's emissive `neon_lime`. thirdjam's material is
     MI_Trim_PuckHalo: M_Trim, Emissive 18, TeamColour linear (0.75, 1.0, 0.15).
   - This is the "glow under the human at the faceoff": it is the puck's halo, always under the puck, and it shows at the
     faceoff because the puck sits between his skates (r10_puck_faceoff.jpg: ours left, thirdjam's film right).
   - DEVIATIONS: section 1 (MI_Fx_PuckBeacon, an additive unlit skirt fading out from 15 m) is not drawn: the palette has no
     additive surface. The halo is emit 2.2 lime, where thirdjam's Emissive 18 reads near white under its exposure: ours is
     a more saturated yellow-green. The trail (NS_puck_trail) is not drawn.
2. THE FIRST MATCH.
   - tests/bot_first_match.gd (new, in pack.json):
     - PLAY NOW at ROOKIE: the key-less `level_rookie` tapped for frame 0, as HOME's PLAY NOW does.
     - Then bot_match_hand's hand through the keys and mouse.
     - Then 300 frames held after the whistle for the end card.
     - Headless PASS: level rookie, 6,295 frames, 3:0, 24 shots, core hash 6f45bf07503f05b8.
   - Film: the whole match in a window (6,596 frames, the editor binary's worker), cut to 58.6 s of its telling moments
     beside thirdjam's 20 s film looped: r10_first_match_60s.mp4.
     - The cut: the opening faceoff, play in the neutral zone, a scrum, a carry, the first goal, play, the third goal, the
       end card.
     - Sheets: r10_sheet_a.jpg, r10_sheet_b.jpg. Start and end: r10_start_and_end_card.jpg.
   - BLOCKED 1, thirdjam's playtester's decisions (K1's rink_keyshand.gd way, measured, .tl/drift.gd):
     - The playtester seated in a second core decides each frame on ITS match. Pressed as keys into the raw core, the two
       matches part within seconds.
     - Seed 1 at ROOKIE: the pucks are 39 m apart at frame 600, the humans 23 m apart at 1,200. They end 3:1 (seat) against
       1:0 (keys).
     - So its decisions are about a match nobody sees: it would skate at a puck that is not there.
     - K1's keys_for also uses an analog skate axis and a pad stick. Our pack's devices are digital WASD and the mouse.
     - What would make it honest: a core call that runs the seat's Think (rink_playtester.h FPlaytesterSeat::Think) on the
       raw core's OWN world each frame and reports the decision without applying it ("raw" human mode plus a
       `playtester_advice()`). The bot then turns that advice into keys and the cursor. That is K1's file: I ask first.
   - BLOCKED 2, filming from the exe's dungeon:
     - The dungeon takes only a person's devices (kernel/dungeon/dungeon.gd:20: "What the worker has and a dungeon does
       not: the input record (--record), --devices").
     - There is no bot path and no record replay in the exe, so a bot cannot drive its title, HOME and match.
     - Injecting real keys into a window on this shared machine is not something I did.
     - What would make it possible: `--input=<record>` replay in the dungeon (kernel / boot), or a person.
     - The film is the same pack in the worker. export.sh check proves the exe plays hokej to the same hash as the editor
       binary. In the worker the front end (title, HOME) is not shown: it appears only where the pack can pause.
   - LOOKED AT, most visible first:
     a. The MATCH card says "PRO" at a ROOKIE match: the core plays rookie (screen.gd start_level). The card's level comes
        from data/match.json unless HOME's PLAY NOW sets it (screen.gd paused_tick: cards.set_level). In the exe, through
        HOME, it will say ROOKIE; in any replay or bot run it says PRO. For K5: read the level start_level applied (the
        root's `hokej_level` meta).
     b. Shadows: still faint under ours, dark under thirdjam's (K7's, per your decision).
     c. The commentary lines are small grey text at the bottom. thirdjam's barks are framed plates ("Orange playing
        keep-away", "Blue says not today"). K5's.
     d. thirdjam shows a white bar under the human's ring (the charge or stamina read-out) that ours does not. Not
        identified yet; K5's to say.
     e. The end card reads "GOALS 2" at 3:0. Two goals by the human and one by a mate is likely; K5 to confirm what
        thirdjam's card counts.
     f. The GOAL banner, the score plates, the end card's layout and its keys line, the halo, the hall: read as
        thirdjam's.
3. EXPORT AND THE OWNER'S COMMAND.
   - Build: export.sh build --no-warm PASS (tag f9d2db9 2026-11-24 21:00). It includes this round's puck.
   - Check: export.sh check --no-window PASS. hokej is 95da6c8cccc47e0a in the editor binary and the exe (600 frames). The
     world has 0 script errors and 0 engine errors in all three runs (editor, exe, exe copied elsewhere).
   - The owner (Windows, from the repository root of a checkout at hokej's head, Git Bash):
       bash engine/tools/export.sh build --no-warm --out .tl/dist
     then double-click .tl\PLAY-LATEST.cmd (export.sh rewrites it on each export). Or run:
       .tl\dist\ThirdLife.exe
     The menu lists Hokej under the dungeons; it opens on thirdjam's title, then HOME: pick ROOKIE, PLAY NOW. Straight
     into the dungeon:
       .tl\dist\ThirdLife.exe -- --dungeon=<absolute path>/.tl/dist/games/hokej
     The build made this round is in this worktree:
       C:\Users\kazda\kiro\third-life\.claude\worktrees\hk-shell\.tl\PLAY-LATEST.cmd
4. HASHES.
   - The core's match hash is unchanged: ab881a00fb9af8ef (bot_match_hand, 3:1).
   - The run's state hashes at this head are: idle 3b762bc25ee35dbc, the bot fd162294891897fc, the dungeon
     95da6c8cccc47e0a. They moved with the merges since round 9, not with this round: the head without my puck edit gives
     the same idle hash (checked).

GATES
- hokej:
  - lint PASS.
  - bots PASS: match_hand (ab881a00fb9af8ef), rule_restart, tj_replay (0.54 cm), level_record, hud_rules (152,761
    checks), gym_hand, first_match (new).
  - invariants PASS: solo p99 3.95 ms of 8, p50 3.34 ms of 8, determinism, the bot twice.
- tl check --tier fast: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229 PASS; foreman NOT RUN (no node_modules here).
- export build and check --no-window PASS. Full tier not run (your instruction).

CHANGED FILES
engine/packs/hokej: gen/tj_rink.gd (thirdjam's puck and its halo disc), scripts/match_view.gd (the disc placed on the
  ice), tests/bot_first_match.gd (new), pack.json (the new test), README.md.
docs/shifts/2026-11-24-night/lanes/K3-shell: REPORT.txt, ROUND-10.md, STANDUP.md, r10_* images and film. No git writes.

QUESTIONS FOR THE DIRECTOR
1. The playtester on the real path needs K1's advice call (2, blocked 1). Ask K1, or keep the scripted hand?
2. The exe has no bot or replay path into a dungeon (2, blocked 2). A kernel addition (`--input` for dungeons), or the
   owner's own hands as the first exe film?
3. K5: the MATCH card's level in a replayed or bot run (2a).

IMAGES TO LOOK AT (docs/shifts/2026-11-24-night/lanes/K3-shell/)
r10_first_match_60s.mp4, r10_sheet_a.jpg, r10_sheet_b.jpg, r10_start_and_end_card.jpg, r10_puck_faceoff.jpg
