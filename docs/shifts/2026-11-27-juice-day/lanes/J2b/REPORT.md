J2b REPORT (juice day, 27 Nov 2026, 16:14-18:10 local). Tree .claude/worktrees/d25-biplane, branch d27-second-b
(main f2d72951 with lane T's items 1-22). Details, every figure and the stills with notes: PROOF-J2b.md in this folder.
Sentences word for word: SENTENCES.md.

OUTCOME
Both games got a second crazy ability, ALL BY THE EDITOR (no hand build), through Create changes on job copies
(.tl/jobs/, plain recursive copies at 16:18 of robots v0.1.9 and shield v0.1.13 from d25-shield, diff -rq empty;
originals untouched), sent as Create sends them (engine/ui/foreman_run.mjs + the "change" flags of
engine/ui/flags/real.json, claude-cli sonnet, paid). No refusal, no bend, no question in any of the 5 promotions.
  Robot soccer: Rocket League Rumble magnet yank on Q (hold: lightning beam and a closing ring on the ball; let go:
  the ball is ripped to you, even off a rival's feet; YOINK!; a robot in the beam's line breaks it, ZAP!):
    v0.1.10 (1 sentence, 41 min, 3.19M in / 37.5k out): works; rivals yank 4-5 a minute; YOINK!/ZAP! small, beam a
      flat hose on the grass, the ball arrives in 10 frames; card: newcomer 7/20 (was 15)
    v0.1.11 (follow-up, 45 min, 2.76M / 22.2k): big fat yellow YOINK!/ZAP!, a jagged bolt through the air, a half-second
      high arc with a trail, the camera pulls back to show the rival who yanked, my mates yank too
      -> rivals 7-9 yanks a minute, mates 5-7; newcomer 15/20, perfect 20/20
  Shield wall: catapult volley on G (Total War fire pots: LOOSE!, a longship's catapult, three red circles for 1.5 s,
  fireballs, KABOOM!, men flung; walk out of a circle or hold the shield overhead, TURTLE!):
    v0.1.14 (1 sentence, 16 min, 3.31M / 32.4k): a new package "volley", wired through the core's module list on its
      first round; both crews use it (gulls 2 a minute); all parts there but small (words, grey stones, low throws)
    v0.1.15 (follow-up, 14 min, 1.49M / 11.9k): big LOOSE!/KABOOM!, orange fireballs with flame and smoke, men flipped
      head over heels, the camera rises for the volley
    v0.1.16 (follow-up 2, 15 min, 1.89M / 19.2k): the longship's arm visibly flings each burning stone; TURTLE! in
      gold over the man who turtled (it was overwritten by KABOOM! in the same frame before)
  Total: 5 promotions, 15 model calls, about 12.6M tokens in (11.7M cache reads), 123k out.
  The J4b / J2nd lesson held twice more: a first sentence builds every part small; a follow-up that NAMES the juice
  (size, colour, height, camera) makes it read at a glance.

MENU (pack path + title; Director-only rows)
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.11
    "Robot soccer v0.1.11: magnet yank (made in Create, juice day)"         keys: hold Q and let go = yank; F hammer
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/shield-wall-3-v-20261125-1-jb/promoted/game.shield_wall_3_v@0.1.16
    "Shield wall v0.1.16: catapult volley (made in Create, juice day)"      keys: G volley; Space shield up (overhead
                                                                             under the stones); Q call first in round 1
  Every other version above sits in the same promoted/ folders; they need no rows. The pack ids are the existing rows'
  ids (game.robot_soccer_3_v, game.shield_wall_3_v); robots 0.1.10-0.1.11 and shield 0.1.14-0.1.16 exist only in my
  job copies. (Shield note: in round 1 neither crew can volley before the captain's first call; it is on the card.)

ACCEPTANCE (brief "Done when" and steps)
- Juice sheet per game before its sentence (key, wind-up, exaggeration in numbers, impact, bots with and against it,
  counterplay, reference game): MET (PROOF, 16:15-16:21; robots: Rocket League Rumble Plunger/Magnetizer; shield:
  Total War fire pots + testudo; the brief's horn idea was already Q's rally call and the quay has no slope).
- One sentence per game, up to 800 chars, naming ability + juice + rivals, sent as a Create change: MET (772 / 784
  chars, 16:22; dry starts checked within 2 min).
- Judged as a person, for every version: window clip <= 30 s, 800 wide, crf 32 (5 clips, 10.5-30 s); stills looked at
  (21 JPGs, each described in PROOF); 3600 headless frames with 0 script errors; the same hash twice; bots' uses per
  minute: MET
    robots v0.1.10 cac479a8 x2, v0.1.11 a4f04e48 x2; shield v0.1.14 d45ff736 x3, v0.1.15 d7b1e462 x2, v0.1.16
    9fdaaac6 x2; seeds 2-3 also 0 errors for every version. Each promoted pack is file for file the film copy I
    measured (diff -rq: only pack.json's tests list and my counting test).
- One or two follow-ups as a person when parts were missing: MET (robots 1, shield 2; SENTENCES.md).
- blocked-editor line: NONE NEEDED (the editor never blocked); 5 editor findings below.
- Disk: raw film deleted after every cut (.tl/j2b/raw empty; .tl/j2b 25 MB incl. 5 film copies).
- PROOF with sentences, clips, measures, cost, pack path and menu title per game: MET.
- Honesty: nobody has played these with real keys. Every figure is from scripted hands (the packs' own hands plus my
  counting tests, on film copies only: .tl/j2b/tests/j2b_magnet.gd, j2b_volley.gd; copies in this folder as
  .gd.txt); every "feels" line is from film and stills. Not met by eye: robots' beam and trail are built of chunky
  boxes (no kit part draws a beam), so the "lightning" reads as stacked blocks; my own robot's yank of a loose ball shows
  no word; the crew's own volleys launch from a ship off the left edge of the play camera.

GATES
- node devx/bin/tl.mjs check --tier fast: PASS 5/5 at 17:20 and 18:07 (arch 12/12, assets 4/4, cards 3/3, devx.test
  230/230, foreman.typecheck clean).
- Full tier: not required (no kernel/kits/rigs/style/seeds change; this lane changed only docs and .tl/).
- The Foreman's own final checks passed V0-V4 for all 5 promotions (robots: 40 hand matches each).

CHANGED FILES (tree, all untracked, in the lane folder)
- docs/shifts/2026-11-27-juice-day/lanes/J2b/: PROOF-J2b.md, SENTENCES.md, STANDUP.md, REPORT.txt,
  j2b_magnet.gd.txt, j2b_volley.gd.txt (the counting tests, for the record; .txt so arch's uid rule is not hit),
  clips/ (5 mp4, 15 MB), stills/ (21 jpg, 7.5 MB).
- Not tracked: .tl/jobs/robot-soccer-3-v-20261125-1 and .tl/jobs/shield-wall-3-v-20261125-1-jb (the job copies, all
  versions), .tl/jobs/_ui_logs/*-j2b-*.log, .tl/j2b/ (scripts, tests, film copies, the small cut clips).
- No foreman/, engine/ or contracts/ edits. docs/shifts/2026-11-27-juice-day/lanes/S35-packs/REPORT.txt and
  docs/shifts/2026-11-27-night/lanes/J11-biplane/REPORT-J11b.txt were untracked before this lane started; not mine.

EDITOR FINDINGS (for the Director / lane T; evidence in PROOF)
1. Robots: T's rivals routing sent "my own bot teammates should use the magnet too" to brain (r4) while core built it
   (decisions in core's magnet.gd); brain r4 changed nothing (about 0.6M tokens, 6 min). When the bot decisions for a
   new verb live in the package that builds it, the rivals copy is redundant (JB-back's duplicate shape, from routing).
2. Robots: the frozen whole-pack tofu bot cannot finish 3 matches in 36000 frames once the ability lengthens matches.
   For core r22 and brain r4 it was a "not judged" balance note; for show r8 a failed V4, then passed on a longer re-run
   (events 1720-1721). Same root as J2nd finding 5, answered differently per package.
3. Robots core r21 failed KIT REGRESSION (BoxMesh.new in a new script); r22 moved the meshes into gen/robot.gd's existing
   helpers and passed: the check counts places, not meshes. Shield's ship, arm and cup are TLBodies boxes ("no kit part
   is a catapult"). Question: intended, or should a beam / ring / catapult become kit parts?
4. Shield volley r4 overrode its contract's stone timing and said so in its note ("change request wins over the
   contract"); a person reading the card's first lines would not see it. Cosmetic.
5. Robots v0.1.10's card flagged "a newcomer player now wins 7 of 20 (was 15)"; the juice follow-up (mates yank too)
   brought it back to 15/20 unasked. The newcomer hand never presses Q, so the bots' use of a new ability moves that
   figure both ways.
Game finding fixed by the editor: shield v0.1.15 showed TURTLE! and then replaced it with KABOOM! in the same frame
(scripts/volley/shot.gd impact()); v0.1.16 draws TURTLE! over the man.

FOR THE OWNER (10 min)
- Watch clips/j2b_robot_v011_magnet_yoink.mp4 (a bolt, the ball's arc, a rival rips the ball off me: the camera pulls
  back, YOINK! fills the screen) and clips/j2b_shield_v016_launch_turtle.mp4 (the longship flings burning stones,
  TURTLE! and BRACED! at the impact); clips/j2b_shield_v015_fireballs.mp4 for four volleys from the lifted camera.
- Play the two rows with the keys above. Questions a person should answer: robots: is 7-9 rival yanks plus 5-7 by my
  mates a minute too much (the ball changes hands very often)? shield: is a gull volley every 30-60 s fair with 1.5 s
  to walk out or turtle?

QUESTIONS FOR THE DIRECTOR
1. Menu rows for the two picks (paths and titles above)?
2. Route findings 1-3 to lane T (the redundant rivals round; the frozen tofu vs longer matches; kit parts for beams,
   rings and catapults).

NEXT THREE
1. A person plays both picks with real keys (the bar is his hand), especially the robots' yank rate.
2. Robots: one sentence for a glowing beam and trail instead of stacked blocks, if a kit beam exists, else a kit part.
3. Shield: let the crew's own volley launch from a ship the play camera can see (or a quick cut to it), so my own
   volleys show the launch too.
