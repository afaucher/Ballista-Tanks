class_name Arena
extends Node3D
## The play space: the inside of a rounded cube (the quarter-pipe shell), plus either the
## hand-built starter layout (docs/design/arena-structure.md, section 7) or a generated road loop
## (RoadGen). Faces are addressed by their inward "up"; place() maps face-local coordinates
## (x, z along the face, y = height off it) to the world.

const HALF := 64.0
const FILLET := 12.0
const ROAD_WIDTH := 10.0
const ROAD_THICK := 1.2

const FACES: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]

var field := GravityField.new()
var player_spawn := Transform3D.IDENTITY
var dummy_spawns: Array[Transform3D] = []
var road: RoadGen.Result   ## roads mode only


## The basis of the face whose inward up is `up`: y = up, z along the face.
static func face_basis(face_up: Vector3) -> Basis:
	var ref := Vector3.BACK if absf(face_up.y) > 0.9 else Vector3.UP
	var z := (ref - face_up * ref.dot(face_up)).normalized()
	return Basis(face_up.cross(z), face_up, z)


## Face-local to world. zs = -1 mirrors through the centre (inversion symmetry for the red half).
func place(face_up: Vector3, local: Vector3, yaw_deg := 0.0, zs := 1.0) -> Transform3D:
	if zs < 0.0:
		local.z = -local.z
		yaw_deg += 180.0
	var b := face_basis(face_up)
	return Transform3D(b * Basis(Vector3.UP, deg_to_rad(yaw_deg)), -face_up * HALF + b * local)


## A tank's transform resting on a face: nose along face-local +x rotated by yaw.
func tank_on(face_up: Vector3, x: float, z: float, yaw_deg := 0.0) -> Transform3D:
	var t := place(face_up, Vector3(x, Tank.RIDE + 0.2, z), yaw_deg)
	return t


func build_shell() -> void:
	var mesh := Geo.rounded_box_interior(HALF, FILLET, 8.0, 8)
	Geo.solid(self, mesh, Transform3D.IDENTITY, Look.stone())


# --- Starter layout ---------------------------------------------------------------------------

func build_starter() -> void:
	build_shell()
	_keep(Vector3.UP, 0, 1.0)
	_keep(Vector3.DOWN, 1, -1.0)
	for up in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		_wall(up)
	_pillar(Vector3(34, 0, 34))
	_pillar(Vector3(-34, 0, -34))
	player_spawn = tank_on(Vector3.UP, 0, 44, 180)   # nose toward the +Z wall, through its arch
	dummy_spawns = [tank_on(Vector3.UP, 30, -30, 90), tank_on(Vector3.DOWN, 0, 40, 0),
			tank_on(Vector3.BACK, 6, 4, 0), tank_on(Vector3.LEFT, -6, 0, 0)]


# A team keep: a car-park block with ramps on both sides, a tower on top, a gatehouse on the approach.
func _keep(up: Vector3, team: int, zs: float) -> void:
	Geo.box(self, Vector3(26, 7, 26), place(up, Vector3(0, 3.5, 0), 0, zs), Look.stone())
	for side in [-1.0, 1.0]:
		var t := place(up, Vector3(0, 0, -35.0 * side), 0.0 if side > 0.0 else 180.0, zs)
		Geo.solid(self, Geo.wedge(10, 22, 7), t, Look.road(), Geo.wedge_shape(10, 22, 7))
	Geo.cylinder(self, 4, 8, place(up, Vector3(0, 11, 0), 0, zs), Look.stone())
	_roof(place(up, Vector3(0, 17, 0), 0, zs), 5.0, 4.0, Look.team(team))
	for x in [-11.0, 11.0]:
		Geo.box(self, Vector3(3, 7, 3), place(up, Vector3(x, 3.5, -44), 0, zs), Look.stone())
	Geo.box(self, Vector3(25, 2, 4), place(up, Vector3(0, 8, -44), 0, zs), Look.stone())
	for x in [-8.0, 8.0]:
		Geo.box(self, Vector3(3, 5, 0.3), place(up, Vector3(x, 3.5, -13.2), 0, zs), Look.team(team))


