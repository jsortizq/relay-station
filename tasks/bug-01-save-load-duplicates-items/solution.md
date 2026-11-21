# Reference solution: bug-01

## Root cause

Loading a save calls `Game.rebuild_world()`, which frees every level node and creates new
ones from `levels/station.json`. Then `remove_collected_pickups()` deletes the pickups the
save lists as collected.

On this branch, pickups are recorded by **instance id**:

```gdscript
collected[str(p.get_instance_id())] = true              # Game.collect
...
if n is Props.Pickup and collected.has(str(n.get_instance_id())):   # remove_collected_pickups
```

Instance ids are unique per object **for one run of the level**. The rebuilt pickups are
new objects with new ids, so nothing matches, every pickup respawns, and the restored
inventory still holds the originals.

The same failure would happen with `node.name` (auto-generated names such as
`@StaticBody3D@23` change when the scene is rebuilt) or with child indices (they change
when a level designer adds an entity).

## Fix

Use the stable id that every entity already has in the level file (`Interactable.uid`,
e.g. `"fuel_cell_1"`):

```diff
-	collected[str(p.get_instance_id())] = true
+	collected[p.uid] = true
...
-		if n is Props.Pickup and collected.has(str(n.get_instance_id())):
+		if n is Props.Pickup and collected.has(n.uid):
```

`git diff bug/01-save-load-duplicates-items main -- scripts/core/game.gd`

## Why this fix

- A level-file id survives rebuilds, game restarts and new builds, and it's what the
  level designer sees.
- The v1 migration already stores ids in that format, so old saves work again too
  (`test_v1_save_is_migrated` was failing on the bugged branch).

## Verification done

- `scenario save_duplication` → PASS: nothing respawns, inventory 1/1.
- Test suite: 43 / 43.
