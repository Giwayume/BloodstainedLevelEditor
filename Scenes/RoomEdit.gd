extends Control

var enemy_profiles = preload("res://Config/EnemyProfiles.gd").enemy_profiles
var viewport_ui_container_normal_style = preload("res://EditorTheme/ViewportUiContainerNormal.tres")
var viewport_ui_container_focus_style = preload("res://EditorTheme/ViewportUiContainerFocus.tres")
var selectable_types = ["StaticMeshActor", "StaticMeshComponent"]

var editor: Node
var uasset_parser: Node

var parse_pak_thread: Thread
var get_room_definition_thread: Thread
var parse_enemy_blueprint_thread: Thread

var editor_container: Control
var loading_3d_scene_notification: Control
var loading_status_container: Control
var loading_status_label: Label
var menu_bar: Control
var room_3d_display: Spatial
var room_3d_display_camera: Camera
var room_3d_focus_container: PanelContainer
var room_3d_viewport_container: ViewportContainer
var room_editor_controls_display: Spatial
var room_editor_controls_display_camera: Camera
var room_editor_controls_display_cursor: Spatial
var viewport_toolbar: Control

var background_tree: Dictionary = {
	"tree": null,
	"root_item": null,
	"node_id_map": {},
	"tree_id_map": {}
}

var room_definition: Dictionary

var current_tool: String = "move"
var transform_tool_names = ["select", "move", "rotate", "scale"]
var is_any_menu_popup_visible: bool = false
var is_mouse_in_3d_viewport_range: bool = false
var is_3d_viewport_focused: bool = false
var is_3d_editor_control_active: bool = false
var selected_node_initial_transforms: Array = []

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
	menu_bar = find_node("RoomEditMenuBar", true, true)
	room_3d_display = find_node("Room3dDisplay", true, true)
	room_3d_display_camera = room_3d_display.find_node("Camera", true, true)
	room_3d_focus_container = find_node("Room3dFocusContainer", true, true)
	room_3d_viewport_container = find_node("Room3dViewportContainer", true, true)
	room_editor_controls_display = find_node("RoomEditorControlsDisplay", true, true)
	room_editor_controls_display_camera = room_editor_controls_display.find_node("Camera", true, true)
	room_editor_controls_display_cursor = room_editor_controls_display.find_node("ObjectTransformCursor", true, true)
	viewport_toolbar = find_node("RoomEditViewportToolbar", true, true)
	
	editor_container.hide()
	loading_status_container.show()
	loading_3d_scene_notification.hide()
	
	background_tree.root_item = background_tree.tree.create_item()
	background_tree.root_item.set_text(0, "World")
	background_tree.root_item.disable_folding = true
	
	background_tree.tree.connect("multi_selected", self, "on_background_tree_multi_selected")
	editor.connect("history_changed", self, "on_history_changed")
	menu_bar.connect("popup_visibility_changed", self, "on_menu_bar_popup_visibility_changed")
	room_3d_display.connect("loading_start", self, "on_room_3d_display_loading_start")
	room_3d_display.connect("loading_end", self, "on_room_3d_display_loading_end")
	room_3d_display.connect("selection_changed", self, "on_room_3d_display_selection_changed")
	room_3d_display_camera.connect("transform_changed", self, "on_room_3d_display_camera_transform_changed")
	room_3d_focus_container.connect("focus_entered", self, "on_room_3d_focus_container_focus")
	room_3d_focus_container.connect("focus_exited", self, "on_room_3d_focus_container_blur")
	room_editor_controls_display.connect("control_active", self, "on_room_editor_controls_display_control_active")
	room_editor_controls_display.connect("control_inactive", self, "on_room_editor_controls_display_control_inactive")
	room_editor_controls_display_cursor.connect("translate_cancel", self, "on_translate_cancel_selection")
	room_editor_controls_display_cursor.connect("translate_preview", self, "on_translate_preview_selection")
	room_editor_controls_display_cursor.connect("translate", self, "on_translate_selection")
	viewport_toolbar.connect("tool_changed", self, "on_tool_changed")
	
	start_parse_pak_thread()

func _input(event):
	# Tell Room3dDisplay if it should capture mouse events
	var parent = get_parent()
	var viewport_position = room_3d_viewport_container.rect_global_position
	var global_mouse_position = get_global_mouse_position()
	is_mouse_in_3d_viewport_range = (
		global_mouse_position.x > viewport_position.x and
		global_mouse_position.y > viewport_position.y and
		global_mouse_position.x < viewport_position.x + room_3d_viewport_container.rect_size.x and
		global_mouse_position.y < viewport_position.y + room_3d_viewport_container.rect_size.y
	)
	is_3d_viewport_focused = room_3d_focus_container.has_focus()
	room_3d_display_camera.viewport_position = viewport_position
	update_3d_viewport_input_tracking()
	if event is InputEventMouseButton:
		if is_mouse_in_3d_viewport_range and event.pressed:
			room_3d_focus_container.call_deferred("grab_focus")

