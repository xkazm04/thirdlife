# Lane C2: changes outside lane C's files (for the Director)

1. **`docs/generated/REPORTS.md`**: regenerated here so arch passes (46+ reports). After merging C2 and S2, run
   `node devx/bin/tl.mjs arch --index` once more.
2. **`contracts/CARDS.md`**: add the `hands` row and a section, worded as the PROPOSAL at the top of
   `docs/reports/engine-world-next/C2.md` (shape, the rule that sets a bound from a measured row, the pack's
   `tests/bot_hand_<hand>.gd` with `won` in `_bot_result()`, the Foreman's final-verification step, `tl cards hands`).
   Also update "What is not here yet": the hand checks are now executed; the other acceptance lines are still prose.
3. **`contracts/JOB.md`**: one line under final verification: when the job's card has `hands`, every check runs on
   seeds 1..N as `verify` events (stem `final-hand-<hand>-seed<k>`, verb bot, V4). A failure means nothing is promoted
   and the job ends `failed` with the rows in its reason; after a change, pack/ goes back to the last promotion.
4. **`engine/packs/hockey`** (not a patch, a finding): at level rookie (the default), an idle player wins 16 of 20
   seeds because blue's two AI mates play for him. A "doing nothing never wins" check therefore cannot go on
   card.team_possession until the game changes, for example by mates who pass to the human instead of scoring alone.
