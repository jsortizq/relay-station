# Tasks

Bug-fix and feature challenges on Relay Station, in the format used for AI-evaluation
tasks: a brief written as a player, designer or producer would write it, reproduction
steps, a reference solution and verifiable success criteria.

| Task | Type | Systems involved | Branch with the problem |
|------|------|------------------|-------------------------|
| [bug-01](bug-01-save-load-duplicates-items/) | Bug fix | Save/load, pickups, inventory, level rebuild | `bug/01-save-load-duplicates-items` |
| [bug-02](bug-02-cargo-bay-stays-powered/) | Bug fix | Power graph, doors, navigation, drone AI | `bug/02-cargo-bay-stays-powered` |
| [feature-01](feature-01-portable-battery/) | Feature | Items with state, power graph, save/load, UI | `main` |

```
brief.md        what the solver receives (symptoms only)
acceptance.md   steps, expected visuals, measurable state, automated checks
solution.md     root cause + reference fix (hidden from the solver)
```

Reproduce any task:

```bash
git checkout <branch>
godot --headless --path . --import
godot --headless --path . --script res://tools/scenario.gd -- <scenario>
godot --headless --path . --script res://tests/run_tests.gd
```

Authoring checklist, applied to every task: visible in normal play · reproducible from
fixed steps · the brief describes symptoms only · success measured on game state · the
reference fix passes all tests and scenarios · played end to end on the bugged branch and
on the fixed branch.
