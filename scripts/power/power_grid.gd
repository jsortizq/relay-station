class_name PowerGrid
extends RefCounted
## The station's electrical network as an undirected graph.
##
## Nodes have a type and a few flags; edges are wires. Power flows from any
## RUNNING generator through nodes that CONDUCT:
##   generator  conducts only while fuelled ("running")
##   relay      conducts only while repaired ("intact")
##   switch     conducts only while "closed" (levers, pressure plates)
##   everything else (junction, light, door, dock, uplink) always conducts
##
## solve() updates the network whenever a flag changes.

signal changed

const CONDUCTING_ALWAYS := ["junction", "light", "door", "dock", "uplink"]

var nodes := {}   # id -> { "type": String, "flags": Dictionary }
var _adj := {}    # id -> Array[String]
var powered := {} # id -> bool (result of the last solve)


func add_node(id: String, type: String, flags := {}) -> void:
	nodes[id] = {"type": type, "flags": flags.duplicate()}
	_adj[id] = []
	powered[id] = false


func connect_nodes(a: String, b: String) -> void:
	assert(nodes.has(a) and nodes.has(b), "Unknown node in edge %s-%s" % [a, b])
	if not _adj[a].has(b):
		_adj[a].append(b)
		_adj[b].append(a)


func neighbours(id: String) -> Array:
	return _adj[id]


func edges() -> Array:
	var out := []
	for a in _adj:
		for b in _adj[a]:
			if a < b:
				out.append([a, b])
	return out


func type_of(id: String) -> String:
	return nodes[id]["type"]


func get_flag(id: String, flag: String, default: Variant = false) -> Variant:
	return nodes[id]["flags"].get(flag, default)


## Change a flag ("running", "intact", "closed") and re-solve.
func set_flag(id: String, flag: String, value: Variant) -> void:
	if nodes[id]["flags"].get(flag) == value:
		return
	nodes[id]["flags"][flag] = value
	solve()


func is_powered(id: String) -> bool:
	return powered.get(id, false)


func conducts(id: String) -> bool:
	match type_of(id):
		"generator":
			return get_flag(id, "running")
		"relay":
			return get_flag(id, "intact")
		"switch":
			return get_flag(id, "closed")
		_:
			return CONDUCTING_ALWAYS.has(type_of(id))


func solve() -> void:
	# Relax from the previous result until nothing changes: a node is
	# powered if it is a running generator or touches a powered conductor.
	# Cheaper than a full BFS when only one flag changed.
	var dirty := true
	while dirty:
		dirty = false
		for id in nodes:
			var on: bool = type_of(id) == "generator" and get_flag(id, "running")
			if not on:
				for nxt in _adj[id]:
					if powered[nxt] and conducts(nxt):
						on = true
						break
			if on != powered[id]:
				powered[id] = on
				dirty = true
	changed.emit()


## Flags only (topology comes from the level file). Used by save/load.
func export_flags() -> Dictionary:
	var out := {}
	for id in nodes:
		if not nodes[id]["flags"].is_empty():
			out[id] = nodes[id]["flags"].duplicate()
	return out


func import_flags(data: Dictionary) -> void:
	for id in data:
		if nodes.has(id):
			nodes[id]["flags"] = (data[id] as Dictionary).duplicate()
	solve()
