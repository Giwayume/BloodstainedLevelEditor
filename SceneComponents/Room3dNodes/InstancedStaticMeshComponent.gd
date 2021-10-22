extends BaseRoom3dNode

func _ready():
	_ready_selection_transform_node()
	_ready_static_mesh_node()
	if get_parent().definition["type"] == "StaticMeshActor":
		use_parent_as_proxy = true

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
