extends TestCase


func _power_cargo_bay(game: Game) -> void:
	game.inventory.add("fuel_cell", 1)
	game.inventory.add("fuse", 1)
	await use(game, "generator")
	await use(game, "relay_a")


func test_interaction_ray_finds_machine_in_front() -> void:
	var game := await make_game()
	await aim_at(game, "workbench")
	assert_eq(game.player.focused, game.entity("workbench"))
	assert_true(game.player.focus_prompt().contains("workbench"), game.player.focus_prompt())


func test_cannot_interact_through_walls() -> void:
	# Stand in the cargo bay right behind the wall where the relay is, aiming at it.
	var game := await make_game()
	var relay: Node3D = game.entity("relay_a")
	var pos := relay.global_position + Vector3(4.0, 0.05, 0) # other side of the x=18..20 wall
	game.player.teleport(pos, PI / 2) # face -X (toward the relay)
	await frames(3)
	assert_true(game.player.focused != relay, "relay must not be reachable through the wall")


func test_generator_needs_fuel_cell() -> void:
	var game := await make_game()
	await use(game, "generator")
	assert_false(game.grid.get_flag("gen", "running"))
	game.inventory.add("fuel_cell", 1)
	await use(game, "generator")
	assert_true(game.grid.get_flag("gen", "running"))
	assert_eq(game.inventory.count_of("fuel_cell"), 0)


func test_removing_fuel_cell_shuts_everything_down() -> void:
	var game := await make_game()
	await _power_cargo_bay(game)
	assert_true(game.grid.is_powered("light_b3"), "precondition")
	await use(game, "generator")
	assert_eq(game.inventory.count_of("fuel_cell"), 1, "cell returned to the player")
	for id in ["light_a", "door_1", "light_b1", "light_b2", "light_b3", "light_b4", "dock"]:
		assert_false(game.grid.is_powered(id), "%s still powered" % id)


func test_door_opens_and_closes_with_power() -> void:
	var game := await make_game()
	var door: Fixtures.Door = game.entity("door_1")
	assert_false(door.nav_region.enabled)
	await _power_cargo_bay(game)
	await frames(80)
	assert_true(door.position.y > 2.8, "open (y=%.2f)" % door.position.y)
	assert_true(door.nav_region.enabled)
	await use(game, "generator")
	await frames(80)
	assert_true(door.position.y < 0.1, "closed (y=%.2f)" % door.position.y)
	assert_false(door.nav_region.enabled)


func test_crate_closes_pressure_plate() -> void:
	var game := await make_game()
	await _power_cargo_bay(game)
	var crate: RigidBody3D = game.entity("crate_1")
	crate.global_position = LevelBuilder.cell_center(Vector2i(14, 5)) + Vector3.UP * 0.8
	await frames(60)
	assert_true(game.grid.get_flag("plate", "closed"), "crate is heavy enough")
	assert_true(game.grid.is_powered("door_2"))
	crate.global_position = LevelBuilder.cell_center(Vector2i(12, 2)) + Vector3.UP * 0.5
	await frames(10)
	assert_false(game.grid.get_flag("plate", "closed"), "crate removed")


func test_player_alone_does_not_press_the_plate() -> void:
	var game := await make_game()
	game.player.teleport(LevelBuilder.cell_center(Vector2i(14, 5)) + Vector3.UP * 0.1)
	await frames(30)
	assert_false(game.grid.get_flag("plate", "closed"))


func test_grab_carry_and_throw() -> void:
	var game := await make_game()
	var crate: RigidBody3D = game.entity("crate_1")
	await aim_at(game, "crate_1")
	assert_true(game.player.focused == crate, "aiming at the crate (focus %s)" % str(game.player.focused))
	game.player.input.grab = true
	await frames(30)
	assert_eq(game.player.held, crate)
	assert_true(crate.global_position.y > 0.8, "lifted (y=%.2f)" % crate.global_position.y)
	game.player.input.throw = true
	await frames(1)
	assert_eq(game.player.held, null)
	assert_true(crate.linear_velocity.length() > 5.0, "thrown (v=%.1f)" % crate.linear_velocity.length())


func test_camera_arm_shortens_against_walls() -> void:
	var game := await make_game()
	# Back to a wall: player in the corner cell, camera looking away from the wall.
	game.player.teleport(LevelBuilder.cell_center(Vector2i(1, 1)) + Vector3.UP * 0.05, PI) # camera behind = -Z side (wall)
	await frames(5)
	assert_true(game.player.arm.get_hit_length() < game.player.arm.spring_length - 0.5, "arm %.2f" % game.player.arm.get_hit_length())


func test_player_can_walk_through_open_door_but_not_closed() -> void:
	var game := await make_game()
	var p := game.player
	# Closed: walk east from room A into door_1 at (9,3).
	p.teleport(LevelBuilder.cell_center(Vector2i(7, 3)) + Vector3.UP * 0.05, -PI / 2) # camera faces +X
	p.input.move = Vector2(0, 1)
	for i in 120:
		p.input.move = Vector2(0, 1)
		await frames(1)
	assert_true(p.global_position.x < 18.8, "blocked by the closed door (x=%.2f)" % p.global_position.x)
	await _power_cargo_bay(game)
	game.grid.set_flag("sec_switch", "closed", false) # keep the drone out of this test
	await frames(80)
	p.teleport(LevelBuilder.cell_center(Vector2i(7, 3)) + Vector3.UP * 0.05, -PI / 2)
	for i in 120:
		p.input.move = Vector2(0, 1)
		await frames(1)
	assert_true(p.global_position.x > 21.0, "walked into the cargo bay (x=%.2f)" % p.global_position.x)
