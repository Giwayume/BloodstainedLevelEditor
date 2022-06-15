extends CustomCollisionMesh

# Called when the node enters the scene tree for the first time.
func create_collision_area():
	generate_sectioned_slope_4(.3, .45, .550067, .6, 6)
	.create_collision_area()
