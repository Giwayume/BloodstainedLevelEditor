extends Control

signal popup_visibility_changed

var editor: Node

var menu_button_package: MenuButton
var menu_button_package_popup: PopupMenu
var menu_button_edit: MenuButton
var menu_button_edit_popup: PopupMenu

var is_any_menu_popup_visible: bool = false
var is_control_modifier_pressed: bool = false
var is_shift_modifier_pressed: bool = false

enum {
	POPUP_ITEM_TEST_PACKAGE,
	POPUP_ITEM_PACKAGE_INSTALL,
	POPUP_ITEM_OPEN_PACKAGE_FOLDER,
	POPUP_ITEM_OPEN_MAP,
	POPUP_ITEM_EXIT_PACKAGE,
	POPUP_ITEM_EDIT_UNDO,
	POPUP_ITEM_EDIT_REDO
}

func _ready():
	editor = get_node("/root/Editor");
	
	menu_button_package = find_node("PackageMenuButton", true, true)
	menu_button_edit = find_node("EditMenuButton", true, true)
	menu_button_package_popup = menu_button_package.get_popup()
	menu_button_edit_popup = menu_button_edit.get_popup()
	
	menu_button_package_popup.add_item("Test In-Game", POPUP_ITEM_TEST_PACKAGE)
	menu_button_package_popup.add_item("View Map", POPUP_ITEM_OPEN_MAP)
	menu_button_package_popup.add_separator()
	menu_button_package_popup.add_item("Package & Install", POPUP_ITEM_PACKAGE_INSTALL)
	menu_button_package_popup.add_item("Open Package Folder", POPUP_ITEM_OPEN_PACKAGE_FOLDER)
	menu_button_package_popup.add_separator()
	menu_button_package_popup.add_item("Exit", POPUP_ITEM_EXIT_PACKAGE)
	
	menu_button_edit_popup.add_item("Undo", POPUP_ITEM_EDIT_UNDO)
	menu_button_edit_popup.add_item("Redo", POPUP_ITEM_EDIT_REDO)
	
	menu_button_package_popup.connect("id_pressed", self, "on_menu_popup_package_pressed")
	menu_button_package_popup.connect("visibility_changed", self, "on_any_menu_popup_visibility_changed")
	menu_button_edit_popup.connect("id_pressed", self, "on_menu_popup_edit_pressed")
	menu_button_edit_popup.connect("visibility_changed", self, "on_any_menu_popup_visibility_changed")

func _input(event):
	if event is InputEventKey:
		if event.scancode == KEY_CONTROL:
			is_control_modifier_pressed = event.pressed
		elif event.scancode == KEY_SHIFT:
			is_shift_modifier_pressed = event.pressed
		elif is_control_modifier_pressed and not is_shift_modifier_pressed and event.scancode == KEY_Z:
			if event.pressed and not editor.history_shortcuts_disabled:
				editor.undo_action()
		elif (is_control_modifier_pressed and event.scancode == KEY_Y) or (is_control_modifier_pressed and is_shift_modifier_pressed and event.scancode == KEY_Z):
			if event.pressed and not editor.history_shortcuts_disabled:
				editor.redo_action()

func on_menu_popup_package_pressed(id: int):
	if id == POPUP_ITEM_TEST_PACKAGE:
		editor.package_and_install()
	elif id == POPUP_ITEM_PACKAGE_INSTALL:
		editor.package_and_install("", false)
	elif id == POPUP_ITEM_OPEN_PACKAGE_FOLDER:
		var open_path = str("file://", ProjectSettings.globalize_path("user://UserPackages/" + editor.selected_package))
		OS.shell_open(open_path)
	elif id == POPUP_ITEM_OPEN_MAP:
		get_tree().change_scene("res://Scenes/MapEdit.tscn")
	elif id == POPUP_ITEM_EXIT_PACKAGE:
		get_tree().change_scene("res://Scenes/SelectPackage.tscn")

func on_menu_popup_edit_pressed(id: int):
	if id == POPUP_ITEM_EDIT_UNDO:
		editor.undo_action()
	elif id == POPUP_ITEM_EDIT_REDO:
		editor.redo_action()

func on_any_menu_popup_visibility_changed():
	is_any_menu_popup_visible = menu_button_package.get_popup().visible or menu_button_edit.get_popup().visible
	emit_signal("popup_visibility_changed", is_any_menu_popup_visible)
