extends Spatial

signal control_active
signal control_inactive

var camera: Camera

var can_capture_mouse: bool = false
var is_mouse_button_left_down: bool = false
var is_mouse_button_right_down: bool = false
var is_shift_modifier_pressed: bool = false
var mouse_down_collider = null
var mouse_hover_collider = null

# Called when the node enters the scene tree for the first time.
func _ready():
	camera = find_node("Camera", true, true)

func _input(event):
	
	if event is InputEventMouseMotion:
		#_mouse_position = event.relative
		handle_mouse_move_collision(event)
	
	# Object selection
	if event is InputEventMouseButton:
		match event.button_index:
			BUTTON_LEFT:
				is_mouse_button_left_down = event.pressed
				if can_capture_mouse and not is_mouse_button_right_down and event.pressed:
					handle_mouse_down_collision(event)
				if not event.pressed:
					handle_mouse_up_collision(event)
			BUTTON_RIGHT:
				is_mouse_button_right_down = event.pressed

	if event is InputEventKey:
		if event.scancode == KEY_SHIFT:
			is_shift_modifier_pressed = event.pressed

func handle_mouse_down_collision(event):
	var ray_length = 100
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_from = camera.project_ray_origin(mouse_pos)
	var ray_to = ray_from + camera.project_ray_normal(mouse_pos) * ray_length
	var space_state = get_world().direct_space_state
	# Find all intersections on ray
	var collision_mask = PhysicsLayers3d.layers.editor_control_select
	var intersection = space_state.intersect_ray(ray_from, ray_to, [], collision_mask, true, true)
	if intersection != null and intersection.has("collider"):
		mouse_down_collider = intersection.collider
		var collider_parent = intersection.collider.get_parent()
		if collider_parent.has_method("handle_mouse_down_collision"):
			var ray = {
				"from": ray_from,
				"to": ray_to
			}
			collider_parent.handle_mouse_down_collision(event, intersection.collider, ray)
		emit_signal("control_active")

func handle_mouse_move_collision(event):
	var ray_length = 100000000000
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_from = camera.project_ray_origin(mouse_pos)
	var ray_to = ray_from + camera.project_ray_normal(mouse_pos) * ray_length
	var ray = {
		"from": ray_from,
		"to": ray_to
	}
	if mouse_down_collider:
		var collider_parent = mouse_down_collider.get_parent()
		if collider_parent.has_method("handle_mouse_move_collision"):
			collider_parent.handle_mouse_move_collision(event, mouse_down_collider, ray)
	else:
		var space_state = get_world().direct_space_state
		var collision_mask = PhysicsLayers3d.layers.editor_control_select
		var intersection = space_state.intersect_ray(ray_from, ray_to, [], collision_mask, true, true)
		var intersection_collider = null
		if intersection != null and intersection.has("collider"):
			intersection_collider = intersection.collider
		if mouse_hover_collider and intersection_collider != mouse_hover_collider:
			var collider_parent = mouse_hover_collider.get_parent()
			if collider_parent.has_method("handle_mouse_leave_collision"):
				collider_parent.handle_mouse_leave_collision(event, mouse_hover_collider, ray)
			mouse_hover_collider = null
		if intersection_collider and intersection_collider != mouse_hover_collider:
			mouse_hover_collider = intersection_collider
			var collider_parent = intersection_collider.get_parent()
			if collider_parent.has_method("handle_mouse_enter_collision"):
				collider_parent.handle_mouse_enter_collision(event, mouse_hover_collider, ray)

func handle_mouse_up_collision(event):
	var ray_length = 100000000000
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_from = camera.project_ray_origin(mouse_pos)
	var ray_to = ray_from + camera.project_ray_normal(mouse_pos) * ray_length
	var ray = {
		"from": ray_from,
		"to": ray_to
	}
	if mouse_down_collider:
		var collider_parent = mouse_down_collider.get_parent()
		if collider_parent.has_method("handle_mouse_up_collision"):
			collider_parent.handle_mouse_up_collision(event, mouse_down_collider, ray)
		emit_signal("control_inactive")
	mouse_down_collider = null
