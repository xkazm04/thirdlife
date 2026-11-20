# Character Astra · builder's report

The diorama biped is a code-sculpted, painted toy. I chose the existing rig because the board's most recognizable shapes are the two locks of hair above a raised collar and the stack of jacket, turnups and boots visible from behind. These shapes can be built once on the game's skeleton and recoloured by every pack. A new game still uses its usual TLBiped.create call and palette names. There is no character asset, import or material work per game.

## What the player sees

- The walker has an asymmetric brown crown and fringe, a split red collar, a back yoke, cuffs, brass snaps, blue trousers, pale turnups and rolled boot soles. The finish uses shallow fingerprints in the clay and small patches of exposed undercoat at worn edges. Look at the rear, front and side in `.tl/astra/final.jpg`. See `poses.jpg` in the same folder for running, takeoff, landing and sliding.
- Parkour keeps the blue jacket its pack chooses. Hockey keeps the teams' palette choices and fits the helmet, ear guards, mittens, skates and two-handed stick grip. I checked actual gameplay at parkour frames 520 and 987 and hockey frame 1500 in `.tl/astra/gameplay/`. The rink close-up is `.tl/astra/v3-hockey-1.png`.
- The hair and collar settle on the fixed physics tick. The idle pauses to glance across the path. A running jump keeps the boot that was ahead at takeoff as the leading knee in the air. The ledge, bar and hockey stick supply targets for the hands. The wings attach at the existing back socket. See `.tl/astra/wing.jpg` and the motion checks below.

## Verification

| Check | Observed result | Builder evidence under .tl/astra |
| --- | --- | --- |
| Geometry and contract | 12 wardrobes counted from actual mesh indices and vertices, including stowed tools. 9,520–11,388 triangles, 29 bones, the same ordered bone names and 20 clip names as classic, height 2.0 and radius 0.3 at unit scale. Runtime recolouring and restoration passed. | character-final.log |
| Grip and transitions | Largest measured palm error after grab acquisition was below 0.00001 m in the rotated, scaled ledge and bar fixture and the skating stick fixture. The leading knees at four stride phases matched their takeoff feet, R/L/L/R. Real visitor and pack wrist-to-support readings were 0.080 m at the ledge and 0.081 m at the bar. The wrist sits behind the mitten's grip point. | character-final.log, test-moves.txt |
| Classic image | Compared 12 corresponding RGB frames from the same fixed-tick front review, 1920 × 1080, recorded before and after. Maximum channel difference 0/255. Differing pixels 0. | classic-final-diff.txt |
| Fast suite | PASS, 5/5 steps and 248/248 counted units, including architecture, assets and API checks. | fast-final.log |
| Required full-tier subset | PASS, kit.selftest 95/95, packs 2/2 with 48/48 verb runs, world 8/8. | character-gate.log |
| Baseline hashes | All eight world digest/tick pairs matched the operator's clean archive of diorama-base in this worktree. All 46 pack runs that emitted a state hash matched the baseline's full digest. The two lint runs complete the 48. | pack-hash-compare.json, world-hash-compare.txt |
| Character and style suites | rig. 14/14, moves. 14/14, flight. 13/13, wings 2/2, style. 3/3, character.clay 1/1. The summoned wings span 4.39 m with 17 parts and 1,236 accessory triangles. Rig sole slip averaged 0.067 m/s moving forward at 4.5 m/s. | rig-final.log, test-moves.txt, test-flight.txt, test-wings.txt, test-style.txt, character-final.log |
| Windowed tour6 | Classic GPU 1.304 ms and frame p50 2.925 ms. Diorama GPU 1.205 ms and frame p50 2.835 ms. Both drew 371 calls. The machine reported BUSY at 73% and 70% utilization. | perf-classic.log, perf-diorama.log |

For the budget and palm check, run `bash engine/tools/selftest.sh character.clay`. For the close-up without the optional satchel, pass `--backpack=0` after the review scene's `--`. The classic comparison used the ordinary wardrobe, `--view=vfront --speed=0`, at 60 fixed ticks per second.

## Broader full tier and timing

The broader `check --tier full` returned FAIL. World passed 8/8, seeds 39/39, item 91/91 and UI 166/166. Foreman reported 217 passed and six skipped. The kernel harness reported Windows EPERM on its temporary directory at its 30-minute limit. Hockey's many-pack invariant measured 1.003 ms against 1.000 ms. The aggregate perf gate measured at 89% utilization and recorded NOT RUN. See `.tl/astra/full.log`.

On the first isolated world/packs retry, world passed 8/8 and hockey measured 1.163 ms, leaving packs at 47/48 verbs. The operator's clean base also missed that budget at 1.132 ms. I timed just the six constructed skating rigs in a separate fixed-step run to isolate the character hot path. Classic medians ranged from 241 to 278 µs for the team and diorama medians from 224 to 232 µs across the stationary and moving samples. See `.tl/astra/worldpacks-retry.log`, `.tl/astra/rigbench-before.log` and the clean-base result in STANDUP.md.

