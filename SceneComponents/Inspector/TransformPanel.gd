extends Control

var gui_tree_arrow_right_icon = preload("res://Icons/Editor/GUITreeArrowRight.svg")
var gui_tree_arrow_down_icon = preload("res://Icons/Editor/GUITreeArrowDown.svg")

var editor: Node

var expand_button: Button
var expand_section: Control
var edits: Dictionary
var edit_dirty_flags: Dictionary

var selected_nodes: Array = []
var focused_edit = null

func _ready():
	editor = get_node("/root/Editor")

	edits = {
		"translation": {
			"x": find_node("TranslationXEdit", true, true),
			"y": find_node("TranslationYEdit", true, true),
			"z": find_node("TranslationZEdit", true, true),
			"reset": find_node("ResetTranslationButton", true, true)
		},
		"rotation_degrees": {
			"x": find_node("RotationXEdit", true, true),
			"y": find_node("RotationYEdit", true, true),
			"z": find_node("RotationZEdit", true, true),
			"reset": find_node("ResetRotationButton", true, true)
		},
		"scale": {
			"x": find_node("ScaleXEdit", true, true),
			"y": find_node("ScaleYEdit", true, true),
			"z": find_node("ScaleZEdit", true, true),
			"reset": find_node("ResetScaleButton", true, true)
		}
	}
	expand_button = find_node("ExpandButton", true, true)
	expand_section = find_node("ExpandSection", true, true)
	
	editor.connect("history_changed", self, "on_history_changed")
	for edit in edits:
		for axis in ["x", "y", "z"]:
			edits[edit][axis].connect("text_changed", self, "on_edit_changed", [edit, axis])
			edits[edit][axis].connect("text_entered", self, "on_edit_entered", [edit, axis])
			edits[edit][axis].connect("focus_entered", self, "on_edit_focus_entered", [edit, axis])
			edits[edit][axis].connect("focus_exited", self, "on_edit_focus_exited", [edit, axis])
		edits[edit]["reset"].connect("pressed", self, "on_reset_pressed", [edit])
	expand_button.connect("toggled", self, "on_expand_button_toggled")
	
	reset_edit_dirty_flags()
	expand()

func on_reset_pressed(field: String):
	var node = selected_nodes[0].selection_transform_node
	var current_global_transform = selected_nodes[0].selection_transform_node.get_global_transform()
	if field == "translation":
		node.translation = Vector3(0, 0, 0)
	elif field == "rotation_degrees":
		node.rotation_degrees = Vector3(0, 0, 0)
	elif field == "scale":
		node.scale = Vector3(1, 1, 1)
	Editor.do_action(
		SpatialTransformAction.new(
			node,
			current_global_transform,
			node.get_global_transform()
		)
	)

func on_edit_changed(new_text: String, field: String, axis: String):
	edit_dirty_flags[field][axis] = true

func on_edit_entered(new_text: String, field: String, axis: String):
	if edit_dirty_flags[field][axis] == true:
		edit_dirty_flags[field][axis] = false
		var node = selected_nodes[0].selection_transform_node
		var current_global_transform = selected_nodes[0].selection_transform_node.get_global_transform()
		var new_vector = Vector3(
			edits[field].x.text.to_float(),
			edits[field].y.text.to_float(),
			edits[field].z.text.to_float()
		)
		if field == "translation":
			new_vector = UE4Convert.convert_translation_from_unreal_to_godot(new_vector)
		elif field == "rotation_degrees":
			new_vector = UE4Convert.convert_rotation_from_unreal_to_godot(new_vector)
		elif field == "scale":
			new_vector = UE4Convert.convert_scale_from_unreal_to_godot(new_vector)
		if node[field].x != new_vector.x or node[field].y != new_vector.y or node[field].z != new_vector.z:
			node[field] = new_vector
			Editor.do_action(
				SpatialTransformAction.new(
					node,
					current_global_transform,
					node.get_global_transform()
				)
			)

func on_edit_focus_entered(field: String, axis: String):
	focused_edit = edits[field][axis]

func on_edit_focus_exited(field: String, axis: String):
	on_edit_entered(edits[field][axis].text, field, axis)
	focused_edit = null

func on_expand_button_toggled(button_pressed: bool):
	if button_pressed:
		expand()
	else:
		collapse()

func on_history_changed(action: HistoryAction):
	if action.get_ids().has(HistoryAction.ID.SPATIAL_TRANSFORM):
		set_transform_from_selected_nodes()

func set_selected_nodes(new_selected_nodes):
	selected_nodes = new_selected_nodes
	set_transform_from_selected_nodes()

func set_transform_from_selected_nodes():
	if selected_nodes.size() == 1:
		if focused_edit:
			var old_focused_edit = focused_edit
			focused_edit.release_focus()
			focused_edit = old_focused_edit
		var node = selected_nodes[0].selection_transform_node
		var translation = UE4Convert.convert_translation_from_godot_to_unreal(node.translation)
		edits.translation.x.text = str(translation.x)
		edits.translation.y.text = str(translation.y)
		edits.translation.z.text = str(translation.z)
		edits.translation.reset.visible = not (translation.x == 0 and translation.y == 0 and translation.z == 0)
		var rotation_degrees = UE4Convert.convert_rotation_from_godot_to_unreal(node.rotation_degrees)
		edits.rotation_degrees.x.text = str(rotation_degrees.x)
		edits.rotation_degrees.y.text = str(rotation_degrees.y)
		edits.rotation_degrees.z.text = str(rotation_degrees.z)
		edits.rotation_degrees.reset.visible = not (rotation_degrees.x == 0 and rotation_degrees.y == 0 and rotation_degrees.z == 0)
		var scale = UE4Convert.convert_scale_from_godot_to_unreal(node.scale)
		edits.scale.x.text = str(scale.x)
		edits.scale.y.text = str(scale.y)
		edits.scale.z.text = str(scale.z)
		edits.scale.reset.visible = not (scale.x == 1 and scale.y == 1 and scale.z == 1)
		call_deferred("focused_edit_regrab_focus")
		call_deferred("reset_edit_dirty_flags")

func focused_edit_regrab_focus():
	if focused_edit:
			focused_edit.grab_focus()

func reset_edit_dirty_flags():
	edit_dirty_flags = {
		"translation": { "x": false, "y": false, "z": false },
		"rotation_degrees": { "x": false, "y": false, "z": false },
		"scale": { "x": false, "y": false, "z": false }
	}

func expand():
	expand_button.icon = gui_tree_arrow_down_icon
	expand_section.show()

func collapse():
	expand_button.icon = gui_tree_arrow_right_icon
	expand_section.hide()
	
