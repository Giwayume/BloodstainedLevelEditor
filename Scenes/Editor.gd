extends Control

var loading_screen_scene = preload("res://Scenes/LoadingScreen.tscn")

var package_and_install_thread: Thread

var selected_package: String = ""
var selected_level_name: String = ""
var loading_screen: Control

func _ready():
	PhysicsLayers3d.read_layers()

func read_config():
	return EditorConfig.read_config()

func write_config_prop(prop_name: String, prop_data):
	return EditorConfig.write_config_prop(prop_name, prop_data)
	
func read_config_prop(prop_name: String):
	return read_config()[prop_name]

func package_and_install(package_name: String = ""):
	if package_name == "":
		package_name = selected_package
	start_package_and_install_thread(package_name)
	
###########
# THREADS #
###########

func start_package_and_install_thread(package_name: String):
	loading_screen = loading_screen_scene.instance()
	get_tree().get_root().add_child(loading_screen)
	loading_screen.set_status_text("Packaging Project...")
	package_and_install_thread = Thread.new()
	package_and_install_thread.start(self, "package_and_install_thread_function", package_name)

func package_and_install_thread_function(package_name: String):
	var uasset_parser = get_node("/root/UAssetParser")
	uasset_parser.PackageAndInstallMod(package_name)
	call_deferred("end_package_and_install_thread")

func end_package_and_install_thread():
	package_and_install_thread.wait_to_finish()
	get_tree().get_root().remove_child(loading_screen)
	loading_screen = null
	
	var game_directory = EditorConfig.read_config()["game_directory"]
	OS.execute(game_directory + "/BloodstainedRotN/Binaries/Win64/BloodstainedRotN-Win64-Shipping.exe", [], false)
