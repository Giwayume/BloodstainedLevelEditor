extends Spatial

var room_3d_display: Spatial
var definition: Dictionary
var is_tree_leaf: bool = true

var static_mesh_component: Spatial = null

func _ready():
	if definition.has("children"):
		for child in definition["children"]:
			if child["type"] == "StaticMeshComponent":
				room_3d_display.place_tree_nodes_recursive(self, child)
				static_mesh_component = get_children()[0]

func select():
	if static_mesh_component != null:
		static_mesh_component.select()

func deselect():
	if static_mesh_component != null:
		static_mesh_component.deselect()
