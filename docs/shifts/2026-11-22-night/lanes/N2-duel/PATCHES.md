# N2 duel: what I need outside my column

1. **engine/packs/README.md** (the house-games index; not mine). Add one line after the parkour line:

   ```
   [Duel](duel/README.md) (`game.duel`): one fighter against a ladder of three rivals (the Wall, the Duelist, the Dancer), best of 3 in a walled ring; DUEL-PLAYBOOK section 6 rules, every contact changes both fighters. Play with `tl play duel`. Recipe card: `engine/cards/duel.json`.
   ```

2. **Rig clip clock (kernel/rigs, N1 or the Director).** The duel stretches the 14-30 frame fight clips over the rules' wind-ups
   (18-54 frames) by writing `rig.clip_t` every frame (`engine/packs/duel/scripts/feel.gd`, `pose` / `run_pose`). `clip_t` is a
   public member of `TLRigNode` but not written down in RIGS.md as pack API. Ask: either document it ("a pack may set the
   clip's time each tick"), or add `rig.play(clip, blend, speed)` / a runtime param `clip_time`. The adapter is the only
   place that touches it, so the switch is one file.

3. **contracts/CARDS.md (Director).** The brief asks the card to carry "the frame tables and the contact matrix as the
   card's text and data". The schema has no key for tables, so they are in `do` (text) and named in `data_files` roles
   (`data/moves.json`, `data/contacts.json`, `data/rivals.json`). Proposal: an optional `tables` key,
   `[{name, file, columns: [..], rows: [[..]]}]`, checked against the example's data file.

4. **engine/boot/games.json** is unchanged: the duel is not in the village world, so `world` stays 8/8 as the brief's
   acceptance reads it. Adding it is one line when the Director wants it in the village.
