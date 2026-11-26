# Two worlds: the Home and the Dungeons

> Status: design, 21 Nov 2026 (night shift `2026-11-21-night`, spark `designer-and-two-worlds`). Nothing in "The Home" is
> built yet. "The Dungeons" v1 was built tonight (lane L4, main d0d0bd9). Owner decisions are marked **[owner]**; the Director's
> proposals are marked **[proposal]** and wait for the owner. The open questions are at the end.

## The principle

Third Life has two kinds of place, made with one kernel.

| | The Home (main world) | A Dungeon |
|---|---|---|
| What it is | The player's own land: a sandbox and a tycoon, where the player is the creator | One game or level, sealed off: a hockey arena, a colosseum, a racing circuit |
| How long it lives | Persistent. It grows over weeks, and it is saved | A run. A seed, play, a result. Its design persists; a round of play does not |
| Who shapes it | The player, friends, and AI residents | The Designer and builders (phases), then the player plays it |
| Physics | The world's laws: gravity, 60 Hz, Jolt | The world's laws by default **[owner]**. It may declare its own (below) |
| Look | Crisp cel, the house look **[owner, 20 Nov]** | Any look the engine can do: a `TL_STYLE` per dungeon **[owner]** |
| Player | The walker: a body, a camera and the world's HUD | Transformed into the dungeon's avatar, with its camera and HUD; the walker is gone **[owner]** |
| How you get in | Boot → menu → World | Menu → Dungeons **[owner]**. Later, also a portal you build in the Home |
| Proof law | A game placed in the world plays as it does alone (`world` gate) | A dungeon hashes as its pack alone (L4's 64x selftest) |

**What crosses between them, and what never does.**
- **Crosses:** the player's identity, a dungeon's result (score, trophy, best moment) going back to the Home, and a
  resident borrowed as a character (as a copy).
- **Never crosses:** the Home's live state into a dungeon (it would break the dungeon's hash), and a dungeon's live state
  into the Home.

The Home can be infinite because nothing in it has to be a game. A dungeon can be anything because nothing in it has to
fit the Home.

## The Dungeons (built 21 Nov, L4: d0d0bd9)

- **The menu.** The exe opens on World / Dungeons / Create / Quit (`engine/boot/hub.gd`, `menu.gd`). Esc in the world
  goes back to the menu. Every verb, flag, headless start and `TL_EXE_*` setting still goes straight to the village, as
  before (selftest 640 checks 19 of those decisions).
- **Its own scene.** The world is never loaded with a dungeon: the menu sits between them. Leaving the world frees the
  viewer, the world, its hint layer and its logger. Measured in a window: nodes 2869 → 33, video memory 897 → 629 MB.
  Three round trips add 10 objects and 0.09 MB.
- **The transform today:**

| Part | What it is today |
|---|---|
| Body | the pack's own player (hockey's skater, parkour's runner, the paddle); the kernel lends no avatar yet |
| Camera, HUD | the pack's `TLCameras` views and `TLHud` layers, exactly as `tl play` shows them |
| Look | the list's `look`, loaded with `TLStyle.load_style` on entry, with the default restored on leaving; sky, sun and post installed under the dungeon's node and freed with it |
| Interface | the menu, the load screen and the pause card (Resume / Leave), drawn by the kernel in the crisp 2D look |
| Physics | the kernel's laws and gravity, the pack alone |

- **Proof law held.** A counted `--dungeon --frames=N` run hashes exactly as `worker --mode=play`. This was checked for
  hockey, parkour and the paddle court, both in the exe and in the editor binary (`export.sh check` step 1b).
- **The list and the flag.** The list is `engine/boot/dungeons.json` (`tl.dungeons/1`, contracts/README.md), holding
  hockey (crisp), parkour and the paddle court. `--dungeon=<pack dir>` opens any pack, including a job's work in progress.
  An exported dungeon must be one of the exe's games.
- **Try it.** The Create page starts a second process: `dungeons.gd` `launch(dir)` runs the same executable with
  `--dungeon=<dir>`, and the child's pause card says "Back to Create". A runaway work-in-progress pack can only hang the
  child. A watchdog for it is being built tonight (L4b).

