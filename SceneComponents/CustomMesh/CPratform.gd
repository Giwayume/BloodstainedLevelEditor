extends BaseRoom3dNode

var editor_collider_visualization_material = preload("res://Materials/EditorColliderVisualization.tres")

var gizmo_bounds: ImmediateGeometry

func _ready():
	_ready_selection_transform_node()
	_ready_static_mesh_node()
	use_parent_as_proxy = true
	call_deferred("create_collision_area")

func _process(delta):
	_process_static_mesh_node(delta)

func on_3d_model_loaded(new_loaded_model):
	pass

# Called when the node enters the scene tree for the first time.
func create_collision_area():
	var wx = .3
	var wz = .2
	var h = .5
	
	var area = Area.new()
	area.set_script(node_selection_area_script)
	area.selectable_parent = self
	var collision_shape = CollisionShape.new()
	var box_shape = BoxShape.new()
	box_shape.extents = Vector3(wx, h, wz)
	area.collision_layer = PhysicsLayers3d.layers.editor_select_collider
	area.collision_mask = PhysicsLayers3d.layers.none
	collision_shape.transform.origin = Vector3(0, 0, 0)
	collision_shape.set_shape(box_shape)
	area.add_child(collision_shape)
	add_child(area)
	area.name = "CollisionArea"
	
	gizmo_bounds = ImmediateGeometry.new()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINE_LOOP)
	gizmo_bounds.add_vertex(Vector3(-wx, h, -wz))
	gizmo_bounds.add_vertex(Vector3(-wx, h, wz))
	gizmo_bounds.add_vertex(Vector3(wx, h, wz))
	gizmo_bounds.add_vertex(Vector3(wx, h, -wz))
	gizmo_bounds.add_vertex(Vector3(-wx, h, -wz))
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINE_LOOP)
	gizmo_bounds.add_vertex(Vector3(-wx, -h, -wz))
	gizmo_bounds.add_vertex(Vector3(-wx, -h, wz))
	gizmo_bounds.add_vertex(Vector3(wx, -h, wz))
	gizmo_bounds.add_vertex(Vector3(wx, -h, -wz))
	gizmo_bounds.add_vertex(Vector3(-wx, -h, -wz))
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINE_LOOP)
	gizmo_bounds.add_vertex(Vector3(-wx, h, -wz))
	gizmo_bounds.add_vertex(Vector3(-wx, -h, -wz))
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINE_LOOP)
	gizmo_bounds.add_vertex(Vector3(wx, h, -wz))
	gizmo_bounds.add_vertex(Vector3(wx, -h, -wz))
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINE_LOOP)
	gizmo_bounds.add_vertex(Vector3(-wx, h, wz))
	gizmo_bounds.add_vertex(Vector3(-wx, -h, wz))
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINE_LOOP)
	gizmo_bounds.add_vertex(Vector3(wx, h, wz))
	gizmo_bounds.add_vertex(Vector3(wx, -h, wz))
	gizmo_bounds.end()
	gizmo_bounds.material_override = editor_collider_visualization_material
	add_child(gizmo_bounds)
	gizmo_bounds.name = "CollisionAreaVisualization"
	
	if is_in_hidden_branch or is_in_deleted_branch:
		get_node("CollisionArea").collision_layer = 0
		hide()

func select():
	.select()
	_select_static_mesh_node()
	get_node("CollisionAreaVisualization").material_override = selection_box_material
	
func deselect():
	.deselect()
	_deselect_static_mesh_node()
	get_node("CollisionAreaVisualization").material_override = editor_collider_visualization_material

func set_deleted(deleted: bool):
	.set_deleted(deleted)
	_set_deleted_static_mesh_node(deleted)
	var collision_area = get_node_or_null("CollisionArea")
	if collision_area:
		if deleted:
			get_node("CollisionArea").collision_layer = 0
			hide()
		elif not is_in_hidden_branch:
			get_node("CollisionArea").collision_layer = PhysicsLayers3d.layers.editor_select_collider
			show()

func set_hidden(hidden: bool):
	.set_hidden(hidden)
	_set_hidden_static_mesh_node(hidden)
	var collision_area = get_node_or_null("CollisionArea")
	if collision_area:
		if hidden:
			get_node("CollisionArea").collision_layer = 0
			hide()
		elif not is_in_deleted_branch:
			get_node("CollisionArea").collision_layer = PhysicsLayers3d.layers.editor_select_collider
			show()
