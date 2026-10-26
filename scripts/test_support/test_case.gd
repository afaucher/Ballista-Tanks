class_name TestCase
extends Node
## Base for headless tests in tests/. Override run() (it may await); the runner passes when the
## output has the PASS marker, the exit code is 0 and there is no SCRIPT ERROR.
##
##   .\test_runner.ps1 -TestName test_gravity_field
##   .\test_runner.ps1 -TestAll

var test_name := ""
var timeout_s := 120.0
var _failures := 0
var _done := false


func run() -> void:
	pass


func _ready() -> void:
	get_tree().create_timer(timeout_s).timeout.connect(func() -> void:
		if not _done:
			_fail("timed out after %.0f s" % timeout_s)
			finish())
	await run()
	finish()


func check(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)


func eq(a: Variant, b: Variant, msg: String) -> void:
	if a != b:
		_fail("%s: got %s, expected %s" % [msg, a, b])


func near(a: Variant, b: Variant, tol: float, msg: String) -> void:
	var d: float
	if a is Vector3 or a is Vector2:
		d = (a - b).length()
	else:
		d = absf(float(a) - float(b))
	if d > tol:
		_fail("%s: got %s, expected %s (+/- %s)" % [msg, a, b, tol])


## Wait n physics frames.
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func finish() -> void:
	if _done:
		return
	_done = true
	if _failures == 0:
		print(">>> [TEST PASSED] %s <<<" % test_name)
		get_tree().quit(0)
	else:
		print(">>> [TEST FAILED] %s: %d failure(s) <<<" % [test_name, _failures])
		get_tree().quit(1)


func _fail(msg: String) -> void:
	_failures += 1
	print("ASSERT FAILED: " + msg)
