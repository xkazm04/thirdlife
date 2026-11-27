# Lanes R1-R3: deep research for the sandbox (day of 27 Nov)

The owner (27 Nov, leaving for 24 h): "use this time to master the sandbox engine, deep research Minecraft/Roblox. Think about what is our engine unique and where can outshine those two, chase it during the day so we stay with balanced level of freedom what to build combining with our graphics and LLM builder which are superior game design aspects".

## What our game is (context only; do not let it bias the findings)
Third Life is a Godot game. The player has a Home in a valley (Wren Valley) with games (dungeons) placed in the world. In build mode the player edits the Home by hand OR by a sentence to an LLM (Claude Opus), and both write the same edit operations into the same save file (so an LLM build is a ghost first, accepted as one undo, then editable by hand):
- land: a heightfield on a 3 m lattice, sculpted (raise, lower, smooth, flatten) and painted (dirt, sand, rock...);
- blocks: 1 m "smart blocks" (shape x material; stairs and roofs form corners, fences connect);
- pieces: kit parts (bench, street lamp, tree, bush, ...) placed freely;
- stamps: saved groups shared as items; water poured into a dug hollow; spline paths with grading; meadow/flower paint and a tree brush;
- unlocks: materials and parts unlock from real results in the games;
- the look is a crisp cel-shaded stylised style that every object shares;
- separately, "Create" makes small playable games from a sentence (an LLM editor that writes game cartridges).
No multiplayer yet, no survival loop, no logic/scripting layer for players.

## Your job
Research ONE subject (below) deeply and current to late 2026, with sources (URL per claim; mark anything you could not verify as [unverified]). Use web search and fetch; prefer primary sources (developer posts, GDC talks, official stats, patch notes), then serious analysis, then player communities (Reddit threads with real numbers of upvotes/comments). Spend real effort: 25-40 searches is normal.

Answer, for your subject:
1. **Why people build there.** What players actually do (time in building vs other modes, the most played building-centred experiences/modes, what goes viral), and the loop that makes building matter (need, showing off, roleplay, a game on top, economy, sharing).
2. **The building primitive.** Its grain and shapes, how fast a novice gets something that looks good, how tedious it gets at scale, and the tools players and modders built to escape the tedium (with names and adoption).
3. **The behaviour layer.** How builds come alive (Minecraft redstone/command blocks/datapacks, Roblox Lua/Studio, others' equivalents): who uses it, the barrier, what people make with it.
4. **The look.** Why the style works and where it fails; what players do to fight it (shaders, texture packs, mesh parts); how coherent player builds look next to each other.
5. **AI.** Every AI building/creation feature shipped or announced up to late 2026 (official and notable third-party/research), how it works, and how players and creators received it, with evidence.
6. **Complaints and gaps.** The recurring complaints of builders (not combat players) and the gaps designers and press point at.
7. **Openings for a game like ours**: where a game with (a) a higher-level grammar of smart pieces on a heightfield, (b) one coherent stylised look, (c) an LLM co-builder that writes the same edits as the hand tools, (d) small playable games in the same world, could clearly beat your subject, AND where it would lose (be blunt: what they have that we cannot match, and the traps).

Write the result to `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/research/sandbox/<FILE>` (2,500-4,500 words, markdown, sections 1-7 above, then "Ten findings that should change our design", each one line with its source). No git commands. Return the ten findings and the file path as your final message.
