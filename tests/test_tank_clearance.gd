extends TestCase
## Nothing on the tank cuts through anything else: the track links (at many points round the
## belt) and the wheels must clear the hull and fenders, and the ballista must clear the seat box
## across its whole traverse. Uses the parts' real meshes as physics shapes.

const SAMPLES := 24   # belt phases tried, as the links run round


func run() -> void:
	var d := TankModel.dims()
	var space := get_viewport().world_3d.direct_space_state
	var hull := _static_trimesh("hull", Transform3D.IDENTITY)
	var seat := _static_trimesh("seat", Transform3D.IDENTITY)
	await frames(2)

	# Track links all the way round both belts.
	var link := _convex("track_link")
	var b: Dictionary = d.belt
	var worst := ""
	for side in [-1.0, 1.0]:
		for k in SAMPLES:
			var phase := float(b.pitch) * k / SAMPLES
			for i in int(b.count):
				var t := TankModel._belt_at(b, (i + 0.5) * float(b.pitch) + phase)
				t.origin.x += side * float(d.track_x)
				var hits := _overlaps(space, link, t, [hull])
				if hits and worst == "":
					worst = "side %+d link %d at %s" % [side, i, t.origin.snapped(Vector3.ONE * 0.01)]
	check(worst == "", "track links clear the hull and fenders (first hit: %s)" % worst)

	# Wheels.
	for w in d.wheels:
		var shape := _convex("wheel_big" if w[3] > 0.3 else "wheel_small")
		var t := Transform3D(Basis.IDENTITY if w[0] > 0 else Basis(Vector3.UP, PI), Vector3(w[0], w[1], w[2]))
		check(not _overlaps(space, shape, t, [hull]), "wheel at %s clears the hull" % Vector3(w[0], w[1], w[2]))

	# The string runs freely through the frame at every draw (so it can push the bolt), and clear
	# of the winch cog below it. Rays along each half, skipping the knot inside the tip cap and the
	# last stretch that slides on the stock's deck.
	var pivot := Vector3(d.pivot[0], d.pivot[1], d.pivot[2])
	var frame := _static_trimesh("ballista", Transform3D(Basis.IDENTITY, pivot))
	# Cranking winches the string back, so each draw has its own crank angle (Tank: draw = crank,
	# TankModel.set_crank: CRANK_TURNS whole turns per crank).
	var gears: Array = []
	for k in 11:
		gears.append(_static_trimesh("gear", Transform3D(Basis(Vector3.RIGHT, -TAU * TankModel.CRANK_TURNS * k / 10.0),
				pivot + Vector3(d.gear[0], d.gear[1], d.gear[2]))))
	await frames(2)
	var control := PhysicsRayQueryParameters3D.create(pivot + Vector3(0.6, 0.4, 0.0), pivot + Vector3(0.0, 0.4, 0.0))
	check(space.intersect_ray(control).get("rid") == frame, "control: a ray through the frame's upper arch hits it")
	var tip := Vector3(d.bow_tip[0], d.bow_tip[1], d.bow_tip[2])
	var string_hit := ""
	for k in 11:
		var nz := lerpf(d.nock_rest, d.nock_drawn, k / 10.0)
		var nock := pivot + Vector3(0, d.nock_y, nz)
		for sx in [-1.0, 1.0]:
			var a := pivot + Vector3(tip.x * sx, tip.y, tip.z)
			var dir := (nock - a).normalized()
			var q := PhysicsRayQueryParameters3D.create(a + dir * 0.25, nock - dir * 0.3)
			q.hit_back_faces = true
			var others := gears.duplicate()
			others.remove_at(k)
			q.exclude = others   # only the cog as it stands at this draw
			var hit := space.intersect_ray(q)
			if not hit.is_empty() and (hit.rid == frame or hit.rid in gears) and string_hit == "":
				string_hit = "draw %.1f, %s half, at %s" % [k / 10.0, "right" if sx > 0 else "left",
						(hit.position - pivot).snapped(Vector3.ONE * 0.01)]
	check(string_hit == "", "the string runs clear through the frame at every draw (first hit: %s)" % string_hit)

	# Across the whole aim range in pitch, nothing on the ballista or the cog (at any crank angle)
	# may enter the fork mount's base plate or arms (mount.py) or drop through the deck.
	var swing: Array[Vector3] = _points("ballista")
	for p in _points("gear"):
		for k in 8:
			swing.append(Vector3(d.gear[0], d.gear[1], d.gear[2]) + Basis(Vector3.RIGHT, TAU * k / 8.0) * p)
	var pitch_hit := ""
	for step in 13:
		var a := lerpf(Tank.PITCH_MIN, Tank.PITCH_MAX, step / 12.0)
		for p in swing:
			var q := Basis(Vector3.RIGHT, a) * p   # yaw space, relative to the pivot
			var in_plate := Vector2(q.x, q.z).length() < 0.5 and q.y < -0.36 + 0.005
			var in_arm := absf(absf(q.x) - 0.47) < 0.05 and q.y < 0.06 and q.y > -0.36 and absf(q.z) < 0.12
			var through_deck := q.y + pivot.y < float(d.hull_deck) and absf(q.x) < 1.34 and q.z + pivot.z > -1.96
			if (in_plate or in_arm or through_deck) and pitch_hit == "":
				pitch_hit = "pitch %.0f deg: point %s %s" % [rad_to_deg(a), q.snapped(Vector3.ONE * 0.01),
						"in the base plate" if in_plate else ("in a fork arm" if in_arm else "through the deck")]
	check(pitch_hit == "", "the ballista and cog clear the mount and deck across the aim range (%s)" % pitch_hit)

	# Ballista across its whole traverse: no point of it (bow tips swinging back, cradle corners)
	# may enter the seat box, the knight or the pennant.
	var blockers := [_static_convex("seat"), _static_convex("knight"), _static_convex("pennant")]
	await frames(2)
	var points := _points("ballista")
	var clear_to := 0
	for deg in range(0, 91, 2):
		var hit := false
		for sgn in [-1, 1]:
			var t := Transform3D(Basis(Vector3.UP, deg_to_rad(deg * sgn)), Vector3(d.pivot[0], d.pivot[1], d.pivot[2]))
			for p in points:
				var q := PhysicsPointQueryParameters3D.new()
				q.position = t * p
				for h in space.intersect_point(q, 4):
					if h.rid in blockers:
						hit = true
						print("first contact at yaw %d: ballista point %s (hull %s) inside %s" % [deg * sgn,
								p.snapped(Vector3.ONE * 0.01), q.position.snapped(Vector3.ONE * 0.01),
								["seat", "knight", "pennant"][blockers.find(h.rid)]])
						break
				if hit:
					break
			if hit:
				break
		if hit:
			break
		clear_to = deg
	print("ballista traverse clear to +-%d deg; Tank.ARC is %.0f deg" % [clear_to, rad_to_deg(Tank.ARC)])
	check(rad_to_deg(Tank.ARC) <= clear_to + 0.5, "Tank.ARC (%.0f deg) stays inside the clear traverse (%d deg)" % [rad_to_deg(Tank.ARC), clear_to])


func _mesh(part: String) -> Mesh:
	var inst: Node3D = (load(TankModel.PART_DIR + part + ".glb") as PackedScene).instantiate()
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var m := mi.mesh
	inst.free()
	return m


func _static_trimesh(part: String, xf: Transform3D) -> RID:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := _mesh(part).create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_transform = xf
	return body.get_rid()


func _static_convex(part: String) -> RID:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = _convex(part)
	body.add_child(cs)
	add_child(body)
	return body.get_rid()


# The part's vertices (deduplicated), in its own space.
func _points(part: String) -> Array[Vector3]:
	var seen := {}
	var out: Array[Vector3] = []
	for v in _mesh(part).get_faces():
		var key := v.snapped(Vector3.ONE * 0.01)
		if not seen.has(key):
			seen[key] = true
			out.append(v)
	return out


func _convex(part: String) -> Shape3D:
	return _mesh(part).create_convex_shape(true, false)


func _overlaps(space: PhysicsDirectSpaceState3D, shape: Shape3D, xf: Transform3D, against: Array) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = xf
	q.margin = 0.0
	for hit in space.intersect_shape(q, 8):
		if hit.rid in against:
			return true
	return false
