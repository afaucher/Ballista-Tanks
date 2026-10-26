class_name TankModel
extends Node3D
## The tank's look, assembled from the textured parts in res://assets/tank/ (built in Blender by
## tools/parts/; docs/design/tank-art-pipeline.md) to the numbers in assets/tank/dims.json.
## Visual only: no collision, no physics.
##
## Origin is the ground contact centre (bottom of the tracks), forward is -Z, up is +Y.
## The ballista yaws on `ballista_yaw` (local Y) and pitches on `ballista_pitch` (local X);
## the hull, tracks, seat, driver and pennant stay put. Surfaces whose material is "team" are
## tinted with the team colour. Every mesh carries a "mat_keys" meta (its material per surface)
## for tools/compare.py, and LM_<name> markers mark landmarks matched against the concept art.

const TEAM_COLORS := [Color("#2c588a"), Color("#d23a2a")]   # tints the pale baked "team" paint
const PART_DIR := "res://assets/tank/"
const CRANK_TURNS := 3.0
const BALLISTA_LANDMARKS := ["bolt_tip", "bow_tip_l", "bow_tip_r", "gear_center"]
const SNAP_TIME := 0.25   # the string's release: snap forward, overshoot, ring back to rest

# Per-material gloss, kept moderate: a soft clearcoat gives the broad highlight along rounded
# edges, and the baked texture carries the edge wear. No rim light: it lights a sub-pixel band
# at every silhouette, which breaks up into single white pixels along the edges.
const GLOSS := {
	"team": {"rough": 0.45, "spec": 0.35, "coat": 0.5, "coat_rough": 0.3},   # the broad highlight on round edges
	"wood": {"rough": 0.6, "spec": 0.35, "coat": 0.25, "coat_rough": 0.35},   # varnished
	"wood_dark": {"rough": 0.6, "spec": 0.35, "coat": 0.25, "coat_rough": 0.35},
	"iron": {"rough": 0.45, "metal": 0.35},
	"steel": {"rough": 0.38, "metal": 0.45},
	"gunmetal": {"rough": 0.45, "metal": 0.3},
	"track": {"rough": 0.85},
	"rope": {"rough": 0.9},
	"skin": {"rough": 0.6},
	"cheek": {"rough": 0.6},
	"cloth": {"rough": 0.85},
	"dark": {"rough": 0.5},
}

static var _dims := {}
static var _styled := {}   # "<material id>/<team>" -> glossed (and team-tinted) copy, shared by all tanks

var ballista_yaw: Node3D
var ballista_pitch: Node3D
var bolt_tip: Marker3D
var bolt: Node3D          ## the loaded bolt (shown by set_loaded); its origin is the nock
var nock := Vector3.ZERO  ## where the string meets the bolt, pitch space

var _team := 0
var _strings: Array[Node3D] = []
var _gear: Node3D
var _wheels: Array = []   # [Node3D, radius]
var _belts: Array[MultiMeshInstance3D] = []   # track links, one belt per side
var _belt_phase := 0.0    # metres the links have travelled round the belt
var _snap := 0.0          # seconds of the release snap left
var _snap_from := 0.0     # nock z the string was released from


## The part numbers from assets/tank/dims.json (written by tools/parts/build.py).
static func dims() -> Dictionary:
	if _dims.is_empty():
		_dims = JSON.parse_string(FileAccess.get_file_as_string(PART_DIR + "dims.json"))
	return _dims


