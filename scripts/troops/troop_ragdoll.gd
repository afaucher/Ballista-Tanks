class_name TroopRagdoll
extends Node3D
## A dead troop: one RigidBody3D per piece, posed where the troop's pieces were, joined at the
## waist, neck, shoulders, elbows, hips and knees with limited joints so limbs flop but don't bend
## backwards. The shield and spear fall off as loose bodies. Cosmetic: it fades after FADE_AFTER
## seconds (PINNED_FADE when a bolt pinned it).
##
## A bolt pins a piece by freezing it (kinematic) and carrying it along (Bolt), so the rest of the
## body hangs from it on the joints; when the bolt sticks, the frozen piece is the anchor.

const LAYER := 8          # ragdoll pieces: bolts hit them
const GEAR_LAYER := 16    # dropped shields and spears: they only land on the world
const FADE_AFTER := 20.0
const PINNED_FADE := 30.0
const FADE_TIME := 1.5
const SHOVE_COOLDOWN := 0.4
const SLACK_DEG := 3.0     # projection leaves joints this far past a limit to the physics
const SLACK_M := 0.03

## Joint limits (degrees), per axis of the troop's rest frame, child off parent: x pitches (a
## hanging limb swings forward, an upright piece tips back), y twists about the bone, z rolls
## (a hanging limb swings to +x). Elbows and knees are hinges: x only, one way.
const JOINTS := {
	"torso": {"x": [-25, 25], "y": [-20, 20], "z": [-20, 20]},
	"head": {"x": [-35, 35], "y": [-40, 40], "z": [-25, 25]},
	"upper_arm_l": {"x": [-60, 85], "y": [-45, 45], "z": [-80, 10]},
	"upper_arm_r": {"x": [-60, 85], "y": [-45, 45], "z": [-10, 80]},
	"forearm_l": {"x": [0, 135], "y": [0, 0], "z": [0, 0]},
	"forearm_r": {"x": [0, 135], "y": [0, 0], "z": [0, 0]},
	"thigh_l": {"x": [-30, 90], "y": [-20, 20], "z": [-45, 10]},
	"thigh_r": {"x": [-30, 90], "y": [-20, 20], "z": [-10, 45]},
	"shin_l": {"x": [-130, 0], "y": [0, 0], "z": [0, 0]},
	"shin_r": {"x": [-130, 0], "y": [0, 0], "z": [0, 0]},
}

var team := 0
var bodies := {}          ## piece name -> RigidBody3D
var gear: Array[RigidBody3D] = []
var joints := {}          ## child piece name -> Joint3D
var parents := {}         ## child piece name -> parent piece name
var pinned := {}          ## piece name -> the Bolt carrying it
var age := 0.0

var _offsets := {}        # child piece name -> its joint in the parent's space
var _shove_t := {}        # tank instance id -> seconds until it can shove again
var _fading := false


## Build the ragdoll from a living troop's current pose; every piece starts with the troop's
## velocity plus `impulse` (more on the pieces near `at`).
static func from_troop(t: Troop, impulse: Vector3, at := Vector3.INF) -> TroopRagdoll:
	var rag := TroopRagdoll.new()
	rag.team = t.team
	rag.name = "Ragdoll"
	t.get_parent().add_child(rag)
	var d := Troop.dims()
	# Joints take their frames from the bodies' poses when they are made, so the bodies start in
	# the rest pose (every piece square to the troop), get joined, then take the dying pose.
	var rest := Transform3D(Basis.looking_at(t.facing, Vector3.UP), t.global_position)
	var rest_at := {}
	var pose := {}
	for p: String in Troop.PIECES:
		var info: Dictionary = d[p]
		var joint := Troop.v3(info.joint)
		rest_at[p] = joint if info.parent == "" else rest_at[info.parent] + joint
		var pivot: Node3D = t.pieces[p]
		if Troop.ATTACHED.has(p):   # rides on its parent's body as it is
			pivot.reparent(rag.bodies[info.parent], false)
			continue
		pose[p] = pivot.global_transform.orthonormalized()
		var b := RigidBody3D.new()
		b.name = p
		var is_gear := Troop.GEAR.has(p)
		b.collision_layer = GEAR_LAYER if is_gear else LAYER
		b.collision_mask = 1 if is_gear else 1 | 2   # not each other: piles of ragdolls fight their joints
		b.mass = float(info.mass)
		b.constant_force = Vector3.DOWN * Troop.GRAVITY * b.mass   # the project's default gravity is zero
		b.linear_damp = 0.05
		b.angular_damp = 0.8
		b.continuous_cd = false
		rag.add_child(b)
		b.global_transform = Transform3D(rest.basis, rest * rest_at[p])
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Troop.v3(info.box)
		cs.shape = box
		cs.position = Troop.v3(info.center)
		b.add_child(cs)
		# The visuals move over to the body (the pieces under this one stay on their own pivots).
		for c in pivot.get_children():
			if c is Node3D and not t.pieces.values().has(c):
				c.reparent(b, false)
		if is_gear:
			rag.gear.append(b)
		else:
			rag.bodies[p] = b
			if info.parent != "":
				rag.parents[p] = info.parent
				rag._offsets[p] = Troop.v3(info.joint)
	for p: String in rag.parents:
		rag._join(p)
	# The whole body moves off as one: the hit's velocity plus a tumble about the point it hit
	# (pieces flung apart would fight their joints).
	var com := t.global_position + Vector3.UP * 0.6
	var hit_at := com if at == Vector3.INF else at
	var spin := (hit_at - com).cross(impulse) * 3.0
	if spin.length() < 1.0:
		spin = impulse.cross(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))).normalized() * 2.0
	spin = spin.limit_length(minf(impulse.length() * 0.5, 9.0))
	for p: String in pose:
		var b: RigidBody3D = rag.bodies[p] if rag.bodies.has(p) else rag.gear[Troop.GEAR.find(p)]
		b.global_transform = pose[p]
		b.linear_velocity = t.velocity + impulse + spin.cross(b.global_position - com)
		b.angular_velocity = spin
	return rag


