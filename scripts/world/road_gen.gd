class_name RoadGen
extends RefCounted
## Road-first arena generator (docs/design/arena-structure.md, "Road-first generation").
##
## The play space is one continuous road looping through the cube's volume. It runs on a 3D
## lattice: the loop visits lattice nodes, every corner is a quarter-circle arc, and the road's
## "up" turns with it. A corner that turns toward the road's up is a quarter-pipe (concave); one
## that turns away is a crest (convex); a corner in the road's own plane is an ordinary bend.
##
## 1. Grow: start from a square loop and keep replacing an edge with a three-edge detour
##    (u->v becomes u->u+e->v+e->v). Every step keeps the loop closed and self-avoiding.
## 2. Orient: choose each straight's up (one of four axes) by dynamic programming around the loop,
##    trading agreement with the airborne gravity against rolls and crests.
## 3. Score: candidates are graded on balance, spread and cost; the best one is swept into frames.


class Settings:
	extends RefCounted
	var seed := 1
	var spacing := 24.0      ## lattice cell (m); corners are arcs of radius spacing / 2
	var extent := 2          ## nodes run -extent..extent on each axis
	var core_radius := 18.0  ## no road within this distance of the centre: the open core
	var target_nodes := 28   ## loop length in nodes (x spacing = metres)
	var hug := 0.6           ## 0..1: how strongly the loop is pushed out toward the faces
	var candidates := 24     ## loops tried per seed; the best score wins
	var w_align := 2.0       ## cost of road whose up disagrees with the airborne gravity
	var w_twist := 1.5       ## cost of a 90 degree roll
	var w_flip := 8.0        ## cost of a 180 degree roll
	var w_crest := 4.0       ## cost of a convex corner (throws fast tanks off)
	var w_balance := 3.0     ## reward for spreading road over all six up directions
	var w_spread := 2.0      ## reward for passing through all six gravity pyramids

	func describe() -> String:
		return "seed %d  nodes %d  hug %.1f  core %.0f m  twist %.1f  crest %.1f  align %.1f" % [
				seed, target_nodes, hug, core_radius, w_twist, w_crest, w_align]


class Result:
	extends RefCounted
	var spacing := 0.0
	var nodes: Array[Vector3i] = []
	var ups: Array[Vector3i] = []   ## per straight: nodes[i] -> nodes[i + 1]
	var frames: Array = []          ## {pos, up, tan} along the deck centre line, closed loop
	var corners: Array = []         ## per node: {kind, pos, center, up, up_out, tan}
	var metrics := {}
	var score := -INF


const AXES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
		Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const SAMPLE_STEP := 2.0
const DRIVE_SPEED := 28.0   # for the lap-time estimate; Tank.MAX_SPEED
const FORBIDDEN := 1000.0


static func generate(s: Settings) -> Result:
	var best: Result = null
	for c in s.candidates:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([s.seed, c])
		var loop := _grow(s, rng)
		if loop.size() < 4:
			continue
		var r := _orient(s, loop)
		if r == null:
			continue
		if best == null or r.score > best.score:
			best = r
	if best != null:
		_sample(s, best)
	return best


# --- 1. Grow ----------------------------------------------------------------------------------

static func _valid(s: Settings, n: Vector3i) -> bool:
	if absi(n.x) > s.extent or absi(n.y) > s.extent or absi(n.z) > s.extent:
		return false
	return Vector3(n).length() * s.spacing >= s.core_radius


