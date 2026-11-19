# Night of 20 Nov 2026: plan (the toy-diorama duel)

**Planned:** with the owner, 22:35-23:15, through the spark `art-engine-duo` (`.spark/Spark/ideas/art-engine-duo.md`).

**The owner's decisions:**
- **Style boards:** four were made, one picture each, with a content-cost note:
  - the page: https://claude.ai/artifact/MaR63DYediCSyJdiZ7cn65
  - the files: `target/`
- **Target:** 4, the toy diorama. "if 4 superior we will discuss whether to replace current theming; if we struggle we
  stay and chase 2 (crisp cel)".
- **Pairing:** a duel. Each pair builds the same package twice, once by GPT 6.2 Astra and once by Fable 5.2. Pair
  planning with one builder was recommended; the owner chose the duel.
- **Pillars:** all four, folded into three pairs (model and animation share `engine/rigs`), which keeps to the cap of
  6 builders.
- **Character:** a free route on fixed rails.
- **Landing:** on branches only, for the owner's eye. Nothing lands on main.

**Base:** `diorama-base`, which is main `6e060d2` plus:
- `09e57d3`, `08915cb`: the `TL_STYLE` switch (the diorama default, classic one switch away); v1 API kept;
  `blend.pigment` runs under classic; case 560.
- `781d32b`: the briefs. Pushed.

**Briefs:** `COMMON.md` (with the lane rules) and `PILLARS.md`. Every arm gets the same text for its pillar.

| Arm | Worktree / branch | Builder | Agent | Started |
|---|---|---|---|---|
| frame-astra | `n20-frame-astra` / `diorama-frame-astra` | Astra via Codex, Opus operator | a961ae657f1a391a3 | 23:33 |
| surfaces-astra | `n20-surfaces-astra` / `diorama-surfaces-astra` | Astra via Codex, Opus operator | a34fc124d90a0acf6 | 23:33 |
| character-astra | `n20-character-astra` / `diorama-character-astra` | Astra via Codex, Opus operator | a9b98dbe5315b4270 | 23:33 |
| frame-fable | `n20-frame-fable` / `diorama-frame-fable` | Fable 5.2 | a66e03b1222a50be6 | 23:33 |
| surfaces-fable | `n20-surfaces-fable` / `diorama-surfaces-fable` | Fable 5.2 | a62acfca651779dd3 | 23:33 |
| character-fable | `n20-character-fable` / `diorama-character-fable` | Fable 5.2 | aa5e24cfa452f834e | 23:33 |

**Times:**
- Standups hourly at :41.
- Arms stop hard at 05:45.
- The Director combines at 06:00: `diorama-combined` takes the leading arm per pillar, and one exe is exported to
  `dist/arms/combined`.
- Verdict at 07:15: a page with a card per pillar, both arms side by side.
- Branches are pushed by 08:00.

**Rules from earlier nights:** report as `REPORT.txt` plus the final message; a message on `done`; raw captures stay
under `.tl/`; each pillar has its own selftest block range (570, 580, 590).

**Risks:**
- Fable may hit its usage limit; a cut arm keeps its branch and report.
- Six Godot-heavy arms load the CPU, so perf figures are labelled busy.