# Joins piece p to its parent at p's origin (its joint) with a 6DOF joint framed square to the
# troop's rest pose (the bodies are in it now): no stretch, each axis turning within its limits.
func _join(p: String) -> void:
	var a: RigidBody3D = bodies[parents[p]]
	var b: RigidBody3D = bodies[p]
	var j := Generic6DOFJoint3D.new()
	j.name = "joint_" + p
	var lim: Dictionary = JOINTS[p]
	for axis in ["x", "y", "z"]:
		var r: Array = lim[axis]
		# The engine measures parent off child: the range flips.
		j.call("set_param_" + axis, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, deg_to_rad(-r[1]))
		j.call("set_param_" + axis, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(-r[0]))
		j.call("set_param_" + axis, Generic6DOFJoint3D.PARAM_ANGULAR_ERP, 0.9)   # firm limits under a body's weight
	add_child(j)
	j.global_transform = Transform3D(a.global_basis, b.global_position)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)
	joints[p] = j


## Piece p's turn off its parent, in degrees about the rest frame's x, y and z, decomposed the
## way the 6DOF joint measures its limits (Bullet's XYZ: rotation = X * Y * Z, Godot's ZYX order).
## The rest pose is all zeros.
func joint_angles(p: String) -> Vector3:
	var a: RigidBody3D = bodies[parents[p]]
	var b: RigidBody3D = bodies[p]
	var rel := a.global_basis.orthonormalized().inverse() * b.global_basis.orthonormalized()
	var e := rel.get_euler(EULER_ORDER_ZYX)
	return Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z))


## How far each joint is past its limits, in degrees (0 when inside), summed over its axes.
func limit_errors() -> Dictionary:
	var out := {}
	for p: String in joints:
		var ang := joint_angles(p)
		var err := 0.0
		for i in 3:
			var r: Array = JOINTS[p]["xyz"[i]]
			err += maxf(maxf(r[0] - ang[i], ang[i] - r[1]), 0.0)
		out[p] = err
	return out


## The first piece a line from `from` along unit `dir` passes through within `reach` metres (a
## bolt's path); the piece nearest to `from` if it misses them all.
func pierced_piece(from: Vector3, dir: Vector3, reach := 1.2) -> String:
	var best := ""
	var best_t := reach
	for p: String in bodies:
		var cs := _shape(p)
		var body: RigidBody3D = bodies[p]
		var inv := (body.global_transform * cs.transform).affine_inverse()
		var o := inv * from
		var d := inv.basis * dir
		var half: Vector3 = (cs.shape as BoxShape3D).size * 0.5
		var t0 := -INF
		var t1 := INF
		for i in 3:   # slabs
			if absf(d[i]) < 1e-6:
				if absf(o[i]) > half[i]:
					t0 = INF
				continue
			var ta: float = (-half[i] - o[i]) / d[i]
			var tb: float = (half[i] - o[i]) / d[i]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
		if t0 <= t1 and t1 >= 0.0 and t0 < best_t:
			best_t = t0
			best = p
	return best if best != "" else closest_piece(from)


func _shape(p: String) -> CollisionShape3D:
	return bodies[p].find_children("*", "CollisionShape3D", false, false)[0]


## The piece whose collision box is nearest to `point`.
func closest_piece(point: Vector3) -> String:
	var best := ""
	var best_d := INF
	for p: String in bodies:
		var b: RigidBody3D = bodies[p]
		var cs := _shape(p)
		var half: Vector3 = (cs.shape as BoxShape3D).size * 0.5
		var lp := (b.global_transform * cs.transform).affine_inverse() * point
		var outside := (lp.abs() - half).max(Vector3.ZERO)
		var dist := outside.length()
		if dist < best_d:
			best_d = dist
			best = p
	return best


