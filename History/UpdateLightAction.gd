extends HistoryAction
class_name UpdateLightAction

const light_defaults = preload("res://Config/LightDefaults.gd").light_defaults

var _node: Spatial
var _new_properties: Dictionary
var _old_properties: Dictionary

func _init(node: Spatial, new_properties: Dictionary, old_properties: Dictionary):
	id = HistoryAction.ID.UPDATE_LIGHT
	description = "Update Light"
	_node = node
	_new_properties = new_properties
	_old_properties = old_properties

func do():
	.do()
	if _node.definition.has("export_index"):
		var export_index = _node.definition["export_index"]
		for property_name in _new_properties:
			_node.definition[property_name] = _new_properties[property_name]
			Editor.set_room_edit_export_prop(_node.tree_name, export_index, property_name, _new_properties[property_name])
		_node.set_light_properties(_new_properties)

func undo():
	.undo()
	if _node.definition.has("export_index"):
		var export_index = _node.definition["export_index"]
		var update_properties: Dictionary = {}
		for property_name in _new_properties:
			if _old_properties.has(property_name):
				_node.definition[property_name] = _old_properties[property_name]
				update_properties[property_name] = _old_properties[property_name]
				Editor.set_room_edit_export_prop(_node.tree_name, export_index, property_name, _old_properties[property_name])
			else:
				_node.definition.erase(property_name)
				update_properties[property_name] = light_defaults[property_name]
				Editor.set_room_edit_export_prop(_node.tree_name, export_index, property_name, light_defaults[property_name])
		_node.set_light_properties(update_properties)
