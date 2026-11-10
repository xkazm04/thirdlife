extends Node
## Not a failure: lint passes, but every line marked BYPASS shows up in composability.bypasses.

var score: int = 0                                  # BYPASS: hand-rolled score while "rules" is declared
var body: RigidBody3D


func _pack_setup(ctx) -> void:
	ctx.root.add_child(TLBodies.ground(Vector2(30, 30), "concrete"))
	body = RigidBody3D.new()                        # BYPASS: TLBodies.make
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	body.add_child(shape)
	body.position = Vector3(0, 2, 0)
	ctx.root.add_child(body)
	var area: Area3D = Area3D.new()                 # BYPASS: TLBodies.trigger
	ctx.root.add_child(area)


func _pack_start() -> void:
	body.apply_central_impulse(Vector3(1, 0, 0))    # BYPASS: TLBodies.push


func _input(_event: InputEvent) -> void:           # BYPASS: ctx.input
	score += 1


func _dress() -> void:                              # look and geometry made by hand (never called)
	var mat: Material = StandardMaterial3D.new()    # BYPASS: style (the kernel and the style give materials)
	var sun: Node3D = DirectionalLight3D.new()      # BYPASS: style (the style gives sun and environment)
	var box: Mesh = BoxMesh.new()                   # BYPASS: kit (geometry by hand outside a generator)
	var holder: Node3D = MeshInstance3D.new()       # BYPASS: kit
	holder.free()
	sun.free()
	print(mat, box)
