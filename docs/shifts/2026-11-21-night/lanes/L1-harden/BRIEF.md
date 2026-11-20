# L1 crisp-harden: crisp cel gets real collisions, and tests that keep them

Read `docs/shifts/2026-11-21-night/COMMON.md` first (owner's words, laws, lane rules, your file column, selftest block 620-629).
Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/n21-harden`, branch `n21-harden`, base main `3a4580b`.
Route: Opus solo. Time box: work until 06:30, standups every 60 min in `docs/shifts/2026-11-21-night/lanes/L1-harden/STANDUP.md`.

## Owner's words
"besides hardening and bugfixing of our new decided graphical engine Crisp cel for its physics, objects collisions handling".
Owner's picks (20 Nov): rails, sign and fences collide (bodies, not decoration); collision regression tests; better kit
colliders; the round construction-site fence follows the footprint.

## What the scout found (start here, verify each)
- `engine/kernel/world/terrain/road_rails.gd`: "Presentation only. No collider is made... so no hash can move". The row
  has deliberate gaps (spur mouths, bridge, plot gates, river, every ninth span): keep every gap.
- Gate sign `detail.sign_out` (STYLE.md ~285) stands in front of the yard fence, no collider.
- `engine/kits/tl_kit_parts.gd:65-69` `auto_box`: one AABB around everything a generator emitted (misses concavity).
  `tree` trunk only, `bush` none, `pond` water none (`tl_kit.gd:61,66,77`). Fence: one box (`tl_kit_parts.gd:225-227`).
- Visitor collider build: `engine/kernel/world/landscape.gd:489-512` (terrain faces + copies of every pack's static
  colliders; copied in slices; only on a plot's first arrival).
- B2: the site's round fence (`engine/kernel/world/site/draw.gd`) is "the last circle seen from the air".
- No test covers walking through a fence/sign/rail or spawning inside a collider.

## Work, in this order
1. **Baseline first (before any change):**
   - `tl check --tier full` on your untouched worktree under the default look (crisp), then `world,packs` under
     `TL_STYLE=classic`. Record the counts.
   - This is also the merged-tree proof of the crisp landing. A red here is inherited: report it at once, in STANDUP
     with `blocked`, and keep going.
2. **Rails, gate sign, kit fences become static bodies** in the visitor's world space. Rails keep their gaps; a walker
   always has a way through.
   - Proof: the world still hashes as alone (`world` step).
   - Any pack hash that moves is named, with why. Colliders a pack makes inside its own space are a pack's hash; visitor-
     space colliders are not.
3. **Per-part kit colliders.** Replace the single-AABB `auto_box` for concave or rotated parts with compound boxes or
   convex shapes; bushes block the visitor, pond water does not. `TLKit.hash` covers collision shapes (selftest 070): every
   kit hash that moves is named, and the asset manifest is re-scanned (`tl assets scan`; the Director commits it).
4. **B2:** the site fence follows the lot footprint (the job's `lot` / the card's `footprint`), not a circle.
5. **Regression selftests** (`engine/tools/selftest.d/62x-*.sh`, headless, frames not wall clock). The visitor:
   - cannot pass a rail, the gate sign, a kit fence, a bush;
   - never spawns inside a collider at any plot gate or the world spawn;
   - is never stuck at a rail gap (walks through each gap kind in N frames);
   - can still jump/slide as `280-walk.sh` asserts.
   Each test must FAIL on the base commit for the thing it guards (run it there and quote the line).

## Acceptance
- [ ] The full gate is green on the branch, and `world,packs` is green under crisp and classic, with test counts >= the base.
- [ ] Rails, sign and fences block the visitor in a window (a 20 s clip of walking into them and through a gap), and there
      are headless tests for each.
- [ ] Per-part colliders: a list of the parts changed, each kit hash moved and why, and the manifest re-scanned.
- [ ] The B2 fence follows the footprint (a still from the air, before/after).
- [ ] `kits/KIT.md` and `kernel/world/WORLD.md` (colliders) are updated in the same branch.
