# Integration 1, 13:00-13:30 (day of 20 Nov)

| Team | Arms committed | Joined | Gates on the joined tree | Exe |
|---|---|---|---|---|
| cel | cel-astra c5d32eb, cel-fable ae30cb0 | d20-cel 597a374 (no conflict) | fast PASS; world 8/8 (base hashes), packs 48/48, kit 95/95; style. 9/10, rig. 14, character. 1/2, cel. 2/4, celsurf. 8 | `dist/day/cel/ThirdLife` (PLAY-CRISP / PLAY-CLASSIC), export.check PASS |
| dio | dio-astra 8cae07a, dio-fable 83c86ec | d20-dio 1070eea (no conflict) | fast PASS; world 8/8 (base hashes), packs 48/48, kit 95/95; style. 9, rig. 14, character. 1, dio. 4, surf. 5 | `dist/day/dio/ThirdLife` (PLAY-DIORAMA / PLAY-CLASSIC), export.check PASS |

- **The cel reds:** one seam. `style_crisp.json` loads with "clamped: toon.shade_k = 0.9 is outside [0.2, 0.85]" (cel-fable's
  key), and cel-astra's figure and exe-AA cases expect a clean load. In play 0.85 is used. Sent to cel-fable.
- **Merge-back:** both teams' joined trees were fast-forwarded into their arms (uncommitted Fable edits kept). All four
  arms resumed at once; nobody waited for the gates.
- **The Director's eye:**
  - cel 07 is close to board 2;
  - cel 13: the meadow is one lemon field and the bluffs read purple;
  - dio 07 is sharp at last, with felt, pebbles and wood readable;
  - dio light is flat and its clouds are grey-white;
  - the dio scaffold is yellow plastic and its bush a blob.
  Each gap went to the arm that owns it.
- **Owner:** both exes are ready to play. Their words go verbatim to the arms.
- **Housekeeping:**
  - dio-astra's lane folder went from 77 to 22 MB (round 1 archived under `.tl/`, clip re-encoded to 7 MB);
  - all six d20 branches pushed;
  - the 13:20 timer was cancelled because the integration started early.
