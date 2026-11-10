# Layered clocks keep every game alive

Large persistent worlds stay "alive" by separating three things that a naive design ties together: what is retained, what is simulated, and what is drawn. Minecraft runs a view distance and a simulation distance as separate settings, Star Citizen streams containers out while their state persists, and S.T.A.L.K.E.R. advances far-away characters on a hidden graph. None of these worlds ticks everything at full rate, and none of the sources read publishes a tier table that can be copied. For Third Life the decisive findings are about Godot. Its Jolt module gives **one fully separate physics system per space** and can drop any space from the step loop with `space_set_active(false)`, but it offers **no per-space step, no per-space rate and no state snapshot**, and it documents **no determinism guarantee**. That combination points to one design: each pack owns its own space at a pack-local origin and its own tick counter. The pack is always stepped at exactly 1/60 s, and its cost is controlled by how many world ticks it is given, never by a different timestep. A far pack then runs slow instead of running wrong or switching off, and its state hash stays comparable with its bot-verified run. This pack-local clock is this report's own synthesis and rests on untested assumptions about toggling a space, so the spike at the end of this report must prove it before anything is built on it. Most numbers the design needs (body budgets, memory per space, activation times) do not exist in any source and must be measured.

## Living worlds split "kept", "simulated" and "drawn" into separate radii

### Interest is a partition plus a filter, and cost is capped by an indivisible unit

