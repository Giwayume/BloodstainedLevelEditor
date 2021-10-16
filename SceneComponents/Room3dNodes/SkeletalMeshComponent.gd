extends BaseRoom3dNode

var selection_box_material = preload("res://Materials/EditorSelectionBox.tres")
var selection_mesh_material = preload("res://Materials/EditorSelectionMesh.tres")

var loaded_model: Spatial
var loaded_model_mesh_instance: MeshInstance
var loaded_model_mesh: Mesh
var model_just_selected_timeout = 0

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

func on_3d_model_loaded(new_loaded_model):
	loaded_model = new_loaded_model
	add_child(loaded_model)
	loaded_model.name = "Model3D"
	if is_in_deleted_branch:
		hide()
	for child_node in loaded_model.get_children():
		if child_node is MeshInstance:
			loaded_model_mesh_instance = child_node
			var mesh = child_node.mesh
			loaded_model_mesh = mesh
			var aabb = mesh.get_aabb()
			var area = Area.new()
			var collision_shape = CollisionShape.new()
			var box_shape = BoxShape.new()
			box_shape.extents = aabb.size / 2
			area.translation = aabb.position + (box_shape.extents)
			if is_in_deleted_branch:
				area.collision_layer = 0
			else:
				area.collision_layer = PhysicsLayers3d.layers.editor_select_mesh
			area.collision_mask = PhysicsLayers3d.layers.none
			collision_shape.set_shape(box_shape)
			area.add_child(collision_shape)
			add_child(area)
			area.name = "CollisionArea"
			break

func select():
	.select()
	if loaded_model_mesh_instance != null and not get_node_or_null("SelectionOutline"):
		loaded_model_mesh_instance.material_override = null
		
		var selection_overlay_model = loaded_model.duplicate(0)
		for child_node in selection_overlay_model.get_children():
			if child_node is MeshInstance:
				child_node.material_override = selection_mesh_material
				pass
		add_child(selection_overlay_model)
		selection_overlay_model.name = "SelectionMesh"
		
		model_just_selected_timeout = 0.2
		loaded_model_mesh_instance.material_override = selection_box_material
		
func deselect():
	.deselect()
	if loaded_model_mesh_instance != null:
		var selection_outline = get_node_or_null("SelectionOutline")
		if selection_outline != null:
			selection_outline.get_parent().remove_child(selection_outline)
		var selection_mesh = get_node_or_null("SelectionMesh")
		if selection_mesh != null:
			selection_mesh.get_parent().remove_child(selection_mesh)
		loaded_model.show()
		
func set_deleted(deleted: bool):
	.set_deleted(deleted)
	var collision_area = get_node_or_null("CollisionArea")
	if collision_area:
		if deleted:
			get_node("CollisionArea").collision_layer = 0
			hide()
		elif not is_in_hidden_branch:
			get_node("CollisionArea").collision_layer = PhysicsLayers3d.layers.editor_select_mesh
			show()

func set_hidden(hidden: bool):
	.set_hidden(hidden)
	var collision_area = get_node_or_null("CollisionArea")
	if collision_area:
		if hidden:
			get_node("CollisionArea").collision_layer = 0
			hide()
		elif not is_in_deleted_branch:
			get_node("CollisionArea").collision_layer = PhysicsLayers3d.layers.editor_select_mesh
			show()
