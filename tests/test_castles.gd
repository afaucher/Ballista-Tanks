extends TestCase
## The castle skatepark under momentum sticking: a slow tank can't ride up a wall and a fast one
## can; rolling off a wall walk through a drop-in gap lands you in the moat and out on the field;
## carving across a moat runs you up its wall onto the walk; a tower spiral takes you to the top;
## the kickers air you onto a wall walk and onto the bridge; the arch road goes over the crown; a
## full-throttle run round the inside of the giant arch makes the loop; a drum's wall of death holds.

var arena: Arena


func run() -> void:
	arena = Arena.new()
	add_child(arena)
	arena.build_castles()
	await frames(2)
	var walk_y := CastleKit.WALL_H

	# The boundary wall at z = -140 (inner face toward +z, a gap in its battlements at x = 60).
	var climb := Transform3D(Basis.looking_at(Vector3.FORWARD), Vector3(60, Tank.RIDE + 0.2, -108))
	var slow := await _drive(climb, 0.3, 6.0, Callable(), 3.0)
	print("slow: top %.1f m, end y %.1f after letting go, grounded %s" % [slow.top, slow.end.y, slow.grounded])
	check(slow.top < walk_y - 2.0, "a slow tank can't ride up the wall (top %.1f m)" % slow.top)
	check(slow.grounded and slow.end.y < 2.0, "and rolls back down when it lets go (y %.1f)" % slow.end.y)

	var fast := await _drive(climb, 1.0, 4.0, func(t: Tank) -> bool:
		return t.grounded and t.up.y > 0.9 and t.global_position.y > walk_y)
	print("fast: top %.1f m, on the walk %s, longest air %.2f s" % [fast.top, fast.done, fast.air])
	check(fast.done, "a fast tank rides up the wall onto the walk (top %.1f m)" % fast.top)

	# Castle A's left wall walk (x = -30) at its drop-in gap, nose out toward the field: down the
	# face into the moat and up its outer bank onto the field.
	var walk := Transform3D(Basis.looking_at(Vector3.LEFT), Vector3(-30, walk_y + Tank.RIDE + 0.2, -64))
	var drop := await _drive(walk, 0.6, 6.0, func(t: Tank) -> bool:
		return t.grounded and t.up.y > 0.9 and absf(t.global_position.y) < 1.0 and t.global_position.x < -58.0)
	print("drop-in: end %s, lowest %.1f, speed %.1f, longest air %.2f s" % [drop.end, drop.low, drop.speed, drop.air])
	check(drop.done, "a drop-in comes down the wall, through the moat and out onto the field (end %s)" % drop.end)
	check(drop.low < -CastleKit.MOAT_D + 1.5, "through the bottom of the moat (lowest %.1f)" % drop.low)
	check(drop.speed > 10.0, "carrying speed out of the moat (%.1f m/s)" % drop.speed)

	# The other way: from the field, down into the moat and up its wall onto the walk.
	var carve := await _drive(_on_ground(Vector3(-84, 0, -64), Vector3.RIGHT), 1.0, 6.0, func(t: Tank) -> bool:
		return t.grounded and t.up.y > 0.9 and t.global_position.y > walk_y - 0.5)
	print("carve: on the walk %s, lowest %.1f, top %.1f, end %s" % [carve.done, carve.low, carve.top, carve.end])
	check(carve.low < -CastleKit.MOAT_D + 1.5, "carved through the moat (lowest %.1f)" % carve.low)
	check(carve.done, "and rode its wall up onto the walk (end %s)" % carve.end)

	# Castle A's front right tower: follow its spiral at a steady 60 % from the corner's ground.
	var spiral: Array = arena.spirals[3]
	var f0: Dictionary = spiral[0]
	var start := _on_ground(f0.pos - f0.tan * 8.0, f0.tan)
	var up_spiral := await _drive(start, 0.6, 40.0, func(t: Tank) -> bool:
		return t.grounded and t.up.y > 0.95 and t.global_position.y > CastleKit.TOWER_H + 0.5, 0.0, spiral)
	print("spiral: at the top %s, top %.1f, longest air %.2f s, end %s" % [up_spiral.done, up_spiral.top, up_spiral.air, up_spiral.end])
	check(up_spiral.done, "rode the tower spiral up to the tower top (top %.1f m)" % up_spiral.top)
	check(up_spiral.air < 0.3, "without leaving it (longest air %.2f s)" % up_spiral.air)

	# Castle A's bastion: from the right lane across the moat onto the right wall's walk.
	var bastion := await _drive(_on_ground(Vector3(84, 0, -64), Vector3.LEFT), 1.0, 5.0, func(t: Tank) -> bool:
		return t.grounded and t.up.y > 0.9 and t.global_position.y > walk_y - 0.5 and t.global_position.x < 40.0)
	print("bastion: landed on the walk %s, air %.2f s, end %s" % [bastion.done, bastion.air, bastion.end])
	check(bastion.done and bastion.air > 0.5, "the bastion kicker airs you over the moat onto the walk (end %s)" % bastion.end)

	# The bridge kicker beside the deck on castle A's half.
	var onto := await _drive(_on_ground(Vector3(55, 0, -10), Vector3.LEFT), 1.0, 5.0, func(t: Tank) -> bool:
		return t.grounded and t.up.y > 0.9 and t.global_position.y > walk_y - 0.5 and absf(t.global_position.x) < 6.0)
	print("bridge kicker: on the deck %s, air %.2f s, end %s" % [onto.done, onto.air, onto.end])
	check(onto.done and onto.air > 0.5, "the bridge kicker airs you onto the bridge (end %s)" % onto.end)

	# The road over the giant arch, from one end to the other.
	var over := await _drive(_on_ground(Vector3(-85, 0, 0), Vector3.RIGHT), 1.0, 10.0, func(t: Tank) -> bool:
		return t.grounded and t.global_position.x > 75.0)
	print("arch road: over %s, top %.1f, longest air %.2f s, end %s" % [over.done, over.top, over.air, over.end])
	check(over.done and over.top > 36.0, "drove the arch road up over the crown and down the far side (top %.1f m)" % over.top)
	check(over.air < 0.5, "staying on it (longest air %.2f s)" % over.air)
	check(absf(over.end.z) < 4.0, "and on the road (z %.1f)" % over.end.z)

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

	# The drum in the (100, -140) corner: in through its door, then round its wall of death,
	# steering to hold a level line as a rider would.
	var c := Vector3(Arena.FIELD.x * 0.5, 0, -Arena.FIELD.y * 0.5)
	var out := Vector3(-1, 0, 1).normalized()   # the door's way out, toward the field
	var door := c + out * (Arena.DRUM.x + Arena.DRUM.y) * 0.5
	var heading := (-out).rotated(Vector3.UP, deg_to_rad(30.0))   # in at a slant, to meet the wall glancing
	var lap := {"turn": 0.0, "last": NAN}
	var wall := await _drive(_on_ground(door - heading * 25.0, heading), 1.0, 8.0, func(t: Tank) -> bool:
		var p := t.global_position - c
		var ang := atan2(p.z, p.x)
		var side := t.up.cross(t.forward)
		if t.grounded and t.up.y < 0.3 and p.y > 6.0 and absf(side.y) > 0.3:   # on the wall, above the door
			if not is_nan(lap.last):
				lap.turn += absf(wrapf(ang - lap.last, -PI, PI))
			lap.last = ang
			t.in_steer = clampf(3.0 * t.forward.y / side.y, -1.0, 1.0)
		else:
			lap.last = NAN
			t.in_steer = 0.0
		return lap.turn > TAU)
	print("wall of death: once round %s, turned %.0f deg on the wall, top %.1f, end %s" % [wall.done, rad_to_deg(lap.turn), wall.top, wall.end])
	check(wall.done, "rode once round the drum's wall of death (%.0f deg)" % rad_to_deg(lap.turn))


