extends TestCase
## A bolt that hits a troop carries it: the troop dies, the hit piece rides the shaft, and when the
## bolt sticks in a wall the troop hangs there pinned, swinging. One bolt skewers two in a line.


func run() -> void:
	Geo.box(self, Vector3(60, 2, 60), Transform3D(Basis.IDENTITY, Vector3(0, -1, 0)), Look.road())
	Geo.box(self, Vector3(20, 10, 2), Transform3D(Basis.IDENTITY, Vector3(0, 5, -31)), Look.stone())   # face at z = -30
	var a := Troop.new(1)
	add_child(a)
	a.global_position = Vector3(0, 0.05, -6)
	var b := Troop.new(1)
	add_child(b)
	b.global_position = Vector3(0.1, 0.05, -10)
	var lone := Troop.new(0)
	add_child(lone)
	lone.global_position = Vector3(8, 0.05, -12)
	await frames(10)

	var kebab := _fire(Vector3(0, 0.4, 0), Vector3(0, 1.5, -70))
	var lone_bolt := _fire(Vector3(8, 0.6, 0), Vector3(0, 1.0, -70))
	await frames(7)
	check(not is_instance_valid(a) or not a.alive, "the first troop in the line is hit")
	check(kebab.carried.size() >= 1, "and carried (%d on the bolt)" % kebab.carried.size())
	if not kebab.carried.is_empty():
		var rag: TroopRagdoll = kebab.carried[0].rag
		var p: RigidBody3D = rag.bodies[kebab.carried[0].piece]
		check(p.global_position.distance_to(kebab.global_position) < 2.0, "the hit piece rides on the shaft")
	await frames(40)
	check(kebab.stuck and lone_bolt.stuck, "both bolts stick in the wall")
	eq(kebab.carried.size(), 2, "one bolt skewers both troops in the line")
	eq(lone_bolt.carried.size(), 1, "the other carries its one troop")
	near(kebab.global_position.z, -30.0, 0.3, "the kebab bolt's tip is in the wall face")

	# Hanging: the pinned piece stays put on the stuck bolt, the body swings below it.
	await frames(120)
	for bolt: Bolt in [kebab, lone_bolt]:
		for c: Dictionary in bolt.carried:
			var rag: TroopRagdoll = c.rag
			var pin: RigidBody3D = rag.bodies[c.piece]
			var tip_dist := pin.global_position.distance_to(bolt.global_position)
			var lowest := INF
			var spread := 0.0
			for body: RigidBody3D in rag.bodies.values():
				lowest = minf(lowest, body.global_position.y)
				spread = maxf(spread, body.global_position.distance_to(pin.global_position))
			print("pinned %s: %.2f m from the tip at y %.2f, lowest piece y %.2f, body within %.2f m" % [
					c.piece, tip_dist, pin.global_position.y, lowest, spread])
			check(rag.is_pinned() and pin.freeze, "%s stays pinned" % c.piece)
			check(tip_dist < 3.0, "%s is on the shaft (%.2f m from the tip)" % [c.piece, tip_dist])
			check(pin.global_position.z > -30.0 and pin.global_position.z < -27.0, "%s hangs against the wall (z %.2f)" % [c.piece, pin.global_position.z])
			check(spread < 1.3, "the body hangs together from the pin (%.2f m)" % spread)
	await get_tree().process_frame
	var errs := []
	for bolt: Bolt in [kebab, lone_bolt]:
		for c: Dictionary in bolt.carried:
			var e: Dictionary = c.rag.limit_errors()
			errs.append(e.values().max())
	print("pinned joints' worst overshoot: %s" % [errs])
	check(errs.max() < 20.0, "pinned bodies' joints stay near their limits")
	# The bolt stays as long as the troop it holds.
	check(is_instance_valid(kebab) and kebab.stuck, "a bolt holding troops stays")


func _fire(from: Vector3, vel: Vector3) -> Bolt:
	var bolt := Bolt.new()
	bolt.setup(null, from, vel, Vector3.ZERO)
	add_child(bolt)
	return bolt
