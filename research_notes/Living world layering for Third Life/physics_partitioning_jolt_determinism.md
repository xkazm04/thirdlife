# Physics partitioning, sleeping and deterministic simulation for many independent mini-games (Jolt in Godot 4.7)

Scope and confidence legend. VERIFIED = read in primary doc/source this session (cited). SECONDARY = third-party/search snippet. INFERENCE = my reasoning, not read anywhere. Source-version notes: Godot source quotes below come from `master` of godotengine/godot (modules/jolt_physics), fetched Nov 2026, not a tagged 4.7 file; defaults could differ in a 4.7 tag (not checked). Docs pages cited as "stable". Nothing here was benchmarked; no numbers about cost of spaces or bodies were found in primary sources (see Gaps).

## One space or many: how spaces work in Godot's Jolt module, stepping, pausing, catch-up

### Takeaway
In Godot's Jolt module each `space_create()` makes a fully separate `JoltSpace3D`, i.e. its own Jolt `PhysicsSystem` (own broadphase, bodies, contact cache), and `space_set_active(false)` simply removes it from the set stepped each tick, so "pause one pack while others run" is natively supported. There is no public per-space step or per-space rate in Godot 4: all active spaces are stepped serially, with the same delta, once per physics tick; `PhysicsServer3D.space_step()` exists only as an unmerged PR.

