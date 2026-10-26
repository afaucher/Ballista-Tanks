class_name Troop
extends CharacterBody3D
## A foot soldier (docs/design/troops.md): a capsule that runs where TroopAI points it, and a toy
## figure of rigid pieces on a simple hierarchy, animated procedurally (legs swing, arms
## counter-swing, the big head bobs and leads, the body leans into turns). On death the pieces
## become a TroopRagdoll.
##
## The pieces are res://assets/troop/<piece>.glb laid out by assets/troop/dims.json when they
## exist, else coloured boxes with the same names and numbers (DEFAULTS). Troop space: origin on
## the ground between the feet, +Y up, forward -Z, left -X; every piece's origin is its joint
## with its parent, and the rest pose (arms hanging) has no rotation on any piece.

signal died(troop: Troop, ragdoll: TroopRagdoll)

const PART_DIR := "res://assets/troop/"
const LAYER := 4                # alive troops; bolts hit them, tanks and other troops don't collide
const RADIUS := 0.35            # the helmet is the tank driver's size (assets/troop/dims.json)
const HEIGHT := 1.55
const RUN_SPEED := 3.6
const ACCEL := 14.0
const TURN_RATE := 9.0          # rad/s the facing turns toward the way it runs
const GRAVITY := 20.0
const STRIDE := 2.6             # run cycles per second at full speed
const RUN_OVER_SPEED := 3.0     # a tank faster than this (relative) knocks a troop down
const RUN_OVER_SHOVE := 1.1     # fraction of the tank's velocity given to the ragdoll
const RUN_OVER_POP := 5.0

## Piece -> parent, joint (in the parent's space), collision box size and centre (piece space), mass.
const DEFAULTS := {
	"pelvis": {"parent": "", "joint": [0, 0.507, 0], "box": [0.366, 0.169, 0.225], "center": [0, 0.042, 0], "mass": 4.2},
	"torso": {"parent": "pelvis", "joint": [0, 0.099, 0], "box": [0.395, 0.338, 0.254], "center": [0, 0.169, 0], "mass": 6.99},
	"head": {"parent": "torso", "joint": [0, 0.338, 0], "box": [0.535, 0.564, 0.535], "center": [0, 0.296, 0], "mass": 7.27},
	"plume": {"parent": "head", "joint": [0, 0.578, 0], "box": [0.085, 0.169, 0.366], "center": [0, 0.085, 0.028], "mass": 0.14},
	"upper_arm_l": {"parent": "torso", "joint": [-0.254, 0.282, 0], "box": [0.113, 0.24, 0.113], "center": [0, -0.12, 0], "mass": 1.68},
	"forearm_l": {"parent": "upper_arm_l", "joint": [0, -0.24, 0], "box": [0.127, 0.24, 0.127], "center": [0, -0.12, 0], "mass": 1.4},
	"upper_arm_r": {"parent": "torso", "joint": [0.254, 0.282, 0], "box": [0.113, 0.24, 0.113], "center": [0, -0.12, 0], "mass": 1.68},
	"forearm_r": {"parent": "upper_arm_r", "joint": [0, -0.24, 0], "box": [0.127, 0.24, 0.127], "center": [0, -0.12, 0], "mass": 1.4},
	"thigh_l": {"parent": "pelvis", "joint": [-0.113, 0, 0], "box": [0.155, 0.24, 0.155], "center": [0, -0.12, 0], "mass": 2.52},
	"shin_l": {"parent": "thigh_l", "joint": [0, -0.24, 0], "box": [0.155, 0.268, 0.183], "center": [0, -0.134, -0.021], "mass": 2.24},
	"thigh_r": {"parent": "pelvis", "joint": [0.113, 0, 0], "box": [0.155, 0.24, 0.155], "center": [0, -0.12, 0], "mass": 2.52},
	"shin_r": {"parent": "thigh_r", "joint": [0, -0.24, 0], "box": [0.155, 0.268, 0.183], "center": [0, -0.134, -0.021], "mass": 2.24},
	"shield": {"parent": "forearm_l", "joint": [-0.099, -0.127, 0], "box": [0.056, 0.366, 0.31], "center": [0, 0, 0], "mass": 1.4},
	"spear": {"parent": "forearm_r", "joint": [0, -0.183, 0], "box": [0.042, 1.832, 0.042], "center": [0, 0.465, 0], "mass": 1.4},
}
## Parents before children.
const PIECES := ["pelvis", "torso", "head", "plume", "upper_arm_l", "forearm_l", "upper_arm_r", "forearm_r",
		"thigh_l", "shin_l", "thigh_r", "shin_r", "shield", "spear"]
