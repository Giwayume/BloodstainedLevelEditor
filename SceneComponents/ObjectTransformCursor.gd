extends Spatial

var active_cursor_materials = {
	"x": preload("res://Materials/EditorCursorXAxisActive.tres"),
	"y": preload("res://Materials/EditorCursorYAxisActive.tres"),
	"z": preload("res://Materials/EditorCursorZAxisActive.tres")
}

var camera: Camera

var nodes: Dictionary
var mode: String = "select"
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
			"move_scale_handle_area": $XMoveScaleHandleArea
		},
		"y": {
			"stem": $YCoordinateStem,
			"move_handle": $YCoordinateMoveArrow,
			"scale_handle": $YCoordinateScaleHandle,
			"rotate_handle": $YAxisRotateRing,
			"move_scale_handle_area": $YMoveScaleHandleArea
		},
		"z": {
			"stem": $ZCoordinateStem,
			"move_handle": $ZCoordinateMoveArrow,
			"scale_handle": $ZCoordinateScaleHandle,
			"rotate_handle": $ZAxisRotateRing,
			"move_scale_handle_area": $ZMoveScaleHandleArea
		}
	}
	set_mode("select")

func _process(_delta):
	if camera:
		var fixed_scale = translation.distance_to(camera.translation) / 4
		scale = Vector3(fixed_scale, fixed_scale, fixed_scale)

func set_mode(new_mode: String):
	mode = new_mode
	for axis in nodes:
		if mode == "select" or mode == "move" or mode == "scale":
			nodes[axis].stem.show()
		else:
			nodes[axis].stem.hide()
		if mode == "select" or mode == "move":
			nodes[axis].move_handle.show()
		else:
			nodes[axis].move_handle.hide()
		if mode == "select" or mode == "rotate":
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
	if drag_start:
		var collider_info = get_collider_info(collider)
		var axis = collider_info.axis
		var type = collider_info.type
		if type == "move_scale":
			var drag_now = get_axis_ray_collision(axis, ray)
			if drag_now != null:
				if axis == "x":
					translation.x = translate_start.x + (drag_now.x - drag_start.x)
				if axis == "y":
					translation.z = translate_start.z + (drag_now.z - drag_start.z)
				if axis == "z":
					translation.y = translate_start.y + (drag_now.y - drag_start.y)

func handle_mouse_up_collision(event, collider, ray):
	if event.button_index == BUTTON_LEFT:
		drag_start = null

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
	var planeA = Vector3()
	var planeB = Vector3()
	var planeC = Vector3()
	var planeD = Vector3()
	var bignum = 1000000000000
	if axis == 'x':
		planeA = Vector3(-bignum, translation.y, -bignum)
		planeB = Vector3(-bignum, translation.y, bignum)
		planeC = Vector3(bignum, translation.y, bignum)
		planeD = Vector3(bignum, translation.y, -bignum)
	elif axis == 'y':
		planeA = Vector3(-bignum, translation.y, -bignum)
		planeB = Vector3(-bignum, translation.y, bignum)
		planeC = Vector3(bignum, translation.y, bignum)
		planeD = Vector3(bignum, translation.y, -bignum)
	elif axis == 'z':
		planeA = Vector3(translation.x, -bignum, -bignum)
		planeB = Vector3(translation.x, -bignum, bignum)
		planeC = Vector3(translation.x, bignum, bignum)
		planeD = Vector3(translation.x, bignum, -bignum)
	var collision = Geometry.ray_intersects_triangle(
		ray.from,
		ray.to,
		planeA,
		planeB,
		planeC
	)
	if collision == null:
		collision = Geometry.ray_intersects_triangle(
			ray.from,
			ray.to,
			planeB,
			planeC,
			planeD
		)
	if collision != null:
		if axis == 'x':
			collision.y = translation.z
			collision.z = translation.y
		elif axis == 'y':
			collision.x = translation.x
			collision.y = translation.z
		elif axis == 'z':
			collision.x = translation.x
			collision.z = translation.y
	return collision
