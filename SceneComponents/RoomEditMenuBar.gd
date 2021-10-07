extends Control

signal popup_visibility_changed

var editor: Node

var menu_button_package: MenuButton
var menu_button_edit: MenuButton

var is_any_menu_popup_visible: bool = false
var is_control_modifier_pressed: bool = false
var is_shift_modifier_pressed: bool = false

func _ready():
	editor = get_node("/root/Editor");
	
	menu_button_package = find_node("PackageMenuButton", true, true)
	menu_button_edit = find_node("EditMenuButton", true, true)
	
	menu_button_package.get_popup().connect("id_pressed", self, "on_menu_popup_package_pressed")
	menu_button_package.get_popup().connect("visibility_changed", self, "on_any_menu_popup_visibility_changed")
	menu_button_edit.get_popup().connect("id_pressed", self, "on_menu_popup_edit_pressed")
	menu_button_edit.get_popup().connect("visibility_changed", self, "on_any_menu_popup_visibility_changed")

func _input(event):
	if event is InputEventKey:
		if event.scancode == KEY_CONTROL:
			is_control_modifier_pressed = event.pressed
		elif event.scancode == KEY_SHIFT:
			is_shift_modifier_pressed = event.pressed
		elif is_control_modifier_pressed and not is_shift_modifier_pressed and event.scancode == KEY_Z:
			if event.pressed:
				editor.undo_action()
		elif (is_control_modifier_pressed and event.scancode == KEY_Y) or (is_control_modifier_pressed and is_shift_modifier_pressed and event.scancode == KEY_Z):
			if event.pressed:
				editor.redo_action()

func on_menu_popup_package_pressed(id: int):
	if id == 0:
		editor.package_and_install()
	elif id == 1:
		get_tree().change_scene("res://Scenes/MapEdit.tscn")
	elif id == 3:
		get_tree().change_scene("res://Scenes/SelectPackage.tscn")

func on_menu_popup_edit_pressed(id: int):
	if id == 0:
		editor.undo_action()
	elif id == 1:
		editor.redo_action()

func on_any_menu_popup_visibility_changed():
	is_any_menu_popup_visible = menu_button_package.get_popup().visible or menu_button_edit.get_popup().visible
	emit_signal("popup_visibility_changed", is_any_menu_popup_visible)
