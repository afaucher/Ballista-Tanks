class_name CastleKit
## The castle skatepark kit (docs/design/castle-skatepark.md), gray-box. Every piece is a static
## body with exact collision, built in its own frame and placed by a transform.
##
## A wall's frame: x along the wall, y up, its OUTER face toward -z. Both faces rise from the
## ground through a quarter-pipe into the vertical, and both top edges are rounded copings, so a
## fast tank can ride up either face onto the walk, and drop back down through a gap in the
## battlements.

const WALL_H := 10.0
const WALL_W := 14.0      # wall thickness: a ~10 m lane between the battlements
const QP_R := 6.0         # quarter-pipe radius at the foot of every face
const COPE_R := 1.5       # rounded coping on the top edges
const MERLON := Vector3(2.0, 2.0, 0.9)   # sunk 0.6 into the walk so it sits on the coping too
const MERLON_STEP := 3.6
const TOWER_R := 8.0
const TOWER_H := 20.0     # castle tower tops, where the spirals arrive
# Moat bowls: where a wall has a moat, its outer quarter-pipe carries on down into it as one
# bigger curve (radius QP_R + MOAT_D, vertical at the same 6 m), so the moat's inner bank IS the
# wall. Then a flat floor, and an outer bank (concave, then a convex lip) back up to the field.
const MOAT_D := 4.0
const MOAT_FLOOR := 2.0
const MOAT_OUT := Vector2(6.0, 3.0)   # outer bank radii: concave, convex
const END_R := 4.0        # a moat's ends: quarter-pipes from the floor to a vertical lip at the field
const SPIRAL_W := 8.0
const SPIRAL_R := 16.0    # the spiral's centre line round a corner tower; it tightens near the top
const KICK_R := 16.0      # kickers: a curve this radius up to a lip at KICK_DEG
const KICK_DEG := 50.0
const ROAD_T := 1.2       # deck thickness of the roads over the arches


## How far a moat reaches out from its wall's centre line (its outer lip).
static func moat_reach() -> float:
	var r := MOAT_OUT.x + MOAT_OUT.y
	return WALL_W * 0.5 + QP_R + MOAT_D + MOAT_FLOOR + r * sin(acos(1.0 - MOAT_D / r))


## The wall's cross-section in (z, y): outer quarter-pipe, face, coping, walk, coping, inner face,
## inner quarter-pipe, closed along the ground. With a moat, the outer quarter-pipe reaches down
## to its floor.
static func wall_profile(moat := 0.0) -> PackedVector2Array:
	var hw := WALL_W * 0.5
	var ro := QP_R + moat
	var p := PackedVector2Array()
	p.append_array(Geo.arc(Vector2(-hw - ro, QP_R), ro, 270, 360, 10 if moat == 0.0 else 16))   # outer quarter-pipe
	p.append_array(Geo.arc(Vector2(-hw + COPE_R, WALL_H - COPE_R), COPE_R, 180, 90, 6))   # outer coping
	p.append_array(Geo.arc(Vector2(hw - COPE_R, WALL_H - COPE_R), COPE_R, 90, 0, 6))      # inner coping
	p.append_array(Geo.arc(Vector2(hw + QP_R, QP_R), QP_R, 180, 270))           # inner quarter-pipe
	return p


## A straight wall `length` long. outer_gaps / inner_gaps: [x0, x1] stretches with no merlons on
## that side, the drop-ins.
static func wall(parent: Node, xf: Transform3D, length: float, outer_gaps := [], inner_gaps := [], moat := 0.0) -> void:
	var mesh := Geo.extrude(wall_profile(moat), -length * 0.5, length * 0.5)
	Geo.solid(parent, mesh, xf, Look.stone())
	var hw := WALL_W * 0.5
	for side in [-1.0, 1.0]:
		var gaps: Array = outer_gaps if side < 0.0 else inner_gaps
		var z: float = side * (hw - COPE_R - 0.2)
		var x := -length * 0.5 + MERLON.x
		while x <= length * 0.5 - MERLON.x * 0.5:
			if not gaps.any(func(g: Array) -> bool: return x > g[0] - MERLON.x * 0.5 and x < g[1] + MERLON.x * 0.5):
				Geo.box(parent, MERLON, xf * Transform3D(Basis.IDENTITY, Vector3(x, WALL_H + MERLON.y * 0.5 - 0.6, z)), Look.stone())
			x += MERLON_STEP


