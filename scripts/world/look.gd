class_name Look
extends RefCounted
## The gray-box look kit: materials, environment and the central light (docs/design/art-direction.md).
##
## The arena is a castle interior inside a cube, with gravity on every face, so surface materials
## are triplanar in world space (block sizes in metres) and read the same on floor, wall and
## ceiling. The only light hangs at the cube's centre: a giant armillary brazier, warm gold.
## Factories are cached: every call returns the same instance.

static var _cache := {}

const MASONRY := preload("res://shaders/masonry.gdshader")
const PAD := preload("res://shaders/pad.gdshader")
const SUN := preload("res://shaders/sun.gdshader")

const WARM_LIGHT := Color(1.0, 0.93, 0.82)


static func _cached(key: String, make: Callable) -> Material:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


## Big grey blocks (2 x 1 m courses, staggered) with darker mortar: walls, towers, the shell.
static func stone() -> Material:
	return _cached("stone", func() -> Material:
		return _masonry({"base_color": Color(0.55, 0.56, 0.59), "mortar_color": Color(0.28, 0.27, 0.27),
				"block_size": Vector2(3.0, 1.5), "mortar_width": 0.12, "bevel": 0.35, "bump": 0.1,
				"variation": 0.2, "warmth": 0.4}))


## Flagstone cobbles for drivable decks, a little warmer than the walls.
static func road() -> Material:
	return _cached("road", func() -> Material:
		return _masonry({"base_color": Color(0.62, 0.58, 0.53), "mortar_color": Color(0.33, 0.28, 0.23),
				"block_size": Vector2(1.5, 1.0), "mortar_width": 0.1, "bevel": 0.4, "bump": 0.09,
				"variation": 0.16, "warmth": 0.8, "dome": 1.0, "roughness": 0.8}))


static func wood() -> Material:
	return _cached("wood", func() -> Material:
		return _plain(Color(0.6, 0.34, 0.15), 0.0, 0.72))


# Metals stay mostly non-metallic: the only thing to reflect is a flat background colour, and
# fully metallic surfaces would turn black or brown.
static func iron() -> Material:
	return _cached("iron", func() -> Material:
		return _plain(Color(0.5, 0.52, 0.57), 0.3, 0.4))


static func gold() -> Material:
	return _cached("gold", func() -> Material:
		return _plain(Color(1.0, 0.77, 0.24), 0.3, 0.32))


## Team paint: 0 blue, 1 red. Saturated and a little glossy.
static func team(t: int) -> Material:
	return _cached("team%d" % t, func() -> Material:
		return _plain(Color(0.1, 0.36, 0.95) if t == 0 else Color(0.9, 0.15, 0.13), 0.0, 0.4))


## Glowing pads with chevrons that run along the pad's local -Z: "launch" (amber gold) or "boost".
static func pad(kind: String) -> Material:
	return _cached("pad_" + kind, func() -> Material:
		var m := ShaderMaterial.new()
		m.shader = PAD
		if kind == "boost":
			m.set_shader_parameter("color", Color(0.45, 0.8, 1.0))
			m.set_shader_parameter("speed", 2.0)
		else:
			m.set_shader_parameter("color", Color(1.0, 0.66, 0.12))
		return m)


## The brazier's fire and candle flames: unshaded and bright enough to bloom.
static func sun_material() -> Material:
	return _cached("sun", func() -> Material:
		var m := ShaderMaterial.new()
		m.shader = SUN
		return m)


## Warm interior: a dim stone background (never really seen), soft warm ambient so faces turned
## away from the brazier stay readable, ACES, a little glow for the fire and pads, light haze for depth.
## A soft studio sky that glossy and metal surfaces reflect (bright above, darker below), so
## paint and iron shine as in the concept. Used for reflections only: the cube has no sky.
static func studio_sky() -> Sky:
	var m := ProceduralSkyMaterial.new()
	m.sky_top_color = Color(0.98, 0.97, 0.95)
	m.sky_horizon_color = Color(0.78, 0.78, 0.8)
	m.ground_horizon_color = Color(0.5, 0.5, 0.52)
	m.ground_bottom_color = Color(0.22, 0.22, 0.24)
	m.sun_angle_max = 0.0
	# Dim: at grazing angles every surface reflects almost fully, and a bright sky turns thin
	# bevel strips on silhouettes into single white pixels.
	m.energy_multiplier = 0.55
	var sky := Sky.new()
	sky.sky_material = m
	return sky


