extends Control

var map_room_scene = preload("res://SceneComponents/MapRoom.tscn")

var editor: Node
var uasset_parser: Node

var parse_pak_thread: Thread
var read_map_thread: Thread

var change_mod_package_button: Button
var edit_selected_room_button: Button
var level_name_item_list: ItemList
var loading_status_container: Control
var loading_status_label: Label
var map_edit: Node2D
var map_room_list_split_container: HSplitContainer
var room_select_container: Control
var search_level_name_clear_button: Button
var search_level_name_edit: LineEdit

var level_names: Array
var level_names_filtered: Array

#############
# LIFECYCLE #
#############

func _ready():
	editor = get_node("/root/Editor");
	uasset_parser = get_node("/root/UAssetParser")
	
	change_mod_package_button = find_node("ChangeModPackageButton", true, true)
	edit_selected_room_button = find_node("EditSelectedRoomButton", true, true)
	loading_status_container = find_node("LoadingStatusContainer", true, true)
	loading_status_label = find_node("LoadingStatusLabel", true, true)
	level_name_item_list = find_node("LevelNameList", true, true)
	map_edit = find_node("MapEdit", true, true)
	map_room_list_split_container = find_node("MapRoomListSplitContainer", true, true)
	room_select_container = find_node("RoomSelectContainer", true, true)
	search_level_name_clear_button = find_node("SearchLevelNameClearButton", true, true)
	search_level_name_edit = find_node("SearchLevelNameEdit", true, true)
	
	change_mod_package_button.text = "Mod Package: " + editor.selected_package
	edit_selected_room_button.disabled = true
	
	loading_status_container.show()
	room_select_container.hide()
	
	change_mod_package_button.connect("pressed", self, "on_change_mod_package")
	edit_selected_room_button.connect("pressed", self, "on_edit_selected_room")
	level_name_item_list.connect("item_activated", self, "on_level_name_list_item_activated")
	level_name_item_list.connect("item_selected", self, "on_level_name_list_item_selected")
	level_name_item_list.connect("nothing_selected", self, "on_level_name_list_nothing_selected")
	map_edit.connect("level_selected", self, "on_map_level_selected")
	map_edit.connect("level_activated", self, "on_map_level_activated")
	search_level_name_edit.connect("text_changed", self, "on_search_level_name_changed")
	search_level_name_clear_button.connect("pressed", self, "on_search_level_name_clear")
	
	if not EditorConfig.read_config().has("game_directory"):
		get_tree().change_scene("res://Scenes/SelectGameFolder.tscn")
	else:
		start_parse_pak_thread()

###########
# THREADS #
###########

func start_parse_pak_thread():
	parse_pak_thread = Thread.new()
	parse_pak_thread.start(self, "parse_pak_thread_function")
	loading_status_label.text = "Reading .pak files..."

func parse_pak_thread_function(_noop):
	uasset_parser.GuaranteeAssetListFromPakFiles()
	call_deferred("end_parse_pak_thread")

func end_parse_pak_thread():
	parse_pak_thread.wait_to_finish()
	
	# Populate level name list GUI on right
	level_names = uasset_parser.LevelNameToAssetPathMap.keys().duplicate()
	level_names.sort()
	level_name_item_list.clear()
	for level_name in level_names:
		level_name_item_list.add_item(level_name)
	on_search_level_name_clear()
	
	start_read_map_thread()

func start_read_map_thread():
	read_map_thread = Thread.new()
	read_map_thread.start(self, "read_map_thread_function")
	loading_status_label.text = "Reading map..."

func read_map_thread_function(_noop):
	uasset_parser.GuaranteeMapData()
	call_deferred("end_read_map_thread")
	
func end_read_map_thread():
	read_map_thread.wait_to_finish()
	
	# Populate map rooms GUI
	for map_room in uasset_parser.MapRooms:
		var map_room_node = map_room_scene.instance()
		map_room_node.name = map_room["level_name"];
		map_edit.add_child(map_room_node)
		map_room_node.init(map_room)
	map_edit.init()
	
	loading_status_container.hide()
	room_select_container.show()
	
	map_room_list_split_container.split_offset = (get_viewport().size.x / 4)
	map_edit.call_deferred("center_map_in_parent")


#############
# CALLBACKS #
#############

func on_change_mod_package():
	get_tree().change_scene("res://Scenes/SelectPackage.tscn")

func on_edit_selected_room():
	on_map_level_activated(level_names_filtered[level_name_item_list.get_selected_items()[0]])

func on_level_name_list_item_activated(index: int):
	on_map_level_activated(level_names_filtered[index])

func on_level_name_list_item_selected(index: int):
	edit_selected_room_button.disabled = false
	map_edit.select_room_and_center(level_names_filtered[index])

func on_level_name_list_nothing_selected():
	edit_selected_room_button.disabled = true

func on_map_level_selected(level_name_to_select: String):
	on_search_level_name_clear()
	edit_selected_room_button.disabled = true
	var index: int = 0
	for level_name in level_names_filtered:
		if level_name == level_name_to_select:
			level_name_item_list.select(index)
			edit_selected_room_button.disabled = false
			break
		index += 1
	level_name_item_list.ensure_current_is_visible()

func on_map_level_activated(level_name_to_activate: String):
	editor.selected_level_name = level_name_to_activate
	get_tree().change_scene("res://Scenes/UMapEdit.tscn")

func on_search_level_name_changed(search_text: String):
	filter_level_name_list(search_text)
	
func on_search_level_name_clear():
	search_level_name_edit.text = ""
	filter_level_name_list("")

###########
# METHODS #
###########

func filter_level_name_list(search_text: String):
	search_text = search_text.to_lower()
	var search_terms: Array = search_text.rsplit(" ");
	level_name_item_list.clear()
	level_names_filtered = []
	for level_name in level_names:
		var is_include: bool = true
		for search_term in search_terms:
			if search_term != "" and not search_term in level_name.to_lower():
				is_include = false
				break
		if is_include:
			level_name_item_list.add_item(level_name)
			level_names_filtered.push_back(level_name)

