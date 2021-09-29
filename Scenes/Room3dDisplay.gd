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

var gltf_loader: DynamicGLTFLoader
var room_definition: Dictionary
var model_load_waitlist: Array = []
var current_waitlist_item: Dictionary

#############
# LIFECYCLE #
#############

func _ready():
	uasset_parser = get_node("/root/UAssetParser")
	gltf_loader = DynamicGLTFLoader.new()
	
	bg_root = get_node("BG")

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
	extract_3d_model_thread = Thread.new()
	extract_3d_model_thread.start(self, "extract_3d_model_thread_function")

func extract_3d_model_thread_function(_noop):
	if (current_waitlist_item.has("definition") and current_waitlist_item["definition"].has("static_mesh_asset_path")):
		var asset_path = current_waitlist_item["definition"]["static_mesh_asset_path"]
		uasset_parser.EnsureModelCache(asset_path)
	call_deferred("end_extract_3d_model_thread")

func end_extract_3d_model_thread():
	extract_3d_model_thread.wait_to_finish()
	
	var model_cache_path = ProjectSettings.globalize_path(@"user://ModelCache")
	var package_path = current_waitlist_item["definition"]["static_mesh_asset_path"]
	var model_full_path = model_cache_path + "/" + package_path.replace(".uasset", ".gltf");
	var loaded_model = gltf_loader.import_scene(model_full_path, 1, 1);
	if loaded_model != null:
		current_waitlist_item["callback_instance"].call_deferred(current_waitlist_item["callback_method"], loaded_model)
	
	if len(model_load_waitlist) > 0:
		current_waitlist_item = model_load_waitlist.pop_front()
		call_deferred("start_extract_3d_model_thread")
	else:
		is_extracting_3d_models = false
		emit_signal("loading_end")

###########
# METHODS #
###########

func load_3d_model(definition: Dictionary, callback_instance: Object, callback_method: String):
	model_load_waitlist.push_back({
		"definition": definition,
		"callback_instance": callback_instance,
		"callback_method": callback_method
	})
	if not is_extracting_3d_models:
		current_waitlist_item = model_load_waitlist.pop_front()
		start_extract_3d_model_thread()

func set_room_definition(new_room_definition: Dictionary):
	room_definition = new_room_definition
	if room_definition.has("bg"):
		place_tree_nodes_recursive(bg_root, room_definition["bg"])

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
