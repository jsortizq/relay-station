extends TestCase
## End-to-end: completes the level through the same interaction path a
## player uses (aim with the camera ray, press E), checking every
## objective on the way.


func test_full_walkthrough() -> void:
	var game := await make_game()
	var obj := func(i: int) -> bool: return game.objectives()[i][1]

	await use(game, "fuel_cell_1")
	assert_true(obj.call(0), "found fuel cell")
	await use(game, "generator")
	assert_true(obj.call(1), "generator on")
	assert_true(game.grid.is_powered("light_a"))

	for id in ["scrap_1", "scrap_2", "wire_1"]:
		await use(game, id)
	var asked := [false]
	game.crafting_requested.connect(func(): asked[0] = true)
	await use(game, "workbench")
	assert_true(asked[0], "workbench opens crafting")
	assert_true(game.inventory.craft(ItemDB.recipes()[0]), "craft fuse")
	assert_true(obj.call(2))

	await use(game, "relay_a")
	assert_true(obj.call(3), "relay repaired")
	assert_true(game.grid.is_powered("door_1"))

	await use(game, "sec_lever")
	assert_eq(game.drone.state, Drone.State.OFFLINE, "security cut")

	var crate: RigidBody3D = game.entity("crate_1")
	crate.global_position = LevelBuilder.cell_center(Vector2i(14, 5)) + Vector3.UP * 0.8
	await frames(90)
	assert_true(obj.call(4), "door 2 open")

	await use(game, "uplink")
	assert_eq(game.state, Game.State.WON)
	assert_true(obj.call(5))
