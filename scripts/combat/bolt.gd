class_name Bolt
extends Node3D
## A ballista bolt. Two gravity modes are being prototyped (docs/design/game-concept.md):
##   STRAIGHT      no drop at all
##   SHOOTER_DOWN  falls toward the shooter's "down" at the moment of firing, for the whole flight
## The mode is global so the whole match plays one way; B toggles it.

enum Mode { STRAIGHT, SHOOTER_DOWN }

static var mode := Mode.SHOOTER_DOWN

const GRAVITY := 20.0
const LIFE := 5.0
const STUCK_LIFE := 12.0
const MASK := 1 | 2

var shooter: Tank
var velocity := Vector3.ZERO
var gravity := Vector3.ZERO
var stuck := false

var _age := 0.0
var _start := Vector3.ZERO


static func mode_name() -> String:
	return "straight" if mode == Mode.STRAIGHT else "shooter's down"


static func gravity_for(shooter_up: Vector3) -> Vector3:
	return Vector3.ZERO if mode == Mode.STRAIGHT else -shooter_up * GRAVITY


func setup(from: Tank, pos: Vector3, vel: Vector3, grav: Vector3) -> void:
	shooter = from
	_start = pos
	velocity = vel
	gravity = grav


func _ready() -> void:
	global_position = _start
	_build()
	_face()


func _physics_process(dt: float) -> void:
	_age += dt
	if stuck:
		if _age > STUCK_LIFE:
			queue_free()
		return
	if _age > LIFE:
		queue_free()
		return
	velocity += gravity * dt
	var from := global_position
	var hit := ray(get_world_3d().direct_space_state, from, from + velocity * dt, _exclude())
	if hit.is_empty():
		global_position = from + velocity * dt
		_face()
		return
	global_position = hit.position
	if hit.collider is Tank:
		hit.collider.take_hit(velocity)
		queue_free()
	else:
		stuck = true   # quivering in the wall
		_age = 0.0


func _exclude() -> Array[RID]:
	var out: Array[RID] = []
	if is_instance_valid(shooter):
		out.append(shooter.get_rid())
	return out


static func ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK)
	q.exclude = exclude
	return space.intersect_ray(q)


## The flight of a bolt fired now: points every dt until it hits something or max_t runs out.
static func predict(space: PhysicsDirectSpaceState3D, pos: Vector3, vel: Vector3, grav: Vector3,
		exclude: Array[RID], max_t := 3.0, dt := 1.0 / 30.0) -> Dictionary:
	var pts := PackedVector3Array([pos])
	var t := 0.0
	while t < max_t:
		vel += grav * dt
		var hit := ray(space, pos, pos + vel * dt, exclude)
		if not hit.is_empty():
			pts.append(hit.position)
			return {"points": pts, "hit": true, "end": hit.position}
		pos += vel * dt
		pts.append(pos)
		t += dt
	return {"points": pts, "hit": false, "end": pos}


func _face() -> void:
	if velocity.length() < 0.1:
		return
	var d := velocity.normalized()
	var ref := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	global_basis = Basis.looking_at(d, ref)


func _build() -> void:
	# The same textured bolt the ballista loads; its origin is the nock, so shift it back to put
	# the tip on this node.
	var path := TankModel.PART_DIR + "bolt.glb"
	if ResourceLoader.exists(path):
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		inst.position.z = float(TankModel.dims().bolt_length)
		add_child(inst)
		return
	var shaft := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.09
	cm.height = 2.2
	shaft.mesh = cm
	shaft.material_override = Look.wood()
	shaft.rotation.x = PI * 0.5
	shaft.position.z = 0.9
	add_child(shaft)
	var tip := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0
	tm.bottom_radius = 0.24
	tm.height = 0.55
	tip.mesh = tm
	tip.material_override = Look.iron()
	tip.rotation.x = -PI * 0.5
	tip.position.z = -0.45
	add_child(tip)