static func perps(d: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for a in AXES:
		if a.x * d.x + a.y * d.y + a.z * d.z == 0:
			out.append(a)
	return out


static func _grow(s: Settings, rng: RandomNumberGenerator) -> Array[Vector3i]:
	var loop: Array[Vector3i] = []
	for attempt in 200:
		var n0 := Vector3i(rng.randi_range(-s.extent, s.extent), rng.randi_range(-s.extent, s.extent),
				rng.randi_range(-s.extent, s.extent))
		var e1: Vector3i = AXES[rng.randi() % 6]
		var options := perps(e1)
		var e2: Vector3i = options[rng.randi() % options.size()]
		var sq: Array[Vector3i] = [n0, n0 + e1, n0 + e1 + e2, n0 + e2]
		if sq.all(func(n: Vector3i) -> bool: return _valid(s, n)):
			loop = sq
			break
	if loop.is_empty():
		return loop
	var used := {}
	for n in loop:
		used[n] = true
	var tries := 0
	while loop.size() < s.target_nodes and tries < 6000:
		tries += 1
		var i := rng.randi() % loop.size()
		var u := loop[i]
		var v := loop[(i + 1) % loop.size()]
		var options := perps(v - u)
		var e: Vector3i = options[rng.randi() % options.size()]
		# Hug: of two random detours, take the one further from the centre with probability hug.
		var e_alt: Vector3i = options[rng.randi() % options.size()]
		var further := Vector3(u + e_alt).length() > Vector3(u + e).length()
		if further == (rng.randf() < s.hug):
			e = e_alt
		var u2 := u + e
		var v2 := v + e
		if not _valid(s, u2) or not _valid(s, v2) or used.has(u2) or used.has(v2):
			continue
		loop.insert(i + 1, u2)
		loop.insert(i + 2, v2)
		used[u2] = true
		used[v2] = true
	return loop


# --- 2. Orient --------------------------------------------------------------------------------

## v rotated by the quarter turn that takes direction a onto direction b (identity if a == b).
static func transport(v: Vector3i, a: Vector3i, b: Vector3i) -> Vector3i:
	if a == b:
		return v
	var k := Vector3(a).cross(Vector3(b))
	var r := k.cross(Vector3(v)) + k * k.dot(Vector3(v))
	return Vector3i(roundi(r.x), roundi(r.y), roundi(r.z))


static func _unary(s: Settings, mid: Vector3, up: Vector3i) -> float:
	var field_up := -GravityField.pyramid_down(mid)
	return s.w_align * (1.0 - field_up.dot(Vector3(up)))


static func _pair(s: Settings, da: Vector3i, na: Vector3i, db: Vector3i, nb: Vector3i) -> float:
	var moved := transport(na, da, db)
	var d := moved.x * nb.x + moved.y * nb.y + moved.z * nb.z
	var c := 0.0 if d == 1 else (s.w_flip if d == -1 else s.w_twist)
	if d != 1 and da != db:
		c += FORBIDDEN   # a roll inside a corner arc folds the deck: rolls only on straights
	if db == -na:
		c += s.w_crest
	return c


static func _orient(s: Settings, loop: Array[Vector3i]) -> Result:   # null: no valid orientation
	var m := loop.size()
	var dirs: Array[Vector3i] = []
	var opts: Array = []
	var unary: Array = []
	for k in m:
		var d := loop[(k + 1) % m] - loop[k]
		dirs.append(d)
		var o := perps(d)
		opts.append(o)
		var mid := (Vector3(loop[k]) + Vector3(loop[(k + 1) % m])) * 0.5
		unary.append(o.map(func(up: Vector3i) -> float: return _unary(s, mid, up)))

	# Cyclic DP: fix the first straight's up, run around the loop, close back onto it.
	var best_cost := INF
	var best_path: Array[int] = []
	for s0 in 4:
		var cost: Array = [[INF, INF, INF, INF]]
		cost[0][s0] = unary[0][s0]
		var back: Array = [[-1, -1, -1, -1]]
		for k in range(1, m):
			var row := [INF, INF, INF, INF]
			var brow := [-1, -1, -1, -1]
			for j in 4:
				for i in 4:
					var c: float = cost[k - 1][i]
					if c == INF:
						continue
					c += _pair(s, dirs[k - 1], opts[k - 1][i], dirs[k], opts[k][j]) + unary[k][j]
					if c < row[j]:
						row[j] = c
						brow[j] = i
			cost.append(row)
			back.append(brow)
		for j in 4:
			var c: float = cost[m - 1][j]
			if c == INF:
				continue
			c += _pair(s, dirs[m - 1], opts[m - 1][j], dirs[0], opts[0][s0])
			if c < best_cost:
				best_cost = c
				best_path = []
				var cur := j
				for k in range(m - 1, -1, -1):
					best_path.push_front(cur)
					cur = back[k][cur]

	if best_cost >= FORBIDDEN:
		return null   # no orientation without a roll in a corner
	var r := Result.new()
	r.spacing = s.spacing
	r.nodes = loop
	for k in m:
		r.ups.append(opts[k][best_path[k]])
	_score(s, r, dirs, best_cost)
	return r


static func _score(s: Settings, r: Result, dirs: Array[Vector3i], cost: float) -> void:
	var m := r.nodes.size()
	var counts := {"straight": 0, "bend": 0, "quarter_pipe": 0, "crest": 0, "twist": 0, "flip": 0}
	var misalign := 0.0
	var up_hist := {}
	var pyramids := {}
	for k in m:
		var da := dirs[(k - 1 + m) % m]
		var na := r.ups[(k - 1 + m) % m]
		var db := dirs[k]
		var nb := r.ups[k]
		counts[corner_kind(da, na, db)] += 1
		var moved := transport(na, da, db)
		var d := moved.x * nb.x + moved.y * nb.y + moved.z * nb.z
		if d == 0:
			counts.twist += 1
		elif d == -1:
			counts.flip += 1
		var mid := (Vector3(r.nodes[k]) + Vector3(r.nodes[(k + 1) % m])) * 0.5
		var field_up := -GravityField.pyramid_down(mid)
		misalign += rad_to_deg(field_up.angle_to(Vector3(nb)))
		up_hist[nb] = up_hist.get(nb, 0) + 1
		pyramids[GravityField.pyramid_down(Vector3(r.nodes[k]))] = true
	var entropy := 0.0
	for key in up_hist:
		var p: float = float(up_hist[key]) / m
		entropy -= p * log(p)
	var balance := entropy / log(6.0)
	var spread := pyramids.size() / 6.0
	var shortfall := absf(m - s.target_nodes) / float(s.target_nodes)
	r.score = s.w_balance * balance + s.w_spread * spread - cost / m * 5.0 - shortfall * 5.0
	var length := 0.0
	for k in m:
		length += s.spacing   # straights are spacing long; arcs shave a little off
	r.metrics = counts
	r.metrics.merge({"nodes": m, "length_m": length, "lap_s": length / DRIVE_SPEED,
			"balance": balance, "spread": spread, "misalign_deg": misalign / m, "score": r.score})


## How the road turns at a node, entering along da with up na and leaving along db.
static func corner_kind(da: Vector3i, na: Vector3i, db: Vector3i) -> String:
	if da == db:
		return "straight"
	if db == na:
		return "quarter_pipe"
	if db == -na:
		return "crest"
	return "bend"


# --- 3. Sample --------------------------------------------------------------------------------

static func _signed_angle(a: Vector3, b: Vector3, axis: Vector3) -> float:
	return atan2(axis.dot(a.cross(b)), a.dot(b))


static func _sample(s: Settings, r: Result) -> void:
	var m := r.nodes.size()
	var h := s.spacing * 0.5
	r.frames = []
	r.corners = []
	var length := 0.0
	for i in m:
		var da := r.nodes[i] - r.nodes[(i - 1 + m) % m]
		var db := r.nodes[(i + 1) % m] - r.nodes[i]
		var na := Vector3(r.ups[(i - 1 + m) % m])
		var nb := Vector3(r.ups[i])
		var a := Vector3(da)
		var b := Vector3(db)
		var p := Vector3(r.nodes[i]) * s.spacing
		var kind := corner_kind(da, r.ups[(i - 1 + m) % m], db)
		if da == db:
			var twist := _signed_angle(na, nb, b)
			var n := ceili(2.0 * h / SAMPLE_STEP)
			for j in n:
				var t := float(j) / n
				r.frames.append({"pos": p + a * h * (2.0 * t - 1.0), "up": na.rotated(a, twist * t), "tan": a})
			r.corners.append({"kind": kind, "pos": p, "center": p, "up": na, "up_out": nb, "tan": a})
			length += 2.0 * h
		else:
			var k := a.cross(b)
			var c := p - a * h + b * h
			var moved := na.rotated(k, PI * 0.5)
			var twist := _signed_angle(moved, nb, b)
			var n := ceili(PI * 0.5 * h / SAMPLE_STEP)
			for j in n:
				var t := float(j) / n
				var th := t * PI * 0.5
				var tan := (a * cos(th) + b * sin(th)).normalized()
				var up := na.rotated(k, th)
				up = up.rotated(tan, twist * t)
				r.frames.append({"pos": c - b * h * cos(th) + a * h * sin(th), "up": up, "tan": tan})
			r.corners.append({"kind": kind, "pos": p, "center": c, "up": na, "up_out": nb, "tan": (a + b).normalized()})
			length += PI * 0.5 * h
	r.metrics.length_m = length
	r.metrics.lap_s = length / DRIVE_SPEED