Running the kernel script directly to its own trailer completed **326 passed, 0 failed**, including character.clay. The complete output is in `.tl/astra/kernel-direct.log`. The full-tier wrapper keeps its recorded FAIL. Opus has the shared .tl/gate-packs directory for the independent verification.

## Changed files

| Path | Change |
| --- | --- |
| engine/rigs/biped/clay_form.gd | Builds the indexed skin from sculpted cross sections and stores the palette and material inputs on the mesh. |
| engine/rigs/biped/clay_biped.gd | Sculpts the head, clothing, limbs, boots and optional wardrobes. |
| engine/rigs/biped/clay_rig.gd | Fits the wardrobe, poses, stick and secondary motion into the existing biped lifecycle. |
| engine/rigs/biped/clay_motion.gd | Implements fixed-tick settling and two-link palm placement. |
| engine/rigs/tl_rigs.gd | Selects the clay biped when the diorama style is loaded. |
| engine/kernel/api/tl_biped.gd and engine/kernel/world/visitor.gd | Pass the sensed support line to the visual rig after its animation tick. The public TLBiped signatures and controller physics are preserved. |
| engine/style/shaders/body_clay.gdshader | Shades the painted figure using palette colours and relief anchored to bind-space coordinates. |
| engine/rigs/review/review.gd | Accepts an optional backpack override so the operator can reproduce the bare-backed village walker. |
| engine/rigs/review/clay_case.gd and engine/tools/selftest.d/590-character-clay.sh | Exercise the mesh budget, palette swaps, rig contract, grip and takeoff lead. |
| Godot .uid files | Sidecars alongside the five new GDScripts and the new shader. |
| This lane's ASTRA-NOTES.md, REPORT.txt, PATCHES.md and STANDUP.md | Builder report, integration notes and milestone log. |

I checked the changed paths with git status and the tracked patch with git diff --check. The character uses the existing palette. Pack, seed and shared style data have no edits. The picture cache excludes meshes with a skin or a moving parent in the _collect_standin method of engine/kernel/world/draw/draw_pictures.gd, so this sculpt does not alter the cached stand-ins. Existing test expectations are intact.

## Where the target still wins

The rounded hair, collar and boots carry the toy silhouette at play distance. Fingerprints and chipped cuffs disappear at the rink overview and in distant flight. In the close-up, the even dark contour and front fill still make the jacket read more like a game model than the hand-pressed, side-lit reference. The clearest next comparisons are softer ink at the crown and cuffs, warm raking light on the rear yoke, and a parkour frame with the runner in focus. These belong to the frame and light passes. See PATCHES.md.

Opus owns independent gate verification, the paired shot set, character and contact sheets, clip and executable. The files under .tl/astra are the builder's working evidence.

## Round 2

I kept the code-built, skinned figure. At equal height beside board 4, the first jacket covered most of the trouser seat, the shoulders held the arms high, and the paint wear formed a thin row along the hem. Those differences were visible from the road. The existing mesh generator let me change those proportions on the same skeleton and see the result on the village visitor, the blue parkour runner and both hockey uniforms. [Board 4 beside rounds 1 and 2](../../../../../.tl/astra/r2/board-compare.jpg) · [Parkour frame 520](../../../../../.tl/astra/r2/parkour-pair.jpg)

### Changed files since round 1

| File | Round 2 change |
| --- | --- |
| `engine/rigs/biped/clay_biped.gd` | Shortened the jacket over the seat, rolled the collar and sleeve ends, and shaped the jeans across both hips. Gave the boots a thicker sole, the nape more volume and the near crown curl a thumb-pressed spiral. The smaller satchel has a bowed flap, one buckle and straps that pass over both shoulders. |
| `engine/rigs/biped/clay_form.gd` | Added the section shapes and joint weights for the curl, collar, sleeves, trousers and straps. |
| `engine/style/shaders/body_clay.gdshader` | Concentrated handling wear at one elbow, the opposite hip, the denim knee and the boot welt. Broken fingertip ridges and small nape grooves catch the light in close-up. Tuned the figure's response to the existing sky and ground colours. |
| `engine/rigs/biped/clay_rig.gd` | Lowered the resting shoulders. The head glances before the mitten brushes the jacket pocket. The chest settles over each planted boot. In a running jump the opposite arm drives with the leading knee, then opens into the landing. At wing summon one heel tucks, and the outside arm opens in a bank. Walking and skating each keep their own uniform when a caller overrides the headgear. |
| `engine/rigs/review/clay_case.gd` | Extended the existing character regression with the uniform, pocket reach, alternating chest roll, takeoff tuck and response to opposite banks. |

