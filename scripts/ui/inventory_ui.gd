class_name InventoryUI
extends PanelContainer
## Inventory grid with native Godot drag & drop (_get_drag_data /
## _can_drop_data / _drop_data on each slot), right-click to split a stack,
## and a crafting list that only appears at the workbench.

var game: Game
var crafting_mode := false
var _grid: GridContainer
var _craft_box: VBoxContainer
var _title: Label


class SlotButton:
	extends Button
	var ui: InventoryUI
	var index := 0

	func _ready() -> void:
		custom_minimum_size = Vector2(118, 72)
		focus_mode = Control.FOCUS_NONE
		add_theme_font_size_override("font_size", 13)
		gui_input.connect(_on_gui_input)

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			ui.game.inventory.split(index)

	func _get_drag_data(_pos: Vector2) -> Variant:
		var s = ui.game.inventory.slots[index]
		if s == null:
			return null
		var preview := Label.new()
		preview.text = "%s x%d" % [ItemDB.item(s["id"]).display_name, s["count"]]
		set_drag_preview(preview)
		return {"slot": index}

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("slot")

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		ui.game.inventory.move(int(data["slot"]), index)


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.94)
	style.border_color = Color("ffc94d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	root.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = 4
	root.add_child(_grid)
	for i in game.inventory.size():
		var b := SlotButton.new()
		b.ui = self
		b.index = i
		_grid.add_child(b)
	var hint := Label.new()
	hint.text = "Drag to move / merge / swap  ·  Right-click to split  ·  Tab to close"
	hint.add_theme_color_override("font_color", Color("8a94a8"))
	hint.add_theme_font_size_override("font_size", 13)
	root.add_child(hint)
	_craft_box = VBoxContainer.new()
	root.add_child(_craft_box)
	game.inventory.changed.connect(refresh)
	refresh()


func open(crafting: bool) -> void:
	crafting_mode = crafting
	visible = true
	refresh()


func close() -> void:
	visible = false
	crafting_mode = false


func refresh() -> void:
	if not is_inside_tree():
		return
	_title.text = "WORKBENCH" if crafting_mode else "INVENTORY"
	for i in _grid.get_child_count():
		var b: Button = _grid.get_child(i)
		var s = game.inventory.slots[i]
		if s == null:
			b.text = ""
			b.remove_theme_color_override("font_color")
		else:
			var it := ItemDB.item(s["id"])
			b.text = "%s\nx%d" % [it.display_name, s["count"]]
			b.add_theme_color_override("font_color", it.color.lightened(0.35))
	for c in _craft_box.get_children():
		c.queue_free()
	if not crafting_mode:
		return
	for r in ItemDB.recipes():
		var btn := Button.new()
		var needs := []
		for id in r.inputs:
			needs.append("%d %s (%d)" % [r.inputs[id], ItemDB.item(id).display_name, game.inventory.count_of(id)])
		btn.text = "Craft %s   (uses %s)" % [ItemDB.item(r.output_id).display_name, ", ".join(needs)]
		btn.disabled = not game.inventory.can_craft(r)
		btn.pressed.connect(func():
			if game.inventory.craft(r):
				game.notify("Crafted %s" % ItemDB.item(r.output_id).display_name))
		_craft_box.add_child(btn)
