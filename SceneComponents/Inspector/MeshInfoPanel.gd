extends Control

var gui_tree_arrow_right_icon = preload("res://Icons/Editor/GUITreeArrowRight.svg")
var gui_tree_arrow_down_icon = preload("res://Icons/Editor/GUITreeArrowDown.svg")

var editor: Node

var expand_button: Button
var expand_section: Control
var mesh_name_display: LineEdit
var asset_path_display: LineEdit

func _ready():
	editor = get_node("/root/Editor")
	
	expand_button = find_node("ExpandButton", true, true)
	expand_section = find_node("ExpandSection", true, true)
	mesh_name_display = find_node("MeshNameDisplay", true, true)
	asset_path_display = find_node("AssetPathDisplay", true, true)
	
	expand_button.connect("toggled", self, "on_expand_button_toggled")
	
	collapse()
	
func on_expand_button_toggled(button_pressed: bool):
	if button_pressed:
		expand()
	else:
		collapse()

func expand():
	expand_button.pressed = true
	expand_button.icon = gui_tree_arrow_down_icon
	expand_section.show()

func collapse():
	expand_button.pressed = false
	expand_button.icon = gui_tree_arrow_right_icon
	expand_section.hide()
	
func set_selected_nodes(selected_nodes):
	if selected_nodes.size() == 1:
		var node = selected_nodes[0].selection_transform_node
		if node.definition.has("static_mesh_name") and node.definition.has("static_mesh_name_instance"):
			mesh_name_display.text = str(node.definition["static_mesh_name"]) + " (" + str(node.definition["static_mesh_name_instance"]) + ")"
		else:
			mesh_name_display.text = "N/A"
		if node.definition.has("static_mesh_asset_path"):
			asset_path_display.text = str(node.definition["static_mesh_asset_path"])
		else:
			asset_path_display.text = "N/A"
