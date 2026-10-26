extends TestCase
## Drive straight ahead from the middle of the floor: the tank must climb the quarter-pipe onto
## the wall and carry on over onto the ceiling, glued to the surface the whole way.


func run() -> void:
	var arena := Arena.new()
	add_child(arena)
	arena.build_shell()
	var tank := Tank.new(0)
	tank.field = arena.field
	add_child(tank)
	tank.place(arena.tank_on(Vector3.UP, 0, 0))   # nose toward -Z
	await frames(2)
	tank.in_throttle = 1.0

	var on_wall := -1.0
	var on_ceiling := -1.0
	var longest_air := 0.0
	var top_speed := 0.0
	for i in 60 * 12:
		await get_tree().physics_frame
		var t := i / 60.0
		longest_air = maxf(longest_air, tank.air_time)
		top_speed = maxf(top_speed, tank.velocity.length())
		if on_wall < 0.0 and tank.up.z > 0.95:
			on_wall = t
		if on_wall > 0.0 and on_ceiling < 0.0 and tank.up.y < -0.95:
			on_ceiling = t
			break
	print("wall at %.2f s, ceiling at %.2f s, longest air %.2f s, top speed %.1f m/s" % [
			on_wall, on_ceiling, longest_air, top_speed])
	check(on_wall > 0.0, "reached the -Z wall")
	check(on_ceiling > 0.0, "carried on over onto the ceiling")
	check(longest_air < 0.25, "stayed on the surface (longest air %.2f s)" % longest_air)
	check(tank.velocity.length() > 20.0, "kept its speed round two quarter-pipes (%.1f m/s)" % tank.velocity.length())
	check(absf(tank.global_position.x) < 2.0, "drove straight (x drift %.2f m)" % tank.global_position.x)
