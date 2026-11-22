N1 teardown: thirdjam against our hockey (night of 22-23 Nov 2026). Lane report.
Opus, solo apart from three read-only scouts on thirdjam's code. Worktree n23-teardown. Research only: nothing in engine/ or foreman/.
Round 1 landed (merge 065f28e), round 2 landed (merge 17973df). Round 3 (the duel teardown) is the last section.

OUTCOME AGAINST THE ACCEPTANCE
1. TEARDOWN.md backs every claim with file:line on both sides: MET.
   docs/research/hockey-teardown/TEARDOWN.md:
   - section 2: side by side in 13 systems (match, scale, skating, puck, passing, shooting, AI, teammates, contact, camera,
     controls, first 30 s, testing);
   - section 3: the ranked top 10;
   - section 4: what thirdjam itself lacks;
   - section 5: 13 process lessons;
   - section 6: 10 recommendations;
   - section 7: an evidence index.
   The thirdjam lines the report leans on were re-read by hand after the scouts. Our line numbers were checked against the files.
2. Clips or sheets of both games: MET.
   - thirdjam RUNS on this machine. No package is in git or on disk, but an editor build of 15 Nov (C:/t/t5, a worktree of the
     deleted thirdjam checkout) was found. Its runtime was copied to .tl/tj-run (785 MB) and run with UE 5.9:
     -game -nosound -Multiprocess -cut=hockey.regular, at pro, with thirdjam's own measured person hand (jam.ScriptHuman 2).
   - Frames are the game's own viewport stills, every 2nd sim frame, so no window grab. 50 s were filmed.
   - That build is about H39-H44, not the submitted H47, and still draws a few marks that H46 and H47 later removed. Said in the
     teardown.
   - Ours: tl play hockey untouched (the first 25 s a person meets), and the ladder bots in a window through TLHand
     (rookie + newcomer, pro + regular).
   - media/: 3 mp4 clips of 20 s, 5 JPG sheets plus thirdjam's own H45 contact sheet, probe.md; 8.6 MB.
3. The ranked top 10 and the process lessons: MET (TEARDOWN sections 3 and 5). INTERIM.md was written at 20:10, well before
   01:00. It points N2 to RULINGS.md.
4. Fast tier green: MET.
   - After `npm ci` in the tree's foreman/: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229,
     foreman.typecheck clean).
   - Run on the round-1 tree and again on the round-2 tree.
5. The Director's round-2 asks:
   - (1) RULINGS.md: MET. docs/research/hockey-teardown/RULINGS.md distils the owner's thirdjam rulings, read in full (R-0001
     to R-0075). Each entry has his verbatim words, the ruling, its scope (ANY game or HOCKEY) and whether our hockey follows it.
     The entries are grouped by what they decide: the bar, scale, camera, controls, puck, contact and drawing, AI and difficulty,
     identity, scope. Section 10 lists the ten rulings a design method should cite first.
   - (2) N2 told: a line at the top of INTERIM.md, and the message to the Director.

THE TOP 10 (cost to the player)
1. There is no ice. Bodies of radius 0.879 m (figures drawn 2.2x, from a drawing fix on 16 Nov, H7) stand on 60 x 30 m. The rink
   is 34 body widths long; thirdjam's is 112. Four or more of the six skaters are within 5 m of the puck in 15-16 % of play.
2. Your teammates refuse to play. They shoot only within 4 s of your own pass or shot and hold 8 m out of the net. The rule was
   made so an idle hand loses the ladder.
3. The camera follows the puck, not you, and the cursor-stick moves under a still hand. thirdjam uses a chase camera and an aim
   anchor, both after the owner's notes.
4. The puck hardly slows (no drag; the ice takes 1.0 m/s2, measured) and passes leave at a fixed 18/23 m/s. A dozen own-goal
   guards patch the consequences.
