# dio-astra, round 2 (12:15-13:05): brief for Astra

Round 1 is in the tree. I am re-running every gate and the full shot set on it now (my outputs go to `.tl/v1/`,
`.tl/v1g/`, `.tl/v1_*.log`; please leave those alone). My figures come back to you as they land.

## 1. The Director's decision (11:35), verbatim
"your EXE_AA finding is the owner's "blurry" in the exe (msaa=2 + TAA). Decision: on your branch you own
`engine/boot/boot.gd`'s EXE_AA. Make the exe window's AA come from your team's style file (a key such as `exe_aa`),
with an absent key meaning today's "msaa=2,taa=1" so classic stays exact, and keep the `TL_EXE_AA` env override
first. cel-astra gets the same ownership on its branch. Measure the exe window (boot scene) before and after with your
edge-energy figure. Your 01_walker_road already reads sharper than last night's combined build."

So `engine/boot/boot.gd` (the EXE_AA part only) is in your scope on this branch. The key belongs in a section you own
of `style_diorama.json`. Measure the boot scene before and after (far / mid bands, GPU p50, your horizon-motion
figure), and say what it costs.

## 2. The first integration is at 13:30
By **13:05** the tree must be clean and working: gates green (fast; full `--only world,packs,kit.selftest`;
selftests `style.`, `rig.`, `moves.`, `flight.`, `wings`, `character.`), classic still exact, notes updated. I verify
13:05-13:30. Please do not start an unfiltered `tl check --tier full` this round (the r1 one was still running when you
ended; it competes with four arms for the machine).

## 3. After the AA, if time remains: the next gap you see in your scope
Your call which. From your own r1 notes the open frame/figure items were the cloud highlight cream and the clay grain
reading only in close-up. The board's other frame items (TEAMS.md, dio-astra): warm raking light that shows fibres and
tool marks; soft shadows with tight contact darkening at feet and posts; the cotton-cloud sunset; the figure as
separate clay pieces with fingerprint normals and sparse chipped paint, a toy feel in motion.

Rules, scope, tools and the notes format are as in `ASTRA-BRIEF-r1.md`. Append a "Round 2" section to `ASTRA-NOTES.md`.
Read-only git is fine; do not commit. Never kill a process you did not start.
