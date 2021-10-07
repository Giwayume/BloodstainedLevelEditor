extends HistoryAction
class_name HistoryGroupAction

var _actions: Array

func _init(group_description, actions: Array):
	id = HistoryAction.ID.SPATIAL_TRANSFORM
	description = group_description
	_actions = actions

func do():
	.do()
	for action in _actions:
		action.do()

func undo():
	.undo()
	for i in range(_actions.size() - 1, -1, -1):
		_actions[i].undo()

func get_ids():
	var ids = []
	for action in _actions:
		ids = ids + action.get_ids()
	return ids
