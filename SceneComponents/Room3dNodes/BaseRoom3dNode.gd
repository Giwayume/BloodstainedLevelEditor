extends Spatial
class_name BaseRoom3dNode

var room_3d_display: Spatial
var tree_name: String
var definition: Dictionary
var use_parent_as_proxy: bool = false
var leaf_parent: Spatial = null
var selection_transform_node: Spatial = null
var persistent_level_child_ancestor: Spatial = null
var is_tree_leaf: bool = false
var is_in_deleted_branch: bool = false
var is_in_hidden_branch: bool = false
var is_selected: bool = false

func select():
	is_selected = true

func deselect():
	is_selected = false

func set_deleted(deleted: bool):
	is_in_deleted_branch = deleted
	for child in get_children():
		if child.has_method("set_deleted"):
			child.set_deleted(deleted)

func set_hidden(hidden: bool):
	is_in_hidden_branch = hidden
	for child in get_children():
		if child.has_method("set_hidden"):
			child.set_hidden(hidden)