func _init(team: int = 0) -> void:
	_team = clampi(team, 0, TEAM_COLORS.size() - 1)
	name = "TankModel"
	var d := dims()
	for part in ["hull", "seat", "knight", "pennant"]:
		_part(self, part)
	for side in [-1.0, 1.0]:
		var track := _part(self, "track")
		if track:
			track.position.x = side * float(d.track_x)
			if side < 0.0:
				track.rotation.y = PI   # its frame plate goes on the hull side...
				track.position.z = float(d.belt.z0) + float(d.belt.z1)   # ...and the turn flips z: shift back
		_build_belt(side * float(d.track_x))
	for w in d.wheels:
		var hub := Node3D.new()
		hub.position = Vector3(w[0], w[1], w[2])
		add_child(hub)
		var wheel := _part(hub, "wheel_big" if w[3] > 0.3 else "wheel_small")
		if wheel and w[0] < 0.0:
			wheel.rotation.y = PI   # face outward; mirroring by scale would render it inside out
		_wheels.append([hub, float(w[3])])

	ballista_yaw = Node3D.new()
	ballista_yaw.name = "BallistaYaw"
	ballista_yaw.position = _v(d.pivot)
	add_child(ballista_yaw)
	ballista_pitch = Node3D.new()
	ballista_pitch.name = "BallistaPitch"
	ballista_yaw.add_child(ballista_pitch)
	_part(ballista_yaw, "mount")   # fork the ballista pivots in
	_part(ballista_pitch, "ballista")
	_gear = Node3D.new()
	_gear.position = _v(d.gear)
	ballista_pitch.add_child(_gear)
	_part(_gear, "gear")
	bolt = Node3D.new()
	bolt.name = "Bolt"
	ballista_pitch.add_child(bolt)
	_part(bolt, "bolt")
	for i in 2:
		var s := Node3D.new()
		ballista_pitch.add_child(s)
		_part(s, "rope")
		_strings.append(s)
	bolt_tip = Marker3D.new()
	bolt_tip.name = "BoltTip"
	ballista_pitch.add_child(bolt_tip)

	# Landmarks on the ballista ride on it, so they follow its pose; the rest sit on the hull.
	for k in d.landmarks:
		var m := Marker3D.new()
		m.name = "LM_" + k
		if k in BALLISTA_LANDMARKS:
			m.position = _v(d.landmarks[k]) - ballista_yaw.position
			ballista_pitch.add_child(m)
		else:
			m.position = _v(d.landmarks[k])
			add_child(m)
	set_draw(0.0)
	set_loaded(true)


## Shows or hides the loaded bolt.
func set_loaded(on: bool) -> void:
	bolt.visible = on


## 0..1: pulls the string, and the bolt sitting on it, back toward the driver.
func set_draw(t: float) -> void:
	var d := dims()
	t = clampf(t, 0.0, 1.0)
	nock = Vector3(0, d.nock_y, lerpf(d.nock_rest, d.nock_drawn, t))
	if _snap <= 0.0:
		_lay_string(nock.z)
	bolt.position = nock
	bolt_tip.position = nock + Vector3(0, 0, -float(d.bolt_length))


## The bolt has been loosed: the string snaps forward from where it was drawn, pushing the bolt
## off the stock, flies past straight and rings back to rest.
func release() -> void:
	_snap = SNAP_TIME
	_snap_from = nock.z


func _process(dt: float) -> void:
	if _snap <= 0.0:
		return
	_snap = maxf(0.0, _snap - dt)
	var k := 1.0 - _snap / SNAP_TIME
	var rest := float(dims().nock_rest)
	# A damped twang about the rest line: starts at the drawn point, ends at rest.
	_lay_string(rest + (_snap_from - rest) * cos(k * PI * 3.5) * exp(-k * 5.0) * (1.0 - k))


func _lay_string(nock_z: float) -> void:
	var d := dims()
	var tip := _v(d.bow_tip)
	var at := Vector3(0, d.nock_y, nock_z)
	for i in 2:
		_span(_strings[i], Vector3(tip.x * (1.0 if i == 0 else -1.0), tip.y, tip.z), at)


## 0..1 crank progress: turns the winch cog.
func set_crank(t: float) -> void:
	_gear.rotation.x = -TAU * CRANK_TURNS * clampf(t, 0.0, 1.0)


## Rolls the wheels and runs the track links for a ground speed in m/s (positive = forward).
func set_spin(track_speed: float, delta: float) -> void:
	for w in _wheels:
		w[0].rotation.x -= track_speed * delta / w[1]
	if not is_zero_approx(track_speed):
		_belt_phase += track_speed * delta
		_lay_belts()


