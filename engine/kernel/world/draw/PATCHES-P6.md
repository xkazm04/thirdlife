# P6: patches for files that are not P6's

None of these is applied. Each has the reason and the exact change. The draw layer works without all of them.

## 1. `engine/kernel/world/tiers.json`, `tiers.gd` (the loading builder): the far-picture threshold

Reason: FAR.md rule 10. The distance at which a backdrop game changes from its middle to its far picture is a
threshold of the world like the others, and a walk should be able to override it. Today the number lives in
`draw.gd` (`picture_far_m = 240`, `picture_margin_m = 30`); the draw layer already reads both keys from the world
host's `cfg` when they exist, so the patch is the two keys and their acceptance by `Tiers.load_config`.

`tiers.json`, after `"backdrop_note"`:
```
  "picture_far_m": 240,
  "picture_note": "P6. Camera to the nearest edge of a plot: beyond it a backdrop or ledger game is drawn as its far picture (silhouette), inside as its middle picture (draw/FAR.md). Drawing only: no tick depends on it.",
```
and `"margin_m": {"stage": 2, "sideline": 10, "backdrop": 40, "picture": 30},`

`tiers.gd`, `load_config`: accept `picture_far_m` (number > 0) and `margin_m.picture` (number >= 0) as optional keys
(absent = the draw layer's defaults). They must not enter `decide()`: a run stays a pure function of its walk.

## 2. `engine/kernel/world/draw/view.gd`, `engine/kernel/runner/verbs.json`: `--picture=still|mid|far`

Reason: the study forces one picture on every far game through the env variable `TL_DRAW_PICTURE`, because the
viewer's options are not P6's. An option is the right door (it shows in `tl.view/1`, it is listed with the others).

`view.gd`, `start()`, after `draw.set("rim_band", ...)`:
```
	draw.set("force_picture", str(opts.get("picture", "")))
```
`verbs.json`, mode `world-view`: add the option `picture` (one of `still`, `mid`, `far`). `draw.gd` keeps reading the
env variable only when the option is empty (it already does: `setup()` reads the env only into an empty value).

## 3. `engine/kits/tl_kit_site.gd` `add_scoreboard`, `engine/kits/KIT.md`: the scoreboard is a prop

Reason: FAR.md finding 1. The part draws fixed digits ("3 : 2"); a game that places it shows a wrong score to
everybody who is not looking at the HUD. In a world the draw layer now lays the real score over it. A single-pack
run (play, capture) still shows the prop. P6 may not change a part's full form, so this is a proposal:
- `KIT.md`, part `scoreboard`: say that the digits are decoration, and that in a world the real score is drawn
  over them when the pack has a `TLRules`.
- later, for the kit's owner: a parameter `digits: false` that leaves the face black, and a kernel helper that
  binds a board to a `TLRules` in a single-pack run (the draw layer's `_refresh_boards` and `_digit` are 30 lines
  and can move to the kit as `TLKitSite.add_score_face(mk, a, b)`).

## 4. `engine/kernel/world/walks/*.json` (the world's walks): the land's new keys

Reason: P6 added optional keys to the walk's `landscape` block; every walk works without them (defaults in
brackets). For the page that lists the block (`WORLD.md`, not P6's):
`relief` [1.0] scale of the land's own height (0 = a flat study ground), `pad_rocks` [true] a rock edge instead of
fence on the side of a pad away from its gate, `road_trees` [44], `road_bushes` [70], `plain_clumps` [16] clumps of
pines on the far plain between the village's hills and the mesas.
