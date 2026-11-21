class_name LevelBuilder
extends RefCounted
## Builds the 3D station from levels/*.json.
##
## Geometry: one floor slab + wall boxes merged per row (fewer bodies).
## Navigation: the navmesh is generated directly from the grid instead of
## being baked: every walkable cell becomes a quad polygon. Door cells get
## their OWN NavigationRegion3D whose quad shares edges with the cells next
## to it, so Godot connects the regions automatically, and a closed door
## just disables its region (no re-bake, no NavigationObstacle hacks).

const CELL := 2.0


static func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL + CELL * 0.5, 0.0, c.y * CELL + CELL * 0.5)


static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


static func build(game: Game, data: Dictionary, root: Node3D) -> void:
	var rows := PackedStringArray(data["map"])
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	var h := rows.size()
	var wall_h: float = data.get("wall_height", 3.0)
	game.map_rows = rows

	# --- floor
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	var fsize := Vector3(w * CELL, 0.2, h * CELL)
	var fcs := Mats.box_shape(fsize)
	fcs.position = Vector3(fsize.x / 2, -0.1, fsize.z / 2)
	floor_body.add_child(fcs)
	var fmesh := Mats.mesh_box(fsize, Mats.solid(Color("2a2f3a"), 0.9))
	fmesh.position = fcs.position
	floor_body.add_child(fmesh)
	root.add_child(floor_body)

	# --- ceiling (keeps the third-person camera inside the rooms: the spring
	# arm collides with it instead of rising above the walls)
	var ceiling := StaticBody3D.new()
	ceiling.name = "Ceiling"
	ceiling.collision_layer = 1
	var ccs := Mats.box_shape(fsize)
	ccs.position = Vector3(fsize.x / 2, wall_h + 0.1, fsize.z / 2)
	ceiling.add_child(ccs)
	var cmesh := Mats.mesh_box(fsize, Mats.solid(Color("1c2029"), 0.95))
	cmesh.position = ccs.position
	ceiling.add_child(cmesh)
	root.add_child(ceiling)

	# --- walls (run-length merged per row)
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	root.add_child(walls)
	var wall_mat := Mats.solid(Color("454c5e"), 0.85)
	for y in h:
		var x := 0
		while x < w:
			if _ch(rows, x, y) != "#":
				x += 1
				continue
			var start := x
			while x < w and _ch(rows, x, y) == "#":
				x += 1
			var size := Vector3((x - start) * CELL, wall_h, CELL)
			var pos := Vector3(start * CELL + size.x / 2, wall_h / 2, y * CELL + CELL / 2)
			var cs := Mats.box_shape(size)
			cs.position = pos
			walls.add_child(cs)
			var m := Mats.mesh_box(size, wall_mat)
			m.position = pos
			walls.add_child(m)

	# --- navigation
	var door_cells := {}
	for e in data["entities"]:
		if e["type"] == "door":
			door_cells[Vector2i(e["cell"][0], e["cell"][1])] = e["id"]
	var main_cells: Array[Vector2i] = []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if _ch(rows, x, y) != "#" and not door_cells.has(c):
				main_cells.append(c)
	var main_region := NavigationRegion3D.new()
	main_region.name = "NavMain"
	main_region.navigation_mesh = navmesh_for(main_cells)
	root.add_child(main_region)

	# --- entities
	for e in data["entities"]:
		var c := Vector2i(e["cell"][0], e["cell"][1])
		var pos := cell_center(c)
		var node: Node3D = null
		match e["type"]:
			"generator":
				node = Machines.Generator.new()
			"relay":
				node = Machines.Relay.new()
			"lever":
				node = Machines.Lever.new()
			"workbench":
				node = Machines.Workbench.new()
			"uplink":
				node = Machines.Uplink.new()
			"dock":
				node = Machines.Dock.new()
			"pickup":
				var p := Props.Pickup.new()
				p.item_id = e["item"]
				p.count = int(e.get("count", 1))
				node = p
			"light":
				var l := Fixtures.LightFixture.new()
				l.game = game
				l.power_node = e["node"]
				node = l
			"door":
				var d := Fixtures.Door.new()
				d.game = game
				d.power_node = e["node"]
				d.uid = e["id"]
				d.horizontal = _ch(rows, c.x - 1, c.y) == "#" and _ch(rows, c.x + 1, c.y) == "#"
				var region := NavigationRegion3D.new()
				region.name = "Nav_" + e["id"]
				region.navigation_mesh = navmesh_for([c])
				region.enabled = false
				root.add_child(region)
				d.nav_region = region
				node = d
			"plate":
				var pp := Fixtures.PressurePlate.new()
				pp.game = game
				pp.power_node = e["node"]
				node = pp
			"crate":
				var cr := Props.Crate.new()
				cr.uid = e["id"]
				pos.y = 0.46
				node = cr
			"drone":
				var dr: Drone = load("res://scenes/drone.tscn").instantiate()
				dr.game = game
				var route: Array[Vector3] = []
				for wp in e["route"]:
					route.append(cell_center(Vector2i(wp[0], wp[1])))
				dr.route = route
				dr.dock_id = e.get("dock", "")
				node = dr
		if node == null:
			push_error("Unknown entity type %s" % e["type"])
			continue
		if node is Interactable:
			(node as Interactable).setup(game, e["id"], e.get("node", ""), not (node is Props.Pickup))
		node.name = e["id"]
		node.position = pos
		# Face machines away from the nearest wall, toward the room.
		if node is Interactable and not (node is Props.Pickup):
			node.rotation.y = _facing_away_from_wall(rows, c)
		root.add_child(node)
		game.register_entity(e["id"], node)


## Navmesh made of one quad per cell. Shared corner vertices make adjacent
## cells (and adjacent regions) connect edge-to-edge.
static func navmesh_for(cells: Array[Vector2i]) -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.4
	nm.cell_size = 0.25
	var verts := PackedVector3Array()
	var index := {}
	var polys: Array[PackedInt32Array] = []
	for c in cells:
		var poly := PackedInt32Array()
		for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var k: Vector2i = c + corner
			if not index.has(k):
				index[k] = verts.size()
				verts.append(Vector3(k.x * CELL, 0.0, k.y * CELL))
			poly.append(index[k])
		polys.append(poly)
	nm.vertices = verts
	for p in polys:
		nm.add_polygon(p)
	return nm


static func _ch(rows: PackedStringArray, x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return "#"
	return rows[y][x]


static func _facing_away_from_wall(rows: PackedStringArray, c: Vector2i) -> float:
	# Model front is +Z. Rotate so +Z points away from an adjacent wall.
	if _ch(rows, c.x, c.y - 1) == "#":
		return 0.0          # wall north -> face south (+Z)
	if _ch(rows, c.x, c.y + 1) == "#":
		return PI           # wall south -> face north
	if _ch(rows, c.x - 1, c.y) == "#":
		return PI / 2       # wall west -> face east
	if _ch(rows, c.x + 1, c.y) == "#":
		return -PI / 2      # wall east -> face west
	return 0.0
