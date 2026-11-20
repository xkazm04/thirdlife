# Board 4, frame arm

## Round 2

The west scoreboard casts the violet rectangle. In a diagnostic copy of the running rink, rebuilding the dress layout with just that board removed returned the affected ice to RGB (255, 221, 201). Turning up the actual sun also moved the cast outside the rink, but clipped the highlights and washed out the lines.

The shipped overhead view keeps the low sunset on the painted pieces. It reads the visible depth to cast a short, soft shadow from the key side of each piece. The occlusion is strongest at the skates and stick, then falls away over a limited distance. A scoreboard outside the image can no longer throw its face across a goal. The comparison at 1920 × 1080 is in `.tl/frame-r2/round2-pair.jpg`.

The cotton tufts have a lower crown, a wider silhouette and a small roll on the front edge. Light rakes over the folds even when the visitor looks away from the sun. In the same 126 × 92 pixel east-view crop at 1280 × 720, 4,281 pixels originally clipped both red and green. The new shape and highlight response clipped zero. The existing 27 tuft positions, paint colours and direction-based sky sampling carry the sunset around the dome.

| View | Round 2 setting |
| --- | --- |
| Named fixed play camera within 20° of straight down | The contact pass replaces the directional shadow map. `ink.tabletop_reach` is 3.6 m and `ink.tabletop_opacity` is 0.47. The view keeps deep focus. Leaving the view restores the regular cast. |
| Grounded chase, orbit and visitor | The focus plane passes through the actor's look point. The `tilt_deg` of −15° is relative to the tabletop. Camera pitch changes the plane in eye space, up to a 52° lean. At 1080p the aperture limits are `near_px 5.0` and `far_px 1.5`. The native optical amount is 0.023. |
| Untracked scenic and review cameras | Only low objects within `vista_near 27` m receive foreground softness. The calculation uses an object's depth and distance below the optical axis. At the axis a close-up stays sharp. Far softness starts at `vista_far 125` m with `vista_transition 180` m and `vista_amount 0.013`. |
| Flight, other fixed play views, camera overrides | Flight and all named fixed views retain deep focus. A camera that supplies optical attributes still owns its focus. The overhead shadow setting works even when the miniature lens is removed. |

The operator's left-ice sample averaged (173, 154, 224) in round 1. In the round 2 arena capture at frame 1500 it averages (255, 221, 201), against (254, 217, 197) in the corresponding open ice. All nine 1080p detail regions round to 1.000 with the lens enabled versus removed. The interior of the ice patch matches pixel for pixel in that pair. The blue line still contrasts with the ice. The overhead contact fixture measures a 22.7/255 change at the base of a piece and zero at 4.2 m.

At parkour frame 520, the runner's feet are about 6 m from the camera. The soil low in the frame is about 7.5–8 m away and more than 3 m below the aim point. Accounting for that height resolves the apparent foreground. Relative to the no-lens photo, the runner crop retains 0.98 of its detail, the stripe crop 0.97, the near deck 0.70 and the low soil 0.51. The sloping front lip itself retains 0.32. Round 1 retained 1.00 on the deck, lip and low soil. Detail is mean absolute four-neighbour Laplacian of luma. See `.tl/frame-r2/parkour-focus.jpg`.

In paired village captures, the centre of the walker road's bottom third retains 0.73 of its detail. The drive crane at 120 m retains 0.86 across the frame and 0.99 in its bottom third. Repeating the round 1 scenic settings on the same layout gives 1.00 on the road foreground and 0.68 across the crane. The runs used the original shot poses, a blocking load of all eight tracked packs, and the same terrain. The two lots that name external job directories were left empty for this worktree-only comparison. The control removed only the lens and its camera attributes. The flight probe recorded deep focus at ticks 80, 265, 615 and 825, then measured a grounded focus distance of 8.77 m at tick 1260.

The sky colours, grade and sun settings are listed in the round 1 record below. These changes add no pack assets, palette keys, camera declarations or authoring steps. The overhead pass uses visible opaque depth. The parkour road is the closest fixed view to the board's timber yard. Its sunset and cotton folds read at a glance. The course still sits across an open field, and the road camera gives the figure little of the board's foreground space. Faceted rocks, sparse ground dressing and violet bands in long cast shadows remain visible. See `.tl/frame-r2/board-yard-final.jpg`.

### Round 2 verification


