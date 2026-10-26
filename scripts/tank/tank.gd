class_name Tank
extends CharacterBody3D
## Arcade tank with a ballista. Gravity follows the surface under the tank while it is grounded,
## and GravityField while it is in the air (docs/design/arena-structure.md, section 2), so it
## drives up quarter-pipes onto walls and ceilings at any speed.
##
## The frame (up, forward) is carried around curves by parallel transport: when up turns,
## forward, velocity and the player's aim turn with it (up_turn), so speed and heading survive
## a quarter-pipe. Input comes from the player (game.gd) or from ai.

signal fired(bolt: Bolt)

const MAX_SPEED := 28.0
const REVERSE_SPEED := 10.0
const ACCEL := 24.0
const BRAKE := 45.0
const COAST_DRAG := 8.0
const OVERSPEED_DRAG := 6.0     # how fast a boost above MAX_SPEED bleeds off
const TURN_RATE := 2.3          # rad/s at speed
const PIVOT := 0.5              # fraction of TURN_RATE when stopped (tanks pivot in place)
const GRIP := 70.0              # m/s^2 of sideways slide removed
const DRIFT_GRIP := 10.0
const DRIFT_TURN := 1.45
const DRIFT_BOOST := 9.0
const HOP_SPEED := 6.0
const GRAVITY := 30.0
const RIDE := 0.8               # capsule radius: body origin height above the ground
const PROBE := 1.4              # ground counts this far below the capsule
const UP_RATE_GROUND := 14.0
const UP_RATE_AIR := 3.0
# Momentum (the castle skatepark): the tank sticks to gentle surfaces at any speed, but to steep
# and upside-down ones only while it's fast enough; below that it peels off and falls. Slopes
# pull along themselves, so climbing costs speed and dropping in gives it back.
const STICK_FREE := 0.785       # rad from "up": surfaces this gentle always hold the tank
const STICK_VERT_SPEED := 12.0  # m/s needed on a vertical wall
const STICK_INV_SPEED := 16.0   # m/s needed upside down
const SLOPE_PULL := 0.6         # fraction of gravity that acts along a slope
const ARC := 1.05               # ballista traverse either side of the nose (rad, 60 deg: further, the stock hits the seat box)
const PITCH_MIN := -0.2
const PITCH_MAX := 0.7
const BALLISTA_TURN := 3.5      # rad/s
const CRANK_TIME := 1.1         # s of holding R per bolt
const BOLT_SPEED_MIN := 55.0
const BOLT_SPEED_MAX := 105.0
const HIT_SHOVE := 14.0
const HIT_POP := 11.0

var team := 0
var field: GravityField
var up := Vector3.UP
var forward := Vector3.FORWARD
var grounded := false
var air_time := 0.0
var up_turn := Quaternion.IDENTITY   ## the frame's rotation this tick; the camera and aim follow it
var hits_taken := 0

# Input, written each tick by the player controller or _ai_input().
var in_throttle := 0.0
var in_steer := 0.0
var in_drift := false
var in_hop := false
var in_crank := 0.0                 ## crank progress to add this tick (0..1 per bolt)
var in_fire := false                ## fire button down (a press looses a loaded bolt)
var aim_point := Vector3.ZERO
var aim_active := false

# Ballista state.
var crank := 0.0
var loaded := true
var draw := 1.0   ## string tension 0..1: follows the crank; a loaded bolt sits on a full draw
var yaw := 0.0
var pitch := 0.0

var ai := ""                        ## "", "circle" or "follow"
var ai_path: Array = []             ## frames to follow ({pos, up, tan})
var ai_throttle := 0.75
var model: TankModel

var _ai_idx := 0
var _fire_was := false   # fire looses on the press, not while held
var _drift_time := 0.0
var _stun := 0.0
var _tumble := 0.0


func _init(p_team := 0) -> void:
	team = p_team


func _ready() -> void:
	add_to_group("tanks")   # troops look for tanks to scatter from, and get run over by them
	collision_layer = 2
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 1.0
	max_slides = 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RIDE
	cap.height = 3.6
	cs.shape = cap
	cs.rotation = Vector3(PI * 0.5, 0, 0)
	add_child(cs)
	model = TankModel.new(team)
	model.position = Vector3(0, -RIDE, 0)
	add_child(model)
	_take_frame()


## Put the tank at xform (its -Z forward, +Y up), at rest.
func place(xform: Transform3D) -> void:
	global_transform = xform
	velocity = Vector3.ZERO
	_take_frame()


func _take_frame() -> void:
	up = global_basis.y.normalized()
	forward = -global_basis.z.normalized()


