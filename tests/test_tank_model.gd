extends TestCase
## TankModel: the public nodes exist, the bolt points forward, draw pulls back, loaded toggles.


func run() -> void:
	var m := TankModel.new(0)
	add_child(m)
	await get_tree().process_frame

	check(m.ballista_yaw != null, "ballista_yaw exists")
	check(m.ballista_pitch != null and m.ballista_pitch.get_parent() == m.ballista_yaw, "ballista_pitch under yaw")
	check(m.bolt_tip != null and m.bolt_tip.get_parent() == m.ballista_pitch, "bolt_tip under pitch")
	near(m.ballista_yaw.position.y, float(TankModel.dims().pivot[1]), 0.001, "pivot height from dims.json")

	var fwd := -m.bolt_tip.global_basis.z.normalized()
	near(fwd.dot(Vector3.FORWARD), 1.0, 0.001, "bolt fires along -Z at yaw 0")
	check(m.bolt_tip.global_position.z < -1.5, "bolt tip sits ahead of the hull")

	m.ballista_yaw.rotation_degrees.y = 90.0
	fwd = -m.bolt_tip.global_basis.z.normalized()
	near(fwd.dot(Vector3.LEFT), 1.0, 0.001, "yaw +90 aims left")
	m.ballista_yaw.rotation_degrees.y = 0.0

	m.set_draw(0.0)
	var rest_nock := m.nock.z
	var rest_tip := m.bolt_tip.position.z
	m.set_draw(1.0)
	check(m.nock.z > rest_nock + 0.9, "draw pulls the string back")
	near(m.bolt_tip.position.z - rest_tip, m.nock.z - rest_nock, 0.001, "bolt rides the string")

	m.set_loaded(false)
	check(not m.bolt.visible, "unloaded hides the bolt")
	m.set_loaded(true)
	check(m.bolt.visible, "loaded shows the bolt")

	m.set_crank(0.5)
	m.set_spin(10.0, 0.1)
	m.queue_free()
