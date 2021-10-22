extends BaseRoom3dNode

const gizmo_spot_light_icon = preload("res://Icons/Editor/GizmoSpotLight.svg")
const light_defaults = preload("res://Config/LightDefaults.gd").light_defaults

var camera: Camera = null
var scale_container: Spatial = null
var gizmo_sprite: Sprite3D = null
var gizmo_bounds: ImmediateGeometry = null
var spot_light: SpotLight = null
var collision_area: Area = null

var light_default_overrides: Dictionary = {} # Set from blueprint or dynamic class
var is_gizmo_hidden: bool = false

func _init():
	selection_light_node = self

func _ready():
	camera = room_3d_display.get_node("Camera")
	_ready_selection_transform_node()
	
	room_3d_display.connect("view_gizmo_toggled", self, "on_view_gizmo_toggled")
	
	call_deferred("after_placed")

func _process(_delta):
	if camera:
		if scale_container and not is_gizmo_hidden:
			var fixed_scale = get_global_transform().origin.distance_to(camera.translation) / 12
			scale_container.scale = Vector3(fixed_scale, fixed_scale, fixed_scale)

func on_view_gizmo_toggled(gizmo_name: String, is_checked: bool):
	if gizmo_name == "light":
		is_gizmo_hidden = !is_checked
		scale_container.visible = is_checked
		if not is_checked:
			collision_area.collision_layer = 0
		elif can_enable_collision_area():
			collision_area.collision_layer = PhysicsLayers3d.layers.editor_select_light

func can_enable_collision_area():
	return not is_in_deleted_branch and not is_in_hidden_branch and not is_gizmo_hidden

func get_light_default(property_name):
	if light_default_overrides.has(property_name):
		return light_default_overrides[property_name]
	else:
		return light_defaults[property_name]

func after_placed():
	scale_container = Spatial.new()
	gizmo_sprite = Sprite3D.new()
	gizmo_sprite.texture = gizmo_spot_light_icon
	gizmo_sprite.billboard = SpatialMaterial.BILLBOARD_ENABLED
	gizmo_sprite.shaded = false
	scale_container.add_child(gizmo_sprite)
	gizmo_sprite.name = "LightGizmoSprite"
	
	collision_area = Area.new()
	collision_area.set_script(node_selection_area_script)
	collision_area.selectable_parent = self
	var collision_shape = CollisionShape.new()
	var box_shape = SphereShape.new()
	box_shape.radius = .6
	if is_in_deleted_branch or is_in_hidden_branch:
		collision_area.collision_layer = 0
	else:
		collision_area.collision_layer = PhysicsLayers3d.layers.editor_select_light
	collision_area.collision_mask = PhysicsLayers3d.layers.none
	collision_shape.set_shape(box_shape)
	collision_area.add_child(collision_shape)
	scale_container.add_child(collision_area)
	collision_area.name = "CollisionArea"
	
	add_child(scale_container)
	scale_container.name = "LightIconAndCollider"
	
	spot_light = SpotLight.new()
	set_light_properties(definition, true)
	add_child(spot_light)
	spot_light.rotation_degrees = Vector3(0, -90, 0)
	spot_light.name = "SpotLight"
	
	undo_parent_scale(get_parent(), Vector3(1, 1, 1))

func undo_parent_scale(parent: Spatial, scale_tmp: Vector3):
	if parent == null:
		global_scale(Vector3(1 / scale_tmp.x, 1 / scale_tmp.y, 1 / scale_tmp.z))
	else:
		if parent.has_method("get_scale"):
			scale_tmp *= parent.get_scale()
		undo_parent_scale(parent.get_parent(), scale_tmp)

