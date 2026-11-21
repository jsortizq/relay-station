# Bug report: loading a save duplicates items

**Reported by:** playtester (speedrun Discord)
**Build:** branch `bug/01-save-load-duplicates-items`
**Severity:** critical (an item-duplication exploit, and the station puzzle becomes trivial)

> "Found a dupe. Pick up the fuel cell, press K, press L. The fuel cell is in my
> inventory AND lying on the floor where it was. Grab it again and now I have
> two. Works with scrap too, so you can farm infinite fuses."

## Steps to reproduce

1. Start a new game.
2. Pick up the **fuel cell** in the maintenance bay (south-east corner) and the **scrap** along the same south wall.
3. Press **K** (save), then **L** (load).
4. Look at where the items were, and open the inventory (**Tab**).

## Expected

Anything you've picked up stays gone after loading, and the inventory matches what it was
at the moment of the save.

## Actual

Every pickup you've collected is back in the world, and your inventory still has them.
You can pick them up again, which doubles them. Repeating the save/load multiplies them.

## Constraints

- Saves made before the fix don't have to be repaired.
- Don't change the save file version for this fix.
