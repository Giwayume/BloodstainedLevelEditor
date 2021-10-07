extends HistoryAction
class_name SpatialTransformAction

var _node: Spatial
var _old_global_transform: Transform
var _new_global_transform: Transform

var _old_translation_value
var _old_rotation_degrees_value
var _old_scale_value

func _init(node: Spatial, old_global_transform: Transform, new_global_transform: Transform):
	id = HistoryAction.ID.SPATIAL_TRANSFORM
	description = "Spatial Transform"
	_node = node
	_old_global_transform = old_global_transform
	_new_global_transform = new_global_transform

func do():
	.do()
	_node.global_transform = _new_global_transform
	if _node.definition.has("export_index"):
		var export_index = _node.definition["export_index"]
		_old_translation_value = Editor.get_room_edit_export_prop(_node.tree_name, export_index, "translation")
		_old_rotation_degrees_value = Editor.get_room_edit_export_prop(_node.tree_name, export_index, "rotation_degrees")
		_old_scale_value = Editor.get_room_edit_export_prop(_node.tree_name, export_index, "scale")
		Editor.set_room_edit_export_prop(_node.tree_name, export_index, "translation", _node.translation)
		Editor.set_room_edit_export_prop(_node.tree_name, export_index, "rotation_degrees", _node.rotation_degrees)
		Editor.set_room_edit_export_prop(_node.tree_name, export_index, "scale", _node.scale)

func undo():
	.undo()
	_node.global_transform = _old_global_transform
	if _node.definition.has("export_index"):
		var export_index = _node.definition["export_index"]
		Editor.set_room_edit_export_prop(_node.tree_name, export_index, "translation", _old_translation_value)
		Editor.set_room_edit_export_prop(_node.tree_name, export_index, "rotation_degrees", _old_rotation_degrees_value)
		Editor.set_room_edit_export_prop(_node.tree_name, export_index, "scale", _old_scale_value)

