extends TestCase
## The castle skatepark under momentum sticking: a slow tank can't ride up a wall and a fast one
## can; rolling off the wall walk through a drop-in gap lands you on the field; a full-throttle run
## round the inside of the giant arch makes the loop.

var arena: Arena


func run() -> void:
	arena = Arena.new()
	add_child(arena)
	arena.build_castles()
	await frames(2)

	# The boundary wall at z = -140 (inner face toward +z, a gap in its battlements at x = 60).
	var climb := Transform3D(Basis.looking_at(Vector3.FORWARD), Vector3(60, Tank.RIDE + 0.2, -108))
	var slow := await _drive(climb, 0.3, 6.0, Callable(), 3.0)
	print("slow: top %.1f m, end y %.1f after letting go, grounded %s" % [slow.top, slow.end.y, slow.grounded])
	check(slow.top < CastleKit.WALL_H - 2.0, "a slow tank can't ride up the wall (top %.1f m)" % slow.top)
	check(slow.grounded and slow.end.y < 2.0, "and rolls back down when it lets go (y %.1f)" % slow.end.y)

	var fast := await _drive(climb, 1.0, 4.0, func(t: Tank) -> bool:
		return t.grounded and t.up.y > 0.9 and t.global_position.y > CastleKit.WALL_H)
	print("fast: top %.1f m, on the walk %s, longest air %.2f s" % [fast.top, fast.done, fast.air])
	check(fast.done, "a fast tank rides up the wall onto the walk (top %.1f m)" % fast.top)

	# Castle A's front wall walk at a drop-in gap, nose out toward the field.
	var walk := Transform3D(Basis.looking_at(Vector3.BACK), Vector3(15.5, CastleKit.WALL_H + Tank.RIDE + 0.2, -40))
	var drop := await _drive(walk, 0.6, 5.0, func(t: Tank) -> bool:
		return t.grounded and t.up.y > 0.9 and t.global_position.y < 2.0 and t.global_position.z > -24.0)
	print("drop-in: end %s, speed %.1f, longest air %.2f s" % [drop.end, drop.speed, drop.air])
	check(drop.done, "a drop-in comes down the wall and out across the field (end %s)" % drop.end)
	check(drop.speed > 12.0, "carrying speed out of the quarter-pipe (%.1f m/s)" % drop.speed)

	# Inside the giant arch, nose along +x toward its right leg.
	var loop_start := Transform3D(Basis.looking_at(Vector3.RIGHT), Vector3(-10, Tank.RIDE + 0.2, 0))
	var state := {"inverted": false}
	var loop := await _drive(loop_start, 1.0, 6.0, func(t: Tank) -> bool:
		if t.up.y < -0.9:
			state.inverted = true
		return state.inverted and t.grounded and t.up.y > 0.9 and t.global_position.y < 2.0)
	print("loop: inverted %s, back on the floor %s, top %.1f m, longest air %.2f s, end %s" % [
			state.inverted, loop.done, loop.top, loop.air, loop.end])
	check(state.inverted, "rode upside down across the crown of the loop")
	check(loop.done, "and came round onto the floor again")
	check(loop.air < 0.3, "glued all the way round (longest air %.2f s)" % loop.air)
	check(absf(loop.end.z) < 5.0, "stayed on the arch (z %.1f)" % loop.end.z)


## Place a fresh tank at xform, hold the throttle for up to `secs`, stop early when done(tank);
## then coast with the throttle let go for `coast` seconds.
func _drive(xform: Transform3D, throttle: float, secs: float, done := Callable(), coast := 0.0) -> Dictionary:
	var tank := Tank.new(0)
	tank.field = arena.field
	add_child(tank)
	tank.place(xform)
	await frames(2)
	tank.in_throttle = throttle
	var out := {"top": 0.0, "air": 0.0, "done": false}
	for i in int(secs * 60.0):
		await get_tree().physics_frame
		out.top = maxf(out.top, tank.global_position.y)
		out.air = maxf(out.air, tank.air_time)
		if done.is_valid() and done.call(tank):
			out.done = true
			break
	tank.in_throttle = 0.0
	for i in int(coast * 60.0):
		await get_tree().physics_frame
	out.end = tank.global_position
	out.speed = tank.velocity.length()
	out.grounded = tank.grounded
	tank.queue_free()
	await frames(1)
	return out
