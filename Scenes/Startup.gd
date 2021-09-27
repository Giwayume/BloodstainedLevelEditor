extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	route_to_scene()

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
