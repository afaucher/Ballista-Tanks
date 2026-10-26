extends Node3D
## Tank lab: a blue and a red TankModel on a grey floor. `-- --shot <path>` saves a PNG and quits.


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#d9dadc")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#c8d4e8")
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40, 40)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#b9bbbf")
	fm.roughness = 0.95
	floor_mi.material_override = fm
	add_child(floor_mi)

	var blue := TankModel.new(0)
	blue.position = Vector3(-2.3, 0, 0)
	blue.rotation_degrees.y = 0.0
	blue.set_crank(0.3)
	add_child(blue)

	var red := TankModel.new(1)
	red.position = Vector3(2.8, 0, 1.2)
	red.rotation_degrees.y = 0.0
	red.ballista_yaw.rotation_degrees.y = 30.0
	red.ballista_pitch.rotation_degrees.x = 8.0
	red.set_draw(0.5)
	add_child(red)

	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.look_at_from_position(Vector3(-7.5, 6.0, -8.5), Vector3(0.2, 0.9, 0.3))

	var args := OS.get_cmdline_user_args()
	if args.has("--behind"):   # roughly the in-game chase view, over the blue driver's helmet
		cam.fov = 70.0
		cam.look_at_from_position(blue.position + Vector3(0, 4.1, 4.2), blue.position + Vector3(0, 1.0, -9.0))
	var i := args.find("--shot")
	if i >= 0 and i + 1 < args.size():
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		var err := get_viewport().get_texture().get_image().save_png(args[i + 1])
		print("shot ", args[i + 1], " -> ", error_string(err))
		get_tree().quit()
