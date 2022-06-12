extends HistoryAction
class_name RevertComponentAction

var _node: Spatial
var _removed_props: Dictionary = {}

func _init(node: Spatial):
	id = HistoryAction.ID.REVERT_COMPONENT
	description = "Revert Component"
	_node = node

func apply_node_edits(property_name):
	if property_name == "translation":
		if _node.definition.has("translation"):
			_node["translation"] = _node.definition["translation"]
		else:
			_node["translation"] = Vector3()
	elif property_name == "rotation_degrees":
		if _node.definition.has("rotation_degrees"):
			_node["rotation_degrees"] = _node.definition["rotation_degrees"]
		else:
			_node["rotation_degrees"] = Vector3()
	elif property_name == "scale":
		if _node.definition.has("scale"):
			_node["scale"] = _node.definition["scale"]
		else:
			_node["scale"] = Vector3(1, 1, 1)
	elif property_name == "deleted":
		_node.set_deleted(_node.definition.has("deleted") and _node.definition["deleted"])

func do():
	.do()
	_removed_props = {}
	if _node.definition.has("export_index"):
		var export_index = _node.definition["export_index"]
		var prop_list = Editor.get_room_edit_export_prop_list(_node.tree_name, export_index)
		for property_name in prop_list:
			if (_node.definition.has(property_name)):
				_removed_props[property_name] = _node.definition[property_name]
				if _node.definition.has("_unedited_" + property_name):
					if _node.definition["_unedited_" + property_name] == null:
						_node.definition.erase(property_name)
					else:
						_node.definition[property_name] = ObjectExt.deep_copy(_node.definition["_unedited_" + property_name])
			else:
				_removed_props[property_name] = null
			apply_node_edits(property_name)
			Editor.remove_room_edit_export_prop(_node.tree_name, export_index, property_name)

func undo():
	.undo()
	if _node.definition.has("export_index"):
		var export_index = _node.definition["export_index"]
		for property_name in _removed_props:
			if _removed_props[property_name] != null:
				_node.definition[property_name] = _removed_props[property_name]
				Editor.set_room_edit_export_prop(_node.tree_name, export_index, property_name, _node.definition[property_name])
			apply_node_edits(property_name)
