S4-core REPORT (juice day 27 Nov 2026; arm A tree d25-arsenal / branch d27-sp-core, arm B tree d27-sp-core-b / branch d27-sp-core-b; both from main 8be26d61; nothing committed, the Director commits)

THE QUESTION (ask 4): "Rink core: bots that use abilities, and a dive block. Is it worth a C++ lane?"
THE ANSWER IN ONE LINE: the native build works on this machine (1 m 39 s from nothing); arm A (patch 0005) gives the rival bots the real meteor
(with a wind-up) and a dive that really stops a meteor, with switches-off parity proved; arm B can only draw it. Full write-up: SPIKE.md.

ACCEPTANCE (brief "Done when" and spike rules)
- Native build checked in the first hour: MET. 08:14 "PASS rink build thirdlife template_debug" (1m39s, godot-cpp cloned at its pin, scons + MSVC 2022); STANDUP 08:15.
- Arm A built (C++ patch, bots use the cartridge's abilities from their own reads, a dive verb, cartridge-sidecar keys Create can write): MET.
  engine/cores/rink/native/patches-thirdlife/0005-bot-abilities-dive.patch (+260/-2); 7 switches; Foreman's ruleSwitches() reads them with their ranges.
- Arm B built (no C++: data + pack drawing + pack-faked dive, and what B cannot do): MET (SPIKE.md section 2 lists the limits).
- Measures, both arms, same packs/seeds/sentence: MET (SPIKE.md section 4).
  bot meteors a minute (rivals): A 1/2/3, B 0/3/0 hot shots; the hand's meteors stopped by a dive: A 3 of 10 (editor copy 6 of 7), B 0 of 13 (0 of 11).
  tl ladder rookie, 10 matches: regular hand unchanged 6/10, A 2/10, B 7/10; sharp 8/10, 7/10, 8/10.
  determinism: every seed 1-3 run twice, same run hash and core hash (24 runs + 3 control, 0 script errors).
  frame cost alone (seed 1 twice): p50 A 4.44/4.52 ms, B 4.17/4.62, unchanged 4.36/4.41; p99 within the machine's noise (23-31 ms).
  lab balance: A PASS parity 600 of 600 matches + 43 gym probes hash for hash (switches off = thirdjam), hockey.thirdlife baseline PASS 600/600.
  lab check-cartridge (thirdjam playtester, 10 seeds a level): unchanged 10/10/10 wins 18.9/19.0/19.7 goals; A 10/9/10 14.1/12.5/13.1; B 10/10/10 22.1/17.7/19.2.
  hockey house pack held: hokej 14 of 14 tests pass with the same state hash in tree A as on main's core.
- Generality (one real Create change on a copy, tree A): PARTLY MET. The builder named the A switches and values exactly, but the cartridge
  package may not write data/harbour.rules.json (scope), so Create did NOT build the bots' hip check (blocked-editor below); with the builder's own
  values written by hand into its v0.1.24, the rival bots hip-check 5/4/5 times a minute. 45.8 min, 1.63M tokens in (1.46M cache), 16.8k out.
- Each arm playable: MET. A: exe exported from tree A (.tl/s4/exe/ThirdLife/ThirdLife.exe, 59 s; plays the A pack as a dungeon headless, 1200 f,
  0 errors); main's exe refuses A's switch. B: main's exe plays the B pack (1200 f, 0 errors).
- Clips (<=30 s) and stills looked at: MET. clips/A_core_dive_blocks_and_bot_meteor.mp4 (11.4 s), clips/B_pack_drawn_dive_and_hot_shots.mp4 (7.3 s);
  stills/ 5 sheets + 4 frames (SPIKE.md section 6 says what each shows).
- SPIKE.md with both arms, results, risks, how to play, recommendation apart: MET.

GATES
- tree A: tl check --tier fast PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230, foreman.typecheck clean).
- tree B: tl check --tier fast PASS (same 5 steps, devx.test 230/230).
- tree A: selftest rink.bot_abilities (block 814) PASS 1/1; rink.sh balance-thirdlife --parity PASS (600/600 + 43 probes); balance-thirdlife PASS (600/600).
- tree A: rink.sh build thirdlife template_debug PASS, template_release PASS.
- The full tier was not run: no kernel, kits, rigs, style or seeds file changed (engine/cores/rink only); the hokej house pack was run test by test (above).

