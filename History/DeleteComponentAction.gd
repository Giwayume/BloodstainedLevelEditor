extends HistoryAction
class_name DeleteComponentAction

var _node: Spatial

func _init(node: Spatial):
	id = HistoryAction.ID.DELETE_COMPONENT
	description = "Delete Component"
	_node = node

func do():
	.do()
	if _node.definition.has("export_index"):
		var export_index = _node.definition["export_index"]
		_node.definition["deleted"] = true
		_node.set_deleted(true)
		Editor.set_room_edit_export_prop(_node.tree_name, export_index, "deleted", true)

func undo():
	.undo()
	if _node.definition.has("export_index"):
		var export_index = _node.definition["export_index"]
		_node.definition["deleted"] = false
		if not (_node.definition.has("hidden") and _node.definition["hidden"]):
			_node.set_deleted(false)
		Editor.remove_room_edit_export_prop(_node.tree_name, export_index, "deleted")