static func make_environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.26, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.84, 0.86, 0.92)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.38, 0.38, 0.4)
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.sky = studio_sky()
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY   # reflections only; never shown
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	return we


## Outdoors (the castle field): a sky, a low warm sun with shadows, sky ambient, distance haze.
static func make_outdoor(parent: Node3D) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.55, 0.82)
	sky_mat.sky_horizon_color = Color(0.78, 0.84, 0.9)
	sky_mat.ground_horizon_color = Color(0.72, 0.78, 0.86)   # the haze the far meadow fades into
	sky_mat.ground_bottom_color = Color(0.72, 0.78, 0.86)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# A neutral-warm fill, not the sky's blue: stone in shade should read as stone, not ice.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.84, 0.8)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.78, 0.86)
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	parent.add_child(we)
	var meadow := MeshInstance3D.new()   # beyond the arena walls, out to the haze; never driven on
	var plane := PlaneMesh.new()
	plane.size = Vector2(2400, 2400)
	meadow.mesh = plane
	meadow.material_override = _plain(Color(0.42, 0.52, 0.3), 0.0, 0.95)
	meadow.position.y = -0.05
	parent.add_child(meadow)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = WARM_LIGHT
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(35.0), 0.0)
	parent.add_child(sun)


## The central light: an armillary brazier hung at the origin on eight chains, one to each corner,
## plus the warm OmniLight that lights the whole cube. `half` is the cube's half-size.
static func make_sun(parent: Node3D, half: float) -> void:
	var root := Node3D.new()
	root.name = "Brazier"
	parent.add_child(root)
	var s := clampf(half / 64.0, 0.25, 2.0)   # sized for the 64 m cube, scaled for labs

	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 3.0 * s
	sphere.height = 6.0 * s
	core.mesh = sphere
	core.material_override = sun_material()
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)

	# Three gold-and-iron rings, one per axis: no face is "up" for the brazier either.
	var ring_basis: Array[Basis] = [Basis.IDENTITY, Basis(Vector3.RIGHT, PI * 0.5), Basis(Vector3.BACK, PI * 0.5)]
	var radii: Array[float] = [8.0, 7.0, 6.0]
	for i in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = (radii[i] - 0.5) * s
		torus.outer_radius = radii[i] * s
		torus.rings = 48
		ring.mesh = torus
		ring.material_override = gold() if i == 0 else iron()
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.basis = ring_basis[i]
		root.add_child(ring)
		# Candle flames around each ring.
		for k in 8:
			var a := TAU * (k + 0.5 * i) / 8.0
			var flame := MeshInstance3D.new()
			var f := SphereMesh.new()
			f.radius = 0.45 * s
			f.height = 1.2 * s
			flame.mesh = f
			flame.material_override = sun_material()
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flame.position = ring_basis[i] * (Vector3(cos(a), 0, sin(a)) * (radii[i] - 0.18) * s)
			root.add_child(flame)

	# Chains out to the eight corners: out of the sightlines down the middle of every face.
	for corner in [Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, 1), Vector3(1, -1, -1),
			Vector3(-1, 1, 1), Vector3(-1, 1, -1), Vector3(-1, -1, 1), Vector3(-1, -1, -1)]:
		var dir: Vector3 = corner.normalized()
		var chain := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var start: float = radii[0] * s
		var length: float = half * 1.55 - start   # the rounded corner is ~1.6 half-sizes out
		cyl.top_radius = 0.12 * s
		cyl.bottom_radius = 0.12 * s
		cyl.height = length
		cyl.radial_segments = 6
		chain.mesh = cyl
		chain.material_override = iron()
		chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chain.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), dir * (start + length * 0.5))
		root.add_child(chain)

	var light := OmniLight3D.new()
	light.name = "BrazierLight"
	light.light_color = WARM_LIGHT
	light.light_energy = 3.0
	light.omni_range = half * 2.6
	light.omni_attenuation = 0.35
	light.shadow_enabled = true
	light.shadow_bias = 0.2
	light.shadow_normal_bias = 1.5
	root.add_child(light)


static func _masonry(params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MASONRY
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func _plain(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m
