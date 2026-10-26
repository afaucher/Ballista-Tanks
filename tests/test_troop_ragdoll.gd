extends TestCase
## A troop shot mid-run turns into a ragdoll: its joints stay within their limits (elbows and knees
## never bend backwards) while it flies, lands hard and settles, it holds together, and it fades
## away after a while.


func run() -> void:
	print("physics engine: %s (%s)" % [ProjectSettings.get_setting("physics/3d/physics_engine"), PhysicsServer3D.get_class()])
	Geo.box(self, Vector3(60, 2, 60), Transform3D(Basis.IDENTITY, Vector3(0, -1, 0)), Look.road())
	var worst_settled := 0.0
	var worst := 0.0
	var worst_joint := ""
	for k in 3:
		var t := Troop.new(k % 2)
		add_child(t)
		t.global_position = Vector3(k * 6.0 - 6.0, 0.05, 0)
		t.move_dir = Vector3(0, 0, -1).rotated(Vector3.UP, k * 1.3)
		await frames(40)
		check(t.is_on_floor(), "troop %d runs on the ground" % k)
		var impulse := Vector3(3.0, 5.0, -8.0).rotated(Vector3.UP, k * 2.0) * (1.0 + k * 0.6)
		var rag := t.die(impulse, t.global_position + Vector3.UP * 0.8)
		check(rag != null and not t.alive, "troop %d dies into a ragdoll" % k)
		eq(rag.joints.size(), 10, "joints: waist, neck, shoulders, elbows, hips, knees")
		for i in 240:
			await get_tree().process_frame   # after the physics tick: the pose that is drawn
			var errs := rag.limit_errors()
			for p: String in errs:
				if errs[p] > worst:
					worst = errs[p]
					worst_joint = p
				if i > 120:
					worst_settled = maxf(worst_settled, errs[p])
		var head: RigidBody3D = rag.bodies.head
		var pelvis: RigidBody3D = rag.bodies.pelvis
		print("ragdoll %d: head y %.2f, pelvis y %.2f, head %.1f m from the pelvis" % [
				k, head.global_position.y, pelvis.global_position.y, head.global_position.distance_to(pelvis.global_position)])
		check(head.global_position.y < 0.6 and pelvis.global_position.y < 0.6, "ragdoll %d lies on the ground" % k)
		check(head.global_position.distance_to(pelvis.global_position) < 0.6, "ragdoll %d holds together" % k)
		for p: String in rag.joints:
			print("  %s: %s deg" % [p, rag.joint_angles(p).round()])
	print("worst limit overshoot %.1f deg (%s), after settling %.1f deg" % [worst, worst_joint, worst_settled])
	# Projection leaves up to SLACK_DEG per axis to the physics.
	var slack := TroopRagdoll.SLACK_DEG * 3.0 + 1.0
	check(worst < slack, "joints never overshoot their limits by more than %.0f deg (%.1f, %s)" % [slack, worst, worst_joint])

	# Fading: a ragdoll goes after FADE_AFTER seconds.
	var rags := find_children("*", "TroopRagdoll", false, false)
	var rag: TroopRagdoll = rags[0]
	rag.age = TroopRagdoll.FADE_AFTER - 0.1
	await frames(int((TroopRagdoll.FADE_TIME + 0.5) * 60))
	check(not is_instance_valid(rag), "a ragdoll fades after %.0f s" % TroopRagdoll.FADE_AFTER)
