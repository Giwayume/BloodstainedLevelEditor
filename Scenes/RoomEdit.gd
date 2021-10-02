extends Control

var enemy_profiles = load("res://Config/EnemyProfiles.gd").enemy_profiles
var viewport_ui_container_normal_style = preload("res://EditorTheme/ViewportUiContainerNormal.tres")
var viewport_ui_container_focus_style = preload("res://EditorTheme/ViewportUiContainerFocus.tres")
var selectable_types = ["StaticMeshComponent"]

var editor: Node
var uasset_parser: Node

var parse_pak_thread: Thread
var get_room_definition_thread: Thread
var parse_enemy_blueprint_thread: Thread

var editor_container: Control
var loading_3d_scene_notification: Control
var loading_status_container: Control
var loading_status_label: Label
var menu_button_package: MenuButton
var menu_button_edit: MenuButton
var room_3d_display: Spatial
var room_3d_display_camera: Camera
var room_3d_focus_container: PanelContainer
var room_3d_viewport_container: ViewportContainer

var background_tree: Dictionary = {
	"tree": null,
	"root_item": null,
	"node_id_map": {},
	"tree_id_map": {}
}

var room_definition: Dictionary

#############
# LIFECYCLE #
#############

func _ready():
	editor = get_node("/root/Editor");
	uasset_parser = get_node("/root/UAssetParser")
	
	if not editor.selected_package:
		editor.selected_package = "MyTest"
	if not editor.selected_level_name:
		editor.selected_level_name = "m02VIL_006"
	
	background_tree.tree = find_node("BackgroundTree", true, true)
	editor_container = find_node("EditorContainer", true, true)
	loading_3d_scene_notification = find_node("Loading3dSceneNotification", true, true)
	loading_status_container = find_node("LoadingStatusContainer", true, true)
	loading_status_label = find_node("LoadingStatusLabel", true, true)
	menu_button_package = find_node("PackageMenuButton", true, true)
	menu_button_edit = find_node("EditMenuButton", true, true)
	room_3d_display = find_node("Room3dDisplay", true, true)
	room_3d_display_camera = room_3d_display.find_node("Camera", true, true)
	room_3d_focus_container = find_node("Room3dFocusContainer", true, true)
	room_3d_viewport_container = find_node("Room3dViewportContainer", true, true)
	
	editor_container.hide()
	loading_status_container.show()
	loading_3d_scene_notification.hide()
	
	background_tree.root_item = background_tree.tree.create_item()
	background_tree.root_item.set_text(0, "World")
	background_tree.root_item.disable_folding = true
	
	menu_button_package.get_popup().connect("id_pressed", self, "on_menu_popup_package_pressed")
	
	background_tree.tree.connect("multi_selected", self, "on_background_tree_multi_selected")
	room_3d_display.connect("loading_start", self, "on_room_3d_display_loading_start")
	room_3d_display.connect("loading_end", self, "on_room_3d_display_loading_end")
	room_3d_display.connect("selection_changed", self, "on_room_3d_display_selection_changed")
	room_3d_focus_container.connect("focus_entered", self, "on_room_3d_focus_container_focus")
	room_3d_focus_container.connect("focus_exited", self, "on_room_3d_focus_container_blur")
	
	start_parse_pak_thread()
	
func _input(event):
	# Tell Room3dDisplay if it should capture mouse events
	var parent = get_parent()
	var viewport_position = room_3d_viewport_container.rect_global_position
	var global_mouse_position = get_global_mouse_position()
	var can_capture_mouse = (
		global_mouse_position.x > viewport_position.x and
		global_mouse_position.y > viewport_position.y and
		global_mouse_position.x < viewport_position.x + room_3d_viewport_container.rect_size.x and
		global_mouse_position.y < viewport_position.y + room_3d_viewport_container.rect_size.y
	)
	var can_capture_keyboard = room_3d_focus_container.has_focus()
	room_3d_display.can_capture_mouse = can_capture_mouse
	room_3d_display.can_capture_keyboard = can_capture_keyboard
	room_3d_display_camera.can_capture_mouse = can_capture_mouse
	room_3d_display_camera.can_capture_keyboard = can_capture_keyboard
	room_3d_display_camera.viewport_position = viewport_position
	if event is InputEventMouseButton:
		if can_capture_mouse and event.pressed:
			room_3d_focus_container.call_deferred("grab_focus")

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
	start_get_room_definition_thread()

func start_get_room_definition_thread():
	get_room_definition_thread = Thread.new()
	get_room_definition_thread.start(self, "get_room_definition_thread_function")
	loading_status_label.text = "Reading the room's assets..."

func get_room_definition_thread_function(_noop):
	room_definition = uasset_parser.GetRoomDefinition(editor.selected_level_name)
	call_deferred("end_get_room_definition_thread")

func end_get_room_definition_thread():
	get_room_definition_thread.wait_to_finish()
	
	threads_finished()


