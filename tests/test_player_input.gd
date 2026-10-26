extends TestCase
## A player's session, through the real input pipeline: key and mouse events go through
## Input.parse_input_event into the game scene exactly as a keyboard and mouse would send them.
## Drive, steer, aim with the mouse, loose, winch the string back, switch bolt gravity and arenas, reset,
## and let go of the mouse.

var game: Node3D


func run() -> void:
	timeout_s = 120.0
	game = load("res://scripts/game.gd").new()
	add_child(game)
	await frames(10)
	var p: Tank = game.player
	check(p.model.find_children("*", "MeshInstance3D", true, false).size() >= 15, "the player drives the textured tank")

	# Mouse: swing the aim to the left; the ballista follows within its arc (on the flat, at the spawn).
	_mouse_motion(Vector2(-240, 0))
	await frames(40)
	check(p.yaw > 0.3, "mouse aims the ballista left (yaw %.2f)" % p.yaw)
	_mouse_motion(Vector2(240, 0))
	await frames(40)

	# W: drive.
	var start := p.global_position
	_key(KEY_W, true)
	await frames(90)
	check(p.global_position.distance_to(start) > 15.0, "W drives forward (%.1f m)" % p.global_position.distance_to(start))
	check(p.velocity.length() > 15.0, "up to speed (%.1f m/s)" % p.velocity.length())
	# D: steer right while driving.
	var heading := p.forward
	_key(KEY_D, true)
	await frames(30)
	_key(KEY_D, false)
	_key(KEY_W, false)
	check(rad_to_deg(heading.angle_to(p.forward)) > 20.0, "D steers (%.0f deg)" % rad_to_deg(heading.angle_to(p.forward)))
	await frames(60)

	# Left button: loose the loaded bolt, which sits on a fully tensioned string.
	check(p.loaded and p.draw == 1.0, "starts loaded, string fully back")
	_mouse_button(MOUSE_BUTTON_LEFT, true)
	await frames(3)
	check(not p.loaded, "a click looses the bolt")
	_mouse_button(MOUSE_BUTTON_LEFT, false)
	check(game.get_children().any(func(n: Node) -> bool: return _has_bolt(n)), "a bolt is in flight")

	# R: winch the string back; at full tension a bolt drops in.
	_key(KEY_R, true)
	await frames(35)
	check(not p.loaded and p.draw > 0.3 and p.draw < 0.9, "holding R winches the string back (%.2f)" % p.draw)
	await frames(45)
	_key(KEY_R, false)
	check(p.loaded and p.draw == 1.0, "fully back: a new bolt is in")

	# B: bolt gravity.
	var mode := Bolt.mode
	_key(KEY_B, true)
	_key(KEY_B, false)
	await frames(2)
	check(Bolt.mode != mode, "B switches bolt gravity")
	Bolt.mode = mode

	# Esc lets go of the mouse: the button no longer fires; a click takes the mouse back.
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await frames(2)
	Input.action_press("fire")
	await frames(10)
	check(game.player.loaded, "no firing with the mouse let go")
	Input.action_release("fire")
	_mouse_button(MOUSE_BUTTON_LEFT, true)
	_mouse_button(MOUSE_BUTTON_LEFT, false)
	await frames(2)
	check(not game._mouse_free, "a click takes the mouse back")

	# M: the generated road arena; T: back to the spawn.
	_key(KEY_M, true)
	_key(KEY_M, false)
	await frames(5)
	check(game.arena_kind == "roads" and game.arena.road != null, "M switches to the road arena")
	p = game.player
	_key(KEY_W, true)
	await frames(60)
	_key(KEY_W, false)
	_key(KEY_T, true)
	_key(KEY_T, false)
	await frames(2)
	near(p.global_position, game.arena.player_spawn.origin, 0.5, "T resets to the spawn")


func _has_bolt(n: Node) -> bool:
	if n is Bolt:
		return true
	return n.get_children().any(func(c: Node) -> bool: return _has_bolt(c))


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _mouse_button(button: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)


func _mouse_motion(rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = rel
	Input.parse_input_event(e)
