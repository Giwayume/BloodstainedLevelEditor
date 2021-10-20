extends HBoxContainer

signal popup_visibility_changed
signal tool_changed
signal view_gizmo_toggled

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
var menu_button_view: MenuButton
var view_menu_popup: PopupMenu
var view_gizmo_submenu: PopupMenu

var is_any_menu_popup_visible: bool = false

enum { OPTION_VIEW_GIZMOS, OPTION_VIEW_GIZMOS_LIGHT }

func _ready():
	tool_button_move = find_node("MoveToolButton", true, true)
	tool_button_rotate = find_node("RotateToolButton", true, true)
	tool_button_scale = find_node("ScaleToolButton", true, true)
	tool_button_select = find_node("SelectToolButton", true, true)
	menu_button_view = find_node("ViewMenuButton", true, true)
	
	view_menu_popup = menu_button_view.get_popup()
	
	view_gizmo_submenu = PopupMenu.new()
	view_gizmo_submenu.hide_on_checkable_item_selection = false
	view_gizmo_submenu.set_name("gizmos")
	view_gizmo_submenu.add_check_item("Lights", OPTION_VIEW_GIZMOS_LIGHT)
	view_gizmo_submenu.set_item_checked(0, true)
	view_menu_popup.add_child(view_gizmo_submenu)
	
	view_menu_popup.add_submenu_item("Gizmos", "gizmos", OPTION_VIEW_GIZMOS)
	
	tool_button_move.connect("pressed", self, "on_tool_button_move_toggled")
	tool_button_rotate.connect("pressed", self, "on_tool_button_rotate_toggled")
	tool_button_scale.connect("pressed", self, "on_tool_button_scale_toggled")
	tool_button_select.connect("pressed", self, "on_tool_button_select_toggled")
	view_menu_popup.connect("index_pressed", self, "on_view_menu_popup_index_pressed")
	view_menu_popup.connect("visibility_changed", self, "on_any_menu_popup_visibility_changed")
	view_gizmo_submenu.connect("index_pressed", self, "on_view_gizmos_menu_popup_index_pressed")
	
	on_tool_button_move_toggled(true)

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

func on_view_gizmos_menu_popup_index_pressed(index: int):
	var id = view_gizmo_submenu.get_item_id(index)
	if id == OPTION_VIEW_GIZMOS_LIGHT:
		var is_checked = not view_gizmo_submenu.is_item_checked(index)
		view_gizmo_submenu.set_item_checked(index, is_checked)
		emit_signal("view_gizmo_toggled", "light", is_checked)

func on_any_menu_popup_visibility_changed():
	is_any_menu_popup_visible = view_menu_popup.visible or view_gizmo_submenu.visible
	emit_signal("popup_visibility_changed", is_any_menu_popup_visible)
