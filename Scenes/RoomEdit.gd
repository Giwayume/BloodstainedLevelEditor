extends Control


var viewport_ui_container_normal_style = preload("res://EditorTheme/ViewportUiContainerNormal.tres")
var viewport_ui_container_focus_style = preload("res://EditorTheme/ViewportUiContainerFocus.tres")
var icon_action_copy = preload("res://Icons/Editor/ActionCopy.svg")
var icon_remove = preload("res://Icons/Editor/Remove.svg")
var icon_reload = preload("res://Icons/Editor/Reload.svg")
var selectable_types = ["StaticMeshActor", "StaticMeshComponent"]

var default_level_name = "m02VIL_003"

var editor: Node
var uasset_parser: Node

var parse_pak_thread: Thread
var get_room_definition_thread: Thread
var parse_blueprint_thread: Thread
var place_nodes_thread: Thread
var blueprint_definitions_pending_load: Array = []

var asset_explorer: Control
var character_selection_dialog: Control
var editor_container: Control
var enemy_difficulty_select_option_button: OptionButton
var enemy_add_button: Button
var enemy_delete_button: Button
var level_outline_tab_container: TabContainer
var loading_3d_scene_notification: Control
var loading_status_container: Control
var loading_status_label: Label
var menu_bar: Control
var panel_asset_info: Control
var panel_character_params: Control
var panel_light: Control
var panel_mesh_info: Control
var panel_selection_type_label: Label
var panel_transform: Control
var room_3d_display: Spatial
var room_3d_display_camera: Camera
var room_3d_focus_container: PanelContainer
var room_3d_viewport_container: ViewportContainer
var room_editor_controls_display: Spatial
var room_editor_controls_display_camera: Camera
var room_editor_controls_display_cursor: Spatial
var tree_popup_menu: PopupMenu
var viewport_toolbar: Control

var trees: Dictionary = {
	"bg": {
		"tab_index": 0,
		"tree": null,
		"root_item": null,
		"node_id_map": {},
		"tree_id_map": {},
		"restore_collapse_state": {}
	},
	"enemy": {
		"tab_index": 1,
		"tab_section_index": 0,
		"tree": null,
		"root_item": null,
		"node_id_map": {},
		"tree_id_map": {},
		"restore_collapse_state": {}
	},
	"enemy_hard": {
		"tab_index": 1,
		"tab_section_index": 2,
		"tree": null,
		"root_item": null,
		"node_id_map": {},
		"tree_id_map": {},
		"restore_collapse_state": {}
	},
	"enemy_normal": {
		"tab_index": 1,
		"tab_section_index": 1,
		"tree": null,
		"root_item": null,
		"node_id_map": {},
		"tree_id_map": {},
		"restore_collapse_state": {}
	},
	"gimmick": {
		"tab_index": 2,
		"tree": null,
		"root_item": null,
		"node_id_map": {},
		"tree_id_map": {},
		"restore_collapse_state": {}
	},
	"setting": {
		"tab_index": 3,
		"tree": null,
		"root_item": null,
		"node_id_map": {},
		"tree_id_map": {},
		"restore_collapse_state": {}
	},
	"event": {
		"tab_index": 4,
		"tree": null,
		"root_item": null,
		"node_id_map": {},
		"tree_id_map": {},
		"restore_collapse_state": {}
	},
	"light": {
		"tab_index": 5,
		"tree": null,
		"root_item": null,
		"node_id_map": {},
		"tree_id_map": {},
		"restore_collapse_state": {}
	},
	"rv": {
		"tab_index": 6,
		"tree": null,
		"root_item": null,
		"node_id_map": {},
		"tree_id_map": {},
		"restore_collapse_state": {}
	}
}
enum {
	TREE_POPUP_ADD,
	TREE_POPUP_CLONE,
	TREE_POPUP_DELETE,
	TREE_POPUP_REMOVE_EDITS,
	TREE_POPUP_UNDELETE
}
var tree_popup_menu_items: Array = [
	{
		"id": TREE_POPUP_DELETE,
		"type": "icon",
		"texture": icon_remove,
		"label": "Delete"
	},
	{
		"id": TREE_POPUP_UNDELETE,
		"type": "icon",
		"texture": icon_reload,
		"label": "Un-Delete"
	},
	{
		"id": TREE_POPUP_REMOVE_EDITS,
		"type": "icon",
		"texture": icon_reload,
		"label": "Remove All Edits"
	}
]

# {
#	"bg": 
# }
var room_definition: Dictionary

