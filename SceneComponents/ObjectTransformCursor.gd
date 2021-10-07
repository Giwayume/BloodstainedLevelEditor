extends Spatial

signal translate_preview
signal translate_cancel
signal translate

var active_cursor_materials = {
	"x": preload("res://Materials/EditorCursorXAxisActive.tres"),
	"y": preload("res://Materials/EditorCursorYAxisActive.tres"),
	"z": preload("res://Materials/EditorCursorZAxisActive.tres")
}

var camera: Camera

var nodes: Dictionary
var mode: String = "move"
var drag_start = null
var translate_start = null

func _ready():
	camera = get_parent().find_node("Camera", true, true)
	nodes = {
		"x": {
			"stem": $XCoordinateStem,
			"move_handle": $XCoordinateMoveArrow,
			"scale_handle": $XCoordinateScaleHandle,
			"rotate_handle": $XAxisRotateRing,
			"move_scale_handle_area": $XMoveScaleHandleArea,
			"move_scale_handle_area_collision_shape": $XMoveScaleHandleArea/CollisionShape
		},
		"y": {
			"stem": $YCoordinateStem,
			"move_handle": $YCoordinateMoveArrow,
			"scale_handle": $YCoordinateScaleHandle,
			"rotate_handle": $YAxisRotateRing,
			"move_scale_handle_area": $YMoveScaleHandleArea,
			"move_scale_handle_area_collision_shape": $YMoveScaleHandleArea/CollisionShape
		},
		"z": {
			"stem": $ZCoordinateStem,
			"move_handle": $ZCoordinateMoveArrow,
			"scale_handle": $ZCoordinateScaleHandle,
			"rotate_handle": $ZAxisRotateRing,
			"move_scale_handle_area": $ZMoveScaleHandleArea,
			"move_scale_handle_area_collision_shape": $ZMoveScaleHandleArea/CollisionShape
		}
	}
	set_mode("move")
	hide()

func _input(event):
	if event is InputEventKey:
		if event.scancode == KEY_ESCAPE:
			if drag_start:
				translation = translate_start
				emit_signal("translate_cancel")
				drag_start = null
				translate_start = null

func _process(_delta):
	if camera:
		var fixed_scale = translation.distance_to(camera.translation) / 4
		scale = Vector3(fixed_scale, fixed_scale, fixed_scale)

func set_mode(new_mode: String):
	mode = new_mode
	for axis in nodes:
		if mode == "move" or mode == "scale":
			nodes[axis].stem.show()
		else:
			nodes[axis].stem.hide()
		if mode == "move" or mode == "scale":
			nodes[axis].move_scale_handle_area.collision_layer = PhysicsLayers3d.layers.editor_control_select
		else:
			nodes[axis].move_scale_handle_area.collision_layer = 0
		if mode == "move":
			nodes[axis].move_handle.show()
		else:
			nodes[axis].move_handle.hide()
		if mode == "rotate":
			nodes[axis].rotate_handle.show()
		else:
			nodes[axis].rotate_handle.hide()
		if mode == "scale":
			nodes[axis].scale_handle.show()
		else:
			nodes[axis].scale_handle.hide()

func get_collider_info(collider):
	var axis = null
	var type = null
	if collider == nodes.x.move_scale_handle_area:
		axis = "x"
		type = "move_scale"
	elif collider == nodes.y.move_scale_handle_area:
		axis = "y"
		type = "move_scale"
	elif collider == nodes.z.move_scale_handle_area:
		axis = "z"
		type = "move_scale"
	return {
		"axis": axis,
		"type": type
	}

func handle_mouse_down_collision(event, collider, ray):
	if event.button_index == BUTTON_LEFT:
		var collider_info = get_collider_info(collider)
		var axis = collider_info.axis
		var type = collider_info.type
		if type == "move_scale":
			drag_start = get_axis_ray_collision(axis, ray)
			translate_start = translation

func handle_mouse_move_collision(event, collider, ray):
	handle_mouse_move_release_collision(event, collider, ray, "move")

func handle_mouse_up_collision(event, collider, ray):
	if event.button_index == BUTTON_LEFT:
		handle_mouse_move_release_collision(event, collider, ray, "up")
		drag_start = null
		translate_start = null

func handle_mouse_move_release_collision(event, collider, ray, mouse_type):
	if drag_start:
		var signal_name = "translate_preview"
		if mouse_type == "up":
			signal_name = "translate"
		var collider_info = get_collider_info(collider)
		var axis = collider_info.axis
		var type = collider_info.type
		if type == "move_scale":
			var drag_now = get_axis_ray_collision(axis, ray)
			if drag_now != null:
				if axis == "x":
					translation.x = translate_start.x + (drag_now.x - drag_start.x)
					emit_signal(signal_name, Vector3(drag_now.x - drag_start.x, 0, 0))
				if axis == "y":
					translation.z = translate_start.z + (drag_now.z - drag_start.z)
					emit_signal(signal_name, Vector3(0, 0, drag_now.z - drag_start.z))
				if axis == "z":
					translation.y = translate_start.y + (drag_now.y - drag_start.y)
					emit_signal(signal_name, Vector3(0, drag_now.y - drag_start.y, 0))

func handle_mouse_enter_collision(event, collider, _ray):
	var collider_info = get_collider_info(collider)
	var axis = collider_info.axis
	var type = collider_info.type
	if type == "move_scale":
		nodes[axis].stem.material_override = active_cursor_materials[axis]
		nodes[axis].move_handle.material_override = active_cursor_materials[axis]
		nodes[axis].scale_handle.material_override = active_cursor_materials[axis]

func handle_mouse_leave_collision(event, collider, _ray):
	var collider_info = get_collider_info(collider)
	var axis = collider_info.axis
	var type = collider_info.type
	if type == "move_scale":
		nodes[axis].stem.material_override = null
		nodes[axis].move_handle.material_override = null
		nodes[axis].scale_handle.material_override = null

func get_axis_ray_collision(axis, ray):
	var collision = null
	var x_distance = abs(ray.from.x - translation.x)
	var y_distance = abs(ray.from.y - translation.y)
	var z_distance = abs(ray.from.z - translation.z)
	var intersect_axis
	if axis == "x":
		intersect_axis = "y"
		if z_distance > y_distance:
			intersect_axis = "z"
		collision = ray_axis_intersection(ray.from, ray.to, intersect_axis)
	elif axis == "y":
		intersect_axis = "y"
		if x_distance > y_distance:
			intersect_axis = "x"
		collision = ray_axis_intersection(ray.from, ray.to, intersect_axis)
	elif axis == "z":
		intersect_axis = "x"
		if z_distance > x_distance:
			intersect_axis = "z"
		collision = ray_axis_intersection(ray.from, ray.to, intersect_axis)
	if collision != null:
		if axis == "x":
			collision.y = translation.z
			collision.z = translation.y
		elif axis == "y":
			collision.x = translation.x
			collision.y = translation.z
		elif axis == "z":
			collision.x = translation.x
			collision.z = translation.y
	return collision

func ray_axis_intersection(ray_from: Vector3, ray_to: Vector3, axis: String):
	var direction = (ray_to - ray_from).normalized()
	if direction[axis] == 0:
		return null
	var distance = (translation[axis] - ray_from[axis]) / direction[axis]
	return ray_from + direction * distance

