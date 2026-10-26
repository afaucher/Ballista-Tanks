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
const TOWER_H := 16.0


## The wall's cross-section in (z, y): outer quarter-pipe, face, coping, walk, coping, inner face,
## inner quarter-pipe, closed along the ground.
static func wall_profile() -> PackedVector2Array:
	var hw := WALL_W * 0.5
	var p := PackedVector2Array()
	p.append_array(Geo.arc(Vector2(-hw - QP_R, QP_R), QP_R, 270, 360))          # outer quarter-pipe
	p.append_array(Geo.arc(Vector2(-hw + COPE_R, WALL_H - COPE_R), COPE_R, 180, 90, 6))   # outer coping
	p.append_array(Geo.arc(Vector2(hw - COPE_R, WALL_H - COPE_R), COPE_R, 90, 0, 6))      # inner coping
	p.append_array(Geo.arc(Vector2(hw + QP_R, QP_R), QP_R, 180, 270))           # inner quarter-pipe
	return p


## A straight wall `length` long. outer_gaps / inner_gaps: [x0, x1] stretches with no merlons on
## that side, the drop-ins.
static func wall(parent: Node, xf: Transform3D, length: float, outer_gaps := [], inner_gaps := []) -> void:
	var mesh := Geo.extrude(wall_profile(), -length * 0.5, length * 0.5)
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


static func tower(parent: Node, xf: Transform3D, team := -1) -> void:
	Geo.cylinder(parent, TOWER_R, TOWER_H, xf * Transform3D(Basis.IDENTITY, Vector3(0, TOWER_H * 0.5, 0)), Look.stone())
	for k in 14:
		var a := TAU * k / 14.0
		var b := Basis(Vector3.UP, -a)
		Geo.box(parent, MERLON, xf * Transform3D(b, Vector3(cos(a), 0, sin(a)) * (TOWER_R - 0.6) + Vector3.UP * (TOWER_H + MERLON.y * 0.5 - 0.6)), Look.stone())
	if team >= 0:
		_roof(parent, xf * Transform3D(Basis.IDENTITY, Vector3(0, TOWER_H + 3.5, 0)), 5.0, 5.0, team)


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


## A whole castle: four walls with quarter-pipes, corner towers, a gate in the front wall,
## drop-in gaps, and a keep whose ramps lead up to the side walls' walks. The front faces +z if
## facing > 0, else -z; the castle is the same either way, turned half round.
static func castle(parent: Node, center: Vector3, facing: float, team: int, half := 30.0) -> void:
	var turn := Basis(Vector3.UP, 0.0 if facing > 0.0 else PI)
	var at := func(local: Vector3, yaw: float) -> Transform3D:
		return Transform3D(turn * Basis(Vector3.UP, yaw), center + turn * local)
	var seg := half - TOWER_R * 0.5   # walls run into the towers
	# Front wall (outer face toward the enemy): the gate in the middle, a drop-in either side.
	var gate := 5.0
	for side in [-1.0, 1.0]:
		wall(parent, at.call(Vector3(side * (gate + seg) * 0.5, 0, half), PI), seg - gate, [[-4.0, 4.0]], [])
	lintel(parent, at.call(Vector3(0, 0, half), PI), gate * 2.0)
	# Back and side walls; the inner gaps on the side walls are where the keep's banks arrive.
	wall(parent, at.call(Vector3(0, 0, -half), 0.0), seg * 2.0, [[-5.0, 5.0]], [[-12.0, -4.0]])
	wall(parent, at.call(Vector3(-half, 0, 0), PI * 0.5), seg * 2.0, [[-14.0, -4.0]], [[1.0, 11.0]])
	wall(parent, at.call(Vector3(half, 0, 0), -PI * 0.5), seg * 2.0, [[4.0, 14.0]], [[-11.0, -1.0]])
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			tower(parent, at.call(Vector3(sx * half, 0, sz * half), 0.0), team)
	keep(parent, at.call(Vector3(0, 0, -6), 0.0), team, half - WALL_W * 0.5 + COPE_R)


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


## The high bridge along z at walk height, from z0 to z1, on piers, with a ramp up to it from
## the field at each `ramps` entry [z, side] (side -1 or +1: which side of the deck it climbs to).
static func bridge(parent: Node, z0: float, z1: float, piers: Array, ramps: Array) -> void:
	Geo.box(parent, Vector3(10, 1.2, z1 - z0), Transform3D(Basis.IDENTITY, Vector3(0, WALL_H - 0.6, (z0 + z1) * 0.5)), Look.road())
	for z in piers:   # two legs under the deck's edges: the lane out of the gates stays open
		for x in [-4.2, 4.2]:
			Geo.box(parent, Vector3(1.6, WALL_H - 1.2, 3), Transform3D(Basis.IDENTITY, Vector3(x, (WALL_H - 1.2) * 0.5, z)), Look.stone())
	for rz in ramps:
		var side: float = rz[1]
		# Rises along its +z: turned to climb from x = side * 35 in to the deck's edge.
		ramp(parent, Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3(side * 35.0, 0, rz[0])), 10, 30, 0, WALL_H)
