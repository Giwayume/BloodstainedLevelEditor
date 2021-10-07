extends Spatial

var room_3d_display: Spatial
var tree_name: String
var definition: Dictionary
var is_tree_leaf: bool = false
var selection_transform_node: Spatial = null

func _ready():
	if definition.has("children"):
		var root_component_export_index = -1
		if definition.has("root_component_export_index"):
			root_component_export_index = definition["root_component_export_index"]
		var scene_component = null
		for child in definition["children"]:
			if child["export_index"] == root_component_export_index:
				scene_component = child
				break
		if scene_component != null:
			for child in definition["children"]:
				if child["type"] != "SceneComponent":
					scene_component["children"].push_back(child)
			room_3d_display.place_tree_nodes_recursive(self, scene_component)
