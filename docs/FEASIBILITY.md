# Third Life: feasibility, stack and mechanisms

Status: spark design output, 2026-11-10. Evidence grades: **[measured]** from this owner's own repos on this
machine, **[estimate]** the Director's reasoning, **[unverified]** vendor/blog claims (links at the end).

## 1. Verdict

**Feasible in a bounded form; not as "anything".** What can be built is a system in which an LLM
*composes verified parts over a stable kernel*: whole mini-games whose mechanics are combinations of rigid-body
physics with materials, characters and vehicles on standard rigs, ball/puck sports, AI built from steering and
behaviour trees, rule state machines, destruction by pre-fractured parts, and a HUD. Hockey and racing both sit inside that envelope.
What an LLM cannot do in minutes, and what the design must therefore not promise:

- bespoke skeletal animation per character (measured 75 min of agent time for one character's 15 clips, plus QA) **[measured]**
- novel simulation systems (fluids, cloth, new vehicle dynamics) that the kernel did not foresee, unless they come through a slow, gated kernel job
- photoreal assets at game scale, and anything whose quality is only judged by feel without a human checkpoint
- "anything" in the sense of Godot + Python written by a human expert over weeks: the honest framing is
  *anything inside the kernel's envelope, with the envelope growing by verified jobs*

The binding constraint is **authoring time and quality iteration, not rendering**: the owner's last 3D spike
rendered a 428k-tri street with 3.49 M primitives, 667 draw calls and 846 MB VRAM at p99 3.56 ms at 1440p on this RTX 4090 **[measured]**,
while one rigged character took 30-70 min and 10-20 look-and-fix rounds, and the first pass was judged "undercooked" **[measured]**.
So every design choice below is about reducing authoring cost per unit of player value and making quality checkable by machine.

## 2. The central idea

The game engine is a **compiler target for LLM-authored, machine-verified artifacts**.
The LLM never "plays the engine"; it writes packs (data + scripts + asset generators) against a narrow, versioned API, and a verifier
decides whether they are real. Three disciplines make that work: contracts before code, verification as the product, and a closed
perception loop (render, look, fix).

## 3. Stack (decided in the spark; alternatives were rejected with reasons in the idea note)

| Layer | Choice | Why |
|---|---|---|
| Game host | **Godot 4.7.2 + Jolt**, GDScript | Owner already runs a headless Godot+Blender pipeline; fast edit-run loop; runtime pack loading; open formats. Rejected: Bevy (compile loop), web/three.js (ceiling), Unreal/Unity (closed, heavy) |
| Asset generation | **Blender-Python + GDScript generators** to GLB, parametric kit parts, shared rigs | An LLM writes scripts reliably; scripts are diffable and re-runnable. Generative image-to-3D (TRELLIS.2/Hunyuan3D, local) is held back: no evidence of rig-ready topology **[unverified]**, and rigged/animated/gameplay-bound assets are the hard case |
| World law | **Material/law tables** (JSON/Resource), objects tagged with materials | Cheap, art-style-agnostic, checkable. Voxel substrate rejected |
| Orchestration ("Foreman") | **Node/TypeScript process** beside the game, local JSONL job log + localhost socket | Spawns Claude Code CLI headless or Messages API; owns the job graph; the game only *renders* its state. Independent of game crashes and of the LLM transport |
| LLM transport | `Builder` interface, two adapters: **Claude Code CLI headless** (agent loop, file tools, subscription), **Messages API** (own loop). Spike drives the CLI first | Registry: `agent-cli-transport`. Subscription use inside a *shipped service* is a terms question to verify before any service, not assumed |
| Verification | headless Godot runners + bot playtests + VLM critique | see section 5 |

## 4. Layers and mechanisms

```
 L5  World + Construction Site   renders job-graph state; milestone checkpoints; player comments
 L4  Foreman                     Designer -> Planner (job DAG, contracts first) -> Builders -> Verifier -> Promoter
 L3  Packs                       pack.json + scripts/ + data/ + gen/ (asset generators) + tests/ (bots) + examples/
 L2  Kits + style                parametric parts (wall, truss, rib, road, rink, chassis, bot, biped), style.json tokens
 L1  Law kernel                  materials, surfaces, contacts, damage/fracture, vehicles, characters, AI libs, rules engine, cameras, VFX/audio presets, UI widgets, API surface
 L0  Host                        Godot + Jolt, deterministic fixed-step sim, headless runner
```

- **L1 kernel**: laws are data tables (density, friction, restitution, hardness, flammability, sound set, breaks-into) and primitives
  (vehicle controller, skater/biped controller, puck/ball, projectile, trigger, spawner, score/timer/win state machines). It also ships
  **procedures and examples**: seed packs a builder learns from by analogy. Seeds must be **disjoint from the test games** (a ball-and-paddle game,
  a drive-around vehicle sandbox, a destructible wall) so that hockey and racing are honest tests.
- **L2 standard rigs + motion library**: biped (Godot humanoid bone names), vehicle, small bot; retargetable clips plus IK/procedural layers.
  Builders pick, parametrize and skin; they do not author skeletons. A "new rig family" is a gated, slow ticket (stub only in the spike).
- **L3 pack**: unit of build, promote and rollback. Manifest declares `kernelApi` version and requested capabilities. Packs are namespaced; the world
  holds promoted packs only. Builds happen in a **separate build workspace (the construction site)**, never in the live world.
- **API fence** (decision: full GDScript inside a fence): the fence is **lint + a wrapped API + a watchdog**, not a security boundary: GDScript in the host
  process can still reach the OS. It guards against LLM mistakes (runaway loops, writing the world, calling OS/network), which is the right threat model
  for a single-player product; it must be re-done as a real sandbox (separate process) before any sharing or service. Because freedom is high, composability is
  measured by **bypass count** (kernel primitives a pack re-implemented in script) and lines of pack script, not only by a clean kernel diff.
- **L4 Foreman** follows the same method as this very design loop: a Designer conversation yields a brief (game rules, arena, AI, controls, art mood, an estimate);
  the Planner cuts a **job DAG of packages with wire-level contracts** (names, types, enum values) so parallel builders cannot drift;
  builders run per package with their own scratch workspaces; the Verifier decides; failures return to the planner as first-class reports. Jobs are idempotent,
  checkpointed and resumable across rate limits, with a **budget policy** the player sets (tokens/hour, only while playing, overnight).
- **Builder transport contract** (registry `agent-cli-transport`, read in full for the golden path): every adapter implements `probe()` (installed, version, authorized, proven through the
  same spawn door and environment as the real call, without spending tokens where possible) and `run({prompt, mode, cwd, schema?, model?, timeoutMs}) -> {ok, text|json, raw, durationMs}`;
  the prompt goes over stdin, never argv; failure is a typed outcome. Consequences for Third Life:
  (1) **modes are separate seams**: `generate` (Designer/Planner/VLM critic: no workspace, neutral cwd), `readonly-scan` (the critic reading a pack), `edit` (a builder inside its package workspace, with
  explicit consent and a per-call bash allowlist derived from the verifier's own commands, not hand-written);
  (2) **timeouts are ours and explicit**: builds run for hours, CLIs impose their own ceilings and idle budgets, so the Foreman sets every ceiling itself and a truncated answer must never read as a failed one;
  (3) **capabilities are dated data** (a matrix of output formats, schema support, sandboxing, ceilings per tool version and date), not constants;
  (4) **auth is the economics and it is ambient**: an API key sitting in the environment can silently move a build from the subscription to per-token billing, so the player sees which billing is in force
  before a job starts and the probe runs in the real environment.
- **L5 Construction Site**: builder bots and blueprint holograms are a *rendering of real job state*, never fake progress. At milestones (blockout, greybox playable,
  art pass, tuned) the Foreman posts screenshots/clips; the player can walk the site, comment, redirect, and affected packages re-plan.

## 5. Verification stack (the product)

"A builder said done" is not evidence (registry: `completion-claim-verification`). Promotion needs all of:
V0 manifest/schema valid; V1 lint (banned APIs, capability check, size limits); V2 headless load + 60 s smoke with a watchdog and zero script errors;
V3 invariants (nothing below ground, frame-time and entity budgets, determinism: same seed gives the same result); V4 **bot playtest** completes the game
(a hockey match to full time, a race lap) with consistent scoring; V5 scripted camera captures + VLM critique against a rubric (silhouette, readability,
consistency with `style.json`); V6 human milestone. V4/V5 can verify *completion and legibility*, not *fun*: the human checkpoint stays.

## 6. Principles

1. Contracts before code; builders return questions, not guesses.
2. Verification is the product; every pack ships its own bot and invariants.
3. Don't make the LLM do what a library can: motion, physics, steering, UI come from the kernel; the LLM composes and writes glue.
4. Style is global data; asset budgets (tris, bones, materials) are linters.
5. Look at the output: render, view, fix, repeat. A single pass is undercooked **[measured]**.
6. Build in the construction site, promote verified packs; world state is never a builder's scratch space.
7. Truthful time, resumable jobs, visible budgets; no fake latency.
8. Kernel growth is a separate gated job type with its own tests; "kernel gap" is recorded, not hidden.

## 7. Risks, ranked

| # | Risk | Evidence / mitigation |
|---|---|---|
| R1 | Asset + animation quality and time | measured 30-70 min/asset; mitigate with kits, standard rigs, loops, art lanes B/C testing it now |
| R2 | API surface sprawl vs expressiveness; with full GDScript freedom, consistency drifts | bypass-count metric, lint, kernel versioning, seed examples |
| R3 | "Fun/feel" cannot be machine-verified | milestone checkpoints; bots only gate completion and legibility |
| R4 | Runtime observation loop for the LLM (errors from a running game) | the headless runner returns structured logs, captures and telemetry per round; ecosystem still immature **[unverified]** |
| R5 | Subscription/CLI terms for a service; transport churn | `Builder` interface; verify terms before service; spike is personal use only |
| R6 | Latency expectations (hockey in hours, not minutes) | truthful construction site and budgets turn latency into the product loop |
| R7 | Kernel under-built for racing, so S2 fails | that *is* the finding; S2 reports gaps as data, not as a failure to hide |
| R8 | Scope creep to "anything" | the envelope list in section 1 is the contract |

## 8. Sources (unverified; vendor blogs, directories and SEO pages: treat as signals)
- Godot MCP + Claude Code ecosystem: [StraySpark setup guide](https://www.strayspark.studio/blog/godot-mcp-setup-claude-code-2026), [Claude for Godot (Summer Engine)](https://www.summerengine.com/blog/claude-for-godot), [Coding-Solo/godot-mcp listing](https://enterprisedna.co/directories/mcp/coding-solo-godot-mcp). They agree editor/scene operations are mature and a live runtime error loop is the open frontier.
- Open 3D generation: [state of AI 3D generation 2026](https://3daistudio.com/state-of-ai-3d-generation-2026), [open-source 3D generators](https://www.cmarix.com/blog/top-open-source-ai-models-for-3d-image-generation/). TRELLIS.2 (MIT) and Hunyuan3D lead; no evidence on rig-ready topology; licences disputed, verify before relying.
- Measured evidence: `gtai-3d-spike/docs/STATUS.md` (cost log, perf), `gtai/docs/perf/LEDGER.md`; registry subjects `fleet-orchestration`, `agent-cli-transport`, `agent-runtime-assembly`.
