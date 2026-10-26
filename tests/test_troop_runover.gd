extends TestCase
## A tank driving through troops ragdolls them with a shove and barely notices; troops off its
## line are left alone. A squad in the way of a charging tank scatters.


func run() -> void:
	Geo.box(self, Vector3(200, 2, 200), Transform3D(Basis.IDENTITY, Vector3(0, -1, 0)), Look.road())
	var field := GravityField.new()
	field.uniform = Vector3.DOWN
	var in_path: Array[Troop] = []
	for i in 4:
		var t := Troop.new(1)
		add_child(t)
		t.global_position = Vector3(-0.9 + i * 0.6, 0.05, -25)
		in_path.append(t)
	var aside := Troop.new(1)
	add_child(aside)
	aside.global_position = Vector3(6, 0.05, -25)
	var rags: Array[TroopRagdoll] = []
	for t in in_path:
		t.died.connect(func(_t: Troop, rag: TroopRagdoll) -> void: rags.append(rag))

	var tank := Tank.new(0)
	tank.field = field
	add_child(tank)
	tank.place(Transform3D(Basis.IDENTITY, Vector3(0, Tank.RIDE + 0.2, 0)))
	await frames(2)
	tank.in_throttle = 1.0
	var speed_before := 0.0
	for i in 150:
		await get_tree().physics_frame
		if tank.global_position.z > -22.0:
			speed_before = tank.velocity.length()
	var speed_after := tank.velocity.length()
	print("run over %d of %d, tank %.1f -> %.1f m/s" % [rags.size(), in_path.size(), speed_before, speed_after])
	eq(rags.size(), in_path.size(), "every troop in the tank's path is knocked down")
	check(is_instance_valid(aside) and aside.alive, "the troop off to the side is left alone")
	check(speed_after > speed_before - 1.0, "the tank barely notices (%.1f -> %.1f m/s)" % [speed_before, speed_after])
	for rag in rags:
		var p: RigidBody3D = rag.bodies.pelvis
		check(p.global_position.z < -27.0, "a run-over troop is shoved ahead (pelvis z %.1f)" % p.global_position.z)
		check(p.global_position.distance_to(rag.bodies.head.global_position) < 0.6, "and holds together")

	# A squad crossing a charging tank's line scatters out of it.
	tank.place(Transform3D(Basis.IDENTITY, Vector3(30, Tank.RIDE + 0.2, 30)))
	var squad := TroopAI.spawn(self, 1, Vector3(25, 0, -10), Vector3(60, 0, -10), 5)
	await frames(2)
	tank.in_throttle = 1.0
	var scattered := false
	for i in 240:
		await get_tree().physics_frame
		if squad.state == TroopAI.State.SCATTER:
			scattered = true
	var alive := squad.members.size() if is_instance_valid(squad) else 0
	print("squad scattered %s, %d of 5 still standing" % [scattered, alive])
	check(scattered, "the squad scatters from the charging tank")
	check(alive >= 3, "and most of it gets out of the way (%d of 5)" % alive)
