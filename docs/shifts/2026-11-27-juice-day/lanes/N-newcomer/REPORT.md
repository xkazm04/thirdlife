N-newcomer REPORT (juice day, 27 Nov 2026, 19:30-21:30 local). Tree .claude/worktrees/d27-newc, branch d27-newcomer
(main 48a7e24b). Details, every figure and the stills with notes: PROOF-N-newcomer.md. Sentences word for word:
SENTENCES.md. Instruments (copies, .txt): tools/.

OUTCOME
In all three games a newcomer either never met the newest crazy ability in his first minute or met it without
understanding it. The cause was the screen each time, not the ability. One sentence per game fixed the worst thing on
the first try; shield and Arsenal then took one more sentence each. 5 sentences in all, 5 promotions, every package
merged in its first round (no refusal, no bend, no question). Job copies: plain cp -r at 19:31 from d25-biplane/.tl/jobs
(robots v0.1.11, shield v0.1.16, Arsenal v0.1.30; originals untouched), changes sent through engine/ui/foreman_run.mjs
with the real.json "change" flags (claude-cli, Sonnet, paid).
  Robot soccer. Worst: Q is never shown anywhere. The blue robots YOINK! the ball off him and the hint says only
    "Yanked: pass before the blue ring closes". The bar over his robot has no letter.
    -> v0.1.12 (34 min, 2 calls, 1.04M in / 8.2k out): a big yellow Q beside the meter; "Hold Q, let go: YANK IT";
       "YANKED! Hold Q to yank it back". The newcomer hand that reads the hint line: 2 Q tries and 1 yank caught in his
       first minute (v0.1.11: 0).
  Shield wall. Worst: "G 10" sits small and grey and never counts down (round 1 keeps the volley locked until the Q
    call, and nothing says so); the gulls' red circles land under him with no hint.
    -> v0.1.17 (18 min, 2 calls, 1.27M / 9.6k): G becomes a sixth key that counts from the first frame;
       "G: call the catapult on them"; "RED CIRCLE: step out, or hold RIGHT MOUSE over your head". His own volley:
       1 a minute (was 0). TURTLE! seen.
    -> second sentence, v0.1.18 (27 min, 3 calls, 1.61M / 10.9k): a Q press while busy was lost silently (probe: 3 of 6
       taps lost on v0.1.17). Now the press is kept and the horn blows when he is free, 6 of 6 taps start a call; the
       hint says "CALL WHEN UP" / "CALL NOT READY". Builder's narrowing: a press while knocked down is dropped, with
       "CALL: STAND UP FIRST" (I asked to keep it).
  Arsenal hockey. Worst: HOME still says "F pops your bubble", but F is the meteor. YOU ARE MEGA! fills the screen 10 s
    in and nothing says a landed check did it.
    -> v0.1.31 (21 min, 4 calls, 2.23M / 22.3k): HOME tells the truth; the panel says "RMB CHECK: GO MEGA"; the hint
       plate says "YOUR CHECK MADE YOU MEGA: BUMP THEM FLAT" and "HIS CHECK MADE HIM MEGA: KEEP AWAY" (seen 2-3 times in
       his first minute). The skin also fixed "First to five goals wins." to the real 3-minute rule (on the card).
    -> second sentence, v0.1.32 (11 min, 2 calls, 0.70M / 5.1k): the two new HOME lines ran off the card's right edge;
       now every line fits.
  Total: 13 model calls, 6.85M tokens in (6.27M cache reads), 56.1k out.

MENU (pack path + title; Director-only rows)
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc/.tl/jobs/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.12
    "Robot soccer v0.1.12: the magnet taught (made in Create, juice day)"            keys: hold Q, let go = yank; F hammer
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc/.tl/jobs/shield-wall-3-v-20261125-1-jb/promoted/game.shield_wall_3_v@0.1.18
    "Shield wall v0.1.18: the catapult taught (made in Create, juice day)"           keys: Q call first, then G volley
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc/.tl/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.32
    "Arsenal hockey v0.1.32: meteor and MEGA told true (made in Create, juice day)"  keys: F meteor, hold LMB; RMB check = MEGA
  The in-between versions (shield v0.1.17, Arsenal v0.1.31) are in the same promoted/ folders and need no rows. The pack
  ids are the existing rows' ids. These version numbers exist only in my job copies.

