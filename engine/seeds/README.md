# How to write a pack (ten minutes)

A pack is one small game in one directory. The kernel loads it, runs it at 60 physics frames per second and
verifies it. This page plus `engine/kernel/API.md` and the three seeds here are all you need.

| Seed | Game | Read it for |
|---|---|---|
| `seed_paddle/` | ball and paddle on a walled court, first to five against an AI | ball, goals, score, a body on a rail, an AI opponent, HUD |
| `seed_drive/` | one car, three laps of a road loop against the clock, a nitro pad, cones | vehicle, a road from data, checkpoints and laps, spawner, chase camera |
| `seed_wall/` | a walker throws balls to knock a wall down in 60 seconds | biped, carry and throw, fracture and damage, effects, sound, time limit |

Each has a `README.md` with a table "need -> how -> API call". Find the seed nearest to your game and work by analogy.

## 1. The shape of a pack

```
my_game/
  pack.json          id, version, kernelApi "0.1", title, capabilities, entry, assets [], tests [..], cameras [..]
  README.md          what it is, how the bot decides it won
  data/*.json        the venue (tl.layout/1), the rules (TLRules config), the tuning numbers
  scripts/main.gd    the entry script: glue between data and kernel primitives
  tests/bot_*.gd     at least one bot that plays the game to the end
```

`capabilities` lists what the scripts use; lint tells you exactly which one is missing and where.
`cameras` lists the view names you register (`ctx.cameras.add_view / chase / orbit`).

## 2. The lifecycle

```
_pack_setup(ctx)     once. Read data, build the venue, make bodies and controllers, create rules and HUD,
                     declare input actions, register cameras. Everything goes under ctx.root.
_pack_start()        once, at frame 0. Start the rules; first seeded choices.
_pack_tick(frame)    every physics frame, after the bot pressed its actions. All game logic lives here.
_pack_state()        whenever asked. Return rules.snapshot() plus what a bot needs to see. It is hashed.
```

Three habits that the seeds follow and that save you most trouble:

- **Signal handlers set a flag or queue an event; `_pack_tick` acts on it.** A trigger or contact signal arrives
  inside the physics step, where bodies must not be created, freed or moved.
- **Time is `frame`.** `ctx.frames(seconds)` converts. There is no clock and no `_process` in a pack.
- **Randomness is `ctx.rng`** (or `ctx.pick`, `ctx.shuffle`). `randf()` and friends fail lint.

## 3. Data first

Before any script, write three files:

1. **The venue** as a `tl.layout/1` file (`res://kits/LAYOUT.md`, parts in `res://kits/KIT.md`). One call builds it:
   `var built := TLKit.build_layout(ctx.read_json("venue.json"), ctx.root)`. Give an `id` to every prop the script
   must find (`built["nodes"][id]`); take cameras from `built["cams"]` and the start from `built["spawn"]`.
   A `terrain` with one flat `pads[]` entry gives ground, forest and mountains; without a terrain there is no
   ground at all and you must bring a `ground_patch`.
2. **The rules** as a `TLRules` config: sides, `score_to_win`, `laps_to_win` and `checkpoints`,
   `time_limit_seconds`, periods. If your win condition fits these keys you write no rule code.
3. **The tuning**: every number a designer would turn. Controllers take their tuning members as options, so a
   dictionary from JSON can be passed straight into `TLVehicle.create(opts)` or `TLBiped.create(opts)`.

**Kit first, boxes second, materials never.** Everything you can see in the seeds is a kit part or a rig. A shape
the kit does not have (a ramp, a chute, a rail) is `TLBodies.make(&"box", size, "wood", {"color": Color(...)})`: the
kernel gives it the style's toon material from the material id or from `color`. Do not create a
`StandardMaterial3D`, a `MeshInstance3D` with your own `BoxMesh`, a light, a sky or a `WorldEnvironment`: the first
real job built a whole marble run that way and it came out near-black and flat. A pack that builds no venue at all still
gets sun, sky and a ground to the horizon, but that ground is a picture: bring a floor with collision.

What kit parts become in the kernel:

| The layout gives you | You call | You get |
|---|---|---|
| any part with collision (floor, wall, house, tree) | nothing | a static body with friction and bounce from the law table |
| `ball`, `puck` (no body) | `TLBall.create({"part": node, ...})` | a ball with shoot, hold, release, signals |
| `paddle` (no body) | `TLBodies.from_part(node, {"lock": [...]})` + `TLBodies.drive` | a body you move under control |
| `barrier_wall`, `crate`, `walls[]` | `TLFracture.attach(node, {...})` | a part that breaks into pieces |
| a circuit | read `tl_centre_line` from `nodes[id]` | a path for placing things and for `TLSteer.keep_lane` |
| nothing (characters and cars are not layout props) | `TLBiped.create`, `TLVehicle.create` | a controller with the real rig |

## 4. The verbs, in this order

