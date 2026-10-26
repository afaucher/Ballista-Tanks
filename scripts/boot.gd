extends Node
## Main scene. `-- --run-test <name>` runs tests/<name>.gd (a TestCase) instead of the game.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--run-test")
	if i >= 0 and i + 1 < args.size():
		var test_name := args[i + 1]
		var script: GDScript = load("res://tests/%s.gd" % test_name)
		if script == null:
			print("SCRIPT ERROR: no test named ", test_name)
			get_tree().quit(2)
			return
		var t: TestCase = script.new()
		t.test_name = test_name
		add_child(t)
		return
	add_child(load("res://scripts/game.gd").new())