### What I checked

The builder's evidence is under `.tl/astra/r2/`. The measurements below refer to the final round 2 sources.

| Check | Result | Evidence |
| --- | --- | --- |
| Triangle count and rig contract | 12 wardrobes, 9,888–11,868 triangles including stowed tools, 29 bones, 20 clips, height 2.0 m and radius 0.3 m. The five game configurations produced identical ordered bone, socket and clip name lists in classic and diorama. | `verified/character.log`, `verified/probe.log`, `verified/probe-classic.log`, `verified/probe-contract.txt` |
| Visible triangles in the operator's game configurations | Bare-backed visitor 10,788. Walker with satchel and worker 11,732 each. Blue and red skaters 10,832 each. These counts exclude hidden meshes and the separately summoned wings. | `verified/probe.log` |
| Gait and idle | Chest roll ranged from −7.2° to +7.2° at walking speed. The right palm moved from 0.327 m to 0.041 m from the upper pocket welt. Forward sole slip at 4.5 m/s averaged 0.067 m/s. | `verified/character.log`, `verified/rig.log`, `motion-strip.jpg` |
| Jump, flight and grip | Across four takeoff phases the leading knee was R/L/L/R and the forward wrist was L/R/R/L. The flight knee flexed 26° more at launch than at the same point in the glide cycle. Opposite 28° banks changed the measured upper-arm angle by 22°. The ledge, bar and stick fixtures each printed 0.00000 m maximum palm error to five decimal places. | `verified/jump-arms.log`, `verified/character.log` |
| Play-distance review | The visitor wore the jacket along the road and carried the wings through takeoff and glide. The 575-tick visit saved four of four views at world ticks 63, 303, 543 and 563. Captured the parkour runner at frame 520 and all six skaters at hockey frame 1500, both at 1920 × 1080 with zero reported engine or script errors. The rig review gives closer views of both uniforms and the optional satchel. | `road-final.log`, `road-strip.jpg`, `parkour-520.json`, `rink.json`, `rink.jpg`, `wardrobe.jpg` |
| Wing fit | The windowed `flight_review --seq=1` rendered 250 sequence frames. At summon and bank the harness follows the back while the two boots take different poses. The wing test counted 17 parts, 1,236 accessory triangles and a 4.39 m open span. | `flight-seq.log`, `wings-strip.jpg`, `verified/wings.log` |
| Classic close-up | All 12 fixed-tick 1920 × 1080 RGB frames matched the original pre-change captures exactly. Maximum channel difference 0/255, zero differing pixels. | `classic-pixels.txt` |
| Requested quick suites | PASS rig. 14/14, moves. 14/14, flight. 13/13, wings 2/2 and character. 1/1. All five final suite trailers report zero failed. | `verified/rig.log`, `verified/moves.log`, `verified/flight.log`, `verified/wings.log`, `verified/character.log` |

The operator owns the independent round 2 full-tier and world/pack hash verification, the publication captures and the executable.

### Where board 4 still reads better

In the road view the crown, short jacket and cuffs identify the toy. At flight and rink distance the paint chips and fingerprints disappear. In close-up the continuous dark outline and the even light across the back still make the coat look smoother than board 4's thumb-worked clay. The remaining frame and lighting observations are in this lane's PATCHES.md. [Idle, stride and jump](../../../../../.tl/astra/r2/motion-strip.jpg) · [Road through takeoff](../../../../../.tl/astra/r2/road-strip.jpg)

## Round 3

The engine files were frozen at 03:23 machine time. The six source digests are in `.tl/astra/r3/verified/frozen-sha256.txt`.

In the operator's rear view, the round 2 hands read as solid ovals. Board 4 has curled thumbs, visible ear lobes below the nape, one crown curl tucked below the other and a worn leather lip above the sole. I kept the code-built figure and used the existing wrist bones to give those hands a second job. The relaxed thumb and fingers now open around the bar and turn to follow its axis. The head, coat, denim and boots have broader changes of shape and finish that can be seen from behind. [Board 4 beside rounds 2 and 3](../../../../../.tl/astra/r3/board.jpg) · [Wardrobes](../../../../../.tl/astra/r3/wardrobe.jpg)

### Changed files since round 2

