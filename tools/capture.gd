extends SceneTree
## Renders the game at a few staged moments and saves screenshots.
##   godot --path . --script res://tools/capture.gd -- <out_dir> [debug]
## Needs a renderer (not --headless); on Linux CI use xvfb-run.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	var game: Game = main.game
	var p := game.player
	p.scripted = true
	if args.has("debug"):
		main._debug.visible = true
	# 1. start, dark station
	await _frames(30)
	_shot(out + "/01_start.png")
	# 2. power on: fuel cell in, relay fixed
	game.inventory.add("fuel_cell", 1)
	game.inventory.add("fuse", 1)
	game.entity("generator").interact(p)
	game.entity("relay_a").interact(p)
	game.grid.set_flag("sec_switch", "closed", false) # keep the drone docked for the photo
	p.teleport(LevelBuilder.cell_center(Vector2i(10, 3)) + Vector3(0, 0.1, 0), -PI / 2)
	await _frames(90)
	_shot(out + "/02_cargo_bay.png")
	# 3. crate on the plate, door 2 open
	var crate: RigidBody3D = game.entity("crate_1")
	crate.global_position = LevelBuilder.cell_center(Vector2i(14, 5)) + Vector3.UP * 0.6
	p.teleport(LevelBuilder.cell_center(Vector2i(14, 2)) + Vector3(0, 0.1, 0), PI)
	await _frames(120)
	_shot(out + "/03_plate_door.png")
	# 4. inventory / workbench UI
	game.inventory.add("scrap", 3)
	game.inventory.add("wire", 1)
	main._open_inventory(true)
	await _frames(10)
	_shot(out + "/04_workbench.png")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	var cam := root.get_viewport().get_camera_3d()
	print("saved ", path, "  camera ", cam.global_position.snapped(Vector3.ONE * 0.01), " fwd ", (-cam.global_transform.basis.z).snapped(Vector3.ONE * 0.01), " current ", cam.get_path())
