extends Node

var room_3d_display: Spatial
var tree_name: String
var definition: Dictionary
var is_tree_leaf: bool = false
var selection_transform_node: Spatial = null

func set_deleted(deleted: bool):
	for child in get_children():
		if child.has_method("set_deleted"):
			child.set_deleted(deleted)