| Gate | Result on the final tree |
| --- | --- |
| Fast | PASS. Architecture 12/12, assets 4/4, cards 3/3, devx tests 229/229, foreman typecheck clean. |
| Full, selected suites | PASS. World 8/8, packs 2/2 with 48/48 verb runs, kit 95/95. Hockey's many-pack frame p50 was 0.948 ms. A previous complete run also passed. An intervening run failed that one timing check at 1.106 ms under machine load 13.08. |
| Style and frame block | PASS. Style 7/7, frame 4/4. The frame block covers focus routing, rig switching and opt-out, windowed pixels, and the actual hockey capture. |
| Compatibility | PASS. All 56 baseline hash and frame-count rows match, including all eight complete 256-bit world hashes checked independently. The original 100 palette columns retain their names, order and values. The diff is clean for packs, seeds, classic style, kernel API and contracts. |

The final gate logs are `.tl/frame-r2/done-fast.log`, `done-full.log`, `done-style.log`, `done-block.log` and `done-hashes.log`. The intervening timing failure is preserved in `shipping-full.log`.

- The windowed rink regression rejects the round 1 image and passes the release image. At 960 × 540 it compares unmarked ice on opposite sides and checks that the blue line remains visible. The camera tests also switch from a table to a bench view, reinstall the rig without the lens, and return the host to classic.
- The GPU fixture retains 1.00 of the reference stripe contrast on both the athlete and the near end of the beam, 0.50 on the low front ground, and 0.36 on the untracked foreground card. The graded sky fixture finds 1,775 cotton samples and zero with both red and green clipped. The near-contact drop is 20.6/255 at road height and 22.7/255 from above, with zero at the two clearance probes.
- In the fixed 1920 × 1080 flight movie, the west join at x=959 changes by more than 6/255 in 3.0% of the upper sky rows at frame 700 and 11.6% at frame 900. Classic measures 40.1% and 54.3%. The grounded east view can be inspected in `.tl/frame-r2/cotton-flight.jpg`.
- Eleven repeatable classic images match their pre-work references at 0/255. The fixed pack and clip cases are parkour frame 520, flight frames 420 and 900, and both official rig clip stills (idle close and walking three-quarter). The additional fixtures are the front rig review and five sky directions. Hockey frame 1500 and flight frame 700 vary between repeat captures. In hockey 418 of 2,073,600 pixels differed from the first pre-work capture, within the skater area. Two pre-work hockey captures already differed on 339 pixels. The interior of the reported ice patch matched classic exactly. On the matched eight-pack village walk, 11 of 16 additional images are pixel-exact against the pristine archive. The same five views vary when pristine runs twice. Their changed-pixel counts and maxima are recorded in `.tl/frame-r2/classic-tour-repeat.txt`. The operator's tour has different external lots, so its screenshots represent a different layout.
- The final RTX 4090 tour measured 1.489 ms GPU in diorama and 1.219 ms in classic, about 22% higher. Both runs were busy, at 95% and 100% machine use. An earlier busy comparison crossed the doubling threshold at 2.915 ms versus 1.347 ms. In one continuous fixed-camera test the prior optics alone ranged from 26.321 to 1.311 ms. The last five block medians were 1.416 and 1.395 ms for the release, 1.342 and 1.311 ms for the prior optics, and 1.369 ms with just the inactive court branch removed. The raw tour and alternating measurements are under `.tl/frame-r2/`.

Round 2 changed `engine/kernel/api/tl_cameras.gd`, `engine/style/tl_style.gd`, `engine/style/tl_style_fx.gd`, `engine/style/style_diorama.json`, the `sky_cotton`, `ink_post_contact` and `dof_tilt` shaders, selftest blocks 570–572, and this lane's two working notes. The round 1 list below includes the chase, orbit and visitor focus hooks.

## Round 1 record

The sun sits to the left of the village road. The mesas stand against a rose and apricot painted sky, and each cloud has a cream-lit crown, a warm underside and a small shadow on the backing. Twenty-seven groups of hand-placed tufts occupy different heights around the dome. Each tuft uses its own tangent frame and a continuous viewing direction. The sky has no longitude texture join. Godot bakes the wool and brushwork into the sky radiance once per lighting change.

At ground level, a 23° key casts shadows across the path. Its azimuth is −91°. The painted disc sits 34° around the backing from the lamp, at an elevation of 6°. That stage arrangement keeps the painted sunset beside the mesas while the practical light picks out the crane, cream beam stripes and sign face. The raised clouds take their light from the practical lamp, too.

