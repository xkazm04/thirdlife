# N2 duel-reference: one excellent duel the editor can copy

Read `docs/shifts/2026-11-22-night/COMMON.md` first. Then read `docs/research/DUEL-PLAYBOOK.md` IN FULL: it is your spec,
and you implement §6.
- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n22-duel`.
- **Route:** Opus solo. This is design judgement and feel by eye.
- **Land:** by 06:00.
- **Selftest:** 720-729.

## The owner, 21 Nov
"there are hundreds of duel games (souls like, for honor duels) with well known game design paths we can mimic". He chose
"Reference pack + card + playbook": hand-build ONE excellent duel pack (a house game, like hockey), extract a recipe card
from it, and give the editor the playbook, so generated duels start from proven rules.

## Work
1. **`engine/packs/duel/`, a house game.** One player against a ladder of the three rivals of §6.7 (the Wall, the Duelist,
   the Dancer), best of 3 rounds of 60-75 s, in a colosseum ring with walls that splat.
   - The fighter state machine of §6.4, with frame counters, an 8-frame input buffer, stamina, posture and poise tiers.
   - The interaction matrix of §6.5 and the contact results of §6.3: every contact changes BOTH fighters.
   - The AI tiers of §6.6, which react only to visible state, never repeat a string three times, and end every string in
     a return window.
   - Controls a newcomer learns in the first 30 s (the plays-twice checklist): light, heavy (hold to charge), block/parry
     tap, roll, bash.
   - Readable state: HP, stamina and posture bars, the parry flash, and the charged heavy's red flash.
   - Clips are L2's fight clips (strike, strike_heavy, block, roll, dodge, body_check, taunt), with arm A's falls and get-ups.
2. **Use the feel kit** (N1: `TLHit.impact`, the mutual-reaction helpers, the pushbox, the occluder fade).
   - Code against the names in COMMON.md, behind ONE adapter file in your pack.
   - Until N1 lands, implement the pack-side minimum through the adapter: pack-held hit-stop frames and `shove`-based
     pushback.
   - When the Director tells you N1 landed and merges main into your tree, switch the adapter to the kernel calls.
3. **`engine/cards/duel.json`,** a recipe card of the existing card schema (`contracts/CARDS.md`). It records:
   - the rules, the frame tables and the contact matrix as the card's text and data;
   - the three archetypes;
   - the bot list;
   - its `fun` block.
   If the schema lacks a place for something, put the question in your report; CARDS.md is Director-only.
4. **Bots and metrics.**
   - A bot per contact type asserting that both fighters change state.
   - A ladder through `TLHand` (newcomer, regular, sharp, perfect) against each rival, quoted with hands.
   - From the plays-twice checklist (docs/research/WHAT-MADE-GAMES-POPULAR.md): every opponent acts (item 9), tells of at
     least 12 frames (item 11), lead changes (item 15), the newcomer wins sometimes (item 7).

## Acceptance
- packs (with duel added to the gated house packs as hockey is) green; world 8/8 = alone; block 720 green.
- **Clips judged by YOU in a window, 20 s or less each:**
  - a parry into a riposte;
  - a blocked heavy punished by a light;
  - a bash into a wall-splat;
  - a clash;
  - the Duelist's tell puzzle;
  - a round won.
  If a clip does not read as Souls / For Honor feel, it is not done.
- The ladder table, with hands.
- `engine/packs/duel/README.md`: how to play, the rules, and the numbers. Note what you changed from the playbook and why.
