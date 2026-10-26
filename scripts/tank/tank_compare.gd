extends Node
## Render rig for tools/compare.py (docs/design/tank-art-pipeline.md). Windowed, not headless.
##
##   -- --landmarks out.json                   model-space landmark positions, then quit
##   -- --camera cam.json --out DIR [--team N] render from cam.json (see compare.py):
##        DIR/beauty.png     studio-lit render on the reference's background colour
##        DIR/ids.png        flat colour per material key, transparent background
##        DIR/ids.json       material key -> id colour
##        DIR/projected.json landmark name -> pixel position in the render
##   -- --pose ballista_yaw_deg,pitch_deg,draw  pose the ballista before rendering (default rest)

const ID_COLORS := {
	"team": Color8(40, 90, 230), "team_dark": Color8(20, 40, 140), "wood": Color8(200, 110, 40),
	"wood_dark": Color8(120, 60, 20), "track": Color8(90, 60, 40), "iron": Color8(150, 150, 160),
	"steel": Color8(220, 220, 235), "rope": Color8(230, 200, 120), "skin": Color8(240, 170, 140),
	"visor": Color8(20, 20, 20), "gold": Color8(240, 190, 0), "iron_dark": Color8(90, 90, 100),
	"gunmetal": Color8(70, 50, 110),
}


func _ready() -> void:
	var args := _args()
	var model := TankModel.new(int(args.get("team", "0")))
	if args.has("pose"):
		var p := String(args.pose).split(",")
		model.ballista_yaw.rotation_degrees.y = float(p[0])
		model.ballista_pitch.rotation_degrees.x = float(p[1])
		model.set_draw(float(p[2]))

	if args.has("landmarks"):
		var out := {}
		var lm := model.landmarks()
		for k in lm:
			out[k] = [lm[k].x, lm[k].y, lm[k].z]
		_write_json(args.landmarks, out)
		print("landmarks ", args.landmarks)
		get_tree().quit()
		return

	var cam_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args.camera))
	var out_dir: String = args.out
	DirAccess.make_dir_recursive_absolute(out_dir)
	var size := Vector2i(int(cam_data.width), int(cam_data.height))
	var bg: Array = cam_data.get("background", [0.88, 0.88, 0.89])

	var vp := SubViewport.new()
	vp.size = size
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA   # as the game (project.godot)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(bg[0], bg[1], bg[2])
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.88, 0.95)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.9
	e.ssao_enabled = true
	e.sky = Look.studio_sky()
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.environment = e
	vp.add_child(env)
	vp.add_child(model)

	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = float(cam_data.fov_y)
	cam.near = 0.05
	var o: Array = cam_data.origin
	var b: Array = cam_data.basis
	cam.transform = Transform3D(Basis(_v(b[0]), _v(b[1]), _v(b[2])), _v(o))
	vp.add_child(cam)
	cam.current = true

	# Key light from the camera's upper left, like a studio turntable shot.
	var key := DirectionalLight3D.new()
	key.light_energy = 1.1
	key.shadow_enabled = true
	vp.add_child(key)
	var from := cam.global_position + cam.global_basis.x * -6.0 + cam.global_basis.y * 9.0
	key.look_at_from_position(from, Vector3(0, 1, 0))
	# Soft fill from just above the camera, so faces turned away from the key still model.
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.3
	vp.add_child(fill)
	fill.look_at_from_position(cam.global_position + cam.global_basis.y * 2.0, Vector3(0, 1, 0))

	await _frames(4)
	vp.get_texture().get_image().save_png(out_dir.path_join("beauty.png"))

	var proj := {}
	var lm := model.landmarks()
	for k in lm:
		var p := cam.unproject_position(model.global_transform * lm[k])
		proj[k] = [p.x, p.y]
	_write_json(out_dir.path_join("projected.json"), proj)

	# Flat id pass: one unshaded colour per material key, transparent background, no AA.
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED   # flat ids must stay exact
	key.visible = false
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	e.ssao_enabled = false
	var legend := {}
	for mmi: MultiMeshInstance3D in model.find_children("*", "MultiMeshInstance3D", true, false):
		var link_key: String = mmi.get_meta("mat_keys", ["unknown"])[0]
		var mc: Color = ID_COLORS.get(link_key, Color8(255, 0, 255))
		legend[link_key] = [mc.r8, mc.g8, mc.b8]
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.albedo_color = mc
		mmi.material_override = mm
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var keys: Array = mi.get_meta("mat_keys", [])
		for s in mi.mesh.get_surface_count():
			var k: String = keys[s] if s < keys.size() else "unknown"
			var c: Color = ID_COLORS.get(k, Color8(255, 0, 255))
			legend[k] = [c.r8, c.g8, c.b8]
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = c
			mi.set_surface_override_material(s, m)
	_write_json(out_dir.path_join("ids.json"), legend)
	await _frames(4)
	vp.get_texture().get_image().save_png(out_dir.path_join("ids.png"))
	print("rendered ", out_dir)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))


func _args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i].begins_with("--") and i + 1 < a.size() and not a[i + 1].begins_with("--"):
			out[a[i].substr(2)] = a[i + 1]
	return out
