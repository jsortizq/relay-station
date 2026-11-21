# Reference solution: feature-01

> Status: **design notes only, implementation pending** (branch `feature/01-portable-battery`).

## Touch points

| System | Change |
|--------|--------|
| `resources/items/battery.tres`, `recipes/battery.tres`, `ItemDB` paths | new resources |
| `Inventory` | slots may carry extra keys (`charge`). `_add_quiet` and `move` never merge items with `max_stack == 1`. `to_data` / `from_data` keep the extra keys. Add `add_instance(slot_dict)` for items with state |
| `PowerGrid` | `add_source(id, node_id)` / `remove_source(id)`: a battery is a temporary generator node with one edge. The full re-solve keeps the result correct |
| `Machines.BatteryPort` behaviour | attached to entities with `battery_port`; `interact` inserts or removes; `_physics_process` drains and removes the source at 0 |
| `SaveSystem` | `VERSION = 3`; `batteries: { port_uid: charge }`; `migrate()` from 2 → 3 sets `{}` |
| `InventoryUI` | charge bar per slot (child `ProgressBar`) |
| Debug overlay | list inserted batteries with their charge |

## Edge cases to cover

- Draining happens on the physics tick, so the charge doesn't depend on frame rate.
- Loading a save rebuilds the world: re-create the battery sources **after** `rebuild_world()`.
- A battery removed at charge 0 is still an item (empty), not deleted.
