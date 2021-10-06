extends HBoxContainer

signal tool_changed

var icon_tool_move = preload("res://Icons/Editor/ToolMove.svg")
var icon_tool_move_pressed = preload("res://Icons/Editor/ToolMovePressed.svg")
var icon_tool_rotate = preload("res://Icons/Editor/ToolRotate.svg")
var icon_tool_rotate_pressed = preload("res://Icons/Editor/ToolRotatePressed.svg")
var icon_tool_scale = preload("res://Icons/Editor/ToolScale.svg")
var icon_tool_scale_pressed = preload("res://Icons/Editor/ToolScalePressed.svg")
var icon_tool_select = preload("res://Icons/Editor/ToolSelect.svg")
var icon_tool_select_pressed = preload("res://Icons/Editor/ToolSelectPressed.svg")

var tool_button_move: ToolButton
var tool_button_rotate: ToolButton
var tool_button_scale: ToolButton
var tool_button_select: ToolButton

func _ready():
	tool_button_move = find_node("MoveToolButton", true, true)
	tool_button_rotate = find_node("RotateToolButton", true, true)
	tool_button_scale = find_node("ScaleToolButton", true, true)
	tool_button_select = find_node("SelectToolButton", true, true)
	
	tool_button_move.connect("pressed", self, "on_tool_button_move_toggled")
	tool_button_rotate.connect("pressed", self, "on_tool_button_rotate_toggled")
	tool_button_scale.connect("pressed", self, "on_tool_button_scale_toggled")
	tool_button_select.connect("pressed", self, "on_tool_button_select_toggled")
	
	on_tool_button_select_toggled(true)

func untoggle_all_tools():
	on_tool_button_move_toggled(false)
	on_tool_button_rotate_toggled(false)
	on_tool_button_scale_toggled(false)
	on_tool_button_select_toggled(false)

func on_tool_button_move_toggled(button_pressed: bool = true):
	if button_pressed:
		if not tool_button_move.icon == icon_tool_move_pressed:
			untoggle_all_tools()
			tool_button_move.icon = icon_tool_move_pressed
			emit_signal("tool_changed", "move")
	else:
		tool_button_move.icon = icon_tool_move
	tool_button_move.pressed = button_pressed

func on_tool_button_rotate_toggled(button_pressed: bool = true):
	if button_pressed:
		if not tool_button_rotate.icon == icon_tool_rotate_pressed:
			untoggle_all_tools()
			tool_button_rotate.icon = icon_tool_rotate_pressed
			emit_signal("tool_changed", "rotate")
	else:
		tool_button_rotate.icon = icon_tool_rotate
	tool_button_rotate.pressed = button_pressed

func on_tool_button_scale_toggled(button_pressed: bool = true):
	if button_pressed:
		if not tool_button_scale.icon == icon_tool_select_pressed:
			untoggle_all_tools()
			tool_button_scale.icon = icon_tool_scale_pressed
			emit_signal("tool_changed", "scale")
	else:
		tool_button_scale.icon = icon_tool_scale
	tool_button_scale.pressed = button_pressed

func on_tool_button_select_toggled(button_pressed: bool = true):
	if button_pressed:
		if not tool_button_select.icon == icon_tool_select_pressed:
			untoggle_all_tools()
			tool_button_select.icon = icon_tool_select_pressed
			emit_signal("tool_changed", "select")
	else:
		tool_button_select.icon = icon_tool_select
	tool_button_select.pressed = button_pressed
