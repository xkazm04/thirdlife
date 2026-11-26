extends RefCounted
## SEAM M5 stub of the plant scatter (lane P fills this file; lane L's plant tool calls it): the trees and bushes a
## scatter brush stroke writes, as seeded `put` ops of the pieces layer (contracts/BUILD.md "Milestone 5": "Trees and
## bushes are put ops (the scatter brush writes one seeded put per tree)"). Static, no state; it reads the Home
## (`build`: home_build.gd, e.g. its pieces layer and protection) and never writes it: the caller applies the ops as one
## batch (one undo). The stub scatters nothing.
##   var ops: Array = PlantScatter.scatter(build, centre, 6.0, "tree", 4.0, seed)    # then build.apply(ops)
## Returns put ops `{"op": "put", "at": [x, y, z], "part": "tree" | "bush", "params"?: {...}, "rot": 0..3, "seed": n}`
## (no v, author or batch: the log fills them in), each one the pieces layer would take, for a disc of `radius_m`
## round `centre` at `per_100m2` plants per 100 m2; the same arguments give the same ops (the seed, never the clock).

const KINDS := ["tree", "bush"]


static func scatter(_build: RefCounted, _centre: Vector3, _radius_m: float, _kind: String, _per_100m2: float, _seed: int) -> Array:
	return []