func set_light_properties(properties: Dictionary, fallback_to_defaults: bool = false):
	var mobility = get_light_default("mobility")
	if properties.has("mobility"):
		mobility = properties["mobility"]
	elif definition.has("mobility"):
		mobility = definition["mobility"]
	
	var use_inverse_squared_falloff = get_light_default("use_inverse_squared_falloff")
	if properties.has("use_inverse_squared_falloff"):
		use_inverse_squared_falloff = properties["use_inverse_squared_falloff"]
	elif definition.has("use_inverse_squared_falloff"):
		use_inverse_squared_falloff = definition["use_inverse_squared_falloff"]
	
	var light_falloff_exponent = get_light_default("light_falloff_exponent")
	if properties.has("light_falloff_exponent"):
		light_falloff_exponent = properties["light_falloff_exponent"]
	elif definition.has("light_falloff_exponent"):
		light_falloff_exponent = definition["light_falloff_exponent"]
	
	if use_inverse_squared_falloff:
		spot_light.light_inverse_square = false # true 
		spot_light.spot_attenuation = 1
	else:
		spot_light.light_inverse_square = false
		spot_light.spot_attenuation = light_falloff_exponent
	
	if properties.has("outer_cone_angle"):
		spot_light.spot_angle = properties["outer_cone_angle"]
	else:
		spot_light.spot_angle = get_light_default("outer_cone_angle")
	
	if properties.has("intensity"):
		if use_inverse_squared_falloff:
			spot_light.light_energy = convert_lumens_to_energy(properties["intensity"])
		else:
			spot_light.light_energy = properties["intensity"]
	elif fallback_to_defaults:
		if use_inverse_squared_falloff:
			spot_light.light_energy = convert_lumens_to_energy(get_light_default("intensity"))
		else:
			spot_light.light_energy = get_light_default("intensity")
	
	var light_color = get_light_default("light_color")
	if properties.has("light_color"):
		light_color = properties["light_color"]
	elif definition.has("light_color"):
		light_color = definition["light_color"]
	light_color.a = 1
	spot_light.light_color = light_color
	
	if properties.has("attenuation_radius"):
		spot_light.spot_range = properties["attenuation_radius"]
		if is_selected:
			update_gizmo_bounds()
	elif fallback_to_defaults:
		spot_light.spot_range = get_light_default("attenuation_radius")
	
	# Not sure if source_radius, soft_source_radius, source_length have an equivalent in Godot.
	
	var use_temperature = get_light_default("use_temperature")
	if properties.has("use_temperature"):
		if properties["use_temperature"] == true:
			use_temperature = true
	elif definition.has("use_temperature"):
		if definition["use_temperature"]:
			use_temperature = true
	
	if use_temperature:
		var temperature = get_light_default("temperature")
		if properties.has("temperature"):
			temperature = properties["temperature"]
		elif definition.has("temperature"):
			temperature = definition["temperature"]
		var temperature_color = convert_kelvin_to_color(temperature)
		spot_light.light_color = Color(
			light_color.r * temperature_color.r,
			light_color.g * temperature_color.g,
			light_color.b * temperature_color.b,
			1
		)
	
#	if properties.has("cast_shadows"):
#		spot_light.shadow_enabled = properties["cast_shadows"]
#	elif fallback_to_defaults:
#		spot_light.shadow_enabled = get_light_default("cast_shadows")
	
	if properties.has("indirect_lighting_intensity"):
		spot_light.light_indirect_energy = properties["indirect_lighting_intensity"]
	elif fallback_to_defaults:
		spot_light.light_indirect_energy = get_light_default("indirect_lighting_intensity")
	
	spot_light.visible = mobility != "static"
	
	gizmo_sprite.modulate = spot_light.light_color
	if mobility == "static":
		gizmo_sprite.modulate.a = 0.5

func convert_lumens_to_energy(lumens: float):
	return lumens / 5000

