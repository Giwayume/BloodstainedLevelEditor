extends BaseRoom3dNode

func _ready():
	_ready_selection_transform_node()
	if (
		persistent_level_child_ancestor != null and
		persistent_level_child_ancestor.definition.has("mesh_export_index") and
		persistent_level_child_ancestor.definition["mesh_export_index"] == definition["export_index"] and
		"main_skeletal_mesh" in persistent_level_child_ancestor
	):
		persistent_level_child_ancestor.main_skeletal_mesh = self

func _process(delta):
	_process_static_mesh_node(delta)

func on_3d_model_loaded(new_loaded_model):
	_place_static_mesh_model(new_loaded_model)

func select():
	.select()
	_select_static_mesh_node()

func deselect():
	.deselect()
	_deselect_static_mesh_node()

func set_deleted(deleted: bool):
	.set_deleted(deleted)
	_set_deleted_static_mesh_node(deleted)

func set_hidden(hidden: bool):
	.set_hidden(hidden)
	_set_hidden_static_mesh_node(hidden)
