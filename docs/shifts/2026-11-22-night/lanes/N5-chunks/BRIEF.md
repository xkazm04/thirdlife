# N5 world-chunks: the Home's foundation (TWO-WORLDS order of work, item 3)

Read `docs/shifts/2026-11-22-night/COMMON.md` first. Then read `docs/TWO-WORLDS.md` §"The Home" ("Where it is today",
"1. Chunked streaming terrain") and `engine/kernel/world/WORLD.md`.
- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n22-chunks`.
- **Route:** Opus director, Astra builds.
- **Land:** by 06:00.
- **Selftest:** 740-749.

## The owner, 21 Nov
"We still have docs with followups regarding the two-world building we should continue with". TWO-WORLDS' order of work,
item 3: "Chunk today's village with the same heights, and turn `ledger` on (proof: the same pictures and hashes)". It is
the first step that changes nothing visible, and every later Home step (lots, layers, growth) stands on it.

## Work
1. **Chunk the terrain into 96 x 96 m chunks** (32 x 32 cells of 3 m), with the source of truth per chunk in a `tl.land/1`
   record:
   - heights as quantised u16;
   - a material id per cell;
   - the water level;
   - a sparse delta over a procedural base made from the world seed.
   Today's village terrain becomes the base plus nothing, so the same heights come out.
2. **Build the mesh and collider per chunk** (Jolt `HeightMapShape3D` per chunk in the visitor space for the near ring), on
   a per-frame build budget counted in frames. The near/mid/far rings may start as "everything near" for today's 0.43 km²,
   with the ring code present and tested.
3. **Turn `ledger` on** for distant games (`backdrop_m`), as WORLD.md describes. The 1/16 floor stays.
4. **Proof that nothing visible changed:**
   - the same tour pictures within the noise floor (the 20 Nov lesson: same world, same site jobs, `--load=block`);
   - the same hashes (world 8/8 = alone);
   - load time measured before and after.
5. **Declare `tl.land/1`** to the Director as a contract proposal (`contracts/`, PATCHES.md). Do not write contracts yourself.

## Acceptance
- world 8/8 = alone, with every hash equal to main.
- Tours headless and in a window PASS, with the pictures compared to main.
- Block 740: chunk boundaries have no cracks (heights equal across seams), colliders exist per near chunk, the land record
  round-trips, and the ledger tier unloads and reloads a game with the same summary.
- Load time and frame cost compared to main.
- WORLD.md gets a "Chunks" section.
