# L6 crisp-harden: the open items, one by one

Read `docs/shifts/2026-11-21-day/COMMON.md` first: the owner's words, the laws, your column (`engine/kernel/world/**`
except `site/event_schema.gd`, plus `engine/kits/**`), and selftest block 700-709.

- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n21d-harden`, branch `n21d-harden`, base main
  `df58f0b`.
- **Route:** Opus solo. Time box: until 18:30.
- **Standups:** in `lanes/L6-harden/STANDUP.md`. When you are landable, also send the Director a message.

## The owner's words
"Crisp looks well, continue with open items during this day to harden."

## Start from last night's L1
Read `docs/shifts/2026-11-21-night/lanes/L1-harden/REPORT.md`: its "NEXT THREE THINGS", PATCHES.md and the clip.
Selftest block 620 is its guard.

## Work, in this order (each fix comes with a case that fails on the base)
1. **The other road-edge objects.** The scatter measures clearance on a 3 m grid, so a tree, rock or tuft can lean onto
   the verge or the road. Check them with an exact road distance, as the bushes now are. Fix them, then walk the road
   in a window.
2. **A kit-wide "collider top = mesh top" selftest:** every kit part's collider top within a tolerance of its mesh top,
   turned and stacked.
   - Fix the remaining `auto_box` parts that are not blocks when turned or stacked (barricade legs, the cabin step).
   - A part's hash change is named; re-scan the manifest only in your tree, as last night.
3. **Site fixtures without an owner** (L1's report). Make them owned, or remove what nothing uses, with evidence.
4. **Block 502, flaky under load** (it failed once in the busy gate and passed alone 3/3). Find the wall-clock or
   frame-race dependence and fix the test or the code. Never loosen it.
5. Then walk the village in crisp as a person: walker into every kind of object near the roads and sites. Note anything
   that lets him through, holds him wrongly, or floats, and fix what you can.

## Acceptance
- Every fix has a case in block 700 that fails on the base.
- world 8/8 = alone under crisp AND classic (`TL_STYLE=classic node devx/bin/tl.mjs check --tier full --only world,packs`).
- The kit selftest is green; the kernel blocks you touch are green.
- A clip of the walk (20 s or less) in your lane folder.
- If kit hashes move, list them and the expected manifest rows for the Director's re-scan at landing.
