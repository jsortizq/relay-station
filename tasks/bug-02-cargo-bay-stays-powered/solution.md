# Reference solution: bug-02

## Root cause

On this branch, `PowerGrid.solve()` was "optimised" into an incremental relaxation that
starts from the **previous** result:

```gdscript
# a node is powered if it is a running generator or touches a powered conductor
while dirty:
	for id in nodes:
		var on = is_running_generator(id)
		if not on:
			for nxt in neighbours(id):
				if powered[nxt] and conducts(nxt): on = true
		...
```

That works when power is added. It fails when power is removed **if the graph has a
cycle**. The cargo bay lights are wired as a ring (`light_b1 → b2 → b3 → b4 → b1`).
Once the generator stops, every light in the ring still has a powered, conducting
neighbour, namely the next light, so none of them ever turns off. The ring powers itself,
and from there it keeps `relay_a`, `door_1`, the security switch, the dock and even `gen`
"powered".

This only shows up after the relay is repaired, because before that the ring was never
powered in the first place.

## Fix

Recompute from scratch: reset every node, then run a breadth-first search from each
running generator through conducting nodes (that's the version on `main`):

```gdscript
func solve() -> void:
	for id in powered:
		powered[id] = false
	var frontier: Array[String] = []
	for id in nodes:
		if type_of(id) == "generator" and get_flag(id, "running"):
			powered[id] = true
			frontier.append(id)
	while not frontier.is_empty():
		var cur: String = frontier.pop_front()
		if not conducts(cur):
			continue
		for nxt in _adj[cur]:
			if not powered[nxt]:
				powered[nxt] = true
				frontier.append(nxt)
	changed.emit()
```

`git diff bug/02-cargo-bay-stays-powered main -- scripts/power/power_grid.gd`

## Why not keep it incremental

The grid has 14 nodes and changes a few times per minute, so a full BFS costs microseconds.
A correct incremental "remove power" needs reachability tracking (for example, recompute
the component the change touched), which is more code for no measurable gain. The comment
at the top of `power_grid.gd` explains this so it doesn't get "optimised" again.

## Verification done

- `scenario generator_shutdown` → PASS: nothing stays powered, the drone goes OFFLINE.
- Test suite: 43 / 43.
