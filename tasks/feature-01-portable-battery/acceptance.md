# Acceptance criteria: feature-01

| # | Setup | Action | Expected state | On screen |
|---|-------|--------|----------------|-----------|
| 1 | 3 scrap + 2 wire | craft at workbench | inventory has `{battery, 1, charge 60}` | slot with a full charge bar |
| 2 | 2 batteries in inventory | drag one onto the other | still 2 separate slots | no merge |
| 3 | generator OFF, battery in inventory | use door_2 port | `door_2` powered, `uplink` NOT powered (only that node) | door 2 opens |
| 4 | after 3 | wait 30 s | port charge ≈ 30 ± 0.5 | prompt "Battery: 30 s" |
| 5 | after 3 | wait 61 s | `door_2` unpowered, battery charge 0 | door closes |
| 6 | battery in port at 45 s | take it out | inventory battery charge ≈ 45 | — |
| 7 | battery in a port | save, then load | port and charge restored (± 0.1) | door state matches |
| 8 | a v2 save | load | migrates to v3 with no batteries | — |
| 9 | battery in door_2, generator ON | remove the crate from the plate | `door_2` still powered (from the battery) | — |

## Automated

Add `tests/test_battery.gd` covering 1, 2, 3, 5, 6, 7 and 8, and register it in the runner.
The whole suite must pass, including the walkthrough (the station must still be
completable without batteries).
