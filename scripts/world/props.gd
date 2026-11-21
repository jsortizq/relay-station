class_name Props
extends RefCounted
## Collectable pickups and physics crates.


class Pickup:
	## An item lying in the world. Identified by its STABLE level-file id
	## (`uid`), which is what the save file records once it's collected.
	extends Interactable
	var item_id := ""
	var count := 1
	var _mesh: MeshInstance3D
	var _t := 0.0

	func _ready() -> void:
		var cs := Mats.box_shape(Vector3(0.7, 0.7, 0.7))
		cs.position.y = 0.5
		add_child(cs)
		var data := ItemDB.item(item_id)
		_mesh = Mats.mesh_box(Vector3(0.4, 0.4, 0.4), Mats.glow(data.color, 1.2))
		_mesh.position.y = 0.5
		add_child(_mesh)

	func prompt(_p: Node) -> String:
		var data := ItemDB.item(item_id)
		return "E — Pick up %s%s" % [data.display_name, " x%d" % count if count > 1 else ""]

	func interact(_p: Node) -> void:
		game.collect(self)

	func _process(delta: float) -> void:
		_t += delta
		_mesh.position.y = 0.5 + sin(_t * 2.0) * 0.08
		_mesh.rotation.y = _t


class Crate:
	extends RigidBody3D
	var uid := ""

	func _ready() -> void:
		collision_layer = 8   # props
		collision_mask = 1 | 2 | 8 | 16
		mass = 30.0
		continuous_cd = true
		var cs := Mats.box_shape(Vector3(0.9, 0.9, 0.9))
		add_child(cs)
		var box := Mats.mesh_box(Vector3(0.9, 0.9, 0.9), Mats.solid(Color("7a5a2e"), 0.9))
		add_child(box)
		for y in [-0.3, 0.3]:
			var band := Mats.mesh_box(Vector3(0.92, 0.08, 0.92), Mats.solid(Color("2a2e38"), 0.5, 0.6))
			band.position.y = y
			add_child(band)

	func prompt(_p: Node) -> String:
		return "F — Grab crate (30 kg)"
