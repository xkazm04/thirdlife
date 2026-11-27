# Day of 27 Nov 2026: the sandbox engine, past Minecraft and Roblox

Owner (27 Nov ~07:50, leaving for 24 h): "lets push main, I will be for 24 hours now off, use this time to master the sandbox engine, deep research Minecraft/Roblox. Think about what is our engine unique and where can outshine those two, chase it during the day so we stay with balanced level of freedom what to buil combining with our graphics and LLM builder which are suprerior game design aspects"

No handshake (owner away): the scope is the owner's sentence; the Director decides lanes, models and landing, and records each decision here and in `.spark/Spark/ideas/world-sandbox.md` as "Director (owner away)".

## State at start (07:55)
- main = origin/main 8be26d61 (M5 pushed by the juice night's push). Night shift done, no claims, no Godot running.
- RAM 33 GB free of 63, disk 94 GB free. Gate on main: last full at M5 (a634560b) all reds pre-existing (hockey + pushbox many_budget, base.lines x2).

## Phases
1. **Research (07:55-~10:30)**: R1 Minecraft + Hytale, R2 Roblox, R3 smart builders (Tiny Glade, Townscaper, Sims, Fortnite/LEGO, Valheim/Enshrouded, Dreams...) + AI-first creation; R4 scout of our engine (uniques, gaps, file:line). Output `docs/research/sandbox/R1-R4*.md`. Opus, web.
2. **Look polish (parallel, all day)**: LP lane, worktree d27-look, Opus: terrace face, growth visibility, stone path, pond shore, LLM bridge deck. Brief `lanes/LP-look/BRIEF.md`.
3. **Thesis (Director, after research)**: `docs/research/sandbox/THESIS.md`: what is unique, where we outshine, the balance of freedom; the design of the next milestones (M6+) as spark wave 6 (Director decisions).
4. **Build (midday-night)**: contract, seam, lanes (max 5 agents running at once), landing by the full gate + uncapped kernel suite + A/B of timing reds; push at the end (the owner's "lets push main" stands for the day's landings).
5. **Verdict (by 28 Nov 08:00)**: VERDICT.md + an Artifact page: what to play, stills, asks.

## Lanes
| Lane | Worktree / branch | Model | Started | Agent |
|---|---|---|---|---|
| R1 Minecraft + Hytale | - (writes docs/research/sandbox in d25-main) | Opus | 08:05 | R1 |
| R2 Roblox | - | Opus | 08:05 | R2 |
| R3 smart builders + AI | - | Opus | 08:05 | R3 |
| R4 our engine scout | - (read-only, Director saves) | Opus Explore | 08:05 | R4 |
| LP look polish | d27-look / d27-look | Opus | 08:05 | LP |

Selftest blocks: LP 768-772; build lanes get 773-799 by range.
Landing: the overlay's pre-merge list on the merged tree in a dedicated worktree; timing reds by A/B under the same load; uncapped `selftest.sh` by count.
