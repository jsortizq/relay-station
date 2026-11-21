extends TestCase


## Powers the dock from a separate test generator and isolates it from the
## room lights (opens the security switch between them).
func _dock_only_power(game: Game) -> void:
	game.grid.add_node("test_gen", "generator", {"running": true})
	game.grid.connect_nodes("test_gen", "dock")
	game.grid.set_flag("sec_switch", "closed", false)


func _powered(game: Game) -> void:
	game.inventory.add("fuel_cell", 1)
	game.inventory.add("fuse", 1)
	await use(game, "generator")
	await use(game, "relay_a")
	game.player.teleport(LevelBuilder.cell_center(Vector2i(2, 5)) + Vector3.UP * 0.05)
	await frames(5)


func test_drone_offline_until_dock_powered() -> void:
	var game := await make_game()
	await frames(10)
	assert_eq(game.drone.state, Drone.State.OFFLINE)
	await _powered(game)
	assert_eq(game.drone.state, Drone.State.PATROL)


func test_cutting_security_circuit_disables_drone() -> void:
	var game := await make_game()
	await _powered(game)
	await use(game, "sec_lever")
	await frames(3)
	assert_eq(game.drone.state, Drone.State.OFFLINE)


func test_drone_patrol_moves_along_route() -> void:
	var game := await make_game()
	await _powered(game)
	var start := game.drone.global_position
	await frames(180)
	assert_true(game.drone.global_position.distance_to(start) > 2.0, "drone moved")
	assert_true(game.drone.agent.get_current_navigation_path().size() >= 2, "has a path")


func test_vision_respects_walls_and_cone() -> void:
	var game := await make_game()
	await _powered(game)
	var d := game.drone
	d.global_position = LevelBuilder.cell_center(Vector2i(12, 3))
	d.facing = Vector3.RIGHT # +X
	await frames(1)
	var ahead := LevelBuilder.cell_center(Vector2i(15, 3)) + Vector3.UP
	var behind := LevelBuilder.cell_center(Vector2i(10, 3)) + Vector3.UP
	var through_wall := LevelBuilder.cell_center(Vector2i(12, 7)) + Vector3.UP
	assert_true(d.can_see(ahead), "in cone, lit, clear line")
	assert_false(d.can_see(behind), "behind the drone")
	d.facing = Vector3.BACK # +Z, toward the wall row y=6
	assert_false(d.can_see(through_wall), "wall in between")


func test_darkness_shortens_vision() -> void:
	var game := await make_game()
	await _powered(game)
	var d := game.drone
	d.global_position = LevelBuilder.cell_center(Vector2i(11, 3))
	d.facing = Vector3.RIGHT
	var target := LevelBuilder.cell_center(Vector2i(14, 3)) + Vector3.UP # 6 m away
	assert_true(d.can_see(target), "lit room")
	# Kill the room lights but keep the drone running.
	_dock_only_power(game)
	game.grid.set_flag("relay_a", "intact", false)
	assert_false(game.is_lit(target), "precondition: dark")
	assert_false(d.can_see(target), "6 m is beyond the 4.5 m dark range")


func test_closed_door_forces_reroute() -> void:
	var game := await make_game()
	await _powered(game)
	var d := game.drone
	d.global_position = LevelBuilder.cell_center(Vector2i(11, 3))
	d.state = Drone.State.SUSPICIOUS
	d.agent.target_position = LevelBuilder.cell_center(Vector2i(5, 3)) # in room A, through door_1
	await frames(5)
	var path_open := d.agent.get_current_navigation_path()
	assert_true(path_open.size() >= 2, "reachable while door is open")
	assert_true(d.agent.is_target_reachable())
	_dock_only_power(game)                         # keep the drone alive
	game.grid.set_flag("relay_a", "intact", false) # door_1 loses power
	d.agent.target_position = LevelBuilder.cell_center(Vector2i(5, 3))
	await frames(5)
	assert_false(d.agent.is_target_reachable(), "door closed: room A unreachable")


func test_drone_catches_player_and_sends_to_checkpoint() -> void:
	var game := await make_game()
	await _powered(game)
	var d := game.drone
	game.player.teleport(LevelBuilder.cell_center(Vector2i(14, 3)) + Vector3.UP * 0.05)
	d.global_position = LevelBuilder.cell_center(Vector2i(12, 3))
	d.facing = Vector3.RIGHT
	await frames(240)
	assert_eq(game.stats["caught"], 1, "caught once")
	assert_true(game.player.global_position.distance_to(game.checkpoint) < 1.0, "back at the checkpoint")
