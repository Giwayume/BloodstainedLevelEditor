extends Spatial
class_name BaseRoom3dNode

var selection_box_material = preload("res://Materials/EditorSelectionBox.tres")
var selection_mesh_material = preload("res://Materials/EditorSelectionMesh.tres")
const node_selection_area_script = preload("res://SceneComponents/Room3dNodes/NodeSelectionArea.gd")

var room_3d_display: Spatial
var tree_name: String
var definition: Dictionary
var use_parent_as_proxy: bool = false
var leaf_parent: Spatial = null
var alternate_child_placement_node: Spatial = null
var selection_transform_node: Spatial = null
var selection_light_node: Spatial = null
var persistent_level_child_ancestor: Spatial = null
var is_tree_leaf: bool = false # MUST be set inside of _init()
var is_in_deleted_branch: bool = false
var is_in_hidden_branch: bool = false
var is_selected: bool = false

# For static mesh model
var loaded_model: Spatial = null
var loaded_model_mesh_instance: MeshInstance = null
var loaded_model_mesh: Mesh = null
var model_just_selected_timeout = 0

##########################
# TRANSFORM NODE METHODS #
##########################

func _ready_selection_transform_node():
	selection_transform_node = self
	if definition.has("translation"):
		translation = definition["translation"]
	if definition.has("rotation_degrees"):
		rotation_degrees = definition["rotation_degrees"]
	if definition.has("scale"):
		scale = definition["scale"]

#######################
# STATIC MESH METHODS #
#######################

func _ready_static_mesh_node():
	if definition.has("static_mesh_name"):
		room_3d_display.load_3d_model(definition, self, "on_3d_model_loaded")

func _process_static_mesh_node(delta):
	if model_just_selected_timeout > 0:
		model_just_selected_timeout -= delta
		if model_just_selected_timeout <= 0:
			loaded_model_mesh_instance.material_override = null

func _place_static_mesh_model(new_loaded_model):
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
			area.set_script(node_selection_area_script)
			area.selectable_parent = self
			var collision_shape = CollisionShape.new()
			var box_shape = BoxShape.new()
			box_shape.extents = aabb.size / 2
			area.translation = aabb.position + (box_shape.extents)
			if is_in_deleted_branch or is_in_hidden_branch:
				area.collision_layer = 0
			else:
				area.collision_layer = PhysicsLayers3d.layers.editor_select_mesh
			area.collision_mask = PhysicsLayers3d.layers.none
			collision_shape.set_shape(box_shape)
			area.add_child(collision_shape)
			add_child(area)
			area.name = "CollisionArea"
			break

func _select_static_mesh_node():
	if loaded_model_mesh_instance != null:
		loaded_model_mesh_instance.material_override = null
		
		var selection_mesh = get_node_or_null("SelectionMesh")
		if selection_mesh != null:
			selection_mesh.get_parent().remove_child(selection_mesh)
		
		var selection_overlay_model = loaded_model.duplicate(0)
		for child_node in selection_overlay_model.get_children():
			if child_node is MeshInstance:
				child_node.material_override = selection_mesh_material
				pass
		add_child(selection_overlay_model)
		selection_overlay_model.name = "SelectionMesh"
		
		model_just_selected_timeout = 0.2
		loaded_model_mesh_instance.material_override = selection_box_material

func _deselect_static_mesh_node():
	if loaded_model_mesh_instance != null:
		var selection_mesh = get_node_or_null("SelectionMesh")
		if selection_mesh != null:
			selection_mesh.get_parent().remove_child(selection_mesh)

func _set_deleted_static_mesh_node(deleted: bool):
	var collision_area = get_node_or_null("CollisionArea")
	if collision_area:
		if deleted:
			get_node("CollisionArea").collision_layer = 0
			hide()
		elif not is_in_hidden_branch:
			get_node("CollisionArea").collision_layer = PhysicsLayers3d.layers.editor_select_mesh
			show()

func _set_hidden_static_mesh_node(hidden: bool):
	var collision_area = get_node_or_null("CollisionArea")
	if collision_area:
		if hidden:
			get_node("CollisionArea").collision_layer = 0
			hide()
		elif not is_in_deleted_branch:
			get_node("CollisionArea").collision_layer = PhysicsLayers3d.layers.editor_select_mesh
			show()

##################
# PUBLIC METHODS #
##################

func select():
	is_selected = true
	if is_tree_leaf:
		select_all_children()

func deselect():
	is_selected = false
	if is_tree_leaf:
		deselect_all_children()

func select_all_children(parent: Spatial = self):
	for child in parent.get_children():
		var child_is_tree_leaf = false
		if "is_tree_leaf" in child:
			child_is_tree_leaf = child.is_tree_leaf
		if child.has_method("select"):
			child.select()
		if not child_is_tree_leaf:
			select_all_children(child)

func deselect_all_children(parent: Spatial = self):
	for child in parent.get_children():
		var child_is_tree_leaf = false
		if "is_tree_leaf" in child:
			child_is_tree_leaf = child.is_tree_leaf
		if child.has_method("deselect"):
			child.deselect()
		if not child_is_tree_leaf:
			deselect_all_children(child)

func set_deleted(deleted: bool):
	is_in_deleted_branch = deleted
	var child_placement_node = self
	if alternate_child_placement_node != null:
		child_placement_node = alternate_child_placement_node
	for child in child_placement_node.get_children():
		if child.has_method("set_deleted"):
			child.set_deleted(deleted)

func set_hidden(hidden: bool):
	is_in_hidden_branch = hidden
	var child_placement_node = self
	if alternate_child_placement_node != null:
		child_placement_node = alternate_child_placement_node
	for child in child_placement_node.get_children():
		if child.has_method("set_hidden"):
			child.set_hidden(hidden)

func clone_config_from(node):
	room_3d_display = node.room_3d_display
	tree_name = node.tree_name
	definition = node.definition
	use_parent_as_proxy = node.use_parent_as_proxy
	leaf_parent = node.leaf_parent
	alternate_child_placement_node = node.alternate_child_placement_node
	selection_transform_node = node.selection_transform_node
	selection_light_node = node.selection_light_node
	persistent_level_child_ancestor = node.persistent_level_child_ancestor
	is_tree_leaf = node.is_tree_leaf
	is_in_deleted_branch = node.is_in_deleted_branch
	is_in_hidden_branch = node.is_in_hidden_branch
	is_selected = node.is_selected

	# For static mesh model
	loaded_model = node.loaded_model
	loaded_model_mesh_instance = node.loaded_model_mesh_instance
	loaded_model_mesh = node.loaded_model_mesh
	model_just_selected_timeout = node.model_just_selected_timeout
