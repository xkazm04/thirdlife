J11-biplane report (night 27 Nov 2026, 03:02-~05:45)
Tree .claude/worktrees/d25-biplane, branch n27-biplane (fast-forwarded by the Director to 6c75354c at ~04:40).
Game: Biplane duel, real Create job .tl/jobs/biplane-duel-two-biplanes-20261125-1 (v0.1.1 at the start).

OUTCOME
Three abilities, all six change sentences sent through Create's change box order (foreman change + real.json "change"
flags, claude-cli sonnet). All three abilities now exist IN THE EDITOR'S OWN PACK: the job promoted v0.1.3 at 05:29:53. Two of the first three changes were refused by the old balance gate and then bent; after lane T's fix the last
two changes came out exactly as asked. A by-hand pack was built while the editor was refusing, and it carried the
bot side (Vesper loops in every round) until change 6 put that in the editor too.

1. Loop-the-loop (E): EDITOR. Change 1 merged first time (r13) but small (5 m radius) and its smoke whited out the
   screen; Vesper never looped (0 in 5 min). Change 4 (r20, first time): 27 m loop, a clean ring of puffs, REVERSED!
   big mid-screen, her loop once a minute (round 1 only). Change 6 (fixed editor, r22, first time, unbent): her loop
   in every round. Now: my loops 2.8/min, hers 1.2/min in all three rounds, REVERSED 0.6/min (mine and hers).
2. Star Fox barrel roll + DEFLECT (Shift): EDITOR, first bent then fixed. Change 2 (r14) built as asked and was
   REFUSED by the tofu gate (skill_spread 0.0989 < 0.25); r15 edited the test pilot and was refused; r16 merged by
   raising her roll share 0.5 -> 0.6 (bent), and in 5 min of play 0 deflects happened. Change 5 on the FIXED editor
   (r21, 6 min, first time): share 0.5 and 40 m exactly as I asked, every round, DEFLECT! big, no deflect on a falling
   wreck; the balance it moved (skill_spread 0.59 -> 0.2) came as a note, not a refusal. Now: her rolls 4.6/min,
   deflects 0.8/min hers + 0.2/min mine.
3. Hit smoke + kill spiral: EDITOR, bent. Change 3 (r17) built as asked and was REFUSED (skill_spread 0.239); r18
   refused; r19 merged by adding a "graze" damage rule I never asked for. Change 6 added SHOT DOWN! big. Now: 0.4
   shoot-downs a minute, each a 2 s burning corkscrew with the camera following it to a ground burst.
By hand (.tl/juice/biplane_hand, built 03:38-04:20 while changes 2 and 3 were refused): a juice module on the
change-1 pack: Star Fox double spin and 8 m jump, wingtip streak corkscrews, DEFLECT ricochets + banner, Vesper rolls
into my bursts and loops over me in every round (1.8/min), the kill corkscrew with a follow camera. 3600 frames twice
0 errors same hash be87c36d; 18000 frames 0 errors.


