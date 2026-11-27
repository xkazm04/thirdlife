# PATCHES-F3: lane F3 (playing what you built), day of 27 Nov 2026

## F3-1 rules_run.gd (seam's file): re-entering the Start does not restart a run that is going

The playtest (Q6, small things): "Stepping back on the Start pad starts the run again and counts a play (run g3:
plays 4, finishes 1)". The contract says (contracts/BUILD.md "Rules", `start`): "Starting the run that is going restarts
it." and `enter` "fires once per entry", so a person who steps off the Start's edge and back, or whose first step
wobbles across its border, restarts the clock and counts a play.

**The rule proposed** (the cleanest I found; one constant, one map, no new wire name): a `start` effect fired by an
`enter` trigger, for the run that is going, starting from that trigger's own zone, does nothing when the feet left that
zone less than `REENTER_FRAMES` = 60 frames (1 s) ago. Everything else is as before: a start from another zone or of
another run, a start by `use` / `every` / `count`, the first start, and a re-entry after a second out all restart. A
respawn (teleport) into the Start after a fall counts by the same clock: on Pad hop the fall into the first gap is
85+ frames after he left the Start, so it restarts, as now.

Contract line for the Director (`contracts/BUILD.md`, `start`): "Starting the run that is going restarts it, except
by entering its start zone within 60 frames (1 s) of the feet leaving it."

Measured with the patch applied in this worktree (then taken out again: the file is unchanged in d27-f3):
- a probe on `RulesRun` (start zone 0..1, a hazard at x 5; feet: in, out 10 frames, in, out 70, in, hazard, back in 2
  frames later): without the patch `run_started` at frames 6, 21, 96, 103; with it at 6 and 96 only.
- 773 `HOME rules-seam ok`, 774 `HOME rules-play ok`, 789 `HOME stamp-starters ok`, 799 `HOME starters-walked ok`,
  803 `HOME play-shows ok`, all with the patch in.
If applied, a test belongs in 773 (the seam's): the probe above, as cells.

```diff
--- a/engine/kernel/world/build/rules_run.gd
+++ b/engine/kernel/world/build/rules_run.gd
@@ -20,6 +20,8 @@
 
 const Check := preload("res://kernel/world/build/rules_check.gd")
 const FEET_LIFT := 0.05                  # metres: feet standing on a block's top read as the cell above it
+const REENTER_FRAMES := 60               # F3: a run going is restarted by entering its start zone only after the feet
+                                         # were out of that zone this many frames (1 s): a step off and back is not a restart
 
 var layer: RefCounted = null             # rules_layer.gd (read only)
 var facade: RefCounted = null            # rules_facade.gd or one extending it
@@ -41,6 +43,7 @@
 var events := {}                         # "start" / "finish" -> true: made in the last frame, read as triggers now
 var _next_events := {}
 var last_finish := {}                    # {"run", "frames", "best_frames", "new_best"} of the last finish
+var left_at := {}                        # F3: zone id -> the frame the feet cell last left it (this visit)
 
 
 func _init(rules_layer: RefCounted = null, f: RefCounted = null, recs: RefCounted = null) -> void:
@@ -75,6 +78,7 @@
 	counters.clear()
 	counted.clear()
 	inside.clear()
+	left_at.clear()
 	events.clear()
 	_next_events.clear()
 	run_name = ""
@@ -97,6 +101,9 @@
 			here[z] = true
 	events = _next_events
 	_next_events = {}
+	for z: int in inside:
+		if not here.has(z):
+			left_at[z] = frame
 	var since := frame - frame0
 	var ids: Array = rules.keys()
 	ids.sort()
@@ -177,6 +184,10 @@
 
 
 func _start(name: String, r: Dictionary, feet: Vector3i) -> void:
+	var w0: Dictionary = r.when
+	if running and name == run_name and str(w0.on) == "enter" and w0.has("zone") \
+			and frame - int(left_at.get(int(w0.zone), -REENTER_FRAMES)) < REENTER_FRAMES:
+		return                                   # back on the start a moment after stepping off: the run goes on
 	_close_all()
 	_coins_back()
 	counters.clear()
```