CHANGED FILES
tree A (d25-arsenal), for branch d27-sp-core:
  engine/cores/rink/native/patches-thirdlife/0005-bot-abilities-dive.patch (new)
  engine/cores/rink/bin/rink_core_thirdlife.windows.template_debug.x86_64.dll, ..._template_release.x86_64.dll (rebuilt with 0005)
  engine/cores/rink/CARTRIDGE.md (section 1: the 0005 switches in player words; section 6: the dive), engine/cores/rink/SNAPSHOT.md (the new fields/events)
  engine/cores/rink/tools/rink_bot_abilities.gd (+ .uid) (new), engine/tools/selftest.d/814-rink-bot-abilities.sh (new)
  docs/shifts/2026-11-27-juice-day/lanes/S4-core/: STANDUP.md, SPIKE.md, REPORT.txt, clips/ (2 mp4), stills/ (9 jpg), arm-a-pack/ (hand, editor, gen_hip
  overlays; .gd stored as .gd.txt; make_pack.sh rebuilds the packs from their bases, checked identical)
tree B (d27-sp-core-b), for branch d27-sp-core-b:
  docs/shifts/2026-11-27-juice-day/lanes/S4-core/arm-b-pack/ (hand and editor overlays, make_pack.sh; the B pack's code)
Untracked, for the menu (Director-only copies): d25-arsenal/.tl/s4/hand_a, .tl/s4/editor_a, .tl/s4/gen_hip, .tl/s4/exe/;
  d27-sp-core-b/.tl/s4/hand_b, .tl/s4/editor_b, .tl/s4/hand_base (control). Job copies: d25-arsenal/.tl/jobs/s4-base-arsenal, s4a-arsenal (v0.1.24 now),
  d27-sp-core-b/.tl/jobs/s4b-arsenal (unused). Raw films in d25-arsenal/.tl/s4/film (avi, about 1.9 GB; delete when the clips are accepted).

BEHAVIOUR CHANGES
- Core (A): none with the switches off (proved). With them on: bots hold the mode ability, wind up and fire it; bots dive; four snapshot fields, two events.
- Packs: J1's meteor.gd no longer says FLOORED! over a diver (both arms). The arm packs carry new tests (bot_s4, bot_s4_marks, two ladder cells).

MENU (Director): A "Arsenal hockey: rival meteors and dives (C++ arm A)" = d25-arsenal/.tl/s4/hand_a (needs an exe with the patched DLL);
  B "Arsenal hockey: hot-shot rivals, drawn dives (no C++ arm B)" = d27-sp-core-b/.tl/s4/hand_b (main's exe).

FOR THE OWNER: play A with the exe from tree A (SPIKE.md section 6), carry the puck at a rival and watch him dive across your meteor; then play B in
the main exe and compare. Look at stills/A_sheet_f1670-1690_hand_meteor_blocked.jpg first.

QUESTIONS FOR THE DIRECTOR
1. blocked-editor for lane T: a sentence whose bot behaviour needs the rules sidecar reaches the cartridge package, whose scope has no
   data/<name>.rules.json in a job planned without one; the builder names the keys and values and writes NOT BUILT, and a "yes" answer does
   not widen the scope (job s4a-arsenal events 1082, 1088, 1091, 1095). The planner prompt says a sidecar joins the scope "when the brief changes
   a Third Life switch"; a change request should be able to add it.
2. Main's exe crashes (segfault) after a pack's rules file is refused (an unknown switch): the base opens a null core and goes on
   (d27-sp-core-b/.tl/s4/exe_main_a.log). Worth a guard in the base/kernel regardless of this spike.
3. Default numbers if A lands: 0.6 / 0.6 / skill 0.6 made the regular hand lose 8 of 10; Create can set them per game.

NEXT THREE (this lane)
1. A's dive for the human too (a key) and a "punish the wind-up" read for bots (check the lit carrier), so the rink answers both ways.
2. Words over near divers placed so they stay in the picture (a near figure's tag goes above the frame), and a short camera beat on a dive block.
3. With lane T's scope fix: the same generality sentence through Create end to end, then a ladder at regular/newcomer for the chosen numbers.
