extends Node2D

signal level_activated
signal level_selected

var tile_width: float = 12.6
var tile_height: float = 7.2
var scrolling: bool = false
var scroll_start_position: Vector2
var scroll_start_mouse_position: Vector2
var zoom_increment = 1.1
var rooms_by_name: Dictionary = {}
var room_coordinate_map: Dictionary = {}
var selected_room_names: Array = []

#############
# LIFECYCLE #
#############

func _ready():
	center_map_in_parent()

func _input(event):
	var parent = get_parent()
	var parent_position = parent.rect_global_position
	var global_mouse_position = get_global_mouse_position()
	var is_mouse_in_parent_bounds = (
		global_mouse_position.x > parent_position.x and
		global_mouse_position.y > parent_position.y and
		global_mouse_position.x < parent_position.x + parent.rect_size.x and
		global_mouse_position.y < parent_position.y + parent.rect_size.y
	)
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			if is_mouse_in_parent_bounds:
				deselect_all_rooms()
				var position_offset = global_mouse_position - get_global_position()
				var coordinate_x = floor(position_offset.x / tile_width / scale.x)
				var coordinate_z = -ceil(position_offset.y / tile_height / scale.x)
				var coordinate_key = str(coordinate_x) + "," + str(coordinate_z)
				if room_coordinate_map.has(coordinate_key):
					var level_name = room_coordinate_map[coordinate_key]
					add_room_to_selection(level_name);
					if event.doubleclick:
						emit_signal("level_activated", level_name)
					else:
						emit_signal("level_selected", level_name)
					
		if event.button_index == BUTTON_RIGHT or event.button_index == BUTTON_MIDDLE:
			if is_mouse_in_parent_bounds and not scrolling and event.pressed:
				scrolling = true
				scroll_start_position = position
				scroll_start_mouse_position = event.position
			if scrolling and not event.pressed:
				scrolling = false
		if is_mouse_in_parent_bounds and event.button_index == BUTTON_WHEEL_UP and scale.x < 8:
			scale *= Vector2(zoom_increment, zoom_increment)
			position -= (global_mouse_position - get_global_position()) * (zoom_increment - 1)
		if is_mouse_in_parent_bounds and event.button_index == BUTTON_WHEEL_DOWN:
			scale *= Vector2(1 / zoom_increment, 1 / zoom_increment)
			if scale.x < 1:
				scale = Vector2(1, 1)
			else:
				position += (global_mouse_position - get_global_position()) * (1 - (1/zoom_increment))
	if event is InputEventMouseMotion and scrolling:
		position = scroll_start_position + event.position - scroll_start_mouse_position

###########
# METHODS #
###########

func init():
	center_map_in_parent()
	var all_rooms = get_children()
	for room in all_rooms:
		var level_name = room.level_name
		if not rooms_by_name.has(level_name):
			rooms_by_name[level_name] = []
		rooms_by_name[level_name].push_back(room)
		var offset_x = round(room.offset_x / tile_width)
		var offset_z = round(room.offset_z / tile_height)
		var area_width_size = round(room.area_width_size)
		var area_height_size = round(room.area_height_size)
		for room_x in range(0, area_width_size):
			for room_z in range(0, area_height_size):
				var coordinate_key = str(offset_x + room_x) + "," + str(offset_z + room_z)
				room_coordinate_map[coordinate_key] = level_name

func deselect_all_rooms():
	for room_name in selected_room_names:
		if rooms_by_name.has(room_name):
			for room in rooms_by_name[room_name]:
				room.deselect()
	selected_room_names = []

func add_room_to_selection(level_name: String):
	if rooms_by_name.has(level_name):
		for room in rooms_by_name[level_name]:
			room.select()
	selected_room_names.push_back(level_name)

func center_map_in_parent():
	var parent = get_parent()
	position = Vector2(parent.rect_size.x / 2, parent.rect_size.y / 2)
	position += Vector2(-700, 0)

func select_room_and_center(level_name: String):
	deselect_all_rooms()
	add_room_to_selection(level_name)
	center_on_selected_rooms()

func center_on_selected_rooms():
	var total_x = 0
	var total_z = 0
	var room_count = 0
	for room_name in selected_room_names:
		if rooms_by_name.has(room_name):
			for room in rooms_by_name[room_name]:
				total_x += room.offset_x + (room.area_width_size * tile_width / 2)
				total_z += room.offset_z + (room.area_height_size * tile_height / 2)
				room_count += 1
	if room_count > 0:
		var parent = get_parent()
		position = Vector2(parent.rect_size.x / 2, parent.rect_size.y / 2)
		position += Vector2(-total_x / room_count * scale.x, total_z / room_count * scale.y)