## The lintel that carries the wall walk over a gate: the gap below is the gate tunnel.
static func lintel(parent: Node, xf: Transform3D, gap: float) -> void:
	Geo.box(parent, Vector3(gap + 0.2, 2.0, WALL_W), xf * Transform3D(Basis.IDENTITY, Vector3(0, WALL_H - 1.0, 0)), Look.stone())


## The moat bowl outside a wall, in the wall's frame (outer side toward -z), from x0 to x1: the
## floor at the foot of the wall's bank and the outer bank up to the field, with a quarter-pipe
## end at each end.
static func moat(parent: Node, xf: Transform3D, x0: float, x1: float) -> void:
	var d0 := WALL_W * 0.5 + QP_R + MOAT_D   # where the wall's bank meets the floor
	var d1 := d0 + MOAT_FLOOR
	var lip := moat_reach()
	var beta := acos(1.0 - MOAT_D / (MOAT_OUT.x + MOAT_OUT.y))
	var p := PackedVector2Array([Vector2(-d0, -MOAT_D)])
	for k in 9:   # concave, up from the floor
		var t := beta * k / 8.0
		p.append(Vector2(-d1 - MOAT_OUT.x * sin(t), -MOAT_D + MOAT_OUT.x * (1.0 - cos(t))))
	for k in range(1, 9):   # convex, over the lip
		var u := beta * (1.0 - k / 8.0)
		p.append(Vector2(-lip + MOAT_OUT.y * sin(u), -MOAT_OUT.y * (1.0 - cos(u))))
	p.append_array([Vector2(-lip, -MOAT_D - 2.0), Vector2(-d0, -MOAT_D - 2.0)])
	Geo.solid(parent, Geo.extrude(p, x0, x1), xf, Look.road())
	_moat_end(parent, xf, x0, 1.0)
	_moat_end(parent, xf, x1, -1.0)


# A quarter-pipe across the moat, its lip at x, the bowl on the `into` side (+1 or -1) of it.
static func _moat_end(parent: Node, xf: Transform3D, x: float, into: float) -> void:
	var c := Vector2(x + into * END_R, 0)
	var p := Geo.arc(c, END_R, 180.0 if into > 0.0 else 270.0, 270.0 if into > 0.0 else 360.0, 8)
	var bottom := -MOAT_D - 2.0
	if into > 0.0:
		p.append_array([Vector2(x + END_R, bottom), Vector2(x, bottom)])
	else:
		p.append_array([Vector2(x, bottom), Vector2(x - END_R, bottom)])
	# Profile in (wall x, y), extruded along the wall's -z (a quarter turn) across the moat.
	var turn := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	Geo.solid(parent, Geo.extrude(p, WALL_W * 0.5, moat_reach()), xf * turn, Look.road())


## A round tower `h` high. Merlons within 5 m of any point in `open` are left out (where a
## spiral arrives); a team tower gets a turret with a roof in its colour.
static func tower(parent: Node, xf: Transform3D, team := -1, h := TOWER_H, open: Array = []) -> void:
	Geo.cylinder(parent, TOWER_R, h, xf * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, 0)), Look.stone())
	for k in 14:
		var a := TAU * k / 14.0
		var t := xf * Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * (TOWER_R - 0.6) + Vector3.UP * (h + MERLON.y * 0.5 - 0.6))
		if open.any(func(q: Vector3) -> bool: return Vector2(q.x - t.origin.x, q.z - t.origin.z).length() < 5.0):
			continue
		Geo.box(parent, MERLON, t, Look.stone())
	if team >= 0:
		Geo.cylinder(parent, 2.5, 3.0, xf * Transform3D(Basis.IDENTITY, Vector3(0, h + 1.5, 0)), Look.stone())
		_roof(parent, xf * Transform3D(Basis.IDENTITY, Vector3(0, h + 5.0, 0)), 3.5, 4.0, team)