### Cited Findings
- `space_create` does `memnew(JoltSpace3D(job_system, temp_allocator))`, registers an RID, and creates a default area for it — one Jolt PhysicsSystem per space. — [jolt_physics_server_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_physics_server_3d.cpp) and [jolt_space_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/spaces/jolt_space_3d.cpp)
- `space_set_active(space, true/false)` calls `space->set_active(...)` and inserts/erases the space in a server-level `active_spaces` set; `space_is_active` returns membership. — [jolt_physics_server_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_physics_server_3d.cpp)
- `JoltPhysicsServer3D::step(p_step)` returns early if server inactive, otherwise loops `for (JoltSpace3D *active_space : active_spaces)` doing `job_system->pre_step(); active_space->step((float)p_step); job_system->post_step();`. The same delta goes to every active space; the loop is serial across spaces (each Jolt Update is itself multithreaded via the job system). `flush_queries` likewise loops active spaces only. — [jolt_physics_server_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_physics_server_3d.cpp)
- `JoltSpace3D::step` calls `physics_system->Update(p_step, 1, temp_allocator, job_system)`: delta passed unchanged, collision-steps argument fixed at 1 (no sub-stepping inside a tick). — [jolt_space_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/spaces/jolt_space_3d.cpp)
- Each space's constructor calls `physics_system->Init(max_bodies, 0, max_body_pairs, max_contact_constraints, ...)` with the project-wide limits, i.e. limits are PER SPACE, not global, and every space allocates for those capacities (defaults 10240 bodies / 65536 pairs / 20480 contact constraints). Memory-per-space not measured/quoted anywhere I found. — [jolt_space_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/spaces/jolt_space_3d.cpp), [jolt_project_settings.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_project_settings.cpp)
- `PhysicsServer3D` class reference lists `space_create`, `space_set_active`, `space_is_active`, `space_get_direct_state`, `body_set_space`, `set_active`, `get_process_info`; no step/simulate method appears in the method table. `get_process_info` gives INFO_ACTIVE_OBJECTS (non-sleeping), INFO_COLLISION_PAIRS, INFO_ISLAND_COUNT. (Method descriptions were beyond the fetch window; table only.) — [PhysicsServer3D docs](https://docs.godotengine.org/en/stable/classes/class_physicsserver3d.html)
- `body_set_space(body, space)` calls `body->set_space(space)` (null RID detaches). — [jolt_physics_server_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_physics_server_3d.cpp)
- Manual stepping: PR #76462 "Add PhysicsServer2/3D::space_step()" is open, not merged, labelled enhancement/topic:physics, with a Godot team member (clayjohn) noting disagreement about whether it serves its use cases; the PR author said they stopped maintaining it. A commenter reported `space_step()` ignores `PhysicsServer3D.set_active(false)`/space deactivation and was non-deterministic with Jolt; a downstream fork note says calling the raw `JoltSpace3D::step()` repeatedly bypasses job-system pre/post-step and exhausts the Jolt job pool. These are PR-thread comments (secondary quality). — [PR #76462](https://github.com/godotengine/godot/pull/76462); older proposal [godot-proposals#236](https://github.com/godotengine/godot-proposals/issues/236) (semi-fixed timestep/manual stepping), still open per search snippet
- Godot has no per-space timestep: Unity by contrast has `PhysicsScene.Simulate(step)`, simulating only that scene's physics, and non-default physics scenes MUST be simulated manually. Unity advises a fixed step, not `Time.deltaTime`, for determinism. — [Unity PhysicsScene.Simulate](https://docs.unity.com/en-us/engine/current/script-reference/unityengine/physicsscene/simulate)
- godot-jolt release notes mention an earlier fix for "project randomly freezing up when having many active physics spaces" and a fix for passing a space RID to some area functions (extension, 0.x era; not the built-in module). Search-snippet level. — [godot-jolt releases](https://www.Github.com/godot-jolt/godot-jolt/releases)
- Jolt's author on partitioning a big sparse world: each `PhysicsSystem` has a single broadphase; per-cell broadphase layers are fixed at init and hard to change; he recommends one `PhysicsSystem` per cell, at the cost that a body crossing cells must be destroyed and recreated; another poster notes X4 keeps one system centred near the player and relocates it. — [JoltPhysics discussion #999](https://github.com/jrouwe/JoltPhysics/discussions/999)
- `SubViewport.own_world_3d` / `World3D`: not read this session. (A World3D owns a space RID; that is Godot core behaviour I know from memory but did not re-verify.)

### Inferences
- Many spaces vs one: since packs are independent, one space per pack matches Jolt author's advice and gives free pause (`space_set_active(false)`), free isolation (no cross-pack contacts, no solver-order coupling), per-pack hash independence, and no dependence on world offset (bodies can live at a local origin). Cost: N PhysicsSystems each initialised for 10240/65536/20480 capacities. Lowering `limits/max_bodies` (restart-required) to e.g. ~700-1024 in a many-space design would reduce per-space allocation, but the limit also applies to the default space; verify memory empirically.
- Spaces step serially on the main physics tick; threading only helps within one space's Update. So "tens of spaces each with active bodies" costs sum of the parts plus per-space fixed overhead (pre/post step, flush, query processing) — the fixed overhead per idle active space is unmeasured; the safe approach is `space_set_active(false)` for idle packs.
- No catch-up for one space: Godot's main loop can run several physics ticks per frame globally (project setting `max_physics_steps_per_frame`, not verified here), but a space cannot be run at a different rate natively. Workarounds: deactivate space and reactivate every Nth tick (but the delta passed is the global tick delta, so a slower pack would be time-compressed, not stepped with a bigger dt, unless you change `Engine.physics_ticks_per_second`/time scale globally). Treat "pack at 30 Hz" as an unsupported design.
- A "deactivated" space also stops `call_queries`, so ray casts/shape queries against it via `space_get_direct_state` may still work (queries flush pending bodies) but Area/body signals won't fire; not verified.

### Gaps
- Could not read the method descriptions for `space_set_active`/`space_step` in the class reference (fetch truncated); did not confirm there is no doc statement on what deactivation preserves.
- No measured memory or time cost per `PhysicsSystem`/space; no GitHub issue found documenting a hard cap on number of spaces in the built-in module.
- Whether the Godot 4.7 tagged source differs from master for step/space code: not checked.
- Interaction of `SubViewport` `own_world_3d` with Jolt not verified.

## Jolt capacity, sleeping, project settings, limits

### Takeaway
Defaults per space: 10240 bodies, 65536 body pairs, 20480 contact constraints; solver 10 velocity / 2 position steps; sleep after 0.5 s below 0.03 m/s. Overflow does not crash for pairs/constraints: contacts are silently dropped (warning once); body creation fails (error once, returns null). Sleeping islands cost no solver time, but bodies still sit in the broadphase.

### Cited Findings
- Defaults (master): `simulation/velocity_steps` 10, `position_steps` 2, `allow_sleep` true, `sleep_velocity_threshold` 0.03 m/s, `sleep_time_threshold` 0.5 s, `penetration_slop` 0.02, `speculative_contact_distance` 0.02, `baumgarte_stabilization_factor` 0.2, `continuous_cd_movement_threshold` 0.75, `continuous_cd_max_penetration` 0.25, `body_pair_contact_cache_enabled` true (distance 0.001 m, angle 2 deg), `limits/temporary_memory_buffer_size` 32 MiB, `limits/world_boundary_shape_size` 2000 m, `max_linear_velocity` 500 m/s, `max_angular_velocity` 2700 deg/s, `max_bodies` 10240 (restart-required), `max_body_pairs` 65536, `max_contact_constraints` 20480. No thread setting in this file. — [jolt_project_settings.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_project_settings.cpp). Whether these defaults were the same in 4.4-4.7 tags: NOT checked.
- Overflow: `CreateBody` returning null yields `ERR_PRINT_ONCE` suggesting raising max bodies and returns null; after each Update the `EPhysicsUpdateError` flags `ManifoldCacheFull`, `BodyPairCacheFull`, `ContactConstraintsFull` each trigger `WARN_PRINT_ONCE` saying contacts were ignored. — [jolt_space_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/spaces/jolt_space_3d.cpp)
- Godot docs: sleep settings were renamed in the module (`simulation/allow_sleep`, `sleep_velocity_threshold`, `sleep_time_threshold`; `simulation/position_steps`, `velocity_steps`); temporary memory buffer is a fixed up-front reservation; "Run On Separate Thread" exists but is "untested and experimental". Built-in module added thread-safety the extension lacked. — [Using Jolt Physics](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html)
- Jolt sleeping: bodies are grouped into islands (dynamic bodies in contact/constraint; statics excluded); island sleeps if all members at rest; sleeping bodies still detect collisions with awake bodies, wake on contact with awake bodies or `ActivateBody`; removing a body does not wake neighbours; `Body::SetLinearVelocity` does not wake but `BodyInterface::SetLinearVelocity` does; criteria `mTimeBeforeSleep`, `mPointVelocitySleepThreshold`. — [Jolt Architecture docs](https://jrouwe.github.io/JoltPhysics/)
- Jolt sleep test mechanics: three bounding spheres over key points tracked over time; if they grow too large the timer resets; at threshold the body sleeps; check runs in the "Solve Position Constraints, Update Bodies Broad Phase" job. — [Jolt Architecture docs](https://jrouwe.github.io/JoltPhysics/)
- Jolt broadphase: quad tree per broadphase layer; moving bodies expand nodes lock-free; a tight tree is rebuilt in the background each step; bodies cannot be added/removed during a step; adding bodies one at a time gives an inefficient tree and in extreme cases can run out of nodes and `std::abort`; use batched add (Godot's module batches in `flush_pending_objects` via AddBodiesPrepare/Finalize). Keep layer counts low. Static bodies/sensors: static sensors only detect active bodies. — [Jolt Architecture docs](https://jrouwe.github.io/JoltPhysics/), [jolt_space_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/spaces/jolt_space_3d.cpp)
- Jolt: the find-collisions job runs the broadphase only for ACTIVE bodies; contacts live in two lock-free caches (read last step / write this step), solver warm-starts from cached impulses; contact cache swap in Finalize Contact Cache; islands rebuilt every step; large islands split for parallel solving and processed `mNumVelocitySteps` times. — [Jolt Architecture docs](https://jrouwe.github.io/JoltPhysics/)
- Godot's Jolt guidance: dynamic bodies ~0.1-10 m, speeds up to ~500 m/s; changing shapes of a body in a space triggers a compound-shape rebuild (expensive for many shapes; mihe closed the issue as not planned for the extension). — [godot-jolt README](https://github.com/godot-jolt/godot-jolt/blob/master/README.md), [godot-jolt#660](https://github.com/godot-jolt/godot-jolt/issues/660)
- Guerrilla's GDC 2022 talk "Architecting Jolt Physics for Horizon Forbidden West" exists (slides on GDC Vault/jrouwe site); a secondary summary says the switch improved sim frequency with less CPU time. I did not retrieve its scaling data. — [Guerrilla page](https://guerrilla-games.com/read/architecting-jolt-physics-for-horizon-forbidden-west)

### Inferences
- With 600 bodies/pack and tens of packs (say 30 -> up to 18000 bodies) one shared space would exceed the default 10240 max_bodies (restart-required setting; raise it), hence another reason to use per-pack spaces or raise limits.
- Cost model (not measured): fully asleep islands cost broadphase presence only (and tree maintenance); active bodies cost narrowphase+solver. Pre-fractured walls are the biggest risk: many small bodies that wake together. Compound shapes are expensive to modify after being added.
- Warning for determinism: overflow silently drops contacts — a hash mismatch could be a limit overflow; watch for `WARN_PRINT_ONCE` text and treat as test failure.

### Gaps
- No published bodies-at-60Hz benchmark found; Jolt Performance test doc URL (md_Docs_2Performance_test) returned 404. The 2 ms budget threshold must be measured in the spike.
- Defaults in 4.4/4.5/4.6/4.7 tagged releases not individually verified; `Godot 4.6` made Jolt the default engine for new projects (secondary: [4.6 release coverage](https://blog.desdelinux.net/en/Godot-4.6-release-Jolt-Physics-IK-modern-theme/)).
- Jolt thread count / WorkerThreadPool sharing across spaces not examined.

## Determinism, absolute position, and cross-body influence

### Takeaway
Jolt is deterministic under strict conditions (same binary, same API call order, FP state, ordered/ID-consistent bodies), but the Godot Jolt authors explicitly make no determinism guarantee. A pack at (2000,0,3000) will not be bit-identical to one at origin in single precision, and other bodies in the same space can plausibly perturb results; separate space per pack at a local origin avoids both.

### Cited Findings
- Jolt determinism conditions: API calls that modify the simulation must occur in exactly the same order; same binary (CPU vendor doesn't matter on same binary); `CROSS_PLATFORM_DETERMINISTIC` build option for cross-platform (about 8% slower); same defines on all platforms; compile with precise FP, no FP contraction; consistent FPU rounding/DAZ/FTZ; use Jolt's own Sin/Cos/QuickSort/Hash. — [Jolt Architecture docs, Deterministic Simulation](https://jrouwe.github.io/JoltPhysics/)
- Non-deterministic bits per Jolt docs: `BroadPhaseQuery` (boxes widen between maintenance updates), order of `NarrowPhaseQuery` results, callback order of ContactListener/BodyActivationListener/PhysicsStepListener (multithreaded), and `PhysicsSystem::GetActiveBodies` ordering. — [Jolt docs](https://jrouwe.github.io/JoltPhysics/)
- "Sloppy determinism": body add order A,B vs B,A is equivalent if BodyIDs are consistent; constraint order irrelevant if `mConstraintPriority` unique. Jolt's own sample app has a "Check Determinism" mode that records state with StateRecorder, rewinds, reruns one step and validates. — [Jolt docs](https://jrouwe.github.io/JoltPhysics/)
- Godot Jolt README: "Jolt itself is deterministic, but Godot Jolt makes no such guarantee. Simulations may look or happen to be deterministic, so you shouldn't rely on that." — [godot-jolt README](https://github.com/godot-jolt/godot-jolt/blob/master/README.md) (extension; the built-in module docs I read are silent on determinism)
- Godot's module batches body adds via pending lists (sleeping list and awake list, each added with AddBodiesPrepare/Finalize at `_pre_step` or before queries), so Jolt's insertion order/BodyIDs follow Godot's pending-list order rather than your scene-tree order per se. — [jolt_space_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/spaces/jolt_space_3d.cpp)
- Large worlds: default float build is "accurate within roughly 5 km of the origin"; `JPH_DOUBLE_PRECISION` needs a custom build (not available in official Godot builds — constraint says no fork); float broadphase loses resolution at distance; keep objects at intended scale. — [Jolt docs](https://jrouwe.github.io/JoltPhysics/)
- Godot 4.x `RigidBody3D`/Jolt `world_boundary_shape_size` is 2000 m (reduced for precision reasons). — [jolt_project_settings.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_project_settings.cpp), [Using Jolt](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html)
- Gaffer On Games: same-machine/same-binary replays are the reliable tier; sources of nondeterminism include compiler optimisations, FMA, transcendental functions, FPU state changed by external DLLs, variable solver iteration counts, and parallelism ("effectively incompatible with most forms of parallelism" per one quoted author); author himself calls cross-machine reliability unsettled. — [Gaffer: Floating point determinism](https://gafferongames.com/post/floating_point_determinism/)
- Unity: pass a fixed step to `PhysicsScene.Simulate`, not frame-delta, for determinism. — [Unity docs](https://docs.unity.com/en-us/engine/current/script-reference/unityengine/physicsscene/simulate)
- Godot PR #76462 thread: a commenter reported results "not deterministic with Jolt" when using `space_step()`; another reviewer said time scale and node-level physics issues affect determinism. Low-confidence (PR comments). — [PR #76462](https://github.com/godotengine/godot/pull/76462)

### Inferences (flagged: reasoning, not read in sources)
- Float32 spacing (ulp) by distance, computed from IEEE-754: at ~1 km (512-1024) 6.1e-5 m; 2000 m (1024-2048) 1.2e-4 m; 3000-4000 m (2048-4096) 2.4e-4 m; ~10 km (8192-16384) 9.8e-4 m, i.e. about your 1 mm hash quantum. Jolt stores body positions as float in the single-precision build, so every position add/transform rounds on a coarser grid at offset; a pack at (2000,0,3000) is therefore NOT bit-identical to one at origin: contact points, penetration depths, and integrator updates round differently; small differences amplify chaotically in stacks/fractured walls. A 1 mm-quantised hash would flip on some runs near rounding boundaries, and chaotic scenes will diverge visibly (not only in last bits).
- Safe designs: (1) one space per pack with bodies at pack-local origin, render/offset the visual root by a Node3D transform (physics results stay identical to today's origin-based verification); (2) never move bodies' physics positions when relocating a pack — move the visual parent; (3) if a pack must live in world coordinates in shared space, compare hashes in pack-local coordinates with tolerance (say >= ulp at that distance) and accept non-bit-identical replays; verify by test, not assumption.
- Presence of other bodies in same space: Jolt's docs say determinism needs identical API call sequence and state; extra bodies change broadphase tree structure, body IDs/order in active lists, island construction, solver ordering within parallel groups and contact cache contents — so a pack's results are not guaranteed identical when others are added/removed. I found no Jolt doc or issue stating that disjoint islands are solved independently and bit-identically regardless of neighbours. Treat as unverified, and make separate spaces the default; test by adding a second pack to the same space (hash stability test below).
- Multithreading: Jolt claims determinism even multi-threaded (its docs don't list threading as a violation, only listener callback order), but Godot's contact/area callbacks and your rules script run on the callback results — order them (sort) before using them.
- Per-pack deterministic replay also needs: fixed 60 Hz delta with no `physics_jitter_fix`, interpolation off for hash purposes, identical add order of bodies, no `Engine.time_scale` changes (not verified in docs; Unity/Godot PR commenters flag time scale), identical project settings, same binary.

### Gaps
- Could not find any Jolt or Godot-Jolt issue testing whether other bodies in the same space perturb a pack's results.
- Did not find a Godot docs statement on `physics/3d/run_on_separate_thread` and determinism beyond "experimental"; did not verify interpolation settings behaviour.
- Cross-position bit-identity: no source tested it; the claim above is arithmetic reasoning.

## Pausing, resuming, and saving/restoring one pack

### Takeaway
Jolt can save/restore a whole PhysicsSystem (StateRecorder) including contact cache, but Godot does not expose it; Godot's API only lets you restore transforms/velocities, which loses warm-start impulses and sleep timers, so a resumed run is not guaranteed bit-identical to an uninterrupted one. Pausing in place via `space_set_active(false)` is the closest thing to exact pause.

### Cited Findings
- Jolt: `PhysicsSystem::SaveState`/`RestoreState` record what the engine changes in Update (positions, velocities, etc.); settings changed via API (e.g. SetFriction) must be reapplied manually; adding/removing bodies or constraints breaks `RestoreState` (remove and re-add on replay); `StateRecorderFilter::ShouldSaveBody` can skip static/inactive bodies; BodyIDs must match between peers. The sample app "Check Determinism" uses StateRecorder. — [Jolt docs](https://jrouwe.github.io/JoltPhysics/)
- Jolt's contact cache is warm-started from cached impulses, and sleep tracking uses time-based bounding-sphere tracking (see sleeping section) — both are per-engine state not in transforms/velocities. — [Jolt docs](https://jrouwe.github.io/JoltPhysics/)
- Godot's Jolt module has a `set_is_object_sleeping` path calling `DeactivateBody`/`ActivateBody`; I found no snapshot/restore API in the module source files read and no Godot docs page mentioning StateRecorder. A search found no Godot/Jolt snapshot PR. PR #76462's thread claims Jolt is "the only officially supported engine with full state snapshot support" (a reviewer's claim, not verified; may refer to internals). Contrast: the third-party Rapier addon exposes whole-space snapshot (`cache_state`/`load_cached_state`). — [jolt_space_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/spaces/jolt_space_3d.cpp), [PR #76462](https://github.com/godotengine/godot/pull/76462), [Rapier addon](https://godot.rapier.rs/docs/documentation/serialization)
- Godot docs: `PhysicsServer3D.space_set_active`, `body_set_state`, `body_set_space` exist (signatures). — [PhysicsServer3D docs](https://docs.godotengine.org/en/stable/classes/class_physicsserver3d.html)

### Inferences
- Pause options ranked: (a) `space_set_active(false)` for a per-pack space: all body state, contact cache and sleep timers remain intact inside the Jolt system, so resume continues as if time stopped (best candidate; verify with the pause/resume equivalence test). Caveat: the hash comparison must use the same number of ticks consumed; rules script timers must also pause. (b) Remove bodies from space / `freeze`: freezing converts to static/kinematic and loses dynamic state semantics; removing from a space discards Jolt-side contact/cache; resuming from transform+velocity only loses warm-start impulses and sleep timer, so the first ticks differ slightly, and an island that was asleep wakes with timer restarted. These produce a different trajectory from an uninterrupted run (small at first, chaotic scenes diverge). (c) Saving a pack to disk and rebuilding it is inherently non-bit-identical unless your own hash/verification treats the restore as a new "seed" (record a keyframe and verify from it forward).
- Practical: treat each pause/resume boundary as a replay keyframe: log (state-at-resume, inputs) rather than trusting equivalence with an uninterrupted run; keep bodies sleeping (can_sleep) while paused for state-at-rest restores where velocities are zero, which minimises contact-cache loss (inferred: resting stacks have near-steady impulses but are not reproducible bit-for-bit).

### Gaps
- Not verified: whether `space_set_active(false)` followed by `true` has any hidden effect (e.g. contact listener, pending-object flushing, query state); only that it adds/removes from the stepped set.
- Whether any Godot version exposes Jolt SaveState via GDExtension-accessible APIs (none found).

## Reduced-rate simulation and alternatives

### Takeaway
Godot offers no per-space or per-subtree tick rate; Jolt's Update takes a single step with the delta provided (collision-steps = 1 in Godot). Reduced fidelity must be done by pausing/deactivating spaces, running rules on an abstract model, or replacing physics with kinematic proxies.

### Cited Findings
- `JoltSpace3D::step` uses `Update(p_step, 1, ...)`: one collision step per tick, no internal sub-stepping, delta = global delta. — [jolt_space_3d.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/spaces/jolt_space_3d.cpp)
- Jolt continuous collision settings in Godot: `continuous_cd_movement_threshold` 0.75, `continuous_cd_max_penetration` 0.25 — controls linear-cast CCD for fast bodies; max linear velocity 500 m/s. — [jolt_project_settings.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_project_settings.cpp)
- Unity solves this with explicit per-scene `PhysicsScene.Simulate(step)` calls; non-default scenes must be stepped manually. — [Unity docs](https://docs.unity.com/en-us/engine/current/script-reference/unityengine/physicsscene/simulate)
- Roblox: with streaming, client physics runs only in streamed areas (replication foci keep distant objects simulating); assemblies stream in as whole units and do not stream out until all parts are eligible. — [Roblox streaming docs](https://create.roblox.com/docs/workspace/streaming)
- Godot proposals #236 on semi-fixed timestep/manual stepping remains open. — [godot-proposals#236](https://github.com/godotengine/godot-proposals/issues/236)

### Inferences
- Bigger timesteps: Jolt's solver is stable per-step, but with a single collision step and speculative contacts (0.02 m) tunnelling risk rises with dt for thin pre-fractured walls and fast vehicles; no sourced numbers. A paused/resumed pack should keep 60 Hz exactly: a pack stepped at 30 Hz would also break deterministic comparison with the 60 Hz bot-verified hash.
- Alternative patterns that transfer: (1) "alive" only near the player: awake space only for packs in range (like Roblox streaming foci/X4's relocated system), others `space_set_active(false)`; (2) distant packs run on an abstract model or scripted animation and swap to real physics on approach; (3) kinematic proxies for background motion; (4) alternate-frame stepping is not possible per space without a global tick change, but you can activate packs in round-robin only if each pack's own logical clock tolerates being paused (ticks are delta-fixed so a paused pack just lags real time).
- Other engines (Unreal Chaos scene-per-world and islands; PhysX/Havok islands; MMO instancing): I did not retrieve primary sources for these this session; do not cite them as verified. General knowledge only: island-based sleeping is the standard mechanism, and server-side instances are separate simulations per instance.

### Gaps
- Unreal, PhysX/Havok and MMO instancing: not researched with sources (tool budget); Roblox network ownership/sleeping not covered by the page fetched.
- No source on tunnelling vs dt for Jolt specifically.

## Vehicles, characters, Area3D

### Takeaway
No primary-source determinism or sleeping caveats were found for ray-cast vehicles, `CharacterBody3D.move_and_slide`, or `Area3D` under Jolt; only behaviour differences from docs and low-confidence forum reports.

### Cited Findings
- Godot docs: with Jolt, `Area3D` overlap signals are supported including with `SoftBody3D` (Godot Physics doesn't emit those); 4.7 betas: Area3D now reports overlaps with SoftBody3D under Jolt; RC3 removed forced area event queuing on body exit (GH-120243); gravity-scale bug when set from code fixed (GH-120258). — [Using Jolt](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html), [4.7 beta 1](https://godotengine.org/article/dev-snapshot-godot-4-7-beta-1/), [4.7 RC3](https://godotengine.org/article/release-candidate-godot-4-7-rc-3/) (as summarised by search; not opened in full)
- Docs: kinematic RigidBody3D contacts not reported by default (`generate_all_kinematic_contacts` false); contact impulses are estimated in advance and accurate only for isolated pairs; motion queries (used by character bodies) have their own settings (`recovery_iterations` 4, `recovery_amount` 0.4, enhanced internal edge removal true). — [Using Jolt](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html), [jolt_project_settings.cpp](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_project_settings.cpp)
- Jolt: sensors detect dynamic/kinematic bodies via the ContactListener (callbacks multi-threaded, so order not deterministic); static sensors only detect active bodies. — [Jolt docs](https://jrouwe.github.io/JoltPhysics/)
- PR #76462 thread (low confidence) lists `CharacterBody3D` needing physics delta, sleeping bodies not waking properly and `Area3D` signals as node-level issues unresolved by a server-level step. — [PR #76462](https://github.com/godotengine/godot/pull/76462)
- Forum/blog items about sleeping bodies still sending collision events and impulses waking bodies: lower confidence (bugnet.io blog, Godot forum). I found no confirmed report of VehicleBody3D non-determinism with Jolt.

### Inferences
- `VehicleBody3D` is a RigidBody3D subclass whose wheels are implemented in Godot node code using ray casts (my recollection of Godot internals, not re-verified this session); results then depend on query ordering and the sleeping state of the chassis. A resting vehicle can fall asleep; keep an explicit wake policy (`can_sleep=false` or wake on input) so a paused-then-resumed pack's vehicle isn't asleep when a rules script drives it.
- Because Area/contact callbacks arrive in unspecified order (Jolt docs) and the rules script consumes them, collect and sort events by body id each tick before processing, or the replay can diverge even if the physics is bit-exact.
- `move_and_slide` queries the space (not a step), so it depends on the pack's space; moving a character between packs means changing its space, which is a different body.

### Gaps
- VehicleBody3D under Jolt, `move_and_slide`, and sleeping-wake-on-Area behaviour were not verified with primary sources or tests.

## Measurable thresholds for the spike

### Takeaway
Seven experiments will settle the open questions; none has published numbers to rely on.

### Cited Findings
(Design only; these are derived from the sources above — [Jolt determinism docs](https://jrouwe.github.io/JoltPhysics/), [Godot Jolt source](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/spaces/jolt_space_3d.cpp), [PR #76462](https://github.com/godotengine/godot/pull/76462).)

### Inferences (proposed tests)
1. Active-body budget: one space, ramp active dynamic bodies (pre-fractured wall + vehicles + characters) until the physics step exceeds 2 ms at 60 Hz; read `PhysicsServer3D.get_process_info(INFO_ACTIVE_OBJECTS/INFO_ISLAND_COUNT)` and the profiler `physics_process` monitor. Repeat with 1 vs several worker threads.
2. Sleeping cost: N packs (10/30/60) in one space fully asleep, measure ms per tick vs 0 packs; vs awake.
3. Space cost: N empty spaces active vs `space_set_active(false)`; N packs in N spaces; measure memory (OS working set) and step time; test with `limits/max_bodies` at 10240 vs ~1024.
4. Hash stability vs neighbours: run pack A alone, then A with B added in the same space (before/after A), then A with B in another space; compare 1 mm hash every tick for e.g. 60 s with a recorded bot.
5. Offset stability: same pack at (0,0,0), (1000,0,0), (2000,0,3000), (4000,0,4000), (10000,0,0) in a space; compare in local coords; record first-divergence tick and magnitude; control by moving only the visual root.
6. Pause/resume equivalence: run K ticks, deactivate space for M ticks, reactivate, run K more; compare with uninterrupted 2K ticks. Then the variant freezing/removing bodies and restoring transform+velocity. Also a pack paused while asleep vs awake.
7. Overflow guard: assert no `WARN_PRINT_ONCE` contact-ignored warnings (capture output), and run each hash test at least 20 times and with Godot's job threads changed to check run-to-run stability.

### Gaps
- No published reference values; thresholds in each test must be set from the spike itself.

---
Sources not usable/failed: Jolt Performance test page (404), godot-jolt docs/determinism.md (404), Godot ProjectSettings page truncated before physics settings (so `max_physics_steps_per_frame`, `physics_jitter_fix`, `run_on_separate_thread` defaults not verified). Unreal/PhysX/Havok/MMO instancing and Gaffer's other articles (e.g. Fix Your Timestep) not researched.
