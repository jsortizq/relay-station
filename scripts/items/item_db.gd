class_name ItemDB
extends RefCounted
## Registry of item and recipe resources.
##
## Paths are listed explicitly (not a folder scan) because exported builds
## remap .tres files. They are loaded lazily on first use instead of with
## const preload(): ItemDB is reachable from scripts that are part of a
## class-reference cycle (Game <-> LevelBuilder <-> Props), and preloading
## resources while their script is still being compiled leaves them without
## a script (they load as plain `Resource`).

const ITEM_PATHS := [
	"res://resources/items/scrap.tres",
	"res://resources/items/wire.tres",
	"res://resources/items/fuse.tres",
	"res://resources/items/fuel_cell.tres",
]
const RECIPE_PATHS := [
	"res://resources/recipes/fuse.tres",
]

static var _items: Array[ItemData] = []
static var _recipes: Array[Recipe] = []


static func items() -> Array[ItemData]:
	if _items.is_empty():
		for p in ITEM_PATHS:
			_items.append(load(p) as ItemData)
	return _items


static func recipes() -> Array[Recipe]:
	if _recipes.is_empty():
		for p in RECIPE_PATHS:
			_recipes.append(load(p) as Recipe)
	return _recipes


static func item(id: String) -> ItemData:
	for it in items():
		if it.id == id:
			return it
	return null


static func max_stack(id: String) -> int:
	var it := item(id)
	return it.max_stack if it != null else 1
