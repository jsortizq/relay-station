extends SceneTree
## Scripted acceptance scenarios (headless). Exit code 0 = PASS, 1 = FAIL.
##   godot --headless --path . --script res://tools/scenario.gd -- <name>
##
##   save_duplication   pick up scrap_1 and the fuel cell, save, load, try to
##                      pick them up again. PASS = no item exists twice.
##   generator_shutdown power the station, then pull the fuel cell back out.
##                      PASS = every light, door and the drone dock go dark.

const SCENARIOS := ["save_duplication", "generator_shutdown"]
const SAVE_PATH := "user://scenario_save.json"

var game: Game


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var name: String = args[0] if args.size() > 0 else ""
	if not SCENARIOS.has(name):
		print("usage: -- <%s>" % "|".join(SCENARIOS))
		quit(2)
		return
	await process_frame
	game = Game.new()
	root.add_child(game)
	await _frames(1)
	game.player.scripted = true
	await _frames(3)
	var ok: bool = await call(name)
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _pickup_exists(uid: String) -> bool:
	var n = game.entity(uid)
	return n != null and is_instance_valid(n) and not n.is_queued_for_deletion()


func save_duplication() -> bool:
	for uid in ["scrap_1", "fuel_cell_1"]:
		game.collect(game.entity(uid))
	await _frames(2)
	print("before save: scrap %d, fuel cells %d" % [game.inventory.count_of("scrap"), game.inventory.count_of("fuel_cell")])
	SaveSystem.save_to(game, SAVE_PATH)
	SaveSystem.load_from(game, SAVE_PATH)
	await _frames(3)
	var respawned := []
	for uid in ["scrap_1", "fuel_cell_1"]:
		if _pickup_exists(uid):
			respawned.append(uid)
			game.collect(game.entity(uid))
	await _frames(2)
	print("after load:  scrap %d, fuel cells %d, respawned in world: %s" % [game.inventory.count_of("scrap"), game.inventory.count_of("fuel_cell"), str(respawned)])
	return respawned.is_empty() and game.inventory.count_of("scrap") == 1 and game.inventory.count_of("fuel_cell") == 1


func generator_shutdown() -> bool:
	game.inventory.add("fuel_cell", 1)
	game.inventory.add("fuse", 1)
	game.entity("generator").interact(game.player)
	game.entity("relay_a").interact(game.player)
	await _frames(5)
	print("powered:  %s" % [str(_powered_list())])
	game.entity("generator").interact(game.player) # take the fuel cell back
	await _frames(5)
	var still := _powered_list()
	print("after removing the fuel cell, still powered: %s" % (str(still) if not still.is_empty() else "nothing"))
	print("drone: %s" % game.drone.state_name())
	return still.is_empty() and game.drone.state == Drone.State.OFFLINE


func _powered_list() -> Array:
	var out := []
	for id in game.grid.powered:
		if game.grid.powered[id]:
			out.append(id)
	return out
