class_name Geo
## Gray-box mesh builders. Each returns an ArrayMesh; solid() adds it to the world with collision.
##
## Godot treats CLOCKWISE triangles as front faces. _tri() takes the normal the face should have
## and orders the corners to match, so builders never think about winding.

const WORLD_LAYER := 1


# --- Placement -------------------------------------------------------------------------------

## A static body holding mesh + collision. shape == null means a trimesh of the mesh itself.
static func solid(parent: Node, mesh: Mesh, xform: Transform3D, mat: Material, shape: Shape3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	parent.add_child(body)
	body.global_transform = xform
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	if shape == null:
		var tri := mesh.create_trimesh_shape()
		tri.backface_collision = true
		shape = tri
	cs.shape = shape
	body.add_child(cs)
	return body


static func box(parent: Node, size: Vector3, xform: Transform3D, mat: Material) -> StaticBody3D:
	var m := BoxMesh.new()
	m.size = size
	var s := BoxShape3D.new()
	s.size = size
	return solid(parent, m, xform, mat, s)


static func cylinder(parent: Node, radius: float, height: float, xform: Transform3D, mat: Material) -> StaticBody3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 24
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	return solid(parent, m, xform, mat, s)


# --- Builders --------------------------------------------------------------------------------

## The inside of a rounded box: a cube of half-size `half` whose edges and corners are concave
## fillets of `radius` (the quarter-pipes). Normals point inward.
static func rounded_box_interior(half: float, radius: float, flat_step: float, fillet_steps: int) -> ArrayMesh:
	var inner := half - radius
	# Axis samples: tan-spaced across each fillet so the angle steps evenly, even in the flat.
	var u: Array[float] = []
	for i in fillet_steps:
		u.append(-(inner + radius * tan(deg_to_rad(45.0) * (1.0 - float(i) / fillet_steps))))
	var flat_n := maxi(1, ceili(2.0 * inner / flat_step))
	for i in flat_n + 1:
		u.append(-inner + 2.0 * inner * i / flat_n)
	for i in range(1, fillet_steps + 1):
		u.append(inner + radius * tan(deg_to_rad(45.0) * float(i) / fillet_steps))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var ia := (axis + 1) % 3
			var ib := (axis + 2) % 3
			var grid: Array = []   # [row][col] -> [pos, normal]
			for a in u:
				var row: Array = []
				for b in u:
					var p := Vector3.ZERO
					p[axis] = sgn * half
					p[ia] = a
					p[ib] = b
					var q := p.clamp(Vector3.ONE * -inner, Vector3.ONE * inner)
					var dir := (p - q).normalized()
					row.append([q + dir * radius, -dir])
				grid.append(row)
			for r in u.size() - 1:
				for c in u.size() - 1:
					var v00: Array = grid[r][c]
					var v10: Array = grid[r + 1][c]
					var v01: Array = grid[r][c + 1]
					var v11: Array = grid[r + 1][c + 1]
					_tri_smooth(st, v00, v10, v11)
					_tri_smooth(st, v00, v11, v01)
	return st.commit()


## A surface of revolution about +Y. profile: Array of [Vector2(radius, y), Vector2 normal (r, y)].
static func revolve(profile: Array, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		for i in profile.size() - 1:
			var ring := []
			for pair in [[i, a0], [i + 1, a0], [i, a1], [i + 1, a1]]:
				var pr: Vector2 = profile[pair[0]][0]
				var nr: Vector2 = profile[pair[0]][1]
				var ang: float = pair[1]
				ring.append([Vector3(cos(ang) * pr.x, pr.y, sin(ang) * pr.x),
						Vector3(cos(ang) * nr.x, nr.y, sin(ang) * nr.x).normalized()])
			_tri_smooth(st, ring[0], ring[1], ring[3])
			_tri_smooth(st, ring[0], ring[3], ring[2])
	return st.commit()


## A ramp: rises from 0 at z=0 to `height` at z=length, `width` wide, centred on x.
static func wedge(width: float, length: float, height: float) -> ArrayMesh:
	var w := width * 0.5
	var p := [Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(-w, 0, length), Vector3(w, 0, length),
			Vector3(-w, height, length), Vector3(w, height, length)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slope_n := Vector3(0, length, -height).normalized()
	_quad(st, p[0], p[1], p[5], p[4], slope_n)
	_quad(st, p[2], p[3], p[5], p[4], Vector3.BACK)
	_quad(st, p[0], p[1], p[3], p[2], Vector3.DOWN)
	_tri(st, p[0], p[2], p[4], Vector3.LEFT)
	_tri(st, p[1], p[3], p[5], Vector3.RIGHT)
	return st.commit()


static func wedge_shape(width: float, length: float, height: float) -> ConvexPolygonShape3D:
	var w := width * 0.5
	var s := ConvexPolygonShape3D.new()
	s.points = PackedVector3Array([Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(-w, 0, length),
			Vector3(w, 0, length), Vector3(-w, height, length), Vector3(w, height, length)])
	return s


## A road swept along a framed curve. frames: Array of {pos, up, tan}, where pos is the deck
## surface centre. A solid deck `thickness` deep (drivable underneath too) with crenellated
## rails: a merlon over every other `merlon` metres of each edge.
static func road(frames: Array, width: float, thickness: float, rail_h: float, merlon: float, closed: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := frames.size()
	var count := n if closed else n - 1
	var dist := 0.0
	var hw := width * 0.5
	for i in count:
		var f0: Dictionary = frames[i]
		var f1: Dictionary = frames[(i + 1) % n]
		var s0: Vector3 = f0.tan.cross(f0.up).normalized()   # right-hand side
		var s1: Vector3 = f1.tan.cross(f1.up).normalized()
		var u0: Vector3 = f0.up
		var u1: Vector3 = f1.up
		var tl0: Vector3 = f0.pos - s0 * hw
		var tr0: Vector3 = f0.pos + s0 * hw
		var tl1: Vector3 = f1.pos - s1 * hw
		var tr1: Vector3 = f1.pos + s1 * hw
		var bl0 := tl0 - u0 * thickness
		var br0 := tr0 - u0 * thickness
		var bl1 := tl1 - u1 * thickness
		var br1 := tr1 - u1 * thickness
		_quad_n(st, [tl0, tr0, tr1, tl1], [u0, u0, u1, u1])                    # deck top
		_quad_n(st, [bl0, br0, br1, bl1], [-u0, -u0, -u1, -u1])                # underside
		var rail := int(floor(dist / merlon)) % 2 == 0
		var rh := rail_h if rail else 0.0
		# Edges: outer faces, with the merlon height when this stretch has one.
		_quad_n(st, [bl0, bl1, tl1 + u1 * rh, tl0 + u0 * rh], [-s0, -s1, -s1, -s0])
		_quad_n(st, [br0, br1, tr1 + u1 * rh, tr0 + u0 * rh], [s0, s1, s1, s0])
		if rail:
			var ri := 0.8   # merlon thickness, inward from the edge
			_quad_n(st, [tl0 + s0 * ri, tl1 + s1 * ri, tl1 + s1 * ri + u1 * rh, tl0 + s0 * ri + u0 * rh], [s0, s1, s1, s0])
			_quad_n(st, [tl0 + u0 * rh, tl1 + u1 * rh, tl1 + s1 * ri + u1 * rh, tl0 + s0 * ri + u0 * rh], [u0, u1, u1, u0])
			_quad_n(st, [tr0 - s0 * ri, tr1 - s1 * ri, tr1 - s1 * ri + u1 * rh, tr0 - s0 * ri + u0 * rh], [-s0, -s1, -s1, -s0])
			_quad_n(st, [tr0 + u0 * rh, tr1 + u1 * rh, tr1 - s1 * ri + u1 * rh, tr0 - s0 * ri + u0 * rh], [u0, u1, u1, u0])
		dist += f0.pos.distance_to(f1.pos)
	return st.commit()


## Frames for a helix around +Y: radius r (centre line), rising `rise` over `turns`.
static func helix_frames(r: float, rise: float, turns: float, step: float) -> Array:
	var length := TAU * r * turns
	var n := maxi(2, ceili(length / step))
	var out := []
	for i in n + 1:
		var t := float(i) / n
		var ang := TAU * turns * t
		var pos := Vector3(cos(ang) * r, rise * t, sin(ang) * r)
		var tan := Vector3(-sin(ang) * TAU * r * turns, rise, cos(ang) * TAU * r * turns).normalized()
		var radial := Vector3(cos(ang), 0, sin(ang))
		var up := radial.cross(tan).normalized()
		if up.y < 0.0:
			up = -up
		out.append({"pos": pos, "up": up, "tan": tan})
	return out


## A closed side profile [(z, y)] (either winding) extruded along x from x0 to x1, with end caps.
## Normals are smooth across bends gentler than smooth_deg (quarter-pipes, copings) and hard at
## sharper corners.
static func extrude(profile: PackedVector2Array, x0: float, x1: float, smooth_deg := 30.0) -> ArrayMesh:
	var n := profile.size()
	var area := 0.0
	for i in n:
		var a := profile[i]
		var b := profile[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var ccw := area > 0.0
	var edge_n: Array[Vector3] = []
	for i in n:
		var d := (profile[(i + 1) % n] - profile[i]).normalized()
		var o := Vector2(d.y, -d.x) if ccw else Vector2(-d.y, d.x)   # outward, in (z, y)
		edge_n.append(Vector3(0, o.y, o.x))
	var cos_smooth := cos(deg_to_rad(smooth_deg))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var j := (i + 1) % n
		var a := profile[i]
		var b := profile[j]
		var prev: Vector3 = edge_n[(i - 1 + n) % n]
		var next: Vector3 = edge_n[j]
		var na: Vector3 = (edge_n[i] + prev).normalized() if edge_n[i].dot(prev) > cos_smooth else edge_n[i]
		var nb: Vector3 = (edge_n[i] + next).normalized() if edge_n[i].dot(next) > cos_smooth else edge_n[i]
		_quad_n(st, [Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x0, b.y, b.x)],
				[na, na, nb, nb])
	var tris := Geometry2D.triangulate_polygon(profile)
	for k in range(0, tris.size(), 3):
		var p := [profile[tris[k]], profile[tris[k + 1]], profile[tris[k + 2]]]
		_tri(st, Vector3(x0, p[0].y, p[0].x), Vector3(x0, p[1].y, p[1].x), Vector3(x0, p[2].y, p[2].x), Vector3.LEFT)
		_tri(st, Vector3(x1, p[0].y, p[0].x), Vector3(x1, p[1].y, p[1].x), Vector3(x1, p[2].y, p[2].x), Vector3.RIGHT)
	return st.commit()


## Points on an arc in a 2D profile plane, angles in degrees, both ends included.
static func arc(c: Vector2, r: float, a0: float, a1: float, n := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := deg_to_rad(lerpf(a0, a1, float(i) / n))
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


# --- Triangles -------------------------------------------------------------------------------

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	_tri_smooth(st, [a, n], [b, n], [c, n])


# Each vertex is [pos, normal]; the winding follows the average normal.
static func _tri_smooth(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	var n: Vector3 = a[1] + b[1] + c[1]
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	var face := (pc - pa).cross(pb - pa)   # front-face normal of a clockwise a, b, c
	var order := [a, b, c] if face.dot(n) >= 0.0 else [a, c, b]
	for v in order:
		st.set_normal(v[1])
		st.set_uv(Vector2(v[0].x + v[0].z, v[0].y + v[0].z) * 0.25)
		st.add_vertex(v[0])


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)


static func _quad_n(st: SurfaceTool, p: Array, n: Array) -> void:
	_tri_smooth(st, [p[0], n[0]], [p[1], n[1]], [p[2], n[2]])
	_tri_smooth(st, [p[0], n[0]], [p[2], n[2]], [p[3], n[3]])
