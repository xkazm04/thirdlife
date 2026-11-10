class_name TLDamage
extends Node
## Contact damage for one target: impacts above a threshold set by the material's hardness take health away.
## Capability: `physics`.
##
##   var d := TLDamage.attach(crate, {hp = 60.0})
##   d.broken.connect(func(by): crate.queue_free())
##
## Law: threshold (N*s) = hardness x impulse_per_hardness (materials.json). An impact of impulse J does
## 100 x (J - threshold) / threshold points of damage, so twice the threshold takes 100 points.
## Impacts are reported by the kernel's movers (anything with a TLContact: bodies from TLBodies.make, TLBall,
## TLVehicle) when they hit the target or the target hits them.

signal damaged(amount: float, by: Node, hp_left: float)
signal broken(by: Node)

var hp: float = 100.0
var max_hp: float = 100.0
var threshold: float = 0.0        ## N*s; 0 means "from the material"
var is_broken: bool = false
var last_impulse: float = 0.0     ## the strongest impact seen so far (for tuning and tests)
var target: Node3D


## Attaches damage to `target` (a body, or a part with bodies under it). Options: hp, threshold.
static func attach(target_: Node3D, opts: Dictionary = {}) -> TLDamage:
	TLContext.require("physics", "TLDamage")
	var d: TLDamage = TLDamage.new()
	d.name = "TLDamage"
	d.target = target_
	for k: String in opts.keys():
		match k:
			"hp":
				d.hp = float(opts[k])
				d.max_hp = d.hp
			"threshold":
				d.threshold = float(opts[k])
			_:
				push_error("TLDamage.attach: unknown option '%s' (hp, threshold)" % k)
	target_.add_child(d)
	_mark(target_, d)
	return d


static func _mark(n: Node, d: TLDamage) -> void:
	if n is CollisionObject3D:
		n.set_meta(&"tl_damage", d)
	for c: Node in n.get_children():
		_mark(c, d)


## The TLDamage a collider belongs to, or null.
static func of(collider: Node) -> TLDamage:
	if collider == null or not collider.has_meta(&"tl_damage"):
		return null
	var d: Variant = collider.get_meta(&"tl_damage")
	return d as TLDamage if is_instance_valid(d) else null


## Kernel door: an impact of `impulse` N*s on `collider`, caused by `by`.
static func report(collider: Node, impulse: float, by: Node) -> void:
	var d: TLDamage = of(collider)
	if d != null:
		d.impact(impulse, by, TLLaws.material_of(collider))


func impact(impulse: float, by: Node = null, material_id: String = "") -> void:
	last_impulse = maxf(last_impulse, impulse)
	var th: float = threshold
	if th <= 0.0:
		th = TLLaws.impact_threshold(material_id if not material_id.is_empty() else "concrete")
	if th <= 0.0:
		th = 1.0
	if impulse > th:
		hurt(100.0 * (impulse - th) / th, by)


## Direct damage in health points (a rule, a hazard), bypassing the impulse law.
func hurt(amount: float, by: Node = null) -> void:
	if is_broken or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	damaged.emit(amount, by, hp)
	if hp <= 0.0:
		is_broken = true
		broken.emit(by)