var current_tool: String = "move"
var transform_tool_names = ["select", "move", "rotate", "scale"]
var is_any_dialog_visible: bool = false
var is_any_menu_popup_visible: bool = false
var is_mouse_in_3d_viewport_range: bool = false
var is_panel_popup_blocking: bool = false
var is_3d_viewport_focused: bool = false
var is_3d_editor_control_active: bool = false
var is_window_focused: bool = true
var selected_node_initial_transforms: Array = []
var ignore_tree_multi_selected_signal: bool = false

#############
# LIFECYCLE #
#############

func _ready():
	editor = get_node("/root/Editor");
	uasset_parser = get_node("/root/UAssetParser")
	
	if not editor.selected_package:
		editor.selected_package = "MyTest"
	if not editor.selected_level_name:
		var last_edited_level_name = editor.read_config_prop("last_edited_level_name")
		if last_edited_level_name != null:
			editor.selected_level_name = last_edited_level_name
		else:
			editor.selected_level_name = default_level_name
	editor.write_config_prop("last_edited_level_name", editor.selected_level_name)
	
	asset_explorer = find_node("AssetExplorer", true, true)
	character_selection_dialog = find_node("CharacterSelectionDialog", true, true)
	enemy_difficulty_select_option_button = find_node("EnemyDifficultySelectOptionButton", true, true)
	enemy_add_button = find_node("EnemyAddButton", true, true)
	enemy_delete_button = find_node("EnemyDeleteButton", true, true)
	editor_container = find_node("EditorContainer", true, true)
	level_outline_tab_container = find_node("LevelOutlineTabContainer", true, true)
	loading_3d_scene_notification = find_node("Loading3dSceneNotification", true, true)
	loading_status_container = find_node("LoadingStatusContainer", true, true)
	loading_status_label = find_node("LoadingStatusLabel", true, true)
	menu_bar = find_node("RoomEditMenuBar", true, true)
	panel_asset_info = find_node("AssetInfoPanel", true, true)
	panel_character_params = find_node("CharacterParamsPanel", true, true)
	panel_light = find_node("LightPanel", true, true)
	panel_mesh_info = find_node("MeshInfoPanel", true, true)
	panel_selection_type_label = find_node("PanelSelectionTypeLabel", true, true)
	panel_transform = find_node("TransformPanel", true, true)
	room_3d_display = find_node("Room3dDisplay", true, true)
	room_3d_display_camera = room_3d_display.find_node("Camera", true, true)
	room_3d_focus_container = find_node("Room3dFocusContainer", true, true)
	room_3d_viewport_container = find_node("Room3dViewportContainer", true, true)
	room_editor_controls_display = find_node("RoomEditorControlsDisplay", true, true)
	room_editor_controls_display_camera = room_editor_controls_display.find_node("Camera", true, true)
	room_editor_controls_display_cursor = room_editor_controls_display.find_node("ObjectTransformCursor", true, true)
	trees["bg"].tree = find_node("BackgroundTree", true, true)
	trees["enemy"].tree = find_node("EnemySharedTree", true, true)
	trees["enemy_hard"].tree = find_node("EnemyHardTree", true, true)
	trees["enemy_normal"].tree = find_node("EnemyNormalTree", true, true)
	trees["event"].tree = find_node("EventTree", true, true)
	trees["gimmick"].tree = find_node("GimmickTree", true, true)
	trees["light"].tree = find_node("LightTree", true, true)
	trees["setting"].tree = find_node("SettingTree", true, true)
	trees["rv"].tree = find_node("RvTree", true, true)
	tree_popup_menu = find_node("TreePopupMenu", true, true)
	viewport_toolbar = find_node("RoomEditViewportToolbar", true, true)
	
	editor_container.hide()
	loading_status_container.show()
	loading_3d_scene_notification.hide()
	panel_asset_info.hide()
	panel_character_params.hide()
	panel_mesh_info.hide()
	panel_transform.hide()
	
	for tree_name in trees:
		trees[tree_name].root_item = trees[tree_name].tree.create_item()
		trees[tree_name].root_item.set_text(0, "World")
		trees[tree_name].root_item.disable_folding = true
	
	for tree_name in trees:
		trees[tree_name].tree.connect("multi_selected", self, "on_tree_multi_selected", [tree_name])
		trees[tree_name].tree.connect("item_rmb_selected", self, "on_tree_rmb_selected", [tree_name])
	editor.connect("history_changed", self, "on_history_changed")
	character_selection_dialog.connect("about_to_show", self, "on_show_any_dialog")
	character_selection_dialog.connect("popup_hide", self, "on_hide_any_dialog")
	character_selection_dialog.connect("character_selected", self, "on_character_add")
	enemy_difficulty_select_option_button.connect("item_selected", self, "on_enemy_difficulty_item_selected")
	enemy_add_button.connect("pressed", self, "on_enemy_add")
	enemy_delete_button.connect("pressed", self, "on_enemy_delete")
	menu_bar.connect("popup_visibility_changed", self, "on_menu_bar_popup_visibility_changed")
	panel_asset_info.connect("open_uassetgui", self, "on_open_uasset_gui")
	panel_light.connect("popup_blocking_changed", self, "on_panel_popup_blocking_changed")
	room_3d_display.connect("loading_start", self, "on_room_3d_display_loading_start")
	room_3d_display.connect("loading_end", self, "on_room_3d_display_loading_end")
	room_3d_display.connect("selection_changed", self, "on_room_3d_display_selection_changed")
	room_3d_display_camera.connect("transform_changed", self, "on_room_3d_display_camera_transform_changed")
	room_3d_focus_container.connect("focus_entered", self, "on_room_3d_focus_container_focus")
	room_3d_focus_container.connect("focus_exited", self, "on_room_3d_focus_container_blur")
	room_editor_controls_display.connect("control_active", self, "on_room_editor_controls_display_control_active")
	room_editor_controls_display.connect("control_inactive", self, "on_room_editor_controls_display_control_inactive")
	room_editor_controls_display_cursor.connect("rotate_cancel", self, "on_transform_cancel_selection")
	room_editor_controls_display_cursor.connect("rotate_preview", self, "on_rotate_preview_selection")
	room_editor_controls_display_cursor.connect("rotate", self, "on_rotate_selection")
	room_editor_controls_display_cursor.connect("scale_cancel", self, "on_transform_cancel_selection")
	room_editor_controls_display_cursor.connect("scale_preview", self, "on_scale_preview_selection")
	room_editor_controls_display_cursor.connect("scale", self, "on_scale_selection")
	room_editor_controls_display_cursor.connect("translate_cancel", self, "on_transform_cancel_selection")
	room_editor_controls_display_cursor.connect("translate_preview", self, "on_translate_preview_selection")
	room_editor_controls_display_cursor.connect("translate", self, "on_translate_selection")
	tree_popup_menu.connect("id_pressed", self, "on_tree_popup_menu_id_pressed")
	viewport_toolbar.connect("popup_visibility_changed", self, "on_menu_bar_popup_visibility_changed")
	viewport_toolbar.connect("tool_changed", self, "on_tool_changed")
	viewport_toolbar.connect("view_gizmo_toggled", self, "on_view_gizmo_toggled")
	
	start_parse_pak_thread()

