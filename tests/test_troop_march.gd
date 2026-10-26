extends TestCase
## In the castle skatepark, with the troops' navigation mesh baked at runtime, a squad marches from
## its courtyard out of its gate, across the field and into the enemy gate, and cheers there. It
## keeps to the walkable: never up a wall face.


func run() -> void:
	timeout_s = 170.0
	var arena := Arena.new()
	add_child(arena)
	arena.build_castles()
	var t0 := Time.get_ticks_msec()
	var region := TroopAI.bake_nav(arena)
	print("navigation mesh baked in %d ms, %d polygons" % [Time.get_ticks_msec() - t0, region.navigation_mesh.get_polygon_count()])
	await frames(2)

	var goal := Vector3(0, 0, Arena.CASTLE_Z - 34.0)   # in the red gate
	var squad := TroopAI.spawn(self, 0, Vector3(12, 0, -Arena.CASTLE_Z + 10.0), goal, 4)
	await frames(2)
	var start := squad.center()
	var top := 0.0
	var steep := 0
	var secs := 0.0
	var path_pts := 0
	while secs < 80.0 and is_instance_valid(squad) and squad.state != TroopAI.State.CHEER:
		await get_tree().physics_frame
		secs += 1.0 / 60.0
		for t in squad.members:
			path_pts = maxi(path_pts, squad.route(t).size())
		if int(secs * 60.0) % 600 == 0:
			print("  %.0f s: centre %s" % [secs, squad.center().round()])
		for t in squad.members:
			top = maxf(top, t.global_position.y)
			if t.is_on_floor() and t.get_floor_normal().y < cos(deg_to_rad(42.0)):
				steep += 1
	var end := squad.center()
	print("march: %.0f s, path %d points, from %s to %s (goal %s), highest %.1f m, %d steep floor frames" % [
			secs, path_pts, start.round(), end.round(), goal, top, steep])
	check(path_pts > 2, "the path comes from the navigation mesh (%d points)" % path_pts)
	check(squad.state == TroopAI.State.CHEER, "the squad reaches the enemy gate and cheers")
	near(Vector3(end.x, 0, end.z), goal, TroopAI.ARRIVE + 1.0, "it ends at the gate")
	eq(squad.members.size(), 4, "all four made it")
	check(steep == 0, "never on a surface steeper than a ramp")
	check(top < CastleKit.WALL_H * 0.5, "never up a wall (highest %.1f m)" % top)
	await frames(60)
	check(squad.members.all(func(t: Troop) -> bool: return t.cheering), "they cheer")