## Standing on the ground at p (y ignored), nose along dir.
func _on_ground(p: Vector3, dir: Vector3) -> Transform3D:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	return Transform3D(Basis.looking_at(d), Vector3(p.x, Tank.RIDE + 0.2, p.z))


## Place a fresh tank at xform, hold the throttle for up to `secs` (or follow `path` at that
## throttle), stop early when done(tank); then coast with the throttle let go for `coast` seconds.
func _drive(xform: Transform3D, throttle: float, secs: float, done := Callable(), coast := 0.0, path := []) -> Dictionary:
	var tank := Tank.new(0)
	tank.field = arena.field
	add_child(tank)
	tank.place(xform)
	await frames(2)
	if path.is_empty():
		tank.in_throttle = throttle
	else:
		tank.ai = "follow"
		tank.ai_path = path
		tank.ai_throttle = throttle
		tank.ai_sync()
	var out := {"top": -INF, "low": INF, "air": 0.0, "done": false}
	for i in int(secs * 60.0):
		await get_tree().physics_frame
		out.top = maxf(out.top, tank.global_position.y)
		out.low = minf(out.low, tank.global_position.y)
		out.air = maxf(out.air, tank.air_time)
		if done.is_valid() and done.call(tank):
			out.done = true
			break
	tank.ai = ""
	tank.in_throttle = 0.0
	tank.in_steer = 0.0
	for i in int(coast * 60.0):
		await get_tree().physics_frame
	out.end = tank.global_position
	out.speed = tank.velocity.length()
	out.grounded = tank.grounded
	tank.queue_free()
	await frames(1)
	return out
