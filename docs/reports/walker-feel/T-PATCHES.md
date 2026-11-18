# Lane T: patches and findings for files that are not mine (walker-feel, 18 Nov 2026)

Nothing here is applied. My fixes (B1, B2, the exe's TAA) do **not** depend on any of them.

## To lane L (engine/style)

### L1. The ink contour breaks up from frame to frame on thin members (the shimmer under the TAA)
Seen: stills/T3_fence_3frames_base_vs_taa.png (top row, without TAA): the contour along a fence rail at 20-40 m is
a row of dashes whose gaps move every frame; the figure's outline frays the same way (T3_figure_walk_*.png). Flicker
in the horizon band, where the far fences and trees are, is 3.5 times the flicker elsewhere (per-pixel map of the
pan). The exe now hides it with TAA (boot.gd `EXE_AA`). At the source it is `ink_post.gdshader`: the "thin members
keep their colour" rule (`thin_keep`, `hair_alpha`: when both opposite taps see the background the contour shrinks
to a hairline) flips per pixel as a 1-2 px rail moves by a fraction of a pixel, and the width noise (`even`) adds to it.
Proposal, for L to measure (I did not change the shader): fade the thin-member decision instead of switching it
(smoothstep over the tap distance instead of a both-taps-see-background test), and take the width noise from
world or view-space position rather than screen position, so it moves with the rail. My measuring kit is ready for it:
boot.gd `TL_EXE_FRAMES=<dir> TL_EXE_FRAMES_FULL=1 TL_EXE_AA=msaa=2,ss=smaa,taa=0` plus the flicker formula in
T.md (T3 table); with TAA off the gain shows directly.

### L2. Near tree canopies are pale flat planes
When a canopy is between the chase camera and the figure (walk 1, frames 1048-1100, running up the bank among
trees at (55..60, -8..-12)) half the screen is pale blue-grey faces for 2-20 frames (frames rt_m1 n990-1018;
stills of the capture in my scratch, not kept). It is not a hole (depth is written). A dither-out of geometry that
is within ~2 m of the camera (toon.gdshader, by view depth) would let the figure be seen; whether the camera should
instead avoid canopies is lane M's.

## To lane M (movement, camera)

### M1. The picture steps with a period of 3 frames while walking and running
With `--fixed-fps 60` (one physics tick per drawn frame) the camera and the figure repeat every third frame while
moving (rt cold capture, frames 710-715 and 1169-1174: frame t and t+3 are the same framing, t+1 and t+2 differ).
It contaminates any frame-to-frame measure (my first detector flagged 930 frames of it). Re-check after physics
interpolation lands.

### M2. Camera through tree canopies
See L2: the camera passes behind or through canopies on the bank north-east of the road. The camera's obstacle
test (if it has one) seems to know hills, not trees.

### M3. SCRIPT ERROR in kernel/runner/visit.gd on leaving a game
`Trying to assign invalid previously freed instance. at: _close_stage_record (res://kernel/runner/visit.gd:223)`,
from `stage (visit.gd:207)`, when Q leaves the kit court during a recorded visit (`-- --record=<file>`, walk 2: E at
frame 520, Q at 700). Without `--record` it does not occur in my runs.

### M4. Scripted keys lose their state when another window takes the focus
TL_EXE_KEYS presses (and the devices of `visit-test`) are dropped when another window takes the focus (the engine
releases pressed keys on focus out): one of my runs stood still from frame 300 on. A recorded visit (`--input`)
does not have this problem; I used it for every comparison.

## To the Director

### D1. Windows and the lock
Lane M's world.sh loop held the machine-wide window lock for long stretches and lane L's movie captures ran at
0,1440 without it. My windows ran at 1920,1440 without the lock (`TL_WINDOW_LOCK=off`); every wall-clock figure of
mine is labelled busy.

### D2. The shipped cache misses once
B1 changes the rim cache key (`<hash>|<radius>|<scenery>|cover`) and the far pictures of the car and hockey plots
(their key holds the rim). An exe built from this tree builds those rims and pictures on its first start unless
`export.sh` warms the cache again (it does: TL_EXE_WARM). A cache shipped beside an older exe is not affected.
