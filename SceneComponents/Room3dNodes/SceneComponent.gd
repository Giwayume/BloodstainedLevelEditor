extends Spatial

var room_3d_display: Spatial
var tree_name: String
var definition: Dictionary
var is_tree_leaf: bool = false
var selection_transform_node: Spatial = null

func _ready():
	selection_transform_node = self
	if definition.has("translation"):
		translation = definition["translation"]
	if definition.has("rotation_degrees"):
		rotation_degrees = definition["rotation_degrees"]
	if definition.has("scale"):
		scale = definition["scale"]
