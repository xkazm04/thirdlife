# Image generation prompts

## 1. boss_front.png

Establish Pip's silhouette and construction in a neutral pose. The road still supplies the material and lighting reference.

**Reference** `ref/game_road_walker.png`

```
Make one finished front-view concept of Pip, the village's walking photo-finish camera, for a painted low-poly sports game. One character, full body, dead straight-on at torso height, both feet planted a little apart, wings folded, centered with clear space around every edge on a plain pale warm-gray background. Use a square canvas. Treat the attached village road still as art direction for the game materials and lighting only.

Pip is a big, comically stern wading bird made from an old trackside camera. Design from three big reads: a squat buttery race-yellow, chamfered camera box for a combined head and body; a single enormous forward-facing dark-plum OCTAGONAL camera lens, poking out on two deep accordion folds and capped by a short dark slate projecting brow shade; two long, exposed burnt-orange bird legs on broad three-toed mechanical feet. Its folded wings are a matching pair of big tapered semaphore paddles, each vermilion with ONE broad diagonal ivory band; shoulder hinges allow them to swing up/out and signal the finish. Above the casing sticks up one crooked little red triangular starter pennant like a bird's crest. A tiny square amber reflection inside the lens makes the mechanical eye feel alert. Short wedge tail. Front silhouette is a stocky box balanced on two tall, separated bird shins, wing tips visible beside the body. Give it presence through the large dark eye and planted stance. Keep the parts few and sculptural; no separate human head, arms, hands, straps, text, numbers or lettering.

Render as a clean in-engine character in the same world as the reference: broad flat polygon faces, slightly uneven deep eggplant exterior ink #1a1024, finer lines only at working joints, 2-3 warm lit/cool violet toon bands, faint paper tooth, quiet flat color areas. Style palette base ids rendered in warm sun: yellow #f2b230, flag red #e8483a, curb white #f3e8dc, steel dark #4f4a60, orange #e8742c. Subtle grounding shadow under the feet. Crisp readable geometry for a Blender modeler. No metal photorealism, blueprint marks, border, labels, other figures or extra views.
```


## 2. boss_three_quarter.png

The front establishes the proportions. Rotate the camera and pose the signal paddle, bellows and legs so the modeler can see their pivots and depth.

**Reference** `out/boss_front.png`

```
Create a second model-reference painting of the EXACT walking finish-line camera in the supplied front design. Now turn around it 35 degrees to a genuine three-quarter FRONT view to show its depth. Depict the instant Pip calls for a photo finish: it cocks its solid camera body slightly to sight along the track, kicks one three-toed foot clear of the floor like a wading bird, and swings the nearer signal paddle straight up and outward on its barrel hinge while the far paddle stays down. Each paddle remains one rigid piece. Balance the bird convincingly on the other planted foot. The raised paddle, pennant mast and lifted foot should each make a clear silhouette. Show the two pleated bellows sections extending the single huge octagonal eye forward under its projecting dark brow. A short yellow wedge tail on the rear counterbalances the lens. The visible side of the chamfered yellow box has a continuous quiet expanse of ochre paint interrupted by the wing hinge.

Maintain the exact front design's box proportions, single red triangular crest, diagonal ivory stripe on each red paddle, amber square lens glint, orange jointed legs, three orange toes with dark tips, and plum ink. Same broad warm and violet facets, faint printed-paper grain. A single full figure, generous breathing room, simple pale warm-gray background and only the cast shadow beneath. Square canvas. No lettering, labels, multiple views, extra parts, camera tripod or environment. Make the silhouette feel like a stern referee holding their call for a beat.
```


## 3. boss_in_game.png

Place the resolved design at player height in the village. Use the road as the primary visual reference and the side still for the walker's proportions. Give both characters a common ground line for scale.

**References in order** `ref/game_road_walker.png`, `out/boss_three_quarter.png`, `ref/side_before_after.png`

```
Create one wide 16:9 in-game encounter still for Third Life. Reference 1 (the road) is the visual target: recreate that distinctive simple Godot village with its painted golden-hour grade, open ochre lane, chartreuse rolling plots, low brown rail fences, tiny red sports flags, a glimpse of track curb, faceted lollipop trees and stacked cone pines, lavender flat-topped mesas and great flat cream clouds shaded lilac underneath in a peach-pink sky. Reference 2 is the boss design and reference 3 shows the game's articulated walker from the side. Make it feel like a neighboring camera position in reference 1. No HUD, lettering, logos or borders.

The entire point of this frame is the encounter between those two characters. On the right half of the road stands Pip, the SAME yellow walking photo-finish camera from reference 2. On the left stands the small 2.0 m village walker seen from the back in three-quarter profile, looking up at Pip, with the auburn chunky swept hair, red jacket and ivory sleeve bands, blue pants, brown boots, tan square backpack with little cyan light, short segmented limbs of the supplied walker. Compose the two facing each other across a small gap, both characters completely visible. Stage their supporting feet at the SAME depth, on the same horizontal level. In the image the walker's head must come just to the underside of Pip's yellow body, roughly two-fifths of Pip's total height to the little red flag. Pip is 5 m tall and its full height should occupy about 62% of the frame; the walker about 25%. Use a moderate lens, horizon near the walker's shoulder, with road, sky and the distant fenced game plots visible between them.

Turn Pip's lens toward the walker while keeping its huge octagonal plum eye legible to camera. Two bellows ridges and dark brow over the eye, square amber glint, chamfered golden box, red triangular flag crest, orange articulated legs with three dark-tipped toes per foot. The near red signal paddle with ONE broad ivory diagonal stripe is cocked outward in anticipation. Transfer Pip into the softer game shader of reference 1: warm yellow sunlight, flatter paint with subtle paper grain, heavy dark-plum silhouette ink tapering away with distance, sparse interior ink, cool toon bands, broad grounded purple-brown cast shadows in one direction. Match the modest polygon count, color grading and visual detail of the road still, particularly on the characters. No new buildings, crowd, motion blur, dramatic FX or cinematic lens effects.
```


**Images generated in total** 3. All three built-in Codex ImageGen calls produced one image each, and all three results were selected.
