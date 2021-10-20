extends BaseRoom3dNode

func _init():
	is_tree_leaf = true

func _ready():
	if definition.has("children"):
		for child in definition["children"]:
			if child["type"] == "CapsuleComponent":
				room_3d_display.place_tree_nodes_recursive(self, child)
				selection_transform_node = get_children()[0]

func select():
	.select()
	if selection_transform_node != null:
		selection_transform_node.select()

func deselect():
	.deselect()
	if selection_transform_node != null:
		selection_transform_node.deselect()
