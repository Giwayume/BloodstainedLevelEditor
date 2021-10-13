extends Control

var package_installed_icon = preload("res://Icons/PackageInstalled.png")
var package_not_installed_icon = preload("res://Icons/PackageNotInstalled.png")

var editor: Node

var edit_button: Button
var install_uninstall_button: Button
var delete_button: Button
var new_package_button: Button
var new_package_dialog: WindowDialog
var new_package_name_edit: LineEdit
var create_package_button: Button
var package_list: ItemList
var selected_package_item: int = -1
var package_name_list: Array = []
var game_directory: String = ""
var level_editor_folder: String = ""
var user_packages_folder: String = "user://UserPackages"
var delete_dialog: ConfirmationDialog
var error_dialog: AcceptDialog

# Called when the node enters the scene tree for the first time.
func _ready():
	editor = get_node("/root/Editor")
	
	package_list = find_node("PackageList", true, true)
	edit_button = find_node("EditButton", true, true)
	install_uninstall_button = find_node("InstallUninstallButton", true, true)
	delete_button = find_node("DeleteButton", true, true)
	new_package_button = find_node("NewPackageButton", true, true)
	new_package_dialog = find_node("NewPackageDialog", true, true)
	new_package_name_edit = new_package_dialog.find_node("NewPackageNameEdit", true, true)
	create_package_button = new_package_dialog.find_node("CreatePackageButton", true, true)
	delete_dialog = find_node("DeleteDialog", true, true)
	error_dialog = find_node("ErrorDialog", true, true)
	game_directory = EditorConfig.read_config()['game_directory']
	level_editor_folder = game_directory + "/BloodstainedRotN/Content/Paks/~BloodstainedLevelEditor"
	
	edit_button.connect("pressed", self, "on_press_edit_button")
	install_uninstall_button.connect("pressed", self, "on_press_install_or_uninstall_button")
	delete_button.connect("pressed", self, "on_press_delete_button")
	delete_dialog.get_ok().text = "Delete"
	delete_dialog.get_ok().connect("pressed", self, "on_press_delete_confirm_button")
	new_package_button.connect("pressed", self, "on_press_new_package_button")
	create_package_button.connect("pressed", self, "on_press_create_package_button")
	package_list.connect("item_selected", self, "on_select_package")
	package_list.connect("item_activated", self, "on_activate_package")
	
	ensure_game_install_directory()
	update_package_list()

func ensure_game_install_directory():
	var dir = Directory.new()
	if not dir.dir_exists(level_editor_folder):
		dir.make_dir(level_editor_folder)

func update_package_list():
	# Ensure UserPackages directory in user data folder
	var dir = Directory.new()
	if not dir.dir_exists(user_packages_folder):
		dir.make_dir(user_packages_folder)
	# Read all folders in directory
	package_name_list = []
	if dir.open(user_packages_folder) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				package_name_list.push_back(file_name)
			file_name = dir.get_next()
	# Remove all items
	package_list.clear()
	# Update UI
	for package_name in package_name_list:
		var installed_icon = package_not_installed_icon
		if dir.file_exists(level_editor_folder + "/" + package_name + ".pak"):
			installed_icon = package_installed_icon
		package_list.add_item(package_name, installed_icon)
	if len(package_name_list) > 0:
		package_list.select(0)
		selected_package_item = 0
		edit_button.disabled = false
		install_uninstall_button.disabled = false
		delete_button.disabled = false
		if package_list.get_item_icon(0) == package_installed_icon:
			install_uninstall_button.text = "Uninstall"
		else:
			install_uninstall_button.text = "Install"
	else:
		selected_package_item = -1
		edit_button.disabled = true
		install_uninstall_button.disabled = true
		delete_button.disabled = true

func on_press_edit_button():
	if selected_package_item > -1:
		get_node("/root/Editor").selected_package = package_list.get_item_text(selected_package_item)
		get_tree().change_scene("res://Scenes/MapEdit.tscn")

func on_press_install_or_uninstall_button():
	if selected_package_item > -1:
		var package_name = package_name_list[selected_package_item]
		if package_list.get_item_icon(selected_package_item) == package_installed_icon:
			var dir = Directory.new()
			if dir.file_exists(level_editor_folder + "/" + package_name + ".pak"):
				dir.remove(level_editor_folder + "/" + package_name + ".pak")
			update_package_list()
		else:
			editor.package_and_install(package_name, false, self, "on_install_finished")

func on_install_finished():
	update_package_list()

func on_press_delete_button():
	if selected_package_item > -1:
		var package_name = package_list.get_item_text(selected_package_item)
		delete_dialog.dialog_text = "Are you sure you want to delete \"" + package_name + "\"?"
		delete_dialog.popup_centered()

func on_press_delete_confirm_button():
	if selected_package_item > -1:
		var package_name = package_list.get_item_text(selected_package_item)
		var dir = Directory.new()
		if dir.remove(user_packages_folder + "/" + package_name) == OK:
			update_package_list()

func on_press_new_package_button():
	new_package_name_edit.text = ""
	new_package_dialog.popup_centered_clamped(Vector2(250, 100), 0.75)

func on_press_create_package_button():
	var dir = Directory.new()
	var accept_character_regex = RegEx.new()
	accept_character_regex.compile("[^a-zA-Z0-9_ -]")
	var package_name = accept_character_regex.sub(new_package_name_edit.text, "", true)
	if package_name == "":
		error_dialog.dialog_text = "Please enter a package name."
		error_dialog.popup_centered()
		return
	elif dir.dir_exists(user_packages_folder + "/" + package_name):
		error_dialog.dialog_text = "A similar package name already exists in the list.\nPlease enter a different name."
		error_dialog.popup_centered()
		return
	else:
		dir.make_dir(user_packages_folder + "/" + package_name)
		new_package_dialog.hide()
		update_package_list()

func on_select_package(index: int):
	selected_package_item = index
	edit_button.disabled = false
	install_uninstall_button.disabled = false
	delete_button.disabled = false
	if package_list.get_item_icon(index) == package_installed_icon:
		install_uninstall_button.text = "Uninstall"
	else:
		install_uninstall_button.text = "Install"
	
func on_activate_package(index: int):
	selected_package_item = index
	on_press_edit_button()
