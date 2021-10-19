extends BaseRoom3dNode

var uasset_parser: Node

var main_skeletal_mesh: Spatial = null

func _init():
	is_tree_leaf = true

func _ready():
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
		var character_id_lower = character_id.to_lower()
		if uasset_parser.CharacterMeshAssetPathMap.has(character_id):
			var mesh_assets = uasset_parser.CharacterMeshAssetPathMap[character_id]
			var highest_scoring_filename = null
			var highest_score = -INF
			for mesh_asset in mesh_assets:
				var filename = Array(mesh_asset.rsplit("/")).pop_back().replace(".uasset", "")
				var filename_lower = filename.to_lower()
				var score = 0
				if "body" in filename_lower:
					score += 3
				if "core" in filename_lower:
					score += 4
				if character_id_lower == filename_lower:
					score += 3
				elif character_id_lower in filename_lower:
					score += 1
				if "physics" in filename_lower:
					score -= 4
				if "skeleton" in filename_lower:
					continue
				if "physicsasset" in filename_lower:
					continue
				if score > highest_score:
					highest_scoring_filename = filename
					highest_score = score
			if highest_scoring_filename != null:
				var model_definition = {
					"static_mesh_name": highest_scoring_filename,
					"static_mesh_name_instance": 0,
					"static_mesh_asset_path": "BloodstainedRotN/Content/Core/Character/" + character_id + "/Mesh/" + highest_scoring_filename + ".uasset"
				}
				if uasset_parser.AssetPathToPakFilePathMap.has(model_definition.static_mesh_asset_path):
					room_3d_display.load_3d_model(model_definition, self, "on_3d_model_loaded")

func on_3d_model_loaded(new_loaded_model):
	var model_placement_parent = self
	if main_skeletal_mesh != null:
		main_skeletal_mesh.on_3d_model_loaded(new_loaded_model)

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
