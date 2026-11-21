extends TestCase
## max_stack: scrap 10, wire 5, fuse 3, fuel_cell 1


func test_add_fills_stacks_then_new_slots() -> void:
	var inv := Inventory.new(4)
	assert_eq(inv.add("scrap", 7), 0)
	assert_eq(inv.add("scrap", 7), 0)
	assert_eq(inv.slots[0]["count"], 10)
	assert_eq(inv.slots[1]["count"], 4)


func test_add_returns_what_did_not_fit() -> void:
	var inv := Inventory.new(2)
	assert_eq(inv.add("fuel_cell", 3), 1, "two single-stack slots")
	assert_eq(inv.count_of("fuel_cell"), 2)


func test_remove_takes_from_last_stacks_first() -> void:
	var inv := Inventory.new(3)
	inv.add("scrap", 15)
	assert_eq(inv.remove("scrap", 6), 6)
	assert_eq(inv.slots[0]["count"], 9)
	assert_eq(inv.slots[1], null)


func test_move_merge_keeps_remainder_in_source() -> void:
	var inv := Inventory.new(3)
	inv.slots[0] = {"id": "scrap", "count": 8}
	inv.slots[1] = {"id": "scrap", "count": 6}
	inv.move(0, 1)
	assert_eq(inv.slots[1]["count"], 10)
	assert_eq(inv.slots[0]["count"], 4, "remainder must stay, not vanish")
	assert_eq(inv.count_of("scrap"), 14)


func test_move_swaps_different_items() -> void:
	var inv := Inventory.new(2)
	inv.slots[0] = {"id": "scrap", "count": 2}
	inv.slots[1] = {"id": "wire", "count": 1}
	inv.move(0, 1)
	assert_eq(inv.slots[0]["id"], "wire")
	assert_eq(inv.slots[1]["id"], "scrap")


func test_split_needs_room() -> void:
	var inv := Inventory.new(1)
	inv.add("scrap", 6)
	assert_false(inv.split(0))
	var inv2 := Inventory.new(2)
	inv2.add("scrap", 7)
	assert_true(inv2.split(0))
	assert_eq(inv2.slots[0]["count"], 4)
	assert_eq(inv2.slots[1]["count"], 3)


func test_craft_consumes_inputs_and_adds_output() -> void:
	var inv := Inventory.new(4)
	inv.add("scrap", 3)
	inv.add("wire", 1)
	var r: Recipe = ItemDB.recipes()[0]
	assert_true(inv.craft(r))
	assert_eq(inv.count_of("scrap"), 1)
	assert_eq(inv.count_of("wire"), 0)
	assert_eq(inv.count_of("fuse"), 1)


func test_craft_can_use_slots_freed_by_its_inputs() -> void:
	var inv := Inventory.new(2)
	inv.add("scrap", 2)
	inv.add("wire", 1)
	assert_true(inv.craft(ItemDB.recipes()[0]), "full inventory, but the inputs free a slot")


func test_craft_is_atomic_when_output_does_not_fit() -> void:
	var inv := Inventory.new(3)
	inv.add("scrap", 4)  # slot 0
	inv.add("wire", 2)   # slot 1
	inv.slots[2] = {"id": "fuel_cell", "count": 1}
	# Inputs leave scrap 2 and wire 1 in place: no slot frees up, no fuse stack.
	var before := JSON.stringify(inv.to_data())
	assert_false(inv.craft(ItemDB.recipes()[0]))
	assert_eq(JSON.stringify(inv.to_data()), before, "failed craft must not change anything")


func test_random_operations_never_create_or_destroy_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var inv := Inventory.new(6)
	var expected := {"scrap": 0, "wire": 0, "fuse": 0}
	for i in 600:
		var id: String = ["scrap", "wire", "fuse"][rng.randi_range(0, 2)]
		match rng.randi_range(0, 3):
			0:
				var n := rng.randi_range(1, 7)
				expected[id] += n - inv.add(id, n)
			1:
				expected[id] -= inv.remove(id, rng.randi_range(1, 4))
			2:
				inv.move(rng.randi_range(0, 5), rng.randi_range(0, 5))
			3:
				inv.split(rng.randi_range(0, 5))
		for s in inv.slots:
			if s != null and s["count"] > ItemDB.max_stack(s["id"]):
				failures.append("step %d: stack over max: %s" % [i, str(s)])
				return
	for id in expected:
		assert_eq(inv.count_of(id), expected[id], id)


func test_data_round_trip() -> void:
	var inv := Inventory.new(4)
	inv.add("scrap", 12)
	inv.add("fuse", 1)
	var copy := Inventory.new(4)
	copy.from_data(JSON.parse_string(JSON.stringify(inv.to_data())))
	assert_eq(copy.to_data(), inv.to_data())