func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		call_deferred("notify_window_focused_deferred")
	elif what == MainLoop.NOTIFICATION_WM_FOCUS_OUT:
		is_window_focused = false
		update_3d_viewport_input_tracking()

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
	
	# Handle mouse events
	if event is InputEventMouseButton:
		if is_mouse_in_3d_viewport_range and room_3d_display.can_capture_mouse and event.pressed:
			room_3d_focus_container.call_deferred("grab_focus")
	
	# Handle keyboard events
	if event is InputEventKey:
		if event.scancode == KEY_DELETE:
			if event.pressed:
				var focus_owner = get_focus_owner()
				var is_delete_node_focus_owner: bool = false
				if focus_owner == room_3d_focus_container:
					is_delete_node_focus_owner = true
				if not is_delete_node_focus_owner:
					for tree_name in trees:
						if trees[tree_name].tree == focus_owner:
							is_delete_node_focus_owner = true
							break
				if is_delete_node_focus_owner and room_3d_display.selected_nodes.size() > 0:
					delete_selected_nodes()

func _exit_tree():
	editor.save_room_edits()
	editor.room_edits = null
	editor.clear_action_history()

###########
# THREADS #
###########

# Get a list of assets in the pak files

func start_parse_pak_thread():
	parse_pak_thread = Thread.new()
	parse_pak_thread.start(self, "parse_pak_thread_function")
	loading_status_label.text = "Reading .pak files..."

func parse_pak_thread_function(_noop):
	uasset_parser.GuaranteeAssetListFromPakFiles()
	call_deferred("end_parse_pak_thread")

func end_parse_pak_thread():
	parse_pak_thread.wait_to_finish()
	print_debug("parse pak complete")
	start_get_room_definition_thread()

# Build the "room_definition" object, which represents the entire tree for Godot

func start_get_room_definition_thread():
	get_room_definition_thread = Thread.new()
	get_room_definition_thread.start(self, "get_room_definition_thread_function")
	loading_status_label.text = "Reading the room's assets..."

func get_room_definition_thread_function(_noop):
	room_definition = uasset_parser.GetRoomDefinition(editor.selected_level_name)
	call_deferred("end_get_room_definition_thread")

func end_get_room_definition_thread():
	get_room_definition_thread.wait_to_finish()
	print_debug("get room def complete")
	start_parse_blueprint_thread()

