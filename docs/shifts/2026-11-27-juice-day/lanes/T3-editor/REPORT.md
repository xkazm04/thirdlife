T3-editor: the last editor findings of the juice day (night of 27-28 Nov 2026, from 21:35)
Tree d25-hard-a, branch d27-tofu (main f6592f87). Nothing is committed: the Director lands it.

HOW IT WAS BUILT
- Every item is a new module, with tests on the real events of the job where the finding was seen.
  - New modules: personwords.ts, playsplit.ts, textowner.ts, longernote.ts, narrowed.ts, botsdone.ts.
  - Fixtures: foreman/fixtures/d27t3/, real events copied from the evidence jobs. I read those jobs and never changed
    them.
- foreman.ts stays at 2005 lines. I changed only lines that T2's diff does not touch (T2's tree d25-court, branch
  d27-tofu2):
  - one import line (26);
  - the rivals line in applyChangeRequests;
  - the afterMerge line in mergeAndGate.
- T2 is editing builder.md, fastchange.ts, halfmade.ts, landcheck.ts, boundlift.ts, scopegrant.ts, unmade.ts, asktwice.ts
  and Create. I did not edit any of them; I import from boundlift, halfmade and rivals only.
- Live proofs run on copies under .tl/t3/jobs, cut back with lane T's .tl/d27/rollback.mjs. Each sentence is sent once,
  word for word, with the change flags of engine/ui/flags/real.json (claude-cli, sonnet).

OUTCOME AGAINST EACH ITEM

38. A question comes only from the person's words: MET (unit and live).
- Cause (J2b's Arsenal copy, events 1278-1285):
  - the cartridge's pre-check (coregate.ts cartridgeChange, unseenChange) judged the Foreman's whole hand-off text;
  - one catalog row in that text, contact.check_reach_m, reads "easier to land (Cage, Bruisers 2)";
  - EASIER_WORDS matched it, and the job paused on "should the bots be weaker still?".
- Fix (personwords.ts personWords): for a Foreman request, the words judged are the person's asks of the change in flight
  (askedChange). Off a person's change they are "".
  - It is used by all three places that ask back or claim from words: absentInChange, unseenChange and
    askedFigureMiss.
- Unit test D27 T3 38, on the real events:
  - main's call on event 1278 gives event 1283's exact question;
  - now: no question.
- Live (l1 and l2, below): neither paid job asked a question. J2b's first run paused here for 1 min, waiting for the
  person's answer.
- Said plainly: with item 37 in place, the cartridge gets the person's words directly, so the hand-off that carried the
  catalog row did not happen live. The very path that asked J2b is proven on its real event (1278) by the unit test, not
  by a live run.

39. keyfind searches effects and triggers too: MET (unit and live).
- Cause:
  - keyfind's catalogRows kept only keys matching /^[a-z][\w.*]*$/, so no list-entry row (`game.effects[].trigger`,
    `game.effects[].stats[].stat`, ...) was ever a candidate;
  - a row's listed values (check_landed, skater_mass) were never searched;
  - the quick cartridge diff's prompt holds only CARTRIDGE.md sections 3 and 5, where effects[] reads "timed changes to
    stats ... given by pickups, zones or hooks" and names no trigger.
- Fix (keyfind.ts; coregate.ts diffCatalog):
  - list-entry keys are read;
  - a row's enum values are searched, and a snake_case value whose words are all in a clause is a hit ("a landed
    check" meets check_landed). The hint names it as `key = value`;
  - rows with a value hit go first, with the list they belong to;
  - the quick diff gets "Rows of the full key list (section 7) that the words of this change meet", with every row of
    each list it meets (catalogFor, at most 30 rows).
- Unit test D27 T3 39, on harbour r20's real NOT DONE (event 1262):
  - the candidates are now game.effects, game.effects[].trigger = check_landed, and game.effects[].stats[].stat =
    skater_mass | skater_speed | skater_turn_rate;
  - main's real hint (event 1277) named no effect key;
  - lane T's D27 3 (J1's winding-up line) still passes.
- Live (l1): the quick diff (event 1261, 10.6 s, 16k tokens) wrote exactly the effect:
  - `mega`, trigger check_landed, target self, 300 frames, stack refresh;
  - mass x2, speed x1.1, turn rate x0.6, check_speed_min x0.5.
  - J2b's diff said "no key says it", and cartridge r14 then needed a builder to find the same effect.

37. On a core, play rules go to the cartridge's owner first: MET (unit and live).
- Cause (J2b's Arsenal copy, events 1258 and 1319-1342):
  - coreowner.ts playOwner keeps the Planner's owner whenever the words also name a picture (DRAW_WORDS);
  - so MEGA's stats, and "they should land their body checks on me and my mates more often", went to harbour, the
    drawing package;
  - both reached the cartridge only through the NOT DONE hand-off, after a drawing round that wrote the rule as drawing
    ("RULE: MEGA is drawing only") and guessed a key ("raise game.ai.body_check from 0.6 to 0.9"; it is 1).
- Fix (playsplit.ts playSplit, called on the rivals line of applyChangeRequests, foreman.ts +0 lines):
  - on a game on a core, a person's change whose sentences ask for play goes to the cartridge's owner first;
  - "Ask for play" (PLAY_ASK) means: a rule, a stat or how often ("lands a body check", "twice as heavy", "turns wide",
    "more often", "cooldown"). A comparative or a knockdown counts only in a sentence that names nothing to see. Quoted
    words are text to show, never an ask;
  - the package the Planner named gets "[foreman] the drawing part of change request N, ...". It runs after the
    cartridge's merge when it depends on the cartridge (harbour does), and draws what the cartridge made (its effect
    ids and events), never a copy of the rule.
