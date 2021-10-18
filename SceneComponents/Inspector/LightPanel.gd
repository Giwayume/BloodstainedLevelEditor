extends Control

signal popup_blocking_changed

var gui_tree_arrow_right_icon = preload("res://Icons/Editor/GUITreeArrowRight.svg")
var gui_tree_arrow_down_icon = preload("res://Icons/Editor/GUITreeArrowDown.svg")
const light_defaults = preload("res://Config/LightDefaults.gd").light_defaults

var editor: Node

var expand_button: Button
var expand_section: Control
var edits: Dictionary
var edit_dirty_flags: Dictionary
var edit_start_selected_nodes: Array
var edit_start_values: Dictionary
var edit_preview_values: Dictionary

var selected_nodes: Array = []
var focused_edit = null
var ignore_edit_signals: bool = false

func _ready():
	editor = get_node("/root/Editor")

	edits = {
		"intensity": {
			"label": find_node("IntensityLabel", true, true),
			"edit_container": find_node("IntensityEditContainer", true, true),
			"edit": find_node("IntensityEdit", true, true)
		},
		"light_color": {
			"label": find_node("LightColorLabel", true, true),
			"edit_container": find_node("LightColorEditContainer", true, true),
			"edit": find_node("LightColorEdit", true, true)
		},
		"inner_cone_angle": {
			"label": find_node("InnerConeAngleLabel", true, true),
			"edit_container": find_node("InnerConeAngleEditContainer", true, true),
			"edit": find_node("InnerConeAngleEdit", true, true)
		},
		"outer_cone_angle": {
			"label": find_node("OuterConeAngleLabel", true, true),
			"edit_container": find_node("OuterConeAngleEditContainer", true, true),
			"edit": find_node("OuterConeAngleEdit", true, true)
		},
		"attenuation_radius": {
			"label": find_node("AttenuationRadiusLabel", true, true),
			"edit_container": find_node("AttenuationRadiusEditContainer", true, true),
			"edit": find_node("AttenuationRadiusEdit", true, true)
		},
		"source_radius": {
			"label": find_node("SourceRadiusLabel", true, true),
			"edit_container": find_node("SourceRadiusEditContainer", true, true),
			"edit": find_node("SourceRadiusEdit", true, true)
		},
		"soft_source_radius": {
			"label": find_node("SoftSourceRadiusLabel", true, true),
			"edit_container": find_node("SoftSourceRadiusEditContainer", true, true),
			"edit": find_node("SoftSourceRadiusEdit", true, true)
		},
		"source_length": {
			"label": find_node("SourceLengthLabel", true, true),
			"edit_container": find_node("SourceLengthEditContainer", true, true),
			"edit": find_node("SourceLengthEdit", true, true)
		},
		"use_temperature": {
			"label": find_node("UseTemperatureLabel", true, true),
			"edit_container": find_node("UseTemperatureEditContainer", true, true),
			"edit": find_node("UseTemperatureEdit", true, true)
		},
		"temperature": {
			"label": find_node("TemperatureLabel", true, true),
			"edit_container": find_node("TemperatureEditContainer", true, true),
			"edit": find_node("TemperatureEdit", true, true)
		},
		"cast_shadows": {
			"label": find_node("CastShadowsLabel", true, true),
			"edit_container": find_node("CastShadowsEditContainer", true, true),
			"edit": find_node("CastShadowsEdit", true, true)
		},
		"use_inverse_squared_falloff": {
			"label": find_node("InverseSquaredFalloffLabel", true, true),
			"edit_container": find_node("InverseSquaredFalloffEditContainer", true, true),
			"edit": find_node("InverseSquaredFalloffEdit", true, true)
		},
		"indirect_lighting_intensity": {
			"label": find_node("IndirectLightingIntensityLabel", true, true),
			"edit_container": find_node("IndirectLightingIntensityEditContainer", true, true),
			"edit": find_node("IndirectLightingIntensityEdit", true, true)
		},
		"volumetric_scattering_intensity": {
			"label": find_node("VolumetricScatteringIntensityLabel", true, true),
			"edit_container": find_node("VolumetricScatteringIntensityEditContainer", true, true),
			"edit": find_node("VolumetricScatteringIntensityEdit", true, true)
		}
	}

	expand_button = find_node("ExpandButton", true, true)
	expand_section = find_node("ExpandSection", true, true)
	
	editor.connect("history_changed", self, "on_history_changed")
	expand_button.connect("toggled", self, "on_expand_button_toggled")
	
	for edit in edits:
		if edits[edit]["edit"] is RangeEdit:
			edits[edit]["edit"].connect("value_changed", self, "on_edit_range_value_changed", [edit])
			edits[edit]["edit"].connect("value_committed", self, "on_edit_range_value_committed", [edit])
		if edits[edit]["edit"] is CheckBox:
			edits[edit]["edit"].connect("toggled", self, "on_edit_check_button_toggled", [edit])
		if edits[edit]["edit"] is ColorPickerButton:
			edits[edit]["edit"].get_popup().connect("about_to_show", self, "on_edit_color_picker_button_popup_about_to_show", [edit])
			edits[edit]["edit"].connect("color_changed", self, "on_edit_color_picker_button_color_changed", [edit])
			edits[edit]["edit"].connect("popup_closed", self, "on_edit_color_picker_button_popup_closed", [edit])
		edits[edit]["edit"].connect("focus_entered", self, "on_edit_focus_entered", [edit])
		edits[edit]["edit"].connect("focus_exited", self, "on_edit_focus_exited", [edit])
	
	collapse()