func start_parse_blueprint_thread():
	Editor.load_room_edits()
	blueprint_definitions_pending_load = []
	for tree_name in trees:
		if Editor.room_edits.has(tree_name) and Editor.room_edits[tree_name].has("new_exports"):
			for export_definition in Editor.room_edits[tree_name]["new_exports"]:
				if export_definition.has("blueprint"):
					blueprint_definitions_pending_load.push_back(export_definition["blueprint"])
	
	parse_blueprint_thread = Thread.new()
	parse_blueprint_thread.start(self, "parse_blueprint_thread_function")
	loading_status_label.text = "Gathering blueprints..."

func parse_blueprint_thread_function(_noop):
	uasset_parser.ParseAndCacheBlueprints(blueprint_definitions_pending_load);
	call_deferred("end_parse_blueprint_thread")

func prefix_export_index_recursive(definition, prefix: int):
	definition.export_index = prefix + definition.export_index
	definition.outer_export_index = prefix + definition.outer_export_index
	if definition.has("mesh_export_index"):
		definition.mesh_export_index = prefix + definition.mesh_export_index
	if definition.has("root_component_export_index"):
		definition.root_component_export_index = prefix + definition.root_component_export_index
	if definition.has("children"):
		for child in definition.children:
			prefix_export_index_recursive(child, prefix)

func end_parse_blueprint_thread():
	parse_blueprint_thread.wait_to_finish()

	blueprint_definitions_pending_load = []
	
	var game_directory = editor.read_config()["game_directory"]
	for tree_name in trees:
		if Editor.room_edits.has(tree_name) and Editor.room_edits[tree_name].has("new_exports"):
			for export_definition in Editor.room_edits[tree_name]["new_exports"]:
				if export_definition.has("blueprint"):
					var blueprint_snippet = uasset_parser.BlueprintSnippetRoomDefinitions[(
						game_directory + "/BloodstainedRotN/Content/Paks/" + export_definition.blueprint.file + '|' +
						export_definition.blueprint.asset + '|' +
						export_definition.blueprint.object_name
					)]
					prefix_export_index_recursive(blueprint_snippet, 10000)
					for child in room_definition[tree_name].children:
						if child.type == "Level":
							child.children.push_back(blueprint_snippet)
							
#	var game_directory = editor.read_config()["game_directory"]
#	var selected_package_name = editor.selected_package
#	var user_project_path = ProjectSettings.globalize_path("user://UserPackages/" + selected_package_name)

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
	print_debug("parse blueprints complete")
	start_place_nodes_thread()

func start_place_nodes_thread():
	place_nodes_thread = Thread.new()
	place_nodes_thread.start(self, "place_nodes_thread_function")
	loading_status_label.text = "Placing the room's assets..."

func place_nodes_thread_function(_noop):
	setup_3d_view()
	build_object_outlines()
	call_deferred("end_place_nodes_thread")

func end_place_nodes_thread():
	place_nodes_thread.wait_to_finish()
	print_debug("place nodes complete")
	threads_finished()

func threads_finished():
	room_3d_display.is_initial_thread_load_complete = true
	room_3d_display.start_3d_model_extraction()
	editor_container.show()
	loading_status_container.hide()
	setup_after_load()

#############
# CALLBACKS #
#############

func on_panel_popup_blocking_changed(blocking: bool):
	is_panel_popup_blocking = blocking

var tree_multi_selection_buffer = null

func on_tree_multi_selected(item: TreeItem, column: int, selected: bool, tree_name: String):
	if not ignore_tree_multi_selected_signal:
		ignore_tree_multi_selected_signal = true
		if tree_multi_selection_buffer == null:
			tree_multi_selection_buffer = []
		tree_multi_selection_buffer.push_back({
			"item": item,
			"column": column,
			"selected": selected,
			"tree_name": tree_name
		})
		call_deferred("on_tree_multi_selected_deferred")
		ignore_tree_multi_selected_signal = false

func tree_multi_selection_buffer_compare(a, b):
	if !a.selected && b.selected:
		return true
	return false

func on_tree_multi_selected_deferred():
	if not ignore_tree_multi_selected_signal:
		ignore_tree_multi_selected_signal = true
		if tree_multi_selection_buffer != null:
			tree_multi_selection_buffer.sort_custom(self, "tree_multi_selection_buffer_compare")
			for multi_selection in tree_multi_selection_buffer:
				var item = multi_selection["item"]
				var column = multi_selection["column"]
				var selected = multi_selection["selected"]
				var tree_name = multi_selection["tree_name"]
				if selected:
					for node in room_3d_display.selected_nodes:
						if node.tree_name != tree_name:
							node.deselect()
							room_3d_display.selected_nodes.erase(node)
							if trees[node.tree_name].tree_id_map.has(node.definition.export_index):
								trees[node.tree_name].tree_id_map[node.definition.export_index].deselect(0)
				var selected_nodes = room_3d_display.selected_nodes
				var current_tree: Dictionary = trees[tree_name]
				var export_index: int = item.get_metadata(0).export_index
				var node = current_tree.node_id_map[export_index]
				if selected:
					node.select()
					room_3d_display.selected_nodes.push_back(node)
				else:
					node.deselect()
					room_3d_display.selected_nodes.erase(node)
			update_panels_after_selection()
			update_3d_cursor_position()
			tree_multi_selection_buffer = null
		ignore_tree_multi_selected_signal = false

