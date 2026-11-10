# World streaming, progressive loading and render LOD for a continuous Godot 4.7 sandbox (versus Unreal and Unity)

Scope note: about 20 tool calls. Godot pages were read from the 4.7 stable docs unless stated. Several requested topics were NOT researched in depth: Minecraft, No Man's Sky, Breath of the Wild, Unity impostors and ECS numbers, SubViewport live impostors, outline-pass behavior at distance, and Godot GitHub issue limits. They appear under Gaps. Items marked "(training knowledge, unverified)" were not confirmed from a source in this session.

## 1. How the reference engines do it (cells, ranges, hysteresis, budgets)

### Takeaway
Reference engines share one pattern: a spatial grid of cells, streaming sources that drive load/unload, proxy (HLOD) stand-ins for unloaded cells, and asynchronous loading. Published concrete numbers are sparse. Only a few examples were found: UE doc example cells and ranges, a Ghost of Tsushima tile size, and Horizon's data density.

### Cited Findings
- UE World Partition: the doc example uses 256 m runtime grid cells and a 768 m loading radius. The doc states no default for either. A streaming source with no custom shape uses a sphere whose radius equals the grid's loading range. — [Epic World Partition](https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition-in-unreal-engine)
- UE streaming sources: Player Controllers are sources by default. Extra sources are added with the World Partition Streaming Source component. Each source has a Priority and a Target State (Loaded or Activated). If a cell touches several sources, the highest priority and highest target state win. — same page
- UE Open World map type enables Data Layers, HLOD and One File Per Actor by default. One File Per Actor saves each actor to its own file, so edits do not need the shared level file checked out. The template landscape is 2 km x 2 km. — same page
- UE Level Instances: the `-OnlyMergeSubLevels` conversion merges sublevels into One File Per Actor. The result can be embedded as a Level Instance in a World Partition level. — same page
- UE HLOD layer types are Instancing (lowest LOD of each static mesh as instanced static meshes), Merged Mesh, and Simplified Mesh (merge plus simplification with a Screen Size in pixels). Each layer has its own Cell Size and Loading Range, unavailable for Always Loaded layers. The example config uses LoadingRange 30000 (centimetres, so 300 m, assuming UE units; not stated on the page). The page does not cover the Approximated Mesh type. — [Epic HLOD layers](https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition---hierarchical-level-of-detail-in-unreal-engine)
- UE HLODs are built offline in the editor or by the WorldPartitionHLODsBuilder commandlet. Unchanged source actors do not trigger a rebuild. `wp.Runtime.HLOD 0` shows the world without HLODs. — same two pages
- Horizon Zero Dawn (Decima): the world data is streamed in sections at about 4 MB/km2 of placement data. About 250 placed assets per frame come from GPU procedural placement. The game targeted 30 fps on PS4. This is per-frame placement, not a streaming time budget. — [GDC 2017 slides via Guerrilla search results](https://www.guerrilla-games.com/media/News/Files/GDC2017_VanMuijden_GPUBasedProceduralPlacementInHorizonZeroDawn.pdf); streaming talk exists: [Streaming the World of Horizon Zero Dawn](https://guerrilla-games.com/read/Streaming-the-World-of-Horizon-Zero-Dawn). I only saw its description, not its numbers.
- Ghost of Tsushima: one 200 m x 200 m terrain tile is typically about 2 MB compressed on disc, including terrain and foliage placements. It uses fine-grained streaming, and during most loads only newly required assets are loaded. — [GDC "Zen of Streaming"](https://gdcvault.com/play/1027205/contactUs), [Kotaku](https://kotaku.com/ghost-of-tsushima-devs-slowed-down-load-times-so-you-co-18444096). Only snippets were seen.
- Star Citizen OCS: streaming on the client is driven by the network layer binding and unbinding entities (network bind culling). Objects with no player nearby are "frozen". The server-side version (S-OCS) shipped at the end of 2019. Mostly fan-wiki and forum sources; CIG's Q&A is the primary one. — [CIG Q&A mirror](https://api.star-citizen.wiki/comm-links/18397), [SC wiki](https://starcitizen.tools/Object_Container_Streaming)
- Unity ECS: scenes load asynchronously as subscenes, split into sections, and HLOD from the Hybrid Renderer relied on section loading. — [Entities streaming overview](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/streaming-overview.html), [Entities 0.50 loading scenes](https://docs.unity3d.com/Packages/com.unity.entities@0.50/manual/loading_scenes.html)
- Unity Addressables pattern: a Meta sample loads grid cells as separate addressable scenes with `LoadSceneAsync(Additive, priority: lodLevel)`, loading coarser LODs first. A separate OpenUPM package, com.unity.hlod.addressable, offers HLOD streaming. — [Meta sample](https://developers.meta.com/vr/documentation/unity/unity-sample-asset-streaming), [OpenUPM](https://openupm.com/packages/com.unity.hlod.addressable/)

### Inferences
- A workable template for the sandbox is UE-like. Use a coarse proxy layer (loading range large, cell large) and a detailed layer (cell about 256 m, range about 3 cells). Use per-layer ranges, with the coarse layer always loaded or very wide. This is inferred from the UE doc example, not a published recommendation.
- Hysteresis is not specified numerically in the UE pages I fetched. Godot's own visibility-range margins are the only quantified hysteresis mechanism I found (section 2).

### Gaps
- Minecraft chunk meshing and render distance, No Man's Sky, Breath of the Wild, Unity HLOD/impostor details: not researched (call budget).
- Per-frame streaming time budgets (ms/frame, nodes/frame) from shipped games: not found in sources I read. Guerrilla and Sucker Punch talk contents were not fetched.
- UE hysteresis/unloading-delay settings, UE default cell sizes: not stated in the fetched docs.

## 2. What Godot 4 provides (4.4 to 4.7)

### Takeaway
Godot has per-instance visibility ranges with hysteresis and parent-child HLOD, automatic import-time mesh LOD, CPU occlusion culling with runtime-creatable occluders, MultiMesh, threaded resource loading and chunk building off-tree. It has no streaming manager, no HLOD baker and no impostor baker. Automatic LOD is documented as an import feature only.

### Cited Findings
- Automatic mesh LOD is generated on import (glTF, .blend, Collada, FBX) with meshoptimizer. It applies to MeshInstance3D, MultiMeshInstance3D and particles. The page documents import only and does not mention ArrayMesh, SurfaceTool or runtime generation. It warns of artifacts on skinned meshes. — [Mesh LOD (4.7 docs)](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html)
- LOD selection is by screen-space size. The project setting Rendering > Mesh LOD > LOD Change > Threshold Pixels defaults to 1 px ("perceptually lossless"). It can be set per viewport via `mesh_lod_threshold` (for example `get_tree().root.mesh_lod_threshold = 4.0`). Per-node `lod_bias` above 1.0 delays transitions, below 1.0 advances them. — same page
- For MultiMesh and particles, LOD is picked from the AABB point nearest the camera, so all instances in a node share one LOD level. The page says to split widely spaced instances into separate nodes, which also helps frustum and occlusion culling. — same page
- `ImporterMesh.generate_lods(normal_merge_angle, normal_split_angle, bone_transform_array)` returns void. `normal_split_angle` is unused. LOD data is read via `get_surface_lod_count()`, `get_surface_lod_size()` and `get_surface_lod_indices()`. `get_mesh()` returns a cached ArrayMesh. The docs do not state that it works at runtime. — [ImporterMesh](https://docs.godotengine.org/en/stable/classes/class_importermesh.html)
- Visibility ranges (GeometryInstance3D): Begin and End distances are measured to the AABB centre. Begin Margin and End Margin act as hysteresis in Fade Mode Disabled (cheapest) and as alpha-fade distance in Self or Dependencies, which force transparent rendering during the fade. Only alpha fading is supported. — [Visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html)
- Visibility Parent gives HLOD. Children hide only when the parent is fully visible/faded. The parent must be a GeometryInstance3D and cannot be a child of the dependent (cycles are an error). A node hidden via `visible` is dropped from the dependency tree. "HLOD reduces distant draw calls while keeping per-house culling up close." — same page
- Occlusion culling: enabled by the project setting Rendering > Occlusion Culling > Use Occlusion Culling. The baker handles only MeshInstance3D with opaque materials; CSG baking was added in 4.4. The CPU rasterizes occluders into a low-resolution buffer via Embree, and an occludee is culled only if its AABB is fully covered. Moving an OccluderInstance3D (or a parent) forces a BVH rebuild. Manual types: Quad, Box, Sphere, Polygon, and ArrayOccluder3D (not editable in the editor, intended for script generation). Tuning: BVH Build Quality, Occlusion Rays Per Thread. Forward+ already has a depth prepass, so the gain is smaller than on Mobile. — [Occlusion culling](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html)
- MultiMesh: one draw for many instances. There is no per-instance culling, so all instances are drawn or none, with a custom AABB possible. Split into several MultiMeshes per area. Use `visible_instance_count` over a max allocation. `RenderingServer.multimesh_set_buffer()` sets the whole buffer at once. The page states no numeric limit and no benchmarks, and is marked work-in-progress. — [Using MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)
- Threading: building node trees off-tree on a thread is allowed ("creating scene chunks ... outside the active tree is fine"). Attach on the main thread, or use `add_child.call_deferred(...)`. Interacting with the active tree is not thread-safe. Loading the same resource from several threads at once is discouraged, and modifying a unique resource from several threads is unsupported. The rendering thread model Separate is opt-in and has known bugs, and physics is not thread-safe unless run on a separate thread (a project setting). The page does not mention WorkerThreadPool. — [Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)
- Background loading: `ResourceLoader.load_threaded_request(path)`, `load_threaded_get_status(path, progress_array)`, `load_threaded_get(path)` (blocks if not finished). The page does not cover `use_sub_threads`, cache mode or off-thread instantiation. — [Background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html)
- Shader/pipeline stutter: Godot 4.4 introduced ubershaders (specialization constants) and precompilation of detected pipelines at load. The page applies to Forward+ and Mobile and to low-level APIs including D3D12, and it says precompilation is imperfect: pipelines can still compile at runtime for unhandled cases, driver cache clears on driver updates, and MSAA level changes across viewports can stutter. A forum report (lower confidence) gives about 430 ms on first use of a preloaded ShaderMaterial on Forward+ D3D12 in 4.6.3. — [Pipeline compilations (4.7)](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html), [forum thread](https://forum.godotengine.org/t/stuttering-when-material-is-first-used-despite-preload/139752)
- Large world coordinates: official builds are single precision. Double precision needs a custom build (`precision=double`, `.double` suffix, GDExtensions rebuilt) and has performance and memory costs. The doc recommends single-precision maximum extents of about 2048 units for first-person, 4096 for third-person, 16384 top-down and 32768 for any 3D game. Float steps are about 0.0002 at 2048 to 4096, 0.0005 at 4096 to 8192 and 0.0039 at 32768 to 65536. Origin shifting is named as the single-precision alternative, with no method given. — [Large world coordinates](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html)
- Godot 4.7 (released June 2026): headline change is HDR output, plus AreaLight3D, per the secondary coverage found. I found no 4.7 change to streaming, LOD or visibility ranges. — [DigitalProduction](https://digitalproduction.com/2026/06/23/godot-4-7-turns-up-hdr/), [Linuxiac](https://linuxiac.com/?p=214411). Secondary only; official release notes not fetched.

### Inferences
- Run-time generated low-poly meshes get no automatic LOD from the documented path. Options: author lower-detail variants in the pack generator and assign them via visibility ranges, or test whether ImporterMesh.generate_lods followed by get_mesh gives LODs at run time (documented neither way; needs a spike). Treating LOD as the pack generator's job is the safe design.
- The single-precision guidance (32768 units for any 3D game) suggests the continuous world should be bounded below about 32 km, or use origin shifting. Physics bodies near the camera matter most.
- For ~600 bodies per pack, physics-server cost likely matters more than render cost for loaded packs. Distant packs should be non-simulated. This is an inference.

### Gaps
- `Node.process_thread_group`, `process_mode` disable-subtree behavior, VisibleOnScreenNotifier3D/Enabler3D, directional shadow distance, fog as distance hider, far-plane depth precision (reversed-Z): not fetched; I could not source them this session. (Training knowledge, unverified: Godot 4 uses reversed-Z depth in Forward+, which helps far-plane precision; `PROCESS_MODE_DISABLED` stops processing and physics callbacks for a subtree.) Verify before relying on either.
- WorkerThreadPool and off-thread SurfaceTool/ArrayMesh creation rules: the thread-safe page does not mention them. Training knowledge, unverified: creating ArrayMesh resources on worker threads is generally done in practice, and RenderingServer calls need the thread-safe rendering setting or deferral.
- Whether `generate_lods` works at run time: not documented in fetched pages.

## 3. What Godot lacks and community solutions

### Takeaway
No built-in streaming manager, HLOD generator or impostor baker was found in the docs I read. Community options exist (Terrain3D for terrain, octahedral impostor addons of unclear maintenance) but nothing replaces World Partition.

### Cited Findings
- Terrain3D: geomorphing geometric clipmap terrain, similar to the Witcher 3. Terrains from 64 m x 64 m up to 65.5 km x 65.5 km, up to 10 LOD levels. A 16k x 16k terrain is sliced into non-contiguous 1k regions. Supports Godot 4.3 to 4.6+ on Windows, with D3D12 notes. `bake_mesh(lod, filter)` produces a static ArrayMesh. The sources do not say whether regions load and unload dynamically. — [Terrain3D docs](https://terrain3d.readthedocs.io/en/latest/api/class_terrain3d.html), [GameFromScratch](https://gamefromscratch.com/terrain3d-a-new-terrain-engine-for-godot/). Secondary summaries from a search; 4.7 support not confirmed.
- Impostors: "Octahedral Impostor LOD" (asset library 5528) bakes 144 views and uses visibility ranges for switching, with a license that needs checking. `godot-imposter` (zhangjt93, MIT) is a Godot 4 port verified on 4.5 beta 5. The original wojtekpil plugin is Godot 3 only. Maturity and 4.7 compatibility are unverified. — [Asset Library 5528](https://godotengine.org/asset-library/asset/5528), [godot-imposter README](https://github-users.yhajoa.workers.dev/zhangjt93/godot-imposter/blob/master/README.md), [wojtekpil via relatedrepos](https://relatedrepos.com/gh/wojtekpil/Godot-Octahedral-Impostors)
- Node-add cost evidence is forum only (low confidence): one poster saw a spike over 500 ms spawning 1000 batches at once versus about 23 ms spread over time. Another reply says `add_child()` still hitches when instantiation ran on a thread, and a Godot 4.3 answer says preloading does not remove the `add_child` stutter, which scales with scene size. — [spawning thread](https://forum.godotengine.org/t/best-practices-for-spawning-large-number-of-objects/102004), [threaded instantiation](https://forum.godotengine.org/t/threaded-instantiation/139671), [resource management](https://forum.godotengine.org/t/understanding-and-smoothing-resource-management-of-godot-4/95761)

### Inferences
- A thin custom streamer (grid of pack cells, a state machine UNLOADED/PROXY/BUILT/ACTIVE, a time-sliced attach queue) is what the engine leaves to the project. Pure GDScript is likely sufficient. GDExtension is not clearly required for this; the only documented case where C++ is suggested is bulk MultiMesh buffer setting at very large scale (MultiMesh page).
- Cheap safe pattern: build the pack's node tree off-tree on a worker, then attach children in small batches per frame from the main thread. The docs permit the first half; the batch size must be measured.

### Gaps
- Proton Scatter, "Godot Open World" demos, chunk-streaming addons: not searched.
- Official limits: draw call costs in Forward+, freeing-many-nodes issues, MultiMesh numeric limits: no authoritative source found (the MultiMesh page gives none; the forum search found nothing on queue_free hitches).

## 4. Impostors and proxies for distant mini-games

### Takeaway
Only the octahedral impostor tools and the visibility-range/HLOD mechanism were sourced. Nothing was found on live SubViewport impostors or outline-pass behavior at distance.

### Cited Findings
- Visibility Parent plus Begin/End ranges form the engine-native HLOD proxy swap, cheapest with Fade Mode Disabled and margins as hysteresis. — [Visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html)
- UE's proxy options (Merged, Simplified, Instanced lowest-LOD) are offline-built stand-ins. — [Epic HLOD layers](https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition---hierarchical-level-of-detail-in-unreal-engine)
- Octahedral impostor addons for Godot 4 exist (section 3), baked from many views.

### Inferences
- A merged low-detail ArrayMesh of the venue, generated by the pack's own generator and assigned as the visibility parent, fits the thesis best. It costs few draw calls and avoids bake tooling. This is unmeasured.
- Likely outline issue: a depth/normal edge detector at distance sees small silhouettes and creates thin lines and shimmer, since line width is in screen pixels but geometry detail shrinks. Untested here; a fade of outline strength with distance, or simpler proxy normals, should be a spike item.
- Render-to-texture live impostors need a SubViewport per distant pack (extra scene render each update, depth from the card not the real geometry). No sources; treat as high cost per pack and test.

### Gaps
- Cost/quality of SubViewport live impostors, baked snapshots and billboard cards with a depth+normal outline pass: no sources found.

## 5. Progressive loading order, budgets and spike thresholds

### Takeaway
No published per-frame streaming budgets were found. Treat all numbers as spike outputs. The sourced facts: LOD pixel threshold defaults, resource loading is asynchronous, and attaching is a main-thread cost.

### Cited Findings
- Godot background loading separates request, status poll and get; the final get blocks if unfinished. — [Background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html)
- UE sources have a priority and a target state (Loaded versus Activated), a two-stage model: load data first, activate later. — [Epic World Partition](https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition-in-unreal-engine)
- Unity sample loads coarse LOD cells with higher priority than detailed cells. — [Meta sample](https://developers.meta.com/vr/documentation/unity/unity-sample-asset-streaming)
- User's own baseline: about 1.8 ms GPU per frame at 1440p for 480k triangles and 260 draw calls (given in the task, not independently sourced).

### Inferences
- Suggested spike measurements (all unmeasured): nodes attached per frame versus frame-time spike, cold versus warm pack activation, visibility-range switch cost for 1000 versus 10000 instances with fade disabled, physics body create/free cost for 600 bodies, first-use pipeline compile time on D3D12 for the shared palette material (one shared material limits this), memory per loaded pack, and a distance-priority queue with margin-based hysteresis. Use two states per pack (proxy always resident, detail resident within range plus margin).
- Because the style uses one palette material, pipeline-compilation risk is lower than in typical games. It is not zero, because the outline post-process and shadow/depth pipelines are separate. Warm them at startup (inferred, not verified).

### Gaps
- Published ms/frame or nodes/frame streaming budgets from shipped games: not found.
- Memory budgets and unloading policies of reference engines: not found.
