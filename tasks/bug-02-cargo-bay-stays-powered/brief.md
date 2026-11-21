# Bug report: pulling the fuel cell doesn't shut down the cargo bay

**Reported by:** level designer
**Build:** branch `bug/02-cargo-bay-stays-powered`
**Severity:** high (breaks the stealth design and the "pull the fuel cell" escape route)

> "Pulling the fuel cell out of the generator is supposed to black out the station.
> The maintenance bay goes dark like it should, but the cargo bay stays fully lit,
> the door between them stays open and the drone keeps patrolling, on zero power.
> It only happens AFTER the relay is fixed. Before that, everything behaves."

## Steps to reproduce

1. Get the fuel cell, insert it into the generator, craft a fuse and repair the relay.
   (With the debug overlay open, F1 shows the power state.)
2. Go back to the generator and press **E** to take the fuel cell out.

## Expected

Every light, both doors and the drone dock lose power. The drone powers down, the
door to the cargo bay closes, and the cargo bay goes dark.

## Actual

Only the maintenance bay light goes off. The four cargo bay lights stay on, door 1 stays
open and the drone keeps patrolling. In the F1 overlay, `powered:` still lists the cargo
bay nodes, and even `gen`.

## Constraints

- The level's wiring is intentional; don't change `levels/station.json`.
