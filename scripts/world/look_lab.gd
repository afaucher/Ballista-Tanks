extends Node3D
## Look lab: the Look kit inside a full-size cube interior, with pieces on the floor, a wall and
## the ceiling. `-- --shot <png>` saves a screenshot and quits; `-- --cam <name>` picks a view.

const HALF := 64.0

var _cams := {
	"across": [Vector3(-46, -48, 44), Vector3(10, -6, -14)],
	"floor": [Vector3(-26, -56, 22), Vector3(-6, -60, -12)],
	"up": [Vector3(-30, -58, 10), Vector3(-6, 30, -20)],
}


func _ready() -> void:
	add_child(Look.make_environment())
	Look.make_sun(self, HALF)
	var shell := _mesh(Geo.rounded_box_interior(HALF, 12.0, 8.0, 8), Transform3D.IDENTITY, Look.stone())
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Floor (y = -64): a tower, a road deck on a ramp, crates, team blocks and the two pads.
	var floor_y := -HALF
	_cyl(5.0, 16.0, Vector3(12, floor_y + 8, -14), Basis.IDENTITY, Look.stone())
	_cyl(5.6, 1.0, Vector3(12, floor_y + 16.5, -14), Basis.IDENTITY, Look.gold())
	_box(Vector3(10, 1, 32), Vector3(-14, floor_y + 4.5, -12), Look.road())
	_mesh(Geo.wedge(10, 18, 4.0), Transform3D(Basis.IDENTITY, Vector3(-14, floor_y, 4)).rotated_local(Vector3.UP, PI), Look.road())
	_box(Vector3(4, 4, 4), Vector3(0, floor_y + 2, 12), Look.team(0))
	_box(Vector3(3, 3, 3), Vector3(5, floor_y + 1.5, 14), Look.wood())
	_box(Vector3(4.2, 0.4, 4.2), Vector3(0, floor_y + 4.2, 12), Look.gold())
	_box(Vector3(1, 6, 1), Vector3(-4, floor_y + 3, 18), Look.iron())
	_box(Vector3(6, 0.3, 6), Vector3(-30, floor_y + 0.15, -20), Look.pad("launch"))
	_box(Vector3(6, 0.3, 6), Vector3(-14, floor_y + 5.15, -20), Look.pad("boost"))
	# Banner on the tower.
	_box(Vector3(3, 6, 0.2), Vector3(12, floor_y + 11, -8.8), Look.team(1))

	# Back wall (z = -64, inward +Z): a block sticking out, a banner and a road deck along it.
	_box(Vector3(16, 10, 6), Vector3(10, -14, -HALF + 3), Look.stone())
	_box(Vector3(36, 10, 1), Vector3(-10, 8, -HALF + 0.5), Look.road())
	_box(Vector3(4, 8, 0.3), Vector3(-20, -24, -HALF + 0.2), Look.team(0))

	# Right wall (x = +64, inward -X): a road deck and a tower sticking out sideways.
	_box(Vector3(1, 10, 36), Vector3(HALF - 0.5, -6, 0), Look.road())
	_cyl(5.0, 16.0, Vector3(HALF - 8, 18, 18), Basis(Vector3.BACK, PI * 0.5), Look.stone())

	# Ceiling (y = +64): a hanging block and a red team block, upside down.
	_box(Vector3(14, 10, 14), Vector3(0, HALF - 5, -20), Look.stone())
	_box(Vector3(4, 4, 4), Vector3(12, HALF - 2, -8), Look.team(1))

	var args := OS.get_cmdline_user_args()
	var view := "across"
	var vi := args.find("--cam")
	if vi >= 0 and vi + 1 < args.size():
		view = args[vi + 1]
	var cam := Camera3D.new()
	cam.fov = 72.0
	cam.far = 400.0
	add_child(cam)
	cam.global_position = _cams[view][0]
	cam.look_at(_cams[view][1], Vector3.UP)
	cam.current = true

	var si := args.find("--shot")
	if si >= 0 and si + 1 < args.size():
		_shoot(args[si + 1])


func _shoot(path: String) -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("shot: ", path)
	get_tree().quit()


func _mesh(mesh: Mesh, xform: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	mi.transform = xform
	return mi


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := BoxMesh.new()
	m.size = size
	_mesh(m, Transform3D(Basis.IDENTITY, pos), mat)


func _cyl(r: float, h: float, pos: Vector3, b: Basis, mat: Material) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 32
	_mesh(m, Transform3D(b, pos), mat)
