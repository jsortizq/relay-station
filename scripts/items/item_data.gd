class_name ItemData
extends Resource
## Static definition of an item type. Instances in the world or in the
## inventory only store the id and a count.

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var max_stack := 1
@export var color := Color.WHITE