func _exit_tree():
	emit_signal("popup_blocking_changed", false)

func on_history_changed(action: HistoryAction):
	if action.get_ids().has(HistoryAction.ID.UPDATE_LIGHT):
		set_edits_from_selected_nodes()
	
func on_edit_range_value_changed(new_value: float, field: String):
	if not ignore_edit_signals:
		edit_start_selected_nodes = selected_nodes
		var node = edit_start_selected_nodes[0].selection_light_node
		if not edit_start_values.has(field):
			if node.definition.has(field):
				edit_start_values[field] = node.definition[field]
			else:
				edit_start_values[field] = light_defaults[field]
		if "radius" in field:
			new_value = new_value * 0.01
		node.set_light_properties({
			field: new_value
		})

func on_edit_range_value_committed(new_value: float, field: String):
	if not ignore_edit_signals:
		if edit_start_selected_nodes.size() > 0:
			var node = edit_start_selected_nodes[0].selection_light_node
			if "radius" in field:
				new_value = new_value * 0.01
			editor.do_action(
				UpdateLightAction.new(node, { field: new_value }, { field: edit_start_values[field] })
			)
			edit_start_values.erase(field)
			edit_start_selected_nodes = []
		else:
			edit_start_values.erase(field)

func on_edit_check_button_toggled(button_pressed: bool, field: String):
	if not ignore_edit_signals:
		var node = selected_nodes[0].selection_light_node
		editor.do_action(
			UpdateLightAction.new(node, { field: button_pressed }, { field: !button_pressed })
		)

func on_edit_color_picker_button_popup_about_to_show(field: String):
	edit_start_selected_nodes = selected_nodes
	var node = edit_start_selected_nodes[0].selection_light_node
	if node.definition.has(field):
		edit_start_values[field] = node.definition[field]
	else:
		edit_start_values[field] = light_defaults[field]
	emit_signal("popup_blocking_changed", true)

func on_edit_color_picker_button_color_changed(color: Color, field: String):
	if not ignore_edit_signals:
		if edit_start_selected_nodes.size() > 0:
			var node = edit_start_selected_nodes[0].selection_light_node
			edit_preview_values[field] = color
			node.set_light_properties({
				field: color
			})

func on_edit_color_picker_button_popup_closed(field: String):
	if not ignore_edit_signals:
		if edit_start_selected_nodes.size() > 0:
			var node = edit_start_selected_nodes[0].selection_light_node
			if edit_preview_values.has(field) and edit_preview_values[field] != edit_start_values[field]:
				editor.do_action(
					UpdateLightAction.new(node, { field: edit_preview_values[field] }, { field: edit_start_values[field] })
				)
			edit_preview_values.erase(field)
			edit_start_values.erase(field)
			edit_start_selected_nodes = []
		else:
			edit_start_values.erase(field)
	emit_signal("popup_blocking_changed", false)

func on_edit_focus_entered(field: String):
	focused_edit = edits[field]["edit"]

func on_edit_focus_exited(field: String):
	focused_edit = null

func on_expand_button_toggled(button_pressed: bool):
	if button_pressed:
		expand()
	else:
		collapse()

func set_selected_nodes(new_selected_nodes):
	selected_nodes = new_selected_nodes
	call_deferred("set_edits_from_selected_nodes")

