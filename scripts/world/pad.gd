class_name Pad
extends Area3D
## A launch pad (sets the tank's velocity: a jump across the core) or a boost pad (adds speed
## along the tank's nose). Lies flat on its surface: local +Y is the surface's up.

var kind := "boost"
var launch_velocity := Vector3.ZERO   ## world space, launch pads only
var boost := 12.0
var size := 7.0

var _cooldown := {}


func _init(p_kind := "boost", p_size := 7.0) -> void:
	kind = p_kind
	size = p_size


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var slab := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(size, 0.15, size)
	slab.mesh = m
	slab.material_override = Look.pad(kind)
	slab.position.y = 0.08
	add_child(slab)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 3.0, size)
	cs.shape = shape
	cs.position.y = 1.5
	add_child(cs)
	body_entered.connect(_on_body)


func _on_body(body: Node3D) -> void:
	if not body is Tank:
		return
	var now := Time.get_ticks_msec()
	if now - int(_cooldown.get(body, -10000)) < 600:
		return
	_cooldown[body] = now
	if kind == "launch":
		body.launch(launch_velocity)
	else:
		body.boost(boost)
