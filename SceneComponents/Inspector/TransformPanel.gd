extends Control

var gui_tree_arrow_right_icon = preload("res://Icons/Editor/GUITreeArrowRight.svg")
var gui_tree_arrow_down_icon = preload("res://Icons/Editor/GUITreeArrowDown.svg")

var expand_button: Button
var expand_section: Control

func _ready():
	expand_button = find_node("ExpandButton", true, true)
	expand_section = find_node("ExpandSection", true, true)
	
	expand_button.connect("toggled", self, "on_expand_button_toggled")
	
	expand()
	
func on_expand_button_toggled(button_pressed: bool):
	if button_pressed:
		expand()
	else:
		collapse()
	
func expand():
	expand_button.icon = gui_tree_arrow_down_icon
	expand_section.show()

func collapse():
	expand_button.icon = gui_tree_arrow_right_icon
	expand_section.hide()
	
