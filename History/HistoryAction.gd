extends Reference
class_name HistoryAction

enum ID {
	DELETE_COMPONENT,
	HISTORY_GROUP,
	SPATIAL_TRANSFORM,
	REVERT_COMPONENT,
	UNDELETE_COMPONENT,
	UNDEFINED,
	UPDATE_LIGHT,
}

var id: int = ID.UNDEFINED
var is_done: bool = false
var description: String = "Undefined"

func do():
	is_done = true

func undo():
	is_done = false

func get_ids():
	return [id]
