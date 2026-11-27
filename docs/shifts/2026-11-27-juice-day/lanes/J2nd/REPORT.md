J2nd REPORT (juice day, 27 Nov 2026, 11:18-15:15 local). Tree .claude/worktrees/d25-kart, branch d27-second (main ccf24701 with lane T's items 1-6).
Details, every figure and the stills with notes: PROOF-J2nd.md in this folder. Sentences word for word: SENTENCES.md.

OUTCOME
All three games got a second crazy ability, ALL BY THE EDITOR (no hand build), through Create changes on job copies
(.tl/jobs/j2nd/, plain copies at 11:20 of karts v0.1.7, biplane v0.1.4, court v0.1.6; originals untouched), sent as
Create sends them (engine/ui/foreman_run.mjs + the "change" flags of engine/ui/flags/real.json, claude-cli sonnet, paid).
  Karts: Mario Kart red shell (boxes, homing shell on F, tumble, SHELLED!, jump over / whirl to swat), 3 sentences:
    v0.1.8 (68 min, 3.79M in / 41.6k out): shell NOT in the game (items never wired; plays exactly as v0.1.7, same hash)
    v0.1.9 (92 min, 3.86M / 28.9k): "switch it on, fix the sound" -> shells live
    v0.1.10 (33 min, 1.49M / 15.8k): the juice named -> big shell + streak, 3-part tumble, deck freeze, SHELLED! 96 pt, warning arrow
  Biplane: whaling harpoon on Q (closing ring, cable, HOOKED!, whip and fling; a roll dodges it), 4 sentences:
    v0.1.5 (51 min, 3.38M / 33.5k): works and reads well; false "NOT made" note; Vesper 0.2 harpoons/min
    v0.1.6 (47 min, 1.94M / 15.5k): her rate raised, no felt change
    v0.1.7 (33 min, 0.87M / 8.6k): she hunts for a shot, HARPOON! ROLL warning
    v0.1.8 (29 min, 1.11M / 9.7k): hunt in every round, HOOKED! big for both, camera pulls back -> Vesper 0.8-1.2/min
  Court: NBA Jam alley-oop off the glass on C (slow beat, push-in, mate slams, ALLEY-OOP!, STOLEN!, brick), 2 sentences:
    v0.1.7 (147 min, about 60 of them a phantom failure; 4.32M / 37.3k): mine land, the bots' never (rivals 0 of 4)
    v0.1.8 (74 min, 4.03M / 25.0k): bots' catchers jump at the throw -> rival oops 3/3 and 4/4 land, STOLEN! happens, word 120 pt
  Total: 10 promotions, 43 model calls, about 24.8M tokens in (mostly cache reads), 216k out.

MENU (pack path + title; Director-only rows)
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart/.tl/jobs/j2nd/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.10
    "Bumper-kart football v0.1.10: red shells (made in Create, juice day)"      keys: F fire a shell, Q jump, E whirl
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart/.tl/jobs/j2nd/biplane-duel-two-biplanes-20261125-1/promoted/game.biplane_duel_two_biplanes@0.1.8
    "Biplane duel v0.1.8: harpoon whip (made in Create, juice day)"              keys: Q harpoon, Shift roll out of her ring
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart/.tl/jobs/j2nd/half-court-3-v-20261125-1/promoted/game.half_court_3_v@0.1.8
    "Half-court v0.1.8: alley-oop off the glass (made in Create, juice day)"     keys: C alley-oop (with the ball)
  Every other version listed above sits in the same promoted/ folders; they need no rows. Note the pack ids are the same
  as the originals' (game.bumper_kart_football_3 etc.); if the menu keys rows by id and version, these versions are new
  (v0.1.8+ for karts and biplane, v0.1.7+ for court) except court v0.1.7, which other lanes may also have made on their copies.

ACCEPTANCE (brief "Done when")
- Juice sheet per game before its sentence (key, wind-up, exaggeration, impact, bots, counterplay, reference): MET (PROOF, 11:25-11:40).
- One sentence per game up to 800 chars naming ability + juice + rivals, sent as a Create change: MET (714 / 682 / 688 chars, 11:24-11:26).
- Judged as a person: window clip <= 30 s at <= 960 px, crf 30 (7 clips, 6-16 s each); stills looked at (21 JPGs, each
  described in PROOF); 3600 headless frames 0 script errors and the same hash twice per pick: MET
  (karts v0.1.10 f7b64a26 x2; biplane v0.1.8 cb37c372 x2; court v0.1.8 60552975 x2; every earlier version too);
  bots' uses per minute: MET (karts mint 5.5-6.9 shells/min, 1.1-2.3 hits; Vesper 0.8-1.2 harpoons/min; rival oops 0.9-1.0 landed/min).
- Follow-up sentences as a person when a part was missing: MET (karts 2, biplane 3, court 1; SENTENCES.md).
- blocked-editor lines with evidence: MET (7 findings below; STANDUP 11:48, 11:58, 12:46, 13:24).
- PROOF with sentences, clips, measures, cost, pack path and menu title per game: MET.
- Honesty: nobody has played these with real keys; every figure is from scripted hands (pack hands + my counting
  tests .tl/j2nd/tests/j2_shell.gd, j2_harpoon.gd, j2_oop.gd, used only in film copies under .tl/j2nd/film/), every
  "feels" line from film. Hand checks: karts v0.1.10 newcomer 17/20, perfect 19/20; court v0.1.8 newcomer 11/20
  (card bound 13; the card says "balance moved ... say make it fairer"), perfect 16/20. The newcomer hands never press
  the new keys.

GATES
- node devx/bin/tl.mjs check --tier fast: PASS 5/5 at 14:12 and 15:12 (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230, foreman.typecheck clean).
- Full tier: not required (no kernel/kits/rigs/style/seeds change; this lane changed only docs and .tl/).
- The Foreman's own final checks passed V0-V4 for all 10 promotions.

CHANGED FILES (tree)
- docs/shifts/2026-11-27-juice-day/lanes/J2nd/: PROOF-J2nd.md, SENTENCES.md, STANDUP.md, REPORT.txt, clips/ (7 mp4, 9.7 MB), stills/ (21 jpg, 3.6 MB).
- Not tracked: .tl/jobs/j2nd/ (the three job copies, all versions), .tl/jobs/_ui_logs/*-j2nd-*.log, .tl/j2nd/ (scripts, tests, film copies, raw mp4s).
- No foreman/, engine/ or contracts/ edits. docs/shifts/2026-11-27-night/lanes/J5-karts/REPORT.txt was untracked before this lane started; not mine.

EDITOR FINDINGS (blocked-editor, for the Director / lane T; evidence in PROOF)
1. Biplane: T's "new attack must land" check wants moves.<move> in a bot test the package's acceptance runs; core's only one
   is the frozen tofu bot; the freeze undoes the edit each round (events 757, 761, 768, 772). After 3 rounds the card said
   "part of your change was NOT made ... the harpoon does not land" (778) while it does land (my test: hooked 1 of 3 in 1 min).
   It cleared only when another package (rival_season) counted it in its own test.
2. Karts: a non-drawing package's NOT DONE hand-off is not routed to the package that owns the file. core wrote the exact fix
   for items.gd in r20-r22; the Foreman never sent it to items, reopened core again (r23-r26) for items' own hand-off, and
   PROMOTED v0.1.8 with the ability unwired (same hash as v0.1.7). After the follow-up, items r2 ran only once core had spent
   another 4 rounds (r27-r30): a deadlock broken by the round limit, not by routing.
3. A Godot run that never started is charged to a package: at 12:32:57, the second the kart copy promoted, two runs in the
   other two jobs failed to start ("the runner wrote no report file", 0.9-1.5 s). Court's hand check read "19 of 20 runs
   finished" as a failed card check (event 1432, "a second failure ends the job unpromoted"); crews_stakes r14 then CHANGED A
   RULE (sudden death ends at +2 points since the tie) to make "that last run finish", and that rule is not on the card.
   Biplane's rival_season got an empty round (846). Likely cause (not proven): promotion work racing other jobs' Godot starts
   on one shared engine/.
4. (= 2, continued) a person's plain follow-up naming both fixes did not break the loop; the round limit did.
5. Karts: core asked the person "wider goals or a shorter match so the pack's own test fits 3 matches?"; the person's answer
   "neither, let your check run longer" cannot be honoured: core's edit to the frozen tofu bot was undone (event 1526). The
   next pack-tofu run passed by itself. The Foreman should not offer a person a question whose third answer it cannot take.
6. Court: a builder's process remark ("Not done this round: bot_tofu, smoke and invariants were not rerun") is shown on the
   card as "part of your change was NOT made".
7. Court: "unasked rule: none added" is listed as an unasked rule.

FOR THE OWNER (15 min)
- Watch clips/j2nd_kart_v0110_juiced_shells.mp4 (a mint shell flips my kart: SHELLED!), clips/j2nd_biplane_v018_vesper_harpoon.mp4
  (HARPOON! ROLL, then she hooks and whips me), clips/j2nd_court_v018_bots_oop_stolen.mp4 (STOLEN!, a huge ALLEY-OOP!, a rival oop).
- Play the three picks with the keys above. Questions a person should answer: is the shell too strong for mint (6-7 shells a
  minute)? does Vesper's harpoon feel fair with the warning? is the court too hard now for a newcomer (11 of 20)?

QUESTIONS FOR THE DIRECTOR
1. Menu rows for the three picks (paths and titles above)?
2. Route findings 1, 2/4, 3 and 5 to lane T: they cost the most time and money today (karts v0.1.8 is a promoted version
   with nothing new in it; court lost an hour and gained an unlisted rule).
3. Finding 3 may also hit other lanes running jobs side by side on one engine/ tonight.

NEXT THREE
1. A person plays the three picks with real keys (the bar is his hand).
2. Lane T: route a NOT DONE hand-off to the package that owns the named file (any package, not only drawing), and re-run a
   check that never started instead of charging a package.
3. A "make it fairer" sentence for court (newcomer 11/20) and a camera tweak so the far shell victim in karts is seen.
