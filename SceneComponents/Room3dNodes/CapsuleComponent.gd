extends BaseRoom3dNode

var editor_collider_visualization_material = preload("res://Materials/EditorColliderVisualization.tres")
var selection_box_material = preload("res://Materials/EditorSelectionBox.tres")

var capsule_half_height = 1
var capsule_radius = 1

func _ready():
	selection_transform_node = self
	if definition.has("translation"):
		translation = definition["translation"]
	if definition.has("rotation_degrees"):
		rotation_degrees = definition["rotation_degrees"]
	if definition.has("scale"):
		scale = definition["scale"]
	if definition.has("capsule_half_height"):
		capsule_half_height = definition["capsule_half_height"]
	if definition.has("capsule_radius"):
		capsule_radius = definition["capsule_radius"]
	call_deferred("create_collision_area")


func create_collision_area():
	var area = Area.new()
	var collision_shape = CollisionShape.new()
	var capsule_shape = CapsuleShape.new()
	capsule_shape.height = (capsule_half_height * 2) - (capsule_radius * 2)
	capsule_shape.radius = capsule_radius
	area.rotation_degrees = Vector3(90, 0, 0)
	if is_in_deleted_branch:
		area.collision_layer = 0
	else:
		area.collision_layer = PhysicsLayers3d.layers.editor_select_collider
	area.collision_mask = PhysicsLayers3d.layers.none
	collision_shape.set_shape(capsule_shape)
	area.add_child(collision_shape)
	add_child(area)
	area.name = "CollisionArea"
	
	var im = ImmediateGeometry.new()
	im.begin(Mesh.PRIMITIVE_LINE_LOOP)
	im.add_vertex(Vector3(capsule_radius, -capsule_half_height + (capsule_radius), 0))
	im.add_vertex(Vector3(capsule_radius, capsule_half_height - (capsule_radius), 0))
	draw_circle_arc(im, Vector3(0, capsule_half_height - capsule_radius, 0), Vector3(0, 0, 0), 0, capsule_radius, 90, 270, 16)
	im.add_vertex(Vector3(-capsule_radius, capsule_half_height - (capsule_radius), 0))
	im.add_vertex(Vector3(-capsule_radius, -capsule_half_height + (capsule_radius), 0))
	draw_circle_arc(im, Vector3(0, -capsule_half_height + capsule_radius, 0), Vector3(0, 0, 0), 0, capsule_radius, 270, 450, 16)
	im.end()
	im.begin(Mesh.PRIMITIVE_LINE_LOOP)
	im.add_vertex(Vector3(0, -capsule_half_height + (capsule_radius), capsule_radius))
	im.add_vertex(Vector3(0, capsule_half_height - (capsule_radius), capsule_radius))
	draw_circle_arc(im, Vector3(0, capsule_half_height - capsule_radius, 0), Vector3(0, 1, 0), -90, capsule_radius, 90, 270, 16)
	im.add_vertex(Vector3(0, capsule_half_height - (capsule_radius), -capsule_radius))
	im.add_vertex(Vector3(0, -capsule_half_height + (capsule_radius), -capsule_radius))
	draw_circle_arc(im, Vector3(0, -capsule_half_height + capsule_radius, 0), Vector3(0, 1, 0), -90, capsule_radius, 270, 450, 16)
	im.end()
	im.begin(Mesh.PRIMITIVE_LINE_LOOP)
	draw_circle_arc(im, Vector3(0, -capsule_half_height + capsule_radius, 0), Vector3(-1, 0, 0), 90, capsule_radius, 0, 360, 32)
	im.end()
	im.begin(Mesh.PRIMITIVE_LINE_LOOP)
	draw_circle_arc(im, Vector3(0, capsule_half_height - capsule_radius, 0), Vector3(-1, 0, 0), 90, capsule_radius, 0, 360, 32)
	im.end()
	im.material_override = editor_collider_visualization_material
	add_child(im)
	im.name = "CollisionAreaVisualization"
	
	if is_in_hidden_branch or is_in_deleted_branch:
		get_node("CollisionArea").collision_layer = 0
		hide()

func draw_circle_arc(im: ImmediateGeometry, center: Vector3, rotation_axis: Vector3, rotation_phi: float, radius: float, angle_from: float, angle_to: float, nb_points: int = 16):
	var points_arc = PoolVector3Array()
	var transform = Transform()
	transform = transform.rotated(rotation_axis.normalized(), deg2rad(rotation_phi))

	for i in range(nb_points + 1):
		var angle_point = deg2rad(angle_from + i * (angle_to-angle_from) / nb_points - 90)
		var point = center + transform.xform(Vector3(cos(angle_point), sin(angle_point), 0) * radius)
		if i == 0:
			im.set_color(Color("ff0000"))
		else:
			im.set_color(Color("ffffff"))
		im.add_vertex(point)

func select():
	.select()
	get_node("CollisionAreaVisualization").material_override = selection_box_material
	
func deselect():
	.deselect()
	get_node("CollisionAreaVisualization").material_override = editor_collider_visualization_material

func set_deleted(deleted: bool):
	.set_deleted(deleted)
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
	var collision_area = get_node_or_null("CollisionArea")
	if collision_area:
		if hidden:
			get_node("CollisionArea").collision_layer = 0
			hide()
		elif not is_in_deleted_branch:
			get_node("CollisionArea").collision_layer = PhysicsLayers3d.layers.editor_select_collider
			show()