LANDABLE
- Best pack: .tl/jobs/biplane-duel-two-biplanes-20261125-1/promoted/game.biplane_duel_two_biplanes@0.1.3
  (in tree d25-biplane; the editor's own pack, all three abilities, no hand code). Menu title: "Biplane duel (juice)".
- Optional second row (the by-hand build, superseded): .tl/juice/biplane_hand -> "Biplane duel (juice by hand)".
  .tl/juice/biplane_final (v0.1.3's predecessor + my module) is NOT for the menu.

ACCEPTANCE
- Juice sheet before the first sentence: met (PROOF top, 03:06; first sentence 03:07:39).
- Each ability first as a Create change sentence on the real job, time/tokens/path/outcome recorded: met (6 changes,
  PROOF "The editor, change by change"; all path full, core package).
- Every refusal/bend a blocked-editor line with evidence, then built by hand in .tl/juice/biplane_hand: met (changes 2
  and 3: tofu-bounds reports s492/s500 and s537/s545; STANDUP 03:37 and 04:00; the hand pack from 03:38).
- Per ability: clip <= 20 s, stills looked at, uses per minute by the bots, 3600 headless frames 0 script errors, same
  hash twice: met for the landed pack and for the hand pack (PROOF table; hashes a67afa4a x2 for v0.1.3's code,
  be87c36d x3 for the hand pack). Clips: v013_editor_her_loop_kill.mp4 (20 s), final_c5_deflect_loopring_reversed.mp4
  (20 s), final_c5_her_deflect_her_loop.mp4 (6 s), editor_kill_r19.mp4 (6 s), hand_v1_reversed_streaks_deflect.mp4
  (20 s), hand_kill_drill.mp4 (9 s, a staged drill copy, labelled), loop_r13_editor.mp4 (11 s, the first loop).
  "The hand" in every clip is the pack's own sharp pilot plus E when tailed (tests/bot_juice.gd in the proof copies),
  not a person on the keys: no keyboard here.
- PROOF says editor vs by hand and how each feels: met (verdict table and "What a person meets in v0.1.3").
- Landable by 07:00: met (~05:45).

UNBENT ON THE FIXED EDITOR (the Director's question)
Yes. Change 5 (roll refinement) and change 6 (Vesper loops every round + SHOT DOWN!) each merged first time, in 6 and
16 minutes, exactly as asked. Change 5 moved skill_spread 0.59 -> 0.2 and the Foreman said so as a note ("balance
moved by your change: built as you asked ... Say "make it fairer" to tune it") instead of refusing; on the old gate
that is the refusal that bent changes 2 and 3.

FIGURES (seed 1, bot_juice, 18000 frames = 5 min, per minute)
v0.1.3: my loops 2.8, Vesper's loops 1.2 (all three rounds), REVERSED 0.6 (0.4 mine, 0.2 hers), her rolls 4.6,
deflects 0.8 hers + 0.2 mine, shoot-downs 0.4. Before tonight (v0.1.1): no loop key; after change 1 Vesper looped 0.
Hand pack: Vesper loops 1.8, roll-ins 1.4, deflects 0.6. Editor: 6 changes, 10 rounds, 12.05M tokens in, 105k out.

GATES
- node devx/bin/tl.mjs check --tier fast (tree at 6c75354c, 05:05): PASS arch 12/12, assets 4/4, cards 3/3,
  devx.test 230/230, foreman.typecheck clean. No kernel/kit/rig/style/seed change, so no full tier.
- The job's own final verification of v0.1.3: lint, smoke, invariants, 4 bots, capture: all ok (events 681-691).
- Hand and final packs: lint and smoke exit 0; bot_tofu and bot_season pass on biplane_final.

CHANGED FILES (all in tree d25-biplane; no tracked engine/foreman/contracts file edited)
- docs/shifts/2026-11-27-night/lanes/J11-biplane/: PROOF-J11-biplane.md, STANDUP.md, REPORT.txt, clips/ (7 mp4,
  ~45 MB), stills/ (11 jpg).
- Untracked .tl/: the job (6 change rounds, promotions 0.1.2 and 0.1.3), .tl/juice/biplane_hand and biplane_final,
  .tl/j11 (proof copies c1-c6, drill, bot_juice.gd, make_final.py), .tl/bin/clip.sh and clipm.sh (window movie with
  the window lock). Raw .avi files deleted.

FOR THE OWNER TO LOOK AT
Play "Biplane duel (juice)": E loops (watch for the ring and REVERSED!), Shift rolls into her burst (DEFLECT!), get
her hull to 0 (SHOT DOWN! and the corkscrew). Judge: (1) late-round black smoke from your own plane covering the
view, (2) whether her rolling into half your bursts (4.6 a minute) feels clever or annoying.

QUESTIONS FOR THE DIRECTOR
- Menu row for v0.1.3 ("Biplane duel (juice)"); the by-hand row optional.
- The old gate bent changes 2 and 3 for good: the graze-damage rule (r19) and the edited test pilot (r15) are still in
  v0.1.3. A person would ask "remove the graze rule"; I did not spend a round on it.
- The Foreman queues a change behind the previous change's reverify of every other package (~12 min a merge): four
  of my six changes spent most of their time waiting.

NEXT THREE
1. A change: "thin my own smoke near the camera" (the black-smoke view problem).
2. A change: "her pull-up after my loop in every round; DEFLECT! for her deflects too; remove the graze rule".
3. A person-hand ladder for the stunts (tl ladder with regular/newcomer hands) to see whether loops and rolls are
   usable by a newcomer, not only by the scripted sharp hand.
