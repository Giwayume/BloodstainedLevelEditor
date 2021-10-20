extends BaseRoom3dNode

const blueprint_profiles = preload("res://Config/BlueprintProfiles.gd").blueprint_profiles

var uasset_parser: Node

func _init():
	is_tree_leaf = true

func _ready():
	uasset_parser = get_node("/root/UAssetParser")
	var scene_component = null
	
	if definition.has("children"):
		var root_component_export_index = -1
		if definition.has("root_component_export_index"):
			root_component_export_index = definition["root_component_export_index"]
		for child in definition["children"]:
			if child["export_index"] == root_component_export_index:
				scene_component = child
				break
		if scene_component != null:
			for child in definition["children"]:
				if child["type"] != "SceneComponent":
					scene_component["children"].push_back(child)
			room_3d_display.place_tree_nodes_recursive(self, scene_component)
	
		var children = get_children()
		if children.size() > 0:
			var first_child = children[0]
			if "definition" in first_child and first_child.definition == scene_component:
				selection_transform_node = first_child
	
	var class_asset_file = definition["class_asset_path"]
	if blueprint_profiles.has(class_asset_file):
		var profile = blueprint_profiles[class_asset_file]
		if profile.has("meshes"):
			call_deferred("start_model_load", profile.meshes)
		if profile.has("light_defaults"):
			call_deferred("set_light_defaults", self, profile.light_defaults)

func set_light_defaults(parent: Node, light_defaults: Dictionary):
	for child in parent.get_children():
		if "light_default_overrides" in child:
			for setting in light_defaults:
				child.light_default_overrides[setting] = light_defaults[setting]
				child.set_light_properties(child.definition, true)
		set_light_defaults(child, light_defaults)

func find_child_by_name_and_type(parent: Node, object_name: String, object_type: String):
	var found_child = null
	for child in parent.get_children():
		if "definition" in child:
			if child.definition["name"] == object_name and child.definition["type"] == object_type:
				found_child = child
				break
			else:
				found_child = find_child_by_name_and_type(child, object_name, object_type)
				if found_child != null:
					break
	return found_child

func start_model_load(meshes: Array):
	for load_def in meshes:
		var mesh_load_node = find_child_by_name_and_type(self, load_def.object_name, load_def.object_type)
		if mesh_load_node:
			var filename = Array(load_def.mesh.rsplit("/")).pop_back().replace(".uasset", "")
			var model_definition = {
				"static_mesh_name": filename,
				"static_mesh_name_instance": 0,
				"static_mesh_asset_path": load_def.mesh
			}
			if uasset_parser.AssetPathToPakFilePathMap.has(model_definition.static_mesh_asset_path):
				room_3d_display.load_3d_model(model_definition, mesh_load_node, "on_3d_model_loaded")
			else:
				print_debug("DynamicClass load mesh asset not found: ", load_def.mesh)
		else:
			print_debug("DynamicClass mesh node not found: ", load_def.object_name, " ", load_def.object_type)

func select():
	.select()
	if selection_transform_node != null:
		selection_transform_node.select()

func deselect():
	.deselect()
	if selection_transform_node != null:
		selection_transform_node.deselect()
