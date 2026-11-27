J19-shield: Shield wall gets a shield charge, a brace and a leaping slam (night of 27 Nov 2026, 05:07-06:4x)
Tree d25-shield, branch n27-shield (main b1ee0b1d). Not committed: the Director lands. Details: PROOF-J19-shield.md.

OUTCOME AGAINST THE ACCEPTANCE
1. Juice sheet before the first sentence: MET. Written at 05:10, before the sentence was sent at 05:10:41:
   - charge (F), brace, leaping slam (C);
   - keys, wind-ups, numbers, impact, bots, counterplay, references.
2. Each ability first as a Create change sentence on the real job, with time, tokens, path and outcome: MET.
   Three sentences, each through foreman_run.mjs with real.json's change flags:
   - Round 1 (780 characters, both moves, the brace and the bots; nothing cut by the new 800 cap). Planner -> core.
     - core r14 (3.1 min, 1.63M in) built rush, slam, brace and brain; its invariants stalled at frame 5915.
     - core r15 (2.4 min, 0.50M in) fixed the stall.
     - v0.1.5 promoted 05:31:39: 21 min, no refusal, no question.
   - Round 2 (331 characters: all six use them, a red lane tell). Planner -> crew.
     - crew r4 (3.3 min, 1.37M in) gave Oda, Finn, Sable and Pip the moves and the answers, and drew the lane.
     - v0.1.6 promoted 06:01:30: 14 min.
   - Round 3 (329 characters: "the charge never knocks anyone over ..."). Planner -> core.
     - core r16 (3.0 min, 0.80M in) gave the rush a lane hit test and lifted its reach from 1.15 to 1.3.
     - Merged 06:08:36; v0.1.7 promoted 06:17:39: 15 min.
   - Total about 4.3M tokens in.
3. Every refusal, bend or failure has a blocked-editor line, and those abilities were also built by hand: MET.
   Two lines, in STANDUP and PROOF:
   (a) Round 1 went to core only. Four of five bots think in the crew package, so the bots measured rush 0 a minute
       and slam 0-1 a minute (Bram only).
   (b) The editor's charge never landed in rounds 1-2: 0 knockdowns from 25 rushes over 6 seeds. Its reach of 1.15 m is
       shorter than the 1.4 m pushbox gap. The person asked for "bowled over like pins".
   Both were then fixed by further sentences, as a person would type them. All three abilities are by hand in
   .tl/juice/shield_hand.
4. For every ability: clip of 20 s or less, stills looked at, bots' uses a minute, 3600 headless frames with 0 script
   errors, same hash twice: MET for the hand pack, and for editor v0.1.5 and v0.1.6.
   - Hand clips:
     - clips/hand_bots_charge_slam.mp4 (20 s): bots bowl a line, my slam floors two, the lens rises with my leap;
     - clips/hand_my_charge_braced.mp4 (3.7 s): my charge braced by two.
   - Editor clips: clips/editor_v015_rush_slam.mp4 (8.6 s) and clips/editor_r3_rush_slam.mp4 (8.8 s, the round-3 pack).
   - 9 contact sheets and stills in stills/, all looked at. Every windowed run had 0 SCRIPT ERROR lines.
   - Hand, seeds 1-3: bots charge 14 / 15 / 6 and slam 11 / 4 / 8 a minute (five bots), and 8-10 are bowled a minute.
     A third of charges are braced. 0 script errors. Seed 1 is e0b41355a5253458 twice.
   - Editor v0.1.5: bots rush 0 and slam 0-1 a minute; 98730759e4dd5b92 twice.
   - Editor v0.1.6: bots rush 1-4 and slam 6-10 a minute, rush knockdowns 0; bfdd762d9fd616b3 twice.
   - Editor v0.1.7 (round 3): rush knockdowns 2 / 1 / 5 and slams 8 / 12 / 6 a minute, 0 errors;
     d7211da4317c8ffe twice.
