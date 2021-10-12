extends Spatial

################################################################################################
# NOTICE!                                                                                      #
# The UI of this component is based on Unreal Engine 4 coordinate space.                       #
# Programmatically, Godot works in a different coordinate space. Namely, y/z axis are flipped. #
# Many variables in this script refer to Unreal 4 coordinate names.                            #
################################################################################################

signal rotate_preview
signal rotate_cancel
signal rotate
signal scale_preview
signal scale_cancel
signal scale
signal translate_preview
signal translate_cancel
signal translate

var active_cursor_materials = {
	"x": preload("res://Materials/EditorCursorXAxisActive.tres"),
	"y": preload("res://Materials/EditorCursorYAxisActive.tres"),
	"z": preload("res://Materials/EditorCursorZAxisActive.tres")
}

var inactive_cursor_materials = {
	"x": preload("res://Materials/EditorCursorXAxis.tres"),
	"y": preload("res://Materials/EditorCursorYAxis.tres"),
	"z": preload("res://Materials/EditorCursorZAxis.tres")
}

var camera: Camera

var nodes: Dictionary
var mode: String = "move"
var drag_start = null
var drag_last = null
var scale_start = null
var translate_start = null
var rotate_start = null

func _ready():
	camera = get_parent().find_node("Camera", true, true)
	nodes = {
		"x": {
			"stem": $XCoordinateStem,
			"move_handle": $XCoordinateMoveArrow,
			"scale_handle": $XCoordinateScaleHandle,
			"rotate_handle": $XAxisRotateRing,
			"rotate_handle_ring": $XAxisRotateRing/RingHighlight/Ring,
			"rotate_handle_area": $XRotateHandleArea,
			"rotate_handle_area_collision_shape": $XRotateHandleArea/CollisionShape,
			"rotate_line": $XAxisRotateAngleLine,
			"move_scale_handle_area": $XMoveScaleHandleArea,
			"move_scale_handle_area_collision_shape": $XMoveScaleHandleArea/CollisionShape
		},
		"y": {
			"stem": $YCoordinateStem,
			"move_handle": $YCoordinateMoveArrow,
			"scale_handle": $YCoordinateScaleHandle,
			"rotate_handle": $YAxisRotateRing,
			"rotate_handle_ring": $YAxisRotateRing/RingHighlight/Ring,
			"rotate_handle_area": $YRotateHandleArea,
			"rotate_handle_area_collision_shape": $YRotateHandleArea/CollisionShape,
			"rotate_line": $YAxisRotateAngleLine,
			"move_scale_handle_area": $YMoveScaleHandleArea,
			"move_scale_handle_area_collision_shape": $YMoveScaleHandleArea/CollisionShape
		},
		"z": {
			"stem": $ZCoordinateStem,
			"move_handle": $ZCoordinateMoveArrow,
			"scale_handle": $ZCoordinateScaleHandle,
			"rotate_handle": $ZAxisRotateRing,
			"rotate_handle_ring": $ZAxisRotateRing/RingHighlight/Ring,
			"rotate_handle_area": $ZRotateHandleArea,
			"rotate_handle_area_collision_shape": $ZRotateHandleArea/CollisionShape,
			"rotate_line": $ZAxisRotateAngleLine,
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
				if mode == "move":
					translation = translate_start
					emit_signal("translate_cancel")
				elif mode == "scale":
					emit_signal("scale_cancel")
				elif mode == "rotate":
					emit_signal("rotate_cancel")
					nodes["x"].rotate_line.hide()
					nodes["y"].rotate_line.hide()
					nodes["z"].rotate_line.hide()
				drag_start = null
				drag_last = null
				translate_start = null
				scale_start = null
				rotate_start = null

func _process(_delta):
	if camera:
		var fixed_scale = translation.distance_to(camera.translation) / 4
		scale = Vector3(fixed_scale, fixed_scale, fixed_scale)
		var rotate_x = Vector2(translation.y, translation.z).angle_to_point(Vector2(camera.translation.y, camera.translation.z)) + (PI / 2)
		nodes.x.rotate_handle.rotation = Vector3(rotate_x, 0, 0)
		var rotate_y = Vector2(translation.x, translation.y).angle_to_point(Vector2(camera.translation.x, camera.translation.y)) + (PI / 2)
		nodes.y.rotate_handle.rotation = Vector3(0, 0, rotate_y)
		var rotate_z = Vector2(translation.z, translation.x).angle_to_point(Vector2(camera.translation.z, camera.translation.x)) + (PI / 2)
		nodes.z.rotate_handle.rotation = Vector3(0, rotate_z, 0)

func set_disabled(is_disabled: bool):
	if is_disabled:
		hide()
		for axis in nodes:
			nodes[axis].move_scale_handle_area.collision_layer = 0
			nodes[axis].rotate_handle_area.collision_layer = 0
	else:
		show()
		set_mode(mode)

func set_mode(new_mode: String):
	mode = new_mode
	for axis in nodes:
		if mode == "move" or mode == "scale":
			nodes[axis].stem.show()
			nodes[axis].move_scale_handle_area.collision_layer = PhysicsLayers3d.layers.editor_control_select
		else:
			nodes[axis].stem.hide()
			nodes[axis].move_scale_handle_area.collision_layer = 0
		if mode == "move":
			nodes[axis].move_handle.show()
		else:
			nodes[axis].move_handle.hide()
		if mode == "rotate":
			nodes[axis].rotate_handle.show()
			nodes[axis].rotate_handle_area.collision_layer = PhysicsLayers3d.layers.editor_control_select
		else:
			nodes[axis].rotate_handle.hide()
			nodes[axis].rotate_handle_area.collision_layer = 0
		if mode == "scale":
			nodes[axis].scale_handle.show()
		else:
			nodes[axis].scale_handle.hide()
		nodes[axis].rotate_line.hide()

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
	elif collider == nodes.x.rotate_handle_area:
		axis = "x"
		type = "rotate"
	elif collider == nodes.y.rotate_handle_area:
		axis = "y"
		type = "rotate"
	elif collider == nodes.z.rotate_handle_area:
		axis = "z"
		type = "rotate"
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
			drag_start = ray_axis_intersection_along_axis(axis, ray)
			if drag_start != null:
				drag_last = null
				translate_start = translation
				scale_start = scale
		elif type == "rotate":
			drag_start = ray_axis_intersection(ray.from, ray.to, unreal_to_godot_axis(axis))
			if drag_start != null:
				drag_last = null
				rotate_start = point_axis_rotation(drag_start, unreal_to_godot_axis(axis))
				nodes[axis].rotate_line.show()
				rotate_axis_indicator_line(drag_start, unreal_to_godot_axis(axis))

func handle_mouse_move_collision(event, collider, ray):
	handle_mouse_move_release_collision(event, collider, ray, "move")

func handle_mouse_up_collision(event, collider, ray):
	if event.button_index == BUTTON_LEFT:
		handle_mouse_move_release_collision(event, collider, ray, "up")
		drag_start = null
		drag_last = null
		translate_start = null
		scale_start = null
		rotate_start = null
		nodes["x"].rotate_line.hide()
		nodes["y"].rotate_line.hide()
		nodes["z"].rotate_line.hide()

func handle_mouse_move_release_collision(event, collider, ray, mouse_type):
	if drag_start:
		var collider_info = get_collider_info(collider)
		var axis = collider_info.axis
		var type = collider_info.type
		var signal_name = ""
		if type == "move_scale":
			if mode == "move":
				signal_name = "translate_preview"
				if mouse_type == "up":
					signal_name = "translate"
			elif mode == "scale":
				signal_name = "scale_preview"
				if mouse_type == "up":
					signal_name = "scale"
			var drag_now = ray_axis_intersection_along_axis(axis, ray)
			if drag_now != null:
				drag_last = drag_now
				if axis == "x":
					if mode == "scale":
						emit_signal(signal_name, Vector3((drag_now.x - translation.x) / (drag_start.x - translation.x), 1, 1))
					else:
						translation.x = translate_start.x + (drag_now.x - drag_start.x)
						emit_signal(signal_name, Vector3(drag_now.x - drag_start.x, 0, 0))
				if axis == "y":
					if mode == "scale":
						emit_signal(signal_name, Vector3(1, 1, (drag_now.z - translation.z) / (drag_start.z - translation.z)))
					else:
						translation.z = translate_start.z + (drag_now.z - drag_start.z)
						emit_signal(signal_name, Vector3(0, 0, drag_now.z - drag_start.z))
				if axis == "z":
					if mode == "scale":
						emit_signal(signal_name, Vector3(1, (drag_now.y - translation.y) / (drag_start.y - translation.y), 1))
					else:
						translation.y = translate_start.y + (drag_now.y - drag_start.y)
						emit_signal(signal_name, Vector3(0, drag_now.y - drag_start.y, 0))
			if mouse_type == "up" and drag_now == null:
				signal_name = "translate_cancel"
				if mode == "scale":
					signal_name = "scale_cancel"
				emit_signal(signal_name)
		elif type == "rotate":
			var drag_now = ray_axis_intersection(ray.from, ray.to, unreal_to_godot_axis(axis))
			signal_name = "rotate_preview"
			if mouse_type == "up":
				signal_name = "rotate"
			if drag_now != null:
				drag_last = drag_now
			if drag_last != null:
				var rotate_now = point_axis_rotation(drag_last, unreal_to_godot_axis(axis))
				var rotate_axis = Vector3()
				if axis == "x":
					rotate_axis = Vector3(1, 0, 0)
				if axis == "y":
					rotate_axis = Vector3(0, 0, 1)
				if axis == "z":
					rotate_axis = Vector3(0, 1, 0)
				emit_signal(signal_name, rotate_axis, rotate_now - rotate_start)
				rotate_axis_indicator_line(drag_last, unreal_to_godot_axis(axis))
			if mouse_type == "up" and drag_last == null:
				emit_signal("rotate_cancel")

func handle_mouse_enter_collision(event, collider, _ray):
	var collider_info = get_collider_info(collider)
	var axis = collider_info.axis
	var type = collider_info.type
	if type == "move_scale":
		nodes[axis].stem.material_override = active_cursor_materials[axis]
		nodes[axis].move_handle.material_override = active_cursor_materials[axis]
		nodes[axis].scale_handle.material_override = active_cursor_materials[axis]
	elif type == "rotate":
		nodes[axis].rotate_handle_ring.material = active_cursor_materials[axis]

func handle_mouse_leave_collision(event, collider, _ray):
	var collider_info = get_collider_info(collider)
	var axis = collider_info.axis
	var type = collider_info.type
	if type == "move_scale":
		nodes[axis].stem.material_override = null
		nodes[axis].move_handle.material_override = null
		nodes[axis].scale_handle.material_override = null
	elif type == "rotate":
		nodes[axis].rotate_handle_ring.material = inactive_cursor_materials[axis]

# Axis in Unreal 4 coordinates
func ray_axis_intersection_along_axis(axis, ray):
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

# Axis in Godot coordinates
func ray_axis_intersection(ray_from: Vector3, ray_to: Vector3, axis: String):
	var direction = (ray_to - ray_from).normalized()
	if direction[axis] == 0:
		return null
	var distance = (translation[axis] - ray_from[axis]) / direction[axis]
	if distance < 0:
		return null
	return ray_from + direction * distance

# Axis in Godot coordinates
func point_axis_rotation(point: Vector3, axis: String):
	if axis == "x":
		return Vector2(translation.y, translation.z).angle_to_point(Vector2(point.y, point.z))
	elif axis == "y":
		return Vector2(translation.z, translation.x).angle_to_point(Vector2(point.z, point.x))
	elif axis == "z":
		return Vector2(translation.x, translation.y).angle_to_point(Vector2(point.x, point.y))

# Axis in Godot coordinates
func rotate_axis_indicator_line(point: Vector3, axis: String):
	var line = nodes[godot_to_unreal_axis(axis)].rotate_line
	if axis == "x":
		line.rotation = Vector3(point_axis_rotation(point, axis) + PI, 0, 0)
	elif axis == "y":
		line.rotation = Vector3(0, point_axis_rotation(point, axis) + PI, 0)
	elif axis == "z":
		line.rotation = Vector3(0, 0, point_axis_rotation(point, axis) + PI)

func unreal_to_godot_axis(axis):
	if axis == "x":
		return "x"
	if axis == "y":
		return "z"
	if axis == "z":
		return "y"

func godot_to_unreal_axis(axis):
	return unreal_to_godot_axis(axis)
