# Patches P2 asks of files outside its scope

P2 works without any of them. None is applied.

## 1. `kernel/world/pack.gd` and `kernel/runner/worker.gd`: tick the pack's contact pass at a named place (optional)

Today the pack's `TLContact.Tracker` (a node under `TLPack`, process priority 100) is ticked by the scene tree, after every
default-priority node of the pack and before the physics step, in the order the bodies entered the tree. That order is
stable and is the same order the per-body `TLContact` nodes had, which is why no hash moved. If the Director would
rather the kernel's own tick call it (so the order is written in `tick()` and not implied by a priority number):

```gdscript
# pack.gd tick(), after entry.call("_pack_tick", ...) and before the census:
var tr: Variant = ctx.get_meta(&"tl_tracker") if ctx.has_meta(&"tl_tracker") else null
if tr != null and is_instance_valid(tr):
    tr.call("_physics_process", 0.0)
# and in TLContact.tracker_of(): tr.set_physics_process(false) after add_child
```

Reason: one visible place for "what the kernel does in a tick". Cost: the tracker would then run inside the
`TLContext.current` bracket of the pack instead of after it (`_End` clears it at priority 0); `TLContact` already asks
`TLContext.of` for its pack, so nothing in it depends on the difference. Not needed for speed.

## 2. `kernel/world/pack.gd` `_census`: skip the tracker node (cosmetic)

`entities_max` of a pack's result is one higher than before (the `TLTracker` node). Nothing reads the exact value except
the V3 budget (5,000 nodes). No patch needed.

## 3. `tl_vehicle.gd`, `tl_biped.gd` (not in P2's scope)

`TLVehicle.create` makes its contact with `TLContact.new()`: it is picked up by the pack's tracker like any other and
needs no change. `TLBiped` has no contact tracker of its own and was not touched.