5. The game keeps stopping: 36-s periods, a whole-game freeze on hard hits about 3.8 times a minute, goal holds and replays.
6. The figures glitch, and our own README lists it.
7. Hits decide the game and are drawn loudly. These are marks the owner had ruled out in thirdjam.
8. The bots read the play 5-18 frames late and decide at 4 Hz, and nobody but you sprints. This item is weak: the measured speeds
   are close.
9. Shooting asks for precision the screen cannot give.
10. The key hints vanish after the first press; there is no radar and no off-screen marker.
Under all ten: by thirdjam's own first-five-minutes measures ours scores BETTER (first touch 0.6-0.7 s, puck on your blade
18-21 % of play). The instruments cannot see what the owner sees.

MEASURED THIS NIGHT (all headless unless said; all through scripted hands)
- The probe, a copy of the pack in .tl/probe with one test. It recorded what b0 meets on 20 seeds each of rookie newcomer and
  pro regular, and on 12 seeds of rookie idle. A second run (12 seeds a cell, three cells) added speeds. The table is
  media/probe.md.
- The puck: a free loose puck loses 0.97-1.05 m/s every second (4 seeds).
- Scale arms in .tl/arms (copies of the pack): the AI on all six at pro, 8 seeds an arm.
  - Life-size bodies alone leave the piles in metres where they are, but cut knockdowns by a third.
  - The 90 x 45 m rink cuts four-man piles from 16 % to 12 % and doubles the carry.
  - Both together halve the knockdowns (5.3 to 2.6 a minute) and cut the hit-stops from 4.8 to 1.5 a minute.
  - Scale is necessary, not sufficient: the AI's pull to the puck is the other half.
- thirdjam, one filmed match: his passes 2 (1 arrived); all passes 22, 45 % to a mate. One match is an anecdote.