| File | Change |
| --- | --- |
| `engine/rigs/biped/clay_biped.gd` | Sculpted each bare hand as one continuous strip from thumb through palm to fingertips. Added a fitted hand shape for the support bar. Revealed the ears, swept the near lock into the nape, staggered the two crown curls and shaped the boot welt. Flattened the satchel straps and used fewer sides on their edges and the small jacket studs. |
| `engine/rigs/biped/clay_form.gd` | Pressed two folds into the rear hem and one into the nape. Registered the fitted fingers as one Godot blend shape on the walking mesh. The padded hockey gloves keep their own geometry. |
| `engine/rigs/biped/clay_rig.gd` | Blends the hand shape on contact and release. On a running landing the jacket tips toward the leading leg, followed by the head and wrists. |
| `engine/rigs/biped/clay_motion.gd` | Aligns the bare hand opening with the sensed support line during the two-link arm solve. A landing impulse lets the crown and the collar/satchel travel different distances and rebound at different times. |
| `engine/style/shaders/body_clay.gdshader` | Changed the fingertip impressions to partial arches, pressed two pocket edges into the jeans and gave flakes a shallow chipped rim. A burnished welt separates the warmer boot upper from the sole. |
| `engine/rigs/review/clay_case.gd` | Measures both hand meshes against a cylinder, checks their orientation while swinging, and measures the travel and settling of the crown and collar at two landing speeds. |

New games inherit the sculpt, grip and landing through the existing biped. The grip shape uses the same vertices, indices and skeleton as the relaxed pose.

### Measurements on the frozen files

The logs and stills in this table are under `.tl/astra/r3/`.

| Check | Observed result | Evidence |
| --- | --- | --- |
| Wardrobes and names | Across 12 wardrobes, 9,888–11,788 triangles including stowed tools, 29 bones, 20 clips, height 2.0 m and radius 0.3 m. The most expensive wardrobe has 212 triangles to spare. The operator's probe gave identical bone, socket and clip name lists for all five game configurations in classic and diorama. All 15 classic probe lines matched their round 2 counterparts. | `verified/test-character/character-clay.log`, `verified/probe-summary.txt` |
| Visible triangles | Walker and worker 11,652 each, village visitor 10,780, blue and red skaters 10,760 each. These are the probe's visible meshes before wing summon. | `verified/probe-diorama.log` |
| Grip size and alignment | Projected every hand triangle perpendicular to the grip axis. At unit scale the minimum clear radius across both hands was 0.00245 m relaxed and 0.05154 m engaged. The course bar's cylindrical collider has a 0.050 m radius. On the tilted and scaled fixture, maximum axis error was 0.00002°. Ledge, bar and stick palm errors each rounded to 0.00000 m. | `verified/test-character/character-clay.log`, `engine/kernel/world/moves_demo.gd` for the course dimensions |
| Landing | At 12 m/s downward, the crown travelled 12.8 mm and peaked on tick 2. The collar/satchel travelled 25.8 mm and peaked on tick 3. Both were back at their rest heights at tick 60. A 1.5 m/s touchdown produced zero extra travel. | `verified/test-character/character-clay.log` |
| Classic close-up | All 12 fixed-tick 1920 × 1080 RGB frames matched the pre-change front close-up. Zero differing pixels, maximum channel difference 0/255. | `verified/classic-pixels.txt` |
| Live visitor on the moves course | The hand shape reached full engagement on the bar at ticks 405 and 475. Its weight was zero after release at tick 580. The visitor was airborne at tick 600, grounded and crouching at 603 and recovering at 611. | `contact-final.log`, `landing.log`, [contact views](../../../../../.tl/astra/r3/contact.jpg), [landing sequence](../../../../../.tl/astra/r3/landing.jpg) |
| Village walk and wing summon | The bounded road visit saved four of four requested views over 575 ticks, including both wings open on the visitor at the parkour yard. | `road.log`, [village road and flight](../../../../../.tl/astra/r3/road.jpg) |
| Pack views | Parkour frame 520 shows the revised crown, cuff and heel on the blue runner. Hockey frame 1500 shows both teams, their sticks and all six skaters. The two 1920 × 1080 captures passed with zero reported script or engine errors. | `parkour.json`, `rink.json`, [parkour comparison](../../../../../.tl/astra/r3/parkour.jpg), [rink overview](../../../../../.tl/astra/r3/rink.jpg) |
| Requested suites | PASS rig. 14/14, moves. 14/14, flight. 13/13, wings 2/2 and character. 1/1. All five trailers report zero failed. The real visitor and pack support checks measured 0.077 m from the wrist to the edge or bar. The hand mesh extends from that wrist to the grip point. | `verified/rig.log`, `verified/moves.log`, `verified/flight.log`, `verified/wings.log`, `verified/character.log` |

Opus owns the independent full-tier and state-hash verification, the publication captures and the executable for this freeze.

### What still falls short

The ears, curled hands and boot welts carry at a medium distance. The pocket rims and broken fingerprints need a closer camera. Board 4 still has softer joins between clay pieces and a stronger sweep of warm light across the jacket. The continuous contour in the review scene makes the hair and collar look more moulded than thumb-worked. The existing frame and lighting notes in PATCHES.md still apply.
