extends Node
## Owns the Game and the UI layer. Handles mouse capture and global keys.

var game: Game
var _ui: CanvasLayer
var _hud: Hud
var _inv: InventoryUI
var _debug: DebugOverlay


func _ready() -> void:
	start()


func start() -> void:
	if game != null:
		game.queue_free()
		_ui.queue_free()
	game = Game.new()
	add_child(game)
	_ui = CanvasLayer.new()
	add_child(_ui)
	_hud = Hud.new()
	_hud.game = game
	_ui.add_child(_hud)
	_inv = InventoryUI.new()
	_inv.game = game
	_inv.set_anchors_preset(Control.PRESET_CENTER)
	_ui.add_child(_inv)
	_debug = DebugOverlay.new()
	_debug.game = game
	_ui.add_child(_debug)
	game.crafting_requested.connect(func(): _open_inventory(true))
	game.won.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)


func _open_inventory(crafting: bool) -> void:
	_inv.open(crafting)
	_inv.position = (_inv.get_viewport_rect().size - _inv.get_combined_minimum_size()) / 2
	game.player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_inventory() -> void:
	_inv.close()
	game.player.controls_enabled = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if _inv.visible:
			_close_inventory()
		else:
			_open_inventory(false)
	elif event.is_action_pressed("toggle_debug"):
		_debug.visible = not _debug.visible
	elif event.is_action_pressed("save_game"):
		game.save_game()
	elif event.is_action_pressed("load_game"):
		_close_inventory()
		game.load_game()
	elif event.is_action_pressed("restart"):
		start()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _inv.visible:
			_close_inventory()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and not _inv.visible and game.state == Game.State.PLAYING:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled() # this click only captures, it doesn't throw
