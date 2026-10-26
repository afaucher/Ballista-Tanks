class_name TroopAI
extends Node
## A squad of 3-6 troops (docs/design/troops.md) and its state machine:
##   MARCH    follow a path to the goal in a loose column
##   SCATTER  a tank charging at a troop sends it sprinting sideways out of its line
##            (per troop; the squad regroups afterwards)
##   CHEER    at the goal: stop, arms up, hop
## Each troop finds its own path on the navigation mesh (bake_nav: ground and gentle ramps only, so
## troops never ride the walls), re-planned every few seconds; with no mesh, a straight line.

enum State { MARCH, SCATTER, CHEER }

const SPACING := 1.1          # m between squad mates
const ARRIVE := 4.0           # the squad's centre this close to the goal: it cheers
const WAYPOINT := 0.8        # close enough to a path point to head for the next (corners hug piers)
const REPATH := 3.0           # s between a troop's path updates (scattering moves it around)
const SCATTER_RANGE := 22.0   # a tank this close...
const SCATTER_LANE := 5.0     # ...heading at a troop within this distance of its line...
const SCATTER_SPEED := 6.0    # ...at this speed or more is charging
const SCATTER_TIME := 1.4
const SCATTER_SPRINT := 1.4
const NAV_CELL := 0.3

var team := 0
var goal := Vector3.ZERO
var members: Array[Troop] = []
var state := State.MARCH

var _routes := {}             # troop instance id -> {path: PackedVector3Array, wp: int, t: s to re-plan}
var _scatter := {}            # troop instance id -> {t: seconds left, dir: Vector3}


## `count` troops of `team` standing around `at` (in `parent`, which must be in the tree), facing
## and marching toward `goal`. The squad node goes into `parent` too.
static func spawn(parent: Node, p_team: int, at: Vector3, p_goal: Vector3, count: int) -> TroopAI:
	var squad := TroopAI.new()
	squad.name = "Squad%d" % p_team
	squad.team = p_team
	squad.goal = p_goal
	parent.add_child(squad)
	var dir := Vector3(p_goal.x - at.x, 0, p_goal.z - at.z).normalized()
	var right := dir.cross(Vector3.UP)
	for i in count:
		var t := Troop.new(p_team)
		var slot := squad._slot(i, count)
		parent.add_child(t)
		t.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), at + right * slot.x - dir * slot.y + Vector3.UP * 0.05)
		t.facing = dir
		squad.members.append(t)
	return squad


# A troop's place in the column: (sideways, back) from the squad's centre.
func _slot(i: int, n: int) -> Vector2:
	var rows := ceili(n / 2.0)
	return Vector2(((i % 2) - 0.5) * SPACING * 1.3, (floori(i / 2.0) - (rows - 1) * 0.5) * SPACING)


func center() -> Vector3:
	var c := Vector3.ZERO
	for t in members:
		c += t.global_position
	return c / maxf(members.size(), 1)


func _physics_process(dt: float) -> void:
	for i in range(members.size() - 1, -1, -1):
		if not is_instance_valid(members[i]) or not members[i].alive:
			members.remove_at(i)
	if members.is_empty():
		queue_free()
		return
	var c := center()
	if state != State.CHEER and _flat(goal - c).length() < ARRIVE:
		state = State.CHEER
	if state == State.CHEER:
		for t in members:
			t.move_dir = Vector3.ZERO
			t.cheering = true
		return
	var map := get_viewport().find_world_3d().navigation_map
	var nav := NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty()
	var scattering := false
	for t in members:
		var id := t.get_instance_id()
		var s: Dictionary = _scatter.get(id, {})
		if s.is_empty():
			s = _threat(t)
			if not s.is_empty():
				_scatter[id] = s
		if not s.is_empty():
			s.t -= dt
			if s.t <= 0.0:
				_scatter.erase(id)
				_routes.erase(id)   # it is somewhere else now
			scattering = true
			t.move_dir = s.dir
			t.speed_scale = SCATTER_SPRINT
			continue
		# March: along its own path (so the column threads round piers and through gates), off
		# its mates, the ones out ahead easing off for the stragglers.
		var dir := _route_dir(t, map, nav, dt)
		var steer := dir
		for o in members:
			var away := _flat(t.global_position - o.global_position)
			var d := away.length()
			if o != t and d < SPACING and d > 0.001:
				steer += away / d * (SPACING - d) * 1.5
		t.move_dir = steer.limit_length(1.0)
		var lead := _flat(t.global_position - c).dot(dir)
		t.speed_scale = clampf(1.0 - lead * 0.15, 0.7, 1.15)
	state = State.SCATTER if scattering else State.MARCH


# A tank charging at troop t: which way to dive. Empty if none.
func _threat(t: Troop) -> Dictionary:
	for tank: Tank in get_tree().get_nodes_in_group("tanks"):
		var v := _flat(tank.velocity)
		var speed := v.length()
		if speed < SCATTER_SPEED:
			continue
		var to_me := _flat(t.global_position - tank.global_position)
		var vd := v / speed
		var ahead := to_me.dot(vd)
		if ahead < 0.0 or ahead > SCATTER_RANGE:
			continue
		var side := to_me - vd * ahead
		if side.length() > SCATTER_LANE:
			continue
		var away := side.normalized() if side.length() > 0.2 else vd.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
		return {"t": SCATTER_TIME, "dir": (away + vd * 0.2).normalized()}
	return {}


## Troop t's path to the goal (empty until it has one).
func route(t: Troop) -> PackedVector3Array:
	return _routes.get(t.get_instance_id(), {}).get("path", PackedVector3Array())


# Which way troop t heads: toward the next point of its path (which starts where it stood when
# planned), re-planned every REPATH seconds.
func _route_dir(t: Troop, map: RID, nav: bool, dt: float) -> Vector3:
	var id := t.get_instance_id()
	var p := t.global_position
	var r: Dictionary = _routes.get(id, {})
	if not r.is_empty():
		r.t -= dt
	if r.is_empty() or r.t <= 0.0 or r.nav != nav:
		var path := NavigationServer3D.map_get_path(map, p, goal, true) if nav else PackedVector3Array()
		if path.size() < 2:
			path = PackedVector3Array([p, goal])
		r = {"path": path, "wp": 1, "t": REPATH + randf(), "nav": nav}
		_routes[id] = r
	var path: PackedVector3Array = r.path
	var wp: int = r.wp
	while wp < path.size() - 1 and _flat(path[wp] - p).length() < WAYPOINT:
		wp += 1
	r.wp = wp
	return _flat(path[wp] - p).normalized()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


## Bakes a navigation mesh for troops from the static colliders under `root` and adds it as a
## region under `root` (about 0.2 s for the castle skatepark). Ground, ramps and walks up to 35
## degrees: the walls' quarter-pipes and faces stay tank territory.
static func bake_nav(root: Node3D) -> NavigationRegion3D:
	var nm := NavigationMesh.new()
	nm.cell_size = NAV_CELL
	nm.cell_height = 0.2
	nm.agent_radius = 0.6
	nm.agent_height = 1.2
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 35.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	var map := root.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, nm.cell_size)
	NavigationServer3D.map_set_cell_height(map, nm.cell_height)
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, root)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var region := NavigationRegion3D.new()
	region.name = "TroopNav"
	region.navigation_mesh = nm
	root.add_child(region)
	return region