## Carried pieces: they fall off as separate bodies when the troop dies.
const GEAR := ["shield", "spear"]
## Pieces fixed to their parent: in a ragdoll they ride on the parent's body.
const ATTACHED := ["plume"]

static var _dims := {}
static var _mats := {}

var team := 0
var alive := true
var move_dir := Vector3.ZERO    ## where TroopAI wants to go (horizontal, length 0..1)
var speed_scale := 1.0          ## TroopAI's urgency: scattering troops sprint
var cheering := false
var facing := Vector3.FORWARD
var pieces := {}                ## piece name -> Node3D pivot at its joint
var rig: Node3D                 ## the figure; leans and bobs on its own

var _phase := 0.0
var _lean := 0.0
var _nod := 0.0                 # head pitch spring: overshoots on stops and starts
var _nod_v := 0.0
var _last_fwd_speed := 0.0
var _cheer_t := 0.0


func _init(p_team := 0) -> void:
	team = p_team


func _ready() -> void:
	add_to_group("troops")
	collision_layer = LAYER
	collision_mask = 1
	floor_max_angle = deg_to_rad(40.0)
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	cs.shape = cap
	cs.position.y = HEIGHT * 0.5
	add_child(cs)
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	_build_pieces()
	_phase = randf() * TAU
	facing = -global_basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.1 else Vector3.FORWARD


## The piece numbers: DEFAULTS, overridden piece by piece from assets/troop/dims.json.
static func dims() -> Dictionary:
	if _dims.is_empty():
		_dims = DEFAULTS.duplicate(true)
		var path := PART_DIR + "dims.json"
		if FileAccess.file_exists(path):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary and d.get("pieces") is Dictionary:
				for p: String in d.pieces:
					if _dims.has(p):
						_dims[p].merge(d.pieces[p], true)
	return _dims


static func v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _build_pieces() -> void:
	var d := dims()
	for p: String in PIECES:
		var info: Dictionary = d[p]
		var pivot := Node3D.new()
		pivot.name = p
		var parent: Node3D = rig if info.parent == "" else pieces[info.parent]
		parent.add_child(pivot)
		pivot.position = v3(info.joint)
		pieces[p] = pivot
		var path: String = PART_DIR + p + ".glb"
		if ResourceLoader.exists(path):
			var inst: Node3D = (load(path) as PackedScene).instantiate()
			pivot.add_child(inst)
			_tint(inst)
		else:
			_placeholder(pivot, p, info)


# Team paint on the glb's "team" surfaces.
func _tint(inst: Node3D) -> void:
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m and m.resource_name.get_slice(".", 0) == "team":
				var key := "glb%d/%d" % [m.get_instance_id(), team]
				if not _mats.has(key):
					var t: BaseMaterial3D = m.duplicate()
					t.albedo_color = TankModel.TEAM_COLORS[clampi(team, 0, 1)]
					_mats[key] = t
				mi.set_surface_override_material(s, _mats[key])


# A coloured box per piece, and a few details so the team and the facing read from afar.
func _placeholder(pivot: Node3D, p: String, info: Dictionary) -> void:
	var mat: Material
	match p:
		"head":
			mat = Look.iron()
		"torso", "upper_arm_l", "upper_arm_r", "shield", "plume":
			mat = Look.team(team)
		"spear":
			mat = Look.wood()
		"shin_l", "shin_r":
			mat = _plain("boot", Color(0.25, 0.16, 0.1))
		_:
			mat = _plain("leather", Color(0.5, 0.33, 0.2))
	_box(pivot, v3(info.box), v3(info.center), mat)
	var size := v3(info.box)
	var c := v3(info.center)
	match p:
		"head":   # face slot at the front
			_box(pivot, Vector3(size.x * 0.7, size.y * 0.16, 0.02), c + Vector3(0, size.y * 0.05, -size.z * 0.5), _plain("slot", Color(0.06, 0.05, 0.05)))
		"spear":
			_box(pivot, Vector3(0.06, 0.16, 0.06), c + Vector3(0, size.y * 0.5 + 0.06, 0), Look.iron())


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


static func _plain(key: String, c: Color) -> Material:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.8
		_mats[key] = m
	return _mats[key]


