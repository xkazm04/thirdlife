extends RefCounted
## Lane K (spark world-sandbox M5, 27 Nov 2026): a riser the visitor steps up (world_body.gd `_ground_move`,
## world_space.gd `walk`, both only with `step_risers`, which only the village visitor sets).
##
## After the lift by `step_up` and the sweep, the probe down puts the capsule's round foot on the riser's EDGE while its
## centre is still in front of it (up to 0.335 m back for a 0.25 m riser, radius 0.35): the contact normal reads steeper
## than `max_slope_deg`, and the ray under the centre finds the lower floor. Without the flag that is "walked off an
## edge" (drive drops him back) or "too steep" (walk refuses), so a 0.125-0.5 m riser stopped him (PATCHES-WP1.md P2).
## With it, a ray straight down at the centre plus the radius (and 2 cm) along the move asks whether a walkable top lies
## there within `step_up` over the feet: a step, a slab, a kerb. Then he stands where the foot met the edge (the sweep
## put him there, so the capsule fits) and rolls over it on the next ticks: his feet only go up (no pop, no dip).
## A wall's top 1 m up is out of reach; a fence rail's top is too thin to be met by the ray past the foot.
## Down a step it is the same edge from the other side: the foot rolls off it while the ray under the centre finds the
## lower tread within `step_up` (`floor_under`): he stands on the edge and goes down with it instead of a fall per step.
## A drop deeper than `step_up` is a ledge: he walks off it and falls, as before.
## Only the Home's blocks (TAGS: block_mesh.gd's bodies) are stepped so: the village's bushes, trunks, rocks, rails and
## walls, a game's copied colliders, the Home's pieces and the land keep stopping him as they did (harden.bush_block: a
## 0.6 m bush on a bank stands under `step_up` over his feet and must still stop him).

const AHEAD := 0.02                 # m past the radius
const ABOVE := 0.01                 # m: the top must stand at least this far over the feet
const TAGS := ["home blocks"]       # the bodies whose risers are stepped (world_space.gd `_tags`)


## True when the body `rid` is one whose risers he steps (TAGS).
static func steps_on(sp: Object, rid: RID) -> bool:
	return TAGS.has(str((sp.get("_tags") as Dictionary).get(rid, "")))


## The walkable top's y ahead of the capsule at `pos` (feet) along the horizontal `move`, within `step_up` over
## `from_y`, on a body of TAGS, or NAN.
static func top_ahead(sp: Object, pos: Vector3, move: Vector3, from_y: float) -> float:
	var dir := Vector3(move.x, 0.0, move.z)
	if dir.length() < 0.00001:
		return NAN
	dir = dir.normalized()
	var at: Vector3 = pos + dir * (float(sp.get("walker_radius")) + AHEAD)
	var step: float = sp.get("step_up")
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, from_y + step + 0.001, at.z), Vector3(at.x, from_y + ABOVE, at.z), 1)
	q.exclude = [sp.get("body")]
	var h: Dictionary = PhysicsServer3D.space_get_direct_state(sp.get("space")).intersect_ray(q)
	if h.is_empty() or (h.normal as Vector3).y < cos(deg_to_rad(float(sp.get("max_slope_deg")))) - 0.0001 or not steps_on(sp, h.rid):
		return NAN
	return (h.position as Vector3).y


## The walkable floor's y straight under the capsule's centre at `pos` (feet), at most `reach` under the feet, or NAN.
static func floor_under(sp: Object, pos: Vector3, reach: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.05, 0.0), pos - Vector3(0.0, reach, 0.0), 1)
	q.exclude = [sp.get("body")]
	var h: Dictionary = PhysicsServer3D.space_get_direct_state(sp.get("space")).intersect_ray(q)
	if h.is_empty() or (h.normal as Vector3).y < cos(deg_to_rad(float(sp.get("max_slope_deg")))) - 0.0001:
		return NAN
	return (h.position as Vector3).y
