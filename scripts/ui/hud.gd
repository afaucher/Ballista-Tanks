class_name Hud
extends Control
## Gray-box HUD, laid out like the cockpit anchor: score at the top, reticle and the bolt's
## predicted flight in the middle, the bolt state at the bottom right, help at the bottom left.

var game: Node   # game.gd; read-only here
var trail := PackedVector3Array()
var impact := Vector3.ZERO
var impact_hit := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	var player: Tank = game.player if game else null
	if cam == null or player == null:
		return
	var font := ThemeDB.fallback_font
	var vp := get_viewport_rect().size

	# Predicted flight: dots every few samples, then a ring where it lands.
	for i in range(2, trail.size(), 3):
		if not cam.is_position_behind(trail[i]):
			draw_circle(cam.unproject_position(trail[i]), 2.5, Color(1, 0.95, 0.7, 0.85))
	if impact_hit and not cam.is_position_behind(impact):
		var p := cam.unproject_position(impact)
		draw_arc(p, 14, 0, TAU, 32, Color(1, 1, 1, 0.95), 2.5)
		draw_circle(p, 2.5, Color(1, 1, 1))
	var c := vp * 0.5
	draw_line(c - Vector2(8, 0), c + Vector2(8, 0), Color(1, 1, 1, 0.6), 1.5)
	draw_line(c - Vector2(0, 8), c + Vector2(0, 8), Color(1, 1, 1, 0.6), 1.5)

	# Top: hits scored.
	_text(font, Vector2(vp.x * 0.5, 34), "Hits  %d" % game.hits, 26, HORIZONTAL_ALIGNMENT_CENTER)

	# Bottom right: bolt state and gravity mode.
	var state: String
	if player.loaded:
		state = "Bolt ready  [LMB]"
	else:
		state = "Crank [R]  %d%%" % roundi(player.crank * 100.0)
	_text(font, Vector2(vp.x - 24, vp.y - 70), state, 24, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(font, Vector2(vp.x - 24, vp.y - 38), "Bolt gravity: %s  [B]" % Bolt.mode_name(), 18, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(font, Vector2(vp.x - 24, vp.y - 14), "%d km/h%s" % [roundi(player.velocity.length() * 3.6),
			"" if player.grounded else "   airborne"], 16, HORIZONTAL_ALIGNMENT_RIGHT)

	# Top left: arena info. Bottom left: controls.
	var y := 30.0
	for line in game.info_lines():
		_text(font, Vector2(20, y), line, 15, HORIZONTAL_ALIGNMENT_LEFT)
		y += 20.0
	if game.show_help:
		var help := ["WASD drive   Shift drift   Space hop", "Mouse aim   LMB fire   R / wheel crank the string back",
				"B bolt gravity   M next arena   N new road seed   T reset   F1 help   Esc mouse"]
		for i in help.size():
			_text(font, Vector2(20, vp.y - 66 + i * 20), help[i], 15, HORIZONTAL_ALIGNMENT_LEFT)


func _text(font: Font, pos: Vector2, s: String, size: int, align: HorizontalAlignment) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	draw_string_outline(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1))
