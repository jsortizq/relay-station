# Acceptance criteria: bug-02

## A. Scenario (must change)

```bash
godot --headless --path . --script res://tools/scenario.gd -- generator_shutdown
```

| Measurement | Bugged | Expected |
|-------------|--------|----------|
| powered before removing the cell | gen, relay_a, light_a, door_1, light_b1-4, sec_switch, dock, plate | same |
| **still powered after removing it** | gen, relay_a, door_1, light_b1-4, sec_switch, dock, plate | **nothing** |
| drone state | PATROL | OFFLINE |
| exit code | 1 | 0 |

## B. On screen

Taking the fuel cell turns off every ceiling light in both rooms. Door 1 slides shut, and
the drone sinks to the floor with its eye dark. With F1 open, every power wire turns grey.

## C. Regression (must NOT change)

| Behaviour | Check |
|-----------|-------|
| A broken relay is energised but blocks | `test_broken_relay_is_energised_but_blocks` |
| An open switch only cuts what's downstream | `test_open_switch_blocks_downstream_only` |
| Reinserting the cell powers everything again | `test_generator_needs_fuel_cell`, walkthrough |
| Closed door → drone can't route through it | `test_closed_door_forces_reroute` |

## D. Automated

`tests/run_tests.gd` → 0 failed. Before the fix it fails: `test_loop_loses_power_when_source_stops`,
`test_loop_loses_power_when_feeding_relay_breaks`, `test_removing_fuel_cell_shuts_everything_down`,
`test_door_opens_and_closes_with_power` and `test_darkness_shortens_vision`.