func piece_of(body: Object) -> String:
	for p: String in bodies:
		if bodies[p] == body:
			return p
	return ""


## A bolt takes hold of piece p: frozen, it follows the bolt from now on (Bolt moves it).
func pin(p: String, bolt: Node) -> void:
	var b: RigidBody3D = bodies[p]
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	b.freeze = true
	pinned[p] = bolt
	age = 0.0


## The bolt let go (it flew off or broke): the piece falls with `vel`.
func unpin(p: String, vel: Vector3) -> void:
	if not pinned.has(p):
		return
	pinned.erase(p)
	var b: RigidBody3D = bodies[p]
	b.freeze = false
	b.linear_velocity = vel


func is_pinned() -> bool:
	return not pinned.is_empty()


## Joint projection, once a physics tick with the last step's results: the engine's joints give
## under hard hits and when a bolt drags a piece at 80 m/s, so every joint past its limits (or
## pulled apart) is set back onto them, working out from the anchor (a pinned piece, else the
## pelvis). What is drawn is the projected pose.
func project() -> void:
	var root: String = pinned.keys()[0] if is_pinned() else "pelvis"
	var done := {root: true}
	var todo: Array[String] = [root]
	while not todo.is_empty():
		var fixed: String = todo.pop_front()
		for p: String in parents:
			var other := ""
			if parents[p] == fixed:
				other = p
			elif p == fixed:
				other = parents[p]
			if other == "" or done.has(other):
				continue
			done[other] = true
			todo.append(other)
			if not pinned.has(other):
				_project(p, other == p)


# Sets piece p (move_child) or its parent (not move_child) back within p's joint limits and
# onto the joint, keeping the other one where it is.
func _project(p: String, move_child: bool) -> void:
	var a: RigidBody3D = bodies[parents[p]]
	var b: RigidBody3D = bodies[p]
	var ab := a.global_basis.orthonormalized()
	var bb := b.global_basis.orthonormalized()
	var e := (ab.inverse() * bb).get_euler(EULER_ORDER_ZYX)
	var c := e
	for i in 3:
		var r: Array = JOINTS[p]["xyz"[i]]
		c[i] = clampf(e[i], deg_to_rad(r[0] - SLACK_DEG), deg_to_rad(r[1] + SLACK_DEG))
	var off: Vector3 = _offsets[p]
	var turned := not c.is_equal_approx(e)
	if move_child:
		if turned:
			bb = ab * Basis.from_euler(c, EULER_ORDER_ZYX)
		var at := a.global_position + ab * off
		if turned or b.global_position.distance_to(at) > SLACK_M:
			b.global_transform = Transform3D(bb, at)
			b.angular_velocity = a.angular_velocity
			b.linear_velocity = a.linear_velocity + a.angular_velocity.cross(at - a.global_position)
	else:
		if turned:
			ab = bb * Basis.from_euler(c, EULER_ORDER_ZYX).inverse()
		var at := b.global_position - ab * off
		if turned or a.global_position.distance_to(at) > SLACK_M:
			a.global_transform = Transform3D(ab, at)
			a.angular_velocity = b.angular_velocity
			a.linear_velocity = b.linear_velocity


func _physics_process(dt: float) -> void:
	age += dt
	if not _fading:
		project()
	_tank_shoves(dt)
	var life := PINNED_FADE if is_pinned() else FADE_AFTER
	if age > life and not _fading:
		_fade()


# Tanks driving through a downed troop kick it along (kinematic bodies don't push reliably).
func _tank_shoves(dt: float) -> void:
	for k in _shove_t.keys():
		_shove_t[k] -= dt
	for t: Tank in get_tree().get_nodes_in_group("tanks"):
		if _shove_t.get(t.get_instance_id(), 0.0) > 0.0 or t.velocity.length() < Troop.RUN_OVER_SPEED:
			continue
		var hit := false
		for p: String in bodies:
			if pinned.has(p):
				continue
			var rel: Vector3 = bodies[p].global_position - t.global_position
			var along := rel.dot(t.forward)
			var side := rel - t.forward * along
			if absf(along) < 2.6 and side.length() < 1.6:
				hit = true
				break
		if not hit:
			continue
		_shove_t[t.get_instance_id()] = SHOVE_COOLDOWN
		for p: String in bodies:
			if not pinned.has(p):
				var b: RigidBody3D = bodies[p]
				b.sleeping = false
				b.linear_velocity = t.velocity * Troop.RUN_OVER_SHOVE + t.up * Troop.RUN_OVER_POP * 0.6


# Shrink away, then go.
func _fade() -> void:
	_fading = true
	var tw := create_tween().set_parallel(true)
	for b in bodies.values() + gear:
		b.freeze = true
		for c in b.get_children():
			if c is Node3D and not c is CollisionShape3D:
				tw.tween_property(c, "scale", Vector3.ONE * 0.01, FADE_TIME)
	tw.chain().tween_callback(queue_free)
