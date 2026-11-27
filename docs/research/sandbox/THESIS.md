# Where the Home sandbox outshines Minecraft and Roblox (thesis, 27 Nov 2026)

Director's synthesis of R1 (Minecraft + Hytale), R2 (Roblox), R3 (smart builders + AI-first creation) and R4 (our engine), written while the owner is away; decisions are marked "Director (owner away)" and are the owner's to overturn. Sources are in the four reports; the finding numbers below point at their "ten findings" lists (R1#3 = R1's third finding).

## What the research agrees on (four independent lines)

1. **A build nobody needs gets an hour.** Tiny Glade's median playtime is 1 h 04 min (R3#1). Obby Creator (build + share, nothing tests it) has "REALLY bad" retention, while Build A Boat (the river tests your boat) and Theme Park Tycoon 2 (guests test your park) last (R2#1). Minecraft's base matters because survival needs it (R1, "where we lose"). **The world must test or use what you build.**
2. **Builds must do something, and the reachable form is "shapes plus rules".** Hypixel Housing's players script their houses with no-code actions and regions; its power users invented a text language (HTSL) because menus were too slow. Hytale's trigger volumes (box/sphere + 20 effects + conditions, saved in prefabs) are "just shapes and rules" (R1#7). Fortnite's devices carry its mechanics; Verse is "hard for creators who aren't engineers" (R3). Redstone and Luau are the two ends nobody casual reaches. **A small vocabulary of zones and rules, with a text form an LLM writes, is the gap between Minecraft and Roblox.**
3. **LLMs fail at space, not syntax.** VoyagerVision 36 % on basic structures, MineAnyBuild "severe limitations" (R3#3); "executable code was far easier than spatially correct outputs" (R1#2); the 2026 GDMC winners placed hand-made templates by terrain rules (R1#1). **The LLM chooses and places big shapes; the grammar absorbs the geometry; every ghost is checked for space before accept.**
4. **AI as hands, never as author.** Microsoft's Copilot-in-Minecraft was killed (May 2026) while a do-the-chores companion mod has 6.6 M downloads (R1#4); model-led creation cut ownership and diversity in a 486-person study (R3#4); designers deleted 45-60 % of unasked AI additions (R3#6); Roblox's procedural models throw away hand edits on regenerate (R2#3); Rec Room's prompt-to-create for non-builders "frustrated our more impactful creators" and the platform closed on 1 June 2026, its AI cost above its revenue (R3#5). **Ghost, accept, one undo, hand edits always survive, metered calls aimed at builders: what we already do is right, and it is rare.**

Also agreed: one enforced look keeps AI output from reading as slop (R2#6, R3#7: the LLM places authored kit parts, never generates art); terrain must be graded, undoable and fast (R3#9, R2#9, R1#6: ours is); a stamp should travel as a short code (R3#8, R2#8, R1#10); give precise control to everyone and unlock content, not control (R2#7); the skill floor kills building games, so ship a ready Home and make "say it" the first way to build (R2#2).

## What only we have (R4 section 9, verified at file:line)

- **One edit language for the hand and the LLM**, every layer (blocks, land, water, paths, plants, pieces), ghost first, one undo, replay without the model. Nobody gives players a co-builder for their own plot (R2#4).
- **Sentence to playable game** (Create: cartridges on cores), and **games already live in the world** (8 village plots, dungeons).
- **Determinism as a feature**: same inputs, same frames, same hash; walks are input records. A run can be replayed exactly (a best-time ghost, a shared challenge that is provably the same).
- **The look is data and reaches every player object** (crisp cel; one JSON restyles everything).
- **Play unlocks building** (trophies -> unlocks -> results card).

## Where we lose (be blunt)

No multiplayer (showing off is a core reason to build), no survival need, a smaller palette than a 1 m cube's "anything", no economy or audience at scale, no player scripting for "any game", and the "AI" label puts off 25-31 % of players (R3). We cannot win on scale or social today. We can win on **what one person makes in an evening, how good it looks, and that it plays**.

## The thesis

> **Build it, say what it does, play it.** The Home is the one sandbox where a person (by hand or by a sentence) builds something that always looks right, gives it rules without code, and plays it at once: the world tests the build, the result unlocks more to build.

The balance of freedom (the owner's "balanced level of freedom"): **free in the large, guided in the small.** The player and the LLM choose big shapes (blocks with smart joins, land, water, paths, plants, kit pieces, assemblies) and rules from a fixed vocabulary of a dozen verbs; the grammar and the style write the small things (corners, trims, the cel look), so nothing a person or a model makes can look off-style. Everything the LLM can do, the hand can do (no control behind a model or a paywall); the LLM is the fast hands, never the only way.

## What we build (Director, owner away)

**M6, today: rules and runs.** Zones (boxes on the 1 m grid) and rules (when, if, do) as a new layer in the same edit log, by hand (a Rules tool with presets: start, checkpoint, finish, coin, door, jump pad, hazard, message) and by sentence ("make this tower a parkour course with three checkpoints"). Visiting the Home runs the rules in frames, deterministically, in the visitor's space only (a game in the world still plays as alone). A run (start -> checkpoints -> finish) times itself, records the best in the Home's records, shows a finish card, and, because the Home is deterministic, can keep the best run's inputs for a replay ghost later. The LLM learns the rules ops, its ghost shows zones, and each ghost is checked for space (floating blocks, pads on nothing, the finish unreachable by a stair or a jump) before accept.

**Next (queued, in order):** day and night in the Home (lamps matter; the cel look at dusk); a stamp as a short share code; assemblies (parametric big shapes the LLM picks: house, tower, bridge, wall, stair run) so the LLM places templates instead of cells; residents that use what you build; the best-run replay ghost; then friends visiting (the determinism seam was built for it).

**Not now:** multiplayer, survival needs, a code language, generated art or meshes, a marketplace.
