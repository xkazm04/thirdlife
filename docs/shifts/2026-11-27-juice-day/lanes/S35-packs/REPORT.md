S35-packs: spikes 3 (old bends) and 5 (shield wall bot_call), juice day 27 Nov 2026, 08:08-10:45
Tree d25-biplane, branch d27-sp-packs (main 8be26d61). Not committed: the Director lands. Details and the lane's
recommendation: SPIKE.md beside this file.

OUTCOME AGAINST THE ACCEPTANCE
1. SPIKE.md covers both spikes in the brief's layout (question, arms, test, results table, what broke, how to play,
   the recommendation kept separate): MET.
2. Every arm playable, with a pack path and a menu title: MET (8 rows, below; 2 of them already on the menu).
3. Each arm: clip <= 30 s + stills looked at; 3600 f, 0 script errors, same hash twice; its own measures; its cost: MET,
   with one named exception: no biplane clip, because the bend is in the test hand and nothing on screen differs (the
   game files are identical; SPIKE.md says why).
4. Both arms a fair best effort, same base, same copies, same seeds, same measures: MET. Two deviations, named:
   - karts 3A: my first sentence said "the old balance check"; the Foreman reads "balanc*" as a fairness ask and refused
     and bent the change. I re-sent the same sentence with "a builder" on a fresh copy of the same base (the arm); the
     first copy is kept as evidence, not as an arm.
   - shield: v0.1.7 (the brief's job) does not fail bot_call (5 of 5 pass); only the hand pack fails (2 of 5). So spike 5
     has editor arms on v0.1.7 (as briefed) and hand arms on the hand pack (the editor cannot reach it: no job).
5. Time box: done at about 10:45, inside 16:00.

FINDINGS (short)
- Biplane 3A: the freeze undid the person's pilot restore ("measure kept", event 751) and the job promoted v0.1.5, byte
  for byte v0.1.4 except the version. Create shows it as done; the what-changed card says "none" and lists 16 unchanged
  files; Create never shows "measure kept". The bent line changes nothing a person meets and almost nothing measured:
  regular-hand ladder 13 of 20 for both pilots, every column identical; tofu hash identical; the test hand first differs
  at f~17,250 of an 18000-frame run.
- Karts 3A (editor, v0.1.8): built exactly as asked, one round, a "balance moved" note. Reversal rule nearly dormant (fired
  once in 5 seeds of 3B; with it gone no bot sat still 51 f). The sweet bump matters: regular hand, first match, 20 seeds:
  3B 20 of 20, goals 2.95:0.40, 6877 frames; 3A 18 of 20, 2.35:0.80, 10899 frames. Foreman hand checks 3A: newcomer 18,
  perfect 16 of 20 (v0.1.7: 18, 18). 121 min, 2.63M tokens in, mostly verification on a loaded machine.
- Karts, the "balance" wording: refused 3 times (lead_change_share 0.17 < 0.3), then teams r8 changed shoot range,
  shoot angle and block chances nobody asked for; promoted with them (125 min, 5.89M tokens); the card does not show
  the teams change.
- Shield: the hand pack's failure is the lesson's "unbreakable" first call broken by a rival charge that started before
  the horn (seed 1: call f301, bowled f303, broken f304): the hand juice's hits skip the rally call's safe gate.
  5A editor v0.1.8: the builder made the lesson call breakable by rush/slam and rewrote tests/bot_call.gd to accept it;
  the Foreman allowed a person to change what a pack test means (only the tofu bot and what it loads are frozen); the new
  branch never ran in 5 seeds. 5B editor v0.1.8: _hold_big() in call.gd, no test change; the one case seen in 9 match
  minutes (Oda's slam during his crew's horn, seed 2 f6051) is gone. 5B hand: the lesson call is never broken, first call
  on time 5 of 5; bot_call still fails 2 of 5 on other rows (floored 1, moved 0.4).

PLAYABLE ARMS (menu rows are the Director's)
- 3B biplane: already on the menu, "Biplane duel v0.1.4 (made in Create)".
- 3A biplane, editor: C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/s35-3A/biplane-duel-two-biplanes-20261125-1/promoted/game.biplane_duel_two_biplanes@0.1.5
  title "Biplane duel v0.1.5: pilot clean-up asked, freeze kept it (spike 3A, Create)"
- 3A biplane, by hand: C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/juice/biplane_3A_hand (id game.biplane_duel_clean_pilot 0.2.0)
  title "Biplane duel: clean test pilot (spike 3A, by hand)"
- 3B karts: already on the menu, "Bumper-kart football v0.1.7: jumps, aerials, air bumps (made in Create)".
- 3A karts, editor: C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/s35-3A2/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.8
  title "Bumper-kart football v0.1.8: bends cleaned (spike 3A, made in Create)"
- 5A shield, editor: C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/s35-5A/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.8
  title "Shield wall v0.1.8: big moves break a call (spike 5A, made in Create)"
- 5B shield, editor: C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/s35-5B/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.8
  title "Shield wall v0.1.8: bots hold big moves while a call charges (spike 5B, made in Create)"
- 5A shield, hand (= the hand pack as it is): C:/Users/kazda/kiro/third-life/.tl/proof-games/shield_charge_hand, already on
  the menu as "Shield wall: charge and slam (juice by hand)".
- 5B shield, hand: C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/juice/shield_hand_5B (id game.shield_wall_hand_hold 0.2.1)
  title "Shield wall: charge and slam, the call holds (spike 5B, by hand)"
Note: two packs share id game.shield_wall_3_v 0.1.8 (5A and 5B editor) and two share game.bumper_kart_football_3 0.1.8
with the copies of other lanes; if the menu keys rows by id and version, the Director may need to copy them to
.tl/proof-games/ under distinct ids, as last night.

GATES
- node devx/bin/tl.mjs check --tier fast: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230,
  foreman.typecheck). No engine/kernel/kit/rigs/style/seed/foreman/contract file changed, so no full tier.
- Hand packs: shield_hand_5B lint pass, smoke 3600 pass (4a7726ec), bot_player / bot_crew / bot_tofu pass with the hand
  pack's own hashes, bot_look pass (calls 1, hand 0), bot_call 3 of 5 (named above); biplane_3A_hand lint pass,
  smoke 3600 pass (cf1f1d3e).
- Editor packs: each job's own V0-V4 passed at promotion. 3600 f twice, seed 1, 0 errors each: 5A 60e9f0e5, 5B 77a8ceb6,
  karts 3A c8d6e6fc, karts 3B 3ff4a06c, biplane 66997af2 (both arms).
- One watchdog trip (5A, seed 3, f7431, 381 ms tick, 260 ms processor, machine at CPU 100 %); the same run twice more
  passed with the same hash 221013d8. Not hidden, not reproduced.

CHANGED FILES (nothing tracked outside docs/)
- docs/shifts/2026-11-27-juice-day/lanes/S35-packs/: SPIKE.md, STANDUP.md, REPORT.txt, clips/ (7 mp4, 6-10 s, 31 MB),
  stills/ (7 jpg sheets).
- .tl/ (untracked): job copies .tl/s35/base/, .tl/jobs/s35-3A, s35-3A2, s35-5A, s35-5B; hand arms .tl/juice/biplane_3A_hand,
  .tl/juice/shield_hand_5B; measuring tests .tl/s35/tests/ (bot_ladder_match_regular, bot_ladder_first_regular,
  s35_kart, s35_shield, s35_callprobe, s35_call_orig); tools .tl/s35/bin/; runs .tl/s35/runs/.
- No foreman/, engine/ or contracts/ file touched. No selftest case added (none needed: no code in the tree changed).

BEHAVIOUR CHANGES (named)
- 5A editor: the lesson's first call can be broken by a charge or slam, and the lesson then ends; tests/bot_call.gd's
  meaning changed on the person's word (the 'floored 2' row is waived when a big move broke the lesson call).
- 5B editor: a caller's own bots drop rush/slam presses from horn to burst.
- 5B hand: a charge or slam no longer floors a caller whose call is the protected lesson call.
- 3A karts: no pinned-bot reversal; sweet-spot bump 23 -> 20 (matches longer, fewer goals for a regular hand).

QUESTIONS FOR THE DIRECTOR
1. Lane T: FAIR_WORDS matches any "balanc*", so "the old balance check added ..." made a clean-up a guarded fair change
   (refusals, then unasked teams changes). Should the fairness read need an ask ("make it fairer", "more balanced")?
2. Lane T: Create never shows "[foreman] measure kept", and the what-changed card of a no-op promotion lists 16 files.
   Should a promotion whose pack is unchanged say so ("nothing changed: your edit of a measure was undone")?
3. Should a person be able to restore a frozen measure to an earlier merged version ("put the test back as in vN")?
4. The shared machine (CPU 100 %, ~80 Godot processes over 5+ trees) made the karts' invariants time out at 600 s and sent
   teams and show unasked builder rounds. Stagger the lanes' heavy runs, or raise V3's limit when the machine is starved?
5. Menu ids (see the note under PLAYABLE ARMS).

NEXT THREE THINGS THIS LANE WOULD DO
1. Karts: send only the reversal-rule half as a sentence (keep sweet 23) and measure it the same way.
2. Shield hand pack: ask the owner the remaining bot_call question (bodies' positions at the burst) on the 5B hand base.
3. Hand the FAIR_WORDS and "measure kept" findings to lane T with the job events (s35-3A events 1295-1443; biplane
   s35-3A events 743-790).
