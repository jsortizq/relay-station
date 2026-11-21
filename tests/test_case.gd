class_name TestCase
extends RefCounted
## Minimal async test base. World tests build a Game inside its own
## SubViewport with own_world_3d = true, so each test has a private physics
## space and navigation map, then advance real physics frames.

var failures := PackedStringArray()
var tree: SceneTree
var _viewports: Array[SubViewport] = []


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		failures.append("expected true. " + msg)


func assert_false(cond: bool, msg := "") -> void:
	if cond:
		failures.append("expected false. " + msg)


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("expected <%s> but got <%s>. %s" % [str(expected), str(actual), msg])


func make_game() -> Game:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(640, 360)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(vp)
	_viewports.append(vp)
	var game := Game.new()
	vp.add_child(game)
	game.player.scripted = true
	await frames(3)
	return game


func frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


## Puts the player in front of an entity, camera aimed at it, and presses E.
func use(game: Game, uid: String) -> void:
	await aim_at(game, uid)
	game.player.input.interact = true
	await frames(2)


func aim_at(game: Game, uid: String) -> void:
	var target: Node3D = game.entity(uid)
	var front := target.global_transform.basis.z.normalized() # machines face +Z, away from the wall
	if not (target is Interactable) or target is Props.Pickup:
		# Loose objects: approach from the first side that isn't a wall.
		var cell := LevelBuilder.world_to_cell(target.global_position)
		for dir in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = cell + dir
			if game.map_rows[n.y][n.x] != "#":
				front = Vector3(dir.x, 0, dir.y)
				break
	var pos := target.global_position + front * 1.6
	pos.y = 0.05
	var to_target := target.global_position - pos
	game.player.teleport(pos, atan2(-to_target.x, -to_target.z))
	# The camera sits over the shoulder, so its centre ray is offset from the
	# player's line. Re-aim from the camera's actual position (a few passes).
	for i in 4:
		await frames(1)
		var cam := game.player.camera.global_position
		var d := target.global_position - cam
		game.player.pivot.rotation.y += _angle_to(-game.player.camera.global_transform.basis.z, d)
	await frames(2)


static func _angle_to(forward: Vector3, wanted: Vector3) -> float:
	var a := Vector2(forward.x, forward.z)
	var b := Vector2(wanted.x, wanted.z)
	return -a.angle_to(b)


func cleanup() -> void:
	for vp in _viewports:
		vp.queue_free()
	_viewports.clear()
	await tree.process_frame