# A wall: an arched elevated road with ramps (tanks pass under the arch), a tower wrapped in a
# spiral road, and a launch pad aimed across the core.
func _wall(up: Vector3) -> void:
	Geo.box(self, Vector3(40, 1.2, 10), place(up, Vector3(0, 5.4, -24)), Look.road())
	for x in [-13.0, 13.0]:
		Geo.box(self, Vector3(14, 4.8, 10), place(up, Vector3(x, 2.4, -24)), Look.stone())
	for x in range(-18, 20, 4):
		for z in [-28.6, -19.4]:
			Geo.box(self, Vector3(2, 1.2, 0.8), place(up, Vector3(x, 6.6, z)), Look.stone())
	Geo.solid(self, Geo.wedge(10, 18, 6), place(up, Vector3(38, 0, -24), -90), Look.road(), Geo.wedge_shape(10, 18, 6))
	Geo.solid(self, Geo.wedge(10, 18, 6), place(up, Vector3(-38, 0, -24), 90), Look.road(), Geo.wedge_shape(10, 18, 6))
	var boost := Pad.new("boost", 6.0)
	add_child(boost)
	boost.global_transform = place(up, Vector3(0, 6.0, -24))

	var tower_at := Vector3(-22, 0, 20)
	Geo.cylinder(self, 7, 14, place(up, tower_at + Vector3(0, 7, 0)), Look.stone())
	var helix := Geo.helix_frames(11.0, 14.0, 1.25, 2.0)
	Geo.solid(self, Geo.road(helix, 7.0, 0.8, 1.0, 3.0, false), place(up, tower_at), Look.road())

	var launch := Pad.new("launch", 7.0)
	add_child(launch)
	launch.global_transform = place(up, Vector3(24, 0, 20))
	launch.launch_velocity = face_basis(up) * (Vector3(0, 52, 0) + Vector3(-1, 0, 1).normalized() * 18.0)


# A pillar from floor to ceiling, flaring into both faces with quarter-pipes so tanks can drive
# straight up it; it has its own gravity volume.
func _pillar(at: Vector3) -> void:
	var rp := 5.0
	var rf := 10.0
	var profile := []
	for i in 9:
		var th := deg_to_rad(90.0 * i / 8.0)
		profile.append([Vector2(rp + rf - rf * sin(th), -HALF + rf - rf * cos(th)), Vector2(sin(th), cos(th))])
	for i in range(8, -1, -1):
		var th := deg_to_rad(90.0 * i / 8.0)
		profile.append([Vector2(rp + rf - rf * sin(th), HALF - rf + rf * cos(th)), Vector2(sin(th), -cos(th))])
	Geo.solid(self, Geo.revolve(profile, 24), Transform3D(Basis.IDENTITY, Vector3(at.x, 0, at.z)), Look.stone())
	field.add_pillar(Vector3(at.x, -HALF + rf, at.z), Vector3(at.x, HALF - rf, at.z), rp + 6.0)


func _roof(xform: Transform3D, radius: float, height: float, mat: Material) -> void:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	add_child(mi)
	mi.global_transform = xform


# --- Castle skatepark -------------------------------------------------------------------------

const FIELD := Vector2(200, 280)   # x, z
const CASTLE_Z := 70.0


