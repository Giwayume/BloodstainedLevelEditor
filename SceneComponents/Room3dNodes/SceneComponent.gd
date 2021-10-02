extends Spatial

var room_3d_display: Spatial
var definition: Dictionary
var is_tree_leaf: bool = false

func _ready():
	if definition.has("translation"):
		translation = definition["translation"]
	if definition.has("rotation_degrees"):
		rotation_degrees = definition["rotation_degrees"]
	if definition.has("scale"):
		scale = definition["scale"]
