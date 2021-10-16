extends BaseRoom3dNode

var uasset_parser: Node

var loaded_model: Spatial
var loaded_model_mesh_instance: MeshInstance
var loaded_model_mesh: Mesh
var main_skeletal_mesh: Spatial = null

func _ready():
	# is_tree_leaf = true
	
	uasset_parser = get_node("/root/UAssetParser")
	
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
		for child in get_children():
			if "definition" in child and child.definition == scene_component:
				selection_transform_node = child
				break
	call_deferred("start_model_load")

func start_model_load():
	if definition.has("character_id"):
		var character_id = definition.character_id
		var try_filenames = [character_id, "SK_" + character_id + "_Body", "SK_" + character_id + "_body", "SK_" + character_id]
		for filename in try_filenames:
			var model_definition = {
				"static_mesh_name": filename,
				"static_mesh_name_instance": 0,
				"static_mesh_asset_path": "BloodstainedRotN/Content/Core/Character/" + character_id + "/Mesh/" + filename + ".uasset"
			}
			if uasset_parser.AssetPathToPakFilePathMap.has(model_definition.static_mesh_asset_path):
				room_3d_display.load_3d_model(model_definition, self, "on_3d_model_loaded")
				break

func on_3d_model_loaded(new_loaded_model):
	var model_placement_parent = self
	if main_skeletal_mesh != null:
		model_placement_parent = main_skeletal_mesh
		loaded_model = new_loaded_model
		model_placement_parent.add_child(loaded_model)
		loaded_model.name = "Model3D"
		if is_in_deleted_branch:
			hide()
		for child_node in loaded_model.get_children():
			if child_node is MeshInstance:
				loaded_model_mesh_instance = child_node
				var mesh = child_node.mesh
				loaded_model_mesh = mesh
				break

func load_character_image():
	if definition.has("character_id") and selection_transform_node:
		var image = Image.new()
		var err = image.load("res://Icons/Characters/" + definition.character_id + ".png")
		if err == OK:
			var texture = ImageTexture.new()
			texture.create_from_image(image, 0)
			var sprite3d = Sprite3D.new()
			sprite3d.texture = texture
			sprite3d.billboard = SpatialMaterial.BILLBOARD_ENABLED
			selection_transform_node.add_child(sprite3d)
			sprite3d.name = "CharacterSprite"
			

func select():
	.select()
	if selection_transform_node != null:
		selection_transform_node.select()

func deselect():
	.deselect()
	if selection_transform_node != null:
		selection_transform_node.deselect()