## The keep: a block with a ramp up its front, banks from its top up to the side walls' walks,
## and a turret on top in the team colour.
static func keep(parent: Node, xf: Transform3D, team: int, bank_to: float) -> void:
	Geo.box(parent, Vector3(20, 6, 20), xf * Transform3D(Basis.IDENTITY, Vector3(0, 3, 0)), Look.stone())
	ramp(parent, xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 24)), 8, 14, 0, 6)
	for sx in [-1.0, 1.0]:
		# Ends at bank_to (from the keep's centre), over the inner coping, flush with the walk.
		ramp(parent, xf * Transform3D(Basis(Vector3.UP, sx * PI * 0.5), Vector3(sx * 10.0, 0, 0)), 8, bank_to - 10.0, 6, WALL_H)
	Geo.cylinder(parent, 3.5, 6, xf * Transform3D(Basis.IDENTITY, Vector3(0, 9, 0)), Look.stone())
	_roof(parent, xf * Transform3D(Basis.IDENTITY, Vector3(0, 14, 0)), 4.5, 4.0, team)


static func _roof(parent: Node, xf: Transform3D, radius: float, height: float, team: int) -> void:
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	roof.mesh = cone
	roof.material_override = Look.team(team)
	parent.add_child(roof)
	roof.global_transform = xf


## A solid ramp block, `width` wide, rising from h0 to h1 over `length` along its local +z.
static func ramp(parent: Node, xf: Transform3D, width: float, length: float, h0: float, h1: float) -> void:
	var p := PackedVector2Array([Vector2(0, 0)])
	if h0 > 0.0:
		p.append(Vector2(0, h0))
	p.append_array([Vector2(length, h1), Vector2(length, 0)])
	Geo.solid(parent, Geo.extrude(p, -width * 0.5, width * 0.5, 5.0), xf, Look.road())


## A whole castle: four walls with quarter-pipes, a moat bowl outside each (the gate's causeway
## splits the front one; the corners stay ground, for the spirals), corner towers with spiral
## ramps, a gate in the front wall, drop-in gaps, a bastion kicker on the right, and a keep whose
## ramps lead up to the side walls' walks. The front faces +z if facing > 0, else -z; the castle
## is the same either way, turned half round. Returns {holes: the moats' footprints as world
## Rect2s in (x, z), for the field to leave open; spirals: each spiral's world frames}.
static func castle(parent: Node, center: Vector3, facing: float, team: int, half := 30.0) -> Dictionary:
	var turn := Basis(Vector3.UP, 0.0 if facing > 0.0 else PI)
	var at := func(local: Vector3, yaw: float) -> Transform3D:
		return Transform3D(turn * Basis(Vector3.UP, yaw), center + turn * local)
	var seg := half - TOWER_R * 0.5   # walls run into the towers
	var gate := 5.0
	# Where the spirals cross the walls at walk level, 10-20 m out from the middle of each side,
	# the battlements open on both sides. In each wall's own x.
	var cross := [[-20.0, -10.0], [10.0, 20.0]]
	# Front wall (outer face toward the enemy): the gate in the middle.
	for side in [-1.0, 1.0]:
		wall(parent, at.call(Vector3(side * (gate + seg) * 0.5, 0, half), PI), seg - gate, [[-4.5, 5.5]], [[-4.5, 5.5]], MOAT_D)
	lintel(parent, at.call(Vector3(0, 0, half), PI), gate * 2.0)
	# Back and side walls; the inner gaps on the side walls are where the keep's banks arrive, the
	# outer ones on the sides are drop-ins.
	wall(parent, at.call(Vector3(0, 0, -half), 0.0), seg * 2.0, [[-5.0, 5.0]] + cross, [[-12.0, -4.0]] + cross, MOAT_D)
	wall(parent, at.call(Vector3(-half, 0, 0), PI * 0.5), seg * 2.0, [[-14.0, -4.0]] + cross, [[1.0, 11.0]] + cross, MOAT_D)
	wall(parent, at.call(Vector3(half, 0, 0), -PI * 0.5), seg * 2.0, [[4.0, 14.0]] + cross, [[-11.0, -1.0]] + cross, MOAT_D)
	# The moats, in the walls' frames; the causeway to the gate is plain ground.
	var reach := moat_reach()
	moat(parent, at.call(Vector3(0, 0, half), PI), -seg, -gate)
	moat(parent, at.call(Vector3(0, 0, half), PI), gate, seg)
	moat(parent, at.call(Vector3(0, 0, -half), 0.0), -seg, seg)
	moat(parent, at.call(Vector3(-half, 0, 0), PI * 0.5), -seg, seg)
	moat(parent, at.call(Vector3(half, 0, 0), -PI * 0.5), -seg, seg)
	var holes := []
	var inner := half + WALL_W * 0.5
	var outer := half + reach
	for r in [[gate, seg, inner, outer], [-seg, -gate, inner, outer], [-seg, seg, -outer, -inner],
			[-outer, -inner, -seg, seg], [inner, outer, -seg, seg]]:   # [x0, x1, z0, z1]
		var p: Vector3 = center + turn * Vector3(r[0], 0, r[2])
		var q: Vector3 = center + turn * Vector3(r[1], 0, r[3])
		holes.append(Rect2(minf(p.x, q.x), minf(p.z, q.z), absf(q.x - p.x), absf(q.z - p.z)))
	# Corner towers, each with a spiral ramp round it.
	var spirals := []
	var xf := Transform3D(turn, center)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var frames := spiral(parent, xf, Vector3(sx * half, 0, sz * half), sx, sz)
			spirals.append(frames)
			var arrival := frames.filter(func(f: Dictionary) -> bool: return f.s >= 380.0).map(func(f: Dictionary) -> Vector3: return f.pos)
			tower(parent, at.call(Vector3(sx * half, 0, sz * half), 0.0), team, TOWER_H, arrival)
	# A bastion in the right moat: a kicker that airs you across it onto the wall walk, through the
	# drop-in gap.
	kicker(parent, at.call(Vector3(half + 20.0 + KICK_R * sin(deg_to_rad(KICK_DEG)), 0, 6), -PI * 0.5), 6.0, -MOAT_D)
	keep(parent, at.call(Vector3(0, 0, -6), 0.0), team, half - WALL_W * 0.5 + COPE_R)
	return {"holes": holes, "spirals": spirals}