- One more defect the live run showed, fixed in this round (playsplit.ts drawnElsewhere and playWhy, coregate.ts):
  - the quick diff made the play exactly, and said "No key can say the white flash ... so a builder has to add those";
  - item 29's check (diffLeavesUnmade) then gave the whole change to the cartridge's builder;
  - now, when the drawing went to another package, sentences that name only a picture or a sound do not count as
    unmade. A play part the diff could not make still goes to the builder (test 37b).
- Unit tests D27 T3 37 and 37b, on the real events 1255 and 1319 and the live diff:
  - main keeps harbour (coreChangeOwner) for both;
  - now the cartridge goes first and harbour gets the drawing;
  - every other ask of the job that the Planner gave harbour (the edge arrow 1373, the HOME text 1411 and 1489, and
    1073-1217) stays harbour's;
  - J1's meteor (1005) goes to the cartridge first. Lane T's round 1 needed the hand-off to reach its shotgun mode.

43. A drawing-only change is not told "balance moved: matches now run longer": MET (unit).
- Cause (N-newcomer's robots copy, event 1828):
  - longerMatch wrote BALANCE_MOVED whenever the frozen tofu bot needed more frames in a person's play change;
  - the matches were as long before the change: the last change's final run needed 41149 frames (event 1733), and this
    one needed 41149 with the same state hash.
- Fix (longernote.ts, through tofugate.longerMatch):
  - the newest passing longer run of the same test before the change is the measure;
  - within 5 % of it, the note is "[foreman] already outside before your change, not judged as its regression: matches
    ran longer than tests/bot_tofu.gd plans (36000 frames) before your change too: it needed 41149 frames then (...) and
    41149 now, the same play to the frame (the same state hash). Your change did not make them longer.";
  - a change that does make them longer is still told so, with the frames before it ("...; 41149 before your change").
  - The run counts in both cases, as before.
- Unit test D27 T3 43, on the real events 1590-1828 and the 40 real tofu reports of that job: event 1828 (main) said
  "balance moved"; the same input now gives the "already outside" note.

35. One rule for longer matches in every package: MET (unit).
- What I found (J2b's robots copy, events 1700-1733): the rule WAS the same for every package.
  - brain r4's pack check (1700), show r8's pack check (1720) and the final (1732) all went through verifyLogged ->
    longerMatch, and all were run again with 108000 frames and passed (41149 used).
  - The difference was what was said. The note is written once a change, so brain r4 got "matches now run longer ... (not
    judged in this change)", and show r8 got nothing: its round read as "bot (V4) failed", then a pass, with no word.
- Fix (longernote.ts judgedLongerLine, roundTold):
  - every package round whose check the longer run decided now gets its own line: "[foreman] judged on a longer run:
    tests/bot_tofu.gd was not done within 36000 frames, so it ran again with 108000 and passed (41149 used), as told
    for this change; this is not a failed check of this round";
  - the person's note stays once a change. Item 43 applies here too: brain r4's note is now "already outside before your
    change", because the v0.1.10 final needed 57217 frames (event 1598).
- Unit test D27 T3 35, replaying 1700, 1720 and 1720 again on the real reports: one line for brain r4, one for show r8,
  and none for the repeat. Main wrote nothing on show r8 (the real log).

34. A rivals' part the owner already made costs no round: MET (unit; a scan of every real rivals' part).
- Cause (J2b's robots copy, events 1653-1706):
  - "And my own bot teammates should use the magnet too." went to core (the Planner) and, as the rivals' part, to brain;
  - core r23 made it: "the magnet bot logic now runs for team 0 mates (ids 1 and 2) as well as rivals";
  - brain r4 then ran anyway, 0.81M tokens in and 3.7 min, and changed nothing in its own AI.
- Fix (botsdone.ts botsDone, on the afterMerge line, +0 lines): after the owner's merge, a package can wait for nothing
  but a rivals' part of the owner's change. That is: its last reopen is that request, it is queued, no builder has run
  for it, and no other request came.
  - When the owner's own words say its code now makes the bots the person named do it, the package is not opened.
  - "Its own words say it" means: the same group (mates, rivals or the bots), an including word ("as well as", "also",
    "too", "for all"), a word of the person's sentence, and no NOT DONE.
  - The package gets a note in the owner's words and goes back to promoted with no round.
- Unit test D27 T3 34, on the real events:
  - at core's merge (1673), brain is closed with core's sentence;
  - J19's core r14 note (its brain.gd drives one bot, crew's mind.gd four) does not close crew;
  - once brain has started, nothing is taken back.
- Scan of every rivals' part in every job on this machine (16 distinct):
  - only J2b's brain r4 is closed;
  - each of the other 15 merged real mind files (crew/mind.gd, crews/brain.gd, ...).

44. A narrowed ask reads as "part of your change was NOT made": MET (unit; a scan of 26 real jobs).
- Cause (N-newcomer's shield copy, events 1506-1524):
  - the person asked "if I press Q while I am down, stunned or mid-move, ... blow the horn the moment I am free again";
  - rally keeps the press only while busy: "The kept press is dropped if the bar is no longer full, the captain falls,
    or a call is already running";
  - its summary even said "pressing Q while your captain is down ... now keeps the press";
  - the card and Create showed no "not made".
- Fix (narrowed.ts narrowedNotes, on the afterMerge line): at a package's merge in a person's change, a builder sentence
  that drops, ignores or refuses something in a state one of the person's own conditions names (down, stunned,
  mid-move, in the air) is a note:
  "[foreman] part of your change was NOT made: rally made it for fewer cases than you asked: you asked "if I press Q while I am down, ...", and rally says (down): "The kept press is dropped if ... the captain falls, ...""
  - That prefix is what Create's not_made_note and the card's NOT made lines read, so the person sees "Not made: ..."
    with no change to Create.
