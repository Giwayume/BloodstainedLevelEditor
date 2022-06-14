extends Control

signal history_changed

const NEW_EXPORT_PREFIX: int = 100000

var toast_scene = preload("res://SceneComponents/UiComponents/Toast.tscn")
var loading_screen_scene = preload("res://Scenes/LoadingScreen.tscn")

var package_and_install_thread: Thread

var uasset_parser: Node
var selected_package: String = ""
var selected_level_name: String = ""
var loading_screen: Control

var room_edits = null

var history: Array = []
var history_index = 0
var history_max = 50
var history_shortcuts_disabled: bool = false

func _ready():
	PhysicsLayers3d.read_layers()
	uasset_parser = get_node("/root/UAssetParser")

func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		save_room_edits(true)
		room_edits = null
		get_tree().quit()

##########
# CONFIG #
##########

func read_config():
	return EditorConfig.read_config()

func write_config_prop(prop_name: String, prop_data):
	return EditorConfig.write_config_prop(prop_name, prop_data)
	
func read_config_prop(prop_name: String):
	var config = read_config()
	if config.has(prop_name):
		return config[prop_name]
	else:
		return null

###########
# HISTORY #
###########

func do_action(action: HistoryAction):
	action.do()
	if history_index < history.size():
		history = ArrayExt.slice(history, 0, history_index)
	history.push_back(action)
	if history.size() > history_max:
		history.pop_front()
	else:
		history_index += 1
	emit_signal("history_changed", action)

func can_redo():
	return history_index < history.size()
	
func can_undo():
	return history_index > 0

func redo_action():
	if can_redo():
		var action = history[history_index]
		action.do()
		history_index += 1
		emit_signal("history_changed", action)
		
func undo_action():
	if can_undo():
		history_index -= 1
		history[history_index].undo()
		emit_signal("history_changed", history[history_index])

func clear_action_history():
	history = []
	history_index = 0

#############
# ROOM EDIT #
#############

func load_room_edits():
	room_edits = null
	var level_assets = uasset_parser.LevelNameToAssetPathMap[selected_level_name]
	if level_assets.has("bg"):
		var directory = Directory.new()
		var edits_folder = "user://UserPackages/" + selected_package + "/Edits"
		var level_path = level_assets["bg"].rsplit("/", true, 1)[0]
		var error = directory.make_dir_recursive(edits_folder + "/" + level_path)
		if error == OK:
			var edits_file_path = edits_folder + "/" + level_path + "/" + selected_level_name + ".json"
			var edits_file
			if not directory.file_exists(edits_file_path):
				edits_file = File.new()
				edits_file.open(edits_file_path, File.WRITE)
				edits_file.store_line("{ }")
				edits_file.close()
			edits_file = File.new()
			var file_error = edits_file.open(edits_file_path, File.READ)
			if file_error == OK:
				var edits_json = edits_file.get_as_text()
				var edits_dictionary_parse = JSON.parse(edits_json)
				if edits_dictionary_parse.error == OK:
					edits_file.close()
					room_edits = edits_dictionary_parse.result
			edits_file.close()

func save_room_edits(is_run_cleanup: bool = false):
	if room_edits != null:
		var level_assets = uasset_parser.LevelNameToAssetPathMap[selected_level_name]
		if level_assets.has("bg"):
			if is_run_cleanup:
				for category in room_edits:
					if typeof(room_edits[category]) == TYPE_DICTIONARY and room_edits[category].has("new_exports"):
						for new_export_index in range(len(room_edits[category].new_exports) - 1, -1, -1):
							var new_export = room_edits[category].new_exports[new_export_index]
							if new_export.has("edits") and new_export.edits.has("0"):
								if new_export.edits["0"].has("deleted") and new_export.edits["0"].deleted == true:
									room_edits[category].new_exports.remove(new_export_index)
				
			var directory = Directory.new()
			var edits_folder = "user://UserPackages/" + selected_package + "/Edits"
			var level_path = level_assets["bg"].rsplit("/", true, 1)[0]
			var edits_file_path = edits_folder + "/" + level_path + "/" + selected_level_name + ".json"
			var edits_file = File.new()
			var file_error = edits_file.open(edits_file_path, File.WRITE)
			if file_error == OK:
				edits_file.store_string(JSON.print(room_edits, "    "))
			edits_file.close()

