class_name Hud
extends Control
## Crosshair, interaction prompt, objectives, notifications, help, win panel.

var game: Game
var _font: Font
var _toasts: Array = [] # {text, time}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	game.notified.connect(func(t): _toasts.append({"text": t, "time": 3.0}))


func _process(delta: float) -> void:
	for t in _toasts:
		t["time"] -= delta
	_toasts = _toasts.filter(func(t): return t["time"] > 0.0)
	queue_redraw()


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(_font, pos, s, align, width, size, 4, Color(0, 0, 0, 0.8))
	draw_string(_font, pos, s, align, width, size, col)


func _draw() -> void:
	var vs := get_viewport_rect().size
	var c := vs / 2
	# crosshair
	draw_circle(c, 2.5, Color(1, 1, 1, 0.8))
	# prompt
	var prompt := game.player.focus_prompt()
	if prompt != "":
		_text(Vector2(0, c.y + 48), prompt, 18, Color("ffe9a8"), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	# objectives
	draw_rect(Rect2(16, 16, 430, 34 + 22 * 6), Color(0, 0, 0, 0.45))
	_text(Vector2(28, 40), "RELAY STATION KAPPA-7", 16, Color("ffc94d"))
	var y := 64.0
	for o in game.objectives():
		var done: bool = o[1]
		# ASCII markers: the default font used in web builds has no ✔ / ○ glyphs.
		_text(Vector2(28, y), ("[x] " if done else "[  ] ") + o[0], 14, Color("4dff7a") if done else Color("d7deea"))
		y += 22
	# toasts
	var ty := vs.y - 120.0
	for t in _toasts:
		var a := clampf(t["time"], 0.0, 1.0)
		_text(Vector2(0, ty), t["text"], 16, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		ty -= 24
	# help
	_text(Vector2(16, vs.y - 16), "WASD move · Shift sprint · mouse/arrows look · E use · F grab · Click throw · Tab inventory · K save · L load · F1 debug · Esc free mouse", 13, Color("8a94a8"))
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and game.state == Game.State.PLAYING and game.player.controls_enabled:
		_text(Vector2(0, c.y - 40), "Click to capture the mouse", 16, Color("8a94a8"), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if game.state == Game.State.WON:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
		_text(Vector2(0, c.y - 20), "UPLINK ESTABLISHED", 46, Color("4de1ff"), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		_text(Vector2(0, c.y + 24), "Station Kappa-7 is back online.  Caught %d times.  R to restart." % game.stats["caught"], 18, Color("d7deea"), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