func _physics_process(dt: float) -> void:
	if ai != "":
		_ai_input()
	_stun = maxf(0.0, _stun - dt)
	var ground := _probe()
	grounded = _stun <= 0.0 and not ground.is_empty() and sticks(ground.normal)
	var target_up: Vector3 = ground.normal if grounded else -field.down_at(global_position)
	_turn_frame(target_up, (UP_RATE_GROUND if grounded else UP_RATE_AIR) * dt)
	_steer(dt)
	_drive(dt)
	up_direction = up
	floor_snap_length = 1.0 if grounded else 0.0
	move_and_slide()
	global_basis = Basis.looking_at(forward, up)
	air_time = 0.0 if grounded else air_time + dt
	_ballista(dt)
	_animate(dt)


# --- Movement ---------------------------------------------------------------------------------

## The ground under the tank: averaged over three rays (front, middle, back) so the normal turns
## smoothly across the faceted quarter-pipes. Empty when nothing is close enough below.
func _probe() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var normal := Vector3.ZERO
	var hits := 0
	var best := {}
	for off in [1.3, 0.0, -1.3]:
		var o: Vector3 = global_position + forward * off
		var q := PhysicsRayQueryParameters3D.create(o + up * 0.3, o - up * (RIDE + PROBE), 1)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.normal.dot(up) < 0.3:   # walls are not ground
			continue
		normal += hit.normal
		hits += 1
		if off == 0.0 or best.is_empty():
			best = hit
	if hits == 0:
		return {}
	best.normal = normal.normalized()
	return best


func _turn_frame(target: Vector3, w: float) -> void:
	if up.dot(target) < -0.95:
		# Straight over the top: tip forward (a flip) rather than through an undefined axis.
		target = (target + forward * 0.6).normalized()
	var new_up := turn_toward(up, target, w)
	var q := Quaternion(up, new_up)
	forward = q * forward
	if grounded:
		velocity = q * velocity
	up = new_up
	up_turn = q
	var f := forward - up * forward.dot(up)
	if f.length() < 0.05:
		f = -global_basis.z - up * (-global_basis.z).dot(up)
	forward = f.normalized()


## Whether the tank holds onto a surface with this normal at its current speed. "Up" is the
## local gravity's up, so in the cube arena (faces aligned with gravity) everything holds.
func sticks(normal: Vector3) -> bool:
	var ang := normal.angle_to(-field.down_at(global_position))
	if ang <= STICK_FREE:
		return true
	var need: float
	if ang <= PI * 0.5:
		need = lerpf(0.0, STICK_VERT_SPEED, inverse_lerp(STICK_FREE, PI * 0.5, ang))
	else:
		need = lerpf(STICK_VERT_SPEED, STICK_INV_SPEED, inverse_lerp(PI * 0.5, PI, ang))
	return (velocity - normal * velocity.dot(normal)).length() >= need


## Unit vector v turned toward unit vector target by fraction w of the angle between them.
## (Vector3.slerp builds a denormalised axis for nearly parallel vectors and errors.)
static func turn_toward(v: Vector3, target: Vector3, w: float) -> Vector3:
	var ang := v.angle_to(target)
	if ang < 0.001:
		return target
	return v.rotated(v.cross(target).normalized(), ang * clampf(w, 0.0, 1.0)).normalized()


func _steer(dt: float) -> void:
	var fs := velocity.dot(forward)
	var dir := -1.0 if fs < -0.5 else 1.0
	var factor := maxf(PIVOT, clampf(absf(fs) / 8.0, 0.0, 1.0))
	if not grounded:
		factor *= 0.35
	var rate := TURN_RATE * (DRIFT_TURN if in_drift and grounded else 1.0)
	forward = forward.rotated(up, -in_steer * rate * factor * dir * dt).normalized()


func _drive(dt: float) -> void:
	if not grounded:
		velocity += field.down_at(global_position) * GRAVITY * dt
		in_hop = false
		return
	var vn := up * velocity.dot(up)
	var vt := velocity - vn
	var down := field.down_at(global_position)
	vt += (down - up * down.dot(up)) * GRAVITY * SLOPE_PULL * dt   # slopes slow the climb, speed the drop
	var fs := vt.dot(forward)
	var side := vt - forward * fs
	var target := in_throttle * (MAX_SPEED if in_throttle > 0.0 else REVERSE_SPEED)
	if absf(in_throttle) < 0.05:
		fs = move_toward(fs, 0.0, COAST_DRAG * dt)
	elif absf(fs) > 0.5 and signf(in_throttle) != signf(fs):
		fs = move_toward(fs, 0.0, BRAKE * dt)
	elif absf(fs) > absf(target):
		fs = move_toward(fs, target, OVERSPEED_DRAG * dt)
	else:
		fs = move_toward(fs, target, ACCEL * dt)
	side = side.move_toward(Vector3.ZERO, (DRIFT_GRIP if in_drift else GRIP) * dt)
	vt = forward * fs + side
	# Drift boost: hold a drift through a turn, release for a kick.
	if in_drift and absf(in_steer) > 0.3 and fs > 10.0:
		_drift_time += dt
	elif _drift_time > 0.0:
		if _drift_time > 0.8:
			vt += forward * DRIFT_BOOST
		_drift_time = 0.0
	if in_hop:
		vn = up * HOP_SPEED
		_stun = 0.1
	else:
		vn = up * minf(velocity.dot(up), 0.0)
	in_hop = false
	velocity = vt + vn - up * GRAVITY * dt


