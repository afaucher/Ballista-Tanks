extends Node3D
## The gray-box prototype: an arena (castle skatepark, starter cube or generated roads), the player's tank,
## a few dummy tanks, the chase camera and the HUD.
##
## User args (after --):
##   --arena castles|starter|roads   --seed N   --bolt straight|down
##   --bot                   the player's tank drives itself (follows the road in roads mode) and
##                           shoots at enemies ahead; --demo puts an enemy just up the road
##   --view chase|overview   --shot-dir DIR --shot-times 1.5,4   save screenshots, then quit

const CAM_HEIGHT := 2.4      # pivot above the tank's origin
const CAM_BACK := 5.6
const CAM_LIFT := 1.4
const MOUSE_SENS := 0.0025
const ARENAS := ["castles", "roads", "starter"]   # M cycles through them

var arena: Arena
var player: Tank
var tanks: Array[Tank] = []
var cam: Camera3D
var hud: Hud
var hits := 0
var show_help := true
var arena_kind := "castles"
var road_settings := RoadGen.Settings.new()

var _aim := Vector3.FORWARD   # world-space aim; carried along by the player's frame
var _cam_up := Vector3.UP
var _bot := false
var _bot_draw := 0.0
var _mouse_free := false   # Esc lets go of the mouse; the next click takes it back
var _demo := false
var _view := "chase"
var _shot_dir := ""
var _shot_times: Array[float] = []
var _clock := 0.0
var _world: Node3D


func _ready() -> void:
	process_physics_priority = 10   # after the tanks
	var args := _args()
	arena_kind = args.get("arena", "castles")
	road_settings.seed = int(args.get("seed", "1"))
	if args.get("bolt", "") == "straight":
		Bolt.mode = Bolt.Mode.STRAIGHT
	_bot = args.has("bot")
	_demo = args.has("demo")
	_view = args.get("view", "chase")
	_shot_dir = args.get("shot-dir", "")
	for t in String(args.get("shot-times", "")).split(",", false):
		_shot_times.append(float(t))
	Controls.setup()

	cam = Camera3D.new()
	cam.fov = 75.0
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	_build()
	if _shot_dir == "" and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--"):
			var key := a[i].substr(2)
			if i + 1 < a.size() and not a[i + 1].begins_with("--"):
				out[key] = a[i + 1]
				i += 1
			else:
				out[key] = true
		i += 1
	return out


func _build() -> void:
	if _world:
		_world.queue_free()
	_world = Node3D.new()
	add_child(_world)
	arena = Arena.new()
	_world.add_child(arena)
	if arena_kind == "castles":
		Look.make_outdoor(_world)
		arena.build_castles()
	else:
		_world.add_child(Look.make_environment())
		Look.make_sun(_world, Arena.HALF)
		if arena_kind == "roads":
			arena.build_roads(road_settings)
		else:
			arena.build_starter()
	tanks.clear()
	player = _spawn(0, arena.player_spawn)
	if _bot and arena.road:
		player.ai = "follow"
		player.ai_path = arena.road.frames
		player.ai_throttle = 0.8
	elif _bot:
		player.in_throttle = 1.0   # straight ahead, up the quarter-pipe
	for t in arena.dummy_spawns:
		var d := _spawn(1, t)
		if arena.road:
			d.ai = "follow"
			d.ai_path = arena.road.frames
			d.ai_throttle = 0.6
		else:
			d.ai = "circle"
	if _demo and arena.road and tanks.size() > 1:   # an enemy just up the road, to chase and shoot
		tanks[1].place(arena._on_road(20))
		tanks[1].ai_throttle = 0.35
	for t in tanks:
		if t.ai == "follow":
			t.ai_sync()
	_aim = player.forward
	_cam_up = player.up
	hits = 0


func _spawn(team: int, xform: Transform3D) -> Tank:
	var t := Tank.new(team)
	t.field = arena.field
	_world.add_child(t)
	t.place(xform)
	tanks.append(t)
	return t


func info_lines() -> Array[String]:
	var out: Array[String] = ["Arena: %s  [M]" % arena_kind]
	if arena.road:
		var m := arena.road.metrics
		out.append(road_settings.describe() + "  [N]")
		out.append("loop %d m (%.0f s lap)  bends %d  quarter-pipes %d  crests %d  twists %d  flips %d" % [
				m.length_m, m.lap_s, m.bend, m.quarter_pipe, m.crest, m.twist, m.flip])
		out.append("up balance %.2f  pyramids %.2f  misalign %.0f deg  score %.2f" % [
				m.balance, m.spread, m.misalign_deg, m.score])
	return out