```
bash engine/tools/tl.sh lint       --pack=<dir>     fence, capabilities, sizes; "bypasses" should be []
bash engine/tools/tl.sh smoke      --pack=<dir>     3,600 frames with no input: zero script errors
bash engine/tools/tl.sh bot        --pack=<dir>     your bot plays to the end; exit 0 only if it says ok
bash engine/tools/tl.sh invariants --pack=<dir>     same seed twice gives the same state_hash, idle and with your
                                                    first bot playing (invariants.bot_deterministic); budgets
bash engine/tools/tl.sh capture    --pack=<dir> --cam=<name> --frame=<n> --test=tests/bot_x.gd --out=<abs.png>
bash engine/tools/tl.sh play       --pack=<dir>     a window and real keys (not a verify verb)
```

Run `lint` after every edit (it takes a second and reads text only). Run `bot` with `--seed=2` and `--seed=3` too.
Look at the captures: a game can pass every verb and still show nothing on screen.
`bash engine/tools/seeds.sh` runs all of this on the three seeds.

## 5. Writing the bot

A bot is a player that reads `ctx.pack_state()` and presses the declared actions (`ctx.input.press`, `release`,
`tap`, `set_axis`). It never touches a node. So decide first **what the state must contain for somebody to play
blind**: positions, facings, what is held, what is next. If your bot needs a number, put it in `_pack_state()`.

`_bot_result()` returns `{"ok", "summary", numbers...}`. Decide `ok` from the rules (`state`, `winner`,
`reason`) plus one or two facts that prove the mechanism really ran (the pad was visited, a block broke, the HUD
shows the result). Put measured numbers in the summary: it is what a reviewer reads.
A bot that is not done within `--frames` fails (exit code 1).

## 6. Ten mistakes made while writing these seeds

1. **A bot variable named `scores`, and later one named `laps`.** Lint counts any variable whose name starts with
   score, clock, timer, period or lap as a hand-rolled rule (a bypass), also in a bot. Read them from the snapshot
   into other names (`tally`, `rounds`).
2. **An opponent that could not lose.** The first paddle rival moved at 3.6 m/s: after 20,000 frames the game stood
   at 0 : 0 with a rally of 276 hits and the bot never finished. Make the difficulty one number in data and lower it
   until the bot wins with a margin.
3. **A look-ahead too short to brake.** Steering toward a point 9 m ahead also told the bot about a bend only 9 m
   before it: at 19 m/s the car ran wide and left the road. The pack now gives two points: one near to steer by,
   one that grows with speed to slow down by.
4. **A button with no hysteresis.** "Nitro while the road is straight" switched on and off 254 times in one run.
   Start on one threshold and stop on a wider one.
5. **Things that leave the venue.** A shot that went through its target rolled off the floor and fell; a skater
   kept gliding off the end of the ice. Both failed `invariants.below_ground` (nothing below y = -50). Add a
   backstop, a brake, a despawn, or a terrain under everything.
6. **A bot that saw the end before the pack did.** The rules ended inside `_pack_tick`; the pack handled its queued
   "finished" event one tick later; the bot, which runs first in a frame, saw `over` in between and reported a HUD
   that had not changed yet. Act on queued events as the last step of `_pack_tick`.
7. **A win target with no margin.** 44 of 48 pieces passed at seed 1 and scraped through with exactly 44 at
   seed 2. Try several seeds and leave room.
8. **A seed that changed nothing.** Two of the seeds first drew from `ctx.rng` only after player input, so
   `smoke` (which presses nothing) gave the same hash for every seed. If the seed should matter, draw something at
   set-up or at the first serve.
9. **Effects on every contact.** A dust burst on every ball bounce covered the yard in particles. Fire effects on
   the events that mean something (a hit on the wall above a speed), and tint them from the scene.
10. **An assertion from a guess.** A check "top speed above 15 m/s" failed because the car reaches 10.4 m/s in the
    two seconds the test gives it. Run once, read the numbers, then write the threshold.

Three from the first real job (a marble run built by agents from one sentence):

11. **Every shape from `BoxMesh` and `StandardMaterial3D`.** Nothing had told the builder about the kit, so it made
    its own meshes, materials, sun and environment. Use `TLKit.build_layout`, kit parts and `TLBodies.make` with
    `color` (section 3).
12. **`set_script` after `add_child`.** A generator added a node to `ctx.root` and attached its script afterwards:
    the script's `_ready` and `_physics_process` never ran, no error was printed, and the whole "look" package did
    nothing. Attach the script first, or better keep the work in `_pack_setup` and `_pack_tick`. The runner now
    says so: read the `smoke.loads` detail for `WARNING:`.
13. **A generator that dresses what does not exist yet.** `gen/*.gd` run before `_pack_setup`; they cannot find
    the nodes the entry builds later. Dress things where you build them.

Two more that cost nothing only because they were looked up first: a thrown ball does damage only above the
target material's threshold (8 kg at 19 m/s is 150 N*s; concrete takes 260 N*s before any damage, so the seed sets
`threshold` in data); and a kit `cone` is static scenery, so a cone the car may knock over has to be re-tagged
as a dynamic prop (`seed_drive/scripts/main.gd`, `_loose_cone`).
