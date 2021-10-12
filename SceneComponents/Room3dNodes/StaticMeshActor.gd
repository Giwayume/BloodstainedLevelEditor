extends Spatial

var room_3d_display: Spatial
var tree_name: String
var definition: Dictionary
var is_tree_leaf: bool = true
var selection_transform_node: Spatial = null

func _ready():
	if definition.has("children"):
		for child in definition["children"]:
			if child["type"] == "StaticMeshComponent":
				room_3d_display.place_tree_nodes_recursive(self, child)
				selection_transform_node = get_children()[0]

func select():
	if selection_transform_node != null:
		selection_transform_node.select()

func deselect():
	if selection_transform_node != null:
		selection_transform_node.deselect()

func set_deleted(deleted: bool):
	for child in get_children():
		if child.has_method("set_deleted"):
			child.set_deleted(deleted)