- Unit test D27 T3 44, on the real events: one note, once; a drop in a case the person did not name is not flagged.
- Live, l2 (this lane's own copy), my first version made a false note (event 1371), which stays in that copy's log:
  - the person asked "When a rival knocks me down, YOU ARE MEGA! stays on screen ...: take it away the moment I fall";
  - harbour wrote "it is cleared the moment the player is down", which is exactly the ask;
  - the note said "part of your change was NOT made".
- Fixed:
  - "cleared" is not a drop;
  - a condition whose sentence asks to take something away (take away, remove, hide, clear) is not narrowed by
    removing it;
  - builder sentences split only before a capital ("FLATTENED! shows" no longer cuts a sentence).
  - Test 44b is on that live event.
- Scan of every builder note against its change's words in 26 jobs, after the fix: exactly one hit, N's rally line.
- Weakness: this is a word rule, not an understanding. It found the one real case and, before the fix, made one false
  one. A model check is the stronger form if more narrowings slip by it.

45. One owner per text the person reads: MET for the routing (unit; scan).
- Cause (N-newcomer's Arsenal copy, events 1489-1496):
  - "Make every line of the ONE MATCH card fit" went to harbour;
  - harbour put the card's lines in its own data/tuning.json harbour.about_lines and drew them over the skin's `about`:
    "its two long `about` lines are no longer shown. If its owner edits `about` later, nothing on screen changes".
- Fix (textowner.ts textSplit, before playSplit on the same line):
  - the person's change goes first to the package whose data file holds words the person quotes and asks to change
    (a TEXT_ASK word beside the quote: too long, cut off, sticks out, fit, still says, ...);
  - the Planner's package gets the drawing, with "never keep a copy of them in your own files, and never draw your own
    text over theirs; a word that must change is skin's (a NOT DONE line naming data/skin.json)".
- Unit test D27 T3 45, on the real event 1489 and v0.1.31's data files:
  - skin goes first, holding "your shot floors everyone";
  - quotes the Planner's own package holds, or that nobody holds, do not split;
  - a quote given as a reference (N's shield 1506: "the G key keeps saying "after your Q call"") is not an ask.
- Scan of every person's change in every job:
  - exactly two split, N's 1411 ("The HOME screen still says "F pops your bubble ..."", which harbour r23 handed on to
    skin anyway) and 1489;
  - the first version of the rule also caught 1506, which is why TEXT_ASK is there.
- Not built: a merge-time guard for a builder that draws its own copy anyway. The same scan of builder notes finds the
  pattern a second time (S4's arsenal 808: "scripts/main.gd overrides the skin's tagline with harbour.tagline"). It is
  next on my list.

LIVE PROOFS (items 37, 38, 39; paid, claude-cli sonnet)
- Copy: J2b's Arsenal job (d25-biplane/.tl/jobs/three-against-three-hockey-20261125-1) cut back to v0.1.27 (event 1254),
  in .tl/t3/jobs/three-against-three-hockey-20261125-1. J2b's own sentences are sent word for word.
- l1, J2b's MEGA sentence (event 1255), sent once at 22:03:40, promoted v0.1.28 at 22:28:13 (24.6 min).
  - 6 model calls, 2.97M tokens in, 31.8k out.
  - J2b's run took 21.5 min, 4 calls and 1.93M in, and paused on a question.
  - What happened:
    - event 1258: the Planner said harbour; playSplit sent the play to cartridge first and the drawing to harbour;
    - no question was asked;
    - the quick diff (1261) wrote the `mega` effect exactly (check_landed, mass x2, speed x1.1, turn rate x0.6,
      check_speed_min x0.5);
    - item 29's check refused that diff for "a builder has to add" the drawing. That was a defect, fixed after this
      run (37b), so cartridge r14's builder wrote the same effect (138 s, 0.36M);
    - harbour r21 got the drawing request and the cartridge's NOT DONE joined into one round. It draws MEGA from the
      core's effect_start/effect_end "mega" events: "No play rule is copied; the drawing only". J2b's finding 9 (the
      drawing and the rule can disagree) is tied here;
    - harbour r22 fixed its own lint;
    - harbour r23 was the land gate's "NEW MOVE: none" parse (T2's file; see FINDING).
  - Measured, with J2b's own counter (tests/j2b_rink.gd on a film copy), seeds 1-3, 3600 frames, 0 script errors:
    - hashes 7df3f5a1 (twice), 57e41c10 and f0c6699b, the same three hashes as J2b's v0.1.28;
    - MEGA starts me/rivals/mates 4/1/1, 3/1/0, 2/1/0, also the same.
    - J2b's mega effect differs only in check_speed_min (x0.25; mine x0.5), which these seeds never reached.
    - So it is the same game, from the one sentence and with no question.
  - Film: clips/t3_ars_v028_mega_cartridge_first.mp4 (seed 1, frames 360-1500, 19 s, 0 script errors). Stills I
    looked at:
    - stills/t3_v028_mega_f384-480_sheet.jpg: my green #7 lands a check, white sparks, he balloons with MEGA! in
      yellow over him, and an orange rival lies flat. Then an orange rival checks me: I lie flat and he grows, with
      MEGA! over him.
    - stills/t3_v028_mega_flatten_f1350-1458_sheet.jpg: my giant at their net, rivals floored. FLATTENED! is a
      small orange word at the top of the screen, twice, piling up. The camera sits close behind the giant.
    - As a person: the giant reads at once both ways. The small, piling FLATTENED! and the close camera are exactly
      what J2b's follow-up asks to fix.
- l2, J2b's follow-up (event 1319), word for word, sent at 22:34:52 on this copy's v0.1.28, promoted v0.1.29 at 22:52:24
  (17.5 min).
  - 3 model calls (the Planner, the quick diff, harbour r24), 2.24M tokens in, 21.9k out.
  - J2b's run took 16.4 min, 3 calls and 0.85M in.
  - What happened:
    - event 1338: the Planner said harbour again ("how often the bots land body checks ... live in
      scripts/main.gd"); the play went to cartridge first;
    - the quick diff made it with no builder: game.contact.bot_check_windup_frames 12 -> 6, the same key J2b's diff
      found. It was kept although its words say the camera and the words need a builder (37b, live);
    - harbour r24 drew the camera (4 m back, 2.5 m up while MEGA) and the big MEGA!/FLATTENED! words on a HUD layer,
      one FLATTENED! at a time.
  - v0.1.29's card carries one false line, "part of your change was NOT made: harbour made it for fewer cases ...",
    from the first version of item 44. It is fixed and tested (44b); the line stays in that copy's log.
  - Measured the same way, seeds 1-3, 3600 frames, 0 script errors:
    - hashes 45fa13fd (twice), 468e8acb and 9bced1db, the same three hashes as J2b's v0.1.29;
    - rival giants 1/1/4 a minute, my mates 1/1/2, me 2/2/2. J2b's table has the same figures.
  - Film: clips/t3_ars_v029_mega_followup.mp4 (seed 1, frames 360-1500, 19 s, 0 script errors). Stills I looked at:
    - stills/t3_v029_mega_cam_f384-492_sheet.jpg: when I go mega the camera rises and pulls back, and my whole giant #7
      stands in the frame with the rink around him. FLATTENED! is big and yellow over the man who goes down, one word at
      a time. Then a rival floors me: no YOU ARE MEGA! is left on screen, and a big MEGA! sits over his giant.
    - stills/t3_v029_mate_mega_f756-864_sheet.jpg: my mate #13 goes giant and flattens a rival, with FLATTENED! over
      him.
    - Flaw a person sees: when the man is near the screen's edge, FLATTENED! is cut by the edge ("ATTENED!"), because
      it is drawn at his projected point and not kept on screen.
    - As a person: the four asks are met. It reads like J2b's v0.1.29 pick.
- Menu rows, if wanted (the owner already has J2b's v0.1.29 row, and these play to the same hashes):
  - .tl/t3/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.29: "Arsenal
    hockey: MEGA, play first (editor T3)".

GATES ON d25-hard-a (final source)
- foreman npm test: 518 tests, 511 pass, 0 fail, 7 skipped (run 3, 22:51-22:57). Main: 508/501/0/7. The +10 are
  d27t3_editor.test.ts.
  - Run 1 is void: I rebuilt dist while it ran.
  - Run 2 (517/510/0/7) came before the 44b fix.
- node devx/bin/tl.mjs check --tier fast: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230,
  foreman.typecheck), 22:56, after the last source change.
- create.: not run. engine/ui is untouched.
- Full tier: NOT RUN. The kernel, kits, rigs, style and seeds are untouched.
- foreman.ts: 2005 lines.

PROPOSED JOB.md TEXT (Director-only)
- A question to the person, or a claim about what they asked ("you asked for matches of about N minutes"), comes only
  from the person's words. For a Foreman request, those are the person's asks since the last promotion, never the
  Foreman's text.
- `[foreman] the drawing part of change request N, for what your files show ...: "<cartridge owner>" makes how it plays
  first ...`: on a game on a core, a person's change whose words ask for play goes to the cartridge's owner first. The
  package the Planner named gets the drawing.
- The same request, starting "...: the words the person quotes (...) are "<X>"'s, in <file>": words the person quotes
  and asks to change, held in one other package's data file, go to that package first. The drawing package may not
  keep a copy of them.
- `[foreman] already outside before your change, not judged as its regression: matches ran longer than <test> plans
  (<n> frames) before your change too: ...`: the frozen test needed as many frames before the change (within 5 %); the
  change is not told it made matches longer.
- `[foreman] judged on a longer run: <test> was not done within <n> frames, so it ran again with <m> and passed (<u>
  used), as told for this change; this is not a failed check of this round`: on every package round the longer run
  decided.
- `[foreman] part of your change was NOT made: X made it for fewer cases than you asked: you asked "<the person's
  condition>", and X says (<state>): "<its sentence>"`.
- `[foreman] the rivals' part of change request N needs no round of P: <owner> made those bots do it in its own files,
  in its words: "..."`. With it comes a package_state `promoted` for P with no round, detail "not opened: ...".

FINDING FOR LANE T2 / THE DIRECTOR (landcheck.ts is T2's file; I did not edit it)
- harbour r22 (my live copy, event 1286) wrote "NEW MOVE: none (MEGA is a timed effect on the core's existing body
  check, as the cartridge said)".
  - newMovesOf read it as a move with the id "none", and the land gate sent the round back (event 1298).
  - harbour r23 then reported a `moves.none` count to satisfy it: a wasted round (68 s, 0.42M in), and a card line
    "new move lands ...: none landed 2 of 4".
- The fix is one condition in newMovesOf: drop the ids none, no, nothing, n/a. I left it for T2, who owns the file
  today.

CHANGED FILES
- foreman/src, new modules:
  - personwords.ts (38);
  - playsplit.ts (37);
  - textowner.ts (45);
  - longernote.ts (43, 35);
  - narrowed.ts (44);
  - botsdone.ts (34).
- foreman/src, edited:
  - coregate.ts: personWords at the three ask-back and claim sites; diffCatalog takes the change's words;
    drawnElsewhere/playWhy before diffLeavesUnmade;
  - keyfind.ts: list-entry keys, enum values, value hits first, catalogFor;
  - tofugate.ts: longerMatch uses longernote; longerNote names the frames before the change;
  - foreman.ts: 2005 lines, +0. One import line; the rivals line (textSplit ?? playSplit); the afterMerge line
    (narrowedNotes, botsDone).
- Tests and fixtures: foreman/src/test/d27t3_editor.test.ts (10 tests); foreman/fixtures/d27t3/ (8 JSON excerpts and
  v0.1.31's four data files of N's Arsenal copy, 330 KB).
- Lane folder: STANDUP.md, REPORT.txt, clips/, stills/.
- Not touched: contracts, the kernel, kits, rigs, style, seeds, engine/ui, any of T2's files.

BEHAVIOUR CHANGES (named)
- On a game on a core, a person's change whose words ask for play goes to the cartridge's owner first. The Planner's
  package gets the drawing after that merge (37).
- Words the person quotes and asks to change go first to the package whose data file holds them (45).
- The cartridge's pre-checks and the figure-missed claim read only the person's words (38).
- keyfind and the quick cartridge diff see list-entry keys and their values (39).
- A quick diff that leaves only the drawing to another package is the round (37b). Before, it went to the builder.
- Matches that ran as long before the change are no longer the change's "balance moved" (43). Every round the longer
  run decided gets a line (35).
- A builder's narrowing of the person's own condition is a "part of your change was NOT made" note (44).
- A rivals' part the owner made, in its own words, opens no round (34).
- No existing test expectation moved: npm 518/511/0/7 against main's 508/501/0/7, and every new test is in
  d27t3_editor.

QUESTIONS FOR THE DIRECTOR
1. Land the "NEW MOVE: none" fix in landcheck.ts (T2's file) with T2's batch, or let me make it after T2 lands?
2. 45's merge-time guard (a builder that draws its own copy of another package's text anyway): build it next, or leave
   it to the routing? It recurs: S4's arsenal 808 is a tagline override.
3. 36 is the owner's call: kit parts for the ring and the beam (my recommendation), or the check counting meshes.

NEXT (what this lane would do)
1. The landcheck "none" fix, and 45's guard (a note and a hand-off when a builder's note says its text is drawn over
   another package's).
2. Item 30: `foreman revert`, built to the plan above.
3. The second-hop NOT DONE of a package that got a drawing part. The cartridge's builder (l1, event 1278) still wrote
   NOT DONE for the drawing that harbour already had. The fold joined the two into one harbour round, so it cost
   nothing this time, but the line on the card reads as if it went on because of the hand-off.

WRITE-UPS (no code)

30. `foreman revert <job> --to <version>`: design and test plan
- Why (JB-back round 5): the person wanted v0.1.11's charge rate back after v0.1.12. The Foreman has no way back, and
  copying files by hand would fake the job's history. So the person had to describe the old behaviour in a new sentence.
- Rule: history is never rewritten. A revert is a new version whose files are an older version's. Example: "v0.1.14 is
  v0.1.11 again". The log only grows, the menu and Create still point at the newest version, and the next sentence is
  judged against v0.1.14.
- Command: `foreman revert <job> --to 0.1.11 [--why "<person's words>"]`. Create gets a "Go back to this version" row
  on the version list. That row runs the same command through engine/ui/foreman_run.mjs.
- Refused (exit 2, in plain words) when:
  - a Foreman process holds the job (the inbox/lock rule: a revert is not an inbox entry);
  - the job is running or waiting on a question;
  - the version is unknown, or its promoted/<pack>@<version>/pack.json is missing;
  - the version is already the newest ("nothing to go back to").
- Steps (one process, under the job's lock):
  1. Keep the current pack/ in reports/revert-s<seq>/pack, as restoreLastPromotion does for an unmade change.
  2. Copy promoted/<pack>@<version> into pack/ and write the next version into pack.json.
  3. Cut every workspace again (ws/<id> and its baseline). This is J2nd's finding 11 from the other side: no workspace
     may carry later edits.
  4. Write one `merge` event per package, giving its merged-file list as it was at that promotion. To get those lists,
     fold the events up to the old `promoted` event (foldEvents, as unmade.ts does). Files merged since then go in
     `removed`. The log and pack/ then agree, and resume's "every merged file is in pack/" check holds.
  5. Write a note: `[foreman] reverted: v0.1.14 is v0.1.11's pack again (asked by the person: "<why>")`.
  6. Run the final verification once (fastFinal: lint, smoke, the plan's bots, the card's hand checks). The engine and
     kernel may have changed since v0.1.11, so an old pack is not assumed to pass. Then promote as v0.1.14, with the
     usual `promoted` and `job_state done` events.
  7. If the final verification fails, nothing is promoted. pack/ goes back to the version that was newest before the
     revert, and the person reads why.
- What is not reverted:
  - the plan: a package grown after v0.1.11 stays in the plan with no merged files;
  - the brief, the ledger, the reports, the inbox.
  - The what-changed card of v0.1.14 reads "went back to v0.1.11: <files that differ from v0.1.13>". A revert is the
    person's change, so askedChange should start after it. That needs one line in askedChange: a revert note counts as
    an end, like a promotion.
- Contract (Director): a JOB.md entry for the verb, the note's first words, and the rule "a revert is a new version". No
  new event type is needed (merge, note, verify, promoted). If the Director prefers a `reverted` event
  {from, to, version}, it is a contract change to events.ts's schema.
- Test plan:
  - Unit, on the paddle fixture with the fake builder:
    - run to v0.1.1, change to v0.1.2, change to v0.1.3, then `revert --to 0.1.1`;
    - pack/ is byte-equal to promoted v0.1.1, except pack.json's version;
    - promotions are 4 and the newest is 0.1.4;
    - every package's mergedFiles equal those at v0.1.1, and rebuildState agrees with pack/;
    - the next `change` reopens from v0.1.4, and its card says "since v0.1.4";
    - each refusal above is tested: exit 2 with its words, the log unchanged;
    - a kill between steps 2 and 6 resumes to a consistent state (the same rule as restoreLastPromotion), or leaves
      v0.1.3's pack/ in place.
  - Determinism: the same seed gives the same state_hash on v0.1.1 and on v0.1.4 (headless smoke and the plan's tofu
    bot).
  - Live, on a copy: JB-back's shield job at v0.1.12, `revert --to 0.1.11`, then JB's round-5 sentence. Expected: a
    v0.1.14 whose charge rate is v0.1.11's (bots_charges 9.5 a minute over 6 seeds, the bot_braced_count hand), and
    then the sentence applied to it. A window still of the HOME card version line.
  - Create: the version list shows the revert as its own row ("v0.1.14: back to v0.1.11"). create.iterate.model gets one
    case.

36. The kit check counts places, not meshes (J2b finding 3)
- What the check measures: lint.gd composability.bypasses counts source places outside gen/ that build a primitive by
  hand (BoxMesh.new(), materials, lights and the like). Rows of the geometry table are skipped under gen/ by design:
  gen/ is where a pack may build its own geometry (lint.gd: "rows from here up to geometry_to are skipped under gen/").
  The Foreman's KIT REGRESSION compares the count before and after a round.
- What happened:
  - Robots core r21 put four BoxMesh.new() calls in scripts/view/magnet_look.gd and was refused (bypasses 4 -> 8).
  - core r22 moved them into gen/robot.gd's existing ring and box helpers and passed.
  - Shield's longship, catapult arm and cup are TLBodies.make boxes ("the kit has no ship part").
  - So the check is met by moving the code, not by using kit parts. That follows its own rule (gen/ is allowed), but
    the look is still boxes: the beam reads as "stacked blocks rather than a glow" (J2b's film).
- Options for the owner (kit, rigs and style are the Home session's files; this lane did not touch them):
  A. Keep the rule and add the parts that recur as kit parts. A ring/disc on the ground (target rings, landing rings,
     lock rings: robots, shield's slam, Arsenal's meteor ring) and a beam/bolt (a chain of glowing segments between
     two points: the magnet, a lock-on, a tether) are generic. Every sports and action game here has drawn them by
     hand at least once.
  B. Keep game-specific props (longship, catapult, cup) as TLBodies.make shapes in gen/. They are scenery for one game,
     and a kit part for each would grow the kit without reuse.
  C. Count meshes, not places. The runner could count MeshInstance3D nodes whose mesh does not come from TLKit/TLMesh
     at a frame of the smoke run. That would refuse a helper in gen/ that makes 40 boxes, but it would also refuse every
     gen/ procedural mesh the kit rules allow today. It is a rule change for the kit contract (KIT.md, Director and
     owner).
- My recommendation: A for the ring and the beam (the two that recur), B for props, not C. The decision is the owner's,
  as the brief says.

==========================================================================================================================
ROUND 2: the Director's rulings after the landing (d0eb5bbf; main = 89f64291 with T2's rounds), 23:10-
Tree d25-hard-a (now main). Not committed: the Director lands it.

(1) "NEW MOVE: none" is no move: MET (unit).
- Cause: my live Arsenal copy, events 1286-1301.
  - harbour r21 wrote "NEW MOVE: none (MEGA is a timed effect on the core's existing body check, ...)";
  - landcheck.ts newMovesOf took "none" as a move id;
  - the land gate refused harbour r22 for it ("no bot test of your package reports moves.none");
  - harbour r23 then counted a fake `moves.none`: 68 s and 0.42M tokens for nothing.
- Fix (landcheck.ts newMovesOf):
  - none, no, nothing and n/a are not ids;
  - an explicit NEW MOVE line is the builder's word, so "NEW MOVE: none" also overrides a loose "New moves `x`" line.
- Test D27 T3 R2 none, on the real note (1286) and the real refusal (1298). "NEW MOVE: rush, slam" still gives both
  moves.

(2) A package that draws its own copy of another package's text goes back once, with the owner named: MET (unit;
    a scan of every real merge).
- textowner.ts copiedTextEvents, on the afterMerge line (foreman.ts stays at 2005 lines). At a merge, a builder line
  qualifies when it says one package's files override or replace another package's text, or that the other's text is
  "no longer shown". COPY_WORDS and TEXT_WORDS find it; "never replaces" does not count.
  - The text's owner is the package named as "the <id>'s ...", or else by one of its text files.
  - The copier is the owner of the other files the line names, or else the builder who wrote it.
- The copier gets "[foreman] one owner per text: <copier>'s files draw their own copy of a text that <owner> owns
  (<files>), in <reporter>'s words: "...". Take the copy out of your files and draw the words as <files> holds them; a
  word that must change is <owner>'s, so write it as a NOT DONE line naming <file> with the exact words."
  - The second time in a change, it is a note for the person instead.
- Test D27 T3 R2 copies:
  - N's event 1496 (harbour's own note): harbour goes back, with skin named as the owner;
  - S4's event 808 (the skin's builder found harbour's tagline override): harbour goes back;
  - a second report in the same change becomes a note.
- Scan of every merge in every job on this machine (766 merges): it fires on exactly these two.
  - The first version also fired on d27-newc's kart items ("it never replaces the core's ... lines"); the negation
    guard is there for that.

(3) Item 36: to the owner with my recommendation (kit parts for the ring and the beam; props stay TLBodies shapes in
    gen/). No code, as ruled.

(4) A word over a body stays whole on the screen: MET in the rule (unit); see the live run for what a builder did with it.
- Seen in my v0.1.29 film: FLATTENED! over a man near the edge read "ATTENED!"
  (stills/t3_v029_mate_mega_f756-864_sheet.jpg).
- Fixed where every builder reads it:
  - foreman/prompts/builder.md, "Words on the screen": a word drawn at a body's screen point (lay.project) is measured
    (lay.measure) and clamped inside the safe area, 5 % of lay.extent() in from every edge; a point behind the camera
    gets no word over it;
  - the juice line of all six cards says the same. tl cards check passes.
- Test D27 T3 R2 edge.

(found live in l3) A drawing-only hand-off is dropped when the drawing already went to another package: MET (unit).
- l3's cartridge builder wrote the camera and FLATTENED! as NOT DONE lines, although the drawing part of the change had
  already gone to harbour (event 1337).
  - One line named the drawing package and went on to harbour. It folded into harbour's round at no cost, but the card
    read "NOT made by cartridge".
  - The other named "scripts/", which is the base's, so halfmade sent it BACK to the cartridge (event 1359).
    cartridge r16 spent a quick diff, a builder run and the checks (2.4 min) to say it cannot.
- Fix (playsplit.ts drawnHandoffs, wrapping afterMerge on its line; foreman.ts +0 lines):
  - while the drawing of the change in flight is another package's, a hand-off from the cartridge's owner whose words
    are drawing only is not sent;
  - its NOT made note becomes "[foreman] the drawing part already went to harbour in this change, so this is not sent
    on: ...".
- Test D27 T3 R2 drawn, on l3's real events (1330-1365):
  - afterMerge alone gives the same two requests the live run made;
  - after the filter: none, and no NOT made note;
  - without a drawing part in the change, nothing is filtered.

LIVE l3: the edge rule in a builder's round (paid, claude-cli sonnet)
- Setup: my copy, cut back to my v0.1.28, in .tl/t3/jobs2/... J2b's follow-up (1319) was resent word for word at
  23:15:45. It promoted v0.1.29 at 23:39:22 (23.6 min): 6 model calls, 3.02M tokens in, 32.4k out.
- It ran on the code from before drawnHandoffs, so the wasted cartridge r16 above is in it.
- The quick diff this time said "no key says it". cartridge r15's builder made the check rate as
  game.skater.check_speed_min 1.5 -> 1, where l2's diff had made bot_check_windup_frames 12 -> 6. Same ask, another
  valid key: model variance.
- harbour r25, built with the new builder.md rule (the person did not ask about edges), draws MEGA! and FLATTENED! with
  one helper. Its doc line: "A big word over a skater's figure, measured and kept 5 % inside the screen, ...; nothing
  when the figure is behind the camera". The code does it: lay.measure, clamps against 5 % of lay.extent(), and returns
  when z <= 0.
- Film: clips/t3_ars_v029b_edge_rule.mp4 (seed 1, frames 360-1500, 19 s, 0 script errors).
  - Still I looked at: stills/t3_v029b_flattened_clamped_f1290-1380_sheet.jpg. A rival lies flat at the left edge of
    the screen, and FLATTENED! is drawn whole, held just inside the edge, under YOU ARE MEGA!.
  - In v0.1.29 (l2), the same kind of moment read "ATTENED!".
  - The camera pulls back while I am MEGA, as asked.
- FINDING (for the Director, not fixed here): l3's v0.1.29 plays to the SAME hashes as v0.1.28 on seeds 1-3 (7df3f5a1,
  57e41c10, f0c6699b; 0 script errors). Rival giants are still 1/1/1 a minute.
  - The cartridge builder's check_speed_min 1.5 -> 1 did not move play on these seeds, so "twice as often" was not met.
    l2's windup 12 -> 6 did meet it.
  - The Foreman promoted it with no word on it. A figure the person names ("twice as often") that the measured check
    can count would be the guard (askedFigureMiss knows minutes and goals, not "how often").

GATES ON d25-hard-a (round 2, final source)
- foreman npm test: 536 tests, 529 pass, 0 fail, 7 skipped (23:31-23:38). Main 89f64291: 532/525/0/7. The +4 are R2
  none, R2 copies, R2 edge and R2 drawn.
  - npm 4 (535/528/0/7) came before R2 drawn.
- node devx/bin/tl.mjs check --tier fast: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230,
  foreman.typecheck), 23:41, after the last source change.
- create.: not run, engine/ui untouched. Full tier: NOT RUN. The kernel, kits, rigs, style and seeds are untouched.
  engine/cards changed only in one juice line each; tl cards check passes.
- foreman.ts: 2005 lines.

CHANGED FILES (round 2)
- foreman/src: landcheck.ts (newMovesOf), textowner.ts (copiedTextEvents, textCopies), playsplit.ts (drawnHandoffs),
  foreman.ts (the afterMerge line, one import line; +0 lines).
- foreman/prompts/builder.md: "A word over a body stays whole on the screen".
- engine/cards/*.json: one clause in each juice line.
- Tests and fixtures: d27t3_editor.test.ts (+4 tests). Fixtures: t3-live-ars-none-1286-1298.json,
  text-copies-n1496-s4808.json, t3-live-l3-handoffs-1334-1365.json.
- Lane folder: clips/t3_ars_v029b_edge_rule.mp4; stills/t3_v029b_flattened_clamped_f1290-1380_sheet.jpg.

BEHAVIOUR CHANGES (round 2)
- "NEW MOVE: none" names no move.
- A builder line that says another package's text is overridden by a copy sends the copier back once, naming the owner.
- While the drawing of a change is another package's, the cartridge owner's drawing-only NOT DONE lines are not sent
  on.
- Every builder is told to keep a word over a body whole inside the safe area.

NEXT
1. The "how often" figure: when the person names a rate ("twice as often") that the measured check can count, check it
   after the change, as askedFigureMiss does for minutes and goals (l3 finding).
2. Item 30: `foreman revert`, built to the plan.

==========================================================================================================================
ROUND 3: the "how often" guard (the Director's last item; round 2 landed as f8b3a687), 23:55-
Tree d25-hard-a. Not committed: the Director lands it.

A rate the person asks for must move: MET (unit, on the live l3 events and the real measured figures).
- Cause (l3, events 1334-1415):
  - the ask was "I want to face their giants about twice as often, so they should land their body checks on me and my
    mates more often";
  - cartridge r15 set game.skater.check_speed_min 1.5 -> 1;
  - v0.1.29 then played to v0.1.28's state hashes on seeds 1-3, and it was promoted with no word.
  - Before this, only minutes and goals a match were checked against the person's words, and only on the quick diff
    (askedFigureMiss).
- Fix (ratecheck.ts rateGate, called on the cartridge owner's round after its acceptance and the land gate, before the
  merge; foreman.ts line 877, +0 lines):
  - rateAsks reads the person's asks of the change for a rate, more or fewer ("more often", "twice as often",
    "N times as often", "fewer", "less often"). The topic names the figure the measured check counts: checks, hits,
    knockdowns, giants and mega give pro_knockdowns; then goals, shots and passes.
  - The measured check (thirdjam's regular playtester at pro, the same one the quick diff uses) runs on the last
    promoted cartridge (once a change, kept in reports/rate-before-s<seq>.json) and on the round's.
  - A figure that did not move at least 5 % the asked way is "unmoved". The measure's own spread is about 2 %: l3's
    v0.1.29 plays the same game as v0.1.28 and still read 32 -> 32.7.
  - Unmoved, the first time in a change: the round fails a check of its own (reports/<id>-r<n>-rate-s<seq>.json, a
    failed V4 verify) and goes back to its builder with the figures: "the rate you asked for did not move: ...
    pro_knockdowns 32 before, 32.7 after ... another key may be the one that does it".
  - The second time it merges, and the person reads "part of your change was NOT made: the rate you asked for did not
    move after cartridge was sent back once ...". Create and the card read that prefix.
  - A check that could not run (code 2) gives no verdict: nothing is claimed, and the round goes on as before.
- The real figures (engine/tools/rink.sh check-cartridge on l3's two promoted cartridges, 00:05):
  - l3's v0.1.28 -> v0.1.29: pro_knockdowns 32 -> 32.7. Unmoved, so it would have gone back.
  - J2b's quick diff of the same ask (bot_check_windup_frames 12 -> 6, d25-biplane event 1347): 32 -> 35, which
    doubled the rival giants on J2b's hand. Moved, so it passes.
- Test D27 T3 R3 rate:
  - the asks of event 1334;
  - both real figure pairs;
  - the gate on l3's real events: back once with the figures, then the NOT made note;
  - a check that could not run gives no verdict.
- Scan: of the 32 distinct person's asks on rink jobs on this machine, only J2b's follow-up asks a rate. The guard is
  narrow, and so is its cost (two measured runs a change, only when a rate is asked).
- Weaknesses, said plainly:
  - The figure is the playtester's whole-match knockdowns, not "rival giants on me". A key that moves the rivals' checks
    on me but not the total would read as unmoved.
  - Only four topics are mapped. "Every 10 s" (a period, not a direction) is not read: no measured figure counts a
    period yet.
  - Not run live: no paid job was sent for it. It is proven on l3's real events and on real figures measured tonight.

GATES (round 3, final source)
- foreman npm test: 537 tests, 530 pass, 0 fail, 7 skipped (23:58-00:05). Main f8b3a687: 536/529/0/7. The +1 is R3
  rate.
- Fast tier: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230, foreman.typecheck), 00:06.
- create.: not run, engine/ui untouched. Full tier: NOT RUN. The kernel, kits, rigs, style and seeds are untouched.
- foreman.ts: 2005 lines.
- Changed: foreman/src/ratecheck.ts (new); foreman/src/foreman.ts (line 877, one import line);
  foreman/src/test/d27t3_editor.test.ts (+1 test); foreman/fixtures/d27t3/t3-live-l3-rate-figures.json.
- The tree is idle: no process of mine runs. Two job copies remain under .tl/t3/jobs and .tl/t3/jobs2 (about 1.4 GB).
  They are gitignored, kept as evidence, and the Director may delete them.