func set_edits_from_selected_nodes():
	ignore_edit_signals = true
	if selected_nodes.size() == 1:
		if focused_edit:
			focused_edit.release_focus()
			focused_edit = null
		
		var node = selected_nodes[0].selection_light_node
		var definition = node.definition
		var type = definition.type
		
		if type == "SpotLightComponent":
			edits["inner_cone_angle"].label.show()
			edits["inner_cone_angle"].edit_container.show()
			edits["outer_cone_angle"].label.show()
			edits["outer_cone_angle"].edit_container.show()
			if definition.has("inner_cone_angle"):
				edits["inner_cone_angle"].edit.value = definition["inner_cone_angle"]
			else:
				edits["inner_cone_angle"].edit.value = light_defaults["inner_cone_angle"]
			if definition.has("outer_cone_angle"):
				edits["outer_cone_angle"].edit.value = definition["outer_cone_angle"]
			else:
				edits["outer_cone_angle"].edit.value = light_defaults["outer_cone_angle"]
		else:
			edits["inner_cone_angle"].label.hide()
			edits["inner_cone_angle"].edit_container.hide()
			edits["outer_cone_angle"].label.hide()
			edits["outer_cone_angle"].edit_container.hide()
		
		if definition.has("intensity"):
			edits["intensity"].edit.value = definition["intensity"]
		else:
			edits["intensity"].edit.value = light_defaults["intensity"]
		
		if definition.has("light_color"):
			edits["light_color"].edit.color = definition["light_color"]
		else:
			edits["light_color"].edit.color = light_defaults["light_color"]
		
		if definition.has("attenuation_radius"):
			edits["attenuation_radius"].edit.value = stepify(definition["attenuation_radius"] * 100, 0.0001)
		else:
			edits["attenuation_radius"].edit.value = stepify(light_defaults["attenuation_radius"] * 100, 0.0001)
		
		if definition.has("source_radius"):
			edits["source_radius"].edit.value = stepify(definition["source_radius"] * 100, 0.0001)
		else:
			edits["source_radius"].edit.value = stepify(light_defaults["source_radius"] * 100, 0.0001)
		
		if definition.has("soft_source_radius"):
			edits["soft_source_radius"].edit.value = stepify(definition["soft_source_radius"] * 100, 0.0001)
		else:
			edits["soft_source_radius"].edit.value = stepify(light_defaults["soft_source_radius"] * 100, 0.0001)
		
		if definition.has("source_length"):
			edits["source_length"].edit.value = stepify(definition["source_length"] * 100, 0.0001)
		else:
			edits["source_length"].edit.value = stepify(light_defaults["source_length"] * 100, 0.0001)
		
		if definition.has("use_temperature"):
			edits["use_temperature"].edit.pressed = definition["use_temperature"]
		else:
			edits["use_temperature"].edit.pressed = light_defaults["use_temperature"]
		
		if definition.has("temperature"):
			edits["temperature"].edit.value = definition["temperature"]
		else:
			edits["temperature"].edit.value = light_defaults["temperature"]
		
		if definition.has("cast_shadows"):
			edits["cast_shadows"].edit.pressed = definition["cast_shadows"]
		else:
			edits["cast_shadows"].edit.pressed = light_defaults["cast_shadows"]
		
		if definition.has("use_inverse_squared_falloff"):
			edits["use_inverse_squared_falloff"].edit.pressed = definition["use_inverse_squared_falloff"]
		else:
			edits["use_inverse_squared_falloff"].edit.pressed = light_defaults["use_inverse_squared_falloff"]
		
		if definition.has("indirect_lighting_intensity"):
			edits["indirect_lighting_intensity"].edit.value = definition["indirect_lighting_intensity"]
		else:
			edits["indirect_lighting_intensity"].edit.value = light_defaults["indirect_lighting_intensity"]
		
		if definition.has("volumetric_scattering_intensity"):
			edits["volumetric_scattering_intensity"].edit.value = definition["volumetric_scattering_intensity"]
		else:
			edits["volumetric_scattering_intensity"].edit.value = light_defaults["volumetric_scattering_intensity"]
	ignore_edit_signals = false

func focused_edit_regrab_focus():
	if focused_edit:
		focused_edit.grab_focus()

func expand():
	expand_button.icon = gui_tree_arrow_down_icon
	expand_section.show()

func collapse():
	expand_button.icon = gui_tree_arrow_right_icon
	expand_section.hide()

