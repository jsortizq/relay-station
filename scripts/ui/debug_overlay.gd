class_name DebugOverlay
extends Control
## F1: text panel (FPS, player, focus, drone FSM + path, grid flags,
## inventory, recent events) plus a 3D overlay drawn with ImmediateMesh:
## power wires (yellow = energised), the drone's current nav path and its
## vision cone.

var game: Game
var _font: Font
var _mesh_instance: MeshInstance3D
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	_mesh_instance.material_override = mat
	game.add_child(_mesh_instance)


func _process(_delta: float) -> void:
	_mesh_instance.visible = visible
	if not visible:
		return
	_draw_3d()
	queue_redraw()


func _node_pos(node_id: String) -> Variant:
	for id in game.entities:
		var n = game.entities[id]
		if is_instance_valid(n) and n.get("power_node") == node_id:
			return (n as Node3D).global_position + Vector3.UP * 2.95
	return null


func _draw_3d() -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for e in game.grid.edges():
		var a = _node_pos(e[0])
		var b = _node_pos(e[1])
		if a == null or b == null:
			continue
		var live := game.grid.is_powered(e[0]) and game.grid.conducts(e[0]) and game.grid.is_powered(e[1])
		live = live or (game.grid.is_powered(e[1]) and game.grid.conducts(e[1]) and game.grid.is_powered(e[0]))
		var col := Color("ffc94d") if live else Color("3a3f4c")
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(a)
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(b)
	var d := game.drone
	if d != null and d.state != Drone.State.OFFLINE:
		var path := d.agent.get_current_navigation_path()
		for i in range(1, path.size()):
			_mesh.surface_set_color(Color("4de1ff"))
			_mesh.surface_add_vertex(path[i - 1] + Vector3.UP * 0.1)
			_mesh.surface_set_color(Color("4de1ff"))
			_mesh.surface_add_vertex(path[i] + Vector3.UP * 0.1)
		var eye := d.global_position + Vector3.UP * Drone.EYE_HEIGHT
		var col: Color = Color("ff4d4d") if d.sees_player else Color("ffc94d")
		for s in [-1.0, 1.0]:
			_mesh.surface_set_color(col)
			_mesh.surface_add_vertex(eye)
			_mesh.surface_set_color(col)
			_mesh.surface_add_vertex(eye + d.facing.rotated(Vector3.UP, s * Drone.HALF_FOV) * Drone.VIEW_RANGE_LIT)
	_mesh.surface_end()


func _draw() -> void:
	var p := game.player
	var d := game.drone
	var lines := PackedStringArray([
		"DEBUG  FPS %d  state %s" % [Engine.get_frames_per_second(), ["PLAYING", "WON"][game.state]],
		"player (%.1f, %.1f, %.1f) vel %.1f  on_floor %s  lit %s" % [p.global_position.x, p.global_position.y, p.global_position.z, p.velocity.length(), p.is_on_floor(), game.is_lit(p.global_position)],
		"focus: %s   held: %s   camera arm %.2f m" % [p.focused.name if p.focused else "-", p.held.name if p.held else "-", p.arm.get_hit_length()],
	])
	if d != null:
		lines.append("drone %s  sees %s  timer %.1f  route %d  path %d pts  target (%.1f, %.1f)" % [d.state_name(), d.sees_player, d.timer, d.route_index, d.agent.get_current_navigation_path().size(), d.agent.target_position.x, d.agent.target_position.z])
	var flags := []
	for id in game.grid.nodes:
		if not game.grid.nodes[id]["flags"].is_empty():
			flags.append("%s:%s" % [id, JSON.stringify(game.grid.nodes[id]["flags"])])
	lines.append("grid " + "  ".join(flags))
	var powered := []
	for id in game.grid.powered:
		if game.grid.powered[id]:
			powered.append(id)
	lines.append("powered: " + ", ".join(powered))
	lines.append("inventory: %s" % JSON.stringify(game.inventory.to_data()))
	lines.append("collected: %s" % ", ".join(game.collected.keys()))
	for e in game.events:
		lines.append("  " + e)
	var h := 18.0 * lines.size() + 14.0
	var x := get_viewport_rect().size.x - 720.0
	draw_rect(Rect2(x, 16, 704, h), Color(0.02, 0.03, 0.05, 0.85))
	draw_rect(Rect2(x, 16, 704, h), Color("4de1ff"), false, 1.0)
	for i in lines.size():
		draw_string(_font, Vector2(x + 10, 34 + i * 18), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 690, 12, Color("d7deea"))