func convert_kelvin_to_color(kelvin: float):
	var temperature: float = kelvin / 100
	
	var red: float
	if temperature <= 66:
		red = 255
	else:
		red = temperature - 60
		red = 329.698727446 * pow(red, -0.1332047592)
		if red < 0:
			red = 0
		if red > 255:
			red = 255
	
	var green: float
	if temperature <= 66:
		green = temperature
		green = 99.4708025861 * log(green) - 161.1195681661
	else:
		green = temperature - 60
		green = 288.1221695283 * pow(green, -0.0755148492)
	if green < 0:
		green = 0
	if green > 255:
		green = 255
	
	var blue: float
	if temperature >= 66:
		blue = 255
	elif temperature <= 19:
		blue = 0
	else:
		blue = temperature - 10
		blue = 138.5177312231 * log(blue) - 305.0447927307
		if blue < 0:
			blue = 0
		if blue > 255:
			blue = 255
	return Color(red / 255, green / 255, blue / 255)

func update_gizmo_bounds():
	remove_gizmo_bounds()
	
	var attenuation_radius = spot_light.spot_range
	var angle = deg2rad(spot_light.spot_angle)
	var radius = spot_light.spot_range * tan(angle)
	
	gizmo_bounds = ImmediateGeometry.new()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINE_LOOP)
	ImmediateGeometryExt.draw_circle_arc(gizmo_bounds, Vector3(spot_light.spot_range, 0, 0), Vector3(0, 1, 0), 90, radius, 0, 360, 64)
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINES)
	gizmo_bounds.add_vertex(Vector3(0, 0, 0))
	gizmo_bounds.add_vertex(Vector3(spot_light.spot_range, radius, 0))
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINES)
	gizmo_bounds.add_vertex(Vector3(0, 0, 0))
	gizmo_bounds.add_vertex(Vector3(spot_light.spot_range, -radius, 0))
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINES)
	gizmo_bounds.add_vertex(Vector3(0, 0, 0))
	gizmo_bounds.add_vertex(Vector3(spot_light.spot_range, 0, radius))
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINES)
	gizmo_bounds.add_vertex(Vector3(0, 0, 0))
	gizmo_bounds.add_vertex(Vector3(spot_light.spot_range, 0, -radius))
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINES)
	gizmo_bounds.add_vertex(Vector3(0, 0, 0))
	gizmo_bounds.add_vertex(Vector3(spot_light.spot_range, cos(PI/4) * radius, sin(PI/4) * radius))
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINES)
	gizmo_bounds.add_vertex(Vector3(0, 0, 0))
	gizmo_bounds.add_vertex(Vector3(spot_light.spot_range, cos(3*PI/4) * radius, sin(3*PI/4) * radius))
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINES)
	gizmo_bounds.add_vertex(Vector3(0, 0, 0))
	gizmo_bounds.add_vertex(Vector3(spot_light.spot_range, cos(5*PI/4) * radius, sin(5*PI/4) * radius))
	gizmo_bounds.end()
	gizmo_bounds.begin(Mesh.PRIMITIVE_LINES)
	gizmo_bounds.add_vertex(Vector3(0, 0, 0))
	gizmo_bounds.add_vertex(Vector3(spot_light.spot_range, cos(7*PI/4) * radius, sin(7*PI/4) * radius))
	gizmo_bounds.end()
	gizmo_bounds.material_override = selection_box_material
	add_child(gizmo_bounds)
	gizmo_bounds.name = "LightGizmoBounds"

func remove_gizmo_bounds():
	if gizmo_bounds != null:
		var gizmo_bounds_parent = gizmo_bounds.get_parent()
		if gizmo_bounds_parent:
			gizmo_bounds_parent.remove_child(gizmo_bounds)
		gizmo_bounds = null

func set_deleted(deleted: bool):
	.set_deleted(deleted)
	if collision_area:
		if deleted:
			collision_area.collision_layer = 0
			hide()
		elif can_enable_collision_area():
			collision_area.collision_layer = PhysicsLayers3d.layers.editor_select_light
			show()

func set_hidden(hidden: bool):
	.set_hidden(hidden)
	if collision_area:
		if hidden:
			collision_area.collision_layer = 0
			hide()
		elif can_enable_collision_area():
			collision_area.collision_layer = PhysicsLayers3d.layers.editor_select_light
			show()

func select():
	.select()
	update_gizmo_bounds()
	
func deselect():
	.deselect()
	remove_gizmo_bounds()
