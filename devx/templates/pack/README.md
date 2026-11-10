# {{title}}

Scaffolded by `tl new pack {{name}}`. Three balls roll down a ramp; Space nudges them toward the finish line.

```
node devx/bin/tl.mjs watch --pack <this dir>      lint -> smoke -> bot on every save
bash engine/tools/tl.sh play --pack=<this dir>    Space nudges, Esc quits
```

| File | What |
|---|---|
| `pack.json` | manifest: id `game.{{name}}`, capabilities, entry, tests |
| `data/tuning.json` | the numbers to turn |
| `scripts/main.gd` | the glue: builds the world from data, acts in `_pack_tick` |
| `tests/bot_{{name}}.gd` | a bot that plays to the end |

Next: read `engine/seeds/README.md`, find the seed nearest to your game, and work by analogy.
