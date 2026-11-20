# L1 crisp-harden: patches for files outside the lane's column

## 1. `engine/kernel/world/walks/visitor_walk.json` (no owner; not gated): the probe `road_verge_walk`

Under crisp the road's rails are solid since tonight (`terrain/road_rails.gd`). The probe walks along the road at
z = -4 from x -60 to -108, which is the row of rails under crisp (road half 2.6 m + 1.3 m). Measured in a window
(`world.sh tour visitor_walk --pictures-only`, this branch): `road_verge_walk expect:pass ok:false ... short_of_target_m:1.32
stopped_by:rail`. The verge it means is between the road's edge and the rails. Suggested change (one value):

```
{"name": "road_verge_walk", "from": [-60, -3.2], "to": [-108, -3.2], "expect": "pass"}
```

Not applied by the lane (the file is not in its column). `fence_from_outside` and `fence_from_inside` of the same walk
fail on the base too (plots are open on every side since 19 Nov, the Director's B1): not this lane's.

## 2. `engine/kernel/world/site/fixtures/no_ring.gd` and `editor_yaw.gd` (no owner; the fixture of site/draw.gd, block 501): APPLIED in the branch

The test counts the site's bodies in the visitor's space. Tonight's site/draw.gd adds the two posts of the site's sign
and, while the game is being built, the stretches of the site fence along the footprint (B2). The count moved from
3 building / 4 arrived to 5 + `site.hoarding` building (5 stretches in the fixture) / 6 arrived, with a new assertion on
`site.hoarding`. Applied in the branch because the fixture tests only draw.gd and the gate would be red without it;
the Director may move it if a lane claims the fixture.
`editor_yaw.gd` (block 502) counted the site's boxes: 4 building (crane, 3 bays) and 2 arrived (pillars). Now 13
building (crane, 3 bays, 4 posts of the sign and the plan board, 5 stretches of site fence) and 4 arrived (pillars and
the sign's posts). Its shell line (502) still says "four crane/bay boxes" (unchanged; the first four boxes are those).
Also applied in the branch, from main: dc9024b's two selftest hunks (513 blend.car_origin under classic, 580 surf.model
names diorama), as the Director asked; they are main's, not this lane's.
