extends Spatial

signal loading_start
signal loading_end
signal selection_changed
signal view_gizmo_toggled

const light_defaults = preload("res://Config/LightDefaults.gd").light_defaults;

var custom_component_scripts = {
	"BlueprintGeneratedClass": {
		"auto_placement": false,
		"script": preload("res://SceneComponents/Room3dNodes/BlueprintGeneratedClass.gd")
	},
	"CapsuleComponent": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/CapsuleComponent.gd")
	},
	"Character": {
		"auto_placement": false,
		"script": preload("res://SceneComponents/Room3dNodes/Character.gd")
	},
	"DirectionalLight": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/DirectionalLight.gd")
	},
	"DirectionalLightComponent": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/DirectionalLightComponent.gd")
	},
	"DynamicClass": {
		"auto_placement": false,
		"script": preload("res://SceneComponents/Room3dNodes/DynamicClass.gd")
	},
	"EventRootComponent": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/EventRootComponent.gd")
	},
	"PBMeshParentComponent": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/PBMeshParentComponent.gd")
	},
	"PointLight": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/PointLight.gd")
	},
	"PointLightComponent": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/PointLightComponent.gd")
	},
	"SceneComponent": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/SceneComponent.gd")
	},
	"SkeletalMeshComponent": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/SkeletalMeshComponent.gd")
	},
	"SpotLight": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/SpotLight.gd")
	},
	"SpotLightComponent": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/SpotLightComponent.gd")
	},
	"StaticMeshActor": {
		"auto_placement": false,
		"script": preload("res://SceneComponents/Room3dNodes/StaticMeshActor.gd")
	},
	"StaticMeshComponent": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/StaticMeshComponent.gd")
	},
	"Unknown": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/Unknown.gd")
	}
}

var editor: Node
var uasset_parser: Node

var extract_3d_model_thread: Thread = null
var is_extracting_3d_models: bool = false

var asset_roots: Dictionary = {}
var camera: Camera

var gltf_loader: DynamicGLTFLoader
var cached_models: Dictionary

# Updated by RoomEdit.gd
var can_capture_mouse: bool = false
var can_capture_keyboard: bool = false
var can_select: bool = true
var room_definition: Dictionary

var already_placed_exports: Dictionary = {}
var current_placing_tree_name: String = ""
var model_load_waitlist: Array = []
var current_waitlist_item: Dictionary
var selected_nodes: Array

var is_mouse_button_left_down: bool = false
var is_mouse_button_right_down: bool = false
var is_shift_modifier_pressed: bool = false

#############
# LIFECYCLE #
#############

func _ready():
	editor = get_node("/root/Editor")
	uasset_parser = get_node("/root/UAssetParser")
	gltf_loader = DynamicGLTFLoader.new()
	
	asset_roots = {
		"bg": $AssetTrees/bg,
		"enemy": $AssetTrees/enemy,
		"enemy_hard": $AssetTrees/enemy_hard,
		"enemy_normal": $AssetTrees/enemy_normal,
		"event": $AssetTrees/event,
		"gimmick": $AssetTrees/gimmick,
		"light": $AssetTrees/light,
		"setting": $AssetTrees/setting,
		"rv": $AssetTrees/rv
	}
	camera = get_node("Camera")

func _input(event):
	# Object selection
	if can_capture_mouse and event is InputEventMouseButton:
		match event.button_index:
			BUTTON_LEFT:
				is_mouse_button_left_down = event.pressed
				if event.pressed and not is_mouse_button_right_down:
					call_deferred("select_object_at_mouse", is_shift_modifier_pressed)
			BUTTON_RIGHT:
				is_mouse_button_right_down = event.pressed
	
	if event is InputEventKey:
		if event.scancode == KEY_SHIFT:
			is_shift_modifier_pressed = event.pressed

func _exit_tree():
	model_load_waitlist = []
	if extract_3d_model_thread != null:
		extract_3d_model_thread.wait_to_finish()

###########
# THREADS #
###########

func start_extract_3d_model_thread():
	if not is_extracting_3d_models:
		is_extracting_3d_models = true
		emit_signal("loading_start")
	
	# Check if model already cached, callback immediately if so
	var package_path = current_waitlist_item["definition"]["static_mesh_asset_path"]
	var mesh_name = current_waitlist_item["definition"]["static_mesh_name"]
	var mesh_name_instance = current_waitlist_item["definition"]["static_mesh_name_instance"]
	var relookup_key = package_path + "|" + mesh_name + "|" + str(mesh_name_instance)
	if uasset_parser.CachedModelReLookupAssetPaths.has(relookup_key):
		package_path = uasset_parser.CachedModelReLookupAssetPaths[relookup_key]
	if cached_models.has(package_path):
		extract_3d_model_thread = null
		var loaded_model = cached_models[package_path]
		if loaded_model != null:
			current_waitlist_item["callback_instance"].call_deferred(current_waitlist_item["callback_method"], loaded_model.duplicate(0))
		end_extract_3d_model_thread()
	# Start thread to load model if not cached
	else:
		extract_3d_model_thread = Thread.new()
		extract_3d_model_thread.start(self, "extract_3d_model_thread_function")

