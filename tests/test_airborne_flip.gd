extends TestCase
## Launch straight up from the floor's centre: once past the cube's centre the ceiling's pyramid
## takes over, the tank flips, and it lands on the ceiling the right way up.


func run() -> void:
	var arena := Arena.new()
	add_child(arena)
	arena.build_shell()
	var tank := Tank.new(0)
	tank.field = arena.field
	add_child(tank)
	tank.place(arena.tank_on(Vector3.UP, 0, 0))
	await frames(2)
	tank.launch(Vector3.UP * 75.0)

	var landed := -1.0
	var was_airborne := false
	for i in 60 * 8:
		await get_tree().physics_frame
		if not tank.grounded:
			was_airborne = true
		elif was_airborne and tank.global_position.y > 0.0:
			landed = i / 60.0
			break
	await frames(30)
	print("landed on the ceiling at %.2f s, up %s" % [landed, tank.up])
	check(landed > 0.0, "landed on the ceiling")
	check(tank.up.y < -0.95, "upright relative to the ceiling (up %s)" % tank.up)
	check(tank.grounded, "still on the ceiling half a second later")
