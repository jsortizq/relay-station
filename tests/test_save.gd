extends TestCase

const PATH := "user://test_save.json"


func _save_load(game: Game) -> void:
	assert_eq(SaveSystem.save_to(game, PATH), OK)
	assert_eq(SaveSystem.load_from(game, PATH), "")
	await frames(3)


func _pickups(game: Game, item_id: String) -> int:
	var n := 0
	for id in game.entities:
		var e = game.entities[id]
		if e is Props.Pickup and is_instance_valid(e) and not e.is_queued_for_deletion() and e.item_id == item_id:
			n += 1
	return n


func test_collected_pickup_stays_collected_after_load() -> void:
	var game := await make_game()
	var before := _pickups(game, "scrap")
	await use(game, "scrap_1")
	assert_eq(game.inventory.count_of("scrap"), 1, "precondition: picked up")
	await _save_load(game)
	assert_eq(game.inventory.count_of("scrap"), 1, "inventory restored")
	assert_eq(_pickups(game, "scrap"), before - 1, "scrap_1 must not respawn after loading")


func test_save_load_cannot_duplicate_items() -> void:
	# The classic exploit: pick up, save, load, pick up the same thing again.
	var game := await make_game()
	await use(game, "fuel_cell_1")
	await _save_load(game)
	assert_eq(game.entity("fuel_cell_1"), null, "fuel cell is gone from the world")
	assert_eq(game.inventory.count_of("fuel_cell"), 1)


func test_derived_state_is_recomputed_after_load() -> void:
	var game := await make_game()
	game.inventory.add("fuel_cell", 1)
	game.inventory.add("fuse", 1)
	await use(game, "generator")
	await use(game, "relay_a")
	assert_true(game.grid.is_powered("door_1"), "precondition")
	await _save_load(game)
	assert_true(game.grid.is_powered("door_1"), "door power comes from the grid flags")
	var door: Fixtures.Door = game.entity("door_1")
	assert_true(door.position.y > 2.5, "door snapped open after load (y=%.2f)" % door.position.y)
	assert_false(game.entity("door_1").nav_region == null)
	assert_true(door.nav_region.enabled, "nav region follows the door")


func test_crate_position_is_restored() -> void:
	var game := await make_game()
	var crate: RigidBody3D = game.entity("crate_1")
	crate.global_position = Vector3(20, 0.46, 11)
	await frames(30)
	var saved := crate.global_position
	await _save_load(game)
	var restored: RigidBody3D = game.entity("crate_1")
	assert_true(restored.global_position.distance_to(saved) < 0.1, "%s vs %s" % [restored.global_position, saved])


func test_v1_save_is_migrated() -> void:
	var game := await make_game()
	var v1 := {
		"version": 1,
		"player": {"pos": [3.0, 0.1, 11.0], "yaw": 0.0},
		"inventory": {"scrap": 12, "wire": 1},
		"grid": {"gen": {"running": true}},
		"collected": ["scrap_1", "scrap_2"],
	}
	assert_eq(SaveSystem.apply(game, v1), "")
	await frames(2)
	assert_eq(game.inventory.count_of("scrap"), 12)
	assert_eq(game.inventory.slots[0]["count"], 10, "split into stacks of max 10")
	assert_true(game.grid.is_powered("light_a"))
	assert_eq(game.entity("scrap_1"), null)


func test_newer_save_version_is_rejected() -> void:
	var game := await make_game()
	var err := SaveSystem.apply(game, {"version": SaveSystem.VERSION + 1})
	assert_true(err.begins_with("Save is from a newer version"), err)