5. PROOF says which abilities came from the editor and which by hand, and how each feels: MET (sections "Which
   abilities ..." and "Editor vs hand").
6. landable J19-shield by 07:00: MET (see the last STANDUP line).

GATES
- node devx/bin/tl.mjs check --tier fast: PASS (5/5 steps): arch 12/12, assets 4/4, cards 3/3, devx.test 230/230,
  foreman.typecheck. Run at 05:36 and again at 06:14 (+0 against the last green).
- Hand pack:
  - lint PASS (no bypasses);
  - smoke 3600 f PASS (0 errors);
  - bot_juice_hand 3600 f on seeds 1-3 PASS (0 errors);
  - the pack's own tests: bot_player, bot_crew, bot_look and bot_tofu PASS;
  - bot_call FAILS on one row: "charged together" 1 of 2. The first call comes at f 5299 instead of 349 on v0.1.4,
    because the scripted captain is bowled and slammed before his meter fills. This is a named behaviour change of the
    juice; the test was not touched.
- Editor v0.1.5, v0.1.6 and v0.1.7: smoke / bot 3600 f with 0 errors. The Foreman's own V0-V4 passed at each promotion.
- NOT RUN: the full tier. No kernel, kit, rigs, style or seed file changed.

CHANGED FILES (all in my tree, none tracked outside docs/)
- docs/shifts/2026-11-27-night/lanes/J19-shield/: PROOF-J19-shield.md, STANDUP.md, REPORT.txt, clips/ (4 mp4, about
  15 MB), stills/ (9 jpg).
- .tl/juice/shield_hand/ (the by-hand pack, from v0.1.4):
  - new: scripts/juice/mod.gd, gen/mod_juice.gd, data/juice.json, tests/bot_juice_hand.gd;
  - edited: scripts/main.gd (restart_match rebuilds over a pause), scripts/camera.gd (the lens rises with a captain in
    the air), pack.json (0.2.0, the module, the test).
- .tl/jobs/shield-wall-3-v-20261125-1: the real job, now done at v0.1.7. .tl/j19/: tools,
  reports, the editor bot.
- No foreman/, engine/ or contracts/ file was touched.

BEHAVIOUR CHANGES (named)
- Hand pack:
  - every fighter has F (charge) and C (slam), and the bots use and answer them;
  - matches are rougher: the bots slam 4-11 times a minute across five;
  - restart after a match now pauses 14 frames to rebuild the fallen, the same fix the editor's core r15 made.
- Editor job: v0.1.5, v0.1.6 and v0.1.7 promoted (v0.1.7: the rush's reach 1.15 -> 1.3 m and a lane hit test).

FOR THE OWNER / DIRECTOR TO LOOK AT
- clips/hand_bots_charge_slam.mp4 first: a bot bowls two Gulls in a row, my slam leap with the lens following.
- Then clips/editor_r3_rush_slam.mp4: the editor's own charge after three sentences.
- Play: tl play with --pack=.tl/juice/shield_hand (F charge, C slam; RMB raised and facing a charge = brace).

LANDABLE
- Best pack: C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/juice/shield_hand
  Menu title: "Shield wall: charge and slam (juice by hand)"
- Optional editor row: C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.7
  Title: "Shield wall: charge and slam (editor)".

QUESTIONS FOR THE DIRECTOR
1. Route to T: a sentence that names what "the rivals" do should reach every package that drives a bot (here core's
   brain.gd AND crew's mind.gd). Round 1 went to core alone.
2. Route to T: a move's reach under the pushbox gap (1.15 < 1.4) can never land, and no gate noticed. A cheap check is
   "a new attack move lands at least once in the tofu bot's run".
3. The hand pack's bot_call row ("charged together" 1 of 2): accept it as the juice's named change, or should I make
   the bots hold big moves while a crew's call charges up?

NEXT THREE
1. Port the hand layer's tells and impact (lane rings, BOWLED/BRACED/SLAM words, the leap height, the lens follow)
   onto the editor's v0.1.7 as sentences, and measure which ones the editor can take.
2. A calmer bot setting (slam rate) behind a param, then the newcomer hand over 20 seeds (tl ladder) on the hand pack.
3. bot_call on the hand pack: the bots hold big moves while a call charges up, so the rally scene plays as before.
