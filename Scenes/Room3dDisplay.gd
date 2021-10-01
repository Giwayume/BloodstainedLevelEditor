extends Spatial

signal loading_start
signal loading_end

var custom_component_scripts = {
	"BlueprintGeneratedClass": {
		"auto_placement": false,
		"script": preload("res://SceneComponents/Room3dNodes/BlueprintGeneratedClass.gd")
	},
	"SceneComponent": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/SceneComponent.gd")
	},
	"StaticMeshComponent": {
		"auto_placement": true,
		"script": preload("res://SceneComponents/Room3dNodes/StaticMeshComponent.gd")
	}
}

var uasset_parser: Node

var extract_3d_model_thread: Thread = null
var is_extracting_3d_models: bool = false

var bg_root: Spatial
var camera: Camera

var gltf_loader: DynamicGLTFLoader
var cached_models: Dictionary

var can_capture_mouse: bool
var room_definition: Dictionary
var model_load_waitlist: Array = []
var current_waitlist_item: Dictionary
var selected_nodes: Array

var is_mouse_button_left_down: bool = false
var is_mouse_button_right_down: bool = false

#############
# LIFECYCLE #
#############

func _ready():
	uasset_parser = get_node("/root/UAssetParser")
	gltf_loader = DynamicGLTFLoader.new()
	
	bg_root = get_node("BG")
	camera = get_node("Camera")

func _input(event):
	# Object selection
	if can_capture_mouse and event is InputEventMouseButton:
		match event.button_index:
			BUTTON_LEFT:
				is_mouse_button_left_down = event.pressed
				if event.pressed and not is_mouse_button_right_down:
					select_object_at_mouse()
			BUTTON_RIGHT:
				is_mouse_button_right_down = event.pressed

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

###########
# THREADS #
###########

func start_extract_3d_model_thread():
	if not is_extracting_3d_models:
		is_extracting_3d_models = true
		emit_signal("loading_start")
	
	# Check if model already cached, callback immediately if so
	var package_path = current_waitlist_item["definition"]["static_mesh_asset_path"]
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
		uasset_parser.EnsureModelCache(asset_path)
	call_deferred("end_extract_3d_model_thread")

func end_extract_3d_model_thread():
	if extract_3d_model_thread != null:
		extract_3d_model_thread.wait_to_finish()
	
	# Import gltf model assign materials
	var package_path = current_waitlist_item["definition"]["static_mesh_asset_path"]
	if not cached_models.has(package_path):
		var model_cache_path = ProjectSettings.globalize_path(@"user://ModelCache")
		var model_full_path = model_cache_path + "/" + package_path.replace(".uasset", ".gltf")
		var loaded_model = gltf_loader.import_scene(model_full_path, 1, 1);
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
		cached_models[package_path] = loaded_model
		if loaded_model != null:
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
	room_definition = new_room_definition
	if room_definition.has("bg"):
		place_tree_nodes_recursive(bg_root, room_definition["bg"])

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
	var is_auto_placement = true
	if custom_component_scripts.has(definition["type"]):
		var script_def = custom_component_scripts[definition["type"]]
		is_auto_placement = script_def.auto_placement
		node.set_script(script_def.script)
		node.definition = definition
		node.room_3d_display = self
	parent.add_child(node)
	node.name = definition["type"] + "__" + definition["name"]
	if is_auto_placement:
		for child_definition in definition["children"]:
			place_tree_nodes_recursive(node, child_definition)

####################
# OBJECT SELECTION #
####################

func select_object_at_mouse():
	for selected_node in selected_nodes:
		selected_node.deselect()
	var ray_length = 100
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_from = camera.project_ray_origin(mouse_pos)
	var ray_to = ray_from + camera.project_ray_normal(mouse_pos) * ray_length
	var space_state = get_world().direct_space_state
	var intersections: Array = []
	var current_intersection = space_state.intersect_ray(ray_from, ray_to, [], 2147483647, false, true)
	while current_intersection != null and current_intersection.has("collider"):
		intersections.push_back(current_intersection.collider)
		current_intersection = space_state.intersect_ray(ray_from, ray_to, intersections, 2147483647, false, true)
	var closest_intersection = null
	var closest_point = Vector3()
	var closest_intersect_distance = INF
	for intersection in intersections:
		var mesh = intersection.get_parent().loaded_model_mesh_instance
		var cast_result = MeshRayCast.intersect_ray(mesh, ray_from, ray_to)
		if cast_result.closest != null:
			if cast_result.closest_distance < closest_intersect_distance:
				closest_intersect_distance = cast_result.closest_distance
				closest_point = cast_result.closest
				closest_intersection = intersection
	if closest_intersection != null:
		var collider_parent = closest_intersection.get_parent()
		collider_parent.select()
		selected_nodes = [collider_parent]
	
#	var selection = space_state.intersect_ray(ray_from, ray_to, [], 2147483647, false, true)
#	if selection and selection.collider:
#		var collider_parent = selection.collider.get_parent()
#		collider_parent.select()
#		selected_nodes = [collider_parent]
