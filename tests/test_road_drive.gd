extends TestCase
## A generated road is drivable: a tank following it gets round the loop without falling off.


func run() -> void:
	timeout_s = 150.0
	var s := RoadGen.Settings.new()
	s.seed = 1
	var arena := Arena.new()
	add_child(arena)
	arena.build_roads(s)
	var tank := Tank.new(0)
	tank.field = arena.field
	add_child(tank)
	tank.place(arena.player_spawn)
	tank.ai = "follow"
	tank.ai_path = arena.road.frames
	tank.ai_throttle = 0.7
	tank.ai_sync()
	await frames(2)

	var frames_n := arena.road.frames.size()
	var progress := 0
	var last_idx := 0
	var lost := 0.0
	var worst_lost := 0.0
	var air := 0.0
	var seconds := 40.0
	for i in int(60 * seconds):
		await get_tree().physics_frame
		var idx := _nearest(arena.road.frames, tank.global_position)
		var step := (idx - last_idx + frames_n) % frames_n
		if step < frames_n / 4:
			progress += step
			last_idx = idx
		var off: float = tank.global_position.distance_to(arena.road.frames[idx].pos)
		lost = lost + 1.0 / 60.0 if off > 8.0 else 0.0
		worst_lost = maxf(worst_lost, lost)
		if not tank.grounded:
			air += 1.0 / 60.0
		if i % 60 == 0 and OS.get_cmdline_user_args().has("--trace"):
			print("t=%2d idx=%3d speed=%5.1f grounded=%s up=%s steer=%.2f kind=%s" % [i / 60, idx,
					tank.velocity.length(), tank.grounded, tank.up.snapped(Vector3.ONE * 0.01), tank.in_steer,
					arena.road.corners[(idx * arena.road.nodes.size()) / frames_n].kind])
			for k in tank.get_slide_collision_count():
				var col := tank.get_slide_collision(k)
				var body: Node = col.get_collider()
				var shape_owner := (body as CollisionObject3D).shape_owner_get_owner(col.get_collider_shape_index())
				print("    hit %s shape %s normal %s up.n %.2f at %s" % [body.get_class(), shape_owner.shape.get_class(),
						col.get_normal().snapped(Vector3.ONE * 0.01), col.get_normal().dot(tank.up),
						(col.get_position() - tank.global_position).snapped(Vector3.ONE * 0.1)])
		if progress >= frames_n:
			break
	var laps := float(progress) / frames_n
	print("laps %.2f, air %.1f s, longest off-road %.1f s, metrics %s" % [laps, air, worst_lost, arena.road.metrics])
	check(laps >= 0.99, "drove a full lap (%.2f)" % laps)
	check(worst_lost < 1.5, "never left the road for long (%.1f s)" % worst_lost)


func _nearest(frames: Array, p: Vector3) -> int:
	var best := 0
	var bd := INF
	for i in frames.size():
		var d: float = p.distance_squared_to(frames[i].pos)
		if d < bd:
			bd = d
			best = i
	return best
