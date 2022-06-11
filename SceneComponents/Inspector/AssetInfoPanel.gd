extends Control

signal open_uassetgui

var gui_tree_arrow_right_icon = preload("res://Icons/Editor/GUITreeArrowRight.svg")
var gui_tree_arrow_down_icon = preload("res://Icons/Editor/GUITreeArrowDown.svg")

var editor: Node

var expand_button: Button
var expand_section: Control
var export_number_display: LineEdit
var class_asset_path_display: LineEdit
var open_uassetgui_button: Button

var selected_nodes: Array = []

func _ready():
	editor = get_node("/root/Editor")
	
	expand_button = find_node("ExpandButton", true, true)
	expand_section = find_node("ExpandSection", true, true)
	export_number_display = find_node("ExportNumberDisplay", true, true)
	class_asset_path_display = find_node("ClassAssetPathDisplay", true, true)
	open_uassetgui_button = find_node("OpenUassetGuiButton", true, true)
	
	expand_button.connect("toggled", self, "on_expand_button_toggled")
	open_uassetgui_button.connect("pressed", self, "on_press_open_uassetgui")
	
	collapse()

func set_selected_nodes(new_selected_nodes):
	selected_nodes = new_selected_nodes
	call_deferred("set_edits_from_selected_nodes")

func set_edits_from_selected_nodes():
	if selected_nodes.size() == 1:
		export_number_display.text = str(selected_nodes[0].definition["export_index"] + 1)
		class_asset_path_display.text = str(selected_nodes[0].definition["class_asset_path"])

func on_expand_button_toggled(button_pressed: bool):
	if button_pressed:
		expand()
	else:
		collapse()

func on_press_open_uassetgui():
	emit_signal("open_uassetgui")

func expand():
	expand_button.icon = gui_tree_arrow_down_icon
	expand_section.show()

func collapse():
	expand_button.icon = gui_tree_arrow_right_icon
	expand_section.hide()
