extends TestCase
## The airborne gravity field: six pyramids, and pillar volumes on top of them.


func run() -> void:
	eq(GravityField.pyramid_down(Vector3(0, -40, 5)), Vector3.DOWN, "floor pyramid")
	eq(GravityField.pyramid_down(Vector3(3, 50, -10)), Vector3.UP, "ceiling pyramid")
	eq(GravityField.pyramid_down(Vector3(60, 20, -30)), Vector3.RIGHT, "+X wall pyramid")
	eq(GravityField.pyramid_down(Vector3(10, -20, -45)), Vector3.FORWARD, "-Z wall pyramid")
	eq(GravityField.pyramid_down(Vector3.ZERO), Vector3.DOWN, "centre defaults to the floor")
	# Crossing a pyramid boundary flips which way you fall.
	eq(GravityField.pyramid_down(Vector3(30, -29, 0)), Vector3.RIGHT, "just past the floor/wall diagonal")
	eq(GravityField.pyramid_down(Vector3(29, -30, 0)), Vector3.DOWN, "just inside the floor's pyramid")

	var f := GravityField.new()
	f.add_pillar(Vector3(30, -50, 30), Vector3(30, 50, 30), 10.0)
	near(f.down_at(Vector3(36, 0, 30)), Vector3.LEFT, 0.001, "near a pillar: toward its axis")
	eq(f.down_at(Vector3(50, 0, 30)), Vector3.RIGHT, "out of the pillar's reach: the pyramid again")
	eq(f.down_at(Vector3(36, -49.5, 30)), Vector3.DOWN, "at the pillar's foot the floor wins")
