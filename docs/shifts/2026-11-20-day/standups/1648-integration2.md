# Integration 2 (16:20-16:48)

**Arm commits:**
- cel-astra c9d14ba
- cel-fable cd89476
- dio-astra 008ee0c (lane stills recompressed, 49 -> 25 MB)
- dio-fable 74208f6

**Merges:** both clean, with no conflicts.
- `d20-cel` 5e4b5c8.
- `d20-dio` f010540, plus 8968ffe, which ports `road_rails.gd` and one guarded `landscape.gd` line from cel. The rails stay off until `style_diorama` names `detail.road_rails`.
- `tl_style.gd` is 585/600 on cel and 600/600 on dio.

**Gates:**

| Gate | cel | dio |
|---|---|---|
| import errors | 0 | 0 |
| fast | PASS | PASS |
| full kit / packs / world | 95/95, 48/48, 8/8 PASS | 95/95, 48/48, 8/8 PASS |
| style. / rig. / character. | 10/0, 14/0, 2/0 | 11/0, 14/0, 1/0 |
| arm blocks | cel. 4/0, celsurf. 9/0 | dio. 4/0, surf. 5/0, diorama. 3/0 |

- The full-gate hashes are the base's: `seed.drive a2940a17@3441`.

**Exes:** both export checks PASS.
- `dist/day/cel/ThirdLife`, 5e4b5c8. `PLAY-CRISP.cmd`, `PLAY-CLASSIC.cmd`, and `dist/day/cel/PLAY-LATEST.cmd` (crisp).
- `dist/day/dio/ThirdLife`, 8968ffe. `PLAY-DIORAMA.cmd`, `PLAY-CLASSIC.cmd`.

**Shots:** `.claude/worktrees/d20-{cel,dio}/.tl/i2/shots/` (16 + log each, jpg beside png).

**Merge-back:** fast-forward into all four arms, which were resumed at 16:35, before the selftests ended. All six branches are pushed.

**By eye, both at the same cameras:**
- **cel** is clean, crisp and calm, with the board's composition: rails, patches, strata. Gaps:
  - the rails run through the spur sign and flag posts;
  - there is a dark C-shaped band on the meadow from above;
  - the river from above is lilac with squiggles.
- **dio** is fuller in material: felt bushes, grit, dowels, deep shadows. Gaps:
  - the grade turns the frame sepia/ochre, so the grass reads mustard, not the board's green lit gold;
  - the sky is streaky and muddy near the horizon;
  - shadows are near-black;
  - the dowels read pale plastic.
- These go to the arms as they were seen.