func on_tree_rmb_selected(position: Vector2, tree_name: String):
	call_deferred("on_tree_rmb_selected_deferred", position, tree_name)

func on_tree_rmb_selected_deferred(position: Vector2, tree_name: String):
	build_tree_popup_menu()
	var viewport_size = get_viewport().size
	var popup_position: Vector2 = trees[tree_name].tree.rect_global_position + position
	tree_popup_menu.popup()
	tree_popup_menu.rect_global_position = popup_position
	tree_popup_menu.set_as_minsize()
	if popup_position.x + tree_popup_menu.rect_size.x > viewport_size.x:
		popup_position.x = viewport_size.x - tree_popup_menu.rect_size.x
	if popup_position.y + tree_popup_menu.rect_size.y > viewport_size.y:
		popup_position.y = viewport_size.y - tree_popup_menu.rect_size.y
	tree_popup_menu.rect_global_position = popup_position

func on_tree_popup_menu_id_pressed(id: int):
	if id == TREE_POPUP_DELETE:
		delete_selected_nodes()
	elif id == TREE_POPUP_UNDELETE:
		undelete_selected_nodes()
	elif id == TREE_POPUP_REMOVE_EDITS:
		revert_selected_nodes()

func on_history_changed(action: HistoryAction):
	var ids = action.get_ids()
	var is_update_3d_cursor_position: bool = false
	var is_rebuild_object_outlines: bool = false
	var is_clear_selection: bool = false
	
	if (
		ids.has(HistoryAction.ID.SPATIAL_TRANSFORM) or
		ids.has(HistoryAction.ID.REVERT_COMPONENT)
	):
		is_update_3d_cursor_position = true
	if (
		ids.has(HistoryAction.ID.DELETE_COMPONENT) or
		ids.has(HistoryAction.ID.UNDELETE_COMPONENT) or
		ids.has(HistoryAction.ID.REVERT_COMPONENT)
	):
		is_rebuild_object_outlines = true
		if not ids.has(HistoryAction.ID.REVERT_COMPONENT):
			is_clear_selection = true
	
	if is_clear_selection:
		clear_selection()
	if is_update_3d_cursor_position:
		update_3d_cursor_position()
	if is_rebuild_object_outlines:
		build_object_outlines()

func on_menu_bar_popup_visibility_changed(is_visible):
	is_any_menu_popup_visible = is_visible

func on_show_any_dialog():
	is_any_dialog_visible = true
	update_3d_viewport_input_tracking()

func on_hide_any_dialog():
	is_any_dialog_visible = (
		character_selection_dialog.visible
	)
	update_3d_viewport_input_tracking()

func on_enemy_difficulty_item_selected(index: int):
	var current_index = -1
	if trees["enemy"].tree.visible:
		current_index = 0
	elif trees["enemy_normal"].tree.visible:
		current_index = 1
	elif trees["enemy_hard"].tree.visible:
		current_index = 2
	trees["enemy"].tree.visible = (index == 0)
	for child in room_3d_display.asset_roots["enemy"].get_children():
		if child.has_method("set_hidden"):
			child.set_hidden(index != 0)
	trees["enemy_normal"].tree.visible = (index == 1)
	for child in room_3d_display.asset_roots["enemy_normal"].get_children():
		if child.has_method("set_hidden"):
			child.set_hidden(index != 1)
	trees["enemy_hard"].tree.visible = (index == 2)
	for child in room_3d_display.asset_roots["enemy_hard"].get_children():
		if child.has_method("set_hidden"):
			child.set_hidden(index != 2)
	if index != current_index:
		call_deferred("clear_selection")

func on_enemy_add():
	character_selection_dialog.popup_centered_ratio(.75)

func on_enemy_delete():
	delete_selected_nodes()

func on_room_3d_display_camera_transform_changed(transform):
	room_editor_controls_display_camera.transform = transform

func on_room_3d_display_loading_start():
	loading_3d_scene_notification.show()

func on_room_3d_display_loading_end():
	loading_3d_scene_notification.hide()

