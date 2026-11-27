J2-robots REPORT: Robot soccer gets a double-sledged hammer (night 27 Nov 2026, 03:02-05:05)

OUTCOME
- The editor made the hammer on the second sentence. Its version is promoted as v0.1.6:
    .tl/jobs/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.6
- By hand, I built the juicier version, v0.1.7. It is the lane's deliverable:
    C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-robot/.tl/juice/robot_hand
- Menu titles:
    "Robot soccer: sledgehammer (juice by hand)" -> .tl/juice/robot_hand
    "Robot soccer: sledgehammer (editor)"        -> promoted/game.robot_soccer_3_v@0.1.6 (optional row)
- 05:13: the hand pack has its own id, game.robot_soccer_hand (0.1.7), titled "Robot soccer: sledgehammer (juice by
  hand)". Checks after the rename:
  - lint PASS;
  - smoke 3600 f: 0 errors;
  - bot_hammer_hand 3600 f: 0 errors, hash ac3f913b... twice.
  The editor's v0.1.6 keeps game.robot_soccer_3_v. Two menu rows, as the Director ruled.

ACCEPTANCE
- Juice sheet before the first sentence: met. It is at the top of PROOF-J2-robots.md, written 03:05.
- Each ability first as a Create change sentence on the real job: met.
  - Round 1, 03:06: 238 characters; the box caps at 240.
    - core r13 built the whole hammer.
    - The tofu gate refused it (tells 2, close_rounds 0). The person got a balance question, and I answered it.
    - The round merged at 03:22.
    - Final verification then failed 4 of 4 on bot_tofu's 36000-frame budget. Each failure was routed to show,
      which could not fix it.
    - 04:07: "the change was NOT made". 60.7 min and 14.15M tokens in, for nothing promoted.
  - Round 2, 04:31, after lane T's fix: 240 characters (hammer + charge).
    - core r16 took 2.1 min; balance was only a note.
    - show r7 added the end-card answer.
    - Final verification passed.
    - v0.1.6 was promoted at 05:02 (31.3 min, 1.42M tokens in).
- blocked-editor lines with evidence: met, four of them, in STANDUP.md and PROOF:
  - the change box caps at 240 characters;
  - the balance refusal of a whole ability;
  - final verification routing a core frame-budget failure to show (loop, then revert);
  - the stale, mixed what-changed note on v0.1.6.
- Built by hand where the editor fell short: met. Charge-scaled flights, the tell, the impact words and lens kick,
  the buried head, bot ball drives and pass-away.
- Each ability has a clip of 20 s or less, stills I looked at, bot uses per minute, 3600 headless frames with 0
  script errors, and the same hash twice: met.
  - Hand: clips/hand_hammer.mp4 (19.0 s), 7 hand stills.
    - Bots swing 7/7/5 times a minute (seeds 1-3).
    - 0 errors; hash ac3f913b... twice (seed 1); 6a221ada... twice (seed 7).
  - Editor v0.1.6: clips/editor2_hammer_charge.mp4 (12 s), 2 sheets.
    - Bots swing 6/5/5 times a minute.
    - 0 errors; hash 4f771e45... twice.
  - The discarded round 1: clips/editor_hammer_discarded.mp4 (20 s), 2 stills.
- PROOF says what the editor made and what was made by hand, and how each feels: met (PROOF, "Editor vs hand").
- "landable J2-robots" by 07:00: met at 05:05.

GATES
- tl check --tier fast: PASS before and after the fast-forward to 6c75354c.
  - 5/5 steps, 249 units: arch 12/12, assets 4/4, cards 3/3, devx.test 230/230, foreman.typecheck clean.
- Hand pack:
  - lint PASS; smoke 3600 f PASS, 0 errors;
  - bot_player, bot_hand_newcomer, bot_hand_perfect, bot_mash, bot_show, bot_hammer_hand: PASS, 0 script errors.
  - tests/bot_tofu.gd: FAIL, frame_budget (2 of 3 matches in 36000 f; hammer matches run 4-4.5 min). Not fixed: it is
    a balance-bot budget (lane T2).
- No engine/, foreman/ or contracts/ edit. No full tier needed: kernel, kits, rigs, style and seeds are untouched.

CHANGED FILES
- Tree (untracked): docs/shifts/2026-11-27-night/lanes/J2-robots/:
  - PROOF-J2-robots.md, STANDUP.md, REPORT.txt;
  - stills/ (11 JPG);
  - clips/ (3 mp4, 9.6 MB).
- .tl/ (ignored):
  - juice/robot_hand (the deliverable);
  - juice/robot_edit2 (a copy of v0.1.6 with the proof test);
  - juice/tools/{clip.sh, bot_hammer_hand.gd};
  - clips/final.mp4, r13_hammer.mp4, edit2.mp4 (raw AVIs deleted).
- The real job advanced: v0.1.6 promoted (promotion 7); the job total is now 42.25M tokens in.

BEHAVIOUR CHANGES THE OWNER SHOULD KNOW
- Both versions: every robot carries a hammer. Matches get longer, and the newcomer wins less often: on v0.1.6, 9 of
  20, was 17 of 20 (the editor's note). The end card has a "Hammered: step away from a raised hammer" answer.
- Hand version:
  - F (or the middle mouse button) raises and swings;
  - a hint teaches it after the opening;
  - bots swing 5-7 times a minute between them, and also drive loose balls at goal.
- How to look:
  - play the hand pack (tl play with --pack=<robot_hand>);
  - hold F near a blue carrier: a short tap is a BONK, the full 50 frames a KA-BONK;
  - watch a blue bot's head go red behind you.

QUESTIONS FOR THE DIRECTOR
(answered by the Director at 05:10-05:12: two menu rows; the hand-layer-to-editor round is deferred to the verdict as
a next step, and no new sentences were sent)

NEXT THREE THINGS
1. Make the swing itself read: a 4-frame swing is a cut. Add a 2-3 frame smear (TLHit.swing_trail) and hold the
   follow-through pose, so a miss shows the head stuck in the court from behind.
2. Put the hammer's tell in the brain package's scoring, so team AI chooses the hammer against the slide by situation
   (now the sim's rule decides), and have rivals punish a rooted misser.
3. Send the hand layer to the editor as three sentences and record which ones it makes, closing the editor-versus-hand
   gap.