func _exit_tree():
	editor.save_room_edits()
	editor.room_edits = null

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
	update_3d_cursor_position()

func on_history_changed(action: HistoryAction):
	if action.get_ids().has(HistoryAction.ID.SPATIAL_TRANSFORM):
		update_3d_cursor_position()

func on_menu_bar_popup_visibility_changed(is_visible):
	is_any_menu_popup_visible = is_visible

func on_room_3d_display_camera_transform_changed(transform):
	room_editor_controls_display_camera.transform = transform

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
	update_3d_cursor_position()

func on_room_3d_focus_container_focus():
	room_3d_focus_container.add_stylebox_override("panel", viewport_ui_container_focus_style)

func on_room_3d_focus_container_blur():
	room_3d_focus_container.add_stylebox_override("panel", viewport_ui_container_normal_style)
	is_3d_viewport_focused = false
	update_3d_viewport_input_tracking()

func on_room_editor_controls_display_control_active():
	is_3d_editor_control_active = true
	
func on_room_editor_controls_display_control_inactive():
	is_3d_editor_control_active = false

func on_tool_changed(new_tool: String):
	current_tool = new_tool
	if transform_tool_names.has(current_tool):
		room_editor_controls_display_cursor.show()
		room_editor_controls_display_cursor.set_mode(current_tool)
	else:
		room_editor_controls_display_cursor.hide()

func on_translate_cancel_selection():
	var index = 0
	for node in room_3d_display.selected_nodes:
		if node.selection_transform_node:
			node.selection_transform_node.global_transform = selected_node_initial_transforms[index]
		index += 1
	selected_node_initial_transforms = []

func on_translate_preview_selection(offset: Vector3):
	var offset_transform = Transform()
	offset_transform = offset_transform.translated(offset)
	if len(selected_node_initial_transforms) != len(room_3d_display.selected_nodes):
		selected_node_initial_transforms = []
		for node in room_3d_display.selected_nodes:
			if node.selection_transform_node:
				selected_node_initial_transforms.push_back(node.selection_transform_node.get_global_transform())
			else:
				selected_node_initial_transforms.push_back(Transform())
	var index = 0
	for node in room_3d_display.selected_nodes:
		if node.selection_transform_node:
			node.selection_transform_node.global_transform = offset_transform * selected_node_initial_transforms[index]
		index += 1

func on_translate_selection(offset: Vector3):
	var offset_transform = Transform()
	offset_transform = offset_transform.translated(offset)
	if len(selected_node_initial_transforms) == len(room_3d_display.selected_nodes):
		var actions = []
		var index = 0
		for node in room_3d_display.selected_nodes:
			if node.selection_transform_node:
				actions.push_back(
					SpatialTransformAction.new(
						node.selection_transform_node,
						selected_node_initial_transforms[index],
						offset_transform * selected_node_initial_transforms[index]
					)
				)
			index += 1
		editor.do_action(
			HistoryGroupAction.new(
				"Spatial Transforms",
				actions
			)
		)
		selected_node_initial_transforms = []

###########
# METHODS #
###########

func update_3d_viewport_input_tracking():
	var can_capture_mouse = is_mouse_in_3d_viewport_range and not is_any_menu_popup_visible
	var can_capture_keyboard = is_3d_viewport_focused and not is_any_menu_popup_visible
	room_3d_display.can_capture_mouse = can_capture_mouse and not is_3d_editor_control_active
	room_3d_display.can_capture_keyboard = can_capture_keyboard
	room_3d_display.can_select = not is_3d_editor_control_active
	room_3d_display_camera.can_capture_mouse = can_capture_mouse
	room_3d_display_camera.can_capture_keyboard = can_capture_keyboard
	room_editor_controls_display.can_capture_mouse = can_capture_mouse

func update_3d_cursor_position():
	if transform_tool_names.has(current_tool):
		var selection_count = len(room_3d_display.selected_nodes)
		if selection_count > 0:
			room_editor_controls_display_cursor.show()
			var average_position: Vector3 = Vector3()
			for node in room_3d_display.selected_nodes:
				if node.selection_transform_node:
					average_position += node.selection_transform_node.get_global_transform().origin
			average_position = average_position / selection_count
			room_editor_controls_display_cursor.translation = average_position
		else:
			room_editor_controls_display_cursor.hide()

func setup_after_load():
	editor.load_room_edits()
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

func tree_uncollapse_from_item(item: TreeItem):
	item.set_collapsed(false)
	var parent = item.get_parent()
	if parent != null:
		tree_uncollapse_from_item(parent)