A finite light disc and a soft directional shadow filter broaden the penumbra. A second, short-range depth-and-normal pass grounds boots, rails and scaffold feet in a cocoa-coloured contact shadow. The grade uses a mild warm highlight split. The art is procedural. A new game can use its existing palette, camera and seed with zero extra authored assets or settings.

## Where the lens focuses

| Active camera | Optical behaviour |
| --- | --- |
| Walking visitor, chase or orbit | The camera transforms the actor's look point into its current eye space. A plane tilted −15° passes through that point. A clear interval covers the figure and the next foothold. The shader softens the close rail and distant meadow. A lighter Godot optical pass also reaches glass, water and particles. |
| Camera pulled forward by a wall, or orbit yawed | The plane follows the actual camera transform, including its distance and aim offset, every render frame. |
| Flying visitor or flying biped | The active target's flight state turns off both blur ranges and the tilted pass. The grounded setting returns on landing. |
| Named fixed play camera, including hockey arena | Deep focus across the field. A skater registered for HUD measurements never attracts the lens. |
| Plain scenic or review camera | Only a gentle far transition starting at 98 m. The review figure and nearby cones remain sharp. |
| Camera with its own optical attributes | Godot uses those attributes and the tilted pass hides itself. |

## Style settings

| Section | Diorama controls |
| --- | --- |
| `sun` | `color #ffcb98`, `energy 1.24`, `elev 23`, `azim −91`, `shadow_max 235`, `shadow_blur 1.28`, `shadow_bias 0.075`. New `angular_size 0.65` degrees, `normal_bias 1.55`, `filter_quality 5`. Switching back restores the project shadow filter. |
| `env` | New `cotton_sky`, `contact_only`, `miniature_lens`. The lens takes `amount 0.023`, `tilt_deg −15`, `near_px 4.6`, `far_px 2.6` at 1080p, `vista_far 98`, `vista_transition 160` metres, `vista_amount 0.016`. Linear tonemap, exposure 0.89, glow 0.28, threshold 1.25, bloom 0.018. |
| `sky` | Painted colours in `zenith`, `upper`, `mid`, `horizon`, `ground`. The painted sun uses `glow`, `glow_k`, `disc`, `disc_r`, `sun_draw_elev 6`, `sun_draw_yaw 34`. `brush 0.26` sets the strength of the brush marks. `cloud`, `cloud_shade` and `cloud_scale` set the wool colours and size. |
| `fog` | Colour #d09a93, density 0.00037, height density 0.0006, sun scatter 0.16, aerial perspective 0.12, sky affect 0.025. A walk can still scale its own haze. |
| `ink` | `ao_color #382a35`, `ao_k 0.78`, `ao_radius 0.7` m, `ao_far 85` m. Twelve samples on three rings evaluate local occlusion. |
| `grade` | `shadows #62617d`, `highlights #ffe0b7`, `split 0.036`, `sat 1.105`, `contrast 1.135`, `vignette 0.13`, `grain 0.004`, `lift 0.003`, `gamma 1`, `paper 0`. |

All 100 palette columns retain their original keys, order and values. Only the six sections above differ from the base diorama JSON. This round changes presentation, with no geometry generator or public kernel signature changes.

## Round 1 evidence

Raw images, measurement controls and logs live under `.tl/frame/` in this worktree. The reference engine is a local read-only-git archive of `diorama-base` at `781d32b`.