func get_room_edit_export_storage(asset_type: String, export_index):
	var edit_storage = null
	export_index = int(export_index)
	if export_index >= NEW_EXPORT_PREFIX:
		var index_in_new_exports_array = floor(export_index / NEW_EXPORT_PREFIX) - 1
		if len(room_edits[asset_type]["new_exports"]) > index_in_new_exports_array:
			var new_export_definition = room_edits[asset_type]["new_exports"][index_in_new_exports_array]
			if not new_export_definition.has("edits"):
				new_export_definition["edits"] = {}
			edit_storage = room_edits[asset_type]["new_exports"][index_in_new_exports_array]["edits"]
		export_index = export_index % NEW_EXPORT_PREFIX
	else:
		edit_storage = room_edits[asset_type]["existing_exports"]
	return {
		"edit_storage": edit_storage,
		"export_index": str(export_index)
	}

func get_room_edit_export_prop_list(asset_type: String, export_index):
	var prop_list = []
	export_index = str(export_index)
	var prop_value = null
	if room_edits != null and room_edits.has(asset_type):
		var edit_storage_export = get_room_edit_export_storage(asset_type, export_index)
		var edit_storage = edit_storage_export.edit_storage
		export_index = edit_storage_export.export_index
		if edit_storage != null and edit_storage.has(export_index):
			for prop_name in edit_storage[export_index]:
				prop_list.push_back(prop_name)
	return prop_list

func get_room_edit_next_new_export_prefix_counter(asset_type: String):
	var prefix = 1
	if room_edits != null and room_edits.has(asset_type):
		if room_edits[asset_type].has("new_exports"):
			prefix = len(room_edits[asset_type]["new_exports"]) + 1
	return prefix

func get_room_edit_export_prop(asset_type: String, export_index, prop_name: String):
	export_index = str(export_index)
	var prop_value = null
	if room_edits != null and room_edits.has(asset_type):
		var edit_storage_export = get_room_edit_export_storage(asset_type, export_index)
		var edit_storage = edit_storage_export.edit_storage
		export_index = edit_storage_export.export_index
		if edit_storage != null and edit_storage.has(export_index):
			if edit_storage[export_index].has(prop_name):
				prop_value = edit_storage[export_index][prop_name]
				if prop_value is Dictionary:
					if prop_value.has("type"):
						if prop_value["type"] == "Vector3":
							prop_value = Vector3(prop_value.x, prop_value.y, prop_value.z)
						elif prop_value["type"] == "Color":
							prop_value = Color(prop_value.r, prop_value.g, prop_value.b, prop_value.a)
	return prop_value

func create_room_edit_asset_type(asset_type: String):
	if room_edits == null:
		return
	if not room_edits.has(asset_type):
		room_edits[asset_type] = {
			"existing_exports": {},
			"new_exports": []
		}

func create_room_edit_export(asset_type: String, new_export_definition: Dictionary):
	if room_edits == null:
		return
	
	room_edits["has_changes"] = true;
	create_room_edit_asset_type(asset_type)
	
	room_edits[asset_type].new_exports.push_back(new_export_definition)