## A kicker `width` wide rising along its local +z: a curve up to a lip at KICK_DEG. base < 0
## sinks its block that far (a bastion standing in a moat).
static func kicker(parent: Node, xf: Transform3D, width: float, base := 0.0) -> void:
	var th := deg_to_rad(KICK_DEG)
	var p := PackedVector2Array()
	for k in 13:
		var t := th * k / 12.0
		p.append(Vector2(KICK_R * sin(t), KICK_R * (1.0 - cos(t))))
	p.append(Vector2(KICK_R * sin(th), base))
	if base < 0.0:
		p.append(Vector2(0, base))
	Geo.solid(parent, Geo.extrude(p, -width * 0.5, width * 0.5), xf, Look.road())


## The spiral ramp round the corner tower at c (castle frame; sx, sz say which corner), placed by
## xf. It starts on the corner's ground, outside the moats, climbs to walk height as it crosses
## over the moat, runs level across both walls' walks (and over the courtyard corner between
## them), then climbs again outside, tightening onto the tower, and arrives level with its top.
## It rests on beams from the tower. Returns its world frames.
static func spiral(parent: Node, xf: Transform3D, c: Vector3, sx: float, sz: float) -> Array:
	var frames := []
	var step := 3.0
	var n := int(410.0 / step)
	for i in n + 1:
		var s := i * step   # degrees round from the start, the outer diagonal
		var a := deg_to_rad(45.0 + s)
		var r := lerpf(SPIRAL_R, TOWER_R + SPIRAL_W * 0.5 - 0.2, smoothstep(266.0, 380.0, s))
		var h := WALL_H * smoothstep(0.0, 99.0, s) + (TOWER_H - WALL_H) * smoothstep(266.0, 380.0, s)
		frames.append({"pos": xf * (c + Vector3(sx * cos(a) * r, h, sz * sin(a) * r)), "s": s})
	for i in frames.size():
		var p0: Vector3 = frames[maxi(i - 1, 0)].pos
		var p1: Vector3 = frames[mini(i + 1, frames.size() - 1)].pos
		var tan := (p1 - p0).normalized()
		var up := tan.cross(Vector3.UP).cross(tan).normalized()
		frames[i].tan = tan
		frames[i].up = up if up.y > 0.0 else -up
	# Railed while it climbs; open where it crosses the walks and where it meets the tower top.
	var cut := [0]
	for edge in [99.0, 266.0, 380.0]:
		cut.append(int(edge / step))
	cut.append(frames.size() - 1)
	for k in 4:
		var part := frames.slice(cut[k], cut[k + 1] + 1)
		var mesh := Geo.road(part, SPIRAL_W, 0.8, 1.2, 2.0, false) if k % 2 == 0 else Geo.deck(part, SPIRAL_W, 0.8)
		Geo.solid(parent, mesh, Transform3D.IDENTITY, Look.road())
	var tower_c := xf * c
	for i in range(0, frames.size(), 6):
		var pos: Vector3 = frames[i].pos
		if pos.y < 3.0:
			continue
		var out := Vector3(pos.x - tower_c.x, 0, pos.z - tower_c.z)
		var r0 := TOWER_R - 0.5
		var r1 := out.length() + SPIRAL_W * 0.5
		var dir := out.normalized()
		var mid := tower_c + dir * (r0 + r1) * 0.5 + Vector3.UP * (pos.y - 0.8 - 0.5)
		Geo.box(parent, Vector3(1.0, 1.0, r1 - r0), Transform3D(Basis.looking_at(dir), mid), Look.stone())
	return frames


