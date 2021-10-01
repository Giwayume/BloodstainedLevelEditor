extends Control

var folder_path: String = ""
var default_install_locations: Array = [
	"C:/Program Files/Steam/steamapps/common/Bloodstained Ritual of the Night",
	"C:/Program Files (x86)/Steam/steamapps/common/Bloodstained Ritual of the Night",
	"C:/Program Files/GOG Galaxy/Games/Bloodstained Ritual of the Night",
	"C:/Program Files (x86)/GOG Galaxy/Games/Bloodstained Ritual of the Night",
	"X:/Steam/steamapps/common/Bloodstained Ritual of the Night"
]

var folder_path_edit: LineEdit
var browser_folder_button: Button
var open_folder_dialog: FileDialog
var error_dialog: AcceptDialog
var done_button: Button

# Called when the node enters the scene tree for the first time.
func _ready():
	folder_path_edit = find_node("FolderPathEdit", true, true)
	browser_folder_button = find_node("BrowseFolderButton", true, true)
	open_folder_dialog = find_node("OpenFolderDialog", true, true)
	error_dialog = find_node("ErrorDialog", true, true)
	done_button = find_node("DoneButton", true, true)
	
	folder_path_edit.connect("text_changed", self, "on_folder_path_edit_changed")
	browser_folder_button.connect("pressed", self, "on_open_folder_dialog")
	open_folder_dialog.connect("dir_selected", self, "on_folder_path_dialog_selected")
	done_button.connect("pressed", self, "on_done_clicked")
	
	var dir = Directory.new()
	for location in default_install_locations:
		if dir.dir_exists(location):
			folder_path = location
			folder_path_edit.text = location
			open_folder_dialog.current_dir = location
			open_folder_dialog.current_path = location

func on_folder_path_edit_changed(new_folder_path: String):
	folder_path = new_folder_path
	open_folder_dialog.current_dir = folder_path
	open_folder_dialog.current_path = folder_path
	
func on_folder_path_dialog_selected(new_folder_path: String):
	folder_path = new_folder_path
	folder_path_edit.text = new_folder_path
	
func on_open_folder_dialog():
	open_folder_dialog.popup_centered_ratio(0.75);

func on_done_clicked():
	var regex = RegEx.new()
	regex.compile("[\/]$")
	var game_directory = regex.sub(folder_path, "")
	var pak_file_path = game_directory + "/BloodstainedRotN/Content/Paks/pakchunk0-WindowsNoEditor.pak"
	var dir = Directory.new()
	if not dir.file_exists(pak_file_path):
		error_dialog.dialog_text = "The path you chose does not appear to be correct.\nMake sure you select the folder that has \"Bloodstained.exe\" inside of it."
		error_dialog.popup_centered_clamped(Vector2(200, 1), 0.75)
		return
	EditorConfig.write_config_prop("game_directory", game_directory)
	get_tree().change_scene("res://Scenes/SelectPackage.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
