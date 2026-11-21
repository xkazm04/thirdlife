# N6 world-directions: grind loops that grow the Home in three directions, for the owner to pick

Read `docs/shifts/2026-11-22-night/COMMON.md` first. Then read `docs/TWO-WORLDS.md` in full (The Home, build layers, the
order of work, the open questions), `engine/kernel/world/WORLD.md` and `engine/kernel/world/landscape.gd`.
- **You are the Opus director of three Astra-SOLO arms** (the route table: Astra alone wins look judged by eye; directing
  it hurts the art).
- **Worktrees:** yours `n22-world`; arms `n22-world-a`, `-b`, `-c`.
- **No arm lands tonight.** The owner picks.
- **Selftest:** 750-759 in each arm.

## The owner, 21 Nov
"Think please also how to use Astra agents, I reset its limit, we can create track for it to put world builder in use and
grind loops to shape the world in different directions."

TWO-WORLDS' open question 1 is still unanswered: "The Home's shape. One continuous land of about 6.5 km, or islands joined
by roads, boats or flight?" Answer it by showing it.

## The three directions (one per arm)
- **A, one continuous land:** a river valley running out from today's village into rolling farmland, woods and a distant
  ridge.
- **B, islands:** today's village becomes the home island in an archipelago, joined by bridges, causeways and a ferry
  line, with beaches and coves.
- **C, highlands:** the village on a terraced shelf, with switchback roads up to plateaus, a lake in a crater and cliffs.

## How each arm works
- Each arm builds a **procedural "Home growth" generator** in its tree: TWO-WORLDS order item 5, "a procedural base outward
  from the village". It lives in NEW files under `engine/kernel/world/home/**` and grows the land at least 3x the village's
  extent.
  - It uses today's terrain builder, kit parts, style and scatter. It does not wait for N5's chunks; it writes per-region
    data that the chunks can adopt later.
  - It places a few venue sites (empty game plots and dungeon-portal markers) where they read well in that landscape.
- **GRIND LOOPS:** each arm runs at least 5 rounds of the same loop.
  1. Build.
  2. Capture a flyover clip (20 s or less) and 6 stills from fixed vantage points, in a window, under crisp.
  3. Score them against a short world rubric you write first. Include:
     - a readable silhouette at distance;
     - variety without oatmeal (`docs/research/WHAT-MADE-GAMES-POPULAR.md`, anti-pattern 3);
     - roads that lead somewhere;
     - venues placed where a player would want to go;
     - performance: load time and frame cost.
  4. Refine.
  Each arm keeps its round stills, so the owner sees the evolution.
- You write each arm's brief, launch the three codex runs in parallel, re-check the gates, and keep the captures queued:
  the window lock is shared, and the 20 Nov lesson is to plan captures as a queue.

## Acceptance
- Three arms, each with:
  - a flyover clip of 20 s or less;
  - a 6-still sheet per round;
  - its rubric scores per round;
  - world 8/8 = alone (the growth must not move any game hash);
  - load time and frame cost.
- One side-by-side sheet and a `COMPARE.md`.
- No arm lands; the Director commits each arm to its branch.
