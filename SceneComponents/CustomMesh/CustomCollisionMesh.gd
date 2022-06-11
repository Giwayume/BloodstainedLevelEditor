class_name CustomCollisionMesh
extends BaseRoom3dNode

var editor_collider_visualization_material = preload("res://Materials/EditorColliderVisualization.tres")

var collision_area: Area
var collision_visualization: ImmediateGeometry

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
	# Child class creates area & visualization first
	
	collision_area.name = "CollisionArea"
	collision_area.collision_layer = PhysicsLayers3d.layers.editor_select_collider
	collision_area.collision_mask = PhysicsLayers3d.layers.none
	add_child(collision_area)
	
	collision_visualization.name = "CollisionAreaVisualization"
	collision_visualization.material_override = editor_collider_visualization_material
	add_child(collision_visualization)
	
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

func generate_cube(wx, wz, h):
	var area = Area.new()
	area.set_script(node_selection_area_script)
	area.selectable_parent = self
	var collision_shape = CollisionShape.new()
	var box_shape = BoxShape.new()
	box_shape.extents = Vector3(wx, h, wz)
	collision_shape.transform.origin = Vector3(0, 0, 0)
	collision_shape.set_shape(box_shape)
	area.add_child(collision_shape)
	collision_area = area
	
	var cv = ImmediateGeometry.new()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(-wx, h, -wz))
	cv.add_vertex(Vector3(-wx, h, wz))
	cv.add_vertex(Vector3(wx, h, wz))
	cv.add_vertex(Vector3(wx, h, -wz))
	cv.add_vertex(Vector3(-wx, h, -wz))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(-wx, -h, -wz))
	cv.add_vertex(Vector3(-wx, -h, wz))
	cv.add_vertex(Vector3(wx, -h, wz))
	cv.add_vertex(Vector3(wx, -h, -wz))
	cv.add_vertex(Vector3(-wx, -h, -wz))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(-wx, h, -wz))
	cv.add_vertex(Vector3(-wx, -h, -wz))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(wx, h, -wz))
	cv.add_vertex(Vector3(wx, -h, -wz))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(-wx, h, wz))
	cv.add_vertex(Vector3(-wx, -h, wz))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(wx, h, wz))
	cv.add_vertex(Vector3(wx, -h, wz))
	cv.end()
	collision_visualization = cv

func generate_wedge_slope(wx, wz, h):
	var area = Area.new()
	area.set_script(node_selection_area_script)
	area.selectable_parent = self
	var collision_polygon = CollisionPolygon.new()
	collision_polygon.polygon = PoolVector2Array([
		Vector2(0, 0),
		Vector2(wx, 0),
		Vector2(wx, h),
	])
	collision_polygon.depth = wz
	collision_polygon.transform.origin = Vector3(0, 0, -wz / 2)
	area.add_child(collision_polygon)
	collision_area = area
	
	var cv = ImmediateGeometry.new()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(0, 0, 0))
	cv.add_vertex(Vector3(wx, h, 0))
	cv.add_vertex(Vector3(wx, h, -wz))
	cv.add_vertex(Vector3(0, 0, -wz))
	cv.add_vertex(Vector3(0, 0, 0))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(0, 0, 0))
	cv.add_vertex(Vector3(wx, 0, 0))
	cv.add_vertex(Vector3(wx, 0, -wz))
	cv.add_vertex(Vector3(0, 0, -wz))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(wx, h, -wz))
	cv.add_vertex(Vector3(wx, 0, -wz))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(wx, h, 0))
	cv.add_vertex(Vector3(wx, 0, 0))
	cv.end()
	collision_visualization = cv

func generate_box_slope(wx, wz, hl, hr):
	var area = Area.new()
	area.set_script(node_selection_area_script)
	area.selectable_parent = self
	var collision_shape = CollisionShape.new()
	var box_shape = BoxShape.new()
	box_shape.extents = Vector3(wx / 2, min(hl, hr) / 2, -wz / 2)
	collision_shape.set_shape(box_shape)
	collision_shape.transform.origin = Vector3(wx / 2, min(hl, hr) / 2, -wz / 2)
	area.add_child(collision_shape)
	var collision_polygon = CollisionPolygon.new()
	collision_polygon.polygon = PoolVector2Array([
		Vector2(0, hl),
		Vector2(wx, hl),
		Vector2(wx, hr),
	])
	collision_polygon.depth = wz
	collision_polygon.transform.origin = Vector3(0, 0, -wz / 2)
	area.add_child(collision_polygon)
	collision_area = area
	
	var cv = ImmediateGeometry.new()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(0, hl, 0))
	cv.add_vertex(Vector3(wx, hr, 0))
	cv.add_vertex(Vector3(wx, hr, -wz))
	cv.add_vertex(Vector3(0, hl, -wz))
	cv.add_vertex(Vector3(0, hl, 0))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(0, 0, 0))
	cv.add_vertex(Vector3(wx, 0, 0))
	cv.add_vertex(Vector3(wx, 0, -wz))
	cv.add_vertex(Vector3(0, 0, -wz))
	cv.add_vertex(Vector3(0, 0, 0))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(0, hl, 0))
	cv.add_vertex(Vector3(0, 0, 0))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(0, hl, -wz))
	cv.add_vertex(Vector3(0, 0, -wz))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(wx, hr, -wz))
	cv.add_vertex(Vector3(wx, 0, -wz))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(wx, hr, 0))
	cv.add_vertex(Vector3(wx, 0, 0))
	cv.end()
	collision_visualization = cv

