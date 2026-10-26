extends TestCase
## The textured tank works in game: every part is built and textured, team surfaces take the team
## colour, the ballista moves its parts, and a tank fires a bolt that hits another tank.

const PARTS := ["hull", "track", "track_link", "wheel_big", "wheel_small", "seat", "knight", "pennant",
		"ballista", "mount", "gear", "bolt", "rope"]


func run() -> void:
	for p in PARTS:
		check(ResourceLoader.exists(TankModel.PART_DIR + p + ".glb"), "part built: " + p)

	for team in [0, 1]:
		var m := TankModel.new(team)
		add_child(m)
		var meshes := m.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() >= 15, "team %d: parts assembled (%d meshes)" % [team, meshes.size()])
		var textured := 0
		var tinted := 0
		for mi: MeshInstance3D in meshes:
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(s) as BaseMaterial3D
				if mat and mat.albedo_texture:
					textured += 1
				if mi.get_meta("mat_keys")[s] == "team":
					tinted += 1
					eq(mat.albedo_color, TankModel.TEAM_COLORS[team], "team %d: team surface tinted" % team)
		check(textured >= meshes.size(), "team %d: every surface has its baked texture (%d)" % [team, textured])
		check(tinted >= 4, "team %d: hull, seat, tunic and flag are team coloured (%d)" % [team, tinted])
		# The track links run round the belt as the tank drives.
		var belts := m.find_children("*", "MultiMeshInstance3D", true, false)
		eq(belts.size(), 2, "team %d: a belt of links per side" % team)
		var mm: MultiMesh = belts[0].multimesh
		check(mm.instance_count >= 20, "team %d: enough links to wrap the wheels (%d)" % [team, mm.instance_count])
		# (Headless runs a dummy renderer that keeps no MultiMesh transforms: test the layout itself.)
		var phase := m._belt_phase
		m.set_spin(5.0, 0.05)
		near(m._belt_phase - phase, 0.25, 0.001, "team %d: driving advances the belt" % team)
		var b: Dictionary = TankModel.dims().belt
		var a := TankModel._belt_at(b, 0.1).origin
		near(TankModel._belt_at(b, 0.35).origin.distance_to(a), 0.25, 0.01, "team %d: links move along the belt" % team)
		var round_front := TankModel._belt_at(b, float(b.z1 - b.z0) + PI * float(b.r) * 0.5)
		near(round_front.origin.distance_to(Vector3(0, b.cy, b.z0)), float(b.r), 0.001, "team %d: links wrap the front wheel" % team)
		near(round_front.basis.determinant(), 1.0, 0.001, "team %d: link basis is right-handed" % team)
		m.queue_free()

	# Fire across the floor at a tank 25 m ahead.
	Bolt.mode = Bolt.Mode.STRAIGHT
	var arena := Arena.new()
	add_child(arena)
	arena.build_shell()
	var shooter := Tank.new(0)
	shooter.field = arena.field
	add_child(shooter)
	shooter.place(arena.tank_on(Vector3.UP, 0, 20))
	var target := Tank.new(1)
	target.field = arena.field
	add_child(target)
	target.place(arena.tank_on(Vector3.UP, 0, -5))
	await frames(10)
	shooter.aim_point = target.global_position + Vector3.UP * 0.5
	shooter.aim_active = true
	await frames(30)
	var gear_before := shooter.model._gear.rotation.x
	eq(shooter.draw, 1.0, "a loaded bolt sits on a fully tensioned string")
	var drawn_z: float = shooter.model.nock.z
	shooter.in_fire = true   # a press looses it
	await frames(2)
	shooter.in_fire = false
	check(not shooter.loaded and not shooter.model.bolt.visible, "fired: the loaded bolt is gone")
	# The string snaps forward from where it was drawn, through rest, and settles there.
	var rest := float(TankModel.dims().nock_rest)
	var string_end := func() -> float:
		var s: Node3D = shooter.model._strings[0]
		return (s.transform.origin + s.transform.basis.y).z
	check(string_end.call() < drawn_z - 0.2, "the string has snapped forward from the draw (%.2f from %.2f)" % [string_end.call(), drawn_z])
	await frames(20)
	near(string_end.call(), rest, 0.01, "the string settles back on its rest line")
	for i in 60:
		await get_tree().physics_frame
		if target.hits_taken > 0:
			break
	eq(target.hits_taken, 1, "the bolt hit the other tank")
	# Reloading winches the string back: halfway round the crank, half tension, no bolt yet.
	shooter.in_crank = 0.5
	await frames(2)
	near(shooter.draw, 0.5, 0.001, "half a crank, half the tension")
	check(not shooter.loaded and not shooter.model.bolt.visible, "no bolt until the string is fully back")
	check(string_end.call() > rest + 0.3, "the string is pulled back (%.2f, rest %.2f)" % [string_end.call(), rest])
	check(shooter.model._gear.rotation.x != gear_before, "cranking turns the winch cog")
	shooter.in_crank = 0.5
	await frames(2)
	check(shooter.loaded and shooter.model.bolt.visible, "fully back: a bolt drops in")
	near(string_end.call(), float(TankModel.dims().nock_drawn), 0.01, "and the string holds at full draw")
	Bolt.mode = Bolt.Mode.SHOOTER_DOWN