func set_room_edit_export_prop(asset_type: String, export_index, prop_name: String, prop_value):
	if room_edits == null:
		return
	
	room_edits["has_changes"] = true;
	export_index = str(export_index)
	if prop_value == null:
		remove_room_edit_export_prop(asset_type, export_index, prop_name)
	else:
		create_room_edit_asset_type(asset_type)
		
		var original_export_index = export_index
		
		var edit_storage_export = get_room_edit_export_storage(asset_type, export_index)
		var edit_storage = edit_storage_export.edit_storage
		export_index = edit_storage_export.export_index
		
		if edit_storage == null:
			print_debug(edit_storage)
			print_debug("[Editor] did not find edit storage for export ", original_export_index)
			return
		
		if not edit_storage.has(export_index):
			edit_storage[export_index] = {}
		if prop_value is Vector3:
			prop_value = {
				"type": "Vector3",
				"x": prop_value.x,
				"y": prop_value.y,
				"z": prop_value.z
			}
		elif prop_value is Color:
			prop_value = {
				"type": "Color",
				"r": prop_value.r,
				"g": prop_value.g,
				"b": prop_value.b,
				"a": prop_value.a
			}
		edit_storage[export_index][prop_name] = prop_value

func remove_room_edit_export_prop(asset_type: String, export_index, prop_name: String):
	if room_edits == null:
		return
	
	room_edits["has_changes"] = true;
	export_index = str(export_index)
	if room_edits.has(asset_type):
		var edit_storage_export = get_room_edit_export_storage(asset_type, export_index)
		var edit_storage = edit_storage_export.edit_storage
		export_index = edit_storage_export.export_index
		if edit_storage != null and edit_storage.has(export_index):
			edit_storage[export_index].erase(prop_name)
			if edit_storage[export_index].size() == 0:
				edit_storage.erase(export_index)

func prefix_export_index_recursive(definition, prefix: int = Editor.NEW_EXPORT_PREFIX):
	definition.export_index = prefix + definition.export_index
	definition.outer_export_index = prefix + definition.outer_export_index
	if definition.has("mesh_export_index"):
		definition.mesh_export_index = prefix + definition.mesh_export_index
	if definition.has("root_component_export_index"):
		definition.root_component_export_index = prefix + definition.root_component_export_index
	if definition.has("children"):
		for child in definition.children:
			prefix_export_index_recursive(child, prefix)

#############
# PACKAGING #
#############

func package_and_install(package_name: String = "", is_run_game: bool = true, install_finish_callback_target: Object = null, install_finish_callback_method: String = ""):
	save_room_edits()
	if package_name == "":
		package_name = selected_package
	start_package_and_install_thread(package_name, is_run_game, install_finish_callback_target, install_finish_callback_method)

func start_package_and_install_thread(package_name: String, is_run_game: bool, install_finish_callback_target: Object, install_finish_callback_method: String):
	loading_screen = loading_screen_scene.instance()
	get_tree().get_root().add_child(loading_screen)
	loading_screen.set_status_text("Packaging Project...")
	package_and_install_thread = Thread.new()
	package_and_install_thread.start(self, "package_and_install_thread_function", [package_name, is_run_game, install_finish_callback_target, install_finish_callback_method])

func package_and_install_thread_function(thread_data: Array):
	var uasset_parser = get_node("/root/UAssetParser")
	var package_name: String = thread_data[0]
	uasset_parser.PackageAndInstallMod(package_name)
	call_deferred("end_package_and_install_thread", thread_data[1], thread_data[2], thread_data[3])

func end_package_and_install_thread(is_run_game: bool, install_finish_callback_target: Object, install_finish_callback_method: String):
	package_and_install_thread.wait_to_finish()
	get_tree().get_root().remove_child(loading_screen)
	loading_screen = null
	
	if is_run_game:
		var game_directory = EditorConfig.read_config()["game_directory"]
		OS.execute(game_directory + "/BloodstainedRotN/Binaries/Win64/BloodstainedRotN-Win64-Shipping.exe", [], false)
		var toast = toast_scene.instance()
		get_tree().get_root().add_child(toast)
		toast.set_text("The game will launch momentarily...")
	
	if install_finish_callback_target != null:
		install_finish_callback_target.call_deferred(install_finish_callback_method)
