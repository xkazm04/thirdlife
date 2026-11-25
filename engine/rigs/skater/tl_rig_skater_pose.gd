class_name TLRigSkaterPose
extends RefCounted
## A pose of thirdjam's skater (24 bones) and the pose arithmetic of Unreal's animation runtime that the driver's
## graph uses, written as Unreal does it (UE 5.9; file:line in the comments are the engine's own source under
## Engine/Source/Runtime). Internal to engine/rigs/skater.
##
## Local rotations for every bone; local translations only for the two bones thirdjam's clips move (pelvis, and the
## stick bone in six clips): every other bone keeps its rest translation, in all 202 clips (build_skater.gd counted).
## Space: the baked skeleton's own (the glTF export: metres, x forward, y up, z right). `ue_*` helpers go between it
## and Unreal's component space (centimetres, x forward, y right, z up), in which the driver's own numbers are written.

const N: int = 24
const PELVIS: int = 1
const STICK: int = 16

var q: Array = []            # 24 Quaternion, local
var tp: Vector3              # pelvis translation, local
var ts: Vector3              # stick_socket translation, local

static var parents: PackedInt32Array = PackedInt32Array()
static var rest_q: Array = []
static var rest_t: Array = []          # 24 Vector3
static var bone_names: PackedStringArray = PackedStringArray()


static func bind(sk: Skeleton3D) -> void:
	if parents.size() == N:
		return
	parents.resize(N)
	rest_q = []
	rest_t = []
	bone_names = PackedStringArray()
	for b: int in range(N):
		parents[b] = sk.get_bone_parent(b)
		var r: Transform3D = sk.get_bone_rest(b)
		rest_q.append(r.basis.get_rotation_quaternion())
		rest_t.append(r.origin)
		bone_names.append(sk.get_bone_name(b))


static func bone(bname: String) -> int:
	return bone_names.find(bname)


static func rest() -> TLRigSkaterPose:
	var p: TLRigSkaterPose = TLRigSkaterPose.new()
	p.q = rest_q.duplicate()
	p.tp = rest_t[PELVIS]
	p.ts = rest_t[STICK]
	return p


func copy() -> TLRigSkaterPose:
	var p: TLRigSkaterPose = TLRigSkaterPose.new()
	p.q = q.duplicate()
	p.tp = tp
	p.ts = ts
	return p


## FAnimationRuntime::BlendPosesTogether (Engine/Private/Animation/AnimationRuntime.cpp:351-370): the first pose
## scaled by its weight, every further rotation added on the accumulator's side of the sphere, then normalised:
## a weighted normalised lerp. Weights are used as given (the callers pass them clamped, in Unreal's order).
static func blend(poses: Array, weights: PackedFloat32Array) -> TLRigSkaterPose:
	if poses.size() == 1:
		return (poses[0] as TLRigSkaterPose).copy()
	var out: TLRigSkaterPose = TLRigSkaterPose.new()
	out.q.resize(N)
	var p0: TLRigSkaterPose = poses[0]
	var w0: float = weights[0]
	out.tp = p0.tp * w0
	out.ts = p0.ts * w0
	for b: int in range(N):
		var a: Quaternion = p0.q[b]
		var ax: float = a.x * w0
		var ay: float = a.y * w0
		var az: float = a.z * w0
		var aw: float = a.w * w0
		for k: int in range(1, poses.size()):
			var c: Quaternion = (poses[k] as TLRigSkaterPose).q[b]
			var w: float = weights[k]
			if ax * c.x + ay * c.y + az * c.z + aw * c.w < 0.0:
				w = -w
			ax += c.x * w
			ay += c.y * w
			az += c.z * w
			aw += c.w * w
		var n: float = sqrt(ax * ax + ay * ay + az * az + aw * aw)
		out.q[b] = Quaternion(ax / n, ay / n, az / n, aw / n) if n > 1e-12 else Quaternion.IDENTITY
	for k: int in range(1, poses.size()):
		out.tp += (poses[k] as TLRigSkaterPose).tp * weights[k]
		out.ts += (poses[k] as TLRigSkaterPose).ts * weights[k]
	return out


## FAnimationRuntime::BlendTwoPosesTogether (AnimationRuntime.cpp:477-489): a at 1 - alpha, b at alpha.
static func blend2(a: TLRigSkaterPose, b: TLRigSkaterPose, alpha: float) -> TLRigSkaterPose:
	if alpha <= 0.0:
		return a.copy()
	if alpha >= 1.0:
		return b.copy()
	return blend([a, b], PackedFloat32Array([1.0 - alpha, alpha]))


func local_t(b: int) -> Vector3:
	if b == PELVIS:
		return tp
	if b == STICK:
		return ts
	return rest_t[b]


## Component-space transforms of all bones (parents come first in the skeleton).
func globals() -> Array:
	var g: Array = []
	g.resize(N)
	for b: int in range(N):
		var l: Transform3D = Transform3D(Basis(q[b] as Quaternion), local_t(b))
		g[b] = l if parents[b] < 0 else (g[parents[b]] as Transform3D) * l
	return g


## Component-space rotations only.
func global_rotations() -> Array:
	var g: Array = []
	g.resize(N)
	for b: int in range(N):
		g[b] = (q[b] as Quaternion) if parents[b] < 0 else ((g[parents[b]] as Quaternion) * (q[b] as Quaternion))
	return g


# ------------------------------------------------------------------ Unreal's space
## A point or direction of the skeleton's space as Unreal's component space sees it: (x, y, z) m -> (x, z, y) cm.
static func ue_vec(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, v.y) * 100.0


static func from_ue_vec(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, v.y) * 0.01


## A rotation given in Unreal's axes as a rotation of the skeleton's space (the exporter's own rule for bone
## rotations: the two spaces are mirror images, so the axis is carried over and the angle changes sign).
static func from_ue_quat(u: Quaternion) -> Quaternion:
	return Quaternion(-u.x, -u.z, -u.y, u.w)


## FRotator(Pitch, Yaw, Roll).Quaternion() (Core/Private/Math/UnrealMath.cpp, FRotator::Quaternion), degrees in,
## Unreal's axes out. Blueprint's MakeRotator takes (Roll, Pitch, Yaw): mind the order at the call.
static func ue_rotator_quat(pitch_deg: float, yaw_deg: float, roll_deg: float) -> Quaternion:
	var hp: float = deg_to_rad(fmod(pitch_deg, 360.0)) * 0.5
	var hy: float = deg_to_rad(fmod(yaw_deg, 360.0)) * 0.5
	var hr: float = deg_to_rad(fmod(roll_deg, 360.0)) * 0.5
	var sp: float = sin(hp)
	var cp: float = cos(hp)
	var sy: float = sin(hy)
	var cy: float = cos(hy)
	var sr: float = sin(hr)
	var cr: float = cos(hr)
	return Quaternion(cr * sp * sy - sr * cp * cy, -cr * sp * cy - sr * cp * sy, cr * cp * sy - sr * sp * cy, cr * cp * cy + sr * sp * sy)


## FQuat(Axis, AngleRad) in Unreal's axes (a unit axis).
static func ue_axis_angle_quat(axis: Vector3, angle_deg: float) -> Quaternion:
	var h: float = deg_to_rad(angle_deg) * 0.5
	var s: float = sin(h)
	return Quaternion(axis.x * s, axis.y * s, axis.z * s, cos(h))