# --- Moving -----------------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if not alive:
		return
	var want := move_dir.limit_length(1.0) * RUN_SPEED * speed_scale
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(want, ACCEL * dt)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	velocity.y -= GRAVITY * dt
	if cheering and is_on_floor() and _cheer_t > 0.55:
		velocity.y = 3.2   # hop for joy
		_cheer_t = 0.0
	_cheer_t += dt
	move_and_slide()

	var yaw_rate := 0.0
	if hv.length() > 0.3:
		var old := facing
		facing = Tank.turn_toward(facing, hv.normalized(), TURN_RATE * dt / maxf(facing.angle_to(hv.normalized()), 0.01))
		facing.y = 0.0
		facing = facing.normalized()
		yaw_rate = old.signed_angle_to(facing, Vector3.UP) / dt
	global_basis = Basis.looking_at(facing, Vector3.UP)
	_animate(dt, hv, yaw_rate)
	_check_run_over()


func _animate(dt: float, hv: Vector3, yaw_rate: float) -> void:
	var speed := hv.length()
	var run := clampf(speed / RUN_SPEED, 0.0, 1.4)
	_phase = fmod(_phase + TAU * STRIDE * minf(run, 1.2) * dt, TAU)
	var s := sin(_phase)
	# Positive x turns a hanging limb forward and tips an upright piece back.
	pieces.thigh_l.rotation.x = s * 0.8 * run
	pieces.thigh_r.rotation.x = -s * 0.8 * run
	pieces.shin_l.rotation.x = -maxf(0.0, cos(_phase)) * 1.1 * run
	pieces.shin_r.rotation.x = -maxf(0.0, -cos(_phase)) * 1.1 * run
	if cheering:
		var wave := sin(_cheer_t * 14.0) * 0.25
		pieces.upper_arm_l.rotation = Vector3(2.7 + wave, 0, -0.3)
		pieces.upper_arm_r.rotation = Vector3(2.7 - wave, 0, 0.3)
		pieces.forearm_l.rotation.x = 0.2
		pieces.forearm_r.rotation.x = 0.2
	else:
		pieces.upper_arm_l.rotation = Vector3(-s * 0.7 * run, 0, 0)
		pieces.upper_arm_r.rotation = Vector3(s * 0.35 * run, 0, 0)   # the spear arm swings less
		pieces.forearm_l.rotation.x = 0.3 + 0.6 * run
		pieces.forearm_r.rotation.x = 0.5 + 0.3 * run
	pieces.torso.rotation.x = -0.18 * run
	# The head leads: it looks into the turn and nods on a spring that overshoots when the speed changes.
	var fwd := hv.dot(facing)
	var accel := (fwd - _last_fwd_speed) / dt
	_last_fwd_speed = fwd
	_nod_v += (-90.0 * _nod - 9.0 * _nod_v - accel * 0.6) * dt
	_nod += _nod_v * dt
	_nod = clampf(_nod, -0.5, 0.5)
	pieces.head.rotation = Vector3(-0.1 * run + _nod + sin(_phase * 2.0) * 0.06 * run, clampf(yaw_rate * 0.12, -0.5, 0.5), 0)
	# Lean into turns (left turn, positive yaw rate: top to the left) and bob twice a stride.
	_lean = lerpf(_lean, clampf(yaw_rate * speed * 0.05, -0.4, 0.4), 1.0 - exp(-10.0 * dt))
	rig.rotation.z = _lean
	rig.position.y = absf(sin(_phase)) * 0.07 * run


# --- Dying ------------------------------------------------------------------------------------

## Tanks driving through knock troops down with a shove; the tank doesn't notice.
func _check_run_over() -> void:
	for t: Tank in get_tree().get_nodes_in_group("tanks"):
		var rel := global_position + Vector3.UP * 0.7 - t.global_position
		var along := rel.dot(t.forward)
		var side := rel - t.forward * along
		var up := side.dot(t.up)
		side -= t.up * up
		if absf(along) > 2.5 or side.length() > 1.5 + RADIUS or up < -1.5 or up > 1.8:
			continue
		var rv := t.velocity - velocity
		if rv.length() < RUN_OVER_SPEED:
			continue
		var push := t.velocity * RUN_OVER_SHOVE + t.up * RUN_OVER_POP + side.normalized() * 2.0
		die(push, global_position + Vector3.UP * 0.7)
		return


## Become a ragdoll (left in the world in this troop's place) moving with `impulse` (a velocity
## change) from a hit at `at`, and free the capsule. Returns the ragdoll.
func die(impulse: Vector3, at := Vector3.INF) -> TroopRagdoll:
	if not alive:
		return null
	alive = false
	var rag := TroopRagdoll.from_troop(self, impulse, at)
	died.emit(self, rag)
	queue_free()
	return rag