func on_room_3d_display_selection_changed(selected_nodes):
	var selected_nodes_by_tree_name = {}
	for node in selected_nodes:
		if not selected_nodes_by_tree_name.has(node.tree_name):
			selected_nodes_by_tree_name[node.tree_name] = []
		selected_nodes_by_tree_name[node.tree_name].push_back(node)
	var last_tree_name = ""
	for tree_name in trees:
		var current_tree: Dictionary = trees[tree_name]
		var remaining_selected_nodes: Array = []
		if selected_nodes_by_tree_name.has(tree_name):
			remaining_selected_nodes = selected_nodes_by_tree_name[tree_name].duplicate(false)
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
		if selected_nodes_by_tree_name.has(tree_name):
			last_tree_name = tree_name
	if last_tree_name:
		level_outline_tab_container.current_tab = trees[last_tree_name].tab_index
		if trees[last_tree_name].has("tab_section_index"):
			on_enemy_difficulty_item_selected(trees[last_tree_name].tab_section_index)
	update_panels_after_selection()
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
		var selection_count = len(room_3d_display.selected_nodes)
		room_editor_controls_display_cursor.set_mode(current_tool)
		room_editor_controls_display_cursor.set_disabled(selection_count == 0)
	else:
		room_editor_controls_display_cursor.set_disabled(true)

func on_view_gizmo_toggled(gizmo_name: String, toggled: bool):
	room_3d_display.emit_signal("view_gizmo_toggled", gizmo_name, toggled)

func on_rotate_preview_selection(axis: Vector3, phi: float):
	var rotate_transform = Transform()
	rotate_transform = rotate_transform.rotated(axis, phi)
	var translate_transform = Transform()
	translate_transform = translate_transform.translated(room_editor_controls_display_cursor.translation)
	var translate_back_transform = Transform()
	translate_back_transform = translate_back_transform.translated(-room_editor_controls_display_cursor.translation)
	if len(selected_node_initial_transforms) != len(room_3d_display.selected_nodes):
		selected_node_initial_transforms = []
		for node in room_3d_display.selected_nodes:
			if node.selection_transform_node:
				selected_node_initial_transforms.push_back(node.selection_transform_node.get_global_transform())
			else:
				selected_node_initial_transforms.push_back(Transform())
	var index: int = 0
	for node in room_3d_display.selected_nodes:
		if node.selection_transform_node:
			node.selection_transform_node.global_transform = translate_transform * rotate_transform * translate_back_transform * selected_node_initial_transforms[index]
		index += 1