CHANGED FILES (docs only)
- docs/research/hockey-teardown/TEARDOWN.md, RULINGS.md, media/ (probe.md, 3 mp4, 6 jpg incl. thirdjam's H45 contact sheet)
- docs/shifts/2026-11-23-night/lanes/N1-teardown/INTERIM.md, STANDUP.md, REPORT.txt
- No behaviour change. Outside git: .tl/thirdjam (12 GB clone), .tl/tj-run (thirdjam runtime and stills), .tl/probe,
  .tl/arms, .tl/n1 (raw clips, logs), foreman/node_modules (npm ci).

FOR THE OWNER
- Look at media/sheet_ours_pro_regular.jpg next to media/sheet_thirdjam_pro_regular.jpg: the scale and the scrums show in one
  glance.
- RULINGS.md section 10: his own rulings from thirdjam that our hockey broke.
- TEARDOWN section 6: ten recommendations to accept or reject. Recommendation 1 is to stop game work on hockey until a one-page
  "world in the player's units" is agreed.

QUESTIONS FOR THE DIRECTOR
1. C:/t/t5 is an orphan thirdjam worktree, 12 GB, with no git metadata: its .git points to the deleted C:/Users/kazda/kiro/thirdjam.
   I copied from it and changed nothing in it. Keep it: it is the only runnable thirdjam on the machine. If it is ever removed,
   list its junctions and links first.
2. Should RULINGS.md move to contracts/ as standing owner rulings? That is a Director-only file, so I did not move it.
3. thirdjam's 40 registry lessons (docs/registry/LESSONS.md in thirdjam) may never have reached the registry. A query tonight
   found generic techniques, not J01, J07 or J18. Someone should check the registry's leads.

NEXT THREE THINGS THIS LANE WOULD DO
1. Run the scale arms with the hand's distances re-scaled to the body (B and D as a design, not a first look), with window clips.
2. Run thirdjam's headless playtester (the editor build in .tl/tj-run) through the same human-centric counters, so both games
   are read with one instrument.
3. Write the "world in the player's units" page for hockey as a proposal for the owner: sizes, speeds in body lengths, camera,
   with stills of each option.

ROUND 3: THE DUEL TEARDOWN (the Director's ask after round 2)
------------------------------------------------------------
Deliverable: docs/research/duel-teardown/TEARDOWN.md, docs only. Same method as the hockey teardown:
- the verdict;
- the references with URLs (section 2);
- side by side in 12 systems with file:line;
- the ranked top 10;
- what the references get wrong;
- 7 process lessons;
- 10 recommendations.
media/ holds 2 clips of 25 s, 3 JPGs and rounds.md; 5.1 MB.

How it was read and played:
- Ours:
  - engine/packs/duel: README, data, fighter, lessons, brain, show.
  - The rig's clip table, the DUEL-PLAYBOOK spec, and N2's brief and report.
  - In a window: tl play duel with nothing pressed (25 s), and the newcomer TLHand against the Wall (45 s).
  - Headless: 5 ladder cells x 8 seeds (93 rounds), for round length and endings.
- References: For Honor (Ubisoft patch notes and fight updates, Kotaku), Souls and Sekiro (Game Developer's anatomy of a DS3 enemy
  attack, wiki.gg, Fextralife, Activision), fighting-game basics (Infil's glossary, SmashWiki, Capcom). A research scout gathered
  them with URLs; community-measured and snippet-only figures are marked. "Not found" is stated for a duel round length and for any
  tutorial opponent that waits until the player succeeds.

THE TOP 10 (why ours is not fun)
1. The bodies do not tell, text does. Every attack is one of two generic rig clips slowed through a frame map; the light's 18-frame
   wind-up is the clip's 3-frame draw-back slowed about five times. The Duelist's "blade tap" tell is a half-raised heavy. Intent is
   written over his head in words (HEAVY, BASH, UNBLOCKABLE), where For Honor and Sekiro use a glyph over a body that does the
   telling.
2. The tutorial hits you while it teaches. The lesson blows are real. A newcomer who touches nothing is at 14 of 100 health 19 s in.
3. A round lasts about 20 s: 93 of 93 rounds measured ended by KO, median 18-24 s, against a 70 s clock. The rival may never idle
   more than 120 frames by rule; the longest idle measured was 35 frames. Published guidance says an enemy attacks every 2-3 s.
4. The threats are faster than a person reacts. Chains wind up in 12 frames, the light in 18, the heavy in 32. For Honor's lights
   take 24-30 frames and its heavies 48-60; a Souls attack's signal plus attack takes at least 20; average reaction is about 15.
   The checklist accepts 12, below the playbook's own floor of 16.
5. A dashboard of meters: three bars a fighter, a crowd meter, stars, rally, tags, cues, banners, a key strip, cause cards.
6. Three rivals are one fighter in three hats: one move set, three reaction speeds.
7. Toy figures, stick weapons, beeps. The light hit-stop is 5 frames, lighter than the references' 6-19.
8. Difficulty is a reaction dial with a cliff: the newcomer wins 4 of 8 against the Wall and 1 of 8 against the Duelist; the regular
   hand wins 8 of 8 against both later rivals.
9. A round ends in a KO show and a cause card, not in a moment the player remembers.
10. Nobody has played it. It was built in five hours by twelve self-judged loops that only added; it was accepted on clips of
    mechanics.
N2's own report says so: "It is not yet a game that sells itself by its feel. Nobody has played it."

Gate (round 3): tl check --tier fast PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck clean).
Changed in round 3: docs/research/duel-teardown/ (TEARDOWN.md, media/ with rounds.md, 2 mp4, 3 jpg), INTERIM.md (a line for N2),
STANDUP.md, REPORT.txt. Nothing in engine/ or foreman/.

Next three for the duel:
1. A person plays the Wall for five minutes, then the Duelist; read where he is hit and whether he reads a body or a word.
2. A per-rival animation brief: the light, the heavy and one signature move with anticipation poses of at least 24 frames.
3. Run the duel's lesson round with zero damage and a wait-until-done step as a measured arm (in a copy), against the
   untouched-first-25-s clip.
