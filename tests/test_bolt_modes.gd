extends TestCase
## Both bolt-gravity modes: straight bolts never drop; shooter's-down bolts fall toward the
## shooter's down at the moment of firing (here a shooter on the +X wall, so down is +X).


func run() -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var start := Vector3(0, 10, 0)

	Bolt.mode = Bolt.Mode.STRAIGHT
	eq(Bolt.gravity_for(Vector3.LEFT), Vector3.ZERO, "straight has no gravity")
	var a := _fire(start, Vector3(0, 0, 10))
	await frames(30)
	var t := (a.global_position.z - start.z) / 10.0
	check(t > 0.3, "bolt flew (t=%.3f)" % t)
	near(a.global_position, start + Vector3(0, 0, 10) * t, 0.01, "straight bolt stays on its line")

	Bolt.mode = Bolt.Mode.SHOOTER_DOWN
	var g := Bolt.gravity_for(Vector3.LEFT)   # shooter's up is -X
	near(g, Vector3.RIGHT * Bolt.GRAVITY, 0.001, "falls toward the shooter's down")
	var b := _fire(start, Vector3(0, 0, 10))
	await frames(30)
	t = (b.global_position.z - start.z) / 10.0
	var n := roundi(t / dt)
	var drop := Bolt.GRAVITY * dt * dt * n * (n + 1) * 0.5   # semi-implicit Euler
	near(b.global_position.x - start.x, drop, 0.05, "drop along +X")
	near(b.global_position.y, start.y, 0.001, "no drop along world down")

	# The HUD's prediction follows the same flight.
	var space := b.get_world_3d().direct_space_state
	var none: Array[RID] = []
	var p := Bolt.predict(space, start, Vector3(0, 0, 10), Vector3.ZERO, none, 0.5, dt)
	near(p.end, start + Vector3(0, 0, 10) * 0.5, 0.2, "prediction of a straight shot")
	Bolt.mode = Bolt.Mode.SHOOTER_DOWN


func _fire(pos: Vector3, vel: Vector3) -> Bolt:
	var bolt := Bolt.new()
	bolt.setup(null, pos, vel, Bolt.gravity_for(Vector3.LEFT))
	add_child(bolt)
	return bolt
