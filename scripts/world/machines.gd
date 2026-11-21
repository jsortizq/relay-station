class_name Machines
extends RefCounted
## All interactable machines of the station. Kept in one file because each
## is small; every class only translates player actions into PowerGrid /
## Inventory operations and reflects the result visually.


class Generator:
	extends Interactable
	var _core: MeshInstance3D

	func _ready() -> void:
		add_child(Mats.box_shape(Vector3(1.6, 1.6, 1.2)))
		var body := Mats.mesh_box(Vector3(1.6, 1.6, 1.2), Mats.solid(Color("3a4152"), 0.6, 0.4))
		body.position.y = 0.8
		add_child(body)
		get_child(0).position.y = 0.8
		_core = Mats.mesh_cyl(0.25, 0.9, Mats.solid(Color("222630")))
		_core.position = Vector3(0, 0.9, 0.62)
		_core.rotation_degrees.x = 90
		add_child(_core)

	func running() -> bool:
		return game.grid.get_flag(power_node, "running")

	func prompt(_p: Node) -> String:
		if running():
			return "E — Remove fuel cell (shuts the station down)"
		if game.inventory.count_of("fuel_cell") > 0:
			return "E — Insert fuel cell"
		return "Generator offline — needs a fuel cell"

	func interact(_p: Node) -> void:
		if running():
			if game.inventory.space_for("fuel_cell") > 0:
				game.inventory.add("fuel_cell", 1)
				game.grid.set_flag(power_node, "running", false)
				game.notify("Generator stopped")
			else:
				game.notify("Inventory full")
		elif game.inventory.remove("fuel_cell", 1) == 1:
			game.grid.set_flag(power_node, "running", true)
			game.notify("Generator online")

	func on_power_changed() -> void:
		_core.material_override = Mats.glow(Color("4dff7a"), 3.0) if running() else Mats.solid(Color("222630"))


class Relay:
	extends Interactable
	var _lamp: MeshInstance3D

	func _ready() -> void:
		add_child(Mats.box_shape(Vector3(0.9, 1.4, 0.6)))
		get_child(0).position.y = 0.7
		var box := Mats.mesh_box(Vector3(0.9, 1.4, 0.6), Mats.solid(Color("4a4f5e"), 0.5, 0.5))
		box.position.y = 0.7
		add_child(box)
		_lamp = Mats.mesh_sphere(0.12, Mats.solid(Color.BLACK))
		_lamp.position = Vector3(0, 1.2, 0.32)
		add_child(_lamp)

	func intact() -> bool:
		return game.grid.get_flag(power_node, "intact")

	func prompt(_p: Node) -> String:
		if intact():
			return "Relay operational"
		if game.inventory.count_of("fuse") > 0:
			return "E — Replace burnt fuse"
		return "Relay fuse burnt out — craft a fuse at the workbench"

	func interact(_p: Node) -> void:
		if not intact() and game.inventory.remove("fuse", 1) == 1:
			game.grid.set_flag(power_node, "intact", true)
			game.notify("Relay repaired")

	func on_power_changed() -> void:
		var energised := game.grid.is_powered(power_node)
		var col := Color("4dff7a") if intact() and energised else (Color("ff4d4d") if energised else Color.BLACK)
		_lamp.material_override = Mats.glow(col, 4.0) if col != Color.BLACK else Mats.solid(col)


class Lever:
	extends Interactable
	var _handle: MeshInstance3D

	func _ready() -> void:
		add_child(Mats.box_shape(Vector3(0.6, 1.2, 0.4)))
		get_child(0).position.y = 0.6
		var base := Mats.mesh_box(Vector3(0.6, 1.2, 0.4), Mats.solid(Color("2f3442")))
		base.position.y = 0.6
		add_child(base)
		_handle = Mats.mesh_box(Vector3(0.12, 0.6, 0.12), Mats.glow(Color("ffc94d"), 1.5))
		_handle.position = Vector3(0, 1.0, 0.26)
		add_child(_handle)

	func closed() -> bool:
		return game.grid.get_flag(power_node, "closed")

	func prompt(_p: Node) -> String:
		return "E — %s security circuit" % ("Cut" if closed() else "Restore")

	func interact(_p: Node) -> void:
		game.grid.set_flag(power_node, "closed", not closed())
		game.notify("Security circuit %s" % ("restored" if closed() else "cut"))

	func on_power_changed() -> void:
		_handle.rotation_degrees.x = 0.0 if closed() else 60.0


class Workbench:
	extends Interactable

	func _ready() -> void:
		add_child(Mats.box_shape(Vector3(1.8, 1.0, 0.9)))
		get_child(0).position.y = 0.5
		var top := Mats.mesh_box(Vector3(1.8, 0.12, 0.9), Mats.solid(Color("8a6a45")))
		top.position.y = 0.95
		add_child(top)
		for x in [-0.8, 0.8]:
			var leg := Mats.mesh_box(Vector3(0.1, 0.9, 0.8), Mats.solid(Color("3a3f4c")))
			leg.position = Vector3(x, 0.45, 0)
			add_child(leg)

	func prompt(_p: Node) -> String:
		return "E — Use workbench (craft)"

	func interact(_p: Node) -> void:
		game.open_crafting()


class Uplink:
	extends Interactable
	var _screen: MeshInstance3D

	func _ready() -> void:
		add_child(Mats.box_shape(Vector3(1.2, 2.2, 0.8)))
		get_child(0).position.y = 1.1
		var tower := Mats.mesh_box(Vector3(1.2, 2.2, 0.8), Mats.solid(Color("2b3040"), 0.4, 0.6))
		tower.position.y = 1.1
		add_child(tower)
		_screen = Mats.mesh_box(Vector3(0.9, 0.6, 0.05), Mats.solid(Color.BLACK))
		_screen.position = Vector3(0, 1.5, 0.42)
		add_child(_screen)

	func prompt(_p: Node) -> String:
		if game.state == Game.State.WON:
			return "Uplink established"
		return "E — Engage uplink" if is_powered() else "Uplink has no power"

	func interact(_p: Node) -> void:
		if is_powered() and game.state != Game.State.WON:
			game.win()

	func on_power_changed() -> void:
		_screen.material_override = Mats.glow(Color("4de1ff"), 2.5) if is_powered() else Mats.solid(Color.BLACK)


class Dock:
	extends Interactable

	func _ready() -> void:
		add_child(Mats.box_shape(Vector3(1.2, 0.3, 1.2)))
		get_child(0).position.y = 0.15
		add_child(Mats.mesh_box(Vector3(1.2, 0.3, 1.2), Mats.solid(Color("30364a"))))
		get_child(1).position.y = 0.15

	func prompt(_p: Node) -> String:
		return "Drone dock: %s" % ("POWERED" if is_powered() else "offline")
