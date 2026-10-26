class_name GravityField
extends RefCounted
## Airborne gravity: which way is "down" at a point in the arena. A grounded tank ignores this
## and falls toward the surface under it (docs/design/arena-structure.md, section 2).
##
## By default the cube is split into six pyramids, apex at the centre, base on a face: inside
## one, down is that face. Fixture volumes (pillars) take priority near their surface.

var center := Vector3.ZERO
var uniform := Vector3.ZERO   ## when set (e.g. DOWN for the castle field), gravity everywhere
var pillars: Array[Dictionary] = []   # {a, b: axis end points, reach: influence radius}


func add_pillar(a: Vector3, b: Vector3, reach: float) -> void:
	pillars.append({"a": a, "b": b, "reach": reach})


## Unit vector pointing down at p.
func down_at(p: Vector3) -> Vector3:
	if uniform != Vector3.ZERO:
		return uniform
	for pl in pillars:
		var d := _pillar_down(pl, p)
		if d != Vector3.ZERO:
			return d
	return pyramid_down(p - center)


## Down inside the six-pyramid split, for a point relative to the cube centre.
static func pyramid_down(local: Vector3) -> Vector3:
	var a := local.abs()
	if a.length_squared() < 1e-6:
		return Vector3.DOWN
	if a.x >= a.y and a.x >= a.z:
		return Vector3(signf(local.x), 0, 0)
	if a.y >= a.z:
		return Vector3(0, signf(local.y), 0)
	return Vector3(0, 0, signf(local.z))


# Toward the pillar's axis while within reach of it, away from its end caps; else ZERO.
func _pillar_down(pl: Dictionary, p: Vector3) -> Vector3:
	var a: Vector3 = pl.a
	var ab: Vector3 = pl.b - a
	var t := (p - a).dot(ab) / ab.length_squared()
	if t < 0.05 or t > 0.95:
		return Vector3.ZERO
	var off := p - (a + ab * t)
	var dist := off.length()
	if dist > pl.reach or dist < 0.01:
		return Vector3.ZERO
	return -off / dist
