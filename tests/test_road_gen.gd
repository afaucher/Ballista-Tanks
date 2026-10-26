extends TestCase
## The road generator: closed, self-avoiding loops on the lattice, clear of the core, with a
## continuous framed road, and the same loop for the same seed.


func run() -> void:
	for seed in range(1, 7):
		var s := RoadGen.Settings.new()
		s.seed = seed
		var r := RoadGen.generate(s)
		check(r != null, "seed %d generated" % seed)
		if r == null:
			continue
		var m := r.nodes.size()
		var seen := {}
		for i in m:
			var n := r.nodes[i]
			check(not seen.has(n), "seed %d: node %s used once" % [seed, n])
			seen[n] = true
			var d := r.nodes[(i + 1) % m] - n
			eq(absi(d.x) + absi(d.y) + absi(d.z), 1, "seed %d: step %d is one lattice edge" % [seed, i])
			check(maxi(absi(n.x), maxi(absi(n.y), absi(n.z))) <= s.extent, "seed %d: inside the lattice" % seed)
			check(Vector3(n).length() * s.spacing >= s.core_radius, "seed %d: clear of the core" % seed)
			var u := r.ups[i]
			eq(u.x * d.x + u.y * d.y + u.z * d.z, 0, "seed %d: road up is across the road" % seed)
		var worst_gap := 0.0
		var worst_turn := 0.0
		var worst_skew := 0.0
		for i in r.frames.size():
			var a: Dictionary = r.frames[i]
			var b: Dictionary = r.frames[(i + 1) % r.frames.size()]
			worst_gap = maxf(worst_gap, a.pos.distance_to(b.pos))
			worst_turn = maxf(worst_turn, rad_to_deg(a.up.angle_to(b.up)))
			worst_skew = maxf(worst_skew, absf(a.up.dot(a.tan)))
		check(worst_gap < 3.0, "seed %d: frames are close (%.2f m)" % [seed, worst_gap])
		check(worst_turn < 30.0, "seed %d: up turns smoothly (%.1f deg per frame)" % [seed, worst_turn])
		check(worst_skew < 0.01, "seed %d: up is perpendicular to the road" % seed)
		print("seed %d: %s" % [seed, r.metrics])

	var s1 := RoadGen.Settings.new()
	s1.seed = 3
	var again := RoadGen.Settings.new()
	again.seed = 3
	eq(RoadGen.generate(s1).nodes, RoadGen.generate(again).nodes, "same seed, same loop")

	# Classification of corners.
	eq(RoadGen.corner_kind(Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 1, 0)), "quarter_pipe", "turn toward up")
	eq(RoadGen.corner_kind(Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)), "crest", "turn away from up")
	eq(RoadGen.corner_kind(Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)), "bend", "turn in the road's plane")
	eq(RoadGen.transport(Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0)), Vector3i(-1, 0, 0), "up after a quarter-pipe")
