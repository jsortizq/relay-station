class_name Interactable
extends StaticBody3D
## Base for anything the player can use with E. Lives on the "interactable"
## physics layer (and "world" too when it is solid), so the player's
## interaction ray can find it. Subclasses override prompt() and interact().

const LAYER_WORLD := 1
const LAYER_INTERACT := 4

var game: Game
var uid := ""        ## stable id from the level file
var power_node := "" ## PowerGrid node id, if any


func setup(g: Game, id: String, node_id: String, solid := true) -> void:
	game = g
	uid = id
	power_node = node_id
	name = id
	collision_layer = LAYER_INTERACT | (LAYER_WORLD if solid else 0)
	collision_mask = 0


## Text shown under the crosshair, e.g. "E — Insert fuel cell". "" = nothing.
func prompt(_player: Node) -> String:
	return ""


func interact(_player: Node) -> void:
	pass


func is_powered() -> bool:
	return power_node != "" and game.grid.is_powered(power_node)


## Called by Game whenever the power grid is re-solved.
func on_power_changed() -> void:
	pass
