# N6 world rubric (written by the Director before any arm built anything, 21 Nov 19:25)

Used every round by the arm (self-score) and by the Director (independent score from the same sheet and clip). Seven
scored items, 0 to 4 each, total out of 28. A score names its evidence (which still, which second of the clip, which
figure). Then the hard gates, pass or fail; a round that fails a hard gate is shown but is not a candidate.

The village box today (engine/boot/village.json through landscape.gd): x -392..452, z -330..280 (844 x 610 m),
centre about (30, -25). "3x the village's extent" means 3x on EACH axis: the Home reaches at least x -1240..1300 and
z -940..890 (about 2.54 x 1.83 km, 9x the area).

## Scored items (0 = absent or broken, 1 = weak, 2 = acceptable, 3 = good, 4 = a person would stop and look)

| # | Item | What a 4 looks like | What a 0-1 looks like |
|---|---|---|---|
| S | **Silhouette at distance** | In `overview_sw` and `far_look_back` shrunk to a 320 px thumbnail, the land's direction (valley / archipelago / highlands) is readable in one glance; the skyline has 2-4 distinct forms that could be named and found again | a flat plain with noise bumps; a skyline that is one even band of trees; the village's ring of hills is the only shape |
| V | **Variety without oatmeal** (WHAT-MADE-GAMES-POPULAR anti-pattern 3) | at least 5 places that differ in KIND (landform + cover + one feature of their own), so a person could give directions: "past the mill pond, up the red cliffs, left at the lone pine"; the same element never repeats at the same scale with only its numbers changed | one noise recipe everywhere with the same pines; regions differ only by a colour or a height factor |
| R | **Roads that lead somewhere** | every road and path out of the village ends at a destination (a venue plot, a portal, a ferry landing, a viewpoint, a farm); roads take the land's own way (a valley floor, a switchback, a bridge, a causeway) and are visible from above in `map` | a road that stops in a field; a road through a cliff or into the sea; a spider of straight lines; no road out of the village at all |
| P | **Venues where a player would want to go** | 4-8 empty venue plots and 2-4 dungeon-portal markers, each at a spot with a reason (a summit, a river bend, an island tip, a crater rim, a cove), each with a road or path to it, and at least the portals visible as markers from a distance | plots on a regular grid; a portal in an empty flat field; a plot no road reaches; a plot on a slope it would need to be graded into |
| C | **Continuity with the village** | the village itself is unchanged (pads, roads, scatter, sites; `village_edge_out` shows today's village as it is); the seam where the village heightfield meets the growth is invisible from every still and the clip; no plain left over, no mesa or tree floating or sunk | a step or a crack at the village box edge; the old flat far plain still showing; mesas or belt trees standing in the air or buried |
| L | **The house look (crisp cel)** | everything drawn through `TLStyle` palette keys and the kit (`TLKit`, `TLKitNature`, `TLKitRoad`, `TLMesh`); it reads as the same world as the village; water, cliffs, sand, fields read as what they are under crisp | a hand-made material or light; z-fighting; a hole into the sky; colours that are not the palette's |
| F | **Performance** (measured in the window, labelled busy if the machine is busy; A/B against the village alone in the same session) | growth build adds <= 1.5 s to the world's load; flyover frame p50 <= 8 ms and p99 <= 20 ms at 1920x1080; draw calls <= 2x the village alone | build > 5 s, or p50 > 16.7 ms, or a frame over 250 ms after the first second |

F scoring: 4 = all three targets met; 3 = two met; 2 = one met; 1 = none met but the run finishes; 0 = not measured.
Unmeasured is 0, never "probably fine".

## Hard gates (pass / fail)

1. **Extent:** the grown land covers at least x -1240..1300, z -940..890 (printed by the generator).
2. **Determinism:** the same seed twice gives the same data hash of the generator's output (regions, paths, venues,
   a sample of heights); a selftest case in the arm's 750-759 block proves it headless.
3. **The village is untouched:** no tracked file changed; the village's own scatter draws the same random stream (the
   growth uses generators of its own); `village_edge_out` is today's village.
4. **A game in the Home plays as it does alone:** the 8 games of `engine/boot/village.json` played in a window with the
   growth built around them: each hash = the same pack alone for the same number of its own ticks (8/8). Plus
   `node devx/bin/tl.mjs check --tier full --only world` PASS in the arm tree.
5. **Gates:** `node devx/bin/tl.mjs check --tier fast` PASS in the arm tree; the arm's selftest block PASS; no file over
   600 lines; no `class_name` in the new files (three arms must not collide in the class cache).
6. **Evidence exists:** a flyover mp4 of 20 s or less and the 6-still sheet for the round.

## The six fixed stills (the same roles in every arm; S1 and S6 the same coordinates in every arm)

| # | Name | Camera |
|---|---|---|
| 1 | `overview_sw` | from (-1500, 650, 1300) looking at (30, 0, -25), fov 50 (the same in all arms) |
| 2 | `village_edge_out` | from the village's edge, about 4-8 m over the ground, looking out along the road that leaves the village |
| 3 | `far_look_back` | from the Home's far side, low (20-60 m), looking back at the village across the grown land |
| 4 | `venue_approach` | on the road to the venue or portal the arm thinks is its best, 2-10 m over the road |
| 5 | `region_seam` | where two different regions of the arm meet, both in the frame |
| 6 | `map` | from (30, 3200, -25) straight down, north (-z) up, fov 50 (the same in all arms) |

The arm picks the coordinates of 2-5 in round 1 and keeps them for every later round (a move is named, with why), so
the rounds can be compared still by still.