func boost(amount: float) -> void:
	velocity += forward * amount


func launch(v: Vector3) -> void:
	velocity = v
	_stun = 0.3


func take_hit(bolt_velocity: Vector3) -> void:
	hits_taken += 1
	velocity += bolt_velocity.normalized() * HIT_SHOVE + up * HIT_POP
	_stun = 0.35
	_tumble = TAU


# --- Ballista ---------------------------------------------------------------------------------

## Reloading is winching: cranking pulls the string back (draw follows the crank) until it's
## fully tensioned, then a bolt drops into the groove. Pressing fire looses it.
func _ballista(dt: float) -> void:
	if not loaded:
		crank = minf(1.0, crank + in_crank)
		draw = crank
		if crank >= 1.0:
			loaded = true
			crank = 0.0   # the cog has turned whole turns, so it doesn't jump
	in_crank = 0.0
	if loaded and in_fire and not _fire_was:
		_fire()
	_fire_was = in_fire

	var want := forward
	if aim_active:
		var to := aim_point - model.ballista_yaw.global_position
		if to.length() > 1.0:
			want = to.normalized()
	var local := global_basis.inverse() * want
	var yaw_t := clampf(atan2(-local.x, -local.z), -ARC, ARC)
	var pitch_t := clampf(asin(clampf(local.y, -1.0, 1.0)), PITCH_MIN, PITCH_MAX)
	yaw = move_toward(yaw, yaw_t, BALLISTA_TURN * dt)
	pitch = move_toward(pitch, pitch_t, BALLISTA_TURN * dt)
	model.ballista_yaw.rotation.y = yaw
	model.ballista_pitch.rotation.x = pitch
	model.set_loaded(loaded)
	model.set_draw(draw)
	model.set_crank(crank)


## Where a bolt would leave the ballista right now, and with what velocity.
func muzzle() -> Dictionary:
	var tip := model.bolt_tip.global_transform
	var speed := lerpf(BOLT_SPEED_MIN, BOLT_SPEED_MAX, draw)
	return {"pos": tip.origin, "vel": -tip.basis.z.normalized() * speed + velocity * 0.5}


func _fire() -> void:
	var m := muzzle()
	var bolt := Bolt.new()
	bolt.setup(self, m.pos, m.vel, Bolt.gravity_for(up))
	get_parent().add_child(bolt)
	model.release()   # the string snaps forward behind the departing bolt
	loaded = false
	draw = 0.0
	fired.emit(bolt)


# --- AI and looks -----------------------------------------------------------------------------

func _ai_input() -> void:
	match ai:
		"circle":
			in_throttle = 0.55
			in_steer = 1.0
		"follow":
			if ai_path.is_empty():
				return
			var n := ai_path.size()
			# Advance along the loop while the next frames are close.
			for i in 8:
				var nxt: Dictionary = ai_path[(_ai_idx + 1) % n]
				if global_position.distance_to(nxt.pos) < global_position.distance_to(ai_path[_ai_idx].pos):
					_ai_idx = (_ai_idx + 1) % n
				else:
					break
			var target: Vector3 = ai_path[(_ai_idx + 5) % n].pos
			var local := global_basis.inverse() * (target - global_position)
			var angle := atan2(local.x, -local.z)
			in_steer = clampf(angle * 2.0, -1.0, 1.0)
			in_throttle = ai_throttle * clampf(1.3 - absf(angle) * 1.5, 0.35, 1.0)   # ease off into corners


## Snap the follower to the nearest point of its path (after placing it somewhere).
func ai_sync() -> void:
	var best := INF
	for i in ai_path.size():
		var d: float = global_position.distance_to(ai_path[i].pos)
		if d < best:
			best = d
			_ai_idx = i


func _animate(dt: float) -> void:
	if _tumble > 0.0:
		_tumble = maxf(0.0, _tumble - dt * 14.0)
		model.rotation.z = _tumble
	model.set_spin(velocity.dot(forward), dt)
