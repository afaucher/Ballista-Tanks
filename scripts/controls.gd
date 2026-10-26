class_name Controls
## Input actions, registered in code so project.godot stays small.

const KEYS := {
	"throttle": [KEY_W, KEY_UP],
	"brake": [KEY_S, KEY_DOWN],
	"steer_left": [KEY_A, KEY_LEFT],
	"steer_right": [KEY_D, KEY_RIGHT],
	"drift": [KEY_SHIFT],
	"hop": [KEY_SPACE],
	"crank": [KEY_R],
	"toggle_bolt": [KEY_B],
	"switch_arena": [KEY_M],
	"new_seed": [KEY_N],
	"reset": [KEY_T],
	"help": [KEY_F1],
}


static func setup() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", m)
