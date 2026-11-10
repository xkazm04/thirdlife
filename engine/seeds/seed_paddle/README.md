# seed.paddle: ball and paddle, first to five

A walled ice court. You move the blue paddle along your end, an AI moves the red one. A ball that gets behind a
paddle is a point for the other side. First to five wins. One ball, two paddles, two goals, one score: the smallest
complete "two sides and a ball" game.

```
bash engine/tools/tl.sh play --pack=engine/seeds/seed_paddle        A / D or the arrow keys; Esc quits
bash engine/tools/tl.sh bot  --pack=engine/seeds/seed_paddle        the bot plays a whole game and wins
```

## What it shows

| Need | How this seed does it | API |
|---|---|---|
| A venue from data | `data/court.json` is one `tl.layout/1` file: terrain, four walls, the ice floor, scenery, cameras | `TLKit.build_layout(layout, ctx.root)` returns `nodes`, `cams` |
| A ball | the layout prop `ball` is a kit part with no body; the kernel makes the body | `TLBall.create({"part": nodes["ball"], "planar": true, "group": "balls"})` |
| A thing the player moves on a rail | the kit `paddle` becomes a rigid body that may only slide along z | `TLBodies.from_part(part, {"lock": ["x", "y", "rx", "ry", "rz"]})`, then `TLBodies.drive(body, velocity)` every frame |
| Player control | two declared actions make one axis | `ctx.input.declare`, `ctx.input.axis(&"left", &"right")` |
| An AI opponent | it gets intents, not actions: where will the ball be, how hard to go there | `TLSteer.intercept_point`, `TLSteer.arrive` |
| A goal | a trigger behind each paddle that only sees the group `balls` | `TLBodies.trigger(&"box", size, {"group_filter": "balls"})`, signal `entered` |
| Score and win | `data/rules.json` is the whole rule set | `TLRules.create`, `add_score`, `is_over`, `snapshot`, signal `finished` |
| HUD | two scores and a hint line | `TLHud.add_score`, `add_label`, `set_text` |
| What the paddle does to the ball | game logic in `_return_ball`: the place it met the paddle sets the angle, each hit adds speed | `TLBall.shoot_at`, signal `bounced` |
| Seeded randomness | who gets the first serve, and the angle of every serve | `ctx.pick`, `ctx.rng.randf_range` |

The floor is ice and the ball is `planar` (it slides and does not roll) on purpose: rubber on ice has a friction
of 0.10 in the law table, so the ball loses only about 1 m/s per second and flies straight. Change `surface` of the
floor in `court.json` to `concrete` and the same game becomes a different one: that is the law table at work.

## Files

- `data/court.json` venue. The script looks up three ids: `ball`, `paddle_player`, `paddle_rival`.
- `data/rules.json` `{"sides": ["player", "rival"], "score_to_win": 5}`.
- `data/tuning.json` speeds, angles, the rival's speed (the difficulty), the dead-ball rule.
- `scripts/main.gd` 128 lines of glue.
- `tests/bot_win.gd` the bot.

## How the bot plays and how it decides it won

It presses only `left` and `right`. When the ball flies toward it, it computes where the ball will cross its paddle
line (straight flight, mirrored at the side walls) and goes there, offering the paddle edge that sends the ball to
the side the rival is not on. `ok` is true when the rules say `state == "over"`, `winner == "player"`,
`reason == "score"`, the player's score is 5 and the HUD shows "PLAYER wins". Measured: 5 : 0 in about 6,800 frames
(113 s of game time) at seed 1; it also wins 5 : 0 at seeds 2 and 3.

## To make it your own

Change the court size in `court.json` (and `court.half_width` in `tuning.json`), the rival's `speed`, `max_angle`,
`score_to_win`. A second ball is a second `TLBall` in the group `balls`: the goals already count it.
