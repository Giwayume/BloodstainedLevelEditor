extends Control

var enemy_profiles = load("res://Config/EnemyProfiles.gd").enemy_profiles

var editor: Node
var uasset_parser: Node

var parse_pak_thread: Thread
var parse_enemy_blueprint_thread: Thread

var editor_container: Control
var loading_status_container: Control
var loading_status_label: Label
var menu_button_package: MenuButton
var menu_button_edit: MenuButton
var world_outliner_tree: Tree
var world_outliner_tree_root: TreeItem
var world_outliner_tree_bg: TreeItem
var world_outliner_tree_enemy: TreeItem
var world_outliner_tree_enemy_normal: TreeItem
var world_outliner_tree_enemy_hard: TreeItem
var world_outliner_tree_gimmick: TreeItem
var world_outliner_tree_event: TreeItem
var world_outliner_tree_rv: TreeItem

#############
# LIFECYCLE #
#############

func _ready():
	editor = get_node("/root/Editor");
	uasset_parser = get_node("/root/UAssetParser")
	
	if not editor.selected_package:
		editor.selected_package = "MyTest"
	
	editor_container = find_node("EditorContainer", true, true)
	loading_status_container = find_node("LoadingStatusContainer", true, true)
	loading_status_label = find_node("LoadingStatusLabel", true, true)
	menu_button_package = find_node("PackageMenuButton", true, true)
	menu_button_edit = find_node("EditMenuButton", true, true)
#	world_outliner_tree = find_node("WorldOutlinerTree", true, true)
#	world_outliner_tree_root = world_outliner_tree.create_item()
#	world_outliner_tree_root.set_text(0, "Scene")
#	world_outliner_tree_bg = world_outliner_tree.create_item(world_outliner_tree_root)
#	world_outliner_tree_bg.set_text(0, "Background")
#	world_outliner_tree_enemy = world_outliner_tree.create_item(world_outliner_tree_root)
#	world_outliner_tree_enemy.set_text(0, "Enemy")
#	world_outliner_tree_enemy_normal = world_outliner_tree.create_item(world_outliner_tree_enemy)
#	world_outliner_tree_enemy_normal.set_text(0, "Normal")
#	world_outliner_tree_enemy_hard = world_outliner_tree.create_item(world_outliner_tree_enemy)
#	world_outliner_tree_enemy_hard.set_text(0, "Hard/Nightmare")
#	world_outliner_tree_gimmick = world_outliner_tree.create_item(world_outliner_tree_root)
#	world_outliner_tree_gimmick.set_text(0, "Gimmick")
#	world_outliner_tree_event = world_outliner_tree.create_item(world_outliner_tree_root)
#	world_outliner_tree_event.set_text(0, "Event")
#	world_outliner_tree_rv = world_outliner_tree.create_item(world_outliner_tree_root)
#	world_outliner_tree_rv.set_text(0, "RV")
	
	editor_container.hide()
	loading_status_container.show()
	
	menu_button_package.get_popup().connect("id_pressed", self, "on_menu_popup_package_pressed")
	
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
	
	start_parse_enemy_blueprint_thread()

func start_parse_enemy_blueprint_thread():
	parse_enemy_blueprint_thread = Thread.new()
	parse_enemy_blueprint_thread.start(self, "parse_enemy_blueprint_thread_function")
	loading_status_label.text = "Reading enemy information..."

func parse_enemy_blueprint_thread_function(_noop):
	uasset_parser.ParseEnemyDefinitionsToUserProjectFolder(enemy_profiles);
	call_deferred("end_enemy_blueprint_thread")

func end_enemy_blueprint_thread():
	parse_enemy_blueprint_thread.wait_to_finish()
	
	var game_directory = editor.read_config()["game_directory"]
	var selected_package_name = editor.selected_package
	var user_project_path = ProjectSettings.globalize_path("user://UserPackages/" + selected_package_name)
	
	uasset_parser.ExtractAssetToFolder(
		game_directory + "/BloodstainedRotN/Content/Paks/pakchunk0-WindowsNoEditor.pak",
		"BloodstainedRotN/Content/Core/Environment/ACT04_GDN/Level/m04GDN_016_Enemy.umap",
		user_project_path + "/ModifiedAssets"
	)
	uasset_parser.AddBlueprintToAsset(
		game_directory + "/BloodstainedRotN/Content/Paks/pakchunk0-WindowsNoEditor.pak",
		"BloodstainedRotN/Content/Core/Environment/ACT04_GDN/Level/m04GDN_015_Enemy.umap",
		"Chr_N3091(3)",
		user_project_path + "/ModifiedAssets/BloodstainedRotN/Content/Core/Environment/ACT04_GDN/Level/m04GDN_015_Enemy.umap"
	)
	uasset_parser.AddBlueprintToAsset(
		game_directory + "/BloodstainedRotN/Content/Paks/pakchunk0-WindowsNoEditor.pak",
		"BloodstainedRotN/Content/Core/Environment/ACT04_GDN/Level/m04GDN_015_Enemy.umap",
		"Chr_N3091(3)",
		user_project_path + "/ModifiedAssets/BloodstainedRotN/Content/Core/Environment/ACT04_GDN/Level/m04GDN_016_Enemy.umap"
	)
	
	editor_container.show()
	loading_status_container.hide()

#############
# CALLBACKS #
#############

func on_menu_popup_package_pressed(id: int):
	if id == 0:
		editor.package_and_install()