# --- Input ------------------------------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and not _mouse_free:
		_turn_aim(-e.relative.x * MOUSE_SENS, -e.relative.y * MOUSE_SENS)
	elif e is InputEventMouseButton and e.pressed:
		if _mouse_free:   # the click that takes the mouse back doesn't also fire
			_mouse_free = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			player.in_crank += 0.12
	elif e.is_action_pressed("toggle_bolt"):
		Bolt.mode = Bolt.Mode.STRAIGHT if Bolt.mode == Bolt.Mode.SHOOTER_DOWN else Bolt.Mode.SHOOTER_DOWN
	elif e.is_action_pressed("switch_arena"):
		arena_kind = ARENAS[(ARENAS.find(arena_kind) + 1) % ARENAS.size()]
		_build()
	elif e.is_action_pressed("new_seed"):
		road_settings.seed += 1
		arena_kind = "roads"
		_build()
	elif e.is_action_pressed("reset"):
		player.place(arena.player_spawn)
		_aim = player.forward
	elif e.is_action_pressed("help"):
		show_help = not show_help
	elif e.is_action_pressed("ui_cancel"):
		_mouse_free = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _turn_aim(yaw: float, pitch: float) -> void:
	var up := player.up
	_aim = _aim.rotated(up, yaw)
	var right := _aim.cross(up).normalized()
	var next := _aim.rotated(right, pitch)
	var elev := asin(clampf(next.dot(up), -1.0, 1.0))
	if elev > -0.45 and elev < 1.1:
		_aim = next
	_aim = _aim.normalized()


func _player_input() -> void:
	if player.ai != "" or _bot:
		return
	player.in_throttle = Input.get_axis("brake", "throttle")
	player.in_steer = Input.get_axis("steer_left", "steer_right")
	player.in_drift = Input.is_action_pressed("drift")
	if Input.is_action_just_pressed("hop"):
		player.in_hop = true
	if Input.is_action_pressed("crank"):
		player.in_crank += get_physics_process_delta_time() / Tank.CRANK_TIME
	player.in_fire = Input.is_action_pressed("fire") and not _mouse_free


# --- Camera, aim, HUD -------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	_clock += dt
	if not is_instance_valid(player):
		return
	_player_input()
	# Carry the aim around with the tank's frame, then keep it off the ground plane's underside.
	_aim = (player.up_turn * _aim).normalized()
	if _bot:   # no mouse: look where the hull goes
		_aim = Tank.turn_toward(_aim, (player.forward - player.up * 0.12).normalized(), 1.0 - exp(-5.0 * dt))
	var target_up := player.up
	if _cam_up.dot(target_up) < -0.95:
		target_up = (target_up + player.forward * 0.5).normalized()
	_cam_up = Tank.turn_toward(_cam_up, target_up, 1.0 - exp(-6.0 * dt))

	if _view == "overview" and arena_kind == "castles":
		cam.global_position = Vector3(95, 60, -115)
		cam.look_at(Vector3(0, 6, -10), Vector3.UP)
	elif _view == "overview":
		cam.global_position = Vector3(-52, -40, 28)   # off the corner diagonal: a chain runs along it
		cam.look_at(Vector3(10, 4, -10), Vector3.UP)
	else:
		var pivot := player.global_position + player.up * CAM_HEIGHT
		var want := pivot - _aim * CAM_BACK + _cam_up * CAM_LIFT
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(pivot, want, 1)
		var hit := space.intersect_ray(q)
		cam.global_position = want if hit.is_empty() else hit.position + (pivot - want).normalized() * 0.4
		var look_dir := (_aim * 40.0 + pivot - cam.global_position).normalized()
		var cam_ref := _cam_up if absf(look_dir.dot(_cam_up)) < 0.98 else player.forward
		cam.look_at(cam.global_position + look_dir, cam_ref)

	# The ballista aims at whatever is under the crosshair.
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_basis.z * 500.0
	var aq := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	aq.exclude = [player.get_rid()]
	var ah := space.intersect_ray(aq)
	player.aim_point = to if ah.is_empty() else ah.position
	player.aim_active = true
	if _bot:
		_bot_gunner(dt)

	var m := player.muzzle()
	var exclude: Array[RID] = [player.get_rid()]
	var pred := Bolt.predict(space, m.pos, m.vel, Bolt.gravity_for(player.up), exclude)
	hud.trail = pred.points
	hud.impact = pred.end
	hud.impact_hit = pred.hit

	_score()
	_shots()


## --bot also shoots: aims at the nearest enemy within 70 m ahead, cranks, draws and looses.
func _bot_gunner(dt: float) -> void:
	var best: Tank = null
	var best_d := 70.0
	for t in tanks:
		if t == player:
			continue
		var to_t := t.global_position - player.global_position
		var d := to_t.length()
		if d < best_d and to_t.normalized().dot(player.forward) > 0.5:
			best = t
			best_d = d
	if not player.loaded:
		player.in_crank += dt / Tank.CRANK_TIME
		return
	if best == null:
		player.in_fire = false
		return
	player.aim_point = best.global_position + best.up * 0.6
	_bot_draw += dt
	player.in_fire = _bot_draw < 0.4   # hold to draw, then let go
	if _bot_draw > 0.5:
		_bot_draw = 0.0


func _score() -> void:
	var total := 0
	for t in tanks:
		if t != player:
			total += t.hits_taken
	hits = total


func _shots() -> void:
	if _shot_dir == "" or _shot_times.is_empty():
		return
	if _clock < _shot_times[0]:
		return
	var t: float = _shot_times.pop_front()
	_save_shot(t, _shot_times.is_empty())


func _save_shot(t: float, last: bool) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var path := _shot_dir.path_join("%s_%s_%04.1f.png" % [arena_kind, _view, t])
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)
	if last:
		get_tree().quit()
