# Feature request: portable battery

**From:** game designer
**Target build:** `main`

> "I want a second way to get power somewhere: a **portable battery**. You craft it,
> slot it into any powered device with a battery port, and it powers that device by
> itself, generator or not, until it drains. It opens up routes: you could open
> door 2 without the crate if you have a charged battery."

## Requirements

1. **New item** `battery` (`max_stack = 1`) with a **charge** from 0 to 60 seconds. It is
   the first item that carries per-instance state, so the inventory slot stores
   `{ "id": "battery", "count": 1, "charge": 60.0 }`. Stacking rules must never merge
   batteries.
2. **Recipe:** 3 scrap + 2 wire → 1 battery (fully charged).
3. **Battery ports:** entities with `"battery_port": true` in the level file. Make
   `door_2` and `uplink` ports. Interacting with a port inserts the battery from the
   inventory, and interacting again takes it out with its remaining charge.
4. **Power:** an inserted battery acts as a running generator connected **only** to that
   entity's power node. It drains 1 charge per second while inserted and stops at 0.
5. **Save/load:** inventory charge and inserted batteries (which port, how much charge)
   persist. Bump the save version to 3 with a migration from 2.
6. **UI:** inventory slots show a charge bar, and the port prompt shows the remaining
   seconds.

## Out of scope

Recharging. Batteries in ports that aren't listed.