- **A made game is a dungeon.** Tonight's two proof jobs started from the same vague sentence, "a fight in a colosseum".
  The Designer v2 wrote a standard and a crazy brief, and the Foreman built them in 4 and 5 phases. Both promoted packs
  open with `--dungeon=<job>/promoted/game.fight_colosseum`: 900 frames, 0 script errors, crisp look. So the loop from
  sentence to dungeon (Create → phases → Try it → Play) runs end to end without the Home. Getting into the Home
  is the portal's job (item 4 below).

**Next [proposal]:**
1. **An optional `dungeon` block in `pack.json`** (`contracts/PACK.md`). L4 proposed it and the Director extends it.
   Nothing in it reaches the hash, and `dungeons.json` stays the menu's list (which packs, in what order, with which
   title). Fields:
   - `look`: a `TL_STYLE` name. The list's `look` overrides it.
   - `avatar`: `own` (the pack's player, as today) or `walker`. With `walker`, the kernel lends the Home's walker as
     `ctx.avatar`, so you can be "the Home's person in another place".
   - `stills`: up to 3 menu pictures.
   - `pause`: `kernel` (the default card) or `pack` (the game's own pause screen, which must offer Leave).
   - `laws`: a gravity scale, plus any of the pack's `TLLaws` (item 2).
   - `results`: the keys a run reports back (item 3).
2. **Own laws.** Gravity is global today (`kernel/world/pack.gd:172-175` copies `ProjectSettings`), but each pack already
   has its own `PhysicsServer3D` space. Space gravity is a space parameter, so the kernel can set a dungeon's declared
   gravity on its space. Pack scripts still never touch `PhysicsServer3D`. A low-gravity arena costs one manifest key.
3. **Results back to the Home.** When a dungeon ends it emits `results` (`{score, won, best, frames}`). The Home shows
   them at the dungeon's portal: a trophy shelf and a leaderboard board. This is the only state that crosses.
4. **Portals.** A portal is an item in the Home's Venues layer that points to a dungeon. Walking in is the same as picking
   it from the menu. Plots that run a live game in the Home (today's village) stay possible for small games. A big arena
   is a portal.

## The Home: a canvas 100 times larger

### Where it is today
- **One terrain mesh,** with a 3 m cell. It is built once, at load, sized to the plots plus 110 m: 696 × 612 m
  (0.43 km²), 47,765 vertices and 88,812 collider triangles, 0.5 s to build (`landscape.gd:119-128`).
- **Plots** are hand-placed circles in a walk JSON (`engine/boot/village.json`), each on a flat pad.
- **Colliders.** Every pack's static colliders are copied into the visitor's space (sliced per arrival since P14).
- **Tiers** (stage, sideline, backdrop, ledger) already give distance-based simulation. `ledger`, which unloads a pack and
  keeps its summary, exists but is off (`backdrop_m` 0).
- **Saving.** `PlotFile.save` exists, but the exe never saves.

100x is about 43 km², roughly 6.5 × 6.5 km. Nothing about the single mesh survives that, so the land is chunked.

### 1. Chunked streaming terrain **[proposal]**
- **Chunk.** 96 × 96 m: 32 × 32 cells of 3 m, the cell the terrain uses today. A 6.5 km map is about 68 × 68 = 4,600
  chunks.
- **Source of truth per chunk:** `tl.land/1`, holding:
  - heights (u16, quantised);
  - a material id per cell;
  - the water level set.
  It is a sparse delta over a procedural base made from the world seed. Untouched land costs nothing to store, and a
  player's sculpting is a delta.
- **Rings around the camera:**

| Ring | Radius | Mesh | Collider |
|---|---|---|---|
| near | 2 chunks (~200 m) | full | Jolt `HeightMapShape3D` per chunk, in the visitor space |
| mid | 6 chunks (~600 m) | half-resolution LOD, skirts against cracks | none |
| far | the whole map | one low-res impostor heightfield, rebuilt rarely | none |

- **Build budget.** A chunk's mesh and collider are built off the main thread. They are swapped in within a per-frame
  budget of about 2 ms, counted in frames, never as a wall-clock condition. Arrivals keep P14's slicing.
- **Determinism.** The land is static between edits. A pack's hash never sees the land: a pack brings its own ground,
  WORLD.md ruling 3. The `world` gate keeps meaning what it means.
- **Lots instead of circles.** Grading follows a lot's footprint polygon (card `footprint`, the job's `lot`), so the owner's
  E1 complaint about a circle that does not match the terrain is solved by construction. Tonight's L1 B2 does this for the
  site fence.
- **Games at scale.** With hundreds of venues, `ledger` turns on: beyond `backdrop_m` a game is unloaded and only its
  summary is kept. The 1/16 floor stays **[owner, 11 Nov]**.
- **First step that changes nothing visible:** chunk today's village with the same heights. Proof: the same pictures (a
  noise floor), the same hashes, and load time measured.

### 2. Build layers **[proposal]**
The Home is a stack of layers. Each is edited, saved, undone and shared on its own, and each has its own owner rights.

| # | Layer | What it holds | Edited with | Saved per |
|---|---|---|---|---|
| 0 | Land | heights, ground material | sculpt, paint | chunk (`tl.land/1`) |
| 1 | Water | rivers, lakes, sea level | draw, flood | chunk |
| 2 | Paths | roads, trails, bridges (splines) | draw | region |
| 3 | Structures | kit parts placed freely, grouped into *builds* | place, snap, group | chunk (builds are items) |
| 4 | Life | plants, scatter, growth rules | paint, seed | chunk |
| 5 | Residents | AI characters, their homes and routines | the Designer ("populate") | world |
| 6 | Venues | game plots, dungeon portals, boards | the Designer (Create), place | world |
| 7 | Sky and mood | time of day, weather, music, the look's knobs | sliders | world |

- **Placement.** Today's `TLKit.build(kind, params)` and the `tl.layout/1` JSON already describe parts and a venue. A
  build is a `tl.layout/1` with a transform, so the layer reuses the kit as it is.
  - Free placement snaps to 0.5 m and 15° by default; a key frees it.
  - Each chunk draws a kind of part as one MultiMesh, so 10,000 fence posts cost about as much as one.
- **Limits per chunk** (not per world), so the world can grow: today's layout caps (props 600, trees 200) become
  per-chunk caps.
- **Colliders** of the Structures layer are built per chunk, the same way as the land's. Tonight's L1 per-part kit
  colliders are the shapes they use.
- **Sharing** maps to `docs/SHARING.md` items:

| Shared thing | Item kind |
|---|---|
| a build | `kit` / `venue` |
| a look | `look` |
| a region of land with its layers | `world` |

- **Undo.** Each layer has its own history, so "undo my last building" never undoes a friend's river.

### 3. AI residents **[proposal]**
- **What a resident is:** `{id, name, role, home, traits, routine, memory, voice}`. For example: a harbour master who is
  grumpy before noon, a kid who races you at the circuit.
- **Two-speed mind:**
  - **Body** (every frame, deterministic): walking (`TLBiped` and `TLSteer`), routines (be at the harbour at 06:00,
    world time), needs and simple reactions. It runs only in the near and mid rings; far residents move on their
    schedule only, the ledger tier for people.
  - **Mind** (rare, LLM, asynchronous): a daily plan at dawn, a conversation when the player talks to them, and a reaction
    to a big event (a new venue, a trophy). Its output is data: a plan JSON, a line of speech, a change of mood. The body
    then carries it out.
- **Determinism.** The mind's outputs are logged, so replaying a day replays its outputs instead of calling the model. No
  resident is ever inside a pack's hash.
- **Cost:**
  - a budget of mind calls per world-day, set by the player;
  - an offline fallback: the routine runs with no mind;
  - the call ledger in `tl ledger`.
- **Authoring.** "Populate" in the Designer: "a fishing village with a grumpy harbour master" gives a roster. It uses the
  same aspect cards as a game (who, what they do, the twist).
- **Into dungeons, as a copy.** A dungeon can take a resident as a rival or a commentator (a copy of name, look and
  traits), so your neighbour can be the goalie. The dungeon never writes back.

### 4. Friends visiting **[proposal]**
- **Host-authoritative.** The host's machine runs the Home.
  - Visitors get the layer files by content hash (cached, so a second visit costs little), snapshots of residents and
    avatars at about 10 Hz, and chat.
  - Visitors predict their own walker.
- **Rights per layer.** A visitor may walk, talk, and play venues and dungeons. Building happens only on a guest lot, or on
  a layer the host grants ("you may plant trees").
- **Shared dungeons: lockstep.** Determinism makes this almost free. Same pack + seed + inputs = same hash, so 2-4
  players exchange inputs with a small delay, each machine runs the dungeon, and the hashes are compared as a desync
  check.
- **Prerequisite.** Code items cannot be shared with others until a pack runs in an isolated process (`docs/SHARING.md`;
  the `kernel/proc/` spike is not on the game path). The isolated process comes first, then friends.
- **Transport:** Steam networking first, matching SHARING.md's Steam Cloud first.

## The sandbox: building by hand and by LLM [owner, 26 Nov]

Decided with the owner on 26 Nov 2026 (spark `world-sandbox`, `.spark/Spark/ideas/world-sandbox.md`). It refines
"Build layers" above. The owner's direction: "combine LLM building together with extend of voxel/block layer which may
be more abstract/higher level than roblox or minecraft. Players without investing to LLM would be able still to play
and build custom creations, players with connected LLM would access the highest potential of this app".

- **One world, four units:**
  - **land**: the heightfield, sculpted and painted;
  - **blocks**: 1 m smart blocks, shape x material, that join their neighbours (stairs and roofs form corners, fences
    connect);
  - **pieces**: kit parts snapped onto cells;
  - **stamps**: saved groups, shared as items.

  Blocks sit on the land. There are no caves: "Voxel substrate rejected" (FEASIBILITY.md) still holds for world law,
  and blocks are a building layer over it.
- **One edit log, two authors.** Every change is a `tl.edit/1` operation with `author: hand|llm` in a batch
  (`contracts/BUILD.md`). An LLM job returns a batch shown as a ghost, and the player accepts it, adjusts it by hand or
  reverts it. Without an LLM, every tool works.
- **Creative, with unlocks from play.** Building costs nothing. Dungeon results (trophies) unlock materials, shapes and
  stamps.
- **One Home, autosaved** in `user://home/`.
- **Rights.** The player may change land and their own builds. The valley's authored structures and the game lots are
  protected.
- **In-world building.** B toggles build mode: the cursor is free, a ghost block follows it, and the hotbar picks the
  shape and material. Walking and F flight stay.

| Milestone | What | State |
|---|---|---|
| M1 | edit log, autosave, build mode, 1 m smart blocks with per-chunk mesh and collider | building (26 Nov) |
| M2 | land sculpt and paint: the valley onto editable `tl.land/1` (its 12 m mesh and 96 m colliders do not use it yet) | next |
| M3 | pieces (kit parts on cells) and stamps as items; unlocks from dungeon results | |
| M4 | the LLM command bar: a sentence at the cursor becomes a Foreman job that returns a `tl.edit/1` batch as a ghost | |
| M5 | water, paths and plants (layers 1, 2 and 4) | |

## Order of work [proposal]
1. **Dungeons v1** (done 21 Nov, L4 d0d0bd9): the menu, the dungeon scene, `--dungeon`, hockey as the first one.
2. **The `dungeon` block in PACK.md and results back**: the trophy shelf at a portal.
3. **Chunk today's village with the same heights**, and turn `ledger` on (proof: the same pictures and hashes).
4. **Lots as footprints and free placement**: the Structures layer, saved per chunk. The exe saves the Home.
5. **The Home grows**: a procedural base outward from the village, plus sculpt and paint (Land and Water layers).
6. **Residents v0**: the body with routines, no mind. Then v1: the mind with a budget.
7. **The isolated process for packs**, then friends visiting (read-only walk), then shared dungeons (lockstep).

## Open questions for the owner
1. **The Home's shape.** One continuous land of about 6.5 km, or islands joined by roads, boats or flight? Islands make
   streaming and sharing simpler, and a region is one item.
2. **Single-player first.** Is the Home single-player and persistent first, with friends after the isolated process (the
   order above)?
3. **Residents' cost policy.** Who pays for minds when nobody is watching: no calls while the player is away, or a small
   nightly budget so the village "lived" overnight?
4. **Guest building.** Do friends build only on a guest lot, or with rights the host grants per layer?
5. **Small games in the Home.** Do today's village plots stay as live games in the Home, or does every game become a
   dungeon behind a portal, with the Home only showing its trophy and a still?
