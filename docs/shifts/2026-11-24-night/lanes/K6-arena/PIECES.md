# K6 arena: the pieces (round 1)

Generated from `engine/cores/rink/arena/arena.json` (the bake of thirdjam's played world, hockey.regular, look tier p3_clay).
"thirdjam source" = the actor label and component the game draws it from (the first of the group); "first at" = the first
instance's origin in our axes (rink x, up, rink y; metres). Ours = the node of that name under `RinkArena` (arena.scn).

| Piece (our node) | Layer | Instances | thirdjam source (actor.component) | thirdjam materials (per surface) | Triangles | First at |
|---|---|---|---|---|---|---|
| `ArenaBenchNeg` | rink | 1 | `RinkActor0.ArenaBenchNeg` | MI_Toon_Board, MI_Toon_KickPlate, MI_Toon_Bench, MI_Toon_Blue, MI_Toon_Dark | 2816 | (-7.50, 0.00, 22.75) |
| `ArenaBenchPos` | rink | 1 | `RinkActor0.ArenaBenchPos` | MI_Toon_Board, MI_Toon_KickPlate, MI_Toon_Bench, MI_Toon_Orange, MI_Toon_Dark | 2816 | (7.50, 0.00, 22.75) |
| `ArenaBoxNeg` | rink | 1 | `RinkActor0.ArenaBoxNeg` | MI_Toon_Board, MI_Toon_KickPlate, MI_Toon_Bench, MI_Toon_Blue, MI_Toon_Dark | 1872 | (-3.00, 0.00, -22.75) |
| `ArenaBoxPos` | rink | 1 | `RinkActor0.ArenaBoxPos` | MI_Toon_Board, MI_Toon_KickPlate, MI_Toon_Bench, MI_Toon_Orange, MI_Toon_Dark | 1872 | (3.00, 0.00, -22.75) |
| `ArenaGoalNeg` | rink | 2 | `RinkActor0.ArenaGoalNeg` | MI_Toon_NetFrame | 3216 | (-41.00, 0.00, 0.00) |
| `ArenaTable` | rink | 1 | `RinkActor0.ArenaTable` | MI_Toon_Board, MI_Toon_KickPlate, MI_Toon_Bench, MI_Toon_Dark, MI_Toon_NetFrame, MID_MI_Trim_Lamp_0 | 2088 | (0.00, 0.00, -22.75) |
| `ArenaGoalNetNeg` | rink | 2 | `RinkActor0.ArenaGoalNetNeg` | MI_Toon_NetCord | 1824 | (-41.00, 0.00, 0.00) |
| `ArenaGoalLightNeg` | rink | 1 | `RinkActor0.ArenaGoalLightNeg` | MI_Toon_Dark, MI_Toon_KickPlate, MID_MI_Trim_Lamp_1 | 696 | (-45.25, 0.00, 0.00) |
| `ArenaGoalLightPos` | rink | 1 | `RinkActor0.ArenaGoalLightPos` | MI_Toon_Dark, MI_Toon_KickPlate, MID_MI_Trim_Lamp_2 | 696 | (45.25, 0.00, 0.00) |
| `ArenaCaps` | rink | 36 | `RinkActor0.ArenaCaps` | MI_Toon_Blue | 1440 | (-3.41, 1.20, 22.60) |
| `ArenaCapsPos` | rink | 37 | `RinkActor0.ArenaCapsPos` | MI_Toon_Orange | 1480 | (45.10, 1.20, 18.76) |
| `ArenaBoxDoorNeg` | rink | 1 | `RinkActor0.ArenaBoxDoorNeg` | MI_Toon_Blue, MI_Toon_Dark | 208 | (-1.25, 0.00, -22.81) |
| `ArenaBoxDoorPos` | rink | 1 | `RinkActor0.ArenaBoxDoorPos` | MI_Toon_Orange, MI_Toon_Dark | 208 | (4.75, 0.00, -22.81) |
| `ArenaBoxHandNeg` | rink | 2 | `RinkActor0.ArenaBoxHandNeg` | MI_Toon_Dark | 128 | (-3.00, 2.35, -24.16) |
| `BarnFloor` | barn | 1 | `Con_P3_Clay_Floor.StaticMeshComponent0` | MI_ClayBarn_Floor | 48 | (0.00, -0.08, 0.00) |
| `Con_ClayWall` | barn | 34 | `Con_P3_Clay_Wall_S1.StaticMeshComponent0` | MI_ClayBarn_Wall | 19992 | (-54.00, 0.00, 37.00) |
| `Con_ClayGable` | barn | 2 | `Con_P3_Clay_Gable_E.StaticMeshComponent0` | MI_ClayBarn_Wall | 6360 | (60.00, 13.50, 0.00) |
| `Con_ClayPost` | barn | 34 | `Con_P3_Clay_Post_S1.StaticMeshComponent0` | MI_ClayBarn_Post | 1224 | (-59.70, 0.00, 36.70) |
| `BarnRoof_S` | barn | 2 | `Con_P3_Clay_Roof_S.StaticMeshComponent0` | MI_ClayBarn_Roof | 96 | (0.00, 17.90, 18.50) |
| `Con_ClayLampShade` | barn | 18 | `Con_P3_Clay_Shade_1.StaticMeshComponent0` | MI_ClayBarn_Post, MI_ClayBulb_Lamp | 4032 | (-33.75, 13.06, 0.00) |
| `Fan_A` | crowd | 60 | `Crowd_P3_Clay_k1000.Fan_A` | MI_ClayCrowd_Skin, MI_ClayCrowd_Fan, MI_ClayCrowd_Scarf | 36480 | (-42.10, 2.95, 30.07) |
| `Fan_B` | crowd | 66 | `Crowd_P3_Clay_k1000.Fan_B` | MI_ClayCrowd_Skin, MI_ClayCrowd_Fan, MI_ClayCrowd_Scarf | 40920 | (-40.96, 2.95, 30.07) |
| `Fan_C` | crowd | 45 | `Crowd_P3_Clay_k1000.Fan_C` | MI_ClayCrowd_Skin, MI_ClayCrowd_Fan, MI_ClayCrowd_Scarf | 24300 | (-42.66, 1.65, 28.17) |
| `Fan_D` | crowd | 4 | `Crowd_P3_Clay_k1000.Fan_D` | MI_ClayCrowd_Skin, MI_ClayCrowd_Fan, MI_ClayCrowd_Scarf | 2176 | (50.75, 1.20, -2.19) |
| `Fan_E` | crowd | 46 | `Crowd_P3_Clay_k1000.Fan_E` | MI_ClayCrowd_Tin, MI_ClayCrowd_Skin, MI_ClayCrowd_Fan, MI_ClayCrowd_Scarf | 26312 | (-42.10, 2.30, 29.12) |
| `Fan_F` | crowd | 63 | `Crowd_P3_Clay_k1000.Fan_F` | MI_ClayCrowd_Skin, MI_ClayCrowd_Fan, MI_ClayCrowd_Scarf | 38052 | (-41.53, 2.95, 30.07) |
| `Fan_G` | crowd | 62 | `Crowd_P3_Clay_k1000.Fan_G` | MI_ClayCrowd_Skin, MI_ClayCrowd_Fan | 37696 | (-41.53, 2.30, 29.12) |
| `Fan_H` | crowd | 64 | `Crowd_P3_Clay_k1000.Fan_H` | MI_ClayCrowd_Skin, MI_ClayCrowd_Fan | 33280 | (-40.40, 2.30, 29.12) |
| `Fan_I` | crowd | 64 | `Crowd_P3_Clay_k1000.Fan_I` | MI_ClayCrowd_Skin, MI_ClayCrowd_Fan | 37632 | (-40.96, 2.30, 29.12) |
| `Fan_J` | crowd | 64 | `Crowd_P3_Clay_k1000.Fan_J` | MI_ClayCrowd_Skin, MI_ClayCrowd_Fan | 39680 | (-40.96, 1.65, 28.17) |
| `Fan_K` | crowd | 58 | `Crowd_P3_Clay_k1000.Fan_K` | MI_ClayCrowd_Skin, MI_ClayCrowd_Fan | 34568 | (-35.05, 1.65, 28.17) |
| `Fan_L` | crowd | 68 | `Crowd_P3_Clay_k1000.Fan_L` | MI_ClayCrowd_Skin, MI_ClayCrowd_Fan | 41344 | (-42.66, 2.95, 30.07) |
| `Barn_Firewood` | crowd | 1 | `Crowd_P3_Clay_k1000.Firewood` | MI_Barn_Timber, MI_Barn_TimberDark | 414 | (-59.27, 0.00, 18.50) |
| `Barn_GateProps` | crowd | 1 | `Crowd_P3_Clay_k1000.GateProps` | MI_Barn_Timber, MI_Barn_TimberDark, MI_ClayCrowd_Tin, MI_ClayCrowd_Cream, MI_Barn_Hay, MI_Barn_Rubber | 688 | (59.27, 0.00, 6.54) |
| `Barn_IceGate` | crowd | 1 | `Crowd_P3_Clay_k1000.IceGate` | MI_Barn_Timber, MI_Barn_TimberDark, MI_ClayCrowd_Tin | 456 | (59.27, 0.00, 18.50) |
| `Barn_IceMachine` | crowd | 1 | `Crowd_P3_Clay_k1000.IceMachine` | MI_ClayCrowd_Tin, MI_Barn_Paint, MI_Barn_Rubber | 804 | (56.64, 0.00, 30.83) |
| `Barn_Loft` | crowd | 2 | `Crowd_P3_Clay_k1000.Loft` | MI_Barn_Timber, MI_Barn_TimberDark, MI_Barn_Hay | 864 | (59.27, 0.00, 24.67) |
| `Barn_ScoreboardHung` | crowd | 1 | `Crowd_P3_Clay_k1000.ScoreboardHung` | MI_Barn_Timber, MI_Barn_TimberDark, MI_ClayCrowd_Tin, MI_ClayCrowd_Cream, MI_Barn_ScoreLamp, MI_ClayCrowd_Cream | 508 | (0.00, 13.50, 0.00) |
| `Barn_SkateBench` | crowd | 1 | `Crowd_P3_Clay_k1000.SkateBench` | MI_Barn_Timber, MI_Barn_TimberDark, MI_ClayCrowd_Tin, MI_Barn_Rubber | 516 | (-59.27, 0.00, -6.17) |
| `Barn_SlidingDoor` | crowd | 1 | `Crowd_P3_Clay_k1000.SlidingDoor` | MI_Barn_Timber, MI_Barn_TimberDark, MI_ClayCrowd_Tin, MI_Barn_Rubber | 384 | (-59.27, 0.00, 6.17) |
| `Stand_Corner` | crowd | 4 | `Crowd_P3_Clay_k1000.Stand_Corner` | MI_ClayBarn_Stand, MI_ClayBarn_StandDark | 5376 | (43.00, 0.00, 20.50) |
| `Stand_End` | crowd | 4 | `Crowd_P3_Clay_k1000.Stand_End` | MI_ClayBarn_Stand, MI_ClayBarn_StandDark | 2016 | (49.00, 0.00, -2.56) |
| `Stand_Mod` | crowd | 48 | `Crowd_P3_Clay_k1000.Stand_Mod` | MI_ClayBarn_Stand, MI_ClayBarn_StandDark | 44352 | (-40.61, 0.00, 26.50) |
| `Barn_Bunting` | barn | 12 | `Dress_P3_Clay.Bunting` | MI_Barn_Cloth | 2784 | (53.00, 13.05, -30.83) |
| `Barn_LampArm_075` | barn | 6 | `Dress_P3_Clay.LampArm_075` | MI_Barn_Timber, MI_ClayCrowd_Tin | 432 | (-11.25, 13.50, 0.00) |
| `Barn_LampArm_225` | barn | 12 | `Dress_P3_Clay.LampArm_225` | MI_Barn_Timber, MI_Barn_TimberDark, MI_ClayCrowd_Tin | 1008 | (-33.75, 13.50, 0.00) |
| `Barn_TrussBay` | barn | 10 | `Dress_P3_Clay.TrussBay` | MI_Barn_Timber, MI_Barn_TimberDark, MI_ClayCrowd_Tin | 4920 | (-60.00, 13.50, 0.00) |
| `Barn_WallBay` | barn | 32 | `Dress_P3_Clay.WallBay` | MI_Barn_Timber, MI_Barn_TimberDark, MI_Barn_NightGlass | 5760 | (-60.00, 0.00, 36.27) |

Totals: 48 groups, 980 instances, 516834 triangles, 41 materials, 18 lights.

## The rink's own surfaces (ARinkActor's procedural components)

| Component | Shown by thirdjam | thirdjam material | Ours |
|---|---|---|---|
| Ice | yes | MID_MI_Ice_Night_0 | `RinkIce` (hall_ice.gdshader), 2 mm over lane K3's ice |
| Markings | yes | MID_BasicShapeMaterial_0, MID_BasicShapeMaterial_1, MID_BasicShapeMaterial_0, MID_BasicShapeMaterial_2 | lane K3's (gen/tj_rink.gd), not touched |
| Boards | yes | MI_Toon_Board | `RinkBoards` (hall_surface.gdshader: panels, joints, felt band, wear, dents), a 4 mm skin over lane K3's boards |
| Glass | no (hidden on p3_clay) | MID_MI_Glass_0 | none (hidden in thirdjam) |
| Trim | yes | MID_MI_Trim_Blue_0 | `RinkTrim` (the red cap), new |
| TrimOrange | yes | MID_MI_Trim_Orange_0 | `RinkTrim` (on the clay tier both halves wear the same matte cap) |
| Nets | no (hidden on p3_clay) | MI_Toon_NetFrame, MI_Toon_NetMesh, MI_Toon_NetFrame | none (hidden: the arena goal meshes are shown) |
| KickPlate | yes | MI_Toon_KickPlate | `RinkKickPlate`, a skin over lane K3's kick plate |
| GlassRail | no (hidden on p3_clay) | MI_Toon_GlassRail, MI_Toon_GlassRail | none (hidden in thirdjam) |
| GoalLights | no (hidden on p3_clay) | MI_Toon_GoalLight, MI_Toon_NetFrame | none (hidden: the arena goal lights are shown) |
| Benches | no (hidden on p3_clay) | MI_Toon_Bench, MI_Toon_KickPlate | none (hidden: the arena benches are shown) |

## The rig's lights (LR_P3_Clay)

| Light | At (x, up, y) m | Looks | Candela | Colour (sRGB) | Cone inner / outer | Radius m | Shadows |
|---|---|---|---|---|---|---|---|
| Key_P3_Clay_1 | (-33.75, 13.00, 0.00) | (0.00, -1.00, 0.00) | 5200 | (255.0, 214.0, 172.0) | 16 / 62 | 30 | yes |
| Key_P3_Clay_2 | (-11.25, 13.00, 0.00) | (0.00, -1.00, 0.00) | 5200 | (255.0, 214.0, 172.0) | 16 / 62 | 30 | yes |
| Key_P3_Clay_3 | (11.25, 13.00, 0.00) | (0.00, -1.00, 0.00) | 5200 | (255.0, 214.0, 172.0) | 16 / 62 | 30 | yes |
| Key_P3_Clay_4 | (33.75, 13.00, 0.00) | (0.00, -1.00, 0.00) | 5200 | (255.0, 214.0, 172.0) | 16 / 62 | 30 | yes |
| Fill_P3_Clay_1 | (0.00, 8.00, -30.00) | (0.00, -0.47, 0.88) | 1100 | (255.0, 208.0, 160.0) | 40 / 80 | 60 | no |
| Fill_P3_Clay_2 | (0.00, 8.00, 30.00) | (0.00, -0.47, -0.88) | 1100 | (255.0, 208.0, 160.0) | 40 / 80 | 60 | no |
| Fill_P3_Clay_3 | (-56.00, 8.00, 0.00) | (0.95, -0.32, 0.00) | 900 | (255.0, 208.0, 160.0) | 25 / 60 | 40 | no |
| Fill_P3_Clay_4 | (56.00, 8.00, 0.00) | (-0.95, -0.32, 0.00) | 900 | (255.0, 208.0, 160.0) | 25 / 60 | 40 | no |
| Fill_P3_Clay_5 | (-25.00, 7.00, 0.00) | (-1.00, -0.07, 0.00) | 2500 | (255.0, 208.0, 160.0) | 30 / 60 | 45 | no |
| Fill_P3_Clay_6 | (25.00, 7.00, 0.00) | (1.00, -0.07, 0.00) | 2500 | (255.0, 208.0, 160.0) | 30 / 60 | 45 | no |
| Lamp_P3_Clay_1 | (-33.75, 11.50, -13.50) | (0.00, -1.00, 0.00) | 2100 | (255.0, 214.0, 172.0) | 50 / 75 | 30 | no |
| Lamp_P3_Clay_2 | (-11.25, 11.50, -13.50) | (0.00, -1.00, 0.00) | 2100 | (255.0, 214.0, 172.0) | 50 / 75 | 30 | no |
| Lamp_P3_Clay_3 | (11.25, 11.50, -13.50) | (0.00, -1.00, 0.00) | 2100 | (255.0, 214.0, 172.0) | 50 / 75 | 30 | no |
| Lamp_P3_Clay_4 | (33.75, 11.50, -13.50) | (0.00, -1.00, 0.00) | 2100 | (255.0, 214.0, 172.0) | 50 / 75 | 30 | no |
| Lamp_P3_Clay_5 | (-33.75, 11.50, 13.50) | (0.00, -1.00, 0.00) | 2100 | (255.0, 214.0, 172.0) | 50 / 75 | 30 | no |
| Lamp_P3_Clay_6 | (-11.25, 11.50, 13.50) | (0.00, -1.00, 0.00) | 2100 | (255.0, 214.0, 172.0) | 50 / 75 | 30 | no |
| Lamp_P3_Clay_7 | (11.25, 11.50, 13.50) | (0.00, -1.00, 0.00) | 2100 | (255.0, 214.0, 172.0) | 50 / 75 | 30 | no |
| Lamp_P3_Clay_8 | (33.75, 11.50, 13.50) | (0.00, -1.00, 0.00) | 2100 | (255.0, 214.0, 172.0) | 50 / 75 | 30 | no |

Ours: all 18 are summed per fragment in the hall shaders (`engine/style/shaders/hall_rig.gdshaderinc`); the four with shadows are the
share the ice loses in the style sun's shadow. No engine light node is made.
