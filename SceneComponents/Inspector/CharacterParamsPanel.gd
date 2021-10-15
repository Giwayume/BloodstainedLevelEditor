extends Control

var character_profiles = preload("res://Config/CharacterProfiles.gd").character_profiles
var gui_tree_arrow_right_icon = preload("res://Icons/Editor/GUITreeArrowRight.svg")
var gui_tree_arrow_down_icon = preload("res://Icons/Editor/GUITreeArrowDown.svg")

var editor: Node

var expand_button: Button
var expand_section: Control
var character_id_display: LineEdit
var character_name_display: LineEdit

func _ready():
	editor = get_node("/root/Editor")
	
	expand_button = find_node("ExpandButton", true, true)
	expand_section = find_node("ExpandSection", true, true)
	character_id_display = find_node("CharacterIdDisplay", true, true)
	character_name_display = find_node("CharacterNameDisplay", true, true)
	
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
		var node = selected_nodes[0]
		if node.definition.has("character_id"):
			var character_id = node.definition["character_id"]
			character_id_display.text = character_id
			character_name_display.text = "N/A"
			for character_profile in character_profiles:
				if character_profile["character_id"] == character_id:
					character_name_display.text = character_profile["character_name"]
					break
		else:
			character_id_display.text = "N/A"

