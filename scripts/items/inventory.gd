class_name Inventory
extends RefCounted
## Fixed-size slot inventory with stacking. Pure logic, no nodes, so every
## rule is unit-tested. A slot is either null or { "id": String, "count": int }.
##
## Invariants (checked by tests):
##  * no slot ever exceeds its item's max_stack
##  * items are never created or destroyed by moving them around
##  * crafting is atomic: it either fully succeeds or changes nothing

signal changed

var slots: Array = []


func _init(size := 8) -> void:
	slots.resize(size)


func size() -> int:
	return slots.size()


func count_of(id: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s["id"] == id:
			n += s["count"]
	return n


func total_items() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += s["count"]
	return n


## Adds up to `count` items. Fills existing stacks first, then empty slots.
## Returns how many did NOT fit (0 = all added).
func add(id: String, count: int) -> int:
	var left := _add_quiet(id, count)
	changed.emit()
	return left


func _add_quiet(id: String, count: int) -> int:
	var cap := ItemDB.max_stack(id)
	var left := count
	for s in slots:
		if left <= 0:
			break
		if s != null and s["id"] == id and s["count"] < cap:
			var moved := mini(cap - s["count"], left)
			s["count"] += moved
			left -= moved
	for i in slots.size():
		if left <= 0:
			break
		if slots[i] == null:
			var moved := mini(cap, left)
			slots[i] = {"id": id, "count": moved}
			left -= moved
	return left


## How many of `id` could be added right now.
func space_for(id: String) -> int:
	var cap := ItemDB.max_stack(id)
	var n := 0
	for s in slots:
		if s == null:
			n += cap
		elif s["id"] == id:
			n += cap - s["count"]
	return n


## Removes up to `count`; returns how many were removed.
func remove(id: String, count: int) -> int:
	var removed := _remove_quiet(id, count)
	changed.emit()
	return removed


func _remove_quiet(id: String, count: int) -> int:
	var left := count
	for i in range(slots.size() - 1, -1, -1):
		var s = slots[i]
		if left <= 0:
			break
		if s != null and s["id"] == id:
			var taken := mini(s["count"], left)
			s["count"] -= taken
			left -= taken
			if s["count"] == 0:
				slots[i] = null
	return count - left


## Drag & drop: move slot `from` onto slot `to`.
##  * empty target      -> move
##  * same item         -> merge up to max_stack, remainder stays in `from`
##  * different item    -> swap
func move(from: int, to: int) -> void:
	if from == to or slots[from] == null:
		return
	var a: Dictionary = slots[from]
	var b = slots[to]
	if b == null:
		slots[to] = a
		slots[from] = null
	elif b["id"] == a["id"]:
		var cap := ItemDB.max_stack(a["id"])
		var moved := mini(cap - b["count"], a["count"])
		b["count"] += moved
		a["count"] -= moved
		if a["count"] == 0:
			slots[from] = null
	else:
		slots[to] = a
		slots[from] = b
	changed.emit()


## Splits half of a stack into the first empty slot. Returns false if no room.
func split(index: int) -> bool:
	var s = slots[index]
	if s == null or s["count"] < 2:
		return false
	var empty := slots.find(null)
	if empty == -1:
		return false
	var half: int = s["count"] / 2
	s["count"] -= half
	slots[empty] = {"id": s["id"], "count": half}
	changed.emit()
	return true


func can_craft(r: Recipe) -> bool:
	for id in r.inputs:
		if count_of(id) < int(r.inputs[id]):
			return false
	# Space check happens on a copy, after the inputs are taken out: crafting
	# 2 scrap + 1 wire into a fuse frees slots that the fuse can use.
	var trial := Inventory.new(slots.size())
	trial.slots = _copy_slots()
	for id in r.inputs:
		trial._remove_quiet(id, int(r.inputs[id]))
	return trial.space_for(r.output_id) >= r.output_count


## Atomic: returns false and changes nothing if it can't fully succeed.
func craft(r: Recipe) -> bool:
	if not can_craft(r):
		return false
	for id in r.inputs:
		_remove_quiet(id, int(r.inputs[id]))
	_add_quiet(r.output_id, r.output_count)
	changed.emit()
	return true


func _copy_slots() -> Array:
	var out := []
	for s in slots:
		out.append(null if s == null else (s as Dictionary).duplicate())
	return out


func to_data() -> Array:
	return _copy_slots()


func from_data(data: Array) -> void:
	slots.clear()
	slots.resize(data.size())
	for i in data.size():
		var s = data[i]
		slots[i] = null if s == null else {"id": str(s["id"]), "count": int(s["count"])}
	changed.emit()