#func start_parse_enemy_blueprint_thread():
#	parse_enemy_blueprint_thread = Thread.new()
#	parse_enemy_blueprint_thread.start(self, "parse_enemy_blueprint_thread_function")
#	loading_status_label.text = "Reading enemy information..."
#
#func parse_enemy_blueprint_thread_function(_noop):
#	uasset_parser.ParseEnemyDefinitionsToUserProjectFolder(enemy_profiles);
#	call_deferred("end_enemy_blueprint_thread")
#
#func end_enemy_blueprint_thread():
#	parse_enemy_blueprint_thread.wait_to_finish()
#
#	var game_directory = editor.read_config()["game_directory"]
#	var selected_package_name = editor.selected_package
#	var user_project_path = ProjectSettings.globalize_path("user://UserPackages/" + selected_package_name)
#
#	uasset_parser.ExtractAssetToFolder(
#		game_directory + "/BloodstainedRotN/Content/Paks/pakchunk0-WindowsNoEditor.pak",
#		"BloodstainedRotN/Content/Core/Environment/ACT04_GDN/Level/m04GDN_016_Enemy.umap",
#		user_project_path + "/ModifiedAssets"
#	)
#	uasset_parser.AddBlueprintToAsset(
#		game_directory + "/BloodstainedRotN/Content/Paks/pakchunk0-WindowsNoEditor.pak",
#		"BloodstainedRotN/Content/Core/Environment/ACT04_GDN/Level/m04GDN_015_Enemy.umap",
#		"Chr_N3091(3)",
#		user_project_path + "/ModifiedAssets/BloodstainedRotN/Content/Core/Environment/ACT04_GDN/Level/m04GDN_015_Enemy.umap"
#	)
#	uasset_parser.AddBlueprintToAsset(
#		game_directory + "/BloodstainedRotN/Content/Paks/pakchunk0-WindowsNoEditor.pak",
#		"BloodstainedRotN/Content/Core/Environment/ACT04_GDN/Level/m04GDN_015_Enemy.umap",
#		"Chr_N3091(3)",
#		user_project_path + "/ModifiedAssets/BloodstainedRotN/Content/Core/Environment/ACT04_GDN/Level/m04GDN_016_Enemy.umap"
#	)


func threads_finished():
	editor_container.show()
	loading_status_container.hide()
	setup_after_load()

#############
# CALLBACKS #
#############

func on_background_tree_multi_selected(item: TreeItem, column: int, selected: bool):
	var current_tree: Dictionary = background_tree
	var selected_nodes = room_3d_display.selected_nodes
	var export_index: int = item.get_metadata(0).export_index
	var node = current_tree.node_id_map[export_index]
	if selected:
		node.select()
		room_3d_display.selected_nodes.push_back(node)
	else:
		node.deselect()
		room_3d_display.selected_nodes.erase(node)

func on_menu_popup_package_pressed(id: int):
	if id == 0:
		editor.package_and_install()
	elif id == 1:
		get_tree().change_scene("res://Scenes/MapEdit.tscn")
	elif id == 3:
		 get_tree().change_scene("res://Scenes/SelectPackage.tscn")

func on_room_3d_display_loading_start():
	loading_3d_scene_notification.show()

func on_room_3d_display_loading_end():
	loading_3d_scene_notification.hide()

func on_room_3d_display_selection_changed(selected_nodes):
	var current_tree: Dictionary = background_tree
	var remaining_selected_nodes: Array = selected_nodes.duplicate(false)
	var items_to_deselect: Array = []
	var selected_item: TreeItem = current_tree.tree.get_next_selected(null)
	while selected_item != null:
		var export_index = selected_item.get_metadata(0).export_index
		var existing_selected_node_index = remaining_selected_nodes.find(current_tree.node_id_map[export_index])
		if existing_selected_node_index == -1:
			items_to_deselect.push_back(selected_item)
		else:
			remaining_selected_nodes.remove(existing_selected_node_index)
		selected_item = current_tree.tree.get_next_selected(selected_item)
	for item in items_to_deselect:
		item.deselect(0)
	for node in remaining_selected_nodes:
		var export_index = node.definition.export_index
		tree_uncollapse_from_item(current_tree.tree_id_map[export_index])
		current_tree.tree_id_map[export_index].select(0)
	current_tree.tree.ensure_cursor_is_visible()

func on_room_3d_focus_container_focus():
	room_3d_focus_container.add_stylebox_override("panel", viewport_ui_container_focus_style)

func on_room_3d_focus_container_blur():
	room_3d_focus_container.add_stylebox_override("panel", viewport_ui_container_normal_style)
	room_3d_display.can_capture_mouse = false
	room_3d_display_camera.can_capture_mouse = false

func tree_uncollapse_from_item(item: TreeItem):
	item.set_collapsed(false)
	var parent = item.get_parent()
	if parent != null:
		tree_uncollapse_from_item(parent)

###########
# METHODS #
###########

func setup_after_load():
	setup_3d_view()
	background_tree.tree_id_map.clear()
	background_tree.node_id_map.clear()
	background_tree.tree.clear()
	build_object_outline(background_tree.tree, background_tree.root_item, background_tree.tree_id_map, background_tree.node_id_map, room_3d_display.find_node("BG", true, true))

func setup_3d_view():
	room_3d_display.set_room_definition(room_definition)

func build_object_outline(tree: Tree, parent_item: TreeItem, tree_id_map: Dictionary, node_id_map: Dictionary, parent_node: Node):
	for child_node in parent_node.get_children():
		var definition = child_node.definition
		var tree_item: TreeItem = tree.create_item(parent_item)
		tree_item.set_collapsed(true)
		tree_item.set_text(0, definition["name"])
		tree_item.set_metadata(0, {
			"export_index": definition["export_index"]
		})
		tree_item.set_selectable(0, selectable_types.has(definition["type"]))
		tree_id_map[definition["export_index"]] = tree_item
		node_id_map[definition["export_index"]] = child_node
		if not child_node.is_tree_leaf:
			build_object_outline(tree, tree_item, tree_id_map, node_id_map, child_node)
		