ACCEPTANCE (brief)
- Copy each job into my tree's .tl/jobs first and say which version: MET (above).
- Step 1, play the newest version in a window through the exe with a newcomer's key stream (reaction delays, misses,
  only keys the screen has shown), and write down what he misses in the first 60 s: MET for all three, with two limits
  said in PROOF. TL_EXE_KEYS has no mouse buttons: shield's mouse keys were pressed as Space/J, the pack's own keys,
  and in Arsenal's exe he cannot shoot or check. The open loop never leaves robots' scripted opening. So every game was
  also played by a closed-loop newcomer in an engine window (the same pack, the same Godot build, a TLHand "newcomer"
  or a slower scripted hand that presses only what the screen has told it).
- Step 2, one fix sentence for the worst thing as a Create change, at most one more, never mixed with "make it fairer":
  MET (robots 1, shield 2, Arsenal 2; no fairness ask sent).
- Step 3, for every version: a window clip of 30 s or less, at most 800 px wide, crf 32 (13 clips, 14-30 s, all
  800x450); 2-3 stills looked at (24 JPGs, each described in PROOF); 3600 headless frames with 0 script errors and the
  same hash twice; the newcomer hand's figures: MET for each version.
    robots v0.1.11 df762275 x2, v0.1.12 a111e01c x2; shield v0.1.16 833d92d5 x2, v0.1.17 95f4c26d x2, v0.1.18 b0341c1a
    x2; Arsenal v0.1.30 49bb62e9 x2, v0.1.31 fa9b55c3 x2, v0.1.32 fa9b55c3 x2. Seed 2 also 0 errors for every
    version. Each promoted pack equals the film copy I measured (diff -rq: only pack.json's tests list and my tests).
    Not filmed in the window: Arsenal v0.1.32. Its change is the HOME card only, filmed in the exe, and its match plays
    to v0.1.31's hash. No exe run of robots v0.1.12: the open loop never leaves the opening, so the window run is the
    evidence.
- PROOF with first minutes, sentences, clips, measures, cost, pack path and menu title per new version: MET.
- Honesty: nobody has played these with real keys. Every figure is from scripted hands on film copies; every "sees" line
  is from film and stills I looked at. One instrument bug of my own, found and fixed: the first Q probe held Q down after
  its first press. Its later "nothing" lines were void; only the rerun is quoted.

GATES
- node devx/bin/tl.mjs check --tier fast: PASS 5/5 at 21:00 (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230,
  foreman.typecheck clean). Disk 42.1 GB free.
- Full tier: not required (no kernel/kits/rigs/style/seeds change; this lane changed only docs and .tl/).
- The Foreman's own final checks passed V0-V4 for all 5 promotions (robots also 40 hand matches: newcomer 15/20,
  perfect 20/20, the same as v0.1.11).

CHANGED FILES (all untracked, in the lane folder docs/shifts/2026-11-27-juice-day/lanes/N-newcomer/)
- PROOF-N-newcomer.md, SENTENCES.md, STANDUP.md, REPORT.txt; clips/ (13 mp4, 27 MB); stills/ (24 jpg, 4.4 MB);
  tools/ (n_robot, n_shield, n_shield_q, n_hockey .gd.txt; keys.mjs.txt; execlip.sh.txt; clipw.sh.txt).
