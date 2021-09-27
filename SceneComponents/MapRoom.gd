extends Node2D

var background: Polygon2D
var tile_width: float = 12.6
var tile_height: float = 7.2
var outline_size: float = 1
var door_size: float = 3
var background_default: Color = Color("00a5ff")
var background_selected: Color = Color("eb8606")
var door_list = []

var level_name: String = ""
var adjacent_room_name: Array = []
var offset_x: float = 0
var offset_z: float = 0
var area_width_size: float = 1
var area_height_size: float = 1
var door_flag: Array = []

var directions = {
	"left": 0x0001,
	"bottom": 0x0002,
	"right": 0x0004,
	"top": 0x0008,
	"left_bottom": 0x0010,
	"right_bottom": 0x0020,
	"left_top": 0x0040,
	"right_top": 0x0080,
	"top_left": 0x0100,
	"top_right": 0x0200,
	"bottom_right": 0x0400,
	"bottom_left": 0x0800
}

# Called when the node enters the scene tree for the first time.
func _ready():
	background = get_node("Background")

func init(params: Dictionary):
	level_name = params.level_name
	adjacent_room_name = params.adjacent_room_name
	offset_x = round(params.offset_x / tile_width) * tile_width
	offset_z = round(params.offset_z / tile_height) * tile_height
	area_width_size = params.area_width_size
	area_height_size = params.area_height_size
	door_flag = params.door_flag
	position = Vector2(offset_x, -offset_z)
	var width = tile_width * area_width_size
	var height = -tile_height * area_height_size
	var outline_half = outline_size / 2
	# Set background
	background.color = background_default
	background.polygon = PoolVector2Array([
		Vector2(0, 0),
		Vector2(0, height),
		Vector2(width, height),
		Vector2(width, 0)
	])
	# Create outline
	var outline_left = Polygon2D.new()
	outline_left.color = Color.white
	outline_left.polygon = PoolVector2Array([
		Vector2(-outline_half, 0),
		Vector2(-outline_half, height),
		Vector2(outline_half, height),
		Vector2(outline_half, 0)
	])
	add_child(outline_left)
	var outline_right = Polygon2D.new()
	outline_right.color = Color.white
	outline_right.polygon = PoolVector2Array([
		Vector2(width - outline_half, 0),
		Vector2(width - outline_half, height),
		Vector2(width + outline_half, height),
		Vector2(width + outline_half, 0)
	])
	add_child(outline_right)
	var outline_top = Polygon2D.new()
	outline_top.color = Color.white
	outline_top.polygon = PoolVector2Array([
		Vector2(-outline_half, height - outline_half),
		Vector2(width + outline_half, height- outline_half),
		Vector2(width + outline_half, height + outline_half),
		Vector2(-outline_half, height + outline_half)
	])
	add_child(outline_top)
	var outline_bottom = Polygon2D.new()
	outline_bottom.color = Color.white
	outline_bottom.polygon = PoolVector2Array([
		Vector2(-outline_half, outline_half),
		Vector2(-outline_half, -outline_half),
		Vector2(width + outline_half, -outline_half),
		Vector2(width + outline_half, outline_half)
	])
	add_child(outline_bottom)
	# Doors
	for i in range(0, len(door_flag), 2):
		var x_block = 0
		var z_block = 0
		var tile_index = door_flag[i] - 1
		var direction = door_flag[i + 1]
		if area_width_size == 0:
			x_block = tile_index
			z_block = 0
		else:
			x_block = int(tile_index) % int(area_width_size)
			z_block = floor(tile_index / area_width_size)
		for direction_name in directions:
			var direction_part = directions[direction_name]
			if (direction & direction_part) != 0:
				door_list.push_back({
					"x_block": x_block,
					"z_block": z_block,
					"direction_part": direction_part
				})
	var door_margin_x = (tile_width - door_size) / 2
	var door_margin_z = (tile_height - door_size) / 2
	var top_directions = [directions.top, directions.top_left, directions.top_right]
	var bottom_directions = [directions.bottom, directions.bottom_left, directions.bottom_right]
	var left_directions = [directions.left, directions.left_top, directions.left_bottom]
	var right_directions = [directions.right, directions.right_top, directions.right_bottom]
	for door in door_list:
		var door_polygon = Polygon2D.new()
		door_polygon.color = background_default
		if door.direction_part in top_directions:
			door_polygon.polygon = PoolVector2Array([
				Vector2(door_margin_x, -tile_height - outline_half),
				Vector2(tile_width - door_margin_x, -tile_height - outline_half),
				Vector2(tile_width - door_margin_x, -tile_height + outline_half),
				Vector2(door_margin_x, -tile_height + outline_half)
			])
		elif door.direction_part in bottom_directions:
			door_polygon.polygon = PoolVector2Array([
				Vector2(door_margin_x, -outline_half),
				Vector2(tile_width - door_margin_x, -outline_half),
				Vector2(tile_width - door_margin_x, outline_half),
				Vector2(door_margin_x, outline_half)
			])
		elif door.direction_part in left_directions:
			door_polygon.polygon = PoolVector2Array([
				Vector2(-outline_half, -tile_height + door_margin_z),
				Vector2(outline_half, -tile_height + door_margin_z),
				Vector2(outline_half, -door_margin_z),
				Vector2(-outline_half, -door_margin_z)
			])
		elif door.direction_part in right_directions:
			door_polygon.polygon = PoolVector2Array([
				Vector2(tile_width - outline_half, -tile_height + door_margin_z),
				Vector2(tile_width + outline_half, -tile_height + door_margin_z),
				Vector2(tile_width + outline_half, -door_margin_z),
				Vector2(tile_width - outline_half, -door_margin_z)
			])
		add_child(door_polygon)
		door_polygon.position = Vector2(door.x_block * tile_width, -door.z_block * tile_height)
		if door.direction_part in [directions.right_top, directions.left_top]:
			door_polygon.position += Vector2(0, -(door_margin_z + .4))
		if door.direction_part in [directions.right_bottom, directions.left_bottom]:
			door_polygon.position += Vector2(0, door_margin_z - .4)
		if door.direction_part in [directions.top_left, directions.bottom_left]:
			door_polygon.position += Vector2(-(door_margin_x + .5), 0)
		if door.direction_part in [directions.top_right, directions.bottom_right]:
			door_polygon.position += Vector2(door_margin_x - .5, 0)

func select():
	background.color = background_selected
	z_index = 1

func deselect():
	background.color = background_default
	z_index = 0