Every system examined answers "who needs to compute or know about what" with a spatial partition and a per-observer relevance filter. A 2006 comparison of eight interest-management algorithms on real player data found that obstacle-aware methods cut update messages by up to a factor of six, yet cheap tile-based methods came close to ideal visibility at very low cost ([Boulanger et al.](https://www.sable.mcgill.ca/~clump/papers/boulanger-06-comparing.pdf)). A landscape of discrete venues has little occlusion to exploit, so plain radius or tile interest is the right starting point; that judgement is the researchers' reasoning, not a finding of the paper.

Production systems bound cost by fixing a unit that cannot be split. In EVE Online a node is one single-threaded server process, a solar system cannot be divided across nodes, and a busy system is given a node of its own instead of sharing with dozens of others ([CCP](https://www.eveonline.com/news/view/fixing-lag-character-nodes)). In Star Citizen exactly one server node holds authority over an entity while others hold views of it, and servers unload object containers that have no players nearby ([CIG Q&A, fan-hosted copy](https://api.star-citizen.wiki/comm-links/18397)). Unreal's Replication Graph groups actors into grid cells or predefined zones, keeps "always relevant" lists, and holds pre-placed actors dormant until something changes them; Fortnite Battle Royale starts a match with **100 connections and about 50,000 replicated actors** ([Epic](https://dev.epicgames.com/documentation/en-us/unreal-engine/replication-graph-in-unreal-engine)). The single-process analogue for Third Life is clear: **the pack's venue is the atom of simulation cost**.

The most reusable pattern is the split between what is shown and what is simulated. Minecraft hosts configure view distance (chunks sent to the client) and simulation distance (chunks actually ticked) independently ([Shockbyte](https://shockbyte.com/help/knowledgebase/articles/changing-view-and-simulation-distances-on-a-minecraft-server)). The owner's ruling fits this split once "alive" is defined as "state is retained and keeps evolving", not "ticks at full rate".

Scoring and acting are also separate jobs. Unreal's Significance Manager ranks registered objects against viewer transforms and invokes callbacks, and its documentation says outright that it does not improve performance by itself and publishes no thresholds ([Epic](https://dev.epicgames.com/documentation/en-us/unreal-engine/significance-manager-in-unreal-engine)). Minecraft supplies the acting half: "tickets" pin a region awake at a given level for a fixed time (player, portal, `/forceload`), and levels fall off by one per chunk from each ticket ([Minecraft Wiki](https://minecraft.wiki/w/Chunk)). A ticket is the right primitive for "keep this pack up although the player left", for example a match the player has bet on.

### Shipped simulation tiers form a ladder, and only one rung is exact

Minecraft documents its ladder most precisely. Entity-ticking chunks cover a square of side min(2s+1, 63) for simulation distance s. Block entities and scheduled ticks cover **one extra ring**, min(2s+3, 65). Border chunks run nothing but stay readable, and unloaded chunks process nothing at all. A dimension with no player stops entity ticking after **300 ticks**. Fluids and fire stop at the edge of an inactive chunk, a documented seam at a dormancy boundary. Always-loaded spawn chunks were cut from radius 10 to 2 in 1.20.5 and removed in 1.21.9 in favour of loading on demand ([Minecraft Wiki](https://minecraft.wiki/w/Chunk)). The wiki is a community source that tracks Mojang's changelogs; the changelogs themselves were not read.

Factorio shows the only tier that loses nothing. Entities go inactive when nothing about them would change, and wake by rule. In Friday Facts #421, idle roboports dropped from 1 ms to 0.025 ms per tick in a test save. Worker robots store a movement intention and skip updates for **at most 20 ticks moving or 60 ticks stationary**, while rendering predicts the motion in between ([Factorio](https://www.factorio.com/blog/post/fff-421)). The same post records a cautionary result: multithreading the electric network raised CPU use from 0.5% to 15% without making the save faster, because the work was bound by memory throughput.

S.T.A.L.K.E.R.'s A-Life is the abstract rung. Characters within a radius of the player are "online"; the rest are advanced by game time on a detailed graph the player never sees. The article calls the between-zones simulation "to some degree" an illusion and reports that factions and defended encampments were cut ([Game Developer](https://gamedeveloper.com/design/a-life-an-insight-into-ambitious-ai)). Dwarf Fortress keeps world history moving during play, and its wiki notes that sites founded off-screen can end up with ownership fields set incorrectly ([DF Wiki](https://dwarffortresswiki.org/index.php/World_activities)). The researchers draw one lesson from these two cases: **the abstract tier is the bug farm**, because it needs its own rules and its own state that must reconcile with the full simulation. That is their inference from two examples, not a published post-mortem.

EVE's time dilation is the last rung, and the one most relevant here. An overloaded node slows its own game clock so that the task queue stays near empty, and clock-tied load falls in proportion ([CCP](https://www.eveonline.com/news/view/introducing-time-dilation-tidi)). The community wiki gives the floor as **10% of normal speed** ([EVE University](https://wiki.eveuniversity.org/Time_Dilation)); the CCP proposal that was read says a minimum is needed but does not set one, so the 10% figure rests on the community source alone. Dilation applies per node, which makes it a per-region slow clock.

### Catch-up is the least documented part of the craft

The session found only two documented behaviours for returning to a dormant region. Minecraft does no catch-up: the world is as it was left, and edge effects resume when the neighbour loads ([Minecraft Wiki](https://minecraft.wiki/w/Chunk)). A-Life advances an abstract model and then materialises characters when the player crosses the switch distance ([Game Developer](https://gamedeveloper.com/design/a-life-an-insight-into-ambitious-ai)). The usual families (closed-form from elapsed time, replay at higher speed, seeded sampling of an outcome, snapshot and resume) and their failure modes (leave-and-return exploits, visible pops at materialisation, long hitches when many systems catch up in one frame) are the researchers' taxonomy from background knowledge. No shipped numbers were found for any of them. A design that avoids catch-up altogether therefore carries less unverified risk than one that depends on it.

## Godot's physics gives per-pack isolation but one global timestep

### One space per pack is the supported partition

In Godot's Jolt module `space_create()` builds a separate `JoltSpace3D`, which owns its own Jolt `PhysicsSystem` with its own broadphase, bodies and contact cache ([jolt_physics_server_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_physics_server_3d.cpp)). The server keeps a set of active spaces. `space_set_active(space, false)` erases a space from that set, and each physics tick loops over the active set, stepping **each space serially with the same delta**. Each space calls `Update(p_step, 1, ...)`: one collision step, no sub-stepping, delta unchanged ([jolt_space_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/spaces/jolt_space_3d.cpp)). These quotes come from Godot's `master` branch in November 2026, not from a 4.7 tag.

Jolt's author recommends this shape for a large sparse world: one `PhysicsSystem` per cell, because a system has a single broadphase and its layers are fixed at initialisation. The price is that a body crossing cells must be destroyed and recreated ([Jolt discussion #999](https://github.com/jrouwe/JoltPhysics/discussions/999)). Independent packs pay that price only when the player or a shared object enters a venue.

Capacity limits are per space. Each space initialises with the project-wide limits, whose defaults on `master` are **10,240 bodies, 65,536 body pairs and 20,480 contact constraints** ([jolt_project_settings.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_project_settings.cpp)). Thirty packs of 600 bodies in one shared space would need 18,000 bodies and exceed the default. Overflow is quiet: a failed body creation prints an error once and returns null, and full pair or contact caches print one warning and **drop contacts** ([jolt_space_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/spaces/jolt_space_3d.cpp)). A dropped contact changes the simulation, so the hash tests must treat that warning as a failure. No source gives the memory cost of a space; lowering `max_bodies` to about 1,024 is the researchers' untested suggestion for a many-space design, and the setting also governs the default space.

### Sleeping is cheap, but it is not pausing

Jolt groups dynamic bodies into islands and puts an island to sleep when every member is at rest. Godot's defaults are **0.5 s below 0.03 m/s**. Collision detection runs the broadphase only for active bodies, sleeping bodies still sit in the broadphase tree, and they wake on contact with an awake body ([Jolt docs](https://jrouwe.github.io/JoltPhysics/), [jolt_project_settings.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_project_settings.cpp)). Sleeping is Factorio's exact rung in physics form: a venue between rounds costs little even while its space is stepped. It does not help a venue in play. The researchers flag pre-fractured walls as the main risk, many small bodies that wake together, without a measurement. No source gives a bodies-at-60-Hz benchmark, and Jolt's performance test page returned a 404.

### Reduced-rate physics is not available, and manual stepping is not safe

Godot has no public per-space step. The `PhysicsServer3D` method table lists `space_create`, `space_set_active`, `body_set_space` and `get_process_info`, and no step method ([Godot docs](https://docs.godotengine.org/en/stable/classes/class_physicsserver3d.html)). The pull request that would add `space_step()` is open and unmerged; its author stopped maintaining it, and commenters in the thread report that it ignored space deactivation and was non-deterministic with Jolt ([PR #76462](https://github.com/godotengine/godot/pull/76462)). Unity, by contrast, steps each physics scene explicitly with `PhysicsScene.Simulate(step)` ([Unity](https://docs.unity.com/en-us/engine/current/script-reference/unityengine/physicsscene/simulate)).

This rules out a tier the simulation research proposed: stepping a pack at 30 or 15 Hz with a larger delta. Godot would pass the global 1/60 s regardless. A space that is active on every second tick is therefore not a 30 Hz simulation; it is a 60 Hz simulation running at half speed. Read correctly, that limitation is the opening the recommended model uses.

### Determinism holds only under conditions Godot does not promise to meet

Jolt is deterministic when calls that modify the simulation occur in the same order and the same binary runs it. Cross-platform determinism needs the `CROSS_PLATFORM_DETERMINISTIC` build option at about **8% cost**, plus precise floating-point flags ([Jolt docs](https://jrouwe.github.io/JoltPhysics/#deterministic-simulation)). The same page lists what is not deterministic: broadphase query results, narrow-phase result order, the order of all listener callbacks, and `GetActiveBodies` order. Godot's page on its built-in Jolt module says nothing about determinism ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html)). The earlier extension was blunt: "Jolt itself is deterministic, but Godot Jolt makes no such guarantee" ([godot-jolt](https://github.com/godot-jolt/godot-jolt/blob/master/README.md)). Whether Godot's own build sets the cross-platform flag was not checked. Same-machine, same-binary replay is the reliable tier in any case ([Gaffer On Games](https://gafferongames.com/post/floating_point_determinism/)).

Three questions decide the layering, and none has a sourced answer.

The first is world offset. Jolt's single-precision build is "accurate within roughly 5 km of the origin", and double precision needs a custom Godot build, which the project's no-fork rule excludes ([Jolt docs](https://jrouwe.github.io/JoltPhysics/), [Godot docs](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html)). The researchers computed float spacing from IEEE-754: about 0.12 mm at 2 km, 0.24 mm at 3 to 4 km, and close to 1 mm at 10 km, which is the project's hash quantum. Their conclusion is that a pack simulated at (2000, 0, 3000) will not be bit-identical to the same pack at the origin, and that chaotic scenes will diverge visibly. That is arithmetic reasoning; no source tested it.

The second is neighbours. Extra bodies in a space change the broadphase tree, body order, island construction and solver ordering. The researchers found no statement that disjoint islands solve bit-identically regardless of what else shares the space.

The third is pause and resume. Jolt can save and restore a whole system, contact cache included, through `StateRecorder`, but no such API was found in Godot's module ([Jolt docs](https://jrouwe.github.io/JoltPhysics/), [jolt_space_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/spaces/jolt_space_3d.cpp)). Restoring transforms and velocities through Godot's API loses warm-start impulses and sleep timers, so the resumed run departs from an uninterrupted one. Deactivating a space leaves all of that state inside Jolt, which makes it the best candidate for an exact pause. Whether deactivation has hidden effects on pending bodies, queries or signals is unverified.

One space per pack, with bodies at a pack-local origin, answers the first two questions by construction and gives the third its best chance. It also makes world offset a non-event for packs: an origin shift or a relocation moves the visual root and never touches a pack's physics coordinates.

Event order is the remaining trap. Contact, activation and area callbacks arrive in unspecified order ([Jolt docs](https://jrouwe.github.io/JoltPhysics/#deterministic-simulation)), so a rules script that consumes them in arrival order can diverge even when the physics is bit-exact. Collect each tick's events and sort them by stable body id before the rules see them. No primary source covered determinism of ray-cast vehicles, `move_and_slide` or `Area3D` under Jolt.

## Godot streams by hand: visibility ranges exist, a streamer does not

### Reference engines share one template and publish few numbers

Unreal's World Partition is the reference design: a grid of cells, streaming sources that drive loading, proxy stand-ins for unloaded cells, and asynchronous loads. Its documentation example uses **256 m cells and a 768 m loading range**, and states no defaults. Each streaming source carries a priority and a target state of Loaded or Activated, and where sources overlap the highest priority and highest state win ([Epic](https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition-in-unreal-engine)). The proxies (instanced, merged or simplified meshes) are built offline, and each proxy layer has its own cell size and loading range ([Epic](https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition---hierarchical-level-of-detail-in-unreal-engine)). A Unity streaming sample loads coarse cells at higher priority than detailed ones ([Meta](https://developers.meta.com/vr/documentation/unity/unity-sample-asset-streaming)). Two ideas transfer directly: a two-stage "loaded, then activated" lifecycle, and coarse-first ordering. No source gave a per-frame streaming budget in milliseconds or nodes, and no hysteresis figures were found in the Unreal pages read.

### What Godot 4.7 provides

Visibility ranges are the core tool. Each `GeometryInstance3D` has begin and end distances measured to its AABB centre, with margins that act as **hysteresis** when fade mode is Disabled, the cheapest mode. A visibility parent turns this into hierarchical LOD: children hide when the parent proxy is shown, which cuts distant draw calls while keeping per-object culling up close. The fade modes force transparent rendering during the fade ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html)).

Automatic mesh LOD is generated **on import** with meshoptimizer and selected by screen-space size, with a default threshold of 1 pixel that can be raised per viewport. For MultiMesh, all instances in a node share one LOD level and are culled together, so the docs advise splitting instances by area ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html), [Godot docs](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)). The page documents import only. Whether `ImporterMesh.generate_lods` works on meshes generated at run time is documented neither way. Pack generators that build meshes in code should therefore author their own low-detail variants and the venue proxy.

Loading is asynchronous through `ResourceLoader.load_threaded_request`, and the docs allow building scene chunks on a thread outside the active tree, then attaching them on the main thread ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html), [Godot docs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)). Attaching is where the hitch risk sits. The only evidence is from forums: one user measured a spike above 500 ms when spawning 1,000 batches at once against about 23 ms when spread over time, and others report that `add_child()` still stutters after threaded instantiation ([Godot forum](https://forum.godotengine.org/t/best-practices-for-spawning-large-number-of-objects/102004), [Godot forum](https://forum.godotengine.org/t/threaded-instantiation/139671)). Treat those figures as leads to measure.

Godot 4.4 added ubershaders and pipeline precompilation, which the docs call imperfect ([Godot docs](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html)). A forum report puts first use of a preloaded shader material at about 430 ms on Forward+ D3D12 ([Godot forum](https://forum.godotengine.org/t/stuttering-when-material-is-first-used-despite-preload/139752)). The inked style's shared palette material limits this exposure, but the outline pass and the shadow and depth pipelines compile separately; warming them at startup is the researchers' suggestion.

Occlusion culling exists but will matter little here. It rasterises occluders on the CPU, moving an occluder forces a rebuild, and Forward+ already has a depth prepass that shrinks the gain ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html)).

World size has a documented ceiling. Official builds are single precision, and the docs recommend maximum extents of about **4,096 units for third-person and 2,048 for first-person** play, with origin shifting named as the alternative but not specified ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html)). With pack-local physics, that ceiling constrains rendering and the open-world space that holds the terrain and the walking player. It does not constrain pack simulation.

### What Godot lacks

No built-in streaming manager, HLOD baker or impostor baker appears in the docs read. Community options are partial. Terrain3D provides clipmap terrain with up to 10 LOD levels; its 4.7 support was not confirmed, and the sources do not say whether regions load dynamically ([Terrain3D](https://terrain3d.readthedocs.io/en/latest/api/class_terrain3d.html)). Octahedral impostor addons exist with unverified maintenance and licence status ([Godot Asset Library](https://godotengine.org/asset-library/asset/5528)). Secondary coverage of Godot 4.7 found no change to streaming, LOD or visibility ranges ([DigitalProduction](https://digitalproduction.com/2026/06/23/godot-4-7-turns-up-hdr/)).

The project must write a thin streamer itself. The researchers sketch it as a grid of pack cells, a per-pack state machine, a queue ordered by distance, and an attach step sliced across frames; they judge GDScript sufficient, without a measurement. For the simple inked style, the natural distant stand-in is a merged low-detail mesh emitted by the pack's own generator and assigned as visibility parent. One style-specific risk has no source: a depth and normal edge detector keeps line width in screen pixels while geometry shrinks, so distant venues are likely to shimmer with thin lines. Fading outline strength with distance is a spike item.

## A pack's plot is a rule scope, and crossing it is a recorded handover

### MMOs scope by copies, by observer, or by region; only the third fits now

Layering in MMOs takes three forms. Capacity copies duplicate a space: Guild Wars 2's megaserver scores map copies by party, guild, language and friends and adds copies on demand, which raised average population per copy by 225% in its prototype ([ArenaNet](https://www.guildwars2.com/en/news/introducing-the-megaserver-system/)). Per-observer variants show different players different states of one space, as in WoW's phasing; the mechanics there come from community summaries only ([Wowhead](https://www.wowhead.com/news=294589/blizzard-clears-up-layering-tech-misconceptions-in-classic-wow)). Region-owned authority assigns each region to one authority and hands entities over at the border, as in SpatialOS workers and Star Citizen's server mesh ([SpatialOS patent](https://patents.google.com/patent/US10579434), [CIG Q&A](https://api.star-citizen.wiki/comm-links/18397)).

No primary source was found on scoping mini-game rules to a region (battlegrounds, creator islands). What follows is the researchers' design reasoning, extended by this report. Region-owned authority fits "a pack owns a plot": rules attach to the plot, an entity is governed by the plot's rules only while inside, and crossing is an explicit event. Copies and phasing are misfits today, because the owner requires one continuous landscape and per-observer state complicates determinism. Both become useful later.

### Physics spaces make the handover concrete

With one space per pack, the rule scope and the physics scope coincide. The open-world space holds the terrain and the walking player. Each pack space holds the venue's own colliders, including its own ground. Entering a venue moves the player's body into the pack's space, converted to pack-local coordinates, at a tick boundary, and the pack's input record logs the entry. In Jolt's terms that is a different body ([Jolt discussion #999](https://github.com/jrouwe/JoltPhysics/discussions/999)).

A body that straddles two plots must be impossible by construction. Plots need buffer margins, and each pack needs its own policy for objects that leave its bounds, because nothing outside the venue exists in its space. Roblox handles the equivalent problem by streaming assemblies in as whole units and keeping them until every part is eligible to leave ([Roblox](https://create.roblox.com/docs/workspace/streaming)).

One implementation question is open. Keeping bodies at a pack-local origin while drawing the venue at its world position requires a bridge between physics and visual transforms, and the notes verified neither a mechanism for it nor how a separate `World3D` behaves with Jolt.

## Multiplayer stays open if the host is the single-player simulation

Lockstep is the wrong plan for a shared world. It sends only inputs, so bandwidth is independent of object count, but every peer waits on the slowest, and Gaffer recommends it for **two to four players** ([Gaffer On Games](https://gafferongames.com/post/deterministic_lockstep/), [Gaffer On Games](https://gafferongames.com/post/snapshot_interpolation/)). Production worlds at scale are server-authoritative with interest management ([Epic](https://dev.epicgames.com/documentation/en-us/unreal-engine/replication-graph-in-unreal-engine)). The researchers recommend a hybrid: one authoritative host runs the same deterministic simulation as single-player, clients send inputs and receive state, and prediction or rollback applies only inside an active mini-game if at all. Under that plan the single-player build already is the server. Full rollback is out of reach on stock Godot, because it needs fast save and restore of physics state, and Godot does not expose Jolt's.

The deterministic 60 Hz tick with a per-tick input record already pays for itself: replay, regression tests, desync detection by periodic hashing, and saves stored as a snapshot plus an input log. The decisions that are expensive to reverse are habits to fix now, on the researchers' judgement backed by the Jolt and Gaffer material:

- all input reaches scripts through one per-tick record keyed by player id, never by polling;
- no game state in global singletons, so a pack can later be instantiated twice;
- randomness comes from a seeded per-pack generator stored in pack state;
- all state changes happen inside the fixed step;
- body creation order is stable, and physics events are sorted before use;
- entities carry stable ids, and pack state is fully serialisable;
- every pack and entity has an authority field, even though its value is always "local" today.

The tier model generalises to several observers without redesign: a pack takes the highest tier any observer demands, which is Unreal's rule for overlapping streaming sources ([Epic](https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition-in-unreal-engine)). Tier changes must be logged events applied at tick boundaries, because they derive from player position, which is input and not simulation state. Capacity copies map onto "instantiate this pack for this group with its own seed and input stream", which per-pack spaces already permit.

## Conclusion

The research changes the central question. It began as "which simulation tier is cheap enough for a far pack" and ends as "how much of the world clock does each pack receive". Godot's missing per-space timestep looks like a limitation, yet it forces the one reduced tier that changes no results: a pack stepped on fewer world ticks at an unchanged delta runs the same trajectory, later. The abstract simulation that the reference games needed, and visibly struggled with, shrinks to a small ledger for packs that are not in memory at all.

The whole model rests on three things nobody has measured: that toggling a space on and off is free of side effects, that a pack costs little enough for several to run at once, and that Godot's Jolt build replays identically on one machine. The spike below settles all three in days. If the first fails, the fallback is a pack that stays active with its bodies asleep and its rules gated by the kernel. If the third fails, the hash contract itself needs rethinking before layering matters.

## Recommended layering model: four tiers on pack-local clocks

Every pack owns one Jolt space with bodies at a pack-local origin, one tick counter, one seeded random generator and one input record. The kernel, not `_physics_process`, calls a pack's rules, and only on ticks when the pack's space is stepped. A pack is always stepped with a delta of 1/60 s. Tiers differ only in how many world ticks a pack receives and in what is built and drawn.

| Tier | When | Rules and AI | Physics | Physics space | Drawn |
|---|---|---|---|---|---|
| **Stage** | The player is inside the plot, or a ticket pins the pack | Every world tick (60 Hz), player input from the tick record | Every world tick at 1/60 s | Own space, active every tick | Full-detail meshes, full outline pass, shadows |
| **Sideline** | Within the range where individual motion is legible, or adjacent to the Stage pack | Every world tick, bot or recorded input | Every world tick at 1/60 s | Own space, active every tick | Detail meshes with LOD variants through visibility ranges; outline strength reduced with distance |
| **Backdrop** | Beyond legibility, inside draw range | Only on the pack's slice: one pack tick per N world ticks, round-robin under a fixed millisecond budget | Same slice, still 1/60 s per step, so the pack runs at 1/N of world speed | Own space, kept in memory, active only on slice ticks | Merged proxy mesh as visibility parent, plus a few cheap markers (scoreboard, lights) refreshed when the pack steps |
| **Ledger** | Outside draw range, never visited, or evicted for memory | No scripts run; a small pack-declared summary (phase, clock, score) advances in closed form from elapsed ticks, seeded from persisted state | None | No space; bodies are not built | Nothing, or a silhouette baked into the landscape's own distant layer |

Supporting rules:

- **Frame ring.** Packs adjacent to the Stage pack run at Sideline regardless of distance, following Minecraft's extra ring.
- **Hysteresis.** Each tier boundary has a margin, and a pack must dwell for a minimum time before it is demoted.
- **Tickets.** A script or the player can pin a pack at a tier for a fixed time. Nothing is pinned permanently; Minecraft removed its always-loaded spawn chunks.
- **Keyframes.** Promotion from Ledger rebuilds the pack from its persisted state and starts a new hash keyframe. It is never claimed to equal an uninterrupted run.
- **Budget valve.** If Stage plus Sideline exceed the physics budget, the scheduler first demotes the farthest Sideline pack to Backdrop, then slows the whole world's tick pace in the manner of EVE's time dilation. It never switches a pack off.
- **Logging.** The world log records every tier change and slice assignment as a tick-boundary event. A pack's own hash depends only on its local tick count and its inputs, so each pack remains comparable with its bot-verified run.

Two consequences need the owner's decision. Walking away from a game slows it to near-pause, so each pack needs a rule for an absent player (forfeit, bot substitute or wait). And pack time drifts from world time, so a pack that needs the world clock must receive it as an input.

## Thresholds the spike should measure

No source supplies pass values. The "pass line" column is this report's proposal, anchored to figures already in the project brief: a 2 ms physics budget, a 1 mm-quantised hash, and a render baseline of about 1.8 ms GPU at 1440p for 480k triangles and 260 draw calls.

| # | Test | Variables | Proposed pass line |
|---|---|---|---|
| 1 | Active-body budget in one space | 50, 150, 300, 600 active bodies (fractured wall, vehicles, characters); one versus several worker threads | Step time recorded per count; a 600-body pack in play fits inside 2 ms with room for at least one Sideline pack |
| 2 | Sleeping cost | 10, 30, 60 packs fully asleep, each in its own active space | Cost per asleep pack per tick small enough that 60 sum to under 0.2 ms |
| 3 | Space overhead | 10, 30, 60 spaces: empty and active, inactive, populated; `max_bodies` at 10,240 versus about 1,024 | Memory per space (OS working set) and per-tick cost of an inactive space recorded; inactive cost indistinguishable from zero |
| 4 | Hash stability against neighbours | Pack A alone; A with B in the same space, added before and after; A with B in another space; 3,600 ticks, 20 runs each, job thread count varied | 20 of 20 identical per-tick hashes with B in another space; the same-space result recorded |
| 5 | Offset stability | Same pack simulated at (0,0,0), (1000,0,0), (2000,0,3000), (4000,0,4000), (10000,0,0); control moves only the visual root | The control is identical at every offset; first-divergence tick and size recorded for the others |
| 6 | Pause and resume | K ticks, deactivate for M ticks, K ticks, against 2K uninterrupted; M of 1, 60, 3,600; paused asleep and awake; variant restoring transforms and velocities | Deactivate and reactivate is identical in 20 of 20 runs; the restore variant's divergence recorded |
| 7 | Slice toggling | A space active on 1 tick in N, for N of 2, 8, 30, against the same pack run continuously for the same local tick count; area signals, queries and pending body adds exercised | Identical hashes; no missed or duplicated signals |
| 8 | Script gating | Pack subtree with processing disabled between slices | No pack script runs on a world tick when its space is not stepped |
| 9 | Overflow guard | Capture engine output during every test | Zero "contacts ignored" warnings and zero body-creation errors |
| 10 | Activation time | Ledger to Backdrop and Backdrop to Sideline for a 600-body pack, cold and warm; nodes attached per frame of 10, 50, 200; body create and free cost | No frame above 16.7 ms during activation; total time to playable recorded |
| 11 | First-use pipeline stutter | Palette material, outline pass, shadow and depth pipelines on D3D12 with and without startup warming | No compile hitch above one frame after warming |
| 12 | Memory per pack | Per tier: proxy only, built and inactive, built and active | Megabytes per pack per tier recorded; sets how many Backdrop packs stay resident |
| 13 | Proxy and visibility ranges | Switch cost for 1,000 versus 10,000 instances with fade disabled; draw calls and GPU time with 30 and 60 proxies in view | Stays within the render baseline; no visible flapping at the margin |
| 14 | Tier distances | Sideline radius of 100, 150, 250 m; Backdrop out to 500, 768, 1,500 m; margin of 10% and 20%; dwell of 120 ticks | Slow motion at the Sideline edge is not noticeable to a viewer; no tier flapping on a walk along a boundary |
| 15 | Outline at distance | Edge-detect pass on detail mesh versus proxy at 200, 500, 1,000 m | No shimmer with the distance fade applied |
| 16 | Run-time LOD | `ImporterMesh.generate_lods` on a generated mesh in an exported build | Works or does not; decides whether generators must author LODs |
| 17 | Ledger promotion | Rebuild from persisted state at an arbitrary point; summary seeded from state, not from return time | Rebuilt state is plausible and identical on repeat; no reroll by leaving and returning |
| 18 | Replay across builds | Same input log in the editor and in a release export, same machine | Identical hashes, or a documented rule that only export builds are authoritative |

## Techniques rejected and why

| Technique | Why it is rejected |
|---|---|
| Switching distant games off, or freezing them as the normal far tier | The owner's ruling. Minecraft's unloaded chunks process nothing, which is exactly the behaviour excluded. A frozen snapshot is kept only as a test baseline. |
| One shared physics space for all packs | Thirty packs of 600 bodies exceed the default 10,240-body limit; one pack cannot be paused alone; neighbours and absolute position are unproven threats to hash stability. |
| Reduced-rate physics with a larger delta (30 or 15 Hz) | Godot passes one global delta and has no per-space step. A larger delta also breaks comparison with the 60 Hz verified hash and raises tunnelling risk for thin fractured pieces. |
| Manual stepping through the `space_step()` pull request or an engine fork | Unmerged, unmaintained, reported non-deterministic with Jolt in its own thread, and excluded by the no-fork rule. |
| Double-precision build | Needs a custom engine build and rebuilt extensions. Pack-local origins remove the need for packs. |
| Physics snapshot and restore as a tier mechanism, and rollback netcode | Godot does not expose Jolt's state recorder. Restoring transforms and velocities loses warm-start impulses and sleep timers. |
| A rich abstract simulation or sampled outcomes for packs in memory | The abstract tier is where A-Life and Dwarf Fortress show their bugs, and materialising bodies from abstract state produces pops. It is confined to the Ledger and kept minimal. |
| Kinematic "attract loop" playback as the standard far tier | Loops are noticeable, and handing off from playback to live needs state restoration at an arbitrary frame. It remains an option for proxy markers only. |
| Catch-up by fast replay on return | Cost grows with time away and causes hitches. Pack-local clocks make catch-up unnecessary for packs in memory. |
| Always-loaded regions | Minecraft shrank and then removed its spawn chunks. Time-limited tickets do the same job. |
| Obstacle-aware interest management | It pays only where occlusion is strong; a landscape of discrete venues has little. |
| Multi-machine partitioning (EVE nodes, server meshing, SpatialOS workers) | These solve scaling across machines, which single-player does not have. Only the "one authority per region" shape is kept. |
| Capacity copies and phasing as cost tools now | They break the one continuous landscape, and per-observer state complicates determinism. Both are reserved for multiplayer. |
| Lockstep for the shared world | Gaffer limits it to two to four players, and it needs bit-identical binaries on every peer. |
| Live SubViewport impostors and octahedral impostor addons | A live impostor is an extra scene render per pack with no source for its cost. The addons have unverified maintenance, licence and 4.7 support. A merged proxy mesh suits the simple style. |
| Physics on a separate thread | The Godot docs call the option untested and experimental. |
| Visibility-range fade modes (Self, Dependencies) | They force transparent rendering during the fade. Disabled mode with margins is the cheapest and gives hysteresis. |

## Claims that are unverified or rest on reasoning

Unverified against any source:

- Whether `space_set_active(false)` followed by `true` has hidden effects on pending bodies, queries, area signals or the contact cache. Only its effect on the stepped set was read.
- Whether Godot's bundled Jolt is built with `CROSS_PLATFORM_DETERMINISTIC` and precise floating-point flags, and whether Godot's own ordering (body iteration, `_physics_process` order, signals) is stable between runs.
- Whether the quoted source and defaults on Godot's `master` branch match the 4.7 tag.
- Memory and time cost of a physics space, and any cap on the number of spaces.
- Any bodies-at-60-Hz figure. The 2 ms budget is a project target, not a measured capacity.
- Whether disabling a subtree's processing stops its physics callbacks (`PROCESS_MODE_DISABLED`). This comes from background knowledge only.
- Whether `ImporterMesh.generate_lods` works at run time, and whether meshes can be built safely on worker threads.
- How to hold bodies at a pack-local origin while drawing at a world offset, and how a separate `World3D` behaves with Jolt.
- Determinism and sleep behaviour of `VehicleBody3D`, `move_and_slide` and `Area3D` under Jolt.
- The defaults of `max_physics_steps_per_frame` and `physics_jitter_fix`, and the effect of `Engine.time_scale` on determinism.
- Terrain3D and impostor addon support for Godot 4.7, and the claim that 4.7 changed nothing in streaming or LOD (secondary coverage only; release notes not read).
- The 10% floor of EVE's time dilation rests on a community wiki. The CCP text read was the pre-ship proposal and sets no floor.
- Star Citizen's current server-mesh status; the source was a 2021 forward-looking Q&A on a fan-hosted mirror.
- WoW layering and phasing mechanics (community summaries only).
- The forum figures for `add_child` spikes (500 ms versus 23 ms) and first-use shader stutter (430 ms).
- The A-Life switch distance of about 150 m (mod-community reports).
- Minecraft chunk facts come from the community wiki; Mojang's changelogs were not read.
- Factorio being a lockstep-deterministic simulation whose sleeping never changes results; the cited post does not state it.

Resting on the researchers' reasoning:

- That a pack at a world offset is not bit-identical to the same pack at the origin, and the float-spacing figures behind it (IEEE-754 arithmetic, no test).
- That other bodies in the same space can perturb a pack's results.
- That deactivating a space is an exact pause, and that transform-and-velocity restore diverges.
- That one space per pack is the right partition; the Jolt author's advice was given for cells of one large world.
- That lowering `max_bodies` to about 1,024 saves meaningful memory.
- That physics, not rendering, dominates the cost of loaded packs, and that pre-fractured walls are the main risk.
- The taxonomy of catch-up strategies and their failure modes, and "the abstract tier is the bug farm".
- That radius interest suffices because venues have little occlusion.
- That region-owned rule scope fits packs, and that straddling bodies must be forbidden by construction.
- That a host-authoritative hybrid is the best multiplayer path, and the list of decisions that are expensive to reverse.
- That GDScript suffices for the streamer; that a merged proxy mesh is the best distant stand-in; that outlines shimmer at distance; that warming pipelines at startup removes stutter.
- That tier changes must be logged as input, and that per-pack hash domains keep dormant packs stable.

Resting on this report's own synthesis:

- The pack-local clock itself: that stepping a space on one world tick in N at an unchanged delta reproduces the continuous run tick for tick. It combines the physics notes' round-robin remark with EVE's per-node dilation, and no source describes it for Godot.
- The four-tier model, its names, the budget valve and the handover of the player's body between spaces.
- Every "proposed pass line" in the thresholds table, and the candidate tier distances, margins and dwell times.
- That far packs running slowly satisfy the owner's "every game stays alive" ruling. That is the owner's call to make.
