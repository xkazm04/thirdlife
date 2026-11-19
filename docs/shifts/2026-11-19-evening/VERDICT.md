# Evening shift of 19 Nov 2026: verdict

Two lanes ran from 19:10 to 21:34, both on your 19:00 points 1 and 2. Both landed on main, with no revert. Nobody has
played them yet.

## Main at the verdict (22:00, `79af060`)
- **Full gate:** PASS on every step.

  | Step | Result |
  |---|---|
  | arch | 12/12 |
  | assets | 4/4 |
  | cards | 3/3 |
  | devx.test | 229/229 |
  | foreman.typecheck | clean |
  | foreman.test | 223 |
  | kernel.selftest | 324/324 |
  | kit | 95/95 |
  | packs | 48/48 |
  | perf | 2/2 (quiet) |
  | seeds | 39/39 |
  | item | 91/91 |
  | ui | 166/166 |
  | world | 8/8 |

- **Index:** `tl arch --index` regenerated for KERNEL_API 1.11.
- **Exe:** `export.sh --commit 79af060` built it, and `export.sh check` passes. To play it, run `dist/PLAY-LATEST.cmd`.

## wings: summoned by magic, never worn (Astra alone; an Opus operator verified)
- **Verdict:** landed, `8cae88f` merged as `a6c44ac`.
- **What it does:**
  - **Walking:** no wings and no backpack.
  - **Summon:** F opens a cyan four-point sigil between the shoulders. Two strokes sweep outward and a bright nib writes
    the harness, the spars and the twelve plates, with sparkles. That takes 36 ticks (0.6 s), and take-off does not
    wait for it.
  - **Landing:** the wings fold, then the same spell runs backwards.
  - **F in the air:** you fall, while the wings fold and vanish together.
  - **Packs:** a pack biped that flies gets the same summon and dismiss.
- **Evidence:**
  - Case `flight.wings_summon`, block 540, checks four things:
    - nothing is drawn before F or after a dismiss;
    - the wings are complete at the end of the summon;
    - an interrupted summon reverses smoothly;
    - two runs give identical frames over 144 ticks.
  - The flight figures are unchanged: on main, flight 14/14 and moves 15/15.
  - Clip: `lanes/wings/clip-summon.mp4` (8.5 s). Sheets: `sheet_close.jpg` and `sheet_road.jpg`.
- **For your eye:** in the exe, walk on the road, press F, fly, then land on grass.
- **Director decision you may overturn:** every walker-feel pack biped starts without the rig's backpack, even one
  that never flies. No tracked game's look changes, because parkour already sets it.
- **Asks:**
  - **W6. The summon key:** F summons and takes off (as built) / a separate key to summon without flying.

## hud: "Split Ticket" and the HUD workshop (Astra alone; an Opus operator verified)
- **Verdict:** landed, `f4e6c82` merged as `1e254ab`. KERNEL_API 1.11 adds three TLHud calls.
- **What it does:**
  - **The look:** the HUD takes the look of race bibs and timing slips:
    - a numbered stage tab;
    - the next move on its own large paper ticket;
    - the split against your best, with a green or red difference;
    - checkpoint punches;
    - keycap controls;
    - a finish docket.
  - **Themes and sizes:** 3 themes (Signal red, Relay blue, Night meet) and 3 sizes. It is the house HUD for every
    game; hockey's picture changes, but its figures do not.
  - **The workshop:** the HUD workshop in the world creator shows or hides each widget, drags it or picks one of 9
    spots, and sets its size and theme, with a live preview. "Save & play" saves the layout with the game
    (`engine/packs/parkour/data/hud.json`; unknown keys are errors).
- **Escaping the first try:** Astra drew two concept boards before writing any code (`lanes/hud/concepts/`). It
  rejected the safe smoked-glass strip, because there the next move weighs the same as five other fields. The operator
  measured round 1 at 720p: the split and checkpoint figures were 7-9 px tall. Round 2 raised them to 16-18 px.
- **Evidence:**
  - Six cases in block 550.
  - All 56 world and pack hashes, and all 72 parkour bot runs (default and custom layout), are identical to before.
  - Clip: `lanes/hud/clip-hud.mp4` (16.7 s). Stills: `stills/contact-sheet.jpg`, before and after for parkour at 720p
    and 1080p, and for hockey.
- **For your eye:**
  1. Run `bash engine/tools/ui.sh open`, click "HUD workshop", rearrange the widgets, then press "Save & play".
  2. Or run Timber Run in the exe.
- **Director decision you may overturn:** the new look is the default for every game.
- **Asks:**
  - **H4. The look:** keep Split Ticket / try another direction.
  - **H5. A convention in PACK.md:** name `data/hud.json` and `data/hud-widgets.json` there / leave it as pack data
    only.

## Route scoreboard
| Lane | Route | Held? |
|---|---|---|
| wings | Astra alone | Yes, in one round. |
| hud | Astra alone | Yes, in two rounds; the operator passed back only measured readability. |

The operators directed no design, as the route table says.

## Cost
- Astra tokens: hud about 597 k, wings 254 k (about 0.85 M in all).
- 2 Opus operators.

## Next
The night's scope comes from you. Candidates:
- give hockey a widget list for the workshop;
- show the workshop's preview on a live paused frame;
- play-test both features.
