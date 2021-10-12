extends Spatial
class_name BaseRoom3dNode

var room_3d_display: Spatial
var tree_name: String
var definition: Dictionary
var is_tree_leaf: bool = false
var use_parent_as_proxy: bool = false
var selection_transform_node: Spatial = null
var is_in_deleted_branch: bool = false

func select():
	pass

func deselect():
	pass

func set_deleted(deleted: bool):
	is_in_deleted_branch = deleted
	for child in get_children():
		if child.has_method("set_deleted"):
			child.set_deleted(deleted)
