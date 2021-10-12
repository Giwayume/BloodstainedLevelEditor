extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var go_button: Button
var download_button: Button

var release_link = "https://github.com/Giwayume/BloodstainedLevelEditor/releases"

# Called when the node enters the scene tree for the first time.
func _ready():
	go_button = find_node("GoButton", true, true)
	download_button = find_node("DownloadButton", true, true)
	
	go_button.connect("pressed", self, "route_to_scene")
	download_button.connect("pressed", self, "open_download_page")

func route_to_scene():
	var config = EditorConfig.read_config()
	if config != null:
		if config.has("game_directory"):
			var game_directory = config["game_directory"]
			var pak_file_path = game_directory + "/BloodstainedRotN/Content/Paks/pakchunk0-WindowsNoEditor.pak"
			var dir = Directory.new()
			if dir.file_exists(pak_file_path):
				get_tree().change_scene("res://Scenes/SelectPackage.tscn")
				return
	get_tree().change_scene("res://Scenes/SelectGameFolder.tscn")

func open_download_page():
	OS.shell_open(release_link)
