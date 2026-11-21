class_name SaveSystem
extends RefCounted
## Versioned save files.
##
## Rules:
##  * Save only SOURCE state: inventory, grid flags (fuel inserted, relay
##    repaired, lever position), which pickups were collected, crate
##    transforms, player and drone positions.
##  * Never save DERIVED state (which doors are open, which lights are on):
##    it is recomputed from the grid after loading, so it can't disagree.
##  * Every format change bumps VERSION and adds a migration step.

const VERSION := 2
const DEFAULT_PATH := "user://relay_station_save.json"


static func capture(game: Game) -> Dictionary:
	var crates := {}
	for id in game.entities:
		var n = game.entities[id]
		if n is Props.Crate:
			var t: Transform3D = n.global_transform
			crates[id] = {"pos": _v3(t.origin), "rot": _v3(t.basis.get_euler())}
	var p := game.player
	var d := game.drone
	return {
		"version": VERSION,
		"level": game.level_path,
		"player": {"pos": _v3(p.global_position), "yaw": p.pivot.rotation.y},
		"inventory": game.inventory.to_data(),
		"grid": game.grid.export_flags(),
		"collected": game.collected.keys(),
		"crates": crates,
		"drone": {"pos": _v3(d.global_position), "route_index": d.route_index} if d != null else {},
		"state": game.state,
	}


static func save_to(game: Game, path := DEFAULT_PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(capture(game), "  "))
	return OK


## Returns "" on success or a human-readable error.
static func load_from(game: Game, path := DEFAULT_PATH) -> String:
	if not FileAccess.file_exists(path):
		return "No save file"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return "Save file is corrupted"
	return apply(game, data)


static func apply(game: Game, data: Dictionary) -> String:
	var version := int(data.get("version", 1))
	if version > VERSION:
		return "Save is from a newer version (%d > %d)" % [version, VERSION]
	data = migrate(data)
	game.rebuild_world()
	game.inventory.from_data(data["inventory"])
	game.collected.clear()
	for id in data["collected"]:
		game.collected[str(id)] = true
	game.remove_collected_pickups()
	game.grid.import_flags(data["grid"])
	for id in data["crates"]:
		var c = game.entity(id)
		if c is Props.Crate:
			c.global_position = _to_v3(data["crates"][id]["pos"])
			c.rotation = _to_v3(data["crates"][id]["rot"])
			c.linear_velocity = Vector3.ZERO
	game.player.teleport(_to_v3(data["player"]["pos"]), float(data["player"]["yaw"]))
	if game.drone != null and not (data["drone"] as Dictionary).is_empty():
		game.drone.global_position = _to_v3(data["drone"]["pos"])
		game.drone.route_index = int(data["drone"]["route_index"])
	game.state = int(data.get("state", Game.State.PLAYING))
	game.snap_doors()
	return ""


## v1 -> v2: v1 stored the inventory as { item_id: count } with no slots.
static func migrate(data: Dictionary) -> Dictionary:
	var d := data.duplicate(true)
	if int(d.get("version", 1)) == 1:
		var inv := Inventory.new(8)
		var old: Dictionary = d.get("inventory", {})
		var ids := old.keys()
		ids.sort()
		for id in ids:
			inv.add(id, int(old[id]))
		d["inventory"] = inv.to_data()
		d["crates"] = d.get("crates", {})
		d["drone"] = d.get("drone", {})
		d["version"] = 2
	return d


static func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _to_v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
