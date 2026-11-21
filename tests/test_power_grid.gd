extends TestCase


## gen - relay - lamp, plus a ring A-B-C-D-A hanging off the relay.
func _grid() -> PowerGrid:
	var g := PowerGrid.new()
	g.add_node("gen", "generator", {"running": false})
	g.add_node("relay", "relay", {"intact": true})
	g.add_node("lamp", "light")
	g.add_node("sw", "switch", {"closed": true})
	g.add_node("door", "door")
	for id in ["a", "b", "c", "d"]:
		g.add_node(id, "junction")
	g.connect_nodes("gen", "relay")
	g.connect_nodes("relay", "lamp")
	g.connect_nodes("relay", "a")
	g.connect_nodes("a", "b")
	g.connect_nodes("b", "c")
	g.connect_nodes("c", "d")
	g.connect_nodes("d", "a")
	g.connect_nodes("c", "sw")
	g.connect_nodes("sw", "door")
	g.solve()
	return g


func test_nothing_powered_without_running_generator() -> void:
	var g := _grid()
	for id in g.nodes:
		assert_false(g.is_powered(id), id)


func test_running_generator_powers_everything_reachable() -> void:
	var g := _grid()
	g.set_flag("gen", "running", true)
	for id in ["gen", "relay", "lamp", "a", "b", "c", "d", "sw", "door"]:
		assert_true(g.is_powered(id), id)


func test_broken_relay_is_energised_but_blocks() -> void:
	var g := _grid()
	g.set_flag("relay", "intact", false)
	g.set_flag("gen", "running", true)
	assert_true(g.is_powered("relay"), "the relay itself sees voltage")
	assert_false(g.is_powered("lamp"), "but nothing after it")


func test_open_switch_blocks_downstream_only() -> void:
	var g := _grid()
	g.set_flag("gen", "running", true)
	g.set_flag("sw", "closed", false)
	assert_false(g.is_powered("door"))
	assert_true(g.is_powered("lamp"))


func test_loop_loses_power_when_source_stops() -> void:
	# The ring a-b-c-d must not keep itself alive once the generator stops.
	var g := _grid()
	g.set_flag("gen", "running", true)
	g.set_flag("gen", "running", false)
	for id in ["a", "b", "c", "d", "door", "lamp"]:
		assert_false(g.is_powered(id), "%s still powered after shutdown" % id)


func test_loop_loses_power_when_feeding_relay_breaks() -> void:
	var g := _grid()
	g.set_flag("gen", "running", true)
	g.set_flag("relay", "intact", false)
	for id in ["a", "b", "c", "d"]:
		assert_false(g.is_powered(id), "%s still powered after relay broke" % id)


func test_flags_round_trip() -> void:
	var g := _grid()
	g.set_flag("gen", "running", true)
	g.set_flag("sw", "closed", false)
	var h := _grid()
	h.import_flags(g.export_flags())
	for id in g.nodes:
		assert_eq(h.is_powered(id), g.is_powered(id), id)


func test_station_level_graph_is_valid() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/station.json"))
	var ids := {}
	for n in data["power"]["nodes"]:
		ids[n["id"]] = true
	for e in data["power"]["edges"]:
		assert_true(ids.has(e[0]) and ids.has(e[1]), "edge %s" % str(e))
	for ent in data["entities"]:
		if ent.has("node"):
			assert_true(ids.has(ent["node"]), "entity %s references unknown node %s" % [ent["id"], ent["node"]])