- Seven classic captures match exactly in RGB. They cover parkour orbit at frame 520 and the rig review at frame 70, both at 1280×720, and five 960×540 sky bearings. The parkour reference predates the edits. The sky and rig references were rendered from the archived engine. See `classic-proof.txt`.
- In the graded, due-west sky capture, the 99th-percentile jump across the old vertical join drops from 70.4/255 to 2/255. The two adjacent control columns also measure 2/255 in diorama. In the ungraded 571 fixture, switching the tufts off changes 1,983 sampled pixels by more than 10/255.
- In the parkour capture the 220×24 split-timer crop and the 327×55 next-move crop match between classic and diorama. Compare `final-parkour-classic/photo.png` and `final-parkour-diorama/photo.png`.
- The windowed optical ruler has identical striped panels at 2, 8 and 70 m. Relative contrast with the subject at 8 m is 0.290, 1.000 and 0.385. Flight matches the sharp control at every sampled pixel. The separate `plane-proof/` has a fronto-parallel chart at 4.15 m. Flipping the tilt from −15° to +15° exchanges its upper and lower contrast values, 46.1 and 37.8 on an 8-bit scale. Zero tilt gives 42.3 at both heights.
- The contact fixture disables cast shadows. Case 571 measures a 20.8/255 darkening six centimetres from the post and zero change 1.38 m away. `contact-proof/` contains an earlier control pair. In the actual rig review, the enabled/disabled pair darkens 1,113 of 1,458 pixels in the grounded boot-and-sole crop. Its 95th percentile is 23.7/255. Compare `review-finaldiorama/close.png` and `review-contact-off/close.png`.
- The six captures in `final-flight/` replay the flight lane's controls with six added shutter events. The visitor is in focus at frame 42. At frames 80, 265, 615 and 825 the tilted pass and both native blur ranges are off. All three return at frame 1260 after landing.
- All eight complete 256-bit world hashes and tick counts agree with the archived base. All 48 pack verb outcomes and frame counts match, including all 46 verbs that emit state hashes. See `pristine-world-full.jsonl`, `final-world-full.jsonl` and `final-comparison.txt`. One early attempt to establish a baseline ran across an in-progress source edit and failed parkour load. The immutable archive and completed source tree both passed all 48 runs.
- One fast run flagged the API index after a public class description changed. Restoring the original description brought `arch` and both associated devx assertions back to green.

The five shots in `final-village/` are working pictures. They use the blend walk's road, terrain and crane placements with the eight local game plots, two external site jobs omitted and a short visitor pass added. The operator owns the official fixed set, sheet, clip, export, standup and report.

## Windowed cost

`tl perf run --scenario tour6 --no-record` measured 1.201 ms GPU in classic and 1.506 ms in the final diorama on the RTX 4090. The observed difference was 0.305 ms, about 25%. Both runs were busy, at 74% and 81% machine use respectively. They are single tour measurements with live plots. See `base-perf.txt` and `perf-release.txt`.

## Gate records

| Check | Final result | Raw log under `.tl/frame/` |
| --- | --- | --- |
| Fast tier | PASS arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck clean | `release-fast.txt` |
| Requested full-tier selection | PASS kit.selftest 95/95, packs 2/2 with 48/48 verb runs, world 8/8. All 105 counted units completed | `release-gate.txt`, `final-comparison.txt` |
| Style cases | PASS 6, FAIL 0 | `final-style.txt` |
| Assigned block, `style.frame` | PASS focus, rig, pixels. Three passed, zero failed | `final-own.txt` |
| Classic pigment | PASS 6,050 pairs, edge p99.9 7.42/255, tone span 53.64/255 | `final-pigment.txt` |
| Existing camera regressions | PASS 8 chase/avoidance, 2 crown, 1 marked-bar case | `cam-regression-0.txt`, `cam-regression-1.txt`, `cam-regression-2.txt` |
| Windowed tour | PASS perf.tour6, machine busy | `perf-release.txt` |

The unfiltered full tier, item/UI results and export are outside this arm's verification run. The operator owns the overnight release gates and artifacts.

## Where the illusion breaks

The rink's toon material still draws violet bands through long shadows. The meadow has broad smooth patches, the pines show flat facets, and diagonal hatching remains visible on shadowed timber and clothing. Those are easiest to see during the sharp bluff flight and in the front rig review. The stock road camera also frames the visitor smaller than board 4 does. The clouds read as mounted tufts, particularly in flight, where the painted backing stays stationary. The surface handoff identifies the shadow response responsible for the rink bands.

The raw `vista-proof/` experiment used centre-depth autofocus for the village crane. It softened the visitor when the scaffold filled the centre of the picture. The shipped scenic setting keeps the near field clear.

## Files for the Director

- `engine/style/style_diorama.json`, `engine/style/tl_style.gd`, `engine/style/tl_style_fx.gd`
- `engine/style/shaders/sky_cotton.gdshader`, `ink_post_contact.gdshader`, `dof_tilt.gdshader` and the three adjacent Godot `.uid` files
- `engine/kernel/api/tl_cameras.gd`, `engine/kernel/api/tl_chase_cam.gd`, `engine/kernel/api/tl_orbit_cam.gd`, `engine/kernel/world/terrain/crown_camera.gd`
- `engine/tools/selftest.d/570-frame.sh`, `engine/tools/selftest.d/571-frame-pixels.sh`
- This note and `PATCHES.md` in the frame-astra lane
