extends BaseRoom3dNode

func _ready():
	selection_transform_node = self
	if definition.has("translation"):
		translation = definition["translation"]
	if definition.has("rotation_degrees"):
		rotation_degrees = definition["rotation_degrees"]
	if definition.has("scale"):
		scale = definition["scale"]
	if (
		persistent_level_child_ancestor != null and
		persistent_level_child_ancestor.definition.has("mesh_export_index") and
		persistent_level_child_ancestor.definition["mesh_export_index"] == definition["export_index"] and
		"main_skeletal_mesh" in persistent_level_child_ancestor
	):
		persistent_level_child_ancestor.main_skeletal_mesh = self
