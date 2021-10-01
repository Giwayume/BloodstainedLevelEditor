extends Control

var enemy_profiles = load("res://Config/EnemyProfiles.gd").enemy_profiles

var editor: Node
var uasset_parser: Node

var parse_pak_thread: Thread
var get_room_definition_thread: Thread
var parse_enemy_blueprint_thread: Thread

var background_tree: Tree
var editor_container: Control
var loading_3d_scene_notification: Control
var loading_status_container: Control
var loading_status_label: Label
var menu_button_package: MenuButton
var menu_button_edit: MenuButton
var room_3d_display: Spatial
var room_3d_display_camera: Camera
var room_3d_viewport_container: ViewportContainer

var background_tree_root: TreeItem
var background_tree_map: Dictionary

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
	
	background_tree = find_node("BackgroundTree", true, true)
	editor_container = find_node("EditorContainer", true, true)
	loading_3d_scene_notification = find_node("Loading3dSceneNotification", true, true)
	loading_status_container = find_node("LoadingStatusContainer", true, true)
	loading_status_label = find_node("LoadingStatusLabel", true, true)
	menu_button_package = find_node("PackageMenuButton", true, true)
	menu_button_edit = find_node("EditMenuButton", true, true)
	room_3d_display = find_node("Room3dDisplay", true, true)
	room_3d_display_camera = room_3d_display.find_node("Camera", true, true)
	room_3d_viewport_container = find_node("Room3dViewportContainer", true, true)
	
	editor_container.hide()
	loading_status_container.show()
	loading_3d_scene_notification.hide()
	
	background_tree_root = background_tree.create_item()
	background_tree_root.set_text(0, "World")
	
	menu_button_package.get_popup().connect("id_pressed", self, "on_menu_popup_package_pressed")
	
	room_3d_display.connect("loading_start", self, "on_room_3d_display_loading_start")
	room_3d_display.connect("loading_end", self, "on_room_3d_display_loading_end")
	
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
	room_3d_display.can_capture_mouse = can_capture_mouse
	room_3d_display_camera.can_capture_mouse = can_capture_mouse
	room_3d_display_camera.viewport_position = viewport_position

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
	setup_3d_view()

#############
# CALLBACKS #
#############

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

###########
# METHODS #
###########

func setup_3d_view():
	room_3d_display.set_room_definition(room_definition)