func extract_3d_model_thread_function(_noop):
	if (current_waitlist_item.has("definition") and current_waitlist_item["definition"].has("static_mesh_asset_path")):
		var asset_path = current_waitlist_item["definition"]["static_mesh_asset_path"]
		var mesh_name = current_waitlist_item["definition"]["static_mesh_name"]
		var mesh_name_instance = current_waitlist_item["definition"]["static_mesh_name_instance"]
		current_waitlist_item["definition"]["static_mesh_asset_path"] = uasset_parser.EnsureModelCache(asset_path, mesh_name, mesh_name_instance)
	call_deferred("end_extract_3d_model_thread")

func end_extract_3d_model_thread():
	if extract_3d_model_thread != null:
		extract_3d_model_thread.wait_to_finish()
		extract_3d_model_thread = null
	
	# Import gltf model assign materials
	var package_path = current_waitlist_item["definition"]["static_mesh_asset_path"]
	if not cached_models.has(package_path):
		var model_cache_path = ProjectSettings.globalize_path(@"user://ModelCache")
		var model_full_path = model_cache_path + "/" + package_path.replace(".uasset", ".gltf")
		var dir = Directory.new()
		var loaded_model = null
		if dir.file_exists(model_full_path):
			loaded_model = gltf_loader.import_scene(model_full_path, 1, 1);
		cached_models[package_path] = loaded_model
		if loaded_model != null:
			if uasset_parser.CachedModelResourcesByAssetPath.has(package_path):
				var model_resources = uasset_parser.CachedModelResourcesByAssetPath[package_path]
				for child_node in loaded_model.get_children():
					if child_node is MeshInstance:
						var cached_material_info = uasset_parser.CachedModelResourcesByAssetPath
						if cached_material_info.has(package_path):
							for i in child_node.get_surface_material_count():
								if i < len(cached_material_info[package_path]):
									var material_slot_info = cached_material_info[package_path][i]
									var spatial_material = SpatialMaterial.new()
									if material_slot_info["texture"].has("albedo"):
										spatial_material.albedo_texture = load_texture(material_slot_info["texture"]["albedo"])
									if material_slot_info["texture"].has("normal"):
										spatial_material.normal_texture = load_texture(material_slot_info["texture"]["normal"])
									if material_slot_info["texture"].has("roughness"):
										spatial_material.roughness_texture = load_texture(material_slot_info["texture"]["roughness"])
									if material_slot_info["texture"].has("metallic"):
										spatial_material.metallic_texture = load_texture(material_slot_info["texture"]["metallic"])
									if material_slot_info["texture"].has("ao"):
										spatial_material.ao_texture = load_texture(material_slot_info["texture"]["ao"])
									child_node.set_surface_material(i, spatial_material)
			current_waitlist_item["callback_instance"].call_deferred(current_waitlist_item["callback_method"], loaded_model.duplicate(0))
	
	if len(model_load_waitlist) > 0:
		current_waitlist_item = model_load_waitlist.pop_front()
		start_extract_3d_model_thread()
	else:
		is_extracting_3d_models = false
		emit_signal("loading_end")

#################
# INITIAL SETUP #
#################

func set_room_definition(new_room_definition: Dictionary):
	already_placed_exports = {}
	room_definition = new_room_definition
	for asset_key in asset_roots:
		if room_definition.has(asset_key):
			already_placed_exports[asset_key] = []
			current_placing_tree_name = asset_key
			place_tree_nodes_recursive(asset_roots[asset_key], room_definition[asset_key])

#####################
# LOADING 3D MODELS #
#####################

func load_texture(asset_path: String):
	var model_output_folder = ProjectSettings.globalize_path("user://ModelCache");
	var image = Image.new()
	var err = image.load(model_output_folder + "/" + asset_path.replace(".uasset", ".png"))
	if err != OK:
		return null
	var texture = ImageTexture.new()
	texture.create_from_image(image, 0)
	return texture

func load_3d_model(definition: Dictionary, callback_instance: Object, callback_method: String):
	model_load_waitlist.push_back({
		"definition": definition,
		"callback_instance": callback_instance,
		"callback_method": callback_method
	})
	if not is_extracting_3d_models:
		current_waitlist_item = model_load_waitlist.pop_front()
		start_extract_3d_model_thread()

