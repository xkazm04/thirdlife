# Lane S: what is needed outside the files lane S owns

1. **`docs/generated/REPORTS.md`** (generated; `tl arch` rule `reports-index-fresh`). Lane S's new report files
   (`docs/reports/engine-world-next/S.md`, this file) and the paths they cite make the digest stale. At the merge:
   `node devx/bin/tl.mjs arch --index` and commit the result (it is regenerated from the tree, so whichever lane
   merges last regenerates it once). Lane S regenerated it in its worktree only so that its own `tl check` could be
   read; drop that copy if it conflicts and regenerate.

2. **Kit (optional, not needed tonight).** The site draws its scaffold, walls and house from `TLMesh` boxes and
   `TLKitSite` parts (`crane`, `add_lumber`, `add_pallet`, `add_barricade`, `add_cone`, `add_ladder`, `add_flag`).
   A kit part "building under construction at stage s of n" (`TLKitSite.add_bay(mk, o, w, d, stage)`) would let a
   pack's own construction props and the world's site look the same; the world's drawing in `site/draw.gd`
   (`_bay`, `_walls`, `_house`, `_scaffold`) is the first draft of it.

3. **World collider (not built).** The site's bays have no colliders: `terrain/world_space.gd` has no call that drops
   a part, so a scaffold that comes down at the arrival would leave its collider standing. A `remove_tag(tag)` on the
   world space would let `site/draw.gd` add colliders under the tag `site <lot>` and drop them when the game arrives.
