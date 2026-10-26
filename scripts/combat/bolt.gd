class_name Bolt
extends Node3D
## A ballista bolt. Two gravity modes are being prototyped (docs/design/game-concept.md):
##   STRAIGHT      no drop at all
##   SHOOTER_DOWN  falls toward the shooter's "down" at the moment of firing, for the whole flight
## The mode is global so the whole match plays one way; B toggles it.
##
## Carry (docs/design/troops.md): a bolt that hits a troop, alive or a ragdoll, kills it and pins
## the hit piece to its shaft, then flies on a little slower, dragging the body; several troops
## in a line go on the same bolt. When the bolt sticks, the pinned pieces stay with it and the
## troops hang there swinging.

enum Mode { STRAIGHT, SHOOTER_DOWN }

static var mode := Mode.SHOOTER_DOWN

const GRAVITY := 20.0
const LIFE := 5.0
const STUCK_LIFE := 12.0
const MASK := 1 | 2 | 4 | 8   # world, tanks, troops (Troop.LAYER), ragdolls (TroopRagdoll.LAYER)
const CARRY_SLOW := 0.88      # speed kept per troop skewered
const PIN_BACK := 0.8         # the first troop sits this far behind the tip, the next ones further back
const PIN_STEP := 0.45
const CARRY_DRAG := 0.5       # how hard a carried body is pulled toward CARRY_TRAIL of the bolt's speed
const CARRY_TRAIL := 0.8      # under the bolt's speed: the body streams out behind the pin
const CARRY_THUD := 0.1       # speed a carried body keeps when the bolt sticks

var shooter: Tank
var velocity := Vector3.ZERO
var gravity := Vector3.ZERO
var stuck := false

var carried: Array = []   ## [{rag: TroopRagdoll, piece: String, offset: Transform3D}]

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
		if _age > (TroopRagdoll.PINNED_FADE if not carried.is_empty() else STUCK_LIFE):
			queue_free()
		return
	if _age > LIFE:
		_let_go()
		queue_free()
		return
	velocity += gravity * dt
	var to := global_position + velocity * dt
	var exclude := _exclude()
	# Troops in the way are skewered and the bolt flies on through them.
	for i in 8:
		var hit := ray(get_world_3d().direct_space_state, global_position, to, exclude)
		if hit.is_empty():
			global_position = to
			_face()
			_drag_carried()
			return
		if _skewer(hit, exclude):
			continue
		global_position = hit.position
		if hit.collider is Tank:
			hit.collider.take_hit(velocity)
			_let_go()
			queue_free()
		else:
			stuck = true   # quivering in the wall, with whatever it carries
			_age = 0.0
			_drag_carried()
		return
	_drag_carried()


# A troop or a ragdoll piece on the bolt's path: kill it, pin the hit piece and carry on.
# False if the hit is something else.
func _skewer(hit: Dictionary, exclude: Array[RID]) -> bool:
	var rag: TroopRagdoll
	var piece := ""
	if hit.collider is Troop:
		var troop: Troop = hit.collider
		exclude.append(troop.get_rid())
		rag = troop.die(velocity * 0.15, hit.position)
		if rag == null:
			return true
		var dir := velocity.normalized()
		piece = rag.pierced_piece(hit.position - dir * 0.3, dir)
	elif hit.collider is RigidBody3D and hit.collider.get_parent() is TroopRagdoll:
		rag = hit.collider.get_parent()
		exclude.append(hit.collider.get_rid())
		piece = rag.piece_of(hit.collider)
		if piece == "" or rag.pinned.has(piece):
			return true
	else:
		return false
	for b: RigidBody3D in rag.bodies.values():
		exclude.append(b.get_rid())
	# Hang the piece on the shaft: its hit point slides back to the next free spot on the axis.
	global_position = hit.position
	_face()
	var b: RigidBody3D = rag.bodies[piece]
	var offset := global_transform.affine_inverse() * b.global_transform
	var hit_local := global_transform.affine_inverse() * Vector3(hit.position)
	offset.origin += Vector3(0, 0, PIN_BACK + PIN_STEP * carried.size()) - hit_local
	rag.pin(piece, self)
	for o: RigidBody3D in rag.bodies.values():
		o.linear_velocity = velocity * 0.9
	carried.append({"rag": rag, "piece": piece, "offset": offset})
	velocity *= CARRY_SLOW
	return true


# The pinned pieces ride on the bolt; the rest of each body trails behind it, pulled along at a
# little under the bolt's speed. When the bolt sticks the bodies thud to a stop and hang.
func _drag_carried() -> void:
	var dir := velocity.normalized()
	for c: Dictionary in carried:
		var rag: TroopRagdoll = c.rag
		if not is_instance_valid(rag):
			continue
		var pinned: RigidBody3D = rag.bodies[c.piece]
		pinned.global_transform = global_transform * c.offset
		pinned.linear_velocity = Vector3.ZERO if stuck else velocity   # what the joints pass on
		pinned.angular_velocity = Vector3.ZERO
		for b: RigidBody3D in rag.bodies.values():
			if b == pinned or b.freeze:
				continue
			if stuck:
				b.linear_velocity *= CARRY_THUD
			else:
				var along := b.linear_velocity.dot(dir)
				b.linear_velocity += dir * (velocity.length() * CARRY_TRAIL - along) * CARRY_DRAG


# The bolt is going away in flight: whatever it carries falls off.
func _let_go() -> void:
	for c: Dictionary in carried:
		if is_instance_valid(c.rag):
			c.rag.unpin(c.piece, velocity)
	carried.clear()


func _exclude() -> Array[RID]:
	var out: Array[RID] = []
	if is_instance_valid(shooter):
		out.append(shooter.get_rid())
	for c: Dictionary in carried:
		if is_instance_valid(c.rag):
			for b: RigidBody3D in c.rag.bodies.values():
				out.append(b.get_rid())
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