func place_tree_nodes_recursive(parent: Spatial, definition: Dictionary):
	var node = Spatial.new()
	var parent_definition = null
	if "definition" in parent:
		parent_definition = parent.definition
	var is_auto_placement = true
	var script_def = custom_component_scripts["Unknown"]
	if custom_component_scripts.has(definition["type"]):
		script_def = custom_component_scripts[definition["type"]]
	is_auto_placement = script_def.auto_placement
	node.set_script(script_def.script)
	if definition.has("export_index"):
		var export_index = definition["export_index"]
		if already_placed_exports[current_placing_tree_name].has(export_index):
			# print_debug("Infinite recursion at export ", export_index)
			return
		else:
			already_placed_exports[current_placing_tree_name].push_back(export_index)
		use_edited_prop_if_exists(definition, export_index, "deleted")
		use_edited_prop_if_exists(definition, export_index, "hidden")
		use_edited_prop_if_exists(definition, export_index, "translation")
		use_edited_prop_if_exists(definition, export_index, "rotation_degrees")
		use_edited_prop_if_exists(definition, export_index, "scale")
		for prop_name in light_defaults:
			use_edited_prop_if_exists(definition, export_index, prop_name)
	node.definition = definition
	node.room_3d_display = self
	node.tree_name = current_placing_tree_name
	if parent_definition and parent_definition["type"] == "Level":
		node.persistent_level_child_ancestor = node
	elif "persistent_level_child_ancestor" in parent:
		node.persistent_level_child_ancestor = parent.persistent_level_child_ancestor
	parent.add_child(node)
	if "is_tree_leaf" in parent and parent.is_tree_leaf:
		node.leaf_parent = parent
	elif "leaf_parent" in parent and parent.leaf_parent:
		node.leaf_parent = parent.leaf_parent
	node.name = definition["type"] + "__" + definition["name"]
	if is_auto_placement:
		for child_definition in definition["children"]:
			place_tree_nodes_recursive(node, child_definition)
	call_deferred("handle_tree_nodes_after_placement", node, definition)

func handle_tree_nodes_after_placement(node: Spatial, definition: Dictionary):
	if (definition.has("deleted") and definition["deleted"]):
		node.set_deleted(true)

func use_edited_prop_if_exists(definition: Dictionary, export_index: int, prop_name: String):
	var edited_prop = editor.get_room_edit_export_prop(current_placing_tree_name, export_index, prop_name)
	if edited_prop != null:
		definition[prop_name] = edited_prop

####################
# OBJECT SELECTION #
####################

func select_object_at_mouse(is_add: bool = false):
	if not can_select:
		return
	if not is_add:
		for selected_node in selected_nodes:
			selected_node.deselect()
	var ray_length = 100
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_from = camera.project_ray_origin(mouse_pos)
	var ray_to = ray_from + camera.project_ray_normal(mouse_pos) * ray_length
	var space_state = get_world().direct_space_state
	var already_collided: Array = []
	var collisions: Array = []
	# Find all intersections on ray
	var collision_mask = PhysicsLayers3d.layers.editor_select_mesh | PhysicsLayers3d.layers.editor_select_collider | PhysicsLayers3d.layers.editor_select_light
	var current_collision = space_state.intersect_ray(ray_from, ray_to, [], collision_mask, true, true)
	while current_collision != null and current_collision.has("collider"):
		if not already_collided.has(current_collision.collider):
			already_collided.push_back(current_collision.collider)
			collisions.push_back(current_collision)
		current_collision = space_state.intersect_ray(ray_from, ray_to, already_collided, collision_mask, false, true)
	var closest_collider = null
	var closest_intersect_distance = INF
	for idx in collisions.size():
		var collision = collisions[idx]
		var collider = collision.collider
		var collider_parent = collider.get_parent()
		if "loaded_model_mesh_instance" in collider_parent:
			var mesh = collider_parent.loaded_model_mesh_instance
			var cast_result = MeshRayCast.intersect_ray(mesh, ray_from, ray_to)
			if cast_result.closest != null:
				if cast_result.closest_distance < closest_intersect_distance:
					closest_intersect_distance = cast_result.closest_distance
					closest_collider = collider
		else:
			var distance = ray_from.distance_to(collision.position)
			if distance < closest_intersect_distance:
				closest_collider = collider
				closest_intersect_distance = distance
	if closest_collider != null:
		var node_to_select = closest_collider.selectable_parent
		if node_to_select.leaf_parent != null:
			node_to_select = node_to_select.leaf_parent
		if is_add:
			if selected_nodes.has(node_to_select):
				node_to_select.deselect()
				selected_nodes.erase(node_to_select)
			else:
				node_to_select.select()
				selected_nodes.push_back(node_to_select)
		else:
			node_to_select.select()
			selected_nodes = [node_to_select]
	else:
		if not is_add:
			selected_nodes = []
	emit_signal("selection_changed", selected_nodes)