## Two castles facing each other across an open field, a giant loop arch in the middle and the
## high bridge between the gates, all under ordinary downward gravity
## (docs/design/castle-skatepark.md).
func build_castles() -> void:
	field.uniform = Vector3.DOWN
	Geo.box(self, Vector3(FIELD.x, 2, FIELD.y), Transform3D(Basis.IDENTITY, Vector3(0, -1, 0)), Look.road())
	CastleKit.castle(self, Vector3(0, 0, -CASTLE_Z), 1.0, 0)
	CastleKit.castle(self, Vector3(0, 0, CASTLE_Z), -1.0, 1)
	CastleKit.arch(self, Transform3D.IDENTITY, 26.0, 36.0, 6.0, 12.0)
	var gate_z := CASTLE_Z - 30.0 + CastleKit.WALL_W * 0.5 - 1.5   # overlaps the outer copings
	CastleKit.bridge(self, -gate_z, gate_z, [-25.0, -10.0, 10.0, 25.0], [[20.0, 1.0], [-20.0, -1.0]])
	# The edge of the world: a skatepark wall all round, its inner face to the field, with gaps
	# every 30 m to ride up onto its walk; the outer battlements are unbroken.
	var hx := FIELD.x * 0.5
	var hz := FIELD.y * 0.5
	for s in [-1.0, 1.0]:
		CastleKit.wall(self, Transform3D(Basis(Vector3.UP, 0.0 if s < 0.0 else PI), Vector3(0, 0, s * hz)), FIELD.x, [], _gaps(FIELD.x))
		CastleKit.wall(self, Transform3D(Basis(Vector3.UP, -s * PI * 0.5), Vector3(s * hx, 0, 0)), FIELD.y, [], _gaps(FIELD.y))
		for t in [-1.0, 1.0]:
			CastleKit.tower(self, Transform3D(Basis.IDENTITY, Vector3(s * hx, 0, t * hz)))
	player_spawn = _ground_spawn(Vector3(0, 0, -50), 0.0)   # in castle A's courtyard, facing the gate
	dummy_spawns = [_ground_spawn(Vector3(0, 0, 50), 180.0), _ground_spawn(Vector3(45, 0, 0), 90.0),
			_ground_spawn(Vector3(-45, 0, 10), -90.0)]


func _gaps(length: float) -> Array:
	var out := []
	var x := 0.0
	while x < length * 0.5 - 15.0:
		out.append([x - 4.0, x + 4.0])
		if x > 0.0:
			out.append([-x - 4.0, -x + 4.0])
		x += 30.0
	return out


## Standing on flat ground at p, nose toward +z turned by yaw.
func _ground_spawn(p: Vector3, yaw_deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis.looking_at(Vector3.BACK), p + Vector3.UP * (Tank.RIDE + 0.2))


# --- Generated roads --------------------------------------------------------------------------

func build_roads(s: RoadGen.Settings) -> void:
	build_shell()
	road = RoadGen.generate(s)
	if road == null:
		push_error("road generation failed for " + s.describe())
		player_spawn = tank_on(Vector3.UP, 0, 0)
		return
	var mesh := Geo.road(road.frames, ROAD_WIDTH, ROAD_THICK, 1.2, 3.0, true)
	Geo.solid(self, mesh, Transform3D.IDENTITY, Look.road())
	var straights := 0
	for c in road.corners:
		var u: Vector3 = c.up
		var t: Vector3 = c.tan
		var b := Basis(t.cross(u).normalized(), u, -t)   # y = up, -z = along the road
		match c.kind:
			"bend":
				var radius := road.spacing * 0.5 - ROAD_WIDTH * 0.5 - 1.5
				Geo.cylinder(self, radius, 11.0, Transform3D(b, c.center + u * (5.5 - ROAD_THICK)), Look.stone())
			"straight":
				straights += 1
				if c.up_out != c.up:
					continue   # a twist: leave it clear so the roll reads
				if straights % 3 == 0:
					_arch(Transform3D(b, c.pos))
				elif straights % 3 == 1:
					var pad := Pad.new("boost", 6.0)
					add_child(pad)
					pad.global_transform = Transform3D(b, c.pos)
	var f0: Dictionary = road.frames[0]
	player_spawn = _on_road(0)
	var n := road.frames.size()
	dummy_spawns = [_on_road(n / 3), _on_road(2 * n / 3)]


func _on_road(i: int) -> Transform3D:
	var f: Dictionary = road.frames[i]
	return Transform3D(Basis.looking_at(f.tan, f.up), f.pos + f.up * (Tank.RIDE + 0.3))


# A gatehouse arch over the road: two posts and a lintel.
func _arch(t: Transform3D) -> void:
	var w := ROAD_WIDTH * 0.5 + 0.8
	for x in [-w, w]:
		Geo.box(self, Vector3(1.4, 8, 2), t * Transform3D(Basis.IDENTITY, Vector3(x, 4, 0)), Look.stone())
	Geo.box(self, Vector3(2 * w + 1.4, 1.6, 2.4), t * Transform3D(Basis.IDENTITY, Vector3(0, 8.6, 0)), Look.stone())
