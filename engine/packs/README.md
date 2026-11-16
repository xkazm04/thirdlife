# House games (`engine/packs/`)

A house game is a finished game the repository keeps and gates: one folder per game, a pack exactly as `contracts/PACK.md`
defines it (`pack.json`, `scripts/`, `data/`, `tests/bot_*.gd`), loaded as `res://packs/<folder>`.
It is not a seed: a seed (`engine/seeds/`) is a small example a builder copies; a house game is played, mounted in the
village (`engine/boot/games.json`) and improved in place. Copy from a seed, not from here.
The gate step `packs` (`tl check --tier full --only packs`, `devx/lib/gate/steps/packs.mjs`) runs lint, smoke, every bot
of the manifest and invariants on every folder here with a `pack.json`; it prints found and completed and fails when they
differ. `tl play` lists the house games; `tl play hockey` plays one.
Today: `hockey/` (`game.ice_hockey_three_against` 0.1.1, built by the Foreman on 11 Nov, record `docs/reports/JOB3-HOCKEY.md`;
since 16 Nov: possession and passing, hits, modes as data in `data/modes/` chosen by the param `mode`, a rule dial once a period).
How to play it, what it is and how it is tested: `hockey/README.md`.