- Not tracked (.tl/): the three job copies with all versions, .tl/jobs/_ui_logs/*-n-*.log, .tl/n/ (scripts, tests, film
  copies, full-length clips, reports; 100 MB; raw avi deleted after every cut).
- .tl-npm.log was untracked in this tree before I started; not mine. No foreman/, engine/ or contracts/ edits.

BEHAVIOUR CHANGES (in the job copies only, via Create)
- Robots v0.1.12: drawing only (the pack's own newcomer hand hashes 970837d6 on v0.1.11 and v0.1.12).
- Shield v0.1.17: the volley cooldown counts from the round's first live frame for both crews (the round-1 lock stays).
  v0.1.18: a Q press while busy is kept for up to 600 frames.
- Arsenal v0.1.31/v0.1.32: screen and HOME text only (the pack's first-match hand hashes 28c8f9f9 on all three).

EDITOR FINDINGS (evidence in PROOF)
1. A drawing-only change gets "balance moved by your change: matches now run longer" (robots v0.1.12, event 1828).
   The sim is unchanged, and the tofu bot was over its frame budget before this change.
2. A builder narrowed an ask (shield: no kept Q press while knocked down) and said so only in a deviation note, not as
   "part of your change was NOT made" (event 1513).
3. Two packages now own one text: harbour draws its own about_lines over skin's about (Arsenal v0.1.32, event 1496).
   The skin's text is now dead data.
4. Good: all 5 sentences routed right in about 5 s, every NOT DONE hand-off reached its owner, every round merged first time.
Newcomer bar: the packs' own newcomer hands never use the newest ability (robots' never presses Q; shield and Arsenal
have none on their cards). A card's "newcomer 15 of 20" does not say whether a newcomer finds the crazy move. Only a
hand that reads the screen does. TL_EXE_KEYS has no mouse buttons, and two of these games teach with the mouse.

QUESTIONS FOR THE DIRECTOR
- Menu rows for the three picks above (Director-only).
- Should TL_EXE_KEYS learn mouse buttons (engine/boot, the other session's scope today)? Without them the exe cannot
  play Arsenal or shield's taught keys as a person would.

NEXT THREE THINGS THIS LANE WOULD DO
1. The same first-minute pass for karts v0.1.11, biplane v0.1.9 and court with the hint-reading hands, closed loop.
2. A shield sentence for the screen clutter: the hint line and everyone's HEALTH/STAMINA plates sit over the fight.
3. Turn the hint-reading newcomer hand into a reusable test (the pack's hint line read from its view object, a press
   60-150 frames after a key is named, 3 in 10 missed), so a card can ask "does a newcomer meet the new move in 60 s".

==========================================================================================================================
ROUND 2 (Director 22:05; 22:10-00:33). Karts, biplane, court: the same first-minute pass; shield: the clutter.
Tree unchanged (main from 48a7e24b, foreman not rebuilt). Job copies (plain cp -r at 22:10, originals untouched):
karts v0.1.11 from d25-kart/.tl/jobs/j2nd, biplane v0.1.9 from d25-court/.tl/t2e/jobs, court v0.1.9 from
d25-kart/.tl/jobs/j2nd3; shield went on in my own copy (v0.1.18).

OUTCOME
  Shield wall (clutter). Worst: the hint line floats mid-screen across the fighters, big HEALTH/STAMINA text plates on
    both sides, YOU / OPEN: HIT NOW / HIT FROM BEHIND/SIDE stacked over heads.
    -> v0.1.19 (22 min, 2 calls, 0.86M in / 7.6k out): hint on a dark strip above the key row, slim bars in the top
       corners, one short word over heads (OPEN!, FLANK!); drawing only (b0341c1a = v0.1.18). In the exe, the open-loop
       newcomer's busy Q press is now kept (v0.1.18) and G READY lights 20 s in (v0.1.16/17: never).
  Karts. Worst: SHELLED! fills the middle of the screen for EVERY hit on the deck (3 in his first minute: his own shell,
    a shell on him, a hit between others), so he cannot tell whether it was him.
    -> v0.1.12 (34 min, 3 calls, 1.85M / 12.0k; a teams r8 "rivals' part" changed nothing): YOU'RE SHELLED! + "by Mint 2"
       only when he is hit, GOT HIM! when his shell hits, a small tag otherwise. Drawing only (08fe071f = v0.1.11);
       hands newcomer 16/20, perfect 19/20 (= v0.1.11). The exe shows the same 2:43 scrum: big word gone, small tag.
  Biplane. Worst: the lesson's harpoon pass puts Vesper below and behind him (a VESPER arrow at the bottom edge) and ends
    after 15 s anyway: 0 hooks in his first minute (seeds 1, 2); "They loop behind you. Fly on." sits for ~25 s.
    -> v0.1.10 (32 min, 3 calls, 2.01M / 17.9k): the pass waits for one hook or 40 s, Vesper level 32 m ahead, red ring
       and "Q NOW!"; newcomer 1 hook in his first minute (both seeds). But in the exe Vesper sat right behind his own
       fuselage: "Q NOW!" and the ring were drawn on his own plane.
    -> follow-up v0.1.11 (29 min, 3 calls, 1.69M / 12.9k): Vesper 4.5 m above and 2.5 m right of the nose line, one hint
       at a time; in the exe she sits visibly above his nose under Q NOW! and even the blind stream hooks her ~18 s in
       (v0.1.10 with the same stream: no hook).
  Court. Worst: nothing ever says C; the hint line flips between HOLD E ON THE CHALK and SPACE: SWAT AS THEY RISE.
    -> v0.1.10 (54 min, 3 calls, 1.56M / 14.9k): big yellow "C: ALLEY-OOP" over the open mate with a ring and a glow, and
       on the hint line 2-3 times in his first minute; hands newcomer 17/20, perfect 20/20 (v0.1.9 newcomer 17/20).
       Unasked play change (finding 5): newcomer hash 64240fb0 -> 181bc670 for the pack's own hand.
    -> follow-up (23:45:55): the top-left commentary line drew over itself and hid the score; two bottom lines stacked.
    -> v0.1.11 (40 min, 2 calls, 1.44M / 11.9k): one bottom line; the commentary on a dark strip under the score, which
       stays; drawing only (181bc670 = v0.1.10); hands 17/20, 20/20. A faint ghost of the old top-left line still shows
       behind the score's left end in the exe at 0:53 (not fully fixed; my one follow-up is spent).

MENU (round 2; pack path + title; Director-only rows)
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc/.tl/jobs/shield-wall-3-v-20261125-1-jb/promoted/game.shield_wall_3_v@0.1.19
    "Shield wall v0.1.19: a clear screen (made in Create, juice day)"           (replaces the v0.1.18 row as the pick)
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc/.tl/jobs/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.12
    "Bumper-kart football v0.1.12: who got shelled (made in Create, juice day)"
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc/.tl/jobs/biplane-duel-two-biplanes-20261125-1/promoted/game.biplane_duel_two_biplanes@0.1.11
    "Biplane duel v0.1.11: the harpoon taught (made in Create, juice day)"
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc/.tl/jobs/half-court-3-v-20261125-1/promoted/game.half_court_3_v@0.1.11
    "Half-court v0.1.11: the alley-oop taught (made in Create, juice day)"      (note: play moved vs v0.1.9, finding 5)
  In-between versions (biplane v0.1.10, court v0.1.10) are in the same promoted/ folders and need no rows.

ACCEPTANCE (round 2: the same method, rules and clip sizes; one fix sentence per game, at most one follow-up, no
"make it fairer")
- Every old and new version: an exe run in a window (told-keys-only open loop) and an engine-window closed-loop run, a
  clip of 30 s or less at 800x450 crf 32, stills looked at, 3600 headless frames with 0 script errors and the same hash
  twice, the newcomer hand's figures: MET (PROOF "Round 2"). Hashes: karts v0.1.11 08fe071f x2, v0.1.12 08fe071f x2;
  biplane v0.1.9 c38ee476 x2, v0.1.10 e3af709a x2, v0.1.11 4df31017 x2; court v0.1.9 64240fb0 x2, v0.1.10 181bc670 x2,
  v0.1.11 181bc670 x2; shield v0.1.19 b0341c1a x2. Seed 2 also 0 errors for every version. Each promoted pack = the film copy
  I measured (diff -rq: only pack.json's tests list and my tests).
- Sentences: shield 1, karts 1, biplane 1 + 1 follow-up, court 1 + 1 follow-up; no fairness ask: MET (SENTENCES.md).
- Honesty notes: the closed-loop biplane pilot hooks Vesper at about frame 300, right where the pass begins, so the
  window runs show the hook but not the pass's picture; the exe runs show the pass. The court window runs print one
  SCRIPT ERROR at exit from the kernel runner's watchdog thread (worker.gd:387), not from the pack; headless runs: 0.

EDITOR FINDINGS (round 2; PROOF findings 5-8)
5. Court v0.1.10: bodies_first_minute merged poses.gd/mod.gd from a stale workspace (it still held the unpromoted cue
   of the 17:39 failed change); v0.1.9's pose cache is gone and play moved (pack newcomer hand 64240fb0 -> 181bc670),
   not on the card. Main has T2's "refused changes leave nothing behind"; this tree predates it.
6. A builder's remark about where numbers live becomes "the rest of your change" for another package (court r21 copied
   the cue numbers into tuning.json: two homes); karts' "rivals' part" to teams r8 changed nothing.
7. Biplane v0.1.11: core and first_flight both steer Vesper in the pass (core's _lesson_lift stays as dead code).
8. Kernel: the runner's watchdog thread (worker.gd:387) errors at exit in windowed --quit-after runs.

GATES (round 2): node devx/bin/tl.mjs check --tier fast PASS 5/5 at 00:00 (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230,
  foreman.typecheck clean); disk 73 GB free. Full tier not required (docs and .tl/ only).