# One MultiMesh of track_link per side, laid round the belt path.
func _build_belt(x: float) -> void:
	var path := PART_DIR + "track_link.glb"
	if not ResourceLoader.exists(path):
		return
	var src: Node3D = (load(path) as PackedScene).instantiate()
	var link: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = link.mesh
	mm.instance_count = int(dims().belt.count)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position.x = x
	mmi.set_meta("mat_keys", ["track"])
	add_child(mmi)
	src.free()
	_belts.append(mmi)
	_lay_belts()


func _lay_belts() -> void:
	var b: Dictionary = dims().belt
	var n := int(b.count)
	for mmi in _belts:
		for i in n:
			mmi.multimesh.set_instance_transform(i, _belt_at(b, (i + 0.5) * float(b.pitch) + _belt_phase))
	

# The link transform at distance s round the belt: starting on top over the back wheel and
# running forward, so driving forward (positive phase) moves the top run forward, as a track does.
static func _belt_at(b: Dictionary, s: float) -> Transform3D:
	var z0 := float(b.z0)
	var z1 := float(b.z1)
	var cy := float(b.cy)
	var r := float(b.r)
	var top := z1 - z0
	var half := PI * r
	s = fposmod(s, 2.0 * top + 2.0 * half)
	var pos: Vector3
	var t: Vector3
	var n: Vector3
	if s < top:
		pos = Vector3(0, cy + r, z1 - s)
		t = Vector3.FORWARD
		n = Vector3.UP
	elif s < top + half:
		var a := PI * 0.5 + (s - top) / r
		n = Vector3(0, sin(a), cos(a))
		pos = Vector3(0, cy, z0) + n * r
		t = Vector3(0, cos(a), -sin(a))
	elif s < 2.0 * top + half:
		pos = Vector3(0, cy - r, z0 + (s - top - half))
		t = Vector3.BACK
		n = Vector3.DOWN
	else:
		var a := -PI * 0.5 + (s - 2.0 * top - half) / r
		n = Vector3(0, sin(a), cos(a))
		pos = Vector3(0, cy, z1) + n * r
		t = Vector3(0, cos(a), -sin(a))
	return Transform3D(Basis(Vector3.RIGHT, n, -t), pos)   # right-handed: a mirrored basis renders inside out


## Landmark name -> position in this model's local space, in its current pose.
func landmarks() -> Dictionary:
	var out := {}
	for m in find_children("LM_*", "Marker3D", true, false):
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n != self:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		out[String(m.name).substr(3)] = t.origin
	return out


# Instances res://assets/tank/<part>.glb under parent, tints its team surfaces and tags its
# material keys. Null (with a warning) if the part hasn't been built.
func _part(parent: Node3D, part: String) -> Node3D:
	var path := PART_DIR + part + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("tank part not built: " + path)
		return null
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	parent.add_child(inst)
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var keys: Array[String] = []
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var key := m.resource_name.get_slice(".", 0) if m else "unknown"
			keys.append(key)
			if m:
				mi.set_surface_override_material(s, _style(m, key))
		mi.set_meta("mat_keys", keys)
	return inst


# The part's material with its GLOSS (and the team colour on "team" paint).
func _style(m: Material, key: String) -> Material:
	var id := "%d/%d" % [m.get_instance_id(), _team]
	if not _styled.has(id):
		var t: BaseMaterial3D = m.duplicate()
		var g: Dictionary = GLOSS.get(key, {})
		t.roughness = g.get("rough", t.roughness)
		t.metallic = g.get("metal", 0.0)
		t.metallic_specular = g.get("spec", 0.5)
		if g.has("coat"):
			t.clearcoat_enabled = true
			t.clearcoat = g.coat
			t.clearcoat_roughness = g.coat_rough
		if key == "team":
			t.albedo_color = TEAM_COLORS[_team]
		_styled[id] = t
	return _styled[id]


# Points node's +Y (the unit rope part) from a to b.
func _span(node: Node3D, a: Vector3, b: Vector3) -> void:
	var dir := b - a
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length_squared() < 1e-4:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	node.transform = Transform3D(Basis(x, y * dir.length(), z), a)


static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
