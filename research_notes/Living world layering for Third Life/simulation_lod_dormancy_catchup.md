# Simulation level of detail, dormancy and catch-up in persistent game worlds

Scope note: this session had a budget of about 17 tool calls. Items marked VERIFIED were read from a fetched page in this session. Items marked SECONDARY come from search snippets or wiki/forum pages. Items marked RECALL are from my background knowledge, NOT checked against a source this session, and must be treated as unverified leads (they are kept in Inferences or Gaps, never in Cited Findings). Several primary sources (Minecraft Mojang changelogs, DF dev log, Game AI Pro PDFs, GDC talks, Jolt docs, UE URO page, Bethesda reset timers, Stardew) could not be reached; see Gaps.

## Q1. What simulation tiers do shipped games use (with numbers)?

### Takeaway
Shipped games cluster into five tiers: full tick, per-system reduced rate (sleeping/active lists, rare/long ticks), abstract off-screen simulation (A-Life offline graph, DF world activities), frozen-with-edge-effects (Minecraft border chunks), and not simulated at all (unloaded chunks). Minecraft and Factorio give the most precisely documented numbers; for Kenshi, Bethesda, NMS, Stardew and RimWorld I could not obtain primary figures.

### Cited Findings

**Minecraft Java (minecraft.wiki Chunk page, VERIFIED fetch; the wiki is a community source, medium confidence, but it tracks Mojang changelogs)**
- Load levels: Entity Ticking is level 31 and below (all game aspects); Block Ticking is level 32 ("lazy chunks": entities not naturally spawned or processed but accessible, chunk ticks not processed); Border is level 33 (nothing runs, blocks and entities still accessible/modifiable); Inaccessible is level 34+ (only world generation). Levels propagate +1 per chunk from a ticket, max 44; only the lowest applies. — [Minecraft Wiki: Chunk](https://minecraft.wiki/w/Chunk)
- Simulation distance s (chunks): entity-ticking square side = min(2s+1, 63); block entities, scheduled ticks and chunk ticks cover side = min(2s+3, 65), i.e. one extra frame ring. Simulation distance 5 gives an 11x11 entity area inside 13x13. — [Minecraft Wiki: Chunk](https://minecraft.wiki/w/Chunk)
- Chunk ticks including mob spawning only for chunks whose centre is within 128 blocks of a player; hostile mobs despawn instantly beyond 128 blocks; passive mobs do not spawn outside a 240x240 block area around a player. — [Minecraft Wiki: Chunk](https://minecraft.wiki/w/Chunk)
- Idle timeout: each dimension has a counter that rises by 1 per tick (not under `/tick freeze`); at 300 ticks entity and block-entity ticking, the Ender Dragon fight and lightning stop. This is a whole-dimension dormancy tier with no player present. — [Minecraft Wiki: Chunk](https://minecraft.wiki/w/Chunk)
- Unloaded chunks process nothing. The game loads whole chunks even if only a section is needed. Edge effects are suspended next to inactive chunks (flowing water and fire stop at the first adjacent block until the outside chunk reaches level 32 or below). That is a documented "pop"/seam at the boundary of a dormant region. — [Minecraft Wiki: Chunk](https://minecraft.wiki/w/Chunk)
- Tickets: player spawn level 30 radius 3 (1 s refreshed), portal level 30 radius 3 (15 s), `/forceload` level 31 per chunk (persisted), ender pearl 2 s. These are the "keep this region awake" mechanism, analogous to a pinning API. — [Minecraft Wiki: Chunk](https://minecraft.wiki/w/Chunk)
- Version changes: 1.20.5 (24w03a) added `/gamerule spawnChunkRadius` and cut the default from 10 to 2; 1.21.9 (25w31a) removed the rule and spawn chunks altogether (needed chunks are loaded before join instead). — [Minecraft Wiki: Chunk](https://minecraft.wiki/w/Chunk)
- Bedrock: everything is active in loaded chunks within simulation distance and in `/tickingarea`s; player chunks form a taxicab circle of radius sim distance + 1 (cardinal edges = sim distance); mob spawning is evaluated within a 6-chunk cylindrical radius. — [Minecraft Wiki: Chunk](https://minecraft.wiki/w/Chunk)
- Random tick speed of 3 per section per tick was NOT on this page (not confirmed this session).

**Factorio (everything always simulated; UPS is the limit)**
- FFF-421 "Optimizations 2.0" (July 2024), VERIFIED fetch of the official blog: Roboports are turned off when idle and reactivated only when needed, average Roboport time in a test save fell from 1 ms to 0.025 ms per tick. Worker robots "sleep": they store a movement intention and skip most updates, with hard limits of 20 ticks of movement and 60 ticks stationary between updates, rendering predicts motion in between; overall +15% in one office save, typically +10-25% in robot-heavy saves. Radar "keep revealed" counters share work in one bucket per tick (+3.6% overall). — [Friday Facts #421](https://www.factorio.com/blog/post/fff-421)
- Same post, failure case: multithreading the electric network cut 0.5 ms to 0.39 ms but raised CPU use from 0.5% to 15% and the save was not faster (memory-throughput bound). Multithreading read-only control behaviours (belt readers, combinators) gave +9.5% on a save and 14.9x on a 77k-combinator synthetic. — [Friday Facts #421](https://www.factorio.com/blog/post/fff-421)
- SECONDARY: a belt transport line stops updating when it holds no items or no moving items (cited by a Reddit guide to FFF-176). Sleeping assemblers/refineries/chemical plants cost essentially nothing in one forum benchmark; inserters watching a belt with items still cost ~440 ns in that test; moving items on and off belts is the usual cost. — [Factorio forums: some things I tested for UPS](https://forums.factorio.com/viewtopic.php?p=588724), [r/technicalfactorio](https://redlib.hbubli.cc/r/technicalfactorio/comments/r6ye86/mechanics_of_transport_line_splits) (lower confidence)

**S.T.A.L.K.E.R. A-Life**
- Every AI character is online (within a set radius of the player) or offline (beyond). Vanilla radius is roughly 150 m, changed in later entries and by mods. While offline, A-Life uses the online information to update NPCs as game time passes; enemies and monsters move and events happen away from the player. Offline movement runs on a "detailed graph" (lead programmer Dmitriy Iassenev) which the player never sees; the article calls the between-zones simulation "to some degree" an illusion. Developers cut features (factions, defending encampments) so A-Life never reached full potential. — [Game Developer: A-Life, an insight into ambitious AI](https://gamedeveloper.com/design/a-life-an-insight-into-ambitious-ai)
- SECONDARY: `switch_distance` in `alife.ltx`; mod authors report values of 150 for performance, and one Steam user reports stutters at 2000 and none at 1. Exact key name (`alife_switch_distance`) not confirmed. — [ModDB performance alife settings](https://www.moddb.com/addons/performance-alife-settings) (lower confidence)
- S.T.A.L.K.E.R. 2 Update 2.1 added an option to increase NPC (A-Life) visualisation distance, not affecting story characters. — [GamingOnLinux](https://www.gamingonlinux.com/2026/10/s-t-a-l-k-e-r-2-heart-of-chornobyl-2-1-adds-a-life-npc-visualisation-distance-options/) (snippet only; relation to the engine switch distance unconfirmed)

**Dwarf Fortress**
- SECONDARY: older versions stopped all world activity once world generation finished; with "world activation" the world keeps developing during play: succession disputes, usurpations, roaming armies (invasion, harassment, reclaiming sites), sites conquered/destroyed/founded. Invaders physically cross the map to reach the fortress. Dev page lists unfinished items (off-site armies you control, army vs army battles); a wiki note says sites founded by other civilisations during fortress mode may have ownership fields set incorrectly. — [DF wiki World activities](https://dwarffortresswiki.org/index.php/World_activities), [Bay 12 dev page](https://bay12games.com/dwarves/dev.html)

**EVE Online time dilation (a global "slow the clock" tier)**
- Maximum slowdown 10% speed (1 in-game second lasts about 10 real seconds); applied per node when it is overloaded; indicator green/yellow/red; does not affect server time, industry or skill training. — [EVE University wiki: Time Dilation](https://wiki.eveuniversity.org/Time_Dilation)

**Bethesda grids**
- SECONDARY: `uGridsToLoad` default 5, `uExterior Cell Buffer` default 36 (= (5+1)^2 per one forum formula); 7 with buffer 64 is the common stable tweak; changing uGrids can make saves incompatible; higher uGrids reportedly causes AI spawning problems. — [UESP CK: uGridsToLoad](https://ck.uesp.net/wiki/UGridsToLoad), [Nexus forum](https://forums.nexusmods.com/topic/653469-what-are-ugrids-and-how-do-you-tweak-them), [STEP forum](https://stepmodifications.org/forum/topic/825-ai-spawning-problems-with-higher-ugrids/)

**Assassin's Creed Unity crowds**
- SECONDARY: GDC 2015 "Massive Crowd on Assassin's Creed Unity: AI Recycling" (Francois Cournoyer) describes AI level of detail enabling thousands of replicated, persistent NPCs, using pooling to swap low-res NPCs for high-res ones without the player noticing; a Japanese write-up says LOD was applied to behaviour logic, not just rendering. Tier structure not confirmed (slides not reached). — [GDC Vault](https://www.gdcvault.com/play/1022141/Massive-Crowd-on-Assassin-s)

**Kenshi**
- Wikipedia notes the map is divided into "Zones". I found no first-party description of Kenshi's off-screen simulation. A fan "Kenshi Virtual Simulation Engine" mod (external sim, self-reported, crashes when scaled up) is not evidence about the base game. — [Wikipedia: Kenshi](https://en.wikipedia.org/wiki/Kenshi_(video_game)), [mod devlog](https://problemchild1500.itch.io/kenshi-virtual-simulation-engine)

### Inferences
- Tier ladder observed in the sources: (T0) full tick near the player; (T1) per-entity sleep with bounded wake interval (Factorio robots: max 20 ticks moving, 60 stationary); (T2) region block-tick-only "frame ring" (Minecraft lazy chunks) which runs scheduled work but not entity/spawn work; (T3) abstract graph simulation (A-Life offline, DF world activities); (T4) unloaded/frozen, with edge-effects suspended; (T5) global time scaling (EVE TiDi, floor 10%).
- Minecraft's design is a distance-to-ticket mapping plus a timeout idle tier; the "frame ring" of one chunk (2s+3 vs 2s+1) is a cheap guard against boundary artefacts, directly reusable as "a pack's neighbours run one tier above its own".
- Factorio's rule is "inactive means provably nothing would change" (no moving items, no energy need). That is the only tier that is exact; everything else trades fidelity.
- RECALL (unverified): Minecraft random tick speed 3 per section; RimWorld Tick/TickRare (250 ticks)/TickLong (2000 ticks) and a world-map layer where caravans/settlements are abstract; Kenshi loads cells around squads; Skyrim cell reset about 30 days for most cells; DF fortress mode runs in "local" view while world sites update coarsely. Verify all before relying on them.

### Gaps
- RimWorld tick types and world abstraction: wiki page 404'd; no source obtained.
- Kenshi, No Man's Sky, Skyrim cell-reset timers and Radiant AI off-screen schedules, Left 4 Dead: no usable sources found.
- Mojang changelog primary sources for simulation distance (1.18) not read; only the community wiki.
- Dwarf Fortress: no numbers on off-site activity cost.

## Q2. Catch-up on return: how, and how it fails

### Takeaway
Documented evidence is thin in this session. The one verified design is Minecraft's "no catch-up, edge effects simply suspended", and A-Life's "offline abstract simulation, then materialise". Closed-form, replay, sampling and snapshot strategies are well-known patterns but I could not source specific shipped numbers.

### Cited Findings
- Minecraft: unloaded chunks process nothing and the world is simply as it was left; fluids and fire resume from their frozen boundary only once the neighbour is at level 32 or lower. — [Minecraft Wiki: Chunk](https://minecraft.wiki/w/Chunk)
- A-Life: offline NPCs are advanced using game-time-based updates on a hidden graph and then become visible when the player crosses the switch distance; the developers describe the result as partly an illusion. — [Game Developer](https://gamedeveloper.com/design/a-life-an-insight-into-ambitious-ai)
- Stardew Valley catch-up: search found no reliable source; one itch.io post claims events only tick for locations the player is teleported to (unconfirmed, possibly not vanilla). — [itch.io post](https://itch.io/post/10967294) (low confidence)
- A-Life switch distance tuning anecdotes: stutters at large radius, none at tiny radius (online set size drives hitch cost). — [ModDB / Steam reports via search](https://www.moddb.com/addons/performance-alife-settings) (low confidence)
- Factorio worker robots use stored intent plus render-side prediction so skipped updates are not visible. — [Friday Facts #421](https://www.factorio.com/blog/post/fff-421)

### Inferences
- Four catch-up families (RECALL-based taxonomy, patterns not sourced to a game here): closed-form from elapsed time (crop growth, timers; exact only for systems with no interactions); replay at higher speed (exact, cost linear in elapsed time, bounded only if capped); statistical sampling of an outcome (cheap, not reproducible against a "true" run, so must be seeded from recorded state); snapshot and resume (zero drift, zero progress).
- Failure modes to design around: leave-and-return exploits (resetting a bad state by walking away, or farming results by re-rolling a sample, fix by seeding the sample from persisted state and not from return time); visible pops where abstract state is materialised (A-Life, AC Unity pooling hide them by materialising out of view); long hitches when many systems catch up in one frame (fix: budget the catch-up across frames and materialise lazily); non-determinism where catch-up order depends on when the player arrived.

### Gaps
- No primary source for Stardew's day-update behaviour, Skyrim's cell reset/respawn catch-up, or any post-mortem on catch-up hitches.

## Q3. Scheduling: time-slicing, significance, AI and animation LOD

### Takeaway
Engines separate "score significance" from "act on it". Unreal's Significance Manager ranks registered objects but does nothing by itself; Factorio and Minecraft show bounded-interval sleeping and distance tickets as the acting side.

### Cited Findings
- UE Significance Manager (UE 5.9 docs): ranks managed objects via a user significance function evaluated per viewer transform (highest wins, or lowest if ascending), runs in parallel (must be thread-safe), optional post-significance callback (None, Concurrent, or Sequential in most-to-least-significant order); `Update` is called once per frame by your code; no numeric thresholds are defined, you pick them; the manager "does not actually improve performance". — [Epic docs](https://dev.epicgames.com/documentation/en-us/unreal-engine/significance-manager-in-unreal-engine)
- SECONDARY: URO (update rate optimisation) only skips animation update/evaluation, it cannot disable tick since logic lives in the mesh tick; the Animation Budget Allocator is reported as easier to manage. — [UE forums](https://forums.unrealengine.com/t/uro-vs-animation-budget-allocator/2509506) (forum, lower confidence). The official URO page with published thresholds was not reached.
- Factorio bounded-interval sleeping: 20 ticks max moving, 60 ticks max stationary. — [Friday Facts #421](https://www.factorio.com/blog/post/fff-421)
- Minecraft idle timeout 300 ticks per dimension. — [Minecraft Wiki](https://minecraft.wiki/w/Chunk)
- AC Unity AI LOD with pooling (see Q1). — [GDC Vault](https://www.gdcvault.com/play/1022141/Massive-Crowd-on-Assassin-s)
- Game AI Pro chapter 14 "Phenomenal AI Level-of-Detail Control with the LOD Trader" exists, Chenney's 2001 GDC paper on proxy simulations is the classic reference; contents not read. — [Perlego TOC listing](https://www.perlego.com/book/1604749/game-ai-pro-collected-wisdom-of-game-ai-professionals-pdf)

### Inferences
- For Godot a significance score per pack (distance, on-screen, player attention, pending interaction) mapped to a tier with hysteresis is the direct analogue; the score must itself be deterministic input if the sim is replayed (see Q5).
- Budgeted round-robin: with tens of packs, a per-frame millisecond budget and "oldest-updated first" among lower tiers is the generic solution (RECALL, not sourced).

### Gaps
- No published URO distance/rate thresholds, no Game AI Pro text, no GDC numbers on AC/Horizon/Watch Dogs.

## Q4. Tiers for a scripted mini-game (physics bodies + rule state)

### Takeaway
No shipped-game source covers this exact case; the analysis below is inference from the cited sources and standard physics practice (RECALL). Jolt-specific claims were NOT verified (docs fetch failed).

### Cited Findings
- (none specific to rigid-body mini-games; relevant analogues: Factorio's sleep-with-wake-rules, Minecraft's block-tick-only tier, A-Life offline abstract graph, as cited above.)

### Inferences
Catalogue of tiers a spike could test (cost and breakage are hypotheses to measure):
- **T0 Full**: 60 Hz Jolt step plus rules plus AI. Baseline cost C0 per pack; measure ms per pack per tick versus body count (50, 150, 300).
- **T1 Reduced physics rate**: step every 2nd or 4th tick with dt=2/60 or 4/60 (or step per-pack at 30/15 Hz). Hypothesis: stacking, thin colliders and fast bodies tunnel or jitter; behaviour diverges from T0 so results differ; stays deterministic if the schedule is recorded. Measure divergence of score outcome versus T0 and tunnelling rate.
- **T2 Physics asleep, rules ticking**: bodies put to sleep or removed from the active set, rule state (clock, score) advances on an abstract model (e.g. per-team scoring rate). Cheapest live tier; breaks when rules depend on body positions (goal detection). Needs a defined "materialise" step that places bodies consistent with abstract state.
- **T3 Frozen snapshot, resume**: zero cost, zero drift; fails the "every game stays alive" rule if shown as stalled, so only acceptable if world time visibly continues elsewhere.
- **T4 Attract loop from recording**: replay recorded inputs (deterministic input replay) at T0 cost or replay of recorded body transforms at near-zero cost (kinematic playback). Looks alive, no drift; repeated loops are noticeable; handoff from playback to live needs state restoration at an arbitrary frame (snapshot keyframes).
- **T5 Statistical result**: sample final outcome (score, winner) from a model fitted to T0 runs, seeded from persisted state; advance coarse state machine (period, intermission). Cost tiny; fidelity only at outcome level; must be seeded to avoid leave-and-return rerolls.
- **T6 Not simulated**: only for packs with nothing observable (placeholder), contradicts owner ruling if used on a live game.
- Transition tests: T2->T0 materialisation pop, T4->T0 handoff mismatch, T5->T0 constructing a plausible position set, catch-up replay at 4x-16x with a cap, and hysteresis to prevent tier flapping.

### Gaps
- Jolt sleeping thresholds, determinism guarantees (cross-platform floating point, island order, `cDeterministic` build options), and multi-step collision stepping behaviour: not verified here; read the Jolt docs (jrouwe.github.io/JoltPhysics) and the Godot Jolt extension notes before the spike.

## Q5. Determinism interactions

### Takeaway
Any tier that changes what is computed per tick (rate, abstraction, sampling, catch-up length) must have its tier schedule recorded as part of the input stream, or replay diverges. Frozen and exact-replay tiers preserve determinism without extra input.

### Cited Findings
- No source in this session addresses determinism of LOD. Factorio is a lockstep deterministic simulation in which sleeping is designed to not change results (sleeping only when nothing would change), consistent with the FFF-421 wording on stored intent and bounded wake intervals. — [Friday Facts #421](https://www.factorio.com/blog/post/fff-421) (the lockstep claim itself is RECALL, not on that page)

### Inferences
- Preserve determinism without recording: T3 frozen (as long as freeze/resume happen at recorded ticks), T4 pure input replay, exact-sleep tiers where wake rules depend only on sim state.
- Need schedule in the recorded input: T1 (which ticks use which dt), T2/T5 (abstraction switches, RNG seed and draw count), catch-up (number of replayed ticks), and any tier choice driven by camera or player position (significance is non-sim input). Simplest rule: tier changes are events applied at tick boundaries and logged; state hash covers per-pack tier id.
- Per-pack hash domains: hash each pack separately and include tier id, so a dormant pack's hash stays stable while it is dormant.

### Gaps
- No sourced example of a shipped deterministic game with tiered simulation besides Factorio's exact sleeping.

## Q6. What developers say went wrong

### Takeaway
Only a few sourced regrets: A-Life was cut back and remained buggy, big switch distances cause stutters, higher Bethesda grids cause spawn problems and save incompatibility, and multithreading a memory-bound system did not pay in Factorio.

### Cited Findings
- A-Life features (factions, defending encampments, fireside sitting) were cut and the series stayed buggy. — [Game Developer](https://gamedeveloper.com/design/a-life-an-insight-into-ambitious-ai)
- Large A-Life switch distance reported to cause stutters (user report). — [ModDB](https://www.moddb.com/addons/performance-alife-settings) (low confidence)
- Higher uGridsToLoad causes AI spawning problems and incompatible saves. — [STEP forum](https://stepmodifications.org/forum/topic/825-ai-spawning-problems-with-higher-ugrids/), [Nexus](https://forums.nexusmods.com/topic/653469-what-are-ugrids-and-how-do-you-tweak-them) (forum, low confidence)
- Factorio electric network multithreading: CPU 0.5% to 15%, no speedup, memory bound; a rare published "tried and dropped". — [Friday Facts #421](https://www.factorio.com/blog/post/fff-421)
- Minecraft: spawn chunks removed in 1.21.9 after being shrunk to radius 2 in 1.20.5, i.e. always-loaded regions were a standing cost and were eventually replaced by on-demand loading. — [Minecraft Wiki](https://minecraft.wiki/w/Chunk)
- DF: sites founded by other civs in fortress mode may get incorrect ownership fields (state not designed for abstract world activity). — [DF wiki](https://dwarffortresswiki.org/index.php/World_activities)

### Inferences
- Common lesson: the abstract tier is the bug farm, because it needs its own rules and its own state that must reconcile with the full tier; keep the abstract model as small as possible and derive it from the full model.

### Gaps
- No GDC post-mortems fetched (Horizon, Watch Dogs, Just Cause, NMS, Kenshi). Dev quotes on regrets are scarce here.

## Summary catalogue of tiers for the spike (in order of cost)
1. T0 full 60 Hz.
2. T1 reduced step rate (1/2, 1/4) with larger dt.
3. T2 physics asleep, abstract rules ticking.
4. T4a attract loop as kinematic playback of recorded transforms; T4b input replay at T0 cost.
5. T5 sampled outcome, seeded from persisted state.
6. T3 frozen snapshot (comparison baseline only).
Edge mechanics to test: one-tier "frame ring" neighbours (Minecraft), bounded max sleep interval (Factorio 20/60 ticks), idle timeout (Minecraft 300 ticks), hysteresis, per-frame catch-up budget, tier schedule logged as input, per-pack state hash including tier id.

Overall confidence: Minecraft chunk facts and FFF-421 numbers verified from fetched pages; EVE TiDi verified; A-Life verified at article level; everything on Bethesda, DF, AC Unity, Unreal URO is secondary; everything on RimWorld, Kenshi, NMS, Stardew, Jolt and catch-up failure modes is unsourced and listed as gaps.