## A giant arch, rideable all round: legs that rise from quarter-pipes, an outer back you can drive
## over and an inner curve that is a loop-the-loop. Span about 2a, height b, ring thickness t,
## `depth` deep; the span runs along the local x.
static func arch(parent: Node, xf: Transform3D, a: float, b: float, t: float, depth: float) -> void:
	var ai := a - t
	var bi := b - t
	var r := QP_R
	var th0 := asin(r / b)    # where the ellipses meet the tops of the foot quarter-pipes
	var th1 := asin(r / bi)
	var xo := a * cos(th0)
	var xi := ai * cos(th1)
	var p := PackedVector2Array()
	p.append_array(Geo.arc(Vector2(-xo - r, r), r, 270, 360, 8))   # outer left foot
	for k in range(1, 48):
		var th: float = lerpf(PI - th0, th0, k / 48.0)
		p.append(Vector2(a * cos(th), b * sin(th)))                # over the back
	p.append_array(Geo.arc(Vector2(xo + r, r), r, 180, 270, 8))    # outer right foot
	p.append_array(Geo.arc(Vector2(xi - r, r), r, 270, 360, 8))    # inner right foot
	for k in range(1, 48):
		var th: float = lerpf(th1, PI - th1, k / 48.0)
		p.append(Vector2(ai * cos(th), bi * sin(th)))              # the loop
	p.append_array(Geo.arc(Vector2(-xi + r, r), r, 180, 270, 8))   # inner left foot
	# extrude() takes (z, y) and runs along x; a quarter turn puts the span along x.
	var mesh := Geo.extrude(p, -depth * 0.5, depth * 0.5)
	Geo.solid(parent, mesh, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), Look.stone())


