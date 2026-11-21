class_name Game
extends Node3D
## Composition root. Owns the systems (PowerGrid, Inventory), the rebuilt-
## on-load World node, the persistent Player, and game flow (objectives,
## checkpoints, win, save/load).

enum State { PLAYING, WON }

signal notified(text: String)
signal crafting_requested
signal won

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var level_path := "res://levels/station.json"
var level_data := {}
var map_rows := PackedStringArray()
var grid := PowerGrid.new()
var inventory := Inventory.new(8)
var player: Player
var drone: Drone
var entities := {}      # uid -> Node
var collected := {}     # pickup uid -> true
var state: int = State.PLAYING
var checkpoint := Vector3.ZERO
var events := PackedStringArray()
var stats := {"caught": 0, "saves": 0, "loads": 0}

var _world: Node3D


func _ready() -> void:
	level_data = JSON.parse_string(FileAccess.get_file_as_string(level_path))
	_setup_environment()
	player = PLAYER_SCENE.instantiate()
	player.game = self
	add_child(player)
	grid.changed.connect(_on_grid_changed)
	rebuild_world()
	player.teleport(checkpoint, 0.0)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07090d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4a66")
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## Frees and recreates every level object from the level file, then
## re-applies the grid. Used at start and when loading a save.
func rebuild_world() -> void:
	if _world != null:
		remove_child(_world)
		_world.queue_free()
	entities.clear()
	drone = null
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	grid = PowerGrid.new()
	grid.changed.connect(_on_grid_changed)
	for n in level_data["power"]["nodes"]:
		grid.add_node(n["id"], n["type"], n.get("flags", {}))
	for e in level_data["power"]["edges"]:
		grid.connect_nodes(e[0], e[1])
	LevelBuilder.build(self, level_data, _world)
	var rows := PackedStringArray(level_data["map"])
	for y in rows.size():
		var x := rows[y].find("P")
		if x != -1:
			checkpoint = LevelBuilder.cell_center(Vector2i(x, y)) + Vector3.UP * 0.1
	grid.solve()
	snap_doors()


func register_entity(uid: String, node: Node) -> void:
	entities[uid] = node
	if node is Drone:
		drone = node


func entity(uid: String) -> Node:
	return entities.get(uid)


func _on_grid_changed() -> void:
	for id in entities:
		var n = entities[id]
		if is_instance_valid(n) and n.has_method("on_power_changed"):
			n.on_power_changed()


func snap_doors() -> void:
	for id in entities:
		if entities[id] is Fixtures.Door:
			entities[id].snap()


func _physics_process(_delta: float) -> void:
	for id in entities:
		var n = entities[id]
		if n is Fixtures.PressurePlate:
			n.refresh()


# ------------------------------------------------------------- gameplay

func collect(p: Props.Pickup) -> void:
	var left := inventory.add(p.item_id, p.count)
	var taken := p.count - left
	if taken == 0:
		notify("Inventory full")
		return
	if left > 0:
		p.count = left
		notify("Picked up %d (inventory full)" % taken)
		return
	collected[p.uid] = true
	entities.erase(p.uid)
	p.queue_free()
	notify("Picked up %s" % ItemDB.item(p.item_id).display_name)


func remove_collected_pickups() -> void:
	for id in entities.keys():
		var n = entities[id]
		if n is Props.Pickup and collected.has(n.uid):
			entities.erase(id)
			n.queue_free()


func player_caught() -> void:
	stats["caught"] += 1
	notify("Caught by the security drone! Back to the maintenance bay.")
	log_event("player caught")
	player.teleport(checkpoint, 0.0)
	if drone != null:
		drone.reset_to(drone.route[0])


func open_crafting() -> void:
	crafting_requested.emit()


func win() -> void:
	state = State.WON
	log_event("uplink engaged")
	won.emit()


func notify(text: String) -> void:
	log_event(text)
	notified.emit(text)


func log_event(text: String) -> void:
	events.append("[%6.1f] %s" % [Time.get_ticks_msec() / 1000.0, text])
	if events.size() > 10:
		events.remove_at(0)


## A point is "lit" if a powered light fixture in the same room is near it.
## Used by the drone: stealth works better in the dark.
func is_lit(pos: Vector3) -> bool:
	for id in entities:
		var n = entities[id]
		if n is Fixtures.LightFixture and grid.is_powered(n.power_node):
			if Vector2(n.global_position.x, n.global_position.z).distance_to(Vector2(pos.x, pos.z)) < 7.0:
				return true
	return false


# ---------------------------------------------------------------- saves

func save_game() -> void:
	var err := SaveSystem.save_to(self)
	stats["saves"] += 1
	notify("Game saved" if err == OK else "Save failed (%s)" % error_string(err))


func load_game() -> void:
	var err := SaveSystem.load_from(self)
	stats["loads"] += 1
	notify("Game loaded" if err == "" else err)


# ------------------------------------------------------------ objectives

func objectives() -> Array:
	var gen_on: bool = grid.get_flag("gen", "running")
	return [
		["Find a fuel cell", gen_on or inventory.count_of("fuel_cell") > 0],
		["Start the generator", gen_on],
		["Craft a fuse at the workbench (2 scrap + 1 wire)", grid.get_flag("relay_a", "intact") or inventory.count_of("fuse") > 0],
		["Repair the relay by the cargo door", grid.get_flag("relay_a", "intact")],
		["Open the uplink door (the plate needs cargo weight)", grid.is_powered("door_2")],
		["Engage the uplink", state == State.WON],
	]


func summary() -> String:
	var flags := []
	for id in ["gen", "relay_a", "sec_switch", "plate"]:
		flags.append("%s=%s" % [id, str(grid.nodes[id]["flags"].values())])
	return "state=%s inv=%d collected=%d %s door1=%s door2=%s drone=%s" % [
		["PLAYING", "WON"][state], inventory.total_items(), collected.size(), " ".join(flags),
		grid.is_powered("door_1"), grid.is_powered("door_2"), drone.state_name() if drone else "-"]
