extends Spatial

var room_3d_display: Spatial
var definition: Dictionary
var is_tree_leaf: bool = true

var selection_box_material = preload("res://Materials/EditorSelectionBox.tres")
var selection_mesh_material = preload("res://Materials/EditorSelectionMesh.tres")
var selection_line_size = 0.05
var loaded_model: Spatial
var loaded_model_mesh_instance: MeshInstance
var loaded_model_mesh: Mesh
var model_just_selected_timeout = 0

func _ready():
	if definition.has("translation"):
		translation = definition["translation"]
	if definition.has("rotation_degrees"):
		rotation_degrees = definition["rotation_degrees"]
	if definition.has("scale"):
		scale = definition["scale"]
	if definition.has("static_mesh_name"):
		room_3d_display.load_3d_model(definition, self, "on_3d_model_loaded")

func _process(delta):
	if model_just_selected_timeout > 0:
		model_just_selected_timeout -= delta
		if model_just_selected_timeout <= 0:
			loaded_model_mesh_instance.material_override = null

func on_3d_model_loaded(new_loaded_model):
	loaded_model = new_loaded_model
	loaded_model.name = "Model3D"
	add_child(loaded_model)
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
			area.collision_layer = PhysicsLayers3d.layers.editor_select
			area.collision_mask = PhysicsLayers3d.layers.none
			collision_shape.set_shape(box_shape)
			area.add_child(collision_shape)
			add_child(area)
			area.name = "CollisionArea"
			break

func select():
	if not get_node_or_null("SelectionOutline"):
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
		
		# loaded_model.hide()
		
#		var aabb = loaded_model_mesh.get_aabb()
#		var outline_container = Spatial.new()
#		var line1 = CSGBox.new()
#		line1.material = selection_box_material
#		line1.width = selection_line_size
#		line1.depth = selection_line_size
#		line1.height = aabb.size.y + selection_line_size
#		line1.translation = aabb.position + Vector3(0, aabb.size.y / 2, 0)
#		outline_container.add_child(line1)
#		var line2 = CSGBox.new()
#		line2.material = selection_box_material
#		line2.width = selection_line_size
#		line2.depth = selection_line_size
#		line2.height = aabb.size.y + selection_line_size
#		line2.translation = aabb.position + Vector3(aabb.size.x, aabb.size.y / 2, 0)
#		outline_container.add_child(line2)
#		var line3 = CSGBox.new()
#		line3.material = selection_box_material
#		line3.width = selection_line_size
#		line3.depth = selection_line_size
#		line3.height = aabb.size.y + selection_line_size
#		line3.translation = aabb.position + Vector3(0, aabb.size.y / 2, aabb.size.z)
#		outline_container.add_child(line3)
#		var line4 = CSGBox.new()
#		line4.material = selection_box_material
#		line4.width = selection_line_size
#		line4.depth = selection_line_size
#		line4.height = aabb.size.y + selection_line_size
#		line4.translation = aabb.position + Vector3(aabb.size.x, aabb.size.y / 2, aabb.size.z)
#		outline_container.add_child(line4)
#		var line5 = CSGBox.new()
#		line5.material = selection_box_material
#		line5.width = aabb.size.x + selection_line_size
#		line5.depth = selection_line_size
#		line5.height = selection_line_size
#		line5.translation = aabb.position + Vector3(aabb.size.x / 2, 0, 0)
#		outline_container.add_child(line5)
#		var line6 = CSGBox.new()
#		line6.material = selection_box_material
#		line6.width = aabb.size.x + selection_line_size
#		line6.depth = selection_line_size
#		line6.height = selection_line_size
#		line6.translation = aabb.position + Vector3(aabb.size.x / 2, aabb.size.y, 0)
#		outline_container.add_child(line6)
#		var line7 = CSGBox.new()
#		line7.material = selection_box_material
#		line7.width = aabb.size.x + selection_line_size
#		line7.depth = selection_line_size
#		line7.height = selection_line_size
#		line7.translation = aabb.position + Vector3(aabb.size.x / 2, 0, aabb.size.z)
#		outline_container.add_child(line7)
#		var line8 = CSGBox.new()
#		line8.material = selection_box_material
#		line8.width = aabb.size.x + selection_line_size
#		line8.depth = selection_line_size
#		line8.height = selection_line_size
#		line8.translation = aabb.position + Vector3(aabb.size.x / 2, aabb.size.y, aabb.size.z)
#		outline_container.add_child(line8)
#		var line9 = CSGBox.new()
#		line9.material = selection_box_material
#		line9.width = selection_line_size
#		line9.depth = aabb.size.z + selection_line_size
#		line9.height = selection_line_size
#		line9.translation = aabb.position + Vector3(0, 0, aabb.size.z / 2)
#		outline_container.add_child(line9)
#		var line10 = CSGBox.new()
#		line10.material = selection_box_material
#		line10.width = selection_line_size
#		line10.depth = aabb.size.z + selection_line_size
#		line10.height = selection_line_size
#		line10.translation = aabb.position + Vector3(aabb.size.x, 0, aabb.size.z / 2)
#		outline_container.add_child(line10)
#		var line11 = CSGBox.new()
#		line11.material = selection_box_material
#		line11.width = selection_line_size
#		line11.depth = aabb.size.z + selection_line_size
#		line11.height = selection_line_size
#		line11.translation = aabb.position + Vector3(0, aabb.size.y, aabb.size.z / 2)
#		outline_container.add_child(line11)
#		var line12 = CSGBox.new()
#		line12.material = selection_box_material
#		line12.width = selection_line_size
#		line12.depth = aabb.size.z + selection_line_size
#		line12.height = selection_line_size
#		line12.translation = aabb.position + Vector3(aabb.size.x, aabb.size.y, aabb.size.z / 2)
#		outline_container.add_child(line12)
#		add_child(outline_container)
#		outline_container.name = "SelectionOutline"

func deselect():
	var selection_outline = get_node_or_null("SelectionOutline")
	if selection_outline != null:
		selection_outline.get_parent().remove_child(selection_outline)
	var selection_mesh = get_node_or_null("SelectionMesh")
	if selection_mesh != null:
		selection_mesh.get_parent().remove_child(selection_mesh)
	loaded_model.show()
