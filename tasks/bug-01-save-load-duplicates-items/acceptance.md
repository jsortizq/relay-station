# Acceptance criteria: bug-01

## A. Scenario (must change)

```bash
godot --headless --path . --script res://tools/scenario.gd -- save_duplication
```

| Measurement | Bugged | Expected |
|-------------|--------|----------|
| inventory before save | scrap 1, fuel cells 1 | scrap 1, fuel cells 1 |
| pickups back in the world after load | `["scrap_1", "fuel_cell_1"]` | `[]` |
| inventory after re-collecting | **scrap 2, fuel cells 2** | scrap 1, fuel cells 1 |
| exit code | 1 | 0 |

## B. On screen

After K → L, the spots where the fuel cell (cell 7,5) and the scrap (cell 4,5) were stay
empty. F1 → `collected:` lists `scrap_1, fuel_cell_1`, the stable level ids.

## C. Save file

`user://relay_station_save.json` → `"collected"` contains level ids (`"fuel_cell_1"`), not
numbers.

## D. Regression (must NOT change)

| Behaviour | Check |
|-----------|-------|
| v1 saves still migrate (their `collected` list uses level ids) | `test_v1_save_is_migrated` |
| Doors and lights are recomputed after load | `test_derived_state_is_recomputed_after_load` |
| Crates are restored | `test_crate_position_is_restored` |

## E. Automated

`tests/run_tests.gd` → 0 failed. Before the fix: `test_collected_pickup_stays_collected_after_load`,
`test_save_load_cannot_duplicate_items` and `test_v1_save_is_migrated` fail.
