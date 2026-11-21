class_name Fixtures
extends RefCounted
## Non-interactive powered fixtures: lights, doors and the pressure plate.


class LightFixture:
	extends Node3D
	var game: Game
	var power_node := ""
	var _light: OmniLight3D
	var _bulb: MeshInstance3D

	func _ready() -> void:
		_bulb = Mats.mesh_box(Vector3(1.0, 0.08, 0.3), Mats.solid(Color("1a1d24")))
		_bulb.position.y = 2.95
		add_child(_bulb)
		_light = OmniLight3D.new()
		_light.position.y = 2.6
		_light.omni_range = 7.0
		_light.light_energy = 1.6
		_light.light_color = Color("ffe9c2")
		_light.visible = false
		add_child(_light)

	func on_power_changed() -> void:
		var on := game.grid.is_powered(power_node)
		_light.visible = on
		_bulb.material_override = Mats.glow(Color("ffe9c2"), 3.0) if on else Mats.solid(Color("1a1d24"))


class Door:
	## Sliding door. Open = powered. While closed it blocks movement AND its
	## own navigation region is disabled, so the drone re-plans around it.
	extends AnimatableBody3D
	const OPEN_HEIGHT := 2.9
	const SPEED := 3.0
	var game: Game
	var power_node := ""
	var uid := ""
	var nav_region: NavigationRegion3D
	var horizontal := true # door spans the X axis (passage along Z)
	var _target := 0.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		sync_to_physics = false
		var size := Vector3(2.0, 3.0, 0.3) if horizontal else Vector3(0.3, 3.0, 2.0)
		var cs := Mats.box_shape(size)
		cs.position.y = 1.5
		add_child(cs)
		var panel := Mats.mesh_box(size, Mats.solid(Color("5a4630"), 0.5, 0.5))
		panel.position.y = 1.5
		add_child(panel)
		var stripe := Mats.mesh_box(size * Vector3(1.02, 0.08, 1.05), Mats.glow(Color("ffc94d"), 1.2))
		stripe.position.y = 1.5
		add_child(stripe)

	func is_open() -> bool:
		return game.grid.is_powered(power_node)

	func on_power_changed() -> void:
		_target = OPEN_HEIGHT if is_open() else 0.0
		if nav_region != null:
			nav_region.enabled = is_open()

	## Instantly match the power state (used after loading a save).
	func snap() -> void:
		on_power_changed()
		position.y = _target

	func _physics_process(delta: float) -> void:
		position.y = move_toward(position.y, _target, SPEED * delta)


class PressurePlate:
	## Closes its switch while a heavy enough RigidBody3D rests on it.
	## The player alone is NOT enough: the plate is calibrated for cargo.
	extends Area3D
	const MIN_MASS := 20.0
	var game: Game
	var power_node := ""
	var _pad: MeshInstance3D

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 8 # props
		monitoring = true
		var cs := Mats.box_shape(Vector3(1.6, 0.5, 1.6))
		cs.position.y = 0.25
		add_child(cs)
		_pad = Mats.mesh_box(Vector3(1.6, 0.06, 1.6), Mats.solid(Color("3a3f4c")))
		_pad.position.y = 0.03
		add_child(_pad)
		body_entered.connect(func(_b): _update())
		body_exited.connect(func(_b): _update())

	func load_on_plate() -> float:
		var mass := 0.0
		for b in get_overlapping_bodies():
			if b is RigidBody3D:
				mass += (b as RigidBody3D).mass
		return mass

	func _update() -> void:
		var closed := load_on_plate() >= MIN_MASS
		game.grid.set_flag(power_node, "closed", closed)

	## Called every physics frame by Game (overlap lists update in the step).
	func refresh() -> void:
		_update()

	func on_power_changed() -> void:
		var closed: bool = game.grid.get_flag(power_node, "closed")
		_pad.material_override = Mats.glow(Color("4dff7a"), 1.5) if closed else Mats.solid(Color("3a3f4c"))
