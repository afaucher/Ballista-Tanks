extends TestCase
## The look kit: every factory returns a material, results are cached, shaders load, and the
## environment and brazier build.


func run() -> void:
	var mats := {"stone": Look.stone(), "road": Look.road(), "wood": Look.wood(), "iron": Look.iron(),
			"gold": Look.gold(), "blue": Look.team(0), "red": Look.team(1), "launch": Look.pad("launch"),
			"boost": Look.pad("boost"), "sun": Look.sun_material()}
	for k in mats:
		check(mats[k] != null, "%s material" % k)
		if mats[k] is ShaderMaterial:
			var sh: Shader = mats[k].shader
			check(sh != null and sh.code.length() > 0, "%s shader has code" % k)
	check(Look.stone() == mats.stone, "stone cached")
	check(Look.road() == mats.road, "road cached")
	check(Look.wood() == mats.wood, "wood cached")
	check(Look.iron() == mats.iron, "iron cached")
	check(Look.gold() == mats.gold, "gold cached")
	check(Look.team(0) == mats.blue and Look.team(1) == mats.red, "team cached")
	check(Look.pad("launch") == mats.launch and Look.pad("boost") == mats.boost, "pads cached")
	check(Look.sun_material() == mats.sun, "sun cached")
	check(mats.blue != mats.red, "teams differ")
	check(mats.launch != mats.boost, "pads differ")
	check(mats.stone != mats.road, "stone and road differ")

	var we := Look.make_environment()
	add_child(we)
	check(we.environment != null, "environment")
	var root := Node3D.new()
	add_child(root)
	Look.make_sun(root, 64.0)
	var lights := root.find_children("*", "OmniLight3D", true, false)
	eq(lights.size(), 1, "one brazier light")
	if lights.size() == 1:
		check(lights[0].omni_range > 64.0 * sqrt(3.0), "light reaches the cube's corners")
		check(lights[0].shadow_enabled, "light casts shadows")

	# Render a couple of frames with every material in use.
	for k in mats:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.material_override = mats[k]
		root.add_child(mi)
	await get_tree().process_frame
	await get_tree().process_frame
