extends CustomCollisionMesh

# Called when the node enters the scene tree for the first time.
func create_collision_area():
	generate_sectioned_slope_3(.4, .5, .6, 6)
	.create_collision_area()