## The road over an arch (same a, b and frame as arch()), 10 m wide: it rides the arch's back over
## the crown and, where the back gets steeper than `slope_deg`, runs straight down to the ground
## on both sides, on piers at the distances `piers` from the middle. Returns its world frames.
static func arch_road(parent: Node, xf: Transform3D, a: float, b: float, slope_deg: float, piers: Array) -> Array:
	var tn := tan(deg_to_rad(slope_deg))
	var k := tn * a * a / b
	var xt := k / sqrt(1.0 + k * k / (a * a))   # where the back's slope reaches slope_deg
	var yt := b * sqrt(1.0 - xt * xt / (a * a)) + ROAD_T
	var xg := xt + yt / tn                      # where the road meets the ground
	var height := func(x: float) -> Vector2:    # (road surface y, dy/dx)
		if absf(x) <= xt:
			var q := sqrt(1.0 - x * x / (a * a))
			return Vector2(b * q + ROAD_T, -b * x / (a * a * q))
		return Vector2(yt - (absf(x) - xt) * tn, -signf(x) * tn)
	var frames := []
	var n := ceili(xg)
	for i in n + 1:
		var x := lerpf(-xg, xg, float(i) / n)
		var hy: Vector2 = height.call(x)
		frames.append({"pos": xf * Vector3(x, hy.x, 0), "tan": xf.basis * Vector3(1, hy.y, 0).normalized(),
				"up": xf.basis * Vector3(-hy.y, 1, 0).normalized()})
	Geo.solid(parent, Geo.road(frames, 10.0, ROAD_T, 1.2, 3.0, false), Transform3D.IDENTITY, Look.road())
	for d in piers:
		for x in [-d, d]:
			var top: float = height.call(x).x - ROAD_T
			var base := _arch_back(a, b, absf(x)) - 1.0
			if top - base < 3.5:
				continue
			Geo.box(parent, Vector3(2.0, top - base, 7.0), xf * Transform3D(Basis.IDENTITY, Vector3(x, (top + base) * 0.5, 0)), Look.stone())
	return frames


# The height of an arch()'s outer surface (or the ground beyond it) at x from its middle.
static func _arch_back(a: float, b: float, x: float) -> float:
	var r := QP_R
	var xo := a * cos(asin(r / b))
	if x <= xo:
		return b * sqrt(1.0 - x * x / (a * a))
	if x <= xo + r:
		return r - sqrt(r * r - pow(xo + r - x, 2.0))
	return 0.0


## A drum tower you ride inside: a wall of death. A round bowl (quarter-pipe floor, vertical wall,
## coping on the rim) of inner radius ri, outer ro, h high, with a door `door_w` wide and 7 m
## high at angle `door` (radians in xf's frame, a point at angle a is (cos a, 0, sin a)).
static func drum(parent: Node, xf: Transform3D, ri: float, ro: float, h: float, door: float, door_w := 8.0) -> void:
	var half := asin(door_w * 0.5 / ri)
	var p := Geo.arc(Vector2(ri - QP_R, QP_R), QP_R, 270, 360, 10)
	p.append_array(Geo.arc(Vector2(ri + COPE_R, h - COPE_R), COPE_R, 180, 90, 6))
	p.append_array([Vector2(ro, h), Vector2(ro, -1.0), Vector2(ri - QP_R, -1.0)])
	Geo.solid(parent, Geo.lathe(p, door + half, door - half + TAU, 64), xf, Look.stone())
	var lintel := PackedVector2Array([Vector2(ri, 7.0)])
	lintel.append_array(Geo.arc(Vector2(ri + COPE_R, h - COPE_R), COPE_R, 180, 90, 6))
	lintel.append_array([Vector2(ro, h), Vector2(ro, 7.0)])
	Geo.solid(parent, Geo.lathe(lintel, door - half, door + half, 6), xf, Look.stone())
	# The floor, a hair above the field's slab where they overlap.
	Geo.cylinder(parent, ri, 1.0, xf * Transform3D(Basis.IDENTITY, Vector3(0, -0.48, 0)), Look.road())


## The high bridge along z at walk height, from z0 to z1, on piers, with a ramp up to it from
## the field at each `ramps` entry [z, side] (side -1 or +1: which side of the deck it climbs to),
## ramp_w wide.
static func bridge(parent: Node, z0: float, z1: float, piers: Array, ramps: Array, ramp_w := 10.0) -> void:
	Geo.box(parent, Vector3(10, 1.2, z1 - z0), Transform3D(Basis.IDENTITY, Vector3(0, WALL_H - 0.6, (z0 + z1) * 0.5)), Look.road())
	for z in piers:   # two legs under the deck's edges: the lane out of the gates stays open
		for x in [-4.2, 4.2]:
			Geo.box(parent, Vector3(1.6, WALL_H - 1.2, 3), Transform3D(Basis.IDENTITY, Vector3(x, (WALL_H - 1.2) * 0.5, z)), Look.stone())
	for rz in ramps:
		var side: float = rz[1]
		# Rises along its +z: turned to climb from x = side * 35 in to the deck's edge.
		ramp(parent, Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3(side * 35.0, 0, rz[0])), ramp_w, 30, 0, WALL_H)