func on_rotate_selection(axis: Vector3, phi: float):
	var rotate_transform = Transform()
	rotate_transform = rotate_transform.rotated(axis, phi)
	var translate_transform = Transform()
	translate_transform = translate_transform.translated(room_editor_controls_display_cursor.translation)
	var translate_back_transform = Transform()
	translate_back_transform = translate_back_transform.translated(-room_editor_controls_display_cursor.translation)
	if len(selected_node_initial_transforms) == len(room_3d_display.selected_nodes):
		var actions: Array = []
		var index: int = 0
		for node in room_3d_display.selected_nodes:
			if node.selection_transform_node:
				actions.push_back(
					SpatialTransformAction.new(
						node.selection_transform_node,
						selected_node_initial_transforms[index],
						translate_transform * rotate_transform * translate_back_transform * selected_node_initial_transforms[index]
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

func on_scale_preview_selection(scale: Vector3):
	var scale_transform = Transform()
	scale_transform = scale_transform.scaled(scale)
	var translate_transform = Transform()
	translate_transform = translate_transform.translated(room_editor_controls_display_cursor.translation)
	var translate_back_transform = Transform()
	translate_back_transform = translate_back_transform.translated(-room_editor_controls_display_cursor.translation)
	if len(selected_node_initial_transforms) != len(room_3d_display.selected_nodes):
		selected_node_initial_transforms = []
		for node in room_3d_display.selected_nodes:
			if node.selection_transform_node:
				selected_node_initial_transforms.push_back(node.selection_transform_node.get_global_transform())
			else:
				selected_node_initial_transforms.push_back(Transform())
	var index: int = 0
	for node in room_3d_display.selected_nodes:
		if node.selection_transform_node:
			node.selection_transform_node.global_transform = translate_transform * scale_transform * translate_back_transform * selected_node_initial_transforms[index]
		index += 1

func on_scale_selection(scale: Vector3):
	var scale_transform = Transform()
	scale_transform = scale_transform.scaled(scale)
	var translate_transform = Transform()
	translate_transform = translate_transform.translated(room_editor_controls_display_cursor.translation)
	var translate_back_transform = Transform()
	translate_back_transform = translate_back_transform.translated(-room_editor_controls_display_cursor.translation)
	if len(selected_node_initial_transforms) == len(room_3d_display.selected_nodes):
		var actions: Array = []
		var index: int = 0
		for node in room_3d_display.selected_nodes:
			if node.selection_transform_node:
				actions.push_back(
					SpatialTransformAction.new(
						node.selection_transform_node,
						selected_node_initial_transforms[index],
						translate_transform * scale_transform * translate_back_transform * selected_node_initial_transforms[index]
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

func on_transform_cancel_selection():
	var index: int = 0
	for node in room_3d_display.selected_nodes:
		if node.selection_transform_node:
			node.selection_transform_node.global_transform = selected_node_initial_transforms[index]
		index += 1
	selected_node_initial_transforms = []
	update_3d_cursor_position()

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
	var index: int = 0
	for node in room_3d_display.selected_nodes:
		if node.selection_transform_node:
			node.selection_transform_node.global_transform = offset_transform * selected_node_initial_transforms[index]
		index += 1

func on_translate_selection(offset: Vector3):
	var offset_transform = Transform()
	offset_transform = offset_transform.translated(offset)
	if len(selected_node_initial_transforms) == len(room_3d_display.selected_nodes):
		var actions: Array = []
		var index: int = 0
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

func on_character_add(character_profile):
	print_debug(character_profile)

func on_open_uasset_gui():
	var current_tree_name
	for tree_name in trees:
		if level_outline_tab_container.current_tab == trees[tree_name].tab_index:
			current_tree_name = tree_name
	OS.execute(ProjectSettings.globalize_path("res://VendorBinary/UAssetGUI/UAssetGUI.exe"), [
		# ProjectSettings.globalize_path("user://PakExtract/" + room_definition.level_assets[current_tree_name]),
		# "VER_UE4_22"
	], false)

###########
# METHODS #
###########

func delete_selected_nodes():
	var delete_actions: Array = []
	for node in room_3d_display.selected_nodes:
		if not (node.definition.has("deleted") and node.definition["deleted"]):
			delete_actions.push_back(
				DeleteComponentAction.new(node)
			)
	if delete_actions.size() > 0:
		Editor.do_action(
			HistoryGroupAction.new("Delete Component(s)", delete_actions)
		)

func undelete_selected_nodes():
	var undelete_actions: Array = []
	for node in room_3d_display.selected_nodes:
		if node.definition.has("deleted") and node.definition["deleted"]:
			undelete_actions.push_back(
				UndeleteComponentAction.new(node)
			)
	if undelete_actions.size() > 0:
		Editor.do_action(
			HistoryGroupAction.new("Un-Delete Component(s)", undelete_actions)
		)

func revert_selected_nodes():
	var revert_actions: Array = []
	for node in room_3d_display.selected_nodes:
		revert_actions.push_back(
			RevertComponentAction.new(node)
		)
	if revert_actions.size() > 0:
		Editor.do_action(
			HistoryGroupAction.new("Revert Changes to Component(s)", revert_actions)
		)

func clear_selection():
	for node in room_3d_display.selected_nodes.duplicate(false):
		node.deselect()
		room_3d_display.selected_nodes.erase(node)
		trees[node.tree_name].tree_id_map[node.definition.export_index].deselect(0)
	update_3d_cursor_position()

func update_3d_viewport_input_tracking():
	var can_capture_mouse = (
		is_mouse_in_3d_viewport_range and
		not is_any_menu_popup_visible and
		not is_any_dialog_visible and
		not is_panel_popup_blocking and
		is_window_focused
	)
	var can_capture_keyboard = (
		is_3d_viewport_focused and
		not is_any_menu_popup_visible and
		not is_any_dialog_visible and
		is_window_focused
	)
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
			var transformable_count: int = 0
			room_editor_controls_display_cursor.set_disabled(false)
			var average_position: Vector3 = Vector3()
			for node in room_3d_display.selected_nodes:
				if node.selection_transform_node:
					average_position += node.selection_transform_node.get_global_transform().origin
					transformable_count += 1
			if transformable_count > 0:
				average_position = average_position / transformable_count
				room_editor_controls_display_cursor.translation = average_position
			else:
				room_editor_controls_display_cursor.set_disabled(true)
		else:
			room_editor_controls_display_cursor.set_disabled(true)

func update_panels_after_selection():
	var selection_count: int = room_3d_display.selected_nodes.size()
	# Component type panel
	if selection_count == 1:
		var definition = room_3d_display.selected_nodes[0].definition
		panel_selection_type_label.text = definition.type
		if definition.type == "DynamicClass":
			panel_selection_type_label.text += "\n" + definition.class_constructor
	elif selection_count > 1:
		panel_selection_type_label.text = "Multiple Selection (" + str(selection_count) + ")"
	else:
		panel_selection_type_label.text = "Nothing Selected"
	
	# Character params panel
	if selection_count == 1 and room_3d_display.selected_nodes[0].definition.type == "Character":
		panel_character_params.show()
		panel_character_params.set_selected_nodes(room_3d_display.selected_nodes)
	else:
		panel_character_params.hide()
	
	# Light panel
	if selection_count == 1 and room_3d_display.selected_nodes[0]["selection_light_node"] != null:
		panel_light.show()
		panel_light.set_selected_nodes(room_3d_display.selected_nodes)
	else:
		panel_light.hide()
	
	# Mesh and transform panels
	if selection_count == 1 and room_3d_display.selected_nodes[0]["selection_transform_node"] != null:
		if room_3d_display.selected_nodes[0]["selection_transform_node"].definition.has("static_mesh_name_instance"):
			panel_mesh_info.show()
			panel_mesh_info.set_selected_nodes(room_3d_display.selected_nodes)
		else:
			panel_mesh_info.hide()
		panel_transform.show()
		panel_transform.set_selected_nodes(room_3d_display.selected_nodes)
	else:
		panel_mesh_info.hide()
		panel_transform.hide()

	# Asset info panel
	if selection_count == 1:
		panel_asset_info.show()
		panel_asset_info.set_selected_nodes(room_3d_display.selected_nodes)
	else:
		panel_asset_info.hide()

func setup_after_load():
	update_panels_after_selection()
	asset_explorer.load_asset_list()
	on_enemy_difficulty_item_selected(0)

func setup_3d_view():
	room_3d_display.set_room_definition(room_definition)

func build_tree_popup_menu():
	tree_popup_menu.clear()
	var is_delete_option: bool = false
	for node in room_3d_display.selected_nodes:
		if not (node.definition.has("deleted") and node.definition["deleted"]):
			is_delete_option = true
	for item in tree_popup_menu_items:
		if item.id == TREE_POPUP_DELETE and not is_delete_option:
			continue
		if item.id == TREE_POPUP_UNDELETE and is_delete_option:
			continue
		build_popup_menu_item(item, tree_popup_menu)

func build_popup_menu_item(item, popup_menu):
	if item.type == "icon":
		popup_menu.add_icon_item(item.texture, item.label, item.id)
	elif item.type == "separator":
		popup_menu.add_separator()

func build_object_outlines():
	for tree_name in trees:
		for id in trees[tree_name].tree_id_map:
			trees[tree_name].restore_collapse_state[id] = trees[tree_name].tree_id_map[id].collapsed
		trees[tree_name].tree_id_map.clear()
		trees[tree_name].node_id_map.clear()
		trees[tree_name].tree.clear()
		build_object_outline(
			trees[tree_name].tree,
			trees[tree_name].root_item,
			trees[tree_name].tree_id_map,
			trees[tree_name].node_id_map,
			trees[tree_name].restore_collapse_state,
			room_3d_display.find_node("AssetTrees", true, true).get_node(tree_name)
		)
		trees[tree_name].restore_collapse_state = {}

func build_object_outline(tree: Tree, parent_item: TreeItem, tree_id_map: Dictionary, node_id_map: Dictionary, restore_collapse_state: Dictionary, parent_node: Node):
	var placement_node = parent_node
	if "alternate_child_placement_node" in parent_node and parent_node.alternate_child_placement_node != null:
		placement_node = parent_node.alternate_child_placement_node
	for child_node in placement_node.get_children():
		if child_node == null or not "definition" in child_node:
			return
		var definition = child_node.definition
		var export_index = definition["export_index"]
		var is_deleted: bool = false
		if definition.has("deleted") and definition["deleted"]:
			is_deleted = true
		var tree_item: TreeItem = tree.create_item(parent_item)
		var is_selectable = selectable_types.has(definition["type"])
		if restore_collapse_state.has(export_index):
			tree_item.set_collapsed(restore_collapse_state[export_index])
		else:
			tree_item.set_collapsed(true)
		tree_item.set_text(0, definition["name"])
		tree_item.set_metadata(0, {
			"export_index": export_index
		})
		tree_item.set_selectable(0, true)
		if is_deleted:
			tree_item.set_custom_color(0, Color("c14224"))
			tree_item.set_suffix(0, "(DELETED)")
		tree_id_map[export_index] = tree_item
		node_id_map[export_index] = child_node
		if not is_deleted:
			build_object_outline(tree, tree_item, tree_id_map, node_id_map, restore_collapse_state, child_node)

func tree_uncollapse_from_item(item: TreeItem):
	item.set_collapsed(false)
	var parent = item.get_parent()
	if parent != null:
		tree_uncollapse_from_item(parent)

func notify_window_focused_deferred():
	is_window_focused = true
	update_3d_viewport_input_tracking()
