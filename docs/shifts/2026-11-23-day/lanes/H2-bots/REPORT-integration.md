H2 integration (bots on the combined hockey, H1 + H2), tree n23-int (branch d23-hockey, 588103c + this round, uncommitted).
Nobody has played it with a hand; every figure is a scripted hand or bots alone.

DONE, IN THE ORDER ASKED
1. A5: check_min_closing_red 4 -> 2.9, _blue 8 -> 5.8, cross_min_closing 1.5 -> 1.09 (ai.json); levels checks 6 / 2 / 2 ->
   4.36 / 1.45 / 1.45, cross-checks rookie 99 (never) / 0.73 / 0.18.
2. Tests on the combined tree: the 56 bot tests pass (list run 13:05-13:09 and the gate); no expectation moved, nothing
   loosened. Packs gate FAIL only on hockey invariants.many_budget (frame p50 1.308 ms, budget 1.0); back to back: this
   round 1.153 ms, the combined tree before it 1.154 ms, main's pack 1.073 ms (and 1.207 / 1.237 against 1.044 / 1.093 at
   13:33-13:35). Main's own pack is over the budget on this machine today. Not loosened.
3. The stick ladder: brain.gd _poke_ready; new keys poke_delay (20 / 6 / 0 frames in reach before a poke) and poke_gap
   (60 / 30 / 14 frames after his own last poke), mates 6 / 30; fresh_frames 60 / 6 / 0, D1 and the hunter only, no
   cross-check at rookie unchanged.
   Before (combined) -> after, the human poked off a minute of his carrying: rookie 17-19 -> 7-9.5, pro 40-43 -> 32-33,
   all-star 39-42 -> 35-42 (thirdjam ~30 at pro). His median carry: rookie 1.1-1.3 -> 1.5-1.7 s, pro 0.73-0.87 ->
   0.75-1.2 s, all-star 0.67 -> 0.72-0.78 s (thirdjam 0.57 s at pro). Judged playable: rookie leaves about 1.5 s to look,
   skate and choose and the poke is seen coming; pro is thirdjam's tempo. Opponents' takes a minute of play (regular hand)
   1.4 / 1.2 / 2.3 against thirdjam's 0.7 / 1.8 / 2.7: rookie still twice thirdjam's per minute of play (said plainly).
   Pass completion 83-93 % (unchanged). Mates' feeds 2.5 / 2.0 / 2.1 a minute (regular). Mates' shots fell at pro and
   all-star on the combined tree (0.41 / 0.36).
4. INTEGRATION.md (target / build 1 / combined / integration / thirdjam; tests; gates), clip and sheet at rookie with the
   newcomer hand, the probe v2 (bots_probe_v2.gd.txt).

GATES
- tl check --tier fast (13:21): PASS arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck.
- tl check --tier full --only packs (13:33): FAIL 128 of 129 verb runs (hockey invariants.many_budget only; see above).

CHANGED FILES (n23-int)
engine/packs/hockey/scripts/ai/brain.gd; data/ai.json; data/levels/rookie.json, pro.json, allstar.json; README.md (the AI
paragraph; a doubled "2.5 m cannot" in the poke paragraph); docs/shifts/2026-11-23-day/lanes/H2-bots/INTEGRATION.md,
STANDUP.md, REPORT.txt, bots_integration_rookie_newcomer.jpg, bots_integration_rookie_newcomer_s1.mp4,
bots_probe_v2.gd.txt. No H1 file changed.

FOR THE OWNER THIS EVENING
Start at rookie: your carries should last about a second and a half; a red man comes to your stick and waits before he
pokes. If rookie feels too sticky or too easy, the one number is poke_delay in data/levels/rookie.json.

NEXT THREE
1. Read the owner's play and move poke_delay / poke_gap from it, not from the ladder.
2. The mates' shooting at pro and all-star on the combined tree.
3. A speed and sprint counter in the probe.
