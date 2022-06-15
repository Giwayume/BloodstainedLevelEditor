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
	
	collision_area.set_script(node_selection_area_script)
	collision_area.selectable_parent = self
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

func generate_sectioned_slope_2(s1, s2, depth):
	var area = Area.new()
	area.set_script(node_selection_area_script)
	area.selectable_parent = self
	var collision_polygon = CollisionPolygon.new()
	collision_polygon.polygon = PoolVector2Array([
		Vector2(0, 0),
		Vector2(.6, s1),
		Vector2(1.2, s2),
		Vector2(1.2, 0.0),
		Vector2(0.6, 0.0)
	])
	collision_polygon.depth = depth
	collision_polygon.transform.origin = Vector3(0, 0, -depth/2)
	area.add_child(collision_polygon)
	collision_area = area
	
	var cv = ImmediateGeometry.new()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(0, 0, 0))
	cv.add_vertex(Vector3(0.6, s1, 0))
	cv.add_vertex(Vector3(0.6, s1, -depth))
	cv.add_vertex(Vector3(0, 0, -depth))
	cv.add_vertex(Vector3(0, 0, 0))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(0.6, s1, 0))
	cv.add_vertex(Vector3(1.2, s2, 0))
	cv.add_vertex(Vector3(1.2, s2, -depth))
	cv.add_vertex(Vector3(0.6, s1, -depth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(1.2, s2, 0))
	cv.add_vertex(Vector3(1.2, 0, 0))
	cv.add_vertex(Vector3(0, 0, 0))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(1.2, s2, -depth))
	cv.add_vertex(Vector3(1.2, 0, -depth))
	cv.add_vertex(Vector3(0, 0, -depth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(1.2, 0, 0))
	cv.add_vertex(Vector3(1.2, 0, -depth))
	cv.end()
	collision_visualization = cv

func generate_sectioned_slope_3(s1, s2, s3, depth):
	var area = Area.new()
	area.set_script(node_selection_area_script)
	area.selectable_parent = self
	var collision_polygon = CollisionPolygon.new()
	collision_polygon.polygon = PoolVector2Array([
		Vector2(0, 0),
		Vector2(.6, s1),
		Vector2(1.2, s2),
		Vector2(1.8, s3),
		Vector2(1.8, 0.0),
		Vector2(1.2, 0.0),
		Vector2(0.6, 0.0)
	])
	collision_polygon.depth = depth
	collision_polygon.transform.origin = Vector3(0, 0, -depth/2)
	area.add_child(collision_polygon)
	collision_area = area
	
	var cv = ImmediateGeometry.new()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(0, 0, 0))
	cv.add_vertex(Vector3(0.6, s1, 0))
	cv.add_vertex(Vector3(0.6, s1, -depth))
	cv.add_vertex(Vector3(0, 0, -depth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_STRIP)
	cv.add_vertex(Vector3(0.6, s1, 0))
	cv.add_vertex(Vector3(1.2, s2, 0))
	cv.add_vertex(Vector3(1.2, s2, -depth))
	cv.add_vertex(Vector3(0.6, s1, -depth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_STRIP)
	cv.add_vertex(Vector3(1.2, s2, 0))
	cv.add_vertex(Vector3(1.8, s3, 0))
	cv.add_vertex(Vector3(1.8, s3, -depth))
	cv.add_vertex(Vector3(1.2, s2, -depth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_STRIP)
	cv.add_vertex(Vector3(1.8, s3, 0))
	cv.add_vertex(Vector3(1.8, 0, 0))
	cv.add_vertex(Vector3(0, 0, 0))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_STRIP)
	cv.add_vertex(Vector3(1.8, s3, -depth))
	cv.add_vertex(Vector3(1.8, 0, -depth))
	cv.add_vertex(Vector3(0, 0, -depth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_STRIP)
	cv.add_vertex(Vector3(1.8, 0, 0))
	cv.add_vertex(Vector3(1.8, 0, -depth))
	cv.end()
	collision_visualization = cv

func generate_sectioned_slope_4(s1, s2, s3, s4, depth):
	var area = Area.new()
	area.set_script(node_selection_area_script)
	area.selectable_parent = self
	var collision_polygon = CollisionPolygon.new()
	collision_polygon.polygon = PoolVector2Array([
		Vector2(0, 0),
		Vector2(.6, s1),
		Vector2(1.2, s2),
		Vector2(1.8, s3),
		Vector2(2.4, s4),
		Vector2(2.4, 0.0),
		Vector2(1.8, 0.0),
		Vector2(1.2, 0.0),
		Vector2(0.6, 0.0)
	])
	collision_polygon.depth = depth
	collision_polygon.transform.origin = Vector3(0, 0, -depth/2)
	area.add_child(collision_polygon)
	collision_area = area
	
	var cv = ImmediateGeometry.new()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(0, 0, 0))
	cv.add_vertex(Vector3(0.6, s1, 0))
	cv.add_vertex(Vector3(0.6, s1, -depth))
	cv.add_vertex(Vector3(0, 0, -depth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_STRIP)
	cv.add_vertex(Vector3(0.6, s1, 0))
	cv.add_vertex(Vector3(1.2, s2, 0))
	cv.add_vertex(Vector3(1.2, s2, -depth))
	cv.add_vertex(Vector3(0.6, s1, -depth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_STRIP)
	cv.add_vertex(Vector3(1.2, s2, 0))
	cv.add_vertex(Vector3(1.8, s3, 0))
	cv.add_vertex(Vector3(1.8, s3, -depth))
	cv.add_vertex(Vector3(1.2, s2, -depth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_STRIP)
	cv.add_vertex(Vector3(1.8, s3, 0))
	cv.add_vertex(Vector3(2.4, s4, 0))
	cv.add_vertex(Vector3(2.4, s4, -depth))
	cv.add_vertex(Vector3(1.8, s3, -depth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_STRIP)
	cv.add_vertex(Vector3(2.4, s4, 0))
	cv.add_vertex(Vector3(2.4, 0, 0))
	cv.add_vertex(Vector3(0, 0, 0))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_STRIP)
	cv.add_vertex(Vector3(2.4, s4, -depth))
	cv.add_vertex(Vector3(2.4, 0, -depth))
	cv.add_vertex(Vector3(0, 0, -depth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_STRIP)
	cv.add_vertex(Vector3(2.4, 0, 0))
	cv.add_vertex(Vector3(2.4, 0, -depth))
	cv.end()
	collision_visualization = cv

func generate_octagon(ix, ox, h, depth):
	var halfdepth = depth / 2
	var area = Area.new()
	area.set_script(node_selection_area_script)
	area.selectable_parent = self
	var collision_polygon = CollisionPolygon.new()
	collision_polygon.polygon = PoolVector2Array([
		Vector2(-ox, h),
		Vector2(-ix, h + .6),
		Vector2(ix, h + .6),
		Vector2(ox, h),
		Vector2(ox, 0),
		Vector2(ix, -.6),
		Vector2(-ix, -.6),
		Vector2(-ox, 0)
	])
	collision_polygon.depth = depth
	collision_polygon.transform.origin = Vector3(0, 0, 0)
	area.add_child(collision_polygon)
	collision_area = area
	
	var cv = ImmediateGeometry.new()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(-ox, h, -halfdepth))
	cv.add_vertex(Vector3(-ix, h + .6, -halfdepth))
	cv.add_vertex(Vector3(ix, h + .6, -halfdepth))
	cv.add_vertex(Vector3(ox, h, -halfdepth))
	cv.add_vertex(Vector3(ox, 0, -halfdepth))
	cv.add_vertex(Vector3(ix, -.6, -halfdepth))
	cv.add_vertex(Vector3(-ix, -.6, -halfdepth))
	cv.add_vertex(Vector3(-ox, 0, -halfdepth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(-ox, h, halfdepth))
	cv.add_vertex(Vector3(-ix, h + .6, halfdepth))
	cv.add_vertex(Vector3(ix, h + .6, halfdepth))
	cv.add_vertex(Vector3(ox, h, halfdepth))
	cv.add_vertex(Vector3(ox, 0, halfdepth))
	cv.add_vertex(Vector3(ix, -.6, halfdepth))
	cv.add_vertex(Vector3(-ix, -.6, halfdepth))
	cv.add_vertex(Vector3(-ox, 0, halfdepth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINES)
	cv.add_vertex(Vector3(-ox, h, halfdepth))
	cv.add_vertex(Vector3(-ox, h, -halfdepth))
	cv.add_vertex(Vector3(-ix, h + .6, halfdepth))
	cv.add_vertex(Vector3(-ix, h + .6, -halfdepth))
	cv.add_vertex(Vector3(ix, h + .6, halfdepth))
	cv.add_vertex(Vector3(ix, h + .6, -halfdepth))
	cv.add_vertex(Vector3(ox, h, halfdepth))
	cv.add_vertex(Vector3(ox, h, -halfdepth))
	cv.add_vertex(Vector3(ox, 0, halfdepth))
	cv.add_vertex(Vector3(ox, 0, -halfdepth))
	cv.add_vertex(Vector3(ix, -.6, halfdepth))
	cv.add_vertex(Vector3(ix, -.6, -halfdepth))
	cv.add_vertex(Vector3(-ix, -.6, halfdepth))
	cv.add_vertex(Vector3(-ix, -.6, -halfdepth))
	cv.add_vertex(Vector3(-ox, 0, halfdepth))
	cv.add_vertex(Vector3(-ox, 0, -halfdepth))
	cv.end()
	collision_visualization = cv
